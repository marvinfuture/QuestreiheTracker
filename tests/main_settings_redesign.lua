-- Native widget fixtures verify layout constraints and clicks; in-game glyphs remain a manual check.
-- Negative quest IDs are synthetic display nodes and must not reach Blizzard data APIs.
local ns, UI, L, passed = TEST_NS, TEST_NS.UI, TEST_NS.L, 0
local saved = { db = ns.db, chain = ns.chain, result = ns.result, snapshot = ns.snapshot }
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Main and settings redesign / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end
local function click(button)
    button.scripts.OnClick(button, "LeftButton")
end
local function configure(savedConfig)
    UI.Close()
    Mock.Flush()
    ns.db = ns.ReadConfig(savedConfig)
    QuestreihenTrackerDB = ns.db
    UI.Restore()
end
local function anchor(widget, target)
    for index = 1, widget:GetNumPoints() do
        local point, relative, relativePoint, x, y = widget:GetPoint(index)
        if point == target then return x, y, relative, relativePoint end
    end
    error("Missing anchor: " .. target)
end
local function renderTitle(title)
    ns.chain = { id = "synthetic-heading", name = title,
        sections = { { name = title, quests = { { questID = -1, title = "Synthetic title fixture" } } } } }
    ns.result = ns.Model.Evaluate(ns.chain, {})
    UI.Render(ns.result)
end

test("search action stays fixed while the loaded line appears between progress and count", function()
    configure({ size = { width = 320, height = 300 } })
    renderTitle("A wrapped quest-line title fixture that fills two lines")
    assert(UI.select:GetText() == L.SEARCH and UI.chainTitle:GetText() == ns.chain.name)
    assert(UI.trackedButton:GetText() == L.LOOKUP_TRACKED and UI.trackedButton:GetWidth() == 288)
    assert(UI.clearButton:GetText() == L.CLEAR_SELECTION and UI.clearButton:IsEnabled())
    local _, barY = anchor(UI.bar, "TOPLEFT")
    local _, titleY = anchor(UI.chainTitle, "TOPLEFT")
    local _, countY = anchor(UI.count, "TOPLEFT")
    local _, noticeY = anchor(UI.notice, "TOPLEFT")
    local _, scrollY = anchor(UI.scroll, "TOPLEFT")
    assert(-barY + UI.bar:GetHeight() < -titleY)
    assert(-titleY + UI.chainTitle:GetHeight() < -countY)
    assert(-countY + UI.count:GetHeight() <= -noticeY)
    assert(-noticeY + UI.notice:GetHeight() < -scrollY)
    assert(UI.chainTitle:GetHeight() >= UI.chainTitle:GetStringHeight())
    assert(UI.frame:GetHeight() + scrollY - 24 >= 40, "Quest list must retain room at minimum size")
    UI.chainTitleHost.scripts.OnEnter(UI.chainTitleHost)
    assert(GameTooltip:GetText() == ns.chain.name)
    UI.chainTitleHost.scripts.OnLeave(UI.chainTitleHost)
    assert(not GameTooltip:IsShown())
end)

test("resizing reflows the line heading and removing a line clears that heading", function()
    local compactHeight = UI.chainTitle:GetHeight()
    UI.frame:SetSize(820, 500)
    assert(UI.chainTitle:GetWidth() == 788 and UI.chainTitle:GetHeight() < compactHeight)
    ns.ClearSelection()
    assert(UI.chainTitle:GetText() == "" and not UI.chainTitle:IsShown())
    assert(not UI.chainTitleHost:IsShown() and UI.select:GetText() == L.SEARCH)
    assert(not UI.clearButton:IsEnabled() and UI.count:GetText() == L.NO_SELECTION)
end)

test("title controls use Blizzard templates and their close callbacks preserve explicit intent", function()
    assert(UI.settingsButton.template == "SquareIconButtonTemplate")
    assert(UI.closeButton.template == "UIPanelCloseButton")
    assert(UI.settings.closeButton.template == "UIPanelCloseButton")
    local closes = 0
    for _, frame in ipairs(Mock.frames) do
        if rawget(frame, "parent") == UI.frame and rawget(frame, "template") == "UIPanelCloseButton" then
            closes = closes + 1
        end
    end
    assert(closes == 1, "The main window must have exactly one close control with explicit close intent")
    UI.Open()
    click(UI.settingsButton)
    assert(UI.settings:IsShown() and UI.frame:IsShown())
    click(UI.settings.closeButton)
    assert(not UI.settings:IsShown() and UI.frame:IsShown() and ns.db.windowOpen)
    click(UI.closeButton)
    Mock.Flush()
    assert(not UI.frame:IsShown() and not ns.db.windowOpen)
end)

test("settings pair choices are labeled separately and selecting the active choice is idempotent", function()
    configure(nil)
    local labels = { chatWarnings = L.SETTING_CHAT, screenWarnings = L.SETTING_SCREEN,
        keepWindowOpen = L.SETTING_KEEP_OPEN }
    for key, label in pairs(labels) do
        local row = UI.settingsRows[key]
        assert(row.label:GetText() == label)
        assert(row.onButton:GetText() == L.SETTING_ON and row.offButton:GetText() == L.SETTING_OFF)
        assert(row.onButton.selected and not row.offButton.selected)
        assert(row.onButton.selection:IsShown() and not row.offButton.selection:IsShown())
        assert(row.onButton.buttonState == "PUSHED" and row.onButton.buttonStateLocked)
        assert(row.offButton.buttonState == "NORMAL" and not row.offButton.buttonStateLocked)
        local _, rowY = anchor(row, "TOPLEFT")
        assert(-rowY + row:GetHeight() < UI.settings:GetHeight())
        local groupX = row:GetWidth() - row.group:GetWidth()
        assert(row.label:GetWidth() < groupX, "Setting label must leave an explicit gap before the choices")
        click(row.onButton)
        assert(ns.db[key] == true and row.onButton.selected and not row.offButton.selected)
        click(row.offButton)
        assert(ns.db[key] == false and not row.onButton.selected and row.offButton.selected)
        click(row.offButton)
        assert(ns.db[key] == false and not row.onButton.selected and row.offButton.selected)
    end
    local config = ns.ReadConfig(QuestreihenTrackerDB)
    configure(config)
    for key in pairs(labels) do
        assert(ns.db[key] == false and UI.settingsRows[key].offButton.selected)
    end
end)

test("dismissed warning retires its deadline and retains a separate queued refresh", function()
    configure({ screenWarnings = true })
    UI.ShowWarning("Synthetic warning fixture")
    assert(UI.warning:IsShown() and UI.warning.closeButton.template == "UIPanelCloseButton")
    ns.ScheduleRefresh()
    local timer, due = ns.timer, ns.refreshDue
    assert(timer and due and #Mock.timers == 1)
    click(UI.warning.closeButton)
    assert(not UI.warning:IsShown() and UI.warningExpires == nil)
    assert(ns.timer == timer and ns.timerDue == due and ns.pending and #Mock.timers == 1)
    Mock.Flush()
    assert(#Mock.timers == 0 and ns.timer == nil and not ns.pending)
    UI.ShowWarning("Synthetic warning fixture without pending refresh")
    local expiryTimer = assert(ns.timer)
    click(UI.warning.closeButton)
    assert(expiryTimer:IsCancelled() and #Mock.timers == 0 and UI.warningExpires == nil)
    assert(ns.db.screenWarnings, "Dismissing one banner must keep future warnings enabled")
end)

UI.ClearWarning()
ns.ScheduleWarningExpiry()
UI.Close()
Mock.Flush()
ns.db, ns.chain, ns.result, ns.snapshot = saved.db, saved.chain, saved.result, saved.snapshot
QuestreihenTrackerDB = ns.db
UI.Restore()
UI.Render(ns.result)
assert(Mock.invalidIDCalls == 0 and Mock.mutationCount == 0)
for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
print("Main heading, native controls and separated settings tests passed: " .. passed)
