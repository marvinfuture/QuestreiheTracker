local _, ns = ...
local UI, L = ns.UI, ns.L

-- Reflect a saved choice with one selected native button and a clear gold underline.
function UI.RenderSetting(key, value)
    local row = UI.settingsRows and UI.settingsRows[key]
    if not row then return end
    for _, button in ipairs({ row.onButton, row.offButton }) do
        button.selected = button.value == (value == true)
        button:SetButtonState(button.selected and "PUSHED" or "NORMAL", button.selected)
        button.selection:SetShown(button.selected)
    end
end

-- Reflect the saved persistence preference without changing the player's window choice.
function UI.RenderKeepWindowOpenSetting()
    UI.RenderSetting("keepWindowOpen", ns.db.keepWindowOpen)
end

-- Toggle the settings dialog without altering main-window visibility or quest selection.
function UI.ShowSettings()
    UI.settings:SetShown(not UI.settings:IsShown())
end

-- Add a localized tooltip to a saved-preference choice using its setting's full label.
local function explain(button, label, hint)
    -- Describe the setting under the pointer without changing its saved value.
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(hint, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    -- Remove the setting tooltip when the pointer leaves the control.
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Build one labeled row with independent, mutually exclusive An and Aus choices.
local function setting(panel, key, label, hint, top, toggle)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(368, 34)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -top)
    row.label = UI.Text(row, nil, 0, -9, 238)
    row.label:SetHeight(22)
    row.label:SetText(label)
    local group = CreateFrame("Frame", nil, row, "BackdropTemplate")
    group:SetSize(118, 30)
    group:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    group:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    group:SetBackdropColor(0.025, 0.025, 0.03, 0.95)
    group:SetBackdropBorderColor(0.44, 0.41, 0.33, 0.8)
    row.group = group
    -- Set the requested boolean once; clicking the active choice does not toggle it back.
    local function choose(self)
        if ns.db[key] ~= self.value then toggle() end
    end
    row.onButton = UI.Button(group, L.SETTING_ON, 52, 3, -3, choose)
    row.offButton = UI.Button(group, L.SETTING_OFF, 52, 63, -3, choose)
    row.onButton.value, row.offButton.value = true, false
    row.on, row.off = row.onButton, row.offButton
    for _, button in ipairs({ row.onButton, row.offButton }) do
        local selection = UI.Rule(button, 40, 0, 0, { 1, 0.82, 0.35, 1 })
        selection:ClearAllPoints()
        selection:SetPoint("BOTTOM", button, "BOTTOM", 0, 4)
        selection:SetHeight(2)
        button.selection = selection
        explain(button, label, hint)
    end
    UI.settingsRows[key] = row
    return row
end

-- Create a native square gear and three clearly separated saved-preference rows.
function UI.CreateSettings()
    local gear = CreateFrame("Button", nil, UI.frame, "SquareIconButtonTemplate")
    UI.settingsButton = gear
    gear:SetSize(24, 24)
    gear:SetPoint("TOPRIGHT", UI.frame, "TOPRIGHT", -34, -4)
    gear:SetScript("OnClick", UI.ShowSettings)
    gear.icon = gear.Icon
    gear.icon:SetSize(16, 16)
    gear.icon:SetAtlas("common-dropdown-a-button-settings-shadowless")
    -- Identify the gear as the entry point to the saved addon preferences.
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L.SETTINGS)
        GameTooltip:AddLine(L.SETTINGS_HINT, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    -- Clear the gear tooltip after the pointer leaves the title bar.
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local panel = UI.Panel(nil, 400, 184, "settings")
    UI.settings, UI.settingsRows = panel, {}
    UI.Text(panel, "large", 16, -14, 330):SetText(L.SETTINGS)
    UI.Rule(panel, 368, 16, -42)
    UI.chatWarningsButton = setting(panel, "chatWarnings", L.SETTING_CHAT,
        L.CHAT_WARNINGS_HINT, 54, ns.ToggleChatWarnings)
    UI.screenWarningsButton = setting(panel, "screenWarnings", L.SETTING_SCREEN,
        L.SCREEN_WARNINGS_HINT, 92, ns.ToggleScreenWarnings)
    UI.keepWindowOpenButton = setting(panel, "keepWindowOpen", L.SETTING_KEEP_OPEN,
        L.KEEP_WINDOW_OPEN_HINT, 130, ns.ToggleKeepWindowOpen)
    panel:Hide()
end
