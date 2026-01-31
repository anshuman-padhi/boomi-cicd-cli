#!/bin/bash
source bin/common.sh
# Query processattachment id before creating it
source bin/queryPackagedComponent.sh "$@"


# mandatory arguments
ARGUMENTS=(componentId componentType packageVersion notes createdDate) 
OPT_ARGUMENTS=(componentVersion branchName) 
createdDate=`date -u +"%Y-%m-%d"T%H:%M:%SZ`
inputs "$@"
if [ "$?" -gt "0" ]
then
        return 255;
fi

URL="${baseURL}PackagedComponent"
id=packageId
exportVariable=packageId

if [ null == "${componentVersion}" ] && [ -z "${branchName}" ];
then
 JSON_FILE=json/createPackagedComponent.json
 URL="${baseURL}PackagedComponent"
elif [ ! -z "${branchName}" ];
then
 # Use Platform API if branchName is present
 JSON_FILE=json/createPackagedComponentPlatform.json
 URL="https://api.boomi.com/api/platform/v1/$accountId/packagedComponent"
else 
 ARGUMENTS=(componentId componentType componentVersion packageVersion notes createdDate) 
 JSON_FILE=json/createPackagedComponentVersion.json
 URL="${baseURL}PackagedComponent"
fi

createJSON
if [ "$packageId" == "null" ] || [ -z "$packageId" ] || [ null == "${packageId}" ]
then 
	callAPI	
fi

clean
if [ "$ERROR" -gt 0 ]
then
   return 255;
fi

