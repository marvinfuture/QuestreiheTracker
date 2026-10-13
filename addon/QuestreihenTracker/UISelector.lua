local _, ns = ...
local UI, L = ns.UI, ns.L

-- Fold localized filter text literally without Lua pattern matching or saved catalog data.
local function folded(text)
    return (text or ""):gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):gsub("ẞ", "ß"):lower()
        :gsub("^%s+", ""):gsub("%s+$", "")
end

-- Show native animation or a verified-success check beside the submitted search action.
local function indicator(control, loading, success)
    control.spinner:SetShown(loading == true)
    control.check:SetShown(success == true and not loading)
end

-- Render one small failure message while retaining separate loading and verified-success states.
function UI.RenderQuestLookup()
    local panel, feedback = UI.selector, UI.searchFeedback
    local nameLookup, questLookup = ns.nameLookup, ns.questLookup
    local text, loading, success, kind = L.LOOKUP_HINT, false, false, nil
    if feedback then
        kind = feedback.kind
        loading = feedback.status == "LOADING"
        success = feedback.opened == true or (kind == "QUEST" and feedback.status == "READY")
        if kind == "NAME" and nameLookup then
            for _, result in ipairs(nameLookup.results or {}) do
                if result.kind == "QUEST_LINE" and result.selectable then success = true; break end
            end
        end
        if feedback.text then text = feedback.text
        elseif loading then text = L.SEARCH_LOADING
        elseif success then text = feedback.opened and L.SEARCH_SUCCESS or L.SEARCH_MATCHES
        else text = L.SEARCH_FAILURE end
    end
    if panel then
        panel.lookupStatus:SetText(text)
        panel.lookupStatus:SetTextColor(feedback and not loading and not success and not feedback.text and 1 or 0.85,
            feedback and not loading and not success and not feedback.text and 0.55 or 0.85, 0.65)
        indicator(panel.nameSearchButton, kind == "NAME" and loading, kind == "NAME" and success)
        indicator(panel.lookupButton, kind == "QUEST" and loading, kind == "QUEST" and success)
    end
    if UI.notice then
        local show = nameLookup or questLookup or (feedback and feedback.opened)
        UI.notice:SetText(show and (nameLookup and L.NAME_MAIN_NOTICE or text)
            or (ns.chain.empty and L.EMPTY_SELECTION or L.BLIZZARD_NOTICE))
        UI.notice:SetTextColor(show and 1 or 0.7, show and 0.8 or 0.7, show and 0.35 or 0.7)
    end
end

-- Apply a zone choice without changing Blizzard's quest tracking or loading every zone.
local function chooseZone(mapID)
    ns.BrowseZone(mapID)
    if UI.selector then UI.selector.scroll:SetVerticalScroll(0) end
end

-- Build native radio submenus from client map names, grouping only the filtered matches.
local function setupZoneMenu(owner, root)
    local panel = UI.selector
    local catalog = ns.WoW.GetZoneCatalog()
    local query = folded(panel.zoneFilter:GetText())
    root:SetScrollMode(260)
    -- Keep the dynamic current-zone choice available even when filtering other zones.
    root:CreateRadio(L.ZONE_CURRENT, function() return ns.WoW.questLines.browseMapID == nil end,
        -- Switch back to the player's dynamically followed zone.
        function() chooseZone(nil) end)
    local groups, count = {}, 0
    for _, zone in ipairs(catalog) do
        local groupName = zone.groupName or L.ZONE_OTHER
        if query == "" or folded(zone.name):find(query, 1, true) or folded(groupName):find(query, 1, true) then
            local group = groups[groupName]
            if not group then
                group = root:CreateButton(groupName)
                group:SetScrollMode(260)
                groups[groupName] = group
            end
            -- Evaluate the current session choice whenever Blizzard regenerates the menu.
            group:CreateRadio(zone.name, function(mapID) return ns.WoW.questLines.browseMapID == mapID end,
                chooseZone, zone.mapID)
            count = count + 1
        end
    end
    if count == 0 then root:CreateTitle(L.ZONE_NO_MATCHES) end
end

-- Reuse result widgets while keeping canceled queries separate from the selected zone.
function UI.RenderSelector()
    local panel = UI.selector
    if not panel then return end
    local chains, status, mapName = ns.WoW.BrowseQuestLines()
    UI.RenderQuestLookup()
    panel.zoneDropdown:OverrideText(ns.WoW.questLines.browseMapID and (mapName or L.ZONE_UNKNOWN) or L.ZONE_CURRENT)
    panel.backButton:SetShown(ns.nameLookup ~= nil)
    for _, button in ipairs(panel.buttons) do button:Hide(); button.chainID = nil end
    for _, label in ipairs(panel.labels) do label:Hide(); label:SetText("") end
    local offset, buttonIndex, labelIndex = 0, 0, 0
    -- Place a measured information row and reuse it after searches or zone changes.
    local function label(value, height)
        labelIndex = labelIndex + 1
        local text = panel.labels[labelIndex]
        if not text then text = UI.Text(panel.content, nil, 0, 0, 500); panel.labels[labelIndex] = text end
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offset)
        text:SetText(value)
        text:SetHeight(0)
        height = math.max(height, math.ceil(text:GetStringHeight()))
        text:SetHeight(height)
        text:Show()
        offset = offset + height + 8
    end
    -- Choose one complete client-supplied line from the current result list.
    local function choice(chain)
        buttonIndex = buttonIndex + 1
        local button = panel.buttons[buttonIndex]
        if not button then
            -- Apply only the line belonging to this reused choice and close the dialog.
            button = UI.Button(panel.content, "", 500, 0, 0, function(self)
                ns.Select(self.chainID)
                panel:Hide()
            end)
            -- Expose the complete localized name and map context without changing selection.
            button:SetScript("OnEnter", function(self)
                local selected = ns.WoW.GetQuestLine(self.chainID)
                if not selected then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(selected.name)
                GameTooltip:AddLine(L.LINE_ID .. ": " .. selected.questLineID, 0.85, 0.85, 0.85, true)
                local map = ns.WoW.questLines.maps[selected.mapID]
                if map then GameTooltip:AddLine(map.name, 0.85, 0.85, 0.85, true) end
                GameTooltip:Show()
            end)
            -- Retire the line tooltip when the pointer leaves this choice.
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            panel.buttons[buttonIndex] = button
        end
        button.chainID = chain.id
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offset)
        button:SetText(chain.loading and string.format(L.BLIZZARD_LINE_LOADING, chain.name) or chain.name)
        button:SetEnabled(not chain.loading)
        button:Show()
        offset = offset + 28
    end
    if ns.nameLookup then
        local results = ns.nameLookup.results or {}
        for _, result in ipairs(results) do
            if result.selectable and result.chain then choice(result.chain)
            elseif result.kind == "QUEST_LINE" then label(string.format(L.BLIZZARD_LINE_LOADING, result.name), 40)
            else
                local progress = result.completed == true and L.NAME_DONE
                    or (result.completed == false and L.NAME_NOT_DONE or L.NAME_UNKNOWN)
                local title = result.kind == "ACHIEVEMENT" and string.format(L.NAME_ACHIEVEMENT, result.name)
                    or string.format(L.NAME_CRITERION, result.name, result.achievementName or "")
                label(title .. "\n" .. progress .. "\n" .. L.NAME_UNRESOLVED, 60)
            end
        end
    else
        if status == "LOADING" then label(L.ZONE_LOADING, 36)
        elseif status ~= "READY" and not (UI.searchFeedback and UI.searchFeedback.kind == "CACHE") then
            label(status == "EMPTY" and L.ZONE_EMPTY or L.SEARCH_FAILURE, 36)
        end
        for _, chain in ipairs(chains) do choice(chain) end
    end
    panel.content:SetHeight(math.max(offset, 1))
end

-- Add native loading and success indicators next to one search action.
local function addIndicators(button)
    button.spinner = CreateFrame("Frame", nil, button, "SpinnerTemplate")
    button.spinner:SetSize(20, 20)
    button.spinner:SetPoint("LEFT", button, "RIGHT", 5, 0)
    button.spinner:Hide()
    button.check = button:CreateTexture(nil, "ARTWORK")
    button.check:SetSize(20, 20)
    button.check:SetPoint("LEFT", button, "RIGHT", 5, 0)
    button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button.check:Hide()
end

-- Toggle the structured search dialog and request only the current browse context.
function UI.ChooseChain()
    if UI.selector and UI.selector:IsShown() then UI.selector:Hide(); return end
    if not UI.selector then
        local panel = UI.Panel(nil, 560, 640, "selector")
        UI.selector = panel
        panel.buttons, panel.labels = {}, {}
        UI.Text(panel, "large", 16, -16, 492):SetText(L.SEARCH_TITLE)
        panel.trackedButton = UI.Button(panel, L.LOOKUP_TRACKED, 528, 16, -52, ns.UseTrackedQuest)
        UI.Text(panel, nil, 16, -90, 300):SetText(L.LOOKUP_ID)
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetSize(372, 24)
        input:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -111)
        input:SetAutoFocus(false)
        input:SetText("")
        panel.questIDInput = input
        -- Submit a validated numeric ID without querying while the user types.
        local function submitID()
            local digits = (input:GetText() or ""):match("^%s*(%d+)%s*$")
            input:ClearFocus()
            ns.LookupQuest(digits and tonumber(digits) or nil)
        end
        input:SetScript("OnEnterPressed", submitID)
        panel.lookupButton = UI.Button(panel, L.NAME_SEARCH, 102, 414, -111, submitID)
        addIndicators(panel.lookupButton)
        UI.Text(panel, nil, 16, -149, 300):SetText(L.LOOKUP_NAME)
        UI.Text(panel, "small", 16, -170, 400):SetText(L.NAME_DESCRIPTION)
        local nameInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        nameInput:SetSize(372, 24)
        nameInput:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -191)
        nameInput:SetAutoFocus(false)
        nameInput:SetMaxLetters(120)
        nameInput:SetText("")
        panel.nameInput = nameInput
        -- Start one finite name query only after clicking Suchen or pressing Enter.
        local function submitName()
            nameInput:ClearFocus()
            ns.LookupName(nameInput:GetText() or "")
        end
        nameInput:SetScript("OnEnterPressed", submitName)
        panel.nameSearchButton = UI.Button(panel, L.NAME_SEARCH, 102, 414, -191, submitName)
        addIndicators(panel.nameSearchButton)
        -- Retire stale result references and feedback when either search field changes.
        local function changed()
            ns.CancelQuestLookup()
            UI.searchFeedback = nil
            UI.RenderSelector()
        end
        input:SetScript("OnTextChanged", changed)
        nameInput:SetScript("OnTextChanged", changed)
        -- Close the search dialog and release keyboard focus through Escape.
        local function escape(self) self:ClearFocus(); panel:Hide() end
        input:SetScript("OnEscapePressed", escape)
        nameInput:SetScript("OnEscapePressed", escape)
        panel.lookupStatus = UI.Text(panel, "small", 16, -228, 520)
        panel.lookupStatus:SetHeight(34)
        UI.Rule(panel, 528, 16, -268)
        panel.zone = UI.Text(panel, nil, 16, -285, 48)
        panel.zone:SetText(L.ZONE_LABEL)
        panel.zoneDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
        panel.zoneDropdown:SetSize(285, 26)
        panel.zoneDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", 65, -277)
        panel.zoneDropdown:SetDefaultText(L.ZONE_CURRENT)
        -- Restore the browse list while retaining the explicit zone preference for this session.
        panel.backButton = UI.Button(panel, L.NAME_BACK_ZONE, 166, 378, -279, function()
            ns.CancelQuestLookup()
            UI.searchFeedback = nil
            UI.RenderSelector()
        end)
        panel.refresh = panel.backButton
        UI.Text(panel, "small", 16, -328, 100):SetText(L.ZONE_FILTER)
        panel.zoneFilter = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        panel.zoneFilter:SetSize(424, 24)
        panel.zoneFilter:SetPoint("TOPLEFT", panel, "TOPLEFT", 120, -319)
        panel.zoneFilter:SetAutoFocus(false)
        panel.zoneFilter:SetMaxLetters(80)
        panel.zoneFilter:SetText("")
        panel.zoneDropdown:SetupMenu(setupZoneMenu)
        -- Filter map labels locally; typing never requests quest lines for other zones.
        panel.zoneFilter:SetScript("OnTextChanged", function() panel.zoneDropdown:GenerateMenu() end)
        panel.zoneFilter:SetScript("OnEscapePressed", escape)
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -362)
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 52)
        panel.content = CreateFrame("Frame", nil, scroll)
        panel.content:SetSize(508, 1)
        scroll:SetScrollChild(panel.content)
        panel.scroll = scroll
        panel.cacheButton = UI.Button(panel, L.CLEAR_SEARCH_CACHE, 180, 16, -600, ns.ClearSearchCache)
        -- Explain what the addon owns before manually releasing its search cache.
        panel.cacheButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(L.CLEAR_SEARCH_CACHE)
            GameTooltip:AddLine(L.CACHE_HINT, 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        -- Dismiss the cache explanation when leaving the action.
        panel.cacheButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Offer the same close action in the footer as in the native title bar.
        UI.Button(panel, L.CLOSE, 100, 444, -600, function() panel:Hide() end)
        -- Finish dragging and retire query references whenever the dialog closes.
        panel:SetScript("OnHide", function(self)
            if self.dragging then
                self:StopMovingOrSizing()
                self.dragging = false
                local point, _, relativePoint, x, y = self:GetPoint()
                ns.db.panelPositions.selector = { point = point, relativePoint = relativePoint, x = x, y = y }
            end
            input:ClearFocus()
            nameInput:ClearFocus()
            panel.zoneFilter:ClearFocus()
            ns.CancelQuestLookup()
            for _, button in ipairs(panel.buttons) do button:Hide(); button.chainID = nil end
            for _, label in ipairs(panel.labels) do label:Hide(); label:SetText("") end
            panel.content:SetHeight(1)
            UI.RenderQuestLookup()
        end)
    end
    ns.WoW.SetBrowseZone(ns.WoW.questLines.browseMapID)
    ns.ScheduleRefresh()
    UI.RenderSelector()
    UI.selector.scroll:SetVerticalScroll(0)
    UI.selector:Show()
end
