@echo off
setlocal

echo.
echo  Blender MCP Deploy - Bootstrap
echo  ===============================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-RestMethod 'https://raw.githubusercontent.com/codingmachineedge/blender-mcp-deploy/main/bootstrap.ps1' | Invoke-Expression" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  Bootstrap failed with error code %ERRORLEVEL%
    echo.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo  Press any key to exit...
pause >nul
