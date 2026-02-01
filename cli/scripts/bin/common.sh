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

###########################################
# Enhanced Error Handling & Logging
###########################################

# Logging utilities with standardized output
function log_info {
  local message="$1"
  echo "[INFO] $message"
}

function log_warn {
  local message="$1"
  echo "[WARN] $message" >&2
}

function log_error {
  local message="$1"
  echo "[ERROR] $message" >&2
}

# Enhanced error handler with descriptive messages
# Usage: handle_error $exit_code "Error message" || return 1
function handle_error {
  local exit_code="${1:-0}"
  local error_msg="${2:-Script failed}"
  
  if [ "$exit_code" -gt 0 ]; then
    log_error "$error_msg (exit code: $exit_code)"
    export ERROR=$exit_code
    export ERROR_MESSAGE="$error_msg"
    return $exit_code
  fi
  
  return 0
}

# Validate required variables are set
# Usage: validate_required_vars "VAR1" "VAR2" "VAR3" || return 1
function validate_required_vars {
  local missing_vars=()
  
  for var_name in "$@"; do
    if [ -z "${!var_name}" ]; then
      missing_vars+=("$var_name")
    fi
  done
  
  if [ ${#missing_vars[@]} -gt 0 ]; then
    log_error "Missing required variables: ${missing_vars[*]}"
    return 1
  fi
  
  return 0
}

# Retry mechanism for API calls (future enhancement)
# Usage: retry_command 3 5 "curl ..."
function retry_command {
  local max_attempts="${1:-3}"
  local wait_seconds="${2:-5}"
  shift 2
  local command="$@"
  
  local attempt=1
  while [ $attempt -le $max_attempts ]; do
    if eval "$command"; then
      return 0
    else
      local exit_code=$?
      if [ $attempt -lt $max_attempts ]; then
        log_warn "Command failed (attempt $attempt/$max_attempts), retrying in ${wait_seconds}s..."
        sleep $wait_seconds
      else
        log_error "Command failed after $max_attempts attempts"
        return $exit_code
      fi
    fi
    ((attempt++))
  done
}

###########################################
# Performance: Response Caching
###########################################

# Cache configuration
CACHE_ENABLED="${CACHE_ENABLED:-true}"
CACHE_TTL_SECONDS="${CACHE_TTL_SECONDS:-300}"  # 5 minutes default

# Initialize cache storage (associative arrays)
declare -gA BOOMI_CACHE_ENVIRONMENT_ID 2>/dev/null || true
declare -gA BOOMI_CACHE_ATOM_ID 2>/dev/null || true
declare -gA BOOMI_CACHE_COMPONENT_ID 2>/dev/null || true
declare -gA BOOMI_CACHE_TTL 2>/dev/null || true

# Get value from cache
# Usage: cached_value=$(cache_get "ENVIRONMENT_ID" "Production")
function cache_get {
  local cache_type="$1"
  local key="$2"
  
  if [ "${CACHE_ENABLED}" != "true" ]; then
    return 1
  fi
  
  local cache_var="BOOMI_CACHE_${cache_type}[${key}]"
  local ttl_var="BOOMI_CACHE_TTL[${cache_type}_${key}]"
  
  # Check if value exists in cache
  local cached_value="${!cache_var}"
  if [ -z "${cached_value}" ]; then
    [ "${VERBOSE}" == "true" ] && log_info "Cache MISS: ${cache_type}[${key}]"
    return 1
  fi
  
  # Check TTL
  local cached_time="${!ttl_var}"
  if [ -n "${cached_time}" ]; then
    local current_time=$(date +%s)
    local age=$((current_time - cached_time))
    
    if [ $age -ge ${CACHE_TTL_SECONDS} ]; then
      [ "${VERBOSE}" == "true" ] && log_info "Cache EXPIRED: ${cache_type}[${key}] (age: ${age}s)"
      return 1
    fi
    
    [ "${VERBOSE}" == "true" ] && log_info "Cache HIT: ${cache_type}[${key}] (age: ${age}s)"
  fi
  
  echo "${cached_value}"
  return 0
}

# Store value in cache
# Usage: cache_set "ENVIRONMENT_ID" "Production" "env-123-456"
function cache_set {
  local cache_type="$1"
  local key="$2"
  local value="$3"
  
  if [ "${CACHE_ENABLED}" != "true" ]; then
    return 0
  fi
  
  # Store value
  eval "BOOMI_CACHE_${cache_type}[${key}]='${value}'"
  
  # Store timestamp
  local current_time=$(date +%s)
  eval "BOOMI_CACHE_TTL[${cache_type}_${key}]=${current_time}"
  
  [ "${VERBOSE}" == "true" ] && log_info "Cache SET: ${cache_type}[${key}]"
  return 0
}

# Clear all caches
# Usage: cache_clear
function cache_clear {
  log_info "Clearing all caches"
  
  unset BOOMI_CACHE_ENVIRONMENT_ID
  unset BOOMI_CACHE_ATOM_ID
  unset BOOMI_CACHE_COMPONENT_ID
  unset BOOMI_CACHE_TTL
  
  declare -gA BOOMI_CACHE_ENVIRONMENT_ID
  declare -gA BOOMI_CACHE_ATOM_ID
  declare -gA BOOMI_CACHE_COMPONENT_ID
  declare -gA BOOMI_CACHE_TTL
  
  return 0
}

# Print cache statistics
# Usage: cache_stats
function cache_stats {
  echo "=== Cache Statistics ==="
  echo "Cache Enabled: ${CACHE_ENABLED}"
  echo "Cache TTL: ${CACHE_TTL_SECONDS}s"
  
  local env_count=0
  local atom_count=0
  local component_count=0
  
  # Count cached entries
  for key in "${!BOOMI_CACHE_ENVIRONMENT_ID[@]}"; do
    env_count=$((env_count + 1))
  done
  
  for key in "${!BOOMI_CACHE_ATOM_ID[@]}"; do
    atom_count=$((atom_count + 1))
  done
  
  for key in "${!BOOMI_CACHE_COMPONENT_ID[@]}"; do
    component_count=$((component_count + 1))
  done
  
  echo "Cached Environments: ${env_count}"
  echo "Cached Atoms: ${atom_count}"
  echo "Cached Components: ${component_count}"
  echo "======================="
}


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
  
  # Ensure workspace exists if valid
  if [ ! -z "${WORKSPACE}" ]; then
    mkdir -p "${WORKSPACE}"
  fi
  
  # Standardize baseURL to have trailing slash
  if [ ! -z "${baseURL}" ] && [[ "${baseURL}" != */ ]]; then
      baseURL="${baseURL}/"
  fi
  
  # Extract accountId from baseURL
  if [ ! -z "${baseURL}" ]; then
      # Remove trailing slash for processing
      local temp_url="${baseURL%/}"
      export accountId=$(basename "${temp_url}")
  fi
  
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
             if [ "$VERBOSE" == "true" ]; then
                 echo "DEBUG CURL: curl -v -X POST -u \"HIDDEN\" -H \"${h1}\" -H \"${h2}\" \"$url\" -d@\"$data_file\""
                 curl -v -X POST -u "$authToken" -H "${h1}" -H "${h2}" "$url" -d@"$data_file" > "$output_file"
             else
                 curl -s -X POST -u "$authToken" -H "${h1}" -H "${h2}" "$url" -d@"$data_file" > "$output_file"
             fi
        else
             if [ "$VERBOSE" == "true" ]; then
                curl -v -X GET -u "$authToken" -H "${h1}" -H "${h2}" "$url" > "$output_file"
             else
                curl -s -X GET -u "$authToken" -H "${h1}" -H "${h2}" "$url" > "$output_file"
             fi
        fi
        
        curl_exit_code=$?
        
        # Check standard curl exit code logic or empty file
        # If success (exit code 0) and (file has content OR empty response allowed)
        if [ "$curl_exit_code" -eq 0 ]; then
            if [ -s "$output_file" ] || [ "$ALLOW_EMPTY_RESPONSE" == "true" ]; then
                return 0
            fi
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
     # Check for valid JSON before parsing
     if ! jq . "${WORKSPACE}/out.json" > /dev/null 2>&1; then
        echo "Error: Failed to parse API response as JSON."
        echo "Raw Response:"
        cat "${WORKSPACE}/out.json"
        return 255
     fi

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
 
 if [ ! -z "${exportVariable}" ] && [ ! -z "${id}" ]; then
    extract "${id}" "${exportVariable}"
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
  if [ -f "${WORKSPACE}/out.json" ]; then
       # Check for valid JSON before parsing
       if ! jq . "${WORKSPACE}/out.json" > /dev/null 2>&1; then
          echo "Error: Failed to parse API response as JSON."
          echo "Raw Response:"
          cat "${WORKSPACE}/out.json"
          return 255
       fi
  
       local is_error=$(jq -r . "${WORKSPACE}/out.json" | grep '"@type": "Error"' | wc -l)
       if [[ $is_error -gt 0 ]]; then 
           export ERROR_MESSAGE=`jq -r .message "${WORKSPACE}/out.json"` 
           echo "API Error: $ERROR_MESSAGE"
           return 251
       fi
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
