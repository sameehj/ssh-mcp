#!/bin/bash
# Tool: network.status - Check network interfaces and connectivity
# Author: ssh-mcp Team
# Version: 0.1.0
# Tags: network, monitoring, connectivity
# Requires sudo: false
#
# Args:
#   interface: Network interface to check (string, default: "all")
#   test_connectivity: Test internet connectivity (boolean, default: true)
#
# Example:
#   {"tool": "network.status", "args": {"interface": "eth0", "test_connectivity": true}}
#
# Schema:
# {
#   "type": "object",
#   "properties": {
#     "interface": {
#       "type": "string",
#       "description": "Network interface to check",
#       "default": "all"
#     },
#     "test_connectivity": {
#       "type": "boolean",
#       "description": "Test internet connectivity",
#       "default": true
#     }
#   }
# }
# End Schema

# Parse arguments from the args file
ARGS_FILE="$1"
INTERFACE=$(jq -r '.interface // "all"' "$ARGS_FILE")
TEST_CONNECTIVITY=$(jq -r '.test_connectivity // true' "$ARGS_FILE")

# Function to get network interfaces
get_interfaces() {
  if command -v ip &> /dev/null; then
    # Using ip command (modern)
    INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
  elif command -v ifconfig &> /dev/null; then
    # Using ifconfig (older systems)
    INTERFACES=$(ifconfig | grep -E "^[a-zA-Z0-9]+" | awk '{print $1}' | grep -v "lo" | tr -d ':')
  else
    # Fallback to listing from /sys
    INTERFACES=$(ls /sys/class/net | grep -v "lo")
  fi
  
  echo "$INTERFACES"
}

# Function to get interface details
get_interface_details() {
  local iface=$1
  local details="{}"
  
  # Get MAC address
  if command -v ip &> /dev/null; then
    MAC=$(ip link show "$iface" | grep -o "link/ether [^ ]*" | cut -d' ' -f2)
  elif command -v ifconfig &> /dev/null; then
    MAC=$(ifconfig "$iface" | grep -o -E "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" | head -1)
  else
    MAC="unknown"
  fi
  
  # Get IP address
  if command -v ip &> /dev/null; then
    IP=$(ip -o -4 addr show "$iface" | awk '{print $4}' | cut -d'/' -f1)
  elif command -v ifconfig &> /dev/null; then
    IP=$(ifconfig "$iface" | grep -o -E "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | cut -d' ' -f2)
  else
    IP="unknown"
  fi
  
  # Get interface state
  if command -v ip &> /dev/null; then
    STATE=$(ip link show "$iface" | grep -o "state [^ ]*" | cut -d' ' -f2)
  elif command -v ifconfig &> /dev/null; then
    if ifconfig "$iface" | grep -q "UP"; then
      STATE="UP"
    else
      STATE="DOWN"
    fi
  elif [ -f "/sys/class/net/$iface/operstate" ]; then
    STATE=$(cat "/sys/class/net/$iface/operstate")
  else
    STATE="unknown"
  fi
  
  # Create JSON object for interface details
  details=$(echo '{}' | jq --arg mac "$MAC" --arg ip "$IP" --arg state "$STATE" \
    '. + {"mac": $mac, "ip": $ip, "state": $state}')
  
  echo "$details"
}

# Function to test internet connectivity
test_internet_connectivity() {
  # Test connectivity to 8.8.8.8 (Google DNS)
  if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    PING_STATUS="success"
    PING_TIME=$(ping -c 1 -W 2 8.8.8.8 | grep -o "time=[0-9.]* ms" | cut -d'=' -f2)
  else
    PING_STATUS="failed"
    PING_TIME="n/a"
  fi
  
  # Test DNS resolution
  if ping -c 1 -W 2 google.com > /dev/null 2>&1; then
    DNS_STATUS="success"
  else
    DNS_STATUS="failed"
  fi
  
  # Create JSON object for connectivity details
  connectivity=$(echo '{}' | jq --arg ping "$PING_STATUS" --arg time "$PING_TIME" --arg dns "$DNS_STATUS" \
    '. + {"ping": $ping, "ping_time": $time, "dns": $dns}')
  
  echo "$connectivity"
}

# Initialize output
INTERFACES_JSON="{"
CONNECTIVITY_JSON="{}"
IS_FIRST=true

# Process all interfaces or just the specified one
if [ "$INTERFACE" = "all" ]; then
  for iface in $(get_interfaces); do
    if [ "$IS_FIRST" = true ]; then
      IS_FIRST=false
    else
      INTERFACES_JSON="$INTERFACES_JSON,"
    fi
    DETAILS=$(get_interface_details "$iface")
    INTERFACES_JSON="$INTERFACES_JSON\"$iface\": $DETAILS"
  done
else
  # Check if interface exists
  if ifconfig "$INTERFACE" &> /dev/null || ip link show "$INTERFACE" &> /dev/null; then
    DETAILS=$(get_interface_details "$INTERFACE")
    INTERFACES_JSON="$INTERFACES_JSON\"$INTERFACE\": $DETAILS"
  else
    INTERFACES_JSON="$INTERFACES_JSON\"error\": \"Interface $INTERFACE not found\""
  fi
fi
INTERFACES_JSON="$INTERFACES_JSON}"

# Test connectivity if requested
if [ "$TEST_CONNECTIVITY" = "true" ]; then
  CONNECTIVITY_JSON=$(test_internet_connectivity)
fi

# Determine overall status
STATUS="online"
if echo "$INTERFACES_JSON" | grep -q "DOWN"; then
  STATUS="degraded"
fi
if [ "$TEST_CONNECTIVITY" = "true" ] && echo "$CONNECTIVITY_JSON" | grep -q "failed"; then
  STATUS="limited connectivity"
fi

# Generate an explanation
EXPLANATION="Network status check complete. "
if [ "$INTERFACE" = "all" ]; then
  EXPLANATION="${EXPLANATION}Scanned all interfaces."
else
  EXPLANATION="${EXPLANATION}Checked interface $INTERFACE."
fi

if [ "$TEST_CONNECTIVITY" = "true" ]; then
  EXPLANATION="${EXPLANATION} Internet connectivity is $(echo "$CONNECTIVITY_JSON" | jq -r '.ping')."
fi

# Create the result
RESULT=$(cat <<EOF
{
  "status": "$STATUS",
  "interfaces": $INTERFACES_JSON,
  "connectivity": $CONNECTIVITY_JSON,
  "explanation": "$EXPLANATION",
  "suggestions": [
    {"tool": "system.info", "description": "Get system information"},
    {"tool": "network.status", "description": "Check a specific interface"}
  ]
}
EOF
)

echo "$RESULT"
exit 0