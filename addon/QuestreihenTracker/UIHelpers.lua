local _, ns = ...
local UI, L = {}, ns.L
ns.UI = UI
UI.MIN_WIDTH, UI.MIN_HEIGHT = 320, 300
UI.MAX_WIDTH, UI.MAX_HEIGHT = 1400, 1200

-- Create an anchored left-aligned label using the requested Blizzard font size.
function UI.Text(parent, size, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    local font = size == "title" and "GameFontNormalHuge" or (size == "large" and "GameFontNormalLarge"
        or (size == "small" and "GameFontHighlightSmall" or "GameFontHighlight"))
    text:SetFontObject(font)
    return text
end

-- Draw a one-pixel separator at the supplied panel coordinates.
function UI.Rule(parent, width, x, y, color)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetSize(width, 1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    line:SetColorTexture(unpack(color or { 0.44, 0.41, 0.33, 0.55 }))
    return line
end

-- Create a standard localized action button and attach its click callback.
function UI.Button(parent, label, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

-- Use Blizzard's native exit control while preserving the caller's close semantics.
function UI.CloseButton(parent, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    button:SetSize(24, 24)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)
    button:SetScript("OnClick", callback)
    return button
end

-- End any drag and restore a saved panel anchor, defaulting to screen center.
function UI.RestorePanelPosition(panel, key)
    if panel.dragging then
        panel:StopMovingOrSizing()
        panel.dragging = false
    end
    local position = ns.db and ns.db.panelPositions and ns.db.panelPositions[key]
    panel:ClearAllPoints()
    if position then panel:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else panel:SetPoint("CENTER") end
end

-- Restore the independent saved positions of already-created selector and link panels.
function UI.RestorePanelPositions()
    for _, key in ipairs({ "selector", "link", "settings" }) do
        if UI[key] then UI.RestorePanelPosition(UI[key], key) end
    end
end

-- Finish a panel drag and persist its anchor as a player preference.
local function stopPanelMoving(panel)
    if not panel.dragging then return end
    panel:StopMovingOrSizing()
    panel.dragging = false
    if panel.positionKey and ns.db then
        local point, _, relativePoint, x, y = panel:GetPoint()
        ns.db.panelPositions = ns.db.panelPositions or {}
        ns.db.panelPositions[panel.positionKey] = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
end

-- Build a movable dialog with saved positioning and a shared dark backdrop.
function UI.Panel(name, width, height, positionKey)
    local panel = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    panel:SetSize(width, height)
    panel.positionKey, panel.dragging = positionKey or false, false
    UI.RestorePanelPosition(panel, positionKey)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    -- Mark the panel as dragging before starting Blizzard's frame movement.
    panel:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", stopPanelMoving)
    panel:SetScript("OnHide", stopPanelMoving)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    panel:SetBackdropColor(0.06, 0.065, 0.075, 0.82)
    panel:SetBackdropBorderColor(0.35, 0.3, 0.18, 1)
    if name ~= "QuestreihenTrackerFrame" then
        -- Close this independent dialog through the standard title-bar control.
        panel.closeButton = UI.CloseButton(panel, function() panel:Hide() end)
    end
    return panel
end

-- Open a reusable copy dialog and select the Wowhead URL for a validated quest ID.
function UI.ShowLink(id)
    if not ns.LiveData.IsID(id) then ns.Print(L.INVALID_QUEST_ID); return end
    if not UI.link then
        local panel = UI.Panel(nil, 500, 120, "link")
        UI.Text(panel, "large", 16, -14, 450):SetText(L.WOWHEAD)
        UI.Text(panel, nil, 16, -45, 450):SetText(L.COPY)
        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        edit:SetSize(460, 24)
        edit:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -72)
        edit:SetAutoFocus(false)
        -- Release keyboard focus and close the copy dialog when Escape is pressed.
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)
        panel.edit, UI.link = edit, panel
    end
    UI.link:Show()
    UI.link.edit:SetText("https://www.wowhead.com/quest=" .. id)
    UI.link.edit:SetFocus()
    UI.link.edit:HighlightText()
end

-- Create or reuse a quest row with status text, an icon, actions, and tooltip scripts.
function UI.Row(parent, key)
    UI.rows = UI.rows or {}
    if UI.rows[key] then return UI.rows[key] end
    local row = CreateFrame("Button", nil, parent)
    local width = parent:GetWidth() - 5
    row:SetSize(width, 40)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.text = UI.Text(row, nil, 28, -3, width - 35)
    row.text:SetHeight(14)
    row.text:SetJustifyV("TOP")
    row.subtext = UI.Text(row, "small", 28, -19, width - 35)
    row.subtext:SetHeight(14)
    row.subtext:SetTextColor(0.7, 0.7, 0.7)
    row.separator = UI.Rule(row, width, 0, 0, { 0.35, 0.32, 0.26, 0.45 })
    row.separator:ClearAllPoints()
    row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.separator:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -3)
    -- Track the row's quest on left click or show its copyable link on right click.
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then ns.TrackQuest(self.questID)
        elseif button == "RightButton" then UI.ShowLink(self.questID) end
    end)
    -- Show the row's quest title, status details, and localized action guidance.
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.text:GetText())
        GameTooltip:AddLine(self.tooltip or "", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine(L.TOOLTIP, 0.8, 0.7, 0.4, true)
        GameTooltip:Show()
    end)
    -- Dismiss the quest tooltip when the pointer leaves its row.
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.rows[key] = row
    return row
end
