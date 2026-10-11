-- DNS Meter Settings window logic
-- Each of the 4 slots cycles through the PC's network adapters:
--   left-click = next adapter, right-click = previous ("(none)" is part of the cycle)
-- The choice is written to ..\DnsSettings.inc and the gadget is refreshed.

local SLOTS = 4

local function trim(s)
  s = (s or ''):gsub('^%s+', '')
  s = s:gsub('%s+$', '')
  return s
end

function Initialize()
  mAd = SKIN:GetMeasure('MeasureAdapters')
  settingsPath = SKIN:GetVariable('dnsSettingsPath')
  gadgetConfig = SKIN:GetVariable('dnsMeterConfig')
  list = {}
  detected = false
  cur = {}
  for i = 1, SLOTS do
    cur[i] = trim(SKIN:GetVariable('dnsInterface' .. i, ''))
  end
  Render()
end

-- Input: Name|Description|Status;...
function SetAdapters()
  list = {}
  local raw = (mAd:GetStringValue() or ''):gsub('[\r\n]', '')
  for entry in raw:gmatch('[^;]+') do
    local name, desc, status = entry:match('^(.-)|(.-)|(.-)$')
    if name and name ~= '' then
      table.insert(list, { name = name, desc = desc, status = status })
    end
  end
  detected = true
  Render()
end

local function find(v)
  local w = v:lower()
  for i, a in ipairs(list) do
    if a.name:lower() == w or a.desc:lower() == w then return i, a end
  end
  return 0, nil
end

function Render()
  local dim = SKIN:GetVariable('colorDim')
  local main = SKIN:GetVariable('colorMain')
  for i = 1, SLOTS do
    local v = cur[i]
    local text, sub, color = v, ' ', main
    if v == '' then
      text, color = '(none)', dim
    else
      local _, a = find(v)
      if a then
        text = a.name
        sub = a.desc .. '  -  ' .. a.status
      elseif detected then
        sub = 'Not found on this PC'
      else
        sub = 'Detecting adapters...'
      end
    end
    SKIN:Bang('!SetOption', 'MeterSlot' .. i .. 'Value', 'Text', text)
    SKIN:Bang('!SetOption', 'MeterSlot' .. i .. 'Value', 'FontColor', color)
    SKIN:Bang('!SetOption', 'MeterSlot' .. i .. 'Sub', 'Text', sub)
  end
  SKIN:Bang('!UpdateMeterGroup', 'Slots')
  SKIN:Bang('!Redraw')
end

-- dir = 1 (next) or -1 (previous)
function Step(i, dir)
  if #list == 0 then return end
  local idx = find(cur[i])               -- 0 means "(none)" or not found
  idx = (idx + dir) % (#list + 1)        -- cycle through 0..#list
  if idx == 0 then cur[i] = '' else cur[i] = list[idx].name end
  Save(i)
end

function Clear(i)
  cur[i] = ''
  Save(i)
end

function Save(i)
  SKIN:Bang('!SetVariable', 'dnsInterface' .. i, cur[i])
  SKIN:Bang('!WriteKeyValue', 'Variables', 'dnsInterface' .. i, cur[i], settingsPath)
  Render()
  SKIN:Bang('!Refresh', gadgetConfig)
end
