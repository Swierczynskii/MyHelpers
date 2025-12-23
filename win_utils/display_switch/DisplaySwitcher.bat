@echo off
setlocal EnableExtensions

rem DisplaySwitcher.bat - interactive and arg-based wrapper for DisplaySwitch.exe
rem - Accepts: extend|first|second as an argument
rem - Or prompts: 1=first, 2=second, 3=extend

set "ds=%windir%\System32\DisplaySwitch.exe"
if not exist "%ds%" (
  echo ERROR: DisplaySwitch.exe not found at "%ds%".
  exit /b 2
)

set "mode="

if "%~1"=="" goto :prompt
if /I "%~1"=="/?" goto :usage

set "arg=%~1"
if /I "%arg%"=="extend" set "mode=/extend"
if /I "%arg%"=="first"  set "mode=/internal"
if /I "%arg%"=="second" set "mode=/external"

if defined mode goto :run

echo Invalid argument: %arg%
echo.
goto :prompt

:prompt
echo Select display mode:
echo   [1] First  - Internal / primary only
echo   [2] Second - External / secondary only
echo   [3] Extend - Extend desktop across displays
choice /C 123 /N /M "Enter choice (1/2/3): "
set "sel=%errorlevel%"
if "%sel%"=="3" set "mode=/extend"
if "%sel%"=="2" set "mode=/external"
if "%sel%"=="1" set "mode=/internal"

if not defined mode (
  echo Invalid selection. Exiting.
  exit /b 1
)

:run
"%ds%" %mode%
set "rc=%errorlevel%"
exit /b %rc%

:usage
echo Usage: %~n0 ^<extend^|first^|second^>
echo Or run with no args to choose:
echo   1=first, 2=second, 3=extend
exit /b 0