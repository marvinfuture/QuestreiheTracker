local _, ns = ...
local UI, L = ns.UI, ns.L
local colors = {
    COMPLETED = { 0.45, 0.85, 0.5 }, ACTIVE = { 1, 0.8, 0.35 },
    AVAILABLE = { 0.4, 0.8, 1 }, UNKNOWN = { 0.8, 0.8, 0.8 },
}

function UI.Restore()
    local size, position = ns.db.size, ns.db.position
    UI.frame:SetSize(size and size.width or 360, size and size.height or 500)
    UI.frame:SetScale(ns.db.scale)
    UI.frame:ClearAllPoints()
    if position then UI.frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else UI.frame:SetPoint("CENTER") end
    UI.Layout(UI.frame:GetWidth())
    UI.RestorePanelPositions()
end

local function saveGeometry()
    local frame = UI.frame
    local point, _, relativePoint, x, y = frame:GetPoint()
    ns.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    ns.db.size = { width = frame:GetWidth(), height = frame:GetHeight() }
end

local function stopSizingOrMoving()
    if not UI.resizing and not UI.moving then return end
    UI.frame:StopMovingOrSizing()
    UI.resizing, UI.moving = nil, nil
    saveGeometry()
end

function UI.Layout(width)
    local textWidth, contentWidth = width - 32, width - 60
    UI.title:SetWidth(width - 66)
    UI.select:SetWidth(textWidth - 92)
    UI.trackedButton:SetWidth(textWidth)
    UI.bar:SetWidth(textWidth)
    UI.count:SetWidth(textWidth)
    UI.notice:SetWidth(textWidth)
    UI.content:SetWidth(contentWidth)
    for _, row in pairs(UI.rows or {}) do
        row:SetWidth(contentWidth - 5)
        row.text:SetWidth(contentWidth - 40)
        row.subtext:SetWidth(contentWidth - 40)
    end
end

function UI.Toggle()
    UI.frame:SetShown(not UI.frame:IsShown())
end

function UI.Create()
    if UI.frame then return end
    local frame = UI.Panel("QuestreihenTrackerFrame", 360, 500)
    UI.frame = frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(UI.MIN_WIDTH, UI.MIN_HEIGHT, UI.MAX_WIDTH, UI.MAX_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not UI.resizing then UI.moving = true; self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.moving = nil
        saveGeometry()
    end)
    frame:SetScript("OnShow", function() if ns.initialized then ns.Refresh() end end)
    frame:SetScript("OnHide", function()
        stopSizingOrMoving()
        if UI.link then UI.link:Hide() end
        if UI.selector then UI.selector:Hide() end
    end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "QuestreihenTrackerFrame" end
    UI.title = UI.Text(frame, "large", 16, -15, 374)
    UI.title:SetText(L.TITLE)
    local close = UI.Button(frame, "X", 25, 400, -10, function() frame:Hide() end)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -10)
    UI.select = UI.Button(frame, "", 316, 16, -44, UI.ChooseChain)
    UI.select:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(self.tooltip or L.CHOOSE_CHAIN)
        GameTooltip:Show()
    end)
    UI.select:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.clearButton = UI.Button(frame, L.CLEAR_SELECTION, 84, 340, -44, function() ns.ClearSelection() end)
    UI.clearButton:ClearAllPoints()
    UI.clearButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -44)
    UI.clearButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L.CLEAR_SELECTION)
        GameTooltip:AddLine(L.CLEAR_SELECTION_HINT, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    UI.clearButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.trackedButton = UI.Button(frame, L.LOOKUP_TRACKED, 328, 16, -74, ns.UseTrackedQuest)
    UI.trackedButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L.LOOKUP_TRACKED)
        GameTooltip:AddLine(L.LOOKUP_HINT, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    UI.trackedButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetSize(328, 16)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -106)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.3, 0.7, 0.5)
    bar:SetMinMaxValues(0, 100)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(bar)
    background:SetColorTexture(0.15, 0.15, 0.18, 1)
    UI.bar, UI.percent = bar, UI.Text(bar, nil, 0, 0, 110)
    UI.percent:ClearAllPoints()
    UI.percent:SetPoint("CENTER", bar, "CENTER", 0, 0)
    UI.percent:SetJustifyH("CENTER")
    UI.count = UI.Text(frame, nil, 16, -129, 328)
    UI.count:SetHeight(20)
    UI.notice = UI.Text(frame, nil, 16, -153, 328)
    UI.notice:SetHeight(56)
    UI.notice:SetTextColor(0.7, 0.7, 0.7)
    UI.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    UI.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -213)
    UI.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 24)
    UI.content = CreateFrame("Frame", nil, UI.scroll)
    UI.content:SetSize(380, 1)
    UI.scroll:SetScrollChild(UI.content)
    local resize = CreateFrame("Button", nil, frame)
    UI.resizeHandle, frame.resizeHandle = resize, resize
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    local grip = resize:CreateTexture(nil, "ARTWORK")
    grip:SetAllPoints(resize)
    grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", "ADD")
    resize:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        UI.resizing = true
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and UI.resizing then stopSizingOrMoving() end
    end)
    resize:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L.SIZE_HINT)
        GameTooltip:Show()
    end)
    resize:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnSizeChanged", function(_, width) UI.Layout(width) end)
    UI.Restore()
    frame:Hide()
end

local function statusLabel(row)
    return row.progressStatus == "UNKNOWN" and L.PROGRESS_UNKNOWN or L[row.progressStatus]
end

-- Core schedules this deadline through the same timer used to coalesce game events.
UI.WARNING_DURATION = 5

function UI.WarningRemaining()
    if not UI.warningExpires then return nil end
    return math.max(0, UI.warningExpires - GetTime())
end

function UI.ClearWarning()
    UI.warningExpires = nil
    if UI.warning then UI.warning:Hide() end
end

function UI.RenderWarning()
    if UI.warningExpires and UI.WarningRemaining() <= 0 then UI.ClearWarning() end
end

local function warningDuration()
    local frame = UIErrorsFrame
    local visible = frame and ns.WoW.Call(frame.GetTimeVisible, frame)
    local fade = frame and ns.WoW.Call(frame.GetFadeDuration, frame)
    if type(visible) == "number" and visible > 0 and visible < 60
        and type(fade) == "number" and fade >= 0 and fade < 60 then
        return 2 * (visible + fade)
    end
    return UI.WARNING_DURATION
end

function UI.ShowWarning(message)
    if not UI.warning then
        local warning = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        warning:SetSize(500, 108)
        warning:SetPoint("TOP", UIParent, "TOP", 0, -140)
        warning:SetFrameStrata("DIALOG")
        warning:SetClampedToScreen(true)
        warning:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        warning:SetBackdropColor(0.12, 0.035, 0.025, 0.94)
        warning:SetBackdropBorderColor(1, 0.55, 0.15, 1)
        local title = UI.Text(warning, "large", 16, -12, 468)
        title:SetText(L.UNRELATED_WARNING_TITLE)
        title:SetTextColor(1, 0.65, 0.2)
        warning.message = UI.Text(warning, nil, 16, -38, 468)
        warning.message:SetHeight(58)
        warning.message:SetTextColor(1, 0.9, 0.75)
        UI.warning = warning
    end
    UI.warning.message:SetText(message)
    UI.warningDuration = warningDuration()
    UI.warningExpires = GetTime() + UI.warningDuration
    UI.warning:Show()
    ns.ScheduleWarningExpiry()
end

function UI.Render(result)
    if not UI.frame then return end
    local chain = ns.chain
    local loading, empty = chain.loading, chain.empty
    UI.select:SetText((empty and L.CHOOSE_CHAIN or chain.name) .. "  >")
    UI.select.tooltip = empty and L.CHOOSE_CHAIN or chain.name
    UI.clearButton:SetEnabled(not empty)
    UI.bar:SetValue(loading and 0 or result.percent)
    UI.percent:SetText(loading and L.LOADING_SHORT or string.format("%.0f %%", result.percent))
    UI.count:SetText(empty and L.NO_SELECTION or (loading and L.BLIZZARD_LOADING
        or string.format(L.RUNTIME_COUNT, result.completed, result.total)))
    UI.notice:SetText(empty and L.EMPTY_SELECTION or L.BLIZZARD_NOTICE)
    UI.RenderQuestLookup()
    for _, row in pairs(UI.rows or {}) do row:Hide() end
    local rowIndex, offset = 0, 0
    local function place(title, item)
        rowIndex = rowIndex + 1
        local row = UI.Row(UI.content, rowIndex)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", UI.content, "TOPLEFT", 0, -offset)
        row:SetHeight(item and 60 or 36)
        row:Show()
        row:EnableMouse(item ~= nil)
        row.icon:Hide()
        row.text:SetText(title)
        row.text:SetTextColor(1, 0.86, 0.55)
        row.subtext:SetText("")
        row.questID, row.tooltip = nil, nil
        if item then
            row.questID = item.questID
            local color = colors[item.status] or colors.UNKNOWN
            row.text:SetTextColor(unpack(color))
            if item.status == "COMPLETED" then
                row.icon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                row.icon:Show()
            end
            local status = statusLabel(item)
            row.subtext:SetText(status)
            local detail = item.status == "AVAILABLE" and L.AVAILABLE or (item.inferredNext and L.INFERRED)
            row.tooltip = status .. (detail and "\n" .. detail or "") .. "\n" .. L.LOOKUP_ID .. ": " .. item.questID
        end
        offset = offset + (item and 64 or 36)
    end
    if loading then
        place(L.BLIZZARD_LOADING)
    elseif not empty then
        for _, section in ipairs(chain.sections) do
            if #chain.sections > 1 then place(section.name) end
            for _, quest in ipairs(section.quests) do
                place(ns.WoW.Title(quest), result.byID[quest.questID])
            end
        end
    end
    UI.content:SetHeight(math.max(offset, 1))
end
