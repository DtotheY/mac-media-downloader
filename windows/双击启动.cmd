@echo off
chcp 65001 >nul
title Media Downloader for Windows
cd /d "%~dp0"

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo Windows PowerShell was not found.
  echo Please use Windows 10 or Windows 11.
  pause
  exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0downloader.ps1"
if errorlevel 1 (
  echo.
  echo The downloader stopped. Please read the message above.
  pause
)
