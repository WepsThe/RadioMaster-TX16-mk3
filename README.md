# RadioMaster TX16S MK3

EdgeTX setup for my RadioMaster TX16S MK3: model configurations, Lua scripts and a deploy workflow.

## Contents

| Path | What it is |
|---|---|
| `TX16S-MK3.etx` | EdgeTX Companion file with the radio settings and models. Earlier versions are in the git history. |
| `Lua/` | **BattLED**: shows flight and radio battery voltage on the RGB rings around the gimbals. See [Lua/README.md](Lua/README.md). |
| `.claude/skills/deploy/` | `/deploy` skill for Claude Code: backs up the radio, merges `TX16S-MK3.etx` and the Lua scripts onto the SD card (D:), then ejects it. |

A `.etx` file is a zip with `RADIO/radio.yml` and `MODELS/modelN.yml`; open it in EdgeTX Companion.

Registration IDs (`ownerRegistrationID`, `modelRegistrationID`) are blanked in this public repo. Writing the `.etx` to the radio with Companion clears the radio's IDs; `/deploy` keeps them.

## Default model: throttle-cut arming

Switch positions: **forward** = away from you, **backward** = toward you.

1. SF **backward**, throttle stick below −98 → motor cut.
2. Move SF **forward** with the throttle still low → a 3-second window opens.
3. Hold SH **backward** for 0.5 s inside the window → armed (siren + "armed"), flight timer starts.
4. SF **backward** → disarmed ("disarmed").

| LS | Function | Role |
|---|---|---|
| L1 | Thr < −98 | Throttle low |
| L2 | Thr > −98 | Throttle not low |
| L3 | L1 AND SF backward | Ready |
| L4 | Sticky (set L3, reset L2) | Primed: ready, throttle still low |
| L5 | L4 AND SF forward | Window open |
| L6 | L4 AND SF forward, delay 3 s | Window closed |
| L7 | SH backward AND L5, delay 0.5 s, only while !L6 | SH held in time |
| L8 | Sticky (set L7, reset SF backward) | **Armed** |

The CH3 "Cut" mix (−100, replace) is active on `!L8`.

Always bench-test with the prop removed.
