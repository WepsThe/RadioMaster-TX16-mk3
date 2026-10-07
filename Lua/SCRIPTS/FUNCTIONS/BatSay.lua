-- BatSay: spoken model battery voltage
-- Special function "Lua Script" (repeat On), switch = armed.
--   - every 30 s: the pack voltage
--   - below 3.55 V per cell: "low battery" + haptic every 5 s
-- Sensor and cell count come from the model's BattLED settings
-- (SYS -> Tools -> BattLED Setup). Cells = Auto: detected from the pack
-- voltage at the first reading after arming (pack should be charged).

local CALLOUT_INTERVAL = 3000   -- 10 ms ticks: 30 s
local WARN_INTERVAL = 500       -- 5 s
local WARN_CELL = 3.55          -- V per cell
local WARN_DEBOUNCE = 200       -- must stay low for 2 s (ignores short sag on punch-outs)
local FALLBACK_SENSORS = { "RxBt", "Volt", "VFAS", "Cels", "A1" }

local lib, cfg
local cells, nextCallout, nextWarn, lowSince
local active = false

local function reset()
  cells, nextCallout, nextWarn, lowSince = nil, nil, nil, nil
end

local function readVoltage()
  local v, n = lib.readVoltage(cfg.sensor)
  if v then return v, n end
  for _, name in ipairs(FALLBACK_SENSORS) do
    v, n = lib.readVoltage(name)
    if v then return v, n end
  end
end

local function init()
  lib = loadScript("/SCRIPTS/BATTLED/lib.lua")()
  cfg = lib.loadConfig()
  reset()
end

local function run()
  if not active then
    -- (re)armed: reload settings and detect the cell count again
    active = true
    cfg = lib.loadConfig()
    reset()
  end

  local v, sensorCells = readVoltage()
  if not v then return end   -- no telemetry

  if not cells then
    cells = sensorCells or (cfg.cells > 0 and cfg.cells) or lib.detectCells(v)
  end

  local now = getTime()
  if not nextCallout then nextCallout = now end

  if v / cells < WARN_CELL then
    lowSince = lowSince or now
    if now - lowSince >= WARN_DEBOUNCE and (not nextWarn or now >= nextWarn) then
      playFile("lowbat.wav")
      playHaptic(30, 20)
      nextWarn = now + WARN_INTERVAL
    end
  else
    lowSince, nextWarn = nil, nil
  end

  if now >= nextCallout then
    playNumber(math.floor(v * 10 + 0.5), UNIT_VOLTS, PREC1)
    nextCallout = now + CALLOUT_INTERVAL
  end
end

local function background()
  active = false
end

return { init = init, run = run, background = background }
