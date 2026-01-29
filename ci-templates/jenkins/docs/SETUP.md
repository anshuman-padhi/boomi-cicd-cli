# Jenkins Setup Guide

This guide shows you how to set up the Boomi CI/CD CLI with Jenkins.

## Prerequisites

1. **Jenkins Server** (2.x or higher)
2. **Jenkins Agent** with:
   - Bash (4.0+)
   - curl
   - jq
   - Git
3. **Boomi Account Credentials**
4. **Jenkins Plugins** (recommended):
   - Pipeline
   - Credentials Binding
   - Mask Passwords

## Setup Steps

### 1. Configure Jenkins Credentials

Navigate to **Jenkins** → **Manage Jenkins** → **Credentials** → **Global**

Create the following credentials:

#### Credential 1: Boomi API Token
- **Kind**: Secret text
- **ID**: `boomi-auth-token`
- **Secret**: Base64 encoded `BOOMI_ACCOUNT.username:api_token`
- **Description**: Boomi API Authentication Token

#### Credential 2: Base URL (Optional)
- **Kind**: Secret text
- **ID**: `boomi-base-url`
- **Secret**: `https://api.boomi.com/api/rest/v1/YOUR_ACCOUNT_ID/`

### 2. Create Pipeline Job

1. **New Item** → **Pipeline** → Name it (e.g., "Boomi Deploy")
2. Under **Pipeline** section:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository URL
   - **Script Path**: `Jenkinsfile` (or path to your pipeline)

### 3. Create Jenkinsfile

Copy the example Jenkinsfile to your repository root:

```bash
cp ci-templates/jenkins/pipelines/deploy_packages.jenkinsfile Jenkinsfile
```

Edit the Jenkinsfile to customize:
- Component IDs
- Environment names
- Package version

### 4. Example Jenkinsfile

```groovy
@Library('shared-library') _

pipeline {
    agent any

    parameters {
        string(name: 'componentIds', defaultValue: '', description: 'Comma-separated Component IDs')
        string(name: 'env', defaultValue: 'Test-Env', description: 'Target Environment')
        string(name: 'packageVersion', defaultValue: '1.0.0', description: 'Package Version')
        string(name: 'notes', defaultValue: 'Deployed via Jenkins', description: 'Deployment Notes')
    }

    environment {
        SCRIPTS_HOME = "${WORKSPACE}/cli/scripts"
        WORKSPACE_DIR = "${WORKSPACE}/workspace"
        baseURL = credentials('boomi-base-url')
        authToken = credentials('boomi-auth-token')
        h1 = "Content-Type: application/json"
        h2 = "Accept: application/json"
        VERBOSE = "true"
        SLEEP_TIMER = "0.2"
    }

    stages {
        stage('Setup') {
            steps {
                sh '''
                    mkdir -p ${WORKSPACE_DIR}
                    chmod +x ${SCRIPTS_HOME}/bin/*.sh
                    chmod +x ${WORKSPACE}/ci-templates/jenkins/pipelines/*.sh
                '''
            }
        }

        stage('Deploy Packages') {
            steps {
                dir("${WORKSPACE}/ci-templates/jenkins/pipelines") {
                    sh '''
                        export WORKSPACE="${WORKSPACE_DIR}"
                        export componentIds="${componentIds}"
                        export env="${env}"
                        export packageVersion="${packageVersion}"
                        export notes="${notes}"
                        export BUILD_USER="${BUILD_USER_ID}"
                        export BUILD_USER_ID="${BUILD_USER_ID}"
                        export BUILD_EVENT="Jenkins"
                        
                        bash -xe ./deploy_packages.sh
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'workspace/*.json, workspace/*.html', allowEmptyArchive: true
        }
        cleanup {
            cleanWs()
        }
    }
}
```

### 5. Build with Parameters

1. Click **Build with Parameters**
2. Fill in:
   - **componentIds**: `comp-123,comp-456`
   - **env**: Your environment name or ID
   - **packageVersion**: `1.0.0`
   - **notes**: Description of deployment
3. Click **Build**

## Advanced Configuration

### Multi-Branch Pipeline

For Git Flow or trunk-based development:

```groovy
pipeline {
    agent any
    
    stages {
        stage('Deploy to Dev') {
            when { branch 'develop' }
            steps {
                script {
                    deployBoomi('Development', env.BUILD_NUMBER)
                }
            }
        }
        
        stage('Deploy to UAT') {
            when { branch 'release/*' }
            steps {
                script {
                    deployBoomi('UAT', env.BUILD_NUMBER)
                }
            }
        }
        
        stage('Deploy to Prod') {
            when { branch 'main' }
            input {
                message "Deploy to Production?"
                ok "Deploy"
            }
            steps {
                script {
                    deployBoomi('Production', env.BUILD_NUMBER)
                }
            }
        }
    }
}

def deployBoomi(envName, version) {
    withEnv(["TARGET_ENV=${envName}", "PKG_VERSION=${version}"]) {
        sh '''
            export WORKSPACE="${WORKSPACE}/workspace"
            export env="${TARGET_ENV}"
            export packageVersion="${PKG_VERSION}"
            cd ci-templates/jenkins/pipelines
            bash -xe ./deploy_packages.sh
        '''
    }
}
```

### Shared Library Integration

Create a Jenkins Shared Library for reusable functions:

```groovy
// vars/boomiDeploy.groovy
def call(Map config) {
    withCredentials([
        string(credentialsId: 'boomi-auth-token', variable: 'authToken'),
        string(credentialsId: 'boomi-base-url', variable: 'baseURL')
    ]) {
        sh """
            export SCRIPTS_HOME=\${WORKSPACE}/cli/scripts
            export WORKSPACE=\${WORKSPACE}/workspace
            export authToken=\${authToken}
            export baseURL=\${baseURL}
            export h1="Content-Type: application/json"
            export h2="Accept: application/json"
            export componentIds="${config.componentIds}"
            export env="${config.environment}"
            export packageVersion="${config.version}"
            export notes="${config.notes}"
            
            cd ci-templates/jenkins/pipelines
            bash -xe ./deploy_packages.sh
        """
    }
}
```

Use in pipeline:
```groovy
boomiDeploy(
    componentIds: 'comp-1,comp-2',
    environment: 'Test-Env',
    version: '1.0.0',
    notes: 'Automated deployment'
)
```

## Troubleshooting

### Error: Credentials not found
Ensure credential IDs match exactly:
- `boomi-auth-token`
- `boomi-base-url`

### Error: Script not executable
Add permission step in your Jenkinsfile:
```groovy
sh 'chmod -R +x cli/scripts/bin/'
```

### Error: WORKSPACE variable collision
Jenkins has a built-in `WORKSPACE` variable. The CLI uses this too. Use `WORKSPACE_DIR` for the CLI workspace:
```groovy
environment {
    WORKSPACE_DIR = "${WORKSPACE}/workspace"
}
```

Then export it:
```groovy
sh 'export WORKSPACE="${WORKSPACE_DIR}"'
```

## Next Steps

- Review [CLI Reference](../../docs/CLI_REFERENCE.md) for all available commands
- Explore [Common Workflows](../../examples/common-workflows/) for deployment patterns
- Set up Jenkins Pipeline Library for reusable components
