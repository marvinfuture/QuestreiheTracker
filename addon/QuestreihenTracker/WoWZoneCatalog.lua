local _, ns = ...
local WoW, LiveData = ns.WoW, ns.LiveData
-- C_Map.GetMapChildrenInfo filters runtime UiMapDetails by UIMapType.Zone.
-- API source: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua
local maximumZones, maximumEntries, maximumParents = 10000, 20000, 16
local catalog

-- Discard only addon-owned map names; no Blizzard caches or quest requests are affected.
function WoW.ClearZoneCatalog()
    catalog = nil
end

-- Enumerate the client's supplied zones without the smaller name-discovery request ceiling.
function WoW.GetZoneCatalog(force)
    if force then catalog = nil end
    if catalog then return catalog.rows, catalog.status, catalog.metadata end
    local rows, metadata = {}, { partial = false, truncated = false, count = 0 }
    -- Store the bounded name-only result and its support or completeness metadata.
    local function finish(status)
        metadata.count = #rows
        if status == "ERROR" or status == "UNSUPPORTED" then metadata.error = status end
        if status == "ERROR" then metadata.partial = true end
        catalog = { rows = rows, status = status, metadata = metadata }
        return rows, status, metadata
    end
    if type(C_Map and C_Map.GetMapInfo) ~= "function" or type(C_Map.GetMapChildrenInfo) ~= "function"
        or not Enum or not Enum.UIMapType or type(Enum.UIMapType.Zone) ~= "number" then
        return finish("UNSUPPORTED")
    end
    local infos, missing = {}, {}
    -- Memoize parent information only while constructing the small name-only catalog.
    local function infoFor(mapID)
        if not LiveData.IsID(mapID) then return nil end
        if infos[mapID] then return infos[mapID] end
        if missing[mapID] then return nil end
        local info = WoW.Call(C_Map.GetMapInfo, mapID)
        if type(info) ~= "table" then missing[mapID] = true; return nil end
        infos[mapID] = info
        return info
    end
    local root = WoW.Call(C_Map.GetFallbackWorldMapID)
    if not LiveData.IsID(root) then
        root = WoW.questLines.currentMapID or WoW.Call(C_Map.GetBestMapForUnit, "player")
        metadata.partial = true
    end
    if not LiveData.IsID(root) then return finish("ERROR") end
    local seen, foundRoot = {}, false
    for _ = 1, maximumParents do
        if seen[root] then metadata.partial = true; break end
        seen[root] = true
        local info = infoFor(root)
        if not info then metadata.partial = true; break end
        if not LiveData.IsID(info.parentMapID) then foundRoot = true; break end
        root = info.parentMapID
    end
    if not foundRoot then metadata.partial = true end
    metadata.rootMapID = root
    local children = WoW.Call(C_Map.GetMapChildrenInfo, root, Enum.UIMapType.Zone, true)
    if type(children) ~= "table" then return finish("ERROR") end
    local rootInfo = infoFor(root)
    local fallbackGroup = rootInfo and LiveData.IsName(rootInfo.name) and rootInfo.name or nil
    -- Find the nearest continent through real parent links, never a fixed ID table.
    local function continent(info)
        local visited, parentID = {}, info.parentMapID
        for _ = 1, maximumParents do
            if not LiveData.IsID(parentID) then return fallbackGroup end
            if visited[parentID] then metadata.partial = true; return fallbackGroup end
            visited[parentID] = true
            local parent = infoFor(parentID)
            if not parent then metadata.partial = true; return fallbackGroup end
            if type(Enum.UIMapType.Continent) == "number" and parent.mapType == Enum.UIMapType.Continent then
                if LiveData.IsName(parent.name) then return parent.name end
                metadata.partial = true
                return fallbackGroup
            end
            parentID = parent.parentMapID
        end
        metadata.partial = true
        return fallbackGroup
    end
    seen = {}
    for entry, supplied in ipairs(children) do
        if entry > maximumEntries then metadata.partial, metadata.truncated = true, true; break end
        if type(supplied) == "table" and LiveData.IsID(supplied.mapID) then
            local mapID = supplied.mapID
            local info = supplied
            -- Verify incomplete responses rather than admitting cities into the zone list.
            if info.mapType == nil or not LiveData.IsName(info.name) or info.parentMapID == nil then
                info = infoFor(mapID) or supplied
            else infos[mapID] = supplied end
            if info.mapType == Enum.UIMapType.Zone and not seen[mapID] then
                if #rows >= maximumZones then metadata.partial, metadata.truncated = true, true; break end
                local name = LiveData.IsName(info.name) and info.name or tostring(mapID)
                if not LiveData.IsName(info.name) then metadata.partial = true end
                rows[#rows + 1] = { mapID = mapID, name = name, groupName = continent(info) }
                seen[mapID] = true
            elseif info.mapType ~= Enum.UIMapType.Zone then metadata.partial = true end
        else metadata.partial = true end
    end
    table.sort(rows, function(a, b)
        if a.groupName ~= b.groupName then return (a.groupName or "") < (b.groupName or "") end
        if a.name ~= b.name then return a.name < b.name end
        return a.mapID < b.mapID
    end)
    return finish(metadata.partial and "PARTIAL" or "READY")
end
