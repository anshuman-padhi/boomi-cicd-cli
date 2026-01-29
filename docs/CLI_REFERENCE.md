# CLI Reference

Complete reference for all Boomi CI/CD CLI commands. This document covers all 74 scripts in `cli/scripts/bin/`.

## Overview

The CLI provides bash scripts that interact with the Boomi AtomSphere API to automate common CI/CD operations. All scripts:
- Are sourced (not executed directly): `source bin/scriptName.sh arg1=value1`
- Require environment variables: `authToken`, `baseURL`, `SCRIPTS_HOME`, `WORKSPACE`
- Use consistent argument parsing from `common.sh`
- Return 0 on success, 255 on error

## Common Environment Variables

Set these before running any script:

```bash
export authToken="$(echo -n 'ACCOUNT.username:api_token' | base64)"
export baseURL="https://api.boomi.com/api/rest/v1/YOUR_ACCOUNT_ID/"
export SCRIPTS_HOME="/path/to/cli/scripts"
export WORKSPACE="/path/to/workspace"
export h1="Content-Type: application/json"
export h2="Accept: application/json"
export VERBOSE="true"  # Optional: enable verbose logging
export SLEEP_TIMER="0.2"  # Optional: API polling interval
```

---

## Package Management

### deployPackages.sh

Deploy packages to a Boomi environment.

**Mandatory Arguments:**
- `env` - Environment ID or name
- `packageVersion` - Version string for the package
- `notes` - Deployment notes/description
- `listenerStatus` - Status for listeners (`RUNNING`, `PAUSED`)

**Optional Arguments:**
- `componentIds` - Comma-separated component IDs to package and deploy
- `processNames` - Comma-separated process names to package and deploy
- `extractComponentXmlFolder` - Folder to extract component XML
- `tag` - Git tag for release
- `componentType` - Component type filter

**Usage:**
```bash
source bin/deployPackages.sh \
  env="Production" \
  componentIds="comp-id-1,comp-id-2" \
  packageVersion="1.0.0" \
  notes="Production release" \
  listenerStatus="RUNNING"
```

**Returns:**
- `packageId` - ID of created package
- `envId` - Environment ID
- `extensionJson` - Extension configuration (if applicable)

---

### undeployPackages.sh

Undeploy packages from an environment.

**Mandatory Arguments:**
- `env` - Environment ID or name
- `componentId` - Component ID to undeploy

**Usage:**
```bash
source bin/undeployPackages.sh \
  env="Test" \
  componentId="comp-abc-123"
```

---

### createPackages.sh

Create deployment packages without deploying.

**Mandatory Arguments:**
- `packageVersion` - Version for the package
- `notes` - Package notes

**Optional Arguments:**
- `componentIds` - Component IDs to include
- `processNames` - Process names to include
- `componentType` - Component type filter

**Usage:**
```bash
source bin/createPackages.sh \
  componentIds="comp-1,comp-2" \
  packageVersion="2.0.0" \
  notes="QA build"
```

---

### createSinglePackage.sh

Create a package for a single component.

**Mandatory Arguments:**
- `packageVersion` - Package version
- `notes` - Package description

**Optional Arguments:**
- `componentId` - Component ID
- `processName` - Process name
- `componentVersion` - Specific component version
- `componentType` - Component type
- `extractComponentXmlFolder` - Extract XML to folder

**Usage:**
```bash
source bin/createSinglePackage.sh \
  processName="MyProcess" \
  packageVersion="1.0.0" \
  notes="Single process package"
```

---

## Process Management

### executeProcess.sh

Execute a Boomi process on an atom.

**Mandatory Arguments:**
- `atomName` - Name of the atom to execute on
- `processName` - Name of the process to execute

**Optional Arguments:**
- `atomType` - Type of atom (`ATOM`, `MOLECULE`, `CLOUD`)

**Usage:**
```bash
source bin/executeProcess.sh \
  atomName="Prod-Atom-01" \
  processName="DataSync Process"
```

**Returns:**
- `executionId` - Execution record ID

---

### deployProcess.sh

Deploy a specific process to an environment.

**Mandatory Arguments:**
- `processName` - Process to deploy
- `env` - Target environment
- `packageVersion` - Package version
- `notes` - Deployment notes

**Usage:**
```bash
source bin/deployProcess.sh \
  processName="MyProcess" \
  env="UAT" \
  packageVersion="1.5.0" \
  notes="UAT deployment"
```

---

### queryProcess.sh

Query process information by name or ID.

**Mandatory Arguments:**
- `processName` - Process name (supports wildcards: `*`)

**Usage:**
```bash
# Query specific process
source bin/queryProcess.sh processName="DataLoader"

# Query all processes
source bin/queryProcess.sh processName="*"
```

**Returns:**
- `componentId` - Process component ID
- Array of process details in `out.json`

---

### promoteProcess.sh

Promote a process through environments.

**Mandatory Arguments:**
- `processName` - Process to promote
- `fromEnv` - Source environment
- `toEnv` - Target environment
- `packageVersion` - Version for promotion
- `notes` - Promotion notes

**Usage:**
```bash
source bin/promoteProcess.sh \
  processName="CriticalProcess" \
  fromEnv="UAT" \
  toEnv="Production" \
  packageVersion="2.0.0" \
  notes="Promoting to prod"
```

---

### executeTestSuite.sh

Execute a test suite.

**Mandatory Arguments:**
- `testSuiteName` - Name of test suite
- `atomName` - Atom to run tests on

**Usage:**
```bash
source bin/executeTestSuite.sh \
  testSuiteName="Integration Tests" \
  atomName="Test-Atom"
```

---

## Environment Management

### queryEnvironment.sh

Query environment details.

**Mandatory Arguments:**
- `env` - Environment name or ID (supports wildcards)
- `classification` - Classification filter (`*` for all)

**Usage:**
```bash
# Query specific environment
source bin/queryEnvironment.sh env="Production" classification="*"

# List all environments
source bin/queryEnvironment.sh env="*" classification="*"
```

**Returns:**
- `envId` - Environment ID
- Environment details in `out.json`

---

### createEnvironment.sh

Create a new environment.

**Mandatory Arguments:**
- `env` - Environment name
- `classification` - Classification (`PRODUCTION`, `TEST`, `DEVELOPMENT`)

**Usage:**
```bash
source bin/createEnvironment.sh \
  env="Staging" \
  classification="TEST"
```

---

### updateExtensions.sh

Update environment extensions (connection overrides).

**Mandatory Arguments:**
- `env` - Environment ID or name
- `extensionJson` - JSON file path with extensions

**Usage:**
```bash
source bin/updateExtensions.sh \
  env="Production" \
  extensionJson="${WORKSPACE}/prod-extensions.json"
```

---

### retrieveExtensions.sh

Retrieve current environment extensions.

**Mandatory Arguments:**
- `env` - Environment ID or name

**Usage:**
```bash
source bin/retrieveExtensions.sh env="Production"
```

**Returns:**
- Extension configuration in `out.json`

---

## Atom Management

### queryAtom.sh

Query atom information.

**Mandatory Arguments:**
- `atomName` - Atom name (supports wildcards)

**Usage:**
```bash
# Query specific atom
source bin/queryAtom.sh atomName="Prod-Atom-01"

# List all atoms
source bin/queryAtom.sh atomName="*"
```

**Returns:**
- `atomId` - Atom ID
- Atom details in `out.json`

---

### createAtom.sh

Create a new atom.

**Mandatory Arguments:**
- `atomName` - Name for the atom
- `cloudId` - Cloud ID to attach to

**Usage:**
```bash
source bin/createAtom.sh \
  atomName="New-Atom-01" \
  cloudId="cloud-123"
```

---

### updateAtom.sh

Update atom configuration.

**Mandatory Arguments:**
- `atomId` - Atom ID to update
- `atomName` - New atom name

**Usage:**
```bash
source bin/updateAtom.sh \
  atomId="atom-abc-123" \
  atomName="Updated-Atom-Name"
```

---

### installAtom.sh

Install an atom runtime.

**Mandatory Arguments:**
- `dir` - Installation directory
- `atomName` - Atom name
- `token` - Installation token

**Usage:**
```bash
source bin/installAtom.sh \
  dir="/opt/boomi/atom" \
  atomName="Runtime-Atom" \
  token="install-token-here"
```

---

### installCloud.sh

Install a cloud atom.

**Mandatory Arguments:**
- `dir` - Installation directory
- `cloudName` - Cloud name
- `token` - Installation token

**Usage:**
```bash
source bin/installCloud.sh \
  dir="/opt/boomi/cloud" \
  cloudName="Cloud-01" \
  token="cloud-token"
```

---

### installGateway.sh

Install API Gateway.

**Mandatory Arguments:**
- `dir` - Installation directory
- `gatewayName` - Gateway name
- `token` - Installation token

**Usage:**
```bash
source bin/installGateway.sh \
  dir="/opt/boomi/gateway" \
  gatewayName="Gateway-01" \
  token="gateway-token"
```

---

### installMolecule.sh

Install a molecule.

**Mandatory Arguments:**
- `dir` - Installation directory
- `moleculeName` - Molecule name
- `token` - Installation token

**Usage:**
```bash
source bin/installMolecule.sh \
  dir="/opt/boomi/molecule" \
  moleculeName="Molecule-01" \
  token="molecule-token"
```

---

## Publishing & Reporting

### publishDeployedPackage.sh

Generate HTML report of deployed packages.

**Mandatory Arguments:**
- `env` - Environment ID or name

**Usage:**
```bash
source bin/publishDeployedPackage.sh env="Production"
```

**Output:**
- `${WORKSPACE}/DeployedPackage.html` - HTML report

---

### publishPackagedComponent.sh

List all packaged components in HTML format.

**Mandatory Arguments:**
- `packageId` - Package ID

**Usage:**
```bash
source bin/publishPackagedComponent.sh packageId="pkg-123"
```

**Output:**
- `${WORKSPACE}/PackagedComponent.html`

---

### publishProcess.sh

Generate HTML report of all processes.

**Optional Arguments:**
- `processName` - Filter by process name

**Usage:**
```bash
# All processes
source bin/publishProcess.sh

# Specific process
source bin/publishProcess.sh processName="MyProcess"
```

**Output:**
- `${WORKSPACE}/Process.html`

---

### publishAtom.sh

Generate HTML report of atoms.

**Optional Arguments:**
- `atomName` - Filter by atom name

**Usage:**
```bash
source bin/publishAtom.sh atomName="*"
```

**Output:**
- `${WORKSPACE}/Atom.html`

---

### publishCodeReviewReport.sh

Generate code review report from component XML.

**Mandatory Arguments:**
- `COMPONENT_LIST_FILE` - File with list of components
- `GIT_COMMIT_ID` - Git commit ID

**Usage:**
```bash
source bin/publishCodeReviewReport.sh \
  COMPONENT_LIST_FILE="${WORKSPACE}/components.list" \
  GIT_COMMIT_ID="abc123"
```

**Output:**
- Code review HTML report

---

## Git Integration

### gitPush.sh

Push component XML to Git repository.

**Mandatory Arguments:**
- `baseFolder` - Folder containing component XML
- `tag` - Git tag
- `notes` - Commit message

**Usage:**
```bash
source bin/gitPush.sh \
  baseFolder="${WORKSPACE}/components" \
  tag="v1.0.0" \
  notes="Release 1.0"
```

---

### gitRelease.sh

Create a Git release.

**Mandatory Arguments:**
- `tag` - Release tag
- `notes` - Release notes

**Usage:**
```bash
source bin/gitRelease.sh \
  tag="v2.0.0" \
  notes="Major release with new features"
```

---

### gitClone.sh

Clone a Git repository.

**Mandatory Arguments:**
- `repoUrl` - Repository URL
- `targetDir` - Target directory

**Usage:**
```bash
source bin/gitClone.sh \
  repoUrl="https://github.com/org/repo.git" \
  targetDir="/tmp/repo"
```

---

## Advanced Operations

### sonarScanner.sh

Run SonarQube analysis on component XML.

**Mandatory Arguments:**
- `baseFolder` - Folder with component XML

**Usage:**
```bash
source bin/sonarScanner.sh baseFolder="${WORKSPACE}/components"
```

**Prerequisites:**
- SonarQube scanner installed and in PATH
- `sonar-project.properties` configured

---

### xpathRulesChecker.sh

Validate components against XPath rules.

**Mandatory Arguments:**
- `ruleFile` - XPath rules file
- `componentXml` - Component XML to validate

**Usage:**
```bash
source bin/xpathRulesChecker.sh \
  ruleFile="${SCRIPTS_HOME}/conf/rules.xml" \
  componentXml="${WORKSPACE}/component.xml"
```

---

### dynamicJobBuilder.sh

Build dynamic job configurations.

**Mandatory Arguments:**
- `jobTemplate` - Job template file
- `outputFile` - Output file path

**Usage:**
```bash
source bin/dynamicJobBuilder.sh \
  jobTemplate="${SCRIPTS_HOME}/conf/job-template.json" \
  outputFile="${WORKSPACE}/job.json"
```

---

## Listener Management

### changeListenerStatus.sh

Change listener status for a deployed process.

**Mandatory Arguments:**
- `deploymentId` - Deployment ID
- `listenerStatus` - Target status (`RUNNING`, `PAUSED`)

**Usage:**
```bash
source bin/changeListenerStatus.sh \
  deploymentId="deploy-123" \
  listenerStatus="RUNNING"
```

---

### changeAllListenersStatus.sh

Change status for all listeners in an environment.

**Mandatory Arguments:**
- `env` - Environment ID or name
- `listenerStatus` - Target status

**Usage:**
```bash
source bin/changeAllListenersStatus.sh \
  env="Production" \
  listenerStatus="PAUSED"
```

---

## Query Operations

All query scripts follow similar patterns - use wildcards (`*`) to list all items.

### queryDeployedPackage.sh

Query deployed package information.

**Mandatory Arguments:**
- `env` - Environment name/ID
- `packageVersion` - Package version (or `*`)

**Usage:**
```bash
source bin/queryDeployedPackage.sh env="Production" packageVersion="*"
```

---

### queryDeployment.sh

Query deployment details.

**Mandatory Arguments:**
- `deploymentId` - Deployment ID

**Usage:**
```bash
source bin/queryDeployment.sh deploymentId="deploy-abc-123"
```

---

### queryExecutionRecord.sh

Query process execution records.

**Mandatory Arguments:**
- `executionId` - Execution ID

**Usage:**
```bash
source bin/queryExecutionRecord.sh executionId="exec-123"
```

---

## Error Handling

All scripts set the `ERROR` variable on failure:

```bash
source bin/deployPackages.sh env="Test" ...
if [ "$ERROR" -gt 0 ]; then
    echo "Deployment failed: $ERROR_MESSAGE"
    exit 1
fi
```

## Return Codes

- `0` - Success
- `251` - API error (check `ERROR_MESSAGE`)
- `255` - Script error (missing args, validation failure)

## Verbose Mode

Enable detailed logging:

```bash
export VERBOSE="true"
source bin/deployPackages.sh ...
```

Output includes:
- All API requests and responses
- Argument values (tokens masked)
- Intermediate processing steps

## Common Patterns

### Deploy and Verify

```bash
# Deploy
source bin/deployPackages.sh \
  env="Test" \
  componentIds="comp-1" \
  packageVersion="1.0" \
  notes="Test" \
  listenerStatus="RUNNING"

# Verify
if [ "$ERROR" -eq 0 ]; then
    source bin/queryDeployedPackage.sh env="Test" packageVersion="1.0"
fi
```

### Multi-Environment Promotion

```bash
for ENV in "Dev" "QA" "UAT" "Prod"; do
    source bin/deployPackages.sh \
      env="$ENV" \
      componentIds="comp-1,comp-2" \
      packageVersion="$VERSION" \
      notes="Deployment to $ENV" \
      listenerStatus="RUNNING"
    
    if [ "$ERROR" -gt 0 ]; then
        echo "Failed to deploy to $ENV"
        break
    fi
done
```

---

## See Also

- [Getting Started Guide](GETTING_STARTED.md) - First-time setup
- [Architecture](ARCHITECTURE.md) - Framework design
- [Contributing](../CONTRIBUTING.md) - Development guidelines
