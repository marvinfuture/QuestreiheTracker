-- API replies below are test fixtures, not claims about map/story membership.
-- Fixture IDs: https://www.wowhead.com/quest=78743, /quest=78744 and /quest=78745.
local ns, passed = TEST_NS, 0
local mapID, otherMapID, lineID = 2248, 2214, 5506
local liveKey = "blizzard:" .. mapID .. ":" .. lineID
local info = { questLineID = lineID, questLineName = "Quest-line test fixture", questID = 78744 }
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Runtime quest lines / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end
local function event(name, ...)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, name, ...)
end
local function zone()
    return ns.WoW.ZoneQuestLines()
end
local function clearFailures()
    Mock.failMapRead, Mock.failMapInfo, Mock.failLineRequest = nil, nil, nil
    Mock.failLineRead, Mock.failLineQuests = nil, nil
end
local function questRow(id)
    for _, row in pairs(ns.UI.rows or {}) do
        if row:IsShown() and rawget(row, "questID") == id and row.subtext:GetText() ~= "" then return row end
    end
    error("Missing runtime quest row: " .. tostring(id))
end

test("positive finite integral IDs only", function()
    assert(ns.LiveData.IsID(78743) and ns.LiveData.IsID(mapID))
    for _, value in ipairs({ 0, -101, 1.5, "78743", false, math.huge, -math.huge, 0 / 0 }) do
        assert(not ns.LiveData.IsID(value))
    end
    assert(not ns.LiveData.IsID(nil) and not ns.LiveData.IsID({}))
    assert(ns.LiveData.Key(mapID, lineID) == liveKey)
end)

test("conversion preserves membership without inventing prerequisites", function()
    local chain = assert(ns.LiveData.Build(mapID, info, { 78743, 78744, 78743, 78745 }))
    assert(chain.id == liveKey and chain.runtime and not chain.demo)
    assert(chain.suggestedQuestID == info.questID)
    local quests = ns.Model.Flatten(chain)
    assert(#quests == 3 and quests[1].questID == 78743 and quests[2].questID == 78744)
    for _, quest in ipairs(quests) do
        assert(quest.prerequisites == nil and quest.requirementsKnown == false)
        assert(quest.optional == nil and quest.optionalityKnown == false)
        local source = quest.sourceURL or quest.source
        assert(type(source) == "string" and source ~= "")
    end
    assert(#ns.Model.Validate(chain) == 0)
    local result = ns.Model.Evaluate(chain, { completed = { [78743] = true, [78744] = false, [78745] = false } })
    assert(result.completed == 1 and result.total == 3)
    assert(result.byID[78744].status == "UNKNOWN" and not result.byID[78744].inferredNext)
    assert(#result.next == 0)
end)

test("invalid lists are rejected before any API can see IDs", function()
    local before = Mock.calls
    assert(ns.LiveData.Build(mapID, info, {}) == nil)
    assert(ns.LiveData.Build(mapID, info, nil) == nil)
    for _, bad in ipairs({ -101, 0, 1.5, "78744", false, math.huge, 0 / 0 }) do
        assert(ns.LiveData.Build(mapID, info, { 78743, bad, 78745 }) == nil)
    end
    assert(ns.LiveData.Build(-mapID, info, { 78743 }) == nil)
    assert(ns.LiveData.Build(mapID, { questLineID = -lineID }, { 78743 }) == nil)
    assert(ns.LiveData.Build(mapID, info, { [1] = 78743, [3] = -101 }) == nil)
    assert(ns.LiveData.Build(mapID, info, { [1] = 78743, extra = 78744 }) == nil)
    assert(Mock.calls == before)
end)

test("loading selections have stable identifiers and no fake quest IDs", function()
    local pending = assert(ns.LiveData.Pending(mapID, lineID))
    assert(pending.runtime and pending.id == liveKey)
    assert(#ns.Model.Flatten(pending) == 0)
    assert(ns.LiveData.Pending(-mapID, lineID) == nil)
end)

test("new events are registered and no map has a clear state", function()
    assert(ns.eventFrame.events.QUESTLINE_UPDATE)
    assert(ns.eventFrame.events.ZONE_CHANGED_NEW_AREA)
    assert(ns.eventFrame.events.PLAYER_ENTERING_WORLD)
    Mock.currentMapID = nil
    ns.DiscoverZone(false); Mock.Flush()
    local chains, status = zone()
    assert(#chains == 0 and status == "NO_MAP")
    Mock.currentMapID = -101
    ns.DiscoverZone(false); Mock.Flush()
    chains, status = zone()
    assert(#chains == 0 and status == "NO_MAP" and Mock.lineRequests[-101] == nil)
end)

test("map discovery is asynchronous and requests are coalesced", function()
    Mock.currentMapID = mapID
    Mock.mapInfos[mapID] = { name = "Map test fixture" }
    Mock.questLinesByMap[mapID] = {}
    local before = Mock.lineRequests[mapID] or 0
    ns.DiscoverZone(false)
    for index = 1, 8 do ns.DiscoverZone(false) end
    assert((Mock.lineRequests[mapID] or 0) == before + 1)
    assert(#Mock.timers == 1)
    Mock.Flush()
    local chains, status, name = zone()
    assert(#chains == 0 and status == "LOADING" and name == "Map test fixture")
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    chains, status = zone()
    assert(#chains == 0 and status == "EMPTY")
    assert(Mock.lineRequests[mapID] == before + 1)
end)

test("later map replies and later quest membership replace loading state", function()
    Mock.questLinesByMap[mapID] = { info, info }
    Mock.questLineQuests[lineID] = nil
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    local chains, status = zone()
    assert(status == "LOADING")
    Mock.questLineQuests[lineID] = { 78743, 78744, 78745, 78743 }
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    chains, status = zone()
    assert(status == "READY" and #chains == 1 and chains[1].id == liveKey)
    assert(#ns.Model.Flatten(chains[1]) == 3)
    assert(ns.WoW.GetQuestLine(liveKey).id == liveKey)
end)

test("runtime selection saves identifiers and derives progress from the game", function()
    Mock.completed[78743], Mock.active[78744] = true, true
    Mock.completed[78744], Mock.completed[78745], Mock.active[78745] = false, false, false
    Mock.titles[78743], Mock.titles[78744], Mock.titles[78745] = nil, nil, nil
    Mock.requests, ns.WoW.requested = {}, {}
    ns.Select(liveKey)
    assert(ns.chain.id == liveKey and ns.db.selectedChain == liveKey)
    assert(ns.db.liveSelection.mapID == mapID and ns.db.liveSelection.questLineID == lineID)
    local count = 0
    for key in pairs(ns.db.liveSelection) do assert(key == "mapID" or key == "questLineID"); count = count + 1 end
    assert(count == 2 and ns.db.questLines == nil and ns.db.progress == nil and ns.db.titles == nil)
    assert(ns.result.total == 3 and ns.result.completed == 1)
    assert(ns.result.byID[78743].status == "COMPLETED" and ns.result.byID[78744].status == "ACTIVE")
    assert(ns.result.byID[78745].status == "UNKNOWN" and not ns.result.byID[78745].inferredNext)
    for _, id in ipairs({ 78743, 78744, 78745 }) do assert(Mock.requests[id] == 1) end
    ns.Refresh(); ns.Refresh()
    for _, id in ipairs({ 78743, 78744, 78745 }) do assert(Mock.requests[id] == 1) end
end)

test("title and progress updates refresh through the existing event timer", function()
    Mock.titles[78745] = "Late localized title fixture"
    Mock.completed[78745] = true
    event("QUEST_DATA_LOAD_RESULT", 78745, true)
    event("QUEST_LOG_UPDATE")
    event("QUESTLINE_UPDATE", false)
    assert(#Mock.timers == 1)
    Mock.Flush()
    assert(ns.result.completed == 2 and ns.result.byID[78745].status == "COMPLETED")
    assert(ns.WoW.Title(ns.result.byID[78745].quest) == Mock.titles[78745])
    assert(questRow(78745).subtext:GetText():find(ns.L.COMPLETED, 1, true))
end)

test("failed title loads wait for explicit refresh and recover once", function()
    Mock.titles[78744] = nil
    local before = Mock.requests[78744]
    for index = 1, 8 do event("QUEST_DATA_LOAD_RESULT", 78744, false) end
    assert(#Mock.timers == 1)
    Mock.Flush()
    assert(ns.WoW.failedRequests[78744] and Mock.requests[78744] == before)
    ns.Refresh(); event("QUEST_LOG_UPDATE"); Mock.Flush()
    assert(Mock.requests[78744] == before)
    ns.WoW.OnQuestDataLoadResult(-101, false)
    ns.WoW.OnQuestDataLoadResult(78746, false)
    assert(ns.WoW.failedRequests[-101] == nil and ns.WoW.failedRequests[78746] == nil)
    ns.DiscoverZone(true); Mock.Flush()
    assert(Mock.requests[78744] == before + 1 and ns.WoW.failedRequests[78744] == nil)
    Mock.titles[78744] = "Recovered localized title fixture"
    event("QUEST_DATA_LOAD_RESULT", 78744, true); Mock.Flush()
    assert(ns.WoW.Title(ns.result.byID[78744].quest) == Mock.titles[78744])
    ns.Refresh(); ns.DiscoverZone(true); Mock.Flush()
    assert(Mock.requests[78744] == before + 1)
end)

test("map candidates never create NPC availability", function()
    Mock.completed[78744], Mock.active[78744] = false, false
    ns.WoW.ClearOffers(); ns.Refresh()
    assert(ns.result.byID[78744].status == "UNKNOWN" and ns.result.byID[78744].inferredNext)
    assert(questRow(78744).subtext:GetText():find(ns.L.INFERRED, 1, true))
    Mock.offers = { { questID = 78744 } }
    event("GOSSIP_SHOW"); Mock.Flush()
    assert(ns.result.byID[78744].status == "AVAILABLE")
    event("GOSSIP_CLOSED"); Mock.Flush()
    assert(ns.result.byID[78744].status == "UNKNOWN")
    assert(Mock.acceptCount == 0 and Mock.setAbandonCount == 0 and Mock.abandonCount == 0)
end)

test("requestRequired is a boolean refresh signal rather than a map ID", function()
    local before = Mock.lineRequests[mapID]
    for index = 1, 12 do event("QUESTLINE_UPDATE", true) end
    assert(#Mock.timers == 1)
    Mock.Flush()
    assert(Mock.lineRequests[mapID] == before + 1)
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    local _, status = zone()
    assert(status == "READY" and ns.chain.id == liveKey)
end)

test("city maps normalize to the parent zone without scanning continents", function()
    local previousEnum = Enum
    Enum = { UIMapType = { Zone = 3, Micro = 5, Continent = 2 } }
    -- The parent relationship is a fixture; it makes no production-data claim.
    Mock.mapInfos[otherMapID] = { name = "City map fixture", mapType = Enum.UIMapType.Micro, parentMapID = mapID }
    Mock.mapInfos[mapID] = { name = "Map test fixture", mapType = Enum.UIMapType.Zone }
    Mock.currentMapID = otherMapID
    ns.DiscoverZone(false); Mock.Flush()
    assert(ns.WoW.questLines.currentMapID == mapID)
    assert(Mock.lineRequests[otherMapID] == nil)
    Enum = previousEnum
end)

test("zone changes and disappearing offers retain the selected story", function()
    Mock.currentMapID = otherMapID
    Mock.mapInfos[otherMapID] = { name = "Other map test fixture" }
    Mock.questLinesByMap[otherMapID] = {}
    event("ZONE_CHANGED_NEW_AREA"); Mock.Flush()
    assert(Mock.lineRequests[otherMapID] == 1 and ns.chain.id == liveKey)
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    local _, status = zone()
    assert(status == "EMPTY" and ns.chain.id == liveKey)
    Mock.questLinesByMap[mapID] = {}
    event("QUESTLINE_UPDATE", true); Mock.Flush()
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    assert(ns.chain.id == liveKey and ns.result.total == 3)
    assert(ns.db.liveSelection.mapID == mapID)
    Mock.currentMapID = mapID
    Mock.questLinesByMap[mapID] = { info }
    event("PLAYER_ENTERING_WORLD", false, false); Mock.Flush()
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    assert(ns.chain.id == liveKey)
end)

test("saved live preferences are validated without persisting API payloads", function()
    local saved = { selectedChain = liveKey, liveSelection = { mapID = mapID, questLineID = lineID,
        name = "Ignored fixture name", quests = { 78743 }, completed = true }, questLines = { info } }
    local config = ns.ReadConfig(saved)
    assert(config.selectedChain == liveKey and config.liveSelection.mapID == mapID)
    assert(config.liveSelection.questLineID == lineID and config.liveSelection.name == nil)
    assert(config.liveSelection.quests == nil and config.liveSelection.completed == nil and config.questLines == nil)
    for _, bad in ipairs({ -mapID, 0, 1.5, "2248", math.huge }) do
        config = ns.ReadConfig({ selectedChain = liveKey, liveSelection = { mapID = bad, questLineID = lineID } })
        assert(config.liveSelection == nil and config.selectedChain == "none")
    end
    config = ns.ReadConfig({ selectedChain = liveKey, liveSelection = { mapID = mapID, questLineID = -lineID } })
    assert(config.liveSelection == nil and config.selectedChain == "none")
    config = ns.ReadConfig({ selectedChain = "blizzard:wrong", liveSelection = { mapID = mapID, questLineID = lineID } })
    assert(config.selectedChain == "none" and config.liveSelection == nil)
    config = ns.ReadConfig({ selectedChain = "mourning-rise", liveSelection = { mapID = mapID, questLineID = lineID } })
    assert(config.selectedChain == "none" and config.liveSelection == nil)
end)

test("restoring a saved story can wait on map data", function()
    -- Clear only the runtime map cache to simulate a fresh session's API cache.
    ns.WoW.questLines.maps = {}
    Mock.questLinesByMap[mapID], Mock.questLineQuests[lineID] = nil, nil
    local chain = assert(ns.WoW.RestoreQuestLine({ mapID = mapID, questLineID = lineID }))
    assert(chain.runtime and chain.id == liveKey and #ns.Model.Flatten(chain) == 0)
    ns.chain = chain
    Mock.questLinesByMap[mapID], Mock.questLineQuests[lineID] = { info }, { 78743, 78744, 78745 }
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    assert(ns.chain.id == liveKey and ns.result.total == 3)
end)

test("missing APIs and API errors have readable states", function()
    local api = C_QuestLine
    C_QuestLine = nil
    ns.DiscoverZone(true); Mock.Flush()
    local _, status = zone()
    assert(status == "UNSUPPORTED")
    C_QuestLine = api
    Mock.failLineRequest = true
    ns.DiscoverZone(true); Mock.Flush()
    _, status = zone()
    assert(status == "ERROR")
    clearFailures()
    ns.DiscoverZone(true); Mock.Flush()
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    Mock.failLineRead = true
    ns.WoW.ReadQuestLines(); ns.Refresh()
    _, status = zone()
    assert(status == "ERROR")
    clearFailures()
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    _, status = zone()
    assert(status == "READY")
    assert(ns.chain.id == liveKey and ns.result.total == 3)
end)

test("zone slash command and repeated events remain display-only without idle polling", function()
    local before = Mock.lineRequests[mapID]
    ns.Slash("zone"); Mock.Flush()
    assert(ns.UI.frame:IsShown() and ns.UI.selector:IsShown())
    assert(Mock.lineRequests[mapID] == before + 1)
    event("QUESTLINE_UPDATE", false); Mock.Flush()
    ns.Slash("reset")
    ns.Refresh()
    event("ZONE_CHANGED_NEW_AREA")
    event("PLAYER_ENTERING_WORLD", false, false)
    event("QUESTLINE_UPDATE", true)
    Mock.Flush()
    assert(ns.chain.id == "none" and ns.ToggleDemo == nil and ns.DemoData == nil)
    for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
    assert(#Mock.timers == 0)
    assert(Mock.acceptCount == 0 and Mock.setAbandonCount == 0 and Mock.abandonCount == 0)
    ns.Select(liveKey)
    Mock.Flush()
    assert(ns.chain.id == liveKey)
end)

print("Runtime quest-line tests passed: " .. passed)
