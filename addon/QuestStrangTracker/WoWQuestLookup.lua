local _, ns = ...
local WoW, LiveData = ns.WoW, ns.LiveData
local dataResults = {}

local function call(fn, ...)
    if type(fn) ~= "function" then return nil, false end
    local ok, value = pcall(fn, ...)
    return value, ok
end

function WoW.ResetQuestLookup()
    WoW.questLookup = nil
end

function WoW.OnQuestLookupDataLoadResult(questID, success)
    if not LiveData.IsID(questID) or type(success) ~= "boolean" then return end
    dataResults[questID] = success
    local lookup = WoW.questLookup
    if lookup and lookup.questID == questID then
        lookup.dataFinished, lookup.dataFailed = true, success == false
    end
end

function WoW.SuperTrackedQuestID()
    if type(C_SuperTrack and C_SuperTrack.IsSuperTrackingQuest) ~= "function"
        or type(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) ~= "function" then return nil, "UNSUPPORTED" end
    local tracking, ok = call(C_SuperTrack.IsSuperTrackingQuest)
    if not ok then return nil, "ERROR" end
    if tracking ~= true then return nil, "NO_TRACKED" end
    if type(C_SuperTrack.GetHighestPrioritySuperTrackingType) == "function"
        and Enum and Enum.SuperTrackingType and Enum.SuperTrackingType.Quest ~= nil then
        local kind, readOK = call(C_SuperTrack.GetHighestPrioritySuperTrackingType)
        if not readOK then return nil, "ERROR" end
        if kind ~= Enum.SuperTrackingType.Quest then return nil, "NO_TRACKED" end
    end
    local questID, readOK = call(C_SuperTrack.GetSuperTrackedQuestID)
    if not readOK then return nil, "ERROR" end
    if not LiveData.IsID(questID) then return nil, "NO_TRACKED" end
    return questID, "READY"
end

local function member(chain, questID)
    if chain.empty or chain.loading then return false end
    local _, byID = ns.Model.Flatten(chain)
    return byID[questID] ~= nil
end

local function cached(questID)
    local ids, byID = {}, {}
    for _, map in pairs(WoW.questLines.maps) do
        for id, chain in pairs(map.byID) do
            if member(chain, questID) then ids[#ids + 1], byID[id] = id, chain end
        end
    end
    table.sort(ids)
    return byID[ids[1]]
end

local function mapContext(questID, info)
    if info and LiveData.IsID(info.startMapID) then return info.startMapID end
    local mapID = WoW.Call(GetQuestUiMapID, questID)
    if LiveData.IsID(mapID) then return mapID end
    mapID = WoW.questLines.currentMapID
    if LiveData.IsID(mapID) then return mapID end
    return nil
end

local function requestData(lookup)
    if lookup.dataRequested then return end
    lookup.dataRequested = true
    local title = WoW.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, lookup.questID)
    if type(title) == "string" and title ~= "" then lookup.dataFinished = true; return end
    if dataResults[lookup.questID] == false and not WoW.requested[lookup.questID] then
        dataResults[lookup.questID] = nil
    end
    if dataResults[lookup.questID] ~= nil then
        lookup.dataFinished, lookup.dataFailed = true, dataResults[lookup.questID] == false
        return
    end
    if type(C_QuestLog and C_QuestLog.RequestLoadQuestByID) ~= "function" then
        lookup.dataFinished = true
        return
    end
    -- Session state is set before requesting: the result can be synchronous.
    WoW.RequestTitle(lookup.questID)
    if WoW.failedRequests[lookup.questID] then lookup.dataFinished, lookup.dataFailed = true, true end
end

local function association(lookup)
    local questID = lookup.questID
    local info, ok = call(C_QuestLine.GetQuestLineInfo, questID, nil, false)
    if not ok or (info ~= nil and (type(info) ~= "table" or not LiveData.IsID(info.questLineID))) then
        return nil, "ERROR"
    end
    local mapID = mapContext(questID, info)
    if not info and mapID then
        info, ok = call(C_QuestLine.GetQuestLineInfo, questID, mapID, false)
        if not ok or (info ~= nil and (type(info) ~= "table" or not LiveData.IsID(info.questLineID))) then
            return nil, "ERROR"
        end
        mapID = mapContext(questID, info)
    end
    if info then lookup.info = info
    elseif lookup.info then info, mapID = lookup.info, mapContext(questID, lookup.info) end
    if info then
        local questIDs, readOK = call(C_QuestLine.GetQuestLineQuests, info.questLineID)
        if not readOK or (questIDs ~= nil and type(questIDs) ~= "table") then return nil, "ERROR" end
        if questIDs and #questIDs > 0 then
            if not mapID then return nil, "NO_MAP" end
            local chain = LiveData.Build(mapID, info, questIDs)
            if not chain then return nil, "ERROR" end
            if not member(chain, questID) then return nil, "NOT_FOUND" end
            -- Reverse lookup is membership, never evidence of a current offer.
            chain.sourceAPI, chain.suggestedQuestID = "C_QuestLine.GetQuestLineInfo", nil
            if chain.nameKnown then chain.nameSourceAPI = "C_QuestLine.GetQuestLineInfo" end
            WoW.ResolveQuestLineName(chain)
            return WoW.RegisterQuestLine(chain), "READY"
        end
    end
    return nil, "LOADING", mapID
end

local function requestMap(lookup, mapID)
    if mapID and not lookup.maps[mapID] then
        lookup.maps[mapID] = true
        local map = WoW.RequestQuestLineMap(mapID)
        if not map or map.error then return map and map.error or "ERROR" end
    end
end

function WoW.FindQuestLine(questID)
    if not LiveData.IsID(questID) then return nil, "INVALID_ID" end
    local chain = cached(questID)
    if chain then return chain, "READY" end
    if type(C_QuestLine and C_QuestLine.GetQuestLineInfo) ~= "function"
        or type(C_QuestLine and C_QuestLine.GetQuestLineQuests) ~= "function" then return nil, "UNSUPPORTED" end
    local lookup = WoW.questLookup
    if not lookup or lookup.questID ~= questID then
        lookup = { questID = questID, maps = {} }
        WoW.questLookup = lookup
        -- Only a new user query retries this quest's failed metadata request.
        if WoW.failedRequests[questID] then
            WoW.failedRequests[questID], WoW.requested[questID], dataResults[questID] = nil, nil, nil
        end
    end
    local status, mapID
    chain, status, mapID = association(lookup)
    if status ~= "LOADING" then return chain, status end
    local errorStatus = requestMap(lookup, mapID)
    if errorStatus then return nil, errorStatus end
    requestData(lookup)
    if mapID then WoW.ReadQuestLineMap(mapID) end
    chain = cached(questID)
    if chain then return chain, "READY" end
    -- A request may synchronously populate a filtered line's association even
    -- though it never appears in GetAvailableQuestLines. Read before concluding.
    chain, status, mapID = association(lookup)
    if status ~= "LOADING" then return chain, status end
    errorStatus = requestMap(lookup, mapID)
    if errorStatus then return nil, errorStatus end
    local pending = not lookup.dataFinished
    for requestedMapID in pairs(lookup.maps) do
        local map = WoW.questLines.maps[requestedMapID]
        if not map or map.error then return nil, map and map.error or "ERROR" end
        if not map.loaded then pending = true end
    end
    if pending then return nil, "LOADING" end
    if lookup.dataFailed then return nil, "ERROR" end
    return nil, mapID and "NOT_FOUND" or "NO_MAP"
end
