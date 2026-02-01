#!/bin/bash
source bin/common.sh

# mandatory arguments
ARGUMENTS=(componentId envId processId current)
JSON_FILE=json/queryDeployment.json
URL=${baseURL}Deployment/query
id=result[0].id
exportVariable=deploymentId
# Set defaults for queryDeployment
current=true
version=""
processId=$componentId

inputs "$@"
if [ "$?" -gt "0" ]
then
    return 255;
fi

# 1. Query existing deployment
createJSON
callAPI

if [ ! -z "$deploymentId" ] && [ "$deploymentId" != "null" ]
then
  echov "Found deploymentId: $deploymentId"
  
  # 2. Delete deployment (Undeploy)
  URL=${baseURL}DeployedPackage/$deploymentId
  
  if [ ! -z ${SLEEP_TIMER} ]; then sleep ${SLEEP_TIMER}; fi
  
  # API Delete
  curl -s -X DELETE -u $authToken -H "${h1}" -H "${h2}" "$URL" > "${WORKSPACE}"/out_delete.json
  
  # Check for errors
  # Successful delete usually returns empty body or 200 OK. 
  # Check if output contains Error
  export ERROR=`jq -r . "${WORKSPACE}"/out_delete.json | grep '"@type": "Error"' | wc -l`
  if [[ $ERROR -gt 0 ]]; then 
	   export ERROR_MESSAGE=`jq -r .message "${WORKSPACE}"/out_delete.json` 
		 echo "Error undeploying: $ERROR_MESSAGE" 
	   return 251
  else
     echo "Successfully undeployed component $componentId from env $envId"
  fi

else
  echo "No active deployment found for component $componentId in env $envId - nothing to undeploy."
fi

clean
if [ "$ERROR" -gt "0" ]
then
   return 255;
fi
