# GitHub Actions Setup Guide

This guide shows you how to set up the Boomi CI/CD CLI with GitHub Actions.

## Prerequisites

1. **GitHub Repository**
2. **GitHub Actions enabled** (available on all GitHub plans)
3. **Boomi Account Credentials**

## Setup Steps

### 1. Configure GitHub Secrets

Navigate to **Repository** → **Settings** → **Secrets and variables** → **Actions**

Create the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `BOOMI_AUTH_TOKEN` | Base64(`ACCOUNT.user:token`) | Boomi API authentication |
| `BOOMI_BASE_URL` | `https://api.boomi.com/api/rest/v1/ACCOUNT_ID/` | Boomi API base URL |

To generate the auth token:
```bash
echo -n "BOOMI_ACCOUNT.username:api_token" | base64
```

### 2. Add Workflow to Repository

Copy the workflow file to your repository:

```bash
mkdir -p .github/workflows
cp ci-templates/github-actions/workflows/deploy-packages.yml .github/workflows/
```

### 3. Configure Environment Variables (Optional)

For environment-specific deployments, create GitHub Environments:

1. Go to **Settings** → **Environments**
2. Create environments: `Development`, `Testing`, `Production`
3. Add environment-specific secrets or variables:
   - `ENVIRONMENT_ID` - Boomi environment ID
   - `ATOM_NAME` - Target atom name

### 4. Trigger Deployment

#### Manual Trigger (Workflow Dispatch)

1. Go to **Actions** tab
2. Select **Boomi Deploy** workflow
3. Click **Run workflow**
4. Fill in parameters:
   - **componentIds**: `comp-123,comp-456`
   - **environment**: Select from dropdown
   - **packageVersion**: `1.0.0`
   - **notes**: Deployment notes
5. Click **Run workflow**

#### Automatic Trigger

The workflow triggers automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main`

### 5. Workflow Examples

#### Simple Deployment

```yaml
name: Deploy to Boomi

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy
        env:
          authToken: ${{ secrets.BOOMI_AUTH_TOKEN }}
          baseURL: ${{ secrets.BOOMI_BASE_URL }}
        run: |
          export SCRIPTS_HOME=${{ github.workspace }}/cli/scripts
          export WORKSPACE=${{ github.workspace }}/workspace
          export componentIds="comp-123,comp-456"
          export env="Production"
          export packageVersion="${{ github.run_number }}"
          mkdir -p $WORKSPACE
          chmod +x cli/scripts/bin/*.sh
          cd ci-templates/github-actions/workflows
          bash -xe ./deploy_packages.sh
```

#### Multi-Environment Workflow

```yaml
name: Multi-Stage Deploy

on:
  push:
    branches: [ develop, release/*, main ]

jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: Development
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Dev
        env:
          authToken: ${{ secrets.BOOMI_AUTH_TOKEN }}
          baseURL: ${{ secrets.BOOMI_BASE_URL }}
          env: ${{ secrets.DEV_ENV_ID }}
        run: |
          # deployment script
  
  deploy-uat:
    if: startsWith(github.ref, 'refs/heads/release/')
    runs-on: ubuntu-latest
    environment: Testing
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to UAT
        env:
          authToken: ${{ secrets.BOOMI_AUTH_TOKEN }}
          baseURL: ${{ secrets.BOOMI_BASE_URL }}
          env: ${{ secrets.UAT_ENV_ID }}
        run: |
          # deployment script
  
  deploy-prod:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: Production
    needs: []
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Production
        env:
          authToken: ${{ secrets.BOOMI_AUTH_TOKEN }}
          baseURL: ${{ secrets.BOOMI_BASE_URL }}
          env: ${{ secrets.PROD_ENV_ID }}
        run: |
          # deployment script
```

#### With Approval Gates

Use GitHub Environments with required reviewers:

```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment:
      name: Production
      url: https://platform.boomi.com
    steps:
      - name: Deploy to Production
        run: |
          # deployment will wait for approval
```

Configure reviewers in **Settings** → **Environments** → **Production** → **Required reviewers**

## Advanced Features

### Matrix Strategy for Multiple Environments

```yaml
jobs:
  deploy:
    strategy:
      matrix:
        environment: [Development, Testing]
    runs-on: ubuntu-latest
    environment: ${{ matrix.environment }}
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to ${{ matrix.environment }}
        env:
          authToken: ${{ secrets.BOOMI_AUTH_TOKEN }}
          env: ${{ secrets[format('{0}_ENV_ID', matrix.environment)] }}
        run: |
          # deployment script
```

### Reusable Workflows

Create `.github/workflows/deploy-reusable.yml`:

```yaml
name: Reusable Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      componentIds:
        required: true
        type: string
    secrets:
      BOOMI_AUTH_TOKEN:
        required: true
      BOOMI_BASE_URL:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        env:
          authToken: ${{ secrets.BOOMI_AUTH_TOKEN }}
          baseURL: ${{ secrets.BOOMI_BASE_URL }}
          componentIds: ${{ inputs.componentIds }}
          env: ${{ inputs.environment }}
        run: |
          # deployment script
```

Call it from another workflow:

```yaml
jobs:
  deploy-dev:
    uses: ./.github/workflows/deploy-reusable.yml
    with:
      environment: Development
      componentIds: comp-1,comp-2
    secrets:
      BOOMI_AUTH_TOKEN: ${{ secrets.BOOMI_AUTH_TOKEN }}
      BOOMI_BASE_URL: ${{ secrets.BOOMI_BASE_URL }}
```

## Troubleshooting

### Error: Dependencies not installed
GitHub Actions runners need jq and curl. Add installation step:
```yaml
- name: Install dependencies
  run: sudo apt-get update && sudo apt-get install -y jq curl
```

### Error: Permission denied
Make scripts executable:
```yaml
- name: Make scripts executable
  run: chmod -R +x cli/scripts/bin/
```

### Error: Secrets not available
Ensure secrets are defined at the repository or environment level, not in the workflow file.

## Next Steps

- Review [CLI Reference](../../docs/CLI_REFERENCE.md) for all available commands
- Explore [Common Workflows](../../examples/common-workflows/) for patterns
- Set up GitHub Environments for approval workflows
