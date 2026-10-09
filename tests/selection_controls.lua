-- Map/line membership and names below are simulated client replies, not data facts.
-- Fixture IDs: https://www.wowhead.com/quest=78743, /quest=78744 and /quest=78745.
-- Pending lookup fixture IDs: https://www.wowhead.com/quest=78562 and /quest=78563.
-- Widget checks verify wiring only; real-client clipping and taint need manual testing.
local ns, passed = TEST_NS, 0
local mapID, lineID = 2248, 5506
local key = ns.LiveData.Key(mapID, lineID)
local function copy(value)
    local result = {}
    for name, item in pairs(value) do result[name] = item end
    return result
end
Mock.Flush()
local saved = { mock = Mock, chain = ns.chain, db = ns.db,
    maps = ns.WoW.questLines.maps, currentMapID = ns.WoW.questLines.currentMapID,
    requested = ns.WoW.requested, failedRequests = ns.WoW.failedRequests,
    offers = ns.WoW.offers, warnings = ns.WoW.warnings,
    questLineAPI = C_QuestLine, questLogAPI = C_QuestLog, superTrackAPI = C_SuperTrack,
    mapAPI = C_Map, questMapAPI = GetQuestUiMapID, enum = Enum }
local function event(name, ...)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, name, ...)
end
local function reset()
    if ns.UI.selector then ns.UI.selector:Hide() end
    if ns.UI.link then ns.UI.link:Hide() end
    ns.CancelQuestLookup()
    C_QuestLine, C_QuestLog, C_SuperTrack = copy(saved.questLineAPI), copy(saved.questLogAPI), copy(saved.superTrackAPI)
    C_Map, GetQuestUiMapID = copy(saved.mapAPI), saved.questMapAPI
    Enum = { SuperTrackingType = { Quest = 0, UserWaypoint = 1 } }
    Mock = copy(saved.mock)
    for _, name in ipairs({ "timers", "completed", "active", "titles", "requests", "offers", "log",
        "mapInfos", "questLinesByMap", "questLineQuests", "lineRequests", "questMapIDs",
        "questMapCalls", "questLineInfoByQuest", "questLineInfoByMap", "reverseCalls",
        "watched", "worldWatched", "tasks", "taskInfo", "warnings", "messages" }) do Mock[name] = {} end
    for _, name in ipairs({ "failMapRead", "failMapInfo", "failLineRequest", "failLineRead", "failLineQuests",
        "failReverseLineRead", "failTrackedRead", "failTrackingKindRead", "failPriorityRead", "failQuestMapRead",
        "failTasksRead", "failTaskInfo", "failWatchRead", "onLineRequest", "superTrackedQuestID",
        "highestPrioritySuperTrackingType" }) do Mock[name] = nil end
    Mock.warningCount, Mock.isSuperTrackingQuest, Mock.currentMapID = 0, false, mapID
    Mock.mapInfos[mapID], Mock.questLinesByMap[mapID] = { name = "Selection map fixture" }, {}
    ns.chain, ns.db, ns.pending = ns.LiveData.Empty(), copy(saved.db), false
    ns.db.selectedChain, ns.db.liveSelection = "none", nil
    QuestreihenTrackerDB = ns.db
    ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID = {}, nil
    ns.WoW.requested, ns.WoW.failedRequests, ns.WoW.offers = {}, {}, {}
    ns.WoW.ResetWarnings()
    ns.WoW.OnQuestLookupDataLoadResult(78743, false)
    ns.WoW.OnQuestLookupDataLoadResult(78562, false)
    ns.Refresh()
end
local function test(name, fn)
    reset()
    local ok, message = pcall(fn)
    assert(ok, "Selection controls / " .. name .. ": " .. tostring(message))
    Mock.Flush()
    assert(#Mock.timers == 0)
    assert(Mock.mutationCount == saved.mock.mutationCount, "Selection control changed game state")
    for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
    passed = passed + 1
end
local function selectLoaded(name)
    Mock.questLineQuests[lineID] = { 78743, 78744, 78745 }
    local chain = assert(ns.LiveData.Build(mapID, { questLineID = lineID, questLineName = name }, Mock.questLineQuests[lineID]))
    ns.WoW.RegisterQuestLine(chain)
    ns.Select(key)
    return ns.chain
end
local function clickClear()
    local button = assert(ns.UI.clearButton)
    assert(button:IsShown() and button:IsEnabled() and type(button.scripts.OnClick) == "function")
    button.scripts.OnClick(button, "LeftButton")
end
local function assertEmpty()
    assert(ns.chain.id == "none" and ns.chain.empty and ns.db.selectedChain == "none" and ns.db.liveSelection == nil)
    assert(ns.result.total == 0 and ns.result.completed == 0 and not ns.result.done)
    assert(ns.questLookup == nil and ns.WoW.questLookup == nil)
    assert(not ns.UI.clearButton:IsShown() or not ns.UI.clearButton:IsEnabled())
    for _, row in pairs(ns.UI.rows or {}) do
        assert(not (row:IsShown() and rawget(row, "questID")), "Removed list retained a visible quest row")
    end
end

test("clear button removes selection and transient state while preserving preferences and Blizzard tracking", function()
    selectLoaded("Loaded selection fixture")
    ns.db.size = { width = 820, height = 930 }
    ns.db.position = { point = "LEFT", relativePoint = "LEFT", x = 80, y = 15 }
    ns.db.minimapAngle = 135
    ns.UI.Restore()
    Mock.watched, Mock.worldWatched, Mock.tasks = { 78743 }, { 78744 }, { 78745 }
    Mock.isSuperTrackingQuest, Mock.superTrackedQuestID = true, 78743
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.Quest
    Mock.userWaypoint = { uiMapID = mapID, x = 0.4, y = 0.5 }
    Mock.completed[78743], Mock.active[78744] = true, true
    ns.UI.ChooseChain(); ns.UI.ShowLink(78743); Mock.Flush()
    ns.WoW.offers = { [78744] = true }
    ns.WoW.warnings.pendingAccepted[78745] = key
    ns.UI.scroll:SetVerticalScroll(120)
    local db, size, position = ns.db, ns.db.size, ns.db.position
    local panelPositions, waypoint = ns.db.panelPositions, Mock.userWaypoint
    clickClear()
    assertEmpty()
    assert(ns.db == db and ns.db.size == size and ns.db.position == position and ns.db.panelPositions == panelPositions)
    assert(ns.db.minimapAngle == 135 and ns.UI.frame:GetWidth() == 820 and ns.UI.frame:GetHeight() == 930)
    assert(ns.UI.scroll.scroll == 0 and not ns.UI.selector:IsShown() and not ns.UI.link:IsShown())
    assert(next(ns.WoW.offers) == nil and next(ns.WoW.warnings.pendingAccepted) == nil)
    assert(Mock.watched[1] == 78743 and Mock.worldWatched[1] == 78744 and Mock.tasks[1] == 78745)
    assert(Mock.superTrackedQuestID == 78743 and Mock.isSuperTrackingQuest and Mock.userWaypoint == waypoint)
    assert(Mock.completed[78743] == true and Mock.active[78744] == true)
end)

test("clear loaded list defeats queued refreshes and does not auto-select rediscovered lines", function()
    selectLoaded("Queued selection fixture")
    Mock.questLinesByMap[mapID] = { { questLineID = lineID, questLineName = "Rediscovered selection fixture", questID = 78744 } }
    event("QUEST_ACCEPTED", 78745)
    event("QUESTLINE_UPDATE", false)
    assert(#Mock.timers == 1)
    clickClear(); Mock.Flush(); assertEmpty()
    for _, name in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "QUESTLINE_UPDATE", "QUEST_LOG_UPDATE" }) do
        event(name, false)
    end
    Mock.Flush(); assertEmpty()
    local choices = ns.WoW.ZoneQuestLines()
    assert(#choices == 1 and choices[1].id == key, "Ordinary discovery must remain usable after clearing")
    assert(Mock.warningCount == 0)
end)

test("loading selection is removable before membership arrives", function()
    ns.chain = assert(ns.WoW.RestoreQuestLine({ mapID = mapID, questLineID = lineID }))
    ns.db.selectedChain, ns.db.liveSelection = key, { mapID = mapID, questLineID = lineID }
    ns.Refresh()
    assert(ns.chain.loading and ns.UI.clearButton:IsEnabled())
    clickClear(); assertEmpty()
    Mock.questLinesByMap[mapID] = { { questLineID = lineID, questLineName = "Late loading fixture" } }
    Mock.questLineQuests[lineID] = { 78743, 78744 }
    event("QUESTLINE_UPDATE", false); Mock.Flush(); assertEmpty()
end)

test("clear cancels an in-flight quest lookup and late results cannot restore it", function()
    selectLoaded("Previous list fixture")
    Mock.questMapIDs[78562], Mock.titles[78562] = mapID, nil
    ns.UI.ChooseChain(); Mock.Flush()
    ns.LookupQuest(78562)
    assert(ns.questLookup and ns.questLookup.pending)
    clickClear(); assertEmpty()
    Mock.questLineInfoByQuest[78562] = { questLineID = lineID + 1, questLineName = "Late query fixture", startMapID = mapID }
    Mock.questLineQuests[lineID + 1], Mock.titles[78562] = { 78562, 78563 }, "Late title fixture"
    event("QUESTLINE_UPDATE", false); event("QUEST_DATA_LOAD_RESULT", 78562, true)
    Mock.Flush(); assertEmpty()
end)

test("clearing is idempotent and leaves only an empty saved selection", function()
    selectLoaded("Idempotence fixture")
    ns.ClearSelection(); ns.ClearSelection(); ns.Refresh()
    assertEmpty()
    local config = ns.ReadConfig(QuestreihenTrackerDB)
    assert(config.selectedChain == "none" and config.liveSelection == nil)
    assert(Mock.warningCount == 0)
end)

test("restored filtered membership obtains the matching localized line name after a later event", function()
    Mock.questLineQuests[lineID] = { 78743, 78744, 78745 }
    ns.chain = assert(ns.WoW.RestoreQuestLine({ mapID = mapID, questLineID = lineID }))
    ns.db.selectedChain, ns.db.liveSelection = key, { mapID = mapID, questLineID = lineID }
    ns.Refresh()
    assert(ns.chain.name == string.format(ns.L.BLIZZARD_LINE_NAME, lineID))
    Mock.questLineInfoByMap[mapID] = { [78744] = { questLineID = lineID, questLineName = "Localized delayed line fixture" } }
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    assert(ns.chain.name == "Localized delayed line fixture" and ns.chain.nameKnown)
    assert(ns.chain.nameSourceAPI == "C_QuestLine.GetQuestLineInfo")
    assert(ns.UI.select:GetText():find(ns.chain.name, 1, true))
    assert(ns.db.liveSelection.name == nil, "Runtime names must not become saved progress/data")
    assert(Mock.lineRequests[mapID] == 1)
end)

test("wrong line names and quest names are not accepted as selected line metadata", function()
    selectLoaded(nil)
    Mock.questLineInfoByQuest[78743] = { questLineID = lineID + 1, questLineName = "Wrong line fixture" }
    Mock.questLineInfoByMap[mapID] = {
        [78743] = { questLineID = lineID, questName = "Quest title fixture" },
        [78744] = { questLineID = lineID + 1, questLineName = "Wrong map line fixture" },
    }
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    assert(ns.chain.name == string.format(ns.L.BLIZZARD_LINE_NAME, lineID) and not ns.chain.nameKnown)
    for _, reply in ipairs(Mock.reverseCalls) do
        assert(reply.displayableOnly == false, "Filtered lines need unrestricted metadata reads")
    end
    Mock.questLineInfoByQuest[78745] = { questLineID = lineID, questLineName = "Matching remaining member fixture" }
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    assert(ns.chain.name == "Matching remaining member fixture" and ns.chain.nameKnown)
end)

test("a known client name survives nil and empty map metadata and replacement registration", function()
    selectLoaded("Known line fixture")
    for _, metadata in ipairs({ { questLineID = lineID }, { questLineID = lineID, questLineName = "" } }) do
        Mock.questLinesByMap[mapID] = { metadata }
        event("QUESTLINE_UPDATE", false); Mock.Flush()
        assert(ns.chain.name == "Known line fixture" and ns.chain.nameKnown)
        local replacement = assert(ns.LiveData.Build(mapID, metadata, { 78743, 78744, 78745 }))
        ns.WoW.RegisterQuestLine(replacement); ns.Refresh()
        assert(ns.chain.name == "Known line fixture" and ns.chain.nameKnown)
    end
end)

test("hidden matching map metadata supplies the selected name without exposing a hidden choice", function()
    selectLoaded(nil)
    local reads = #Mock.reverseCalls
    Mock.questLinesByMap[mapID] = { { questLineID = lineID, questLineName = "Hidden matching line fixture", isHidden = true } }
    ns.DiscoverZone(false)
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    assert(ns.chain.name == "Hidden matching line fixture" and ns.chain.nameKnown)
    assert(ns.chain.nameSourceAPI == "C_QuestLine.GetAvailableQuestLines")
    assert(#Mock.reverseCalls == reads, "Matching map metadata should avoid unnecessary reverse reads")
    local choices = ns.WoW.ZoneQuestLines()
    assert(#choices == 0 and ns.result.total == 3)
end)

test("independent member metadata repairs the header during failed map discovery without erasing cached data", function()
    for _, failure in ipairs({ "nil", "error", "unsupported" }) do
        reset()
        Mock.questLinesByMap[mapID] = { { questLineID = lineID } }
        selectLoaded(nil)
        Mock.Flush()
        local map = ns.WoW.questLines.maps[mapID]
        assert(#map.chains == 1 and not ns.chain.nameKnown)
        local choices = map.chains
        Mock.questLineInfoByMap[mapID] = { [78744] = { questLineID = lineID, questLineName = "Name despite discovery failure fixture" } }
        if failure == "nil" then Mock.questLinesByMap[mapID] = nil
        elseif failure == "error" then Mock.failLineRead = true
        else C_QuestLine.GetAvailableQuestLines = nil end
        ns.Refresh()
        assert(ns.chain.name == "Name despite discovery failure fixture" and ns.chain.nameKnown)
        assert(ns.chain.nameSourceAPI == "C_QuestLine.GetQuestLineInfo")
        assert(ns.result.total == 3 and ns.db.selectedChain == key and map.chains == choices)
        assert(ns.UI.select:GetText():find(ns.chain.name, 1, true))
        assert(next(Mock.lineRequests) == nil and #Mock.timers == 0)
    end
end)

test("minimum-width header leaves both selection and removal buttons usable", function()
    selectLoaded("A long runtime line-name fixture that needs the native label tooltip")
    ns.UI.frame:SetSize(ns.UI.MIN_WIDTH, ns.UI.MIN_HEIGHT)
    local selectWidth, clearWidth = ns.UI.select:GetWidth(), ns.UI.clearButton:GetWidth()
    assert(selectWidth > 100 and clearWidth >= 80 and selectWidth + clearWidth + 8 <= ns.UI.MIN_WIDTH - 32)
    assert(ns.UI.trackedButton:GetWidth() == ns.UI.MIN_WIDTH - 32)
    assert(ns.UI.select.tooltip == ns.chain.name and ns.UI.clearButton:IsEnabled())
    clickClear(); assertEmpty()
end)

test("main tracked button resolves the current Blizzard navigation quest", function()
    assert(not ns.UI.selector or not ns.UI.selector:IsShown())
    Mock.questLineInfoByQuest[78743] = { questLineID = lineID,
        questLineName = "Main tracked lookup fixture", questID = 78743, startMapID = mapID }
    Mock.questLineQuests[lineID] = { 78743, 78744, 78745 }
    Mock.isSuperTrackingQuest, Mock.superTrackedQuestID = true, 78743
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.Quest
    local button = ns.UI.trackedButton
    assert(button and button:IsShown() and button:IsEnabled())
    button.scripts.OnClick(button, "LeftButton")
    Mock.Flush()
    assert(ns.chain.id == key and ns.db.liveSelection.questLineID == lineID)
    assert(ns.UI.notice:GetText() == ns.L.BLIZZARD_NOTICE)
    assert(ns.UI.frame:IsShown() and (not ns.UI.selector or not ns.UI.selector:IsShown()))
end)

test("main tracked button shows lookup failures without opening the selector", function()
    local button = ns.UI.trackedButton
    button.scripts.OnClick(button, "LeftButton")
    assert(ns.questLookup.status == "NO_TRACKED" and ns.chain.empty)
    assert(ns.UI.notice:GetText() == ns.L.LOOKUP_NO_TRACKED)
    assert(not ns.UI.selector or not ns.UI.selector:IsShown())
end)

test("quest rows show progress without availability clutter", function()
    selectLoaded("Progress label fixture")
    Mock.active[78744] = true
    Mock.completed[78745] = true
    ns.Refresh()
    local expected = { [78743] = ns.L.NOT_ACCEPTED, [78744] = ns.L.ACTIVE, [78745] = ns.L.COMPLETED }
    local found = 0
    for _, row in pairs(ns.UI.rows or {}) do
        local id = rawget(row, "questID")
        if row:IsShown() and id then
            assert(row.subtext:GetText() == expected[id])
            assert(not row.subtext:GetText():find(ns.L.UNKNOWN, 1, true))
            assert(row.clickButtons[1] == "LeftButtonUp" and row.clickButtons[2] == "RightButtonUp")
            found = found + 1
        end
    end
    assert(found == 3)
end)

if ns.UI.selector then ns.UI.selector:Hide() end
if ns.UI.link then ns.UI.link:Hide() end
ns.CancelQuestLookup()
Mock = saved.mock
C_QuestLine, C_QuestLog, C_SuperTrack = saved.questLineAPI, saved.questLogAPI, saved.superTrackAPI
C_Map, GetQuestUiMapID, Enum = saved.mapAPI, saved.questMapAPI, saved.enum
ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID = saved.maps, saved.currentMapID
ns.WoW.requested, ns.WoW.failedRequests = saved.requested, saved.failedRequests
ns.WoW.offers, ns.WoW.warnings = saved.offers, saved.warnings
ns.chain, ns.db, ns.pending = saved.chain, saved.db, false
QuestreihenTrackerDB = ns.db
ns.UI.Restore(); ns.Refresh()
print("Selection removal, runtime naming and header tests passed: " .. passed)
