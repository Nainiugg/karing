@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Build Node Inspector

where flutter >nul 2>nul
if errorlevel 1 goto :flutter_missing

if not exist "windows\runner\main.cpp" (
  call flutter create --platforms=windows --project-name=node_inspector_app --org=io.nainiugg --no-pub .
  if errorlevel 1 goto :failed
)

call flutter pub get
if errorlevel 1 goto :failed
call flutter analyze --fatal-infos
if errorlevel 1 goto :failed
call flutter test
if errorlevel 1 goto :failed
call flutter build windows --release
if errorlevel 1 goto :failed

echo.
echo Build complete:
echo %CD%\build\windows\x64\runner\Release
echo.
pause
exit /b 0

:flutter_missing
echo Flutter 3.35 or newer was not found in PATH.
pause
exit /b 1

:failed
echo.
echo Build failed. Review the complete error above.
pause
exit /b 1
