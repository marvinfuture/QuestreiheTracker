-- Strict, intentionally small stand-ins for the exact widget/API surface used.
Mock = { frames = {}, timers = {}, completed = {}, active = {}, titles = {}, requests = {},
    currentMapID = nil, mapInfos = {}, questLinesByMap = {}, questLineQuests = {},
    lineRequests = {}, mapReads = 0, lineReads = 0, cursorX = 1000, cursorY = 800,
    superTrackedQuestID = nil, trackedReads = 0, questMapIDs = {}, questMapReads = 0,
    isSuperTrackingQuest = false, trackingKindReads = 0, priorityReads = 0,
    questMapCalls = {}, questLineInfoByQuest = {}, questLineInfoByMap = {}, reverseCalls = {},
    log = {}, offers = {}, detailID = 78743, npc = true, combat = false, acceptCount = 0,
    setAbandonCount = 0, abandonCount = 0, mutationCount = 0, mutations = {},
    warningCount = 0, warnings = {}, messages = {}, watched = {}, worldWatched = {}, tasks = {}, taskInfo = {},
    now = 0, watchAddCount = 0, watchAddCalls = {}, worldQuests = {}, questTasks = {}, questsOnMap = {},
    superTrackSetCount = 0, superTrackSetCalls = {},
    calls = 0, invalidIDCalls = 0, achievementDone = false, achievementMine = false, criteriaDone = 2 }
local methods = {}
local function widget(kind)
    local value = { kind = kind, shown = true, enabled = true, scripts = {}, events = {},
        children = {}, checked = false }
    return setmetatable(value, { __index = function(_, key)
        if methods[key] then return methods[key] end
        error("Unknown widget method: " .. tostring(key))
    end })
end
for _, method in ipairs({ "SetFrameStrata", "SetClampedToScreen",
    "SetBackdrop", "SetFontObject", "SetJustifyH", "SetJustifyV",
    "SetAutoFocus", "ClearFocus", "SetFocus", "HighlightText", "EnableMouse",
    "SetStatusBarTexture",
    "SetStatusBarColor", "SetMinMaxValues", "SetAllPoints", "SetColorTexture",
    "ClearAllPoints", "SetOwner" }) do
    methods[method] = function() end
end
function methods:SetBackdropColor(...) self.backdropColor = { ... } end
function methods:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
function methods:SetMovable(value) self.movable = value end
function methods:SetSize(width, height)
    self.width, self.height = width, height
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, width, height) end
end
function methods:SetWidth(width)
    self.width = width
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, width, rawget(self, "height") or 0) end
end
function methods:SetHeight(height)
    self.height = height
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, rawget(self, "width") or 0, height) end
end
function methods:GetWidth() return rawget(self, "width") or 0 end
function methods:GetHeight() return rawget(self, "height") or 0 end
function methods:GetCenter() return rawget(self, "centerX"), rawget(self, "centerY") end
function methods:GetEffectiveScale()
    local scale = rawget(self, "scale") or 1
    local parent = rawget(self, "parent")
    return scale * (parent and parent:GetEffectiveScale() or 1)
end
function methods:RegisterForClicks(...) self.clickButtons = { ... } end
function methods:RegisterForDrag(...) self.dragButtons = { ... } end
function methods:SetHighlightTexture(value, blendMode)
    self.highlight = widget("Texture")
    self.highlight:SetTexture(value)
    self.highlight.blendMode = blendMode
end
function methods:GetHighlightTexture() return rawget(self, "highlight") end
function methods:SetResizable(value) self.resizable = value end
function methods:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    self.resizeBounds = { minWidth, minHeight, maxWidth, maxHeight }
end
function methods:StartSizing(point)
    self.sizing, self.sizingPoint = true, point
    self.startSizingCount = (rawget(self, "startSizingCount") or 0) + 1
end
function methods:StartMoving()
    self.moving = true
    self.startMovingCount = (rawget(self, "startMovingCount") or 0) + 1
end
function methods:StopMovingOrSizing()
    self.sizing, self.moving = false, false
    self.stopCount = (rawget(self, "stopCount") or 0) + 1
end
function methods:SetPoint(point, _, relativePoint, x, y)
    self.point = { point or "CENTER", relativePoint or point or "CENTER", x or 0, y or 0 }
end
function methods:GetPoint()
    local p = self.point or { "CENTER", "CENTER", 0, 0 }
    return p[1], UIParent, p[2], p[3], p[4]
end
function methods:SetScale(value) self.scale = value end
function methods:SetValue(value) self.value = value end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:SetText(value) assert(type(value) == "string"); self.textValue = value end
function methods:SetNumeric(value) self.numeric = value end
function methods:SetMaxLetters(value) self.maxLetters = value end
function methods:GetText() return self.textValue end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetTexture(value) self.textureValue = value end
function methods:GetTexture() return self.textureValue end
function methods:SetTexCoord(...) self.texCoords = { ... } end
function methods:AddLine(value)
    self.lines = rawget(self, "lines") or {}
    self.lines[#self.lines + 1] = value
end
function methods:SetScript(key, value) self.scripts[key] = value end
function methods:RegisterEvent(key) self.events[key] = true end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:Disable() self.enabled = false end
function methods:Enable() self.enabled = true end
function methods:IsEnabled() return self.enabled end
function methods:SetEnabled(value) if value then self:Enable() else self:Disable() end end
function methods:SetScrollChild(value) self.scrollChild = value end
function methods:CreateFontString() local child = widget("FontString"); self.children[#self.children + 1] = child; return child end
function methods:CreateTexture()
    local child = widget("Texture")
    self.children[#self.children + 1] = child
    return child
end
function methods:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function CreateFrame(kind, name, parent)
    local value = widget(kind)
    value.parent = parent
    Mock.frames[#Mock.frames + 1] = value
    if name then _G[name] = value end
    return value
end
UIParent = widget("Root")
Minimap = widget("Minimap")
Minimap:SetSize(140, 140)
Minimap.centerX, Minimap.centerY = 1000, 800
function GetCursorPosition() return Mock.cursorX, Mock.cursorY end
GameTooltip = widget("Tooltip")
UISpecialFrames, SlashCmdList = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message)
    Mock.lastMessage = message
    Mock.messages[#Mock.messages + 1] = message
end }
UIErrorsFrame = { AddMessage = function(_, message)
    Mock.warningCount = Mock.warningCount + 1
    Mock.warnings[#Mock.warnings + 1] = message
end,
    GetTimeVisible = function() return Mock.errorTimeVisible or 2 end,
    GetFadeDuration = function() return Mock.errorFadeDuration or 0.5 end,
}
function GetTime() return Mock.now end
Constants = { QuestWatchConsts = { MAX_QUEST_WATCHES = 25 } }
local function scheduleTimer(delay, fn)
    assert(type(delay) == "number" and delay >= 0 and type(fn) == "function")
    local timer = { due = Mock.now + delay, callback = fn, cancelled = false }
    function timer:Cancel()
        self.cancelled = true
        for index = #Mock.timers, 1, -1 do
            if Mock.timers[index] == self then table.remove(Mock.timers, index) end
        end
    end
    function timer:IsCancelled() return self.cancelled end
    Mock.timers[#Mock.timers + 1] = timer
    return timer
end
C_Timer = { After = function(delay, fn) scheduleTimer(delay, fn) end, NewTimer = scheduleTimer }
local function runTimers(target)
    local count = 0
    while #Mock.timers > 0 do
        table.sort(Mock.timers, function(left, right) return left.due < right.due end)
        local timer = Mock.timers[1]
        if target and timer.due > target then break end
        count = count + 1
        assert(count < 100, "Repeated event timer loop")
        table.remove(Mock.timers, 1)
        Mock.now = math.max(Mock.now, timer.due)
        if not timer.cancelled then timer.callback(timer) end
    end
end
function Mock.Flush() runTimers() end
function Mock.Advance(seconds)
    assert(type(seconds) == "number" and seconds >= 0)
    local target = Mock.now + seconds
    runTimers(target)
    Mock.now = target
end
local function realID(id)
    if not (type(id) == "number" and id > 0 and id < math.huge and id == math.floor(id)) then
        Mock.invalidIDCalls = Mock.invalidIDCalls + 1
        error("Synthetic or invalid ID reached real API")
    end
    Mock.calls = Mock.calls + 1
end
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) realID(id); return Mock.completed[id] == true end,
    IsOnQuest = function(id) realID(id); return Mock.active[id] == true end,
    GetTitleForQuestID = function(id) realID(id); return Mock.titles[id] end,
    RequestLoadQuestByID = function(id) realID(id); Mock.requests[id] = (Mock.requests[id] or 0) + 1 end,
    GetNumQuestLogEntries = function() return #Mock.log, #Mock.log end,
    GetInfo = function(index) return Mock.log[index] end,
    GetQuestsOnMap = function(mapID)
        realID(mapID)
        if Mock.failQuestsOnMap then error("Quests-on-map fixture failure") end
        return Mock.questsOnMap[mapID] or {}
    end,
    IsWorldQuest = function(id)
        realID(id)
        if Mock.failQuestKindRead then error("Quest-kind fixture failure") end
        return Mock.worldQuests[id] == true
    end,
    IsQuestTask = function(id)
        realID(id)
        if Mock.failQuestKindRead then error("Quest-kind fixture failure") end
        return Mock.questTasks[id] == true
    end,
    GetNumQuestWatches = function()
        if Mock.failWatchRead then error("Watch count fixture failure") end
        return #(Mock.watched or {})
    end,
    GetQuestIDForQuestWatchIndex = function(index) return (Mock.watched or {})[index] end,
    GetNumWorldQuestWatches = function() return #(Mock.worldWatched or {}) end,
    GetQuestIDForWorldQuestWatchIndex = function(index) return (Mock.worldWatched or {})[index] end,
}
function GetTasksTable()
    if Mock.failTasksRead then error("Task-list fixture failure") end
    return Mock.tasks
end
function GetTaskInfo(id)
    realID(id)
    if Mock.failTaskInfo then error("Task-info fixture failure") end
    local info = (Mock.taskInfo or {})[id] or {}
    return info.inArea, info.onMap, info.numObjectives or 1, info.title, info.displayAsObjective
end
C_Map = {
    GetBestMapForUnit = function(unit)
        assert(unit == "player")
        Mock.calls = Mock.calls + 1
        Mock.mapReads = Mock.mapReads + 1
        if Mock.failMapRead then error("Map API fixture failure") end
        return Mock.currentMapID
    end,
    GetMapInfo = function(id)
        realID(id)
        if Mock.failMapInfo then error("Map info fixture failure") end
        return Mock.mapInfos[id]
    end,
}
C_QuestLine = {
    RequestQuestLinesForMap = function(id)
        realID(id)
        Mock.lineRequests[id] = (Mock.lineRequests[id] or 0) + 1
        if Mock.failLineRequest then error("Quest-line request fixture failure") end
        if Mock.onLineRequest then Mock.onLineRequest(id) end
    end,
    GetAvailableQuestLines = function(id)
        realID(id)
        Mock.lineReads = Mock.lineReads + 1
        if Mock.failLineRead then error("Quest-line map fixture failure") end
        return Mock.questLinesByMap[id]
    end,
    GetQuestLineQuests = function(id)
        realID(id)
        if Mock.failLineQuests then error("Quest-line quest fixture failure") end
        return Mock.questLineQuests[id]
    end,
    GetQuestLineInfo = function(id, mapID, displayableOnly)
        realID(id)
        if mapID ~= nil then realID(mapID) end
        assert(displayableOnly == nil or type(displayableOnly) == "boolean")
        Mock.reverseCalls[#Mock.reverseCalls + 1] = {
            questID = id, mapID = mapID, displayableOnly = displayableOnly }
        if Mock.failReverseLineRead then error("Reverse quest-line fixture failure") end
        if mapID ~= nil then return (Mock.questLineInfoByMap[mapID] or {})[id] end
        return Mock.questLineInfoByQuest[id]
    end,
}
C_SuperTrack = {
    GetSuperTrackedQuestID = function()
        Mock.calls, Mock.trackedReads = Mock.calls + 1, Mock.trackedReads + 1
        if Mock.failTrackedRead then error("Tracked quest fixture failure") end
        return Mock.superTrackedQuestID
    end,
    IsSuperTrackingQuest = function()
        Mock.calls, Mock.trackingKindReads = Mock.calls + 1, Mock.trackingKindReads + 1
        if Mock.failTrackingKindRead then error("Tracking kind fixture failure") end
        return Mock.isSuperTrackingQuest
    end,
    GetHighestPrioritySuperTrackingType = function()
        Mock.calls, Mock.priorityReads = Mock.calls + 1, Mock.priorityReads + 1
        if Mock.failPriorityRead then error("Tracking priority fixture failure") end
        return Mock.highestPrioritySuperTrackingType
    end,
}
function GetQuestUiMapID(id, ignoreWaypoints)
    realID(id)
    assert(ignoreWaypoints == nil or type(ignoreWaypoints) == "boolean")
    Mock.questMapReads = Mock.questMapReads + 1
    Mock.questMapCalls[#Mock.questMapCalls + 1] = { questID = id, ignoreWaypoints = ignoreWaypoints }
    if Mock.failQuestMapRead then error("Quest map fixture failure") end
    return Mock.questMapIDs[id]
end
C_GossipInfo = { GetAvailableQuests = function() return Mock.offers end }
function UnitFactionGroup() return "Alliance" end
function UnitExists() return Mock.npc end
function InCombatLockdown() return Mock.combat end
function GetQuestID() return Mock.detailID end
function QuestGetAutoAccept() return Mock.autoAccepted == true end
function QuestFlagsPVP() return Mock.pvp == true end
function QuestIsFromAreaTrigger() return Mock.area == true end
function QuestIsFromAdventureMap() return Mock.adventure == true end
local function forbid(name, counter)
    return function()
        Mock.mutationCount = Mock.mutationCount + 1
        Mock.mutations[#Mock.mutations + 1] = name
        if counter then Mock[counter] = Mock[counter] + 1 end
        error("Forbidden game-changing API called: " .. name)
    end
end
AcceptQuest = forbid("AcceptQuest", "acceptCount")
SetAbandonQuest = forbid("SetAbandonQuest", "setAbandonCount")
AbandonQuest = forbid("AbandonQuest", "abandonCount")
for _, name in ipairs({ "CompleteQuest", "GetQuestReward", "ConfirmAcceptQuest", "ContinueQuest",
    "QuestMapFrame_OpenToQuestDetails", "SelectGossipOption", "SelectGossipAvailableQuest",
    "SelectGossipActiveQuest", "SelectAvailableQuest", "SelectActiveQuest", "AddQuestWatch",
    "RemoveQuestWatch", "SetSuperTrackedQuestID", "SetUserWaypoint", "ClearUserWaypoint",
    "DeleteCursorItem", "PickupContainerItem", "UseContainerItem", "PickupItem", "UseItemByName",
    "RunMacro", "RunMacroText", "RunScript", "CreateMacro", "EditMacro", "DeleteMacro",
    "SendChatMessage", "SendAddonMessage", "SetCVar", "ResetCvars", "CancelUnitBuff",
    "DropItemOnUnit", "DestroyTotem", "LeaveParty", "AcceptGroup", "DeclineGroup" }) do
    _G[name] = forbid(name)
end
for _, entry in ipairs({
    { "C_QuestLog", { "AbandonQuest", "SetAbandonQuest", "SetSelectedQuest", "RemoveQuestWatch" } },
    { "C_GossipInfo", { "SelectOption", "SelectAvailableQuest", "SelectActiveQuest" } },
    { "C_Container", { "DeleteCursorItem", "PickupContainerItem", "UseContainerItem", "SplitContainerItem" } },
    { "C_SuperTrack", { "SetSuperTrackedQuestID", "SetSuperTrackedUserWaypoint" } },
    { "C_Map", { "SetUserWaypoint", "ClearUserWaypoint" } },
    { "C_CVar", { "SetCVar", "ResetCVars" } },
    { "C_ChatInfo", { "SendAddonMessage", "SendAddonMessageLogged" } },
}) do
    local name, operations = entry[1], entry[2]
    _G[name] = _G[name] or {}
    for _, operation in ipairs(operations) do _G[name][operation] = forbid(name .. "." .. operation) end
end
C_QuestLog.AddQuestWatch = function(id)
    realID(id)
    Mock.watchAddCount = Mock.watchAddCount + 1
    Mock.watchAddCalls[#Mock.watchAddCalls + 1] = id
    if Mock.failWatchAdd then error("Quest-watch fixture failure") end
    if Mock.refuseWatchAdd then return false end
    assert(Mock.active[id] == true, "Only currently active quests may be watched")
    assert(not Mock.worldQuests[id] and not Mock.questTasks[id], "Only regular quests may be watched")
    assert(#Mock.watched < Constants.QuestWatchConsts.MAX_QUEST_WATCHES, "Watch limit was not checked")
    for _, watchedID in ipairs(Mock.watched) do assert(watchedID ~= id, "Already watched quest was added twice") end
    Mock.watched[#Mock.watched + 1] = id
    return true
end
C_SuperTrack.SetSuperTrackedQuestID = function(id)
    realID(id)
    Mock.superTrackSetCount = Mock.superTrackSetCount + 1
    Mock.superTrackSetCalls[#Mock.superTrackSetCalls + 1] = id
    if Mock.failSuperTrackSet then error("Quest-navigation fixture failure") end
    if Mock.refuseSuperTrackSet then return end
    assert(Mock.active[id] == true, "Only currently active quests may be navigation targets")
    assert(not Mock.worldQuests[id] and not Mock.questTasks[id], "Only regular quests may be navigation targets")
    local watched = false
    for _, watchedID in ipairs(Mock.watched) do if watchedID == id then watched = true end end
    assert(watched, "Clicked quest must be watched before setting navigation")
    Mock.superTrackedQuestID, Mock.isSuperTrackingQuest = id, true
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.Quest
    -- The generated Blizzard contract declares no return values.
end
function GetBuildInfo() return "12.1.0", "69933", "2026", 120100 end
function GetAchievementInfo(id)
    return id, "Verbündete Völker: Irdene", 10, Mock.achievementDone, 1, 1, 2026,
        "Description", 0, 1, "", false, Mock.achievementMine, "Name"
end
function GetAchievementNumCriteria() return 4 end
function GetAchievementCriteriaInfo(_, index) return "Criterion", 27, index <= Mock.criteriaDone end
