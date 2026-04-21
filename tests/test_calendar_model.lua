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

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
