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

local MONTH_SHORT_NAMES = {
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
}

-- Top bar: a "Day N" header above a row with the collection picker, the
-- view-mode toggle, and the refresh button. The toggle is two
-- push_buttons; the one matching the current view is disabled to act as
-- a selected state. Clicking a button closes the modal with a
-- "view:<mode>" result so the dialog loop re-presents in the new mode.
--
-- `state.view` is "calendar" or "missing".
-- `state.todayProjectDay` is a number, or nil when the collection is empty.
function M._topBar(f, state, properties, close_with)
  local dayPart = state.todayProjectDay
    and ("Day " .. tostring(state.todayProjectDay))
    or "Day —"
  local dateLabel = string.format(
    "%s %d, %d — %s",
    MONTH_NAMES[state.today.month], state.today.day, state.today.year, dayPart)

  return f:column {
    spacing = 6,
    f:static_text {
      title = dateLabel,
      font = "<system/bold>",
    },
    f:row {
      spacing = 8,
      f:static_text { title = "Collection:" },
      f:popup_menu {
        items = state.collections,
        value = LrView.bind { key = "collectionValue", object = properties },
        width_in_chars = 30,
      },
      f:push_button {
        title = "Calendar",
        enabled = state.view ~= "calendar",
        action = function() close_with("view:calendar") end,
      },
      f:push_button {
        title = "Missing",
        enabled = state.view ~= "missing",
        action = function() close_with("view:missing") end,
      },
      f:push_button {
        title = "Refresh",
        action = function() close_with("refresh") end,
      },
    },
  }
end

-- A vertical text list of missing-day entries, grouped under a bold
-- year heading. Each row reads "MMM D (Day N)" -- e.g., "Feb 3 (Day 5)".
-- Entries arrive sorted ascending, so same-year runs are contiguous and
-- we emit a new heading whenever the year changes. Children are built
-- into an args table first, because LrView finalizes children at
-- construction and post-hoc table.insert on a completed column is
-- silently dropped.
-- `entry` shape: { year, month, day, project_day }.
function M._missingList(f, entries)
  local columnArgs = { spacing = 2 }
  local current_year = nil
  for _, entry in ipairs(entries) do
    if entry.year ~= current_year then
      current_year = entry.year
      columnArgs[#columnArgs + 1] = f:static_text {
        title = tostring(current_year),
        font = "<system/bold>",
      }
    end
    columnArgs[#columnArgs + 1] = f:static_text {
      title = string.format(
        "%s %d (Day %d)",
        MONTH_SHORT_NAMES[entry.month], entry.day, entry.project_day),
    }
  end
  return f:column(columnArgs)
end

-- Indent applied to every row inside the Missing view so the text
-- isn't jammed against the left edge of the scrolled view.
local MISSING_INDENT = 16

-- Content region for the Missing view: a one-line summary plus the grid
-- (or a full-width message, when the edge cases apply).
-- Shapes:
--   empty collection        -> "No photos in this collection."
--   non-empty, zero missing -> "You're caught up -- no missing days."
--   otherwise               -> "N missing" line, then grid
function M._missingContent(f, state)
  if not state.todayProjectDay then
    return f:column {
      spacing = 8,
      margin_left = MISSING_INDENT,
      f:static_text { title = "No photos in this collection." },
    }
  end
  if #state.missingDays == 0 then
    return f:column {
      spacing = 8,
      margin_left = MISSING_INDENT,
      f:static_text { title = "You're caught up — no missing days." },
    }
  end
  return f:column {
    spacing = 8,
    margin_left = MISSING_INDENT,
    f:static_text {
      title = tostring(#state.missingDays) .. " missing",
      font = "<system/bold>",
    },
    M._missingList(f, state.missingDays),
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
    fill_horizontal = 1,
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

  local children = {
    spacing = 10,
    bind_to_object = properties,

    M._topBar(f, state, properties, close_with),
  }

  -- The top bar is wider than the calendar grid (collection popup + view
  -- toggles + refresh + Day N counter), so the dialog window ends up
  -- wider than the grid's natural footprint. Wrap the scrolled views in
  -- a filling row with flanking spacers so the content stays centered in
  -- the available width instead of clinging to the left edge.
  local function centered(view)
    return f:row {
      fill_horizontal = 1,
      f:spacer { fill_horizontal = 1 },
      view,
      f:spacer { fill_horizontal = 1 },
    }
  end

  -- Natural width of the 7-column grid (7 cells + 6 inter-cell gaps).
  -- The scrolled view needs extra horizontal padding for its scrollbar
  -- gutter; without it a vertical scrollbar steals from cell space and
  -- triggers a horizontal scrollbar too. The weekday header sits in a
  -- column of the same outer width so its cells share a left edge with
  -- the grid cells below it.
  local GRID_WIDTH   = CELL_SIZE * 7 + 4 * 6
  local GRID_HEIGHT  = (CELL_SIZE + 28) * 6 + 20
  local SCROLL_WIDTH = GRID_WIDTH + 20

  if state.view == "missing" then
    children[#children + 1] = f:separator { fill_horizontal = 1 }
    children[#children + 1] = centered(f:scrolled_view {
      width  = GRID_WIDTH,
      height = GRID_HEIGHT,
      M._missingContent(f, state),
    })
  else
    children[#children + 1] = M._navBar(f, state, properties, close_with)
    children[#children + 1] = f:separator { fill_horizontal = 1 }
    -- Pack the weekday header and the grid's scrolled view inside a
    -- single column, then center that column. Both children are
    -- naturally GRID_WIDTH wide, so they align column-for-column from
    -- a shared left edge instead of being centered independently (which
    -- risks mismatched midpoints if Lightroom's layout rounds widths).
    children[#children + 1] = centered(f:column {
      spacing = 4,
      width = SCROLL_WIDTH,
      M._weekdayHeader(f),
      f:scrolled_view {
        -- Cells include a "Day N" label beneath the thumbnail, so the
        -- vertical footprint grows by ~24px per row (label + spacing).
        width  = SCROLL_WIDTH,
        height = GRID_HEIGHT,
        M._grid(f, state.cells, state.firstWeekday),
      },
    })
  end

  root = f:column(children)
  return root
end

return M
