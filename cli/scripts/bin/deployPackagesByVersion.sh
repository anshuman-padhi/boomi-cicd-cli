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

for componentId in `echo "${componentIds}" | tr ',' ' '`; do 
    componentId=`echo "${componentId}" | xargs`
    if [ -z "${componentId}" ]; then
        continue
    fi
    unset packageId
    echo "Processing Component ID: ${componentId}"
    
    # Query Package ID by Version
    if [ -z "${saveComponentType}" ]; then
         echo "Component Type not provided. Querying metadata for ${componentId}..."
         source bin/queryComponentMetadata.sh componentId="${componentId}"
         if [ "$ERROR" -gt 0 ]; then
            echo "Error: Could not retrieve metadata for component ${componentId}"
            return 255
         fi
         # queryComponentMetadata exports componentType, componentId, componentName, etc.
         # capture it
         useComponentType="${componentType}"
         echo "Retrieved Component Type: ${useComponentType}"
    else
         useComponentType="${saveComponentType}"
    fi

    if [ -n "${useComponentType}" ]; then
        source bin/queryPackagedComponent.sh componentId="${componentId}" packageVersion="${savePackageVersion}" componentType="${useComponentType}"
    else
        # Fallback to version-only query if for some reason type is still missing
        source bin/queryPackagedComponent.sh componentId="${componentId}" packageVersion="${savePackageVersion}"
    fi
    
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
