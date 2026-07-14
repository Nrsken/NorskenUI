---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local table_insert = table.insert
local pairs, ipairs = pairs, ipairs
local tonumber, tostring = tonumber, tostring
local wipe = wipe
local CreateFrame = CreateFrame
local C_Spell = C_Spell

local DUNGEON_INFO = {
    -- Dungeons
    Dungeon_MagistersTerrace  = { key = "MagistersTerrace", name = "Magisters' Terrace" },
    Dungeon_MaisaraCaverns    = { key = "MaisaraCaverns", name = "Maisara Caverns" },
    Dungeon_NexusPointXenas   = { key = "NexusPointXenas", name = "Nexus-Point Xenas" },
    Dungeon_WindrunnerSpire   = { key = "WindrunnerSpire", name = "Windrunner Spire" },
    Dungeon_AlgetharAcademy   = { key = "AlgetharAcademy", name = "Algeth'ar Academy" },
    Dungeon_PitOfSaron        = { key = "PitOfSaron", name = "Pit of Saron" },
    Dungeon_SeatOfTriumvirate = { key = "SeatOfTriumvirate", name = "Seat of the Triumvirate" },
    Dungeon_Skyreach          = { key = "Skyreach", name = "Skyreach" },
    -- Raids
    Raid_TheDreamrift         = { key = "TheDreamrift", name = "The Dreamrift" },
    Raid_TheVoidspire         = { key = "TheVoidspire", name = "The Voidspire" },
    Raid_MarchOnQuelDanas     = { key = "MarchOnQuelDanas", name = "March on Quel'Danas" },
}

local SUB_TABS = {
    { id = "trigger", text = "Trigger" },
    { id = "display", text = "Display" },
    { id = "load",    text = "Load" },
    { id = "actions", text = "Actions" },
}

local TRIGGER_TYPE_OPTIONS = {
    { key = "timer",    text = "Timer" },
    { key = "announce", text = "Announce" },
}

local MESSAGE_OPERATOR_OPTIONS = {
    { key = "find",  text = "Contains" },
    { key = "==",    text = "Exact Match" },
    { key = "match", text = "Pattern" },
}

local COMPARISON_OPTIONS = {
    { key = "<",  text = "< (less than)" },
    { key = "<=", text = "<= (less or equal)" },
    { key = "==", text = "= (equal)" },
    { key = ">=", text = ">= (greater or equal)" },
    { key = ">",  text = "> (greater than)" },
}

local DISPLAY_TYPE_OPTIONS = {
    { key = "bar",  text = "Bar" },
    { key = "text", text = "Text Only" },
}

local SIDEBAR_WIDTH = 191
local BUTTON_HEIGHT = 28
local LIST_PADDING = 4

local TAB_BAR_HEIGHT = 30

local dungeonStates = {}
local currentPreviewDungeon = nil
local previewActive = false

local function GetModule()
    if NRSKNUI then
        return NRSKNUI:GetModule("DungeonTimers", true)
    end
    return nil
end

local function StopPreview()
    previewActive = false
    currentPreviewDungeon = nil
    local mod = GetModule()
    if mod then
        if mod.DisablePreviews then
            mod:DisablePreviews()
        end
        if mod.HideAll then
            mod:HideAll()
        end
    end
end

local function StartDungeonPreview(dungeonKey)
    if not GUIFrame or not GUIFrame:IsShown() then return end

    StopPreview()

    if not dungeonKey then return end

    currentPreviewDungeon = dungeonKey
    previewActive = true

    local mod = GetModule()
    if not mod then return end

    if mod.EnablePreviews then mod:EnablePreviews() end

    local function loopCallback()
        if not GUIFrame or not GUIFrame:IsShown() then
            return
        end
        if previewActive and currentPreviewDungeon == dungeonKey then
            local m = GetModule()
            if m and m.PreviewDungeon and m.previewsAllowed then
                m:PreviewDungeon(dungeonKey, loopCallback)
            end
        end
    end

    if mod.PreviewDungeon then
        mod:PreviewDungeon(dungeonKey, loopCallback)
    end
end
GUIFrame.contentCleanupCallbacks = GUIFrame.contentCleanupCallbacks or {}
GUIFrame.contentCleanupCallbacks["DungeonTimers"] = StopPreview

GUIFrame.onCloseCallbacks = GUIFrame.onCloseCallbacks or {}
GUIFrame.onCloseCallbacks["DungeonTimers"] = StopPreview

local VALID_SUB_TABS = { trigger = true, display = true, load = true, actions = true }

local function GetDungeonState(dungeonKey)
    if not dungeonStates[dungeonKey] then
        dungeonStates[dungeonKey] = {
            selectedTriggerId = nil,
            currentSubTab = "trigger",
            spellSearchFilter = "",
        }
    end
    if not VALID_SUB_TABS[dungeonStates[dungeonKey].currentSubTab] then
        dungeonStates[dungeonKey].currentSubTab = "trigger"
    end
    return dungeonStates[dungeonKey]
end

local function CreateSpellIconPreview(parent, spellId, size)
    size = size or 32
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(size)

    local iconFrame = CreateFrame("Frame", nil, container)
    iconFrame:SetSize(size, size)
    iconFrame:SetPoint("LEFT", container, "LEFT", 0, -6)

    iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.texture:SetPoint("TOPLEFT", 1, -1)
    iconFrame.texture:SetPoint("BOTTOMRIGHT", -1, 1)

    local texture = spellId and spellId ~= "" and C_Spell.GetSpellTexture(tonumber(spellId))
    if texture then
        iconFrame.texture:SetTexture(texture)
        iconFrame.texture:SetZoom()
    else
        iconFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    local border = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)

    local spellInfo = spellId and spellId ~= "" and C_Spell.GetSpellInfo(tonumber(spellId))
    local spellName = spellInfo and spellInfo.name or "No spell selected"

    local nameLabel = container:CreateFontString(nil, "OVERLAY")
    nameLabel:SetPoint("LEFT", iconFrame, "RIGHT", Theme.paddingSmall, 0)
    nameLabel:SetFont(NRSKNUI.Media.Fonts.Expressway, Theme.fontSizeSmall, "OUTLINE")
    nameLabel:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3], 1)
    nameLabel:SetText(spellName)

    local oldEnter = container:GetScript("OnEnter")
    local oldLeave = container:GetScript("OnLeave")
    container:SetScript("OnEnter", function(self, ...)
        if oldEnter then oldEnter(self, ...) end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 30, 0)
        GameTooltip:SetSpellByID(spellId)
        GameTooltip:Show()
    end)
    container:SetScript("OnLeave", function(self, ...)
        if oldLeave then oldLeave(self, ...) end
        GameTooltip:Hide()
    end)

    return container
end

local function CreateDungeonPanel(dungeonId)
    local info = DUNGEON_INFO[dungeonId]
    if not info then return nil end

    local dungeonKey = info.key
    local state = GetDungeonState(dungeonKey)

    return function(container)
        local DT_GUI = NRSKNUI.GUI and NRSKNUI.GUI.DungeonTimers
        if DT_GUI then
            if DT_GUI.HideBarPreviews then DT_GUI.HideBarPreviews() end
            if DT_GUI.HideTextPreviews then DT_GUI.HideTextPreviews() end
        end

        local db = NRSKNUI.db and NRSKNUI.db.profile.DungeonTimers
        if not db then return nil end

        if not db.Dungeons then db.Dungeons = {} end
        if not db.Dungeons[dungeonKey] then
            db.Dungeons[dungeonKey] = { Enabled = true, Triggers = {} }
        end

        local dungeonDb = db.Dungeons[dungeonKey]
        if not dungeonDb.Triggers then dungeonDb.Triggers = {} end

        if state.selectedTriggerId and not dungeonDb.Triggers[state.selectedTriggerId] then
            state.selectedTriggerId = nil
            StopPreview()
        end

        local selectedTrigger = state.selectedTriggerId and dungeonDb.Triggers[state.selectedTriggerId] or nil

        local function ApplySettings()
            local mod = GetModule()
            if mod then
                if state.selectedTriggerId then
                    local frameKey = dungeonKey .. "_" .. state.selectedTriggerId
                    if mod.triggerFrames and mod.triggerFrames[frameKey] then
                        mod.triggerFrames[frameKey]:Hide()
                        mod.triggerFrames[frameKey] = nil
                    end
                end
                if mod.ApplySettings then
                    mod:ApplySettings()
                end
            end
            if state.selectedTriggerId then
                StartDungeonPreview(dungeonKey)
            end
        end

        local function RefreshContent()
            C_Timer.After(0.05, function()
                GUIFrame:RefreshContent()
            end)
        end

        local panel = CreateFrame("Frame", nil, container)
        panel:SetAllPoints()

        panel:SetScript("OnHide", function()
            if currentPreviewDungeon == dungeonKey then
                StopPreview()
            end
        end)

        local RenderContent
        local BuildTimerList
        local UpdateTimerListSelection

        local miniSidebar = NRSKNUI.GUI.CreateMiniSidebar(panel, {
            sidebarWidth = SIDEBAR_WIDTH,
            listPadding = LIST_PADDING,
            itemHeight = BUTTON_HEIGHT,
            itemSpacing = 2,
            customListRendering = true,
            buttonArea = {
                layout = "horizontal",
                buttonHeight = BUTTON_HEIGHT,
                spacing = LIST_PADDING,
                rowSpacing = 2,
                rows = {
                    {
                        {
                            text = "New",
                            tooltip = "Create New Timer",
                            onClick = function()
                                local mod = GetModule()
                                if mod and mod.CreateTrigger then
                                    local newId = mod:CreateTrigger(dungeonKey)
                                    if newId then
                                        state.selectedTriggerId = newId
                                        selectedTrigger = dungeonDb.Triggers[newId]
                                        BuildTimerList()
                                        RenderContent(state.currentSubTab)
                                        StartDungeonPreview(dungeonKey)
                                    end
                                end
                            end,
                        },
                        {
                            text = "Dup",
                            tooltip = "Duplicate Selected Timer",
                            onClick = function()
                                if state.selectedTriggerId then
                                    local mod = GetModule()
                                    if mod and mod.DuplicateTrigger then
                                        local newId = mod:DuplicateTrigger(dungeonKey, state.selectedTriggerId)
                                        if newId then
                                            state.selectedTriggerId = newId
                                            selectedTrigger = dungeonDb.Triggers[newId]
                                            BuildTimerList()
                                            RenderContent(state.currentSubTab)
                                            StartDungeonPreview(dungeonKey)
                                        end
                                    end
                                end
                            end,
                        },
                        {
                            text = "Del",
                            tooltip = "Delete Selected Timer",
                            onClick = function()
                                if state.selectedTriggerId then
                                    local mod = GetModule()
                                    if mod and mod.DeleteTrigger then
                                        mod:DeleteTrigger(dungeonKey, state.selectedTriggerId)
                                        state.selectedTriggerId = nil
                                        selectedTrigger = nil
                                        BuildTimerList()
                                        RenderContent(state.currentSubTab)
                                        StartDungeonPreview(dungeonKey)
                                    end
                                end
                            end,
                        },
                    },
                    {
                        {
                            icon = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga",
                            iconRotation = 180,
                            tooltip = "Move Timer Up",
                            onClick = function()
                                if state.selectedTriggerId then
                                    local mod = GetModule()
                                    if mod and mod.MoveTrigger then
                                        local newId = mod:MoveTrigger(dungeonKey, state.selectedTriggerId, "up")
                                        if newId then
                                            state.selectedTriggerId = newId
                                            selectedTrigger = dungeonDb.Triggers[newId]
                                            BuildTimerList()
                                            RenderContent(state.currentSubTab)
                                            StartDungeonPreview(dungeonKey)
                                        end
                                    end
                                end
                            end,
                        },
                        {
                            icon = "Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga",
                            tooltip = "Move Timer Down",
                            onClick = function()
                                if state.selectedTriggerId then
                                    local mod = GetModule()
                                    if mod and mod.MoveTrigger then
                                        local newId = mod:MoveTrigger(dungeonKey, state.selectedTriggerId, "down")
                                        if newId then
                                            state.selectedTriggerId = newId
                                            selectedTrigger = dungeonDb.Triggers[newId]
                                            BuildTimerList()
                                            RenderContent(state.currentSubTab)
                                            StartDungeonPreview(dungeonKey)
                                        end
                                    end
                                end
                            end,
                        },
                    },
                },
            },
            contentType = "tabbed",
            tabs = SUB_TABS,
            tabBarHeight = TAB_BAR_HEIGHT,
            defaultTab = state.currentSubTab,
            onTabChanged = function(tabId)
                state.currentSubTab = tabId
                RenderContent(tabId)
            end,
        })

        local listChild = miniSidebar.listChild
        local contentArea = miniSidebar.contentArea
        local scrollChild = contentArea.scrollChild
        local activeCards = contentArea.activeCards or {}

        -- Module disabled state
        local isModuleDisabled = db.Enabled == false
        if isModuleDisabled then
            miniSidebar.panel:SetAlpha(0.5)
            for _, btn in ipairs(miniSidebar.actionButtons or {}) do
                btn:EnableMouse(false)
            end
        end

        local timerButtons = {}

        local function CreateTimerButton(index, triggerId, triggerData)
            local btn = CreateFrame("Button", nil, listChild)
            btn:SetHeight(BUTTON_HEIGHT)
            btn:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -(index - 1) * (BUTTON_HEIGHT + 2))
            btn:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", 0, -(index - 1) * (BUTTON_HEIGHT + 2))
            btn.triggerId = triggerId

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0)
            btn.bg = bg

            local hover = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
            hover:SetAllPoints()
            hover:SetColorTexture(1, 1, 1, 0.05)
            hover:Hide()
            btn.hover = hover

            local selected = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
            selected:SetAllPoints()
            selected:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.15)
            selected:Hide()
            btn.selected = selected

            local accentBar = btn:CreateTexture(nil, "OVERLAY")
            accentBar:SetWidth(2)
            accentBar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            accentBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
            accentBar:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            accentBar:Hide()
            btn.accentBar = accentBar

            local iconSize = BUTTON_HEIGHT - 6
            local iconBorder = CreateFrame("Frame", nil, btn, "BackdropTemplate")
            iconBorder:SetSize(iconSize + 2, iconSize + 2)
            iconBorder:SetPoint("LEFT", btn, "LEFT", 5, 0)
            iconBorder:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            iconBorder:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
            btn.iconBorder = iconBorder

            local spellIcon = btn:CreateTexture(nil, "ARTWORK")
            spellIcon:SetSize(iconSize, iconSize)
            spellIcon:SetPoint("CENTER", iconBorder, "CENTER", 0, 0)

            local spellId = triggerData.spellId and tonumber(triggerData.spellId)
            if spellId and spellId > 0 then
                local iconTexture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId)
                if iconTexture then
                    spellIcon:SetTexture(iconTexture)
                else
                    spellIcon:SetTexture(134400)
                end
            else
                spellIcon:SetTexture(134400)
            end
            spellIcon:SetZoom()
            btn.spellIcon = spellIcon

            local typeIndicator = btn:CreateFontString(nil, "OVERLAY")
            typeIndicator:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
            NRSKNUI:ApplyThemeFont(typeIndicator, "small")

            local isBar = triggerData.displayType == "bar"
            if isBar then
                typeIndicator:SetText("B")
                typeIndicator:SetTextColor(0.4, 0.7, 1.0, 0.9)
            else
                typeIndicator:SetText("T")
                typeIndicator:SetTextColor(0.4, 1.0, 0.5, 0.9)
            end
            btn.typeIndicator = typeIndicator

            local hasSound = (triggerData.actionOnShowSound and triggerData.actionOnShowSound ~= "" and triggerData.actionOnShowSound ~= "None")
                or (triggerData.actionOnHideSound and triggerData.actionOnHideSound ~= "" and triggerData.actionOnHideSound ~= "None")
            local soundIndicator = btn:CreateFontString(nil, "OVERLAY")
            soundIndicator:SetPoint("RIGHT", typeIndicator, "LEFT", -2, 0)
            NRSKNUI:ApplyThemeFont(soundIndicator, "small")
            if hasSound then
                soundIndicator:SetText("S")
                soundIndicator:SetTextColor(1.0, 0.8, 0.3, 0.9)
            else
                soundIndicator:SetText("")
            end
            btn.soundIndicator = soundIndicator

            local label = btn:CreateFontString(nil, "OVERLAY")
            label:SetPoint("LEFT", iconBorder, "RIGHT", 6, 0)
            label:SetPoint("RIGHT", soundIndicator, "LEFT", -2, 0)
            label:SetJustifyH("LEFT")
            NRSKNUI:ApplyThemeFont(label, "small")
            local displayName = triggerData.name or ("Timer " .. triggerId)
            if #displayName > 21 then
                displayName = displayName:sub(1, 21) .. ".."
            end
            label:SetText(displayName)
            label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
            btn.label = label

            btn:SetScript("OnEnter", function(self)
                if state.selectedTriggerId ~= self.triggerId then
                    self.hover:Show()
                    self.label:SetTextColor(1, 1, 1, 1)
                end
            end)

            btn:SetScript("OnLeave", function(self)
                self.hover:Hide()
                if state.selectedTriggerId ~= self.triggerId then
                    self.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                end
            end)

            btn:SetScript("OnClick", function(self)
                state.selectedTriggerId = self.triggerId
                selectedTrigger = dungeonDb.Triggers[state.selectedTriggerId]
                UpdateTimerListSelection()
                RenderContent(state.currentSubTab)
                StartDungeonPreview(dungeonKey)
            end)

            return btn
        end

        local function UpdateTimerListSelectionVisuals()
            for _, btn in ipairs(timerButtons) do
                if btn.triggerId == state.selectedTriggerId then
                    btn.selected:Show()
                    btn.accentBar:Show()
                    btn.label:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                else
                    btn.selected:Hide()
                    btn.accentBar:Hide()
                    btn.label:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
                end
            end
        end

        BuildTimerList = function()
            for _, btn in ipairs(timerButtons) do
                btn:Hide()
                btn:SetParent(nil)
            end
            wipe(timerButtons)

            local sortedTriggers = {}
            for id, trigger in pairs(dungeonDb.Triggers) do
                table_insert(sortedTriggers, { id = id, data = trigger })
            end
            table.sort(sortedTriggers, function(a, b) return tonumber(a.id) < tonumber(b.id) end)

            for i, item in ipairs(sortedTriggers) do
                local btn = CreateTimerButton(i, item.id, item.data)
                table_insert(timerButtons, btn)
            end

            local listHeight = #sortedTriggers * (BUTTON_HEIGHT + 2)
            miniSidebar.SetListHeight(math.max(listHeight, 1))

            UpdateTimerListSelectionVisuals()
        end

        function UpdateTimerListSelection()
            UpdateTimerListSelectionVisuals()
        end

        BuildTimerList()

        -- Trigger tab
        local function RenderTriggerTab(yOffset)
            if not selectedTrigger then
                local card = GUIFrame:CreateCard(scrollChild, "No Timer Selected", yOffset)
                card:AddLabel("Click + to create a new timer or select one from the list on the left.")
                table_insert(activeCards, card)
                return yOffset + card:GetContentHeight() + (Theme.paddingSmall)
            end

            local padding = Theme.paddingSmall

            -- Card 1: Basic settings
            local card1 = GUIFrame:CreateCard(scrollChild, "Basic Settings", yOffset)
            table_insert(activeCards, card1)

            local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
            local enableTrigger = GUIFrame:CreateCheckbox(row1, "Enabled", {
                value = selectedTrigger.enabled ~= false,
                callback = function(checked)
                    selectedTrigger.enabled = checked
                    ApplySettings()
                end
            })
            row1:AddWidget(enableTrigger, 1)
            card1:AddRow(row1, Theme.rowHeight)

            local separator1 = GUIFrame:CreateSeparator(card1.content)
            card1:AddRow(separator1, Theme.rowHeightSeparator)

            local row2 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
            local nameInput = GUIFrame:CreateEditBox(row2, "Timer Name", {
                value = selectedTrigger.name or "",
                callback = function(text)
                    selectedTrigger.name = text
                    ApplySettings()
                    RefreshContent()
                end
            })
            row2:AddWidget(nameInput, 0.5)

            local typeDropdown = GUIFrame:CreateDropdown(row2, "Trigger Type", {
                options = TRIGGER_TYPE_OPTIONS,
                value = selectedTrigger.triggerType or "timer",
                callback = function(key)
                    selectedTrigger.triggerType = key
                    ApplySettings()
                end
            })
            row2:AddWidget(typeDropdown, 0.5)
            card1:AddRow(row2, Theme.rowHeightLast, 0)

            yOffset = yOffset + card1:GetContentHeight() + padding

            -- Card 2: Filters
            local card2 = GUIFrame:CreateCard(scrollChild, "Trigger Filters", yOffset)
            table_insert(activeCards, card2)

            local row3 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
            local spellInput = GUIFrame:CreateEditBox(row3, "Spell ID (optional)", {
                value = selectedTrigger.spellId or "",
                callback = function(text)
                    selectedTrigger.spellId = text
                    ApplySettings()
                    RefreshContent()
                end
            })
            row3:AddWidget(spellInput, 0.5)

            local iconPreview = CreateSpellIconPreview(row3, selectedTrigger.spellId, 24)
            row3:AddWidget(iconPreview, 0.5)
            card2:AddRow(row3, Theme.rowHeight)

            local row4 = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
            local msgInput = GUIFrame:CreateEditBox(row4, "Message Filter (optional)", {
                value = selectedTrigger.message or "",
                callback = function(text)
                    selectedTrigger.message = text
                    ApplySettings()
                end
            })
            row4:AddWidget(msgInput, 0.5)

            local msgOpDropdown = GUIFrame:CreateDropdown(row4, "Match", {
                options = MESSAGE_OPERATOR_OPTIONS,
                value = selectedTrigger.messageOperator or "find",
                callback = function(key)
                    selectedTrigger.messageOperator = key
                    ApplySettings()
                end
            })
            row4:AddWidget(msgOpDropdown, 0.5)
            card2:AddRow(row4, Theme.rowHeight)

            local row5b = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
            local castBarCheck = GUIFrame:CreateCheckbox(row5b, "Exclude BigWigs cast bars", {
                tooltip =
                "Some BigWigs bars are used for both timers and casts, this setting makes the trigger only look for timers, ignoring casts.",
                value = selectedTrigger.excludeCastBars == true,
                callback = function(checked)
                    selectedTrigger.excludeCastBars = checked
                    ApplySettings()
                end
            })
            row5b:AddWidget(castBarCheck, 1)
            card2:AddRow(row5b, Theme.rowHeightLast, 0)

            yOffset = yOffset + card2:GetContentHeight() + padding

            -- Card 3: Remaining time condition
            local card3 = GUIFrame:CreateCard(scrollChild, "Time Conditions", yOffset)
            table_insert(activeCards, card3)

            local row6 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
            local remCheck = GUIFrame:CreateCheckbox(row6, "Enable remaining time condition", {
                value = selectedTrigger.remainingEnabled == true,
                callback = function(checked)
                    selectedTrigger.remainingEnabled = checked
                    ApplySettings()
                    RefreshContent()
                end
            })
            row6:AddWidget(remCheck, 1)
            card3:AddRow(row6, Theme.rowHeight)

            if selectedTrigger.remainingEnabled then
                local row7 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
                local remOpDropdown = GUIFrame:CreateDropdown(row7, "Operator", {
                    options = COMPARISON_OPTIONS,
                    value = selectedTrigger.remainingOperator or "<",
                    callback = function(key)
                        selectedTrigger.remainingOperator = key
                        ApplySettings()
                    end
                })
                row7:AddWidget(remOpDropdown, 0.5)

                local remSlider = GUIFrame:CreateSlider(row7, "Seconds", {
                    min = 1,
                    max = 60,
                    step = 1,
                    value = selectedTrigger.remainingValue or 5,
                    labelWidth = 60,
                    callback = function(val)
                        selectedTrigger.remainingValue = val
                        ApplySettings()
                    end
                })
                row7:AddWidget(remSlider, 0.5)
                card3:AddRow(row7, Theme.rowHeight)
            end

            local separator2 = GUIFrame:CreateSeparator(card3.content)
            card3:AddRow(separator2, Theme.rowHeightSeparator)

            local row5 = GUIFrame:CreateRow(card3.content, Theme.rowHeightLast)
            local offsetSlider = GUIFrame:CreateSlider(row5, "Timer Offset (seconds)", {
                min = -10,
                max = 10,
                step = 0.5,
                value = selectedTrigger.extendTimer or 0,
                labelWidth = 80,
                callback = function(val)
                    selectedTrigger.extendTimer = val
                    ApplySettings()
                end
            })
            row5:AddWidget(offsetSlider, 1)
            card3:AddRow(row5, Theme.rowHeightLast, 0)

            yOffset = yOffset + card3:GetContentHeight() + padding

            -- Card 4: BigWigs Spell Browser (always force refresh to avoid stale cache issues)
            local mod = GetModule()
            local spells = mod and mod.GetSpellsForDungeon and mod:GetSpellsForDungeon(dungeonKey, true) or {}
            local browserCard
            browserCard, yOffset = GUIFrame:CreateSpellBrowserCard(scrollChild, yOffset, {
                spells = spells,
                searchFilter = state.spellSearchFilter or "",
                onSearchChange = function(text)
                    state.spellSearchFilter = text
                    RefreshContent()
                end,
                onSpellSelect = function(spellId)
                    if selectedTrigger then
                        selectedTrigger.spellId = tostring(spellId)
                        ApplySettings()
                        RefreshContent()
                    end
                end,
            })
            table_insert(activeCards, browserCard)

            return yOffset
        end

        -- Display tab
        local function RenderDisplayTab(yOffset)
            if not selectedTrigger then
                local card = GUIFrame:CreateCard(scrollChild, "No Timer Selected", yOffset)
                card:AddLabel("Click + to create a new timer, or select one from the list on the left.")
                table_insert(activeCards, card)
                return yOffset + card:GetContentHeight() + (Theme.paddingSmall)
            end

            local padding = Theme.paddingSmall
            local isBar = (selectedTrigger.displayType or "bar") == "bar"

            -- Card 1: Display type
            local card1 = GUIFrame:CreateCard(scrollChild, "Display Type", yOffset)
            table_insert(activeCards, card1)

            local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeight)
            local displayDropdown = GUIFrame:CreateDropdown(row1, "Style", {
                options = DISPLAY_TYPE_OPTIONS,
                value = selectedTrigger.displayType or "bar",
                callback = function(key)
                    selectedTrigger.displayType = key
                    ApplySettings()
                    RefreshContent()
                end
            })
            row1:AddWidget(displayDropdown, 1)
            card1:AddRow(row1, Theme.rowHeight)

            yOffset = yOffset + card1:GetContentHeight() + padding

            -- Card 2: Text format
            if isBar then
                -- Bar text settings
                local card3
                card3, yOffset = GUIFrame:CreateTextFormatCard(scrollChild, yOffset, {
                    title = "Text 1",
                    db = selectedTrigger,
                    dbKeys = {
                        format = "barText1Format",
                        justify = "barText1Justify",
                        xOffset = "barText1XOffset",
                        yOffset = "barText1YOffset",
                    },
                    defaults = { format = "%n", justify = "LEFT", xOffset = 4, yOffset = 0 },
                    onChangeCallback = ApplySettings,
                })
                table_insert(activeCards, card3)

                local card3b
                card3b, yOffset = GUIFrame:CreateTextFormatCard(scrollChild, yOffset, {
                    title = "Text 2",
                    db = selectedTrigger,
                    dbKeys = {
                        format = "barText2Format",
                        justify = "barText2Justify",
                        xOffset = "barText2XOffset",
                        yOffset = "barText2YOffset",
                    },
                    defaults = { format = "%p", justify = "RIGHT", xOffset = -4, yOffset = 0 },
                    onChangeCallback = ApplySettings,
                })
                table_insert(activeCards, card3b)

                -- Card 3: Time display settings
                local card3c = GUIFrame:CreateCard(scrollChild, "Time Display", yOffset)
                table_insert(activeCards, card3c)

                local row3e = GUIFrame:CreateRow(card3c.content, Theme.rowHeightLast)
                local showDecimalsCheck = GUIFrame:CreateCheckbox(row3e, "Show Decimals", {
                    value = selectedTrigger.showDecimals == true,
                    callback = function(checked)
                        selectedTrigger.showDecimals = checked
                        ApplySettings()
                        RefreshContent()
                    end
                })
                row3e:AddWidget(showDecimalsCheck, selectedTrigger.showDecimals and 0.5 or 1)

                if selectedTrigger.showDecimals then
                    local decimalThresholdSlider = GUIFrame:CreateSlider(row3e, "Below (seconds)", {
                        min = 1,
                        max = 30,
                        step = 1,
                        value = selectedTrigger.decimalThreshold or 3,
                        labelWidth = 50,
                        callback = function(val)
                            selectedTrigger.decimalThreshold = val
                            ApplySettings()
                        end
                    })
                    row3e:AddWidget(decimalThresholdSlider, 0.5)
                end
                card3c:AddRow(row3e, Theme.rowHeightLast, 0)

                yOffset = yOffset + card3c:GetContentHeight() + padding
            else
                -- Text timer settings
                local card3 = GUIFrame:CreateCard(scrollChild, "Text Format", yOffset)
                table_insert(activeCards, card3)

                local row3 = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
                local formatInput = GUIFrame:CreateEditBox(row3, "Format String", {
                    value = selectedTrigger.textFormat or "%i %n %p",
                    callback = function(text)
                        selectedTrigger.textFormat = text
                        ApplySettings()
                        RefreshContent()
                    end
                })
                row3:AddWidget(formatInput, 1)
                card3:AddRow(row3, Theme.rowHeight)

                local row3c = GUIFrame:CreateRow(card3.content, Theme.rowHeight)
                local showDecimalsCheck = GUIFrame:CreateCheckbox(row3c, "Show Decimals", {
                    value = selectedTrigger.showDecimals == true,
                    callback = function(checked)
                        selectedTrigger.showDecimals = checked
                        ApplySettings()
                        RefreshContent()
                    end
                })
                row3c:AddWidget(showDecimalsCheck, selectedTrigger.showDecimals and 0.5 or 1)

                if selectedTrigger.showDecimals then
                    local decimalThresholdSlider = GUIFrame:CreateSlider(row3c, "Below (seconds)", {
                        min = 1,
                        max = 30,
                        step = 1,
                        value = selectedTrigger.decimalThreshold or 3,
                        labelWidth = 50,
                        callback = function(val)
                            selectedTrigger.decimalThreshold = val
                            ApplySettings()
                        end
                    })
                    row3c:AddWidget(decimalThresholdSlider, 0.5)
                end
                card3:AddRow(row3c, Theme.rowHeightLast, 0)

                yOffset = yOffset + card3:GetContentHeight() + padding
            end

            -- Card 4: Colors
            local card4 = GUIFrame:CreateCard(scrollChild, "Colors", yOffset)
            table_insert(activeCards, card4)

            if isBar then
                -- Bar color settings, has BigWigs color sync option so has more settings than text timers
                local row4 = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
                local bwColorCheck = GUIFrame:CreateCheckbox(row4, "Sync With BigWigs Bar Coloring", {
                    value = selectedTrigger.useBigWigsColors ~= false,
                    callback = function(checked)
                        selectedTrigger.useBigWigsColors = checked
                        ApplySettings()
                        RefreshContent()
                    end
                })
                row4:AddWidget(bwColorCheck, 1)

                if selectedTrigger.useBigWigsColors then
                    card4:AddRow(row4, Theme.rowHeightLast, 0)
                else
                    card4:AddRow(row4, Theme.rowHeight)

                    local separator = GUIFrame:CreateSeparator(card4.content)
                    card4:AddRow(separator, Theme.rowHeightSeparator)

                    local row5 = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
                    local barColorPicker = GUIFrame:CreateColorPicker(row5, "Bar Color", {
                        color = selectedTrigger.barColor,
                        callback = function(r, g, b, a)
                            selectedTrigger.barColor = { r, g, b, a }
                            ApplySettings()
                        end
                    })
                    row5:AddWidget(barColorPicker, 1)
                    card4:AddRow(row5, Theme.rowHeight)

                    local row5b = GUIFrame:CreateRow(card4.content, Theme.rowHeight)
                    local bgColorPicker = GUIFrame:CreateColorPicker(row5b, "Background Color", {
                        color = selectedTrigger.backgroundColor,
                        callback = function(r, g, b, a)
                            selectedTrigger.backgroundColor = { r, g, b, a }
                            ApplySettings()
                        end
                    })
                    row5b:AddWidget(bgColorPicker, 1)
                    card4:AddRow(row5b, Theme.rowHeight)

                    local row6 = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
                    local textColorPicker = GUIFrame:CreateColorPicker(row6, "Text Color", {
                        color = selectedTrigger.textColor,
                        callback = function(r, g, b, a)
                            selectedTrigger.textColor = { r, g, b, a }
                            ApplySettings()
                        end
                    })
                    row6:AddWidget(textColorPicker, 1)
                    card4:AddRow(row6, Theme.rowHeightLast, 0)
                end
            else
                -- Text timer color settings
                local row4 = GUIFrame:CreateRow(card4.content, Theme.rowHeightLast)
                local textColorPicker = GUIFrame:CreateColorPicker(row4, "Text Color", {
                    color = selectedTrigger.textColor,
                    callback = function(r, g, b, a)
                        selectedTrigger.textColor = { r, g, b, a }
                        ApplySettings()
                    end
                })
                row4:AddWidget(textColorPicker, 1)
                card4:AddRow(row4, Theme.rowHeightLast, 0)
            end

            yOffset = yOffset + card4:GetContentHeight() + padding

            return yOffset
        end

        -- Load tab
        local function RenderLoadTab(yOffset)
            if not selectedTrigger then
                local card = GUIFrame:CreateCard(scrollChild, "No Timer Selected", yOffset)
                card:AddLabel("Click + to create a new timer, or select one from the list on the left.")
                table_insert(activeCards, card)
                return yOffset + card:GetContentHeight() + Theme.paddingSmall
            end

            -- Card 1: Role/Spec/Class Filters
            local card1
            card1, yOffset = GUIFrame:CreateRoleFilterCard(scrollChild, yOffset, {
                db = selectedTrigger,
                onChangeCallback = ApplySettings,
                onRefreshCallback = RefreshContent,
            })
            table_insert(activeCards, card1)

            -- Card 2: Position Filters
            local card2
            card2, yOffset = GUIFrame:CreatePosFilterCard(scrollChild, yOffset, {
                db = selectedTrigger,
                onChangeCallback = ApplySettings,
                onRefreshCallback = RefreshContent,
            })
            table_insert(activeCards, card2)

            return yOffset
        end

        -- Actions tab
        local function RenderActionsTab(yOffset)
            if not selectedTrigger then
                local card = GUIFrame:CreateCard(scrollChild, "No Timer Selected", yOffset)
                card:AddLabel("Click + to create a new timer, or select one from the list on the left.")
                table_insert(activeCards, card)
                return yOffset + card:GetContentHeight() + Theme.paddingSmall
            end

            local card1
            card1, yOffset = GUIFrame:CreateSoundSettingsCard(scrollChild, yOffset, {
                db = selectedTrigger,
                onChangeCallback = ApplySettings,
            })
            table_insert(activeCards, card1)

            return yOffset
        end

        RenderContent = function(tabId)
            contentArea:ClearContent()

            local yOffset = Theme.paddingSmall

            if tabId == "trigger" then
                yOffset = RenderTriggerTab(yOffset)
            elseif tabId == "display" then
                yOffset = RenderDisplayTab(yOffset)
            elseif tabId == "load" then
                yOffset = RenderLoadTab(yOffset)
            elseif tabId == "actions" then
                yOffset = RenderActionsTab(yOffset)
            end

            contentArea:SetContentHeight(yOffset)
        end

        RenderContent(state.currentSubTab)

        -- Apply disabled state to all content
        if isModuleDisabled then
            for _, card in ipairs(activeCards) do
                if card.SetEnabled then
                    card:SetEnabled(false)
                end
            end
            for _, btn in ipairs(timerButtons) do
                btn:EnableMouse(false)
            end
        end

        C_Timer.After(0.1, function()
            if panel:IsShown() and not isModuleDisabled then
                StartDungeonPreview(dungeonKey)
            end
        end)

        return panel
    end
end

for sidebarId, info in pairs(DUNGEON_INFO) do
    GUIFrame:RegisterPanel(sidebarId, CreateDungeonPanel(sidebarId))
end
