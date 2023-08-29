package com.jesseekung.beamtutorial;

import com.google.api.services.bigquery.model.TableRow;
import com.google.cloud.pubsublite.proto.SequencedMessage;
import com.google.cloud.pubsublite.SubscriptionPath;

import org.apache.beam.sdk.Pipeline;
import org.apache.beam.sdk.PipelineResult;
import org.apache.beam.sdk.io.gcp.pubsublite.SubscriberOptions;
import org.apache.beam.sdk.io.gcp.pubsublite.PubsubLiteIO;
import org.apache.beam.sdk.io.gcp.bigquery.BigQueryIO;
import org.apache.beam.sdk.io.gcp.bigquery.BigQueryIO.Write.CreateDisposition;
import org.apache.beam.sdk.io.gcp.bigquery.BigQueryIO.Write.WriteDisposition;
import org.apache.beam.sdk.io.gcp.bigquery.InsertRetryPolicy;
import org.apache.beam.sdk.options.PipelineOptions;
import org.apache.beam.sdk.options.PipelineOptionsFactory;
import org.apache.beam.sdk.options.ValueProvider;
import org.apache.beam.sdk.transforms.PTransform;
import org.apache.beam.sdk.transforms.ParDo;
import org.apache.beam.sdk.transforms.DoFn;
import org.apache.beam.sdk.values.PCollection;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.joda.JodaModule;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import com.jesseekung.beamtutorial.entity.InputMessage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Demo1 {
  public static final Logger logger = LoggerFactory.getLogger(Demo1.class);

  public static final ObjectMapper MAPPER = new ObjectMapper()
        .registerModule(new JavaTimeModule())
        .registerModule(new JodaModule())
        .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
        .disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);

  public interface Options extends PipelineOptions {
    ValueProvider<String> getInputSubscription();

    void setInputSubscription(ValueProvider<String> value);

    ValueProvider<String> getOutputTable();

    void setOutputTable(ValueProvider<String> value);
  }

  static class MessageTransform extends PTransform<PCollection<SequencedMessage>, PCollection<TableRow>> {
    @Override
    public PCollection<TableRow> expand(PCollection<SequencedMessage> input) {
      return input.apply(
          "PubsubLiteMessageToTableRow",
          ParDo.of(new DoFn<SequencedMessage, TableRow>() {
            @ProcessElement
            public void processElement(ProcessContext context) {
              String json = context.element().getMessage().getData().toStringUtf8();
              try {
                InputMessage message = MAPPER.readValue(json, InputMessage.class);

                context.output(message.toTableRow());
              } catch (Exception e) {
                logger.error("fail to parse from json to table row:", e);
                return;
              }
            }
          }));
    }
  }

  public static PipelineResult run(Options options) {
    SubscriberOptions subscriberOptions = SubscriberOptions.newBuilder()
        .setSubscriptionPath(SubscriptionPath.parse(options.getInputSubscription().get()))
        .build();

    Pipeline pipeline = Pipeline.create(options);

    PCollection<SequencedMessage> messages = pipeline.apply(
        "ReadPubSubLite",
        PubsubLiteIO.read(subscriberOptions));

    PCollection<TableRow> tableRows = messages.apply(
        "ToTableRows",
        new MessageTransform());

    tableRows.apply(
        "WriteBigQueryTables",
        BigQueryIO.writeTableRows()
            .withoutValidation()
            .withCreateDisposition(CreateDisposition.CREATE_NEVER)
            .withWriteDisposition(WriteDisposition.WRITE_APPEND)
            .withExtendedErrorInfo()
            .withMethod(BigQueryIO.Write.Method.STREAMING_INSERTS)
            .withFailedInsertRetryPolicy(InsertRetryPolicy.retryTransientErrors())
            .to(options.getOutputTable()));

    return pipeline.run();
  }

  public static void main(String[] args) {
    Options options = PipelineOptionsFactory.fromArgs(args).withValidation().as(Options.class);
    run(options);
  }
}