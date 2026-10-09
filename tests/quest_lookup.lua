-- All map/line associations and names below are simulated API replies, not data facts.
-- Fixture IDs: https://www.wowhead.com/quest=78562, /quest=78563 and /quest=78564.
-- No production catalog or curated fallback is loaded by these tests.
local ns, passed = TEST_NS, 0
local mapID, lineID = 2248, 5506
local liveKey = ns.LiveData.Key(mapID, lineID)
local questID = 78562
local function copy(value)
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    return result
end
Mock.Flush()
local saved = {
    mock = Mock, db = ns.db, chain = ns.chain,
    maps = ns.WoW.questLines.maps, currentMapID = ns.WoW.questLines.currentMapID,
    requested = ns.WoW.requested, failedRequests = ns.WoW.failedRequests,
    offers = ns.WoW.offers,
    questLineAPI = C_QuestLine, questLogAPI = C_QuestLog, superTrackAPI = C_SuperTrack,
    mapAPI = C_Map, questMapAPI = GetQuestUiMapID, enum = Enum,
}
local function event(name, ...)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, name, ...)
end
local function reset()
    if ns.UI.selector then ns.UI.selector:Hide() end
    ns.CancelQuestLookup()
    C_QuestLine, C_QuestLog = copy(saved.questLineAPI), copy(saved.questLogAPI)
    C_SuperTrack, C_Map = copy(saved.superTrackAPI), copy(saved.mapAPI)
    GetQuestUiMapID = saved.questMapAPI
    Enum = { SuperTrackingType = { Quest = 0, UserWaypoint = 1 } }
    Mock = copy(saved.mock)
    for _, name in ipairs({ "timers", "completed", "active", "titles", "requests", "offers", "log",
        "mapInfos", "questLinesByMap", "questLineQuests", "lineRequests", "questMapIDs",
        "questMapCalls", "questLineInfoByQuest", "questLineInfoByMap", "reverseCalls" }) do
        Mock[name] = {}
    end
    for _, name in ipairs({ "failMapRead", "failMapInfo", "failLineRequest", "failLineRead",
        "failLineQuests", "failReverseLineRead", "failTrackedRead", "failTrackingKindRead",
        "failPriorityRead", "failQuestMapRead", "onLineRequest", "currentMapID",
        "superTrackedQuestID", "highestPrioritySuperTrackingType" }) do Mock[name] = nil end
    Mock.isSuperTrackingQuest = false
    ns.pending = false
    ns.chain, ns.db = ns.LiveData.Empty(), copy(saved.db)
    ns.db.selectedChain, ns.db.liveSelection = ns.chain.id, nil
    QuestStrangTrackerDB = ns.db
    ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID = {}, nil
    ns.WoW.requested, ns.WoW.failedRequests, ns.WoW.offers = {}, {}, {}
    ns.WoW.ResetWarnings()
    -- Reset the public result cache through a failed-result fixture. A fresh
    -- explicit lookup must request data again when no title is currently cached.
    ns.WoW.OnQuestLookupDataLoadResult(questID, false)
    Mock.mapInfos[mapID] = { name = "Lookup map test fixture" }
    Mock.questLinesByMap[mapID] = {}
    ns.Refresh()
end
local function test(name, fn)
    reset()
    local ok, message = pcall(fn)
    assert(ok, "Quest lookup / " .. name .. ": " .. tostring(message))
    Mock.Flush()
    assert(#Mock.timers == 0)
    assert(Mock.mutationCount == saved.mock.mutationCount, "Lookup attempted a game mutation")
    for _, frame in ipairs(Mock.frames) do
        assert(frame.scripts.OnUpdate == nil, "Lookup must not install permanent polling")
    end
    passed = passed + 1
end
local function selector()
    if not ns.UI.selector or not ns.UI.selector:IsShown() then ns.UI.ChooseChain() end
    Mock.Flush()
    return ns.UI.selector
end
local function click(button)
    assert(button and type(button.scripts.OnClick) == "function")
    button.scripts.OnClick(button, "LeftButton")
end
local function input(text, submitWithEnter)
    local panel = selector()
    panel.questIDInput:SetText(text)
    -- The intentionally small widget stub does not dispatch text-change events.
    panel.questIDInput.scripts.OnTextChanged(panel.questIDInput, true)
    if submitWithEnter then panel.questIDInput.scripts.OnEnterPressed(panel.questIDInput)
    else click(panel.lookupButton) end
end
local function reverseFixture(id, ids, context)
    Mock.questLineInfoByQuest[id] = { questLineID = lineID,
        questLineName = "Reverse lookup story test fixture", questID = id, startMapID = context or mapID }
    Mock.questLineQuests[lineID] = ids or { 78562, 78563, 78564 }
end
local function pendingFixture()
    Mock.titles[questID] = nil
    Mock.questMapIDs[questID] = mapID
    selector()
    ns.LookupQuest(questID)
    assert(ns.questLookup and ns.questLookup.status == "LOADING")
    assert(ns.chain.id == "none")
    assert(Mock.lineRequests[mapID] == 1 and Mock.requests[questID] == 1)
end
local function finishFixture()
    reverseFixture(questID)
    Mock.titles[questID] = "Completed title reply test fixture"
    event("QUESTLINE_UPDATE", false)
    event("QUEST_DATA_LOAD_RESULT", questID, true)
end

test("tracked button selects only API-provided exact membership", function()
    reverseFixture(questID)
    Mock.isSuperTrackingQuest, Mock.superTrackedQuestID = true, questID
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.Quest
    click(selector().trackedButton)
    Mock.Flush()
    assert(ns.chain.id == liveKey and ns.db.selectedChain == liveKey)
    assert(ns.UI.frame:IsShown() and not ns.UI.selector:IsShown())
    assert(#Mock.reverseCalls > 0)
end)

test("ID button and Enter select runtime membership without title matching", function()
    reverseFixture(questID)
    input(" 78562 ", false)
    Mock.Flush()
    assert(ns.chain.id == liveKey and ns.result.byID[78563] and ns.result.byID[78564])
    assert(ns.db.liveSelection.mapID == mapID and ns.db.liveSelection.questLineID == lineID)
    local calls = #Mock.reverseCalls
    input("78563", true)
    Mock.Flush()
    assert(ns.chain.id == liveKey and #Mock.reverseCalls == calls)
end)

test("known legacy IDs have no embedded membership fallback", function()
    Mock.titles[78743] = "Lookup title test fixture"
    ns.LookupQuest(78743)
    assert(ns.questLookup.status == "NO_MAP" and ns.chain.id == "none")
    assert(ns.WoW.GetQuestLine("mourning-rise") == nil)
end)

test("stale quest tracking is rejected for a waypoint or inactive quest mode", function()
    local panel = selector()
    Mock.superTrackedQuestID, Mock.isSuperTrackingQuest = 78743, false
    local reads = Mock.trackedReads
    click(panel.trackedButton)
    assert(ns.questLookup.status == "NO_TRACKED" and Mock.trackedReads == reads)
    assert(panel.lookupStatus:GetText() == ns.L.LOOKUP_NO_TRACKED)
    Mock.isSuperTrackingQuest = true
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.UserWaypoint
    click(panel.trackedButton)
    assert(ns.questLookup.status == "NO_TRACKED" and Mock.trackedReads == reads)
    Mock.highestPrioritySuperTrackingType = nil
    click(panel.trackedButton)
    assert(ns.questLookup.status == "NO_TRACKED" and Mock.trackedReads == reads,
        "A nullable priority result supplies no current quest navigation target")
    assert(ns.chain.id == "none")
end)

test("all invalid programmatic IDs are rejected before game API arguments", function()
    local values = { 0, -101, 1.5, "78743", false, {}, math.huge, -math.huge, 0 / 0 }
    for _, value in ipairs(values) do
        local calls = Mock.calls
        local chain, status = ns.WoW.FindQuestLine(value)
        assert(chain == nil and status == "INVALID_ID")
        ns.LookupQuest(value)
        assert(ns.questLookup.status == "INVALID_ID" and Mock.calls == calls)
    end
    local calls = Mock.calls
    ns.LookupQuest(nil)
    assert(ns.questLookup.status == "INVALID_ID" and Mock.calls == calls)
    assert(#Mock.reverseCalls == 0 and #Mock.questMapCalls == 0)
end)

test("ID input accepts decimal digits only", function()
    for _, text in ipairs({ "", "0", "-101", "78743.0", "1e5", "0x13397", "NaN", "inf", "quest 78743" }) do
        local panel = selector()
        panel.questIDInput:SetText(text)
        local calls = Mock.calls
        click(panel.lookupButton)
        assert(ns.questLookup.status == "INVALID_ID" and Mock.calls == calls)
        assert(panel.lookupStatus:GetText() == ns.L.LOOKUP_INVALID)
    end
end)

test("invalid IDs returned by supertracking never reach quest APIs", function()
    Mock.isSuperTrackingQuest = true
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.Quest
    for _, value in ipairs({ 0, -101, 1.5, "78743", math.huge, 0 / 0 }) do
        Mock.superTrackedQuestID = value
        ns.UseTrackedQuest()
        assert(ns.questLookup.status == "NO_TRACKED")
    end
    assert(#Mock.reverseCalls == 0 and #Mock.questMapCalls == 0)
end)

test("reverse lookup keeps provenance and unknown prerequisite/optionality facts", function()
    reverseFixture(questID, { 78562, 78563, 78562, 78564 })
    local chain, status = ns.WoW.FindQuestLine(questID)
    assert(status == "READY" and chain.id == liveKey and chain.runtime)
    assert(chain.source == ns.LiveData.source and chain.sourceAPI == "C_QuestLine.GetQuestLineInfo")
    assert(chain.suggestedQuestID == nil and #ns.Model.Flatten(chain) == 3)
    for _, quest in ipairs(ns.Model.Flatten(chain)) do
        assert(quest.source == ns.LiveData.source and quest.sourceAPI == "C_QuestLine.GetQuestLineQuests")
        assert(quest.prerequisites == nil and quest.requirementsKnown == false)
        assert(quest.optional == nil and quest.optionalityKnown == false)
    end
    local reply = Mock.reverseCalls[1]
    assert(reply.questID == questID and reply.displayableOnly == false)
    ns.LookupQuest(questID)
    assert(ns.chain.id == liveKey and ns.db.liveSelection.mapID == mapID)
    assert(ns.db.liveSelection.questLineID == lineID)
    for _, row in pairs(ns.result.byID) do
        assert(row.status == "UNKNOWN" and not row.inferredNext)
    end
    assert(#ns.result.next == 0 and ns.db.progress == nil and ns.db.titles == nil)
end)

test("a reverse association is accepted only when its membership contains the input", function()
    reverseFixture(questID, { 78563, 78564 })
    local oldID = ns.chain.id
    ns.LookupQuest(questID)
    assert(ns.chain.id == oldID and ns.db.selectedChain == oldID)
    assert(ns.questLookup.status == "NOT_FOUND" and ns.WoW.GetQuestLine(liveKey) == nil)
end)

test("map-specific reverse fallback uses a sourced positive request context", function()
    Mock.questMapIDs[questID] = mapID
    Mock.questLineInfoByMap[mapID] = { [questID] = { questLineID = lineID,
        questLineName = "Map-specific reverse test fixture", questID = questID } }
    Mock.questLineQuests[lineID] = { 78562, 78563, 78564 }
    local chain, status = ns.WoW.FindQuestLine(questID)
    assert(status == "READY" and chain.id == liveKey)
    assert(#Mock.reverseCalls == 2 and Mock.reverseCalls[1].mapID == nil)
    assert(Mock.reverseCalls[2].mapID == mapID and Mock.reverseCalls[2].displayableOnly == false)
end)

test("missing map context and unsupported reverse APIs preserve the current story", function()
    reverseFixture(questID)
    Mock.questLineInfoByQuest[questID].startMapID = nil
    ns.LookupQuest(questID)
    assert(ns.questLookup.status == "NO_MAP" and ns.chain.id == "none")
    C_QuestLine.GetQuestLineInfo = nil
    ns.LookupQuest(questID)
    assert(ns.questLookup.status == "UNSUPPORTED" and ns.chain.id == "none")
    C_SuperTrack.IsSuperTrackingQuest = nil
    ns.UseTrackedQuest()
    assert(ns.questLookup.status == "UNSUPPORTED")
    ns.LookupQuest(78743)
    assert(ns.questLookup.status == "UNSUPPORTED" and ns.chain.id == "none")
end)

test("asynchronous map/title events coalesce and resolve filtered reverse membership", function()
    pendingFixture()
    for index = 1, 8 do
        event("QUEST_LOG_UPDATE")
        event("QUESTLINE_UPDATE", false)
    end
    assert(#Mock.timers == 1)
    finishFixture()
    assert(#Mock.timers == 1)
    Mock.Flush()
    assert(ns.chain.id == liveKey and ns.result.total == 3)
    assert(Mock.lineRequests[mapID] == 1 and Mock.requests[questID] == 1 and #Mock.timers == 0)
    assert(not ns.UI.selector:IsShown())
end)

test("unassociated completed replies leave selection intact and perform no idle retry", function()
    pendingFixture()
    event("QUESTLINE_UPDATE", false)
    event("QUEST_DATA_LOAD_RESULT", questID, true)
    Mock.Flush()
    assert(ns.questLookup.status == "NOT_FOUND" and ns.chain.id == "none")
    assert(ns.UI.selector.lookupStatus:GetText() == string.format(ns.L.LOOKUP_NOT_FOUND, questID))
    assert(#Mock.timers == 0 and Mock.lineRequests[mapID] == 1 and Mock.requests[questID] == 1)
    for index = 1, 4 do ns.Refresh() end
    assert(Mock.lineRequests[mapID] == 1 and Mock.requests[questID] == 1 and #Mock.timers == 0)
end)

test("synchronous map/title completion rechecks the reverse association", function()
    Mock.titles[questID] = nil
    Mock.questMapIDs[questID] = mapID
    selector()
    Mock.onLineRequest = function(id)
        assert(id == mapID)
        reverseFixture(questID)
        event("QUESTLINE_UPDATE", false)
        event("QUEST_DATA_LOAD_RESULT", questID, true)
    end
    ns.LookupQuest(questID)
    Mock.Flush()
    assert(ns.chain.id == liveKey, "A synchronous reply must not become a terminal false NOT_FOUND")
    assert(Mock.lineRequests[mapID] == 1 and #Mock.timers == 0)
end)

test("synchronous title completion rechecks a filtered reverse association", function()
    Mock.titles[questID] = nil
    Mock.questMapIDs[questID] = mapID
    selector()
    local request = C_QuestLog.RequestLoadQuestByID
    C_QuestLog.RequestLoadQuestByID = function(id)
        request(id)
        reverseFixture(id)
        event("QUESTLINE_UPDATE", false)
        event("QUEST_DATA_LOAD_RESULT", id, true)
    end
    ns.LookupQuest(questID)
    Mock.Flush()
    assert(ns.chain.id == liveKey and Mock.requests[questID] == 1)
    assert(Mock.lineRequests[mapID] == 1 and #Mock.timers == 0)
end)

test("failed title results retry only on an explicit new submission", function()
    pendingFixture()
    event("QUESTLINE_UPDATE", false)
    event("QUEST_DATA_LOAD_RESULT", questID, false)
    Mock.Flush()
    assert(ns.questLookup.status == "ERROR" and ns.chain.id == "none")
    for index = 1, 4 do ns.Refresh(); event("QUEST_LOG_UPDATE") end
    Mock.Flush()
    assert(Mock.requests[questID] == 1 and #Mock.timers == 0)
    local unrelatedRequests = Mock.requests[78743]
    ns.LookupQuest(questID)
    assert(Mock.requests[questID] == 2 and Mock.requests[78743] == unrelatedRequests)
    finishFixture(); Mock.Flush()
    assert(ns.chain.id == liveKey)
end)

test("editing the input cancels a late successful lookup", function()
    pendingFixture()
    local panel = ns.UI.selector
    panel.questIDInput:SetText("79542")
    panel.questIDInput.scripts.OnTextChanged(panel.questIDInput, true)
    assert(ns.questLookup == nil and ns.WoW.questLookup == nil)
    finishFixture(); Mock.Flush()
    assert(ns.chain.id == "none" and panel:IsShown())
    assert(panel.lookupStatus:GetText() == ns.L.LOOKUP_HINT)
end)

test("manual selection and selector close cancel late responses", function()
    pendingFixture()
    local other = assert(ns.LiveData.Build(mapID, { questLineID = 5507, questLineName = "Manual choice fixture" }, { 78743, 78744 }))
    ns.WoW.RegisterQuestLine(other)
    ns.Select(other.id)
    assert(ns.questLookup == nil and ns.WoW.questLookup == nil)
    finishFixture(); Mock.Flush()
    assert(ns.chain.id == ns.LiveData.Key(mapID, 5507))
    reset(); pendingFixture()
    ns.UI.selector:Hide()
    assert(ns.questLookup == nil and ns.WoW.questLookup == nil)
    finishFixture(); Mock.Flush()
    assert(ns.chain.id == "none" and not ns.UI.selector:IsShown())
end)

test("superseding input survives late and reordered unlabelled map replies", function()
    pendingFixture()
    local firstQuestID = questID
    local secondQuestID = 78563
    local otherMapID = 2214 -- A distinct simulated request context, not a location fact.
    Mock.mapInfos[otherMapID] = { name = "Second lookup map test fixture" }
    Mock.questLinesByMap[otherMapID] = {}
    Mock.titles[secondQuestID] = nil
    Mock.questMapIDs[secondQuestID] = otherMapID
    ns.WoW.OnQuestLookupDataLoadResult(secondQuestID, false)
    ns.LookupQuest(secondQuestID)
    assert(ns.questLookup.questID == secondQuestID and ns.questLookup.status == "LOADING")
    event("QUEST_DATA_LOAD_RESULT", secondQuestID, true)
    event("QUESTLINE_UPDATE", false) -- A late map reply carries no request identity.
    event("QUEST_DATA_LOAD_RESULT", firstQuestID, true)
    Mock.Flush()
    assert(ns.chain.id == "none")
    reverseFixture(secondQuestID, nil, otherMapID)
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    assert(ns.chain.id == ns.LiveData.Key(otherMapID, lineID),
        "A later matching reply must resolve the current input and map context")
    assert(Mock.lineRequests[mapID] == 1 and Mock.lineRequests[otherMapID] == 1)
    assert(#Mock.timers == 0 and Mock.requests[secondQuestID] == 1)
end)

test("reverse and request failures are readable and preserve the previous selection", function()
    Mock.failReverseLineRead = true
    ns.LookupQuest(questID)
    assert(ns.questLookup.status == "ERROR" and ns.chain.id == "none")
    Mock.failReverseLineRead = nil
    reverseFixture(questID)
    Mock.failLineQuests = true
    ns.LookupQuest(questID)
    assert(ns.questLookup.status == "ERROR" and ns.chain.id == "none")
    Mock.failLineQuests, Mock.questLineInfoByQuest[questID] = nil, nil
    Mock.questMapIDs[questID], Mock.failLineRequest = mapID, true
    ns.LookupQuest(questID)
    assert(ns.questLookup.status == "ERROR" and ns.chain.id == "none")
    for _, failure in ipairs({ "failTrackingKindRead", "failPriorityRead", "failTrackedRead" }) do
        Mock.failLineRequest = nil
        Mock.isSuperTrackingQuest, Mock.superTrackedQuestID = true, 78743
        Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.Quest
        Mock[failure] = true
        ns.UseTrackedQuest()
        assert(ns.questLookup.status == "ERROR")
        Mock[failure] = nil
    end
end)

test("thrown title requests and malformed line metadata are contained", function()
    Mock.titles[questID] = nil
    C_QuestLog.RequestLoadQuestByID = function() error("Title request test fixture failure") end
    ns.LookupQuest(questID)
    assert(ns.questLookup.status == "ERROR" and ns.chain.id == "none")
    Mock.Flush()
    assert(ns.WoW.failedRequests[questID] and #Mock.timers == 0)
    local reads, mapReads = Mock.calls, #Mock.questMapCalls
    Mock.questLineInfoByQuest[questID] = { questLineID = -101, startMapID = mapID }
    ns.LookupQuest(questID)
    assert(ns.questLookup.status == "ERROR" and ns.chain.id == "none")
    assert(Mock.calls > reads and #Mock.questMapCalls == mapReads)
    -- The strict GetQuestLineQuests stub would fail if that synthetic ID leaked.
    assert(ns.WoW.GetQuestLine(liveKey) == nil)
end)

if ns.UI.selector then ns.UI.selector:Hide() end
ns.CancelQuestLookup()
Mock = saved.mock
C_QuestLine, C_QuestLog, C_SuperTrack, C_Map = saved.questLineAPI, saved.questLogAPI, saved.superTrackAPI, saved.mapAPI
GetQuestUiMapID, Enum = saved.questMapAPI, saved.enum
ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID = saved.maps, saved.currentMapID
ns.WoW.requested, ns.WoW.failedRequests, ns.WoW.offers = saved.requested, saved.failedRequests, saved.offers
ns.WoW.ResetWarnings()
ns.chain, ns.db, ns.pending = saved.chain, saved.db, false
QuestStrangTrackerDB = ns.db
ns.Refresh()
print("Quest lookup behavioral tests passed: " .. passed)
