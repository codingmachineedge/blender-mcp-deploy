#Requires -Version 5.1
<#
.SYNOPSIS
    Start the Blender MCP server (Windows).
#>

$repoRoot = Split-Path $PSScriptRoot -Parent
$venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"

if (-not (Test-Path $venvPython)) {
    Write-Host "ERROR: venv not found. Run .\setup.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Blender MCP server..." -ForegroundColor Cyan
Write-Host "  Python: $venvPython" -ForegroundColor Gray
Write-Host "  Make sure Blender is running with the MCP addon enabled." -ForegroundColor Yellow
Write-Host ""

& $venvPython -m blender_mcp
