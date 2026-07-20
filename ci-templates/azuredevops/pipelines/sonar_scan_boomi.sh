#!/usr/bin/env bash
#
# Export Boomi component XML (live, via the CLI) and scan it with SonarQube using
# the imported "Boomi" quality profile (language: xml, XPathCheck rules).
#
# Required env (from Azure DevOps variable groups):
#   authToken       ACCOUNT.user:token   (secret)
#   baseURL         https://api.boomi.com/api/rest/v1/ACCOUNT_ID/
#   componentIds    comma-separated Boomi component IDs to export & scan
#   sonarHostURL    e.g. http://boomi-sonarqube:9000
#   sonarToken      SonarQube analysis token (secret)
# Optional:
#   sonarProjectKey (default: Boomi)
# Provided by the pipeline: SCRIPTS_HOME, WORKSPACE
# NOTE: no 'set -u' — the sourced CLI scripts (e.g. getComponent.sh) reference
# unset vars by design; nounset would abort them.
set -o pipefail

: "${authToken:?authToken is required (ACCOUNT.user:token)}"
: "${baseURL:?baseURL is required}"
: "${componentIds:?componentIds is required (comma-separated)}"
: "${sonarHostURL:?sonarHostURL is required (e.g. http://boomi-sonarqube:9000)}"
: "${sonarToken:?sonarToken is required}"
: "${SCRIPTS_HOME:?SCRIPTS_HOME is required}"
: "${WORKSPACE:?WORKSPACE is required}"
sonarProjectKey="${sonarProjectKey:-Boomi}"

export h1="${h1:-Content-Type: application/json}"
export h2="${h2:-Accept: application/json}"
export VERBOSE="${VERBOSE:-false}"
export SLEEP_TIMER="${SLEEP_TIMER:-0.2}"
export SCRIPTS_HOME WORKSPACE authToken baseURL h1 h2 VERBOSE SLEEP_TIMER

mkdir -p "$WORKSPACE"
SCAN_DIR="${WORKSPACE}/boomi-components"
rm -rf "$SCAN_DIR"; mkdir -p "$SCAN_DIR"

cd "$SCRIPTS_HOME" || { echo "ERROR: cannot cd to SCRIPTS_HOME=$SCRIPTS_HOME" >&2; exit 1; }

exported=0
IFS=',' read -ra IDS <<< "$componentIds"
for raw in "${IDS[@]}"; do
  cid="$(echo "$raw" | xargs)"   # trim surrounding whitespace
  [ -z "$cid" ] && continue
  echo "==> Exporting Boomi component: $cid"
  # getComponent.sh writes ${WORKSPACE}/${cid}.xml; run in a subshell so its
  # globals / 'clean' don't leak into this script.
  ( source bin/getComponent.sh componentId="$cid" version="" ) || true
  src="${WORKSPACE}/${cid}.xml"
  if [ -s "$src" ] && grep -q "Component" "$src" 2>/dev/null; then
    cp "$src" "${SCAN_DIR}/${cid}.xml"
    exported=$((exported + 1))
    echo "    exported -> boomi-components/${cid}.xml"
  else
    echo "    WARN: no valid component XML for '$cid' (check componentId / credentials)" >&2
    [ -s "$src" ] && head -c 400 "$src" >&2 && echo >&2
  fi
done

if [ "$exported" -eq 0 ]; then
  echo "ERROR: no components exported — nothing to scan." >&2
  exit 1
fi
echo "Exported ${exported} component(s). Running SonarQube scan..."

# Preflight: does the token authenticate? Distinguishes an empty/unmapped secret
# (length 0) from an invalid token ({"valid":false}). The value is never printed.
echo "sonarHostURL=${sonarHostURL}  sonarToken length=${#sonarToken}"
echo "SonarQube auth preflight: $(curl -s -u "${sonarToken}:" "${sonarHostURL}/api/authentication/validate")"

# projectBaseDir must contain sources. The script cd's into SCRIPTS_HOME, so set
# the base dir explicitly to the export folder and scan it with sources=. — otherwise
# the scanner indexes 0 files and the project comes up empty.
sonar-scanner \
  -Dsonar.projectKey="${sonarProjectKey}" \
  -Dsonar.projectName="Boomi Components" \
  -Dsonar.projectBaseDir="${SCAN_DIR}" \
  -Dsonar.sources=. \
  -Dsonar.inclusions="**/*.xml" \
  -Dsonar.scm.disabled=true \
  -Dsonar.host.url="${sonarHostURL}" \
  -Dsonar.token="${sonarToken}"
scan_rc=$?

if [ "$scan_rc" -ne 0 ]; then
  echo "ERROR: sonar-scanner failed (exit ${scan_rc}). If 'Not authorized': regenerate a" >&2
  echo "       Global Analysis Token in SonarQube and update the 'sonarToken' secret." >&2
  exit "$scan_rc"
fi
echo "Scan submitted. Results: ${sonarHostURL}/dashboard?id=${sonarProjectKey}"
