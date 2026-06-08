#!/usr/bin/env bash
set -euo pipefail

# AGENTS.md Migration Helper
# Handles mechanical file operations: state detection, symlink creation, directory moves.
# Content transformation is handled by the LLM, not this script.

usage() {
  cat <<'EOF'
Usage: setup-agents.sh --project-dir <path> <command> [options]

Commands:
  --detect              Detect current state (A/B/C/D) and print report
  --apply               Apply changes: move files, create symlinks
  --verify              Verify symlinks and structure are correct
  --dry-run             Show what --apply would do without doing it

Options:
  --project-dir <path>  Project root directory (required)
  --agents <list>       Comma-separated agent list (default: claude)
                        Supported: claude,gemini,copilot,cursor,windsurf
EOF
  exit 1
}

# --- Defaults ---
PROJECT_DIR=""
AGENTS="claude"
COMMAND=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir) [[ $# -lt 2 ]] && { echo "Error: --project-dir requires a value"; usage; }; PROJECT_DIR="$2"; shift 2 ;;
    --agents) [[ $# -lt 2 ]] && { echo "Error: --agents requires a value"; usage; }; AGENTS="$2"; shift 2 ;;
    --detect) COMMAND="detect"; shift ;;
    --apply) COMMAND="apply"; shift ;;
    --verify) COMMAND="verify"; shift ;;
    --dry-run) COMMAND="dry-run"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "${PROJECT_DIR}" ]] && { echo "Error: --project-dir is required"; usage; }
[[ -z "${COMMAND}" ]] && { echo "Error: command is required (--detect, --apply, --verify, --dry-run)"; usage; }

PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"

# --- State detection ---
detect_state() {
  local has_claude=false
  local has_agents=false
  local claude_is_symlink=false
  local claude_symlink_target=""

  if [[ -e "${PROJECT_DIR}/CLAUDE.md" ]] || [[ -L "${PROJECT_DIR}/CLAUDE.md" ]]; then
    has_claude=true
    if [[ -L "${PROJECT_DIR}/CLAUDE.md" ]]; then
      claude_is_symlink=true
      claude_symlink_target="$(readlink "${PROJECT_DIR}/CLAUDE.md")"
    fi
  fi

  if [[ -e "${PROJECT_DIR}/AGENTS.md" ]]; then
    has_agents=true
  fi

  # If CLAUDE.md is already a symlink to AGENTS.md AND AGENTS.md exists, treat as State B
  if ${claude_is_symlink} && [[ "${claude_symlink_target}" == "AGENTS.md" ]] && [[ -f "${PROJECT_DIR}/AGENTS.md" ]]; then
    echo "STATE=B"
    echo "DETAIL=CLAUDE.md is already a symlink to AGENTS.md"
  elif ${has_claude} && ! ${has_agents}; then
    echo "STATE=A"
    echo "DETAIL=CLAUDE.md exists, no AGENTS.md"
  elif ${has_agents} && ! ${has_claude}; then
    echo "STATE=B"
    echo "DETAIL=AGENTS.md exists, no CLAUDE.md"
  elif ${has_agents} && ${has_claude}; then
    if ${claude_is_symlink}; then
      echo "STATE=B"
      echo "DETAIL=CLAUDE.md is a symlink to ${claude_symlink_target}, AGENTS.md exists"
    else
      echo "STATE=C"
      echo "DETAIL=Both CLAUDE.md and AGENTS.md exist as separate files"
    fi
  else
    echo "STATE=D"
    echo "DETAIL=Neither CLAUDE.md nor AGENTS.md exists"
  fi

  # Report skills directory state
  if [[ -d "${PROJECT_DIR}/.agents/skills" ]]; then
    echo "AGENTS_SKILLS=exists"
  else
    echo "AGENTS_SKILLS=missing"
  fi

  if [[ -d "${PROJECT_DIR}/.claude/skills" ]] || [[ -L "${PROJECT_DIR}/.claude/skills" ]]; then
    if [[ -L "${PROJECT_DIR}/.claude/skills" ]]; then
      local skills_target
      skills_target="$(readlink "${PROJECT_DIR}/.claude/skills")"
      echo "CLAUDE_SKILLS=symlink:${skills_target}"
    else
      echo "CLAUDE_SKILLS=directory"
    fi
  else
    echo "CLAUDE_SKILLS=missing"
  fi

  # Report existing agent symlinks
  for agent in claude gemini copilot cursor windsurf; do
    check_agent_symlink "${agent}"
  done
}

check_agent_symlink() {
  local agent="$1"
  local target=""

  case "${agent}" in
    claude)   target="${PROJECT_DIR}/CLAUDE.md" ;;
    gemini)   target="${PROJECT_DIR}/GEMINI.md" ;;
    copilot)  target="${PROJECT_DIR}/.github/copilot-instructions.md" ;;
    cursor)   target="${PROJECT_DIR}/.cursor/rules/agents.md" ;;
    windsurf) target="${PROJECT_DIR}/.windsurfrules" ;;
    *)        return 0 ;;
  esac

  local agent_upper
  agent_upper="$(echo "${agent}" | tr '[:lower:]' '[:upper:]')"

  if [[ -L "${target}" ]]; then
    local symlink_dest
    symlink_dest="$(readlink "${target}")"
    echo "AGENT_${agent_upper}=symlink:${symlink_dest}"
  elif [[ -e "${target}" ]]; then
    echo "AGENT_${agent_upper}=file"
  else
    echo "AGENT_${agent_upper}=missing"
  fi
}

# --- Symlink creation helpers ---
get_symlink_source_and_target() {
  local agent="$1"
  case "${agent}" in
    claude)
      echo "CLAUDE.md|AGENTS.md"
      ;;
    gemini)
      echo "GEMINI.md|AGENTS.md"
      ;;
    copilot)
      echo ".github/copilot-instructions.md|../AGENTS.md"
      ;;
    cursor)
      echo ".cursor/rules/agents.md|../../AGENTS.md"
      ;;
    windsurf)
      echo ".windsurfrules|AGENTS.md"
      ;;
    *)
      echo "Error: unknown agent: ${agent}" >&2
      return 1
      ;;
  esac
}

create_agent_symlink() {
  local agent="$1"
  local dry_run="${2:-false}"
  local pair
  pair="$(get_symlink_source_and_target "${agent}")"
  local link_path="${pair%%|*}"
  local link_target="${pair##*|}"
  local full_link_path="${PROJECT_DIR}/${link_path}"

  # Handle existing symlinks
  if [[ -L "${full_link_path}" ]]; then
    local current_target
    current_target="$(readlink "${full_link_path}")"
    if [[ "${current_target}" == "${link_target}" ]]; then
      echo "  [skip] ${link_path} already points to ${link_target}"
      return 0
    else
      # Wrong target — replace it
      if [[ "${dry_run}" == "true" ]]; then
        echo "  [would] rm ${link_path} (currently -> ${current_target})"
        echo "  [would] ln -s ${link_target} ${link_path}"
      else
        rm "${full_link_path}"
        ln -s "${link_target}" "${full_link_path}"
        echo "  [updated] ${link_path} -> ${link_target} (was -> ${current_target})"
      fi
      return 0
    fi
  fi

  # Warn if file exists and is not a symlink
  if [[ -e "${full_link_path}" ]] && [[ ! -L "${full_link_path}" ]]; then
    echo "  [warn] ${link_path} exists as a regular file, skipping (resolve manually)"
    return 0
  fi

  # Create parent directory if needed
  local parent_dir
  parent_dir="$(dirname "${full_link_path}")"
  if [[ ! -d "${parent_dir}" ]]; then
    if [[ "${dry_run}" == "true" ]]; then
      echo "  [would] mkdir -p ${parent_dir}"
    else
      mkdir -p "${parent_dir}"
      echo "  [created] directory $(dirname "${link_path}")"
    fi
  fi

  if [[ "${dry_run}" == "true" ]]; then
    echo "  [would] ln -s ${link_target} ${link_path}"
  else
    ln -s "${link_target}" "${full_link_path}"
    echo "  [created] ${link_path} -> ${link_target}"
  fi
}

# --- Skills directory migration ---
migrate_skills() {
  local dry_run="${1:-false}"

  # Case 1: .agents/skills exists, .claude/skills is already a symlink — verify target is correct
  if [[ -d "${PROJECT_DIR}/.agents/skills" ]] && [[ -L "${PROJECT_DIR}/.claude/skills" ]]; then
    local target
    target="$(readlink "${PROJECT_DIR}/.claude/skills")"
    if [[ "${target}" == "../.agents/skills" ]]; then
      echo "  [skip] .claude/skills already symlinked to ${target}"
    else
      echo "  [warn] .claude/skills is symlinked to ${target} (expected ../.agents/skills)"
      return 0
    fi
    return 0
  fi

  # Case 2: .claude/skills is a real directory, .agents/skills doesn't exist — move it
  if [[ -d "${PROJECT_DIR}/.claude/skills" ]] && [[ ! -L "${PROJECT_DIR}/.claude/skills" ]] && [[ ! -d "${PROJECT_DIR}/.agents/skills" ]]; then
    if [[ "${dry_run}" == "true" ]]; then
      echo "  [would] mkdir -p .agents"
      echo "  [would] mv .claude/skills .agents/skills"
      echo "  [would] ln -s ../.agents/skills .claude/skills"
    else
      mkdir -p "${PROJECT_DIR}/.agents"
      mv "${PROJECT_DIR}/.claude/skills" "${PROJECT_DIR}/.agents/skills"
      ln -s "../.agents/skills" "${PROJECT_DIR}/.claude/skills"
      echo "  [moved] .claude/skills -> .agents/skills"
      echo "  [created] .claude/skills -> ../.agents/skills (symlink)"
    fi
    return 0
  fi

  # Case 3: .agents/skills exists, no .claude/skills — just create symlink
  if [[ -d "${PROJECT_DIR}/.agents/skills" ]] && [[ ! -e "${PROJECT_DIR}/.claude/skills" ]]; then
    # Ensure .claude directory exists
    if [[ ! -d "${PROJECT_DIR}/.claude" ]]; then
      if [[ "${dry_run}" == "true" ]]; then
        echo "  [would] mkdir -p .claude"
      else
        mkdir -p "${PROJECT_DIR}/.claude"
      fi
    fi
    if [[ "${dry_run}" == "true" ]]; then
      echo "  [would] ln -s ../.agents/skills .claude/skills"
    else
      ln -s "../.agents/skills" "${PROJECT_DIR}/.claude/skills"
      echo "  [created] .claude/skills -> ../.agents/skills"
    fi
    return 0
  fi

  # Case 4: Neither exists — nothing to do
  if [[ ! -d "${PROJECT_DIR}/.claude/skills" ]] && [[ ! -d "${PROJECT_DIR}/.agents/skills" ]]; then
    echo "  [skip] No skills directories found"
    return 0
  fi

  # Case 5: Both exist as real directories — flag conflict
  if [[ -d "${PROJECT_DIR}/.claude/skills" ]] && [[ ! -L "${PROJECT_DIR}/.claude/skills" ]] && [[ -d "${PROJECT_DIR}/.agents/skills" ]]; then
    echo "  [conflict] Both .claude/skills/ and .agents/skills/ exist as directories"
    echo "  [action] Resolve manually: merge contents into .agents/skills/, then delete .claude/skills/ and re-run"
    return 0
  fi
}

# --- Gitignore handling ---
update_gitignore() {
  local dry_run="${1:-false}"
  local gitignore="${PROJECT_DIR}/.gitignore"

  if [[ ! -f "${gitignore}" ]]; then
    return 0
  fi

  # Check if .agents/ is ignored
  if grep -qE '^\/?\.agents\/?$' "${gitignore}" 2>/dev/null; then
    if [[ "${dry_run}" == "true" ]]; then
      echo "  [would] Remove .agents/ from .gitignore"
    else
      # Remove the line that ignores .agents
      sed -i.bak '/^\/?\.agents\/?$/d' "${gitignore}"
      rm -f "${gitignore}.bak"
      echo "  [fixed] Removed .agents/ from .gitignore"
    fi
  fi
}

# --- Verify ---
verify() {
  local errors=0

  echo "Verifying AGENTS.md setup in ${PROJECT_DIR}..."

  # Check AGENTS.md exists
  if [[ -f "${PROJECT_DIR}/AGENTS.md" ]]; then
    echo "  [ok] AGENTS.md exists"
  else
    echo "  [FAIL] AGENTS.md not found"
    errors=$((errors + 1))
  fi

  # Check each configured agent
  IFS=',' read -ra agent_list <<< "${AGENTS}"
  for agent in "${agent_list[@]}"; do
    local pair
    pair="$(get_symlink_source_and_target "${agent}")"
    local link_path="${pair%%|*}"
    local link_target="${pair##*|}"
    local full_link_path="${PROJECT_DIR}/${link_path}"

    if [[ -L "${full_link_path}" ]]; then
      local actual_target
      actual_target="$(readlink "${full_link_path}")"
      if [[ "${actual_target}" == "${link_target}" ]]; then
        echo "  [ok] ${link_path} -> ${link_target}"
      else
        echo "  [FAIL] ${link_path} points to ${actual_target} (expected ${link_target})"
        errors=$((errors + 1))
      fi
    elif [[ -e "${full_link_path}" ]]; then
      echo "  [warn] ${link_path} exists but is not a symlink"
    else
      echo "  [FAIL] ${link_path} does not exist"
      errors=$((errors + 1))
    fi
  done

  # Check skills
  if [[ -d "${PROJECT_DIR}/.agents/skills" ]]; then
    echo "  [ok] .agents/skills/ exists"
    if [[ -L "${PROJECT_DIR}/.claude/skills" ]]; then
      local skills_target
      skills_target="$(readlink "${PROJECT_DIR}/.claude/skills")"
      echo "  [ok] .claude/skills -> ${skills_target}"
    else
      echo "  [info] .claude/skills is not a symlink (may be intentional)"
    fi
  else
    echo "  [info] No .agents/skills/ directory"
  fi

  if [[ ${errors} -gt 0 ]]; then
    echo ""
    echo "Found ${errors} issue(s)"
    return 1
  else
    echo ""
    echo "All checks passed"
    return 0
  fi
}

# --- Main ---
case "${COMMAND}" in
  detect)
    detect_state
    ;;
  apply)
    echo "Applying AGENTS.md setup in ${PROJECT_DIR}..."
    echo ""
    echo "Skills migration:"
    migrate_skills false
    echo ""
    echo "Agent symlinks:"
    IFS=',' read -ra agent_list <<< "${AGENTS}"
    for agent in "${agent_list[@]}"; do
      create_agent_symlink "${agent}" false
    done
    echo ""
    echo "Gitignore:"
    update_gitignore false
    echo ""
    echo "Done. Run with --verify to confirm."
    ;;
  dry-run)
    echo "Dry run — showing what --apply would do in ${PROJECT_DIR}..."
    echo ""
    echo "Skills migration:"
    migrate_skills true
    echo ""
    echo "Agent symlinks:"
    IFS=',' read -ra agent_list <<< "${AGENTS}"
    for agent in "${agent_list[@]}"; do
      create_agent_symlink "${agent}" true
    done
    echo ""
    echo "Gitignore:"
    update_gitignore true
    echo ""
    echo "Dry run complete. Run with --apply to apply these changes."
    ;;
  verify)
    verify
    ;;
  *)
    echo "Error: unknown command: ${COMMAND}"; usage
    ;;
esac
