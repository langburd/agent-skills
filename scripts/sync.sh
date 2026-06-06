#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKETPLACE_JSON="${REPO_ROOT}/.claude-plugin/marketplace.json"
README="${REPO_ROOT}/README.md"
CHECK_MODE=0

if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=1
fi

# --- Validation ---

FAILED=0

for plugin_dir in "${REPO_ROOT}/plugins"/*/; do
  [[ -d "${plugin_dir}" ]] || continue
  plugin_name="$(basename "${plugin_dir}")"
  plugin_json="${plugin_dir}.claude-plugin/plugin.json"

  if [[ ! -f "${plugin_json}" ]]; then
    echo "${plugin_json}: ERROR: missing .claude-plugin/plugin.json"
    FAILED=1
    continue
  fi

  if ! jq empty "${plugin_json}" 2>/dev/null; then
    echo "${plugin_json}: ERROR: invalid JSON"
    FAILED=1
    continue
  fi

  name="$(jq -r '.name // empty' "${plugin_json}")"
  version="$(jq -r '.version // empty' "${plugin_json}")"

  if [[ -z "${name}" ]]; then
    echo "${plugin_json}: ERROR: missing 'name' field"
    FAILED=1
  fi

  if [[ -z "${version}" ]]; then
    echo "${plugin_json}: ERROR: missing 'version' field"
    FAILED=1
  fi

  desc_val="$(jq -r '.description // empty' "${plugin_json}")"
  if [[ -z "${desc_val}" ]]; then
    echo "${plugin_json}: ERROR: missing 'description' field"
    FAILED=1
  fi

  if [[ -n "${name}" && "${name}" != "${plugin_name}" ]]; then
    echo "${plugin_json}: ERROR: name '${name}' does not match directory '${plugin_name}'"
    FAILED=1
  fi

  skills_dir="${plugin_dir}skills"
  if [[ ! -d "${skills_dir}" ]]; then
    echo "${plugin_dir}: ERROR: missing skills/ directory"
    FAILED=1
    continue
  fi

  skill_count=0
  while IFS= read -r -d '' skill_md; do
    skill_count=$((skill_count + 1))

    skill_name=""
    skill_desc=""
    in_frontmatter=0
    found_open=0

    while IFS= read -r line; do
      if [[ ${found_open} -eq 0 && "${line}" == "---" ]]; then
        found_open=1
        in_frontmatter=1
        continue
      fi
      if [[ ${in_frontmatter} -eq 1 && "${line}" == "---" ]]; then
        in_frontmatter=0
        break
      fi
      if [[ ${in_frontmatter} -eq 1 ]]; then
        if [[ "${line}" =~ ^name:[[:space:]]*(.*) ]]; then
          skill_name="${BASH_REMATCH[1]}"
        fi
        if [[ "${line}" =~ ^description:[[:space:]]*(.*) ]]; then
          skill_desc="${BASH_REMATCH[1]}"
        fi
      fi
    done <"${skill_md}"

    if [[ -z "${skill_name}" ]]; then
      echo "${skill_md}: ERROR: frontmatter missing 'name'"
      FAILED=1
    fi

    if [[ -z "${skill_desc}" ]]; then
      echo "${skill_md}: ERROR: frontmatter missing 'description'"
      FAILED=1
    fi
  done < <(find "${skills_dir}" -name "SKILL.md" -print0)

  if [[ ${skill_count} -eq 0 ]]; then
    echo "${skills_dir}: ERROR: no SKILL.md files found"
    FAILED=1
  fi
done

if [[ ${FAILED} -ne 0 ]]; then
  echo ""
  echo "Validation failed. Fix errors above."
  exit 1
fi

# --- Generation ---

MARKETPLACE_HEADER='{
  "name": "langburd",
  "owner": { "name": "langburd" },
  "description": "Personal Claude Code marketplace"
}'

plugins_json="[]"

for plugin_dir in "${REPO_ROOT}/plugins"/*/; do
  [[ -d "${plugin_dir}" ]] || continue
  plugin_name="$(basename "${plugin_dir}")"
  plugin_json="${plugin_dir}.claude-plugin/plugin.json"

  desc="$(jq -r '.description // ""' "${plugin_json}")"
  ver="$(jq -r '.version // ""' "${plugin_json}")"

  entry="$(
    jq -n \
      --arg name "${plugin_name}" \
      --arg source "./plugins/${plugin_name}" \
      --arg description "${desc}" \
      --arg version "${ver}" \
      '{"name": $name, "source": $source, "description": $description, "version": $version}'
  )"

  plugins_json="$(echo "${plugins_json}" | jq --argjson entry "${entry}" '. + [$entry]')"
done

new_marketplace="$(
  echo "${MARKETPLACE_HEADER}" |
    jq --argjson plugins "${plugins_json}" '. + {"plugins": $plugins}'
)"

# Build table content file (avoids shell escaping issues with multiline strings)
build_table_file() {
  local out="$1"
  printf '<!-- BEGIN PLUGIN TABLE -->\n' >"${out}"
  printf '| Plugin | Version | Description |\n' >>"${out}"
  printf '|--------|---------|-------------|\n' >>"${out}"
  for plugin_dir in "${REPO_ROOT}/plugins"/*/; do
    [[ -d "${plugin_dir}" ]] || continue
    local pname ver desc
    pname="$(basename "${plugin_dir}")"
    ver="$(jq -r '.version // ""' "${plugin_dir}.claude-plugin/plugin.json")"
    desc="$(jq -r '.description // ""' "${plugin_dir}.claude-plugin/plugin.json")"
    desc="${desc//|/\\|}"
    printf '| [%s](plugins/%s) | %s | %s |\n' "${pname}" "${pname}" "${ver}" "${desc}" >>"${out}"
  done
  printf '<!-- END PLUGIN TABLE -->\n' >>"${out}"
}

# Inject table into a readme file using awk
inject_table() {
  local src="$1" table_file="$2" dest="$3"
  awk -v table_file="${table_file}" '
    /<!-- BEGIN PLUGIN TABLE -->/ { skip=1; while ((getline line < table_file) > 0) print line; next }
    /<!-- END PLUGIN TABLE -->/ { skip=0; next }
    !skip { print }
  ' "${src}" >"${dest}"
}

if [[ ${CHECK_MODE} -eq 1 ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT

  tmp_marketplace="${tmp_dir}/marketplace.json"
  tmp_readme="${tmp_dir}/README.md"
  tmp_table="${tmp_dir}/table.txt"

  echo "${new_marketplace}" | jq . >"${tmp_marketplace}"

  if [[ -f "${README}" ]]; then
    build_table_file "${tmp_table}"
    inject_table "${README}" "${tmp_table}" "${tmp_readme}"
  fi

  drift=0
  if ! diff -q "${tmp_marketplace}" "${MARKETPLACE_JSON}" >/dev/null 2>&1; then
    echo "DRIFT: .claude-plugin/marketplace.json is out of sync"
    diff "${MARKETPLACE_JSON}" "${tmp_marketplace}" || true
    drift=1
  fi
  if [[ -f "${README}" ]] && ! diff -q "${tmp_readme}" "${README}" >/dev/null 2>&1; then
    echo "DRIFT: README.md plugin table is out of sync"
    diff "${README}" "${tmp_readme}" || true
    drift=1
  fi
  if [[ ${drift} -ne 0 ]]; then
    echo ""
    echo "Run ./scripts/sync.sh to fix drift."
    exit 1
  fi
  echo "No drift detected."
else
  mkdir -p "${REPO_ROOT}/.claude-plugin"
  echo "${new_marketplace}" | jq . >"${MARKETPLACE_JSON}"

  if [[ -f "${README}" ]]; then
    tmp_table="$(mktemp)"
    tmp_readme="$(mktemp)"
    build_table_file "${tmp_table}"
    inject_table "${README}" "${tmp_table}" "${tmp_readme}"
    mv "${tmp_readme}" "${README}"
    rm -f "${tmp_table}"
  fi

  echo "Sync complete."
fi
