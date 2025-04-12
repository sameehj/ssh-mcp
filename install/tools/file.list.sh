#!/bin/bash
# Tool: file.list - List files in a directory
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: files, filesystem, directory
# Requires sudo: false
#
# Args:
#   path: Directory path to list (string, default: ".")
#   pattern: Optional pattern to filter files (string, default: "")
#   show_hidden: Show hidden files (boolean, default: false)
#   recursive: List recursively (boolean, default: false)
#   limit: Maximum number of files to return (number, default: 50)
#
# Example:
#   {"tool": "file.list", "args": {"path": "/etc", "pattern": "*.conf", "show_hidden": false}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "path": {
#       "type": "string",
#       "description": "Directory path to list",
#       "default": "."
#     },
#     "pattern": {
#       "type": "string",
#       "description": "Optional pattern to filter files",
#       "default": ""
#     },
#     "show_hidden": {
#       "type": "boolean",
#       "description": "Show hidden files",
#       "default": false
#     },
#     "recursive": {
#       "type": "boolean",
#       "description": "List recursively",
#       "default": false
#     },
#     "limit": {
#       "type": "number",
#       "description": "Maximum number of files to return",
#       "default": 50
#     }
#   }
# }
# End Schema

# Parse arguments from the args file
ARGS_FILE="$1"
PATH_TO_LIST=$(jq -r '.path // "."' "$ARGS_FILE")
PATTERN=$(jq -r '.pattern // ""' "$ARGS_FILE")
SHOW_HIDDEN=$(jq -r '.show_hidden // false' "$ARGS_FILE")
RECURSIVE=$(jq -r '.recursive // false' "$ARGS_FILE")
LIMIT=$(jq -r '.limit // 50' "$ARGS_FILE")

# Ensure limit is a number
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  LIMIT=50
fi

# Validate path
if [ ! -d "$PATH_TO_LIST" ]; then
  echo "{\"error\": \"Directory not found\", \"path\": \"$PATH_TO_LIST\"}" >&2
  exit 1
fi

# Build ls command arguments (more portable than find)
LS_ARGS="-la"  # Get detailed listing
if [ "$RECURSIVE" = "true" ]; then
  LS_ARGS="$LS_ARGS -R"  # Recursive
fi

# Execute ls command and process output
FILES_DATA=$(ls $LS_ARGS "$PATH_TO_LIST" 2>/dev/null | grep -v "^total" | awk '{
  # Use $9 (name) for non-recursive listing
  filename = $9
  
  # For recursive listings, we need to handle directory headers
  if (NF >= 9) {
    # This is a file entry, combine fields 9+ for filename (may have spaces)
    filename = ""
    for (i=9; i<=NF; i++) {
      if (i > 9) filename = filename " "
      filename = filename $i
    }
  } else if (NF == 0 || $0 ~ /^$/) {
    # Skip empty lines
    next
  } else if ($0 ~ /:$/) {
    # This is a directory header in recursive listing
    dir_name = $0
    gsub(/:$/, "", dir_name)
    current_dir = dir_name
    next
  } else {
    # Skip lines we cannot parse
    next
  }

  # Skip if not matching pattern
  if ("'"$PATTERN"'" != "" && filename !~ "'"$PATTERN"'") {
    next
  }
  
  # Skip hidden files if not showing hidden
  if ("'"$SHOW_HIDDEN"'" != "true" && filename ~ /^\./) {
    next
  }
  
  # Get file type
  type = substr($1, 1, 1)
  type_name = "unknown"
  if (type == "-") type_name = "file"
  else if (type == "d") type_name = "directory"
  else if (type == "l") type_name = "symlink"
  else if (type == "c") type_name = "character device"
  else if (type == "b") type_name = "block device"
  else if (type == "p") type_name = "pipe"
  else if (type == "s") type_name = "socket"
  
  # Get permissions string
  perms = substr($1, 2)
  
  # Get size
  size = $5
  
  # Get modification time
  mod_time = $6 " " $7 " " $8
  
  # Build the output line
  if ("'"$RECURSIVE"'" == "true" && current_dir != "") {
    path = current_dir "/" filename
  } else {
    path = filename
  }
  
  print path "," type_name "," size "," mod_time "," perms
}' | head -n "$LIMIT")

# Convert to JSON format
FILE_JSON="["
first=true

while IFS= read -r line; do
  if [ -n "$line" ]; then
    # Parse the comma-separated values
    PATH_NAME=$(echo "$line" | cut -d',' -f1)
    TYPE=$(echo "$line" | cut -d',' -f2)
    SIZE=$(echo "$line" | cut -d',' -f3)
    MOD_TIME=$(echo "$line" | cut -d',' -f4)
    PERMS=$(echo "$line" | cut -d',' -f5)
    
    # Escape JSON special characters
    PATH_NAME=$(echo "$PATH_NAME" | sed 's/"/\\"/g')
    
    # Add comma if not first item
    if [ "$first" = true ]; then
      first=false
    else
      FILE_JSON="$FILE_JSON,"
    fi
    
    # Add file to JSON array
    FILE_JSON="$FILE_JSON
    {
      \"name\": \"$PATH_NAME\",
      \"type\": \"$TYPE\",
      \"size\": $SIZE,
      \"modified\": \"$MOD_TIME\",
      \"permissions\": \"$PERMS\"
    }"
  fi
done <<< "$FILES_DATA"

FILE_JSON="$FILE_JSON
]"

# Get directory info
DIR_SIZE=$(du -sh "$PATH_TO_LIST" 2>/dev/null | cut -f1 || echo "unknown")
FILE_COUNT=$(echo "$FILE_JSON" | grep -c "name")
TOTAL_FILES=$(ls -la "$PATH_TO_LIST" 2>/dev/null | grep -v "^total" | wc -l)

# Add directory details to result
DIR_INFO=$(cat <<EOF
{
  "path": "$PATH_TO_LIST",
  "size": "$DIR_SIZE",
  "file_count": $FILE_COUNT,
  "total_files": $TOTAL_FILES,
  "is_recursive": $RECURSIVE,
  "pattern": "$PATTERN",
  "show_hidden": $SHOW_HIDDEN
}
EOF
)

# Create explanation
if [ -n "$PATTERN" ]; then
  EXPLANATION="Listing of $PATH_TO_LIST (filtered by pattern '$PATTERN') showing $FILE_COUNT of $TOTAL_FILES files."
else
  EXPLANATION="Listing of $PATH_TO_LIST showing $FILE_COUNT of $TOTAL_FILES files."
fi

if [ "$RECURSIVE" = "true" ]; then
  EXPLANATION="$EXPLANATION Recursive listing."
fi

if [ "$SHOW_HIDDEN" = "true" ]; then
  EXPLANATION="$EXPLANATION Including hidden files."
else
  EXPLANATION="$EXPLANATION Excluding hidden files."
fi

# Create the result
RESULT=$(cat <<EOF
{
  "directory": $DIR_INFO,
  "files": $FILE_JSON,
  "explanation": "$EXPLANATION",
  "suggestions": [
    {"tool": "file.list", "description": "List files with different options"},
    {"tool": "file.read", "description": "Read the contents of a file"}
  ]
}
EOF
)

echo "$RESULT"
exit 0