-- Offline fixtures verify preference wiring and warning behavior, not client layout or taint.
-- Quest IDs: https://www.wowhead.com/quest=78743, /quest=78562 and /quest=78563.
local ns, UI, passed = TEST_NS, TEST_NS.UI, 0
Mock.Flush()
local saved = {
    db = ns.db, savedDB = QuestreihenTrackerDB, chain = ns.chain,
    snapshot = ns.snapshot, result = ns.result, questLookup = ns.questLookup, nameLookup = ns.nameLookup,
    adapterQuestLookup = ns.WoW.questLookup, pending = ns.pending, refreshDue = ns.refreshDue,
    warnings = ns.WoW.warnings, offers = ns.WoW.offers,
    requested = ns.WoW.requested, failedRequests = ns.WoW.failedRequests,
    maps = ns.WoW.questLines.maps, currentMapID = ns.WoW.questLines.currentMapID,
    errors = UIErrorsFrame, shown = UI.frame:IsShown(), warningDuration = UI.warningDuration,
    warningMessage = UI.warning and UI.warning.message:GetText(),
    selectorShown = UI.selector and UI.selector:IsShown(), linkShown = UI.link and UI.link:IsShown(),
}
local mockKeys = { "active", "completed", "watched", "worldWatched", "tasks", "taskInfo",
    "messages", "warnings", "titles", "warningCount", "superTrackedQuestID",
    "isSuperTrackingQuest", "highestPrioritySuperTrackingType", "questLinesByMap",
    "questLineQuests", "mapInfos", "requests", "now", "lastMessage", "calls",
    "mapReads", "lineReads", "trackedReads", "trackingKindReads", "priorityReads" }
for _, key in ipairs(mockKeys) do saved["mock_" .. key] = Mock[key] end

-- Preserve surrounding test state and retire every deadline introduced by this file.
local function restore()
    UI.ClearWarning()
    ns.ScheduleWarningExpiry()
    Mock.Flush()
    ns.db, QuestreihenTrackerDB, ns.chain = saved.db, saved.savedDB, saved.chain
    ns.snapshot, ns.result = saved.snapshot, saved.result
    ns.questLookup, ns.nameLookup = saved.questLookup, saved.nameLookup
    ns.WoW.questLookup, ns.pending, ns.refreshDue = saved.adapterQuestLookup, saved.pending, saved.refreshDue
    ns.WoW.warnings, ns.WoW.offers = saved.warnings, saved.offers
    ns.WoW.requested, ns.WoW.failedRequests = saved.requested, saved.failedRequests
    ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID = saved.maps, saved.currentMapID
    UIErrorsFrame, UI.warningDuration = saved.errors, saved.warningDuration
    if UI.warning and saved.warningMessage then UI.warning.message:SetText(saved.warningMessage) end
    for _, key in ipairs(mockKeys) do Mock[key] = saved["mock_" .. key] end
    UI.Restore()
    UI.Render(ns.result)
    UI.RenderSelector()
    if saved.shown then UI.Open() else UI.Close() end
    if UI.selector then UI.selector:SetShown(saved.selectorShown == true) end
    if UI.link then UI.link:SetShown(saved.linkShown == true) end
    assert(#Mock.timers == 0 and ns.timer == nil and ns.timerDue == nil)
end

-- Attach context to failures while counting independent behavior checks.
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Screen-warning settings / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end

-- Invoke the real screen-setting callback through its native button fixture.
local function clickScreen()
    local row = UI.settingsRows.screenWarnings
    local button = ns.db.screenWarnings and row.offButton or row.onButton
    button.scripts.OnClick(button, "LeftButton")
end

-- Report banner visibility even before the first warning widget has been created.
local function bannerShown()
    return UI.warning ~= nil and UI.warning:IsShown()
end

-- Install a clean loaded line and independent preferences for each output scenario.
local function prepare(chat, screen)
    UI.ClearWarning()
    ns.ScheduleWarningExpiry()
    Mock.Flush()
    ns.db = ns.ReadConfig({ chatWarnings = chat, screenWarnings = screen })
    QuestreihenTrackerDB = ns.db
    ns.questLookup, ns.nameLookup = nil, nil
    ns.WoW.requested, ns.WoW.failedRequests, ns.WoW.offers = {}, {}, {}
    ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID = {}, nil
    ns.chain = assert(ns.LiveData.Build(2248, { questLineID = 5506,
        questLineName = "Independent warning settings fixture" }, { 78743 }))
    ns.WoW.RegisterQuestLine(ns.chain)
    for _, key in ipairs({ "active", "completed", "watched", "worldWatched", "tasks",
        "taskInfo", "messages", "warnings", "titles", "questLinesByMap", "mapInfos", "requests" }) do
        Mock[key] = {}
    end
    Mock.questLineQuests = { [5506] = { 78743 } }
    Mock.titles[78562], Mock.titles[78563] = "First screen fixture", "Second screen fixture"
    Mock.warningCount = 0
    Mock.superTrackedQuestID, Mock.isSuperTrackingQuest = nil, false
    Mock.highestPrioritySuperTrackingType = nil
    UIErrorsFrame = {
        -- Detect any accidental restoration of the extra native warning text.
        AddMessage = function() Mock.warningCount = Mock.warningCount + 1 end,
        -- Supply a deterministic native duration used by the independent banner.
        GetTimeVisible = function() return 2 end,
        -- Supply the fade component of that native duration.
        GetFadeDuration = function() return 0.5 end,
    }
    ns.WoW.ResetWarnings()
    UI.Restore()
end

-- Dispatch a real acceptance event and let the shared refresh timer process it.
local function accept(questID)
    Mock.active[questID] = true
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUEST_ACCEPTED", questID)
    Mock.Advance(0.1)
end

local ok, message = pcall(function()
    test("schema 9 defaults on and retains only explicit boolean preferences", function()
        for _, value in ipairs({ {}, { schemaVersion = 7 }, { screenWarnings = "false" },
            { screenWarnings = 0 }, { screenWarnings = 1 }, { screenWarnings = {} } }) do
            local config = ns.ReadConfig(value)
            assert(config.schemaVersion == 9 and config.screenWarnings == true)
        end
        assert(ns.ReadConfig(nil).screenWarnings == true)
        assert(ns.ReadConfig(false).screenWarnings == true)
        assert(ns.ReadConfig({ screenWarnings = false }).screenWarnings == false)
        assert(ns.ReadConfig({ screenWarnings = true }).screenWarnings == true)
        local config = ns.ReadConfig({ chatWarnings = false })
        assert(config.chatWarnings == false and config.screenWarnings == true)
    end)

    test("choices persist independently and restore their selected state after reload", function()
        prepare(false, true)
        assert(UI.screenWarningsButton.parent == UI.settings and UI.screenWarningsButton.onButton:IsEnabled())
        assert(UI.screenWarningsButton:GetWidth() == 368)
        local point, _, _, x, y = UI.screenWarningsButton:GetPoint()
        assert(point == "TOPLEFT" and x == 16 and y == -92)
        assert(UI.screenWarningsButton.label:GetText() == ns.L.SETTING_SCREEN)
        assert(UI.screenWarningsButton.onButton.selected and not UI.screenWarningsButton.offButton.selected)
        clickScreen()
        assert(ns.db.screenWarnings == false and QuestreihenTrackerDB.screenWarnings == false)
        assert(ns.db.chatWarnings == false and UI.screenWarningsButton.offButton.selected)
        local reloaded = ns.ReadConfig(QuestreihenTrackerDB)
        assert(reloaded ~= ns.db and reloaded.schemaVersion == 9)
        assert(reloaded.chatWarnings == false and reloaded.screenWarnings == false)
        ns.db, QuestreihenTrackerDB = reloaded, reloaded
        UI.Restore()
        assert(UI.screenWarningsButton.offButton.selected and not UI.screenWarningsButton.onButton.selected)
        assert(UI.chatWarningsButton.offButton.selected and not UI.chatWarningsButton.onButton.selected)
        clickScreen()
        assert(ns.db.screenWarnings == true and ns.db.chatWarnings == false)
        assert(UI.screenWarningsButton.onButton.selected and not UI.screenWarningsButton.offButton.selected)
    end)

    for _, flags in ipairs({ { false, false }, { false, true }, { true, false }, { true, true } }) do
        local chat, screen = flags[1], flags[2]
        test("independent outputs: chat=" .. tostring(chat) .. ", screen=" .. tostring(screen), function()
            prepare(chat, screen)
            accept(78562)
            assert(#Mock.messages == (chat and 1 or 0))
            assert(bannerShown() == screen)
            assert((UI.warningExpires ~= nil) == screen)
            assert(#Mock.timers == (screen and 1 or 0))
            if chat then assert(Mock.messages[1]:find("First screen fixture", 1, true)) end
            if screen then assert(UI.warning.message:GetText():find("First screen fixture", 1, true)) end
            local deadline = UI.warningExpires
            ns.WoW.WarnActivities()
            assert(#Mock.messages == (chat and 1 or 0) and UI.warningExpires == deadline)
            assert(Mock.warningCount == 0, "Banner preferences must never emit extra native warning text")
            Mock.Flush()
            assert(not bannerShown() and UI.warningExpires == nil and #Mock.timers == 0)
        end)
    end

    test("toggle off immediately hides the banner and cancels its shared expiry timer", function()
        prepare(true, true)
        accept(78562)
        local timer = assert(ns.timer)
        assert(bannerShown() and UI.warningExpires and #Mock.timers == 1)
        clickScreen()
        assert(ns.db.screenWarnings == false and ns.db.chatWarnings == true)
        assert(not bannerShown() and UI.warningExpires == nil)
        assert(timer:IsCancelled() and ns.timer == nil and ns.timerDue == nil and #Mock.timers == 0)
        assert(#Mock.messages == 1)
    end)

    test("toggle off retains an independently pending coalesced refresh", function()
        prepare(true, true)
        accept(78562)
        ns.ScheduleRefresh()
        local timer, due = assert(ns.timer), ns.refreshDue
        clickScreen()
        assert(not bannerShown() and UI.warningExpires == nil)
        assert(ns.timer == timer and ns.timerDue == due and #Mock.timers == 1)
        assert(not timer:IsCancelled() and ns.pending == true)
        Mock.Advance(0.1)
        assert(#Mock.timers == 0 and ns.timer == nil and ns.pending == false and ns.refreshDue == nil)
        assert(#Mock.messages == 1 and not bannerShown())
    end)

    test("toggle on does not replay activity observed while banners were disabled", function()
        prepare(false, false)
        accept(78562)
        clickScreen()
        assert(ns.db.screenWarnings == true and ns.db.chatWarnings == false)
        assert(not bannerShown() and UI.warningExpires == nil and #Mock.timers == 0)
        ns.WoW.WarnActivities()
        ns.ScheduleRefresh()
        Mock.Advance(0.1)
        assert(not bannerShown() and UI.warningExpires == nil and #Mock.timers == 0)
        assert(#Mock.messages == 0)
        accept(78563)
        assert(bannerShown() and UI.warning.message:GetText():find("Second screen fixture", 1, true))
        assert(#Mock.messages == 0 and #Mock.timers == 1)
        Mock.Flush()
    end)

    test("turning a shown banner off and on cannot rearm its previous activity", function()
        prepare(false, true)
        accept(78562)
        clickScreen()
        clickScreen()
        ns.WoW.WarnActivities()
        assert(not bannerShown() and UI.warningExpires == nil and #Mock.timers == 0)
        assert(#Mock.messages == 0)
    end)

    test("clearing a selection retains every combination of warning preferences", function()
        for _, flags in ipairs({ { false, false }, { false, true }, { true, false }, { true, true } }) do
            prepare(flags[1], flags[2])
            ns.ClearSelection()
            assert(ns.chain.empty and ns.db.selectedChain == "none")
            assert(ns.db.chatWarnings == flags[1] and ns.db.screenWarnings == flags[2])
            local reloaded = ns.ReadConfig(QuestreihenTrackerDB)
            assert(reloaded.chatWarnings == flags[1] and reloaded.screenWarnings == flags[2])
            assert(not bannerShown() and UI.warningExpires == nil and #Mock.timers == 0)
        end
    end)

    test("reset restores both default-on choices and both visible labels", function()
        prepare(false, false)
        ns.Slash("reset")
        assert(ns.db.schemaVersion == 9 and ns.db.chatWarnings == true and ns.db.screenWarnings == true)
        assert(QuestreihenTrackerDB.chatWarnings == true and QuestreihenTrackerDB.screenWarnings == true)
        assert(UI.chatWarningsButton.onButton.selected and not UI.chatWarningsButton.offButton.selected)
        assert(UI.screenWarningsButton.onButton.selected and not UI.screenWarningsButton.offButton.selected)
        assert(ns.chain.empty and not bannerShown() and UI.warningExpires == nil and #Mock.timers == 0)
    end)
end)
restore()
assert(ok, message)
assert(Mock.mutationCount == 0 and Mock.invalidIDCalls == 0)
print("Independent screen-warning preference, output and timer tests passed: " .. passed)
