-- BatLed: shows the flight battery level on one RGB gimbal ring and the
-- radio battery on the other (see the LED ring setting).
-- Full battery = whole ring green; as the voltage drops the colour shifts to
-- red and, depending on the display style, the ring empties (gauge from
-- 12 o'clock, or a bottle emptying from the top). At the warning voltage the
-- whole ring blinks red until the voltage is back above it.
-- Configure with the "BattLED Setup" tool, then add a Special Function
-- "RGB leds" -> BatLed, repeat ON.

local lib
local cfg, radioRange
local modelRings, radioRing, offRings
local cells, vFilt
local seenSince, lostSince
local warning, radioWarning = false, false
local lastUpdate, lastCfgLoad = 0, 0

local UPDATE_TICKS = 10      -- 10 ms ticks: refresh LEDs every 100 ms
local CFG_RELOAD_TICKS = 500 -- re-read settings every 5 s
local DETECT_DELAY = 200     -- wait 2 s of stable telemetry before detecting cells
local LOST_RESET = 300       -- 3 s without telemetry = battery swapped, start over
local FILTER = 0.2           -- voltage smoothing against short load dips
local WARN_HYST = 0.10       -- V/cell above the warning voltage before blinking stops
local RADIO_HYST = 0.10      -- V above the radio warning voltage before blinking stops

local FULL = 1              -- level that lights the whole ring

local function loadConfig()
  cfg = lib.loadConfig()
  modelRings, radioRing, offRings = lib.selectRings(cfg.ring)
  radioRange = lib.radioRange()
end

-- Show level p (0..1) on a ring in colour r, g, b using the display style
local function paintRing(ring, r, g, b, p)
  local order, lit = lib.styleLeds(ring, cfg.style, p)
  for i, index in ipairs(order) do
    if i <= lit then
      setRGBLedColor(index, r, g, b)
    else
      setRGBLedColor(index, 0, 0, 0)
    end
  end
end

local function blinkRed()
  if lib.blinkOn() then return 255, 0, 0, FULL end
  return 0, 0, 0, FULL
end

-- Model battery: colour and level
local function modelState(now)
  local v, sensorCells = lib.readVoltage(cfg.sensor)
  if not v then
    lostSince = lostSince or now
    if now - lostSince > LOST_RESET then
      cells, vFilt, seenSince, warning = nil, nil, nil, false
    end
    return 0, 0, 40, FULL   -- dim blue: no telemetry
  end
  lostSince = nil

  if vFilt then
    vFilt = vFilt + FILTER * (v - vFilt)
  else
    vFilt = v
  end

  if cfg.cells > 0 then
    cells = cfg.cells
  elseif sensorCells then
    cells = sensorCells
  elseif not cells then
    seenSince = seenSince or now
    if now - seenSince < DETECT_DELAY then
      return 0, 0, 40, FULL
    end
    cells = lib.detectCells(vFilt)
  end

  local cellV = vFilt / cells

  -- Warning on at the warning voltage, off again once the voltage is
  -- WARN_HYST above it, so it does not flicker around the threshold.
  if cellV <= cfg.warn then
    warning = true
  elseif cellV > cfg.warn + WARN_HYST then
    warning = false
  end
  if warning then return blinkRed() end

  local p = lib.percent(cellV, cfg.type)
  local r, g, b = lib.color(p)
  return r, g, b, p
end

-- Radio battery: colour and level
local function radioState()
  local v, p = lib.radioBattery(radioRange)
  if v <= radioRange.warn then
    radioWarning = true
  elseif v > radioRange.warn + RADIO_HYST then
    radioWarning = false
  end
  if radioWarning then return blinkRed() end

  local r, g, b = lib.color(p)
  return r, g, b, p
end

local function init()
  lib = loadScript("/SCRIPTS/BATTLED/lib.lua")()
  loadConfig()
  lastCfgLoad = getTime()
end

local function run()
  local now = getTime()
  if now - lastUpdate < UPDATE_TICKS then return end
  lastUpdate = now

  if now - lastCfgLoad > CFG_RELOAD_TICKS then
    loadConfig()
    lastCfgLoad = now
  end

  local r, g, b, lit = modelState(now)
  for _, ring in ipairs(modelRings) do
    paintRing(ring, r, g, b, lit)
  end
  if radioRing then
    paintRing(radioRing, radioState())
  end
  for _, ring in ipairs(offRings) do
    paintRing(ring, 0, 0, 0, 0)
  end
  applyRGBLedColors()
end

return { init = init, run = run }
