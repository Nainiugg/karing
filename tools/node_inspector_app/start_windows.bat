@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Node Inspector

where flutter >nul 2>nul
if errorlevel 1 goto :flutter_missing

if not exist "windows\runner\main.cpp" (
  echo [1/3] Preparing the standard Windows runner...
  call flutter create --platforms=windows --project-name=node_inspector_app --org=io.nainiugg --no-pub .
  if errorlevel 1 goto :failed
)

echo [2/3] Resolving Flutter dependencies...
call flutter pub get
if errorlevel 1 goto :failed

echo [3/3] Starting Node Inspector...
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
