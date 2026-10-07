-- BatTst: test pattern for the BattLED rings.
-- Both rings count down from full to empty in 10 steps, one step every
-- 3 seconds, then blink red for 3 seconds and start again.
-- Uses the display style set in BattLED Setup for the current model, with the
-- same LED order and colours as BatLed.
-- Special Function "RGB leds" -> BatTst, repeat ON.

local lib
local cfg
local rings
local startTime
local lastUpdate = 0

local STEP_TICKS = 300    -- 10 ms ticks: 3 s per step
local UPDATE_TICKS = 10

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

local function init()
  lib = loadScript("/SCRIPTS/BATTLED/lib.lua")()
  cfg = lib.loadConfig()
  local right, left = lib.ringLayout()
  rings = { right, left }
  startTime = getTime()
end

local function run()
  local now = getTime()
  if now - lastUpdate < UPDATE_TICKS then return end
  lastUpdate = now

  local count = rings[1].count
  local step = math.floor((now - startTime) / STEP_TICKS) % (count + 1)

  for _, ring in ipairs(rings) do
    if step == count then
      -- last step: warning blink
      if lib.blinkOn() then
        paintRing(ring, 255, 0, 0, 1)
      else
        paintRing(ring, 0, 0, 0, 1)
      end
    else
      local p = (count - 1 - step) / (count - 1)   -- 1 = full, 0 = empty
      local r, g, b = lib.color(p)
      paintRing(ring, r, g, b, p)
    end
  end
  applyRGBLedColors()
end

return { init = init, run = run }
