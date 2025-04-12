#!/bin/bash
# Tool: file.rsync - Efficiently synchronize files and directories
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: files, sync, rsync, directory, transfer
# Requires sudo: false
#
# Args:
#   source: Source path (string, required)
#   destination: Destination path (string, required)
#   direction: Transfer direction (string, default: "upload", options: "upload", "download")
#   host: Remote host for transfer (string, default: "")
#   port: SSH port (number, default: 22)
#   identity: Path to SSH identity file (string, default: "")
#   delete: Delete extraneous files from destination (boolean, default: false)
#   archive: Archive mode (preserves permissions, times, etc.) (boolean, default: true)
#   compress: Enable compression (boolean, default: true)
#   verbose: Show detailed output (boolean, default: false)
#   exclude: Patterns to exclude (array or string, default: [])
#   include: Patterns to include (array or string, default: [])
#   dry_run: Simulate the transfer without making changes (boolean, default: false)
#
# Example:
#   {"tool": "file.rsync", "args": {"source": "/local/dir/", "destination": "/remote/dir/", "host": "user@remote-host"}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "source": {
#       "type": "string",
#       "description": "Source path"
#     },
#     "destination": {
#       "type": "string",
#       "description": "Destination path"
#     },
#     "direction": {
#       "type": "string",
#       "description": "Transfer direction",
#       "enum": ["upload", "download"],
#       "default": "upload"
#     },
#     "host": {
#       "type": "string",
#       "description": "Remote host for transfer",
#       "default": ""
#     },
#     "port": {
#       "type": "number",
#       "description": "SSH port",
#       "default": 22
#     },
#     "identity": {
#       "type": "string",
#       "description": "Path to SSH identity file",
#       "default": ""
#     },
#     "delete": {
#       "type": "boolean",
#       "description": "Delete extraneous files from destination",
#       "default": false
#     },
#     "archive": {
#       "type": "boolean",
#       "description": "Archive mode (preserves permissions, times, etc.)",
#       "default": true
#     },
#     "compress": {
#       "type": "boolean",
#       "description": "Enable compression",
#       "default": true
#     },
#     "verbose": {
#       "type": "boolean",
#       "description": "Show detailed output",
#       "default": false
#     },
#     "exclude": {
#       "oneOf": [
#         {"type": "string"},
#         {"type": "array", "items": {"type": "string"}}
#       ],
#       "description": "Patterns to exclude",
#       "default": []
#     },
#     "include": {
#       "oneOf": [
#         {"type": "string"},
#         {"type": "array", "items": {"type": "string"}}
#       ],
#       "description": "Patterns to include",
#       "default": []
#     },
#     "dry_run": {
#       "type": "boolean",
#       "description": "Simulate the transfer without making changes",
#       "default": false
#     }
#   },
#   "required": ["source", "destination"]
# }
# End Schema

# Check if rsync is installed
if ! command -v rsync &> /dev/null; then
  echo '{"error": "rsync is not installed. Please install rsync to use this tool."}' >&2
  exit 1
fi

# Parse arguments from the args file
ARGS_FILE="$1"
SOURCE=$(jq -r '.source' "$ARGS_FILE")
DESTINATION=$(jq -r '.destination' "$ARGS_FILE")
DIRECTION=$(jq -r '.direction // "upload"' "$ARGS_FILE")
HOST=$(jq -r '.host // ""' "$ARGS_FILE")
PORT=$(jq -r '.port // 22' "$ARGS_FILE")
IDENTITY=$(jq -r '.identity // ""' "$ARGS_FILE")
DELETE=$(jq -r '.delete // false' "$ARGS_FILE")
ARCHIVE=$(jq -r '.archive // true' "$ARGS_FILE")
COMPRESS=$(jq -r '.compress // true' "$ARGS_FILE")
VERBOSE=$(jq -r '.verbose // false' "$ARGS_FILE")
DRY_RUN=$(jq -r '.dry_run // false' "$ARGS_FILE")
EXCLUDE=$(jq -r '.exclude // []' "$ARGS_FILE")
INCLUDE=$(jq -r '.include // []' "$ARGS_FILE")

# Validate required arguments
if [ "$SOURCE" = "null" ] || [ -z "$SOURCE" ]; then
  echo '{"error": "Missing required argument: source"}' >&2
  exit 1
fi

if [ "$DESTINATION" = "null" ] || [ -z "$DESTINATION" ]; then
  echo '{"error": "Missing required argument: destination"}' >&2
  exit 1
fi

# Validate host if required
if [ -z "$HOST" ] && [ "$DIRECTION" != "local" ]; then
  echo '{"error": "Remote host is required for upload/download operations"}' >&2
  exit 1
fi

# Build rsync command options
RSYNC_OPTS=""

# Add archive option if requested
if [ "$ARCHIVE" = "true" ]; then
  RSYNC_OPTS="$RSYNC_OPTS -a"
else
  # If not archive mode, at least use recursive to ensure directory transfers
  RSYNC_OPTS="$RSYNC_OPTS -r"
fi

# Add compression option if requested
if [ "$COMPRESS" = "true" ]; then
  RSYNC_OPTS="$RSYNC_OPTS -z"
fi

# Add verbose option if requested
if [ "$VERBOSE" = "true" ]; then
  RSYNC_OPTS="$RSYNC_OPTS -v"
else
  # If not verbose, use quiet mode
  RSYNC_OPTS="$RSYNC_OPTS -q"
fi

# Add delete option if requested
if [ "$DELETE" = "true" ]; then
  RSYNC_OPTS="$RSYNC_OPTS --delete"
fi

# Add dry-run option if requested
if [ "$DRY_RUN" = "true" ]; then
  RSYNC_OPTS="$RSYNC_OPTS --dry-run"
fi

# Add SSH options
RSYNC_OPTS="$RSYNC_OPTS -e 'ssh -p $PORT"
if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "null" ]; then
  RSYNC_OPTS="$RSYNC_OPTS -i $IDENTITY"
fi
RSYNC_OPTS="$RSYNC_OPTS'"

# Process exclude patterns
EXCLUDE_OPTS=""
if [[ "$EXCLUDE" == "["* ]]; then
  # It's an array, extract items
  while read -r pattern; do
    if [ -n "$pattern" ]; then
      EXCLUDE_OPTS="$EXCLUDE_OPTS --exclude='$pattern'"
    fi
  done < <(jq -r '.exclude[]' "$ARGS_FILE")
elif [ -n "$EXCLUDE" ] && [ "$EXCLUDE" != "null" ]; then
  # It's a string
  EXCLUDE_OPTS="--exclude='$EXCLUDE'"
fi

# Process include patterns
INCLUDE_OPTS=""
if [[ "$INCLUDE" == "["* ]]; then
  # It's an array, extract items
  while read -r pattern; do
    if [ -n "$pattern" ]; then
      INCLUDE_OPTS="$INCLUDE_OPTS --include='$pattern'"
    fi
  done < <(jq -r '.include[]' "$ARGS_FILE")
elif [ -n "$INCLUDE" ] && [ "$INCLUDE" != "null" ]; then
  # It's a string
  INCLUDE_OPTS="--include='$INCLUDE'"
fi

# Ensure source ends with trailing slash for directory syncing
if [ -d "$SOURCE" ] && [[ "$SOURCE" != */ ]]; then
  SOURCE="$SOURCE/"
fi

# Construct the source and destination paths based on direction
case "$DIRECTION" in
  "upload")
    SRC_PATH="$SOURCE"
    DEST_PATH="$HOST:$DESTINATION"
    ;;
  "download")
    SRC_PATH="$HOST:$SOURCE"
    DEST_PATH="$DESTINATION"
    ;;
  *)
    echo "{\"error\": \"Invalid direction: $DIRECTION. Must be 'upload' or 'download'.\"}" >&2
    exit 1
    ;;
esac

# Start transfer time
START_TIME=$(date +%s)

# Execute the rsync command
if [ "$VERBOSE" = "true" ]; then
  echo "Executing: rsync $RSYNC_OPTS $INCLUDE_OPTS $EXCLUDE_OPTS $SRC_PATH $DEST_PATH" >&2
fi

# Create a log file for rsync output
RSYNC_LOG=$(mktemp)

# Execute command with all options
eval "rsync $RSYNC_OPTS $INCLUDE_OPTS $EXCLUDE_OPTS \"$SRC_PATH\" \"$DEST_PATH\"" > "$RSYNC_LOG" 2>&1
EXIT_CODE=$?

# End transfer time
END_TIME=$(date +%s)
TRANSFER_TIME=$((END_TIME - START_TIME))

# Check if transfer succeeded
if [ $EXIT_CODE -ne 0 ]; then
  ERROR_MSG=$(cat "$RSYNC_LOG")
  echo "{\"error\": \"rsync transfer failed\", \"details\": \"$ERROR_MSG\", \"exit_code\": $EXIT_CODE}" >&2
  rm -f "$RSYNC_LOG"
  exit 1
fi

# Analyze transfer statistics
if [ "$DRY_RUN" = "true" ]; then
  # For dry run, just count the number of lines in the log file
  TRANSFERRED_FILES=$(grep -v "^total size" "$RSYNC_LOG" | wc -l)
  BYTES_TRANSFERRED="0 (dry run)"
else
  # For real transfers, try to extract stats if verbose was enabled
  if [ "$VERBOSE" = "true" ]; then
    TRANSFERRED_FILES=$(grep -v "^total size" "$RSYNC_LOG" | wc -l)
    BYTES_TRANSFERRED=$(grep "^total size" "$RSYNC_LOG" | awk '{print $4}' || echo "unknown")
  else
    # For non-verbose transfers, we can't get exact stats
    TRANSFERRED_FILES="unknown (use verbose mode for details)"
    BYTES_TRANSFERRED="unknown (use verbose mode for details)"
  fi
fi

# Clean up log file
rm -f "$RSYNC_LOG"

# Create explanation message
if [ "$DIRECTION" = "upload" ]; then
  EXPLANATION="Successfully synchronized from $SOURCE to $HOST:$DESTINATION in $TRANSFER_TIME seconds"
else
  EXPLANATION="Successfully synchronized from $HOST:$SOURCE to $DESTINATION in $TRANSFER_TIME seconds"
fi

if [ "$DRY_RUN" = "true" ]; then
  EXPLANATION="$EXPLANATION (dry run - no actual changes made)"
fi

# Create the result
RESULT=$(cat <<EOF
{
  "status": "success",
  "sync": {
    "direction": "$DIRECTION",
    "source": "$SOURCE",
    "destination": "$DESTINATION",
    "host": "$HOST",
    "transferred_files": "$TRANSFERRED_FILES",
    "bytes_transferred": "$BYTES_TRANSFERRED",
    "time_seconds": $TRANSFER_TIME,
    "dry_run": $DRY_RUN,
    "delete_enabled": $DELETE
  },
  "explanation": "$EXPLANATION",
  "suggestions": [
    {"tool": "file.list", "description": "List files in the destination directory"},
    {"tool": "file.rsync", "description": "Perform additional synchronization"}
  ]
}
EOF
)

echo "$RESULT"
exit 0