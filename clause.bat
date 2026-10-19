@echo off
rem clause.bat - Windows Command Shell Entry Trampoline
setlocal enableextensions

set "CLAUSE_ROOT=%~dp0"
if "%CLAUSE_ROOT:~-1%"=="\" set "CLAUSE_ROOT=%CLAUSE_ROOT:~0,-1%"

set "CLAUSE_PROJECT_ROOT=%CLAUSE_ROOT%"
set "USERPROFILE=%CLAUSE_ROOT%"
set "HOME=%CLAUSE_ROOT%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%CLAUSE_ROOT%\clause.ps1" %*

endlocal