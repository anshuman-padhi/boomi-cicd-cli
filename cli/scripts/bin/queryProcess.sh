#!/bin/bash
source bin/common.sh
# get atom id of the by atom name
# mandatory arguments
ARGUMENTS=(processName)
JSON_FILE=json/queryProcess.json
URL=$baseURL/Process/query
id=result[0].id
exportVariable=processId

inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Querying process: ${processName}"

createJSON

callAPI

extract $id componentId

clean
handle_error "$ERROR" "Failed to query process: ${processName}" || return 1

if [ -z "${componentId}" ] || [ "${componentId}" == "null" ]; then
    log_error "Process not found: ${processName}"
    return 1
fi

log_info "Found process: ${processName} (ID: ${componentId})"
