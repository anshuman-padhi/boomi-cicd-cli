#!/usr/bin/env bash
# Entrypoint for the self-hosted Azure DevOps agent container.
# Downloads the agent package matching your Azure DevOps server, configures it
# unattended, and runs it. Removes the agent registration on container stop.
set -euo pipefail

: "${AZP_URL:?AZP_URL is required, e.g. https://dev.azure.com/ORG or https://ORG.visualstudio.com}"
: "${AZP_TOKEN:?AZP_TOKEN is required (Azure DevOps PAT with 'Agent Pools: Read & manage')}"
AZP_POOL="${AZP_POOL:-Default}"
AZP_AGENT_NAME="${AZP_AGENT_NAME:-boomi-podman-agent}"
AZP_WORK="${AZP_WORK:-_work}"

cd /azp

cleanup() {
  if [ -e ./config.sh ]; then
    echo "Removing agent registration..."
    ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN" || true
  fi
}
trap 'cleanup; exit 0' EXIT INT TERM

echo "1/3 Resolving agent package for linux-arm64 from ${AZP_URL} ..."
# NOTE: do NOT pin api-version here. Some orgs return a stub ({"url":null}) for
# 'api-version=6.0-preview.1'; a plain Accept returns the real package list.
PACKAGE_URL="$(curl -LsS -u "user:${AZP_TOKEN}" -H 'Accept: application/json' \
  "${AZP_URL}/_apis/distributedtask/packages/agent?platform=linux-arm64" \
  | jq -r 'first(.value[]? | select(.platform=="linux-arm64") | .downloadUrl) // empty')"

if [ -z "${PACKAGE_URL}" ] || [ "${PACKAGE_URL}" = "null" ]; then
  echo "ERROR: could not resolve the agent package URL." >&2
  echo "       Check AZP_URL and that the PAT has 'Agent Pools: Read & manage'." >&2
  exit 1
fi

echo "2/3 Downloading and extracting agent ..."
curl -LsS "${PACKAGE_URL}" | tar -xz

echo "3/3 Configuring agent '${AZP_AGENT_NAME}' in pool '${AZP_POOL}' ..."
./config.sh --unattended \
  --agent "${AZP_AGENT_NAME}" \
  --url "${AZP_URL}" \
  --auth pat --token "${AZP_TOKEN}" \
  --pool "${AZP_POOL}" \
  --work "${AZP_WORK}" \
  --replace \
  --acceptTeeEula

echo "Agent configured. Starting (Ctrl-C to stop and unregister) ..."
./run.sh "$@"
