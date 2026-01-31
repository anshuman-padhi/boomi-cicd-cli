# Azure DevOps Setup Guide

Complete guide for integrating Boomi CI/CD CLI with Azure DevOps Pipelines.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setting Up Self-Hosted Agent](#setting-up-self-hosted-agent-complete-guide)
- [Quick Start](#quick-start)
- [Variable Groups Configuration](#variable-groups-configuration)
- [Available Templates](#available-templates)
- [Creating Your First Pipeline](#creating-your-first-pipeline)
- [Common Patterns](#common-patterns)
- [Approval Gates Setup](#approval-gates-setup)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

---

## Prerequisites

1. **Azure DevOps Organization & Project**
2. **Agent Requirements:**
   - Bash 4.0+
   - curl
   - jq
   - Self-hosted or Microsoft-hosted Linux agent
3. **Boomi Credentials:**
   - Boomi account ID
   - API token with deployment permissions

## Setting Up Self-Hosted Agent (Complete Guide)

### Step 1: Prepare Linux Machine

**System Requirements:**
- Ubuntu 18.04+, RHEL 7+, or compatible Linux distribution
- 2+ CPU cores
- 4+ GB RAM
- 20+ GB disk space
- Network access to:
  - `dev.azure.com` (Azure DevOps)
  - `api.boomi.com` (Boomi AtomSphere API)

### Step 2: Install Dependencies

**On Ubuntu/Debian:**
```bash
# Update package list
sudo apt-get update

# Install required packages
sudo apt-get install -y \
  curl \
  jq \
  git \
  bash \
  libicu60 \
  libssl1.0.0 \
  ca-certificates

# Verify installations
jq --version        # Should show jq-1.5 or higher
curl --version      # Should show curl 7.x or higher
bash --version      # Should show 4.0 or higher
git --version       # Should show 2.x or higher
```

**On RHEL/CentOS:**
```bash
# Update packages
sudo yum update -y

# Install required packages
sudo yum install -y \
  curl \
  jq \
  git \
  bash \
  libicu \
  openssl-libs \
  ca-certificates

# Verify installations
jq --version
curl --version
bash --version
git --version
```

### Step 3: Create Agent User

```bash
# Create dedicated user for agent
sudo useradd -m -s /bin/bash azureagent

# Set password (optional, for manual login)
sudo passwd azureagent

# Add to sudo group if needed for installations
sudo usermod -aG sudo azureagent

# Switch to agent user
sudo su - azureagent
```

### Step 4: Download and Install Azure DevOps Agent

```bash
# Create agent directory
mkdir ~/myagent && cd ~/myagent

# Download latest agent (check for latest version at https://github.com/Microsoft/azure-pipelines-agent/releases)
wget https://vstsagentpackage.azureedge.net/agent/3.236.1/vsts-agent-linux-x64-3.236.1.tar.gz

# Extract
tar zxvf vsts-agent-linux-x64-3.236.1.tar.gz

# Clean up tarball
rm vsts-agent-linux-x64-3.236.1.tar.gz
```

### Step 5: Configure the Agent

```bash
# Run configuration script
./config.sh

# You will be prompted for:
# 1. Server URL: https://dev.azure.com/{your-organization}
# 2. Authentication type: PAT (Personal Access Token)
# 3. Personal Access Token: [paste your PAT]
# 4. Agent pool: Default (or your custom pool name)
# 5. Agent name: boomi-agent-01 (or custom name)
# 6. Work folder: _work (default, press Enter)
# 7. Run as service: Y (yes, recommended)
```

**To create a Personal Access Token (PAT):**
1. In Azure DevOps: Click your profile icon → **Personal access tokens**
2. **+ New Token**
3. Name: `Boomi Agent Token`
4. Organization: Select your organization
5. Scopes: **Agent Pools (Read & manage)**
6. **Create** and **copy the token** (you won't see it again!)

### Step 6: Start the Agent

**Interactive Mode (for testing):**
```bash
./run.sh
```

**As a Service (production):**
```bash
# Install as systemd service
sudo ./svc.sh install azureagent

# Start service
sudo ./svc.sh start

# Check status
sudo ./svc.sh status

# Enable auto-start on boot
sudo systemctl enable vsts.agent.{your-org}.{pool-name}.{agent-name}
```

### Step 7: Verify Agent Connection

1. Go to Azure DevOps → **Project Settings** → **Agent pools**
2. Select your pool (e.g., "Default")
3. **Agents** tab
4. Verify your agent shows as **Online** (green)

### Step 8: Clone Repository to Agent

```bash
# As azureagent user
cd ~

# Clone repository (use HTTPS or SSH)
git clone https://dev.azure.com/{organization}/{project}/_git/{repository}

# Or if using external repo
git clone https://github.com/your-org/boomi-cicd-cli.git
```

### Step 9: Test CLI Scripts

```bash
# Navigate to CLI scripts
cd ~/boomi-cicd-cli/cli/scripts

# Make scripts executable
chmod +x bin/*.sh

# Set test environment variables
export authToken="BOOMI_TOKEN.username:api_token"
export baseURL="https://api.boomi.com/api/rest/v1/YOUR_ACCOUNT_ID/"
export SCRIPTS_HOME="$(pwd)"
export WORKSPACE="$(pwd)/workspace"

# Set mandatory framework variables
export h1="Content-Type: application/json"
export h2="Accept: application/json"
export VERBOSE="false"
export SLEEP_TIMER="0.2"

# Test a simple query
source bin/queryEnvironment.sh env="*" classification="*"

# If successful, you'll see JSON output with your environments
```

### Step 10: Validating the CLI (Automated Tests)
We have included a comprehensive test suite to validate the CLI scripts without connecting to a real Boomi environment. This verifies that JSON payloads are generated correctly and API calls are constructed properly.

To run the full test suite:
```bash
# Navigate to the CLI root
cd ~/boomi-cicd-cli

# Run the test runner
./cli/tests/run_tests.sh
```

**Expected Output:**
```text
TEST: queryEnvironment.sh - Wildcard (*)
PASS: URL construction
PASS: Operator is LIKE for wildcard
...
ALL TESTS PASSED
```

### Step 11: Create Agent Pool (If Needed)

If you want a dedicated pool for Boomi deployments:

1. **Project Settings** → **Agent pools** → **Add pool**
2. Pool type: **Self-hosted**
3. Name: `Boomi-Agents`
4. Grant access permission to all pipelines: ✓ (check)
5. **Create**

Then reconfigure your agent (Step 5) to use this new pool.

---

## Quick Start

```bash
# 1. Agent already set up (see above)

# 2. Repository cloned to agent

# 3. Copy example pipeline
cp ci-templates/azuredevops/examples/dummy-api.yaml my-pipeline.yaml

# 4. Configure variable groups (see below)

# 5. Create pipeline in Azure DevOps pointing to my-pipeline.yaml

# 6. Run pipeline
```

---

## Variable Groups Configuration

Create two variable groups in **Azure DevOps** → **Pipelines** → **Library**:

### Variable Group: `boomicicd`

Core Boomi API credentials:

| Variable | Value | Secret | Example |
|----------|-------|--------|---------|
| `authToken` | `BOOMI_TOKEN.username:api_token` | ✅ Yes | `BOOMI_TOKEN.john.doe:sk-a1b2c3d4...` |
| `baseURL` | Boomi API base URL | ❌ No | `https://api.boomi.com/api/rest/v1/acme-ABC123/` |

> **Note:** `authToken` is **NOT** Base64 encoded. Use plain text format: `ACCOUNT.username:token`

### Variable Group: `boomiruntime` 

Environment-specific configuration:

| Variable | Description | Example |
|----------|-------------|---------|
| `development_apim_envname` | Development environment name | `Development` or `Dev-QA` |
| `testing_apim_envname` | UAT/Testing environment name | `UAT` or `Testing` |
| `production_apim_envname` | Production environment name | `Production` or `Prod` |
| `testing_apim_atom` | Testing atom name | `Test-Atom-01` |
| `production_apim_atom` | Production atom name | `Prod-Atom-01` |

**To create variable groups:**
1. Navigate to **Pipelines** → **Library** → **+ Variable group**
2. Name: `boomicicd`
3. Add variables listed above
4. Click **Save**
5. Repeat for `boomiruntime`

### Advanced Configuration (Optional)

The following variables are optional and can be added for advanced features:

#### Core Optional Variables

These can be added to the `boomicicd` variable group if needed:

| Variable | Description | Default/Example | When to Use |
|----------|-------------|-----------------|-------------|
| `accountId` | Boomi account ID | `acme-ABC123` | Already in `baseURL`, but some scripts may reference it directly |
| `h1` | HTTP Content-Type header | `Content-Type: application/json` | Usually auto-set by templates, override if needed |
| `h2` | HTTP Accept header | `Accept: application/json` | Usually auto-set by templates, override if needed |

#### Performance Tuning Variables

Add these to your pipeline YAML if you need to adjust performance:

```yaml
variables:
  - group: boomicicd
  - group: boomiruntime
  - name: SLEEP_TIMER
    value: '0.2'  # API rate limiting (default: 0.2 = 5 requests/second)
  - name: VERBOSE
    value: 'false'  # Set to 'true' for detailed debugging output
```

**When to adjust:**
- **`SLEEP_TIMER`**: Increase to `0.5` or `1.0` if hitting Boomi API rate limits (429 errors)
- **`VERBOSE`**: Set to `'true'` when troubleshooting pipeline failures

#### Git Integration Variables

For tracking component XML changes in Git repository:

**Create a new variable group: `boomi-git-config`**

| Variable | Description | Example |
|----------|-------------|---------|
| `gitRepoURL` | Git repository URL for component XML | `https://dev.azure.com/org/project/_git/boomi-components` |
| `gitUserName` | Git commit author name | `Azure Pipeline` or `Boomi CI Bot` |
| `gitUserEmail` | Git commit author email | `pipeline@company.com` |
| `gitRepoName` | Repository folder name | `boomi-components` |
| `gitOption` | Clone mode | `CLONE` (clone repo) or leave empty (use tags) |

**Add to your pipeline:**
```yaml
variables:
  - group: boomicicd
  - group: boomiruntime
  - group: boomi-git-config  # Add this

# Then use branchName parameter in templates
- template: ci-templates/azuredevops/pipelines/deploy_packages.yaml
  parameters:
    componentIds: 'comp-id-1'
    branchName: 'main'  # Now supported with Git config
```

**What this enables:**
- Component XML is extracted and committed to Git repository
- Track changes over time
- Version control for Boomi components
- Enables Boomi branch/merge feature integration

#### SonarQube Integration Variables

For code quality scanning of Boomi component XML:

**Create a new variable group: `boomi-sonar-config`**

| Variable | Description | Example | Secret |
|----------|-------------|---------|--------|
| `SONAR_HOST` | Path to sonar-scanner binary | `/usr/local/bin/sonar-scanner` | ❌ |
| `sonarHostURL` | SonarQube server URL | `https://sonar.company.com` | ❌ |
| `sonarHostToken` | SonarQube authentication token | `squ_abc123...` | ✅ Yes |
| `sonarProjectKey` | SonarQube project identifier | `BoomiProject` | ❌ |
| `sonarRulesFile` | Path to Boomi rules file | `conf/BoomiSonarRules.xml` | ❌ |

**Prerequisites:**
- SonarQube server accessible from agent
- `sonar-scanner` installed on self-hosted agent
- SonarQube project created with appropriate rules

**Add to your pipeline:**
```yaml
variables:
  - group: boomicicd
  - group: boomiruntime
  - group: boomi-sonar-config  # Add this

# SonarQube scanning happens automatically during package creation
# if Git integration is also enabled
```

**What this enables:**
- Automated code quality analysis
- XML validation and best practices checking
- Integration with SonarQube dashboards
- Quality gates for deployments

---

## Available Templates

### 🌟 Recommended: Build-Once-Deploy-Many

Production-ready templates implementing the build-once-deploy-many pattern:

| Template | Purpose | Documentation |
|----------|---------|---------------|
| `base_build_approval_deploy.yaml` | ✅ **RECOMMENDED** - Complete multi-stage pipeline with approval gates | [BUILD_ONCE_PATTERN.md](BUILD_ONCE_PATTERN.md) |
| `create_packages.yaml` | Build package once, export packageId | [BUILD_ONCE_PATTERN.md](BUILD_ONCE_PATTERN.md) |
| `deploy_packages_byId.yaml` | Deploy pre-built package by ID | [BUILD_ONCE_PATTERN.md](BUILD_ONCE_PATTERN.md) |
| `undeploy_packages_byId.yaml` | Undeploy package by ID | [BUILD_ONCE_PATTERN.md](BUILD_ONCE_PATTERN.md) |

> **📖 For production deployments, see the complete [Build-Once-Deploy-Many Guide](BUILD_ONCE_PATTERN.md)**

### Quick Deploy Templates

For development and ad-hoc deployments:

| Template | Purpose | Note |
|----------|---------|------|
| `deploy_packages.yaml` | Create and deploy package | ⚠️ Builds NEW package each time |
| `undeploy_packages.yaml` | Undeploy packages | By component ID |

### Utility Templates

Supporting templates for specialized operations:

| Template | Purpose |
|----------|---------|
| `get_components.yaml` | Retrieve component IDs from Boomi |
| `execute_processes.yaml` | Execute processes on atom |
| `validate_processes.yaml` | Validate execution results |
| `call_api.yaml` | Run Postman collections (API testing) |
| `call_secretmanager.yaml` | Retrieve secrets from Azure Key Vault / AWS Secrets Manager |
| `retrieve_extensions.yaml` | Get environment extensions |
| `update_extensions.yaml` | Update environment extensions |
| `clean_up.yaml` | Cleanup temporary files |

---

## Managing Templates in Azure DevOps

Before creating a pipeline, you need to decide how to host these templates. There are two common strategies:

### Strategy A: Central Repository (Recommended)
Host this `boomi-cicd-cli` codebase as a dedicated repository (e.g., named `boomi-cicd-cli`) in your Azure DevOps project. Your integration pipelines (in other repos) will reference it remotely.

**Pros:**
- Update templates once, update everywhere
- Cleaner integration repositories
- Version control for your CI/CD logic

### Strategy B: Single Repository
Copy the `ci-templates` and `cli` directories directly into your integration project's repository.

**Pros:**
- Simple to start
- No cross-repo permissions needed
**Cons:**
- Hard to maintain updates across multiple projects

---

## Creating Your First Pipeline

This guide follows **Strategy A (Central Repository)** as it is the best practice for scalability.

### Step 1: Push CLI to Azure DevOps
1. Create a new repository in Azure DevOps named `boomi-cicd-cli`.
2. Push this entire codebase to that repository.
   ```bash
   git remote add azure https://dev.azure.com/{org}/{project}/_git/boomi-cicd-cli
   git push -u azure main
   ```

### Step 2: Create Integration Pipeline
In your Boomi integration repository (where your process logic might ideally live, or just a repo for pipelines):

1. Create a file named `azure-pipelines.yml`.
2. Paste the following configuration:

```yaml
# azure-pipelines.yml

# 1. Define resources to access the CLI templates
resources:
  repositories:
    - repository: templates
      type: git
      name: YourProjectName/boomi-cicd-cli # <--- CHANGE THIS to your properties
      ref: main

trigger:
  - main

pool:
  name: 'Default' # Ensure this matches your Self-Hosted Agent pool

# 2. Extend the "Build-Once-Deploy-Many" template
extends:
  template: ci-templates/azuredevops/pipelines/base_build_approval_deploy.yaml@templates
  parameters:
    packageName: 'My-Boomi-Process-Pkg'
    packageVersion: '1.0.$(Build.BuildId)'
    
    # 3. Define the component IDs to package (Find via queryProcess.sh or AtomSphere)
    componentIds: '4d5e6f7g-8h9i-0j1k-2l3m-4n5o6p7q8r9s' 
    
    # 4. Enable deployments
    deployToQA: true
    deployToUAT: true
    deployToProd: true
    
    # 5. Add deployment notes
    notes: 'Automated release via Azure DevOps'
```

### Step 3: Register Pipeline
1. Go to **Azure DevOps** -> **Pipelines** -> **New pipeline**.
2. Select **Azure Repos Git**.
3. Select your **Integration Repository**.
4. Select **Existing Azure Pipelines YAML file**.
5. Path: `/azure-pipelines.yml`.
6. Click **Run**.

---

### Alternative: Method 2 (Single Repository)

If you prefer to copy the template files directly into your project repository (Strategy B), follow these examples.

#### Option A: Full Production Pipeline (Build-Once Pattern)

**1. Copy the example:**
```bash
cp ci-templates/azuredevops/examples/dummy-api.yaml my-api-pipeline.yaml
```

**2. Edit `my-api-pipeline.yaml`:**
```yaml
trigger:
  - main

pool:
  name: 'Default'  # Your agent pool

extends:
  template: ci-templates/azuredevops/pipelines/base_build_approval_deploy.yaml
  parameters:
    packageName: 'my-api'
    componentIds: 'comp-id-1,comp-id-2'  # Find with queryProcess.sh
    deployToQA: true
    deployToUAT: true
    deployToProd: true
```

**3. Find your component IDs:**
```bash
# From your local machine
export authToken="BOOMI_ACCOUNT.username:token"
export baseURL="https://api.boomi.com/api/rest/v1/ACCOUNT_ID/"
export SCRIPTS_HOME="$(pwd)/cli/scripts"
export WORKSPACE="$(pwd)/workspace"
export h1="Content-Type: application/json"
export h2="Accept: application/json"
export VERBOSE="false"
export SLEEP_TIMER="0.2"

cd $SCRIPTS_HOME
source bin/queryProcess.sh processName="MyProcessName"
# Copy the componentId from output
```

**4. Register Pipeline:**
Follow the same "Register Pipeline" steps as above, pointing to `my-api-pipeline.yaml`.

#### Option B: Simple Development Pipeline

```yaml
trigger:
  - develop

pool:
  name: 'Default'

variables:
  - group: boomicicd
  - group: boomiruntime
  - name: SCRIPTS_HOME
    value: $(Build.SourcesDirectory)/cli/scripts
  - name: WORKSPACE
    value: $(Build.SourcesDirectory)/workspace

steps:
  - script: |
      mkdir -p $(WORKSPACE)
      chmod +x $(SCRIPTS_HOME)/bin/*.sh
      chmod +x $(Build.SourcesDirectory)/ci-templates/azuredevops/pipelines/*.sh
    displayName: 'Prepare Environment'

  - template: ci-templates/azuredevops/pipelines/deploy_packages.yaml
    parameters:
      packageName: 'dev-package'
      packageVersion: '$(Build.BuildNumber)'
      componentIds: 'comp-id-1,comp-id-2'
      env: $(development_apim_envname)
      notes: 'Development deployment'
```

---

## Common Patterns

### Deploy Specific Components by ID

```yaml
- template: ci-templates/azuredevops/pipelines/deploy_packages.yaml
  parameters:
    componentIds: 'abc-123,def-456,ghi-789'
    env: $(testing_apim_envname)
    packageVersion: '$(Build.BuildNumber)'
    notes: 'UAT deployment'
```

### Deploy by Process Names

```yaml
- template: ci-templates/azuredevops/pipelines/deploy_packages.yaml
  parameters:
    processNames: 'ProcessA,ProcessB,ProcessC'
    env: $(development_apim_envname)
    packageVersion: '1.2.3'
```

### Deploy with Branch/Merge Support

```yaml
- template: ci-templates/azuredevops/pipelines/deploy_packages.yaml
  parameters:
    componentIds: 'comp-id-1'
    branchName: 'feature/new-integration'  # Boomi branch name
    env: $(development_apim_envname)
    packageVersion: '$(Build.BuildNumber)'
```

### Execute Process After Deployment

```yaml
# Deploy packages
- template: ci-templates/azuredevops/pipelines/deploy_packages.yaml
  parameters:
    componentIds: 'comp-id-1'
    env: $(testing_apim_envname)
    packageVersion: '$(Build.BuildNumber)'

# Execute process for validation
- template: ci-templates/azuredevops/pipelines/execute_processes.yaml
  parameters:
    atomName: $(testing_apim_atom)
    atomType: 'ATOM'
    processName: 'Validation_Process'
```

---

## Approval Gates Setup

For production deployments, configure approval gates to ensure controlled releases.

### Quick Setup (5 minutes)

**1. Create Environments:**
- **Pipelines** → **Environments** → **New environment**
- Create: `UAT` and `Production`

**2. Add Approvals to Production:**
- Go to **Production** environment
- **⋮** → **Approvals and checks** → **Approvals**
- Add approvers (users or Azure AD groups)
- Set minimum number of approvers (recommended: 2 for production)
- Set timeout: 24-48 hours
- **Create**

**3. Optional: Add Checks:**
- **Business hours** - Restrict to 9 AM - 5 PM Mon-Fri
- **Branch control** - Only allow `main` and `release/*` branches
- **Required template** - Enforce use of approved templates

### Role-Based Approval Groups

**Create Azure AD Groups:**
1. **Azure Active Directory** → **Groups** → **New group**
2. Create groups:
   - `Boomi-QA-Approvers`
   - `Boomi-UAT-Approvers`
   - `Boomi-Prod-Approvers`
3. Add members to each group

**Assign to Environments:**
- Production environment → **Approvals**
- Add `Boomi-Prod-Approvers` as approver
- Require 2+ approvals for critical systems

> **📖 For detailed approval configuration, see [BUILD_ONCE_PATTERN.md § "Setting Up Approval Gates"](BUILD_ONCE_PATTERN.md#setting-up-approval-gates)**

---

## Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `jq: command not found` | jq not installed on agent | Install: `sudo apt-get install jq` or `sudo yum install jq` |
| `Permission denied` | Scripts not executable | Run: `chmod +x cli/scripts/bin/*.sh` |
| `401 Unauthorized` | Invalid authToken | Verify format: `ACCOUNT.username:token` (NOT Base64) |
| `404 Not Found` | Invalid baseURL or component not found | Check baseURL has trailing `/` |
| `componentId is null` | Process name not found | Verify exact process name (case-sensitive) |
| `SCRIPTS_HOME not set` | Variable not defined | Add to pipeline variables |

### Debugging Steps

**1. Check variable values:**
```yaml
- script: |
    echo "SCRIPTS_HOME: $SCRIPTS_HOME"
    echo "WORKSPACE: $WORKSPACE"
    echo "baseURL: $baseURL"
  displayName: 'Debug Variables'
```

**2. Inspect API responses:**
```yaml
- script: |
    cat $(WORKSPACE)/out.json | jq .
  displayName: 'Show API Response'
  condition: always()
```

**3. Enable verbose mode:**
```yaml
- script: |
    export VERBOSE="true"
    source $(SCRIPTS_HOME)/bin/deployPackages.sh ...
  displayName: 'Deploy with Verbose Logging'
```

### Agent Issues

**Self-hosted agent missing dependencies:**
```bash
# On the agent machine
sudo apt-get update
sudo apt-get install -y jq curl bash git

# Verify
jq --version
curl --version
bash --version
```

**Microsoft-hosted agent:**
- Ubuntu agents have jq and curl pre-installed
- Use `ubuntu-latest` pool

---

## Next Steps

- **Production Deployments** → [Build-Once-Deploy-Many Guide](BUILD_ONCE_PATTERN.md)
- **Complete CLI Reference** → [CLI Reference](../../../docs/CLI_REFERENCE.md)
- **Example Workflows** → [Examples Directory](../examples/)
- **Architecture Details** → [Architecture Guide](../../../docs/ARCHITECTURE.md)

---

## Additional Resources

- [Boomi AtomSphere API Documentation](https://help.boomi.com/bundle/integration/page/r-atm-AtomSphere_API_6730e8e4-b2db-4e94-a653-82ae1d05c78e.html)
- [Azure DevOps YAML Schema](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Azure DevOps Environments](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/environments)
