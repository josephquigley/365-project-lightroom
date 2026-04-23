-- CalendarModel: pure-Lua date binning for the 365 calendar view.
-- No Lightroom SDK imports in this file.

local M = {}

-- Cocoa epoch (2001-01-01 UTC) offset from Unix epoch (1970-01-01 UTC).
local COCOA_UNIX_OFFSET = 978307200

-- Convert Cocoa-epoch seconds (as returned by
-- `photo:getRawMetadata("dateTimeOriginal")`) to a local calendar (year, month, day).
function M._cocoaToLocalDate(cocoaSeconds)
  local unix = cocoaSeconds + COCOA_UNIX_OFFSET
  local t = os.date("*t", unix)
  return t.year, t.month, t.day
end

local function dayKey(y, m, d)
  return string.format("%04d-%02d-%02d", y, m, d)
end

local Model = {}
Model.__index = Model

function Model:_binFor(year, month, day)
  return self._bins[dayKey(year, month, day)] or {}
end

function M.new(photos)
  -- Bin each photo into a (year, month, day) bucket along with its cached
  -- capture time. We cache `dto` on the bin entry so table.sort's comparator
  -- stays pure-Lua: Lightroom metadata getters can yield, and yielding inside
  -- the C-level table.sort raises "Yielding is not allowed within a C or
  -- metamethod call". The earliest capture time is also remembered as the
  -- 365-project start date anchor for project_day numbering.
  local bins = {}
  local min_dto = nil
  for _, photo in ipairs(photos) do
    local cs = photo:getRawMetadata("dateTimeOriginal")
    if cs then
      local y, mo, d = M._cocoaToLocalDate(cs)
      local key = dayKey(y, mo, d)
      bins[key] = bins[key] or {}
      table.insert(bins[key], { photo = photo, dto = cs })
      if min_dto == nil or cs < min_dto then min_dto = cs end
    end
  end
  for key, bin in pairs(bins) do
    table.sort(bin, function(a, b) return a.dto < b.dto end)
    local photos_only = {}
    for i, entry in ipairs(bin) do photos_only[i] = entry.photo end
    bins[key] = photos_only
  end
  local start = nil
  if min_dto then
    local sy, sm, sd = M._cocoaToLocalDate(min_dto)
    start = { year = sy, month = sm, day = sd }
  end
  local self = setmetatable({ _bins = bins, _start = start }, Model)
  return self
end

function M.rollMonth(year, month, delta)
  -- Convert (year, month) into a 0-indexed month count, shift, convert back.
  local zeroBased = (year * 12 + (month - 1)) + delta
  local newYear = math.floor(zeroBased / 12)
  local newMonth = (zeroBased - newYear * 12) + 1
  return newYear, newMonth
end

-- Returns the number of days in the given (year, month) using os.time/os.date.
-- Trick: day 0 of month+1 is the last day of month.
local function daysInMonth(year, month)
  local nextMonth, nextYear = month + 1, year
  if nextMonth > 12 then nextMonth, nextYear = 1, year + 1 end
  local t = os.date("*t", os.time({ year = nextYear, month = nextMonth, day = 0, hour = 12 }))
  return t.day
end

-- Returns the number of whole days between two local dates, anchored at
-- local noon to sidestep DST seams.
local function daysBetween(a, b)
  local ta = os.time({ year = a.year, month = a.month, day = a.day, hour = 12 })
  local tb = os.time({ year = b.year, month = b.month, day = b.day, hour = 12 })
  return math.floor((tb - ta) / 86400 + 0.5)
end

function Model:projectDayOf(today)
  if not self._start then return nil end
  return daysBetween(self._start, today) + 1
end

function Model:missingDays(today)
  if not self._start then return {} end
  local span = daysBetween(self._start, today)
  if span < 0 then return {} end

  local out = {}
  for offset = 0, span do
    local t = os.date("*t", os.time({
      year = self._start.year,
      month = self._start.month,
      day = self._start.day + offset,
      hour = 12,
    }))
    local key = string.format("%04d-%02d-%02d", t.year, t.month, t.day)
    if not self._bins[key] then
      out[#out + 1] = {
        year        = t.year,
        month       = t.month,
        day         = t.day,
        project_day = offset + 1,
      }
    end
  end
  return out
end

function Model:cellsForMonth(year, month)
  local n = daysInMonth(year, month)
  local cells = {}
  for day = 1, n do
    local bin = self:_binFor(year, month, day)
    local primary = bin[1]
    local project_day = nil
    if primary and self._start then
      project_day = daysBetween(self._start, { year = year, month = month, day = day }) + 1
    end
    cells[day] = {
      day         = day,
      primary     = primary,
      extras      = math.max(#bin - 1, 0),
      project_day = project_day,
    }
  end
  return cells
end

-- Returns the weekday of day 1 of the given month, with 1=Sunday..7=Saturday.
function M.firstWeekdayOfMonth(year, month)
  local t = os.date("*t", os.time({ year = year, month = month, day = 1, hour = 12 }))
  return t.wday  -- os.date already uses 1=Sun..7=Sat
end

return M
