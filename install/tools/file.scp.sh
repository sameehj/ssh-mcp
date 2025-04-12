#!/bin/bash
# Tool: file.scp - Transfer files securely between SSH hosts
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: files, transfer, ssh, scp, secure
# Requires sudo: false
#
# Args:
#   source: Source path (string, required)
#   destination: Destination path (string, required)
#   direction: Transfer direction (string, default: "upload", options: "upload", "download")
#   host: Remote host for transfer (string, default: "")
#   port: SSH port (number, default: 22)
#   identity: Path to SSH identity file (string, default: "")
#   recursive: Copy directories recursively (boolean, default: false)
#   preserve: Preserve file attributes (boolean, default: false)
#   compress: Enable compression (boolean, default: false)
#   verbose: Show detailed output (boolean, default: false)
#
# Example:
#   {"tool": "file.scp", "args": {"source": "/local/path", "destination": "/remote/path", "host": "user@remote-host"}}
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
#     "recursive": {
#       "type": "boolean",
#       "description": "Copy directories recursively",
#       "default": false
#     },
#     "preserve": {
#       "type": "boolean",
#       "description": "Preserve file attributes",
#       "default": false
#     },
#     "compress": {
#       "type": "boolean",
#       "description": "Enable compression",
#       "default": false
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
DIRECTION=$(jq -r '.direction // "upload"' "$ARGS_FILE")
HOST=$(jq -r '.host // ""' "$ARGS_FILE")
PORT=$(jq -r '.port // 22' "$ARGS_FILE")
IDENTITY=$(jq -r '.identity // ""' "$ARGS_FILE")
RECURSIVE=$(jq -r '.recursive // false' "$ARGS_FILE")
PRESERVE=$(jq -r '.preserve // false' "$ARGS_FILE")
COMPRESS=$(jq -r '.compress // false' "$ARGS_FILE")
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

# Validate host if required
if [ -z "$HOST" ] && [ "$DIRECTION" != "local" ]; then
  echo '{"error": "Remote host is required for upload/download operations"}' >&2
  exit 1
fi

# Build scp command options
SCP_OPTS="-P $PORT"

# Add identity file if specified
if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "null" ]; then
  SCP_OPTS="$SCP_OPTS -i $IDENTITY"
fi

# Add recursive option if requested
if [ "$RECURSIVE" = "true" ]; then
  SCP_OPTS="$SCP_OPTS -r"
fi

# Add preserve option if requested
if [ "$PRESERVE" = "true" ]; then
  SCP_OPTS="$SCP_OPTS -p"
fi

# Add compression option if requested
if [ "$COMPRESS" = "true" ]; then
  SCP_OPTS="$SCP_OPTS -C"
fi

# Add quiet option if not verbose
if [ "$VERBOSE" != "true" ]; then
  SCP_OPTS="$SCP_OPTS -q"
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

# Execute the scp command
if [ "$VERBOSE" = "true" ]; then
  echo "Executing: scp $SCP_OPTS $SRC_PATH $DEST_PATH" >&2
fi

scp $SCP_OPTS "$SRC_PATH" "$DEST_PATH" 2>/tmp/scp_error.txt
EXIT_CODE=$?

# End transfer time
END_TIME=$(date +%s)
TRANSFER_TIME=$((END_TIME - START_TIME))

# Check if transfer succeeded
if [ $EXIT_CODE -ne 0 ]; then
  ERROR_MSG=$(cat /tmp/scp_error.txt)
  echo "{\"error\": \"SCP transfer failed\", \"details\": \"$ERROR_MSG\", \"exit_code\": $EXIT_CODE}" >&2
  rm -f /tmp/scp_error.txt
  exit 1
fi

rm -f /tmp/scp_error.txt

# Get file/directory info
if [ "$DIRECTION" = "download" ]; then
  # For downloads, we can get local file info
  if [ -f "$DEST_PATH" ]; then
    FILE_TYPE="file"
    FILE_SIZE=$(du -h "$DEST_PATH" 2>/dev/null | cut -f1 || echo "unknown")
    FILE_COUNT=1
  elif [ -d "$DEST_PATH" ]; then
    FILE_TYPE="directory"
    FILE_SIZE=$(du -sh "$DEST_PATH" 2>/dev/null | cut -f1 || echo "unknown")
    FILE_COUNT=$(find "$DEST_PATH" -type f | wc -l)
  else
    FILE_TYPE="unknown"
    FILE_SIZE="unknown"
    FILE_COUNT=0
  fi
else
  # For uploads, we can only guess based on the source
  if [ -f "$SRC_PATH" ]; then
    FILE_TYPE="file"
    FILE_SIZE=$(du -h "$SRC_PATH" 2>/dev/null | cut -f1 || echo "unknown")
    FILE_COUNT=1
  elif [ -d "$SRC_PATH" ]; then
    FILE_TYPE="directory"
    FILE_SIZE=$(du -sh "$SRC_PATH" 2>/dev/null | cut -f1 || echo "unknown")
    FILE_COUNT=$(find "$SRC_PATH" -type f | wc -l)
  else
    FILE_TYPE="unknown"
    FILE_SIZE="unknown"
    FILE_COUNT=0
  fi
fi

# Create explanation message
if [ "$DIRECTION" = "upload" ]; then
  EXPLANATION="Successfully uploaded $FILE_TYPE ($FILE_SIZE) from $SOURCE to $HOST:$DESTINATION in $TRANSFER_TIME seconds"
else
  EXPLANATION="Successfully downloaded $FILE_TYPE ($FILE_SIZE) from $HOST:$SOURCE to $DESTINATION in $TRANSFER_TIME seconds"
fi

# Create the result
RESULT=$(cat <<EOF
{
  "status": "success",
  "transfer": {
    "direction": "$DIRECTION",
    "source": "$SOURCE",
    "destination": "$DESTINATION",
    "host": "$HOST",
    "type": "$FILE_TYPE",
    "size": "$FILE_SIZE",
    "file_count": $FILE_COUNT,
    "time_seconds": $TRANSFER_TIME
  },
  "explanation": "$EXPLANATION",
  "suggestions": [
    {"tool": "file.list", "description": "List files in the destination directory"},
    {"tool": "file.scp", "description": "Transfer more files between hosts"}
  ]
}
EOF
)

echo "$RESULT"
exit 0