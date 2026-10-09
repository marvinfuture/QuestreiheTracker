-- API membership below is simulated; it does not assert a real map or quest line.
-- Fixture IDs: https://www.wowhead.com/quest=78743, /quest=78744 and /quest=78745.
local ns, passed = TEST_NS, 0
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Runtime model / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end
local function fixture()
    return assert(ns.LiveData.Build(2248, { questLineID = 5506,
        questLineName = "Pure model fixture", questID = 78744 }, { 78743, 78744, 78745 }))
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

test("fresh startup has no embedded catalog or false completion", function()
    assert(ns.initialized and ns.chain.id == "none" and ns.chain.empty)
    assert(ns.Chains == nil and ns.validChains == nil and ns.DemoData == nil)
    assert(ns.result.total == 0 and ns.result.completed == 0 and ns.result.percent == 0 and not ns.result.done)
    assert(ns.db.selectedChain == "none" and ns.db.liveSelection == nil)
    assert(ns.UI.Options == nil and rawget(ns.UI, "options") == nil)
    assert(rawget(ns.UI, "review") == nil and rawget(ns.UI, "reviewButton") == nil)
end)

test("membership validation and flattening stay pure", function()
    local before = Mock.calls
    local chain = fixture()
    local quests, byID = ns.Model.Flatten(chain)
    assert(#quests == 3 and byID[78744] == quests[2] and #ns.Model.Validate(chain) == 0)
    assert(ns.Model.Contains(chain, 78743) and not ns.Model.Contains(chain, 78562))
    local duplicate = copy(chain); duplicate.sections[1].quests[2].questID = 78743
    assert(#ns.Model.Validate(duplicate) > 0)
    assert(#ns.Model.Validate(false) > 0 and #ns.Model.Validate(ns.LiveData.Empty()) == 0)
    assert(#ns.Model.Validate(ns.LiveData.Pending(2248, 5506)) == 0)
    assert(Mock.calls == before, "Pure model must not call game APIs")
end)

test("model rejects every synthetic and nonfinite quest ID", function()
    for _, id in ipairs({ -101, 0, 1.5, math.huge, -math.huge, 0 / 0 }) do
        local chain = fixture(); chain.sections[1].quests[1].questID = id
        assert(#ns.Model.Validate(chain) > 0)
    end
end)

test("progress distinguishes unavailable API data from known nonacceptance", function()
    local cases = {
        { true, true, "COMPLETED" }, { true, false, "COMPLETED" },
        { false, true, "ACTIVE" }, { false, false, "NOT_ACCEPTED" },
        { false, nil, "UNKNOWN" }, { nil, false, "UNKNOWN" }, { nil, nil, "UNKNOWN" },
    }
    local before = Mock.calls
    for _, case in ipairs(cases) do
        assert(ns.Model.ProgressStatus(case[1], case[2]) == case[3])
        local result = ns.Model.Evaluate(fixture(), { completed = { [78743] = case[1] },
            active = { [78743] = case[2] } })
        assert(result.byID[78743].progressStatus == case[3])
    end
    assert(Mock.calls == before)
end)

test("only current NPC offer establishes AVAILABLE", function()
    local chain = fixture()
    local result = ns.Model.Evaluate(chain, { completed = { [78744] = false }, active = { [78744] = false } })
    assert(result.byID[78744].status == "UNKNOWN" and result.byID[78744].inferredNext)
    result = ns.Model.Evaluate(chain, { offered = { [78744] = true } })
    assert(result.byID[78744].status == "AVAILABLE")
    result = ns.Model.Evaluate(chain, { active = { [78744] = true }, offered = { [78744] = true } })
    assert(result.byID[78744].status == "ACTIVE")
    result = ns.Model.Evaluate(chain, { completed = { [78744] = true }, active = { [78744] = true } })
    assert(result.byID[78744].status == "COMPLETED")
end)

test("all API members count without invented optionality or prerequisites", function()
    local chain = fixture()
    for _, quest in ipairs(ns.Model.Flatten(chain)) do
        assert(quest.prerequisites == nil and quest.optional == nil)
        assert(quest.requirementsKnown == false and quest.optionalityKnown == false)
        assert(quest.source == ns.LiveData.source and quest.sourceAPI == "C_QuestLine.GetQuestLineQuests")
    end
    local result = ns.Model.Evaluate(chain, { completed = { [78743] = true, [78744] = true, [78745] = true } })
    assert(result.total == 3 and result.completed == 3 and result.percent == 100 and result.done)
    result = ns.Model.Evaluate(ns.LiveData.Pending(2248, 5506), {})
    assert(result.total == 0 and result.percent == 0 and not result.done)
end)

test("saved preferences discard old catalogs progress titles and feature flags", function()
    local config = ns.ReadConfig({ selectedChain = "mourning-rise", autoAccept = true,
        autoAbandon = true, warnUnrelated = false, offerHint = false, otherHint = true,
        highlight = false, markOther = true, scale = 1.1, completed = { [78743] = true },
        titles = { [78743] = "Old title" }, questLines = { fixture() },
        panelPositions = { options = { point = "CENTER", relativePoint = "CENTER", x = 1, y = 2 } } })
    assert(config.schemaVersion == 6 and config.selectedChain == "none" and config.scale == 1)
    for _, key in ipairs({ "autoAccept", "autoAbandon", "warnUnrelated", "offerHint", "otherHint",
        "highlight", "markOther", "completed", "titles", "questLines" }) do assert(config[key] == nil) end
    assert(config.panelPositions.options == nil)
    assert(ns.ReadConfig({ size = { width = 550, height = 750 } }).size == nil)
    assert(ns.ReadConfig({ schemaVersion = 4, size = { width = 550, height = 750 } }).size == nil)
    local retained = ns.ReadConfig({ schemaVersion = 5, size = { width = 550, height = 750 } })
    assert(retained.size.width == 550 and retained.size.height == 750)
    retained = ns.ReadConfig({ size = { width = 820, height = 930 } })
    assert(retained.size.width == 820 and retained.size.height == 930)
    assert(ns.ReadConfig({ selectedChain = "demo-branches" }).selectedChain == "none")
    assert(ns.ReadConfig({ position = { point = "invalid", relativePoint = "CENTER", x = 0, y = 0 } }).position == nil)
end)

test("invalid adapter and link IDs never reach game APIs", function()
    local before = Mock.calls
    for _, id in ipairs({ -101, 0, 1.5, math.huge, -math.huge, 0 / 0 }) do
        ns.UI.ShowLink(id)
        assert(ns.WoW.Title({ questID = id, title = "Invalid fixture" }) == "Invalid fixture")
        ns.WoW.RequestTitle(id)
        local snapshot = ns.WoW.Snapshot({ sections = { { quests = { { questID = id } } } } })
        assert(next(snapshot.completed) == nil and next(snapshot.active) == nil)
    end
    assert(Mock.calls == before)
end)

test("all gameplay events share one coalescing refresh timer", function()
    Mock.Flush()
    for index = 1, 20 do ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUEST_LOG_UPDATE") end
    assert(#Mock.timers == 1)
    Mock.Flush(); assert(not ns.pending and #Mock.timers == 0)
    for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
    assert(Mock.mutationCount == 0)
end)

print("Runtime model and fresh-start tests passed: " .. passed)
