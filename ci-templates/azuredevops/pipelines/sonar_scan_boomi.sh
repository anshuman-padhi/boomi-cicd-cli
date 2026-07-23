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

# Recursive dependency discovery: scan the entry component(s) PLUS every component they
# reference (sub-processes, referenced Process Script components, profiles, connector
# operations/settings ...), discovered transitively and de-duplicated.
SCAN_REFERENCES="${SCAN_REFERENCES:-true}"   # false = scan only the exact componentIds given
REFERENCE_SOURCE="${REFERENCE_SOURCE:-both}" # xml | api | both  (both = XML-scrape ∪ ComponentReference API)
MAX_COMPONENTS="${MAX_COMPONENTS:-300}"      # safety cap on total tree size
MAX_DEPTH="${MAX_DEPTH:-15}"                 # safety cap on recursion depth

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

# Stage a component XML into COMP_DIR named after its process/component @name, so the
# process NAME (not the bare component id) shows in SonarQube and in script filenames.
stage_component() {
  local src="$1" idhint="$2" name safe
  name="$(xmllint --xpath 'string(/*[local-name()="Component"]/@name)' "$src" 2>/dev/null)"
  safe="$(printf '%s' "${name:-$idhint}" | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^_*//; s/_*$//')"
  [ -z "$safe" ] && safe="$idhint"
  cp "$src" "${COMP_DIR}/${safe}__${idhint}.xml"
  printf '%s' "$safe"
}

# Discover + export the component(s). With SCAN_REFERENCES=true (default) each input id
# is expanded into its full dependency tree (deduped) via getComponentTree.sh; otherwise
# only the exact ids given are exported. The manifest TSV drives staging, so transient or
# non-component exports (out.xml, error responses) are never scanned.
TREE_ALL="${SCAN_ROOT}/component_tree.tsv"; : > "$TREE_ALL"
exported=0
IFS=',' read -ra IDS <<< "$componentIds"
for raw in "${IDS[@]}"; do
  cid="$(echo "$raw" | xargs)"; [ -z "$cid" ] && continue
  case "$SCAN_REFERENCES" in
    [Tt][Rr][Uu][Ee] | 1 | [Yy][Ee][Ss])
      echo "==> Discovering dependency tree from: $cid (source=${REFERENCE_SOURCE}, maxComponents=${MAX_COMPONENTS}, maxDepth=${MAX_DEPTH})"
      tf="${WORKSPACE}/_tree_${cid}.tsv"
      ( source bin/getComponentTree.sh componentId="$cid" referenceSource="$REFERENCE_SOURCE" \
          maxComponents="$MAX_COMPONENTS" maxDepth="$MAX_DEPTH" treeFile="$tf" ) || true
      [ -f "$tf" ] && cat "$tf" >> "$TREE_ALL"
      ;;
    *)
      echo "==> Exporting single Boomi component: $cid"
      ( source bin/getComponent.sh componentId="$cid" version="" ) || true
      src="${WORKSPACE}/${cid}.xml"
      if [ -s "$src" ] && grep -q "Component" "$src" 2>/dev/null; then
        ctype="$(xmllint --xpath "string(/*[local-name()='Component']/@type)" "$src" 2>/dev/null)"
        printf '%s\t%s\t%s\t%s\n' "$cid" "${ctype:-component}" "$cid" "0" >> "$TREE_ALL"
      else
        echo "    WARN: no valid component XML for '$cid' (check componentId / credentials)" >&2
      fi
      ;;
  esac
done

# Stage every UNIQUE discovered component (named by its @name) into COMP_DIR for scanning.
if [ -s "$TREE_ALL" ]; then
  awk -F'\t' '!seen[$1]++' "$TREE_ALL" > "${TREE_ALL}.uniq" && mv "${TREE_ALL}.uniq" "$TREE_ALL"
  while IFS=$'\t' read -r tid ttype tname tdepth; do
    [ -z "$tid" ] && continue
    src="${WORKSPACE}/${tid}.xml"
    [ -s "$src" ] || continue
    nm="$(stage_component "$src" "${tid:0:8}")"
    exported=$((exported + 1))
    echo "    staged ${nm}__${tid:0:8}.xml  (${ttype}, depth ${tdepth})"
  done < "$TREE_ALL"
  echo "Staged ${exported} unique component(s) from the dependency tree."
fi

# (demo) stage the deliberately-vulnerable sample PROCESS component(s) so a run always
# shows findings — the risky Groovy lives in a real Data Process shape (not external
# scripts), so both Semgrep (extracted code) and the SonarQube XPath rules fire.
# Enable via the pipeline's includeSampleFindings parameter (Azure stringifies bools).
case "${INCLUDE_SAMPLE_FINDINGS:-false}" in
  [Tt][Rr][Uu][Ee] | 1 | [Yy][Ee][Ss])
    for s in "${REPO_ROOT}/test-env/samples/"*.xml; do
      [ -e "$s" ] || continue
      nm="$(stage_component "$s" "sample")"
      echo "NOTE: included risky sample component '${nm}' (deliberately vulnerable)."
    done
    ;;
esac

if ! ls "${COMP_DIR}"/*.xml >/dev/null 2>&1; then
  echo "ERROR: no component XML to scan (no export succeeded and no sample included)." >&2
  exit 1
fi
echo "Staged $(ls "${COMP_DIR}"/*.xml | wc -l | tr -d ' ') component(s) for scanning."

# ---------------------------------------------------------------- 2) extract scripts
bash "${PIPE_DIR}/extract_scripts.sh" "$COMP_DIR" "$SCRIPTS_DIR" || true

# ---------------------------------------------------------------- 3) Semgrep SAST
sarif="${SCAN_ROOT}/semgrep.sarif"
sg_total=0; sg_err=0
if ls "$SCRIPTS_DIR"/* >/dev/null 2>&1; then
  echo "==> Semgrep scanning $(ls "$SCRIPTS_DIR" | wc -l | tr -d ' ') extracted script(s)..."
  # Local ruleset always; optionally layer registry packs via SEMGREP_EXTRA_CONFIG
  # (space-separated, e.g. "p/security-audit p/secrets") when the registry is reachable.
  sg_cfg=(--config "$SEMGREP_CONFIG")
  for extra in ${SEMGREP_EXTRA_CONFIG:-}; do sg_cfg+=(--config "$extra"); done
  # --no-git-ignore: the scripts live under the (git-ignored) workspace dir inside the
  # checked-out repo; without this Semgrep scans "0 files tracked by git".
  ( cd "$SCAN_ROOT" && semgrep scan "${sg_cfg[@]}" \
      --metrics off --disable-version-check --no-git-ignore --sarif --output "$sarif" scripts ) || true
  if [ -f "$sarif" ]; then
    # Semgrep records severity on the RULE (defaultConfiguration.level), not on the
    # result — so map ruleId -> level for both the error count and the printout.
    sg_total=$(jq '[.runs[].results[]?] | length' "$sarif" 2>/dev/null || echo 0)
    sg_err=$(jq '
      (.runs[0].tool.driver.rules // [] | map({key:.id, value:(.defaultConfiguration.level // "warning")}) | from_entries) as $lvl
      | [ .runs[].results[]? | select( ($lvl[.ruleId] // .level // "warning") == "error") ] | length' \
      "$sarif" 2>/dev/null || echo 0)
    echo "Semgrep findings: ${sg_total} (error: ${sg_err})"
    jq -r '
      (.runs[0].tool.driver.rules // [] | map({key:.id, value:(.defaultConfiguration.level // "warning")}) | from_entries) as $lvl
      | .runs[].results[]?
      | "  [\(($lvl[.ruleId] // .level // "warning") | ascii_upcase)] \(.ruleId | sub(".*[.]";"")) — \(.locations[0].physicalLocation.artifactLocation.uri):\(.locations[0].physicalLocation.region.startLine)"' \
      "$sarif" 2>/dev/null
  fi
else
  echo "No embedded Groovy/JS scripts found in the exported component(s)."
fi

# ---------------------------------------------------------------- 4) SonarQube
echo "sonarHostURL=${sonarHostURL}  sonarToken length=${#sonarToken}"
# Auth preflight — pass the token via a curl config on stdin (-K -) so it never appears
# in the process argv (ps aux) or in a traced command line; print only the HTTP status.
sonar_http="$(printf 'user = "%s:"\n' "${sonarToken}" \
  | curl -s -K - -o /dev/null -w '%{http_code}' "${sonarHostURL}/api/authentication/validate")"
echo "SonarQube auth preflight: HTTP ${sonar_http}"
sarif_arg=(); [ -f "$sarif" ] && sarif_arg=(-Dsonar.sarifReportPaths=semgrep.sarif)

# Pass the token via the SONAR_TOKEN env var (read natively by sonar-scanner) instead of
# -Dsonar.token=..., so the secret is not exposed in the long-lived process's argv.
export SONAR_TOKEN="${sonarToken}"
sonar-scanner \
  -Dsonar.projectKey="${sonarProjectKey}" \
  -Dsonar.projectName="Boomi Components" \
  -Dsonar.projectBaseDir="${SCAN_ROOT}" \
  -Dsonar.sources=. \
  -Dsonar.inclusions="**/*.xml,**/*.groovy,**/*.js" \
  -Dsonar.import_unknown_files=true \
  -Dsonar.scm.disabled=true \
  "${sarif_arg[@]}" \
  -Dsonar.host.url="${sonarHostURL}"
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
