#!/bin/bash

set -x
source bin/common.sh
# get atom id of the by atom name
# mandatory arguments
ARGUMENTS=(env)
OPT_ARGUMENTS=(envId extensionJson)

inputs "$@"

if [ "$?" -gt "0" ]
then
        return 255;
fi

if [ ! -z "${envId}" ]
	then
		envId=${envId}
elif [ ! -z "${env}" ]
	then
		source bin/queryEnvironment.sh env=${env} type="*" classification="*"
else
		envId=$(echo "$extensionJson" | jq -r .environmentId)
fi

echov "The env id is ${envId}"

JSON_FILE="${WORKSPACE}"/envId.json

URL="${baseURL}EnvironmentExtensions/${envId}"

getAPI

cp "${WORKSPACE}"/out.json "${WORKSPACE}"/$extensionJson

if [ "$ERROR" -gt "0" ]
then
   return 255;
fi
set +x
