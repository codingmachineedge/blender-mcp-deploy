@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0list-servers.ps1" %*
