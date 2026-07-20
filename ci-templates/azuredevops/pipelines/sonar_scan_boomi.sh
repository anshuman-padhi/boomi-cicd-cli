#!/usr/bin/env bash
#
# Boomi component security + quality scan:
#   1. export component XML (live, via the CLI)
#   2. extract embedded Groovy/JS scripts
#   3. SAST-scan the scripts with Semgrep (SQLi/XSS/XXE/creds/cmd-exec/…) -> SARIF
#   4. run SonarQube: Boomi XPath profile on the XML + JS/secrets rules + Semgrep SARIF import
#
# Required env (Azure DevOps variable groups):
#   authToken baseURL componentIds sonarHostURL sonarToken   (+ SCRIPTS_HOME WORKSPACE)
# Optional: sonarProjectKey (default Boomi), SEMGREP_CONFIG, SEMGREP_FAIL_ON (error|warning)
# NOTE: no 'set -u' — sourced CLI scripts reference unset vars by design.
set -o pipefail

: "${authToken:?authToken is required}"
: "${baseURL:?baseURL is required}"
: "${componentIds:?componentIds is required (comma-separated)}"
: "${sonarHostURL:?sonarHostURL is required}"
: "${sonarToken:?sonarToken is required}"
: "${SCRIPTS_HOME:?SCRIPTS_HOME is required}"
: "${WORKSPACE:?WORKSPACE is required}"
sonarProjectKey="${sonarProjectKey:-Boomi}"
SEMGREP_FAIL_ON="${SEMGREP_FAIL_ON:-}"   # empty = report only; 'error' or 'warning' = gate the build

export h1="${h1:-Content-Type: application/json}" h2="${h2:-Accept: application/json}"
export VERBOSE="${VERBOSE:-false}" SLEEP_TIMER="${SLEEP_TIMER:-0.2}"
export SCRIPTS_HOME WORKSPACE authToken baseURL h1 h2 VERBOSE SLEEP_TIMER

PIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${PIPE_DIR}/../../.." && pwd)"
SEMGREP_CONFIG="${SEMGREP_CONFIG:-${REPO_ROOT}/test-env/semgrep/boomi-scripts.yml}"

SCAN_ROOT="${WORKSPACE}/boomi-scan"
COMP_DIR="${SCAN_ROOT}/components"
SCRIPTS_DIR="${SCAN_ROOT}/scripts"
rm -rf "$SCAN_ROOT"; mkdir -p "$COMP_DIR" "$SCRIPTS_DIR"

# ---------------------------------------------------------------- 1) export
cd "$SCRIPTS_HOME" || { echo "ERROR: cannot cd to SCRIPTS_HOME=$SCRIPTS_HOME" >&2; exit 1; }
exported=0
IFS=',' read -ra IDS <<< "$componentIds"
for raw in "${IDS[@]}"; do
  cid="$(echo "$raw" | xargs)"; [ -z "$cid" ] && continue
  echo "==> Exporting Boomi component: $cid"
  ( source bin/getComponent.sh componentId="$cid" version="" ) || true
  src="${WORKSPACE}/${cid}.xml"
  if [ -s "$src" ] && grep -q "Component" "$src" 2>/dev/null; then
    cp "$src" "${COMP_DIR}/${cid}.xml"; exported=$((exported + 1))
  else
    echo "    WARN: no valid component XML for '$cid' (check componentId / credentials)" >&2
  fi
done
[ "$exported" -eq 0 ] && { echo "ERROR: no components exported — nothing to scan." >&2; exit 1; }
echo "Exported ${exported} component(s)."

# ---------------------------------------------------------------- 2) extract scripts
bash "${PIPE_DIR}/extract_scripts.sh" "$COMP_DIR" "$SCRIPTS_DIR" || true

# ---------------------------------------------------------------- 3) Semgrep SAST
sarif="${SCAN_ROOT}/semgrep.sarif"
sg_total=0; sg_err=0
if ls "$SCRIPTS_DIR"/* >/dev/null 2>&1; then
  echo "==> Semgrep scanning $(ls "$SCRIPTS_DIR" | wc -l | tr -d ' ') extracted script(s)..."
  ( cd "$SCAN_ROOT" && semgrep scan --config "$SEMGREP_CONFIG" \
      --metrics off --disable-version-check --sarif --output "$sarif" scripts ) || true
  if [ -f "$sarif" ]; then
    sg_total=$(jq '[.runs[].results[]?] | length' "$sarif" 2>/dev/null || echo 0)
    sg_err=$(jq '[.runs[].results[]? | select(.level=="error")] | length' "$sarif" 2>/dev/null || echo 0)
    echo "Semgrep findings: ${sg_total} (error: ${sg_err})"
    jq -r '.runs[].results[]? | "  [\(.level)] \(.ruleId) — \(.locations[0].physicalLocation.artifactLocation.uri):\(.locations[0].physicalLocation.region.startLine)"' "$sarif" 2>/dev/null
  fi
else
  echo "No embedded Groovy/JS scripts found in the exported component(s)."
fi

# ---------------------------------------------------------------- 4) SonarQube
echo "sonarHostURL=${sonarHostURL}  sonarToken length=${#sonarToken}"
echo "SonarQube auth preflight: $(curl -s -u "${sonarToken}:" "${sonarHostURL}/api/authentication/validate")"
sarif_arg=(); [ -f "$sarif" ] && sarif_arg=(-Dsonar.sarifReportPaths=semgrep.sarif)

sonar-scanner \
  -Dsonar.projectKey="${sonarProjectKey}" \
  -Dsonar.projectName="Boomi Components" \
  -Dsonar.projectBaseDir="${SCAN_ROOT}" \
  -Dsonar.sources=. \
  -Dsonar.inclusions="**/*.xml,**/*.groovy,**/*.js" \
  -Dsonar.scm.disabled=true \
  "${sarif_arg[@]}" \
  -Dsonar.host.url="${sonarHostURL}" \
  -Dsonar.token="${sonarToken}"
scan_rc=$?
if [ "$scan_rc" -ne 0 ]; then
  echo "ERROR: sonar-scanner failed (exit ${scan_rc})." >&2
  exit "$scan_rc"
fi

echo "Done. SonarQube: ${sonarHostURL}/dashboard?id=${sonarProjectKey}"
[ -f "$sarif" ] && echo "Semgrep SARIF: ${sarif}"

# ---------------------------------------------------------------- optional build gate
if [ -n "$SEMGREP_FAIL_ON" ]; then
  if { [ "$SEMGREP_FAIL_ON" = "error" ] && [ "$sg_err" -gt 0 ]; } \
  || { [ "$SEMGREP_FAIL_ON" = "warning" ] && [ "$sg_total" -gt 0 ]; }; then
    echo "FAIL: Semgrep quality gate '${SEMGREP_FAIL_ON}' — errors=${sg_err}, total=${sg_total}" >&2
    exit 3
  fi
fi
