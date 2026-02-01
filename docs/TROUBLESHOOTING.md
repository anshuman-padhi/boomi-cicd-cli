# Boomi CI/CD CLI - Troubleshooting Guide

Common errors, solutions, and debugging strategies for the Boomi CI/CD CLI.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Common Errors](#common-errors)
  - [Authentication Errors](#authentication-errors)
  - [Environment Errors](#environment-errors)
  - [Deployment Errors](#deployment-errors)
  - [Process Execution Errors](#process-execution-errors)
- [Error Messages Reference](#error-messages-reference)
- [Debugging Techniques](#debugging-techniques)
- [Getting Help](#getting-help)

---

## Quick Diagnostics

### Check Prerequisites

```bash
# Verify required tools
which jq || echo "ERROR: jq not installed"
which curl || echo "ERROR: curl not installed"
which xmllint || echo "ERROR: xmllint not installed"

# Check bash version (need 4.0+)
bash --version | head -n 1
```

### Verify Environment Variables

```bash
# Check all required variables are set
echo "baseURL: ${baseURL:?NOT SET}"
echo "authToken: ${authToken:?NOT SET}"
echo "WORKSPACE: ${WORKSPACE:?NOT SET}"
echo "SCRIPTS_HOME: ${SCRIPTS_HOME:?NOT SET}"
```

### Test API Connectivity

```bash
curl -s -u "${authToken}" \
  -H "Accept: application/json" \
  "${baseURL}Account/query" | jq .
  
# Should return JSON with account details
# If error, check baseURL format and authToken
```

---

## Common Errors

### Authentication Errors

#### Error: "HTTP 401 Unauthorized"

**Symptom:**
```
[ERROR] Failed to query environment: Production (exit code: 1)
HTTP/1.1 401 Unauthorized
```

**Causes:**
1. Invalid or expired API token
2. Incorrect username
3. Wrong baseURL (account ID)

**Solutions:**

```bash
# 1. Regenerate API token in AtomSphere
# Go to Settings > Account Information & Setup > AtomSphere API
# Generate new API token

# 2. Verify credentials format
export authToken="username@domain.com:BOOMI_TOKEN.your-token-here"

# 3. Check baseURL format
export baseURL="https://api.boomi.com/api/rest/v1/boomi_account-ACCOUNTID/"
# Note: Must end with trailing slash
```

---

#### Error: "HTTP 403 Forbidden"

**Symptom:**
```
[ERROR] Failed to create package (exit code: 1)
HTTP/1.1 403 Forbidden
```

**Cause:** User lacks required permissions

**Solution:**
```bash
# Contact Boomi administrator to grant:
# - Account Administrator role (read access)
# - API Service Deploy role (deployment permissions)
# - Process Manager role (process execution)
```

---

### Environment Errors

#### Error: "Environment not found"

**Symptoms:**
```
[INFO] Querying environment: Production (classification: *)
[ERROR] Failed to query environment: Production (exit code: 1)
[ERROR] Environment not found: Production
```

**Causes:**
1. Environment name mismatch (case-sensitive)
2. Environment doesn't exist
3. User lacks access to environment

**Solutions:**

```bash
# 1. List all environments
source bin/getAllEnvironments.sh
# Check exact environment name

# 2. Verify environment exists in AtomSphere
# Go to Manage > Atoms > Environments

# 3. Check for typos
source bin/queryEnvironment.sh env="production" classification="*"  # FAIL
source bin/queryEnvironment.sh env="Production" classification="*"  # SUCCESS
```

---

### Deployment Errors

#### Error: "Package deployment failed"

**Symptoms:**
```
[INFO] Deploying package pkg-123 to environment env-prod-456
[ERROR] Failed to deploy package pkg-123 (exit code: 1)
[ERROR] Package deployment failed
```

**Common Causes & Solutions:**

**1. Atom Offline:**
```bash
# Check atom status
source bin/queryAtom.sh \
  atomName="ProdAtom" \
  atomType="ATOM" \
  atomStatus="online"

# If not found, check atom is running in AtomSphere
# Manage > Atoms > [Your Atom] > Status should be "Online"
```

**2. Environment Not Attached to Atom:**
```bash
# Verify environment-atom attachment
# In AtomSphere: Manage > Atoms > [Your Atom] > Environment Attachments
# Ensure your environment is attached
```

**3. Package Already Deployed:**
```
[WARN] Package already deployed, redeploying...
```

**Solution:** This is usually not an error. The script handles redeployment automatically.

**4. Component Dependencies Missing:**
```bash
# Deploy all components in correct order
# Example: Deploy Connection first, then Process that uses it

source bin/deployPackages.sh \
  env="Production" \
  processNames="DatabaseConnection,OrderProcess" \
  packageVersion="v1.0.0" \
  notes="Deploy in dependency order" \
  listenerStatus="RUNNING"
```

---

#### Error: "Listener status change failed"

**Symptom:**
```
Package deployed but listener failed to start
```

**Solution:**
```bash
# 1. Deploy with PAUSED status first
source bin/deployPackages.sh \
  env="Production" \
  processNames="OrderProcess" \
  packageVersion="v1.0.0" \
  notes="Deploy paused" \
  listenerStatus="PAUSED"

# 2. Manually start in AtomSphere
# Manage > Atoms > [Environment] > Deployed Processes
# Click Start for the process

# 3. Or use changeListenerStatus.sh
source bin/changeListenerStatus.sh \
  processId="proc-123" \
  atomId="atom-456" \
  status="RUNNING"
```

---

### Process Execution Errors

#### Error: "Failed to execute process"

**Symptoms:**
```
[INFO] Executing process proc-123 on atom atom-789
[ERROR] Failed to execute process proc-123 (exit code: 1)
```

**Common Causes:**

**1. Process Not Deployed:**
```bash
# Ensure process is deployed first
source bin/deployPackages.sh \
  env="Production" \
  processNames="OrderProcess" \
  packageVersion="v1.0.0" \
  notes="Deployment" \
  listenerStatus="RUNNING"

# Then execute
source bin/executeProcess.sh \
  atomName="ProdAtom" \
  atomType="ATOM" \
  processName="OrderProcess"
```

**2. Atom Offline:**
```bash
# Query atom status
source bin/queryAtom.sh \
  atomName="ProdAtom" \
  atomType="ATOM" \
  atomStatus="online"
  
# Expected: [INFO] Found atom: ProdAtom (ID: atom-123)
# If error, check atom is running
```

**3. Process Requires Input Parameters:**
```bash
# Execute with process properties
export processProperties='[{"name":"orderId","value":"12345"}]'

source bin/executeProcess.sh \
  atomName="ProdAtom" \
  atomType="ATOM" \
  processName="OrderProcess" \
  processProperties="${processProperties}"
```

---

#### Error: "Process execution timeout"

**Symptom:**
```
Process execution triggered but no results returned
```

**Solution:**
```bash
# 1. Check execution status
source bin/queryExecutionRecord.sh \
  processId="proc-123" \
  atomId="atom-456"

# 2. Increase SLEEP_TIMER for slow processes
export SLEEP_TIMER=5  # Wait 5 seconds between API calls

# 3. Check process logs in AtomSphere
# Manage > Process Reporting > [Your Process]
```

---

## Error Messages Reference

### Scripts with Enhanced Error Handling ✅

These scripts provide detailed error messages:

| Script | Error Messages |
|--------|----------------|
| `createPackages.sh` | Failed to process input arguments<br>Package creation failed |
| `deployPackages.sh` | Failed to query environment<br>Package deployment failed |
| `undeployPackages.sh` | Package undeployment failed |
| `queryEnvironment.sh` | Environment not found |
| `queryAtom.sh` | Atom not found |
| `queryProcess.sh` | Process not found |
| `executeProcess.sh` | Failed to execute process |
| `createDeployedPackage.sh` | Failed to deploy package |
| `undeployPackage.sh` | Undeployment failed |

### Legacy Error Messages (Pre-Enhancement)

Scripts without ✅ may show generic errors:

```bash
return 255;  # No context
```

**Tip:** Check `$ERROR_MESSAGE` variable for details:
```bash
source bin/oldScript.sh ...
if [ $? -gt 0 ]; then
    echo "Error: ${ERROR_MESSAGE}"
fi
```

---

## Debugging Techniques

### 1. Enable Verbose Mode

```bash
export VERBOSE=true

source bin/deployPackages.sh \
  env="Production" \
  processNames="OrderProcess" \
  packageVersion="v1.0.0" \
  notes="Debug deployment" \
  listenerStatus="RUNNING"

# Shows all API calls, JSON payloads, and responses
```

### 2. Check Temp Files

```bash
# Scripts create temp files in WORKSPACE
ls -la ${WORKSPACE}/

# Key files:
# - out.json - API responses
# - in.json - Request payloads
# - out.xml - XML responses
# - *.list - Component lists

# Example: Check last API response
cat ${WORKSPACE}/out.json | jq .
```

### 3. Test Individual Components

```bash
# Test each step separately

# Step 1: Query environment
source bin/queryEnvironment.sh env="Production" classification="*"
echo "envId: ${envId}"

# Step 2: Query component
source bin/queryComponentMetadata.sh \
  componentName="OrderProcess" \
  componentType="process"
echo "componentId: ${componentId}"

# Step 3: Create package
source bin/createSinglePackage.sh \
  componentId="${componentId}" \
  packageVersion="v1.0.0" \
  notes="Test"
echo "packageId: ${packageId}"
```

### 4. Enable Bash Debug Mode

```bash
# Run with debug output
bash -x ${SCRIPTS_HOME}/bin/deployPackages.sh \
  env="Production" \
  processNames="OrderProcess" \
  packageVersion="v1.0.0" \
  notes="Debug" \
  listenerStatus="RUNNING"

# Shows every command executed
```

### 5. Check API Response Details

```bash
# After a failed operation, inspect API response
cat ${WORKSPACE}/out.json | jq .

# Common API error structures:
# {
#   "@type": "Error",
#   "message": "Component not found",
#   "code": "404"
# }
```

---

## Variable Troubleshooting

### Common Variable Issues

#### Issue: "Variable not exported"

```bash
# WRONG - Variable not available to sourced script
componentId="comp-123"
source bin/createSinglePackage.sh ...

# CORRECT - Export variable
export componentId="comp-123"
source bin/createSinglePackage.sh ...
```

#### Issue: "Command-line parameters not working"

```bash
# Use assignment format with source
source bin/createSinglePackage.sh \
  componentId="comp-123" \
  packageVersion="v1.0.0" \
  notes="Test"

# NOT: source bin/createSinglePackage.sh comp-123 v1.0.0 "Test"
```

---

## Pipeline-Specific Issues

### Azure DevOps

#### Issue: "Variable group not found"

```yaml
# Ensure variable group is linked
variables:
  - group: boomi-credentials  # Must exist in Azure DevOps

# Check in Azure DevOps:
# Pipelines > Library > Variable groups
```

#### Issue: "Authentication works locally but fails in pipeline"

```yaml
# Ensure secrets are properly masked
variables:
  - group: boomi-credentials  # Contains BOOMI_AUTH_TOKEN

steps:
  - script: |
      # Use $(VARIABLE) syntax for pipeline variables
      export authToken="$(BOOMI_AUTH_TOKEN)"
      
      # NOT: export authToken="${BOOMI_AUTH_TOKEN}"
```

#### Issue: "Script not found"

```yaml
steps:
  - checkout: self  # REQUIRED - checks out repository
  
  - script: |
      # Derive SCRIPTS_HOME from checkout location
      export SCRIPTS_HOME="$(Build.SourcesDirectory)/cli/scripts"
      cd "${SCRIPTS_HOME}"
      source bin/deployPackages.sh ...
```

---

## Performance Issues

### Slow API Calls

```bash
# Add delay between calls to avoid rate limiting
export SLEEP_TIMER=2  # 2 seconds between API calls

# Typical values:
# 0-1 : Fast (risk of rate limiting)
# 2-3 : Recommended
# 5+  : Slow but very safe
```

### Large Component XMLs

```bash
# Skip XML extraction if not needed
source bin/createPackages.sh \
  processNames="OrderProcess" \
  packageVersion="v1.0.0" \
  notes="No XML extraction"
  # extractComponentXmlFolder="" - Leave empty

# Only extract when needed for code review
source bin/createPackages.sh \
  processNames="OrderProcess" \
  packageVersion="v1.0.0" \
  notes="With XML" \
  extractComponentXmlFolder="code-review"
```

---

## Getting Help

### 1. Check Documentation

- [CLI_REFERENCE.md](./CLI_REFERENCE.md) - Script usage
- [ERROR_HANDLING_GUIDE.md](../cli/scripts/ERROR_HANDLING_GUIDE.md) - Error handling patterns
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture

### 2. Enable Logging

```bash
# Send all output to log file
export VERBOSE=true
source bin/deployPackages.sh ... 2>&1 | tee deployment.log

# Review log for details
less deployment.log
```

### 3. Common Diagnostics Script

Create a diagnostics script:

```bash
#!/bin/bash
# diagnose.sh - Check CLI environment

echo "=== Prerequisites ===" 
jq --version 2>&1
curl --version 2>&1  
xmllint --version 2>&1

echo -e "\n=== Environment Variables ==="
echo "baseURL: ${baseURL:-(not set)}"
echo "authToken: ${authToken:+(set, hidden)}"
echo "WORKSPACE: ${WORKSPACE:-(not set)}"
echo "SCRIPTS_HOME: ${SCRIPTS_HOME:-(not set)}"

echo -e "\n=== API Connectivity ==="
curl -s -u "${authToken}" \
  -H "Accept: application/json" \
  "${baseURL}Account/query" | jq -r '.name // "ERROR: Cannot connect to API"'

echo -e "\n=== Disk Space ==="
df -h "${WORKSPACE}" 2>/dev/null || echo "WORKSPACE not accessible"
```

Run with:
```bash
bash diagnose.sh
```

---

## FAQ

### Q: Can I run multiple scripts in parallel?

**A:** Generally no. Scripts use shared temporary files in `$WORKSPACE`. Run sequentially:

```bash
source bin/createPackages.sh ...
source bin/deployPackages.sh ...  # Wait for previous to complete
```

### Q: How do I handle special characters in parameters?

**A:** Use quotes:

```bash
source bin/createPackages.sh \
  notes="Release with special chars: & | ; < >" \
  processNames="Process-Name, Another_Process" \
  packageVersion="v2.1.0-beta"
```

### Q: Can I use these scripts outside Azure DevOps?

**A:** Yes! They work in any bash environment:

```bash
# Local execution
export baseURL="..."
export authToken="..."
export WORKSPACE="/tmp/boomi"
export SCRIPTS_HOME="/path/to/scripts"

cd "${SCRIPTS_HOME}"
source bin/createPackages.sh ...
```

### Q: How do I bulk deploy to multiple environments?

**A:** Loop through environments:

```bash
for env in "QA" "Staging" "Production"; do
  echo "Deploying to ${env}..."
  source bin/deployPackages.sh \
    env="${env}" \
    processNames="OrderProcess" \
    packageVersion="v2.1.0" \
    notes="Multi-env deployment" \
    listenerStatus="RUNNING"
done
```

---

**Last Updated:** 2026-02-01  
**Version:** 1.0.0
