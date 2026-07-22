#!/usr/bin/env bash
# Build (if needed) and run the self-hosted Azure DevOps agent container on the
# boomi-ci network so it can reach the SonarQube container.
#
# Reads config from test-env/.env  (copy test-env/.env.example -> test-env/.env).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${HERE}/../.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

: "${AZP_URL:?Set AZP_URL in test-env/.env (e.g. https://anshumanpadhi.visualstudio.com)}"
: "${AZP_TOKEN:?Set AZP_TOKEN in test-env/.env (Azure DevOps PAT)}"
AZP_POOL="${AZP_POOL:-Default}"
AZP_AGENT_NAME="${AZP_AGENT_NAME:-boomi-podman-agent}"

SONAR_SCANNER_VERSION="${SONAR_SCANNER_VERSION:-5.0.1.3006}"
if [ ! -f "${HERE}/sonar-scanner.zip" ]; then
  echo "Fetching sonar-scanner ${SONAR_SCANNER_VERSION} on the host (reliable behind the proxy) ..."
  curl -fsSL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip" \
    -o "${HERE}/sonar-scanner.zip"
fi

# Pre-fetch the Azure DevOps agent on the host and bake it into the image, so the
# container never does the large runtime CDN download (which stalls behind the proxy).
# For an amd64 host, set AZP_AGENT_PLATFORM=linux-x64.
AZP_AGENT_PLATFORM="${AZP_AGENT_PLATFORM:-linux-arm64}"
if [ ! -f "${HERE}/azp-agent.tgz" ]; then
  echo "Fetching the Azure DevOps agent (${AZP_AGENT_PLATFORM}) on the host ..."
  agent_url="$(curl -fsSL --connect-timeout 20 --max-time 60 -u "user:${AZP_TOKEN}" -H 'Accept: application/json' \
    "${AZP_URL}/_apis/distributedtask/packages/agent?platform=${AZP_AGENT_PLATFORM}" \
    | jq -r --arg p "$AZP_AGENT_PLATFORM" 'first(.value[]? | select(.platform==$p) | .downloadUrl) // empty')"
  [ -n "$agent_url" ] || { echo "ERROR: could not resolve agent URL (check AZP_URL/AZP_TOKEN)." >&2; exit 1; }
  curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 --max-time 600 -o "${HERE}/azp-agent.tgz" "$agent_url"
fi

if ! ls "${HERE}/certs/"*.crt >/dev/null 2>&1; then
  echo "WARNING: no CA in test-env/agent/certs/. If you are behind a TLS-intercepting"
  echo "         proxy (e.g. Zscaler), agent registration to Azure DevOps may fail."
  echo "         Export your root CA, e.g.:"
  echo "           security find-certificate -a -c Zscaler -p /Library/Keychains/System.keychain > ${HERE}/certs/zscaler.crt"
fi

echo "Ensuring network 'boomi-ci' exists ..."
podman network exists boomi-ci 2>/dev/null || podman network create boomi-ci

echo "Building agent image (boomi-azdo-agent) ..."
podman build --arch arm64 -t boomi-azdo-agent "$HERE"

echo "Starting agent '${AZP_AGENT_NAME}' in pool '${AZP_POOL}' ..."
podman rm -f boomi-azdo-agent 2>/dev/null || true
podman run -d --name boomi-azdo-agent \
  --network boomi-ci \
  -e AZP_URL="${AZP_URL}" \
  -e AZP_TOKEN="${AZP_TOKEN}" \
  -e AZP_POOL="${AZP_POOL}" \
  -e AZP_AGENT_NAME="${AZP_AGENT_NAME}" \
  boomi-azdo-agent

echo "Agent starting. Follow logs with:  podman logs -f boomi-azdo-agent"
