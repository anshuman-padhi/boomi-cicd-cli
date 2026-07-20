#!/usr/bin/env bash
#
# Extract embedded Groovy/JavaScript from Boomi component XML into standalone files
# so a SAST tool (Semgrep) can analyze them.
#
# Boomi stores script bodies as XML-escaped text inside <script> elements, under
# <dataprocessscript language="groovy2|javascript"> (Data Process shapes) and
# scripting-function steps. xmllint's string() decodes the entities back to source.
#
# Usage: extract_scripts.sh <components-dir> <out-dir>
set -o pipefail

SRC_DIR="${1:?usage: extract_scripts.sh <components-dir> <out-dir>}"
OUT_DIR="${2:?usage: extract_scripts.sh <components-dir> <out-dir>}"
mkdir -p "$OUT_DIR"

shopt -s nullglob
total=0
for xml in "$SRC_DIR"/*.xml; do
  base="$(basename "$xml" .xml)"
  count="$(xmllint --xpath 'count(//*[local-name()="script"])' "$xml" 2>/dev/null)"
  [ -z "$count" ] && count=0
  i=1
  while [ "$i" -le "$count" ]; do
    # language from the nearest ancestor carrying @language (dataprocessscript / scriptingfunction)
    lang="$(xmllint --xpath "string((//*[local-name()='script'])[$i]/ancestor-or-self::*[@language][1]/@language)" "$xml" 2>/dev/null)"
    ext="groovy"
    case "$lang" in *avascript*|*js*) ext="js" ;; esac
    body="$(xmllint --xpath "string((//*[local-name()='script'])[$i])" "$xml" 2>/dev/null)"
    if [ -n "$body" ]; then
      printf '%s\n' "$body" > "${OUT_DIR}/${base}_${i}.${ext}"
      total=$((total + 1))
      echo "  extracted ${base}_${i}.${ext} (language=${lang:-unknown})"
    fi
    i=$((i + 1))
  done
done
echo "Extracted ${total} script(s) to ${OUT_DIR}"
