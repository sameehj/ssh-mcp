#!/bin/bash
# Tool: file.upload - Upload file to remote server or service
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: files, upload, network, http
# Requires sudo: false
#
# Args:
#   file: Local file path to upload (string, required)
#   destination: Destination URL or path (string, required)
#   type: Destination type (string, default: "http", options: "http", "ftp", "s3")
#   credentials: Authentication credentials (object, default: {})
#   headers: Custom HTTP headers for web uploads (object, default: {})
#   progress: Show upload progress (boolean, default: false)
#
# Example:
#   {"tool": "file.upload", "args": {"file": "/tmp/data.csv", "destination": "https://example.com/upload"}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "file": {
#       "type": "string",
#       "description": "Local file path to upload"
#     },
#     "destination": {
#       "type": "string",
#       "description": "Destination URL or path"
#     },
#     "type": {
#       "type": "string",
#       "description": "Destination type",
#       "enum": ["http", "ftp", "s3"],
#       "default": "http"
#     },
#     "credentials": {
#       "type": "object",
#       "description": "Authentication credentials",
#       "default": {}
#     },
#     "headers": {
#       "type": "object",
#       "description": "Custom HTTP headers for web uploads",
#       "default": {}
#     },
#     "progress": {
#       "type": "boolean",
#       "description": "Show upload progress",
#       "default": false
#     }
#   },
#   "required": ["file", "destination"]
# }
# End Schema

# Parse arguments from the args file
ARGS_FILE="$1"
FILE=$(jq -r '.file' "$ARGS_FILE")
DESTINATION=$(jq -r '.destination' "$ARGS_FILE")
TYPE=$(jq -r '.type // "http"' "$ARGS_FILE")
PROGRESS=$(jq -r '.progress // false' "$ARGS_FILE")

# Validate required arguments
if [ "$FILE" = "null" ] || [ -z "$FILE" ]; then
  echo '{"error": "Missing required argument: file"}' >&2
  exit 1
fi

if [ "$DESTINATION" = "null" ] || [ -z "$DESTINATION" ]; then
  echo '{"error": "Missing required argument: destination"}' >&2
  exit 1
fi

# Check if source file exists
if [ ! -f "$FILE" ]; then
  echo "{\"error\": \"Source file does not exist: $FILE\"}" >&2
  exit 1
fi

# Get file info before upload
FILE_SIZE=$(du -h "$FILE" 2>/dev/null | cut -f1 || echo "unknown")
FILE_TYPE=$(file -b "$FILE" 2>/dev/null || echo "unknown")
MD5_SUM=$(md5sum "$FILE" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

# Function to handle HTTP upload
http_upload() {
  # Extract credentials if provided
  USERNAME=""
  PASSWORD=""
  
  if jq -e '.credentials.username' "$ARGS_FILE" > /dev/null 2>&1; then
    USERNAME=$(jq -r '.credentials.username' "$ARGS_FILE")
    
    if jq -e '.credentials.password' "$ARGS_FILE" > /dev/null 2>&1; then
      PASSWORD=$(jq -r '.credentials.password' "$ARGS_FILE")
      AUTH_ARG="-u \"$USERNAME:$PASSWORD\""
    else
      AUTH_ARG="-u \"$USERNAME\""
    fi
  else
    AUTH_ARG=""
  fi
  
  # Build headers arguments
  HEADERS_ARGS=""
  if jq -e '.headers' "$ARGS_FILE" > /dev/null 2>&1; then
    while read -r key; do
      if [ -n "$key" ]; then
        value=$(jq -r ".headers[\"$key\"]" "$ARGS_FILE")
        HEADERS_ARGS="$HEADERS_ARGS -H \"$key: $value\""
      fi
    done < <(jq -r '.headers | keys[]' "$ARGS_FILE" 2>/dev/null)
  fi
  
  # Determine content type based on file extension if not specified
  if ! echo "$HEADERS_ARGS" | grep -q "Content-Type"; then
    # Extract file extension
    FILE_EXT="${FILE##*.}"
    
    case "$FILE_EXT" in
      "json")
        CONTENT_TYPE="application/json"
        ;;
      "xml")
        CONTENT_TYPE="application/xml"
        ;;
      "csv")
        CONTENT_TYPE="text/csv"
        ;;
      "txt")
        CONTENT_TYPE="text/plain"
        ;;
      "html"|"htm")
        CONTENT_TYPE="text/html"
        ;;
      "jpg"|"jpeg")
        CONTENT_TYPE="image/jpeg"
        ;;
      "png")
        CONTENT_TYPE="image/png"
        ;;
      "pdf")
        CONTENT_TYPE="application/pdf"
        ;;
      *)
        CONTENT_TYPE="application/octet-stream"
        ;;
    esac
    
    HEADERS_ARGS="$HEADERS_ARGS -H \"Content-Type: $CONTENT_TYPE\""
  fi
  
  # Build CURL command
  if [ "$PROGRESS" = "true" ]; then
    PROGRESS_ARG=""
  else
    PROGRESS_ARG="-s"
  fi
  
  COMMAND="curl $PROGRESS_ARG -L $AUTH_ARG $HEADERS_ARGS -X POST --data-binary @\"$FILE\" \"$DESTINATION\""
  
  # Start upload time
  START_TIME=$(date +%s)
  
  # Execute the command
  RESPONSE=$(eval "$COMMAND")
  EXIT_CODE=$?
  
  # End upload time
  END_TIME=$(date +%s)
  UPLOAD_TIME=$((END_TIME - START_TIME))
  
  # Return the result
  if [ $EXIT_CODE -eq 0 ]; then
    echo "{\"status\":\"success\",\"response\":\"$RESPONSE\",\"time_seconds\":$UPLOAD_TIME}"
  else
    echo "{\"status\":\"error\",\"exit_code\":$EXIT_CODE,\"response\":\"$RESPONSE\"}" >&2
    return 1
  fi
}

# Function to handle FTP upload
ftp_upload() {
  # Extract credentials
  USERNAME=$(jq -r '.credentials.username // "anonymous"' "$ARGS_FILE")
  PASSWORD=$(jq -r '.credentials.password // ""' "$ARGS_FILE")
  
  # Check for curl with FTP support
  if curl --version | grep -q "ftp"; then
    # Build FTP URL with credentials
    if [[ "$DESTINATION" == ftp://* ]]; then
      # URL already has ftp:// prefix
      FTP_URL="$DESTINATION"
    else
      # Add ftp:// prefix if not present
      FTP_URL="ftp://$DESTINATION"
    fi
    
    # Add credentials to URL if not already present
    if ! echo "$FTP_URL" | grep -q "@"; then
      FTP_URL="${FTP_URL/ftp:\/\//ftp:\/\/$USERNAME:$PASSWORD@}"
    fi
    
    # Build CURL command
    if [ "$PROGRESS" = "true" ]; then
      PROGRESS_ARG=""
    else
      PROGRESS_ARG="-s"
    fi
    
    COMMAND="curl $PROGRESS_ARG -T \"$FILE\" \"$FTP_URL\""
    
    # Start upload time
    START_TIME=$(date +%s)
    
    # Execute the command
    eval "$COMMAND"
    EXIT_CODE=$?
    
    # End upload time
    END_TIME=$(date +%s)
    UPLOAD_TIME=$((END_TIME - START_TIME))
    
    # Return the result
    if [ $EXIT_CODE -eq 0 ]; then
      echo "{\"status\":\"success\",\"time_seconds\":$UPLOAD_TIME}"
    else
      echo "{\"status\":\"error\",\"exit_code\":$EXIT_CODE}" >&2
      return 1
    fi
  elif command -v ftp &> /dev/null; then
    # Extract host, port, and path from destination
    if [[ "$DESTINATION" == ftp://* ]]; then
      # Parse URL
      HOST=$(echo "$DESTINATION" | sed -E 's|ftp://([^/]+)/.*|\1|')
      PATH=$(echo "$DESTINATION" | sed -E 's|ftp://[^/]+/(.*)|\1|')
    else
      # Assume destination is in format host:/path
      HOST=$(echo "$DESTINATION" | cut -d':' -f1)
      PATH=$(echo "$DESTINATION" | cut -d':' -f2-)
    fi
    
    # Create FTP commands file
    FTP_COMMANDS=$(mktemp)
    cat > "$FTP_COMMANDS" << EOF
user $USERNAME $PASSWORD
binary
cd $(dirname "$PATH")
put "$FILE" $(basename "$PATH")
quit
EOF
    
    # Start upload time
    START_TIME=$(date +%s)
    
    # Execute FTP command
    if [ "$PROGRESS" = "true" ]; then
      ftp -n "$HOST" < "$FTP_COMMANDS"
    else
      ftp -n "$HOST" < "$FTP_COMMANDS" > /dev/null 2>&1
    fi
    EXIT_CODE=$?
    
    # Clean up commands file
    rm "$FTP_COMMANDS"
    
    # End upload time
    END_TIME=$(date +%s)
    UPLOAD_TIME=$((END_TIME - START_TIME))
    
    # Return the result
    if [ $EXIT_CODE -eq 0 ]; then
      echo "{\"status\":\"success\",\"time_seconds\":$UPLOAD_TIME}"
    else
      echo "{\"status\":\"error\",\"exit_code\":$EXIT_CODE}" >&2
      return 1
    fi
  else
    echo "{\"error\": \"No FTP client available. Please install curl with FTP support or ftp client.\"}" >&2
    return 1
  fi
}

# Function to handle S3 upload
s3_upload() {
  # Check for AWS CLI
  if ! command -v aws &> /dev/null; then
    echo "{\"error\": \"AWS CLI not installed. Please install aws-cli to use S3 uploads.\"}" >&2
    return 1
  fi
  
  # Extract credentials if provided
  if jq -e '.credentials.aws_access_key_id' "$ARGS_FILE" > /dev/null 2>&1; then
    AWS_ACCESS_KEY=$(jq -r '.credentials.aws_access_key_id' "$ARGS_FILE")
    AWS_SECRET_KEY=$(jq -r '.credentials.aws_secret_access_key' "$ARGS_FILE")
    
    # Set AWS credentials as environment variables
    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_KEY"
  fi
  
  # Parse S3 URL
  if [[ "$DESTINATION" == s3://* ]]; then
    S3_URL="$DESTINATION"
  else
    S3_URL="s3://$DESTINATION"
  fi
  
  # Build AWS command
  if [ "$PROGRESS" = "true" ]; then
    COMMAND="aws s3 cp \"$FILE\" \"$S3_URL\""
  else
    COMMAND="aws s3 cp \"$FILE\" \"$S3_URL\" --quiet"
  fi
  
  # Start upload time
  START_TIME=$(date +%s)
  
  # Execute the command
  eval "$COMMAND"
  EXIT_CODE=$?
  
  # End upload time
  END_TIME=$(date +%s)
  UPLOAD_TIME=$((END_TIME - START_TIME))
  
  # Return the result
  if [ $EXIT_CODE -eq 0 ]; then
    echo "{\"status\":\"success\",\"s3_url\":\"$S3_URL\",\"time_seconds\":$UPLOAD_TIME}"
  else
    echo "{\"status\":\"error\",\"exit_code\":$EXIT_CODE}" >&2
    return 1
  fi
}

# Perform upload based on the specified type
case "$TYPE" in
  "http")
    UPLOAD_RESULT=$(http_upload)
    EXIT_CODE=$?
    ;;
  "ftp")
    UPLOAD_RESULT=$(ftp_upload)
    EXIT_CODE=$?
    ;;
  "s3")
    UPLOAD_RESULT=$(s3_upload)
    EXIT_CODE=$?
    ;;
  *)
    echo "{\"error\": \"Unsupported upload type: $TYPE\"}" >&2
    exit 1
    ;;
esac

# Check if upload succeeded
if [ $EXIT_CODE -ne 0 ]; then
  echo "{\"error\": \"Failed to upload file\", \"details\": $UPLOAD_RESULT}" >&2
  exit 1
fi

# Create the result
RESULT=$(cat <<EOF
{
  "status": "success",
  "file": {
    "name": "$(basename "$FILE")",
    "size": "$FILE_SIZE",
    "type": "$FILE_TYPE",
    "md5": "$MD5_SUM"
  },
  "upload": $UPLOAD_RESULT,
  "destination": "$DESTINATION",
  "explanation": "Successfully uploaded file $(basename "$FILE") ($FILE_SIZE) to $DESTINATION",
  "suggestions": [
    {"tool": "file.list", "description": "List files in the source directory"},
    {"tool": "file.download", "description": "Download a file from a remote location"}
  ]
}
EOF
)

echo "$RESULT"
exit 0