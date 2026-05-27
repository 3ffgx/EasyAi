@echo off
setlocal
cd /d "%~dp0"

where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [ERROR] PowerShell was not found on this computer.
  pause
  exit /b 1
)

if "%EASYAI_SKIP_GUI%"=="1" (
  echo [OK] EasyAi launcher check passed.
  exit /b 0
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p = Join-Path (Get-Location) 'EasyAi-DeepSeek.ps1'; $code = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p)); Invoke-Expression $code"
set EXIT_CODE=%ERRORLEVEL%

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] EasyAi failed to start. Exit code: %EXIT_CODE%
  echo Check the log folder:
  echo %USERPROFILE%\.easyai
  pause
)

exit /b %EXIT_CODE%
