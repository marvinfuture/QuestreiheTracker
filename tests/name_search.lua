-- All names, positive generated IDs and associations below are simulated API replies, not gameplay facts.
-- Fixed quest fixtures follow existing tests: https://www.wowhead.com/quest=78743 and /quest=78744.
local ns, passed = TEST_NS, 0
local saved = { categories = GetCategoryList, categoryCount = GetCategoryNumAchievements,
    achievement = GetAchievementInfo, criterionCount = GetAchievementNumCriteria,
    criterion = GetAchievementCriteriaInfo, metaType = CRITERIA_TYPE_ACHIEVEMENT,
    maps = ns.WoW.questLines.maps }
local fixture, counts

-- Prefix failures with this module's name while retaining the original assertion details.
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Name search / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end

-- Install local read-only achievement fixtures without changing the shared global stub file.
local function reset()
    fixture = { categories = { 92 }, achievements = { [92] = { 6 } },
        names = { [6] = "Verbündete Völker: Irdene", [503] = "Verknüpfter Erfolg" },
        completed = {}, criteria = { [6] = {
            { name = "Geschichtsreihe Trauerhöhe", kind = 27, assetID = 78743, criteriaID = 101, completed = false },
            { name = "Weiterer Erfolg", kind = 8, assetID = 503, criteriaID = 102, completed = false },
        }, [503] = { { name = "Unterkriterium", kind = 8, assetID = 6, criteriaID = 103, completed = false } } } }
    counts = { categories = 0, categoryCount = 0, achievement = 0, criterionCount = 0, criterion = 0 }
    ns.WoW.questLines.maps = {}
    CRITERIA_TYPE_ACHIEVEMENT = 8
    -- Return personal category IDs and count calls to prove session index reuse.
    GetCategoryList = function()
        counts.categories = counts.categories + 1
        return fixture.categories
    end
    -- Supply category cardinality independently from the number of child criteria.
    GetCategoryNumAchievements = function(categoryID)
        counts.categoryCount = counts.categoryCount + 1
        return #(fixture.achievements[categoryID] or {})
    end
    -- Preserve the API's category/index overload and achievement completion position.
    GetAchievementInfo = function(id, entry)
        counts.achievement = counts.achievement + 1
        if entry then id = (fixture.achievements[id] or {})[entry] end
        if id and fixture.names[id] then return id, fixture.names[id], 10, fixture.completed[id] == true end
    end
    -- Return only the criterion count belonging to the queried fixture achievement.
    GetAchievementNumCriteria = function(id)
        counts.criterionCount = counts.criterionCount + 1
        return #(fixture.criteria[id] or {})
    end
    -- Retain typed assets and criterion identifiers in the native return positions.
    GetAchievementCriteriaInfo = function(id, entry)
        counts.criterion = counts.criterion + 1
        local criterion = (fixture.criteria[id] or {})[entry]
        if criterion then return criterion.name, criterion.kind, criterion.completed, 0, 1,
            nil, 0, criterion.assetID, "", criterion.criteriaID end
    end
    ns.WoW.OnNameSearchAchievementUpdate(true)
end

-- Build a verified line using the same guarded runtime conversion as the actual addon.
local function line(name, lineID)
    local chain = assert(ns.LiveData.Build(2248, { questLineID = lineID, questLineName = name }, { 78743, 78744 }))
    ns.WoW.RegisterQuestLine(chain)
    return chain
end

-- Retrieve a particular result kind while keeping multiple matches explicit in assertions.
local function resultOf(results, kind, id)
    for _, result in ipairs(results) do
        if result.kind == kind and (not id or result.achievementID == id) then return result end
    end
end

-- Drive only the finite index continuation and fail if the search does not settle within its bound.
local function finish(query)
    local results, status
    for _ = 1, 150 do
        results, status = ns.WoW.SearchQuestLinesByName(query)
        if status ~= "LOADING" then return results, status end
    end
    error("Name search failed to reach a terminal state")
end

-- Invalid inputs must never begin achievement discovery or call game data APIs.
test("invalid inputs do not query APIs", function()
    reset()
    for _, text in ipairs({ "", "   ", "x", "ä", string.rep("x", 241), 1, false, {} }) do
        local results, status = ns.WoW.SearchQuestLinesByName(text)
        assert(#results == 0 and status == "INVALID")
    end
    local results, status = ns.WoW.SearchQuestLinesByName(nil)
    assert(#results == 0 and status == "INVALID" and counts.categories == 0)
end)

-- German case folding, partial matches and exact-first ordering apply to verified runtime names.
test("German names and partial matches search every session map deterministically", function()
    reset()
    local exact = line("Trauerhöhe", 5506)
    local partial = line("Tal von Trauerhöhe", 5507)
    local pending = ns.LiveData.Pending(2248, 5508, "Trauerhöhe wartet")
    ns.WoW.RegisterQuestLine(pending)
    ns.WoW.questLines.maps[2214] = { byID = { [exact.id] = exact }, chains = {} }
    local results, status = finish("  TRAUERHÖHE  ")
    assert(status == "READY" and results[1].chain == exact and results[1].selectable and results[1].exact)
    assert(results[2].chain == partial and results[2].selectable)
    local pendingHit, selectable = nil, 0
    for _, result in ipairs(results) do
        if result.selectable then selectable = selectable + 1 end
        if result.chain == pending then pendingHit = result end
    end
    assert(selectable == 2 and pendingHit and not pendingHit.selectable and pendingHit.loading)
    results = finish("höhe")
    assert(results[1].chain == partial and results[2].chain == exact)
    line("ÄÖÜẞ", 5509)
    results = finish("äöüß")
    assert(#results == 1 and results[1].selectable)
end)

-- Achievement and chapter-like criterion labels cannot fabricate a selectable quest line.
test("achievement criterion assets and text are informational without verified membership", function()
    reset()
    local before = Mock.calls
    local results, status = finish("Trauerhöhe")
    local criterion = assert(resultOf(results, "CRITERION"))
    assert(status == "READY" and #results == 1 and not criterion.selectable and criterion.chain == nil)
    assert(criterion.assetID == 78743 and criterion.criteriaType == 27 and criterion.criteriaID == 101)
    assert(criterion.achievementName == "Verbündete Völker: Irdene" and criterion.completed == false)
    assert(type(criterion.source) == "string" and criterion.sourceAPI == "GetAchievementCriteriaInfo")
    assert(Mock.calls == before, "Criterion asset IDs must never be probed as quest IDs")
    local chain = line("Trauerhöhe", 5506)
    results, status = finish("Trauerhöhe")
    assert(results[1].chain == chain and results[1].selectable and resultOf(results, "CRITERION").chain == nil)
end)

-- Invalid synthetic assets remain information-only and never enter any Blizzard API.
test("negative criterion and subachievement assets never reach game APIs", function()
    reset()
    fixture.criteria[6][1].assetID, fixture.criteria[6][2].assetID = -101, -102
    local before = Mock.calls
    local results, status = finish("Irdene")
    assert(status == "READY" and #results == 3 and counts.criterionCount == 1)
    for _, result in ipairs(results) do
        assert(result.assetID == nil and result.childAchievementID == nil and not result.selectable)
    end
    assert(Mock.calls == before)
end)

-- The native achievement criterion type follows explicit links and terminates even with a cycle.
test("linked subachievements are searched with cycle protection", function()
    reset()
    local results, status = finish("Verknüpfter")
    assert(status == "READY" and #results == 2)
    assert(resultOf(results, "ACHIEVEMENT", 503) and resultOf(results, "CRITERION", 503))
    assert(counts.categoryCount == 1 and counts.criterionCount == 2)
    results = finish("Irdene")
    assert(#results == 3 and resultOf(results, "ACHIEVEMENT", 6))
    local child
    for _, result in ipairs(results) do
        if result.childAchievementID == 503 then child = result end
    end
    assert(child and child.criteriaType == CRITERIA_TYPE_ACHIEVEMENT and not child.selectable)
end)

-- Absent native type metadata must not promote an arbitrary asset to an achievement ID.
test("missing achievement type constant leaves linked assets untraversed", function()
    reset()
    CRITERIA_TYPE_ACHIEVEMENT = nil
    local results, status = finish("Verknüpfter")
    assert(#results == 0 and status == "PARTIAL" and counts.criterionCount == 1)
end)

-- Pattern punctuation is ordinary search text, not executable Lua matching syntax.
test("search treats pattern characters literally", function()
    reset()
    local exact = line("[%] Fixture", 5506)
    local results = finish("[%]")
    assert(#results == 1 and results[1].chain == exact)
end)

-- Completion rereads reflect events without repeatedly enumerating stable achievement names.
test("progress events reread returned hits and list events rebuild discovery", function()
    reset()
    local results = finish("Irdene")
    assert(resultOf(results, "ACHIEVEMENT", 6).completed == false)
    assert(resultOf(results, "CRITERION", 6).completed == false)
    fixture.completed[6], fixture.criteria[6][1].completed = true, true
    ns.WoW.OnNameSearchAchievementUpdate()
    results = finish("Irdene")
    assert(resultOf(results, "ACHIEVEMENT", 6).completed == true)
    assert(resultOf(results, "CRITERION", 6).completed == true and counts.categories == 1)
    fixture.names[6] = "Umbenannter Erfolg"
    ns.WoW.OnNameSearchAchievementUpdate(true)
    results = finish("Umbenannter")
    assert(#results == 3 and counts.categories == 2)
end)

-- Missing optional APIs preserve runtime line results and report the uncovered data source.
test("missing and failed APIs remain guarded", function()
    reset()
    local chain = line("Trauerhöhe", 5506)
    GetCategoryList = nil
    ns.WoW.OnNameSearchAchievementUpdate(true)
    local results, status = finish("Trauerhöhe")
    assert(#results == 1 and results[1].chain == chain and status == "PARTIAL")
    results, status = finish("Unbekannt")
    assert(#results == 0 and status == "UNSUPPORTED")
    reset()
    GetAchievementCriteriaInfo = nil
    ns.WoW.OnNameSearchAchievementUpdate(true)
    results, status = finish("Irdene")
    assert(#results == 1 and status == "PARTIAL")
    reset()
    -- Simulate a client read failure to verify pcall contains the error.
    GetCategoryList = function() error("Fixture failure") end
    ns.WoW.OnNameSearchAchievementUpdate(true)
    results, status = finish("Irdene")
    assert(#results == 0 and status == "PARTIAL")
end)

-- Large fixture indexes advance in chunks and retain their cursors when the query changes.
test("large indexes respect per-refresh budgets and reuse partial discovery", function()
    reset()
    fixture.achievements[92], fixture.names, fixture.criteria = {}, {}, {}
    for entry = 1, 250 do
        local id = 100000 + entry
        fixture.achievements[92][entry], fixture.names[id], fixture.criteria[id] = id, "Unmatched " .. entry, {}
        for criterion = 1, 6 do
            fixture.criteria[id][criterion] = { name = "Criterion " .. criterion,
                kind = 27, assetID = 78743, criteriaID = entry * 10 + criterion, completed = false }
        end
    end
    local results, status = ns.WoW.SearchQuestLinesByName("Missing")
    assert(#results == 0 and status == "LOADING")
    assert(counts.achievement <= 100 and counts.criterion <= 500)
    local beforeAchievement, beforeCriterion = counts.achievement, counts.criterion
    results, status = ns.WoW.SearchQuestLinesByName("Still missing")
    assert(status == "LOADING" and counts.categories == 1)
    assert(counts.achievement - beforeAchievement <= 100 and counts.criterion - beforeCriterion <= 500)
    results, status = finish("Missing")
    assert(status == "EMPTY" and counts.achievement == 250 and counts.criterion == 1500)
end)

-- A malformed native cardinality must never enter an unbounded enumeration loop.
test("invalid category and criterion counts stop with partial coverage", function()
    reset()
    -- Supply a nonfinite cardinality that cannot drive a numeric loop.
    GetCategoryNumAchievements = function() return math.huge end
    ns.WoW.OnNameSearchAchievementUpdate(true)
    local results, status = finish("Irdene")
    assert(#results == 0 and status == "PARTIAL" and counts.achievement == 0)
    reset()
    -- Supply a NaN criterion count while retaining the available achievement label.
    GetAchievementNumCriteria = function() return 0 / 0 end
    ns.WoW.OnNameSearchAchievementUpdate(true)
    results, status = finish("Irdene")
    assert(#results == 1 and status == "PARTIAL" and counts.criterion == 0)
end)

-- Total scan ceilings guarantee terminal partial status even for excessive client lists.
test("session scan ceilings terminate without permanent polling", function()
    reset()
    fixture.achievements[92], fixture.names, fixture.criteria = {}, {}, {}
    for entry = 1, 7000 do
        local id = 100000 + entry
        fixture.achievements[92][entry], fixture.names[id] = id, "Unmatched " .. entry
    end
    local results, status = finish("Missing")
    assert(status == "PARTIAL" and #results == 0 and counts.achievement == 6000)
    local before = counts.achievement
    results, status = finish("Missing")
    assert(status == "PARTIAL" and counts.achievement == before)
    reset()
    -- Simulate an excessive criterion list lazily to avoid a permanent timer or fixture catalogue.
    GetAchievementNumCriteria = function() return 40000 end
    -- Keep every returned criterion name valid while counting the strict total scan ceiling.
    GetAchievementCriteriaInfo = function(_, entry)
        counts.criterion = counts.criterion + 1
        return "Unmatched criterion", 27, false, 0, 1, nil, 0, 78743, "", entry
    end
    ns.WoW.OnNameSearchAchievementUpdate(true)
    results, status = finish("Missing")
    assert(status == "PARTIAL" and #results == 0 and counts.criterion == 30000)
end)

-- Excessive name matches are bounded before live progress reads and remain deterministic.
test("result limit reports partial coverage and keeps verified lines first", function()
    reset()
    fixture.criteria[6] = {}
    for entry = 1, 250 do
        fixture.criteria[6][entry] = { name = "Trauerhöhe " .. entry, kind = 27,
            assetID = 78743, criteriaID = entry, completed = false }
    end
    local chain = line("Trauerhöhe", 5506)
    local results, status = finish("Trauerhöhe")
    assert(status == "PARTIAL" and #results == 200 and results[1].chain == chain and results[1].selectable)
    local repeated = finish("Trauerhöhe")
    for entry, result in ipairs(results) do
        assert(result.name == repeated[entry].name and result.criteriaID == repeated[entry].criteriaID)
    end
end)

GetCategoryList, GetCategoryNumAchievements = saved.categories, saved.categoryCount
GetAchievementInfo, GetAchievementNumCriteria = saved.achievement, saved.criterionCount
GetAchievementCriteriaInfo, CRITERIA_TYPE_ACHIEVEMENT = saved.criterion, saved.metaType
ns.WoW.questLines.maps = saved.maps
ns.WoW.OnNameSearchAchievementUpdate(true)
print("Name-search behavior checks passed: " .. passed)
