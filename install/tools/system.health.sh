#!/bin/bash
# Tool: system.health - Check system health status
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: system, monitoring, health, diagnostics
# Requires sudo: false
#
# Args:
#   check: Specific check to perform (string, default: "all", options: "all", "cpu", "memory", "disk", "load")
#   threshold: Warning threshold percentage (number, default: 80)
#
# Example:
#   {"tool": "system.health", "args": {"check": "disk", "threshold": 90}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "check": {
#       "type": "string",
#       "description": "Specific health check to perform",
#       "enum": ["all", "cpu", "memory", "disk", "load"],
#       "default": "all"
#     },
#     "threshold": {
#       "type": "number",
#       "description": "Warning threshold percentage",
#       "default": 80
#     }
#   }
# }
# End Schema

# Parse arguments from the args file
ARGS_FILE="$1"
CHECK=$(jq -r '.check // "all"' "$ARGS_FILE")
THRESHOLD=$(jq -r '.threshold // 80' "$ARGS_FILE")

# Ensure threshold is a number
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
  THRESHOLD=80
fi

# Initialize health status
STATUS="healthy"
ISSUES=[]
DETAILS="{}"

# Check CPU usage
check_cpu() {
  # Get current CPU usage using top (snapshot)
  if command -v mpstat &> /dev/null; then
    # Use mpstat if available
    CPU_USAGE=$(mpstat 1 1 | awk '/Average:/ {print 100 - $NF}' | sed 's/,/./')
  else
    # Fallback to top
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/,/./')
  fi

  # Ensure CPU_USAGE is a number
  if ! [[ "$CPU_USAGE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    CPU_USAGE=0
  fi

  # Check if CPU usage is above threshold
  CPU_STATUS="healthy"
  if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l) )); then
    CPU_STATUS="warning"
    STATUS="warning"
    ISSUES=$(echo "$ISSUES" | jq -c ". + [\"CPU usage is high: ${CPU_USAGE}%\"]")
  fi

  # Add CPU details
  DETAILS=$(echo "$DETAILS" | jq --arg usage "$CPU_USAGE" --arg status "$CPU_STATUS" \
    '. + {"cpu": {"usage_percent": ($usage | tonumber), "status": $status}}')
}

# Check memory usage
check_memory() {
  # Get memory usage
  if command -v free &> /dev/null; then
    MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
    MEM_USED=$(free | grep Mem | awk '{print $3}')
    if [[ "$MEM_TOTAL" =~ ^[0-9]+$ ]] && [[ "$MEM_USED" =~ ^[0-9]+$ ]] && [ "$MEM_TOTAL" -gt 0 ]; then
      MEM_USAGE=$(echo "scale=2; ($MEM_USED / $MEM_TOTAL) * 100" | bc)
    else
      MEM_USAGE=0
    fi
  else
    # Fallback for systems without free command
    MEM_USAGE=0
  fi

  # Check if memory usage is above threshold
  MEM_STATUS="healthy"
  if (( $(echo "$MEM_USAGE > $THRESHOLD" | bc -l) )); then
    MEM_STATUS="warning"
    STATUS="warning"
    ISSUES=$(echo "$ISSUES" | jq -c ". + [\"Memory usage is high: ${MEM_USAGE}%\"]")
  fi

  # Add memory details
  DETAILS=$(echo "$DETAILS" | jq --arg usage "$MEM_USAGE" --arg status "$MEM_STATUS" \
    '. + {"memory": {"usage_percent": ($usage | tonumber), "status": $status}}')
}

# Check disk usage
check_disk() {
  # Get disk usage for root filesystem
  ROOT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

  # Check if disk usage is above threshold
  DISK_STATUS="healthy"
  if [ "$ROOT_USAGE" -gt "$THRESHOLD" ]; then
    DISK_STATUS="warning"
    STATUS="warning"
    ISSUES=$(echo "$ISSUES" | jq -c ". + [\"Disk usage is high: ${ROOT_USAGE}%\"]")
  fi

  # Add disk details
  DETAILS=$(echo "$DETAILS" | jq --arg usage "$ROOT_USAGE" --arg status "$DISK_STATUS" \
    '. + {"disk": {"usage_percent": ($usage | tonumber), "status": $status}}')
}

# Check system load
check_load() {
  # Get current load average
  LOAD=$(uptime | awk -F'[a-z]:' '{ print $2}' | awk -F', ' '{ print $1}' | tr -d ' ')
  
  # Get number of cores
  NUM_CORES=$(grep -c "processor" /proc/cpuinfo)
  if [ "$NUM_CORES" -lt 1 ]; then
    NUM_CORES=1
  fi
  
  # Calculate load per core
  LOAD_PER_CORE=$(echo "scale=2; $LOAD / $NUM_CORES" | bc)
  
  # Convert to percentage (1.0 load per core = 100%)
  LOAD_PERCENT=$(echo "scale=0; $LOAD_PER_CORE * 100" | bc)
  
  # Check if load is above threshold
  LOAD_STATUS="healthy"
  if [ "$LOAD_PERCENT" -gt "$THRESHOLD" ]; then
    LOAD_STATUS="warning"
    STATUS="warning"
    ISSUES=$(echo "$ISSUES" | jq -c ". + [\"System load is high: ${LOAD_PERCENT}% per core\"]")
  fi
  
  # Add load details
  DETAILS=$(echo "$DETAILS" | jq --arg load "$LOAD" --arg cores "$NUM_CORES" --arg percent "$LOAD_PERCENT" --arg status "$LOAD_STATUS" \
    '. + {"load": {"value": ($load | tonumber), "cores": ($cores | tonumber), "percent": ($percent | tonumber), "status": $status}}')
}

# Perform health checks based on requested type
case "$CHECK" in
  "cpu")
    check_cpu
    ;;
  "memory")
    check_memory
    ;;
  "disk")
    check_disk
    ;;
  "load")
    check_load
    ;;
  "all"|*)
    check_cpu
    check_memory
    check_disk
    check_load
    ;;
esac

# Generate appropriate explanation
EXPLANATION="System health check completed for $CHECK checks."
if [ "$STATUS" = "warning" ]; then
  EXPLANATION="$EXPLANATION Warning: Some health checks exceeded the $THRESHOLD% threshold."
else
  EXPLANATION="$EXPLANATION All systems operating within normal parameters."
fi

# Create the result
RESULT=$(cat <<EOF
{
  "status": "$STATUS",
  "issues": $ISSUES,
  "details": $DETAILS,
  "threshold": $THRESHOLD,
  "check_type": "$CHECK",
  "explanation": "$EXPLANATION",
  "suggestions": [
    {"tool": "system.info", "description": "Get detailed system information"},
    {"tool": "process.list", "description": "List processes consuming resources"}
  ]
}
EOF
)

echo "$RESULT"
exit 0