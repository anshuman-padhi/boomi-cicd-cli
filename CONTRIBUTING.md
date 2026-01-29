# Contributing to Boomi CI/CD CLI

Thank you for your interest in contributing! This document provides guidelines for contributing to the Boomi CI/CD CLI framework.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Bash version, CLI version)
- Relevant logs or error messages

### Suggesting Features

Feature requests are welcome! Please include:
- Use case description
- Proposed solution
- Alternatives considered
- Any implementation ideas

### Submitting Pull Requests

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following our coding standards
3. **Test thoroughly** - ensure scripts work on your platform
4. **Update documentation** if adding features or changing behavior
5. **Submit a PR** with a clear description

## Development Setup

### Prerequisites

```bash
# Install dependencies
# macOS
brew install jq curl bash

# Ubuntu/Debian
sudo apt-get install -y jq curl bash

# RHEL/CentOS
sudo yum install -y jq curl bash
```

### Getting Started

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/boomi-cicd-cli.git
cd boomi-cicd-cli

# Make scripts executable
chmod +x cli/scripts/bin/*.sh

# Set up environment
export SCRIPTS_HOME="$(pwd)/cli/scripts"
export WORKSPACE="$(pwd)/workspace"
mkdir -p $WORKSPACE
```

## Coding Standards

### Shell Scripts

- **Use Bash 4.0+** compatible syntax
- **Follow existing patterns** in `cli/scripts/bin/common.sh`
- **Error handling**: Always check return codes
- **Logging**: Use `echov` for verbose logging
- **Security**: Never hardcode credentials, mask sensitive data in logs

### Script Structure

```bash
#!/bin/bash
# Check if SCRIPTS_HOME is set
if [ -z "${SCRIPTS_HOME}" ]; then
    SCRIPTS_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
fi

source "${SCRIPTS_HOME}/bin/common.sh"

# Define mandatory arguments
ARGUMENTS=(arg1 arg2)
OPT_ARGUMENTS=(optArg1)
inputs "$@"

# Your script logic here

# Clean up
clean
```

### Best Practices

1. **Input Validation**: Use the `inputs` function from `common.sh`
2. **API Calls**: Use `callAPI` or `getAPI` helpers for consistency
3. **Error Handling**: Set `ERROR` variable on failures
4. **Credentials**: Always use environment variables, never hardcode
5. **Dependencies**: Check for required tools at script start
6. **Documentation**: Add comments for complex logic

### Testing

Before submitting a PR:

```bash
# Syntax check all modified scripts
bash -n cli/scripts/bin/your_script.sh

# Test with verbose mode
export VERBOSE=true
source cli/scripts/bin/your_script.sh arg1=value1 arg2=value2

# Test error cases
# (missing args, invalid values, API failures)
```

## Adding CI/CD Platform Support

To add support for a new CI/CD platform:

1. Create directory structure:
   ```
   ci-templates/your-platform/
   ├── docs/
   │   └── SETUP.md
   ├── examples/
   │   └── example-config.yml
   ├── pipelines/ (or configs/)
   │   ├── deploy_packages.sh
   │   └── platform-specific-files
   ```

2. **SETUP.md** should include:
   - Prerequisites
   - Configuration steps
   - Examples
   - Troubleshooting

3. **Wrapper scripts** should:
   - Set required environment variables
   - Source the core CLI scripts
   - Handle platform-specific logic

4. **Update main README.md**:
   - Add platform to table
   - Add link to setup guide

## Documentation

- Keep documentation **concise and clear**
- Use **examples** to illustrate usage
- Update **CLI_REFERENCE.md** for new commands
- Update **CHANGELOG.md** following Keep a Changelog format

## Commit Messages

Use clear, descriptive commit messages:

```
feat: add support for TeamCity CI/CD platform
fix: correct retry logic in API polling
docs: update Jenkins setup guide
refactor: extract common deployment logic
```

Prefixes:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

## Pull Request Process

1. **Update CHANGELOG.md** under `[Unreleased]` section
2. **Update documentation** for any user-facing changes
3. **Ensure scripts are executable**: `chmod +x ...`
4. **Test on multiple platforms** if possible (Linux, macOS)
5. **Link related issues** in PR description

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] All scripts pass syntax check (`bash -n`)
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated
- [ ] Scripts are tested and working
- [ ] No hardcoded credentials or secrets
- [ ] Scripts are executable (chmod +x)

## Code Review

All PRs require review before merging. Reviewers will check:
- Code quality and style
- Functionality and correctness
- Security considerations
- Documentation completeness
- Test coverage

## Security

If you discover a security vulnerability:
- **DO NOT** open a public issue
- Email the maintainers directly
- Provide detailed description and PoC if possible

## Questions?

- Check existing [documentation](docs/)
- Review [CLI Reference](docs/CLI_REFERENCE.md)
- Search existing [issues and PRs](../../issues)
- Ask in discussions or create a new issue

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Boomi CI/CD CLI! 🚀
