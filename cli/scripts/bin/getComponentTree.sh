#!/bin/bash
#
# getComponentTree.sh — recursively discover and export a Boomi component and ALL
# the components it references (sub-processes, referenced Process Script components,
# profiles, connector operations/settings, ...), so a downstream SAST/quality scan
# covers the whole dependency tree instead of just the entry component.
#
# Discovery per component (deduplicated union):
#   1. XML-scrape  — parse referenced component GUIDs out of the exported Component XML
#                    (authoritative for the process definition; works on unpackaged/draft
#                     components; a proven superset of the ComponentReference table).
#   2. ComponentReference API — Boomi's recorded reference edges (one level; requires the
#                    parent version, read from the exported XML). Union'd in for safety.
# A visited-set makes traversal cycle-safe; only code/flow-bearing components
# (process / processroute / script*) are recursed into, but every reachable component
# is exported (leaves too) so XML/XPath rules cover config components as well.
#
# Usage (sourced, like the other bin/ scripts):
#   source bin/getComponentTree.sh componentId=<id> [referenceSource=xml|api|both] \
#          [maxComponents=300] [maxDepth=15] [treeFile=<path>]
#
# Output:
#   - ${WORKSPACE}/<id>.xml for every discovered component (via getComponent.sh)
#   - a TSV manifest (treeFile, default ${WORKSPACE}/component_tree.tsv):
#         <componentId>\t<type>\t<name>\t<depth>
#
# Testable: set GCT_LIB_ONLY=1 before sourcing to load the functions WITHOUT running
# the traversal, then drive the gct_* functions directly (see cli/tests/test_component_tree.sh).

GCT_GUID_RE='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

# Read a root <Component> attribute (type / name / version) from an exported XML file.
gct_root_attr() {
  xmllint --xpath "string(/*[local-name()='Component']/@$2)" "$1" 2>/dev/null
}

# Print the referenced component GUIDs found in an XML file (lowercased, unique, self excluded).
gct_scrape_guids() {
  local xml="$1" self="$2"
  [ -f "$xml" ] || return 0
  grep -oE "$GCT_GUID_RE" "$xml" 2>/dev/null \
    | tr 'A-F' 'a-f' | sort -u | grep -iv "^${self}$"
}

# Should we recurse INTO this component's references? Only code/flow-bearing types.
gct_should_recurse() {
  case "$1" in
    process|processroute|script.processing|script) return 0 ;;
    *) return 1 ;;
  esac
}

# Export one component's XML to ${WORKSPACE}/<id>.xml. Overridable in tests via GCT_FIXTURE_DIR.
gct_export() {
  local id="$1"
  if [ -n "${GCT_FIXTURE_DIR:-}" ]; then
    [ -f "${GCT_FIXTURE_DIR}/${id}.xml" ] || return 1
    cp "${GCT_FIXTURE_DIR}/${id}.xml" "${WORKSPACE}/${id}.xml"
    return 0
  fi
  ( cd "$SCRIPTS_HOME" && source bin/getComponent.sh componentId="$id" version="" ) >/dev/null 2>&1 || true
  [ -s "${WORKSPACE}/${id}.xml" ]
}

# Print child GUIDs from the Boomi ComponentReference API. No-op when referenceSource=xml.
# Overridable in tests by defining gct_api_child_ids_impl.
gct_api_child_ids() {
  local id="$1" xml="$2"
  if declare -F gct_api_child_ids_impl >/dev/null 2>&1; then
    gct_api_child_ids_impl "$id" "$xml"; return 0
  fi
  [ "${GCT_REFERENCE_SOURCE:-both}" = "xml" ] && return 0
  local ver; ver="$(gct_root_attr "$xml" version)"
  ( cd "$SCRIPTS_HOME" && source bin/queryComponentReferences.sh componentId="$id" parentVersion="$ver" ) >/dev/null 2>&1 || true
  [ -f "${WORKSPACE}/_refs_${id}.txt" ] && cat "${WORKSPACE}/_refs_${id}.txt"
  return 0
}

# Breadth-first traversal from one or more comma-separated root ids.
gct_build_tree() {
  local roots="$1"
  local max_comp="${GCT_MAX_COMPONENTS:-300}"
  local max_depth="${GCT_MAX_DEPTH:-15}"
  local tree_file="${GCT_TREE_FILE:-${WORKSPACE}/component_tree.tsv}"
  : > "$tree_file"

  local visited=" "          # space-delimited set: " id1 id2 "
  local q_ids=() q_depth=()   # parallel-array FIFO (bash 3.2 safe)
  local r oldIFS="$IFS"
  IFS=','
  for r in $roots; do
    r="$(printf '%s' "$r" | tr -d '[:space:]')"
    [ -n "$r" ] && { q_ids+=("$r"); q_depth+=("0"); }
  done
  IFS="$oldIFS"

  local count=0 head=0
  while [ "$head" -lt "${#q_ids[@]}" ]; do
    local id="${q_ids[$head]}"; local depth="${q_depth[$head]}"; head=$((head + 1))
    case "$visited" in *" $id "*) continue ;; esac
    if [ "$count" -ge "$max_comp" ]; then
      echo "[WARN] getComponentTree: reached max components ($max_comp); stopping discovery — some referenced components were NOT scanned." >&2
      break
    fi
    if ! gct_export "$id"; then
      echo "[WARN] getComponentTree: could not export component '$id' (skipping)." >&2
      continue
    fi
    local xml="${WORKSPACE}/${id}.xml"
    local ctype cname
    ctype="$(gct_root_attr "$xml" type)"
    cname="$(gct_root_attr "$xml" name)"
    if [ -z "$ctype" ]; then
      echo "[WARN] getComponentTree: '$id' did not return a valid Component (skipping)." >&2
      continue
    fi
    visited="${visited}${id} "
    count=$((count + 1))
    printf '%s\t%s\t%s\t%s\n' "$id" "$ctype" "$cname" "$depth" >> "$tree_file"
    echo "[INFO] getComponentTree: scanned ${ctype} '${cname}' (${id}) at depth ${depth}"

    # Enqueue children only for code/flow-bearing types and within the depth budget.
    if gct_should_recurse "$ctype" && [ "$depth" -lt "$max_depth" ]; then
      local child
      while IFS= read -r child; do
        [ -z "$child" ] && continue
        case "$visited" in *" $child "*) continue ;; esac
        q_ids+=("$child"); q_depth+=("$((depth + 1))")
      done < <( { gct_scrape_guids "$xml" "$id"; gct_api_child_ids "$id" "$xml"; } \
                  | tr 'A-F' 'a-f' | grep -oE "$GCT_GUID_RE" | sort -u )
    fi
  done

  echo "[INFO] getComponentTree: discovered ${count} component(s); manifest -> ${tree_file}"
  return 0
}

# ------------------------------------------------------------------ main
if [ -z "${GCT_LIB_ONLY:-}" ]; then
  source bin/common.sh
  unset referenceSource maxComponents maxDepth treeFile
  ARGUMENTS=(componentId)
  OPT_ARGUMENTS=(referenceSource maxComponents maxDepth treeFile)
  inputs "$@"
  handle_error "$?" "Failed to process input arguments" || return 1

  export GCT_REFERENCE_SOURCE="${referenceSource:-both}"
  export GCT_MAX_COMPONENTS="${maxComponents:-300}"
  export GCT_MAX_DEPTH="${maxDepth:-15}"
  export GCT_TREE_FILE="${treeFile:-${WORKSPACE}/component_tree.tsv}"

  log_info "Discovering component tree from ${componentId} (source=${GCT_REFERENCE_SOURCE}, maxComponents=${GCT_MAX_COMPONENTS}, maxDepth=${GCT_MAX_DEPTH})"
  gct_build_tree "$componentId"

  clean
fi
