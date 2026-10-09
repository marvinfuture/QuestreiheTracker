local _, ns = ...
local WoW, LiveData = ns.WoW, ns.LiveData
WoW.questLines = { maps = {} }
local state = WoW.questLines

local function supported()
    return C_QuestLine and type(C_QuestLine.RequestQuestLinesForMap) == "function"
        and type(C_QuestLine.GetAvailableQuestLines) == "function"
        and type(C_QuestLine.GetQuestLineQuests) == "function"
end

local function mapInfo(mapID)
    return WoW.Call(C_Map and C_Map.GetMapInfo, mapID)
end

local function currentZone()
    local mapID = WoW.Call(C_Map and C_Map.GetBestMapForUnit, "player")
    if not LiveData.IsID(mapID) then return nil end
    local original, seen = mapID, {}
    -- Prefer the zone for city/subzone maps; never scan continents or the world.
    for _ = 1, 10 do
        if seen[mapID] then break end
        seen[mapID] = true
        local info = mapInfo(mapID)
        if type(info) ~= "table" or not Enum or not Enum.UIMapType then break end
        if info.mapType == Enum.UIMapType.Zone then return mapID end
        if not LiveData.IsID(info.parentMapID) then break end
        mapID = info.parentMapID
    end
    return original
end

local function requestMap(mapID, force)
    if not LiveData.IsID(mapID) then return end
    local map = state.maps[mapID]
    if not map then
        local info = mapInfo(mapID)
        map = { mapID = mapID, name = type(info) == "table" and info.name or tostring(mapID),
            chains = {}, byID = {} }
        state.maps[mapID] = map
    else
        local info = mapInfo(mapID)
        if type(info) == "table" and type(info.name) == "string" then map.name = info.name end
    end
    if not supported() then map.error = "UNSUPPORTED"; return map end
    if force or not map.requested then
        -- Set state first: Blizzard can dispatch events during a request.
        map.requested, map.loaded, map.error, map.requestFailed = true, false, nil, false
        map.requesting = true
        if not pcall(C_QuestLine.RequestQuestLinesForMap, mapID) then
            map.error, map.requestFailed = "ERROR", true
        end
        map.requesting = nil
    end
    return map
end

function WoW.DiscoverZone(force)
    state.currentMapID = currentZone()
    if state.currentMapID then requestMap(state.currentMapID, force) end
    if force and ns.chain and ns.chain.runtime and ns.chain.mapID ~= state.currentMapID then
        requestMap(ns.chain.mapID, true)
    end
end

function WoW.GetQuestLine(id)
    for _, map in pairs(state.maps) do
        if map.byID[id] then return map.byID[id] end
    end
end

-- Lookup maps are request contexts, not claims about a quest's location.
function WoW.RequestQuestLineMap(mapID)
    return requestMap(mapID, true)
end

local function preserveName(chain, previous)
    if not chain.nameKnown and previous and previous.questLineID == chain.questLineID and previous.nameKnown then
        chain.name, chain.nameKnown, chain.nameSourceAPI = previous.name, true, previous.nameSourceAPI
    end
end

-- Map discovery can omit completed/filtered lines or return membership before
-- the localized name. Only a matching line association can supply its name.
function WoW.ResolveQuestLineName(chain)
    if type(chain) ~= "table" or not chain.runtime or chain.nameKnown
        or not LiveData.IsID(chain.questLineID) or not LiveData.IsID(chain.mapID)
        or type(C_QuestLine and C_QuestLine.GetQuestLineInfo) ~= "function" then return chain end
    for _, section in ipairs(chain.sections or {}) do
        for _, quest in ipairs(section.quests or {}) do
            if LiveData.IsID(quest.questID) then
                for context = 1, 2 do
                    local mapID = context == 2 and chain.mapID or nil
                    local info = WoW.Call(C_QuestLine.GetQuestLineInfo, quest.questID, mapID, false)
                    if type(info) == "table" and info.questLineID == chain.questLineID
                        and LiveData.IsName(info.questLineName) then
                        chain.name, chain.nameKnown = info.questLineName, true
                        chain.nameSourceAPI = "C_QuestLine.GetQuestLineInfo"
                        return chain
                    end
                end
            end
        end
    end
    return chain
end

function WoW.RegisterQuestLine(chain)
    if type(chain) ~= "table" or not chain.runtime or not LiveData.IsID(chain.mapID)
        or not LiveData.IsID(chain.questLineID) then return nil end
    local map = state.maps[chain.mapID]
    if not map then
        local info = mapInfo(chain.mapID)
        map = { mapID = chain.mapID, name = type(info) == "table" and info.name or tostring(chain.mapID),
            chains = {}, byID = {} }
        state.maps[chain.mapID] = map
    end
    preserveName(chain, map.byID[chain.id])
    map.byID[chain.id] = chain
    return chain
end

function WoW.RestoreQuestLine(selection)
    if type(selection) ~= "table" or not LiveData.IsID(selection.mapID)
        or not LiveData.IsID(selection.questLineID) then return nil end
    local map = requestMap(selection.mapID)
    local chain = LiveData.Pending(selection.mapID, selection.questLineID)
    map.byID[chain.id] = map.byID[chain.id] or chain
    return map.byID[chain.id]
end

local function resolveSelectedName(map, selected)
    if selected and selected.mapID == map.mapID then
        WoW.ResolveQuestLineName(map.byID[selected.id] or selected)
    end
end

local function readMap(map, selected)
    if map.needsRequest then
        map.needsRequest = nil
        requestMap(map.mapID, true)
    end
    if not supported() then
        map.error = "UNSUPPORTED"
        resolveSelectedName(map, selected)
        return
    end
    local infos = WoW.Call(C_QuestLine.GetAvailableQuestLines, map.mapID)
    if type(infos) ~= "table" then
        map.error = "ERROR"
        resolveSelectedName(map, selected)
        return
    end
    if not map.requestFailed then map.error = nil end
    local chains, seen, selectedName = {}, {}, nil
    for _, info in ipairs(infos) do
        if selected and selected.mapID == map.mapID and type(info) == "table"
            and info.questLineID == selected.questLineID and LiveData.IsName(info.questLineName) then
            selectedName = info.questLineName
        end
        if type(info) == "table" and LiveData.IsID(info.questLineID) and not info.isHidden then
            local id = LiveData.Key(map.mapID, info.questLineID)
            if not seen[id] then
                local questIDs = WoW.Call(C_QuestLine.GetQuestLineQuests, info.questLineID)
                local chain = LiveData.Build(map.mapID, info, questIDs)
                    or LiveData.Pending(map.mapID, info.questLineID, info.questLineName)
                preserveName(chain, map.byID[id])
                -- A transient empty quest cache must not erase a loaded selection.
                if chain.loading and map.byID[id] and not map.byID[id].loading then
                    preserveName(map.byID[id], chain)
                    chain = map.byID[id]
                    chain.suggestedQuestID = nil
                end
                chains[#chains + 1], map.byID[id], seen[id] = chain, chain, true
            end
        end
    end
    map.chains = chains
    if #infos > 0 then map.loaded = true end
    -- Completed/filtered lines can disappear from map discovery. Keep the user's
    -- selected membership, but remove its stale map-based next-step suggestion.
    if selected and selected.mapID == map.mapID and not seen[selected.id] then
        local info = { questLineID = selected.questLineID,
            questLineName = selected.nameKnown and selected.name or nil }
        local chain = LiveData.Build(map.mapID, info, WoW.Call(C_QuestLine.GetQuestLineQuests, selected.questLineID))
            or map.byID[selected.id] or selected
        preserveName(chain, selected)
        if selected.nameKnown then chain.nameSourceAPI = selected.nameSourceAPI end
        chain.suggestedQuestID = nil
        chain.sourceAPI = selected.sourceAPI or chain.sourceAPI
        map.byID[selected.id] = chain
    end
    if selected and selected.mapID == map.mapID then
        local chain = map.byID[selected.id] or selected
        if selectedName then
            chain.name, chain.nameKnown, chain.nameSourceAPI = selectedName, true, "C_QuestLine.GetAvailableQuestLines"
        end
        WoW.ResolveQuestLineName(chain)
    end
    table.sort(chains, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name end)
end

function WoW.ReadQuestLineMap(mapID)
    local map = state.maps[mapID]
    if map then readMap(map, ns.chain and ns.chain.runtime and ns.chain or nil) end
    return map
end

function WoW.ReadQuestLines()
    local selected = ns.chain and ns.chain.runtime and ns.chain or nil
    local map = state.maps[state.currentMapID]
    if map then readMap(map, selected) end
    if selected and selected.mapID ~= state.currentMapID then
        local selectedMap = state.maps[selected.mapID]
        if selectedMap then readMap(selectedMap, selected) end
    end
    for mapID in pairs(WoW.questLookup and WoW.questLookup.maps or {}) do
        if mapID ~= state.currentMapID and (not selected or mapID ~= selected.mapID) then
            local lookupMap = state.maps[mapID]
            if lookupMap then readMap(lookupMap, selected) end
        end
    end
end

function WoW.OnQuestLineUpdate(requestRequired)
    local relevant = {}
    -- Restoration can dispatch this event before Core assigns the selection.
    for mapID, map in pairs(state.maps) do if map.requesting then relevant[mapID] = true end end
    if state.currentMapID then relevant[state.currentMapID] = true end
    if ns.chain and ns.chain.runtime then relevant[ns.chain.mapID] = true end
    for mapID in pairs(WoW.questLookup and WoW.questLookup.maps or {}) do relevant[mapID] = true end
    for mapID in pairs(relevant) do
        if requestRequired == true and state.maps[mapID] then state.maps[mapID].needsRequest = true
        elseif state.maps[mapID] then state.maps[mapID].loaded = true end
    end
end

function WoW.ZoneQuestLines()
    if not supported() then return {}, "UNSUPPORTED", nil end
    local map = state.maps[state.currentMapID]
    if not map then return {}, "NO_MAP", nil end
    local status = map.error or (#map.chains > 0 and "READY" or (map.loaded and "EMPTY" or "LOADING"))
    if not map.error and #map.chains > 0 then
        local ready = false
        for _, chain in ipairs(map.chains) do if not chain.loading then ready = true; break end end
        if not ready then status = "LOADING" end
    end
    return map.chains, status, map.name
end
