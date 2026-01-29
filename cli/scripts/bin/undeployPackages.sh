#!/bin/bash
source bin/common.sh

# mandatory arguments
ARGUMENTS=(env) 
OPT_ARGUMENTS=(componentIds processNames)
inputs "$@"
if [ "$?" -gt "0" ]
then
    return 255;
fi

saveEnv="${env}"

# Get Environment ID
source bin/queryEnvironment.sh env="$env" classification="*"
saveEnvId=${envId}

if [ -z "${componentIds}" ]
then
	IFS=',' ;for processName in `echo "${processNames}"`; 
	do 
    processName=`echo "${processName}" | xargs`
    
    # Query Component ID for the process name
    componentId=""
    source bin/queryComponentMetadata.sh componentName="${processName}" componentType="process" componentId="${componentId}" currentVersion="" deleted=""
    
    if [ ! -z "${componentId}" ]; then
       echov "Undeploying process $processName ($componentId)"
       source bin/undeployPackage.sh componentId=${componentId} envId=${saveEnvId}
    else
       echo "Detailed component ID not found for process $processName"
    fi
 	done   
else    
	IFS=',' ;for componentId in `echo "${componentIds}"`; 
	do 
    componentId=`echo "${componentId}" | xargs`
    echov "Undeploying component $componentId"
    source bin/undeployPackage.sh componentId=${componentId} envId=${saveEnvId}
 	done   
fi  

clean

if [ "$ERROR" -gt 0 ]
then
   return 255;
fi
