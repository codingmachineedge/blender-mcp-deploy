# Blender MCP Deploy

Fully automatic Blender MCP server deployment for **any Windows installation**. Works with or without winget, admin rights, or prior setup.

## One-Liner Install

Open PowerShell and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/codingmachineedge/blender-mcp-deploy/main/bootstrap.ps1 | iex
```

That's it. Everything is installed and configured automatically.

## What It Does

1. **Detects or installs Blender** - checks PATH, registry, common locations; falls back to direct download if winget unavailable
2. **Detects or installs Python 3.12** - same detection chain, direct download fallback
3. **Creates a Python venv** and installs `blender-mcp`
4. **Installs the Blender addon** automatically via Blender's Python API
5. **Sets up WSL components** if WSL is available
6. **Configures all AI agents** - writes MCP configs for OpenCode, Claude Code, and Codex (both project-local and global)

## Manual Install

```powershell
git clone https://github.com/codingmachineedge/blender-mcp-deploy.git
cd blender-mcp-deploy
.\setup.ps1
```

## Options

```powershell
.\setup.ps1 -SkipWsl                    # Skip WSL setup
.\setup.ps1 -SkipBlenderInstall         # Skip Blender install
.\setup.ps1 -SkipPythonInstall          # Skip Python install
.\setup.ps1 -Portable                   # Install everything locally (no system-wide changes)
.\setup.ps1 -BlenderMcpVersion "0.5.0"  # Pin a specific blender-mcp version
```

## After Install

1. Open **Blender** - the MCP addon starts automatically
2. Launch your AI agent (**OpenCode** / **Claude** / **Codex**)
3. The `blender` MCP tools are available automatically

## Manual MCP Server Start

```powershell
.\scripts\start-mcp-server.ps1             # Windows
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

## How Detection Works

The installer checks for Blender and Python in this order:
1. System PATH
2. Windows Registry (uninstall entries, Python install paths)
3. Common install locations (Program Files, LocalAppData, etc.)
4. If not found: winget -> direct download -> error with manual install link

## Troubleshooting

**"Blender/Python not found after install"** - Restart your terminal and re-run. PATH changes need a new session.

**Permission denied** - Use `-Portable` flag to install entirely under `%LOCALAPPDATA%`.

**WSL not available** - That's fine, WSL is optional. The Windows MCP server works independently.
