-- ShowCalendarDialog: entry point invoked from the Library menu.
-- Owns the re-present-dialog-per-navigation loop.

local LrTasks            = import "LrTasks"
local LrDialogs          = import "LrDialogs"
local LrBinding          = import "LrBinding"
local LrFunctionContext  = import "LrFunctionContext"

local CalendarModel    = require("CalendarModel")
local CollectionReader = require("CollectionReader")
local CalendarView     = require("CalendarView")

local function currentYearMonth()
  local t = os.date("*t")
  return t.year, t.month
end

local function currentDate()
  local t = os.date("*t")
  return { year = t.year, month = t.month, day = t.day }
end

local function buildState(collectionValue, collectionsList, view, year, month, model)
  local today = currentDate()
  local now   = os.date("*t")
  local state = {
    collections      = collectionsList,
    collectionValue  = collectionValue,
    view             = view,
    today            = today,
    todayProjectDay  = model and model:projectDayOf(today) or nil,
    todayYear        = now.year,
    todayMonth       = now.month,
  }
  if view == "missing" then
    state.missingDays = model and model:missingDays(today) or {}
  else
    state.year         = year
    state.month        = month
    state.cells        = model and model:cellsForMonth(year, month) or {}
    state.firstWeekday = CalendarModel.firstWeekdayOfMonth(year, month)
  end
  return state
end

local function run()
  LrFunctionContext.callWithContext("365Calendar.dialog", function(context)
    local collections = CollectionReader.listRegularCollections()
    if #collections == 0 then
      LrDialogs.message("365 Calendar", "No regular collections found in this catalog.", "info")
      return
    end

    local collectionsList = {}
    for _, c in ipairs(collections) do
      table.insert(collectionsList, {
        title = CollectionReader.qualifiedName(c),
        value = c,
      })
    end

    local currentCollection = CollectionReader.activeRegularCollection() or collections[1]
    local year, month = currentYearMonth()
    local viewMode = "calendar"
    local model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))

    while true do
      local properties = LrBinding.makePropertyTable(context)
      properties.collectionValue = currentCollection

      local state = buildState(currentCollection, collectionsList, viewMode, year, month, model)

      local result = LrDialogs.presentModalDialog {
        title      = "365 Project Calendar",
        contents   = CalendarView.build(state, properties),
        actionVerb = "Close",
        cancelVerb = "< exclude >",  -- hide default Cancel
        save_frame = "365Calendar.mainDialog",
      }

      -- Collection popup may have changed without closing the dialog via a button.
      if properties.collectionValue ~= currentCollection then
        currentCollection = properties.collectionValue
        model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))
      end

      if result == "prev" then
        year, month = CalendarModel.rollMonth(year, month, -1)
      elseif result == "next" then
        year, month = CalendarModel.rollMonth(year, month, 1)
      elseif result == "refresh" then
        model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))
      elseif result == "view:calendar" then
        viewMode = "calendar"
      elseif result == "view:missing" then
        viewMode = "missing"
      else
        break  -- user clicked Close or dismissed
      end
    end
  end)
end

LrTasks.startAsyncTask(run)
