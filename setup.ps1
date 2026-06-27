#Requires -Version 5.1
<#
.SYNOPSIS
    Fully automatic multi-MCP server deployment for any Windows installation.
.DESCRIPTION
    - Auto-elevates to admin if needed
    - Reads servers.json for which MCP servers to deploy
    - Detects or installs Blender (if any server requires it)
    - Detects or installs Python (winget, direct download)
    - Creates a dedicated venv and installs all Python-based servers
    - Installs Blender addons automatically
    - Sets up WSL components (if WSL is available)
    - Writes MCP config for OpenCode, Claude Code, and Codex
    - No winget required - uses direct downloads as fallback
#>

[CmdletBinding()]
param(
    [switch]$SkipWsl,
    [switch]$SkipBlenderInstall,
    [switch]$SkipPythonInstall,
    [switch]$Portable,
    [switch]$NoAutoElevate,
    [string]$VenvPath = "",
    [string]$InstallDir = "",
    [string]$ServerConfig = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ── Admin elevation check ───────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $NoAutoElevate -and -not $Portable) {
    Write-Host "`n>> Requesting administrator privileges..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"")
    $argList += @("-NoAutoElevate")
    if ($SkipWsl) { $argList += "-SkipWsl" }
    if ($SkipBlenderInstall) { $argList += "-SkipBlenderInstall" }
    if ($SkipPythonInstall) { $argList += "-SkipPythonInstall" }
    if ($Portable) { $argList += "-Portable" }
    if ($VenvPath) { $argList += @("-VenvPath", "`"$VenvPath`"") }
    if ($InstallDir) { $argList += @("-InstallDir", "`"$InstallDir`"") }
    if ($ServerConfig) { $argList += @("-ServerConfig", "`"$ServerConfig`"") }
    
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait
        exit 0
    } catch {
        Write-Host "   WARNING: Could not elevate to admin. Continuing without admin rights..." -ForegroundColor Yellow
        Write-Host "   Some features may not work. Use -Portable flag for user-only install." -ForegroundColor Yellow
    }
}

if ($isAdmin) {
    Write-Host "`n>> Running with administrator privileges" -ForegroundColor Green
}

function Write-Step { param([string]$msg) Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Skip { param([string]$msg) Write-Host "   SKIP: $msg" -ForegroundColor Yellow }
function Write-Warn { param([string]$msg) Write-Host "   WARNING: $msg" -ForegroundColor Yellow }

# ── 0. Resolve paths ────────────────────────────────────────────────
$repoRoot    = $PSScriptRoot
$scriptsDir  = Join-Path $repoRoot "scripts"

if (-not $ServerConfig) {
    $ServerConfig = Join-Path $repoRoot "servers.json"
}

if (-not (Test-Path $ServerConfig)) {
    throw "Server config not found at $ServerConfig. Run add-server.ps1 first or create servers.json manually."
}

$serverConfigData = Get-Content $ServerConfig -Raw | ConvertFrom-Json

if ($serverConfigData.defaults.install_dir -and -not $InstallDir) {
    $InstallDir = $serverConfigData.defaults.install_dir
}

if (-not $InstallDir) {
    if ($Portable -or $serverConfigData.defaults.portable) {
        $InstallDir = Join-Path $repoRoot "install"
    } else {
        $InstallDir = Join-Path $env:LOCALAPPDATA "mcp-servers"
    }
}

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

if ($serverConfigData.defaults.venv_path -and -not $VenvPath) {
    $VenvPath = $serverConfigData.defaults.venv_path
}

if (-not $VenvPath) {
    $VenvPath = Join-Path $InstallDir "venv"
}

Write-Host ""
Write-Host "  MCP Server Deploy" -ForegroundColor Green
Write-Host "  =================" -ForegroundColor Green
Write-Host "  Install dir: $InstallDir" -ForegroundColor Gray
Write-Host "  Venv path:   $VenvPath" -ForegroundColor Gray
Write-Host "  Config:      $ServerConfig" -ForegroundColor Gray

# ── Check if any server requires Blender ────────────────────────────
$needsBlender = $false
foreach ($server in $serverConfigData.servers) {
    if ($server.enabled -and $server.requires_blender) {
        $needsBlender = $true
        break
    }
}

# ── 1. Detect or Install Blender (if needed) ────────────────────────
$blenderExe = $null

if ($needsBlender) {
    Write-Step "Checking Blender"
    
    $blenderExe = (Get-Command blender -ErrorAction SilentlyContinue).Source
    
    if (-not $blenderExe) {
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        foreach ($regPath in $regPaths) {
            $blenderReg = Get-ItemProperty $regPath -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Blender*" } | Select-Object -First 1
            if ($blenderReg -and $blenderReg.InstallLocation) {
                $candidate = Join-Path $blenderReg.InstallLocation "blender.exe"
                if (Test-Path $candidate) { $blenderExe = $candidate; break }
            }
        }
    }
    
    if (-not $blenderExe) {
        $searchPaths = @(
            "${env:ProgramFiles}\Blender Foundation",
            "${env:ProgramFiles(x86)}\Blender Foundation",
            "$env:LOCALAPPDATA\Programs\Blender Foundation",
            "$env:LOCALAPPDATA\Blender Foundation",
            "C:\Blender",
            "D:\Blender"
        )
        foreach ($p in $searchPaths) {
            if (Test-Path $p) {
                $found = Get-ChildItem -Path $p -Filter "blender.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $blenderExe = $found.FullName; break }
            }
        }
    }
    
    if ($blenderExe) {
        Write-Ok "Blender found at $blenderExe"
    } elseif ($SkipBlenderInstall) {
        Write-Skip "Blender not found and -SkipBlenderInstall set"
    } else {
        Write-Host "   Blender not found. Attempting installation..." -ForegroundColor Yellow
        
        $installed = $false
        
        if (-not $installed) {
            try {
                $null = winget --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   Trying winget..." -ForegroundColor Gray
                    winget install --id BlenderFoundation.Blender -e --accept-source-agreements --accept-package-agreements --silent
                    if ($LASTEXITCODE -eq 0) { $installed = $true }
                }
            } catch { }
        }
        
        if (-not $installed) {
            Write-Host "   Downloading Blender directly..." -ForegroundColor Gray
            $blenderUrl = "https://download.blender.org/release/Blender4.2/blender-4.2.0-windows-x64.msi"
            $blenderMsi = Join-Path $env:TEMP "blender-installer.msi"
            
            try {
                Invoke-WebRequest -Uri $blenderUrl -OutFile $blenderMsi -UseBasicParsing
                Write-Host "   Installing Blender (this may take a few minutes)..." -ForegroundColor Gray
                
                $installArgs = @("/i", $blenderMsi, "/qn", "/norestart")
                if (-not $Portable) {
                    $installArgs += "ALLUSERS=1"
                } else {
                    $installArgs += "TARGETDIR=`"$InstallDir\Blender`""
                }
                
                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) { $installed = $true }
                
                Remove-Item $blenderMsi -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Warn "Direct download failed: $_"
            }
        }
        
        if ($installed) {
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $blenderExe = (Get-Command blender -ErrorAction SilentlyContinue).Source
            
            if (-not $blenderExe) {
                $searchPaths = @(
                    "${env:ProgramFiles}\Blender Foundation",
                    "$env:LOCALAPPDATA\Programs\Blender Foundation",
                    "$InstallDir\Blender"
                )
                foreach ($p in $searchPaths) {
                    if (Test-Path $p) {
                        $found = Get-ChildItem -Path $p -Filter "blender.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($found) { $blenderExe = $found.FullName; break }
                    }
                }
            }
            
            if ($blenderExe) {
                Write-Ok "Blender installed at $blenderExe"
            } else {
                throw "Blender installation completed but executable not found. Please restart your terminal and re-run setup."
            }
        } else {
            throw "Could not install Blender automatically. Please install Blender manually from https://www.blender.org/download/ and re-run setup."
        }
    }
}

# ── 2. Detect or Install Python ─────────────────────────────────────
Write-Step "Checking Python"
$pythonExe = $null

$pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $pythonExe) { $pythonExe = (Get-Command python3 -ErrorAction SilentlyContinue).Source }

if (-not $pythonExe) {
    $regPaths = @(
        "HKLM:\SOFTWARE\Python\PythonCore\*\InstallPath",
        "HKCU:\SOFTWARE\Python\PythonCore\*\InstallPath"
    )
    foreach ($regPath in $regPaths) {
        $pythonReg = Get-ItemProperty $regPath -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pythonReg -and $pythonReg.'(default)') {
            $candidate = Join-Path $pythonReg.'(default)' "python.exe"
            if (Test-Path $candidate) { $pythonExe = $candidate; break }
        }
    }
}

if (-not $pythonExe) {
    $searchPaths = @(
        "$env:LOCALAPPDATA\Programs\Python",
        "${env:ProgramFiles}\Python*",
        "C:\Python*"
    )
    foreach ($pattern in $searchPaths) {
        $dirs = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            $candidate = Join-Path $dir.FullName "python.exe"
            if (Test-Path $candidate) { $pythonExe = $candidate; break }
        }
        if ($pythonExe) { break }
    }
}

if ($pythonExe) {
    Write-Ok "Python found at $pythonExe"
} elseif ($SkipPythonInstall) {
    Write-Skip "Python not found and -SkipPythonInstall set"
} else {
    Write-Host "   Python not found. Attempting installation..." -ForegroundColor Yellow
    
    $installed = $false
    
    if (-not $installed) {
        try {
            $null = winget --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   Trying winget..." -ForegroundColor Gray
                winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements --silent
                if ($LASTEXITCODE -eq 0) { $installed = $true }
            }
        } catch { }
    }
    
    if (-not $installed) {
        Write-Host "   Downloading Python directly..." -ForegroundColor Gray
        $pythonUrl = "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe"
        $pythonInstaller = Join-Path $env:TEMP "python-installer.exe"
        
        try {
            Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
            Write-Host "   Installing Python (this may take a few minutes)..." -ForegroundColor Gray
            
            $installArgs = @("/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_test=0")
            if ($Portable) {
                $installArgs += "TargetDir=`"$InstallDir\Python`""
            }
            
            $process = Start-Process -FilePath $pythonInstaller -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) { $installed = $true }
            
            Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warn "Direct download failed: $_"
        }
    }
    
    if ($installed) {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
        
        if (-not $pythonExe) {
            $searchPaths = @(
                "$env:LOCALAPPDATA\Programs\Python\Python312",
                "$env:LOCALAPPDATA\Programs\Python\Python3*",
                "$InstallDir\Python"
            )
            foreach ($p in $searchPaths) {
                $candidate = Join-Path $p "python.exe"
                if (Test-Path $candidate) { $pythonExe = $candidate; break }
            }
        }
        
        if ($pythonExe) {
            Write-Ok "Python installed at $pythonExe"
        } else {
            throw "Python installation completed but executable not found. Please restart your terminal and re-run setup."
        }
    } else {
        throw "Could not install Python automatically. Please install Python 3.12+ manually from https://www.python.org/downloads/ and re-run setup."
    }
}

# ── 3. Create venv ──────────────────────────────────────────────────
Write-Step "Setting up Python venv"
if (-not (Test-Path $VenvPath)) {
    & $pythonExe -m venv $VenvPath
    Write-Ok "Created venv at $VenvPath"
} else {
    Write-Ok "Venv already exists"
}

$venvPython = Join-Path $VenvPath "Scripts\python.exe"
$venvPip    = Join-Path $VenvPath "Scripts\pip.exe"

& $venvPython -m pip install --upgrade pip 2>&1 | Out-Null

# ── 4. Install each server ──────────────────────────────────────────
$installedServers = @()

foreach ($server in $serverConfigData.servers) {
    if (-not $server.enabled) {
        Write-Skip "Server '$($server.name)' is disabled"
        continue
    }
    
    Write-Step "Installing server: $($server.name)"
    
    if ($server.type -eq "python" -and $server.pip_package) {
        $pkgSpec = if ($server.version) { "$($server.pip_package)==$($server.version)" } else { $server.pip_package }
        Write-Host "   Installing $pkgSpec..." -ForegroundColor Gray
        & $venvPip install $pkgSpec 2>&1 | Out-Null
        Write-Ok "$($server.name) installed"
        
        if ($server.requires_blender -and $server.blender_addon_script -and $blenderExe) {
            $addonScript = Join-Path $scriptsDir $server.blender_addon_script
            if (Test-Path $addonScript) {
                Write-Host "   Installing Blender addon..." -ForegroundColor Gray
                & $blenderExe --background --python "$addonScript" 2>&1 | Out-Null
                Write-Ok "Blender addon installed"
            }
        }
    }
    
    $installedServers += $server
}

# ── 5. WSL setup ────────────────────────────────────────────────────
if (-not $SkipWsl) {
    Write-Step "Checking WSL"
    $wslAvailable = $false
    try {
        $null = wsl --list --quiet 2>&1
        if ($LASTEXITCODE -eq 0) { $wslAvailable = $true }
    } catch { }

    if ($wslAvailable) {
        Write-Ok "WSL detected"
        $wslScript = Join-Path $scriptsDir "install-wsl-components.sh"
        if (Test-Path $wslScript) {
            $wslScriptUnix = $wslScript -replace '\\', '/'
            $wslScriptUnix = $wslScriptUnix -replace '^([A-Z]):', { '/mnt/' + $args[0].Value.ToLower() }
            wsl bash -c "chmod +x '$wslScriptUnix' && '$wslScriptUnix'"
            Write-Ok "WSL components configured"
        }
    } else {
        Write-Skip "WSL not available, skipping WSL setup"
    }
} else {
    Write-Skip "WSL setup skipped by flag"
}

# ── 6. Write agent configs ──────────────────────────────────────────
Write-Step "Configuring AI agent MCP connections"

$opencodeServers = @{}
$claudeServers = @{}
$codexServers = @{}
$agentsMdSections = @()

foreach ($server in $installedServers) {
    $serverName = $server.name
    
    if ($server.type -eq "python") {
        $cmd = $venvPython
        $argsList = if ($server.args) { $server.args } else { @("-m", $server.pip_package -replace '-', '_') }
    } else {
        $cmd = $server.command
        $argsList = $server.args
    }
    
    $opencodeServers[$serverName] = @{
        type    = "stdio"
        command = $cmd
        args    = $argsList
    }
    
    $claudeServers[$serverName] = @{
        command = $cmd
        args    = $argsList
    }
    
    $codexServers[$serverName] = @{
        command = $cmd
        args    = $argsList
        env     = @{}
    }
    
    $section = @"

### $serverName
- **Transport:** stdio
- **Command:** ``$cmd``
- **Args:** ``$($argsList -join ' ')``
- **Description:** $($server.description)
"@
    $agentsMdSections += $section
}

# --- OpenCode (opencode.json) ---
$opencodeConfig = @{
    mcp = @{
        servers = $opencodeServers
    }
} | ConvertTo-Json -Depth 10

$opencodeJsonPath = Join-Path $repoRoot "opencode.json"
Set-Content -Path $opencodeJsonPath -Value $opencodeConfig -Encoding UTF8
Write-Ok "opencode.json written"

# --- Claude Code (.mcp.json) ---
$claudeConfig = @{
    mcpServers = $claudeServers
} | ConvertTo-Json -Depth 10

$claudeJsonPath = Join-Path $repoRoot ".mcp.json"
Set-Content -Path $claudeJsonPath -Value $claudeConfig -Encoding UTF8
Write-Ok ".mcp.json (Claude Code) written"

# --- Codex (AGENTS.md) ---
$agentsMd = @"
# AGENTS.md

## MCP Servers
$($agentsMdSections -join "`n")

## Instructions
- Use the MCP servers to interact with external tools and services.
- Always confirm destructive operations with the user before executing.
- Prefer non-destructive edits when possible.
"@

$agentsMdPath = Join-Path $repoRoot "AGENTS.md"
Set-Content -Path $agentsMdPath -Value $agentsMd -Encoding UTF8
Write-Ok "AGENTS.md (Codex) written"

# ── 7. Global config injection ──────────────────────────────────────
Write-Step "Injecting into global agent configs"

# OpenCode global config
$opencodeGlobalDir = Join-Path $env:USERPROFILE ".config" "opencode"
if (-not (Test-Path $opencodeGlobalDir)) { New-Item -ItemType Directory -Path $opencodeGlobalDir -Force | Out-Null }
$opencodeGlobalJson = Join-Path $opencodeGlobalDir "opencode.json"
if (Test-Path $opencodeGlobalJson) {
    $existing = Get-Content $opencodeGlobalJson -Raw | ConvertFrom-Json
} else {
    $existing = [PSCustomObject]@{}
}
if (-not $existing.PSObject.Properties['mcp']) {
    $existing | Add-Member -NotePropertyName "mcp" -NotePropertyValue ([PSCustomObject]@{ servers = [PSCustomObject]@{} })
}
foreach ($serverName in $opencodeServers.Keys) {
    $srv = $opencodeServers[$serverName]
    $serverObj = [PSCustomObject]@{
        type    = $srv.type
        command = $srv.command
        args    = $srv.args
    }
    $existing.mcp.servers | Add-Member -NotePropertyName $serverName -NotePropertyValue $serverObj -Force
}
$existing | ConvertTo-Json -Depth 10 | Set-Content $opencodeGlobalJson -Encoding UTF8
Write-Ok "OpenCode global config updated ($opencodeGlobalJson)"

# Claude Code global config
$claudeGlobalDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeGlobalDir)) { New-Item -ItemType Directory -Path $claudeGlobalDir -Force | Out-Null }
$claudeGlobalJson = Join-Path $claudeGlobalDir "claude_desktop_config.json"
if (Test-Path $claudeGlobalJson) {
    $existingClaude = Get-Content $claudeGlobalJson -Raw | ConvertFrom-Json
} else {
    $existingClaude = [PSCustomObject]@{}
}
if (-not $existingClaude.PSObject.Properties['mcpServers']) {
    $existingClaude | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{})
}
foreach ($serverName in $claudeServers.Keys) {
    $srv = $claudeServers[$serverName]
    $serverObj = [PSCustomObject]@{
        command = $srv.command
        args    = $srv.args
    }
    $existingClaude.mcpServers | Add-Member -NotePropertyName $serverName -NotePropertyValue $serverObj -Force
}
$existingClaude | ConvertTo-Json -Depth 10 | Set-Content $claudeGlobalJson -Encoding UTF8
Write-Ok "Claude global config updated ($claudeGlobalJson)"

# Codex (OpenAI) global config
$codexGlobalDir = Join-Path $env:USERPROFILE ".codex"
if (-not (Test-Path $codexGlobalDir)) { New-Item -ItemType Directory -Path $codexGlobalDir -Force | Out-Null }
$codexGlobalJson = Join-Path $codexGlobalDir "config.json"
if (Test-Path $codexGlobalJson) {
    $existingCodex = Get-Content $codexGlobalJson -Raw | ConvertFrom-Json
} else {
    $existingCodex = [PSCustomObject]@{}
}
if (-not $existingCodex.PSObject.Properties['mcpServers']) {
    $existingCodex | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{})
}
foreach ($serverName in $codexServers.Keys) {
    $srv = $codexServers[$serverName]
    $serverObj = [PSCustomObject]@{
        command = $srv.command
        args    = $srv.args
        env     = [PSCustomObject]@{}
    }
    $existingCodex.mcpServers | Add-Member -NotePropertyName $serverName -NotePropertyValue $serverObj -Force
}
$existingCodex | ConvertTo-Json -Depth 10 | Set-Content $codexGlobalJson -Encoding UTF8
Write-Ok "Codex global config updated ($codexGlobalJson)"

# ── Done ─────────────────────────────────────────────────────────────
Write-Host "`n" -NoNewline
Write-Host "============================================" -ForegroundColor Green
Write-Host "  MCP Servers deployed successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed servers:" -ForegroundColor White
foreach ($server in $installedServers) {
    Write-Host "  - $($server.name): $($server.description)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Launch your AI agent (OpenCode / Claude / Codex)"
Write-Host "  2. The MCP tools will be available automatically"
Write-Host ""
if ($needsBlender -and $blenderExe) {
    Write-Host "  Note: Open Blender for Blender MCP servers to work" -ForegroundColor Yellow
    Write-Host ""
}
