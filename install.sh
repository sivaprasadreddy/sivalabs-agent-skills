#!/usr/bin/env bash

set -e

URL="https://github.com/sivaprasadreddy/spring-boot-skill/archive/refs/heads/main.zip"
ZIP_FILE="spring-boot-skill.zip"

TARGET_DIR="${PWD}/.agents/skills"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Download the zip
curl -L "$URL" -o "$ZIP_FILE"

# Extract into target directory
unzip -q "$ZIP_FILE" -d "$TARGET_DIR"

# Remove the zip file
rm "$ZIP_FILE"

ln -s ${PWD}/.agents ${PWD}/.claude
ln -s ${PWD}/.agents ${PWD}/.codex
ln -s ${PWD}/.agents ${PWD}/.gemini

echo "Installed spring-boot-skill successfully."
