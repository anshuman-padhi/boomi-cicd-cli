# SonarQube Integration Setup

This directory contains SonarQube scanner for code quality analysis of Boomi components.

## Download SonarQube Scanner

The scanner binary is **not included in this repository** to keep it lightweight. Download it separately:

### Option 1: Direct Download

```bash
cd sonarqube

# Download SonarQube Scanner CLI
curl -L -O https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856.zip

# Extract
unzip sonar-scanner-cli-4.8.0.2856.zip

# Verify
./sonar-scanner-cli-4.8.0.2856/bin/sonar-scanner --version
```

### Option 2: Using Package Manager

**macOS (Homebrew):**
```bash
brew install sonar-scanner
```

**Linux (apt):**
```bash
sudo apt-get install sonar-scanner
```

## Configuration

Create `sonar-project.properties` in your project root:

```properties
# Project identification
sonar.projectKey=boomi-project
sonar.projectName=My Boomi Project
sonar.projectVersion=1.0

# Source code location
sonar.sources=workspace/components

# SonarQube server
sonar.host.url=http://localhost:9000
sonar.login=your-token-here
```

## Usage

The CLI's `sonarScanner.sh` script automatically uses the scanner if available:

```bash
source cli/scripts/bin/sonarScanner.sh baseFolder="${WORKSPACE}/components"
```

## Why Not Included?

- **Repository Size**: Scanner binary is ~50MB, keeping repo lightweight
- **Version Flexibility**: Users can download the version they need
- **Platform Specific**: Different platforms may prefer different installation methods

## Additional Resources

- [SonarQube Documentation](https://docs.sonarqube.org/latest/)
- [SonarQube Scanner Downloads](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/)
- [Boomi Code Quality Best Practices](https://help.boomi.com/)
