@echo off
setlocal
cd /d "%~dp0"
echo [1/2] Obsidian
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-obsidian.ps1" -VaultPath "%~dp0"
if errorlevel 1 goto :error
echo.
echo [2/2] Kaku
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-kaku.ps1"
if errorlevel 1 goto :error
echo.
echo Setup completed.
pause
exit /b 0
:error
echo Setup stopped because an error occurred.
pause
exit /b 1
