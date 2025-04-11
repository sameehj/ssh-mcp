#!/usr/bin/env bash
# ssh-mcp: Smart client for Machine Chat Protocol over SSH
# Version: 0.2.0

set -e

# Configuration
REMOTE_PATH="${REMOTE_PATH:-~/.ssh-mcp}"
SSH_KEY=""
SSH_CONFIG_FILE="$HOME/.ssh/config"

# Display help message for --help flag
function show_help {
  cat <<EOF
ssh-mcp: Machine Chat Protocol over SSH

USAGE:
  ./ssh-mcp.sh [OPTIONS] [HOST] TOOL [KEY=VALUE...]  Run a tool on HOST
  ./ssh-mcp.sh --hosts                              List SSH hosts from config
  ./ssh-mcp.sh --add-host NAME IP [USER] [KEY]      Add a host to SSH config
  ./ssh-mcp.sh [HOST] --list                        List available tools on HOST
  ./ssh-mcp.sh [HOST] --describe TOOL               Describe a specific tool

OPTIONS:
  --key FILE       Use specific SSH key file
  --help, -h       Show this help message

EXAMPLES:
  ./ssh-mcp.sh webserver system.info verbose=true
  ./ssh-mcp.sh --key ~/.ssh/mykey.pem webserver file.read path=/etc/hostname
  ./ssh-mcp.sh --add-host aws-server 1.2.3.4 ubuntu ~/.ssh/aws.pem
EOF
  exit 0
}

# Handle --help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
fi

# Handle --add-host command
if [[ "$1" == "--add-host" ]]; then
  if [ -z "$2" ] || [ -z "$3" ]; then
    echo "Error: Missing parameters"
    echo "Usage: ./ssh-mcp.sh --add-host NAME IP [USER] [KEY_PATH]"
    exit 1
  fi

  HOST_NAME="$2"
  HOST_IP="$3"
  HOST_USER="${4:-$USER}"
  HOST_KEY="${5:-}"

  # Check if config file exists
  if [ ! -f "$SSH_CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$SSH_CONFIG_FILE")"
    touch "$SSH_CONFIG_FILE"
    chmod 600 "$SSH_CONFIG_FILE"
  fi

  # Check if host already exists
  if grep -q "^Host $HOST_NAME$" "$SSH_CONFIG_FILE"; then
    echo "Host '$HOST_NAME' already exists in SSH config. Skipping."
    exit 0
  fi

  # Add the host
  echo -e "\n# Added by ssh-mcp on $(date)" >> "$SSH_CONFIG_FILE"
  echo "Host $HOST_NAME" >> "$SSH_CONFIG_FILE"
  echo "    HostName $HOST_IP" >> "$SSH_CONFIG_FILE"
  echo "    User $HOST_USER" >> "$SSH_CONFIG_FILE"
  if [ -n "$HOST_KEY" ]; then
    echo "    IdentityFile $HOST_KEY" >> "$SSH_CONFIG_FILE"
  fi
  echo "" >> "$SSH_CONFIG_FILE"

  echo "Host '$HOST_NAME' added to SSH config. You can now use:"
  echo "./ssh-mcp.sh $HOST_NAME system.info"
  exit 0
fi

# Handle --key option
if [[ "$1" == "--key" ]]; then
  if [ -z "$2" ]; then
    echo "Error: Missing key file path"
    echo "Usage: ./ssh-mcp.sh --key PATH [HOST] TOOL [ARGS]"
    exit 1
  fi
  SSH_KEY="$2"
  shift 2
fi

# Set SSH command with or without key
SSH_CMD="ssh"
if [ -n "$SSH_KEY" ]; then
  SSH_CMD="ssh -i $SSH_KEY"
fi

# List hosts from SSH config
if [[ "$1" == "--hosts" ]]; then
  echo "SSH hosts from your config:"
  if [ -f "$HOME/.ssh/config" ]; then
    grep -i "^Host " "$HOME/.ssh/config" | grep -v "\\*" | awk '{print $2}'
  else
    echo "No SSH config file found."
    echo "You can create one with './ssh-mcp.sh --add-host NAME IP [USER] [KEY]'"
  fi
  exit 0
fi

# Parse arguments
if [[ -z "$1" ]]; then
  echo "Error: No arguments provided"
  echo "Run './ssh-mcp.sh --help' for usage information"
  exit 1
elif [[ "$1" =~ ^-- || "$1" =~ ^(system|meta|file|network)\..* ]]; then
  # First arg is a flag or tool - use localhost
  HOST="localhost"
  ARGS=("$@")
else
  # First arg is a host
  HOST="$1"
  shift
  ARGS=("$@")
fi

# Handle specific commands
if [[ "${ARGS[0]}" == "--list" ]]; then
  $SSH_CMD "$HOST" "cd $REMOTE_PATH && ./mcp.sh --list"
  exit $?
fi

if [[ "${ARGS[0]}" == "--describe" ]]; then
  if [ -z "${ARGS[1]}" ]; then
    echo "Error: Missing tool name"
    echo "Usage: ./ssh-mcp.sh [HOST] --describe TOOL"
    exit 1
  fi
  $SSH_CMD "$HOST" "cd $REMOTE_PATH && ./mcp.sh --describe ${ARGS[1]}"
  exit $?
fi

# Handle tool execution with arguments
if [ -n "${ARGS[0]}" ]; then
  TOOL="${ARGS[0]}"
  
  # Parse key=value arguments into JSON
  ARGS_JSON="{}"
  for ((i=1; i<${#ARGS[@]}; i++)); do
    if [[ "${ARGS[$i]}" == *"="* ]]; then
      KEY="${ARGS[$i]%%=*}"
      VALUE="${ARGS[$i]#*=}"
      
      # Handle different value types
      if [[ "$VALUE" == "true" || "$VALUE" == "false" ]]; then
        # Boolean values
        ARGS_JSON=$(echo "$ARGS_JSON" | jq --arg k "$KEY" --argjson v "$VALUE" '. + {($k): $v}')
      elif [[ "$VALUE" =~ ^[0-9]+$ ]]; then
        # Integer values
        ARGS_JSON=$(echo "$ARGS_JSON" | jq --arg k "$KEY" --argjson v "$VALUE" '. + {($k): $v}')
      else
        # String values
        ARGS_JSON=$(echo "$ARGS_JSON" | jq --arg k "$KEY" --arg v "$VALUE" '. + {($k): $v}')
      fi
    fi
  done

  # Add this to your ssh-mcp.sh script if it's not already there
if [[ "$1" == "--install" ]]; then
  if [ -z "$2" ]; then
    echo "Error: Missing host parameter"
    echo "Usage: ./ssh-mcp.sh --install HOST"
    exit 1
  fi
  
  HOST="$2"
  echo "Installing ssh-mcp tools on $HOST..."
  
  # Get script directory correctly
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  
  # Create remote directories
  $SSH_CMD "$HOST" "mkdir -p $REMOTE_PATH/tools"
  
  # Check if mcp.sh exists in current directory
  if [ -f "$SCRIPT_DIR/mcp.sh" ]; then
    echo "Copying mcp.sh..."
    $SCP_CMD "$SCRIPT_DIR/mcp.sh" "$HOST:$REMOTE_PATH/"
    $SSH_CMD "$HOST" "chmod +x $REMOTE_PATH/mcp.sh"
  else
    echo "Warning: mcp.sh not found in $SCRIPT_DIR"
    ls -la "$SCRIPT_DIR"  # Show what files are actually there
    exit 1
  fi
  
  # Check if tools directory exists
  TOOLS_DIR="$SCRIPT_DIR/install/tools"
  if [ ! -d "$TOOLS_DIR" ]; then
    echo "Warning: Tools directory not found at $TOOLS_DIR"
    # Try to find it elsewhere
    if [ -d "$SCRIPT_DIR/tools" ]; then
      TOOLS_DIR="$SCRIPT_DIR/tools"
      echo "Using tools from $TOOLS_DIR instead."
    else
      echo "Error: Could not find tools directory"
      exit 1
    fi
  fi
  
  # Copy all tool scripts
  echo "Copying tools from $TOOLS_DIR..."
  for TOOL_FILE in "$TOOLS_DIR/"*.sh; do
    if [ -f "$TOOL_FILE" ]; then
      TOOL_NAME=$(basename "$TOOL_FILE")
      echo "  - $TOOL_NAME"
      $SCP_CMD "$TOOL_FILE" "$HOST:$REMOTE_PATH/tools/"
      $SSH_CMD "$HOST" "chmod +x $REMOTE_PATH/tools/$TOOL_NAME"
    fi
  done
  
  # Test connection
  echo "Installation complete. Testing connection..."
  echo '{"tool":"meta.discover"}' | $SSH_CMD "$HOST" "cd $REMOTE_PATH && ./mcp.sh"
  exit 0
fi
  
  # Create and send the payload
  JSON_PAYLOAD=$(jq -n --arg tool "$TOOL" --argjson args "$ARGS_JSON" '{tool: $tool, args: $args}')
  echo "$JSON_PAYLOAD" | $SSH_CMD "$HOST" "cd $REMOTE_PATH && ./mcp.sh"
  exit $?
fi

# Fallback to stdin pipe mode (if no tool specified)
cat | $SSH_CMD "$HOST" "cd $REMOTE_PATH && ./mcp.sh"