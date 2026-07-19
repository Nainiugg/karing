@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Node Inspector

where flutter >nul 2>nul
if errorlevel 1 goto :flutter_missing

echo [1/4] Preparing the verified isolated scan core...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare_core_windows.ps1"
if errorlevel 1 goto :failed

if not exist "windows\runner\main.cpp" (
  echo [2/4] Preparing the standard Windows runner...
  call flutter create --platforms=windows --project-name=node_inspector_app --org=io.nainiugg --no-pub .
  if errorlevel 1 goto :failed
)

echo [3/4] Resolving Flutter dependencies...
call flutter pub get
if errorlevel 1 goto :failed

echo [4/4] Starting Node Inspector...
call flutter run -d windows
if errorlevel 1 goto :failed
exit /b 0

:flutter_missing
echo.
echo Flutter was not found in PATH.
echo Install Flutter 3.35 or newer and enable Windows desktop support:
echo https://docs.flutter.dev/platform-integration/windows/setup
echo.
pause
exit /b 1

:failed
echo.
echo Node Inspector failed to start. Keep this window and copy the full error.
echo.
pause
exit /b 1
