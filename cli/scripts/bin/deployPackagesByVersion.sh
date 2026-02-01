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

# Use IFS for robust comma separation
IFS=',' read -r -a componentIdArray <<< "${componentIds}"

for componentId in "${componentIdArray[@]}"; do
    # Trim whitespace
    componentId=$(echo "${componentId}" | xargs)
    
    if [ -z "${componentId}" ]; then
        continue
    fi
    unset packageId
    echo "================================================================================"
    echo "DEBUG: Starting Processing for Component ID: '${componentId}'"
    echo "================================================================================"
    
    # Query Package ID by Version
    if [ -z "${saveComponentType}" ]; then
         echo "DEBUG: Component Type not provided. Querying metadata..."
         source bin/queryComponentMetadata.sh componentId="${componentId}"
         if [ "$ERROR" -gt 0 ]; then
            echo "Error: Could not retrieve metadata for component ${componentId}"
            # Ensure we fail the pipeline if metadata lookup fails
            return 255
         fi
         # queryComponentMetadata exports componentType, componentId, componentName, etc.
         # capture it
         useComponentType="${componentType}"
         echo "DEBUG: Retrieved Component Type: ${useComponentType}"
    else
         useComponentType="${saveComponentType}"
    fi

    if [ -n "${useComponentType}" ]; then
        echo "DEBUG: Querying Packaged Component with Type: ${useComponentType}"
        source bin/queryPackagedComponent.sh componentId="${componentId}" packageVersion="${savePackageVersion}" componentType="${useComponentType}"
    else
        echo "DEBUG: Querying Packaged Component without Type (Fallback)"
        # Fallback to version-only query if for some reason type is still missing
        source bin/queryPackagedComponent.sh componentId="${componentId}" packageVersion="${savePackageVersion}"
    fi
    
    if [ "$ERROR" -gt 0 ] || [ -z "${packageId}" ]; then
        echo "Error: Could not find package for component ${componentId} with version ${savePackageVersion}"
        return 255
    fi
    
    echo "DEBUG: Found Package ID: ${packageId}"
    
    # Deploy
    echo "DEBUG: Creating Deployed Package..."
    source bin/createDeployedPackage.sh envId="${saveEnvId}" packageId="${packageId}" listenerStatus="${saveListenerStatus}" notes="${saveNotes}"
    
    if [ "$ERROR" -gt 0 ]; then
        echo "Error: Failed to deploy component ${componentId}"
        return 255
    fi
    
    echo "DEBUG: Successfully deployed component ${componentId}"
done

clean
