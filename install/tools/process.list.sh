#!/bin/bash
# Tool: process.list - List running processes on the system
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: process, monitoring, system
# Requires sudo: false
#
# Args:
#   filter: Optional string to filter process list (string, default: "")
#   sort: Field to sort by (string, default: "cpu", options: "cpu", "memory", "pid", "name")
#   limit: Maximum number of processes to return (number, default: 10)
#
# Example:
#   {"tool": "process.list", "args": {"filter": "ssh", "sort": "cpu", "limit": 5}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "filter": {
#       "type": "string",
#       "description": "Optional filter for process names",
#       "default": ""
#     },
#     "sort": {
#       "type": "string",
#       "description": "Field to sort by",
#       "enum": ["cpu", "memory", "pid", "name"],
#       "default": "cpu"
#     },
#     "limit": {
#       "type": "number",
#       "description": "Maximum number of processes to return",
#       "default": 10
#     }
#   }
# }
# End Schema

# Parse arguments from the args file
ARGS_FILE="$1"
FILTER=$(jq -r '.filter // ""' "$ARGS_FILE")
SORT_BY=$(jq -r '.sort // "cpu"' "$ARGS_FILE")
LIMIT=$(jq -r '.limit // 10' "$ARGS_FILE")

# Ensure limit is a number
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  LIMIT=10
fi

# Collect process information depending on sort order
case "$SORT_BY" in
  "cpu")
    # Sort by CPU usage (highest first)
    if [ -n "$FILTER" ]; then
      PROCESSES=$(ps aux | grep -v "^USER" | grep -i "$FILTER" | sort -rk3 | head -n "$LIMIT")
    else
      PROCESSES=$(ps aux | grep -v "^USER" | sort -rk3 | head -n "$LIMIT")
    fi
    SORT_FIELD="cpu_percent"
    ;;
  "memory")
    # Sort by memory usage (highest first)
    if [ -n "$FILTER" ]; then
      PROCESSES=$(ps aux | grep -v "^USER" | grep -i "$FILTER" | sort -rk4 | head -n "$LIMIT")
    else
      PROCESSES=$(ps aux | grep -v "^USER" | sort -rk4 | head -n "$LIMIT")
    fi
    SORT_FIELD="memory_percent"
    ;;
  "pid")
    # Sort by PID (highest first)
    if [ -n "$FILTER" ]; then
      PROCESSES=$(ps aux | grep -v "^USER" | grep -i "$FILTER" | sort -rk2 | head -n "$LIMIT")
    else
      PROCESSES=$(ps aux | grep -v "^USER" | sort -rk2 | head -n "$LIMIT")
    fi
    SORT_FIELD="pid"
    ;;
  "name")
    # Sort by process name (alphabetically)
    if [ -n "$FILTER" ]; then
      PROCESSES=$(ps aux | grep -v "^USER" | grep -i "$FILTER" | sort -k11 | head -n "$LIMIT")
    else
      PROCESSES=$(ps aux | grep -v "^USER" | sort -k11 | head -n "$LIMIT")
    fi
    SORT_FIELD="command"
    ;;
  *)
    # Default sort by CPU usage
    if [ -n "$FILTER" ]; then
      PROCESSES=$(ps aux | grep -v "^USER" | grep -i "$FILTER" | sort -rk3 | head -n "$LIMIT")
    else
      PROCESSES=$(ps aux | grep -v "^USER" | sort -rk3 | head -n "$LIMIT")
    fi
    SORT_FIELD="cpu_percent"
    ;;
esac

# Convert to JSON format
PROCESS_JSON="["
first=true

while IFS= read -r line; do
  if [ -n "$line" ]; then
    # Parse ps output fields
    USER=$(echo "$line" | awk '{print $1}')
    PID=$(echo "$line" | awk '{print $2}')
    CPU=$(echo "$line" | awk '{print $3}')
    MEM=$(echo "$line" | awk '{print $4}')
    VSZ=$(echo "$line" | awk '{print $5}')
    RSS=$(echo "$line" | awk '{print $6}')
    TTY=$(echo "$line" | awk '{print $7}')
    STAT=$(echo "$line" | awk '{print $8}')
    START=$(echo "$line" | awk '{print $9}')
    TIME=$(echo "$line" | awk '{print $10}')
    COMMAND=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=$10=""; print $0}' | sed -e 's/^ *//')

    # Escape for JSON
    COMMAND=$(echo "$COMMAND" | sed 's/"/\\"/g')

    # Add comma if not first item
    if [ "$first" = true ]; then
      first=false
    else
      PROCESS_JSON="$PROCESS_JSON,"
    fi

    # Add process to JSON array
    PROCESS_JSON="$PROCESS_JSON
    {
      \"user\": \"$USER\",
      \"pid\": $PID,
      \"cpu_percent\": $CPU,
      \"memory_percent\": $MEM,
      \"vsz\": $VSZ,
      \"rss\": $RSS,
      \"tty\": \"$TTY\",
      \"status\": \"$STAT\",
      \"start_time\": \"$START\",
      \"time\": \"$TIME\",
      \"command\": \"$COMMAND\"
    }"
  fi
done <<< "$PROCESSES"

PROCESS_JSON="$PROCESS_JSON
]"

# Create the result
RESULT=$(cat <<EOF
{
  "processes": $PROCESS_JSON,
  "total_count": $(echo "$PROCESS_JSON" | grep -c "pid"),
  "sort_by": "$SORT_FIELD",
  "filter": "$FILTER",
  "explanation": "Showing top $LIMIT processes sorted by $SORT_FIELD",
  "suggestions": [
    {"tool": "process.list", "description": "List processes with different filtering"},
    {"tool": "system.info", "description": "Get system information"}
  ]
}
EOF
)

echo "$RESULT"
exit 0