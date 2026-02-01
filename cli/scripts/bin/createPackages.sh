#!/bin/bash
source bin/common.sh

# mandatory arguments
ARGUMENTS=(packageVersion notes) 
OPT_ARGUMENTS=(componentIds processNames extractComponentXmlFolder tag componentType branchName)
inputs "$@"

# Use new error handler
handle_error "$?" "Failed to process input arguments" || return 1

if [ ! -z "${extractComponentXmlFolder}" ]
then
 folder="${WORKSPACE}/${extractComponentXmlFolder}"
 rm -rf ${folder}
 unset extensionJson
 saveExtractComponentXmlFolder="${extractComponentXmlFolder}"
fi

saveNotes="${notes}"
savePackageVersion="${packageVersion}"
saveComponentType="${componentType}"

packageIds=""
saveTag="${tag}"
unset tag
if [ -z "${componentIds}" ]
then
	IFS=',' ;for processName in `echo "${processNames}"`; 
	do 
		notes="${saveNotes}"
    packageVersion="${savePackageVersion}"
    processName=`echo "${processName}" | xargs`
    saveProcessName="${processName}"
		componentType="${saveComponentType}"
		source bin/createSinglePackage.sh processName="${processName}" componentType="${componentType}" packageVersion="${packageVersion}" notes="${notes}" extractComponentXmlFolder="${extractComponentXmlFolder}"  componentVersion="" branchName="${branchName}"
 	done   
else    
	IFS=',' ;for componentId in `echo "${componentIds}"`; 
	do 
		notes="${saveNotes}"
   	packageVersion="${savePackageVersion}"
    componentId=`echo "${componentId}" | xargs`
    if [ -z "${componentId}" ]; then
        continue
    fi
    saveComponentId="${componentId}"
    componentType="${saveComponentType}"
    source bin/createSinglePackage.sh componentId=${componentId} componentType="${componentType}" packageVersion="${packageVersion}" notes="${notes}" extractComponentXmlFolder="${extractComponentXmlFolder}"  componentVersion="" branchName="${branchName}"
 	done   
fi  



# Tag all the packages of the release together
handleXmlComponents "${saveExtractComponentXmlFolder}" "${saveTag}" "${saveNotes}"

clean

# Use new errorhandler
handle_error "$ERROR" "Package creation failed" || return 1

printExtensions
