#!/bin/bash
source bin/common.sh

# get atom id of the by atom name
# mandatory arguments
ARGUMENTS=(env packageVersion notes listenerStatus)
OPT_ARGUMENTS=(componentId processName componentVersion extractComponentXmlFolder tag componentType)

inputs "$@"
if [ "$?" -gt "0" ]
then
        return 255;
fi



if [ ! -z "${extractComponentXmlFolder}" ]
then
 folder="${WORKSPACE}/${extractComponentXmlFolder}"
 rm -rf ${folder}
 unset extensionJson
 saveExtractComponentXmlFolder="${extractComponentXmlFolder}"
fi

saveNotes="${notes}";
saveTag="${tag}"


source bin/createSinglePackage.sh componentId=${componentId} processName="${processName}" componentType="${componentType}" componentVersion="${componentVersion}" packageVersion="$packageVersion" notes="$notes" extractComponentXmlFolder="${extractComponentXmlFolder}" 
handle_error "$?" "Failed to create package" || return 1
if [ -z "$packageId" ] || [ "$packageId" == "null" ]; then
    log_error "Package ID is empty after package creation"
    return 255
fi
notes="${saveNotes}";

source bin/queryEnvironment.sh env="$env" classification="*"
handle_error "$?" "Failed to query environment: $env" || return 1
if [ -z "$envId" ] || [ "$envId" == "null" ]; then
    log_error "Environment ID is empty for environment: $env"
    return 255
fi
saveEnvId=${envId}

source bin/createDeployedPackage.sh envId=${envId} listenerStatus="${listenerStatus}" packageId=$packageId notes="$notes"

handleXmlComponents "${saveExtractComponentXmlFolder}" "${saveTag}" "${saveNotes}"

if [ "$ERROR" -gt "0" ]
then
   return 255;
fi

export envId=${saveEnvId}

if [ ! -z "${extensionJson}" ]
then
   export extensionJson=$(echo "${extensionJson}" | jq --arg envId ${envId} '.environmentId=$envId' | jq --arg envId ${envId} '.id=$envId')
   printExtensions
fi

clean
