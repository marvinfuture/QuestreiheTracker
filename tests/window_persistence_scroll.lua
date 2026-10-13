-- Isolated widget fixtures verify behavior; real talent/teleport/layout tests remain manual.
-- Negative quest IDs below are synthetic display nodes and must never reach game APIs.
local ns, UI, passed = TEST_NS, TEST_NS.UI, 0
Enum = { SuperTrackingType = { Quest = 0 } }
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Window persistence and scroll / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end
local function click(button)
    button.scripts.OnClick(button, "LeftButton")
end
-- Click the inactive choice to change a setting through the actual native control.
local function changeSetting(key)
    local row = UI.settingsRows[key]
    click(ns.db[key] and row.offButton or row.onButton)
end
local function specialCount()
    local count = 0
    for _, name in ipairs(UISpecialFrames) do
        if name == "QuestreihenTrackerFrame" then count = count + 1 end
    end
    return count
end
local function configure(saved)
    UI.Close()
    Mock.Flush()
    ns.db = ns.ReadConfig(saved)
    QuestreihenTrackerDB = ns.db
    UI.Restore()
end

test("new preferences are validated and a new installation stays closed", function()
    assert(ns.db.schemaVersion == 9 and ns.db.keepWindowOpen and not ns.db.windowOpen)
    assert(not UI.frame:IsShown() and specialCount() == 0)
    for _, invalid in ipairs({ "true", 1, 0, {} }) do
        local config = ns.ReadConfig({ keepWindowOpen = invalid, windowOpen = invalid })
        assert(config.keepWindowOpen == true and config.windowOpen == false)
    end
    local config = ns.ReadConfig({ keepWindowOpen = false, windowOpen = true })
    assert(config.keepWindowOpen == false and config.windowOpen == true)
end)

test("gear opens three independent controls and closing settings retains the main window", function()
    UI.Open()
    click(UI.settingsButton)
    assert(UI.settings:IsShown() and UI.frame:IsShown())
    assert(UI.chatWarningsButton.parent == UI.settings and UI.screenWarningsButton.parent == UI.settings)
    assert(UI.keepWindowOpenButton.parent == UI.settings)
    assert(UI.settingsButton.icon.atlasValue == "common-dropdown-a-button-settings-shadowless")
    changeSetting("chatWarnings")
    assert(not ns.db.chatWarnings and ns.db.screenWarnings and ns.db.keepWindowOpen)
    changeSetting("screenWarnings")
    assert(not ns.db.screenWarnings and not ns.db.chatWarnings and ns.db.keepWindowOpen)
    click(UI.settings.closeButton)
    assert(not UI.settings:IsShown() and UI.frame:IsShown() and ns.db.windowOpen)
    click(UI.settingsButton)
    UI.Close()
    assert(not UI.settings:IsShown() and not UI.frame:IsShown())
end)

test("unrelated hides recover on one coalesced timer without permanently polling", function()
    configure(nil)
    UI.Open()
    UI.frame:Hide()
    assert(not UI.frame:IsShown() and ns.db.windowOpen and #Mock.timers == 1)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_ENTERING_WORLD", false, false)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ZONE_CHANGED_NEW_AREA")
    assert(#Mock.timers == 1)
    Mock.Flush()
    assert(UI.frame:IsShown() and ns.db.windowOpen and #Mock.timers == 0)
    assert(UI.frame.scripts.OnUpdate == nil)
end)

test("explicit X minimap and slash closes stay closed after queued refresh and world events", function()
    local actions = {
        function() click(UI.closeButton) end,
        function() ns.Minimap.button.scripts.OnClick(ns.Minimap.button, "LeftButton") end,
        function() ns.Slash("") end,
    }
    for _, close in ipairs(actions) do
        UI.Open()
        ns.ScheduleRefresh()
        close()
        assert(not UI.frame:IsShown() and not ns.db.windowOpen)
        ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_ENTERING_WORLD", false, false)
        Mock.Flush()
        assert(not UI.frame:IsShown() and not ns.db.windowOpen and #Mock.timers == 0)
        local reloaded = ns.ReadConfig(QuestreihenTrackerDB)
        assert(reloaded.keepWindowOpen and not reloaded.windowOpen)
    end
end)

test("saved open state restores only while enabled and reset restores default closed state", function()
    configure({ keepWindowOpen = true, windowOpen = true })
    assert(UI.frame:IsShown() and ns.db.windowOpen and specialCount() == 0)
    configure({ keepWindowOpen = false, windowOpen = true })
    assert(not UI.frame:IsShown() and specialCount() == 1)
    UI.Open()
    UI.frame:Hide()
    Mock.Flush()
    assert(not UI.frame:IsShown() and not ns.db.windowOpen)
    ns.Slash("reset")
    assert(ns.db.keepWindowOpen and not ns.db.windowOpen and not UI.frame:IsShown())
    assert(specialCount() == 0 and UI.keepWindowOpenButton.onButton.selected)
end)

test("turning persistence on follows the current window state and removes only its own special entries", function()
    configure({ keepWindowOpen = false })
    UISpecialFrames[#UISpecialFrames + 1] = "UnrelatedFixtureFrame"
    UISpecialFrames[#UISpecialFrames + 1] = "QuestreihenTrackerFrame"
    changeSetting("keepWindowOpen")
    assert(ns.db.keepWindowOpen and not ns.db.windowOpen and specialCount() == 0)
    assert(UISpecialFrames[1] == "UnrelatedFixtureFrame")
    UI.Open()
    changeSetting("keepWindowOpen")
    assert(not ns.db.keepWindowOpen and ns.db.windowOpen and specialCount() == 1)
    UI.UpdateWindowPersistence()
    assert(specialCount() == 1)
    changeSetting("keepWindowOpen")
    assert(ns.db.keepWindowOpen and ns.db.windowOpen and UI.frame:IsShown() and specialCount() == 0)
    UI.Close()
end)

test("settings dialog position persists and invalid geometry is discarded", function()
    click(UI.settingsButton)
    UI.settings.scripts.OnDragStart(UI.settings)
    UI.settings:ClearAllPoints()
    UI.settings:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 48, -92)
    UI.settings.scripts.OnDragStop(UI.settings)
    local config = ns.ReadConfig(QuestreihenTrackerDB)
    assert(config.panelPositions.settings.x == 48 and config.panelPositions.settings.y == -92)
    assert(ns.ReadConfig({ panelPositions = { settings = { point = "bad" } } }).panelPositions.settings == nil)
    UI.settings:Hide()
end)

test("explicit close cancels delayed lookup so late data cannot reopen the window", function()
    UI.Open()
    ns.LookupQuest(78743)
    assert(ns.questLookup and ns.questLookup.pending)
    UI.Close()
    assert(ns.questLookup == nil and ns.nameLookup == nil and not ns.db.windowOpen)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUESTLINE_UPDATE", false)
    Mock.Flush()
    assert(not UI.frame:IsShown() and not ns.db.windowOpen)
end)

test("a temporarily hidden UI parent retains the user's open choice without a timer loop", function()
    UI.Open()
    UIParent:Hide()
    -- Model the child's OnHide notification while its own shown state remains true.
    UI.frame.scripts.OnHide(UI.frame)
    Mock.Flush()
    assert(not UIParent:IsShown() and UI.frame:IsShown() and ns.db.windowOpen and #Mock.timers == 0)
    UIParent:Show()
    UI.Close()
end)

test("acceptance and successful clicks select only currently displayed member quests", function()
    -- Real quest fixtures are documented in docs/DATA_SOURCES.md; no IDs are invented.
    ns.chain = assert(ns.LiveData.Build(2248, { questLineID = 5506,
        questLineName = "Event focus fixture" }, { 78743, 78744 }))
    UI.focusQuestID = nil
    Mock.active[78743], Mock.active[78744] = true, true
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUEST_ACCEPTED", 78743)
    assert(UI.focusQuestID == 78743)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUEST_ACCEPTED", 78562)
    assert(UI.focusQuestID == 78743)
    ns.TrackQuest(78744)
    assert(UI.focusQuestID == 78744)
    Mock.active[78743] = false
    ns.TrackQuest(78743)
    assert(UI.focusQuestID == 78744)
    Mock.Flush()
    UI.Close()
end)

local chain = { id = "synthetic-scroll", name = "Synthetic display fixture", sections = {} }
for sectionIndex = 1, 2 do
    local section = { name = "Section fixture " .. sectionIndex, quests = {} }
    for index = 1, 8 do
        local number = (sectionIndex - 1) * 8 + index
        section.quests[index] = { questID = -number, title = "Synthetic quest " .. number }
    end
    chain.sections[sectionIndex] = section
end
local function render(active, completed)
    ns.chain = chain
    ns.result = ns.Model.Evaluate(chain, { active = active or {}, completed = completed or {} })
    UI.Render(ns.result)
end
local function questRow(id)
    for _, row in ipairs(UI.renderedRows) do if row.hasQuest and row.questID == id then return row end end
    error("Fixture row not found")
end
local function visible(id)
    local row, position = questRow(id), UI.scroll:GetVerticalScroll()
    assert(row.offset >= position and row.offset + row:GetHeight() <= position + UI.scroll:GetHeight())
    assert(UI.scroll.ScrollBar.value == position)
    assert(position >= 0 and position <= math.max(0, UI.content:GetHeight() - UI.scroll:GetHeight()))
end

test("active quests below the viewport scroll into view with section headers and a synchronized thumb", function()
    UI.scroll:SetHeight(90)
    UI.scroll:SetVerticalScroll(0)
    UI.focusQuestID = nil
    render({ [-12] = true })
    visible(-12)
    assert(UI.scroll:GetVerticalScroll() > 0 and UI.scroll.scrollChildUpdates > 0)
end)

test("focused active quest wins and invalid or completed focus falls back to first accepted quest", function()
    UI.focusQuestID = -15
    render({ [-3] = true, [-15] = true })
    visible(-15)
    UI.focusQuestID = -99
    render({ [-3] = true, [-15] = true })
    visible(-3)
    UI.focusQuestID = -15
    render({ [-3] = true }, { [-15] = true })
    visible(-3)
end)

test("currently accepted repeatable quests stay eligible despite historical completion", function()
    UI.focusQuestID = -15
    render({ [-3] = true, [-15] = true }, { [-15] = true })
    assert(ns.result.byID[-15].accepted and ns.result.byID[-15].progressStatus == "COMPLETED")
    visible(-15)
end)

test("already visible rows preserve manual position and wrapped titles stay fully visible", function()
    UI.focusQuestID = -12
    render({ [-12] = true })
    local position = UI.scroll:GetVerticalScroll()
    render({ [-12] = true })
    assert(UI.scroll:GetVerticalScroll() == position)
    chain.sections[2].quests[4].title = string.rep("Wrapped fixture title ", 5)
    UI.frame:SetSize(320, 300)
    UI.scroll:SetHeight(73)
    render({ [-12] = true })
    visible(-12)
    assert(questRow(-12).text:GetHeight() == 32)
end)

test("no active quest preserves scroll and shrinking content clamps it within range", function()
    UI.scroll:SetVerticalScroll(100)
    render({})
    assert(UI.scroll:GetVerticalScroll() == 100 and UI.scroll.ScrollBar.value == 100)
    local sections = chain.sections
    chain.sections = { { name = "Short fixture", quests = { sections[1].quests[1] } } }
    render({})
    assert(UI.scroll:GetVerticalScroll() == 0 and UI.scroll.ScrollBar.maximum == 0)
    chain.sections = sections
end)

assert(Mock.invalidIDCalls == 0 and Mock.mutationCount == 0)
for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
print("Window persistence, settings and automatic-scroll tests passed: " .. passed)
