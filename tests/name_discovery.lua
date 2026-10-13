-- Map/line IDs, names and relationships below are simulated runtime replies, not gameplay facts.
-- Existing quest-ID fixtures: https://www.wowhead.com/quest=78743 and /quest=78744.
local ns, WoW, passed = TEST_NS, TEST_NS.WoW, 0
Mock.Flush()
local saved = { mock = Mock, mapAPI = C_Map, lineAPI = C_QuestLine, logAPI = C_QuestLog,
    enum = Enum, time = GetTime, questMapAPI = GetQuestUiMapID, maps = WoW.questLines.maps,
    currentMapID = WoW.questLines.currentMapID, discovery = WoW.nameDiscovery,
    lookup = WoW.questLookup, requested = WoW.requested, failed = WoW.failedRequests, chain = ns.chain }
local rootMap, otherMap, lineID = 120000, 120002, 130001
local children, treeCalls

local function copy(value)
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    return result
end

local function reset()
    WoW.ResetNameDiscovery()
    WoW.ResetQuestLookup()
    Mock = copy(saved.mock)
    for _, key in ipairs({ "timers", "active", "titles", "requests", "log", "mapInfos", "questLinesByMap",
        "questLineQuests", "lineRequests", "questMapIDs", "questMapCalls", "questLineInfoByQuest",
        "questLineInfoByMap", "reverseCalls", "questsOnMap" }) do Mock[key] = {} end
    for _, key in ipairs({ "currentMapID", "onLineRequest", "failMapInfo", "failLineRead", "failLineRequest",
        "failLineQuests", "failReverseLineRead", "failQuestMapRead" }) do Mock[key] = nil end
    Mock.now, Mock.lineReads = 0, 0
    C_Map, C_QuestLine, C_QuestLog = copy(saved.mapAPI), copy(saved.lineAPI), copy(saved.logAPI)
    Enum = { UIMapType = { World = 0, Continent = 2, Zone = 3 }, SuperTrackingType = { Quest = 0 } }
    GetTime, GetQuestUiMapID = saved.time, saved.questMapAPI
    WoW.questLines.maps, WoW.questLines.currentMapID = {}, nil
    WoW.requested, WoW.failedRequests = {}, {}
    ns.chain = ns.LiveData.Empty()
    children, treeCalls = { { mapID = otherMap, mapType = 3 } }, 0
    Mock.mapInfos[rootMap] = { name = "Runtime root fixture", mapType = 0, parentMapID = 0 }
    Mock.mapInfos[otherMap] = { name = "Other zone fixture", mapType = 3, parentMapID = rootMap }
    Mock.questLinesByMap[otherMap] = { { questLineID = lineID, questLineName = "Trauerh\195\182he" } }
    Mock.questLineQuests[lineID] = { 78743, 78744 }
    C_Map.GetFallbackWorldMapID = function() return rootMap end
    C_Map.GetMapChildrenInfo = function(mapID, kind, recursive)
        assert(mapID == rootMap and kind == Enum.UIMapType.Zone and recursive == true)
        treeCalls = treeCalls + 1
        return children
    end
    WoW.OnNameSearchAchievementUpdate(true)
end

local function finish(query)
    for _ = 1, 300 do
        local status = WoW.AdvanceNameDiscovery(query)
        if status ~= "LOADING" then return status end
        Mock.now = Mock.now + 0.1
    end
    error("Runtime discovery did not terminate")
end

local function chain()
    return WoW.GetQuestLine(ns.LiveData.Key(otherMap, lineID))
end

local function lineHit(query)
    local results = WoW.SearchQuestLinesByName(query)
    for _, result in ipairs(results) do if result.kind == "QUEST_LINE" then return result end end
end

local function requestCount()
    local count = 0
    for _, value in pairs(Mock.lineRequests) do count = count + value end
    return count
end

local function test(name, fn)
    reset()
    local ok, message = pcall(fn)
    assert(ok, "Name discovery / " .. name .. ": " .. tostring(message))
    assert(Mock.mutationCount == saved.mock.mutationCount and Mock.invalidIDCalls == saved.mock.invalidIDCalls)
    assert(#Mock.timers == 0, "Discovery itself must use Core's existing timer")
    WoW.ResetNameDiscovery()
    WoW.ResetQuestLookup()
    passed = passed + 1
end

test("fresh cross-zone line names yield the complete same chain as later-member ID lookup", function()
    assert(chain() == nil and finish("trauerh\195\182he") == "READY")
    local named = assert(chain())
    local quests = ns.Model.Flatten(named)
    assert(named.name == "Trauerh\195\182he" and named.nameKnown and #quests == 2)
    assert(quests[1].questID == 78743 and quests[2].questID == 78744)
    local hit = assert(lineHit("Trauerh\195\182he"))
    assert(hit.selectable and hit.chain.id == named.id)
    WoW.questLines.maps = {}
    Mock.questLineInfoByQuest[78744] = { questLineID = lineID, questLineName = named.name, startMapID = otherMap }
    local byID, status = WoW.FindQuestLine(78744)
    local members = ns.Model.Flatten(assert(byID))
    assert(status == "READY" and byID.id == named.id and #members == #quests)
    for entry, quest in ipairs(quests) do assert(members[entry].questID == quest.questID) end
end)

test("current and known maps precede deduplicated sorted tree maps", function()
    local current, known = 120010, 120009
    WoW.questLines.currentMapID = current
    Mock.mapInfos[current], Mock.mapInfos[known] = { name = "Current fixture" }, { name = "Known fixture" }
    Mock.questLinesByMap[current], Mock.questLinesByMap[known] = {}, {}
    WoW.questLines.maps[known] = { mapID = known, name = "Known fixture", byID = {}, chains = {}, loaded = true, requested = true }
    children = { { mapID = otherMap }, { mapID = current }, { mapID = otherMap } }
    WoW.AdvanceNameDiscovery("fixture")
    local queue = WoW.nameDiscovery.mapQueue
    assert(#queue == 3 and queue[1] == current and queue[2] == known and queue[3] == otherMap)
    assert(Mock.lineRequests[otherMap] == 1 and Mock.lineRequests[known] == nil)
end)

test("accepted other-zone member recovers a line missing from available map pins", function()
    Mock.questLinesByMap[otherMap] = {}
    Mock.log = { { questID = 78743 }, { questID = 78744 } }
    Mock.active[78743], Mock.active[78744] = true, true
    Mock.questLineInfoByQuest[78743] = { questLineID = lineID, questLineName = "Trauerh\195\182he", startMapID = otherMap }
    assert(finish("trauerh\195\182he") == "PARTIAL")
    local named = assert(chain())
    assert(#ns.Model.Flatten(named) == 2 and named.sourceAPI == "C_QuestLine.GetQuestLineInfo")
    assert(named.nameSourceAPI == "C_QuestLine.GetQuestLineInfo" and Mock.lineRequests[otherMap] == 1)
    assert(lineHit("Trauerh\195\182he").selectable)
end)

test("individual quest title cannot become a quest-line name alias", function()
    Mock.questLinesByMap[otherMap][1].questLineName = "Other chain fixture"
    Mock.titles[78743] = "Zur Trauerh\195\182he"
    assert(finish("trauerh\195\182he") == "READY" and lineHit("Trauerh\195\182he") == nil)
    assert(chain().name == "Other chain fixture")
end)

test("delayed full membership becomes selectable through a bounded event reread", function()
    Mock.questLineQuests[lineID] = nil
    assert(WoW.AdvanceNameDiscovery("trauerh\195\182he") == "LOADING" and chain().loading)
    Mock.questLineQuests[lineID] = { 78743, 78744 }
    WoW.OnNameDiscoveryQuestLineUpdate(false)
    assert(finish("trauerh\195\182he") == "READY" and not chain().loading)
    assert(Mock.lineRequests[otherMap] == 1)
end)

test("missing map replies time out and late events reread without another request", function()
    Mock.questLinesByMap[otherMap] = {}
    assert(finish("trauerh\195\182he") == "PARTIAL" and WoW.nameDiscovery.done)
    local requests, reads = requestCount(), Mock.lineReads
    for _ = 1, 10 do assert(WoW.AdvanceNameDiscovery("trauerh\195\182he") == "PARTIAL") end
    assert(requestCount() == requests and Mock.lineReads == reads)
    Mock.questLinesByMap[otherMap] = { { questLineID = lineID, questLineName = "Trauerh\195\182he" } }
    WoW.OnNameDiscoveryQuestLineUpdate(false)
    assert(finish("trauerh\195\182he") == "PARTIAL" and not chain().loading)
    assert(requestCount() == requests and lineHit("Trauerh\195\182he").selectable)
end)

test("asynchronous empty map completion settles through the documented boolean update", function()
    Mock.questLinesByMap[otherMap] = {}
    assert(WoW.AdvanceNameDiscovery("empty") == "LOADING")
    WoW.OnQuestLineUpdate(false)
    WoW.OnNameDiscoveryQuestLineUpdate(false)
    assert(finish("empty") == "READY" and WoW.questLines.maps[otherMap].loaded)
    assert(Mock.lineRequests[otherMap] == 1 and chain() == nil)
end)

test("request-required map update reloads once and terminal continuations remain idle", function()
    Mock.questLinesByMap[otherMap] = {}
    assert(WoW.AdvanceNameDiscovery("trauerh\195\182he") == "LOADING")
    WoW.OnQuestLineUpdate(true)
    WoW.OnNameDiscoveryQuestLineUpdate(true)
    assert(WoW.questLines.maps[otherMap].needsRequest)
    Mock.questLinesByMap[otherMap] = { { questLineID = lineID, questLineName = "Trauerh\195\182he" } }
    assert(finish("trauerh\195\182he") == "READY" and not chain().loading)
    assert(Mock.lineRequests[otherMap] == 2)
    for _ = 1, 10 do assert(WoW.AdvanceNameDiscovery("trauerh\195\182he") == "READY") end
    assert(Mock.lineRequests[otherMap] == 2)
end)

test("empty complete tree is finite while map failures report partial coverage", function()
    children = {}
    assert(finish("empty") == "READY" and requestCount() == 0)
    WoW.ResetNameDiscovery()
    children = { { mapID = otherMap } }
    Mock.failLineRead = true
    assert(finish("failed") == "PARTIAL")
    assert(Mock.lineRequests[otherMap] == 1 and chain() == nil)
end)

test("missing APIs preserve guarded partial or unsupported discovery", function()
    C_Map.GetMapChildrenInfo = nil
    assert(finish("partial") == "PARTIAL" and treeCalls == 0)
    WoW.ResetNameDiscovery()
    C_QuestLine, C_QuestLog = nil, nil
    assert(finish("unsupported") == "UNSUPPORTED" and WoW.nameDiscovery.done)
end)

test("absent world-map fallback can still enumerate from the player's valid map", function()
    C_Map.GetFallbackWorldMapID = nil
    Mock.currentMapID = otherMap
    assert(finish("partial") == "PARTIAL" and treeCalls == 1 and chain())
end)

test("invalid and cyclic map metadata never pass invalid IDs to game APIs", function()
    children = { { mapID = -101 }, { mapID = otherMap }, { mapID = 0 / 0 }, "malformed" }
    assert(finish("partial") == "PARTIAL" and Mock.lineRequests[otherMap] == 1)
    WoW.ResetNameDiscovery()
    Mock.mapInfos[rootMap].parentMapID = rootMap
    assert(finish("cycle") == "PARTIAL" and treeCalls == 2)
end)

test("map queues use modest batches and enforce the finite catalogue ceiling", function()
    children = {}
    for entry = 1, 600 do
        local mapID, id = 121000 + entry, 131000 + entry
        children[#children + 1] = { mapID = mapID, mapType = 3 }
        Mock.mapInfos[mapID] = { name = "Generated map fixture" }
        Mock.questLinesByMap[mapID] = { { questLineID = id, questLineName = "Generated line fixture" } }
        Mock.questLineQuests[id] = { 78743, 78744 }
    end
    assert(WoW.AdvanceNameDiscovery("fixture") == "LOADING" and requestCount() == 6)
    assert(#WoW.nameDiscovery.mapQueue == 400 and finish("fixture") == "PARTIAL")
    assert(requestCount() == 400 and treeCalls == 1)
end)

test("accepted quest enumeration is bounded and deduplicates repeated members", function()
    children = {}
    for entry = 1, 130 do
        local questID, id = 141000 + entry, 151000 + entry
        Mock.log[#Mock.log + 1] = { questID = questID }
        Mock.active[questID] = true
        Mock.questLineInfoByQuest[questID] = { questLineID = id, questLineName = "Generated accepted fixture", startMapID = otherMap }
        Mock.questLineQuests[id] = { questID, 78744 }
    end
    assert(WoW.AdvanceNameDiscovery("fixture") == "LOADING")
    assert(#WoW.nameDiscovery.questQueue == 100 and WoW.nameDiscovery.questCursor == 5)
    assert(finish("fixture") == "PARTIAL")
    assert(#Mock.reverseCalls == 100 and requestCount() == 0)
end)

test("accepted associations still require the queried ID in the complete membership", function()
    children = {}
    Mock.log, Mock.active[78743] = { { questID = 78743 } }, true
    Mock.questLineInfoByQuest[78743] = { questLineID = lineID, questLineName = "Trauerh\195\182he", startMapID = otherMap }
    Mock.questLineQuests[lineID] = { 78744 }
    assert(finish("trauerh\195\182he") == "READY" and chain() == nil)
    assert(lineHit("Trauerh\195\182he") == nil and requestCount() == 0)
end)

test("wait read ceiling terminates even when the runtime clock does not advance", function()
    Mock.questLineQuests[lineID] = nil
    GetTime = function() return 0 end
    for _ = 1, 49 do assert(WoW.AdvanceNameDiscovery("fixture") == "LOADING") end
    assert(WoW.AdvanceNameDiscovery("fixture") == "PARTIAL" and WoW.nameDiscovery.done)
    assert(Mock.lineRequests[otherMap] == 1)
end)

test("cancellation drops query work while shared verified memberships survive", function()
    assert(finish("fixture") == "READY")
    local verified = assert(chain())
    WoW.ResetNameDiscovery()
    assert(WoW.nameDiscovery == nil and chain() == verified)
    WoW.OnNameDiscoveryQuestLineUpdate(false)
    assert(WoW.nameDiscovery == nil)
    local requests = requestCount()
    assert(finish("another query") == "READY" and requestCount() == requests)
end)

WoW.ResetNameDiscovery()
Mock, C_Map, C_QuestLine, C_QuestLog = saved.mock, saved.mapAPI, saved.lineAPI, saved.logAPI
Enum, GetTime, GetQuestUiMapID = saved.enum, saved.time, saved.questMapAPI
WoW.questLines.maps, WoW.questLines.currentMapID = saved.maps, saved.currentMapID
WoW.nameDiscovery, WoW.questLookup = saved.discovery, saved.lookup
WoW.requested, WoW.failedRequests, ns.chain = saved.requested, saved.failed, saved.chain
WoW.OnNameSearchAchievementUpdate(true)
print("Name-discovery behavioral checks passed: " .. passed)
