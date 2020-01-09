#!/bin/bash

verify_installed()
{
  local cmd="$1"
  if [[ $(type $cmd 2>&1) =~ "not found" ]]; then
    echo -e "\nERROR: This script requires '$cmd'. Please install '$cmd' and run again.\n"
    exit 1
  fi
}
verify_installed "jq"
verify_installed "docker-compose"

DOCKER_COMPOSE_FILE_OVERRIDE=$1
if [ -f "${DOCKER_COMPOSE_FILE_OVERRIDE}" ]
then
  docker-compose -f ../../environment/mdc-plaintext/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} down -v
  docker-compose -f ../../environment/mdc-plaintext/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} up -d
else
  docker-compose -f ../../environment/mdc-plaintext/docker-compose.yml down -v
  docker-compose -f ../../environment/mdc-plaintext/docker-compose.yml up -d
fi

shift
../../scripts/wait-for-connect-and-controlcenter.sh connect-us $@
../../scripts/wait-for-connect-and-controlcenter.sh connect-europe $@