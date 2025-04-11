#!/bin/bash
# mcp.sh: Machine Chat Protocol over SSH implementation
# Version: 0.1.0

set -e

# Configuration
TOOL_DIR="$HOME/.ssh-mcp/tools"
LOG_FILE="$HOME/.ssh-mcp/mcp.log"

# Display help if requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  cat <<HELP
ssh-mcp: Machine Chat Protocol over SSH

USAGE:
  ./mcp.sh                              # Process JSON from stdin
  ./mcp.sh --help                       # Show this help message
  ./mcp.sh --list                       # List available tools
  ./mcp.sh --describe TOOL              # Show details for a specific tool
  ./mcp.sh --version                    # Show version information
  
EXAMPLES:
  echo '{"tool":"system.info","args":{"verbose":true}}' | ./mcp.sh
  ./mcp.sh --list
  ./mcp.sh --describe system.info

For more information, visit: https://github.com/yourusername/ssh-mcp
HELP
  exit 0
fi

# List available tools
if [ "$1" = "--list" ]; then
  if [ -d "$TOOL_DIR" ]; then
    echo '{"tool":"meta.discover","args":{}}' | $0
  else
    echo '{"status":{"code":404,"message":"No tools directory found"},"result":null,"error":{"code":"TOOL_DIR_NOT_FOUND","message":"Tools directory does not exist"}}'
  fi
  exit 0
fi

# Describe a specific tool
if [ "$1" = "--describe" ]; then
  if [ -z "$2" ]; then
    echo "Error: Tool name required"
    echo "Usage: ./mcp.sh --describe TOOL"
    exit 1
  fi
  
  echo "{\"tool\":\"meta.describe\",\"args\":{\"tool\":\"$2\"}}" | $0
  exit 0
fi

# Show version
if [ "$1" = "--version" ]; then
  echo "ssh-mcp version 0.1.0"
  exit 0
fi

# Ensure directories exist
mkdir -p "$TOOL_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Read the input JSON
INPUT=$(cat)

# Validate JSON input
if ! command -v jq &> /dev/null; then
  echo '{"status":{"code":500,"message":"Missing dependency"},"result":null,"error":{"code":"MISSING_DEPENDENCY","message":"jq is not installed but required for JSON processing"}}'
  exit 1
fi

if ! echo "$INPUT" | jq empty >/dev/null 2>&1; then
  echo '{"status":{"code":400,"message":"Invalid JSON"},"result":null,"error":{"code":"INVALID_JSON","message":"The input is not valid JSON"}}'
  exit 1
fi

# Extract the tool name and arguments
TOOL=$(echo "$INPUT" | jq -r '.tool')
ARGS=$(echo "$INPUT" | jq -r '.args // {}')
CONVERSATION_ID=$(echo "$INPUT" | jq -r '.conversation_id // "none"')

# Log the request
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [$CONVERSATION_ID] REQUEST: $INPUT" >> "$LOG_FILE"

# Check if the tool exists
if [ ! -f "$TOOL_DIR/$TOOL.sh" ]; then
  RESPONSE='{"conversation_id":"'"$CONVERSATION_ID"'","status":{"code":404,"message":"Tool not found"},"result":null,"error":{"code":"TOOL_NOT_FOUND","message":"The requested tool does not exist"}}'
  echo "$RESPONSE"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [$CONVERSATION_ID] RESPONSE: $RESPONSE" >> "$LOG_FILE"
  exit 1
fi

# Create a temporary file for args to avoid potential shell injection
ARGS_FILE=$(mktemp)
echo "$ARGS" > "$ARGS_FILE"

# Execute the tool with the args file
RESULT=$(bash "$TOOL_DIR/$TOOL.sh" "$ARGS_FILE" 2>/tmp/mcp_error.txt)
EXIT_CODE=$?

# Clean up the temporary file
rm "$ARGS_FILE"

if [ $EXIT_CODE -eq 0 ]; then
  # Success response
  RESPONSE="{\"conversation_id\":\"$CONVERSATION_ID\",\"status\":{\"code\":0,\"message\":\"Success\"},\"result\":$RESULT,\"error\":null}"
else
  # Error response
  ERROR_MSG=$(cat /tmp/mcp_error.txt)
  RESPONSE="{\"conversation_id\":\"$CONVERSATION_ID\",\"status\":{\"code\":$EXIT_CODE,\"message\":\"Tool execution failed\"},\"result\":null,\"error\":{\"code\":\"EXECUTION_ERROR\",\"message\":\"$ERROR_MSG\",\"details\":{\"exit_code\":$EXIT_CODE}}}"
  rm /tmp/mcp_error.txt
fi

# Output the result
echo "$RESPONSE"

# Log the response
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [$CONVERSATION_ID] RESPONSE: $RESPONSE" >> "$LOG_FILE"

exit 0
