local _, ns = ...
local MinimapButton = {}
ns.Minimap = MinimapButton

local DEFAULT_ANGLE = 315
local EDGE_OFFSET = 8

local function NormalizeAngle(angle)
    if type(angle) ~= "number" or angle ~= angle or angle == math.huge or angle == -math.huge then
        return DEFAULT_ANGLE
    end
    return angle % 360
end

local function OrbitRadii()
    return Minimap:GetWidth() / 2 + EDGE_OFFSET, Minimap:GetHeight() / 2 + EDGE_OFFSET
end

function MinimapButton.Position(angle)
    local button = MinimapButton.button
    if not button or not Minimap then return end
    angle = NormalizeAngle(angle or (ns.db and ns.db.minimapAngle))
    local radiusX, radiusY = OrbitRadii()
    local radians = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radiusX, math.sin(radians) * radiusY)
end

local function DragUpdate(self)
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    if not centerX or not centerY or not scale or scale <= 0 then return end
    local cursorX, cursorY = GetCursorPosition()
    local radiusX, radiusY = OrbitRadii()
    local x, y = (cursorX / scale - centerX) / radiusX, (cursorY / scale - centerY) / radiusY
    if x == 0 and y == 0 then return end
    self.dragAngle = NormalizeAngle(math.deg(math.atan2(y, x)))
    MinimapButton.Position(self.dragAngle)
end

local function StopDrag(self, updateCursor)
    if self.dragging then
        if updateCursor then DragUpdate(self) end
        if ns.db and self.dragAngle then ns.db.minimapAngle = self.dragAngle end
    end
    self.dragging, self.dragAngle = false, false
    self:SetScript("OnUpdate", nil)
end

function MinimapButton.Create()
    if MinimapButton.button or not Minimap then return end
    local button = CreateFrame("Button", nil, Minimap)
    button.dragging, button.dragAngle, button.suppressClick = false, false, false
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local backdrop = button:CreateTexture(nil, "BACKGROUND")
    backdrop:SetSize(24, 24)
    backdrop:SetPoint("CENTER", button, "CENTER")
    backdrop:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.backdrop = backdrop

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER")
    icon:SetTexture("Interface\\AddOns\\QuestreihenTracker\\Media\\QuestreihenTrackerLogo")
    button.icon = icon
    -- Blizzard's border sheet contains the small ring in its upper-left corner.
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", button, "TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    button:SetScript("OnMouseDown", function(self)
        self.suppressClick = false
    end)
    button:SetScript("OnDragStart", function(self)
        self.dragging, self.suppressClick = true, true
        self.dragAngle = NormalizeAngle(ns.db and ns.db.minimapAngle)
        GameTooltip:Hide()
        DragUpdate(self)
        -- Cursor sampling exists only while the player is actively dragging.
        self:SetScript("OnUpdate", DragUpdate)
    end)
    button:SetScript("OnDragStop", function(self) StopDrag(self, true) end)
    button:SetScript("OnMouseUp", function(self) StopDrag(self, true) end)
    button:SetScript("OnHide", function(self)
        StopDrag(self, false)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.suppressClick then
            self.suppressClick = false
            return
        end
        if mouseButton == "RightButton" then
            ns.UI.frame:Show()
            ns.UI.ChooseChain()
        else
            ns.UI.Toggle()
        end
    end)
    button:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.L.TITLE)
        GameTooltip:AddLine(ns.L.MINIMAP_TOOLTIP, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnShow", function() MinimapButton.Position() end)
    button:RegisterEvent("PLAYER_ENTERING_WORLD")
    button:RegisterEvent("UI_SCALE_CHANGED")
    button:RegisterEvent("DISPLAY_SIZE_CHANGED")
    button:SetScript("OnEvent", function()
        if not button.dragging then MinimapButton.Position() end
    end)
    MinimapButton.button = button
    MinimapButton.Position()
end
