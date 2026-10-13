local _, ns = ...
local WoW, LiveData = ns.WoW, ns.LiveData
-- Blizzard's generated MapDocumentation and QuestLineInfoDocumentation define
-- map-tree enumeration and client-supplied membership; no catalogue is bundled.
local maximumMaps, maximumQuests, maximumLogEntries = 400, 100, 1000
local mapBudget, mapReadBudget, questBudget = 6, 12, 4
local waitSeconds, waitReads, maximumAdvances = 5, 50, 250

-- Read time defensively; the iteration ceiling also bounds clients without a clock.
local function now()
    local value = WoW.Call(GetTime)
    if type(value) == "number" and value == value and value > -math.huge and value < math.huge then return value end
    return 0
end

-- Cancel discovery without clearing shared lines or an unrelated manual ID lookup.
function WoW.ResetNameDiscovery()
    if WoW.questLookup and WoW.questLookup.nameDiscovery then WoW.ResetQuestLookup() end
    WoW.nameDiscovery = nil
end

-- Deduplicate validated map IDs while retaining the current zone's priority.
local function addMap(state, mapID)
    if not LiveData.IsID(mapID) then state.partial = true; return end
    if state.queuedMaps[mapID] then return end
    if #state.mapQueue >= maximumMaps then state.partial = true; return end
    state.mapQueue[#state.mapQueue + 1], state.queuedMaps[mapID] = mapID, true
end

-- Collect accepted quests only; individual quest titles never become search names.
local function collectQuests(state)
    if not state.questSupported then return end
    local count = WoW.Call(C_QuestLog.GetNumQuestLogEntries)
    if type(count) ~= "number" or count < 0 or count >= math.huge or count ~= math.floor(count) then
        state.partial = true; return
    end
    if count > maximumLogEntries then count, state.partial = maximumLogEntries, true end
    for entry = 1, count do
        local info = WoW.Call(C_QuestLog.GetInfo, entry)
        if type(info) == "table" and not info.isHeader and LiveData.IsID(info.questID)
            and not state.questSeen[info.questID]
            and WoW.Call(C_QuestLog.IsOnQuest, info.questID) == true then
            if #state.questQueue >= maximumQuests then state.partial = true; break end
            state.questQueue[#state.questQueue + 1], state.questSeen[info.questID] = info.questID, true
        end
    end
end

-- Enumerate supplied zone maps under the client's world-map root, not guessed IDs.
local function collectMaps(state)
    if LiveData.IsID(WoW.questLines.currentMapID) then addMap(state, WoW.questLines.currentMapID) end
    local known = {}
    for mapID in pairs(WoW.questLines.maps) do
        if LiveData.IsID(mapID) then known[#known + 1] = mapID end
    end
    table.sort(known)
    for _, mapID in ipairs(known) do addMap(state, mapID) end
    if type(C_Map and C_Map.GetMapInfo) ~= "function" or type(C_Map.GetMapChildrenInfo) ~= "function"
        or not Enum or not Enum.UIMapType or type(Enum.UIMapType.Zone) ~= "number" then
        state.partial = true; return
    end
    local root = WoW.Call(C_Map.GetFallbackWorldMapID)
    if not LiveData.IsID(root) then
        state.partial = true
        root = WoW.questLines.currentMapID
        if not LiveData.IsID(root) then root = WoW.Call(C_Map.GetBestMapForUnit, "player") end
    end
    if not LiveData.IsID(root) then state.partial = true; return end
    local seen, complete = {}, false
    for _ = 1, 10 do
        if seen[root] then state.partial = true; break end
        seen[root] = true
        local info = WoW.Call(C_Map.GetMapInfo, root)
        if type(info) ~= "table" then state.partial = true; break end
        if not LiveData.IsID(info.parentMapID) then complete = true; break end
        root = info.parentMapID
    end
    if not complete then state.partial = true end
    local children = WoW.Call(C_Map.GetMapChildrenInfo, root, Enum.UIMapType.Zone, true)
    if type(children) ~= "table" then state.partial = true; return end
    local maps = {}
    for entry, info in ipairs(children) do
        if entry > maximumMaps * 2 then state.partial = true; break end
        if type(info) == "table" and LiveData.IsID(info.mapID)
            and (info.mapType == nil or info.mapType == Enum.UIMapType.Zone) then
            maps[#maps + 1] = info.mapID
        else state.partial = true end
    end
    table.sort(maps)
    for _, mapID in ipairs(maps) do addMap(state, mapID) end
end

-- Start one bounded query, preserving runtime cache payloads across submissions.
local function newDiscovery(query)
    local state = { query = query, maps = {}, mapQueue = {}, queuedMaps = {}, mapCursor = 1,
        pending = {}, pendingByMap = {}, readCursor = 1, questQueue = {}, questSeen = {}, questCursor = 1,
        advances = 0, retries = {}, status = "LOADING" }
    state.mapSupported = type(C_QuestLine and C_QuestLine.RequestQuestLinesForMap) == "function"
        and type(C_QuestLine.GetAvailableQuestLines) == "function"
        and type(C_QuestLine.GetQuestLineQuests) == "function"
    state.questSupported = type(C_QuestLine and C_QuestLine.GetQuestLineInfo) == "function"
        and type(C_QuestLine.GetQuestLineQuests) == "function"
        and type(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) == "function"
        and type(C_QuestLog.GetInfo) == "function" and type(C_QuestLog.IsOnQuest) == "function"
    if state.mapSupported then collectMaps(state) else state.partial = true end
    if state.questSupported then collectQuests(state) else state.partial = true end
    state.unsupported = not state.mapSupported and not state.questSupported
    return state
end

-- Queue a map once; later events only reread already requested maps in bounded batches.
local function pendingMap(state, mapID, recheck)
    if state.pendingByMap[mapID] then return end
    local node = { mapID = mapID, started = now(), reads = 0, recheck = recheck }
    state.pending[#state.pending + 1], state.pendingByMap[mapID] = node, node
end

-- A new request retries previously missing maps once; event rechecks never force requests.
local function requestMaps(state)
    for _ = 1, mapBudget do
        local mapID = state.mapQueue[state.mapCursor]
        if not mapID then break end
        state.mapCursor = state.mapCursor + 1
        state.maps[mapID] = true
        local map = WoW.questLines.maps[mapID]
        if not map or not map.requested or map.error or not map.loaded then
            if not state.retries[mapID] then
                state.retries[mapID] = true
                map = WoW.RequestQuestLineMap(mapID)
            end
        end
        if map then pendingMap(state, mapID) else state.partial = true end
    end
end

-- Read each pending map at most once per continuation, retaining unavailable membership.
local function readMaps(state)
    local selected, count = {}, #state.pending
    if count == 0 then return end
    if state.readCursor > count then state.readCursor = 1 end
    local cursor = state.readCursor
    for _ = 1, math.min(mapReadBudget, count) do
        selected[#selected + 1] = state.pending[cursor]
        cursor = cursor % count + 1
    end
    local following = state.pending[cursor]
    for _, node in ipairs(selected) do
        local map = WoW.ReadQuestLineMap(node.mapID)
        node.reads = node.reads + 1
        local waiting = map and not map.error and not map.loaded
        if map and not map.error then
            for _, chain in ipairs(map.chains or {}) do if chain.loading then waiting = true; break end end
        end
        local expired = node.reads >= waitReads or now() - node.started >= waitSeconds
        if not map or map.error then state.partial = true end
        if waiting and expired then state.partial = true end
        if not waiting or expired or node.recheck then
            state.pendingByMap[node.mapID] = nil
            for entry, candidate in ipairs(state.pending) do
                if candidate == node then table.remove(state.pending, entry); break end
            end
        end
    end
    state.readCursor = 1
    for entry, node in ipairs(state.pending) do
        if node == following then state.readCursor = entry; break end
    end
end

-- Resolve accepted quests sequentially through the exact same verified ID lookup.
local function readQuests(state)
    for _ = 1, questBudget do
        local questID = state.questQueue[state.questCursor]
        if not questID then return end
        if not state.activeQuest then
            state.activeQuest = { questID = questID, started = now(), reads = 0 }
            WoW.ResetQuestLookup()
            WoW.questLookup = { questID = questID, maps = {}, nameDiscovery = true }
        end
        local active = state.activeQuest
        local chain, status = WoW.FindQuestLine(questID)
        active.reads = active.reads + 1
        if chain then state.maps[chain.mapID] = true end
        for mapID in pairs(WoW.questLookup and WoW.questLookup.maps or {}) do state.maps[mapID] = true end
        local expired = active.reads >= waitReads or now() - active.started >= waitSeconds
        if status == "LOADING" and not expired then return end
        if status ~= "READY" and status ~= "NOT_FOUND" and status ~= "NO_MAP" then state.partial = true end
        if status == "LOADING" then state.partial = true end
        state.activeQuest, state.questCursor = nil, state.questCursor + 1
        WoW.ResetQuestLookup()
    end
end

-- Revisit queried caches on client events without re-requesting the completed map tree.
function WoW.OnNameDiscoveryQuestLineUpdate()
    local state = WoW.nameDiscovery
    if not state then return end
    if state.done then
        local mapIDs = {}
        for mapID in pairs(state.maps) do mapIDs[#mapIDs + 1] = mapID end
        table.sort(mapIDs)
        for _, mapID in ipairs(mapIDs) do pendingMap(state, mapID, true) end
        collectQuests(state)
        state.questCursor = 1
        state.done, state.advances = false, 0
    end
end

-- Advance finite runtime discovery; terminal calls remain idle until an actual data event.
function WoW.AdvanceNameDiscovery(query)
    local state = WoW.nameDiscovery
    if not state or state.query ~= query then
        WoW.ResetNameDiscovery()
        state = newDiscovery(query)
        WoW.nameDiscovery = state
    end
    if state.done then return state.status end
    if state.unsupported then state.done, state.status = true, "UNSUPPORTED"; return state.status end
    state.advances = state.advances + 1
    if state.advances > maximumAdvances then
        state.partial, state.done, state.status = true, true, "PARTIAL"
        state.pending, state.pendingByMap, state.activeQuest = {}, {}, nil
        WoW.ResetQuestLookup()
        return state.status
    end
    requestMaps(state)
    readMaps(state)
    readQuests(state)
    if state.mapCursor <= #state.mapQueue or #state.pending > 0 or state.questCursor <= #state.questQueue then
        state.status = "LOADING"
    else
        state.done, state.status = true, state.partial and "PARTIAL" or "READY"
    end
    return state.status
end
