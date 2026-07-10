@echo off
setlocal
rem ============================================================================
rem  Turnbased Anytime installer (double-click me)
rem  Runs install.ps1 - no PowerShell knowledge required.
rem  Auto-detects your Steam install; prompts if it can't find one.
rem  At the prompt, quotes are optional; paths with spaces and parentheses are OK.
rem ============================================================================
echo.
echo Installing Turnbased Anytime...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "TA_EXIT=%errorlevel%"
echo.
if "%TA_EXIT%"=="0" (
    echo Done. You can close this window and launch the game.
) else (
    echo Something went wrong ^(exit code %TA_EXIT%^). See the messages above.
    echo Make sure Pillars of Eternity is closed and the folder is correct, then try again.
)
echo.
pause
endlocal
