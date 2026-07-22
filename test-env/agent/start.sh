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

# Resilient curl: bounded connect/transfer time, abort on stalls (< 1KB/s for 60s),
# and retry transient failures/timeouts — the dev.azure.com CDN download otherwise
# occasionally hangs indefinitely behind the proxy.
CURL_DL=(--fail --location --show-error --silent
  --connect-timeout 30 --max-time 900 --speed-limit 1024 --speed-time 60
  --retry 6 --retry-delay 5 --retry-connrefused)
CURL_API=(--fail --location --show-error --silent
  --connect-timeout 20 --max-time 120 --retry 6 --retry-delay 3 --retry-connrefused)

echo "1/3 Resolving agent package for linux-arm64 from ${AZP_URL} ..."
# NOTE: do NOT pin api-version here. Some orgs return a stub ({"url":null}) for
# 'api-version=6.0-preview.1'; a plain Accept returns the real package list.
PACKAGE_URL="$(curl "${CURL_API[@]}" -u "user:${AZP_TOKEN}" -H 'Accept: application/json' \
  "${AZP_URL}/_apis/distributedtask/packages/agent?platform=linux-arm64" \
  | jq -r 'first(.value[]? | select(.platform=="linux-arm64") | .downloadUrl) // empty')"

if [ -z "${PACKAGE_URL}" ] || [ "${PACKAGE_URL}" = "null" ]; then
  echo "ERROR: could not resolve the agent package URL." >&2
  echo "       Check AZP_URL and that the PAT has 'Agent Pools: Read & manage'." >&2
  exit 1
fi

echo "2/3 Downloading agent package (with retries) ..."
# Download to a file (not piped to tar) so a retried attempt can't corrupt the stream.
for attempt in 1 2 3; do
  if curl "${CURL_DL[@]}" -o /azp/agent.tgz "${PACKAGE_URL}"; then break; fi
  echo "   download attempt ${attempt} failed; retrying in 10s ..." >&2
  sleep 10
  [ "$attempt" = "3" ] && { echo "ERROR: agent package download failed after retries." >&2; exit 1; }
done
echo "    extracting ..."
tar -xzf /azp/agent.tgz && rm -f /azp/agent.tgz

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
