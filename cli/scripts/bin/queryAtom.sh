#!/bin/bash

source bin/common.sh
# get atom id of the by atom name
# mandatory arguments
ARGUMENTS=(atomName atomType atomStatus)
JSON_FILE=json/queryAtom.json
URL="${baseURL}Atom/query"
id=result[0].id
exportVariable=atomId

inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Querying atom: ${atomName} (type: ${atomType}, status: ${atomStatus})"

# Try cache first
cache_key="${atomName}_${atomType}_${atomStatus}"
cached_atomId=$(cache_get "ATOM_ID" "${cache_key}")

if [ -n "${cached_atomId}" ]; then
    export atomId="${cached_atomId}"
    log_info "Using cached atom ID: ${atomId}"
else
    # Cache miss - query API
    if [ "$atomType" = "*" ] || [ "$atomStatus" = "*" ]
    then
            JSON_FILE=json/queryAtomAny.json
    fi
    createJSON
     
    callAPI
     
    clean
    handle_error "$ERROR" "Failed to query atom: ${atomName}" || return 1

    if [ -z "${atomId}" ] || [ "${atomId}" == "null" ]; then
        log_error "Atom not found: ${atomName}"
        return 1
    fi
    
    # Cache the result
    cache_set "ATOM_ID" "${cache_key}" "${atomId}"

    log_info "Found atom: ${atomName} (ID: ${atomId})"
fi
