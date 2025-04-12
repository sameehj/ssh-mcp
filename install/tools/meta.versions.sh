#!/bin/bash
# Tool: meta.update - Updates tools to the latest versions
# Author: ssh-mcp Team
# Version: 1.0.0
# Tags: meta, system
# Requires sudo: false

REPOS_URL="https://api.github.com/repos/ssh-mcp/ssh-mcp/contents/tools"
TOOL_DIR="$HOME/.mcp/tools"

# Get list of available tools from repository
AVAILABLE_TOOLS=$(curl -s "$REPOS_URL" | jq -r '.[].name')

# Check and update each tool
for TOOL_NAME in $AVAILABLE_TOOLS; do
  LOCAL_PATH="$TOOL_DIR/$TOOL_NAME"
  
  # Skip if tool doesn't exist locally
  if [ ! -f "$LOCAL_PATH" ]; then
    echo "Installing new tool: $TOOL_NAME" >&2
    curl -s "https://raw.githubusercontent.com/ssh-mcp/ssh-mcp/main/tools/$TOOL_NAME" > "$LOCAL_PATH"
    chmod +x "$LOCAL_PATH"
    continue
  fi
  
  # Get versions
  REMOTE_VERSION=$(curl -s "https://raw.githubusercontent.com/ssh-mcp/ssh-mcp/main/tools/$TOOL_NAME" | grep -m 1 "# Version:" | sed 's/# Version: //')
  LOCAL_VERSION=$(grep -m 1 "# Version:" "$LOCAL_PATH" | sed 's/# Version: //')
  
  # Compare versions (basic semver comparison)
  if [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
    echo "Updating $TOOL_NAME from $LOCAL_VERSION to $REMOTE_VERSION" >&2
    curl -s "https://raw.githubusercontent.com/ssh-mcp/ssh-mcp/main/tools/$TOOL_NAME" > "$LOCAL_PATH"
    chmod +x "$LOCAL_PATH"
  fi
done

echo '{"updated_tools": true, "explanation": "All tools have been checked for updates"}'
exit 0