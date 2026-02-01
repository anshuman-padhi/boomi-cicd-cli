#!/bin/bash
# executeProcess (asyncronously) by passing the processId and atomId
# Usage : executeProcess.sh <atomId> <processId>
source bin/common.sh
#execute Process by atomId and processId
ARGUMENTS=(atomName atomType)
OPT_ARGUMENTS=(componentId processName processProperties)

inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Executing process on atom: ${atomName} (${atomType})"

source bin/queryAtom.sh atomName="$atomName" atomStatus=online atomType=$atomType

if [ -z "${componentId}" ]
then
	source bin/queryProcess.sh processName="$processName"
fi
processId=${componentId}

if [ -z "${processProperties}" ] || [ "${processProperties}" == "[]" ]; then
    ARGUMENTS=(atomId processId)
    JSON_FILE=json/executeProcessSimple.json
else
    ARGUMENTS=(atomId processId processProperties)
    JSON_FILE=json/executeProcess.json
fi
URL="${baseURL}executeProcess"
 
export ALLOW_EMPTY_RESPONSE=true 
createJSON

log_info "Executing process ${processId} on atom ${atomId}"
callAPI
handle_error "$ERROR" "Failed to execute process ${processId}" || return 1

clean
log_info "Successfully triggered process execution"
