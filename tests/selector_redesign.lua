-- Focused native-widget fixtures verify search/zone wiring; real client layout remains manual.
-- Real membership fixtures: https://www.wowhead.com/quest=78743 and /quest=78744.
local ns, UI, L, passed = TEST_NS, TEST_NS.UI, TEST_NS.L, 0
Mock.Flush()
local saved = { db = ns.db, chain = ns.chain, snapshot = ns.snapshot, result = ns.result,
    questLookup = ns.questLookup, nameLookup = ns.nameLookup, feedback = UI.searchFeedback,
    shown = UI.frame:IsShown(), selectorShown = UI.selector and UI.selector:IsShown(), enum = Enum,
    search = ns.WoW.SearchQuestLinesByName, find = ns.WoW.FindQuestLine, catalog = ns.WoW.GetZoneCatalog,
    maps = ns.WoW.questLines.maps, current = ns.WoW.questLines.currentMapID,
    browse = ns.WoW.questLines.browseMapID, requested = ns.WoW.requested,
    failed = ns.WoW.failedRequests, offers = ns.WoW.offers, warnings = ns.WoW.warnings,
    mock = {} }
for key, value in pairs(Mock) do saved.mock[key] = value end
local initialPanel = UI.selector
if initialPanel then
    saved.idText = initialPanel.questIDInput:GetText()
    saved.nameText = initialPanel.nameInput:GetText()
    saved.filterText = initialPanel.zoneFilter:GetText()
end
local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
local catalog = {
    { mapID = 2248, name = "Zone [K] fixture", groupName = "First continent fixture" },
    { mapID = 2022, name = "Other zone fixture", groupName = "Second continent fixture" },
}
local panel

-- Add a case name to failures while counting independent behavior checks.
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Selector redesign / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end
local function click(button)
    button.scripts.OnClick(button, "LeftButton")
end
local function top(widget)
    local _, _, _, x, y = widget:GetPoint(1)
    return -y, x
end
local function labelExists(text)
    for _, child in ipairs(panel.children) do
        if child.kind == "FontString" and child:GetText() == text then return true end
    end
end
local function choiceCount()
    local count = 0
    for _, button in ipairs(panel.buttons) do if button:IsShown() then count = count + 1 end end
    return count
end
local function group(label)
    for _, entry in ipairs(panel.zoneDropdown.menu.entries) do
        if entry.label == label then return entry end
    end
end
local function regenerateFilter(text)
    panel.zoneFilter:SetText(text)
    panel.zoneFilter.scripts.OnTextChanged(panel.zoneFilter)
end
local function submitName(text)
    panel.nameInput:SetText(text or "Submitted fixture")
    panel.nameInput.scripts.OnTextChanged(panel.nameInput)
    click(panel.nameSearchButton)
end

-- Give each scenario clean session data while preserving the surrounding isolated test context.
local function prepare(selected)
    UI.Close()
    if UI.selector then UI.selector:Hide() end
    UI.ClearWarning()
    ns.ScheduleWarningExpiry()
    ns.CancelQuestLookup()
    Mock.Flush()
    ns.db = ns.ReadConfig({ chatWarnings = false, screenWarnings = false,
        keepWindowOpen = true, minimapAngle = 123, size = { width = 480, height = 520 } })
    QuestreihenTrackerDB = ns.db
    ns.chain = ns.LiveData.Empty()
    ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID, ns.WoW.questLines.browseMapID = {}, nil, nil
    ns.WoW.requested, ns.WoW.failedRequests, ns.WoW.offers = {}, {}, {}
    ns.WoW.ResetWarnings()
    for _, key in ipairs({ "active", "completed", "watched", "worldWatched", "tasks", "taskInfo",
        "messages", "warnings", "titles", "log", "questMapIDs", "questLineInfoByQuest",
        "questLineInfoByMap", "questsOnMap", "requests", "lineRequests" }) do Mock[key] = {} end
    Mock.currentMapID = 2248
    Mock.mapInfos = {
        [2248] = { mapID = 2248, name = catalog[1].name, mapType = zoneType, parentMapID = 0 },
        [2022] = { mapID = 2022, name = catalog[2].name, mapType = zoneType, parentMapID = 0 },
    }
    Mock.questLinesByMap, Mock.questLineQuests = { [2248] = {}, [2022] = {} }, { [5506] = { 78743, 78744 } }
    Mock.titles[78743], Mock.titles[78744] = "Selected first fixture", "Selected second fixture"
    Mock.superTrackedQuestID, Mock.isSuperTrackingQuest = nil, false
    ns.WoW.GetZoneCatalog = function() return catalog, "READY" end
    ns.WoW.SearchQuestLinesByName = function() return {}, "EMPTY" end
    UI.searchFeedback = nil
    UI.Restore()
    UI.ChooseChain()
    panel = UI.selector
    panel.questIDInput:SetText("")
    panel.nameInput:SetText("")
    regenerateFilter("")
    Mock.Flush()
    if selected then
        local chain = assert(ns.LiveData.Build(2248, { questLineID = 5506,
            questLineName = "Selected whole line fixture" }, { 78743, 78744 }))
        ns.WoW.RegisterQuestLine(chain)
        ns.Select(chain.id)
        Mock.Flush()
        return ns.chain
    end
end

local ok, message = pcall(function()
    test("search fields are vertical, consistently labeled, and use native status controls", function()
        prepare()
        local idTop, idX = top(panel.questIDInput)
        local nameTop, nameX = top(panel.nameInput)
        local idActionTop = top(panel.lookupButton)
        local nameActionTop = top(panel.nameSearchButton)
        assert(idX == nameX and idTop + panel.questIDInput:GetHeight() < nameTop)
        assert(idActionTop == idTop and nameActionTop == nameTop)
        assert(panel.lookupButton:GetText() == L.NAME_SEARCH and panel.nameSearchButton:GetText() == L.NAME_SEARCH)
        assert(labelExists(L.LOOKUP_ID) and labelExists(L.LOOKUP_NAME) and labelExists(L.NAME_DESCRIPTION))
        assert(panel.trackedButton:GetText() == L.LOOKUP_TRACKED and panel.trackedButton:GetWidth() >= 300)
        assert(panel.zone:GetText() == L.ZONE_LABEL)
        assert(panel.zoneDropdown.kind == "DropdownButton" and panel.zoneDropdown.template == "WowStyle1DropdownTemplate")
        assert(panel.closeButton.template == "UIPanelCloseButton")
        for _, button in ipairs({ panel.lookupButton, panel.nameSearchButton }) do
            assert(button.spinner.template == "SpinnerTemplate")
            assert(not button.spinner:IsShown() and not button.check:IsShown())
        end
    end)

    test("pending name lookup shows a spinner and settled verified matches show only a check", function()
        prepare()
        local chain = assert(ns.LiveData.Build(2248, { questLineID = 5506,
            questLineName = "Verified result fixture" }, { 78743, 78744 }))
        local calls = 0
        ns.WoW.SearchQuestLinesByName = function()
            calls = calls + 1
            return { { kind = "QUEST_LINE", name = chain.name, chain = chain, selectable = true } },
                calls == 1 and "LOADING" or "READY"
        end
        submitName()
        assert(panel.nameSearchButton.spinner:IsShown() and not panel.nameSearchButton.check:IsShown())
        assert(not panel.lookupButton.spinner:IsShown() and not panel.lookupButton.check:IsShown())
        assert(panel.lookupStatus:GetText() == L.SEARCH_LOADING and #Mock.timers == 1)
        Mock.Flush()
        assert(calls == 2 and not panel.nameSearchButton.spinner:IsShown() and panel.nameSearchButton.check:IsShown())
        assert(panel.lookupStatus:GetText() == L.SEARCH_MATCHES and choiceCount() == 1)
        assert(panel:IsShown() and ns.chain.empty and #Mock.timers == 0)
    end)

    test("ID lookup uses its own spinner and confirms opening the complete matching line", function()
        prepare()
        local chain = assert(ns.LiveData.Build(2248, { questLineID = 5506,
            questLineName = "ID association fixture" }, { 78743, 78744 }))
        local calls = 0
        ns.WoW.FindQuestLine = function(id)
            assert(id == 78743)
            calls = calls + 1
            if calls == 1 then return nil, "LOADING" end
            return chain, "READY"
        end
        panel.questIDInput:SetText("78743")
        panel.questIDInput.scripts.OnTextChanged(panel.questIDInput)
        click(panel.lookupButton)
        assert(panel.lookupButton.spinner:IsShown() and not panel.lookupButton.check:IsShown())
        assert(not panel.nameSearchButton.spinner:IsShown() and not panel.nameSearchButton.check:IsShown())
        assert(panel.lookupStatus:GetText() == L.SEARCH_LOADING and #Mock.timers == 1)
        Mock.Flush()
        assert(calls == 2 and not panel.lookupButton.spinner:IsShown() and panel.lookupButton.check:IsShown())
        assert(panel.lookupStatus:GetText() == L.SEARCH_SUCCESS and ns.chain.id == chain.id and ns.result.total == 2)
        assert(UI.frame:IsShown() and not panel:IsShown() and #Mock.timers == 0)
    end)

    test("achievement hints and unloaded lines cannot produce a verified-success check", function()
        prepare()
        ns.WoW.SearchQuestLinesByName = function()
            return { { kind = "CRITERION", name = "Information-only fixture", achievementName = "Parent fixture",
                completed = false, selectable = false },
                { kind = "QUEST_LINE", name = "Membership still loading fixture", loading = true, selectable = false } }, "READY"
        end
        submitName()
        assert(not panel.nameSearchButton.spinner:IsShown() and not panel.nameSearchButton.check:IsShown())
        assert(panel.lookupStatus:GetText() == L.SEARCH_FAILURE and choiceCount() == 0 and ns.chain.empty)
        assert(panel.labels[1]:GetText():find("Information-only fixture", 1, true))
        assert(panel.labels[2]:GetText():find("Membership still loading fixture", 1, true))
    end)

    test("invalid empty and unsupported searches share the same small inline failure", function()
        prepare()
        for _, status in ipairs({ "INVALID", "EMPTY", "UNSUPPORTED" }) do
            ns.WoW.SearchQuestLinesByName = function() return {}, status end
            submitName()
            assert(ns.nameLookup.status == status and panel.lookupStatus:GetText() == L.SEARCH_FAILURE)
            assert(not panel.nameSearchButton.spinner:IsShown() and not panel.nameSearchButton.check:IsShown())
            assert(panel:IsShown() and ns.chain.empty)
        end
        panel.questIDInput:SetText("not-an-ID")
        panel.questIDInput.scripts.OnTextChanged(panel.questIDInput)
        click(panel.lookupButton)
        assert(ns.questLookup.status == "INVALID_ID" and panel.lookupStatus:GetText() == L.SEARCH_FAILURE)
        assert(not panel.lookupButton.spinner:IsShown() and not panel.lookupButton.check:IsShown())
    end)

    test("grouped native zone radios filter literally without requesting other zones", function()
        prepare()
        local menu = panel.zoneDropdown.menu
        assert(menu.entries[1].kind == "Radio" and menu.entries[1].label == L.ZONE_CURRENT)
        assert(menu.entries[1].selected())
        assert(group(catalog[1].groupName).entries[1].label == catalog[1].name)
        assert(group(catalog[2].groupName).entries[1].kind == "Radio")
        assert(Mock.lineRequests[2022] == nil, "Listing zones must not load their quest lines")
        local calls, lineReads = Mock.calls, Mock.lineReads
        regenerateFilter("[")
        assert(group(catalog[1].groupName) and not group(catalog[2].groupName))
        assert(panel.zoneDropdown.menu.entries[1].label == L.ZONE_CURRENT)
        regenerateFilter("SECOND CONTINENT")
        assert(not group(catalog[1].groupName) and group(catalog[2].groupName))
        regenerateFilter("No matching fixture")
        assert(group(L.ZONE_NO_MATCHES) and panel.zoneDropdown.menu.entries[1].selected())
        assert(Mock.calls == calls and Mock.lineReads == lineReads and Mock.lineRequests[2022] == nil)
    end)

    test("choosing another zone cancels a pending name match before the shared timer runs", function()
        local selected = prepare(true)
        local calls = 0
        ns.WoW.SearchQuestLinesByName = function()
            calls = calls + 1
            return {}, calls == 1 and "LOADING" or "READY", selected
        end
        submitName()
        assert(ns.nameLookup.pending and #Mock.timers == 1)
        local radio = group(catalog[2].groupName).entries[1]
        radio.select(radio.data)
        Mock.Flush()
        assert(calls == 1 and ns.nameLookup == nil and ns.questLookup == nil)
        assert(ns.WoW.questLines.browseMapID == 2022 and panel.zoneDropdown.overrideText == catalog[2].name)
        assert(Mock.lineRequests[2022] == 1 and ns.chain.id == selected.id)
        assert(panel:IsShown() and not UI.frame:IsShown() and #Mock.timers == 0)
        panel.zoneDropdown:GenerateMenu()
        assert(group(catalog[2].groupName).entries[1].selected(2022))
        panel.zoneDropdown.menu.entries[1].select()
        Mock.Flush()
        assert(ns.WoW.questLines.browseMapID == nil and panel.zoneDropdown.overrideText == L.ZONE_CURRENT)
    end)

    test("the native selector X cancels a delayed exact match and cannot reopen either window", function()
        local selected = prepare(true)
        local calls = 0
        ns.WoW.SearchQuestLinesByName = function()
            calls = calls + 1
            return {}, calls == 1 and "LOADING" or "READY", selected
        end
        submitName()
        click(panel.closeButton)
        Mock.Flush()
        assert(calls == 1 and ns.nameLookup == nil and ns.questLookup == nil)
        assert(not panel:IsShown() and not UI.frame:IsShown() and not ns.db.windowOpen)
        assert(ns.chain.id == selected.id and #Mock.timers == 0)
    end)

    test("separate cache clearing cancels continuation while retaining selection and saved preferences", function()
        local selected = prepare(true)
        local config, calls = ns.db, 0
        ns.WoW.SearchQuestLinesByName = function()
            calls = calls + 1
            return {}, calls == 1 and "LOADING" or "READY", selected
        end
        submitName()
        ns.WoW.questLines.maps[2022] = { mapID = 2022, name = "Unused map fixture", chains = {}, byID = {}, loaded = true }
        ns.WoW.requested[78562] = true
        assert(panel.cacheButton:GetText() == L.CLEAR_SEARCH_CACHE and UI.clearButton:GetText() == L.CLEAR_SELECTION)
        click(panel.cacheButton)
        assert(ns.db == config and ns.chain.id == selected.id and ns.result.total == 2)
        assert(ns.db.liveSelection.questLineID == 5506 and ns.db.selectedChain == selected.id)
        assert(ns.db.chatWarnings == false and ns.db.screenWarnings == false and ns.db.keepWindowOpen)
        assert(ns.db.minimapAngle == 123 and ns.db.size.width == 480 and ns.db.size.height == 520)
        assert(ns.WoW.questLines.maps[2022] == nil and ns.WoW.requested[78562] == nil)
        assert(ns.nameLookup == nil and ns.questLookup == nil and panel.lookupStatus:GetText() == L.CACHE_CLEARED)
        assert(not panel.nameSearchButton.spinner:IsShown() and not panel.nameSearchButton.check:IsShown())
        Mock.Flush()
        assert(calls == 1 and ns.chain.id == selected.id and ns.result.total == 2)
        assert(panel:IsShown() and not UI.frame:IsShown() and #Mock.timers == 0)
        assert(UI.chainTitle:GetText() == selected.name and UI.clearButton:IsEnabled())
    end)
end)

-- Retire module-owned work before restoring the enclosing isolated namespace.
UI.Close()
if UI.selector then UI.selector:Hide() end
UI.ClearWarning()
ns.ScheduleWarningExpiry()
ns.CancelQuestLookup()
Mock.Flush()
ns.WoW.SearchQuestLinesByName, ns.WoW.FindQuestLine, ns.WoW.GetZoneCatalog = saved.search, saved.find, saved.catalog
ns.WoW.questLines.maps, ns.WoW.questLines.currentMapID, ns.WoW.questLines.browseMapID = saved.maps, saved.current, saved.browse
ns.WoW.requested, ns.WoW.failedRequests, ns.WoW.offers, ns.WoW.warnings = saved.requested, saved.failed, saved.offers, saved.warnings
for key in pairs(Mock) do if saved.mock[key] == nil then Mock[key] = nil end end
for key, value in pairs(saved.mock) do Mock[key] = value end
Enum = saved.enum
ns.db, QuestreihenTrackerDB, ns.chain, ns.snapshot, ns.result = saved.db, saved.db, saved.chain, saved.snapshot, saved.result
ns.questLookup, ns.nameLookup, UI.searchFeedback = saved.questLookup, saved.nameLookup, saved.feedback
UI.Restore()
UI.Render(ns.result)
if panel then
    panel.questIDInput:SetText(saved.idText or "")
    panel.nameInput:SetText(saved.nameText or "")
    panel.zoneFilter:SetText(saved.filterText or "")
    UI.RenderSelector()
end
UI.frame:SetShown(saved.shown)
if panel then panel:SetShown(saved.selectorShown == true) end
assert(ok, message)
assert(Mock.mutationCount == 0 and Mock.invalidIDCalls == 0)
for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
assert(#Mock.timers == 0 and ns.timer == nil)
print("Structured search, native zone menu and cache-action tests passed: " .. passed)
