-- RngOff: switches the gimbal RGB rings off, leaving the switch LEDs alone.
-- Use as Special Function "RGB leds" -> RngOff, repeat ON, on the opposite
-- switch of BatLed (e.g. BatLed on SW1 on, RngOff on SW1 off), because the
-- rings keep their last colours when BatLed stops.

local lib = loadScript("/SCRIPTS/BATTLED/lib.lua")()
local rings

local function init()
  local right, left = lib.ringLayout()
  rings = { right, left }
end

local function run()
  for _, ring in ipairs(rings) do
    for k = 0, ring.count - 1 do
      setRGBLedColor(ring.first + k, 0, 0, 0)
    end
  end
  applyRGBLedColors()
end

return { init = init, run = run }
