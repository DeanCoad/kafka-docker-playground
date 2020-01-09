#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"


echo -e "\033[0;33mSending messages to topic orders\033[0m"
docker exec -i schema-registry kafka-avro-console-producer --broker-list broker:9092 --topic orders --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"id","type":"int"},{"name":"product", "type": "string"}, {"name":"quantity", "type": "int"}, {"name":"price",
 "type": "float"}]}' << EOF
{"id": 999, "product": "foo", "quantity": 100, "price": 50}
EOF


echo -e "\033[0;33mCreating OmniSci sink connector\033[0m"
docker exec connect \
     curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.connect.omnisci.OmnisciSinkConnector",
                    "tasks.max" : "1",
                    "topics": "orders",
                    "connection.database": "omnisci",
                    "connection.port": "6274",
                    "connection.host": "omnisci",
                    "connection.user": "admin",
                    "connection.password": "HyperInteractive",
                    "confluent.topic.bootstrap.servers": "broker:9092",
                    "confluent.topic.replication.factor": "1",
                    "auto.create": "true"
          }' \
     http://localhost:8083/connectors/omnisci-sink/config | jq .

sleep 10

echo -e "\033[0;33mVerify data is in OmniSci\033[0m"
docker exec -i omnisci /omnisci/bin/omnisql -p HyperInteractive << EOF
select * from orders;
EOF
