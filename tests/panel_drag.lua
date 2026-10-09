-- Verify each addon window moves itself and keeps its position as a preference.
local ns, passed = TEST_NS, 0
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, "Window dragging / " .. name .. ": " .. tostring(message))
    passed = passed + 1
end
local function position(frame)
    local point, _, relativePoint, x, y = frame:GetPoint()
    return { point = point, relativePoint = relativePoint, x = x, y = y }
end
local function assertPosition(frame, expected)
    local actual = position(frame)
    for key, value in pairs(expected) do assert(actual[key] == value, "Wrong anchor field: " .. key) end
end
local function count(frame, key) return rawget(frame, key) or 0 end
local function panels()
    ns.UI.frame:Show()
    if not ns.UI.selector or not ns.UI.selector:IsShown() then ns.UI.ChooseChain() end
    ns.UI.ShowLink(78743)
    return { { key = "selector", frame = ns.UI.selector },
        { key = "link", frame = ns.UI.link } }
end

test("all three windows register left-button dragging and move their own frame", function()
    local all = panels()
    all[#all + 1] = { frame = ns.UI.frame }
    for _, item in ipairs(all) do
        local frame = item.frame
        assert(frame.movable == true)
        assert(frame.dragButtons[1] == "LeftButton" and #frame.dragButtons == 1)
        assert(type(frame.scripts.OnDragStart) == "function")
        assert(type(frame.scripts.OnDragStop) == "function")
        local starts, stops = count(frame, "startMovingCount"), count(frame, "stopCount")
        local mainStarts, mainStops = count(ns.UI.frame, "startMovingCount"), count(ns.UI.frame, "stopCount")
        frame.scripts.OnDragStart(frame)
        assert(frame.moving == true and count(frame, "startMovingCount") == starts + 1)
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
        frame.scripts.OnDragStop(frame)
        assert(frame.moving == false and count(frame, "stopCount") == stops + 1)
        if item.key then
            assert(count(ns.UI.frame, "startMovingCount") == mainStarts)
            assert(count(ns.UI.frame, "stopCount") == mainStops)
        end
    end
end)

test("each popup saves its own anchor without changing tracker geometry", function()
    local main = position(ns.UI.frame)
    local mainWidth, mainHeight = ns.UI.frame:GetWidth(), ns.UI.frame:GetHeight()
    for index, item in ipairs(panels()) do
        local expected = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -80 * index, y = 50 * index }
        item.frame.scripts.OnDragStart(item.frame)
        item.frame:SetPoint(expected.point, UIParent, expected.relativePoint, expected.x, expected.y)
        item.frame.scripts.OnDragStop(item.frame)
        local stored = ns.db.panelPositions[item.key]
        assert(stored and stored.point == expected.point and stored.relativePoint == expected.relativePoint)
        assert(stored.x == expected.x and stored.y == expected.y)
        item.frame:Hide()
        item.frame:Show()
        assertPosition(item.frame, expected)
    end
    assertPosition(ns.UI.frame, main)
    assert(ns.UI.frame:GetWidth() == mainWidth and ns.UI.frame:GetHeight() == mainHeight)
    assert(ns.db.position.point == main.point and ns.db.position.x == main.x and ns.db.position.y == main.y)
end)

test("closing a dragged popup stops and saves that popup only", function()
    local main = position(ns.UI.frame)
    for index, item in ipairs(panels()) do
        local frame = item.frame
        local expected = { point = "LEFT", relativePoint = "LEFT", x = 25 * index, y = -35 * index }
        frame.scripts.OnDragStart(frame)
        frame:SetPoint(expected.point, UIParent, expected.relativePoint, expected.x, expected.y)
        local stops, mainStops = count(frame, "stopCount"), count(ns.UI.frame, "stopCount")
        frame:Hide()
        assert(frame.moving == false and count(frame, "stopCount") == stops + 1)
        assert(count(ns.UI.frame, "stopCount") == mainStops)
        local stored = ns.db.panelPositions[item.key]
        assert(stored and stored.x == expected.x and stored.y == expected.y)
        frame:Show()
        assertPosition(frame, expected)
    end
    assertPosition(ns.UI.frame, main)
end)

test("saved popup positions are isolated validated preferences and reset to defaults", function()
    local saved = ns.ReadConfig(ns.db)
    for _, item in ipairs(panels()) do
        assert(saved.panelPositions[item.key] ~= ns.db.panelPositions[item.key])
        item.frame:SetPoint("CENTER")
    end
    ns.db, QuestreihenTrackerDB = saved, saved
    ns.UI.Restore()
    for _, item in ipairs(panels()) do assertPosition(item.frame, saved.panelPositions[item.key]) end
    local repaired = ns.ReadConfig({ panelPositions = {
        selector = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 45, y = -75, foreign = true },
        options = { point = "invalid", relativePoint = "CENTER", x = 0, y = 0 },
        link = { point = "CENTER", relativePoint = "CENTER", x = math.huge, y = 0 },
        unknown = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    } })
    assert(repaired.panelPositions.selector.x == 45 and repaired.panelPositions.selector.foreign == nil)
    assert(repaired.panelPositions.options == nil and repaired.panelPositions.link == nil)
    assert(repaired.panelPositions.unknown == nil)
    ns.Slash("reset")
    assert(ns.db.panelPositions == nil or next(ns.db.panelPositions) == nil)
    for _, item in ipairs(panels()) do
        assertPosition(item.frame, { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 })
        assert(item.frame.scripts.OnUpdate == nil)
    end
    assert(Mock.mutationCount == 0, table.concat(Mock.mutations, ", "))
    ns.UI.frame:Hide()
    Mock.Flush()
end)

print("All-window drag tests passed: " .. passed)
