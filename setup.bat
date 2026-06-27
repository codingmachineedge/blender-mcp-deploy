@echo off
setlocal

echo.
echo  Blender MCP Deploy
echo  ===================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  Setup failed with error code %ERRORLEVEL%
    echo.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo  Press any key to exit...
pause >nul
