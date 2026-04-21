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

local function buildState(collectionValue, collectionsList, year, month, model)
  return {
    collections     = collectionsList,
    collectionValue = collectionValue,
    year            = year,
    month           = month,
    cells           = model and model:cellsForMonth(year, month) or {},
    firstWeekday    = CalendarModel.firstWeekdayOfMonth(year, month),
  }
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

    local currentCollection = collections[1]
    local year, month = currentYearMonth()
    local model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))

    while true do
      local properties = LrBinding.makePropertyTable(context)
      properties.collectionValue = currentCollection
      properties.action = nil

      local state = buildState(currentCollection, collectionsList, year, month, model)

      local result = LrDialogs.presentModalDialog {
        title  = "365 Project Calendar",
        contents = CalendarView.build(state, properties),
        actionVerb = "Close",
        cancelVerb = "< exclude >",  -- hide default Cancel
      }

      -- Handle collection change before acting on button presses.
      if properties.collectionValue ~= currentCollection then
        currentCollection = properties.collectionValue
        model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))
      end

      local action = properties.action
      if action == "prev" then
        year, month = CalendarModel.rollMonth(year, month, -1)
      elseif action == "next" then
        year, month = CalendarModel.rollMonth(year, month, 1)
      elseif action == "refresh" then
        model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))
      else
        break  -- user clicked Close or dismissed
      end
    end
  end)
end

LrTasks.startAsyncTask(run)
