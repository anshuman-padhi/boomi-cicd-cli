#!/bin/bash

source bin/common.sh
# get atom id of the by atom name
# mandatory arguments
ARGUMENTS=(componentId packageVersion)
OPT_ARGUMENTS=(componentType componentVersion)
URL="${baseURL}PackagedComponent/query"
id=result[0].packageId
exportVariable=packageId

inputs "$@"
if [ "$?" -gt "0" ]
then
        return 255;
fi

if [ -n "${componentVersion}" ]; then
    JSON_FILE=json/queryPackagedComponentComponentVersion.json
elif [ -n "${componentType}" ]; then
    JSON_FILE=json/queryPackagedComponent.json
else
    JSON_FILE=json/queryPackagedComponentByVersion.json
fi
createJSON
 
callAPI
 
clean
if [ "$ERROR" -gt 0 ]
then
   return 255;
fi
