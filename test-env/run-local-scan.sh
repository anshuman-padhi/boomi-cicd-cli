#!/usr/bin/env bash
#
# run-local-scan.sh — run the Boomi recursive component discovery (and optionally the
# full Semgrep + SonarQube scan) locally, mapping the repo-root .env (BOOMI_* vars)
# onto the CLI's baseURL/authToken.
#
#   .env keys used:  BOOMI_API_URL  BOOMI_ACCOUNT_ID  BOOMI_USERNAME  BOOMI_API_TOKEN
#                    [BOOMI_VERIFY_SSL]
#   full mode also uses:  SONAR_HOST_URL  SONAR_TOKEN  [SONAR_PROJECT_KEY]
#
# Usage:
#   bash test-env/run-local-scan.sh <componentId>[,<id2>,...] [tree|full] [referenceSource]
#
#   tree  (default) — discover + export the dependency tree, print the manifest.
#                     Needs only curl/jq/xmllint. No Semgrep/SonarQube required.
#   full            — run ci-templates/.../sonar_scan_boomi.sh end-to-end
#                     (requires semgrep + sonar-scanner + SONAR_* env).
#
set -o pipefail

COMPONENT_IDS="${1:?usage: run-local-scan.sh <componentId>[,...] [tree|full] [xml|api|both]}"
MODE="${2:-tree}"
REFSRC="${3:-both}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
[ -f "$ENV_FILE" ] || { echo "ERROR: ${ENV_FILE} not found (copy your BOOMI_* creds there)." >&2; exit 1; }

# shellcheck disable=SC1090
set -a; . "$ENV_FILE"; set +a

: "${BOOMI_API_URL:?set BOOMI_API_URL in .env}"
: "${BOOMI_ACCOUNT_ID:?set BOOMI_ACCOUNT_ID in .env}"
: "${BOOMI_USERNAME:?set BOOMI_USERNAME in .env}"
: "${BOOMI_API_TOKEN:?set BOOMI_API_TOKEN in .env}"

# ---- map BOOMI_* -> CLI baseURL/authToken -------------------------------------
BASE="${BOOMI_API_URL%/}"
case "$BASE" in */api/rest/v1*) : ;; *) BASE="${BASE}/api/rest/v1" ;; esac
case "$BASE" in */"${BOOMI_ACCOUNT_ID}") : ;; *) BASE="${BASE}/${BOOMI_ACCOUNT_ID}" ;; esac
export baseURL="${BASE}/"
# API-token auth: username must be prefixed with BOOMI_TOKEN. (unless already prefixed)
case "${BOOMI_USERNAME}" in BOOMI_TOKEN.*) PFX="" ;; *) PFX="BOOMI_TOKEN." ;; esac
export authToken="${PFX}${BOOMI_USERNAME}:${BOOMI_API_TOKEN}"

export SCRIPTS_HOME="${REPO_ROOT}/cli/scripts"
export WORKSPACE="${REPO_ROOT}/workspace"
export h1="Content-Type: application/json" h2="Accept: application/json"
export VERBOSE="${VERBOSE:-false}" SLEEP_TIMER="${SLEEP_TIMER:-0.2}"
mkdir -p "$WORKSPACE"

echo "baseURL : ${baseURL}"
echo "account : ${BOOMI_ACCOUNT_ID}"
echo "mode    : ${MODE}   referenceSource: ${REFSRC}"
echo ""

if [ "$MODE" = "full" ]; then
  export sonarHostURL="${SONAR_HOST_URL:?full mode needs SONAR_HOST_URL}"
  export sonarToken="${SONAR_TOKEN:?full mode needs SONAR_TOKEN}"
  export sonarProjectKey="${SONAR_PROJECT_KEY:-Boomi}"
  export componentIds="${COMPONENT_IDS}"
  export SCAN_REFERENCES="true" REFERENCE_SOURCE="${REFSRC}"
  export SEMGREP_FAIL_ON="${SEMGREP_FAIL_ON:-none}"
  exec bash "${REPO_ROOT}/ci-templates/azuredevops/pipelines/sonar_scan_boomi.sh"
fi

# ---- tree mode: discovery only ------------------------------------------------
TREE="${WORKSPACE}/component_tree.tsv"; : > "$TREE"
cd "$SCRIPTS_HOME" || exit 1
IFS=','; for cid in $COMPONENT_IDS; do
  cid="$(printf '%s' "$cid" | tr -d '[:space:]')"; [ -z "$cid" ] && continue
  ( source bin/getComponentTree.sh componentId="$cid" referenceSource="$REFSRC" \
      treeFile="${WORKSPACE}/_tree_${cid}.tsv" ) 2>&1 | grep -E 'getComponentTree: (scanned|discovered|reached)'
  [ -f "${WORKSPACE}/_tree_${cid}.tsv" ] && cat "${WORKSPACE}/_tree_${cid}.tsv" >> "$TREE"
done; unset IFS

awk -F'\t' '!seen[$1]++' "$TREE" > "$TREE.u" && mv "$TREE.u" "$TREE"
echo ""
echo "=== dependency tree (depth  type  name  id) ==="
awk -F'\t' '{printf "  d%-2s  %-20s  %-48s  %s\n",$4,$2,$3,substr($1,1,8)}' "$TREE"
echo ""
echo "total unique components: $(grep -c . "$TREE")   manifest: ${TREE}"
