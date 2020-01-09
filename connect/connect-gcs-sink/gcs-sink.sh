#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

verify_installed "gcloud"

BUCKET_NAME=${1:-test-gcs-playground}

KEYFILE="${DIR}/keyfile.json"
if [ ! -f ${KEYFILE} ]
then
     echo -e "\033[0;33mERROR: the file ${KEYFILE} file is not present!\033[0m"
     exit 1
fi

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"


echo -e "\033[0;33mRemoving existing objects in GCS, if applicable\033[0m"
set +e
gsutil rm -r gs://$BUCKET_NAME/topics/gcs_topic
set -e

echo -e "\033[0;33mSending messages to topic gcs_topic\033[0m"
seq -f "{\"f1\": \"value%g\"}" 10 | docker exec -i schema-registry kafka-avro-console-producer --broker-list broker:9092 --topic gcs_topic --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"f1","type":"string"}]}'


echo -e "\033[0;33mCreating GCS Sink connector\033[0m"
docker exec -e BUCKET_NAME="$BUCKET_NAME" connect \
     curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.connect.gcs.GcsSinkConnector",
                    "tasks.max" : "1",
                    "topics" : "gcs_topic",
                    "gcs.bucket.name" : "'"$BUCKET_NAME"'",
                    "gcs.part.size": "5242880",
                    "flush.size": "3",
                    "gcs.credentials.path": "/root/keyfiles/keyfile.json",
                    "storage.class": "io.confluent.connect.gcs.storage.GcsStorage",
                    "format.class": "io.confluent.connect.gcs.format.avro.AvroFormat",
                    "partitioner.class": "io.confluent.connect.storage.partitioner.DefaultPartitioner",
                    "schema.compatibility": "NONE",
                    "confluent.topic.bootstrap.servers": "broker:9092",
                    "confluent.topic.replication.factor": "1"
          }' \
     http://localhost:8083/connectors/gcs-sink/config | jq .

sleep 10

echo -e "\033[0;33mDoing gsutil authentication\033[0m"
gcloud auth activate-service-account --key-file ${KEYFILE}

echo -e "\033[0;33mListing objects of in GCS\033[0m"
gsutil ls gs://$BUCKET_NAME/topics/gcs_topic/partition=0/

echo -e "\033[0;33mGetting one of the avro files locally and displaying content with avro-tools\033[0m"
gsutil cp gs://$BUCKET_NAME/topics/gcs_topic/partition=0/gcs_topic+0+0000000000.avro /tmp/


docker run -v /tmp:/tmp actions/avro-tools tojson /tmp/gcs_topic+0+0000000000.avro
