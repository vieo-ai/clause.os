# boot.ps1 - Cross-Platform Stage 0 Microkernel & Confined Profile Bootloader
$ErrorActionPreference = 'Stop'

# ==============================================================================
# RESOLVE ROOT & LOAD CANONICAL ENVIRONMENT
# ==============================================================================
$ProjectRoot = if ($env:CLAUSE_PROJECT_ROOT) { $env:CLAUSE_PROJECT_ROOT } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$env:CLAUSE_PROJECT_ROOT = $ProjectRoot

# Ingest the Single Source of Truth
$EnvScript = Join-Path $ProjectRoot "scripts\cli\pwsh\config\env.ps1"
if (-not (Test-Path $EnvScript)) {
    throw "[ClauseOS] Critical: Canonical environment file missing at $EnvScript"
}
. $EnvScript

# Detect OS flags
$IsOSWindows = $IsWindows -or $env:OS -eq "Windows_NT"

# Ensure hermetic AppData trees exist so nu and cosign/TUF never hit missing dirs
if ($IsOSWindows) {
    $WinRoaming = Join-Path $env:CLAUSE_HOME "AppData\Roaming"
    $WinLocal   = Join-Path $env:CLAUSE_HOME "AppData\Local"
    @($WinRoaming, $WinLocal) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
    }
}

$IsOSMac   = $IsMacOS -or ($PSVersionTable.OS -like "*Darwin*")
$IsOSLinux = -not $IsOSWindows -and -not $IsOSMac

# ==============================================================================
# LOGGING SYSTEM INITIALIZATION
# ==============================================================================
$LogDir  = $env:CLAUSE_LOGS_DIR
$LogFile = Join-Path $LogDir "bootstrap.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
}

function Write-ClauseLog {
    param (
        [Parameter(Mandatory=$true)] [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")] [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry  = "[$Timestamp] [$Level] $Message"

    try {
        Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
    } catch {
        # Fallback if log file is temporarily locked
    }

    switch ($Level) {
        "INFO"  { Write-Host "[ClauseOS] $Message" -ForegroundColor Cyan }
        "WARN"  { Write-Host "[ClauseOS WARN] $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[ClauseOS ERROR] $Message" -ForegroundColor Red }
        "FATAL" { Write-Host "[ClauseOS FATAL] $Message" -ForegroundColor DarkRed }
        "DEBUG" { Write-Host "[ClauseOS DEBUG] $Message" -ForegroundColor DarkGray }
    }
}

Write-ClauseLog "Initializing ClauseOS Microkernel Bootloader..." -Level INFO
Write-ClauseLog "Context: Root=$ProjectRoot | Home=$env:CLAUSE_HOME | OS(Windows=$IsOSWindows, Linux=$IsOSLinux, Mac=$IsOSMac)" -Level DEBUG

# ==============================================================================
# TARGET DIRECTORY PROVISIONING
# ==============================================================================
$LocalBin    = $env:CLAUSE_BIN_DIR
$AppDir      = $env:CLAUSE_APPS_DIR
$TmpDir      = $env:CLAUSE_TEMP_DIR
$Manifest    = Join-Path $ProjectRoot ".clause.toml"
$NuConfigDir = $env:NU_CONFIG_DIR

if (-not (Test-Path $Manifest)) {
    Write-ClauseLog "Manifest file missing at path: $Manifest" -Level FATAL
    throw "[ClauseOS] Error: Manifest file not found at $Manifest"
}

function Get-TomlValue([string]$Content, [string]$Key) {
    $Pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*"([^"]+)"'
    $Match = [regex]::Match($Content, $Pattern)
    if ($Match.Success) { return $Match.Groups[1].Value }
    return $null
}

function Get-File([string]$Url, [string]$OutFile) {
    Write-ClauseLog "Downloading asset: $Url -> $OutFile" -Level DEBUG
    try {
        if ($IsOSWindows) {
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                curl.exe -sSL "$Url" -o "$OutFile"
                if ($LASTEXITCODE -ne 0) { throw "curl.exe exited with code $LASTEXITCODE" }
            } else {
                Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
            }
        } else {
            if (Get-Command curl -ErrorAction SilentlyContinue) {
                curl -sSL "$Url" -o "$OutFile"
                if ($LASTEXITCODE -ne 0) { throw "curl exited with code $LASTEXITCODE" }
            } else {
                Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
            }
        }
    } catch {
        Write-ClauseLog "Download failed for URL '$Url': $_" -Level ERROR
        throw "[ClauseOS] Download failed via curl for URL: $Url"
    }
}

function Expand-HermeticArchive([string]$ArchivePath, [string]$DestinationPath) {
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    }

    Write-ClauseLog "Extracting archive: $ArchivePath -> $DestinationPath" -Level DEBUG
    try {
        if ($IsOSWindows) {
            if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
                tar.exe -xf "$ArchivePath" -C "$DestinationPath"
                if ($LASTEXITCODE -ne 0) { throw "tar.exe failed with code $LASTEXITCODE" }
            } else {
                Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
            }
        } else {
            $NativeTar = if (Test-Path "/usr/bin/tar") { "/usr/bin/tar" } elseif (Test-Path "/bin/tar") { "/bin/tar" } else { "tar" }
            & $NativeTar -xf "$ArchivePath" -C "$DestinationPath"
            if ($LASTEXITCODE -ne 0) { throw "$NativeTar failed with code $LASTEXITCODE" }
        }
    } catch {
        Write-ClauseLog "Archive extraction failed for '$ArchivePath': $_" -Level ERROR
        throw $_
    }
}

function Install-ExtractedArchive([string]$ExtractTarget, [string]$DestinationPath) {
    if (-not $ExtractTarget.StartsWith($TmpDir)) {
        Write-ClauseLog "Extraction target $ExtractTarget is outside $TmpDir" -Level FATAL
        throw "[ClauseOS] Critical Error: Extraction target $ExtractTarget is outside $TmpDir"
    }

    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    }

    $ChildItems = Get-ChildItem -Path $ExtractTarget -Force -ErrorAction Stop
    if ($ChildItems.Count -eq 0) {
        Write-ClauseLog "Extraction target directory is empty: $ExtractTarget" -Level ERROR
        throw "[ClauseOS] Error: Extract target is empty: $ExtractTarget"
    }

    try {
        if ($ChildItems.Count -eq 1 -and $ChildItems[0].PSIsContainer) {
            Write-ClauseLog "Moving single container content '$($ChildItems[0].Name)' to $DestinationPath" -Level DEBUG
            Get-ChildItem -Path $ChildItems[0].FullName -Force | Move-Item -Destination $DestinationPath -Force
        } else {
            Write-ClauseLog "Moving extracted directory contents to $DestinationPath" -Level DEBUG
            Get-ChildItem -Path $ExtractTarget -Force | Move-Item -Destination $DestinationPath -Force
        }
    } catch {
        Write-ClauseLog "Failed to move extracted archive to '$DestinationPath': $_" -Level ERROR
        throw $_
    }
}

function Set-PosixExecutable([string]$FilePath) {
    if (-not $IsOSWindows) {
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            chmod +x "$FilePath" 2>$null
            Write-ClauseLog "Applied chmod +x to $FilePath" -Level DEBUG
        }
    }
}

try {
    $TomlContent = Get-Content -Path $Manifest -Raw
} catch {
    Write-ClauseLog "Unable to read manifest file: $_" -Level FATAL
    throw $_
}

# Provision Core System Directories
@($LocalBin, $AppDir, $TmpDir, $NuConfigDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
}

# ==============================================================================
# MODULAR RECIPE EXECUTION (STAGE 0 & STAGE 1)
# ==============================================================================
$InstallerDir = Join-Path $ProjectRoot "scripts/cli/pwsh/installers"

$InstallerPipeline = @(
    @{ Name = "Mise";       Key = "mise";       Script = "installer_mise.ps1" },
    @{ Name = "Just";       Key = "just";       Script = "installer_just.ps1" },
    @{ Name = "Nushell";    Key = "nu";         Script = "installer_nu.ps1" },
    @{ Name = "Lemonade";   Key = "lemonade";   Script = "installer_lemonade.ps1" },
    @{ Name = "FastFlowLM"; Key = "fastflowlm"; Script = "installer_fastflowlm.ps1"; Skip = $IsOSMac },
    @{ Name = "APM";        Key = "apm";        Script = "installer_apm.ps1" },
    @{ Name = "VSCode";     Key = "vscode";     Script = "installer_vscode.ps1" },
    @{ Name = "Pulumi";     Key = "pulumi";     Script = "installer_pulumi.ps1" }
)

foreach ($Tool in $InstallerPipeline) {
    if ($Tool.Skip) { continue }

    $Version = Get-TomlValue -Content $TomlContent -Key $Tool.Key
    if (-not $Version) {
        Write-ClauseLog "Missing required version definition for '$($Tool.Key)' in .clause.toml" -Level FATAL
        throw "[ClauseOS] Error: Missing required version definition for '$($Tool.Key)' in .clause.toml"
    }

    $ScriptPath = Join-Path $InstallerDir $Tool.Script
    if (-not (Test-Path $ScriptPath)) {
        Write-ClauseLog "Installer recipe missing at: $ScriptPath" -Level FATAL
        throw "[ClauseOS] Error: Installer recipe not found at $ScriptPath"
    }

    # Execute modular installer recipe
    & $ScriptPath -Version $Version
}

# Cleanup transient downloads
if (Test-Path $TmpDir) {
    Write-ClauseLog "Cleaning up temporary extraction folder: $TmpDir" -Level DEBUG
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Windows Profile Attribute Protection
if ($IsOSWindows) {
    if (Get-Command attrib.exe -ErrorAction SilentlyContinue) {
        attrib.exe +h "$($env:CLAUSE_HOME)" 2>$null
    }
}

# ==============================================================================
# GENERATE NUSHELL MISE ACTIVATION OVERLAY
# ==============================================================================
$ExeExt  = if ($IsOSWindows) { ".exe" } else { "" }
$MiseBin = Join-Path $LocalBin "mise$ExeExt"
$NuBin   = Join-Path $LocalBin "nu$ExeExt"
$MiseNu  = Join-Path $NuConfigDir "mise.nu"

if ((Test-Path $MiseBin) -and (Test-Path $NuBin)) {
    Write-ClauseLog "Syncing Mise Nushell overlay..." -Level INFO
    try {
        & $NuBin -c "^'$MiseBin' activate nu | save '$MiseNu' --force"
    } catch {
        Write-ClauseLog "Failed to sync Mise overlay with Nushell: $_" -Level ERROR
    }
}

# Install Mise Dependencies (Userland Tools)
Write-ClauseLog "Finalizing ClauseOS toolchain installation..." -Level INFO
& $MiseBin install
if ($LASTEXITCODE -ne 0) {
    Write-ClauseLog "Mise installation failed with exit code $LASTEXITCODE" -Level FATAL
    exit $LASTEXITCODE
}

# ==============================================================================
# STAGE 2: NUSHELL HANDOFF (CLI, CI/CD NON-INTERACTIVE, & TTY ROUTING)
# ==============================================================================
Set-Location -Path $ProjectRoot

$EnvNu    = Join-Path $ProjectRoot "scripts/cli/nu/core/boot.nu"
$ConfigNu = Join-Path $NuConfigDir "config.nu"
$IsNonInteractive = [Console]::IsInputRedirected -or $env:CI -eq "true"

Write-ClauseLog "Performing Nushell handoff (Interactive=$(-not $IsNonInteractive))..." -Level INFO

if (Test-Path $NuBin) {
    if (Test-Path $EnvNu) {
        if ($args.Count -gt 0) {
            $CommandString = $args -join " "
            & $NuBin --env-config $EnvNu -c "clause $CommandString"
            exit $LASTEXITCODE
        } elseif ($IsNonInteractive) {
            & $NuBin --env-config $EnvNu -c "clause boot:check"
            exit $LASTEXITCODE
        } else {
            if (Test-Path $ConfigNu) {
                & $NuBin --env-config $EnvNu --config $ConfigNu -e "clause banner"
            } else {
                & $NuBin --env-config $EnvNu -e "clause banner"
            }
        }
    } else {
        Write-ClauseLog "Environment file missing at $EnvNu. Booting default Nushell shell..." -Level WARN
        & $NuBin
    }
} else {
    Write-ClauseLog "Nushell executable missing at $NuBin." -Level FATAL
    exit 1
}