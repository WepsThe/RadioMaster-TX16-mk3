---
name: deploy
description: Copy this project's EdgeTX Lua scripts to the RadioMaster TX16 MK3's SD card (drive D: by default). Use when the user asks to deploy, upload, install or copy the scripts to the radio.
---

# Deploy scripts to the radio

The radio's SD card shows up as a USB drive (normally `D:`) when the radio is connected and **USB Storage (SD)** is chosen on the radio.

## Steps

1. Run a dry run first to check the drive and show what will be copied:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File ".claude/skills/deploy/deploy.ps1" -DryRun
   ```

   If the user named another drive letter, add `-Drive E:`.

2. If the dry run reports an error (drive missing, or not an EdgeTX SD card), stop and tell the user what to do (connect the radio, select USB Storage, check the drive letter). Do not copy.

3. Otherwise run the same command without `-DryRun` to copy the files.

4. Report which files were new or updated, and remind the user to eject the drive safely before unplugging the radio.

## What the script does

- Checks that the drive exists and looks like an EdgeTX SD card (`RADIO`, `MODELS` or `edgetx.sdcard.version` present).
- Copies every `.lua` file under the project's `SCRIPTS/` folder to the same path under `<drive>\SCRIPTS\`, creating folders as needed.
- Deletes the matching `.luac` (compiled) file on the radio so EdgeTX recompiles the new version.
- Never touches other files on the SD card, such as the per-model `*.cfg` settings in `SCRIPTS\BATTLED\`.
