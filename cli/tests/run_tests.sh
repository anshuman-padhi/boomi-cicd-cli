#!/bin/bash

# Boomi CLI Test Runner
# Mocks curl to validate generated JSON payloads and API calls.

# Setup Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLI_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SCRIPTS_HOME="$CLI_ROOT/cli/scripts"
WORKSPACE="$SCRIPT_DIR/workspace"
MOCK_BIN="$SCRIPT_DIR/mocks"
REQUEST_LOG="$WORKSPACE/request_log.json"

# Export Environment for Scripts
export SCRIPTS_HOME
export WORKSPACE
export PATH="$MOCK_BIN:$PATH" # Prepend mock curl to PATH
export REQUEST_LOG_FILE="$REQUEST_LOG"

# Mock Credentials
export authToken="test-user:test-token"
export baseURL="https://api.boomi.com/api/rest/v1/test-account/"
export h1="Content-Type: application/json"
export h2="Accept: application/json"
export VERBOSE="true"
export SLEEP_TIMER="0"

# Setup Workspace
mkdir -p "$WORKSPACE"

# --- Helper Functions ---

function setup_test {
    echo "---------------------------------------------------"
    echo "TEST: $1"
    rm -f "$REQUEST_LOG" "$WORKSPACE"/*.json
    echo "[]" > "$REQUEST_LOG"
}

function assert_request_body {
    local key="$1"
    local expected="$2"
    local msg="$3"
    
    # Check the last request in the log
    local actual=$(jq -r ".[-1].body | fromjson | $key" "$REQUEST_LOG")
    
    if [ "$actual" == "$expected" ]; then
        echo "PASS: $msg"
    else
        echo "FAIL: $msg"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        exit 1
    fi
}

function assert_url {
    local expected_suffix="$1"
    local msg="$2"
    
    local actual=$(jq -r ".[-1].url" "$REQUEST_LOG")
    
    if [[ "$actual" == *"$expected_suffix" ]]; then
        echo "PASS: $msg"
    else
        echo "FAIL: $msg"
        echo "  Expected suffix: $expected_suffix"
        echo "  Actual URL:      $actual"
        exit 1
    fi
}

# --- TEST CASES ---

# Test 1: queryEnvironment.sh - Wildcard Support
setup_test "queryEnvironment.sh - Wildcard (*)"
export MOCK_RESPONSE_BODY='{"result": [{"id": "env-123", "name": "dev"}]}'
export env="*"
export classification="*"

# Run Script
# We run in a subshell so exports don't leak/pollute, but we need to source it
(cd "$SCRIPTS_HOME" && source "bin/queryEnvironment.sh" env="$env" classification="$classification")

# Validation
# 1. URL should not end with //
assert_url "${baseURL}Environment/query" "URL construction"

# 2. Operator should be LIKE (since we used wildcard)
assert_request_body ".QueryFilter.expression.nestedExpression[0].operator" "LIKE" "Operator is LIKE for wildcard"

# 3. Argument should be % (converted from *)
assert_request_body ".QueryFilter.expression.nestedExpression[0].argument[0]" "%" "Wildcard * converted to %"


# Test 2: createPackages.sh - Variable Substitution
setup_test "createPackages.sh - Variable Substitution"
export MOCK_RESPONSE_BODY='{"packageId": "pkg-456"}'
export componentIds="test-component-id"
export packageVersion="1.0.0"
export notes="Release Notes"

# Logic for createPackages is complex, it calls createSinglePackage.sh
(cd "$SCRIPTS_HOME" && source "bin/createPackages.sh" componentIds="$componentIds" packageVersion="$packageVersion" notes="$notes")

# Validation
# createPackages calls multiple APIs. The LAST call should be creating the package.
assert_url "PackagedComponent" "URL is PackagedComponent"
assert_request_body ".componentId" "test-component-id" "Component ID passed correctly"
assert_request_body ".packageVersion" "1.0.0" "Package Version passed correctly"
assert_request_body ".notes" "Release Notes" "Notes passed correctly"



# Test 3: executeProcess.sh - Atom Execution
setup_test "executeProcess.sh - Atom Execution"
export MOCK_RESPONSE_BODY='{"result": [{"id": "atom-123", "status": "online", "type": "MOLECULE"}]}'
export atomName="Test Atom"
export atomType="MOLECULE"
export componentId="proc-xyz"

(cd "$SCRIPTS_HOME" && source "bin/executeProcess.sh" atomName="$atomName" atomType="$atomType" componentId="$componentId")

# Validation
# 1. First call is queryAtom
# 2. Second call is execution
assert_url "${baseURL}executeProcess" "URL is executeProcess"
assert_request_body ".atomId" "atom-123" "Atom ID resolved and passed correctly"
assert_request_body ".processId" "proc-xyz" "Process ID passed correctly"


# Test 4: deployPackage.sh - Deployment
setup_test "deployPackage.sh - Deployment"
export MOCK_RESPONSE_BODY='{"result": [{"id": "env-789", "name": "UAT"}]}'
export env="UAT"
export packageVersion="1.0"
export notes="Deploying to UAT"
export packageId="pkg-555"
export listenerStatus="RUNNING"

(cd "$SCRIPTS_HOME" && source "bin/deployPackage.sh" env="$env" packageVersion="$packageVersion" notes="$notes" packageId="$packageId" listenerStatus="$listenerStatus")

# Validation
# 1. queryEnvironment (returns env-789)
# 2. createDeployedPackage
assert_url "DeployedPackage" "URL is DeployedPackage"
assert_request_body ".environmentId" "env-789" "Environment ID resolved correctly"
assert_request_body ".packageId" "pkg-456" "Package ID passed correctly"


echo "---------------------------------------------------"
echo "ALL TESTS PASSED"
exit 0
