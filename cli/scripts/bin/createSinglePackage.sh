#!/bin/bash
source bin/common.sh

# mandatory arguments
ARGUMENTS=(packageVersion notes) 
OPT_ARGUMENTS=(componentId processName extractComponentXmlFolder componentVersion componentType branchName)
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1
folder="${WORKSPACE}/${extractComponentXmlFolder}"
saveNotes="${notes}"
savePackageVersion="${packageVersion}"
saveComponentType="${componentType}"
if [ -z "${componentId}" ] || [ null == "${componentId}" ]
then
		notes="${saveNotes}"
    packageVersion="${savePackageVersion}"
    processName=`echo "${processName}" | xargs`
    saveProcessName="${processName}"
    componentType="${saveComponentType}"
    componentId=""
		source bin/queryComponentMetadata.sh componentName="${processName}" componentType="${componentType}" componentId="${componentId}"	currentVersion="" deleted=""
		handle_error "$?" "Failed to query component metadata for: ${processName}" || return 1
		if [ -z "$componentId" ] || [ "$componentId" == "null" ]; then
		    log_error "Component ID is empty for process: ${processName}"
		    return 255
		fi
		saveComponentName="${componentName}"
    saveComponentId="${componentId}"
    saveComponentVersion="${componentVersion}"
		source bin/createPackagedComponent.sh componentId=${componentId} componentType="${componentType}" packageVersion="${packageVersion}" notes="${notes}" componentVersion="${componentVersion}" branchName="${branchName}"
		handle_error "$?" "Failed to create packaged component for: ${componentId}" || return 1
		if [ -z "$packageId" ] || [ "$packageId" == "null" ]; then
		    log_error "Package ID is empty after creating package"
		    return 255
		fi
		echov "Created package ${packageId} for process ${saveProcessName}"
else    
		notes="${saveNotes}"
    packageVersion="${savePackageVersion}"
    componentId=`echo "${componentId}" | xargs`
    saveComponentId="${componentId}"
    componentType="${saveComponentType}"
		processName=""
		source bin/queryComponentMetadata.sh componentName="${processName}" componentType="${componentType}" componentId="${componentId}" currentVersion="" deleted=""
		handle_error "$?" "Failed to query component metadata for ID: ${componentId}" || return 1
		saveComponentName="${componentName}"
    saveComponentVersion="${componentVersion}"
		source bin/createPackagedComponent.sh componentId=${componentId} componentType="${componentType}" packageVersion="${packageVersion}" notes="${notes}" componentVersion="${componentVersion}" branchName="${branchName}"
		handle_error "$?" "Failed to create packaged component for: ${componentId}" || return 1
		if [ -z "$packageId" ] || [ "$packageId" == "null" ]; then
		    log_error "Package ID is empty after creating package"
		    return 255
		fi
		echov "Created package ${packageId} for componentId ${saveComponentId}"
fi  

savePackageId=${packageId}

# Extract Boomi componentXMLs to a local disk
if [ ! -z "${extractComponentXmlFolder}" ] && [ null != "${extractComponentXmlFolder}" ] && [ "" != "${extractComponentXmlFolder}" ]
then
  folder="${WORKSPACE}/${extractComponentXmlFolder}"
	packageFolder="${folder}/${saveComponentId}"
	mkdir -p "${packageFolder}"
	
  # save the list of component details for a codereview report to be published at the end
	printf "%s%s%s\n" "${saveComponentId}|" "${saveComponentName}|" "${saveComponentVersion}" >> "${WORKSPACE}/${extractComponentXmlFolder}/${extractComponentXmlFolder}.list"
	echov "Publishing package metatdata for ${packageId}."
	source bin/publishPackagedComponentMetadata.sh packageIds="${packageId}" > "${packageFolder}/Manifest_${saveComponentId}.html"

  g=0
	for g in ${!componentIds[@]}; 
	do
		componentId=${componentIds[$g]}
		componentVersion=${componentVersions[$g]}
		source bin/getComponent.sh componentId=${componentId} version=${componentVersion} 
    eval `cat "${WORKSPACE}"/${componentIds[$g]}.xml | xmllint --xpath '//*/@folderFullPath' -`
    mkdir -p "${packageFolder}/${folderFullPath}"
		type=$(cat "${WORKSPACE}"/${componentIds[$g]}.xml | xmllint --xpath 'string(//*/@type)' -)
		
		# create extension file for this process
		if [ $type == "process" ] 
		then
			componentFile="${WORKSPACE}"/${componentIds[$g]}.xml
			source bin/createExtensionsJson.sh componentFile="${componentFile}"
		fi
 
    mv "${WORKSPACE}"/${componentIds[$g]}.xml "${packageFolder}/${folderFullPath}" 
 done
  
# Create a violations report using sonarqube rules	
#bin/xpathRulesChecker.sh baseFolder="${packageFolder}" > "${packageFolder}/ViolationsReport_${saveComponentId}.html"

fi

clean

unset folder packageFolder
export packageId=${savePackageId}


handle_error "$ERROR" "Package creation failed for component" || return 1
