#!/bin/bash
source bin/common.sh

# mandatory arguments
ARGUMENTS=(env packageVersion) 
OPT_ARGUMENTS=(componentIds listenerStatus notes componentType)
inputs "$@"
if [ "$?" -gt "0" ]
then
    return 255;
fi

# Query environment to get envId
source bin/queryEnvironment.sh env="${env}" classification="*"
if [ "$ERROR" -gt 0 ]; then
    return 255
fi

saveEnvId=${envId}
saveNotes="${notes}"
savePackageVersion="${packageVersion}"
saveListenerStatus="${listenerStatus}"
saveComponentType="${componentType}"

if [ -z "${componentIds}" ]; then
    echo "Error: componentIds is required for deployPackagesByVersion"
    return 255
fi

IFS=','
for componentId in `echo "${componentIds}" | tr ',' ' '`; do 
    componentId=`echo "${componentId}" | xargs`
    echo "Processing Component ID: ${componentId}"
    
    # Reset variables
    export packageId=""
    
    # Query Package ID by Version
    # Note: queryPackagedComponent.sh expects componentVersion (for internal version) or just packageVersion?
    # Based on view_file, it accepts packageVersion.
    source bin/queryPackagedComponent.sh componentId="${componentId}" packageVersion="${savePackageVersion}" componentType="${saveComponentType}"
    
    if [ "$ERROR" -gt 0 ] || [ -z "${packageId}" ]; then
        echo "Error: Could not find package for component ${componentId} with version ${savePackageVersion}"
        # We might want to continue or fail. Let's fail for now to be safe.
        return 255
    fi
    
    echo "Found Package ID: ${packageId}"
    
    # Deploy
    source bin/createDeployedPackage.sh envId="${saveEnvId}" packageId="${packageId}" listenerStatus="${saveListenerStatus}" notes="${saveNotes}"
    
    if [ "$ERROR" -gt 0 ]; then
        echo "Error: Failed to deploy component ${componentId}"
        return 255
    fi
    
done

clean
