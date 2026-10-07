-- BattLED shared library
-- Used by /SCRIPTS/TOOLS/BattLED.lua (setup) and /SCRIPTS/RGBLED/BatLed.lua (LED driver).
-- Settings are stored per model in /SCRIPTS/BATTLED/<modelname>.cfg

local M = {}

M.DIR = "/SCRIPTS/BATTLED/"
M.MAX_CELLS = 14

-- Per battery type: resting discharge curve { cell voltage, state of charge % },
-- highest voltage first. At `green` V/cell and above the whole ring is green;
-- at the last curve point (empty) one red LED is left. `warn` is the default
-- per-cell voltage where the whole ring starts blinking red.
M.TYPES = {
  { name = "LiPo", green = 3.95, warn = 3.50, curve = {
      { 4.20, 100 }, { 4.10, 90 }, { 3.95, 75 }, { 3.85, 55 }, { 3.80, 45 },
      { 3.75, 35 }, { 3.70, 25 }, { 3.60, 10 }, { 3.50, 0 } } },
  { name = "Li-Ion", green = 3.95, warn = 2.70, curve = {
      { 4.20, 100 }, { 4.10, 90 }, { 4.00, 80 }, { 3.90, 68 }, { 3.80, 55 },
      { 3.70, 42 }, { 3.60, 30 }, { 3.50, 20 }, { 3.40, 12 }, { 3.30, 7 },
      { 3.20, 4 }, { 3.00, 1 }, { 2.70, 0 } } },
}

-- Lowest voltage of a battery type's curve (0 % charge)
function M.emptyVoltage(batteryType)
  local curve = (M.TYPES[batteryType] or M.TYPES[1]).curve
  return curve[#curve][1]
end

-- What each gimbal ring shows: the model battery, the radio battery or nothing.
-- Lua cannot read the stick mode, so it is a setting: with mode 1/3 the
-- throttle stick is on the right.
M.RINGS = { "R: model  L: radio", "L: model  R: radio", "Both: model",
            "R: model  L: off", "L: model  R: off" }

local ROLES = {
  { left = "radio", right = "model" },
  { left = "model", right = "radio" },
  { left = "model", right = "model" },
  { left = "off",   right = "model" },
  { left = "model", right = "off" },
}

function M.ringRoles(ringSetting)
  return ROLES[ringSetting] or ROLES[1]
end

-- How the level is shown on a ring:
-- 1 = gauge: lit arc clockwise from 12 o'clock, shrinking back to 12 o'clock
-- 2 = full ring: all LEDs lit in the level colour
-- 3 = bottle: lit from the bottom up, emptying on both sides at once
M.STYLES = { "Gauge (12 o'clock)", "Full ring", "Bottle" }

-- LED order and number of lit LEDs for a ring at level p (0..1)
function M.styleLeds(ring, style, p)
  if style == 2 then return ring.order, ring.count end
  if style == 3 then return ring.bottom, M.litCount(p, ring.count) end
  return ring.order, M.litCount(p, ring.count)
end

-- Adjustable range of the warning voltage (per cell)
M.WARN_MIN = 2.50
M.WARN_MAX = 4.20

-- Highest plausible per-cell voltage, used for automatic cell count detection
local DETECT_CELL_MAX = 4.30

local function cfgPath()
  local info = model.getInfo()
  local name = (info and info.name) or ""
  name = string.gsub(name, "[^%w%-_]", "_")
  if name == "" then name = "default" end
  return M.DIR .. name .. ".cfg"
end

function M.loadConfig()
  -- cells = 0 means auto detect
  local cfg = { sensor = "", type = 1, cells = 0, ring = 1, style = 1 }
  local f = io.open(cfgPath(), "r")
  if f then
    local data = io.read(f, 512) or ""
    io.close(f)
    for key, val in string.gmatch(data, "(%w+)=([^\r\n]*)") do
      if key == "sensor" then
        cfg.sensor = val
      elseif key == "type" then
        cfg.type = tonumber(val) or 1
      elseif key == "cells" then
        cfg.cells = tonumber(val) or 0
      elseif key == "warn" then
        cfg.warn = tonumber(val)
      elseif key == "ring" then
        cfg.ring = tonumber(val) or 1
      elseif key == "style" then
        cfg.style = tonumber(val) or 1
      end
    end
  end
  if not M.TYPES[cfg.type] then cfg.type = 1 end
  if not M.RINGS[cfg.ring] then cfg.ring = 1 end
  if not M.STYLES[cfg.style] then cfg.style = 1 end
  if cfg.cells < 0 or cfg.cells > M.MAX_CELLS then cfg.cells = 0 end
  if not cfg.warn or cfg.warn < M.WARN_MIN or cfg.warn > M.WARN_MAX then
    cfg.warn = M.TYPES[cfg.type].warn
  end
  return cfg
end

function M.saveConfig(cfg)
  local f = io.open(cfgPath(), "w")
  if not f then return false end
  io.write(f, "sensor=" .. cfg.sensor .. "\n")
  io.write(f, "type=" .. cfg.type .. "\n")
  io.write(f, "cells=" .. cfg.cells .. "\n")
  io.write(f, string.format("warn=%.2f\n", cfg.warn))
  io.write(f, "ring=" .. cfg.ring .. "\n")
  io.write(f, "style=" .. cfg.style .. "\n")
  io.close(f)
  return true
end

local function sortedIndexes(items)
  table.sort(items, function(a, b) return a.key < b.key end)
  local list = {}
  for i, item in ipairs(items) do list[i] = item.index end
  return list
end

-- Adds to a ring:
--   ring.angle[index]  position of each LED in degrees
--   ring.order         LED indexes clockwise, starting nearest to 12 o'clock
--   ring.bottom        LED indexes from the bottom of the ring to the top
-- Angles follow the EdgeTX convention: 0 = 3 o'clock, 90 = 12 o'clock,
-- counter clockwise positive; direction 1 = the next LED is counter
-- clockwise, -1 = clockwise.
local function orderRing(ring)
  local start = ring.startAngle or ring.start_angle
  local dir = ring.direction
  if not start or not dir then
    start, dir = 90, -1   -- unknown layout: assume clockwise from 12 o'clock
  end
  local half = 180 / ring.count   -- so the LED nearest to 12 o'clock comes first
  local byClock, byHeight = {}, {}
  ring.angle = {}
  for k = 0, ring.count - 1 do
    local index = ring.first + k
    local angle = start + dir * 360 * k / ring.count
    ring.angle[index] = angle
    byClock[#byClock + 1] = { index = index, key = (90 - angle + half) % 360 }
    byHeight[#byHeight + 1] = { index = index, key = math.sin(angle * math.pi / 180) }
  end
  ring.order = sortedIndexes(byClock)
  ring.bottom = sortedIndexes(byHeight)
  return ring
end

-- LED layout of the gimbal rings. TX16S MK3: right = 0-9, left = 10-19
-- (20-25 are the switch LEDs and are left alone). Newer firmware can report
-- the layout itself through getRGBLedInfo().
function M.ringLayout()
  local right = { first = 0, count = 10, startAngle = 190, direction = -1 }
  local left = { first = 10, count = 10, startAngle = 350, direction = 1 }
  if getRGBLedInfo then
    local ok, info = pcall(getRGBLedInfo)
    if ok and type(info) == "table" and type(info.groups) == "table" then
      local g = info.groups
      if g.gimbal_right and g.gimbal_right.count then right = g.gimbal_right end
      if g.gimbal_left and g.gimbal_left.count then left = g.gimbal_left end
    end
  end
  return orderRing(right), orderRing(left)
end

-- Returns the rings showing the model battery (list), the ring showing the
-- radio battery (or nil) and the rings to switch off (list)
function M.selectRings(ringSetting)
  local right, left = M.ringLayout()
  local roles = M.ringRoles(ringSetting)
  local modelRings, radioRing, offRings = {}, nil, {}
  for _, entry in ipairs({ { right, roles.right }, { left, roles.left } }) do
    local ring, role = entry[1], entry[2]
    if role == "model" then
      modelRings[#modelRings + 1] = ring
    elseif role == "radio" then
      radioRing = ring
    else
      offRings[#offRings + 1] = ring
    end
  end
  return modelRings, radioRing, offRings
end

-- Radio battery range and warning voltage from Radio Setup
function M.radioRange()
  local gs = getGeneralSettings() or {}
  local lo = gs.battMin or 6.6
  local hi = gs.battMax or 8.4
  if hi <= lo then hi = lo + 1 end
  return { min = lo, max = hi, warn = gs.battWarn or lo }
end

-- Radio battery voltage and level 0..1, linear over the Radio Setup range
function M.radioBattery(range)
  local v = getValue("tx-voltage") or 0
  local p = (v - range.min) / (range.max - range.min)
  if p < 0 then p = 0 end
  if p > 1 then p = 1 end
  return v, p
end

-- Returns total pack voltage, plus the cell count when the sensor reports
-- individual cells (FrSky FLVSS "Cels" style sensor). Returns nil without telemetry.
function M.readVoltage(sensor)
  if sensor == nil or sensor == "" then return nil end
  local v = getValue(sensor)
  if type(v) == "table" then
    local sum, n = 0, 0
    for _, cell in pairs(v) do
      sum = sum + cell
      n = n + 1
    end
    if n == 0 or sum < 0.5 then return nil end
    return sum, n
  end
  if type(v) ~= "number" or v < 0.5 then return nil end
  return v
end

-- Cell count from pack voltage. Reliable when the pack is reasonably charged
-- (above ~3.6 V/cell); use a fixed cell count otherwise.
function M.detectCells(v)
  local cells = math.ceil(v / DETECT_CELL_MAX)
  if cells < 1 then cells = 1 end
  if cells > M.MAX_CELLS then cells = M.MAX_CELLS end
  return cells
end

-- State of charge (%) from the discharge curve, interpolated between points
local function curveSoc(curve, v)
  if v >= curve[1][1] then return curve[1][2] end
  for i = 2, #curve do
    local hi, lo = curve[i - 1], curve[i]
    if v >= lo[1] then
      return lo[2] + (v - lo[1]) * (hi[2] - lo[2]) / (hi[1] - lo[1])
    end
  end
  return 0
end

-- Ring level 0..1 following the discharge curve: 1 at the `green` voltage
-- and above, 0 at the empty end of the curve
function M.percent(cellVoltage, batteryType)
  local t = M.TYPES[batteryType] or M.TYPES[1]
  local p = curveSoc(t.curve, cellVoltage) / curveSoc(t.curve, t.green)
  if p < 0 then p = 0 end
  if p > 1 then p = 1 end
  return p
end

-- Number of lit LEDs in a ring of `count` LEDs; at least one stays lit
function M.litCount(p, count)
  local lit = math.ceil(p * count)
  if lit < 1 then lit = 1 end
  if lit > count then lit = count end
  return lit
end

-- Green (1.0) -> yellow (0.5) -> red (0.0)
function M.color(p)
  local r, g
  if p >= 0.5 then
    r = math.floor(255 * (1 - p) * 2)
    g = 255
  else
    r = 255
    g = math.floor(255 * p * 2)
  end
  return r, g, 0
end

-- true during the "on" half of the 2 Hz warning blink
function M.blinkOn()
  return (getTime() % 50) < 25
end

return M
