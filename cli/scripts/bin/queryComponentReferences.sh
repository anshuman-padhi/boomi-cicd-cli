#!/bin/bash
#
# queryComponentReferences.sh — query the Boomi ComponentReference object for the
# components DIRECTLY referenced by a given parent component (one level).
#
# Boomi records reference edges per parent VERSION, so parentVersion must be supplied
# (read it from the component's exported XML / ComponentMetadata). The response is
# nested: result[].references[].componentId — those child ids are written, one per
# line, to ${WORKSPACE}/_refs_<componentId>.txt for the caller to consume.
#
# NOTE: reference edges are populated when a component is packaged/deployed, so this
# can legitimately return nothing for never-packaged components — getComponentTree.sh
# unions these results with XML GUID-scraping for full coverage.
#
# Usage: source bin/queryComponentReferences.sh componentId=<id> parentVersion=<n>
source bin/common.sh

unset parentVersion
ARGUMENTS=(componentId)
OPT_ARGUMENTS=(parentVersion)
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

: "${parentVersion:=}"

# Defense-in-depth: a Boomi componentId is a GUID (hex + dashes) and a version is an
# integer. Validate before building the query so sed metacharacters can never reach
# common.sh createJSON (which substitutes template values via unescaped sed).
case "$componentId" in
  "" | *[!0-9A-Fa-f-]*)
    log_error "queryComponentReferences: refusing non-GUID componentId '${componentId}'"
    return 255 ;;
esac
case "$parentVersion" in
  *[!0-9]*) parentVersion="" ;;   # keep only a clean integer (empty is harmless: API returns none)
esac

log_info "Querying ComponentReference for parent ${componentId} (version: ${parentVersion:-<unpinned>})"

JSON_FILE=json/queryComponentReference.json
export URL="${baseURL}ComponentReference/query"
createJSON
callAPI

local_refs="${WORKSPACE}/_refs_${componentId}.txt"
: > "$local_refs"
if [ -f "${WORKSPACE}/out.json" ]; then
  jq -r '[.result[]?.references[]?.componentId] | .[]?' "${WORKSPACE}/out.json" 2>/dev/null \
    | grep -E '.' | sort -u > "$local_refs"
fi
log_info "ComponentReference: $(grep -c . "$local_refs" 2>/dev/null || echo 0) direct reference(s) -> ${local_refs}"

clean

if [ "${ERROR:-0}" -gt "0" ]; then
  return 255
fi
