#!/bin/bash
export MKFILE_DIR=$(dirname $(cd "$(dirname "$0")" && pwd)/$(basename "$0"))
export OP=$1
export TOPIC=$2

cd $MKFILE_DIR/deployment/environments/dev/infra

export TF_INFRA_RESOURCE=$(terraform output -json)
if [ "$TF_INFRA_RESOURCE" == "{}" ]; then
    echo "infra resource not ready, build skipped" >> /dev/stderr
    exit 1
fi
cd $MKFILE_DIR

export PROJECT_ID=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_project.project_id" )
export REGION=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_project.region" )
export DEPLOYMENT_BUCKET=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_storage_bucket.deployment_bucket" )
export DATASET_ID=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_bigquery.dataset_id" )
export SERVICE_ACCOUNT_EMAIL=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_service_account")
export NETWORK=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_network.network")
export SUBNETWORK=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_network.subnetwork")

case $TOPIC in
demo1)
    export MAIN_CLASS=com.jesseekung.beamtutorial.Demo1
    export INPUT_SUBSCRIPTION=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_pubsublite.beam_tutorial.subscription_id")
    export OUTPUT_TABLE=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_bigquery.tables.demo1.table_id")
    ;;
demo2)
    export MAIN_CLASS=com.jesseekung.beamtutorial.Demo2
    export INPUT_SUBSCRIPTION=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_pubsublite.beam_tutorial.subscription_id")
    export OUTPUT_TABLE=$( echo $TF_INFRA_RESOURCE | jq -r ".infra.value.google_bigquery.tables.demo2.table_id")
    ;;
*)
    echo "unexpected topic: ${TOPIC}"
    exit 1
    ;;
esac

case $OP in
build)
    mvn compile exec:java -e \
            -Pdataflow-runner \
            -Dexec.mainClass=${MAIN_CLASS} \
            -Dexec.cleanupDaemonThreads=false \
            -Dexec.args="--project=${PROJECT_ID} \
                        --region=${REGION} \
                        --runner=DataflowRunner \
                        --streaming=true \
                        --usePublicIps=false \
                        --numWorkers=1 \
                        --maxNumWorkers=4 \
                        --network=${NETWORK} \
                        --subnetwork=${SUBNETWORK} \
                        --serviceAccount=${SERVICE_ACCOUNT_EMAIL} \
                        --tempLocation=gs://${DEPLOYMENT_BUCKET}/dataflow-etls/tmp/${TOPIC} \
                        --templateLocation=gs://${DEPLOYMENT_BUCKET}/dataflow-etls/template/${TOPIC} \
                        --inputSubscription=${INPUT_SUBSCRIPTION} \
                        --outputTable=${OUTPUT_TABLE}"
    exit 0
    ;;
run)
    gcloud dataflow jobs run ${TOPIC}  \
        --gcs-location=gs://${DEPLOYMENT_BUCKET}/dataflow-etls/template/${TOPIC} \
        --region=${REGION} \
        --enable-streaming-engine
    exit 0
    ;;
direct-run)
    mvn compile exec:java -e \
            -Pdirect-runner \
            -Dexec.mainClass=${MAIN_CLASS} \
            -Dexec.args="--inputSubscription=${INPUT_SUBSCRIPTION} \
                         --outputTable=${OUTPUT_TABLE}"
    exit 0
    ;;
*)
    echo "unexpected operation: ${OP}"
    exit 1
    ;;
esac