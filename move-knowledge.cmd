@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
rem Retain the original filename for compatibility. This batch COPIES files.
set "SOURCE=C:\work\Knowledge"
set "DESTINATION=C:\Users\e230038\OneDrive - 株式会社 経営管理センター\AI推進部 - ドキュメント\99_ナレッジ\吉富"
set "FOLDERS=.obsidian 06_Experiments 07_Decisions Assets Notes Sources Workspace"
set "EXECUTE="
set "INTERACTIVE=1"
if "%~1"=="" goto run
set "INTERACTIVE="
if not "%~2"=="" goto usage
if /I "%~1"=="--preview" goto run
if /I not "%~1"=="--execute" goto usage
set "EXECUTE=-Execute"
:run
echo Source: "%SOURCE%"
echo Destination: "%DESTINATION%"
if defined EXECUTE (echo COPY - overwrite destination files; keep source files) else (echo PREVIEW - no target files will be changed)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0move-knowledge.ps1" -Source "%SOURCE%" -Destination "%DESTINATION%" -FolderList "%FOLDERS%" %EXECUTE%
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" (echo Finished successfully.) else (echo ERROR: Copy failed. See the output above.)
if defined INTERACTIVE pause
exit /b %RESULT%
:usage
echo Usage: %~nx0 [--preview ^| --execute]
exit /b 2
