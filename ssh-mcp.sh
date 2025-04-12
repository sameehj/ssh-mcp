#!/bin/bash
# ssh-mcp: Smart client for Machine Chat Protocol over SSH
# Version: 0.2.0

SSH_CONFIG="$HOME/.ssh/config"
INTERACTIVE=true

# Function to show help
show_help() {
    echo "Usage: ssh-mcp [OPTIONS] COMMAND [ARGS]"
    echo ""
    echo "Options:"
    echo "  --server HOST      Specify remote server (user@host)"
    echo "  --key PATH         SSH private key path"
    echo "  --non-interactive  Disable interactive host selection"
    echo ""
    echo "Commands:"
    echo "  --list              List available tools"
    echo "  --describe TOOL     Show tool description"
    echo "  TOOL [JSON_ARGS]    Execute tool with arguments"
    echo ""
    echo "Hosts are read from ~/.ssh/config"
    exit 1
}

# Function to list and select hosts from SSH config
select_host() {
    if [ ! -f "$SSH_CONFIG" ]; then
        echo "No SSH config file found at ~/.ssh/config"
        exit 1
    fi

    # Get hosts from SSH config (excluding wildcards and patterns)
    HOSTS=$(grep -i "^Host " "$SSH_CONFIG" | grep -v "[*?]" | awk '{print $2}' | sort)
    
    if [ -z "$HOSTS" ]; then
        echo "No hosts found in SSH config."
        exit 1
    fi

    echo "Available hosts from SSH config:"
    echo "------------------------------"
    i=1
    while IFS= read -r host; do
        # Get user if specified in config
        USER=$(awk "/^Host $host\$/,/^$/ {if (\$1 == \"User\") print \$2}" "$SSH_CONFIG")
        # Get identity file if specified
        IDENTITY=$(awk "/^Host $host\$/,/^$/ {if (\$1 == \"IdentityFile\") print \$2}" "$SSH_CONFIG")
        
        if [ -n "$USER" ]; then
            echo "$i) $host ($USER)"
        else
            echo "$i) $host"
        fi
        i=$((i+1))
    done <<< "$HOSTS"
    echo "q) Quit"
    echo ""
    
    read -p "Select host (1-n): " choice
    
    if [[ $choice == "q" ]]; then
        exit 0
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$((i-1))" ]; then
        echo "Invalid selection"
        exit 1
    fi
    
    # Get selected host
    SELECTED_HOST=$(echo "$HOSTS" | sed -n "${choice}p")
    
    # Get configuration for selected host
    USER=$(awk "/^Host $SELECTED_HOST\$/,/^$/ {if (\$1 == \"User\") print \$2}" "$SSH_CONFIG")
    IDENTITY=$(awk "/^Host $SELECTED_HOST\$/,/^$/ {if (\$1 == \"IdentityFile\") print \$2}" "$SSH_CONFIG")
    
    # Expand ~ in identity file path
    IDENTITY="${IDENTITY/#\~/$HOME}"
    
    if [ -n "$USER" ]; then
        REMOTE_SERVER="$USER@$SELECTED_HOST"
    else
        REMOTE_SERVER="$SELECTED_HOST"
    fi
    
    if [ -n "$IDENTITY" ]; then
        SSH_KEY="$IDENTITY"
    fi
    
    REMOTE_PATH="~/.ssh-mcp"
}

# Check for help first
case "$1" in
    --help|-h)
        show_help
        ;;
esac

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            REMOTE_SERVER="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --key)
            SSH_KEY="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        *)
            break
            ;;
    esac
done

# If in interactive mode and no server specified, show host selection
if [ "$INTERACTIVE" = true ] && [ -z "$REMOTE_SERVER" ]; then
    select_host
fi

# Validate required parameters
if [ -z "$REMOTE_SERVER" ]; then
    echo "Error: Remote server not specified"
    echo "Use --server option or select a host from SSH config"
    exit 1
fi

# Build SSH command
SSH_CMD="ssh"
if [ -n "$SSH_KEY" ]; then
    SSH_CMD="ssh -i $SSH_KEY"
fi

# Function to execute remote command
remote_exec() {
    # First check if jq is available
    if ! $SSH_CMD "$REMOTE_SERVER" "command -v jq >/dev/null 2>&1"; then
        echo "Warning: jq not found on remote host. Using alternative JSON processing..."
        # Use grep and sed for basic JSON processing
        $SSH_CMD "$REMOTE_SERVER" "cd $REMOTE_PATH && $1" | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'
    else
        $SSH_CMD "$REMOTE_SERVER" "cd $REMOTE_PATH && $1"
    fi
}

# Handle commands
case "$1" in
    --list)
        remote_exec "./mcp.sh --list"
        exit $?
        ;;
    --describe)
        if [ -z "$2" ]; then
            echo "Usage: ssh-mcp --describe TOOL"
            exit 1
        fi
        remote_exec "./mcp.sh --describe $2"
        exit $?
        ;;
    "")
        echo "Error: No command specified"
        echo "Try 'ssh-mcp --help' for usage information"
        exit 1
        ;;
    *)
        # Tool execution with arguments
        TOOL="$1"
        ARGS="${2:-{}}"
        echo "$ARGS" | remote_exec "./mcp.sh $TOOL"
        exit $?
        ;;
esac