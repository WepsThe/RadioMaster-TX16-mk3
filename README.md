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

## Models

| File | Model | Notes |
|---|---|---|
| `model1.yml` | **Ares** | Copy of the Default model, with picture `Ares.png`. Everything below applies to it too. |
| `model2.yml` | **Default** | Template for new models. |

## Default model: RF module

Internal RF: **CRSF** (ExpressLRS), 16 channels, receiver number **4** (ELRS Model Match). ELRS arming mode is **Switch** with L8 (armed), because CH5 is the right aileron in this model.

## Default model: throttle-cut arming

Switch positions: **forward** = away from you, **backward** = toward you.

1. SF **backward**, throttle stick below −98 → motor cut.
2. Move SF **forward** with the throttle still low → a 3-second window opens.
3. Press custom switch **SW1** (red) inside the window → after 0.5 s armed: SW1 turns **green**, siren + "armed", flight timer starts.
4. SF **backward** → disarmed ("disarmed"), SW1 turns **red** again.

| LS | Function | Role |
|---|---|---|
| L1 | Thr < −98 | Throttle low |
| L2 | Thr > −98 | Throttle not low |
| L3 | L1 AND SF backward | Ready |
| L4 | Sticky (set L3, reset L2) | Primed: ready, throttle still low |
| L5 | L4 AND SF forward | Window open |
| L6 | L4 AND SF forward, delay 3 s | Window closed |
| L7 | SW1 on AND L5, delay 0.5 s, only while !L6 | SW1 pressed in time |
| L8 | Sticky (set L7, reset SF backward) | **Armed** |
| L9 | L8 AND SE forward | → FM1 Start |
| L10 | L8 AND SE middle | → FM2 Flight |
| L11 | L8 AND SE backward | → FM3 Landing |
| L12 | SW1 on AND !L8, delay 1 s | Pressed but not armed → SF8 pushes SW1 back to red |
| L13 | L8 AND SW1 off | Pressed while armed → SF9 pushes SW1 back to green |
| L14 | SW1 on AND SF backward | Disarmed → SF10 pushes SW1 to red at once |

The CH3 "Cut" mix (−100, replace) is active on `!L8`.

SW1 is a latching custom switch (starts off, red when off, green when on). SF8–SF10 use **Push CS** (SW1, 0.1 s), so the LED always shows the armed state.

### Flight modes (SE, only when armed)

| State | Flight mode | Sound |
|---|---|---|
| Disarmed | FM0 Disarmed (fallback) | — ("disarmed" is already played) |
| Armed + SE forward | FM1 Start | `start` |
| Armed + SE middle | FM2 Flight | `fm-nrm` |
| Armed + SE backward | FM3 Landing | `fm-lnd` |

The sound plays once each time the flight mode becomes active (special functions SF4–SF6, Play Track, repeat 1x). Arming with SE already set plays "armed" followed by that mode's sound.

All flight modes share FM0's trims.

### BattLED rings on custom switch 6

SF62 (RGB LEDs → `BatLed`) is active on **SW6** (`SW62` = on). SW6 is a toggle, outside any group, and starts on.

| SW6 | LED | Gimbal rings |
|---|---|---|
| On | green | BattLED battery gauge |
| Off | red | dark (SF61 runs `RngOff`) |

The rings keep their last colours when BatLed stops, so SF61 (RGB LEDs → `RngOff`, on `SW60` = SW6 off) blanks the two gimbal rings. It leaves the switch LEDs alone.

### Battery callouts (only when armed)

SF7 runs the Lua function script `SCRIPTS/FUNCTIONS/BatSay.lua` while L8 (armed) is on:

- every 30 s it says the pack voltage;
- below **3.55 V per cell** it plays "lowbat" with a haptic pulse every 5 s. The voltage must stay low for 2 s first, so short sag on a punch-out doesn't trigger it.

It reads the sensor and cell count from the model's BattLED settings (SYS → Tools → BattLED Setup). If no sensor is set, it tries `RxBt`, `Volt`, `VFAS`, `Cels`, `A1`. With Cells = Auto, it detects the cell count from the first reading after arming, so arm with a charged pack (or set the cell count). Discover the model's telemetry sensors first.

Always bench-test with the prop removed.
