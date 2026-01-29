# CircleCI Setup Guide

This guide shows you how to set up the Boomi CI/CD CLI with CircleCI.

## Prerequisites

1. **CircleCI Account** connected to your Git provider (GitHub, Bitbucket, GitLab)
2. **Project added to CircleCI**
3. **Boomi Account Credentials**

## Setup Steps

### 1. Configure Environment Variables

In CircleCI, navigate to **Project Settings** → **Environment Variables**

Add the following variables:

| Variable Name | Value | Description |
|---------------|-------|-------------|
| `BOOMI_AUTH_TOKEN` | Base64(`ACCOUNT.user:token`) | Boomi API authentication |
| `BOOMI_BASE_URL` | `https://api.boomi.com/api/rest/v1/ACCOUNT_ID/` | Boomi API endpoint |
| `COMPONENT_IDS` | `comp-1,comp-2` | Component IDs to deploy |

Optionally, add environment-specific variables:
- `DEV_ENV_ID` - Development environment ID
- `UAT_ENV_ID` - UAT environment ID
- `PROD_ENV_ID` - Production environment ID

### 2. Add Configuration to Repository

Copy the CircleCI config to your repository:

```bash
mkdir -p .circleci
cp ci-templates/circleci/config/config.yml .circleci/config.yml
```

### 3. Configure Workflows

The example configuration includes three workflows:

- **develop** branch → Deploy to Development
- **release/** branches → Deploy to UAT/Testing
- **main** branch → Deploy to Production (with approval)

### 4. Basic Configuration

```yaml
version: 2.1

jobs:
  deploy:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      
      - run:
          name: Install dependencies
          command: |
            sudo apt-get update
            sudo apt-get install -y jq curl
      
      - run:
          name: Setup workspace
          command: |
            mkdir -p workspace
            chmod +x cli/scripts/bin/*.sh
      
      - run:
          name: Deploy to Boomi
          command: |
            export SCRIPTS_HOME=${PWD}/cli/scripts
            export WORKSPACE=${PWD}/workspace
            export authToken="${BOOMI_AUTH_TOKEN}"
            export baseURL="${BOOMI_BASE_URL}"
            export componentIds="${COMPONENT_IDS}"
            export env="Production"
            export packageVersion="${CIRCLE_BUILD_NUM}"
            export notes="Deployed via CircleCI"
            export h1="Content-Type: application/json"
            export h2="Accept: application/json"
            export VERBOSE="true"
            
            cd ci-templates/circleci/config
            bash -xe ./deploy_packages.sh

workflows:
  deploy:
    jobs:
      - deploy:
          filters:
            branches:
              only: main
```

### 5. Using Contexts for Secrets

CircleCI Contexts allow you to share secrets across projects:

1. Go to **Organization Settings** → **Contexts**
2. Create a context (e.g., `boomi-production`)
3. Add environment variables to the context
4. Reference in your workflow:

```yaml
workflows:
  deploy-with-context:
    jobs:
      - deploy:
          context: boomi-production
          filters:
            branches:
              only: main
```

## Advanced Patterns

### Multi-Environment with Approval

```yaml
workflows:
  deploy-pipeline:
    jobs:
      # Deploy to Dev automatically
      - deploy-dev:
          filters:
            branches:
              only: develop
      
      # Deploy to UAT with approval
      - approve-uat:
          type: approval
          filters:
            branches:
              only: /release\/.*/
      
      - deploy-uat:
          requires:
            - approve-uat
          filters:
            branches:
              only: /release\/.*/
      
      # Deploy to Prod with approval
      - approve-prod:
          type: approval
          filters:
            branches:
              only: main
      
      - deploy-prod:
          requires:
            - approve-prod
          filters:
            branches:
              only: main
```

### Using Orbs

Create a custom orb for reusability:

```yaml
version: 2.1

orbs:
  boomi: your-org/boomi-deploy@1.0.0

workflows:
  deploy:
    jobs:
      - boomi/deploy:
          environment: Production
          component-ids: comp-1,comp-2
```

### Parameterized Workflows

Use pipeline parameters for manual triggers:

```yaml
version: 2.1

parameters:
  deploy-environment:
    type: string
    default: "Development"
  component-ids:
    type: string
    default: ""

workflows:
  deploy:
    jobs:
      - deploy:
          environment: << pipeline.parameters.deploy-environment >>
          component_ids: << pipeline.parameters.component-ids >>
```

Trigger via API:
```bash
curl -X POST \
  https://circleci.com/api/v2/project/github/your-org/your-repo/pipeline \
  -H 'Circle-Token: YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "parameters": {
      "deploy-environment": "Production",
      "component-ids": "comp-1,comp-2"
    }
  }'
```

### Scheduled Deployments

```yaml
workflows:
  nightly-deploy:
    triggers:
      - schedule:
          cron: "0 0 * * *"
          filters:
            branches:
              only: develop
    jobs:
      - deploy-dev
```

## Troubleshooting

### Error: Dependencies not found
Ensure your base image has apt-get or use a different image:
```yaml
docker:
  - image: cimg/base:stable  # Has apt-get
```

### Error: Permission denied
Add step to make scripts executable:
```yaml
- run:
    name: Make scripts executable
    command: chmod -R +x cli/scripts/bin/
```

### Error: Cannot find SCRIPTS_HOME
Ensure you're using `${PWD}` or `${CIRCLE_WORKING_DIRECTORY}`:
```yaml
export SCRIPTS_HOME=${CIRCLE_WORKING_DIRECTORY}/cli/scripts
```

### Debugging
Enable SSH and connect to debug:
```yaml
- run:
    name: Enable SSH
    command: echo "SSH Debug enabled"
```

Then rerun the job with SSH enabled from the CircleCI UI.

## Best Practices

1. **Use Contexts** for production secrets
2. **Add Approvals** for production deployments
3. **Store Artifacts** for audit trails
4. **Use Caching** for dependencies
5. **Implement Retries** for flaky network calls

## Next Steps

- Review [CLI Reference](../../docs/CLI_REFERENCE.md) for all commands
- Explore [Common Workflows](../../examples/common-workflows/) for patterns
- Set up CircleCI Insights for monitoring
