#!/bin/bash
cd ${SCRIPTS_HOME}
#Using JSON as parameter might lead to Argument list too long
#source ./bin/updateExtensions.sh
#echo $envId
source bin/queryEnvironment.sh env="$env" classification="*"
curl -s -X POST -u $authToken -H "${h1}" -H "${h2}" $baseURL/EnvironmentExtensions/${envId}/update -d@"${WORKSPACE}"/$extensionJson -vvv
