---
name: deploy
description: Deploy the latest EdgeTX config to the RadioMaster TX16S MK3 SD card on D:. Checks that D: is the radio, backs it up, merges TX16S-MK3.etx (and the BattLED Lua scripts) into it without losing changes made on the radio, then safely ejects D:.
disable-model-invocation: true
---

# Deploy to radio (D:)

Run the steps in order. Stop and report if any step fails. Never skip the backup.

Terms: describe switch positions as **forward** (Sx0) / **backward** (Sx2, toward the pilot), never up/down.

## 1. Check D:

- `Test-Path D:\` must be true, and D: must look like the radio's SD card: `D:\edgetx.sdcard.version`, `D:\MODELS` and `D:\RADIO` all exist.
- If not: stop and tell the user to connect the radio by USB and choose **USB Storage (SD)**, then run `/deploy` again.

## 2. Back up the radio's existing models

Do this immediately after D: is confirmed, before reading or changing anything else.

Backups live **outside the project folder** (and outside git), in `..\TX16S-MK3 Backups\` — the sibling folder of the project root (`...\Edge-TX\TX16S-MK3 Backups\`).

- Create `..\TX16S-MK3 Backups\<yyyyMMdd-HHmm>\` (create `TX16S-MK3 Backups\` itself if it does not exist yet).
- Copy all of `D:\MODELS\` into `<that folder>\MODELS\`, and `D:\RADIO\radio.yml` into `<that folder>\RADIO\`.
- Verify the file count and sizes match D: before continuing. If they don't, stop.
- Tell the user the backup folder name.

## 3. Pick the source

Versions are kept by git, not by file names. There is one config file: `TX16S-MK3.etx` in the project root.

- **Source** = `TX16S-MK3.etx` as it is in the working folder. If it has uncommitted changes, say so and ask whether to commit them first.
- **Base** = the version that was last deployed: `git show deployed:TX16S-MK3.etx` (the git tag `deployed`, see step 7). This is the common ancestor for the merge.
  - If the tag does not exist yet (first deploy), there is no base: for every model/radio file where the radio differs from the source, show the differences per setting and ask the user which side to keep. Never overwrite silently.
- A `.etx` is a zip: `RADIO/radio.yml`, `MODELS/modelN.yml`, `MODELS/labels.yml`, and small `MODELS/*.txt` files. Extract source and base into the scratchpad (never into the project folder).
- Tell the user the source commit and the base commit.

## 4. Merge into the radio

Treat each file separately. Compare by **content** (keys and values), not by text lines: the radio writes YAML with different indentation, quoting and key order than Companion, so a line diff is meaningless.

For each `MODELS/modelN.yml` and `RADIO/radio.yml` in the source:

| Situation | Action |
|---|---|
| File not on the radio | Copy it. |
| Radio content == source | Nothing to do. |
| Radio content == base (radio unchanged since the last save) | Overwrite with the source. |
| Radio content differs from both | **3-way merge**: take every change made in the source (source vs base) and apply it to the radio's file, keeping the radio's own changes (radio vs base). Edit the radio file in its own format (indentation/quoting). |
| Same setting changed differently on both sides | Conflict: do **not** guess. Show both values and ask the user which to keep. |

**Registration IDs:** the `.etx` files in this repo have `ownerRegistrationID` and `modelRegistrationID` blanked (`""`) because the repo is public. Never write a blank registration ID to the radio: always keep the radio's existing value for these two fields, whatever the source says.

Also check the header `name:` matches. If modelN on the radio is a *different* model than modelN in the source, stop and ask.

`MODELS/labels.yml`: never overwrite blindly. Make sure every model file that exists on D: has an entry (name from its header). The radio rebuilds the rest itself.

`MODELS/*.txt` (1-byte marker files): copy any that are missing; never delete.

Never delete files from D: unless the user asks.

After editing, check every changed `.yml`:
- no BOM (first bytes are not `239,187,191`), UTF-8;
- references are consistent: every `L<n>` used in mixes, timers, special functions or other logical switches exists in `logicalSw`;
- sound files used by `PLAY_TRACK` exist in `D:\SOUNDS\en\`.

## 5. Lua scripts

Merge the `.lua` files under `Lua\SCRIPTS\` (project) into `D:\SCRIPTS\`, keeping the sub-folder structure:
- copy `.lua` files that are missing on D: or differ (compare hashes);
- for every `.lua` copied, delete the matching compiled `.luac` next to it on D: (if present) so EdgeTX recompiles the new version;
- never touch other files on D:, such as the per-model `*.cfg` settings in `SCRIPTS\BATTLED\`, and never delete anything else.
List what was copied and which `.luac` files were removed.

## 6. Verify

Re-read every file written to D: and compare its hash with the intended content. Report any mismatch and do not eject until it is resolved.

## 7. Mark as deployed

Only if the source was committed (no uncommitted changes in `TX16S-MK3.etx`): move the local tag to that commit with `git tag -f deployed`. This becomes the base for the next deploy. Do not push the tag unless the user asks.

## 8. Eject D:

```powershell
$sh = New-Object -ComObject Shell.Application
$sh.Namespace(17).ParseName('D:').InvokeVerb('Eject')
Start-Sleep -Seconds 3
if (Test-Path D:\) { 'D: still present' } else { 'D: ejected' }
```

If D: is still present, tell the user to close any Explorer windows or programs using D: and eject it from the system tray.

## 9. Report

Summarise briefly:
- backup folder (`..\TX16S-MK3 Backups\<yyyyMMdd-HHmm>\`), source and base commits used, whether the `deployed` tag was moved;
- per file: copied / unchanged / overwritten / merged (and what was merged) / conflicts resolved;
- Lua files copied;
- eject result;
- reminder to bench-test with the prop off (motor cut at power-on, arming sequence, disarm).
