#!/bin/bash

source bin/common.sh
# get atom id of the by atom name
# mandatory arguments
ARGUMENTS=(env classification)
URL="${baseURL}Environment/query"
id=result[0].id
exportVariable=envId

inputs "$@" 
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Querying environment: ${env} (classification: ${classification})"

# Try cache first
cache_key="${env}_${classification}"
cached_envId=$(cache_get "ENVIRONMENT_ID" "${cache_key}") || true

if [ -n "${cached_envId}" ]; then
    export envId="${cached_envId}"
    export environmentId="${cached_envId}"
    log_info "Using cached environment ID: ${envId}"
else
    # Cache miss - query API
    if [ "${env}" = "*" ]; then
      env="%"
    fi

    if [ "${classification}" = "*" ]
    then
     JSON_FILE=json/queryEnvironmentAnyClassification.json
    else
     JSON_FILE=json/queryEnvironment.json
    fi

    createJSON

    callAPI
    handle_error "$ERROR" "Failed to query environment: ${env}" || return 1

    if [ -z "${envId}" ]; then
        log_error "Environment not found: ${env}"
        return 1
    fi
    
    # Cache the result
    cache_set "ENVIRONMENT_ID" "${cache_key}" "${envId}"

    log_info "Found environment: ${env} (ID: ${envId})"
fi
