#!/bin/bash
# ssh-mcp installer script
# Version: 0.1.3

set -e

# Configuration
TOOL_DIR="$HOME/.ssh-mcp/tools"
INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
REMOTE_SERVER=""
REMOTE_PATH=""
SSH_KEY=""

# Function to display available SSH hosts
display_ssh_hosts() {
  echo "Available SSH hosts from your config:"
  echo "------------------------------------"
  
  if [ -f "$HOME/.ssh/config" ]; then
    HOSTS=$(grep -i "^Host " "$HOME/.ssh/config" | grep -v "\\*" | awk '{print $2}' | sort)
    if [ -n "$HOSTS" ]; then
      echo "$HOSTS" | while read -r host; do
        echo "  * $host"
      done
    else
      echo "  No specific hosts found in SSH config"
    fi
  else
    echo "  No SSH config file found at ~/.ssh/config"
  fi

  if [ -f "$HOME/.ssh/known_hosts" ]; then
    echo ""
    echo "Recently connected hosts:"
    echo "------------------------"
    RECENT_HOSTS=$(awk '{print $1}' "$HOME/.ssh/known_hosts" | grep -v "^|" | awk -F, '{print $1}' | awk -F"[" '{print $1}' | sort | uniq | tail -5)
    if [ -n "$RECENT_HOSTS" ]; then
      echo "$RECENT_HOSTS" | while read -r host; do
        echo "  * $host"
      done
    else
      echo "  No recent hosts found"
    fi
  fi

  echo ""
  echo "You can install ssh-mcp on a remote server with:"
  echo "./install.sh --remote user@hostname --key ~/.ssh/key.pem"
  echo ""
}

# Argument parser
while [[ $# -gt 0 ]]; do
  case $1 in
    --remote)
      REMOTE_SERVER="$2"
      shift 2
      ;;
    --remote-path)
      REMOTE_PATH="$2"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --key)
      SSH_KEY="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --remote HOSTNAME     Install on remote server"
      echo "  --remote-path PATH    Path on remote server (default: ~/.ssh-mcp)"
      echo "  --install-dir PATH    Local installation directory (default: /usr/local/bin)"
      echo "  --key PATH            SSH private key for authentication"
      echo "  --help, -h            Show this help message"
      echo ""
      display_ssh_hosts
      exit 0
      ;;
    *)
      if [[ ! $1 == --* ]] && [[ -z "$REMOTE_SERVER" ]]; then
        INSTALL_DIR="$1"
      fi
      shift
      ;;
  esac
done

# SSH wrapper functions
ssh_exec() {
  if [ -n "$SSH_KEY" ]; then
    ssh -i "$SSH_KEY" "$@"
  else
    ssh "$@"
  fi
}

scp_exec() {
  if [ -n "$SSH_KEY" ]; then
    scp -i "$SSH_KEY" "$@"
  else
    scp "$@"
  fi
}

# If no arguments provided, prompt local install
if [ -z "$REMOTE_SERVER" ]; then
  echo "=== ssh-mcp installer ==="
  echo "No installation options specified."
  echo ""
  echo "Installation options:"
  echo "---------------------"
  echo "1. Local installation (default):"
  echo "   ./install.sh"
  echo ""
  echo "2. Remote installation:"
  echo "   ./install.sh --remote user@hostname --key ~/.ssh/key.pem"
  echo ""
  display_ssh_hosts
  read -p "Proceed with local installation? [Y/n] " choice
  case "$choice" in
    n|N ) exit 0;;
    * ) echo "Proceeding with local installation...";;
  esac
fi

echo "=== Installing ssh-mcp ==="

if [ -n "$REMOTE_SERVER" ]; then
  echo "Remote installation mode"
  echo "Target server: $REMOTE_SERVER"
  [ -z "$REMOTE_PATH" ] && REMOTE_PATH="~/.ssh-mcp"
  echo "Remote path: $REMOTE_PATH"

  echo "Creating remote directories..."
  ssh_exec "$REMOTE_SERVER" "mkdir -p $REMOTE_PATH/tools"

  echo "Copying mcp.sh script..."
  scp_exec "$SCRIPT_DIR/mcp.sh" "$REMOTE_SERVER:$REMOTE_PATH/"
  ssh_exec "$REMOTE_SERVER" "chmod +x $REMOTE_PATH/mcp.sh"

  echo "Installing tools..."
  for TOOL_FILE in "$SCRIPT_DIR/install/tools/"*.sh; do
    if [ -f "$TOOL_FILE" ]; then
      TOOL_NAME=$(basename "$TOOL_FILE")
      echo "  - $TOOL_NAME"
      scp_exec "$TOOL_FILE" "$REMOTE_SERVER:$REMOTE_PATH/tools/"
      ssh_exec "$REMOTE_SERVER" "chmod +x $REMOTE_PATH/tools/$TOOL_NAME"
    fi
  done

  echo "Checking for remote 'jq' dependency..."
  if ! ssh_exec "$REMOTE_SERVER" "command -v jq &>/dev/null"; then
    echo "Warning: jq is not available on the remote server."
    echo "Checking if this is a shared hosting environment..."
    
    # Try to detect shared hosting environment
    IS_SHARED_HOSTING=false
    if ssh_exec "$REMOTE_SERVER" "uname -a | grep -i cpanel" &>/dev/null; then
      IS_SHARED_HOSTING=true
    fi

    if [ "$IS_SHARED_HOSTING" = true ]; then
      echo "Detected shared hosting environment (cPanel/Hostgator)"
      echo "Attempting to use Python as a fallback for JSON processing..."
      
      # Create a Python fallback script for JSON processing
      ssh_exec "$REMOTE_SERVER" "cat > $REMOTE_PATH/json_helper.py" << 'PYEOF'
#!/usr/bin/env python
import sys
import json

def process_json():
    try:
        data = json.load(sys.stdin)
        if len(sys.argv) > 1:
            if sys.argv[1] == '--arg':
                data[sys.argv[2]] = sys.argv[3]
            elif sys.argv[1] == '--argjson':
                data[sys.argv[2]] = json.loads(sys.argv[3])
        print(json.dumps(data))
    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}\n")
        sys.exit(1)

if __name__ == "__main__":
    process_json()
PYEOF

      ssh_exec "$REMOTE_SERVER" "chmod +x $REMOTE_PATH/json_helper.py"
      
      # Create the wrapper script in the specified installation directory
      echo "Creating wrapper script..."
      cat > "$INSTALL_DIR/ssh-mcp" << EOF
#!/bin/bash
SERVER="$REMOTE_SERVER"
REMOTE_PATH="$REMOTE_PATH"
SSH_KEY="$SSH_KEY"

SSH_CMD="ssh"
[ -n "$SSH_KEY" ] && SSH_CMD="ssh -i $SSH_KEY"

if [ "\$1" = "--help" ] || [ "\$1" = "-h" ]; then
  echo "ssh-mcp: Machine Chat Protocol over SSH"
  echo ""
  echo "USAGE:"
  echo "  ssh-mcp [tool] [args_json]"
  echo "  ssh-mcp --list"
  echo "  ssh-mcp --describe TOOL"
  echo "  ssh-mcp --help"
  echo "Remote server: $SERVER"
  exit 0
fi

if [ "\$1" = "--list" ]; then
  \$SSH_CMD "$SERVER" "cd $REMOTE_PATH && ./mcp.sh --list"
  exit 0
fi

if [ "\$1" = "--describe" ]; then
  if [ -z "\$2" ]; then
    echo "Usage: ssh-mcp --describe TOOL"
    exit 1
  fi
  \$SSH_CMD "$SERVER" "cd $REMOTE_PATH && ./mcp.sh --describe \$2"
  exit 0
fi

if [ -n "\$1" ]; then
  TOOL="\$1"
  ARGS="\${2:-{}}"
  
  # Use Python fallback for JSON processing
  if command -v jq &>/dev/null; then
    PAYLOAD=\$(echo "{}" | jq --arg tool "\$TOOL" --argjson args "\$ARGS" '. + {tool: \$tool, args: \$args}')
  else
    echo "{}" | python3 "$REMOTE_PATH/json_helper.py" --arg tool "\$TOOL" --argjson args "\$ARGS" > /tmp/payload.json
    PAYLOAD=\$(cat /tmp/payload.json)
    rm -f /tmp/payload.json
  fi
  
  echo "\$PAYLOAD" | \$SSH_CMD "$SERVER" "cd $REMOTE_PATH && ./mcp.sh"
  exit 0
fi

cat | \$SSH_CMD "$SERVER" "cd $REMOTE_PATH && ./mcp.sh"
EOF

      chmod +x "$INSTALL_DIR/ssh-mcp"
      
      echo "Remote installation complete!"
      echo "Try: ssh-mcp --list"
      echo "     ssh-mcp system.info '{\"verbose\":true}'"
      exit 0
    else
      echo "This seems to be a standard server environment."
      echo "Attempting to install jq via package manager..."
      if ssh_exec "$REMOTE_SERVER" "command -v apt-get &>/dev/null"; then
        ssh_exec "$REMOTE_SERVER" "DEBIAN_FRONTEND=noninteractive sudo apt-get install -y jq"
      elif ssh_exec "$REMOTE_SERVER" "command -v yum &>/dev/null"; then
        ssh_exec "$REMOTE_SERVER" "sudo yum install -y jq"
      else
        echo "Warning: Could not install jq. Some features may not work."
      fi
    fi
  fi

  echo "Remote installation complete!"
  echo "Try: ssh-mcp --list"
  echo "     ssh-mcp system.info '{\"verbose\":true}'"
  exit 0
fi

# Local installation
mkdir -p "$TOOL_DIR"

if [ ! -w "$INSTALL_DIR" ]; then
  echo "Need sudo to install to $INSTALL_DIR"
  sudo cp "$SCRIPT_DIR/mcp.sh" "$INSTALL_DIR/ssh-mcp"
  sudo chmod +x "$INSTALL_DIR/ssh-mucp"
else
  cp "$SCRIPT_DIR/mcp.sh" "$INSTALL_DIR/ssh-mcp"
  chmod +x "$INSTALL_DIR/ssh-mcp"
fi

echo "Installing tools..."
for TOOL_FILE in "$SCRIPT_DIR/install/tools/"*.sh; do
  if [ -f "$TOOL_FILE" ]; then
    TOOL_NAME=$(basename "$TOOL_FILE")
    echo "  - $TOOL_NAME"
    cp "$TOOL_FILE" "$TOOL_DIR/"
    chmod +x "$TOOL_DIR/$TOOL_NAME"
  fi
done

if ! command -v jq &> /dev/null; then
  echo "Warning: jq is not installed but required."
  echo "Install with: sudo apt install jq (or brew/yum based on system)"
fi

echo "Installation complete! Try:"
echo "  ssh-mcp --list"
echo "  ssh-mcp system.info '{\"verbose\":true}'"
exit 0