#!/bin/bash
###########################################
# Create Packages Wrapper Script
###########################################
set -e

echo "=========================================="
echo "Starting Package Creation"
echo "=========================================="
echo "Component IDs: ${componentIds:-[from processNames]}"
echo "Process Names: ${processNames:-[none]}"
echo "Package Version: ${packageVersion}"
echo "Component Type: ${componentType:-[all]}"
echo "=========================================="

# Navigate to scripts directory
cd "${SCRIPTS_HOME}"

# Call the actual package creation script
source bin/createPackages.sh \
  componentIds="${componentIds}" \
  processNames="${processNames}" \
  componentType="${componentType}" \
  packageVersion="${packageVersion}" \
  notes="${notes}" \
  extractComponentXmlFolder="${extractComponentXmlFolder}" \
  tag="${tag}" \
  branchName="${branchName}"

# Check for errors
if [ "$ERROR" -gt 0 ]; then
  echo "❌ Package creation failed: $ERROR_MESSAGE"
  exit 1
fi

echo "✅ Package created successfully: ${packageId}"

# Export packageId for use in subsequent stages (if running in pipeline)
if [ -n "$SYSTEM_TASKDEFINITIONSURI" ]; then
  echo "##vso[task.setvariable variable=packageId;isOutput=true]${packageId}"
fi
