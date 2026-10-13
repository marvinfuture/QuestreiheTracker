local _, ns = ...
local UI, L = ns.UI, ns.L

-- Reflect the saved persistence preference in the settings dialog.
function UI.RenderKeepWindowOpenSetting()
    if UI.keepWindowOpenButton then
        UI.keepWindowOpenButton:SetText(ns.db.keepWindowOpen and L.KEEP_WINDOW_OPEN_ON or L.KEEP_WINDOW_OPEN_OFF)
    end
end

-- Toggle the settings dialog without altering main-window visibility or quest selection.
function UI.ShowSettings()
    UI.settings:SetShown(not UI.settings:IsShown())
end

-- Add a localized tooltip to an independent saved-preference control.
local function explain(button, hint)
    -- Describe the setting under the pointer without changing its saved value.
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(self:GetText())
        GameTooltip:AddLine(hint, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    -- Remove the setting tooltip when the pointer leaves the control.
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Create the gear and a reusable dialog containing the three requested switches.
function UI.CreateSettings()
    local gear = CreateFrame("Button", nil, UI.frame)
    UI.settingsButton = gear
    gear:SetSize(25, 25)
    gear:SetPoint("TOPRIGHT", UI.frame, "TOPRIGHT", -48, -10)
    gear:SetScript("OnClick", UI.ShowSettings)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetAllPoints(gear)
    gear.icon:SetAtlas("common-dropdown-a-button-settings-shadowless")
    gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- Identify the gear as the entry point to the saved addon preferences.
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L.SETTINGS)
        GameTooltip:AddLine(L.SETTINGS_HINT, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    -- Clear the gear tooltip after the pointer leaves the title bar.
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local panel = UI.Panel(nil, 320, 178, "settings")
    UI.settings = panel
    UI.Text(panel, "large", 16, -14, 260):SetText(L.SETTINGS)
    -- Close only the settings dialog through its title-bar button.
    panel.closeButton = UI.Button(panel, "X", 25, 280, -10, function() panel:Hide() end)
    UI.chatWarningsButton = UI.Button(panel, "", 288, 16, -54, ns.ToggleChatWarnings)
    UI.screenWarningsButton = UI.Button(panel, "", 288, 16, -88, ns.ToggleScreenWarnings)
    UI.keepWindowOpenButton = UI.Button(panel, "", 288, 16, -122, ns.ToggleKeepWindowOpen)
    explain(UI.chatWarningsButton, L.CHAT_WARNINGS_HINT)
    explain(UI.screenWarningsButton, L.SCREEN_WARNINGS_HINT)
    explain(UI.keepWindowOpenButton, L.KEEP_WINDOW_OPEN_HINT)
    panel:Hide()
end
