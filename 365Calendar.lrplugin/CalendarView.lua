-- CalendarView: builds the LrView tree for the calendar dialog.
-- All functions are pure with respect to their inputs -- they return view
-- descriptors, never calling LR APIs directly.

local LrView  = import "LrView"
local LrColor = import "LrColor"

local M = {}

local CELL_SIZE = 80

local COLOR_MISSING_BG  = LrColor(0.95, 0.85, 0.85)
local COLOR_MISSING_FG  = LrColor(0.55, 0.25, 0.25)
local COLOR_OVERLAY_FG  = LrColor(1, 1, 1)
local COLOR_OVERLAY_BG  = LrColor(0.15, 0.15, 0.15)  -- opaque dark; LrColor alpha support is unreliable

-- A present-day cell: catalog photo thumbnail with overlaid day number and
-- "+N" badge (visible only when extras > 0).
function M._presentCell(f, cell)
  return f:place {
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
  }
end

-- A missing-day cell: soft-red filled box with centered day number.
function M._missingCell(f, cell)
  return f:view {
    width = CELL_SIZE, height = CELL_SIZE,
    background_color = COLOR_MISSING_BG,
    f:static_text {
      title = tostring(cell.day),
      text_color = COLOR_MISSING_FG,
      place_horizontal = 0.5,
      place_vertical = 0.5,
    },
  }
end

-- A blank cell: used for leading/trailing spacer slots to align the grid.
function M._blankCell(f)
  return f:view {
    width = CELL_SIZE, height = CELL_SIZE,
  }
end

local WEEKDAY_LABELS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

function M._weekdayHeader(f)
  local row = f:row { spacing = 4 }
  for _, label in ipairs(WEEKDAY_LABELS) do
    table.insert(row, f:static_text {
      title = label,
      width = CELL_SIZE,
      alignment = "center",
    })
  end
  return row
end

return M
