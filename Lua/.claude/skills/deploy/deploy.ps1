# Copies the Lua scripts from this project to the radio's SD card.
# Usage: deploy.ps1 [-Drive D:] [-DryRun]
param(
    [string]$Drive = "D:",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$source = Join-Path $projectRoot "SCRIPTS"
$Drive = $Drive.TrimEnd("\")
$target = "$Drive\SCRIPTS"

if (-not (Test-Path "$Drive\")) {
    Write-Output "ERROR: Drive $Drive is not available. Connect the radio via USB and choose 'USB Storage (SD)'."
    exit 1
}

$markers = @("RADIO", "MODELS", "edgetx.sdcard.version")
$found = $markers | Where-Object { Test-Path (Join-Path "$Drive\" $_) }
if (-not $found) {
    Write-Output "ERROR: Drive $Drive does not look like an EdgeTX SD card (no RADIO, MODELS or edgetx.sdcard.version)."
    exit 1
}

if (-not (Test-Path $source)) {
    Write-Output "ERROR: Source folder $source not found."
    exit 1
}

# Only .lua files are deployed. Per-model settings (*.cfg) on the radio are never touched.
$files = Get-ChildItem -Path $source -Recurse -File -Filter "*.lua"
if (-not $files) {
    Write-Output "Nothing to deploy: no .lua files in $source."
    exit 0
}

$prefix = if ($DryRun) { "[dry run] " } else { "" }
Write-Output "${prefix}Deploying $($files.Count) file(s) from $source to $target"

foreach ($file in $files) {
    $relative = $file.FullName.Substring($source.Length).TrimStart("\")
    $dest = Join-Path $target $relative
    $destDir = Split-Path $dest -Parent
    $compiled = "${dest}c"   # .luac compiled by EdgeTX

    $state = if (Test-Path $dest) { "update" } else { "new" }
    Write-Output "${prefix}  $state  SCRIPTS\$relative"

    if (-not $DryRun) {
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $file.FullName -Destination $dest -Force
        # Remove the stale compiled version so EdgeTX recompiles the new script
        if (Test-Path $compiled) {
            Remove-Item -Path $compiled -Force -Confirm:$false
            Write-Output "${prefix}          removed old SCRIPTS\${relative}c"
        }
    }
}

Write-Output "${prefix}Done. Eject the drive safely before unplugging the radio."
