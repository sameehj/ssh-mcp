#!/bin/bash
# Tool: file.download - Download files from remote URLs to the local filesystem
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: files, download, network, http
# Requires sudo: false
#
# Args:
#   url: URL to download from (string, required)
#   destination: Local path to save the file (string, required)
#   timeout: Download timeout in seconds (number, default: 60)
#   user_agent: Custom user agent string (string, default: "ssh-mcp/0.1.0")
#   headers: Custom HTTP headers (object, default: {})
#   force: Overwrite existing files (boolean, default: false)
#
# Example:
#   {"tool": "file.download", "args": {"url": "https://example.com/file.zip", "destination": "/tmp/file.zip"}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "url": {
#       "type": "string",
#       "description": "URL to download from"
#     },
#     "destination": {
#       "type": "string",
#       "description": "Local path to save the file"
#     },
#     "timeout": {
#       "type": "number",
#       "description": "Download timeout in seconds",
#       "default": 60
#     },
#     "user_agent": {
#       "type": "string",
#       "description": "Custom user agent string",
#       "default": "ssh-mcp/0.1.0"
#     },
#     "headers": {
#       "type": "object",
#       "description": "Custom HTTP headers",
#       "default": {}
#     },
#     "force": {
#       "type": "boolean",
#       "description": "Overwrite existing files",
#       "default": false
#     }
#   },
#   "required": ["url", "destination"]
# }
# End Schema

# Parse arguments from the args file
ARGS_FILE="$1"
URL=$(jq -r '.url' "$ARGS_FILE")
DESTINATION=$(jq -r '.destination' "$ARGS_FILE")
TIMEOUT=$(jq -r '.timeout // 60' "$ARGS_FILE")
USER_AGENT=$(jq -r '.user_agent // "ssh-mcp/0.1.0"' "$ARGS_FILE")
FORCE=$(jq -r '.force // false' "$ARGS_FILE")

# Validate required arguments
if [ "$URL" = "null" ] || [ -z "$URL" ]; then
  echo '{"error": "Missing required argument: url"}' >&2
  exit 1
fi

if [ "$DESTINATION" = "null" ] || [ -z "$DESTINATION" ]; then
  echo '{"error": "Missing required argument: destination"}' >&2
  exit 1
fi

# Check if destination already exists
if [ -e "$DESTINATION" ] && [ "$FORCE" != "true" ]; then
  echo "{\"error\": \"Destination file already exists: $DESTINATION. Use force: true to overwrite.\"}" >&2
  exit 1
fi

# Create the directory if it doesn't exist
mkdir -p "$(dirname "$DESTINATION")" 2>/dev/null

# Determine which download tool to use
if command -v curl &> /dev/null; then
  # Build CURL command with custom headers
  HEADERS_ARGS=""
  if jq -e '.headers' "$ARGS_FILE" > /dev/null 2>&1; then
    # Process each header
    while read -r key; do
      if [ -n "$key" ]; then
        value=$(jq -r ".headers[\"$key\"]" "$ARGS_FILE")
        HEADERS_ARGS="$HEADERS_ARGS -H \"$key: $value\""
      fi
    done < <(jq -r '.headers | keys[]' "$ARGS_FILE" 2>/dev/null)
  fi
  
  # Build the command
  COMMAND="curl -s -L --connect-timeout $TIMEOUT -A \"$USER_AGENT\" $HEADERS_ARGS -o \"$DESTINATION\" \"$URL\""
  
  # Add -f to fail on HTTP errors
  COMMAND="$COMMAND -f"
  
  # Start download time
  START_TIME=$(date +%s)
  
  # Execute the command
  eval "$COMMAND"
  EXIT_CODE=$?
  
  # End download time
  END_TIME=$(date +%s)
  DOWNLOAD_TIME=$((END_TIME - START_TIME))
elif command -v wget &> /dev/null; then
  # Build WGET command with custom headers
  HEADERS_ARGS=""
  if jq -e '.headers' "$ARGS_FILE" > /dev/null 2>&1; then
    # Process each header
    while read -r key; do
      if [ -n "$key" ]; then
        value=$(jq -r ".headers[\"$key\"]" "$ARGS_FILE")
        HEADERS_ARGS="$HEADERS_ARGS --header=\"$key: $value\""
      fi
    done < <(jq -r '.headers | keys[]' "$ARGS_FILE" 2>/dev/null)
  fi
  
  # Build the command
  COMMAND="wget -q --timeout=$TIMEOUT --user-agent=\"$USER_AGENT\" $HEADERS_ARGS -O \"$DESTINATION\" \"$URL\""
  
  # Start download time
  START_TIME=$(date +%s)
  
  # Execute the command
  eval "$COMMAND"
  EXIT_CODE=$?
  
  # End download time
  END_TIME=$(date +%s)
  DOWNLOAD_TIME=$((END_TIME - START_TIME))
else
  echo '{"error": "No download tool available. Please install curl or wget."}' >&2
  exit 1
fi

# Check if download succeeded
if [ $EXIT_CODE -ne 0 ]; then
  echo "{\"error\": \"Failed to download file from $URL\", \"exit_code\": $EXIT_CODE}" >&2
  exit 1
fi

# Get file info
FILE_SIZE=$(du -h "$DESTINATION" 2>/dev/null | cut -f1 || echo "unknown")
FILE_TYPE=$(file -b "$DESTINATION" 2>/dev/null || echo "unknown")
MD5_SUM=$(md5sum "$DESTINATION" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

# Create the result
RESULT=$(cat <<EOF
{
  "status": "success",
  "file": {
    "path": "$DESTINATION",
    "size": "$FILE_SIZE",
    "type": "$FILE_TYPE",
    "md5": "$MD5_SUM"
  },
  "download": {
    "url": "$URL",
    "time_seconds": $DOWNLOAD_TIME
  },
  "explanation": "Successfully downloaded file from $URL to $DESTINATION (size: $FILE_SIZE) in $DOWNLOAD_TIME seconds",
  "suggestions": [
    {"tool": "file.list", "description": "List files in the download directory"},
    {"tool": "archive.extract", "description": "Extract this file if it's an archive"}
  ]
}
EOF
)

echo "$RESULT"
exit 0