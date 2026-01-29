# GitLab CI/CD Setup Guide

This guide shows you how to set up the Boomi CI/CD CLI with GitLab CI/CD.

## Prerequisites

1. **GitLab Repository** (GitLab.com or self-hosted)
2. **GitLab Runner** configured with:
   - Docker executor (recommended) or Shell executor
   - Access to pull Docker images
3. **Boomi Account Credentials**

## Setup Steps

### 1. Configure CI/CD Variables

Navigate to **Settings** → **CI/CD** → **Variables** in your GitLab project

Add the following variables:

| Variable Key | Value | Protected | Masked |
|--------------|-------|-----------|--------|
| `BOOMI_AUTH_TOKEN` | Base64(`ACCOUNT.user:token`) | ✓ | ✓ |
| `BOOMI_BASE_URL` | `https://api.boomi.com/api/rest/v1/ACCOUNT_ID/` | ✓ | ✓ |
| `COMPONENT_IDS` | `comp-1,comp-2` | | |
| `DEV_ENV_ID` | Development environment ID | | |
| `UAT_ENV_ID` | UAT environment ID | | |
| `PROD_ENV_ID` | Production environment ID | ✓ | |

**Protected variables** are only available on protected branches (main, production, etc.)

### 2. Add Pipeline Configuration

Copy the GitLab CI configuration to your repository:

```bash
cp ci-templates/gitlab-ci/pipelines/.gitlab-ci.yml .gitlab-ci.yml
```

### 3. Configure Environments

GitLab Environments provide deployment tracking and rollback capabilities:

1. Go to **Deployments** → **Environments**
2. Environments will be created automatically on first deployment
3. Optionally, configure environment-specific variables

### 4. Basic Configuration

```yaml
variables:
  SCRIPTS_HOME: "$CI_PROJECT_DIR/cli/scripts"
  WORKSPACE: "$CI_PROJECT_DIR/workspace"

stages:
  - deploy

deploy:
  image: ubuntu:latest
  stage: deploy
  before_script:
    - apt-get update && apt-get install -y jq curl bash
    - mkdir -p $WORKSPACE
    - chmod +x cli/scripts/bin/*.sh
  script:
    - |
      export authToken="${BOOMI_AUTH_TOKEN}"
      export baseURL="${BOOMI_BASE_URL}"
      export componentIds="${COMPONENT_IDS}"
      export env="Production"
      export packageVersion="${CI_PIPELINE_IID}"
      export notes="Deployed via GitLab CI"
      export SCRIPTS_HOME="${SCRIPTS_HOME}"
      export WORKSPACE="${WORKSPACE}"
      export h1="Content-Type: application/json"
      export h2="Accept: application/json"
      export VERBOSE="true"
      cd ci-templates/gitlab-ci/pipelines
      bash -xe ./deploy_packages.sh
  only:
    - main
```

### 5. Multi-Environment Pipeline

```yaml
stages:
  - deploy-dev
  - deploy-uat
  - deploy-prod

deploy:dev:
  stage: deploy-dev
  image: ubuntu:latest
  environment:
    name: development
  script:
    - export env="${DEV_ENV_ID}"
    # ... deployment script
  only:
    - develop

deploy:uat:
  stage: deploy-uat
  image: ubuntu:latest
  environment:
    name: uat
  script:
    - export env="${UAT_ENV_ID}"
    # ... deployment script
  only:
    - /^release\/.*$/

deploy:prod:
  stage: deploy-prod
  image: ubuntu:latest
  environment:
    name: production
    url: https://platform.boomi.com
  when: manual
  script:
    - export env="${PROD_ENV_ID}"
    # ... deployment script
  only:
    - main
```

## Advanced Features

### Using Templates and Includes

Create reusable templates:

**`.gitlab/ci/deploy-template.yml`**:
```yaml
.deploy_base:
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y jq curl bash
    - mkdir -p $WORKSPACE
    - chmod +x cli/scripts/bin/*.sh
  script:
    - |
      export authToken="${BOOMI_AUTH_TOKEN}"
      export baseURL="${BOOMI_BASE_URL}"
      # ... export other variables
      cd ci-templates/gitlab-ci/pipelines
      bash -xe ./deploy_packages.sh
```

**`.gitlab-ci.yml`**:
```yaml
include:
  - local: '.gitlab/ci/deploy-template.yml'

deploy:prod:
  extends: .deploy_base
  environment:
    name: production
  variables:
    ENVIRONMENT: $PROD_ENV_ID
  only:
    - main
```

### Dynamic Environments

For feature branch deployments:

```yaml
deploy:feature:
  stage: deploy
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    on_stop: cleanup:feature
  script:
    - export env="${FEATURE_ENV_ID}"
    # ... deployment script
  only:
    - branches
  except:
    - main
    - develop

cleanup:feature:
  stage: deploy
  when: manual
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  script:
    - echo "Cleanup feature deployment"
    # Add undeploy logic
```

### Scheduled Pipelines

Create scheduled pipelines in **CI/CD** → **Schedules**:

```yaml
deploy:nightly:
  only:
    - schedules
  variables:
    DEPLOYMENT_TYPE: "nightly"
  script:
    # ... deployment script
```

### Parent-Child Pipelines

For complex workflows:

**`.gitlab-ci.yml`**:
```yaml
trigger:deploy:
  stage: deploy
  trigger:
    include: ci-templates/gitlab-ci/pipelines/.gitlab-ci-deploy.yml
    strategy: depend
```

### Deployment Approvals

**GitLab Premium/Ultimate**: Use Protected Environments with approval rules

**Community Edition**: Use `when: manual` for manual approval

## CI/CD Templates

### Deploy with Rollback

```yaml
deploy:prod:
  stage: deploy
  environment:
    name: production
    url: https://platform.boomi.com
    on_stop: rollback:prod
  script:
    # deployment script
  only:
    - main

rollback:prod:
  stage: deploy
  environment:
    name: production
    action: stop
  when: manual
  script:
    # rollback script using undeploy
  only:
    - main
```

### Multi-Project Pipeline

Trigger deployments across multiple projects:

```yaml
trigger:downstream:
  stage: deploy
  trigger:
    project: your-group/another-boomi-project
    branch: main
  only:
    - main
```

## Troubleshooting

### Error: Runner cannot pull Docker image
Configure runner to use specific Docker images or use shell executor:
```yaml
deploy:
  tags:
    - shell
```

### Error: Scripts not executable
Ensure before_script sets permissions:
```yaml
before_script:
  - chmod -R +x cli/scripts/bin/
```

### Error: Variables not available
Check variable scope:
- Unprotected variables work on all branches
- Protected variables only work on protected branches
- Masked variables hide sensitive data in logs

### Debugging Pipelines
Enable debug logging:
```yaml
variables:
  CI_DEBUG_TRACE: "true"
```

Or enable for specific jobs:
```yaml
deploy:
  variables:
    CI_DEBUG_TRACE: "true"
```

## Best Practices

1. **Use Protected Variables** for production credentials
2. **Enable Manual Approval** for production (`when: manual`)
3. **Store Artifacts** for audit trail
4. **Use Environments** for deployment tracking
5. **Tag Runners** appropriately for security
6. **Use Templates** for reusability

## Next Steps

- Review [CLI Reference](../../docs/CLI_REFERENCE.md) for all commands
- Explore [Common Workflows](../../examples/common-workflows/) for patterns
- Set up GitLab Environments for deployment tracking
- Configure deployment approvals (GitLab Premium)
