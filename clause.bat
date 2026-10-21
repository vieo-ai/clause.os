@echo off
rem install.bat - Reads .clause.toml, bootstraps pwsh into .local\bin, and hands off to clause.ps1
setlocal enableextensions enabledelayedexpansion

set "CLAUSE_ROOT=%~dp0"
if "%CLAUSE_ROOT:~-1%"=="\" set "CLAUSE_ROOT=%CLAUSE_ROOT:~0,-1%"

set "CLAUSE_PROJECT_ROOT=%CLAUSE_ROOT%"
set "LOCAL_BIN=%CLAUSE_ROOT%\.local\bin"
set "PWSH_EXE=%LOCAL_BIN%\pwsh.exe"
set "TMP_DIR=%CLAUSE_ROOT%\.cache\tmp_bootstrap"
set "MANIFEST=%CLAUSE_ROOT%\.clause.toml"

if not exist "%LOCAL_BIN%" mkdir "%LOCAL_BIN%"

if exist "%PWSH_EXE%" goto RUN_HANDOFF

if not exist "%MANIFEST%" (
    echo [ClauseOS] Error: Manifest file not found at %MANIFEST%
    exit /b 1
)

set "PWSH_VER="
for /f "usebackq tokens=1,* delims==" %%A in ("%MANIFEST%") do (
    set "KEY=%%A"
    set "KEY=!KEY: =!"
    if "!KEY!"=="pwsh" (
        set "VAL=%%B"
        for /f "tokens=1 delims=#" %%C in ("!VAL!") do set "VAL=%%C"
        for /f "tokens=*" %%D in ("!VAL!") do set "VAL=%%~D"
        set "VAL=!VAL:"=!"
        set "PWSH_VER=!VAL: =!"
    )
)

if "%PWSH_VER%"=="" (
    echo [ClauseOS] Error: Could not parse 'pwsh' version from .clause.toml
    exit /b 1
)

if "%PWSH_VER:~0,1%"=="v" set "PWSH_VER=%PWSH_VER:~1%"

echo [ClauseOS] Seeding PowerShell Core ^(v%PWSH_VER%^) into .local\bin\...
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"

set "PWSH_ASSET=powershell-%PWSH_VER%-win-x64.zip"
set "PWSH_URL=https://github.com/PowerShell/PowerShell/releases/download/v%PWSH_VER%/%PWSH_ASSET%"
set "ZIP_PATH=%TMP_DIR%\%PWSH_ASSET%"

curl.exe -sSL "%PWSH_URL%" -o "%ZIP_PATH%"
if errorlevel 1 (
    echo [ClauseOS] Download failed via curl.exe for URL: %PWSH_URL%
    exit /b 1
)

tar.exe -xf "%ZIP_PATH%" -C "%LOCAL_BIN%"
if exist "%TMP_DIR%" rmdir /s /q "%TMP_DIR%"

:RUN_HANDOFF
"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%CLAUSE_ROOT%\boot.ps1" %*

endlocal