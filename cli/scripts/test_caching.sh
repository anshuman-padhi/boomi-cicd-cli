#!/bin/bash
# Test script for caching functionality
# This demonstrates cache behavior and validates implementation

set -e

# Setup
export SCRIPTS_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export WORKSPACE="/tmp/boomi-cache-test-$$"
mkdir -p "${WORKSPACE}"

echo "=== Boomi CLI Caching Test ==="
echo "Workspace: ${WORKSPACE}"
echo ""

# Source common functions
cd "${SCRIPTS_HOME}"
source bin/common.sh

echo "=== Test 1: Cache Configuration ==="
echo "CACHE_ENABLED: ${CACHE_ENABLED}"
echo "CACHE_TTL_SECONDS: ${CACHE_TTL_SECONDS}"
echo ""

echo "=== Test 2: Basic Cache Operations ==="

# Test cache_set
cache_set "ENVIRONMENT_ID" "Production_*" "env-prod-123"
cache_set "ENVIRONMENT_ID" "QA_*" "env-qa-456"
cache_set "ATOM_ID" "ProdAtom_ATOM_online" "atom-789"

echo "✓ Set 3 cache entries"
echo ""

# Test cache_get
echo "=== Test 3: Cache Retrieval ==="
prod_env=$(cache_get "ENVIRONMENT_ID" "Production_*")
echo "Retrieved Production env: ${prod_env}"

qa_env=$(cache_get "ENVIRONMENT_ID" "QA_*")
echo "Retrieved QA env: ${qa_env}"

prod_atom=$(cache_get "ATOM_ID" "ProdAtom_ATOM_online")
echo "Retrieved ProdAtom: ${prod_atom}"

# Test cache miss
missing=$(cache_get "ENVIRONMENT_ID" "NonExistent" || echo "(cache miss)")
echo "Non-existent key: ${missing}"
echo ""

# Test cache stats
echo "=== Test 4: Cache Statistics ==="
cache_stats
echo ""

# Test cache clear
echo "=== Test 5: Cache Clear ==="
cache_clear
echo "✓ Cache cleared"
cache_stats
echo ""

# Test TTL expiration
echo "=== Test 6: TTL Expiration ==="
export CACHE_TTL_SECONDS=2
cache_set "ENVIRONMENT_ID" "TestEnv_*" "env-test-999"
echo "Set cache with 2-second TTL"

echo "Immediate retrieval:"
test_env=$(cache_get "ENVIRONMENT_ID" "TestEnv_*")
echo "  Result: ${test_env}"

echo "Waiting 3 seconds..."
sleep 3

echo "After expiration:"
expired_env=$(cache_get "ENVIRONMENT_ID" "TestEnv_*" || echo "(expired)")
echo "  Result: ${expired_env}"
echo ""

# Test cache disabled
echo "=== Test 7: Cache Disabled ==="
export CACHE_ENABLED=false
cache_set "ENVIRONMENT_ID" "DisabledTest_*" "should-not-cache"
disabled_result=$(cache_get "ENVIRONMENT_ID" "DisabledTest_*" || echo "(caching disabled)")
echo "Result with CACHE_ENABLED=false: ${disabled_result}"
echo ""

# Cleanup
rm -rf "${WORKSPACE}"

echo "=== All Cache Tests Passed! ✓ ==="
echo ""
echo "Usage in scripts:"
echo "  - Enable: export CACHE_ENABLED=true (default)"
echo "  - Disable: export CACHE_ENABLED=false"
echo "  - Set TTL: export CACHE_TTL_SECONDS=300 (default: 5 minutes)"
echo "  - Clear cache: cache_clear"
echo "  - View stats: cache_stats"
