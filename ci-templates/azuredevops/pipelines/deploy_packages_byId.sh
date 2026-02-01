#!/bin/bash
###########################################
# Deploy Package by ID Wrapper Script
###########################################
set -e

echo "=========================================="
echo "Deploying Existing Package by ID"
echo "=========================================="
echo "Package ID: ${packageId}"
echo "Environment: ${env}"
echo "Listener Status: ${listenerStatus}"
echo "=========================================="

# Navigate to scripts directory
cd "${SCRIPTS_HOME}"

# Query environment to get envId
echo "Querying environment: ${env}"
source bin/queryEnvironment.sh env="${env}" classification="*"

if [ "$ERROR" -gt 0 ]; then
  echo "❌ Failed to query environment: $ERROR_MESSAGE"
  exit 1
fi

echo "Environment ID: ${envId}"

# Deploy the existing package (does NOT create new package)
echo "Deploying package ${packageId} to environment ${envId}"
source bin/createDeployedPackage.sh \
  envId="${envId}" \
  packageId="${packageId}" \
  listenerStatus="${listenerStatus}" \
  notes="${notes}"

if [ "$ERROR" -gt 0 ]; then
  echo "❌ Deployment failed: $ERROR_MESSAGE"
  exit 1
fi

echo "✅ Package ${packageId} deployed successfully to ${env}"
