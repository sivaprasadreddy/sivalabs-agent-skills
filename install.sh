#!/usr/bin/env bash

set -Eeuo pipefail

# Supported AI agents
AI_AGENTS=( "claude" "codex" "gemini" "cursor" )

# Default installation level
INSTALL_LEVEL="project"  # or "user"
SELECTED_AGENTS=()

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Install sivalabs-agent-skills for AI agents (Claude, Codex, Gemini, Cursor).

OPTIONS:
  --project           Install at project level (default)
  --user              Install at user level (~/.claude, ~/.codex, etc.)
  --agent AGENT       Install for specific agent(s): claude, codex, gemini, cursor, or 'all'
                      Can be specified multiple times. Default: all agents
  -h, --help          Show this help message

EXAMPLES:
  $0                                    # Install for all agents at project level
  $0 --user                             # Install for all agents at user level
  $0 --agent claude                     # Install for Claude only at project level
  $0 --agent claude --agent codex       # Install for Claude and Codex at project level
  $0 --user --agent gemini              # Install for Gemini only at user level

EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      INSTALL_LEVEL="project"
      shift
      ;;
    --user)
      INSTALL_LEVEL="user"
      shift
      ;;
    --agent)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --agent requires an argument"
        exit 1
      fi
      if [[ "$2" == "all" ]]; then
        SELECTED_AGENTS=( "${AI_AGENTS[@]}" )
      elif [[ "$2" =~ ^(claude|codex|gemini|cursor)$ ]]; then
        SELECTED_AGENTS+=( "$2" )
      else
        echo "Error: Invalid agent '$2'. Must be one of: claude, codex, gemini, cursor, all"
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Unknown option '$1'"
      usage
      ;;
  esac
done

# Default to all agents if none specified
if [[ ${#SELECTED_AGENTS[@]} -eq 0 ]]; then
  SELECTED_AGENTS=( "${AI_AGENTS[@]}" )
fi

# Remove duplicates from SELECTED_AGENTS
SELECTED_AGENTS=( $(printf "%s\n" "${SELECTED_AGENTS[@]}" | sort -u) )

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SKILLS_DIR="${SCRIPT_DIR}/skills"

# Verify source skills directory exists
if [[ ! -d "${SOURCE_SKILLS_DIR}" ]]; then
  echo "Error: skills directory not found at ${SOURCE_SKILLS_DIR}"
  exit 1
fi

# Install for each selected agent
for agent in "${SELECTED_AGENTS[@]}"; do
  if [[ "${INSTALL_LEVEL}" == "user" ]]; then
    AGENT_DIR="${HOME}/.${agent}"
  else
    AGENT_DIR="${PWD}/.${agent}"
  fi

  SKILLS_DIR="${AGENT_DIR}/skills"

  echo "Installing for ${agent} at ${INSTALL_LEVEL} level..."

  # Create skills directory
  mkdir -p "${SKILLS_DIR}"

  # Copy all skills
  cp -r "${SOURCE_SKILLS_DIR}"/* "${SKILLS_DIR}/"

  echo "✓ Installed skills for ${agent} into ${SKILLS_DIR}"
done

echo ""
echo "Installation complete for: ${SELECTED_AGENTS[*]}"
echo "Installation level: ${INSTALL_LEVEL}"
