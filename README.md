# MCP Server Deploy

Fully automatic **multi-MCP server** deployment for **any Windows installation**. Deploy Blender, filesystem, GitHub, and any other MCP servers with a single command. Works with or without winget, admin rights, or prior setup.

## One-Liner Install

Open PowerShell and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/codingmachineedge/blender-mcp-deploy/main/bootstrap.ps1 | iex
```

That's it. Everything is installed and configured automatically.

## Quick Start

```powershell
# Clone the repo
git clone https://github.com/codingmachineedge/blender-mcp-deploy.git
cd blender-mcp-deploy

# Add servers you want
.\add-server.ps1 -Name "blender" -PipPackage "blender-mcp" -Description "Blender 3D" -RequiresBlender
.\add-server.ps1 -Name "github" -NpxCommand "@modelcontextprotocol/server-github" -Description "GitHub API"
.\add-server.ps1 -Name "filesystem" -NpxCommand "@modelcontextprotocol/server-filesystem" -Description "File access"

# Deploy everything
.\setup.ps1
```

## Managing Servers

```powershell
# Add a Python-based server
.\add-server.ps1 -Name "myserver" -PipPackage "my-mcp-server" -Description "My custom server"

# Add an npm/npx-based server
.\add-server.ps1 -Name "github" -NpxCommand "@modelcontextprotocol/server-github" -Description "GitHub API"

# Add a custom command server
.\add-server.ps1 -Name "custom" -Command "node" -Args "server.js" -Description "Custom server"

# List configured servers
.\list-servers.ps1

# Remove a server
.\remove-server.ps1 -Name "myserver"

# Deploy all enabled servers
.\setup.ps1
```

## What It Does

1. **Auto-elevates to admin** if needed (prompts UAC)
2. **Detects or installs Blender** - checks PATH, registry, common locations; falls back to direct download
3. **Detects or installs Python 3.12** - same detection chain, direct download fallback
4. **Creates a Python venv** and installs all Python-based MCP servers
5. **Installs Blender addons** automatically for Blender-dependent servers
6. **Sets up WSL components** if WSL is available
7. **Configures all AI agents** - writes MCP configs for OpenCode, Claude Code, and Codex (both project-local and global)

## Options

```powershell
.\setup.ps1 -SkipWsl                    # Skip WSL setup
.\setup.ps1 -SkipBlenderInstall         # Skip Blender install
.\setup.ps1 -SkipPythonInstall          # Skip Python install
.\setup.ps1 -Portable                   # Install everything locally (no system-wide changes)
```

## Server Config (servers.json)

Servers are defined in `servers.json`:

```json
{
  "servers": [
    {
      "name": "blender",
      "description": "Blender MCP server for 3D scene manipulation",
      "type": "python",
      "pip_package": "blender-mcp",
      "version": "",
      "command": "python",
      "args": ["-m", "blender_mcp"],
      "env": {},
      "requires_blender": true,
      "blender_addon_script": "install-addon.py",
      "enabled": true
    },
    {
      "name": "github",
      "description": "GitHub API access",
      "type": "node",
      "pip_package": "",
      "version": "",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {},
      "requires_blender": false,
      "blender_addon_script": "",
      "enabled": true
    }
  ],
  "defaults": {
    "install_dir": "",
    "venv_path": "",
    "portable": false
  }
}
```

## After Install

1. Launch your AI agent (**OpenCode** / **Claude** / **Codex**)
2. The MCP tools will be available automatically
3. For Blender servers, open Blender first

## Manual MCP Server Start

```powershell
.\scripts\start-mcp-server.ps1             # Windows (Blender)
wsl bash scripts/start-mcp-server-wsl.sh   # WSL
```

## Agent Configs Written

| Agent    | Project Config     | Global Config                              |
|----------|--------------------|--------------------------------------------|
| OpenCode | `opencode.json`    | `~/.config/opencode/opencode.json`         |
| Claude   | `.mcp.json`        | `~/.claude/claude_desktop_config.json`     |
| Codex    | `AGENTS.md`        | `~/.codex/config.json`                     |

## Requirements

- Windows 10/11
- PowerShell 5.1+ (included with Windows)
- Internet connection (for first-time downloads)
- No admin rights required (installs to user directories)
- No winget required (direct download fallbacks included)

## Batch Files

For cmd.exe or double-click execution:

- `setup.bat` - Run deployment
- `bootstrap.bat` - One-click install from GitHub
- `add-server.bat` - Add a new server
- `remove-server.bat` - Remove a server
- `list-servers.bat` - List configured servers

## Troubleshooting

**"Blender/Python not found after install"** - Restart your terminal and re-run. PATH changes need a new session.

**Permission denied** - Use `-Portable` flag to install entirely under `%LOCALAPPDATA%`.

**WSL not available** - That's fine, WSL is optional. The Windows MCP server works independently.

**Server not working** - Run `.\list-servers.ps1` to check if it's enabled, then re-run `.\setup.ps1`.
