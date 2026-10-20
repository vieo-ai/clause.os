@echo off
rem install.bat - Bootstraps pwsh into .local\bin and hands off directly to clause.ps1
setlocal enableextensions

set "CLAUSE_ROOT=%~dp0"
if "%CLAUSE_ROOT:~-1%"=="\" set "CLAUSE_ROOT=%CLAUSE_ROOT:~0,-1%"

set "CLAUSE_PROJECT_ROOT=%CLAUSE_ROOT%"
set "LOCAL_BIN=%CLAUSE_ROOT%\.local\bin"
set "PWSH_EXE=%LOCAL_BIN%\pwsh.exe"
set "TMP_DIR=%CLAUSE_ROOT%\.cache\tmp_bootstrap"

if not exist "%LOCAL_BIN%" mkdir "%LOCAL_BIN%"

if not exist "%PWSH_EXE%" (
    echo [ClauseOS] Seeding PowerShell Core into .local\bin\...
    if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"
    
    set "PWSH_ASSET=powershell-7.4.1-win-x64.zip"
    set "PWSH_URL=https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/powershell-7.4.1-win-x64.zip"
    set "ZIP_PATH=%TMP_DIR%\%PWSH_ASSET%"

    curl.exe -sSL "%PWSH_URL%" -o "%ZIP_PATH%"
    tar.exe -xf "%ZIP_PATH%" -C "%LOCAL_BIN%"
    if exist "%TMP_DIR%" rmdir /s /q "%TMP_DIR%"
)

"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%CLAUSE_ROOT%\clause.ps1" %*

endlocal