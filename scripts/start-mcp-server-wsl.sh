#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_PYTHON="$REPO_ROOT/.venv-wsl/bin/python"

if [ ! -x "$VENV_PYTHON" ]; then
    echo "ERROR: WSL venv not found. Run scripts/install-wsl-components.sh first." >&2
    exit 1
fi

echo "Starting Blender MCP server (WSL)..."
echo "  Python: $VENV_PYTHON"
echo "  Make sure Blender is running with the MCP addon enabled."
echo ""

exec "$VENV_PYTHON" -m blender_mcp
