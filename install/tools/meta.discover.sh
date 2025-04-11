#!/bin/bash
# Tool: meta.discover - Lists all available tools with their descriptions
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: meta, discovery, documentation
#
# Args:
#   category: Optional filter for tool category (string, optional)
#   tags: Optional tags to filter by (array, optional)
#
# Example:
#   {"tool": "meta.discover", "args": {"category": "system"}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "category": {
#       "type": "string",
#       "description": "Filter tools by category (e.g., 'system', 'file')"
#     },
#     "tags": {
#       "type": "array",
#       "items": {
#         "type": "string"
#       },
#       "description": "Filter tools by tags"
#     }
#   }
# }
# End Schema

ARGS_FILE="$1"
CATEGORY=$(jq -r '.category // ""' "$ARGS_FILE")
TAGS=$(jq -r '.tags // []' "$ARGS_FILE")

TOOL_DIR="$HOME/.ssh-mcp/tools"

# Get a list of all tool files
TOOL_FILES=$(find "$TOOL_DIR" -name "*.sh" -type f | sort)

# Initialize the tools array
TOOLS="["

# First tool flag to handle commas correctly
FIRST=true

# Process each tool file
for TOOL_FILE in $TOOL_FILES; do
  # Extract the tool name from the filename
  TOOL_NAME=$(basename "$TOOL_FILE" .sh)
  
  # Skip if category filter is active and doesn't match
  if [ -n "$CATEGORY" ] && [[ "$TOOL_NAME" != $CATEGORY.* ]]; then
    continue
  fi
  
  # Extract the description from the file
  DESCRIPTION=$(grep -m 1 "# Tool:" "$TOOL_FILE" | sed 's/# Tool: .* - //')
  
  # If no description found, use a default
  if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="No description available"
  fi
  
  # Extract tags if needed for filtering
  if [ "$(echo "$TAGS" | jq 'length')" -gt 0 ]; then
    TOOL_TAGS=$(grep -m 1 "# Tags:" "$TOOL_FILE" | sed 's/# Tags: //' | tr ',' ' ')
    
    # Check if any of the filter tags match
    TAG_MATCH=false
    for TAG in $(echo "$TAGS" | jq -r '.[]'); do
      if [[ "$TOOL_TAGS" == *"$TAG"* ]]; then
        TAG_MATCH=true
        break
      fi
    done
    
    # Skip if no tag matches
    if [ "$TAG_MATCH" = "false" ]; then
      continue
    fi
  fi
  
  # Get tool metadata
  AUTHOR=$(grep -m 1 "# Author:" "$TOOL_FILE" | sed 's/# Author: //' || echo "Unknown")
  VERSION=$(grep -m 1 "# Version:" "$TOOL_FILE" | sed 's/# Version: //' || echo "1.0.0")
  TOOL_TAGS=$(grep -m 1 "# Tags:" "$TOOL_FILE" | sed 's/# Tags: //' | tr ',' '\n' | jq -R -s 'split("\n") | map(select(length > 0))' || echo "[]")
  
  # Add to the tools array, handling commas
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    TOOLS="$TOOLS,"
  fi
  
  TOOLS="$TOOLS
  {
    \"name\": \"$TOOL_NAME\",
    \"description\": \"$DESCRIPTION\",
    \"version\": \"$VERSION\",
    \"author\": \"$AUTHOR\",
    \"tags\": $TOOL_TAGS
  }"
done

# Close the array
TOOLS="$TOOLS
]"

# Prepare suggestions based on the discovered tools
SUGGESTIONS="[]"
if [ "$(echo "$TOOLS" | jq '. | length')" -gt 0 ]; then
  # Pick up to 3 random tools to suggest
  SAMPLE_SIZE=$(echo "$TOOLS" | jq '. | length | if . > 3 then 3 else . end')
  SAMPLE_TOOLS=$(echo "$TOOLS" | jq "[(.|to_entries|sort_by(.value.name)|from_entries|keys)[0:$SAMPLE_SIZE]|.[]")
  
  SUGGESTIONS="["
  FIRST_SUGG=true
  
  for TOOL in $SAMPLE_TOOLS; do
    TOOL=$(echo "$TOOL" | tr -d '"')
    if [ "$FIRST_SUGG" = true ]; then
      FIRST_SUGG=false
    else
      SUGGESTIONS="$SUGGESTIONS,"
    fi
    
    SUGGESTIONS="$SUGGESTIONS
    {
      \"tool\": \"$TOOL\",
      \"description\": \"Try this tool\"
    }"
  done
  
  SUGGESTIONS="$SUGGESTIONS
  ]"
fi

# Return the list of tools
cat <<EOF
{
  "tools": $TOOLS,
  "count": $(echo "$TOOLS" | jq '. | length'),
  "explanation": "These are all the available tools on this system. You can get more details about a specific tool using meta.describe.",
  "suggestions": $SUGGESTIONS
}
