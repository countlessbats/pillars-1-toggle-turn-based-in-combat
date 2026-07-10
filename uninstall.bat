@echo off
setlocal
echo.
echo Uninstalling Turnbased Anytime...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
echo.
echo Done. You can close this window.
echo.
pause
endlocal
