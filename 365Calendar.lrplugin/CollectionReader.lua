-- CollectionReader: loads photo data from a Lightroom collection.
-- Isolates LR catalog I/O so the rest of the plugin can stay pure or stubbed.

local LrApplication = import "LrApplication"

local M = {}

-- Returns an array of LrCollection objects (smart and regular) walked
-- recursively from the active catalog's root.
function M.listCollections()
  local catalog = LrApplication.activeCatalog()
  local result = {}

  local function walk(children)
    for _, c in ipairs(children) do
      if c:type() == "LrCollection" then
        table.insert(result, c)
      end
      if c:type() == "LrCollectionSet" then
        walk(c:getChildCollections())
        walk(c:getChildCollectionSets())
      end
    end
  end

  walk(catalog:getChildCollections())
  walk(catalog:getChildCollectionSets())
  return result
end

-- Returns a human-readable path-prefixed name like "Trips/2026/Iceland" for
-- disambiguation in the picker.
function M.qualifiedName(collection)
  local parts = { collection:getName() }
  local parent = collection:getParent()
  while parent do
    table.insert(parts, 1, parent:getName())
    parent = parent:getParent()
  end
  return table.concat(parts, "/")
end

-- Returns the dropdown label for a collection: the qualified path, with
-- " [smart]" appended when the collection is rule-driven.
function M.displayLabel(collection)
  local name = M.qualifiedName(collection)
  if collection:isSmartCollection() then
    return name .. " [smart]"
  end
  return name
end

-- Returns the array of LrPhoto objects in the given collection.
function M.loadPhotos(collection)
  return collection:getPhotos()
end

-- Returns the first active LrCollection source (smart or regular) from
-- the Library's active sources, or nil if none is selected.
function M.activeCollection()
  local catalog = LrApplication.activeCatalog()
  local sources = catalog:getActiveSources() or {}
  for _, src in ipairs(sources) do
    if type(src) == "table" and src.type and src:type() == "LrCollection" then
      return src
    end
  end
  return nil
end

return M
