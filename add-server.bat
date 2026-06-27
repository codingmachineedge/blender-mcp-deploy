@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0add-server.ps1" %*
