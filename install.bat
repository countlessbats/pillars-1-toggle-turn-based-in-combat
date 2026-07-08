@echo off
setlocal
rem ============================================================================
rem  Tactical Toggle installer (double-click me)
rem  Runs install.ps1 - no PowerShell knowledge required.
rem  Auto-detects your Steam install; prompts if it can't find one.
rem  At the prompt, quotes are optional; paths with spaces and parentheses are OK.
rem ============================================================================
echo.
echo Installing Tactical Toggle...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "TT_EXIT=%errorlevel%"
echo.
if "%TT_EXIT%"=="0" (
    echo Done. You can close this window and launch the game.
) else (
    echo Something went wrong ^(exit code %TT_EXIT%^). See the messages above.
    echo Make sure Pillars of Eternity is closed and the folder is correct, then try again.
)
echo.
pause
endlocal
