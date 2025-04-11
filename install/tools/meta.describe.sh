#!/bin/bash
# Tool: meta.describe - Returns detailed description for a specific tool
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: meta, discovery, documentation
#
# Args:
#   tool: Name of the tool to describe (string, required)
#
# Example:
#   {"tool": "meta.describe", "args": {"tool": "system.info"}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "tool": {
#       "type": "string",
#       "description": "Name of the tool to describe"
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

# Extract tool metadata from the file
DESCRIPTION=$(grep -m 1 "# Tool:" "$TOOL_FILE" | sed 's/# Tool: .* - //')
AUTHOR=$(grep -m 1 "# Author:" "$TOOL_FILE" | sed 's/# Author: //' || echo "Unknown")
VERSION=$(grep -m 1 "# Version:" "$TOOL_FILE" | sed 's/# Version: //' || echo "1.0.0")
CREATED=$(stat -c %y "$TOOL_FILE" 2>/dev/null | cut -d' ' -f1 || date +%Y-%m-%d)
TAGS=$(grep -m 1 "# Tags:" "$TOOL_FILE" | sed 's/# Tags: //' | tr ',' '\n' | jq -R -s 'split("\n") | map(select(length > 0))' || echo "[]")

# Extract argument documentation from the file
ARGS_DOC=$(awk '/# Args:/,/^#$|^$/ {print}' "$TOOL_FILE" | grep -v "^$" | sed 's/# Args: //' | sed 's/# *//' | jq -R -s 'split("\n") | map(select(length > 0))')

# Extract examples from the file
EXAMPLES=$(awk '/# Example:/,/^#$|^$/ {print}' "$TOOL_FILE" | grep -v "^$" | sed 's/# Example: //' | sed 's/# *//' | jq -R -s 'split("\n") | map(select(length > 0))')

# Extract schema if available
SCHEMA=""
if grep -q "# Schema:" "$TOOL_FILE"; then
  SCHEMA=$(awk '/# Schema:/,/# End Schema/ {print}' "$TOOL_FILE" | grep -v "# Schema:" | grep -v "# End Schema" | sed 's/# //')
  # Validate schema as JSON
  if ! echo "$SCHEMA" | jq empty >/dev/null 2>&1; then
    SCHEMA="{}"
  fi
else
  SCHEMA="{}"
fi

# Return the tool description
cat <<EOF
{
  "tool": "$TOOL_NAME",
  "description": "$DESCRIPTION",
  "metadata": {
    "author": "$AUTHOR",
    "version": "$VERSION",
    "created": "$CREATED",
    "tags": $TAGS
  },
  "args_description": $ARGS_DOC,
  "examples": $EXAMPLES,
  "schema": $SCHEMA,
  "explanation": "This tool ($TOOL_NAME) is used for $DESCRIPTION. It was created by $AUTHOR and is currently at version $VERSION.",
  "suggestions": [
    {"tool": "meta.schema", "description": "Get the JSON schema for this tool"},
    {"tool": "meta.discover", "description": "Discover other available tools"}
  ]
}
