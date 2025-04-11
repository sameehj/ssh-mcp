#!/bin/bash
# Tool: meta.schema - Returns the JSON schema for a specific tool
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: meta, schema, validation
#
# Args:
#   tool: Name of the tool to get schema for (string, required)
#
# Example:
#   {"tool": "meta.schema", "args": {"tool": "system.info"}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "tool": {
#       "type": "string",
#       "description": "Name of the tool to get schema for"
#     }
#   },
#   "required": ["tool"]
# }
# End Schema

ARGS_FILE="$1"
TOOL_NAME=$(jq -r '.tool' "$ARGS_FILE")

# Validate input
if [ -z "$TOOL_NAME" ]; then
  echo "Tool name parameter is required" >&2
  exit 1
fi

# Locate the tool file
TOOL_DIR="$HOME/.ssh-mcp/tools"
TOOL_FILE="$TOOL_DIR/$TOOL_NAME.sh"

# Check if tool exists
if [ ! -f "$TOOL_FILE" ]; then
  echo "Tool not found: $TOOL_NAME" >&2
  exit 2
fi

# Extract schema if available
if grep -q "# Schema:" "$TOOL_FILE"; then
  SCHEMA=$(awk '/# Schema:/,/# End Schema/ {print}' "$TOOL_FILE" | grep -v "# Schema:" | grep -v "# End Schema" | sed 's/# //')
  
  # Validate schema as JSON
  if ! echo "$SCHEMA" | jq empty >/dev/null 2>&1; then
    echo "Invalid schema in tool: $TOOL_NAME" >&2
    exit 3
  fi
else
  # Default minimal schema if none is defined
  SCHEMA="{
  \"type\": \"object\",
  \"properties\": {}
}"
fi

# Return the schema with metadata
cat <<EOF
{
  "tool": "$TOOL_NAME",
  "schema": $SCHEMA,
  "explanation": "This is the JSON schema for the $TOOL_NAME tool. It defines the expected input format.",
  "suggestions": [
    {"tool": "meta.describe", "description": "Get full description of this tool"},
    {"tool": "meta.discover", "description": "Discover other available tools"}
  ]
}
