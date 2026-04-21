-- CalendarModel: pure-Lua date binning for the 365 calendar view.
-- No Lightroom SDK imports in this file.

local M = {}

function M.new(photos)
  error("not yet implemented", 2)
end

function M.rollMonth(year, month, delta)
  -- Convert (year, month) into a 0-indexed month count, shift, convert back.
  local zeroBased = (year * 12 + (month - 1)) + delta
  local newYear = math.floor(zeroBased / 12)
  local newMonth = (zeroBased - newYear * 12) + 1
  return newYear, newMonth
end

return M
