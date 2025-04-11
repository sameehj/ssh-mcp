# ssh-mcp: Simple, Secure, Structured AI Tool Execution over SSH

![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)
![Status: Pre-release](https://img.shields.io/badge/status-pre--release-orange)
![AI-Ready](https://img.shields.io/badge/AI-ready-blue)

`ssh-mcp` is a **simple, secure, and structured** CLI tool that enables AI agents and developers to execute JSON-based commands over SSH using the Machine Chat Protocol (MCP).

**The missing bridge between AI and ops.**

It acts as a bridge between AI systems (like Claude, LLaMA, GPT) and real-world system operations, allowing tools, prompts, and resource-based interactions through a structured protocol.

<details>
<summary>📚 Table of Contents</summary>

- [Current Status](#-current-status)
- [The Problem](#-the-problem)
- [The Solution](#-the-solution)
- [Key Benefits](#-key-benefits)
- [Who Should Use This](#-who-should-use-this)
- [Use Cases](#-use-cases)
- [Comparison to Alternatives](#-comparison-to-alternatives)
- [Protocol Design](#-protocol-design)
- [Quick Start](#-quick-start)
- [Prerequisites](#-prerequisites)
- [Features](#-features)
- [Tool Categories](#-tool-categories)
- [AI Integration Example](#-ai-integration-example-python)
- [Chat / REPL Support](#-chat--repl-support)
- [Roadmap](#-roadmap)
- [License](#-license)
- [Architecture Diagram](#-architecture-diagram)
- [References & Related Projects](#-references--related-projects)
- [Get Involved](#-get-involved)

</details>

---

## 📌 Current Status

> **🚧 Under active development** – MVP Bash implementation available. Go version and package manager support coming soon.

---

## ❓ The Problem

SSH works great for people. But for AI agents and automated devtools?

- There's no structure — just raw text output
- No arguments, schemas, or results
- No streaming, prompting, or metadata

**Result:** AI agents can't reliably automate remote tasks. Devtools can't reason with responses. And humans must glue everything together.

---

## ✅ The Solution

**`ssh-mcp` makes SSH structured, predictable, and AI-friendly.**

- Wrap any remote tool as a JSON-based callable
- Interact with remote machines using structured requests
- Return consistent results with explanations and suggestions
- Secure-by-default using existing SSH keys

---

## ✨ Key Benefits

| Feature            | Description                                   |
| ------------------ | --------------------------------------------- |
| ✅ **Simple**       | One binary or bash script, zero dependencies  |
| 🔐 **Secure**      | Uses existing SSH auth (no daemon, no socket) |
| 📦 **Structured**  | MCP protocol for inputs, outputs, context     |
| 🤖 **AI-Ready**    | Built for agents, LLMs, auto-devtools         |
| ⚙️ **Extensible**  | Add your own tools, prompts, resources        |

---

## 👥 Who Should Use This

If you're building:

- AI tools that talk to real infrastructure
- Developer copilots that touch live servers
- Secure automations that need structured control

...then `ssh-mcp` helps you move fast *without sacrificing control or safety.*

---

## 💡 Use Cases

- 💻 Developers: Structured command execution over SSH
- 🤖 AI Agents (Claude, GPT, LLaMA): Natural language → structured tool invocation
- 🛠️ Automation: Run predefined tools, long-running ops, and observability
- 👨‍💻 Replit / Cursor / AutoGPT: Drop-in remote tool layer

---

## ⚖️ Comparison to Alternatives

| Feature           | Raw SSH | REST APIs | ssh-mcp |
| ----------------- | ------- | --------- | ------- |
| Structured Output | ❌       | ✅         | ✅       |
| Schema-based Args | ❌       | ✅         | ✅       |
| Streaming Support | ❌       | Limited   | ✅       |
| Requires Daemon   | ❌       | Usually   | ❌       |
| Secure by SSH     | ✅       | ❌         | ✅       |
| AI Prompt Support | ❌       | ❌         | ✅       |

---

## ⚙️ Protocol Design

### Request Format

```json
{
  "tool": "string",
  "args": {
    "property1": "value1"
  },
  "conversation_id": "uuid",
  "context": {
    "user_intent": "string",
    "reasoning": "string"
  }
}
```

### Response Format

```json
{
  "conversation_id": "uuid",
  "status": { "code": 0, "message": "Success" },
  "result": { "property1": "value1" },
  "explanation": "string",
  "suggestions": [
    { "tool": "string", "description": "string" }
  ],
  "error": {
    "code": "string",
    "message": "string",
    "details": {}
  }
}
```

---

## ⚡ Quick Start

```bash
# 1. Install (planned)
curl -s https://mcp.sh/install | bash

# 2. Run a tool
echo '{"tool":"system.info"}' | ssh-mcp user@host
```

> Note: The `mcp.sh` installer and domain are under development. You can clone the repo and run directly from `./mcp.sh`.

---

## 🔐 Prerequisites

- SSH access to the target system
- Bash and `jq` installed on remote machine
- Key-based auth recommended

---

## 🚀 Features

- Full MCP Protocol support
- Tools, prompts, and resource handling
- Conversation tracking and AI context embedding
- Structured error handling, suggestions, explanations
- Shell completions, self-discovery, tool schemas

---

## 📊 Tool Categories

### Meta Tools

- `meta.discover`: List tools
- `meta.describe`: Tool descriptions
- `meta.schema`: Tool input schema

### System Tools

- `system.info`: OS, CPU, memory
- `system.health`: Disk, load, uptime

### File Tools

- `file.read`, `file.write`, `file.list`, `file.find`

### Process Tools

- `process.list`, `process.info`

### Network Tools

- `network.status`, `network.route`

### Resources

- `resource.get`, `resource.list`, `resource.create`

### Long-Running

- `longRunning.backup`, `longRunning.scan`, `longRunning.download`

---

## 🤖 AI Integration Example (Python)

```python
import json, subprocess, uuid

class McpClient:
    def __init__(self, server):
        self.server = server
        self.conversation_id = str(uuid.uuid4())

    def execute_tool(self, tool_name, args=None, user_intent=None):
        payload = {
            "tool": tool_name,
            "args": args or {},
            "conversation_id": self.conversation_id,
        }
        if user_intent:
            payload["context"] = {"user_intent": user_intent}

        result = subprocess.run([
            "ssh", self.server, "./mcp.sh"
        ], input=json.dumps(payload).encode(), stdout=subprocess.PIPE)
        return json.loads(result.stdout)
```

---

## 💬 Chat / REPL Support

Use `ssh-mcp` in conversational loops or LLaMA-based shells:

```bash
while true; do
  echo -n "mcp > "
  read CMD
  echo $CMD | ssh-mcp user@host
done
```

Pair this with a local LLM (e.g. LLaMA) to enable:

> "Check CPU usage" → `{ "tool": "system.monitor" }`

---

## 🔮 Roadmap

- ✅ Bash-based MVP (`mcp.sh`)
- 🚧 Go binary version (`ssh-mcp`)
- 🚧 Streaming support for long-running tools
- 🚧 Resource references: inline or URI-based
- 🚧 Prompt + tool hybrid execution
- 🚧 Plugin architecture for third-party tools
- 🚧 Package manager support (`brew`, `apt`, `scoop`)
- 🚧 Shell completions and `--discover`/`--describe`
- 🚧 Integration with Claude, Cursor, Replit AI agents

---

## 🪧 License

MIT License — see `LICENSE` file for details.

---

## 🎯 Architecture Diagram

<svg viewBox="0 0 800 400" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <rect width="800" height="400" fill="#f8f9fa" rx="10" ry="10"/>
  
  <!-- Title -->
  <text x="400" y="30" font-family="Arial, sans-serif" font-size="20" text-anchor="middle" font-weight="bold">SSH-MCP Architecture</text>
  
  <!-- AI Systems Section -->
  <rect x="50" y="70" width="200" height="260" fill="#e6f7ff" stroke="#1890ff" stroke-width="2" rx="10" ry="10"/>
  <text x="150" y="95" font-family="Arial, sans-serif" font-size="16" text-anchor="middle" font-weight="bold">AI Systems</text>
  
  <!-- AI Components -->
  <rect x="75" y="115" width="150" height="40" fill="#91d5ff" stroke="#1890ff" stroke-width="1" rx="5" ry="5"/>
  <text x="150" y="140" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">Claude</text>
  
  <rect x="75" y="165" width="150" height="40" fill="#91d5ff" stroke="#1890ff" stroke-width="1" rx="5" ry="5"/>
  <text x="150" y="190" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">GPT</text>
  
  <rect x="75" y="215" width="150" height="40" fill="#91d5ff" stroke="#1890ff" stroke-width="1" rx="5" ry="5"/>
  <text x="150" y="240" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">LLaMA</text>
  
  <rect x="75" y="265" width="150" height="40" fill="#91d5ff" stroke="#1890ff" stroke-width="1" rx="5" ry="5"/>
  <text x="150" y="290" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">Automation Tools</text>
  
  <!-- SSH-MCP Section -->
  <rect x="300" y="70" width="200" height="260" fill="#f6ffed" stroke="#52c41a" stroke-width="2" rx="10" ry="10"/>
  <text x="400" y="95" font-family="Arial, sans-serif" font-size="16" text-anchor="middle" font-weight="bold">SSH-MCP</text>
  
  <!-- SSH-MCP Components -->
  <rect x="325" y="125" width="150" height="50" fill="#b7eb8f" stroke="#52c41a" stroke-width="1" rx="5" ry="5"/>
  <text x="400" y="145" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">MCP Protocol</text>
  <text x="400" y="165" font-family="Arial, sans-serif" font-size="12" text-anchor="middle">JSON Structure</text>
  
  <rect x="325" y="185" width="150" height="50" fill="#b7eb8f" stroke="#52c41a" stroke-width="1" rx="5" ry="5"/>
  <text x="400" y="205" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">SSH Transport</text>
  <text x="400" y="225" font-family="Arial, sans-serif" font-size="12" text-anchor="middle">Security Layer</text>
  
  <rect x="325" y="245" width="150" height="50" fill="#b7eb8f" stroke="#52c41a" stroke-width="1" rx="5" ry="5"/>
  <text x="400" y="265" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">Tool Registry</text>
  <text x="400" y="285" font-family="Arial, sans-serif" font-size="12" text-anchor="middle">Discovery & Schemas</text>
  
  <!-- Remote Systems Section -->
  <rect x="550" y="70" width="200" height="260" fill="#fff2e8" stroke="#fa8c16" stroke-width="2" rx="10" ry="10"/>
  <text x="650" y="95" font-family="Arial, sans-serif" font-size="16" text-anchor="middle" font-weight="bold">Remote Systems</text>
  
  <!-- Remote Components -->
  <rect x="575" y="125" width="150" height="40" fill="#ffd591" stroke="#fa8c16" stroke-width="1" rx="5" ry="5"/>
  <text x="650" y="150" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">System Tools</text>
  
  <rect x="575" y="175" width="150" height="40" fill="#ffd591" stroke="#fa8c16" stroke-width="1" rx="5" ry="5"/>
  <text x="650" y="200" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">File Operations</text>
  
  <rect x="575" y="225" width="150" height="40" fill="#ffd591" stroke="#fa8c16" stroke-width="1" rx="5" ry="5"/>
  <text x="650" y="250" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">Process Management</text>
  
  <rect x="575" y="275" width="150" height="40" fill="#ffd591" stroke="#fa8c16" stroke-width="1" rx="5" ry="5"/>
  <text x="650" y="300" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">Network Operations</text>
  
  <!-- Arrows -->
  <!-- AI to SSH-MCP -->
  <path d="M 255 150 L 295 150" stroke="#1890ff" stroke-width="2" fill="none" marker-end="url(#arrowhead)"/>
  <text x="275" y="140" font-family="Arial, sans-serif" font-size="10" text-anchor="middle">Request</text>
  
  <!-- SSH-MCP to AI -->
  <path d="M 295 170 L 255 170" stroke="#52c41a" stroke-width="2" fill="none" marker-end="url(#arrowhead)"/>
  <text x="275" y="185" font-family="Arial, sans-serif" font-size="10" text-anchor="middle">Response</text>
  
  <!-- SSH-MCP to Remote -->
  <path d="M 505 150 L 545 150" stroke="#52c41a" stroke-width="2" fill="none" marker-end="url(#arrowhead)"/>
  <text x="525" y="140" font-family="Arial, sans-serif" font-size="10" text-anchor="middle">Execute</text>
  
  <!-- Remote to SSH-MCP -->
  <path d="M 545 170 L 505 170" stroke="#fa8c16" stroke-width="2" fill="none" marker-end="url(#arrowhead)"/>
  <text x="525" y="185" font-family="Arial, sans-serif" font-size="10" text-anchor="middle">Results</text>
  
  <!-- Example flow at bottom -->
  <rect x="100" y="350" width="600" height="30" fill="white" stroke="#d9d9d9" stroke-width="1" rx="5" ry="5"/>
  <text x="400" y="370" font-family="monospace" font-size="12" text-anchor="middle">AI → {"tool":"system.info"} → SSH-MCP → Remote Execution → {"result":{...}} → AI</text>
  
  <!-- Arrowhead definition -->
  <defs>
    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" />
    </marker>
  </defs>
</svg>

Architecture: LLM ↔ ssh-mcp ↔ Secure SSH ↔ Tools on Target Machine

---

## 🔎 References & Related Projects

- MCP Protocol *(early-stage spec)*
- MCP Specification *(draft)*
- ClaudeMCP *(conceptual integration)*
- [KernelFaaS (eBPF backend)](https://github.com/Kiinitix/KernelFaaS)

---

## 🎉 Get Involved

Want to contribute tools, prompts, or ideas? Want to use `ssh-mcp` with your AI shell, devtool, or infra layer?

Let's build it together. Star the repo, fork it, or open an issue.

---

### 🚀 Let's Build the AI Shell of the Future

> `ssh-mcp` is more than a CLI — it's a protocol for building intelligent, secure interfaces between humans, AI, and machines.

- ⭐ Star the repo
- 🛠️ Contribute a tool or prompt
- 💬 Tell us what you're building

This is the terminal AI deserves.