#Requires -Version 5.1
<#
.SYNOPSIS
    One-liner bootstrap for MCP Server Deploy.
.DESCRIPTION
    Downloads and runs the full MCP server setup on any Windows machine.
    No prerequisites required except PowerShell 5.1+.
.EXAMPLE
    irm https://raw.githubusercontent.com/codingmachineedge/blender-mcp-deploy/main/bootstrap.ps1 | iex
.EXAMPLE
    Invoke-RestMethod https://raw.githubusercontent.com/codingmachineedge/blender-mcp-deploy/main/bootstrap.ps1 | Invoke-Expression
.EXAMPLE
    Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/codingmachineedge/blender-mcp-deploy/main/bootstrap.ps1 | iex
#>

[CmdletBinding()]
param(
    [switch]$SkipWsl,
    [switch]$SkipBlenderInstall,
    [switch]$SkipPythonInstall,
    [switch]$Portable
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoOwner = "codingmachineedge"
$repoName  = "blender-mcp-deploy"
$branch    = "main"
$zipUrl    = "https://github.com/$repoOwner/$repoName/archive/refs/heads/$branch.zip"

$installBase = if ($Portable) {
    Join-Path $PSScriptRoot "mcp-servers-deploy"
} else {
    Join-Path $env:LOCALAPPDATA "mcp-servers-deploy"
}

Write-Host ""
Write-Host "  MCP Server Deploy - Bootstrap" -ForegroundColor Cyan
Write-Host "  ==============================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path (Join-Path $installBase "setup.ps1")) {
    Write-Host "  Existing installation found at $installBase" -ForegroundColor Yellow
    Write-Host "  Updating..." -ForegroundColor Yellow
    Remove-Item $installBase -Recurse -Force -ErrorAction SilentlyContinue
}

$zipPath = Join-Path $env:TEMP "mcp-servers-deploy.zip"
$extractPath = Join-Path $env:TEMP "mcp-servers-deploy-extract"

Write-Host "  Downloading from GitHub..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
} catch {
    Write-Host "  ERROR: Failed to download. Check your internet connection." -ForegroundColor Red
    Write-Host "  URL: $zipUrl" -ForegroundColor Gray
    throw
}

if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Write-Host "  Extracting..." -ForegroundColor Gray
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$extractedDir = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
if (-not $extractedDir) { throw "Extraction failed - no directory found" }

if (-not (Test-Path (Split-Path $installBase -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $installBase -Parent) -Force | Out-Null
}
if (Test-Path $installBase) { Remove-Item $installBase -Recurse -Force }
Move-Item -Path $extractedDir.FullName -Destination $installBase -Force

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "  Installed to: $installBase" -ForegroundColor Green
Write-Host ""

$setupScript = Join-Path $installBase "setup.ps1"
$setupArgs = @()
if ($SkipWsl) { $setupArgs += "-SkipWsl" }
if ($SkipBlenderInstall) { $setupArgs += "-SkipBlenderInstall" }
if ($SkipPythonInstall) { $setupArgs += "-SkipPythonInstall" }
if ($Portable) { $setupArgs += "-Portable" }

Write-Host "  Running setup..." -ForegroundColor Cyan
Write-Host ""

& $setupScript @setupArgs
