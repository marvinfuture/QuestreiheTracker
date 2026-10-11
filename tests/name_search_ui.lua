-- UI/Core fixtures verify wiring and cancellation; they do not establish real client data or layout.
-- Fixture membership IDs: https://www.wowhead.com/quest=78743 and /quest=78744.
local ns, UI, passed = TEST_NS, TEST_NS.UI, 0
Mock.Flush()
local saved = { search = ns.WoW.SearchQuestLinesByName, db = ns.db, chain = ns.chain,
    maps = ns.WoW.questLines.maps, currentMap = ns.WoW.questLines.currentMapID,
    shown = UI.frame:IsShown(), selectorShown = UI.selector and UI.selector:IsShown() }
ns.CancelQuestLookup()
ns.db = ns.ReadConfig(nil)
QuestreihenTrackerDB = ns.db
ns.chain = ns.LiveData.Empty()
ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID = {}, nil
UI.Restore()
UI.frame:Show()
if UI.selector then UI.selector:Hide() end
UI.ChooseChain()
local panel = UI.selector
local chain = assert(ns.LiveData.Build(2248, { questLineID = 5506,
    questLineName = "Name-search UI fixture" }, { 78743, 78744 }))
ns.WoW.RegisterQuestLine(chain)
local verified = { kind = "QUEST_LINE", name = chain.name, selectable = true, chain = chain }
local criterion = { kind = "CRITERION", name = "Trauerhöhe criterion fixture",
    achievementName = "Unlock achievement fixture", completed = false, selectable = false }

local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Name-search UI / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end
local function click(button)
    button.scripts.OnClick(button, "LeftButton")
end
local function visibleButtons()
    local count = 0
    for _, button in ipairs(panel.buttons) do if button:IsShown() then count = count + 1 end end
    return count
end

test("typing cancels rather than submits a search", function()
    local calls = 0
    ns.WoW.SearchQuestLinesByName = function() calls = calls + 1; return {}, "EMPTY" end
    panel.nameInput:SetText("Trauerhöhe")
    panel.nameInput.scripts.OnTextChanged(panel.nameInput)
    assert(calls == 0 and ns.nameLookup == nil and ns.questLookup == nil)
end)

test("a submitted finite search shares the timer and stops when complete", function()
    local calls = 0
    ns.WoW.SearchQuestLinesByName = function(text)
        calls = calls + 1
        assert(text == "Trauerhöhe")
        return { verified, criterion }, calls == 1 and "LOADING" or "PARTIAL"
    end
    click(panel.nameSearchButton)
    assert(ns.nameLookup.status == "LOADING" and ns.chain.empty and #Mock.timers == 1)
    assert(visibleButtons() == 1 and panel.lookupStatus:GetText():find("Trauerhöhe", 1, true))
    Mock.Flush()
    assert(calls == 2 and ns.nameLookup.status == "PARTIAL" and #Mock.timers == 0)
    assert(ns.chain.empty and panel.refresh:GetText() == ns.L.NAME_BACK_ZONE)
end)

test("achievement criteria show context and progress without selecting a line", function()
    assert(visibleButtons() == 1)
    local text = panel.labels[1]:GetText()
    assert(text:find(criterion.name, 1, true) and text:find(criterion.achievementName, 1, true))
    assert(text:find(ns.L.NAME_NOT_DONE, 1, true) and text:find(ns.L.NAME_UNRESOLVED, 1, true))
    assert(ns.chain.empty and ns.db.liveSelection == nil)
end)

test("a confirmed line requires an explicit selection click", function()
    click(panel.buttons[1])
    assert(ns.chain.id == chain.id and ns.db.liveSelection.questLineID == chain.questLineID)
    assert(ns.nameLookup == nil and not panel:IsShown())
    Mock.Flush()
end)

test("Enter submits and pending membership remains informational", function()
    UI.ChooseChain()
    ns.WoW.SearchQuestLinesByName = function()
        return { { kind = "QUEST_LINE", name = "Pending line fixture", selectable = false, loading = true } }, "READY"
    end
    panel.nameInput.scripts.OnEnterPressed(panel.nameInput)
    assert(ns.nameLookup and visibleButtons() == 0)
    assert(panel.labels[1]:GetText():find("Pending line fixture", 1, true))
    assert(ns.chain.id == chain.id)
end)

test("editing cancels continuation before the next shared timer fires", function()
    local calls = 0
    ns.WoW.SearchQuestLinesByName = function()
        calls = calls + 1
        return {}, "LOADING"
    end
    click(panel.nameSearchButton)
    assert(calls == 1 and #Mock.timers == 1)
    panel.nameInput:SetText("Different text")
    panel.nameInput.scripts.OnTextChanged(panel.nameInput)
    Mock.Flush()
    assert(calls == 1 and ns.nameLookup == nil and #Mock.timers == 0)
    assert(panel.refresh:GetText() == ns.L.REFRESH_ZONE)
end)

test("editing a quest ID restores the zone view after completed name results", function()
    ns.WoW.SearchQuestLinesByName = function() return { verified, criterion }, "READY" end
    click(panel.nameSearchButton)
    assert(ns.nameLookup and visibleButtons() == 1 and panel.refresh:GetText() == ns.L.NAME_BACK_ZONE)
    panel.questIDInput:SetText("78743")
    panel.questIDInput.scripts.OnTextChanged(panel.questIDInput)
    assert(ns.nameLookup == nil and panel.refresh:GetText() == ns.L.REFRESH_ZONE)
    local choices = ns.WoW.ZoneQuestLines()
    assert(visibleButtons() == #choices and UI.notice:GetText() == ns.L.BLIZZARD_NOTICE)
    for _, label in ipairs(panel.labels) do
        assert(not label:IsShown() or not label:GetText():find(criterion.name, 1, true))
    end
end)

test("closing the selector cancels continuation", function()
    local calls = 0
    ns.WoW.SearchQuestLinesByName = function() calls = calls + 1; return {}, "LOADING" end
    click(panel.nameSearchButton)
    panel:Hide()
    Mock.Flush()
    assert(calls == 1 and ns.nameLookup == nil and #Mock.timers == 0)
    assert(UI.notice:GetText() == ns.L.BLIZZARD_NOTICE)
    UI.ChooseChain()
end)

test("returning to zone choices clears the submitted name query", function()
    ns.WoW.SearchQuestLinesByName = function() return {}, "EMPTY" end
    click(panel.nameSearchButton)
    assert(ns.nameLookup and panel.refresh:GetText() == ns.L.NAME_BACK_ZONE)
    click(panel.refresh)
    Mock.Flush()
    assert(ns.nameLookup == nil and panel.refresh:GetText() == ns.L.REFRESH_ZONE)
end)

test("achievement list events invalidate discovery without selecting or mutating quests", function()
    local original, reset = ns.WoW.OnNameSearchAchievementUpdate, nil
    ns.WoW.OnNameSearchAchievementUpdate = function(value) reset = value end
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "RECEIVED_ACHIEVEMENT_LIST")
    assert(reset == true)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "CRITERIA_UPDATE")
    assert(reset == nil)
    ns.WoW.OnNameSearchAchievementUpdate = original
    Mock.Flush()
end)

panel:Hide()
ns.CancelQuestLookup()
ns.WoW.SearchQuestLinesByName = saved.search
ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID = saved.maps, saved.currentMap
ns.db, ns.chain = saved.db, saved.chain
QuestreihenTrackerDB = ns.db
UI.Restore()
ns.WoW.ResetWarnings()
ns.Refresh()
UI.frame:SetShown(saved.shown)
if saved.selectorShown then UI.ChooseChain() end
Mock.Flush()
assert(Mock.mutationCount == 0 and Mock.invalidIDCalls == 0)
print("Name-search UI, explicit selection and finite continuation tests passed: " .. passed)
