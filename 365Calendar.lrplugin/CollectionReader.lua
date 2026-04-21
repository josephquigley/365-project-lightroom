-- CollectionReader: loads photo data from a Lightroom collection.
-- Isolates LR catalog I/O so the rest of the plugin can stay pure or stubbed.

local LrApplication = import "LrApplication"

local M = {}

-- Returns an array of regular (non-smart) LrCollection objects, recursively
-- walked from the active catalog's root. Smart collections are excluded --
-- see design spec, "Out of scope".
function M.listRegularCollections()
  local catalog = LrApplication.activeCatalog()
  local result = {}

  local function walk(children)
    for _, c in ipairs(children) do
      if c:type() == "LrCollection" and not c:isSmartCollection() then
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

-- Returns the array of LrPhoto objects in the given collection.
function M.loadPhotos(collection)
  return collection:getPhotos()
end

-- Returns the first regular (non-smart) collection currently selected as a
-- source in the Library, or nil if none is selected.
function M.activeRegularCollection()
  local catalog = LrApplication.activeCatalog()
  local sources = catalog:getActiveSources() or {}
  for _, src in ipairs(sources) do
    if type(src) == "table" and src.type and src:type() == "LrCollection"
       and not src:isSmartCollection() then
      return src
    end
  end
  return nil
end

return M
