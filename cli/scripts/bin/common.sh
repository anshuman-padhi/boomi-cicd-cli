#!/bin/bash
unset ARGUMENTS OPT_ARGUMENTS
# Capture user inputs
function inputs {
     for ARGUMENT in "$@"
     do
       KEY=$(echo $ARGUMENT | cut -f1 -d=)
       VALUE="$(echo $ARGUMENT | cut -f2 -d=)"
      	for i in "${ARGUMENTS[@]}"
      	do
					# remove all old values of the ARGUMENTS
        	case "$KEY" in
              $i)  unset ${KEY}; export eval $KEY="${VALUE}" ;;
              *)
        	esac
	      done
      	for i in "${OPT_ARGUMENTS[@]}"
      	do
					# remove all old values of the OPTIONAL ARGUMENTS
        	case "$KEY" in
              $i)  unset ${KEY}; export eval $KEY="${VALUE}" ;;
              *)
        	esac
    		done  
 
   			if [ $KEY = "help" ]
   				then
    	 			usage
     			return 255; 
   			fi
   done
 
   # Check inputs
   for i in "${ARGUMENTS[@]}"
   do
    if [ -z "${!i}" ]
    then
      echo "Missing mandatory field:  ${i}"
      usage
      return 255;
    fi
   done

	if [ "${VERBOSE}" == "true" ]
	then
		echo "Executing script: ${BASH_SOURCE[1]} with arguments"
		echo "----"
		printArgs
		echo "----"
	fi
  }
 
# The help function
# Check for required dependencies
function check_dependencies {
    local deps=("jq" "curl" "awk")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: Required dependency '$dep' is not installed."
            return 1
        fi
    done
    return 0
}

# Ensure SCRIPTS_HOME is set
function check_scripts_home {
    if [ -z "${SCRIPTS_HOME}" ]; then
        echo "Error: SCRIPTS_HOME environment variable is not set."
        echo "Please set it to the absolute path of the 'cli/scripts' directory."
        return 1
    fi
}

check_dependencies || exit 1
check_scripts_home || exit 1

function usage {
 echo "Usage: source bin/${BASH_SOURCE[1]} option1=value1 option2=value2 .."
}

function inputs {
  ARGUMENTS+=("VERBOSE" "SLEEP_TIMER" "h1" "h2" "baseURL" "authToken" "WORKSPACE" "SCRIPTS_HOME")
  
  for ARGUMENT in "$@"
  do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)   

    for ARG in "${ARGUMENTS[@]}"
    do 
        if [ "$KEY" == "$ARG" ]; then 
           export "$KEY"="$VALUE"
        fi  
    done    
    
    for ARG in "${OPT_ARGUMENTS[@]}"
    do 
        if [ "$KEY" == "$ARG" ]; then 
           export "$KEY"="$VALUE"
        fi  
    done    
  done

  # Validate mandatory arguments
  for ARG in "${ARGUMENTS[@]}"
  do 
    if [ -z "${!ARG}" ]; then 
        echo "${ARG} is mandatory."
        usage
        return 255;
    fi  
  done
  
  if [ "$VERBOSE" == "true" ]  
  then 
   printArgs
  fi
}

function clean { 
  for ARGUMENT in "$@"
  do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   for ARG in "${ARGUMENTS[@]}"
   do
     if [ "$KEY" == "$ARG" ]; then 
       unset "$KEY"
     fi  
    done
  done
}

function printArgs {
  echo "Arguments:"
  for ARG in "${ARGUMENTS[@]}"
  do 
   if [ "$ARG" == "authToken" ]; then
       echo "$ARG=********"
   else
       echo "$ARG=${!ARG}"
   fi
  done  
  for ARG in "${OPT_ARGUMENTS[@]}"
  do 
   echo "$ARG=${!ARG}"
  done  
}

# Secure logging helper
function log_secure {
    local message="$1"
    if [ "$VERBOSE" == "true" ]; then
        # simple mask for standard basic auth structure or bearer tokens in logs if they accidentally get printed
        # Note: robust masking is complex in shell; this is a best-effort Basic Auth mask.
        echo "$message" | sed 's/Authorization: Basic [a-zA-Z0-9+=/]*//g'
    fi
}

# Create JSON payload
function createJSON {
  local templateFile="${JSON_FILE}"  # Read from global JSON_FILE variable
  local outputFile="${WORKSPACE}/tmp.json"
  
  if [ -z "${templateFile}" ]; then
      echo "Error: JSON_FILE variable not set"
      return 1
  fi
  
  if [ ! -f "${SCRIPTS_HOME}/${templateFile}" ]; then
      echo "Error: JSON template '${templateFile}' not found in ${SCRIPTS_HOME}"
      return 1
  fi

  cp "${SCRIPTS_HOME}/${templateFile}" "$outputFile"
  
  # Substitute all variables from ARGUMENTS and OPT_ARGUMENTS arrays
  # JSON templates use ${variable} format, not %variable%
  for KEY in "${ARGUMENTS[@]}" "${OPT_ARGUMENTS[@]}"
  do
    # Use indirect variable expansion to get the value
    if [ ! -z "${!KEY}" ]; then
      VALUE="${!KEY}"
      local temp_sed="${outputFile}.tmp"
      # Match ${KEY} pattern in JSON templates
      sed "s~\${${KEY}}~${VALUE}~g" "$outputFile" > "$temp_sed" && mv "$temp_sed" "$outputFile"
    fi
  done
}

# Polling helper to replace hard sleeps
# Usage: poll_api_call "URL" "OUTPUT_FILE" "METHOD" "OPTS_JSON"
function poll_api_call {
    local url="$1"
    local output_file="$2"
    local method="$3"
    local data_file="$4"
    local max_retries=3
    local wait_time=1
    
    # If SLEEP_TIMER is set appropriately, we can just use that, but a polling loop is safer for network flakes
    # Here we stick to a simple retry mechanism for robustness.
    
    local attempt=1
    while [ $attempt -le $max_retries ]; do
        if [ "$method" == "POST" ]; then
             curl -s -X POST -u "$authToken" -H "${h1}" -H "${h2}" "$url" -d@"$data_file" > "$output_file"
        else
             curl -s -X GET -u "$authToken" -H "${h1}" -H "${h2}" "$url" > "$output_file"
        fi
        
        # Check standard curl exit code logic or empty file
        if [ -s "$output_file" ]; then
            return 0
        fi
        
        echo "Attempt $attempt failed. Retrying in $wait_time seconds..."
        sleep $wait_time
        attempt=$((attempt + 1))
        wait_time=$((wait_time * 2)) # Exponential backoff
    done
    
    echo "Error: API call failed after $max_retries attempts."
    return 1
}

function callAPI {
 unset ERROR ERROR_MESSAGE
 export ERROR=0
 export ERROR_MESSAGE=""
 
 createJSON "$@"
 
 # If queryToken is used, handle specifically (legacy logic support)
 # Assuming logic flows: if queryToken param is present, it uses that instead of tmp.json
 # But standard use seems to be tmp.json. 
 
 # Check if queryToken variable is set globally (legacy global var usage)
 if [ -z "${queryToken}" ]; then
   poll_api_call "$URL" "${WORKSPACE}/out.json" "POST" "${WORKSPACE}/tmp.json"
   local res=$?
   if [ $res -ne 0 ]; then return 255; fi
 else
   # Handling raw data string content in queryToken is tricky with file references
   echo "${queryToken}" > "${WORKSPACE}/query_token_tmp.dat"
   poll_api_call "$URL" "${WORKSPACE}/out.json" "POST" "${WORKSPACE}/query_token_tmp.dat"
 fi
 
 # Error Checking
 if [ -f "${WORKSPACE}/out.json" ]; then
     local is_error=$(jq -r . "${WORKSPACE}/out.json" | grep '"@type": "Error"' | wc -l)
     if [[ $is_error -gt 0 ]]; then 
          export ERROR_MESSAGE=`jq -r .message "${WORKSPACE}"/out.json` 
          echo "API Error: $ERROR_MESSAGE"
          return 251
     fi
 else
    echo "Error: No output received from API."
    return 255
 fi

 # Logging
 if [ "$VERBOSE" == "true" ]; then 
  cat  "${WORKSPACE}"/tmp.json >> "${WORKSPACE}/tmps.json" 2>/dev/null
  echo "ARA: Debug Output"
  jq '.' "${WORKSPACE}"/out.json
 fi
}

function getAPI {
  unset ERROR ERROR_MESSAGE
  export ERROR=0
  
  poll_api_call "$URL" "${WORKSPACE}/out.json" "GET"
  local res=$?
  if [ $res -ne 0 ]; then return 255; fi

  # Error Checking
  local is_error=$(jq -r . "${WORKSPACE}/out.json" | grep '"@type": "Error"' | wc -l)
  if [[ $is_error -gt 0 ]]; then 
      export ERROR_MESSAGE=`jq -r .message "${WORKSPACE}/out.json"` 
      echo "API Error: $ERROR_MESSAGE"
      return 251
  fi
  
  if [ "$VERBOSE" == "true" ]; then 
   cat  "${WORKSPACE}"/out.json >> "${WORKSPACE}"/outs.json
  fi
}

function getXMLAPI {
  unset ERROR ERROR_MESSAGE
  export ERROR=0
  export ERROR_MESSAGE=""
  
  # XML calls might need specific headers different from h1/h2 if hardcoded
  # The original used -H "application/xml" which seems to be the Accept header overwrite
  
  curl -s -X GET -u "$authToken" -H "Accept: application/xml" "$URL" > "${WORKSPACE}/out.xml"
  
  if [ "$VERBOSE" == "true" ]; then 
   cat  "${WORKSPACE}"/out.xml >> "${WORKSPACE}"/outs.xml
  fi
}

function extract {
    # $1 = json key, $2 = export variable name
    local val=$(jq -r .${1} "${WORKSPACE}"/out.json)
    export ${2}="$val"
    log_secure "export ${2}=${!2}."
}

function extractMap {
    mapfile -t ${2} < <(jq -r .result[].${1} "${WORKSPACE}/out.json")
}

function extractComponentMap {
    mapfile -t ${2} < <(jq -r .componentInfo[].${1} "${WORKSPACE}/out.json")
}

#Echo from other scripts
function echov {
  if [ "$VERBOSE" == "true" ]; then 
   echo -e "${BASH_SOURCE[1]}: ${1}"
  fi
}

#Echo from common.sh
function echovv {
  if [ "$VERBOSE" == "true" ]; then 
   echo -e "${BASH_SOURCE[2]}: ${1}"
  fi
}

function printReportHead {
  printf "<!DOCTYPE html>\n<html lang='en'>\n<head>\n"
  printf "<title>${REPORT_TITLE}</title>\n"
  printf "<style>\n"
  printf "table { font-family: arial, sans-serif; border-collapse: collapse; width: 100%%; }\n"
  printf "td, th { border: 1px solid #dddddd; text-align: left; padding: 8px; }\n"
  printf "tr:nth-child(even) { background-color: #dddddd; }\n"
  printf "</style>\n</head>\n<body>\n"
  printf "<h2>${REPORT_TITLE}</h2>\n"
  printf "<table>\n<caption><h3>List of ${REPORT_TITLE}</h3></caption>\n<tr>\n"  
  for i in "${REPORT_HEADERS[@]}"; do
        printf "<th scope='row'>${i}</th>\n"
  done   
  printf "</tr>\n\n"
}

function printReportTail {
  printf "\n\n</table>\n</body>\n</html>\n"
}

function printReportRow {
  local printFormat="%s\\n"
  local printText="<tr>"
  for FIELD in "$@"; do              
    printFormat="${printFormat}%s"
    printText="${printText} <th scope='row'>${FIELD}</th>"
  done    
  printFormat="${printFormat}%s"
  printText="${printText} </tr>"
  printf "${printFormat} ${printText}"
}

function handleXmlComponents {
    local extractComponentXmlFolder="$1"
    local tag="${2}"
    local notes="${3}"

    if [ -n "${extractComponentXmlFolder}" ]; then
        local folder="${WORKSPACE}/${extractComponentXmlFolder}"
        if [ -n "${tag}" ]; then
            # Assuming these scripts exist in bin/ and we are running from root or they are in path relative to CWD
            # Ideally use ${SCRIPTS_HOME}/bin/...
             if [ -f "${SCRIPTS_HOME}/bin/publishCodeReviewReport.sh" ]; then
                "${SCRIPTS_HOME}/bin/publishCodeReviewReport.sh" COMPONENT_LIST_FILE="${WORKSPACE}/${extractComponentXmlFolder}/${extractComponentXmlFolder}.list" GIT_COMMIT_ID="master" > "${WORKSPACE}/${extractComponentXmlFolder}_CodeReviewReport.html"
             fi
             if [ -f "${SCRIPTS_HOME}/bin/sonarScanner.sh" ]; then
                "${SCRIPTS_HOME}/bin/sonarScanner.sh" baseFolder="${folder}"
             fi
             if [ -f "${SCRIPTS_HOME}/bin/gitPush.sh" ]; then
                "${SCRIPTS_HOME}/bin/gitPush.sh" baseFolder="${folder}" tag="${tag}" notes="${notes}"
             fi
        fi
    fi 
}

function printExtensions {
    if [ ! -z "${extensionJson}" ]; then
        echo "${extensionJson}" > "${WORKSPACE}/${extractComponentXmlFolder}.json"
    fi
}

# Extension function to retrieve value
function getValueFrom {
   # Use indirect reference carefully
   if [ -n "${!1}" ]; then
       export extensionValue=${!1}
   else
       export extensionValue=""
   fi
}
