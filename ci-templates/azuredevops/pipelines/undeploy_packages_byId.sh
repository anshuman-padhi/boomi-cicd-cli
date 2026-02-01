#!/bin/bash
###########################################
# Undeploy Package by ID Wrapper Script
###########################################
set -e

echo "=========================================="
echo "Undeploying Package by ID"
echo "=========================================="
echo "Package ID: ${packageId:-[none]}"
echo "Component ID: ${componentId}"
echo "Environment: ${env}"
echo "=========================================="

# Navigate to scripts directory
cd "${SCRIPTS_HOME}"

# Use undeploy script with componentId
source bin/undeployPackages.sh \
  env="${env}" \
  componentIds="${componentId}"

if [ "$ERROR" -gt 0 ]; then
  echo "❌ Undeploy failed: $ERROR_MESSAGE"
  exit 1
fi

echo "✅ Package undeployed successfully from ${env}"
