@echo off
rem Nightly release launcher. Task Scheduler runs this twice a day:
rem   nightly-release.cmd scheduled   (the main cut time)
rem   nightly-release.cmd retry       (skips if this machine already succeeded today)
rem All paths and the prompt come from release-manager.config.json one folder up.
setlocal
set "HERE=%~dp0"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=scheduled"

for /f "usebackq delims=" %%L in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%..\docs\releases\scripts\ReleaseConfig.ps1" -ConfigPath "%HERE%..\release-manager.config.json" -AsCmd`) do set "%%L"
if not defined RM_WS (
  echo Could not read release-manager.config.json. Run ReleaseConfig.ps1 -AsCmd by hand to see the error.
  exit /b 2
)

for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "TODAY=%%d"

if /i "%MODE%"=="retry" (
  findstr /x /c:"%TODAY%" "%RM_STAMP%" >nul 2>&1
  if not errorlevel 1 (
    echo [%TODAY% %TIME%] retry skipped: run already completed today>>"%RM_LOG%"
    exit /b 0
  )
)

echo [%TODAY% %TIME%] run start (%MODE%)>>"%RM_LOG%"
cd /d "%RM_WS%"
rem call, so a claude.cmd shim (npm install) returns here instead of ending the script.
call "%RM_CLAUDE%" %RM_CLAUDE_ARGS% -p "%RM_PROMPT%">>"%RM_LOG%" 2>&1
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo [%TODAY% %TIME%] run FAILED exit %RC% (%MODE%^)>>"%RM_LOG%"
  exit /b 1
)
echo %TODAY%>>"%RM_STAMP%"
echo [%TODAY% %TIME%] run complete (%MODE%)>>"%RM_LOG%"
exit /b 0
