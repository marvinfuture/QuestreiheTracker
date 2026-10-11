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
    for _, key in ipairs({ "selector", "link" }) do
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
        -- Close the copy dialog through its title-bar button.
        UI.Button(panel, "X", 25, 464, -8, function() panel:Hide() end)
        panel.edit, UI.link = edit, panel
    end
    UI.link:Show()
    UI.link.edit:SetText("https://www.wowhead.com/quest=" .. id)
    UI.link.edit:SetFocus()
    UI.link.edit:HighlightText()
end

-- Translate reverse-lookup status into localized selector and tracker notices.
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
    local nameLookup = ns.nameLookup
    if nameLookup then
        local nameMessages = { INVALID = L.NAME_INVALID, LOADING = L.NAME_LOADING,
            READY = L.NAME_READY, EMPTY = L.NAME_EMPTY, PARTIAL = L.NAME_PARTIAL,
            UNSUPPORTED = L.NAME_UNSUPPORTED }
        text = string.format(nameMessages[nameLookup.status] or L.NAME_HINT, nameLookup.text)
    end
    if UI.selector then UI.selector.lookupStatus:SetText(text) end
    if UI.notice then
        local showLookup = nameLookup or (lookup and lookup.status ~= "READY")
        UI.notice:SetText(nameLookup and L.NAME_MAIN_NOTICE
            or (showLookup and text or (ns.chain.empty and L.EMPTY_SELECTION or L.BLIZZARD_NOTICE)))
        if showLookup then UI.notice:SetTextColor(1, 0.8, 0.35)
        else UI.notice:SetTextColor(0.7, 0.7, 0.7) end
    end
end

-- Reuse labels and choice buttons to display the current zone's discovered lines.
function UI.RenderSelector()
    local panel = UI.selector
    if not panel then return end
    local chains, status, mapName = ns.WoW.ZoneQuestLines()
    UI.RenderQuestLookup()
    panel.zone:SetText(string.format(L.ZONE_NAME, mapName or L.ZONE_UNKNOWN))
    for _, button in ipairs(panel.buttons) do button:Hide() end
    for _, label in ipairs(panel.labels) do label:Hide() end
    local offset, buttonIndex, labelIndex = 0, 0, 0
    -- Reuse a status label and advance the vertical layout by its required height.
    local function label(value, height)
        labelIndex = labelIndex + 1
        local text = panel.labels[labelIndex]
        if not text then
            text = UI.Text(panel.content, nil, 0, 0, 430)
            panel.labels[labelIndex] = text
        end
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offset)
        text:SetText(value)
        text:SetHeight(0)
        local measured = text:GetStringHeight()
        if type(measured) == "number" and measured > 0 and measured < 10000 then
            height = math.max(height, math.ceil(measured))
        end
        text:SetHeight(height)
        text:Show()
        offset = offset + height + 8
    end
    -- Reuse a line-choice button and place it at the next vertical position.
    local function choice(chain)
        buttonIndex = buttonIndex + 1
        local button = panel.buttons[buttonIndex]
        if not button then
            -- Select the button's current line and close the selector.
            button = UI.Button(panel.content, "", 430, 0, 0, function(self)
                ns.Select(self.chainID)
                panel:Hide()
            end)
            -- Expose long or ambiguous line names with the client-supplied map and line ID.
            button:SetScript("OnEnter", function(self)
                local selected = ns.WoW.GetQuestLine(self.chainID)
                if not selected then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(selected.name)
                GameTooltip:AddLine(L.LINE_ID .. ": " .. selected.questLineID, 0.85, 0.85, 0.85, true)
                local map = ns.WoW.questLines.maps[selected.mapID]
                if map and map.name then GameTooltip:AddLine(map.name, 0.85, 0.85, 0.85, true) end
                GameTooltip:Show()
            end)
            -- Dismiss the full-name tooltip after leaving the selector choice.
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            panel.buttons[buttonIndex] = button
        end
        button.chainID = chain.id
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offset)
        button:SetText(chain.loading and string.format(L.BLIZZARD_LINE_LOADING, chain.name) or chain.name)
        button:Show()
        offset = offset + 28
    end
    if ns.nameLookup then
        panel.zone:SetText(L.NAME_HINT)
        panel.refresh:SetText(L.NAME_BACK_ZONE)
        local results = ns.nameLookup.results or {}
        for _, result in ipairs(results) do
            if result.selectable and result.chain then
                choice(result.chain)
            elseif result.kind == "QUEST_LINE" then
                label(string.format(L.BLIZZARD_LINE_LOADING, result.name), 44)
            else
                local progress = result.completed == true and L.NAME_DONE
                    or (result.completed == false and L.NAME_NOT_DONE or L.NAME_UNKNOWN)
                local title = result.kind == "ACHIEVEMENT" and string.format(L.NAME_ACHIEVEMENT, result.name)
                    or string.format(L.NAME_CRITERION, result.name, result.achievementName or "")
                label(title .. "\n" .. progress .. "\n" .. L.NAME_UNRESOLVED, 70)
            end
        end
        if #results == 0 then label(panel.lookupStatus:GetText(), 56) end
        panel.content:SetHeight(math.max(offset, 1))
        return
    end
    panel.refresh:SetText(L.REFRESH_ZONE)
    local messages = { NO_MAP = L.ZONE_NO_MAP, UNSUPPORTED = L.ZONE_UNSUPPORTED,
        ERROR = L.ZONE_ERROR, LOADING = L.ZONE_LOADING, EMPTY = L.ZONE_EMPTY }
    if messages[status] then label(messages[status], 44) end
    for _, chain in ipairs(chains) do choice(chain) end
    panel.content:SetHeight(math.max(offset, 1))
end

-- Toggle the selector and lazily create its quest lookup and zone discovery controls.
function UI.ChooseChain()
    if UI.selector and UI.selector:IsShown() then UI.selector:Hide(); return end
    if not UI.selector then
        local panel = UI.Panel(nil, 500, 480, "selector")
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
        -- Parse the entered numeric ID and start its reverse lookup after releasing focus.
        local function submitQuestID()
            local text = input:GetText() or ""
            local digits = string.match(text, "^%s*(%d+)%s*$")
            input:ClearFocus()
            ns.LookupQuest(digits and tonumber(digits) or nil)
        end
        input:SetScript("OnEnterPressed", submitQuestID)
        -- Cancel stale lookup results whenever the player changes the quest ID.
        input:SetScript("OnTextChanged", function()
            ns.CancelQuestLookup()
            UI.RenderSelector()
        end)
        -- Close the selector and release the quest input's keyboard focus on Escape.
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)
        panel.lookupButton = UI.Button(panel, L.LOOKUP_SHOW, 80, 404, -46, submitQuestID)
        UI.Text(panel, nil, 16, -84, 55):SetText(L.LOOKUP_NAME)
        local nameInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        nameInput:SetSize(317, 24)
        nameInput:SetPoint("TOPLEFT", panel, "TOPLEFT", 74, -79)
        nameInput:SetAutoFocus(false)
        nameInput:SetMaxLetters(120)
        nameInput:SetText("")
        panel.nameInput = nameInput
        -- Submit a typed name explicitly so ordinary typing cannot scan achievement data.
        local function submitName()
            nameInput:ClearFocus()
            ns.LookupName(nameInput:GetText() or "")
        end
        nameInput:SetScript("OnEnterPressed", submitName)
        -- Cancel a stale query when its input changes and restore normal zone choices.
        nameInput:SetScript("OnTextChanged", function()
            ns.CancelQuestLookup()
            UI.RenderSelector()
        end)
        -- Close the selector and its pending query when the user presses Escape.
        nameInput:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)
        panel.nameSearchButton = UI.Button(panel, L.NAME_SEARCH, 80, 404, -79, submitName)
        panel.lookupStatus = UI.Text(panel, nil, 16, -112, 468)
        panel.lookupStatus:SetHeight(42)
        panel.zone = UI.Text(panel, nil, 16, -164, 320)
        panel.zone:SetHeight(36)
        -- Return from name results or explicitly request fresh zone metadata.
        panel.refresh = UI.Button(panel, L.REFRESH_ZONE, 136, 348, -162, function()
            ns.CancelQuestLookup()
            ns.DiscoverZone(true)
            UI.RenderSelector()
        end)
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -207)
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 44)
        panel.content = CreateFrame("Frame", nil, scroll)
        panel.content:SetSize(440, 1)
        scroll:SetScrollChild(panel.content)
        panel.scroll = scroll
        -- Close the selector through its footer button.
        UI.Button(panel, L.CLOSE, 100, 384, -440, function() panel:Hide() end)
        -- Persist a finished drag, release focus, and cancel a hidden selector's lookup.
        panel:SetScript("OnHide", function(self)
            stopPanelMoving(self)
            input:ClearFocus()
            ns.CancelQuestLookup()
            nameInput:ClearFocus()
            UI.RenderQuestLookup()
        end)
    end
    ns.DiscoverZone()
    UI.RenderSelector()
    UI.selector.scroll:SetVerticalScroll(0)
    UI.selector:Show()
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
