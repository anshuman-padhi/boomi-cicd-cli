#!/bin/bash
cd ${SCRIPTS_HOME}
source ./bin/queryEnvironment.sh env="$env" classification="*"
unset env
echo $envId
source ./bin/retrieveExtensions.sh
echo $envId
