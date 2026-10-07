# BattLED – battery voltage on the RGB rings

**English** | [Nederlands](README_NL.md)

Lua scripts for the **RadioMaster TX16S MK3** running **EdgeTX**. The RGB rings around the gimbals show the voltage of the flight battery and of the radio battery as a "fuel gauge".

- **Full battery:** the whole ring is green.
- **Battery draining:** the color changes from green through yellow to red. Depending on the display style, the ring also empties (see below).
- **Warning voltage reached:** the whole ring blinks red. Blinking stops once the voltage is back more than 0.10 V per cell above the warning voltage.
- **No telemetry:** the model ring glows dim blue.

## Display styles

| Style | What you see |
|---|---|
| **Gauge (12 o'clock)** | The ring gets shorter counterclockwise, back towards 12 o'clock. When empty, only the LED at 12 o'clock stays lit. |
| **Full ring** | All LEDs stay lit; only the color changes. |
| **Bottle** | The ring empties like a bottle: the level drops from the top on both sides at once. When empty, only the LED at the bottom stays lit. |

For the **Gauge** style:

| Level | Lit part of the ring |
|---|---|
| 100 % | whole ring |
| 75 % | 12 → 9 o'clock |
| 50 % | 12 → 6 o'clock |
| 25 % | 12 → 3 o'clock |
| empty | only the LED at 12 o'clock |

## Requirements

- RadioMaster TX16S MK3 (800×480 color screen, RGB rings around the gimbals)
- EdgeTX with the **RGB leds** special function
- A telemetry sensor for the model's battery voltage, for example `RxBt`, `A1`, `VFAS` or `Cels`

## Contents

| File | Purpose |
|---|---|
| `SCRIPTS/TOOLS/BattLED.lua` | **BattLED Setup** settings screen (SYS → Tools) |
| `SCRIPTS/RGBLED/BatLed.lua` | Drives the RGB rings while flying |
| `SCRIPTS/RGBLED/BatTst.lua` | Test pattern to check the rings |
| `SCRIPTS/BATTLED/lib.lua` | Shared code; this folder also holds the per-model settings |

## Installation

1. Connect the radio to the computer by USB and choose **USB Storage (SD)** on the radio.
2. Copy the `SCRIPTS` folder from this zip file to the root of the SD card. Existing folders are merged.
3. Eject the drive safely and disconnect the radio.

## Setup

1. Power the model and choose **Discover new sensors** on the **Telemetry** page.
2. Open **SYS → Tools → BattLED Setup** with the right model selected.
3. Set the following (saved immediately):

| Setting | Meaning |
|---|---|
| **Sensor** | The telemetry sensor with the model's battery voltage |
| **Battery type** | **LiPo** or **Li-Ion** (see below) |
| **Cell count** | **Auto** or a fixed number of cells (1S–14S) |
| **Blink below** | Voltage per cell at which the ring starts blinking red |
| **LED rings** | What each ring shows (see below) |
| **Display** | Display style: **Gauge (12 o'clock)**, **Full ring** or **Bottle** (see above) |

4. Go to **Model → Special Functions** and add:
   - Switch: **ON**
   - Function: **RGB leds**
   - Value: **BatLed**
   - Repeat: **ON**

Settings are **per model**. They are saved in `SCRIPTS/BATTLED/<modelname>.cfg`. If you rename a model, set it up again. Two models with the same name share their settings.

## Battery types

The ring follows a discharge curve for each battery type, not a straight line. This makes the ring go down more evenly during the flight.

| Type | Whole ring green from | Empty | Default blink below |
|---|---|---|---|
| LiPo | 3.95 V/cell | 3.50 V/cell | 3.50 V/cell |
| Li-Ion | 3.95 V/cell | 2.70 V/cell | 2.70 V/cell |

When you change the battery type, **Blink below** is set to that type's default. You can then adjust it yourself in 0.05 V steps.

**Note for Li-Ion:** 2.70 V is the cell's absolute minimum. Regularly discharging that deep shortens its life. Many pilots use 3.0 V.

## Cell count

- **Auto:** the cell count is worked out from the voltage when the battery is plugged in. This is reliable with a reasonably charged battery (above about 3.6 V per cell). With a nearly empty 5S or larger pack it can come out one cell short.
- **Fixed count:** always correct, even with an empty battery.
- **Cels sensor** (for example FrSky FLVSS): the cell count comes straight from the sensor.

After a battery swap (3 seconds without telemetry) the cell count is detected again.

## LED rings

EdgeTX doesn't let Lua scripts read the stick mode, so this is a setting. In mode 1 and 3 the throttle is on the right.

| Setting | Right ring | Left ring |
|---|---|---|
| R: model L: radio | model | radio |
| L: model R: radio | radio | model |
| Both: model | model | model |
| R: model L: off | model | off |
| L: model R: off | off | model |

The **radio ring** uses the battery range from **Radio Setup → Battery range** (min and max) and blinks at the radio's battery warning voltage. Check that this range matches the battery in your radio, for example 6.6–8.4 V for a 2S Li-Ion pack.

## Test script

With **BatTst** you can check the rings without a model or battery:

1. In **Special Functions**, set the value of **RGB leds** to **BatTst**.
2. Every 3 seconds the level drops one step, from full to empty in 10 steps, in the display style set for the model. Then the ring blinks red for 3 seconds and the cycle starts again.
3. Set the value back to **BatLed** afterwards.

No LED sits exactly at 12 o'clock. The "12 o'clock LED" is about 8° off: slightly clockwise on the right ring, slightly counterclockwise on the left. Because of this, the two rings seem to sit at a slightly different angle.

## Good to know

- **Voltage under load:** at full throttle the voltage sags, so in flight the ring shows a little less than the real charge. The voltage is smoothed, so short dips don't show up straight away.
- **Switch LEDs:** the LEDs of switches SW1–SW6 are not touched.
- **Changes while flying:** the LED script reads the settings again every 5 seconds.
