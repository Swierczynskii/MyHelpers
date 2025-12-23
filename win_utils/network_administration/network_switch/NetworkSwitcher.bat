@echo off
setlocal EnableExtensions

rem NetworkSwitcher.bat - interactive network adapter switcher with admin elevation
rem - 1: Ethernet (disable "Wi-Fi", enable "Ethernet")
rem - 2: Wi-Fi    (disable "Ethernet", enable "Wi-Fi")

rem --- Self-elevate if not already running as admin ---
fltmc >nul 2>&1
if errorlevel 1 (
  echo Requesting administrative privileges...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  if errorlevel 1 (
    echo Elevation canceled or failed. Exiting.
    exit /b 1
  )
  exit /b
)
rem --- Elevated from here ---

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%NetworkInterfaceSwitch.ps1"
if not exist "%PS1%" (
  echo ERROR: PowerShell script not found: "%PS1%"
  exit /b 2
)

set "mode="
goto :prompt

:prompt
echo Select network mode:
echo   [1] Ethernet - disable "Wi-Fi", enable "Ethernet"
echo   [2] Wi-Fi    - disable "Ethernet", enable "Wi-Fi"
choice /C 12 /N /M "Enter choice (1/2): "
set "sel=%errorlevel%"
if "%sel%"=="1" set "mode=ethernet"
if "%sel%"=="2" set "mode=wifi"

if not defined mode (
  echo Invalid selection. Exiting.
  exit /b 1
)

:run
if /I "%mode%"=="ethernet" (
  set "DISABLE=Wi-Fi"
  set "ENABLE=Ethernet"
) else (
  set "DISABLE=Ethernet"
  set "ENABLE=Wi-Fi"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" "%DISABLE%" "%ENABLE%"
set "rc=%errorlevel%"
exit /b %rc%