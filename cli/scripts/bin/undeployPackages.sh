#!/bin/bash
source bin/common.sh

# mandatory arguments
ARGUMENTS=(env) 
OPT_ARGUMENTS=(componentIds processNames)
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Starting package undeployment from environment: ${env}"

saveEnv="${env}"

# Get Environment ID
log_info "Querying environment: ${env}"
source bin/queryEnvironment.sh env="$env" classification="*"
handle_error "$ERROR" "Failed to query environment: ${env}" || return 1

saveEnvId=${envId}
log_info "Environment ID: ${envId}"

if [ -z "${componentIds}" ]
then
	IFS=',' ;for processName in `echo "${processNames}"`; 
	do 
    processName=`echo "${processName}" | xargs`
    
    # Query Component ID for the process name
    componentId=""
    source bin/queryComponentMetadata.sh componentName="${processName}" componentType="process" componentId="${componentId}" currentVersion="" deleted=""
    handle_error "$?" "Failed to query component metadata for: ${processName}" || return 1
    
    if [ ! -z "${componentId}" ]; then
       log_info "Undeploying process: ${processName} (${componentId})"
       source bin/undeployPackage.sh componentId=${componentId} envId=${saveEnvId}
    else
       log_warn "Component ID not found for process: ${processName}"
    fi
 	done   
else    
	IFS=',' ;for componentId in `echo "${componentIds}"`; 
	do 
    componentId=`echo "${componentId}" | xargs`
    log_info "Undeploying component: ${componentId}"
    source bin/undeployPackage.sh componentId=${componentId} envId=${saveEnvId}
 	done   
fi  

clean

handle_error "$ERROR" "Package undeployment failed" || return 1

log_info "Successfully undeployed packages from ${env}"
