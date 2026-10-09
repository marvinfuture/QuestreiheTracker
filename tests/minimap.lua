-- Offline gestures verify preferences and cleanup, not real-client artwork or taint.
local ns, passed = TEST_NS, 0
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Minimap / " .. name .. ": " .. tostring(message))
    assert(Mock.mutationCount == 0 and Mock.acceptCount == 0
        and Mock.setAbandonCount == 0 and Mock.abandonCount == 0)
    passed = passed + 1
end
local function near(actual, expected)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.00001,
        tostring(actual) .. " differs from " .. tostring(expected))
end
local function point(x, y)
    local anchor, _, relativeAnchor, actualX, actualY = ns.Minimap.button:GetPoint()
    assert(anchor == "CENTER" and relativeAnchor == "CENTER")
    near(actualX, x); near(actualY, y)
end
local function cursor(x, y)
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    Mock.cursorX, Mock.cursorY = (centerX + x) * scale, (centerY + y) * scale
end
local function idle()
    local button = ns.Minimap.button
    assert(not button.dragging and not button.dragAngle and button.scripts.OnUpdate == nil)
    for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
end

test("saved angle is a finite normalized preference", function()
    assert(ns.ReadConfig(nil).minimapAngle == 315)
    for _, case in ipairs({ { 0, 0 }, { 90, 90 }, { 360, 0 }, { -90, 270 }, { 720.25, 0.25 } }) do
        local config = ns.ReadConfig({ minimapAngle = case[1], completed = { [78743] = true } })
        near(config.minimapAngle, case[2])
        assert(config.completed == nil and config.minimapPosition == nil)
    end
    for _, bad in ipairs({ "90", false, {}, math.huge, -math.huge, 0 / 0 }) do
        assert(ns.ReadConfig({ minimapAngle = bad }).minimapAngle == 315)
    end
end)

test("small inset icon has native border hover highlight and left-button dragging", function()
    local button = ns.Minimap.button
    assert(button:GetWidth() == 32 and button:GetHeight() == 32)
    assert(button.icon:GetWidth() == 20 and button.icon:GetHeight() == 20)
    assert(button.border:GetTexture() == "Interface\\Minimap\\MiniMap-TrackingBorder")
    local highlight = button:GetHighlightTexture()
    assert(highlight:GetTexture() == "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    assert(highlight.blendMode == "ADD")
    assert(#button.dragButtons == 1 and button.dragButtons[1] == "LeftButton")
    assert(button.events.PLAYER_ENTERING_WORLD and button.events.UI_SCALE_CHANGED
        and button.events.DISPLAY_SIZE_CHANGED)
    idle()
end)

test("scaled cursor drag orbits the minimap and persists only on release", function()
    local button = ns.Minimap.button
    Mock.Flush()
    local timers, gameCalls = #Mock.timers, Mock.calls
    Minimap:SetSize(220, 160); Minimap:SetScale(1.25)
    Minimap.centerX, Minimap.centerY = 400, 320
    ns.db.minimapAngle = 315
    ns.UI.frame:Hide()
    cursor(200, 0)
    button.scripts.OnMouseDown(button, "LeftButton")
    button.scripts.OnDragStart(button)
    assert(button.dragging and type(button.scripts.OnUpdate) == "function")
    point(118, 0)
    assert(ns.db.minimapAngle == 315)
    cursor(0, 200); button.scripts.OnUpdate(button, 0.01)
    point(0, 88)
    assert(ns.db.minimapAngle == 315)
    cursor(-200, 0); button.scripts.OnDragStop(button)
    point(-118, 0); near(ns.db.minimapAngle, 180)
    idle()
    assert(#Mock.timers == timers and Mock.calls == gameCalls)
    button.scripts.OnClick(button, "LeftButton")
    assert(not ns.UI.frame:IsShown(), "A drag-release click must not open the tracker")
    button.scripts.OnMouseDown(button, "LeftButton")
    button.scripts.OnClick(button, "LeftButton")
    assert(ns.UI.frame:IsShown(), "The next deliberate click must remain usable")
    ns.UI.frame:Hide()
end)

test("mouse release and hidden launcher always remove temporary cursor sampling", function()
    local button = ns.Minimap.button
    cursor(0, -200)
    button.scripts.OnMouseDown(button, "LeftButton")
    button.scripts.OnDragStart(button)
    button.scripts.OnMouseUp(button, "LeftButton")
    near(ns.db.minimapAngle, 270); idle()
    button.scripts.OnDragStop(button); idle()
    button.scripts.OnClick(button, "LeftButton")
    assert(not ns.UI.frame:IsShown())
    cursor(118, 88)
    button.scripts.OnMouseDown(button, "LeftButton")
    button.scripts.OnDragStart(button)
    point(118 / math.sqrt(2), 88 / math.sqrt(2))
    GameTooltip:Hide(); button.scripts.OnEnter(button)
    assert(not GameTooltip:IsShown(), "Tooltip should stay closed while dragging")
    button:Hide()
    near(ns.db.minimapAngle, 45); idle()
    button:Show()
    point(118 / math.sqrt(2), 88 / math.sqrt(2))
    button.scripts.OnMouseDown(button, "LeftButton")
end)

test("reopening and display events restore the saved orbit without polling", function()
    local button = ns.Minimap.button
    local config = ns.ReadConfig(ns.db)
    near(config.minimapAngle, 45)
    ns.db, QuestStrangTrackerDB = config, config
    button:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    button:Hide(); button:Show()
    point(118 / math.sqrt(2), 88 / math.sqrt(2))
    Minimap:SetSize(140, 140); Minimap:SetScale(1)
    Minimap.centerX, Minimap.centerY = 1000, 800
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        button.scripts.OnEvent(button, event)
        point(78 / math.sqrt(2), 78 / math.sqrt(2))
        idle()
    end
    assert(#Mock.timers == 0)
end)

test("reset restores the default angle and later clicks still toggle", function()
    local button = ns.Minimap.button
    ns.Slash("reset")
    assert(ns.db.minimapAngle == 315)
    point(78 / math.sqrt(2), -78 / math.sqrt(2))
    ns.UI.frame:Hide()
    button.scripts.OnMouseDown(button, "LeftButton")
    button.scripts.OnClick(button, "LeftButton")
    assert(ns.UI.frame:IsShown())
    button.scripts.OnClick(button, "LeftButton")
    assert(not ns.UI.frame:IsShown())
    idle()
    Mock.Flush()
    assert(#Mock.timers == 0)
end)

print("Minimap gesture and preference tests passed: " .. passed)
