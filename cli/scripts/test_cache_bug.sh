#!/bin/bash
# Quick test for cache_get stdout pollution bug

export SCRIPTS_HOME="$(pwd)"
export CACHE_ENABLED=true
export VERBOSE=true

source bin/common.sh

echo "=== Testing cache_get output ==="

# Set a cache value
cache_set "TEST" "mykey" "myvalue"

# Get it back with VERBOSE=true
result=$(cache_get "TEST" "mykey")

echo "Result: '${result}'"
echo "Expected: 'myvalue'"

if [ "${result}" == "myvalue" ]; then
    echo "✓ TEST PASSED - No stdout pollution"
    exit 0
else
    echo "✗ TEST FAILED - Got: '${result}'"
    exit 1
fi
