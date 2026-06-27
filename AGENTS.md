# AGENTS.md

## MCP Servers

### blender
- **Transport:** stdio
- **Command:** `.venv\Scripts\python.exe`
- **Args:** `-m blender_mcp`
- **Description:** Blender MCP server for 3D scene manipulation via AI.

## Instructions
- Use the `blender` MCP server to create, modify, and query 3D scenes in Blender.
- Always confirm destructive operations with the user before executing.
- Prefer non-destructive edits when possible.
- When creating objects, set appropriate materials and lighting.
- Use the `get_scene_info` tool first to understand the current scene state.
