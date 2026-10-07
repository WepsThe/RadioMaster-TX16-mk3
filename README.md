# RadioMaster TX16S MK3

EdgeTX setup for my RadioMaster TX16S MK3: model configurations, Lua scripts and a deploy workflow.

## Contents

| Path | What it is |
|---|---|
| `TX16S-MK3.etx` | EdgeTX Companion file with the radio settings and models. Earlier versions are in the git history. |
| `Lua/` | **BattLED**: shows flight and radio battery voltage on the RGB rings around the gimbals. See [Lua/README.md](Lua/README.md). |
| `Lua/SCRIPTS/` | Mirror of the radio's `SCRIPTS` folder (without compiled `.luac`): BattLED plus the other scripts on the radio (ExpressLRS, FlightsHistory, locator_by_rssi, RGBLED effects, setGyro, ...). Third-party scripts keep their own licences. |
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
| L9 | L8 AND SE forward | → FM1 Start |
| L10 | L8 AND SE middle | → FM2 Flight |
| L11 | L8 AND SE backward | → FM3 Landing |

The CH3 "Cut" mix (−100, replace) is active on `!L8`.

### Flight modes (SE, only when armed)

| State | Flight mode | Sound |
|---|---|---|
| Disarmed | FM0 Disarmed (fallback) | — ("disarmed" is already played) |
| Armed + SE forward | FM1 Start | `start` |
| Armed + SE middle | FM2 Flight | `fm-nrm` |
| Armed + SE backward | FM3 Landing | `fm-lnd` |

The sound plays once each time the flight mode becomes active (special functions SF4–SF6, Play Track, repeat 1x). Arming with SE already set plays "armed" followed by that mode's sound.

All flight modes share FM0's trims.

### BattLED rings on custom switch 1

SF62 (RGB LEDs → `BatLed`) is active on **SW1** (`SW12` = on). SW1 is a toggle, outside any group, and starts on.

| SW1 | LED | Gimbal rings |
|---|---|---|
| On | green | BattLED battery gauge |
| Off | red | BattLED off |

### Battery callouts (only when armed)

SF7 runs the Lua function script `SCRIPTS/FUNCTIONS/BatSay.lua` while L8 (armed) is on:

- every 30 s it says the pack voltage;
- below **3.55 V per cell** it plays "lowbat" with a haptic pulse every 5 s. The voltage must stay low for 2 s first, so short sag on a punch-out doesn't trigger it.

It reads the sensor and cell count from the model's BattLED settings (SYS → Tools → BattLED Setup). If no sensor is set, it tries `RxBt`, `Volt`, `VFAS`, `Cels`, `A1`. With Cells = Auto, it detects the cell count from the first reading after arming, so arm with a charged pack (or set the cell count). Discover the model's telemetry sensors first.

Always bench-test with the prop removed.
