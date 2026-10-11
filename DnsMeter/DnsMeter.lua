-- DNS Meter (ModernGadgets-style) - display logic
-- Shows the DNS servers of up to 4 interfaces chosen in DNS Meter Settings
-- (variables dnsInterface1..4 in DnsSettings.inc). If none are chosen, it
-- shows the active interface. DNS values are read from the registry
-- measures, which update every second.

local SLOTS = 4

local function trim(s)
  s = (s or ''):gsub('^%s+', '')
  s = s:gsub('%s+$', '')
  return s
end

function Initialize()
  mList = SKIN:GetMeasure('MeasureIfList')
  mStatic, mDhcp = {}, {}
  for i = 1, SLOTS do
    mStatic[i] = SKIN:GetMeasure('MeasureRegStatic' .. i)
    mDhcp[i] = SKIN:GetMeasure('MeasureRegDhcp' .. i)
  end
  adapters = {}
  rows = {}
  detected = false
  lastL, lastR = nil, nil
end

-- Called by MeasureIfList's FinishAction.
-- Input: Name|Description|{GUID}|Status|isActive;...
function SetAdapters()
  adapters = {}
  local raw = (mList:GetStringValue() or ''):gsub('[\r\n]', '')
  for entry in raw:gmatch('[^;]+') do
    local name, desc, guid, status, act = entry:match('^(.-)|(.-)|(.-)|(.-)|(%d)$')
    if name and name ~= '' then
      table.insert(adapters, {
        name = name, desc = desc, guid = guid, status = status, active = (act == '1')
      })
    end
  end
  detected = true
  BuildRows()
end

local function findAdapter(want)
  local w = want:lower()
  for _, a in ipairs(adapters) do
    if a.name:lower() == w or a.desc:lower() == w then return a end
  end
  return nil
end

function BuildRows()
  rows = {}
  local configured = false
  for i = 1, SLOTS do
    local want = trim(SKIN:GetVariable('dnsInterface' .. i, ''))
    if want ~= '' then
      configured = true
      table.insert(rows, { slot = i, want = want, adapter = findAdapter(want) })
    end
  end

  -- Nothing configured: fall back to the active interface
  if not configured then
    for _, a in ipairs(adapters) do
      if a.active then
        table.insert(rows, { slot = 1, want = a.name, adapter = a })
        break
      end
    end
  end

  -- Point each slot's registry measures at its adapter
  local used = {}
  for _, r in ipairs(rows) do
    if r.adapter and r.adapter.guid ~= '' then
      used[r.slot] = true
      SKIN:Bang('!SetVariable', 'slotGuid' .. r.slot, r.adapter.guid)
    end
  end
  for i = 1, SLOTS do
    if used[i] then
      SKIN:Bang('!EnableMeasure', 'MeasureRegStatic' .. i)
      SKIN:Bang('!EnableMeasure', 'MeasureRegDhcp' .. i)
    else
      SKIN:Bang('!DisableMeasure', 'MeasureRegStatic' .. i)
      SKIN:Bang('!DisableMeasure', 'MeasureRegDhcp' .. i)
    end
  end
  SKIN:Bang('!UpdateMeasureGroup', 'DnsReg')
  lastL, lastR = nil, nil
  Render()
end

-- Rainmeter returns "0" for an empty registry value, so treat it as empty.
local function clean(s)
  if not s or s == '0' then return '' end
  return s
end

local function getServers(r)
  local a = r.adapter
  if not a then return {} end
  local s = clean(mStatic[r.slot]:GetStringValue())     -- manually set DNS
  -- DHCP-provided DNS only counts while the adapter is connected
  if s == '' and a.status == 'Up' then
    s = clean(mDhcp[r.slot]:GetStringValue())
  end
  local t = {}
  for ip in s:gmatch('[^,%s]+') do table.insert(t, ip) end
  return t
end

function Render()
  local L, R = {}, {}

  if not detected then
    L[1], R[1] = 'Detecting...', ' '
  elseif #rows == 0 then
    L[1], R[1] = 'No active interface', ' '
  end

  for _, r in ipairs(rows) do
    local a = r.adapter
    local name, suffix = r.want, ' (not found)'
    if a then
      name = a.name
      if a.status ~= 'Up' then
        suffix = ' (disconnected)'
      elseif a.active then
        suffix = ' (active)'
      else
        suffix = ''
      end
    end
    L[#L + 1] = name .. suffix
    R[#R + 1] = ' '
    local s = getServers(r)
    L[#L + 1] = 'Primary:'
    R[#R + 1] = s[1] or 'None'
    L[#L + 1] = 'Secondary:'
    R[#R + 1] = s[2] or 'None'
  end

  local lt, rt = table.concat(L, '\n'), table.concat(R, '\n')
  if lt ~= lastL or rt ~= lastR then
    lastL, lastR = lt, rt
    SKIN:Bang('!SetOption', 'MeterDnsLabels', 'Text', lt)
    SKIN:Bang('!SetOption', 'MeterDnsValues', 'Text', rt)
    SKIN:Bang('!UpdateMeterGroup', 'DnsBody')
    SKIN:Bang('!UpdateMeterGroup', 'Background')
    SKIN:Bang('!Redraw')
  end
end

function Update()
  Render()
end
