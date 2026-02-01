#!/bin/bash
###########################################
# Deploy Multiple Packages by Version Wrapper Script
###########################################
set -e

echo "=========================================="
echo "Deploying Packages by Version"
echo "=========================================="
echo "Component IDs: ${componentIds}"
echo "Package Version: ${packageVersion}"
echo "Environment: ${env}"
echo "Component Type: ${componentType:-[all]}"
echo "Listener Status: ${listenerStatus}"
echo "=========================================="

# Navigate to scripts directory
cd "${SCRIPTS_HOME}"

# Use the multi-deploy script
source bin/deployPackagesByVersion.sh \
  env="${env}" \
  packageVersion="${packageVersion}" \
  componentIds="${componentIds}" \
  listenerStatus="${listenerStatus}" \
  notes="${notes}" \
  componentType="${componentType}"

RETURN_CODE=$?

if [ "$ERROR" -gt 0 ] || [ "$RETURN_CODE" -ne 0 ]; then
  echo "❌ Deployment failed"
  exit 1
fi

echo "✅ All packages deployed successfully to ${env}"
