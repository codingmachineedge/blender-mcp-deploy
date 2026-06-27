#Requires -Version 5.1
<#
.SYNOPSIS
    List all configured MCP servers.
.EXAMPLE
    .\list-servers.ps1
#>

[CmdletBinding()]
param(
    [string]$ServerConfig = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot

if (-not $ServerConfig) {
    $ServerConfig = Join-Path $repoRoot "servers.json"
}

if (-not (Test-Path $ServerConfig)) {
    Write-Host "No server config found. Run add-server.ps1 to add servers." -ForegroundColor Yellow
    exit 0
}

$configData = Get-Content $ServerConfig -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "  Configured MCP Servers" -ForegroundColor Cyan
Write-Host "  ======================" -ForegroundColor Cyan
Write-Host ""

if ($configData.servers.Count -eq 0) {
    Write-Host "  No servers configured. Run add-server.ps1 to add servers." -ForegroundColor Yellow
} else {
    foreach ($server in $configData.servers) {
        $status = if ($server.enabled) { "[enabled]" } else { "[disabled]" }
        $statusColor = if ($server.enabled) { "Green" } else { "Gray" }
        
        Write-Host "  $($server.name)" -ForegroundColor White -NoNewline
        Write-Host " $status" -ForegroundColor $statusColor
        Write-Host "    Type: $($server.type)" -ForegroundColor Gray
        Write-Host "    Description: $($server.description)" -ForegroundColor Gray
        
        if ($server.type -eq "python" -and $server.pip_package) {
            $pkg = $server.pip_package
            if ($server.version) { $pkg += "==$($server.version)" }
            Write-Host "    Package: $pkg" -ForegroundColor Gray
        }
        
        if ($server.command) {
            Write-Host "    Command: $($server.command) $($server.args -join ' ')" -ForegroundColor Gray
        }
        
        if ($server.requires_blender) {
            Write-Host "    Requires: Blender" -ForegroundColor Yellow
        }
        
        Write-Host ""
    }
}

Write-Host "  Config file: $ServerConfig" -ForegroundColor Gray
Write-Host ""
