local _, ns = ...
local WoW = { requested = {}, failedRequests = {}, offers = {} }
ns.WoW = WoW

function WoW.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

function WoW.Title(quest)
    if not ns.LiveData.IsID(quest.questID) then return quest.title end
    local title = WoW.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, quest.questID)
    if type(title) == "string" and title ~= "" then return title end
    if type(quest.title) == "string" and quest.title ~= "" then return quest.title end
    return string.format(ns.L.UNKNOWN_TITLE, quest.questID)
end

function WoW.RequestTitle(id)
    if WoW.requested[id] or not ns.LiveData.IsID(id) then return end
    WoW.requested[id] = true
    local fn = C_QuestLog and C_QuestLog.RequestLoadQuestByID
    if type(fn) ~= "function" or not pcall(fn, id) then WoW.failedRequests[id] = true end
end

function WoW.OnQuestDataLoadResult(id, success)
    if not ns.LiveData.IsID(id) or not WoW.requested[id] then return end
    WoW.failedRequests[id] = success == false or nil
end

function WoW.RetryQuestTitles()
    -- Retry only on an explicit refresh, never in a failure-event loop.
    for id in pairs(WoW.failedRequests) do WoW.requested[id] = nil end
    WoW.failedRequests = {}
end

function WoW.Snapshot(chain)
    local snapshot = { completed = {}, active = {}, offered = {} }
    if not chain then return snapshot end
    local quests = ns.Model.Flatten(chain)
    for _, quest in ipairs(quests) do
        local id = quest.questID
        if ns.LiveData.IsID(id) then
            snapshot.completed[id] = WoW.Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, id)
            snapshot.active[id] = WoW.Call(C_QuestLog and C_QuestLog.IsOnQuest, id)
            snapshot.offered[id] = WoW.offers[id] == true
            if not WoW.requested[id] and
                not WoW.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, id) then
                WoW.RequestTitle(id)
            end
        end
    end
    return snapshot
end

function WoW.SetGossipOffers()
    WoW.offers = {}
    for _, info in ipairs(WoW.Call(C_GossipInfo and C_GossipInfo.GetAvailableQuests) or {}) do
        if ns.LiveData.IsID(info.questID) and not info.isIgnored then
            WoW.offers[info.questID] = true
        end
    end
end

function WoW.ClearOffers()
    WoW.offers = {}
end

local function readWatches(previous)
    previous = previous or {}
    local watched, lists = {}, {}
    local function read(countFn, idFn, old)
        if type(countFn) ~= "function" or type(idFn) ~= "function" then return old or {} end
        local count = WoW.Call(countFn)
        if type(count) ~= "number" or count < 0 or count ~= math.floor(count) or count > 1000 then return old or {} end
        local current = {}
        for index = 1, count do
            local id = WoW.Call(idFn, index)
            if not ns.LiveData.IsID(id) then return old or {} end
            current[id] = true
        end
        return current
    end
    lists.regular = read(C_QuestLog and C_QuestLog.GetNumQuestWatches,
        C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex, previous.regular)
    lists.world = read(C_QuestLog and C_QuestLog.GetNumWorldQuestWatches,
        C_QuestLog and C_QuestLog.GetQuestIDForWorldQuestWatchIndex, previous.world)
    for _, list in pairs(lists) do for id in pairs(list) do watched[id] = true end end
    return watched, lists
end

local function warningSelection()
    local chain = ns.chain
    return chain and not chain.empty and not chain.loading
        and type(chain.sections) == "table" and #chain.sections > 0
end

local function readNavigation(previous)
    local id, status = WoW.SuperTrackedQuestID()
    if status == "READY" or status == "NO_TRACKED" then return id end
    return previous
end

function WoW.ResetWarnings()
    -- Existing watched quests are a baseline, not new user actions.
    local watched, lists = readWatches()
    WoW.warnings = { watched = watched, watchLists = lists, tasks = {}, superTrackedID = nil,
        pendingAccepted = {}, accepted = {} }
end

function WoW.OnWarningEvent(event, ...)
    if not WoW.warnings then WoW.ResetWarnings() end
    local state = WoW.warnings
    local id, added = ...
    if event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
        if ns.LiveData.IsID(id) then
            state.pendingAccepted[id], state.accepted[id], state.tasks[id], state.watched[id] = nil, nil, nil, nil
            state.watchLists.regular[id], state.watchLists.world[id] = nil, nil
            if state.superTrackedID == id then state.superTrackedID = nil end
        end
    elseif event == "QUEST_ACCEPTED" then
        if warningSelection() and ns.LiveData.IsID(id) and not state.accepted[id] then
            state.pendingAccepted[id] = ns.chain.id
        end
    elseif event == "QUEST_WATCH_LIST_CHANGED" and added == false then
        -- Remember the removal even if the quest is re-added before the timer.
        if ns.LiveData.IsID(id) then
            state.watched[id] = nil
            state.watchLists.regular[id], state.watchLists.world[id] = nil, nil
        end
    elseif event == "SUPER_TRACKING_CHANGED" then
        local current = readNavigation(state.superTrackedID)
        if current ~= state.superTrackedID then state.superTrackedID = nil end
    end
end

function WoW.WarnActivities()
    if not warningSelection() then WoW.ResetWarnings(); return end
    if not WoW.warnings then WoW.ResetWarnings() end
    local state, candidates = WoW.warnings, {}
    local watched, lists = readWatches(state.watchLists)
    local tasks, taskTitles = {}, {}
    for id in pairs(watched) do
        if not state.watched[id] then candidates[id] = true end
    end
    local taskIDs = WoW.Call(GetTasksTable)
    if type(taskIDs) == "table" then
        for _, id in ipairs(taskIDs) do
            if ns.LiveData.IsID(id) then
                local ok, inArea, title
                if type(GetTaskInfo) == "function" then
                    local onMap, objectives
                    ok, inArea, onMap, objectives, title = pcall(GetTaskInfo, id)
                end
                if ok and inArea == true then
                    tasks[id] = true
                    if type(title) == "string" and title ~= "" then taskTitles[id] = title end
                    if not state.tasks[id] then candidates[id] = true end
                elseif (not ok or inArea ~= false) and state.tasks[id] then
                    -- An unavailable read is not evidence of leaving the area.
                    tasks[id] = true
                end
            end
        end
    else
        tasks = state.tasks
    end
    local superTrackedID = readNavigation(state.superTrackedID)
    if superTrackedID and superTrackedID ~= state.superTrackedID then candidates[superTrackedID] = true end
    for id, chainID in pairs(state.pendingAccepted) do
        if chainID ~= ns.chain.id or state.accepted[id] then
            state.pendingAccepted[id] = nil
        elseif WoW.Call(C_QuestLog and C_QuestLog.IsOnQuest, id) == true then
            -- Task/watch events can precede the quest-log state becoming ready.
            if not state.tasks[id] and not state.watched[id] and state.superTrackedID ~= id then
                candidates[id] = true
            end
            state.accepted[id], state.pendingAccepted[id] = true, nil
        end
    end
    state.watched, state.watchLists, state.tasks, state.superTrackedID = watched, lists, tasks, superTrackedID
    -- One warning per quest in the coalesced refresh, regardless of its sources.
    for id in pairs(candidates) do
        if not ns.Model.Contains(ns.chain, id) then
            if state.pendingAccepted[id] then
                state.accepted[id], state.pendingAccepted[id] = true, nil
            end
            local title = taskTitles[id] or WoW.Title({ questID = id })
            local message = string.format(ns.L.UNRELATED_WARNING, title, id, ns.chain.name)
            ns.Print(message)
            if UIErrorsFrame then UIErrorsFrame:AddMessage(message, 1, 0.65, 0.2) end
        end
    end
end

function WoW.OnDetail(startItemID)
    WoW.ClearOffers()
    if not warningSelection() then return end
    local id = WoW.Call(GetQuestID)
    if not ns.LiveData.IsID(id) or WoW.Call(UnitExists, "questnpc") ~= true
        or (startItemID and startItemID ~= 0) then return end
    WoW.offers[id] = true
end
