#Requires -Version 5.1
<#
.SYNOPSIS
    Remove an MCP server from the deployment config.
.EXAMPLE
    .\remove-server.ps1 -Name "filesystem"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [string]$ServerConfig = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot

if (-not $ServerConfig) {
    $ServerConfig = Join-Path $repoRoot "servers.json"
}

if (-not (Test-Path $ServerConfig)) {
    throw "Server config not found at $ServerConfig"
}

$configData = Get-Content $ServerConfig -Raw | ConvertFrom-Json

$existing = $configData.servers | Where-Object { $_.name -eq $Name }
if (-not $existing) {
    throw "Server '$Name' not found in config"
}

$serversList = [System.Collections.ArrayList]@($configData.servers)
$serversList.Remove($existing)
$configData.servers = $serversList.ToArray()

$configData | ConvertTo-Json -Depth 10 | Set-Content $ServerConfig -Encoding UTF8

Write-Host ""
Write-Host "  Removed server: $Name" -ForegroundColor Green
Write-Host ""
Write-Host "  Run .\setup.ps1 to update agent configs." -ForegroundColor Yellow
Write-Host ""
