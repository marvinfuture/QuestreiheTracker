local addonName, ns = ...
local L = ns.L
ns.version = "0.5.0"

-- Write localized addon feedback to the player's own chat frame.
function ns.Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd8b66a" .. L.TITLE .. "|r: " .. tostring(message)) end
end

local anchors = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
-- Reject invalid or extreme saved coordinates before restoring window geometry.
local function finite(value)
    return type(value) == "number" and value == value and value > -10000 and value < 10000
end
-- Copy a supported saved anchor without retaining unknown preference fields.
local function readPosition(position)
    if type(position) == "table" and anchors[position.point] and anchors[position.relativePoint]
        and finite(position.x) and finite(position.y) then
        return { point = position.point, relativePoint = position.relativePoint, x = position.x, y = position.y }
    end
end

-- Migrate and validate character preferences while deriving all progress from the client.
function ns.ReadConfig(saved)
    saved = type(saved) == "table" and saved or {}
    local config = { schemaVersion = 8, selectedChain = "none", scale = 1, minimapAngle = 315,
        chatWarnings = true, screenWarnings = true, panelPositions = {} }
    if type(saved.chatWarnings) == "boolean" then config.chatWarnings = saved.chatWarnings end
    if type(saved.screenWarnings) == "boolean" then config.screenWarnings = saved.screenWarnings end
    local selection = saved.liveSelection
    if type(selection) == "table" and ns.LiveData.IsID(selection.mapID)
        and ns.LiveData.IsID(selection.questLineID)
        and saved.selectedChain == ns.LiveData.Key(selection.mapID, selection.questLineID) then
        config.liveSelection = { mapID = selection.mapID, questLineID = selection.questLineID }
        config.selectedChain = saved.selectedChain
    end
    local angle = saved.minimapAngle
    if type(angle) == "number" and angle == angle and angle > -math.huge and angle < math.huge then
        config.minimapAngle = angle % 360
    end
    local size = saved.size
    local legacy = saved.schemaVersion == nil or (type(saved.schemaVersion) == "number" and saved.schemaVersion < 5)
    local oldDefault = legacy and type(size) == "table" and size.width == 550 and size.height == 750
    local compactLegacy = saved.schemaVersion == nil or (type(saved.schemaVersion) == "number" and saved.schemaVersion < 6)
    local compactDefault = compactLegacy and type(size) == "table" and size.width == 440 and size.height == 500
    if type(size) == "table" and finite(size.width) and finite(size.height)
        and size.width >= ns.UI.MIN_WIDTH and size.width <= ns.UI.MAX_WIDTH
        and size.height >= ns.UI.MIN_HEIGHT and size.height <= ns.UI.MAX_HEIGHT and not oldDefault and not compactDefault then
        config.size = { width = size.width, height = size.height }
    end
    config.position = readPosition(saved.position)
    if type(saved.panelPositions) == "table" then
        for _, key in ipairs({ "selector", "link" }) do config.panelPositions[key] = readPosition(saved.panelPositions[key]) end
    end
    return config
end

-- Replace the displayed line and reset its ephemeral offers, warnings, and scroll position.
local function applySelection(selected)
    ns.chain, ns.db.selectedChain = selected, selected.id
    ns.db.liveSelection = selected.runtime and { mapID = selected.mapID, questLineID = selected.questLineID } or nil
    ns.WoW.ClearOffers()
    ns.WoW.ResetWarnings()
    ns.UI.ClearWarning()
    ns.ScheduleWarningExpiry()
    if ns.UI.scroll then ns.UI.scroll:SetVerticalScroll(0) end
end

-- Cancel both lookup modes so late data cannot replace the player's current choice.
function ns.CancelQuestLookup()
    ns.questLookup = nil
    ns.nameLookup = nil
    ns.WoW.ResetQuestLookup()
end

-- Clear the addon selection while retaining preferences and Blizzard quest state.
function ns.ClearSelection()
    if not ns.initialized then return end
    ns.CancelQuestLookup()
    if ns.UI.selector then ns.UI.selector:Hide() end
    if ns.UI.link then ns.UI.link:Hide() end
    applySelection(ns.LiveData.Empty())
    ns.Refresh()
end

-- Retry the submitted quest association after client data events and apply confirmed results.
local function resolveQuestLookup()
    local lookup = ns.questLookup
    if not lookup or not lookup.pending then return end
    local chain, status = ns.WoW.FindQuestLine(lookup.questID)
    -- Unlabelled map events can arrive before the current request's association.
    lookup.status, lookup.pending = status, status == "LOADING" or status == "NOT_FOUND"
    if chain and status == "READY" then
        applySelection(chain)
        ns.UI.frame:Show()
        if ns.UI.selector then ns.UI.selector:Hide() end
    end
end

-- Start a guarded quest-ID lookup without hiding the existing view while data loads.
function ns.LookupQuest(questID)
    ns.CancelQuestLookup()
    ns.questLookup = { questID = questID, status = "INVALID_ID", pending = false }
    if ns.LiveData.IsID(questID) then
        ns.questLookup.pending = true
        ns.Refresh()
        ns.ScheduleRefresh()
    else ns.UI.RenderQuestLookup() end
end

-- Read the current Blizzard quest navigation target and look up its quest line.
function ns.UseTrackedQuest()
    ns.CancelQuestLookup()
    local questID, status = ns.WoW.SuperTrackedQuestID()
    if questID then ns.LookupQuest(questID)
    else
        ns.questLookup = { status = status, pending = false }
        ns.UI.RenderQuestLookup()
    end
end

-- Save the chat-output preference without rearming already observed quest activity.
function ns.ToggleChatWarnings()
    if not ns.initialized then return end
    ns.db.chatWarnings = not ns.db.chatWarnings
    ns.UI.RenderChatWarningSetting()
end

-- Save the independent banner preference and immediately retire a disabled banner.
function ns.ToggleScreenWarnings()
    if not ns.initialized then return end
    ns.db.screenWarnings = not ns.db.screenWarnings
    if not ns.db.screenWarnings then
        ns.UI.ClearWarning()
        ns.ScheduleWarningExpiry()
    end
    ns.UI.RenderScreenWarningSetting()
end

-- Submit an explicit name query without replacing the currently displayed quest list.
function ns.LookupName(text)
    ns.CancelQuestLookup()
    ns.nameLookup = { text = text or "", results = {}, status = "INVALID" }
    ns.Refresh()
end

-- Advance the finite achievement index only while a submitted name search is active.
local function resolveNameLookup()
    local lookup = ns.nameLookup
    if not lookup then return end
    lookup.results, lookup.status = ns.WoW.SearchQuestLinesByName(lookup.text)
    if lookup.status == "LOADING" then ns.ScheduleRefresh() end
end

-- The only gameplay action: explicitly observing and navigating to a clicked member quest.
function ns.TrackQuest(questID)
    if not ns.initialized or not ns.LiveData.IsID(questID)
        or not ns.Model.Contains(ns.chain, questID) then return end
    local ok, status = ns.WoW.WatchQuest(questID)
    if ok then ns.ScheduleRefresh()
    else ns.Print(ns.L["WATCH_" .. status] or ns.L.WATCH_FAILED) end
end

-- Rebuild live progress, advance submitted lookups, and redraw the existing widgets.
function ns.Refresh()
    if not ns.initialized then return end
    ns.WoW.ReadQuestLines()
    resolveQuestLookup()
    resolveNameLookup()
    if ns.chain.runtime then ns.chain = ns.WoW.GetQuestLine(ns.chain.id) or ns.chain end
    ns.snapshot = ns.WoW.Snapshot(ns.chain)
    ns.result = ns.Model.Evaluate(ns.chain, ns.snapshot)
    ns.UI.Render(ns.result)
    ns.UI.RenderSelector()
    ns.UI.RenderWarning()
end

-- Request current-zone lines and optionally retry metadata after explicit refresh.
function ns.DiscoverZone(force)
    if not ns.initialized then return end
    local previous = ns.WoW.questLines.currentMapID
    if force then ns.WoW.RetryQuestTitles() end
    ns.WoW.DiscoverZone(force)
    if force or ns.WoW.questLines.currentMapID or previous then ns.ScheduleRefresh() end
end

local armTimer
-- Keep one cancellable timer for pending refresh work and the banner's expiry deadline.
armTimer = function()
    if not ns.initialized then return end
    local due = ns.refreshDue
    local expiry = ns.UI.warningExpires
    if expiry and (not due or expiry < due) then due = expiry end
    if ns.timer and ns.timerDue == due then return end
    if ns.timer then ns.timer:Cancel(); ns.timer, ns.timerDue = nil, nil end
    if not due then return end
    ns.timerDue = due
    -- Run due work once, then retain a timer only for another concrete pending deadline.
    ns.timer = C_Timer.NewTimer(math.max(0, due - GetTime()), function()
        ns.timer, ns.timerDue = nil, nil
        ns.UI.RenderWarning()
        if ns.refreshDue and ns.refreshDue <= GetTime() + 0.001 then
            ns.pending, ns.refreshDue = false, nil
            ns.Refresh()
            ns.WoW.WarnActivities()
        end
        armTimer()
    end)
end

-- Reconcile the banner deadline with any refresh already queued on the shared timer.
function ns.ScheduleWarningExpiry()
    armTimer()
end

-- Coalesce game events or finite search chunks into one short delayed refresh.
function ns.ScheduleRefresh()
    if ns.pending or not ns.initialized then return end
    ns.pending, ns.refreshDue = true, GetTime() + 0.1
    armTimer()
end

-- Select an existing client-supplied line after cancelling unrelated lookup work.
function ns.Select(id)
    local selected = ns.WoW.GetQuestLine(id)
    if not selected then return end
    ns.CancelQuestLookup()
    applySelection(selected)
    ns.Refresh()
    ns.ScheduleRefresh()
end

-- Print addon, client, and progress information for reproducible client diagnostics.
function ns.Debug()
    ns.Print(string.format(L.DEBUG_VERSION, ns.version, ns.chain.name))
    if type(GetBuildInfo) == "function" then
        local version, _, _, interface = GetBuildInfo()
        ns.Print(string.format(L.DEBUG_CLIENT, tostring(version), tostring(interface)))
    end
    ns.Print(string.format(L.DEBUG_PROGRESS, ns.result.completed, ns.result.total, #ns.result.next))
end

-- Dispatch localized slash-command actions and read-only quest diagnostics.
function ns.Slash(text)
    local command, argument = string.match(text or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command)
    if command == "" then ns.UI.Toggle()
    elseif command == "zone" then
        ns.UI.frame:Show()
        ns.DiscoverZone(true)
        if not ns.UI.selector or not ns.UI.selector:IsShown() then ns.UI.ChooseChain() end
    elseif command == "debug" then
        ns.Refresh()
        ns.Debug()
    elseif command == "reset" then
        ns.db = ns.ReadConfig(nil)
        QuestreihenTrackerDB = ns.db
        ns.ClearSelection()
        ns.UI.Restore()
        ns.Minimap.Position()
        ns.Print(L.RESET)
    elseif command == "quest" then
        local id = tonumber(argument)
        if not ns.LiveData.IsID(id) then ns.Print(L.QUEST_USAGE); return end
        local status = ns.Model.ProgressStatus(
            ns.WoW.Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, id),
            ns.WoW.Call(C_QuestLog and C_QuestLog.IsOnQuest, id))
        ns.Print(string.format(L.DEBUG_QUEST, id, status == "UNKNOWN" and L.PROGRESS_UNKNOWN or L[status]))
    else ns.Print(L.SLASH_HELP) end
end

local events = CreateFrame("Frame")
ns.eventFrame = events
events:RegisterEvent("ADDON_LOADED")
-- Initialize saved preferences once and route client data events through coalesced refreshes.
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= addonName or ns.initialized then return end
        ns.db = ns.ReadConfig(QuestreihenTrackerDB)
        QuestreihenTrackerDB = ns.db
        ns.chain = ns.LiveData.Empty()
        ns.initialized = true
        ns.UI.Create()
        ns.Minimap.Create()
        SLASH_QUESTREIHENTRACKER1 = "/qrt"
        SlashCmdList.QUESTREIHENTRACKER = ns.Slash
        for _, name in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED",
            "QUEST_TURNED_IN", "QUEST_DATA_LOAD_RESULT", "QUEST_DETAIL", "QUEST_FINISHED",
            "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUESTLINE_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
            "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "TASK_PROGRESS_UPDATE", "QUEST_POI_UPDATE" }) do
            events:RegisterEvent(name)
        end
        events:RegisterEvent("ACHIEVEMENT_EARNED")
        events:RegisterEvent("CRITERIA_UPDATE")
        events:RegisterEvent("RECEIVED_ACHIEVEMENT_LIST")
        if ns.db.liveSelection then ns.chain = ns.WoW.RestoreQuestLine(ns.db.liveSelection) or ns.chain end
        ns.WoW.ResetWarnings()
        ns.Refresh()
        ns.Print(L.READY)
    elseif ns.initialized then
        if event == "QUESTLINE_UPDATE" then ns.WoW.OnQuestLineUpdate(...)
        elseif event == "QUEST_DATA_LOAD_RESULT" then
            ns.WoW.OnQuestDataLoadResult(...)
            ns.WoW.OnQuestLookupDataLoadResult(...)
        elseif event == "ACHIEVEMENT_EARNED" or event == "CRITERIA_UPDATE" then
            ns.WoW.OnNameSearchAchievementUpdate()
        elseif event == "RECEIVED_ACHIEVEMENT_LIST" then
            ns.WoW.OnNameSearchAchievementUpdate(true)
        elseif event == "PLAYER_LOGIN" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
            ns.WoW.DiscoverZone(event == "PLAYER_LOGIN")
        elseif event == "QUEST_DETAIL" then ns.WoW.OnDetail(...)
        elseif event == "GOSSIP_SHOW" then ns.WoW.SetGossipOffers()
        elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then ns.WoW.ClearOffers() end
        ns.WoW.OnWarningEvent(event, ...)
        ns.ScheduleRefresh()
    end
end)
