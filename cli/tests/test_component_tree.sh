#!/bin/bash
#
# Tests for recursive component-dependency discovery:
#   - bin/getComponentTree.sh  (BFS traversal, dedup, cycle-safety, caps, recursion policy)
#   - bin/queryComponentReferences.sh  (Boomi ComponentReference API query + nested parse)
#
# Pure-logic tests use injected fixtures (GCT_FIXTURE_DIR) and a stubbed API-refs
# function, so no network/curl is needed. The ComponentReference API script is
# tested separately against the repo's mock curl.
#
# Run:  bash cli/tests/test_component_tree.sh
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLI_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
export SCRIPTS_HOME="$CLI_ROOT/cli/scripts"
export WORKSPACE="$SCRIPT_DIR/workspace/tree"
FIX="$SCRIPT_DIR/workspace/fixtures"
rm -rf "$WORKSPACE" "$FIX"; mkdir -p "$WORKSPACE" "$FIX"

PASS=0
fail() { echo "FAIL: $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; exit 1; }
assert_eq() { [ "$2" == "$3" ] && { echo "PASS: $1"; PASS=$((PASS+1)); } || fail "$1" "$2" "$3"; }
assert_contains() { case "$2" in *"$3"*) echo "PASS: $1"; PASS=$((PASS+1));; *) fail "$1" "contains '$3'" "$2";; esac; }
assert_not_contains() { case "$2" in *"$3"*) fail "$1" "NOT contains '$3'" "$2";; *) echo "PASS: $1"; PASS=$((PASS+1));; esac; }

# ---- fixtures: a small dependency graph with a cycle + a non-recursed leaf ----
ROOT=aaaaaaaa-0000-0000-0000-000000000001   # process
SCR=bbbbbbbb-0000-0000-0000-000000000002    # script.processing
SUB=cccccccc-0000-0000-0000-000000000003    # process (references ROOT -> cycle)
PROF=dddddddd-0000-0000-0000-000000000004   # profile.xml (leaf: must NOT be recursed)
CONN=eeeeeeee-0000-0000-0000-000000000005   # connector-action (referenced by SUB)
PROFONLY=ffffffff-0000-0000-0000-000000000006 # referenced ONLY by PROF -> must be skipped
APIONLY=99999999-0000-0000-0000-000000000007  # discovered ONLY via API union stub

cat > "$FIX/$ROOT.xml" <<EOF
<bns:Component xmlns:bns="http://api.platform.boomi.com/" name="Root Proc" type="process" version="7">
  <ref id="$SCR"/><ref id="$SUB"/><ref id="$PROF"/>
</bns:Component>
EOF
cat > "$FIX/$SCR.xml" <<EOF
<bns:Component xmlns:bns="http://api.platform.boomi.com/" name="My Script" type="script.processing" version="1">
  <script language="groovy">def x = "secret"</script>
</bns:Component>
EOF
cat > "$FIX/$SUB.xml" <<EOF
<bns:Component xmlns:bns="http://api.platform.boomi.com/" name="Sub Proc" type="process" version="2">
  <ref id="$CONN"/><ref id="$ROOT"/>
</bns:Component>
EOF
cat > "$FIX/$PROF.xml" <<EOF
<bns:Component xmlns:bns="http://api.platform.boomi.com/" name="A Profile" type="profile.xml" version="3">
  <ref id="$PROFONLY"/>
</bns:Component>
EOF
cat > "$FIX/$CONN.xml" <<EOF
<bns:Component xmlns:bns="http://api.platform.boomi.com/" name="Get Op" type="connector-action" version="1"/>
EOF
cat > "$FIX/$PROFONLY.xml" <<EOF
<bns:Component xmlns:bns="http://api.platform.boomi.com/" name="Prof Only" type="profile.xml" version="1"/>
EOF
cat > "$FIX/$APIONLY.xml" <<EOF
<bns:Component xmlns:bns="http://api.platform.boomi.com/" name="Api Only" type="profile.xml" version="1"/>
EOF

# ---- load the library (functions only) ----
cd "$SCRIPTS_HOME" || exit 1
GCT_LIB_ONLY=1 source bin/getComponentTree.sh || { echo "cannot source getComponentTree.sh"; exit 1; }
export GCT_FIXTURE_DIR="$FIX"

echo "=== unit: gct_root_attr ==="
assert_eq "root type"    "process"          "$(gct_root_attr "$FIX/$ROOT.xml" type)"
assert_eq "root name"    "Root Proc"        "$(gct_root_attr "$FIX/$ROOT.xml" name)"
assert_eq "root version" "7"                "$(gct_root_attr "$FIX/$ROOT.xml" version)"
assert_eq "script type"  "script.processing" "$(gct_root_attr "$FIX/$SCR.xml" type)"

echo "=== unit: gct_scrape_guids (excludes self, dedups) ==="
scr_out="$(gct_scrape_guids "$FIX/$ROOT.xml" "$ROOT" | tr '\n' ' ')"
assert_contains "scrape finds SCR"  "$scr_out" "$SCR"
assert_contains "scrape finds SUB"  "$scr_out" "$SUB"
assert_contains "scrape finds PROF" "$scr_out" "$PROF"
assert_not_contains "scrape excludes self" "$scr_out" "$ROOT"

echo "=== unit: gct_should_recurse (code/flow types only) ==="
gct_should_recurse "process"           && echo "PASS: process recurses"           || fail "process recurses" 0 1
gct_should_recurse "script.processing" && echo "PASS: script.processing recurses" || fail "script recurses"  0 1
gct_should_recurse "profile.xml"       && { fail "profile NOT recursed" 1 0; }     || echo "PASS: profile not recursed"
gct_should_recurse "connector-action"  && { fail "connector NOT recursed" 1 0; }   || echo "PASS: connector not recursed"

echo "=== traversal: XML-only, full graph, cycle-safe, leaf not recursed ==="
export GCT_REFERENCE_SOURCE=xml
export GCT_TREE_FILE="$WORKSPACE/tree.tsv"
export GCT_MAX_COMPONENTS=100 GCT_MAX_DEPTH=15
gct_build_tree "$ROOT" >"$WORKSPACE/out.log" 2>&1
tree="$(cat "$GCT_TREE_FILE")"
assert_contains "root scanned"  "$tree" "$ROOT"
assert_contains "script scanned" "$tree" "$SCR"
assert_contains "subproc scanned" "$tree" "$SUB"
assert_contains "profile scanned" "$tree" "$PROF"
assert_contains "connector scanned (via subproc)" "$tree" "$CONN"
assert_not_contains "profile's child NOT scanned (no recurse into profile)" "$tree" "$PROFONLY"
assert_eq "exactly 5 components discovered" "5" "$(grep -c . "$GCT_TREE_FILE")"
assert_eq "no duplicate scans (root once)" "1" "$(cut -f1 "$GCT_TREE_FILE" | grep -c "^$ROOT$")"
# each discovered component has an exported XML staged in WORKSPACE
assert_eq "connector XML exported" "1" "$( [ -f "$WORKSPACE/$CONN.xml" ] && echo 1 || echo 0 )"

echo "=== traversal: max-depth cap ==="
export GCT_TREE_FILE="$WORKSPACE/tree_d0.tsv"; export GCT_MAX_DEPTH=0
gct_build_tree "$ROOT" >/dev/null 2>&1
assert_eq "depth 0 -> only root" "1" "$(grep -c . "$GCT_TREE_FILE")"
export GCT_MAX_DEPTH=15

echo "=== traversal: max-components cap (logs truncation) ==="
export GCT_TREE_FILE="$WORKSPACE/tree_cap.tsv"; export GCT_MAX_COMPONENTS=2
capout="$(gct_build_tree "$ROOT" 2>&1)"
assert_eq "cap -> 2 components" "2" "$(grep -c . "$GCT_TREE_FILE")"
assert_contains "cap logs a warning" "$capout" "max components"
export GCT_MAX_COMPONENTS=100

echo "=== traversal: API union (dedup, discovers api-only child) ==="
# stub the API refs: for ROOT return an already-known id (SCR, must dedup) + a new one (APIONLY)
gct_api_child_ids_impl() { local id="$1"; if [ "$id" == "$ROOT" ]; then echo "$SCR"; echo "$APIONLY"; fi; }
export GCT_REFERENCE_SOURCE=both
export GCT_TREE_FILE="$WORKSPACE/tree_union.tsv"
gct_build_tree "$ROOT" >/dev/null 2>&1
utree="$(cat "$GCT_TREE_FILE")"
assert_contains "union discovers api-only child" "$utree" "$APIONLY"
assert_eq "union still dedups SCR" "1" "$(cut -f1 "$GCT_TREE_FILE" | grep -c "^$SCR$")"
assert_eq "union total = 6" "6" "$(grep -c . "$GCT_TREE_FILE")"
unset -f gct_api_child_ids_impl

echo ""
echo "ALL $PASS COMPONENT-TREE ASSERTIONS PASSED"
