#!/usr/bin/env bash
# Import the "Boomi" SonarQube quality profile (xml + XPathCheck rules) via the
# REST API, then set it as the default profile for the xml language.
#
# Auth (admin required for restore):
#   SONAR_ADMIN_TOKEN=squ_...        (preferred)  OR
#   SONAR_ADMIN_USER / SONAR_ADMIN_PASS          (default admin / admin)
# Usage:
#   SONAR_ADMIN_TOKEN=squ_xxx bash test-env/import-boomi-profile.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SONAR_URL="${SONAR_URL:-http://localhost:9001}"
PROFILE_FILE="${1:-${HERE}/sonarqube/boomi-quality-profile.xml}"

if [ -n "${SONAR_ADMIN_TOKEN:-}" ]; then
  AUTH=(-u "${SONAR_ADMIN_TOKEN}:")
else
  AUTH=(-u "${SONAR_ADMIN_USER:-admin}:${SONAR_ADMIN_PASS:-admin}")
fi

[ -f "$PROFILE_FILE" ] || { echo "Profile file not found: $PROFILE_FILE" >&2; exit 1; }

echo "Waiting for SonarQube at ${SONAR_URL} to be UP ..."
status=""
for _ in $(seq 1 60); do
  status="$(curl -fsS "${SONAR_URL}/api/system/status" 2>/dev/null | jq -r '.status' 2>/dev/null || echo "")"
  [ "$status" = "UP" ] && break
  sleep 5
done
[ "$status" = "UP" ] || { echo "SonarQube did not reach UP status." >&2; exit 1; }

echo "Restoring quality profile from ${PROFILE_FILE} ..."
resp="$(curl -sS -w $'\n%{http_code}' "${AUTH[@]}" -X POST \
  "${SONAR_URL}/api/qualityprofiles/restore" \
  -F "backup=@${PROFILE_FILE}")"
code="$(printf '%s' "$resp" | tail -n1)"
body="$(printf '%s' "$resp" | sed '$d')"
printf '%s\n' "$body" | jq . 2>/dev/null || printf '%s\n' "$body"

if [ "$code" != "200" ]; then
  echo "Restore failed (HTTP ${code})." >&2
  if [ "$code" = "401" ] || [ "$code" = "403" ]; then
    echo "Auth failed. On first login SonarQube forces an admin password change;" >&2
    echo "set SONAR_ADMIN_PASS to the new password or use SONAR_ADMIN_TOKEN." >&2
  fi
  exit 1
fi

echo "Setting 'Boomi' as the default profile for language 'xml' ..."
curl -sS "${AUTH[@]}" -X POST "${SONAR_URL}/api/qualityprofiles/set_default" \
  --data-urlencode "language=xml" \
  --data-urlencode "qualityProfile=Boomi" >/dev/null && echo "  default set."

echo "Done. Rules imported. Review at ${SONAR_URL}/profiles?language=xml"
