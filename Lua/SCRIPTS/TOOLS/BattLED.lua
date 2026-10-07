local toolName = "TNS|BattLED Setup|TNE"

-- BattLED Setup: choose the battery voltage sensor, battery type, cell count,
-- warning voltage, LED rings and display style for the current model.
-- Settings are saved immediately on every change.
-- Rotary: scroll / ENTER to edit / scroll to change / ENTER or EXIT to finish.
-- Touch:  tap the < and > buttons.

local lib, cfg, radioRange
local rightRing, leftRing
local sensors = {}
local modelName = ""
local sel = 1
local editing = false
local status = ""

local LABELS = { "Sensor", "Battery type", "Cell count", "Blink below", "LED rings", "Display" }
local NUM_ROWS = #LABELS

local HEADER_H = 50
local ROW_Y = 58
local ROW_H = 48
local BTN_W = 80

local function loadSensors()
  sensors = {}
  for i = 0, 59 do
    local s = model.getSensor(i)
    if s and s.name and s.name ~= "" then
      sensors[#sensors + 1] = s.name
    end
  end
end

local function valueText(row)
  if row == 1 then
    if cfg.sensor == "" then return "(none)" end
    return cfg.sensor
  elseif row == 2 then
    local t = lib.TYPES[cfg.type]
    return string.format("%s  (%.2f - %.2f V)", t.name, lib.emptyVoltage(cfg.type), t.green)
  elseif row == 3 then
    if cfg.cells == 0 then return "Auto" end
    return cfg.cells .. "S"
  elseif row == 4 then
    return string.format("%.2f V per cell", cfg.warn)
  elseif row == 5 then
    return lib.RINGS[cfg.ring]
  else
    return lib.STYLES[cfg.style]
  end
end

-- Steps a 1..n setting up or down with wrap-around
local function cycle(value, dir, n)
  value = value + dir
  if value < 1 then value = n end
  if value > n then value = 1 end
  return value
end

local function change(row, dir)
  if row == 1 then
    if #sensors == 0 then return end
    local idx = 0
    for i, name in ipairs(sensors) do
      if name == cfg.sensor then idx = i end
    end
    cfg.sensor = sensors[cycle(idx, dir, #sensors)]
  elseif row == 2 then
    cfg.type = cycle(cfg.type, dir, #lib.TYPES)
    cfg.warn = lib.TYPES[cfg.type].warn
  elseif row == 3 then
    cfg.cells = (cfg.cells + dir) % (lib.MAX_CELLS + 1)
  elseif row == 4 then
    local w = math.floor((cfg.warn + dir * 0.05) * 100 + 0.5) / 100
    if w < lib.WARN_MIN then w = lib.WARN_MIN end
    if w > lib.WARN_MAX then w = lib.WARN_MAX end
    cfg.warn = w
  elseif row == 5 then
    cfg.ring = cycle(cfg.ring, dir, #lib.RINGS)
  else
    cfg.style = cycle(cfg.style, dir, #lib.STYLES)
  end
  if lib.saveConfig(cfg) then
    status = "Saved"
  else
    status = "Save failed: is " .. lib.DIR .. " on the SD card?"
  end
end

local function rowY(row)
  return ROW_Y + (row - 1) * ROW_H
end

local function buttonsX()
  return LCD_W - 20 - 2 * BTN_W - 10, LCD_W - 20 - BTN_W
end

local function drawRow(row)
  local y = rowY(row)
  local h = ROW_H - 8
  local bg, fg = COLOR_THEME_PRIMARY2, COLOR_THEME_PRIMARY1
  if row == sel then
    bg = editing and COLOR_THEME_EDIT or COLOR_THEME_FOCUS
    fg = COLOR_THEME_PRIMARY2
  end
  lcd.drawFilledRectangle(10, y, LCD_W - 20, h, bg)
  lcd.drawText(30, y + h / 2, LABELS[row], MIDSIZE + VCENTER + fg)
  lcd.drawText(250, y + h / 2, valueText(row), MIDSIZE + BOLD + VCENTER + fg)

  local lx, rx = buttonsX()
  lcd.drawFilledRectangle(lx, y + 4, BTN_W, h - 8, COLOR_THEME_SECONDARY1)
  lcd.drawFilledRectangle(rx, y + 4, BTN_W, h - 8, COLOR_THEME_SECONDARY1)
  lcd.drawText(lx + BTN_W / 2, y + h / 2, "<", MIDSIZE + CENTER + VCENTER + COLOR_THEME_PRIMARY2)
  lcd.drawText(rx + BTN_W / 2, y + h / 2, ">", MIDSIZE + CENTER + VCENTER + COLOR_THEME_PRIMARY2)
end

-- Preview of one gimbal ring at level p (0..1) in the selected display
-- style. The LEDs are drawn at their real positions. color = nil: all dark.
local function drawRing(cx, cy, label, ring, p, color)
  local R = 46
  local lit = {}
  if color then
    local order, n = lib.styleLeds(ring, cfg.style, p)
    for i = 1, n do lit[order[i]] = true end
  end
  for index, angle in pairs(ring.angle) do
    local a = angle * math.pi / 180
    local x = math.floor(cx + R * math.cos(a) + 0.5)
    local y = math.floor(cy - R * math.sin(a) + 0.5)
    if lit[index] then
      lcd.drawFilledCircle(x, y, 8, color)
    else
      lcd.drawCircle(x, y, 8, COLOR_THEME_DISABLED)
    end
  end
  lcd.drawText(cx, cy, label, MIDSIZE + CENTER + VCENTER + COLOR_THEME_PRIMARY1)
end

local RED = lcd.RGB(255, 0, 0)
local DIM_BLUE = lcd.RGB(0, 0, 120)

-- Whole ring red during the "on" half of the blink, dark otherwise
local function blinkRed()
  if lib.blinkOn() then return 1, RED end
  return 1, nil
end

-- Model battery text; returns level and colour for the model ring preview
local function drawModel(y)
  if #sensors == 0 then
    lcd.drawText(30, y + 12, "No telemetry sensors found", MIDSIZE + COLOR_THEME_WARNING)
    lcd.drawText(30, y + 52, "Run 'Discover new' on the Telemetry page", COLOR_THEME_PRIMARY1)
    return 1, DIM_BLUE
  end

  local v, sensorCells = lib.readVoltage(cfg.sensor)
  if not v then
    lcd.drawText(30, y + 12, "No data from sensor", MIDSIZE + COLOR_THEME_WARNING)
    lcd.drawText(30, y + 52, "Model ring shows dim blue without telemetry", COLOR_THEME_PRIMARY1)
    return 1, DIM_BLUE
  end

  local cells, how
  if cfg.cells > 0 then
    cells, how = cfg.cells, "fixed"
  elseif sensorCells then
    cells, how = sensorCells, "from sensor"
  else
    cells, how = lib.detectCells(v), "auto"
  end
  local cellV = v / cells
  local p = lib.percent(cellV, cfg.type)

  lcd.drawText(30, y + 12, string.format("Model %.2f V   %dS (%s)", v, cells, how), MIDSIZE + BOLD + COLOR_THEME_PRIMARY1)
  if cellV <= cfg.warn then
    lcd.drawText(30, y + 50, string.format("%.2f V per cell  -  LOW!", cellV), MIDSIZE + COLOR_THEME_WARNING)
    return blinkRed()
  end
  lcd.drawText(30, y + 50, string.format("%.2f V per cell  -  %d %%", cellV, math.floor(p * 100 + 0.5)), MIDSIZE + COLOR_THEME_PRIMARY1)
  return p, lcd.RGB(lib.color(p))
end

-- Radio battery text; returns level and colour for the radio ring preview
local function drawRadio(y)
  local v, p = lib.radioBattery(radioRange)
  if v <= radioRange.warn then
    lcd.drawText(30, y + 88, string.format("Radio %.2f V  -  LOW!", v), MIDSIZE + COLOR_THEME_WARNING)
    return blinkRed()
  end
  lcd.drawText(30, y + 88, string.format("Radio %.2f V  -  %d %%", v, math.floor(p * 100 + 0.5)), MIDSIZE + COLOR_THEME_PRIMARY1)
  return p, lcd.RGB(lib.color(p))
end

local function drawLive()
  local y = rowY(NUM_ROWS + 1)
  local h = LCD_H - y - 10
  lcd.drawFilledRectangle(10, y, LCD_W - 20, h, COLOR_THEME_PRIMARY2)

  local mLevel, mColor = drawModel(y)
  local rLevel, rColor = drawRadio(y)

  local roles = lib.ringRoles(cfg.ring)
  local function ringState(role)
    if role == "model" then return mLevel, mColor end
    if role == "radio" then return rLevel, rColor end
    return 0, nil
  end
  local cy = y + h / 2
  drawRing(LCD_W - 250, cy, "L", leftRing, ringState(roles.left))
  drawRing(LCD_W - 110, cy, "R", rightRing, ringState(roles.right))
end

local function draw()
  lcd.clear(COLOR_THEME_SECONDARY3)
  lcd.drawFilledRectangle(0, 0, LCD_W, HEADER_H, COLOR_THEME_SECONDARY1)
  lcd.drawText(20, HEADER_H / 2, "BattLED Setup  -  " .. modelName, MIDSIZE + VCENTER + COLOR_THEME_PRIMARY2)
  lcd.drawText(LCD_W - 20, HEADER_H / 2, status, RIGHT + VCENTER + COLOR_THEME_PRIMARY2)
  for row = 1, NUM_ROWS do
    drawRow(row)
  end
  drawLive()
end

local function handleTouch(x, y)
  local lx, rx = buttonsX()
  for row = 1, NUM_ROWS do
    local ry = rowY(row)
    if y >= ry and y < ry + ROW_H - 8 then
      sel = row
      editing = false
      if x >= lx and x < lx + BTN_W then
        change(row, -1)
      elseif x >= rx and x < rx + BTN_W then
        change(row, 1)
      end
    end
  end
end

local function init()
  lib = loadScript("/SCRIPTS/BATTLED/lib.lua")()
  cfg = lib.loadConfig()
  radioRange = lib.radioRange()
  rightRing, leftRing = lib.ringLayout()
  loadSensors()
  local info = model.getInfo()
  modelName = (info and info.name) or ""
  -- Preselect a likely voltage sensor when nothing is configured yet
  if cfg.sensor == "" then
    for _, name in ipairs(sensors) do
      if name == "RxBt" or name == "A1" or name == "VFAS" or name == "Cels" or name == "BtRx" then
        cfg.sensor = name
        lib.saveConfig(cfg)
        status = "Sensor " .. name .. " preselected"
        break
      end
    end
  end
end

local function run(event, touchState)
  if event == EVT_VIRTUAL_EXIT then
    if editing then
      editing = false
    else
      return 1
    end
  elseif event == EVT_VIRTUAL_ENTER then
    editing = not editing
  elseif event == EVT_VIRTUAL_NEXT then
    if editing then change(sel, 1) else sel = sel % NUM_ROWS + 1 end
  elseif event == EVT_VIRTUAL_PREV then
    if editing then change(sel, -1) else sel = (sel - 2) % NUM_ROWS + 1 end
  elseif event == EVT_TOUCH_TAP and touchState then
    handleTouch(touchState.x, touchState.y)
  end
  draw()
  return 0
end

return { init = init, run = run }
