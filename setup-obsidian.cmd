@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-obsidian.ps1" -VaultPath "%~dp0"
echo.
pause
