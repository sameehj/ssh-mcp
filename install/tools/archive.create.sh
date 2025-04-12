#!/bin/bash
# Tool: archive.create - Create an archive (zip, tar, tar.gz) from files or directories
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: files, archive, zip, tar, compress
# Requires sudo: false
#
# Args:
#   source: Source path(s) to archive (string or array, required)
#   destination: Destination archive path (string, required)
#   format: Archive format (string, default: "zip", options: "zip", "tar", "tar.gz", "tar.bz2")
#   exclude: Patterns to exclude (string or array, default: [])
#   verbose: Show detailed output (boolean, default: false)
#
# Example:
#   {"tool": "archive.create", "args": {"source": "/home/user/docs", "destination": "/tmp/docs.zip"}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "source": {
#       "oneOf": [
#         {"type": "string"},
#         {"type": "array", "items": {"type": "string"}}
#       ],
#       "description": "Source path(s) to archive"
#     },
#     "destination": {
#       "type": "string",
#       "description": "Destination archive path"
#     },
#     "format": {
#       "type": "string",
#       "description": "Archive format",
#       "enum": ["zip", "tar", "tar.gz", "tar.bz2"],
#       "default": "zip"
#     },
#     "exclude": {
#       "oneOf": [
#         {"type": "string"},
#         {"type": "array", "items": {"type": "string"}}
#       ],
#       "description": "Patterns to exclude",
#       "default": []
#     },
#     "verbose": {
#       "type": "boolean",
#       "description": "Show detailed output",
#       "default": false
#     }
#   },
#   "required": ["source", "destination"]
# }
# End Schema

# Parse arguments from the args file
ARGS_FILE="$1"
SOURCE=$(jq -r '.source' "$ARGS_FILE")
DESTINATION=$(jq -r '.destination' "$ARGS_FILE")
FORMAT=$(jq -r '.format // "zip"' "$ARGS_FILE")
EXCLUDE=$(jq -r '.exclude // []' "$ARGS_FILE")
VERBOSE=$(jq -r '.verbose // false' "$ARGS_FILE")

# Validate required arguments
if [ "$SOURCE" = "null" ] || [ -z "$SOURCE" ]; then
  echo '{"error": "Missing required argument: source"}' >&2
  exit 1
fi

if [ "$DESTINATION" = "null" ] || [ -z "$DESTINATION" ]; then
  echo '{"error": "Missing required argument: destination"}' >&2
  exit 1
fi

# Handle array or string for source
if [[ "$SOURCE" == "["* ]]; then
  # It's an array, extract items
  SOURCE_PATHS=$(jq -r '.source[] | @sh' "$ARGS_FILE" | tr -d "'")
else
  # It's a string
  SOURCE_PATHS="$SOURCE"
fi

# Handle array or string for exclude
EXCLUDE_ARGS=""
if [[ "$EXCLUDE" == "["* ]]; then
  # It's an array, extract items
  while read -r pattern; do
    if [ -n "$pattern" ]; then
      case "$FORMAT" in
        "zip")
          EXCLUDE_ARGS="$EXCLUDE_ARGS -x $pattern"
          ;;
        *)
          EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=$pattern"
          ;;
      esac
    fi
  done < <(jq -r '.exclude[]' "$ARGS_FILE")
elif [ -n "$EXCLUDE" ] && [ "$EXCLUDE" != "null" ]; then
  # It's a string
  case "$FORMAT" in
    "zip")
      EXCLUDE_ARGS="-x $EXCLUDE"
      ;;
    *)
      EXCLUDE_ARGS="--exclude=$EXCLUDE"
      ;;
  esac
fi

# Prepare command based on format
case "$FORMAT" in
  "zip")
    if ! command -v zip &> /dev/null; then
      echo '{"error": "zip command not found. Please install zip."}' >&2
      exit 1
    fi
    
    # Build zip command
    if [ "$VERBOSE" = "true" ]; then
      COMMAND="zip -r $DESTINATION $SOURCE_PATHS $EXCLUDE_ARGS"
    else
      COMMAND="zip -rq $DESTINATION $SOURCE_PATHS $EXCLUDE_ARGS"
    fi
    ;;
  "tar")
    # Build tar command
    if [ "$VERBOSE" = "true" ]; then
      COMMAND="tar -cvf $DESTINATION $EXCLUDE_ARGS $SOURCE_PATHS"
    else
      COMMAND="tar -cf $DESTINATION $EXCLUDE_ARGS $SOURCE_PATHS"
    fi
    ;;
  "tar.gz")
    # Build tar.gz command
    if [ "$VERBOSE" = "true" ]; then
      COMMAND="tar -czvf $DESTINATION $EXCLUDE_ARGS $SOURCE_PATHS"
    else
      COMMAND="tar -czf $DESTINATION $EXCLUDE_ARGS $SOURCE_PATHS"
    fi
    ;;
  "tar.bz2")
    # Build tar.bz2 command
    if [ "$VERBOSE" = "true" ]; then
      COMMAND="tar -cjvf $DESTINATION $EXCLUDE_ARGS $SOURCE_PATHS"
    else
      COMMAND="tar -cjf $DESTINATION $EXCLUDE_ARGS $SOURCE_PATHS"
    fi
    ;;
  *)
    echo "{\"error\": \"Unsupported archive format: $FORMAT\"}" >&2
    exit 1
    ;;
esac

# Execute the command and capture output
if [ "$VERBOSE" = "true" ]; then
  OUTPUT=$(eval "$COMMAND" 2>&1)
  EXIT_CODE=$?
else
  OUTPUT=$(eval "$COMMAND" 2>&1)
  EXIT_CODE=$?
fi

# Check if command succeeded
if [ $EXIT_CODE -ne 0 ]; then
  # Command failed
  echo "{\"error\": \"Failed to create archive\", \"details\": \"$OUTPUT\"}" >&2
  exit 1
fi

# Get archive info
ARCHIVE_SIZE=$(du -h "$DESTINATION" 2>/dev/null | cut -f1 || echo "unknown")
FILE_COUNT=$(case "$FORMAT" in
  "zip")
    unzip -l "$DESTINATION" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown"
    ;;
  *)
    tar -tf "$DESTINATION" 2>/dev/null | wc -l || echo "unknown"
    ;;
esac)

# Create the result
RESULT=$(cat <<EOF
{
  "status": "success",
  "archive": {
    "path": "$DESTINATION",
    "format": "$FORMAT",
    "size": "$ARCHIVE_SIZE",
    "file_count": $FILE_COUNT
  },
  "source": $(jq '.source' "$ARGS_FILE"),
  "explanation": "Successfully created $FORMAT archive at $DESTINATION containing $FILE_COUNT files/directories with size $ARCHIVE_SIZE",
  "suggestions": [
    {"tool": "archive.extract", "description": "Extract this archive"},
    {"tool": "archive.list", "description": "List the contents of this archive"},
    {"tool": "file.list", "description": "List files in the directory of this archive"}
  ]
}
EOF
)

echo "$RESULT"
exit 0