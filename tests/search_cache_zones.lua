-- Map/line names and positive generated IDs below are simulated runtime responses.
-- Quest fixtures: https://www.wowhead.com/quest=78743, /quest=78744, /quest=78745 and /quest=78562.
local ns, WoW, passed = TEST_NS, TEST_NS.WoW, 0
Mock.Flush()
local function copy(value)
    local result = {}
    for key, item in pairs(value or {}) do result[key] = item end
    return result
end
local saved = { mock = Mock, mapAPI = C_Map, lineAPI = C_QuestLine, logAPI = C_QuestLog,
    enum = Enum, questMapAPI = GetQuestUiMapID, maps = WoW.questLines.maps,
    current = WoW.questLines.currentMapID, browse = WoW.questLines.browseMapID,
    discovery = WoW.nameDiscovery, lookup = WoW.questLookup, requested = WoW.requested,
    failed = WoW.failedRequests, chain = ns.chain, db = ns.db, nameLookup = ns.nameLookup,
    nsLookup = ns.questLookup, category = GetCategoryList, categoryCount = GetCategoryNumAchievements,
    achievement = GetAchievementInfo, criterionCount = GetAchievementNumCriteria,
    criterion = GetAchievementCriteriaInfo, metaType = CRITERIA_TYPE_ACHIEVEMENT }
local root, north, south = 120000, 120010, 120020
local current, explicit, distant, retired = 120001, 120002, 120003, 120004
local children, treeCalls, categoryCalls

local function requests()
    local count = 0
    for _, amount in pairs(Mock.lineRequests) do count = count + amount end
    return count
end

local function reset()
    WoW.ResetNameDiscovery()
    WoW.ResetQuestLookup()
    Mock = copy(saved.mock)
    for _, key in ipairs({ "timers", "active", "titles", "requests", "log", "mapInfos", "questLinesByMap",
        "questLineQuests", "lineRequests", "questMapIDs", "questMapCalls", "questLineInfoByQuest",
        "questLineInfoByMap", "reverseCalls", "questsOnMap" }) do Mock[key] = {} end
    for _, key in ipairs({ "onLineRequest", "failMapInfo", "failLineRead", "failLineRequest",
        "failLineQuests", "failReverseLineRead", "failQuestMapRead", "failMapRead" }) do Mock[key] = nil end
    Mock.currentMapID, Mock.now, Mock.lineReads = current, 0, 0
    C_Map, C_QuestLine, C_QuestLog = copy(saved.mapAPI), copy(saved.lineAPI), copy(saved.logAPI)
    Enum = { UIMapType = { World = 0, Continent = 2, Zone = 3, Dungeon = 4 }, SuperTrackingType = { Quest = 0 } }
    GetQuestUiMapID = saved.questMapAPI
    WoW.questLines.maps, WoW.questLines.currentMapID, WoW.questLines.browseMapID = {}, nil, nil
    WoW.requested, WoW.failedRequests = {}, {}
    ns.chain, ns.db, ns.nameLookup, ns.questLookup = ns.LiveData.Empty(), copy(saved.db), nil, nil
    treeCalls, categoryCalls = 0, 0
    Mock.mapInfos[root] = { mapID = root, name = "World fixture", mapType = 0, parentMapID = 0 }
    Mock.mapInfos[north] = { mapID = north, name = "North fixture", mapType = 2, parentMapID = root }
    Mock.mapInfos[south] = { mapID = south, name = "South fixture", mapType = 2, parentMapID = root }
    for index, mapID in ipairs({ current, explicit, distant, retired }) do
        Mock.mapInfos[mapID] = { mapID = mapID, name = "Zone fixture " .. index, mapType = 3,
            parentMapID = index % 2 == 0 and south or north }
        Mock.questLinesByMap[mapID] = {}
    end
    children = { Mock.mapInfos[distant], Mock.mapInfos[explicit], Mock.mapInfos[current] }
    C_Map.GetFallbackWorldMapID = function() return root end
    C_Map.GetMapChildrenInfo = function(mapID, kind, recursive)
        assert(mapID == root and kind == Enum.UIMapType.Zone and recursive == true)
        treeCalls = treeCalls + 1
        return children
    end
    GetCategoryList = function() categoryCalls = categoryCalls + 1; return {} end
    GetCategoryNumAchievements = function() return 0 end
    GetAchievementInfo, GetAchievementNumCriteria = saved.achievement, saved.criterionCount
    GetAchievementCriteriaInfo, CRITERIA_TYPE_ACHIEVEMENT = saved.criterion, saved.metaType
    WoW.ClearSearchCache()
end

local function line(mapID, lineID, title, ids)
    local chain = assert(ns.LiveData.Build(mapID, { questLineID = lineID, questLineName = title }, ids))
    Mock.questLineQuests[lineID] = ids
    return assert(WoW.RegisterQuestLine(chain))
end

local function test(name, fn)
    reset()
    local ok, message = pcall(fn)
    assert(ok, "Search cache / zones / " .. name .. ": " .. tostring(message))
    assert(Mock.mutationCount == saved.mock.mutationCount and Mock.invalidIDCalls == saved.mock.invalidIDCalls)
    assert(#Mock.timers == 0, "Backend must use Core's existing coalescing timer")
    passed = passed + 1
end

test("zone catalog groups real parent continents, deduplicates and requests no quests", function()
    children[#children + 1] = Mock.mapInfos[explicit]
    children[#children + 1] = { mapID = retired, mapType = 4, name = "Dungeon fixture", parentMapID = south }
    local rows, status, metadata = WoW.GetZoneCatalog()
    assert(#rows == 3 and status == "PARTIAL" and metadata.partial and not metadata.truncated)
    assert(rows[1].mapID == current and rows[1].groupName == "North fixture")
    assert(rows[2].mapID == distant and rows[3].groupName == "South fixture")
    assert(requests() == 0 and next(Mock.requests) == nil)
    assert(WoW.GetZoneCatalog() == rows and treeCalls == 1)
end)

test("catalog includes every supplied zone beyond the 400-map discovery ceiling", function()
    children = {}
    for index = 1, 512 do
        children[index] = { mapID = 150000 + index, name = "Catalog fixture " .. index,
            mapType = 3, parentMapID = north }
    end
    local rows, status, metadata = WoW.GetZoneCatalog()
    assert(#rows == 512 and status == "READY" and metadata.count == 512 and not metadata.partial)
    assert(requests() == 0 and next(WoW.questLines.maps) == nil)
end)

test("pathological catalogs are bounded with explicit partial metadata", function()
    children = {}
    for index = 1, 10001 do
        children[index] = { mapID = 160000 + index, name = "Large fixture " .. index,
            mapType = 3, parentMapID = north }
    end
    local rows, status, metadata = WoW.GetZoneCatalog()
    assert(#rows == 10000 and status == "PARTIAL" and metadata.truncated and metadata.partial)
    assert(requests() == 0)
end)

test("missing map APIs and unavailable child data return guarded statuses", function()
    C_Map.GetMapChildrenInfo = nil
    local rows, status, metadata = WoW.GetZoneCatalog()
    assert(#rows == 0 and status == "UNSUPPORTED" and metadata.error == "UNSUPPORTED")
    C_Map.GetMapChildrenInfo = function() error("Unavailable map catalog fixture") end
    rows, status, metadata = WoW.GetZoneCatalog(true)
    assert(#rows == 0 and status == "ERROR" and metadata.error == "ERROR" and metadata.partial and requests() == 0)
end)

test("cyclic continent parents produce bounded partial groups", function()
    Mock.mapInfos[north].mapType, Mock.mapInfos[north].parentMapID = 0, north
    local rows, status, metadata = WoW.GetZoneCatalog()
    assert(#rows == 3 and status == "PARTIAL" and metadata.partial)
    assert(rows[1].groupName ~= nil and requests() == 0)
end)

test("choosing a catalog zone requests only that chosen zone", function()
    WoW.GetZoneCatalog()
    assert(requests() == 0)
    local ok = WoW.SetBrowseZone(explicit)
    assert(ok and requests() == 1 and Mock.lineRequests[explicit] == 1)
    assert(WoW.questLines.browseMapID == explicit and WoW.questLines.currentMapID == nil)
    WoW.ReadQuestLines()
    assert(Mock.lineReads == 1)
    WoW.SetBrowseZone(explicit)
    assert(requests() == 1, "Repeated selection should reuse its existing request")
end)

test("explicit browsing stays selected across player zone changes", function()
    WoW.DiscoverZone()
    WoW.SetBrowseZone(explicit)
    Mock.currentMapID = distant
    WoW.DiscoverZone()
    assert(WoW.questLines.currentMapID == distant and WoW.questLines.browseMapID == explicit)
    local _, _, name = WoW.BrowseQuestLines()
    local _, _, currentName = WoW.ZoneQuestLines()
    assert(name == Mock.mapInfos[explicit].name and currentName == Mock.mapInfos[distant].name)
    assert(Mock.lineRequests[explicit] == 1)
end)

test("explicit browsing includes accepted lines without pins and excludes unrelated accepted lines", function()
    WoW.DiscoverZone()
    WoW.SetBrowseZone(explicit)
    Mock.log = { { questID = 78743 }, { questID = 78562 } }
    Mock.active[78743], Mock.active[78562] = true, true
    Mock.questLineInfoByQuest[78743] = { questLineID = 130001, questLineName = "Accepted browsed fixture",
        startMapID = explicit }
    Mock.questLineInfoByQuest[78562] = { questLineID = 130002, questLineName = "Unrelated accepted fixture",
        startMapID = distant }
    Mock.questMapIDs[78743], Mock.questMapIDs[78562] = explicit, distant
    Mock.questLineQuests[130001], Mock.questLineQuests[130002] = { 78743, 78744 }, { 78562 }
    WoW.ReadQuestLines()
    local choices, status = WoW.BrowseQuestLines()
    assert(#choices == 1 and status == "READY" and choices[1].questLineID == 130001)
    assert(#ns.Model.Flatten(choices[1]) == 2)
    assert(WoW.GetQuestLine(ns.LiveData.Key(explicit, 130002)) == nil)
    assert(#WoW.ZoneQuestLines() == 0, "Neither accepted line belongs to the player's current zone")
end)

test("current-zone option follows changes and normalizes a supplied subzone", function()
    WoW.SetBrowseZone(explicit)
    local subzone = 120030
    Mock.mapInfos[subzone] = { name = "Subzone fixture", mapType = 4, parentMapID = current }
    Mock.currentMapID = subzone
    assert(WoW.SetBrowseZone(nil))
    assert(WoW.questLines.browseMapID == nil and WoW.questLines.currentMapID == current)
    local _, _, name = WoW.BrowseQuestLines()
    assert(name == Mock.mapInfos[current].name)
    Mock.currentMapID = distant
    WoW.DiscoverZone()
    _, _, name = WoW.BrowseQuestLines()
    assert(name == Mock.mapInfos[distant].name)
end)

test("invalid or non-zone dropdown entries cannot request maps or change browsing", function()
    WoW.SetBrowseZone(explicit)
    local count = requests()
    for _, id in ipairs({ -1, 0, 1.5, math.huge, north }) do assert(not WoW.SetBrowseZone(id)) end
    assert(requests() == count and WoW.questLines.browseMapID == explicit)
end)

test("normal refresh reads browsing and current contexts without traversing distant caches", function()
    WoW.DiscoverZone()
    WoW.SetBrowseZone(explicit)
    for index = 1, 50 do line(180000 + index, 190000 + index, "Retired cache fixture", { 78743 }) end
    WoW.ReadQuestLines()
    assert(Mock.lineReads == 2, "Refresh must read only two active zone contexts")
end)

test("automatic cleanup keeps selected/current/browse/results and active pending contexts", function()
    WoW.DiscoverZone()
    WoW.SetBrowseZone(explicit)
    local selected = line(distant, 130001, "Selected fixture", { 78743, 78744 })
    ns.chain = selected
    line(distant, 130002, "Unneeded same-map fixture", { 78562 })
    line(retired, 130003, "Discarded fixture", { 78562 })
    local resultMap, pendingMap = 120040, 120050
    Mock.mapInfos[pendingMap] = { name = "Pending fixture" }
    local result = line(resultMap, 130004, "Result fixture", { 78745 })
    ns.nameLookup = { results = { { chain = result, kind = "QUEST_LINE" } }, pending = false }
    WoW.RequestTitle(78743)
    WoW.RequestTitle(78562)
    WoW.RequestTitle(78745)
    WoW.RequestQuestLineMap(pendingMap)
    WoW.questLookup = { questID = 78563, maps = { [pendingMap] = true } }
    WoW.RequestTitle(78563)
    WoW.PruneSearchCache()
    assert(WoW.GetQuestLine(selected.id) == selected and WoW.GetQuestLine(result.id) == result)
    assert(WoW.questLines.maps[current] and WoW.questLines.maps[explicit] and WoW.questLines.maps[pendingMap])
    assert(WoW.questLines.maps[retired] == nil and WoW.GetQuestLine(ns.LiveData.Key(distant, 130002)) == nil)
    assert(WoW.requested[78743] and WoW.requested[78745] and WoW.requested[78563] and not WoW.requested[78562])
end)

test("terminal discovery payloads disappear while displayed results remain selectable", function()
    local result = line(distant, 130001, "Displayed fixture", { 78743 })
    line(retired, 130002, "Other fixture", { 78744 })
    ns.nameLookup = { pending = false, results = { { kind = "QUEST_LINE", chain = result } } }
    WoW.nameDiscovery = { done = true, maps = { [distant] = true, [retired] = true } }
    WoW.PruneSearchCache()
    assert(WoW.nameDiscovery == nil and WoW.questLines.maps[retired] == nil)
    assert(WoW.GetQuestLine(result.id) == result)
    ns.nameLookup = nil
    WoW.PruneSearchCache()
    assert(WoW.GetQuestLine(result.id) == nil)
end)

test("manual clear preserves the displayed chain/preferences and drops all unrelated caches", function()
    WoW.DiscoverZone()
    WoW.SetBrowseZone(explicit)
    local selected = line(distant, 130001, "Selected fixture", { 78743, 78744 })
    ns.chain = selected
    line(distant, 130002, "Unneeded same-map fixture", { 78562 })
    line(retired, 130003, "Other fixture", { 78562 })
    WoW.RequestTitle(78743)
    WoW.RequestTitle(78562)
    WoW.failedRequests[78562] = true
    WoW.GetZoneCatalog()
    local previousRequests, previousReads, db = requests(), Mock.lineReads, ns.db
    WoW.ClearSearchCache()
    assert(ns.chain == selected and ns.db == db and WoW.GetQuestLine(selected.id) == selected)
    assert(WoW.questLines.maps[current] == nil and WoW.questLines.maps[explicit] == nil)
    assert(WoW.questLines.maps[retired] == nil and WoW.GetQuestLine(ns.LiveData.Key(distant, 130002)) == nil)
    assert(WoW.requested[78743] and not WoW.requested[78562] and not WoW.failedRequests[78562])
    local _, _, browseName = WoW.BrowseQuestLines()
    assert(browseName == Mock.mapInfos[explicit].name, "Clearing quest caches must preserve the chosen zone label")
    WoW.OnQuestLineUpdate(true)
    WoW.ReadQuestLines()
    assert(requests() == previousRequests and Mock.lineReads == previousReads)
    WoW.GetZoneCatalog()
    assert(treeCalls == 2, "Manual cache clearing must also release the name-only zone catalog")
end)

test("late canceled metadata outcomes cannot seed the next query's private result cache", function()
    WoW.RequestTitle(78562)
    WoW.OnQuestLookupDataLoadResult(78562, false)
    WoW.ClearSearchCache()
    WoW.OnQuestDataLoadResult(78562, true)
    WoW.OnQuestLookupDataLoadResult(78562, true)
    assert(not WoW.requested[78562] and WoW.questLookup == nil)
    Mock.questMapIDs[78562] = distant
    local _, status = WoW.FindQuestLine(78562)
    assert(status == "LOADING" and Mock.requests[78562] == 2)
    WoW.OnQuestLineUpdate(false)
    WoW.ReadQuestLines()
    _, status = WoW.FindQuestLine(78562)
    assert(status == "LOADING", "Canceled old outcome must not finish the new title request")
    WoW.OnQuestLookupDataLoadResult(78562, true)
    _, status = WoW.FindQuestLine(78562)
    assert(status == "NOT_FOUND")
end)

test("late quest-line events cannot recreate discarded distant maps or change the chain", function()
    local selected = line(current, 130001, "Selected fixture", { 78743 })
    ns.chain = selected
    WoW.RequestQuestLineMap(retired)
    WoW.nameDiscovery = { maps = { [retired] = true } }
    WoW.ClearSearchCache()
    WoW.OnNameDiscoveryQuestLineUpdate(false)
    WoW.OnQuestLineUpdate(true)
    WoW.ReadQuestLines()
    assert(WoW.nameDiscovery == nil and WoW.questLines.maps[retired] == nil and ns.chain == selected)
end)

test("terminal displayed membership and achievement progress refresh without rediscovery", function()
    local pending = ns.LiveData.Pending(distant, 130001, "Exact fixture")
    WoW.RegisterQuestLine(pending)
    Mock.questLineQuests[130001] = { 78743, 78744 }
    local done = false
    GetAchievementInfo = function(id) return id, "Achievement fixture", 10, done end
    local results = {
        { kind = "QUEST_LINE", chain = pending, name = pending.name, foldedName = "exact fixture",
            exact = true, query = "exact fixture", selectable = false },
        { kind = "ACHIEVEMENT", achievementID = 130020, completed = false },
    }
    local exact = WoW.RefreshNameSearchResults(results)
    assert(exact and exact == results[1].chain and results[1].selectable and #ns.Model.Flatten(exact) == 2)
    done = true
    WoW.RefreshNameSearchResults(results)
    assert(results[2].completed == true and treeCalls == 0 and categoryCalls == 0 and requests() == 0)
end)

test("terminal refresh retains verified membership during transient unavailable reads", function()
    local verified = line(distant, 130001, "Exact fixture", { 78743, 78744 })
    Mock.failLineQuests = true
    local results = { { kind = "QUEST_LINE", chain = verified, name = verified.name,
        foldedName = "exact fixture", exact = true, query = "exact fixture", selectable = true } }
    assert(WoW.RefreshNameSearchResults(results) == verified and results[1].selectable)
end)

test("terminal refresh retains exact-name ambiguity and unresolved membership safeguards", function()
    local first = line(distant, 130001, "Exact fixture", { 78743 })
    local second = ns.LiveData.Pending(explicit, 130002, "Exact fixture")
    WoW.RegisterQuestLine(second)
    local results = {}
    for _, chain in ipairs({ first, second }) do
        results[#results + 1] = { kind = "QUEST_LINE", chain = chain, name = chain.name,
            foldedName = "exact fixture", query = "exact fixture", exact = true }
    end
    assert(WoW.RefreshNameSearchResults(results) == nil and not results[2].selectable)
    Mock.questLineQuests[130002] = { 78744 }
    assert(WoW.RefreshNameSearchResults(results) == nil and results[2].selectable)
end)

WoW.ResetNameDiscovery()
WoW.ResetQuestLookup()
WoW.ClearZoneCatalog()
Mock, C_Map, C_QuestLine, C_QuestLog = saved.mock, saved.mapAPI, saved.lineAPI, saved.logAPI
Enum, GetQuestUiMapID = saved.enum, saved.questMapAPI
WoW.questLines.maps, WoW.questLines.currentMapID, WoW.questLines.browseMapID = saved.maps, saved.current, saved.browse
WoW.nameDiscovery, WoW.questLookup = saved.discovery, saved.lookup
WoW.requested, WoW.failedRequests, ns.chain, ns.db = saved.requested, saved.failed, saved.chain, saved.db
ns.nameLookup, ns.questLookup = saved.nameLookup, saved.nsLookup
GetCategoryList, GetCategoryNumAchievements = saved.category, saved.categoryCount
GetAchievementInfo, GetAchievementNumCriteria = saved.achievement, saved.criterionCount
GetAchievementCriteriaInfo, CRITERIA_TYPE_ACHIEVEMENT = saved.criterion, saved.metaType
WoW.OnNameSearchAchievementUpdate(true)
print("Search-cache and zone-browser behavioral checks passed: " .. passed)
