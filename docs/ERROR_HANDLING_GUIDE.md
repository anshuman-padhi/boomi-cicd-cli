# Error Handling Utilities - Developer Guide

## Overview

New utility functions have been added to `cli/scripts/bin/common.sh` to provide consistent error handling and logging across all Boomi CI/CD scripts.

## New Functions

### Logging Functions

#### `log_info(message)`
**Purpose:** Print informational messages to stdout
```bash
log_info "Creating package for component: $componentId"
#Output: [INFO] Creating package for component: abc-123
```

#### `log_warn(message)`
**Purpose:** Print warning messages to stderr
```bash
log_warn "Component metadata not found, using fallback query"
# Output: [WARN] Component metadata not found, using fallback query
```

#### `log_error(message)`
**Purpose:** Print error messages to stderr
```bash
log_error "API call failed: Invalid credentials"
# Output: [ERROR] API call failed: Invalid credentials
```

---

### Error Handling

#### `handle_error(exit_code, error_message)`
**Purpose:** Standardized error handling with descriptive messages

**Parameters:**
- `exit_code`: Numeric exit code (0 = success, >0 = error)
- `error_message`: Human-readable error description

**Returns:** 
- `0` if exit_code is 0
- `exit_code` if > 0 (and sets `$ERROR` and `$ERROR_MESSAGE` variables)

**Usage:**
```bash
# Old pattern (inconsistent):
callAPI
if [ "$ERROR" -gt "0" ]; then
    return 255;
fi

# New pattern (recommended):
callAPI
handle_error "$ERROR" "Failed to create deployment" || return 1
```

**Benefits:**
- Consistent error messages with exit codes
- Easier debugging (know exactly what failed)
- Sets both `$ERROR` (code) and `$ERROR_MESSAGE` (text)

---

### Variable Validation

#### `validate_required_vars(var_name1 var_name2 ...)`
**Purpose:** Validate that required environment variables are set

**Usage:**
```bash
# Ensure critical variables exist before proceeding
validate_required_vars "baseURL" "authToken" "WORKSPACE" || return 1
# Output (if authToken missing): [ERROR] Missing required variables: authToken
```

---

### Retry Mechanism

#### `retry_command(max_attempts, wait_seconds, command)`
**Purpose:** Retry a command with exponential backoff (useful for flaky API calls)

**Parameters:**
- `max_attempts`: Maximum retry attempts (default: 3)
- `wait_seconds`: Seconds to wait between retries (default: 5)
- `command`: Command to execute (quoted string)

**Usage:**
```bash
# Retry curl command up to 3 times with 5-second delays
retry_command 3 5 "curl -s ${baseURL}Atom/query"

# With custom retry logic:
retry_command 5 10 "source bin/queryEnvironment.sh env='Production'"
```

---

## Migration Guide

### Phase 1: Adopt New Error Handling (Non-Breaking)

**Priority Scripts:**
1. Package Management: `createPackages.sh`, `deployPackages.sh`, `undeployPackages.sh`
2. Query Operations: `query*.sh` scripts
3. Process Execution: `executeProcess.sh`, `deployProcess.sh`

**Migration Pattern:**
```bash
# Before:
inputs "$@"
if [ "$?" -gt "0" ]; then
    return 255;
fi

# After:
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

# Before:
callAPI
if [ "$ERROR" -gt "0" ]; then
    return 255;
fi

# After:
callAPI
handle_error "$ERROR" "API call to ${URL} failed" || return 1
```

### Phase 2: Add Informational Logging

**Usage:**
```bash
# At start of critical operations
log_info "Starting deployment of package ${packageId} to ${env}"

# For warnings
if [ -z "${componentVersion}" ]; then
    log_warn "Component version not found, using fallback query"
fi

# For errors (automatically handled by handle_error, but can use directly)
if [ ! -f "$JSON_FILE" ]; then
    log_error "JSON template not found: $JSON_FILE"
    return 1
fi
```

### Phase 3: Add Variable Validation

**Usage:**
```bash
# At script start, after inputs()
ARGUMENTS=(componentId packageVersion env)
inputs "$@"

# Validate all required vars are set
validate_required_vars "componentId" "packageVersion" "env" || return 1
```

---

## Example: Migrated Script

### Before (Old Pattern)
```bash
#!/bin/bash
source bin/common.sh

ARGUMENTS=(componentId)
inputs "$@"
if [ "$?" -gt "0" ]; then
    return 255;
fi

JSON_FILE=json/queryAtom.json
URL="${baseURL}Atom/query"
id=result[0].id
exportVariable=atomId

createJSON
callAPI

if [ "$ERROR" -gt "0" ]; then
    return 255;
fi
```

### After (New Pattern)
```bash
#!/bin/bash
source bin/common.sh

ARGUMENTS=(componentId)
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

# Validate critical dependencies
validate_required_vars "baseURL" "WORKSPACE" || return 1

log_info "Querying atom: $componentId"

JSON_FILE=json/queryAtom.json
URL="${baseURL}Atom/query"
id=result[0].id
exportVariable=atomId

createJSON
callAPI
handle_error "$ERROR" "API query failed for atom $componentId" || return 1

log_info "Successfully retrieved atomId: $atomId"
```

---

## Benefits

1. **Consistency**: All scripts use same error patterns
2. **Debuggability**: Clear error messages with context
3. **Maintainability**: Easier to understand failures
4. **Robustness**: Built-in retry mechanism for flaky operations
5. **Backward Compatible**: Existing scripts still work; migrate gradually

---

## Next Steps

1. ✅ Utilities added to `common.sh`
2. ✅ Demonstrated in `createPackages.sh`
3. 🔄 **Your Action:** Gradually update other scripts using the patterns above
4. 📖 **Documentation:** Update CLI_REFERENCE.md with these utilities

---

## Testing

Test the new functions:
```bash
# Source common.sh
cd cli/scripts
source bin/common.sh

# Test logging
log_info "This is an info message"
log_warn "This is a warning"
log_error "This is an error"

# Test error handler
export ERROR=1
handle_error "$ERROR" "Test error message"
echo "ERROR=$ERROR, ERROR_MESSAGE=$ERROR_MESSAGE"

# Test variable validation
validate_required_vars "PATH" "HOME"  # Should pass
validate_required_vars "NONEXISTENT_VAR"  # Should fail
```

---

**Last Updated:** 2026-02-01  
**Version:** 1.0.0
