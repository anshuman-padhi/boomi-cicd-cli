# Boomi CI/CD CLI Reference

Complete reference guide for all CLI scripts in the Boomi CI/CD automation toolkit.

## Table of Contents

- [Overview](#overview)
- [Error Handling](#error-handling)
- [Core Operations](#core-operations)
  - [Package Management](#package-management)
  - [Deployment Operations](#deployment-operations)
  - [Process Management](#process-management)
  - [Atom Management](#atom-management)
  - [Environment Management](#environment-management)
  - [Component Operations](#component-operations)
- [Supporting Scripts](#supporting-scripts)
- [Usage Examples](#usage-examples)

---

## Overview

The Boomi CI/CD CLI provides shell scripts for automating Boomi AtomSphere operations including package creation, deployment, process execution, and environment management.

### Prerequisites

- Bash 4.0+
- `jq` (JSON processor)
- `curl` (API client)
- `xmllint` (XML processor)

### Common Environment Variables

All scripts use these standard environment variables:

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `baseURL` | Yes | Boomi API base URL | `https://api.boomi.com/api/rest/v1/account-id/` |
| `authToken` | Yes | Authentication credentials | `username:api-token` |
| `WORKSPACE` | Yes | Working directory for temp files | `/tmp/boomi-workspace` |
| `SCRIPTS_HOME` | Yes | Path to scripts directory | `/path/to/cli/scripts` |
| `h1` | No | HTTP header (Accept) | `Accept: application/json` |
| `h2` | No | HTTP header (Content-Type) | `Content-Type: application/json` |
| `VERBOSE` | No | Enable verbose logging | `true` |
| `SLEEP_TIMER` | No | Delay between API calls (seconds) | `2` |

---

## Error Handling

### Enhanced Error Handling (15 scripts)

Scripts marked with ✅ use enhanced error handling with clear, contextual error messages.

**Error Handling Functions** (from `common.sh`):

```bash
log_info "message"           # [INFO] message
log_warn "message"           # [WARN] message
log_error "message"          # [ERROR] message
handle_error $? "message"    # Check exit code, log if error
validate_required_vars var1 var2  # Validate variables exist
retry_command 3 5 "command"  # Retry command with backoff
```

**Exit Codes:**
- `0` - Success
- `1` - General error (with handle_error)
- `255` - Legacy error code (pre-enhancement)

---

## Core Operations

### Package Management

#### createPackages.sh ✅
**Purpose:** Create multiple Boomi packages for components.

**Parameters:**
```bash
# Required
packageVersion=""     # Package version (e.g., "v1.0.0")
notes=""             # Package creation notes

# Optional (one required)
componentIds=""      # Comma-separated component IDs
processNames=""      # Comma-separated process names

# Optional
componentType=""     # Filter by component type
branchName=""       # Boomi branch name
extractComponentXmlFolder=""  # Folder for XML extraction
tag=""              # Git tag for release
```

**Usage:**
```bash
source bin/createPackages.sh \
  processNames="OrderProcess,InventorySync" \
  packageVersion="v2.1.0" \
  notes="Production release 2.1" \
  componentType="process"
```

**Output:**
```
[INFO] Starting package creation
[INFO] Created package pkg-123 for OrderProcess
[INFO] Created package pkg-456 for InventorySync
```

---

#### createSinglePackage.sh ✅
**Purpose:** Create a single Boomi package for one component.

**Parameters:**
```bash
# Required
packageVersion=""    # Package version
notes=""            # Creation notes

# Optional (one required)
componentId=""      # Component ID
processName=""      # Process name

# Optional
componentType=""    # Component type
componentVersion="" # Specific component version
branchName=""      # Branch name
extractComponentXmlFolder=""  # XML extraction folder
```

**Usage:**
```bash
source bin/createSinglePackage.sh \
  processName="DataSync" \
  packageVersion="v1.5.0" \
  notes="Bug fix release"
```

---

#### createPackagedComponent.sh ✅
**Purpose:** Create a packaged component (low-level API operation).

**Parameters:**
```bash
# Required
componentId=""       # Component ID
componentType=""     # Component type (process, connector, etc.)
packageVersion=""    # Package version
notes=""            # Notes
createdDate=""      # Creation date (auto-generated)

# Optional
componentVersion="" # Specific component version
branchName=""      # Branch name
```

**Usage:**
```bash
source bin/createPackagedComponent.sh \
  componentId="comp-123" \
  componentType="process" \
  packageVersion="v1.0.0" \
  notes="Initial release"
```

**Output:**
```
[INFO] Creating packaged component: comp-123 (version: v1.0.0)
[INFO] Successfully created packaged component (packageId: pkg-789)
```

---

### Deployment Operations

#### deployPackages.sh ✅
**Purpose:** Deploy packages to a Boomi environment.

**Parameters:**
```bash
# Required
env=""              # Environment name
packageVersion=""   # Package version to deploy
notes=""           # Deployment notes
listenerStatus=""  # Listener status after deployment (RUNNING/PAUSED)

# Optional (one required)
componentIds=""     # Comma-separated component IDs
processNames=""     # Comma-separated process names

# Optional
componentType=""    # Component type filter
extractComponentXmlFolder=""  # XML extraction folder
```

**Usage:**
```bash
source bin/deployPackages.sh \
  env="Production" \
  processNames="OrderProcess" \
  packageVersion="v2.1.0" \
  notes="Production deployment" \
  listenerStatus="RUNNING"
```

**Output:**
```
[INFO] Starting package deployment to environment: Production
[INFO] Querying environment: Production
[INFO] Environment ID: env-prod-123
[INFO] Deploying package pkg-456 to environment env-prod-123
[INFO] Successfully deployed package: pkg-456
[INFO] Successfully deployed packages to Production
```

---

#### createDeployedPackage.sh ✅
**Purpose:** Deploy a specific package to an environment (low-level).

**Parameters:**
```bash
# Required
envId=""           # Environment ID
packageId=""       # Package ID to deploy
listenerStatus=""  # Listener status (RUNNING/PAUSED)

# Optional
notes=""          # Deployment notes
```

**Usage:**
```bash
source bin/createDeployedPackage.sh \
  envId="env-123" \
  packageId="pkg-456" \
  listenerStatus="RUNNING" \
  notes="Hotfix deployment"
```

**Output:**
```
[INFO] Deploying package pkg-456 to environment env-123
[INFO] Successfully deployed package: pkg-456
```

---

#### undeployPackages.sh ✅
**Purpose:** Undeploy packages from an environment.

**Parameters:**
```bash
# Required
env=""  # Environment name

# Optional (one required)
componentIds=""   # Comma-separated component IDs
processNames=""   # Comma-separated process names
```

**Usage:**
```bash
source bin/undeployPackages.sh \
  env="QA" \
  processNames="LegacyProcess,OldIntegration"
```

**Output:**
```
[INFO] Starting package undeployment from environment: QA
[INFO] Querying environment: QA
[INFO] Environment ID: env-qa-789
[INFO] Undeploying process: LegacyProcess (comp-123)
[INFO] Undeploying process: OldIntegration (comp-456)
[INFO] Successfully undeployed packages from QA
```

---

#### undeployPackage.sh ✅
**Purpose:** Undeploy a single component from an environment.

**Parameters:**
```bash
# Required
componentId=""  # Component ID to undeploy
envId=""       # Environment ID
```

**Usage:**
```bash
source bin/undeployPackage.sh \
  componentId="comp-123" \
  envId="env-qa-789"
```

**Output (Success):**
```
[INFO] Undeploying component comp-123 from environment env-qa-789
[INFO] Found deployment deploy-456, undeploying...
[INFO] Successfully undeployed component comp-123
```

**Output (Already Undeployed):**
```
[INFO] Undeploying component comp-999 from environment env-qa-789
[WARN] No active deployment found for component comp-999 - nothing to undeploy
```

---

### Process Management

#### executeProcess.sh ✅
**Purpose:** Execute a Boomi process on an atom.

**Parameters:**
```bash
# Required
atomName=""     # Atom name
atomType=""     # Atom type (ATOM, MOLECULE, CLOUD)

# Optional (one required)
componentId=""     # Process component ID
processName=""     # Process name

# Optional
processProperties=""  # JSON array of process properties
```

**Usage:**
```bash
source bin/executeProcess.sh \
  atomName="ProdAtom" \
  atomType="ATOM" \
  processName="DataSync"
```

**Output:**
```
[INFO] Executing process on atom: ProdAtom (ATOM)
[INFO] Executing process proc-123 on atom atom-789
[INFO] Successfully triggered process execution
```

---

#### queryProcess.sh ✅
**Purpose:** Query process details by name.

**Parameters:**
```bash
# Required
processName=""  # Process name to query

# Optional
componentType=""  # Component type filter
```

**Usage:**
```bash
source bin/queryProcess.sh processName="OrderProcessing"
```

**Output:**
```
[INFO] Querying process: OrderProcessing
[INFO] Found process: OrderProcessing (ID: proc-456)
```

**Exports:**
- `componentId` - Process component ID
- `processId` - Process ID

---

### Atom Management

#### queryAtom.sh ✅
**Purpose:** Query atom details by name and status.

**Parameters:**
```bash
# Required
atomName=""      # Atom name
atomType=""      # Atom type (ATOM, MOLECULE, CLOUD, or *)
atomStatus=""    # Atom status (online, offline, or *)
```

**Usage:**
```bash
source bin/queryAtom.sh \
  atomName="ProdAtom" \
  atomType="ATOM" \
  atomStatus="online"
```

**Output (Success):**
```
[INFO] Querying atom: ProdAtom (type: ATOM, status: online)
[INFO] Found atom: ProdAtom (ID: atom-123-456)
```

**Output (Not Found):**
```
[INFO] Querying atom: NonExistent (type: ATOM, status: online)
[ERROR] Failed to query atom: NonExistent (exit code: 1)
[ERROR] Atom not found: NonExistent
```

**Exports:**
- `atomId` - Atom ID

---

#### createAtom.sh ✅
**Purpose:** Create a new Boomi atom.

**Parameters:**
```bash
# Required
atomName=""  # Name for the new atom
cloudId=""   # Cloud ID for atom placement
```

**Usage:**
```bash
source bin/createAtom.sh \
  atomName="NewProdAtom" \
  cloudId="cloud-123"
```

**Output:**
```
[INFO] Creating atom: NewProdAtom
[INFO] Successfully created atom: NewProdAtom (ID: atom-789-012)
```

**Exports:**
- `atomId` - Created atom ID

---

### Environment Management

#### queryEnvironment.sh ✅
**Purpose:** Query environment details by name.

**Parameters:**
```bash
# Required
env=""             # Environment name

# Optional
classification=""  # Environment classification (or *)
```

**Usage:**
```bash
source bin/queryEnvironment.sh \
  env="Production" \
  classification="*"
```

**Output (Success):**
```
[INFO] Querying environment: Production (classification: *)
[INFO] Found environment: Production (ID: env-prod-123)
```

**Output (Not Found):**
```
[INFO] Querying environment: InvalidEnv (classification: *)
[ERROR] Failed to query environment: InvalidEnv (exit code: 1)
[ERROR] Environment not found: InvalidEnv
```

**Exports:**
- `envId` - Environment ID

---

### Component Operations

#### queryComponentMetadata.sh ✅
**Purpose:** Query component metadata by ID or name.

**Parameters:**
```bash
# Optional (at least one required)
componentId=""        # Component ID
componentName=""      # Component name
componentType=""      # Component type
componentVersion=""   # Specific version
currentVersion=""     # Query current version (default: true)
deleted=""           # Include deleted (default: false)
```

**Usage:**
```bash
source bin/queryComponentMetadata.sh \
  componentName="DataSync" \
  componentType="process"
```

**Exports:**
- `componentId` - Component ID
- `componentName` - Component name
- `componentType` - Component type
- `componentVersion` - Component version

---

#### getComponent.sh ✅
**Purpose:** Retrieve component XML.

**Parameters:**
```bash
# Required
componentId=""  # Component ID

# Optional
version=""     # Specific version
```

**Usage:**
```bash
source bin/getComponent.sh \
  componentId="comp-123" \
  version="1.2.0"
```

**Output:**
```
[INFO] Retrieving component: comp-123 (version: 1.2.0)
```

**Creates:** `${WORKSPACE}/${componentId}.xml`

---

#### publishPackagedComponentMetadata.sh
**Purpose:** Generate HTML manifest report for packaged components.

**Parameters:**
```bash
# Required
packageIds=""  # Space/comma-separated package IDs

# Optional
atomId=""     # Atom ID for deployment info
envId=""      # Environment ID for deployment info
```

**Usage:**
```bash
source bin/publishPackagedComponentMetadata.sh \
  packageIds="pkg-123 pkg-456"
```

**Output:** HTML table with component manifest

---

## Supporting Scripts

### Query Operations

- `queryDeployedPackage.sh` - Query deployed package details
- `queryDeployment.sh` - Query deployment status
- `queryPackagedComponent.sh` - Query packaged component details
- `queryExecutionRecord.sh` - Query process execution records

### Install Operations

- `installAny.sh` - Orchestrator for various install operations
- `installAtom.sh` - Install to Atom
- `installMolecule.sh` - Install to Molecule
- `installCloud.sh` - Install to Cloud

### Utility Scripts

- `common.sh` - Shared utility functions and error handling
- `clean.sh` - Cleanup temporary files
- `createJSON.sh` - Generate JSON payloads from templates
- `callAPI.sh` - Execute API calls
- `extract.sh` - Extract values from JSON responses

---

## Usage Examples

### Example 1: Complete Build-Deploy-Execute Workflow

```bash
#!/bin/bash
# Setup environment
export baseURL="https://api.boomi.com/api/rest/v1/your-account/"
export authToken="username:api-token"
export WORKSPACE="/tmp/boomi-workspace"
export SCRIPTS_HOME="/path/to/cli/scripts"
export h1="Accept: application/json"
export h2="Content-Type: application/json"
export VERBOSE=true

cd "${SCRIPTS_HOME}"

# Step 1: Create packages
source bin/createPackages.sh \
  processNames="OrderProcess,InventorySync" \
  packageVersion="v2.1.0" \
  notes="Production release 2.1" \
  componentType="process"

# Step 2: Deploy to QA
source bin/deployPackages.sh \
  env="QA" \
  processNames="OrderProcess,InventorySync" \
  packageVersion="v2.1.0" \
  notes="QA deployment" \
  listenerStatus="RUNNING"

# Step 3: Execute test
source bin/executeProcess.sh \
  atomName="QAAtom" \
  atomType="ATOM" \
  processName="OrderProcess"

# Step 4: Deploy to Production
source bin/deployPackages.sh \
  env="Production" \
  processNames="OrderProcess,InventorySync" \
  packageVersion="v2.1.0" \
  notes="Production deployment" \
  listenerStatus="RUNNING"
```

**Output:**
```
[INFO] Starting package creation
[INFO] Created package pkg-123 for OrderProcess
[INFO] Created package pkg-456 for InventorySync

[INFO] Starting package deployment to environment: QA
[INFO] Querying environment: QA
[INFO] Environment ID: env-qa-789
[INFO] Successfully deployed packages to QA

[INFO] Executing process on atom: QAAtom (ATOM)
[INFO] Successfully triggered process execution

[INFO] Starting package deployment to environment: Production
[INFO] Querying environment: Production
[INFO] Environment ID: env-prod-123
[INFO] Successfully deployed packages to Production
```

---

### Example 2: Rollback Deployment

```bash
#!/bin/bash
# Undeploy from environment

source bin/undeployPackages.sh \
  env="QA" \
  processNames="FailedProcess,BuggyIntegration"
```

**Output:**
```
[INFO] Starting package undeployment from environment: QA
[INFO] Querying environment: QA
[INFO] Environment ID: env-qa-789
[INFO] Undeploying process: FailedProcess (comp-123)
[INFO] Undeploying process: BuggyIntegration (comp-456)
[INFO] Successfully undeployed packages from QA
```

---

### Example 3: Query Operations

```bash
# Query environment
source bin/queryEnvironment.sh env="Production" classification="*"
echo "Environment ID: ${envId}"

# Query atom
source bin/queryAtom.sh atomName="ProdAtom" atomType="ATOM" atomStatus="online"
echo "Atom ID: ${atomId}"

# Query process
source bin/queryProcess.sh processName="OrderProcessing"
echo "Process ID: ${componentId}"
```

---

## Error Handling Best Practices

### 1. Check Return Codes

```bash
source bin/deployPackages.sh env="Production" ...
if [ $? -gt 0 ]; then
    echo "Deployment failed, rolling back..."
    source bin/undeployPackages.sh env="Production" ...
fi
```

### 2. Validate Exported Variables

```bash
source bin/queryEnvironment.sh env="Production" classification="*"
if [ -z "${envId}" ]; then
    echo "ERROR: Environment not found"
    exit 1
fi
```

### 3. Use Error Messages for Debugging

Scripts with ✅ provide detailed error messages:

```bash
source bin/queryAtom.sh atomName="TestAtom" atomType="ATOM" atomStatus="online"
# Output: [ERROR] Atom not found: TestAtom
# Clear indication of exactly what went wrong
```

---

## Integration with Azure DevOps

### Using in Azure Pipelines

```yaml
steps:
  - script: |
      export h1='Accept: application/json'
      export h2='Content-Type: application/json'
      export baseURL=$(BOOMI_BASE_URL)
      export authToken=$(BOOMI_AUTH_TOKEN)
      export WORKSPACE=$(Build.SourcesDirectory)
      export SCRIPTS_HOME=$(Build.SourcesDirectory)/cli/scripts
      
      cd $(Build.SourcesDirectory)/cli/scripts
      
      source bin/createPackages.sh \
        processNames="$(PROCESS_NAMES)" \
        packageVersion="$(Build.BuildNumber)" \
        notes="Azure DevOps Build $(Build.BuildId)"
    displayName: 'Create Boomi Packages'
    env:
      BUILD_USER: $(Build.RequestedFor)
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common errors and solutions.

---

## Contributing

When adding or modifying scripts:

1. Use the error handling utilities from `common.sh`
2. Follow the established parameter naming conventions
3. Add log messages at key operations
4. Update this reference documentation
5. Test with both success and failure scenarios

---

**Last Updated:** 2026-02-01  
**Version:** 1.0.0
