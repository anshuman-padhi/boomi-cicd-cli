#!/bin/bash
# GitLab CI wrapper for Boomi deployments

# Ensure SCRIPTS_HOME is available
if [ -z "${SCRIPTS_HOME}" ]; then
  echo "SCRIPTS_HOME is not set. Assuming default relative location..."
  SCRIPTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../cli/scripts" && pwd )"
fi

if [ ! -d "${SCRIPTS_HOME}" ]; then
    echo "Error: Scripts directory not found at ${SCRIPTS_HOME}"
    exit 1
fi

saveNotes="Triggered by ${BUILD_USER} (${BUILD_USER_ID}) via ${BUILD_EVENT} event. ${notes}"

# Execute using source with absolute path
source "${SCRIPTS_HOME}/bin/deployPackages.sh" notes="${saveNotes}"
