local _, ns = ...
local WoW, LiveData = ns.WoW, ns.LiveData
local source = "https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua"
local maximumAchievements, maximumCriteria, maximumResults = 6000, 30000, 200
local achievementBudget, criteriaBudget, categoryBudget = 100, 500, 100
local index

-- Fold German uppercase characters explicitly because Lua's lowercase is byte based.
local function folded(text)
    return text:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):gsub("ẞ", "ß"):lower()
        :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Accept only bounded, nonnegative integral counts before entering API loops.
local function boundedCount(value, maximum)
    if type(value) ~= "number" or value < 0 or value >= math.huge or value ~= math.floor(value) then return nil end
    return math.min(value, maximum), value > maximum
end

-- Read the legacy API's multiple return values without allowing failures to escape.
local function achievementInfo(id, entry)
    if type(GetAchievementInfo) ~= "function" then return nil end
    local ok, achievementID, name, points, completed
    if entry then ok, achievementID, name, points, completed = pcall(GetAchievementInfo, id, entry)
    else ok, achievementID, name, points, completed = pcall(GetAchievementInfo, id) end
    if ok and LiveData.IsID(achievementID) and LiveData.IsName(name) then
        return { achievementID = achievementID, name = name, completed = completed }
    end
end

-- Keep criterion asset IDs as typed information; only Blizzard's achievement type is traversed.
local function criterionInfo(achievementID, entry)
    if type(GetAchievementCriteriaInfo) ~= "function" then return nil end
    local ok, name, kind, completed, _, _, _, _, assetID, _, criteriaID =
        pcall(GetAchievementCriteriaInfo, achievementID, entry)
    if ok and LiveData.IsName(name) then
        return { name = name, criteriaType = kind, completed = completed,
            assetID = LiveData.IsID(assetID) and assetID or nil,
            criteriaID = LiveData.IsID(criteriaID) and criteriaID or nil }
    end
end

-- Sort numeric category IDs so identical client data always produces the same scan order.
local function compareIDs(a, b)
    return a < b
end

-- Build a session-only discovery index from personal achievement categories supplied by Blizzard.
local function newIndex()
    local state = { records = {}, categories = {}, category = 1, entry = 1,
        seen = {}, queued = {}, queue = {}, queueEntry = 1, achievementReads = 0, criteriaReads = 0 }
    if type(GetCategoryList) ~= "function" or type(GetCategoryNumAchievements) ~= "function"
        or type(GetAchievementInfo) ~= "function" then
        state.unsupported, state.done = true, true
        return state
    end
    local categories = WoW.Call(GetCategoryList)
    if type(categories) ~= "table" then state.partial, state.unavailable, state.done = true, true, true; return state end
    local seen = {}
    for entry, categoryID in ipairs(categories) do
        if entry > 1000 then state.partial = true; break end
        if LiveData.IsID(categoryID) and not seen[categoryID] then
            state.categories[#state.categories + 1], seen[categoryID] = categoryID, true
        elseif not LiveData.IsID(categoryID) then state.partial = true end
    end
    table.sort(state.categories, compareIDs)
    state.criteriaSupported = type(GetAchievementNumCriteria) == "function"
        and type(GetAchievementCriteriaInfo) == "function"
    if not state.criteriaSupported or type(CRITERIA_TYPE_ACHIEVEMENT) ~= "number" then state.partial = true end
    return state
end

-- Queue each explicit subachievement once, including linked achievements absent from category lists.
local function queueAchievement(state, achievementID)
    if not state.seen[achievementID] and not state.queued[achievementID] then
        if #state.queue >= maximumAchievements then state.partial = true; return end
        state.queue[#state.queue + 1], state.queued[achievementID] = achievementID, true
    end
end

-- Store stable names and identifiers while leaving completion to guarded live reads of search hits.
local function addAchievement(state, info)
    if not info then state.partial = true; return end
    local achievementID = info.achievementID
    if state.seen[achievementID] then return end
    state.seen[achievementID] = true
    local record = { kind = "ACHIEVEMENT", name = info.name, foldedName = folded(info.name),
        achievementID = achievementID, achievementName = info.name,
        source = source, sourceAPI = "GetAchievementInfo" }
    state.records[#state.records + 1] = record
    if state.criteriaSupported then
        local count, truncated = boundedCount(WoW.Call(GetAchievementNumCriteria, achievementID), maximumCriteria)
        if count == nil then state.partial = true; return end
        if truncated then state.partial = true end
        if count > 0 then state.pending = { achievement = record, entry = 1, count = count } end
    end
end

-- Resume one achievement's criteria without exceeding the current refresh's work budget.
local function readCriterion(state)
    local pending, record = state.pending, state.pending.achievement
    local entry = pending.entry
    pending.entry, state.criteriaReads = entry + 1, state.criteriaReads + 1
    local info = criterionInfo(record.achievementID, entry)
    if info then
        info.kind, info.foldedName = "CRITERION", folded(info.name)
        info.achievementID, info.achievementName, info.criteriaIndex = record.achievementID, record.name, entry
        info.completed = nil
        info.source, info.sourceAPI = source, "GetAchievementCriteriaInfo"
        -- The native UI treats assetID as an achievement only for this exact runtime constant.
        if type(CRITERIA_TYPE_ACHIEVEMENT) == "number" and info.criteriaType == CRITERIA_TYPE_ACHIEVEMENT
            and info.assetID then
            info.childAchievementID = info.assetID
            queueAchievement(state, info.assetID)
        end
        state.records[#state.records + 1] = info
    else state.partial = true end
    if pending.entry > pending.count then state.pending = nil end
end

-- Incrementally enumerate categories and linked criteria with finite per-refresh and session limits.
local function advanceIndex(state)
    if state.done then return end
    local achievements, criteria, categories = 0, 0, 0
    while not state.done do
        if state.pending then
            if state.criteriaReads >= maximumCriteria then state.partial, state.done = true, true; break end
            if criteria >= criteriaBudget then break end
            readCriterion(state)
            criteria = criteria + 1
        else
            if achievements >= achievementBudget then break end
            if state.queueEntry <= #state.queue then
                local achievementID = state.queue[state.queueEntry]
                state.queueEntry = state.queueEntry + 1
                if not state.seen[achievementID] then
                    if state.achievementReads >= maximumAchievements then state.partial, state.done = true, true; break end
                    state.achievementReads, achievements = state.achievementReads + 1, achievements + 1
                    addAchievement(state, achievementInfo(achievementID))
                end
            elseif state.category > #state.categories then state.done = true
            elseif state.categoryCount == nil then
                if categories >= categoryBudget then break end
                categories = categories + 1
                local count, truncated = boundedCount(WoW.Call(GetCategoryNumAchievements,
                    state.categories[state.category]), maximumAchievements)
                state.categoryCount = count or 0
                if count == nil or truncated then state.partial = true end
            elseif state.entry > state.categoryCount then
                state.category, state.entry, state.categoryCount = state.category + 1, 1, nil
            else
                if state.achievementReads >= maximumAchievements then state.partial, state.done = true, true; break end
                state.achievementReads, achievements = state.achievementReads + 1, achievements + 1
                local info = achievementInfo(state.categories[state.category], state.entry)
                state.entry = state.entry + 1
                addAchievement(state, info)
            end
        end
    end
end

-- Collect only runtime line names and retain pending entries as nonselectable information.
local function addQuestLines(results, query)
    local seen = {}
    for _, map in pairs(WoW.questLines.maps) do
        for id, chain in pairs(map.byID) do
            if not seen[id] and chain.runtime and chain.nameKnown and LiveData.IsName(chain.name) then
                local name = folded(chain.name)
                if name:find(query, 1, true) then
                    seen[id] = true
                    local quests = ns.Model.Flatten(chain)
                    results[#results + 1] = { kind = "QUEST_LINE", name = chain.name, foldedName = name,
                        chain = chain, selectable = not chain.loading and not chain.empty and #quests > 0,
                        loading = chain.loading == true, exact = name == query,
                        source = chain.source, sourceAPI = chain.nameSourceAPI or chain.sourceAPI }
                end
            end
        end
    end
end

-- Rank selectable lines first, then exact names and stable identifiers for unambiguous result lists.
local function compareResults(a, b)
    if a.selectable ~= b.selectable then return a.selectable == true end
    if a.exact ~= b.exact then return a.exact == true end
    if a.foldedName ~= b.foldedName then return a.foldedName < b.foldedName end
    if a.kind ~= b.kind then return a.kind < b.kind end
    if a.kind == "QUEST_LINE" then return a.chain.id < b.chain.id end
    if a.achievementID ~= b.achievementID then return a.achievementID < b.achievementID end
    return (a.criteriaIndex or 0) < (b.criteriaIndex or 0)
end

-- Copy a hit before reading live completion so session names never become saved progress data.
local function copyResult(record, query)
    local result = {}
    for key, value in pairs(record) do result[key] = value end
    result.selectable, result.exact = false, record.foldedName == query
    return result
end

-- Refresh returned achievement and criterion progress without reindexing thousands of stable names.
local function refreshProgress(result)
    if result.kind == "QUEST_LINE" then return true end
    local info
    if result.kind == "ACHIEVEMENT" then info = achievementInfo(result.achievementID)
    else info = criterionInfo(result.achievementID, result.criteriaIndex) end
    if not info then return false end
    -- An index can be rebuilt after list changes; a mismatching live record is never trusted.
    if result.kind == "ACHIEVEMENT" and info.achievementID ~= result.achievementID then return false end
    if result.kind == "CRITERION" and result.criteriaID and info.criteriaID ~= result.criteriaID then return false end
    result.completed = nil
    if type(info.completed) == "boolean" then result.completed = info.completed end
    return true
end

-- Rebuild discovery for a new client achievement list; progress events use live reads of matching hits.
function WoW.OnNameSearchAchievementUpdate(reset)
    if reset == true or (index and index.unavailable) then index = nil end
end

-- Search client-supplied line and achievement names without inventing quest membership from text or assets.
function WoW.SearchQuestLinesByName(text)
    if type(text) ~= "string" or #text > 240 then return {}, "INVALID" end
    local query = folded(text)
    local _, characters = query:gsub("[^\128-\191]", "")
    if characters < 2 then return {}, "INVALID" end
    index = index or newIndex()
    advanceIndex(index)
    local results, achievements = {}, {}
    addQuestLines(results, query)
    for _, record in ipairs(index.records) do
        if record.kind == "ACHIEVEMENT" and record.foldedName:find(query, 1, true) then
            achievements[record.achievementID] = true
        end
    end
    for _, record in ipairs(index.records) do
        if record.foldedName:find(query, 1, true)
            or (record.kind == "CRITERION" and achievements[record.achievementID]) then
            results[#results + 1] = copyResult(record, query)
        end
    end
    table.sort(results, compareResults)
    local partial = index.partial or index.unsupported or #results > maximumResults
    for entry = #results, maximumResults + 1, -1 do results[entry] = nil end
    for _, result in ipairs(results) do
        if not refreshProgress(result) then partial = true end
    end
    if not index.done then return results, "LOADING" end
    if index.unsupported and #results == 0 then return results, "UNSUPPORTED" end
    if partial then return results, "PARTIAL" end
    return results, #results > 0 and "READY" or "EMPTY"
end
