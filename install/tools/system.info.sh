#!/bin/bash
# Tool: system.info - Returns basic system information
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: system, monitoring, diagnostics
#
# Args:
#   verbose: Set to true for more detailed information (boolean, default: false)
#
# Example:
#   {"tool": "system.info", "args": {"verbose": true}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "verbose": {
#       "type": "boolean",
#       "description": "Whether to include detailed system information",
#       "default": false
#     }
#   }
# }
# End Schema

# Parse arguments from the args file
ARGS_FILE="$1"
VERBOSE=$(jq -r '.verbose // false' "$ARGS_FILE")

# Collect system information
HOSTNAME=$(hostname)
OS=$(uname -s)
KERNEL=$(uname -r)
UPTIME=$(uptime | sed 's/.*up \([^,]*\).*/\1/' 2>/dev/null || echo "Unknown")

# Get CPU info conditionally based on OS
if [ -f "/proc/cpuinfo" ]; then
  CPU_INFO=$(grep "model name" /proc/cpuinfo | head -1 | sed 's/.*: //' 2>/dev/null || echo "Unknown")
  CPU_COUNT=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo 1)
elif [ "$OS" = "Darwin" ]; then
  CPU_INFO=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
  CPU_COUNT=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
else
  CPU_INFO="Unknown"
  CPU_COUNT=1
fi

# Get memory info conditionally
if command -v free &> /dev/null; then
  MEM_TOTAL=$(free -h | grep Mem | awk '{print $2}' 2>/dev/null || echo "Unknown")
  MEM_USED=$(free -h | grep Mem | awk '{print $3}' 2>/dev/null || echo "Unknown")
elif [ "$OS" = "Darwin" ]; then
  MEM_TOTAL=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.2f GB", $1/1024/1024/1024}' || echo "Unknown")
  MEM_USED="N/A on macOS"
else
  MEM_TOTAL="Unknown"
  MEM_USED="Unknown"
fi

# Create the basic result
RESULT=$(cat <<EOF
{
  "hostname": "$HOSTNAME",
  "os": "$OS",
  "kernel": "$KERNEL",
  "uptime": "$UPTIME",
  "cpu": {
    "model": "$CPU_INFO",
    "count": $CPU_COUNT
  },
  "memory": {
    "total": "$MEM_TOTAL",
    "used": "$MEM_USED"
  }
}
EOF
)

# If verbose, add more information
if [ "$VERBOSE" = "true" ]; then
  # Get disk info based on OS
  if [ "$OS" = "Darwin" ]; then
    DISK_INFO=$(df -h | grep "/dev/" | awk '{print $1 " " $2 " " $3 " " $5}' | jq -R -s -c 'split("\n") | map(select(length > 0) | split(" ") | {device: .[0], total: .[1], used: .[2], usage: .[3]})' 2>/dev/null || echo "[]")
  else
    DISK_INFO=$(df -h | grep '^/dev' | awk '{print $1 " " $2 " " $3 " " $5}' | jq -R -s -c 'split("\n") | map(select(length > 0) | split(" ") | {device: .[0], total: .[1], used: .[2], usage: .[3]})' 2>/dev/null || echo "[]")
  fi
  
  # Get load average
  if [ -f "/proc/loadavg" ]; then
    LOAD_AVG=$(cat /proc/loadavg | awk '{print $1, $2, $3}' 2>/dev/null || echo "Unknown")
  elif [ "$OS" = "Darwin" ]; then
    LOAD_AVG=$(sysctl -n vm.loadavg | sed 's/{ \(.*\) }/\1/' 2>/dev/null || echo "Unknown")
  else
    LOAD_AVG="Unknown"
  fi
  
  # Get IP address
  if command -v hostname &> /dev/null && hostname -I &> /dev/null; then
    IP_ADDR=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "Unknown")
  elif command -v ifconfig &> /dev/null; then
    IP_ADDR=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1 2>/dev/null || echo "Unknown")
  else
    IP_ADDR="Unknown"
  fi
  
  # Add the additional information to the result
  RESULT=$(echo "$RESULT" | jq --arg load "$LOAD_AVG" --arg ip "$IP_ADDR" \
    '. + {"load_average": $load, "ip_address": $ip, "disk": '"$DISK_INFO"'}')
fi

# Add suggestions for follow-up commands
SUGGESTIONS='[
  {"tool": "system.health", "description": "Check system health status"},
  {"tool": "process.list", "description": "List running processes"},
  {"tool": "file.list", "description": "List files in a directory"}
]'

# Add explanation based on the data
EXPLANATION="This system ($HOSTNAME) is running $OS kernel $KERNEL with $CPU_COUNT CPU cores and $MEM_TOTAL of memory."

# Add them to the result
RESULT=$(echo "$RESULT" | jq --arg explanation "$EXPLANATION" \
  '. + {"explanation": $explanation, "suggestions": '"$SUGGESTIONS"'}')

echo "$RESULT"
exit 0