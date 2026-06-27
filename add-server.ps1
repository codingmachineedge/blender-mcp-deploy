#Requires -Version 5.1
<#
.SYNOPSIS
    Add a new MCP server to the deployment config.
.EXAMPLE
    .\add-server.ps1 -Name "filesystem" -PipPackage "@modelcontextprotocol/server-filesystem" -Description "File system access"
.EXAMPLE
    .\add-server.ps1 -Name "github" -NpxCommand "@modelcontextprotocol/server-github" -Description "GitHub API access"
.EXAMPLE
    .\add-server.ps1 -Name "custom" -Command "node" -Args "server.js" -Description "Custom MCP server"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [string]$Description = "",
    
    [string]$PipPackage = "",
    [string]$PipVersion = "",
    
    [string]$NpxCommand = "",
    
    [string]$Command = "",
    [string[]]$Args = @(),
    
    [switch]$RequiresBlender,
    [string]$BlenderAddonScript = "",
    
    [string]$ServerConfig = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot

if (-not $ServerConfig) {
    $ServerConfig = Join-Path $repoRoot "servers.json"
}

if (-not (Test-Path $ServerConfig)) {
    $initialConfig = @{
        servers = @()
        defaults = @{
            install_dir = ""
            venv_path = ""
            portable = $false
        }
    }
    $initialConfig | ConvertTo-Json -Depth 10 | Set-Content $ServerConfig -Encoding UTF8
    Write-Host "Created new server config at $ServerConfig" -ForegroundColor Green
}

$configData = Get-Content $ServerConfig -Raw | ConvertFrom-Json

$existing = $configData.servers | Where-Object { $_.name -eq $Name }
if ($existing) {
    throw "Server '$Name' already exists. Use remove-server.ps1 first or edit servers.json directly."
}

$newServer = [PSCustomObject]@{
    name = $Name
    description = $Description
    type = ""
    pip_package = ""
    version = ""
    command = ""
    args = @()
    env = @{}
    requires_blender = $false
    blender_addon_script = ""
    enabled = $true
}

if ($PipPackage) {
    $newServer.type = "python"
    $newServer.pip_package = $PipPackage
    $newServer.version = $PipVersion
    if (-not $Args) {
        $moduleName = $PipPackage -replace '-', '_' -replace '@.*', ''
        $newServer.args = @("-m", $moduleName)
    }
} elseif ($NpxCommand) {
    $newServer.type = "node"
    $newServer.command = "npx"
    $newServer.args = @("-y", $NpxCommand)
} elseif ($Command) {
    $newServer.type = "custom"
    $newServer.command = $Command
    $newServer.args = $Args
} else {
    throw "Must specify one of: -PipPackage, -NpxCommand, or -Command"
}

if ($RequiresBlender) {
    $newServer.requires_blender = $true
    $newServer.blender_addon_script = if ($BlenderAddonScript) { $BlenderAddonScript } else { "install-addon.py" }
}

$serversList = [System.Collections.ArrayList]@($configData.servers)
$serversList.Add($newServer) | Out-Null
$configData.servers = $serversList.ToArray()

$configData | ConvertTo-Json -Depth 10 | Set-Content $ServerConfig -Encoding UTF8

Write-Host ""
Write-Host "  Added server: $Name" -ForegroundColor Green
Write-Host "  Type: $($newServer.type)" -ForegroundColor Gray
Write-Host "  Description: $Description" -ForegroundColor Gray
Write-Host ""
Write-Host "  Run .\setup.ps1 to install and configure this server." -ForegroundColor Yellow
Write-Host ""
