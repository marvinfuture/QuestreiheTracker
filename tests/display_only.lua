-- These fixtures trap all actions except explicit regular-quest watch/navigation clicks.
-- They do not establish live-client layout, Blizzard internals, or taint safety.
local ns, passed = TEST_NS, 0
local fixture = assert(ns.LiveData.Build(2248, { questLineID = 5506,
    questLineName = "Display-only fixture" }, { 78743, 78744, 78745 }))
ns.WoW.RegisterQuestLine(fixture)
ns.Select(fixture.id)
Mock.Flush()
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function same(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not same(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end
local function gameState()
    return copy({ completed = Mock.completed, active = Mock.active, titles = Mock.titles,
        log = Mock.log, offers = Mock.offers, questLinesByMap = Mock.questLinesByMap,
        questLineQuests = Mock.questLineQuests, mapInfos = Mock.mapInfos,
        currentMapID = Mock.currentMapID, detailID = Mock.detailID, npc = Mock.npc,
        combat = Mock.combat, achievementDone = Mock.achievementDone,
        achievementMine = Mock.achievementMine, criteriaDone = Mock.criteriaDone })
end
local function noMutation(before)
    assert(Mock.mutationCount == 0, "Forbidden game API used: " .. table.concat(Mock.mutations or {}, ", "))
    assert(Mock.acceptCount == 0 and Mock.setAbandonCount == 0 and Mock.abandonCount == 0)
    assert(Mock.opened == nil, "Tracker opened Blizzard quest details")
    assert(same(before, gameState()), "Display interaction changed a game-data fixture")
end
local function test(name, fn, allowWatch)
    local before = gameState()
    local watchAdds, watches = Mock.watchAddCount, copy(Mock.watched)
    local navigationSets, navigation = Mock.superTrackSetCount, Mock.superTrackedQuestID
    local trackingQuest, trackingKind = Mock.isSuperTrackingQuest, Mock.highestPrioritySuperTrackingType
    local ok, message = pcall(fn)
    assert(ok, "Quest interactions / " .. name .. ": " .. tostring(message))
    noMutation(before)
    if not allowWatch then
        assert(Mock.watchAddCount == watchAdds and same(watches, Mock.watched),
            "Read-only interaction changed quest watches")
        assert(Mock.superTrackSetCount == navigationSets and Mock.superTrackedQuestID == navigation
            and Mock.isSuperTrackingQuest == trackingQuest and Mock.highestPrioritySuperTrackingType == trackingKind,
            "Read-only interaction changed quest navigation")
    end
    passed = passed + 1
end
local function event(name, ...)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, name, ...)
end
local function click(widget, button)
    assert(type(widget.scripts.OnClick) == "function", "Control has no click handler")
    widget.scripts.OnClick(widget, button or "LeftButton")
end
local function visibleRows()
    local rows = {}
    for _, row in pairs(ns.UI.rows or {}) do
        if row:IsShown() and rawget(row, "questID") and row.subtext:GetText() ~= "" then
            rows[#rows + 1] = row
        end
    end
    return rows
end

assert(type(Mock.mutationCount) == "number" and type(Mock.mutations) == "table",
    "Display-only suite requires forbidden game-API traps")

test("every runtime quest row right-click only shows addon UI", function()
    assert(ns.WoW.OpenQuest == nil, "Game quest navigation must not be exposed")
    assert(ns.DemoData == nil and ns.ToggleDemo == nil and rawget(ns.UI, "demoButton") == nil)
    for _, chain in ipairs({ fixture }) do
        ns.Select(chain.id)
        ns.UI.frame:Show()
        local rows = visibleRows()
        assert(#rows == #ns.Model.Flatten(chain), "All quests must remain represented")
        for _, row in ipairs(rows) do
            assert(row.questID > 0, "Only real quest IDs belong in the quest list")
            local before = gameState()
            click(row, "RightButton")
            assert(ns.UI.link:IsShown())
            assert(ns.UI.link.edit:GetText() == "https://www.wowhead.com/quest=" .. row.questID)
            ns.UI.link.edit.scripts.OnEscapePressed(ns.UI.link.edit)
            assert(not ns.UI.link:IsShown())
            row.scripts.OnEnter(row)
            assert(GameTooltip:IsShown())
            row.scripts.OnLeave(row)
            assert(not GameTooltip:IsShown())
            noMutation(before)
        end
    end
end)

local function watchTest(name, fn)
    Mock.Flush()
    local saved = { active = Mock.active, completed = Mock.completed, watched = Mock.watched,
        worldQuests = Mock.worldQuests, questTasks = Mock.questTasks, combat = Mock.combat,
        questLog = C_QuestLog, superTrack = C_SuperTrack, constants = Constants, enum = Enum,
        superTrackedQuestID = Mock.superTrackedQuestID, isSuperTrackingQuest = Mock.isSuperTrackingQuest,
        highestPrioritySuperTrackingType = Mock.highestPrioritySuperTrackingType }
    local api = {}; for key, value in pairs(C_QuestLog) do api[key] = value end
    C_QuestLog = api
    api = {}; for key, value in pairs(C_SuperTrack) do api[key] = value end
    C_SuperTrack = api
    Enum = { SuperTrackingType = { Quest = 0, UserWaypoint = 1 } }
    Constants = { QuestWatchConsts = { MAX_QUEST_WATCHES = 25 } }
    Mock.active, Mock.completed, Mock.watched = { [78743] = true }, {}, {}
    Mock.worldQuests, Mock.questTasks, Mock.combat = {}, {}, false
    Mock.superTrackedQuestID, Mock.isSuperTrackingQuest, Mock.highestPrioritySuperTrackingType = nil, false, nil
    ns.Select(fixture.id); ns.UI.frame:Show(); Mock.Flush()
    -- Adapter tests may change read fixtures; each assertion captures its own
    -- immutable quest data immediately before invoking the adapter or click.
    local ok, message = pcall(fn)
    Mock.Flush()
    C_QuestLog, C_SuperTrack, Constants, Enum = saved.questLog, saved.superTrack, saved.constants, saved.enum
    Mock.active, Mock.completed, Mock.watched = saved.active, saved.completed, saved.watched
    Mock.worldQuests, Mock.questTasks, Mock.combat = saved.worldQuests, saved.questTasks, saved.combat
    Mock.superTrackedQuestID, Mock.isSuperTrackingQuest = saved.superTrackedQuestID, saved.isSuperTrackingQuest
    Mock.highestPrioritySuperTrackingType = saved.highestPrioritySuperTrackingType
    Mock.failWatchAdd, Mock.refuseWatchAdd, Mock.failWatchRead, Mock.failQuestKindRead = nil, nil, nil, nil
    Mock.failSuperTrackSet, Mock.refuseSuperTrackSet = nil, nil
    Mock.failTrackedRead, Mock.failTrackingKindRead, Mock.failPriorityRead = nil, nil, nil
    assert(ok, "Quest watching / " .. name .. ": " .. tostring(message))
    assert(Mock.mutationCount == 0 and Mock.invalidIDCalls == 0)
    passed = passed + 1
    ns.WoW.ResetWarnings(); ns.Refresh(); Mock.Flush()
end
local function watchResult(id, success, status, adds, navigationSets)
    local before, count, sets = gameState(), Mock.watchAddCount, Mock.superTrackSetCount
    local ok, result = ns.WoW.WatchQuest(id)
    assert(ok == success and result == status, tostring(result))
    assert(Mock.watchAddCount == count + (adds or 0))
    assert(Mock.superTrackSetCount == sets + (navigationSets or (success and 1 or 0)))
    if success then assert(ns.WoW.SuperTrackedQuestID() == id) end
    noMutation(before)
end

watchTest("left click observes an accepted quest once and selects its navigation", function()
    local chosen
    for _, row in ipairs(visibleRows()) do if row.questID == 78743 then chosen = row end end
    assert(chosen and chosen.clickButtons[1] == "LeftButtonUp" and chosen.clickButtons[2] == "RightButtonUp")
    if ns.UI.link then ns.UI.link:Hide() end
    local before, adds, sets = gameState(), Mock.watchAddCount, Mock.superTrackSetCount
    click(chosen, "LeftButton")
    assert(Mock.watchAddCount == adds + 1 and #Mock.watched == 1 and Mock.watched[1] == 78743)
    assert(not ns.UI.link:IsShown(), "Left click must not open a Wowhead link")
    assert(ns.WoW.SuperTrackedQuestID() == 78743 and Mock.superTrackSetCount == sets + 1)
    click(chosen, "LeftButton")
    assert(Mock.watchAddCount == adds + 1 and #Mock.watched == 1, "Repeated click must keep the quest watched")
    assert(Mock.superTrackSetCount == sets + 2)
    click(chosen, "MiddleButton")
    assert(Mock.watchAddCount == adds + 1 and Mock.superTrackSetCount == sets + 2)
    click(chosen, "RightButton")
    assert(ns.UI.link:IsShown() and Mock.watchAddCount == adds + 1 and Mock.superTrackSetCount == sets + 2)
    noMutation(before)
end)

watchTest("an already watched quest replaces another quest or waypoint navigation", function()
    Mock.watched = { 78743 }
    Mock.superTrackedQuestID, Mock.isSuperTrackingQuest = 78744, true
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.Quest
    watchResult(78743, true, "ALREADY_WATCHED")
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.UserWaypoint
    watchResult(78743, true, "ALREADY_WATCHED")
    assert(#Mock.watched == 1 and Mock.watched[1] == 78743)
end)

watchTest("invalid synthetic inactive and completed absent quests never request a watch", function()
    local calls = Mock.calls
    for _, id in ipairs({ -101, 0, 1.5, "78743", math.huge, -math.huge, 0 / 0 }) do
        watchResult(id, false, "INVALID_ID")
    end
    watchResult(nil, false, "INVALID_ID")
    assert(Mock.calls == calls, "Invalid IDs reached a quest API")
    watchResult(78744, false, "NOT_ACTIVE")
    Mock.completed[78745] = true
    watchResult(78745, false, "NOT_ACTIVE")
    local row = ns.UI.Row(ns.UI.content, "watch-invalid-fixture")
    local before, adds = gameState(), Mock.watchAddCount
    for _, id in ipairs({ -101, 0, 78744, 78745, 78562 }) do
        row.questID = id; click(row, "LeftButton")
    end
    row:Hide()
    assert(#Mock.watched == 0 and Mock.watchAddCount == adds)
    noMutation(before)
end)

watchTest("an accepted repeatable iteration remains watchable after historical completion", function()
    Mock.completed[78743] = true
    watchResult(78743, true, "WATCHED", 1)
    watchResult(78743, true, "ALREADY_WATCHED")
end)

watchTest("world quests and bonus tasks require their separate Blizzard watch APIs", function()
    Mock.worldQuests[78743] = true; watchResult(78743, false, "NOT_REGULAR")
    Mock.worldQuests[78743], Mock.questTasks[78743] = nil, true
    watchResult(78743, false, "NOT_REGULAR")
    assert(#Mock.watched == 0 and #Mock.worldWatched == 0)
end)

watchTest("watch limit keeps existing watches and an existing watch succeeds at the limit", function()
    Constants.QuestWatchConsts.MAX_QUEST_WATCHES = 2
    Mock.watched = { 78744, 78745 }
    watchResult(78743, false, "LIMIT")
    assert(Mock.watched[1] == 78744 and Mock.watched[2] == 78745)
    Mock.active[78744] = true
    watchResult(78744, true, "ALREADY_WATCHED")
end)

watchTest("missing thrown and refusing APIs never report success or retry automatically", function()
    local active, kind, add, count = C_QuestLog.IsOnQuest, C_QuestLog.IsQuestTask,
        C_QuestLog.AddQuestWatch, C_QuestLog.GetNumQuestWatches
    C_QuestLog.IsOnQuest = nil; watchResult(78743, false, "UNAVAILABLE")
    C_QuestLog.IsOnQuest = function() error("Active-state read failed") end
    watchResult(78743, false, "UNAVAILABLE"); C_QuestLog.IsOnQuest = active
    C_QuestLog.IsQuestTask = nil; watchResult(78743, false, "UNAVAILABLE"); C_QuestLog.IsQuestTask = kind
    Mock.failQuestKindRead = true; watchResult(78743, false, "UNAVAILABLE"); Mock.failQuestKindRead = nil
    for _, value in ipairs({ -1, 0.5, math.huge, 0 / 0 }) do
        C_QuestLog.GetNumQuestWatches = function() return value end
        watchResult(78743, false, "UNAVAILABLE")
    end
    C_QuestLog.GetNumQuestWatches = nil; watchResult(78743, false, "UNAVAILABLE")
    C_QuestLog.GetNumQuestWatches = count
    Mock.failWatchRead = true; watchResult(78743, false, "UNAVAILABLE"); Mock.failWatchRead = nil
    Mock.watched = { -101 }; watchResult(78743, false, "UNAVAILABLE")
    Mock.watched = { 78744 }
    local idRead = C_QuestLog.GetQuestIDForQuestWatchIndex
    C_QuestLog.GetQuestIDForQuestWatchIndex = nil; watchResult(78743, false, "UNAVAILABLE")
    C_QuestLog.GetQuestIDForQuestWatchIndex = function() error("Watch-ID read failed") end
    watchResult(78743, false, "UNAVAILABLE")
    C_QuestLog.GetQuestIDForQuestWatchIndex, Mock.watched = idRead, {}
    local constants = Constants; Constants = nil
    watchResult(78743, false, "UNAVAILABLE"); Constants = constants
    C_QuestLog.AddQuestWatch = nil; watchResult(78743, false, "FAILED"); C_QuestLog.AddQuestWatch = add
    Mock.failWatchAdd = true; watchResult(78743, false, "FAILED", 1); Mock.failWatchAdd = nil
    Mock.refuseWatchAdd = true; watchResult(78743, false, "FAILED", 1); Mock.refuseWatchAdd = nil
    local adds = Mock.watchAddCount
    event("QUEST_LOG_UPDATE"); event("PLAYER_REGEN_ENABLED"); Mock.Flush()
    assert(Mock.watchAddCount == adds and #Mock.watched == 0, "Watch failures must wait for another click")
end)

watchTest("explicit combat click uses the normal watch API without a deferred action", function()
    Mock.combat = true
    watchResult(78743, true, "WATCHED", 1)
    assert(#Mock.timers == 0)
end)

watchTest("missing throwing and silently rejected navigation never report success", function()
    local setter = C_SuperTrack.SetSuperTrackedQuestID
    C_SuperTrack.SetSuperTrackedQuestID = nil
    watchResult(78743, false, "NAVIGATION_FAILED", 1)
    assert(Mock.watched[1] == 78743, "A navigation failure must preserve the successful watch")
    C_SuperTrack.SetSuperTrackedQuestID = setter
    Mock.failSuperTrackSet = true
    watchResult(78743, false, "NAVIGATION_FAILED", 0, 1)
    Mock.failSuperTrackSet, Mock.refuseSuperTrackSet = nil, true
    watchResult(78743, false, "NAVIGATION_FAILED", 0, 1)
    Mock.refuseSuperTrackSet = nil
    for _, failure in ipairs({ "failTrackedRead", "failTrackingKindRead", "failPriorityRead" }) do
        Mock[failure] = true
        watchResult(78743, false, "NAVIGATION_FAILED", 0, 1)
        Mock[failure] = nil
    end
    local reader = C_SuperTrack.GetSuperTrackedQuestID
    C_SuperTrack.GetSuperTrackedQuestID = nil
    watchResult(78743, false, "NAVIGATION_FAILED", 0, 1)
    C_SuperTrack.GetSuperTrackedQuestID = reader
    local sets = Mock.superTrackSetCount
    event("QUEST_LOG_UPDATE"); event("SUPER_TRACKING_CHANGED"); event("PLAYER_REGEN_ENABLED"); Mock.Flush()
    assert(Mock.superTrackSetCount == sets, "Navigation failures must wait for another explicit click")
end)

test("quest NPC progress and data events only refresh the display", function()
    ns.Select(fixture.id)
    Mock.Flush()
    for _, name in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "QUEST_TURNED_IN", "QUEST_DATA_LOAD_RESULT", "QUEST_DETAIL", "QUEST_FINISHED",
        "GOSSIP_SHOW", "GOSSIP_CLOSED", "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE",
        "PLAYER_REGEN_ENABLED", "QUESTLINE_UPDATE", "ZONE_CHANGED_NEW_AREA",
        "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN" }) do
        if name == "QUEST_ACCEPTED" or name == "QUEST_REMOVED" or name == "QUEST_TURNED_IN" then
            event(name, 78743)
        elseif name == "QUEST_DATA_LOAD_RESULT" then event(name, 78743, true)
        elseif name == "QUEST_DETAIL" then event(name, 0)
        elseif name == "QUESTLINE_UPDATE" then event(name, false)
        else event(name) end
    end
    assert(#Mock.timers == 1, "Event burst should use one coalescing timer")
    Mock.Flush()
    assert(#Mock.timers == 0)
end)

test("selector refresh and runtime row right-clicks remain read-only", function()
    ns.Slash("zone")
    Mock.Flush()
    assert(ns.UI.selector:IsShown())
    click(ns.UI.selector.refresh)
    event("QUESTLINE_UPDATE", false)
    Mock.Flush()
    local chains = ns.WoW.ZoneQuestLines()
    assert(#chains > 0, "Runtime fixtures must provide a selectable quest line")
    local chosen
    for _, button in ipairs(ns.UI.selector.buttons) do
        if button:IsShown() and button.chainID == chains[1].id then chosen = button end
    end
    assert(chosen, "Runtime line has no visible selection control")
    click(chosen)
    assert(ns.chain.runtime and not ns.UI.selector:IsShown())
    local rows = visibleRows()
    assert(#rows > 0)
    for _, row in ipairs(rows) do click(row, "RightButton") end

end)

test("selector minimap window movement and reset only change preferences", function()
    ns.UI.frame:Hide()
    click(ns.Minimap.button, "LeftButton")
    assert(ns.UI.frame:IsShown())
    click(ns.Minimap.button, "RightButton")
    assert(ns.UI.selector:IsShown() and ns.UI.Options == nil)
    ns.UI.frame.scripts.OnDragStart(ns.UI.frame)
    ns.UI.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60)
    ns.UI.frame.scripts.OnDragStop(ns.UI.frame)
    assert(ns.db.position.x == 40 and ns.db.position.y == -60)
    ns.Slash("debug")
    ns.Slash("quest 78743")
    ns.Slash("reset")
    assert(ns.db.position == nil and ns.db.autoAccept == nil and ns.db.autoAbandon == nil)
    Mock.Flush()
    for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
end)

print("Quest interaction integration tests passed: " .. passed .. "; forbidden game API calls: " .. Mock.mutationCount)
