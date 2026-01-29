# Boomi CI/CD CLI Framework

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-blue.svg)](https://github.com/)

A **universal, CI/CD-agnostic command-line framework** for automating Boomi deployments, package management, and process execution. The core CLI is built with portable Bash scripts that work with any CI/CD platform.

## 🎯 Overview

This framework provides:
- **Universal CLI** - Tool-agnostic bash scripts for Boomi platform operations
- **Multi-Platform Support** - Pre-built templates for 6+ CI/CD platforms
- **Production-Ready** - Battle-tested scripts with error handling, retry logic, and security features
- **Extensible** - Easy to customize for your deployment workflows

## 🚀 Quick Start

### 1. Choose Your CI/CD Platform

Select your platform and follow the setup guide:

| Platform | Setup Guide | Template Location |
|----------|-------------|-------------------|
| **Azure DevOps** | [Setup Guide](ci-templates/azuredevops/docs/SETUP.md) | [`ci-templates/azuredevops/`](ci-templates/azuredevops/) |
| **Jenkins** | [Setup Guide](ci-templates/jenkins/docs/SETUP.md) | [`ci-templates/jenkins/`](ci-templates/jenkins/) |
| **GitHub Actions** | [Setup Guide](ci-templates/github-actions/docs/SETUP.md) | [`ci-templates/github-actions/`](ci-templates/github-actions/) |
| **CircleCI** | [Setup Guide](ci-templates/circleci/docs/SETUP.md) | [`ci-templates/circleci/`](ci-templates/circleci/) |
| **GitLab CI** | [Setup Guide](ci-templates/gitlab-ci/docs/SETUP.md) | [`ci-templates/gitlab-ci/`](ci-templates/gitlab-ci/) |
| **TeamCity** | [Setup Guide](ci-templates/teamcity/docs/SETUP.md) | [`ci-templates/teamcity/`](ci-templates/teamcity/) |

### 2. Install Dependencies

On your CI/CD agent or local machine:

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y jq curl bash

# RHEL/CentOS
sudo yum install -y jq curl bash

# macOS
brew install jq curl
```

### 3. Configure Authentication

Set environment variables for Boomi API access:

```bash
export authToken="$(echo -n 'BOOMI_ACCOUNT.username:api_token' | base64)"
export baseURL="https://api.boomi.com/api/rest/v1/YOUR_ACCOUNT_ID/"
export SCRIPTS_HOME="/path/to/cli/scripts"
export WORKSPACE="/path/to/workspace"
```

### 4. Run Your First Deployment

```bash
cd ci-templates/<your-platform>/
# Follow platform-specific instructions
```

## 📁 Project Structure

```
boomi-cicd-cli/
├── cli/                          # Core CLI (tool-agnostic)
│   └── scripts/
│       ├── bin/                  # Bash scripts for Boomi operations
│       ├── json/                 # API payload templates
│       └── conf/                 # Configuration files
├── ci-templates/                 # Platform-specific integrations
│   ├── azuredevops/
│   │   ├── pipelines/            # Azure Pipeline YAML templates
│   │   ├── docs/SETUP.md         # Setup guide
│   │   └── examples/             # Example configurations
│   ├── jenkins/
│   │   ├── pipelines/            # Jenkinsfiles
│   │   ├── docs/SETUP.md
│   │   └── examples/
│   ├── github-actions/
│   │   ├── workflows/            # GitHub Actions workflows
│   │   ├── docs/SETUP.md
│   │   └── examples/
│   ├── circleci/
│   │   ├── config/               # CircleCI configurations
│   │   ├── docs/SETUP.md
│   │   └── examples/
│   ├── gitlab-ci/
│   │   ├── pipelines/            # GitLab CI YAML
│   │   ├── docs/SETUP.md
│   │   └── examples/
│   └── teamcity/
│       ├── configs/              # TeamCity configurations
│       ├── docs/SETUP.md
│       └── examples/
├── docs/                         # Central documentation
│   ├── CLI_REFERENCE.md          # Complete CLI command reference
│   ├── GETTING_STARTED.md        # Quick start guide
│   └── ARCHITECTURE.md           # Framework architecture
├── examples/
│   └── common-workflows/         # Cross-platform workflow examples
└── README.md                     # This file
```

## 🔧 Core CLI Capabilities

The CLI provides scripts for all major Boomi operations:

### Package Management
- `createPackages.sh` - Create deployment packages
- `deployPackages.sh` - Deploy packages to environments
- `undeployPackages.sh` - Undeploy packages

### Process Management
- `executeProcess.sh` - Execute a process
- `deployProcess.sh` - Deploy individual processes
- `queryProcess.sh` - Query process information

### Environment Management
- `queryEnvironment.sh` - Get environment details
- `createEnvironment.sh` - Create new environments
- `updateExtensions.sh` - Update environment extensions

### Atom Management
- `queryAtom.sh` - Get atom information
- `createAtom.sh` - Create atom
- `updateAtom.sh` - Update atom configuration

### Reporting
- `publishDeployedPackage.sh` - Generate deployment reports
- `publishPackagedComponent.sh` - List packaged components
- `publishProcess.sh` - List processes

See [CLI Reference](docs/CLI_REFERENCE.md) for complete documentation.

## 🏗️ Architecture

### Design Principles

1. **Separation of Concerns**
   - Core CLI logic is independent of CI/CD platform
   - Platform templates are thin wrappers around CLI

2. **Portability**
   - Pure Bash scripts (Bash 4.0+)
   - Standard dependencies (jq, curl)
   - No platform-specific features in core CLI

3. **Security**
   - Token masking in logs
   - Secure credential handling
   - No hardcoded secrets

4. **Reliability**
   - Exponential backoff for API calls
   - Comprehensive error handling
   - Dependency validation on startup

### How It Works

```
┌─────────────────────┐
│   CI/CD Platform    │  ← Your chosen platform
│  (Jenkins, ADO,     │     (orchestrates workflow)
│   GitHub, etc.)     │
└──────────┬──────────┘
           │ calls
           ▼
┌─────────────────────-┐
│  Platform Template   │  ← Thin wrapper script
│  (deploy_packages.sh)│    (sets env vars)
└──────────┬──────────-┘
           │ sources
           ▼
┌─────────────────────┐
│    Core CLI         │  ← Tool-agnostic logic
│  (deployPackages.sh │    (calls Boomi API)
│   in cli/scripts/)  │
└──────────┬──────────┘
           │ calls
           ▼
┌─────────────────────┐
│   Boomi Platform    │  ← AtomSphere API
│   (REST API)        │
└─────────────────────┘
```

## 📚 Documentation

- **[Getting Started](docs/GETTING_STARTED.md)** - Step-by-step tutorial
- **[CLI Reference](docs/CLI_REFERENCE.md)** - Complete command documentation
- **[Architecture](docs/ARCHITECTURE.md)** - Deep dive into framework design
- **[Common Workflows](examples/common-workflows/)** - Example deployment patterns

### Platform-Specific Guides
- [Azure DevOps Setup](ci-templates/azuredevops/docs/SETUP.md)
- [Jenkins Setup](ci-templates/jenkins/docs/SETUP.md)
- [GitHub Actions Setup](ci-templates/github-actions/docs/SETUP.md)
- [CircleCI Setup](ci-templates/circleci/docs/SETUP.md)
- [GitLab CI Setup](ci-templates/gitlab-ci/docs/SETUP.md)
- [TeamCity Setup](ci-templates/teamcity/docs/SETUP.md)

## 💡 Use Cases

- **Automated Deployments** - CI/CD pipelines for Boomi processes
- **Multi-Environment Promotion** - Dev → QA → UAT → Production
- **Scheduled Deployments** - Nightly or weekend releases
- **Hotfix Deployments** - Rapid deployment for critical fixes
- **API Testing** - Integrate with Postman/Newman for API validation
- **Rollback** - Undeploy packages when issues occur

## 🔒 Security Best Practices

1. **Never commit credentials** - Use CI/CD secret management
2. **Mask tokens in logs** - Framework automatically masks `authToken`
3. **Use protected branches** - Restrict production deployments
4. **Implement approvals** - Manual gates for production
5. **Audit deployments** - Store artifacts and logs

## 🤝 Contributing

Contributions are welcome! Areas for contribution:
- Additional CI/CD platform templates
- Enhanced error handling
- Additional Boomi API operations
- Documentation improvements

## 📋 Requirements

### Core CLI
- Bash 4.0+
- jq (JSON processor)
- curl (HTTP client)

### Optional: SonarQube Integration

For code quality scanning with `sonarScanner.sh`:

**Download SonarQube Scanner:**
```bash
cd sonarqube
# Download from official source
curl -L -O https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856.zip
unzip sonar-scanner-cli-4.8.0.2856.zip
```

**Note:** The `sonarqube/` directory is excluded from Git to keep the repository lightweight. Download the scanner separately if you need code quality integration.

### CI/CD Platforms
- See platform-specific setup guides for agent requirements

## 🐛 Troubleshooting

### Common Issues

**Error: `jq: command not found`**
```bash
sudo apt-get install jq  # Ubuntu/Debian
sudo yum install jq      # RHEL/CentOS
brew install jq          # macOS
```

**Error: `SCRIPTS_HOME not set`**
```bash
export SCRIPTS_HOME="/path/to/boomi-cicd-cli/cli/scripts"
```

**Error: Authentication failed**
```bash
# Verify token format: Base64(ACCOUNT.username:api_token)
echo -n "BOOMI_ACCOUNT.user:token" | base64
```

See platform-specific troubleshooting in setup guides.

## 📞 Support

- **Documentation**: See [`docs/`](docs/) directory
- **Platform Issues**: Check platform-specific SETUP.md
- **CLI Issues**: Review [CLI Reference](docs/CLI_REFERENCE.md)

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2026 Essilor

## 🙏 Acknowledgments

This framework builds on best practices from the Boomi community and integrates with the official Boomi AtomSphere API.

---

**Ready to get started?** Choose your CI/CD platform above and follow the setup guide!