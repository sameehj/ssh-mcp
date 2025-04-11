#!/bin/bash
# ssh-mcp: Simple client for Machine Chat Protocol over SSH
# Version: 0.1.0

# Default remote path
REMOTE_PATH="~/.ssh-mcp"
SERVER="$REMOTE_SERVER"
REMOTE_PATH="$REMOTE_PATH"
SSH_KEY="$SSH_KEY"

SSH_CMD="ssh"
if [ -n \"\$SSH_KEY\" ]; then
  SSH_CMD=\"ssh -i \$SSH_KEY\"
fi

# Display help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "ssh-mcp: Machine Chat Protocol over SSH"
  echo ""
  echo "USAGE:"
  echo "  ssh-mcp SERVER TOOL [ARGS_JSON]   # Run a tool on a remote server"
  echo "  ssh-mcp SERVER --list             # List available tools on server"
  echo "  ssh-mcp SERVER --describe TOOL    # Show details about a tool"
  echo ""
  echo "EXAMPLES:"
  echo "  ssh-mcp user@server1 system.info '{\"verbose\":true}'"
  echo "  ssh-mcp user@server2 --list"
  echo "  ssh-mcp myserver --describe file.read"
  echo ""
  exit 0
fi

# Check if server is provided
if [ -z "$1" ]; then
  echo "Error: SERVER argument is required"
  echo "Run 'ssh-mcp --help' for usage information"
  exit 1
fi

SERVER="$1"
shift

# Handle commands
if [ "$1" = "--list" ]; then
  # List available tools
  $SSH_CMD $SERVER "cd $REMOTE_PATH && ./mcp.sh --list"
  exit 0
fi

if [ "$1" = "--describe" ]; then
  if [ -z "$2" ]; then
    echo "Error: Tool name required"
    echo "Usage: ssh-mcp SERVER --describe TOOL"
    exit 1
  fi
  
  # Describe a specific tool
  $SSH_CMD $SERVER "cd $REMOTE_PATH && ./mcp.sh --describe $2"
  exit 0
fi

# If we have a tool name
if [ -n "$1" ]; then
  TOOL="$1"
  ARGS_RAW="\${2:-{}}"
  echo "{\"tool\":\"\$TOOL\",\"args\":\$ARGS_RAW}" | \$SSH_CMD \$SERVER "cd \$REMOTE_PATH && ./mcp.sh"
  exit 0
fi

# If no explicit tool, read JSON from stdin
cat | $SSH_CMD "$SERVER" "cd $REMOTE_PATH && ./mcp.sh"