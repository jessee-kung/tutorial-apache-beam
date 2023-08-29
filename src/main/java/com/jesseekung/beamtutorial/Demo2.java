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
import org.apache.beam.sdk.transforms.Sum;
import org.apache.beam.sdk.values.PCollection;
import org.apache.beam.sdk.values.KV;
import org.apache.beam.sdk.transforms.windowing.FixedWindows;
import org.apache.beam.sdk.transforms.windowing.Window;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.joda.JodaModule;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import com.jesseekung.beamtutorial.entity.InputMessage;

import org.joda.time.Duration;
import org.joda.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Demo2 {
  public static final Logger logger = LoggerFactory.getLogger(Demo2.class);

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

  static class MessageTransform extends PTransform<PCollection<SequencedMessage>, PCollection<KV<Integer, Integer>>> {
    @Override
    public PCollection<KV<Integer, Integer>> expand(PCollection<SequencedMessage> input) {
      return input.apply(
          "PubsubLiteMessageToKV",
          ParDo.of(new DoFn<SequencedMessage, KV<Integer, Integer>>() {
            @ProcessElement
            public void processElement(
                @Element SequencedMessage element,
                OutputReceiver<KV<Integer, Integer>> outputReceiver) {
              String json = element.getMessage().getData().toStringUtf8();
              try {
                InputMessage message = MAPPER.readValue(json, InputMessage.class);

                Instant ts = Instant.ofEpochSecond(message.getEventTime());
                outputReceiver.outputWithTimestamp(
                    KV.<Integer, Integer>of(message.getUserId(), message.getClick()), ts);
              } catch (Exception e) {
                logger.error("fail to parse from json to table row:", e);
                return;
              }
            }
          }));
    }
  }

  static class KVSumToTableRowTransform extends PTransform<PCollection<KV<Integer, Integer>>, PCollection<TableRow>> {
    @Override
    public PCollection<TableRow> expand(PCollection<KV<Integer, Integer>> input) {
      return input.apply(
        "KVSumToTableRow",
        ParDo.of(new DoFn<KV<Integer, Integer>, TableRow>(){
          @ProcessElement
          public void processElement(ProcessContext context) {
            KV<Integer, Integer> kv = context.element();
            
            TableRow row = new TableRow();
            row.put("processing_time", Instant.now().getMillis() / 1000);
            row.put("user_id", kv.getKey());
            row.put("count", kv.getValue());

            context.output(row);
          }
        })
      );
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

    /**
     * Output: KV<Integer, Integer>, where
     * Integer: user_id
     * Integer: click (always 1)
     */
    PCollection<KV<Integer, Integer>> kvElements = messages.apply(
        "ToKVElements",
        new MessageTransform());

    /**
     * Output: KV<Integer, Integer>, where
     * Integer: user_id
     * Integer: sum of click in the window size
     */
    PCollection<KV<Integer, Integer>> windowedSum = kvElements.apply(
        "ToPerMinuteWindow",
        Window.<KV<Integer, Integer>>into(
            FixedWindows.of(Duration.standardMinutes(1))
        ).withAllowedLateness(Duration.standardMinutes(5))
        .discardingFiredPanes())
        .apply(
            "ToPerMinuteWindowedSum",
            Sum.<Integer>integersPerKey());
    
    PCollection<TableRow> tableRows = windowedSum.apply(
      "ToTableRow",
      new KVSumToTableRowTransform()
    );

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