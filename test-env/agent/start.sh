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

if [ -x ./config.sh ]; then
  # Agent pre-baked into the image (run-agent.sh fetched it on the host) — no large
  # runtime download, which is unreliable from inside the container behind the proxy.
  echo "1/2 Using pre-baked agent."
else
  echo "1/2 No baked agent found — downloading from ${AZP_URL} (with retries) ..."
  # Resilient curl: bounded connect/transfer time, abort on stalls (<1KB/s for 60s),
  # retry transient failures/timeouts (the CDN download can hang behind a proxy).
  CURL_DL=(--fail --location --show-error --silent
    --connect-timeout 30 --max-time 900 --speed-limit 1024 --speed-time 60
    --retry 6 --retry-delay 5 --retry-connrefused)
  CURL_API=(--fail --location --show-error --silent
    --connect-timeout 20 --max-time 120 --retry 6 --retry-delay 3 --retry-connrefused)
  # Do NOT pin api-version; a plain Accept returns the real package list.
  PACKAGE_URL="$(curl "${CURL_API[@]}" -u "user:${AZP_TOKEN}" -H 'Accept: application/json' \
    "${AZP_URL}/_apis/distributedtask/packages/agent?platform=linux-arm64" \
    | jq -r 'first(.value[]? | select(.platform=="linux-arm64") | .downloadUrl) // empty')"
  if [ -z "${PACKAGE_URL}" ] || [ "${PACKAGE_URL}" = "null" ]; then
    echo "ERROR: could not resolve the agent package URL (check AZP_URL / PAT scope)." >&2
    exit 1
  fi
  for attempt in 1 2 3; do
    if curl "${CURL_DL[@]}" -o /azp/agent.tgz "${PACKAGE_URL}"; then break; fi
    echo "   download attempt ${attempt} failed; retrying in 10s ..." >&2
    sleep 10
    [ "$attempt" = "3" ] && { echo "ERROR: agent package download failed after retries." >&2; exit 1; }
  done
  tar -xzf /azp/agent.tgz && rm -f /azp/agent.tgz
fi

echo "2/2 Configuring agent '${AZP_AGENT_NAME}' in pool '${AZP_POOL}' ..."
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
