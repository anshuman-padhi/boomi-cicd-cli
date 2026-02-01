#!/bin/bash
cd ${SCRIPTS_HOME}
export atomNameBackup=${atomName}
export i=1
export totaltime=0

function getDate {
  echo `date '+%Y-%m-%dT%H:%M:%S.000Z'`
}

function getTimestamp {
  echo `date +%s`
}

function initTestSuites {
  echo "  <!--Init-->" > ${validate_processes_results_tmp}
}

function addTestSuite {
  export testName=$1
  export testId=$1
  export success=$2
  export time=$3
  if [ "$success" == "true" ]
    then
      export failures=0
      export errors=0
    else
      export failures=1
      export errors=1
  fi
  echo "  <testsuite name=\"${testName}\" id=\"${testId}\" timestamp=\"$(getDate)\" tests=\"1\" failures=\"${failures}\" errors=\"${errors}\" time=\"${time}.000\">" >> ${validate_processes_results_tmp}
  echo "    <testcase name=\"Boomi Scheduled Processes ${testId}\" time=\"${time}.000\" classname=\"BoomiCicdValidateProcesses\"/>" >> ${validate_processes_results_tmp}
  echo "  </testsuite>" >> ${validate_processes_results_tmp}
}

function createTestSuites {
  export totaltests=$1
  export totaltime=$2
  echo "<testsuites name=\"Boomi CICD - Scheduled Process\" tests=\"${totaltests}\" time=\"${totaltime}.000\">" > ${validate_processes_results}
  cat ${validate_processes_results_tmp} >> ${validate_processes_results}
  echo "</testsuites>" >> ${validate_processes_results}
}

export validate_processes_results_folder=${artifactstagingdirectory}/results
export validate_processes_results_tmp=${validate_processes_results_folder}/boomi.xml.tmp
export validate_processes_results=${validate_processes_results_folder}/boomi.xml
mkdir -p ${validate_processes_results_folder}

initTestSuites

for componentId in $(echo $componentIds | sed "s/,/ /g")
do
    export atomName=${atomNameBackup}
    export timestart=$(getTimestamp)
    
    # Retry logic: Poll for execution record up to 5 times with 10 second intervals
    max_retries=5
    retry_wait=10
    found_execution=false
    
    for attempt in $(seq 1 $max_retries); do
        echo "[Attempt $attempt/$max_retries] Querying execution record for ${componentId}..."
        source bin/queryExecutionRecord.sh processId=${componentId}
        
        # Check if we got a valid execution record
        if [ "$executionId" != "null" ] && [ ! -z "$executionId" ]; then
            echo "[SUCCESS] Found execution record: ${executionId}"
            found_execution=true
            break
        else
            if [ $attempt -lt $max_retries ]; then
                echo "[WAITING] No execution record found yet, waiting ${retry_wait}s before retry..."
                sleep $retry_wait
            else
                echo "[FAILED] No execution record found after $max_retries attempts"
            fi
        fi
    done
    
    checkStatus=`echo "${checkStatus,,}"`
    if [ "$checkStatus" == "true" ]
    then
      export timestop=$(getTimestamp)
      export time=`expr ${timestop} - ${timestart}`
      export totaltime=`expr ${totaltime} + ${time}`
    	if [ "$status" != "COMPLETE" ]
        then
          echo "Error: Process status is '${status}', expected 'COMPLETE'"
          addTestSuite ${componentId} false ${time}
        	exit 255
        else
          echo 'Success'
          addTestSuite ${componentId} true ${time}
      fi
      export i=$((i+1))
    fi
done

createTestSuites ${i} ${totaltime}
