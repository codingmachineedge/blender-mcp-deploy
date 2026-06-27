@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0remove-server.ps1" %*
