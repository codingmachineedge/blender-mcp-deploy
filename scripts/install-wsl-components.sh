#!/usr/bin/env bash
set -euo pipefail

echo ">> Setting up WSL components for Blender MCP"

if ! command -v python3 &>/dev/null; then
    echo "   Installing Python 3..."
    sudo apt-get update -qq && sudo apt-get install -y -qq python3 python3-pip python3-venv
fi

echo "   OK: Python3 available ($(python3 --version))"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_PATH="$REPO_ROOT/.venv-wsl"

if [ ! -d "$VENV_PATH" ]; then
    python3 -m venv "$VENV_PATH"
    echo "   OK: Created WSL venv at $VENV_PATH"
fi

"$VENV_PATH/bin/pip" install --upgrade pip -q
"$VENV_PATH/bin/pip" install blender-mcp -q
echo "   OK: blender-mcp installed in WSL venv"

echo ""
echo "   WSL MCP server python: $VENV_PATH/bin/python"
echo "   Run with: $VENV_PATH/bin/python -m blender_mcp"
echo ""
echo ">> WSL setup complete"
