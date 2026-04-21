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
  local bins = {}
  for _, photo in ipairs(photos) do
    local cs = photo:getRawMetadata("dateTimeOriginal")
    if cs then
      local y, mo, d = M._cocoaToLocalDate(cs)
      local key = dayKey(y, mo, d)
      bins[key] = bins[key] or {}
      table.insert(bins[key], photo)
    end
  end
  local self = setmetatable({ _bins = bins }, Model)
  return self
end

function M.rollMonth(year, month, delta)
  -- Convert (year, month) into a 0-indexed month count, shift, convert back.
  local zeroBased = (year * 12 + (month - 1)) + delta
  local newYear = math.floor(zeroBased / 12)
  local newMonth = (zeroBased - newYear * 12) + 1
  return newYear, newMonth
end

function Model:cellsForMonth(year, month)
  error("not yet implemented", 2)
end

return M
