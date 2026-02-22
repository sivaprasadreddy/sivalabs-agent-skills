#!/usr/bin/env bash

set -Eeuo pipefail

#
# Configuration (avoid magic strings)
#
REPO_OWNER="sivaprasadreddy"
REPO_NAME="spring-boot-skill"
DEFAULT_BRANCH="main"

ARCHIVE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${DEFAULT_BRANCH}.zip"
ZIP_FILE="${REPO_NAME}.zip"

# Files in installed directory that we don't need to keep
PRUNE_FILES=( ".gitignore" "install.sh" "LICENSE" "README.md" )

# Supported AI agents
AI_AGENTS=( "claude" "codex" "gemini" )

# Default installation level
INSTALL_LEVEL="project"  # or "user"
SELECTED_AGENTS=()

#
# Usage/Help
#
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Install spring-boot-skill for AI agents (Claude, Codex, Gemini, Cursor).

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
  $0 --project --agent all              # Install for all agents at project level

EOF
  exit 0
}

#
# Parse command-line arguments
#
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
        SELECTED_AGENTS=( "${AI_AGENTS[@]}" "cursor" )
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
  SELECTED_AGENTS=( "${AI_AGENTS[@]}" "cursor" )
fi

# Remove duplicates from SELECTED_AGENTS
SELECTED_AGENTS=( $(printf "%s\n" "${SELECTED_AGENTS[@]}" | sort -u) )

#
# Download archive
#
echo "Downloading ${ARCHIVE_URL} -> ${ZIP_FILE}"
curl -fsSL --retry 3 "${ARCHIVE_URL}" -o "${ZIP_FILE}"

#
# Extract to temp directory
#
TEMP_DIR=$(mktemp -d)
trap "rm -rf '${TEMP_DIR}' '${ZIP_FILE}'" EXIT

echo "Extracting ${ZIP_FILE}..."
unzip -q -o "${ZIP_FILE}" -d "${TEMP_DIR}"

EXTRACTED_DIR_NAME="${REPO_NAME}-${DEFAULT_BRANCH}"
SOURCE_DIR="${TEMP_DIR}/${EXTRACTED_DIR_NAME}"

# Prune unnecessary files from source
for f in "${PRUNE_FILES[@]}"; do
  [ -e "${SOURCE_DIR}/${f}" ] && rm -f "${SOURCE_DIR}/${f}"
done

#
# Install for each selected agent
#
for agent in "${SELECTED_AGENTS[@]}"; do
  if [[ "${INSTALL_LEVEL}" == "user" ]]; then
    AGENT_DIR="${HOME}/.${agent}"
  else
    AGENT_DIR="${PWD}/.${agent}"
  fi

  SKILLS_DIR="${AGENT_DIR}/skills"
  INSTALL_DIR="${SKILLS_DIR}/${REPO_NAME}"

  echo "Installing for ${agent} at ${INSTALL_LEVEL} level..."

  # Create skills directory
  mkdir -p "${SKILLS_DIR}"

  # Remove existing installation
  rm -rf "${INSTALL_DIR}"

  # Copy skill files
  cp -r "${SOURCE_DIR}" "${INSTALL_DIR}"

  echo "✓ Installed ${REPO_NAME} for ${agent} into ${INSTALL_DIR}"
done

echo ""
echo "Installation complete for: ${SELECTED_AGENTS[*]}"
echo "Installation level: ${INSTALL_LEVEL}"
