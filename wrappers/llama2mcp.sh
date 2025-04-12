#!/bin/bash
# llama2mcp.sh - Natural language interface for ssh-mcp using LLaMA
# Version: 1.0.0

# Configuration
SSH_CONFIG="$HOME/.ssh/config"
DEFAULT_HOST="aws-t3-micro"
REMOTE_MCP_PATH="~/.ssh-mcp"

# Get user's natural language instruction
INSTRUCTION="$*"

if [ -z "$INSTRUCTION" ]; then
    echo "Usage: $0 \"your instruction in natural language\""
    echo "Example: $0 \"get system information from aws-t3-micro\""
    exit 1
fi

# Simple prompt for LLaMA
PROMPT="Convert this instruction to a JSON command with host, tool, and args fields: $INSTRUCTION
Default host is $DEFAULT_HOST unless specified.
Available tools: system.info, system.health, process.list, file.list, file.read, network.status.
Example output: {\"host\": \"$DEFAULT_HOST\", \"tool\": \"system.info\", \"args\": {\"verbose\": true}}
ONLY output the JSON, no explanation:"

echo "🧠 Asking LLaMA model to interpret your request..."
if ! command -v ollama &>/dev/null; then
    echo "❌ Error: ollama command not found"
    exit 1
fi

RESPONSE=$(echo "$PROMPT" | ollama run llama3.2:3b-instruct-fp16 2>/dev/null)

# Extract JSON - look for anything that looks like JSON
JSON=$(echo "$RESPONSE" | grep -o '{.*}' | head -n 1)

# If no JSON found, create a simple default
if [ -z "$JSON" ]; then
    echo "❌ Couldn't extract JSON, using default"
    
    # Check if a specific host was mentioned
    if [[ "$INSTRUCTION" == *"aws-t3-micro"* ]]; then
        HOST="aws-t3-micro"
    else
        HOST="$DEFAULT_HOST"
    fi
    
    # Default to system.info
    JSON="{\"host\":\"$HOST\",\"tool\":\"system.info\",\"args\":{}}"
fi

echo "💡 Generated command: $JSON"

# Basic extraction of fields using grep/sed
HOST=$(echo "$JSON" | grep -o '"host"[^,}]*' | cut -d'"' -f4)
TOOL=$(echo "$JSON" | grep -o '"tool"[^,}]*' | cut -d'"' -f4)
ARGS=$(echo "$JSON" | grep -o '"args"[^}]*}' | cut -d':' -f2-)

# Default values if extraction failed
HOST=${HOST:-$DEFAULT_HOST}
TOOL=${TOOL:-"system.info"}
ARGS=${ARGS:-"{}"}

echo "⚡ Executing on $HOST, tool: $TOOL, args: $ARGS"

# Get SSH details from config
USER=$(grep -A5 "^Host $HOST$" "$SSH_CONFIG" | grep "User" | head -n1 | awk '{print $2}')
IDENTITY=$(grep -A5 "^Host $HOST$" "$SSH_CONFIG" | grep "IdentityFile" | head -n1 | awk '{print $2}')
IDENTITY=${IDENTITY/\~/$HOME}

# Build SSH command
SSH_CMD="ssh"
[ -n "$IDENTITY" ] && SSH_CMD="ssh -i $IDENTITY"
[ -n "$USER" ] && HOST="$USER@$HOST"

# Create clean JSON request
REQUEST="{\"tool\":\"$TOOL\",\"args\":$ARGS}"
echo "📦 Request: $REQUEST"

# Execute via SSH
echo "$REQUEST" | $SSH_CMD "$HOST" "cd $REMOTE_MCP_PATH && ./mcp.sh"