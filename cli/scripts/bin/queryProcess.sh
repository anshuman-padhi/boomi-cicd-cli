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

# Try cache first
cache_key="${processName}"
cached_componentId=$(cache_get "COMPONENT_ID" "${cache_key}") || true

if [ -n "${cached_componentId}" ]; then
    export componentId="${cached_componentId}"
    export processId="${cached_componentId}"
    log_info "Using cached component ID: ${componentId}"
else
    # Cache miss - query API
    createJSON

    callAPI

    extract $id componentId

    clean
    handle_error "$ERROR" "Failed to query process: ${processName}" || return 1

    if [ -z "${componentId}" ] || [ "${componentId}" == "null" ]; then
        log_error "Process not found: ${processName}"
        return 1
    fi
    
    # Cache the result
    cache_set "COMPONENT_ID" "${cache_key}" "${componentId}"

    log_info "Found process: ${processName} (ID: ${componentId})"
fi
