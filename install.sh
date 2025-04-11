#!/bin/bash
# ssh-mcp installer script
# Version: 0.1.0

set -e

# Configuration
TOOL_DIR="$HOME/.ssh-mcp/tools"
INSTALL_DIR="${1:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Display welcome message
echo "=== Installing ssh-mcp ==="
echo "Tool directory: $TOOL_DIR"
echo "Install directory: $INSTALL_DIR"

# Create tool directory if it doesn't exist
mkdir -p "$TOOL_DIR"

# Copy main script to install directory
if [ ! -w "$INSTALL_DIR" ]; then
  echo "Need sudo permission to install to $INSTALL_DIR"
  sudo cp "$SCRIPT_DIR/mcp.sh" "$INSTALL_DIR/ssh-mcp"
  sudo chmod +x "$INSTALL_DIR/ssh-mcp"
else
  cp "$SCRIPT_DIR/mcp.sh" "$INSTALL_DIR/ssh-mcp"
  chmod +x "$INSTALL_DIR/ssh-mcp"
fi

# Copy all tool scripts
echo "Installing tools..."
for TOOL_FILE in "$SCRIPT_DIR/tools/"*.sh; do
  if [ -f "$TOOL_FILE" ]; then
    TOOL_NAME=$(basename "$TOOL_FILE")
    echo "  - $TOOL_NAME"
    cp "$TOOL_FILE" "$TOOL_DIR/"
    chmod +x "$TOOL_DIR/$TOOL_NAME"
  fi
done

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo "Warning: jq is not installed but required for ssh-mcp to function."
  echo "Please install jq:"
  echo "  - Debian/Ubuntu: sudo apt install jq"
  echo "  - RHEL/CentOS/Fedora: sudo yum install jq"
  echo "  - macOS: brew install jq"
fi

echo "Installation complete! You can now use ssh-mcp."
echo "Try: echo '{\"tool\":\"meta.discover\"}' | ssh-mcp"
echo "Or: echo '{\"tool\":\"meta.discover\"}' | ssh your-server ssh-mcp"

exit 0
