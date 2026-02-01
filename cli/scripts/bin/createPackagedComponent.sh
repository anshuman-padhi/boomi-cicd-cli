#!/bin/bash
source bin/common.sh
# Query processattachment id before creating it
source bin/queryPackagedComponent.sh "$@"


# mandatory arguments
ARGUMENTS=(componentId componentType packageVersion notes createdDate) 
OPT_ARGUMENTS=(componentVersion branchName) 
createdDate=`date -u +"%Y-%m-%d"T%H:%M:%SZ`
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Creating packaged component: ${componentId} (version: ${packageVersion})"

URL="${baseURL}PackagedComponent"
id=packageId
exportVariable=packageId

if [ null == "${componentVersion}" ] && [ -z "${branchName}" ];
then
 JSON_FILE=json/createPackagedComponent.json
elif [ ! -z "${branchName}" ];
then
 # Use Platform API JSON structure but standard REST URL
 JSON_FILE=json/createPackagedComponentPlatform.json
else 
 ARGUMENTS=(componentId componentType componentVersion packageVersion notes createdDate) 
 JSON_FILE=json/createPackagedComponentVersion.json
fi

URL="${baseURL}PackagedComponent"

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

