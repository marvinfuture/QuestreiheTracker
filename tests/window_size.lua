-- Widget stubs verify event wiring and preferences; real client layout remains a manual check.
local ns, passed = TEST_NS, 0
local function test(name, fn)
    local ok, message = pcall(fn)
    assert(ok, name .. ": " .. tostring(message))
    passed = passed + 1
end
local function assertGeometry(width, height, point, relativePoint, x, y)
    local frame = ns.UI.frame
    assert(frame:GetWidth() == width and frame:GetHeight() == height)
    local actualPoint, _, actualRelativePoint, actualX, actualY = frame:GetPoint()
    assert(actualPoint == point and actualRelativePoint == relativePoint)
    assert(actualX == x and actualY == y)
end
local function storedSize(width, height)
    assert(ns.db.size and ns.db.size.width == width and ns.db.size.height == height)
end

test("window preference validation keeps only finite supported dimensions", function()
    assert(ns.ReadConfig(nil).schemaVersion == 5)
    for _, size in ipairs({ { width = 360, height = 300 }, { width = 1400, height = 1200 },
        { width = 830.5, height = 875.25, foreign = true } }) do
        local config = ns.ReadConfig({ size = size })
        assert(config.size.width == size.width and config.size.height == size.height)
        assert(config.size ~= size and config.size.foreign == nil)
        size.width = 600
        assert(config.size.width ~= size.width)
    end
    for _, size in ipairs({ {}, { width = 550 }, { height = 750 },
        { width = "550", height = 750 }, { width = 550, height = "750" },
        { width = 359, height = 750 }, { width = 1401, height = 750 },
        { width = 550, height = 299 }, { width = 550, height = 1201 },
        { width = 0 / 0, height = 750 }, { width = 550, height = 0 / 0 },
        { width = math.huge, height = 750 }, { width = 550, height = -math.huge },
        "550x750", false }) do
        assert(ns.ReadConfig({ size = size }).size == nil)
    end
end)

test("tracker has a native resize handle and explicit bounds", function()
    local frame, handle = ns.UI.frame, ns.UI.resizeHandle
    assert(frame.resizable == true)
    assert(handle and rawget(frame, "resizeHandle") == handle and handle.parent == frame)
    assert(type(handle.scripts.OnMouseDown) == "function")
    assert(type(handle.scripts.OnMouseUp) == "function")
    local bounds = frame.resizeBounds
    assert(bounds[1] == 360 and bounds[2] == 300 and bounds[3] == 1400 and bounds[4] == 1200)
    assert(frame.scripts.OnUpdate == nil and handle.scripts.OnUpdate == nil)
end)

test("resizing updates rows and persists dimensions and anchor only on release", function()
    local frame, handle = ns.UI.frame, ns.UI.resizeHandle
    ns.Slash("reset")
    frame:Show()
    assertGeometry(440, 500, "CENTER", "CENTER", 0, 0)
    handle.scripts.OnMouseDown(handle, "RightButton")
    assert(not ns.UI.resizing and not rawget(frame, "sizing"))
    handle.scripts.OnMouseDown(handle, "LeftButton")
    assert(ns.UI.resizing and frame.sizing and frame.sizingPoint == "BOTTOMRIGHT")
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 125, -90)
    frame:SetSize(820, 910)
    assert(ns.db.size == nil and ns.db.position == nil)
    assert(ns.UI.content:GetWidth() == 760)
    for _, row in pairs(ns.UI.rows) do
        if row:IsShown() then
            assert(row:GetWidth() == 755)
            assert(row.text:GetWidth() == 720 and row.subtext:GetWidth() == 720)
        end
    end
    handle.scripts.OnMouseUp(handle, "RightButton")
    assert(ns.UI.resizing and frame.sizing and ns.db.size == nil)
    handle.scripts.OnMouseUp(handle, "LeftButton")
    assert(not ns.UI.resizing and not frame.sizing)
    storedSize(820, 910)
    assert(ns.db.position.point == "TOPLEFT" and ns.db.position.relativePoint == "TOPLEFT")
    assert(ns.db.position.x == 125 and ns.db.position.y == -90)
end)

test("dragging records the anchor and reopening restores the chosen geometry", function()
    local frame = ns.UI.frame
    frame.scripts.OnDragStart(frame)
    assert(ns.UI.moving and frame.moving)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -160, 110)
    frame.scripts.OnDragStop(frame)
    assert(not ns.UI.moving and not frame.moving)
    assert(ns.db.position.point == "BOTTOMRIGHT" and ns.db.position.x == -160)
    storedSize(820, 910)
    ns.UI.Toggle(); assert(not frame:IsShown())
    ns.UI.Toggle(); assert(frame:IsShown())
    assertGeometry(820, 910, "BOTTOMRIGHT", "BOTTOMRIGHT", -160, 110)
    local saved = ns.ReadConfig(ns.db)
    frame:SetPoint("CENTER")
    frame:SetSize(440, 500)
    ns.db, QuestStrangTrackerDB = saved, saved
    ns.UI.Restore()
    assertGeometry(820, 910, "BOTTOMRIGHT", "BOTTOMRIGHT", -160, 110)
end)

test("hiding an active resize or drag stops it and saves the final layout", function()
    local frame, handle = ns.UI.frame, ns.UI.resizeHandle
    frame:Show()
    handle.scripts.OnMouseDown(handle, "LeftButton")
    frame:SetSize(700, 800)
    frame:SetPoint("LEFT", UIParent, "LEFT", 60, 35)
    local stops = frame.stopCount
    frame:Hide()
    assert(frame.stopCount == stops + 1 and not frame.sizing and not ns.UI.resizing)
    storedSize(700, 800)
    assert(ns.db.position.point == "LEFT" and ns.db.position.x == 60)
    frame:Show()
    frame.scripts.OnDragStart(frame)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, -35)
    stops = frame.stopCount
    frame:Hide()
    assert(frame.stopCount == stops + 1 and not frame.moving and not ns.UI.moving)
    assert(ns.db.position.point == "RIGHT" and ns.db.position.y == -35)
    frame:Show()
    assertGeometry(700, 800, "RIGHT", "RIGHT", -60, -35)
end)

test("restoration handles bounds and keeps scale separate from window size", function()
    local frame = ns.UI.frame
    for _, size in ipairs({ { width = 360, height = 300 }, { width = 1400, height = 1200 } }) do
        ns.db = ns.ReadConfig({ size = size, scale = 1.1 })
        QuestStrangTrackerDB = ns.db
        ns.UI.Restore()
        assertGeometry(size.width, size.height, "CENTER", "CENTER", 0, 0)
        assert(frame.scale == 1)
        storedSize(size.width, size.height)
    end
    ns.Slash("reset")
    assert(ns.db.size == nil and ns.db.position == nil and ns.db.scale == 1)
    assertGeometry(440, 500, "CENTER", "CENTER", 0, 0)
    frame:Hide()
    assert(Mock.mutationCount == 0, table.concat(Mock.mutations, ", "))
end)

print("Window preference tests passed: " .. passed)
