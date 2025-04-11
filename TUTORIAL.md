# SSH-MCP Tutorial

SSH-MCP (SSH Machine Chat Protocol) is a lightweight tool that provides a structured, JSON-based interface for securely executing commands on remote servers over SSH. This tutorial will guide you through installing, configuring, and using ssh-mcp.

## Installation

### Local Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/ssh-mcp.git
   cd ssh-mcp
   ```

2. Install locally:
   ```bash
   ./install.sh
   ```

### Remote Installation

To install ssh-mcp on a remote server:

```bash
./install.sh --remote user@hostname --key ~/.ssh/your_key.pem
```

This will:
- Create the necessary directories on the remote server
- Copy the mcp.sh script
- Install all tool scripts
- Check for dependencies (jq)

## Basic Usage

### Execute a Tool

```bash
# Basic syntax
./ssh-mcp.sh [HOST] TOOL [KEY=VALUE...]

# Examples
./ssh-mcp.sh webserver system.info verbose=true
./ssh-mcp.sh webserver file.read path=/etc/hostname

# With explicit SSH key
./ssh-mcp.sh --key ~/.ssh/aws.pem webserver system.info verbose=true
```

### Pipe JSON Directly

```bash
echo '{"tool":"system.info","args":{"verbose":true}}' | ./ssh-mcp.sh webserver
```

## Meta Tools

SSH-MCP includes several meta tools to help you discover and understand available functionality.

### meta.discover

Lists all available tools on the remote server:

```bash
./ssh-mcp.sh webserver meta.discover
```

Sample output:
```json
{
  "tools": [
    {
      "name": "meta.describe",
      "description": "Returns detailed description for a specific tool",
      "version": "0.1.0",
      "author": "ssh-mcp Team",
      "tags": ["meta", "discovery", "documentation"]
    },
    {
      "name": "system.info",
      "description": "Returns basic system information",
      "version": "0.1.0",
      "author": "ssh-mcp Team",
      "tags": ["system", "monitoring", "diagnostics"]
    },
    ...
  ],
  "count": 4,
  "explanation": "These are all the available tools on this system. You can get more details about a specific tool using meta.describe."
}
```

You can also filter tools by category:
```bash
./ssh-mcp.sh webserver meta.discover category=system
```

### meta.describe

Get detailed information about a specific tool:

```bash
./ssh-mcp.sh webserver meta.describe tool=system.info
```

Sample output:
```json
{
  "tool": "system.info",
  "description": "Returns basic system information",
  "metadata": {
    "author": "ssh-mcp Team",
    "version": "0.1.0",
    "tags": ["system", "monitoring", "diagnostics"]
  },
  "args_description": [
    "verbose: Set to true for more detailed information (boolean, default: false)"
  ],
  "examples": [
    {"tool": "system.info", "args": {"verbose": true}}
  ],
  "explanation": "This tool (system.info) is used for retrieving system information like hostname, OS details, CPU, memory and more.",
  "suggestions": [
    {"tool": "meta.schema", "description": "Get the JSON schema for this tool"},
    {"tool": "meta.discover", "description": "Discover other available tools"}
  ]
}
```

### meta.schema

Get the JSON schema for a specific tool:

```bash
./ssh-mcp.sh webserver meta.schema tool=system.info
```

Sample output:
```json
{
  "type": "object",
  "properties": {
    "verbose": {
      "type": "boolean",
      "description": "Whether to include detailed system information",
      "default": false
    }
  }
}
```

## Built-in Tools

### system.info

Returns basic system information:

```bash
./ssh-mcp.sh webserver system.info verbose=true
```

Sample output:
```json
{
  "hostname": "webserver-01",
  "os": "Linux",
  "kernel": "5.15.0-35-generic",
  "uptime": "14 days, 6:43",
  "cpu": {
    "model": "Intel(R) Xeon(R) CPU E5-2650 v4 @ 2.20GHz",
    "count": 8
  },
  "memory": {
    "total": "16G",
    "used": "8.5G"
  },
  "load_average": "0.14 0.15 0.19",
  "ip_address": "10.0.1.5",
  "disk": [
    {
      "device": "/dev/sda1",
      "total": "100G",
      "used": "45G",
      "usage": "45%"
    }
  ],
  "explanation": "This system (webserver-01) is running Linux kernel 5.15.0-35-generic with 8 CPU cores and 16G of memory."
}
```

## Managing Hosts

### List Available SSH Hosts

```bash
./ssh-mcp.sh --hosts
```

### Add a New Host to SSH Config

```bash
./ssh-mcp.sh --add-host webserver 192.168.1.10 ubuntu ~/.ssh/web-key.pem
```

## Creating Your Own Tools

Tools are simple bash scripts stored in `~/.ssh-mcp/tools/` on the remote server. Here's a simple template:

```bash
#!/bin/bash
# Tool: category.name - Short description
# Author: Your Name
# Version: 1.0.0
# Tags: tag1, tag2, tag3
#
# Args:
#   arg1: Description of first argument (type, constraints)
#
# Example:
#   {"tool": "category.name", "args": {"arg1": "value"}}

# Parse arguments
ARGS_FILE="$1"
ARG1=$(jq -r '.arg1 // "default"' "$ARGS_FILE")

# Tool implementation
RESULT=$(cat <<EOF
{
  "key1": "value1",
  "key2": "value2",
  "explanation": "Human-friendly explanation of the result"
}
EOF
)

echo "$RESULT"
exit 0
```

## Integration with Other Tools

### Python Integration

```python
import json
import subprocess

def run_ssh_mcp(host, tool, args=None):
    if args is None:
        args = {}
    
    # Build the command
    cmd_args = [tool]
    for key, value in args.items():
        cmd_args.append(f"{key}={value}")
    
    # Execute the command
    result = subprocess.run(
        ["./ssh-mcp.sh", host] + cmd_args,
        capture_output=True, text=True
    )
    
    return json.loads(result.stdout)

# Example usage
system_info = run_ssh_mcp("webserver", "system.info", {"verbose": True})
print(f"Running {system_info['os']} with {system_info['cpu']['count']} CPUs")
```

## Troubleshooting

- **Tool not found**: Ensure the tool script exists in `~/.ssh-mcp/tools/` on the remote server
- **Permission denied**: Ensure tool scripts are executable (`chmod +x`)
- **jq errors**: Ensure jq is installed on the remote server
- **Syntax errors**: Check the tool script for bash syntax errors

## Best Practices

1. **Use key-based authentication**: Avoid password prompts by setting up SSH key authentication
2. **Keep tools modular**: Each tool should do one thing well
3. **Include good documentation**: Every tool should have clear descriptions, examples, and argument documentation
4. **Return structured data**: Always return valid JSON
5. **Add useful suggestions**: Help users discover related functionality

## Advanced Features

### Session Management

SSH-MCP supports conversation tracking via the `conversation_id` parameter:

```bash
echo '{"tool":"system.info","conversation_id":"session-123"}' | ./ssh-mcp.sh webserver
```

This allows you to associate multiple commands as part of the same logical session.

### AI Integration

SSH-MCP is designed to be AI-friendly, enabling AI agents to interact with remote systems through a structured interface. The protocol supports context information that can be used by AI systems:

```bash
echo '{
  "tool": "system.info",
  "args": {"verbose": true},
  "conversation_id": "session-123",
  "context": {
    "user_intent": "The user wants to diagnose high memory usage",
    "reasoning": "System information will help identify resource constraints"
  }
}' | ./ssh-mcp.sh webserver
```

## Security Considerations

SSH-MCP inherits its security model from SSH:

1. **Authentication**: Uses SSH's key-based authentication 
2. **Encryption**: All traffic is encrypted via SSH
3. **Authorization**: Tools run with the permissions of the SSH user
4. **Audit**: All commands are logged for accountability

It's recommended to:
- Use dedicated SSH keys with appropriate restrictions
- Create separate users with limited permissions for SSH-MCP access
- Regularly review logs for suspicious activity
- Keep tools simple and focused to minimize security risks