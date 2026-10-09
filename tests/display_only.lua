-- These fixtures and trapped API calls exercise display-only behavior offline.
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
    assert(Mock.opened == nil, "Tracker opened Blizzard quest navigation")
    assert(same(before, gameState()), "Display interaction changed a game-data fixture")
end
local function test(name, fn)
    local before = gameState()
    local ok, message = pcall(fn)
    assert(ok, "Display-only / " .. name .. ": " .. tostring(message))
    noMutation(before)
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

test("every runtime quest row only shows addon UI", function()
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
            click(row, "LeftButton")
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

test("selector refresh and runtime row clicks remain display-only", function()
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
    for _, row in ipairs(rows) do click(row, "LeftButton"); click(row, "RightButton") end

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

print("Display-only integration tests passed: " .. passed .. "; forbidden game API calls: " .. Mock.mutationCount)
