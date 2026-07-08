@echo off
setlocal
echo.
echo Uninstalling Tactical Toggle...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
echo.
echo Done. You can close this window.
echo.
pause
endlocal
