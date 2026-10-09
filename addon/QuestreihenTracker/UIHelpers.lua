local _, ns = ...
local UI, L = {}, ns.L
ns.UI = UI
UI.MIN_WIDTH, UI.MIN_HEIGHT = 320, 300
UI.MAX_WIDTH, UI.MAX_HEIGHT = 1400, 1200

function UI.Text(parent, size, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetFontObject(size == "large" and "GameFontNormalLarge" or "GameFontHighlight")
    return text
end

function UI.Button(parent, label, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

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

function UI.RestorePanelPositions()
    for _, key in ipairs({ "selector", "link" }) do
        if UI[key] then UI.RestorePanelPosition(UI[key], key) end
    end
end

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
    return panel
end

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
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)
        UI.Button(panel, "X", 25, 464, -8, function() panel:Hide() end)
        panel.edit, UI.link = edit, panel
    end
    UI.link:Show()
    UI.link.edit:SetText("https://www.wowhead.com/quest=" .. id)
    UI.link.edit:SetFocus()
    UI.link.edit:HighlightText()
end

function UI.RenderQuestLookup()
    if not UI.selector and not UI.notice then return end
    local lookup = ns.questLookup
    local messages = { INVALID_ID = L.LOOKUP_INVALID, NO_TRACKED = L.LOOKUP_NO_TRACKED,
        UNSUPPORTED = L.LOOKUP_UNSUPPORTED, ERROR = L.LOOKUP_ERROR, NO_MAP = L.LOOKUP_NO_MAP }
    local text = L.LOOKUP_HINT
    if lookup then
        if lookup.status == "LOADING" then text = string.format(L.LOOKUP_LOADING, lookup.questID)
        elseif lookup.status == "NOT_FOUND" then text = string.format(L.LOOKUP_NOT_FOUND, lookup.questID)
        else text = messages[lookup.status] or L.LOOKUP_HINT end
    end
    if UI.selector then UI.selector.lookupStatus:SetText(text) end
    if UI.notice then
        local showLookup = lookup and lookup.status ~= "READY"
        UI.notice:SetText(showLookup and text or (ns.chain.empty and L.EMPTY_SELECTION or L.BLIZZARD_NOTICE))
        if showLookup then UI.notice:SetTextColor(1, 0.8, 0.35)
        else UI.notice:SetTextColor(0.7, 0.7, 0.7) end
    end
end

function UI.RenderSelector()
    local panel = UI.selector
    if not panel then return end
    local chains, status, mapName = ns.WoW.ZoneQuestLines()
    UI.RenderQuestLookup()
    panel.zone:SetText(string.format(L.ZONE_NAME, mapName or L.ZONE_UNKNOWN))
    for _, button in ipairs(panel.buttons) do button:Hide() end
    for _, label in ipairs(panel.labels) do label:Hide() end
    local offset, buttonIndex, labelIndex = 0, 0, 0
    local function label(value, height)
        labelIndex = labelIndex + 1
        local text = panel.labels[labelIndex]
        if not text then
            text = UI.Text(panel.content, nil, 0, 0, 430)
            panel.labels[labelIndex] = text
        end
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offset)
        text:SetHeight(height)
        text:SetText(value)
        text:Show()
        offset = offset + height + 8
    end
    local function choice(chain)
        buttonIndex = buttonIndex + 1
        local button = panel.buttons[buttonIndex]
        if not button then
            button = UI.Button(panel.content, "", 430, 0, 0, function(self)
                ns.Select(self.chainID)
                panel:Hide()
            end)
            panel.buttons[buttonIndex] = button
        end
        button.chainID = chain.id
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offset)
        button:SetText(chain.loading and string.format(L.BLIZZARD_LINE_LOADING, chain.name) or chain.name)
        button:Show()
        offset = offset + 28
    end
    local messages = { NO_MAP = L.ZONE_NO_MAP, UNSUPPORTED = L.ZONE_UNSUPPORTED,
        ERROR = L.ZONE_ERROR, LOADING = L.ZONE_LOADING, EMPTY = L.ZONE_EMPTY }
    if messages[status] then label(messages[status], 44) end
    for _, chain in ipairs(chains) do choice(chain) end
    panel.content:SetHeight(math.max(offset, 1))
end

function UI.ChooseChain()
    if UI.selector and UI.selector:IsShown() then UI.selector:Hide(); return end
    if not UI.selector then
        local panel = UI.Panel(nil, 500, 440, "selector")
        UI.selector = panel
        panel.buttons, panel.labels = {}, {}
        UI.Text(panel, "large", 16, -16, 440):SetText(L.CHOOSE_CHAIN)
        panel.trackedButton = UI.Button(panel, L.LOOKUP_TRACKED, 207, 16, -46, ns.UseTrackedQuest)
        UI.Text(panel, nil, 236, -51, 60):SetText(L.LOOKUP_ID)
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetSize(90, 24)
        input:SetPoint("TOPLEFT", panel, "TOPLEFT", 301, -46)
        input:SetAutoFocus(false)
        input:SetText("")
        panel.questIDInput = input
        local function submitQuestID()
            local text = input:GetText() or ""
            local digits = string.match(text, "^%s*(%d+)%s*$")
            input:ClearFocus()
            ns.LookupQuest(digits and tonumber(digits) or nil)
        end
        input:SetScript("OnEnterPressed", submitQuestID)
        input:SetScript("OnTextChanged", function()
            ns.CancelQuestLookup()
            UI.RenderQuestLookup()
        end)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)
        panel.lookupButton = UI.Button(panel, L.LOOKUP_SHOW, 80, 404, -46, submitQuestID)
        panel.lookupStatus = UI.Text(panel, nil, 16, -80, 468)
        panel.lookupStatus:SetHeight(36)
        panel.zone = UI.Text(panel, nil, 16, -124, 340)
        panel.zone:SetHeight(30)
        panel.refresh = UI.Button(panel, L.REFRESH_ZONE, 110, 374, -120, function()
            ns.DiscoverZone(true)
            UI.RenderSelector()
        end)
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -161)
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 44)
        panel.content = CreateFrame("Frame", nil, scroll)
        panel.content:SetSize(440, 1)
        scroll:SetScrollChild(panel.content)
        panel.scroll = scroll
        UI.Button(panel, L.CLOSE, 100, 384, -400, function() panel:Hide() end)
        panel:SetScript("OnHide", function(self)
            stopPanelMoving(self)
            input:ClearFocus()
            ns.CancelQuestLookup()
        end)
    end
    ns.DiscoverZone()
    UI.RenderSelector()
    UI.selector.scroll:SetVerticalScroll(0)
    UI.selector:Show()
end

function UI.Row(parent, key)
    UI.rows = UI.rows or {}
    if UI.rows[key] then return UI.rows[key] end
    local row = CreateFrame("Button", nil, parent)
    local width = parent:GetWidth() - 5
    row:SetSize(width, 60)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.text = UI.Text(row, nil, 28, -3, width - 35)
    row.text:SetHeight(32)
    row.text:SetJustifyV("TOP")
    row.subtext = UI.Text(row, nil, 28, -39, width - 35)
    row.subtext:SetHeight(18)
    row.subtext:SetTextColor(0.7, 0.7, 0.7)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -3)
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then ns.TrackQuest(self.questID)
        elseif button == "RightButton" then UI.ShowLink(self.questID) end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.text:GetText())
        GameTooltip:AddLine(self.tooltip or "", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine(L.TOOLTIP, 0.8, 0.7, 0.4, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.rows[key] = row
    return row
end
