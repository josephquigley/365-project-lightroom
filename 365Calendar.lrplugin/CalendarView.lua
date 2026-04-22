-- CalendarView: builds the LrView tree for the calendar dialog.
-- All functions are pure with respect to their inputs -- they return view
-- descriptors, never calling LR APIs directly.

local LrView    = import "LrView"
local LrColor   = import "LrColor"
local LrDialogs = import "LrDialogs"

local M = {}

local CELL_SIZE = 80

local COLOR_MISSING_BG  = LrColor(0.95, 0.85, 0.85)
local COLOR_MISSING_FG  = LrColor(0, 0, 0)
local COLOR_OVERLAY_FG  = LrColor(1, 1, 1)
local COLOR_OVERLAY_BG  = LrColor(0.15, 0.15, 0.15)  -- opaque dark; LrColor alpha support is unreliable

-- A present-day cell: catalog photo thumbnail with overlaid day number and
-- "+N" badge (visible only when extras > 0). `place = "overlapping"` stacks
-- the children at absolute positions specified by place_horizontal/vertical.
-- Below the thumbnail, render the 365-project day number ("Day N") so the
-- photographer can see progress at a glance.
function M._presentCell(f, cell)
  return f:column {
    spacing = 2,
    f:view {
      place = "overlapping",
      width = CELL_SIZE, height = CELL_SIZE,

      f:catalog_photo {
        photo = cell.primary,
        width = CELL_SIZE, height = CELL_SIZE,
      },

      f:view {
        background_color = COLOR_OVERLAY_BG,
        place_horizontal = 0,
        place_vertical = 0,
        f:static_text {
          title = tostring(cell.day),
          text_color = COLOR_OVERLAY_FG,
          font = "<system/small/bold>",
        },
      },

      f:view {
        background_color = COLOR_OVERLAY_BG,
        place_horizontal = 1,
        place_vertical = 0,
        visible = cell.extras > 0,
        f:static_text {
          title = "+" .. tostring(cell.extras),
          text_color = COLOR_OVERLAY_FG,
          font = "<system/small>",
        },
      },
    },
    f:static_text {
      title = cell.project_day and ("Day " .. tostring(cell.project_day)) or "",
      width = CELL_SIZE,
      alignment = "center",
      font = "<system/small>",
    },
  }
end

-- A missing-day cell: soft-red filled box with centered day number. Matches
-- the present-cell's total footprint (thumbnail + day-label line) so the
-- grid stays uniform.
function M._missingCell(f, cell)
  return f:column {
    spacing = 2,
    f:view {
      width = CELL_SIZE, height = CELL_SIZE,
      background_color = COLOR_MISSING_BG,
      f:static_text {
        title = tostring(cell.day),
        text_color = COLOR_MISSING_FG,
        place_horizontal = 0.5,
        place_vertical = 0.5,
      },
    },
    f:static_text {
      title = "",
      width = CELL_SIZE,
      alignment = "center",
      font = "<system/small>",
    },
  }
end

-- A blank cell: used for leading/trailing spacer slots to align the grid.
-- Size must match present/missing cells so the grid stays rectangular.
function M._blankCell(f)
  return f:column {
    spacing = 2,
    f:view { width = CELL_SIZE, height = CELL_SIZE },
    f:static_text {
      title = "",
      width = CELL_SIZE,
      alignment = "center",
      font = "<system/small>",
    },
  }
end

local WEEKDAY_LABELS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

-- LrView finalizes children at construction time -- post-hoc `table.insert`
-- on the returned view is silently dropped. We build the args table first,
-- then construct the view once with all children in place.
function M._weekdayHeader(f)
  local args = { spacing = 4 }
  for _, label in ipairs(WEEKDAY_LABELS) do
    args[#args + 1] = f:static_text {
      title = label,
      width = CELL_SIZE,
      alignment = "center",
    }
  end
  return f:row(args)
end

-- Builds the month grid: up to 6 rows of 7 cells each. Leading blanks
-- account for the weekday of the 1st; trailing blanks pad the final row so
-- the grid edge stays rectangular. Children are built into args tables
-- before the view is constructed; post-hoc table.insert on a completed
-- LrView row/column is silently dropped.
function M._grid(f, cells, firstWeekday)
  local columnArgs = { spacing = 4 }
  local rowArgs = { spacing = 4 }
  for _ = 1, (firstWeekday - 1) do
    rowArgs[#rowArgs + 1] = M._blankCell(f)
  end
  local inRow = firstWeekday - 1

  for _, cell in ipairs(cells) do
    local view
    if cell.primary then
      view = M._presentCell(f, cell)
    else
      view = M._missingCell(f, cell)
    end
    rowArgs[#rowArgs + 1] = view
    inRow = inRow + 1
    if inRow == 7 then
      columnArgs[#columnArgs + 1] = f:row(rowArgs)
      rowArgs = { spacing = 4 }
      inRow = 0
    end
  end

  -- Trailing blanks + flush partial row.
  if inRow > 0 then
    for _ = inRow + 1, 7 do
      rowArgs[#rowArgs + 1] = M._blankCell(f)
    end
    columnArgs[#columnArgs + 1] = f:row(rowArgs)
  end

  return f:column(columnArgs)
end

local MONTH_NAMES = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
}

-- Top bar: collection picker + refresh button.
-- `state.collections` is an array of { title, value } entries;
-- `state.collectionValue` is the currently-selected value.
-- `close_with(result)` closes the modal dialog with the given result string.
function M._topBar(f, state, properties, close_with)
  return f:row {
    spacing = 8,
    f:static_text { title = "Collection:" },
    f:popup_menu {
      items = state.collections,
      value = LrView.bind { key = "collectionValue", object = properties },
      width_in_chars = 30,
    },
    f:push_button {
      title = "Refresh",
      action = function() close_with("refresh") end,
    },
  }
end

-- Nav bar: prev button, centered month/year label, next button.
-- Next is disabled once the selected month is at or past the current month,
-- so the user cannot navigate into the future.
function M._navBar(f, state, properties, close_with)
  local atOrPastToday =
    state.year > state.todayYear
    or (state.year == state.todayYear and state.month >= state.todayMonth)

  return f:row {
    f:push_button {
      title = "<",
      action = function() close_with("prev") end,
    },
    f:spacer { fill_horizontal = 1 },
    f:static_text {
      title = MONTH_NAMES[state.month] .. " " .. tostring(state.year),
      font = "<system/bold>",
      alignment = "center",
      width_in_chars = 20,
    },
    f:spacer { fill_horizontal = 1 },
    f:push_button {
      title = ">",
      enabled = not atOrPastToday,
      action = function() close_with("next") end,
    },
  }
end

-- Builds the complete dialog contents for a single month render.
--
-- `state` shape: {
--   collections     = { { title = string, value = LrCollection }, ... },
--   collectionValue = <LrCollection currently selected>,
--   year            = integer,
--   month           = 1..12,
--   cells           = array of { day, primary, extras } for this month,
--   firstWeekday    = 1..7 (1 = Sunday),
-- }
--
-- `properties` is an LrBinding property table; buttons mutate `properties.action`
-- to signal the navigation loop which transition to take.
function M.build(state, properties)
  local f = LrView.osFactory()
  -- Forward-declare the root view so button callbacks can reference it.
  -- LrDialogs.stopModalWithResult needs a view that lives inside the
  -- currently-presented modal to walk up and find the dialog; the root view
  -- is the surest bet.
  local root
  local function close_with(result)
    LrDialogs.stopModalWithResult(root, result)
  end

  root = f:column {
    spacing = 10,
    bind_to_object = properties,

    M._topBar(f, state, properties, close_with),
    M._navBar(f, state, properties, close_with),
    f:separator { fill_horizontal = 1 },
    M._weekdayHeader(f),
    f:scrolled_view {
      -- Cells now include a "Day N" label beneath the thumbnail, so the
      -- vertical footprint grows by ~24px per row (label + spacing).
      width = (CELL_SIZE + 4) * 7 + 20,
      height = (CELL_SIZE + 28) * 6 + 20,
      M._grid(f, state.cells, state.firstWeekday),
    },
  }
  return root
end

return M
