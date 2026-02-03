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

ROOT_DIR="${PWD}"
AGENTS_DIR="${ROOT_DIR}/.agents"
SKILLS_DIR="${AGENTS_DIR}/skills"
EXTRACTED_DIR_NAME="${REPO_NAME}-${DEFAULT_BRANCH}"
INSTALL_DIR="${SKILLS_DIR}/${REPO_NAME}"

# Files in installed directory that we don't need to keep
PRUNE_FILES=( ".gitignore" "install.sh" "LICENSE" "README.md" )

# Symlinks to create pointing to .agents
SYMLINKS=( ".claude" ".codex" ".gemini" )

#
# Prepare directories
#
mkdir -p "${SKILLS_DIR}"

#
# Download archive
#
echo "Downloading ${ARCHIVE_URL} -> ${ZIP_FILE}"
curl -fsSL --retry 3 "${ARCHIVE_URL}" -o "${ZIP_FILE}"

#
# Extract and install
#
#echo "Extracting ${ZIP_FILE} to ${SKILLS_DIR}"
unzip -q -o "${ZIP_FILE}" -d "${SKILLS_DIR}"

# Ensure idempotency: remove existing install dir if present
rm -rf "${INSTALL_DIR}"
mv "${SKILLS_DIR}/${EXTRACTED_DIR_NAME}" "${INSTALL_DIR}"

# Prune unnecessary files (ignore if missing)
for f in "${PRUNE_FILES[@]}"; do
  [ -e "${INSTALL_DIR}/${f}" ] && rm -f "${INSTALL_DIR}/${f}"
done

# Optionally remove the downloaded zip
rm -f "${ZIP_FILE}"

# Create helpful symlinks to .agents
for link in "${SYMLINKS[@]}"; do
  ln -sfn "${AGENTS_DIR}" "${ROOT_DIR}/${link}"
done

echo "Installed ${REPO_NAME} successfully into ${INSTALL_DIR}."
