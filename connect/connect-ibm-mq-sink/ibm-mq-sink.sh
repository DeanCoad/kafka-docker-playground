#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

if [ ! -f ${DIR}/jms.jar ]
then
     echo -e "\033[0;33mERROR: ${DIR}/jms.jar is missing. It must be downloaded manually in order to acknowledge user agreement\033[0m"
     exit 1
fi

if [ ! -f ${DIR}/com.ibm.mq.allclient.jar ]
then
     echo -e "\033[0;33mERROR: ${DIR}/com.ibm.mq.allclient.jar is missing. It must be downloaded manually in order to acknowledge user agreement\033[0m"
     exit 1
fi

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

echo -e "\033[0;33mSending messages to topic sink-messages\033[0m"
docker exec -i broker kafka-console-producer --broker-list broker:9092 --topic sink-messages << EOF
This is my message
EOF

echo -e "\033[0;33mCreating IBM MQ source connector\033[0m"
docker exec connect \
     curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.connect.jms.IbmMqSinkConnector",
                    "topics": "sink-messages",
                    "mq.hostname": "ibmmq",
                    "mq.port": "1414",
                    "mq.transport.type": "client",
                    "mq.queue.manager": "QM1",
                    "mq.channel": "DEV.APP.SVRCONN",
                    "mq.username": "app",
                    "mq.password": "passw0rd",
                    "jms.destination.name": "DEV.QUEUE.1",
                    "jms.destination.type": "queue",
                    "value.converter": "org.apache.kafka.connect.storage.StringConverter",
                    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
                    "confluent.license": "",
                    "confluent.topic.bootstrap.servers": "broker:9092",
                    "confluent.topic.replication.factor": "1"
          }' \
     http://localhost:8083/connectors/ibm-mq-sink/config | jq .

sleep 5

echo -e "\033[0;33mVerify message received in DEV.QUEUE.1 queue\033[0m"
docker exec ibmmq bash -c "/opt/mqm/samp/bin/amqsbcg DEV.QUEUE.1"

