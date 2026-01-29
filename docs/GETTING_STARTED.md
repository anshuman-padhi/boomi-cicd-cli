# Getting Started with Boomi CI/CD CLI

This guide will walk you through setting up and using the Boomi CI/CD CLI framework for the first time.

## What You'll Learn

- Installing required dependencies
- Configuring Boomi authentication
- Running your first deployment
- Choosing a CI/CD platform

## Prerequisites

Before you begin, you'll need:

1. **Boomi Account** with API access
2. **Boomi API Token** - Generate from AtomSphere Platform
3. **Linux/macOS/WSL environment** with Bash 4.0+
4. **Admin or deployment permissions** in your Boomi account

## Step 1: Install Dependencies

The CLI requires three standard tools:

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y jq curl bash git
```

### RHEL/CentOS
```bash
sudo yum install -y jq curl bash git
```

### macOS
```bash
brew install jq curl bash git
```

### Verify Installation
```bash
jq --version    # Should show jq-1.6 or higher
curl --version  # Should show curl 7.x or higher
bash --version  # Should show 4.0 or higher
```

## Step 2: Clone the Repository

```bash
cd /path/to/your/projects
git clone https://github.com/YOUR_ORG/boomi-cicd-cli.git
cd boomi-cicd-cli
```

Make scripts executable:
```bash
chmod +x cli/scripts/bin/*.sh
```

## Step 3: Get Your Boomi API Credentials

### 3.1 Generate API Token

1. Log in to Boomi AtomSphere Platform
2. Navigate to **Settings** → **API Management** → **API Tokens**
3. Click **Generate Token**
4. Copy and save your token securely

### 3.2 Find Your Account ID

Your account ID is in the URL when logged into AtomSphere:
```
https://platform.boomi.com/Account/<YOUR_ACCOUNT_ID>/...
```

### 3.3 Create Authentication Token

Encode your credentials:

```bash
# Replace with your actual values
ACCOUNT_ID="yourcompany-ABC123"
USERNAME="your.username"
API_TOKEN="your-api-token-here"

# Create the auth token
authToken=$(echo -n "${ACCOUNT_ID}.${USERNAME}:${API_TOKEN}" | base64)
echo "Your authToken: ${authToken}"
```

Save this token - you'll use it in every deployment.

## Step 4: Configure Environment Variables

Create a configuration file for easy reuse:

```bash
cat > ~/.boomi-cli-config << 'EOF'
# Boomi CLI Configuration
export authToken="<YOUR_BASE64_TOKEN>"
export baseURL="https://api.boomi.com/api/rest/v1/<YOUR_ACCOUNT_ID>/"
export SCRIPTS_HOME="/path/to/boomi-cicd-cli/cli/scripts"
export WORKSPACE="/path/to/boomi-cicd-cli/workspace"
export h1="Content-Type: application/json"
export h2="Accept: application/json"
export VERBOSE="true"
export SLEEP_TIMER="0.2"
EOF
```

Load the configuration:
```bash
source ~/.boomi-cli-config
```

## Step 5: Test the CLI

Let's verify everything works by querying your environments:

```bash
cd boomi-cicd-cli/cli/scripts
source bin/queryEnvironment.sh classification="*"
```

If successful, you'll see JSON output with your environments!

## Step 6: Deploy Your First Package (Manual)

### 6.1 Find Your Component IDs

Query for a process:
```bash
source bin/queryProcess.sh processName="YourProcessName"
```

Note the `componentId` from the output.

### 6.2 Find Your Environment ID

Query environments:
```bash
source bin/queryEnvironment.sh env="Test"
```

Note the `id` of your target environment.

### 6.3 Create and Deploy a Package

```bash
# Set variables
export componentIds="your-component-id-here"
export env="your-env-id-here"
export packageVersion="1.0.0"
export notes="My first CLI deployment"

# Create package and deploy
source bin/deployPackages.sh
```

Watch the logs - you should see your deployment succeed!

## Step 7: Choose Your CI/CD Platform

Now that you've tested manually, set up automated deployments:

### For Azure DevOps Users
1. Read [Azure DevOps Setup Guide](../ci-templates/azuredevops/docs/SETUP.md)
2. Copy example pipeline:
   ```bash
   cp ci-templates/azuredevops/examples/azure-pipelines.yml .
   ```
3. Configure variable groups
4. Push to Azure DevOps

### For Jenkins Users
1. Read [Jenkins Setup Guide](../ci-templates/jenkins/docs/SETUP.md)
2. Copy Jenkinsfile:
   ```bash
   cp ci-templates/jenkins/pipelines/deploy_packages.jenkinsfile Jenkinsfile
   ```
3. Configure credentials in Jenkins
4. Create pipeline job

### For GitHub Actions Users
1. Read [GitHub Actions Setup Guide](../ci-templates/github-actions/docs/SETUP.md)
2. Copy workflow:
   ```bash
   mkdir -p .github/workflows
   cp ci-templates/github-actions/workflows/deploy-packages.yml .github/workflows/
   ```
3. Add secrets to repository
4. Push to GitHub

### For Other Platforms
See the [main README](../README.md) for links to all platform guides.

## Next Steps

### Learn More
- **[CLI Reference](CLI_REFERENCE.md)** - All available commands and parameters
- **[Architecture](ARCHITECTURE.md)** - How the framework works
- **[Common Workflows](../examples/common-workflows/)** - Deployment patterns

### Advanced Topics
- **Multi-Environment Deployments** - Dev → QA → Prod pipelines
- **Environment Extensions** - Managing connection strings and secrets
- **Process Execution** - Running and validating processes
- **API Testing** - Integration with Postman collections
- **Rollback Strategies** - Undeploying packages

## Troubleshooting

### Error: Authentication failed
```bash
# Verify your token format
echo -n "ACCOUNT.username:token" | base64

# Test authentication
curl -u "$authToken" "$baseURL/Environment"
```

### Error: Component not found
```bash
# List all processes
source bin/publishProcess.sh

# Search by name
source bin/queryProcess.sh processName="*"
```

### Error: Permission denied
```bash
# Make scripts executable
chmod -R +x cli/scripts/bin/
```

### Error: SCRIPTS_HOME not set
```bash
# Set it explicitly
export SCRIPTS_HOME="$(pwd)/cli/scripts"
```

## Best Practices

1. **Version Your Packages** - Use meaningful version numbers
2. **Document Deployments** - Use descriptive notes
3. **Test in Lower Environments** - Deploy to Dev/QA first
4. **Use Git Tags** - Tag releases for traceability
5. **Store Credentials Securely** - Never commit tokens to Git

## Getting Help

- Check the [CLI Reference](CLI_REFERENCE.md) for command documentation
- Review platform-specific guides in `ci-templates/<platform>/docs/`
- See [Common Workflows](../examples/common-workflows/) for examples

