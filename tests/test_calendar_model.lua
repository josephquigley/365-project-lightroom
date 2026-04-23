-- Make the plugin modules importable. Tests are run from repo root.
package.path = "./365Calendar.lrplugin/?.lua;" .. package.path

local CalendarModel = require("CalendarModel")

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  PASS: " .. name)
  else
    failed = failed + 1
    print("  FAIL: " .. name)
    print("    " .. tostring(err))
  end
end

local function assert_equal(actual, expected, msg)
  if actual ~= expected then
    error((msg or "values differ") ..
      string.format(" (expected %s, got %s)", tostring(expected), tostring(actual)), 2)
  end
end

local function assert_nil(x, msg)
  if x ~= nil then
    error((msg or "expected nil") .. " (got " .. tostring(x) .. ")", 2)
  end
end

-- Build a minimal LrPhoto stub: `getRawMetadata(key)` returns whatever
-- was passed in, keyed by metadata name.
local function stubPhoto(metadata)
  return {
    getRawMetadata = function(self, key) return metadata[key] end,
  }
end

-- Cocoa-epoch offset: Cocoa = Unix - 978307200.
local function cocoaAt(y, m, d, h, min, sec)
  local unix = os.time({
    year = y, month = m, day = d,
    hour = h or 12, min = min or 0, sec = sec or 0,
  })
  return unix - 978307200
end

-- ---------------------------------------------------------------
-- Smoke test: the module loads and exposes its expected interface
-- ---------------------------------------------------------------

test("module exposes new and rollMonth", function()
  assert_equal(type(CalendarModel.new), "function", "new should be a function")
  assert_equal(type(CalendarModel.rollMonth), "function", "rollMonth should be a function")
end)

-- ---------------------------------------------------------------
-- rollMonth: month arithmetic with year rollover
-- ---------------------------------------------------------------

test("rollMonth: simple forward step", function()
  local y, m = CalendarModel.rollMonth(2026, 4, 1)
  assert_equal(y, 2026)
  assert_equal(m, 5)
end)

test("rollMonth: simple backward step", function()
  local y, m = CalendarModel.rollMonth(2026, 4, -1)
  assert_equal(y, 2026)
  assert_equal(m, 3)
end)

test("rollMonth: December forward rolls year", function()
  local y, m = CalendarModel.rollMonth(2026, 12, 1)
  assert_equal(y, 2027)
  assert_equal(m, 1)
end)

test("rollMonth: January backward rolls year", function()
  local y, m = CalendarModel.rollMonth(2026, 1, -1)
  assert_equal(y, 2025)
  assert_equal(m, 12)
end)

-- ---------------------------------------------------------------
-- _cocoaToLocalDate
-- ---------------------------------------------------------------

test("_cocoaToLocalDate: round-trips a known local date", function()
  -- Build a Cocoa-seconds value for 2026-04-21 12:00:00 local, then convert.
  local cs = cocoaAt(2026, 4, 21, 12)
  local y, mo, d = CalendarModel._cocoaToLocalDate(cs)
  assert_equal(y, 2026)
  assert_equal(mo, 4)
  assert_equal(d, 21)
end)

test("_cocoaToLocalDate: works near midnight boundary", function()
  -- 23:30 local on the 15th must stay on the 15th.
  local cs = cocoaAt(2026, 4, 15, 23, 30, 0)
  local y, mo, d = CalendarModel._cocoaToLocalDate(cs)
  assert_equal(y, 2026)
  assert_equal(mo, 4)
  assert_equal(d, 15)
end)

-- ---------------------------------------------------------------
-- CalendarModel.new: binning
-- ---------------------------------------------------------------

test("new: returns an object with cellsForMonth method", function()
  local m = CalendarModel.new({})
  assert_equal(type(m.cellsForMonth), "function")
end)

test("new: bins a single photo into its date key", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  local bin = m:_binFor(2026, 4, 15)
  assert_equal(#bin, 1)
  assert_equal(bin[1], p)
end)

test("new: photos on different days go into separate bins", function()
  local p1 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local p2 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 16, 10) })
  local m = CalendarModel.new({ p1, p2 })
  assert_equal(#m:_binFor(2026, 4, 15), 1)
  assert_equal(#m:_binFor(2026, 4, 16), 1)
end)

-- ---------------------------------------------------------------
-- cellsForMonth: shape + simple cases
-- ---------------------------------------------------------------

test("cellsForMonth: April has 30 cells", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(#cells, 30)
end)

test("cellsForMonth: July has 31 cells", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2026, 7)
  assert_equal(#cells, 31)
end)

test("cellsForMonth: cells have day, primary, extras fields", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(cells[1].day, 1)
  assert_equal(cells[15].day, 15)
  assert_nil(cells[1].primary)
  assert_equal(cells[1].extras, 0)
end)

test("cellsForMonth: single photo becomes primary of that day", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(cells[15].primary, p)
  assert_equal(cells[15].extras, 0)
end)

test("cellsForMonth: photos outside month do not appear", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 3, 31, 10) })
  local m = CalendarModel.new({ p })
  local cells = m:cellsForMonth(2026, 4)
  for _, c in ipairs(cells) do
    assert_nil(c.primary)
  end
end)

-- ---------------------------------------------------------------
-- cellsForMonth: multi-photo days
-- ---------------------------------------------------------------

test("cellsForMonth: three photos same day -> primary earliest, extras=2", function()
  local morning = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 8) })
  local noon    = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 12) })
  local evening = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 20) })
  -- Pass in arbitrary order to confirm sorting.
  local m = CalendarModel.new({ evening, morning, noon })
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(cells[15].primary, morning)
  assert_equal(cells[15].extras, 2)
end)

-- ---------------------------------------------------------------
-- Photos without dateTimeOriginal
-- ---------------------------------------------------------------

test("new: photos without dateTimeOriginal are skipped", function()
  local good    = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local missing = stubPhoto({ dateTimeOriginal = nil })
  local m = CalendarModel.new({ good, missing })
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(cells[15].primary, good)
  assert_equal(cells[15].extras, 0)  -- missing did not inflate extras
end)

-- ---------------------------------------------------------------
-- Leap February
-- ---------------------------------------------------------------

test("cellsForMonth: February 2024 has 29 cells (leap year)", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2024, 2)
  assert_equal(#cells, 29)
end)

test("cellsForMonth: February 2025 has 28 cells", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2025, 2)
  assert_equal(#cells, 28)
end)

-- ---------------------------------------------------------------
-- firstWeekdayOfMonth: 1=Sunday..7=Saturday
-- ---------------------------------------------------------------

test("firstWeekdayOfMonth: April 2026 starts on Wednesday (4)", function()
  assert_equal(CalendarModel.firstWeekdayOfMonth(2026, 4), 4)
end)

test("firstWeekdayOfMonth: February 2026 starts on Sunday (1)", function()
  assert_equal(CalendarModel.firstWeekdayOfMonth(2026, 2), 1)
end)

-- ---------------------------------------------------------------
-- project_day: 365-Project day number, day 1 = earliest photo
-- ---------------------------------------------------------------

test("cellsForMonth: project_day = 1 on the day of the earliest photo", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 1, 10) })
  local m = CalendarModel.new({ p })
  local cells = m:cellsForMonth(2026, 1)
  assert_equal(cells[1].project_day, 1)
end)

test("cellsForMonth: project_day = 3 for a photo two days after start", function()
  local p1 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 1, 10) })
  local p3 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 3, 10) })
  local m = CalendarModel.new({ p1, p3 })
  local cells = m:cellsForMonth(2026, 1)
  assert_equal(cells[3].project_day, 3)
end)

test("cellsForMonth: earliest photo anchors the count regardless of input order", function()
  local later   = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 3, 15, 10) })
  local earlier = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 1, 10) })
  local m = CalendarModel.new({ later, earlier })
  local cells = m:cellsForMonth(2026, 3)
  -- March 15 = 31 (Jan) + 28 (Feb) + 15 = day 74 from Jan 1
  assert_equal(cells[15].project_day, 74)
end)

test("cellsForMonth: project_day spans month boundary correctly", function()
  -- Earliest on Jan 30, photo on Feb 1 -> day 3
  local p1 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 30, 10) })
  local p3 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 2, 1, 10) })
  local m = CalendarModel.new({ p1, p3 })
  local cells = m:cellsForMonth(2026, 2)
  assert_equal(cells[1].project_day, 3)
end)

test("cellsForMonth: missing days carry no project_day", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 1, 10) })
  local m = CalendarModel.new({ p })
  local cells = m:cellsForMonth(2026, 1)
  assert_nil(cells[2].project_day)
end)

test("cellsForMonth: empty model leaves project_day nil", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2026, 4)
  assert_nil(cells[1].project_day)
end)

-- ---------------------------------------------------------------
-- projectDayOf(today): inclusive day count since the earliest photo
-- ---------------------------------------------------------------

test("projectDayOf: nil when the model has no photos", function()
  local m = CalendarModel.new({})
  assert_nil(m:projectDayOf({ year = 2026, month = 4, day = 22 }))
end)

test("projectDayOf: 1 when today equals the earliest-photo date", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  assert_equal(m:projectDayOf({ year = 2026, month = 4, day = 15 }), 1)
end)

test("projectDayOf: returns N+1 when today is N days after the earliest photo", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  assert_equal(m:projectDayOf({ year = 2026, month = 4, day = 20 }), 6)
end)

test("projectDayOf: spans month boundaries", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 30, 10) })
  local m = CalendarModel.new({ p })
  assert_equal(m:projectDayOf({ year = 2026, month = 2, day = 2 }), 4)
end)

test("projectDayOf: negative when today precedes the earliest photo", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  assert_equal(m:projectDayOf({ year = 2026, month = 4, day = 12 }), -2)
end)

-- ---------------------------------------------------------------
-- missingDays(today): ordered list of dates without a photo
-- ---------------------------------------------------------------

test("missingDays: empty model returns empty list", function()
  local m = CalendarModel.new({})
  local result = m:missingDays({ year = 2026, month = 4, day = 22 })
  assert_equal(type(result), "table")
  assert_equal(#result, 0)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
