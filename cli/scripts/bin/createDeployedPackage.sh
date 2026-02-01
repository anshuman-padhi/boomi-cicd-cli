#!/bin/bash

source bin/common.sh 
# Query processattachment id before creating it
# Query processattachment id before creating it
echo "$@"
unset deploymentId
source bin/queryDeployedPackage.sh "$@"
handle_error "$?" "Failed to query deployed package" || return 1


# mandatory arguments
ARGUMENTS=(envId packageId notes listenerStatus)
JSON_FILE=json/createDeployedPackage.json
URL="${baseURL}DeployedPackage"
id=deploymentId
exportVariable=deploymentId
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Deploying package ${packageId} to environment ${envId}"
createJSON
 
if [ "$deploymentId" == "null" ] || [ -z "$deploymentId" ]
then 
	callAPI
else
	#ARA
	echo "Redeploying..."
	callAPI
fi

clean
handle_error "$ERROR" "Failed to deploy package ${packageId}" || return 1

log_info "Successfully deployed package: ${packageId}"
