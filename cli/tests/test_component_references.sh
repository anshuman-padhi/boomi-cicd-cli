#!/bin/bash
#
# Test for bin/queryComponentReferences.sh against the repo's mock curl:
#   - POSTs to ComponentReference/query with parentComponentId + parentVersion
#   - parses the NESTED response (.result[].references[].componentId)
#   - writes the referenced ids to ${WORKSPACE}/_refs_<componentId>.txt
#
# Run:  bash cli/tests/test_component_references.sh
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLI_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
export SCRIPTS_HOME="$CLI_ROOT/cli/scripts"
export WORKSPACE="$SCRIPT_DIR/workspace/refs"
export PATH="$SCRIPT_DIR/mocks:$PATH"        # prepend mock curl
export REQUEST_LOG_FILE="$WORKSPACE/request_log.json"
export authToken="test-user:test-token"
export baseURL="https://api.boomi.com/api/rest/v1/test-account/"
export h1="Content-Type: application/json"
export h2="Accept: application/json"
export VERBOSE="false"; export SLEEP_TIMER="0"
rm -rf "$WORKSPACE"; mkdir -p "$WORKSPACE"; echo "[]" > "$REQUEST_LOG_FILE"

fail() { echo "FAIL: $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; exit 1; }
assert_eq() { [ "$2" == "$3" ] && echo "PASS: $1" || fail "$1" "$2" "$3"; }
assert_suffix() { case "$2" in *"$3") echo "PASS: $1";; *) fail "$1" "ends with $3" "$2";; esac; }
assert_contains() { case "$2" in *"$3"*) echo "PASS: $1";; *) fail "$1" "contains $3" "$2";; esac; }

PARENT="1234abcd-0000-0000-0000-000000000000"
CHILDA="aaaa0001-0000-0000-0000-000000000000"
CHILDB="bbbb0002-0000-0000-0000-000000000000"
export MOCK_RESPONSE_BODY="{\"@type\":\"QueryResult\",\"numberOfResults\":1,\"result\":[{\"@type\":\"ComponentReference\",\"references\":[{\"componentId\":\"$CHILDA\",\"parentComponentId\":\"$PARENT\",\"parentVersion\":5,\"type\":\"DEPENDENT\"},{\"componentId\":\"$CHILDB\",\"parentComponentId\":\"$PARENT\",\"parentVersion\":5,\"type\":\"INDEPENDENT\"}]}]}"

( cd "$SCRIPTS_HOME" && source bin/queryComponentReferences.sh componentId="$PARENT" parentVersion="5" )

LAST_URL="$(jq -r '.[-1].url' "$REQUEST_LOG_FILE")"
assert_suffix "queries ComponentReference/query" "$LAST_URL" "ComponentReference/query"

PROP="$(jq -r '.[-1].body | fromjson | .QueryFilter.expression.nestedExpression[0].property' "$REQUEST_LOG_FILE")"
ARG0="$(jq -r '.[-1].body | fromjson | .QueryFilter.expression.nestedExpression[0].argument[0]' "$REQUEST_LOG_FILE")"
VARG="$(jq -r '.[-1].body | fromjson | .QueryFilter.expression.nestedExpression[1].argument[0]' "$REQUEST_LOG_FILE")"
assert_eq "filters by parentComponentId" "parentComponentId" "$PROP"
assert_eq "parentComponentId = input id" "$PARENT" "$ARG0"
assert_eq "pins parentVersion" "5" "$VARG"

OUT="$WORKSPACE/_refs_${PARENT}.txt"
assert_eq "refs file written" "1" "$( [ -f "$OUT" ] && echo 1 || echo 0 )"
refs="$(tr '\n' ' ' < "$OUT")"
assert_contains "extracts nested child A" "$refs" "$CHILDA"
assert_contains "extracts nested child B" "$refs" "$CHILDB"
assert_eq "exactly 2 refs" "2" "$(grep -c . "$OUT")"

# ---- guard: reject non-GUID componentId (defense-in-depth vs createJSON sed-injection) ----
echo "[]" > "$REQUEST_LOG_FILE"
rc=0
( cd "$SCRIPTS_HOME" && source bin/queryComponentReferences.sh componentId='id&malicious' parentVersion="5" ) || rc=$?
assert_eq "non-GUID componentId is rejected (nonzero)" "1" "$( [ "$rc" -ne 0 ] && echo 1 || echo 0 )"
NREQ="$(jq 'length' "$REQUEST_LOG_FILE")"
assert_eq "no API request made for bad componentId" "0" "$NREQ"

echo ""
echo "ALL COMPONENT-REFERENCE ASSERTIONS PASSED"
