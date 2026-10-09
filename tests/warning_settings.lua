-- Widget/API fixtures establish wiring and persistence, not real-client layout or taint behavior.
-- Quest IDs: https://www.wowhead.com/quest=78743, /quest=78562 and /quest=78563.
local ns, UI, passed = TEST_NS, TEST_NS.UI, 0
Mock.Flush()
local saved = { db = ns.db, chain = ns.chain, errors = UIErrorsFrame, shown = UI.frame:IsShown() }
local mockKeys = { "active", "completed", "watched", "worldWatched", "tasks", "taskInfo",
    "messages", "warnings", "titles", "warningCount", "superTrackedQuestID",
    "isSuperTrackingQuest", "highestPrioritySuperTrackingType" }
for _, key in ipairs(mockKeys) do saved[key] = Mock[key] end
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Chat-warning settings / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end
local function click()
    local button = UI.chatWarningsButton
    button.scripts.OnClick(button, "LeftButton")
end
local function config(value)
    ns.db = ns.ReadConfig(value)
    QuestreihenTrackerDB = ns.db
    UI.Restore()
end

test("new and legacy configurations default to chat on; only booleans are retained", function()
    for _, value in ipairs({ {}, { schemaVersion = 6 }, { chatWarnings = "false" },
        { chatWarnings = 0 }, { chatWarnings = 1 }, { chatWarnings = {} } }) do
        assert(ns.ReadConfig(value).chatWarnings == true)
    end
    assert(ns.ReadConfig(nil).chatWarnings == true)
    assert(ns.ReadConfig({ chatWarnings = false }).chatWarnings == false)
    assert(ns.ReadConfig({ chatWarnings = true }).chatWarnings == true)
end)

test("main-window callback changes the saved preference and its visible label", function()
    config(nil)
    assert(UI.chatWarningsButton.parent == UI.frame and UI.chatWarningsButton:IsEnabled())
    assert(UI.chatWarningsButton:GetText() == ns.L.CHAT_WARNINGS_ON)
    click()
    assert(ns.db.chatWarnings == false and QuestreihenTrackerDB.chatWarnings == false)
    assert(UI.chatWarningsButton:GetText() == ns.L.CHAT_WARNINGS_OFF)
    local persisted = ns.ReadConfig(QuestreihenTrackerDB)
    assert(persisted ~= ns.db and persisted.chatWarnings == false)
    config(persisted)
    assert(UI.chatWarningsButton:GetText() == ns.L.CHAT_WARNINGS_OFF)
    click()
    assert(ns.db.chatWarnings == true and UI.chatWarningsButton:GetText() == ns.L.CHAT_WARNINGS_ON)
end)

test("both actions share one row at minimum dimensions", function()
    config({ chatWarnings = false, size = { width = 320, height = 300 } })
    assert(UI.trackedButton:GetWidth() == 140 and UI.chatWarningsButton:GetWidth() == 140)
    local trackedPoint, _, _, trackedX, trackedY = UI.trackedButton:GetPoint()
    local chatPoint, _, _, chatX, chatY = UI.chatWarningsButton:GetPoint()
    assert(trackedPoint == "TOPLEFT" and trackedX == 16 and trackedY == -74)
    assert(chatPoint == "TOPRIGHT" and chatX == -16 and chatY == trackedY)
    assert(UI.frame:GetHeight() == 300)
end)

test("chat off keeps the banner; chat on affects the next activity without duplicates", function()
    config({ chatWarnings = false })
    ns.chain = assert(ns.LiveData.Build(2248, { questLineID = 5506,
        questLineName = "Chat toggle fixture" }, { 78743 }))
    ns.WoW.RegisterQuestLine(ns.chain)
    for _, key in ipairs({ "active", "completed", "watched", "worldWatched", "tasks",
        "taskInfo", "messages", "warnings", "titles" }) do Mock[key] = {} end
    Mock.warningCount = 0
    Mock.superTrackedQuestID, Mock.isSuperTrackingQuest = nil, false
    Mock.titles[78562], Mock.titles[78563] = "First toggle fixture", "Second toggle fixture"
    local nativeMessages = 0
    UIErrorsFrame = { AddMessage = function() nativeMessages = nativeMessages + 1 end,
        GetTimeVisible = function() return 2 end, GetFadeDuration = function() return 0.5 end }
    ns.WoW.ResetWarnings()
    Mock.active[78562] = true
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUEST_ACCEPTED", 78562)
    Mock.Advance(0.1)
    assert(UI.warning:IsShown() and UI.warning.message:GetText():find("First toggle fixture", 1, true))
    assert(#Mock.messages == 0 and nativeMessages == 0)
    local firstMessage, firstExpiry = UI.warning.message:GetText(), UI.warningExpires
    click()
    ns.WoW.WarnActivities()
    assert(#Mock.messages == 0 and UI.warning.message:GetText() == firstMessage)
    assert(UI.warningExpires == firstExpiry, "Toggling must not rearm the existing warning")
    Mock.active[78563] = true
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUEST_ACCEPTED", 78563)
    Mock.Advance(0.1)
    assert(#Mock.messages == 1 and Mock.messages[1]:find("Second toggle fixture", 1, true))
    assert(UI.warning:IsShown() and UI.warning.message:GetText():find("Second toggle fixture", 1, true))
    assert(nativeMessages == 0, "The extra native text above the banner must stay removed")
    click()
    local before = #Mock.messages
    ns.Debug()
    assert(#Mock.messages > before, "The switch must not suppress diagnostic output")
    before = #Mock.messages
    ns.TrackQuest(78743)
    assert(#Mock.messages == before + 1 and Mock.messages[#Mock.messages]:find(ns.L.WATCH_NOT_ACTIVE, 1, true),
        "The switch must not suppress failed-click feedback")
    Mock.Flush()
end)

test("reset restores the default and refreshes the button", function()
    assert(ns.db.chatWarnings == false)
    ns.Slash("reset")
    assert(ns.db.chatWarnings == true and QuestreihenTrackerDB.chatWarnings == true)
    assert(UI.chatWarningsButton:GetText() == ns.L.CHAT_WARNINGS_ON)
    Mock.Flush()
end)

UI.ClearWarning()
ns.ScheduleWarningExpiry()
ns.db, ns.chain, UIErrorsFrame = saved.db, saved.chain, saved.errors
QuestreihenTrackerDB = ns.db
for _, key in ipairs(mockKeys) do Mock[key] = saved[key] end
ns.WoW.ResetWarnings()
UI.Restore()
ns.Refresh()
UI.frame:SetShown(saved.shown)
Mock.Flush()
assert(Mock.mutationCount == 0 and Mock.invalidIDCalls == 0)
print("Chat-warning preference, button and output tests passed: " .. passed)
