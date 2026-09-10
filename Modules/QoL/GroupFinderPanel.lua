---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GroupFinderModule
local GroupFinder = NRSKNUI:GetModule('GroupFinder')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G
local GetTime = GetTime
local format = string.format
local CreateFrame = CreateFrame
local ipairs, next, type = ipairs, next, type
local ceil, floor, rad = math.ceil, math.floor, math.rad
local ShowUIPanel, HideUIPanel = ShowUIPanel, HideUIPanel

local GetRewardLevelForDifficultyLevel = C_MythicPlus and C_MythicPlus.GetRewardLevelForDifficultyLevel
local GetSeasonBestForMap = C_MythicPlus and C_MythicPlus.GetSeasonBestForMap

local GetKeystoneLevelRarityColor = C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor
local GetScoreRarityColor = C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
local LoadAddOn = C_AddOns and C_AddOns.LoadAddOn

local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
local GameTooltip = GameTooltip

-- Panel and layout.
local PANEL_WIDTH = 176
local PANEL_GAP = 0
local INSET = 10
local COLUMN_GAP = 6
local SECTION_GAP = 10
local TITLE_PITCH = 20

-- Sort direction/clear filter button.
local ICON_BUTTON_WIDTH = 24

-- Search row.
local BUTTON_HEIGHT = 24
local CROSS_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png'
local CROSS_ICON = 12

-- Dungeon grid.
local TOGGLE_HEIGHT = 34
local ROW_PITCH = 38
local DUNGEON_ART_ALPHA = 0.3
local DUNGEON_ART_SELECTED_ALPHA = 0.75

-- Role strip.
local ROLE_STRIP = {
    {
        key = 'hasTank',
        atlas = 'groupfinder-icon-role-micro-tank',
        tooltip = L['Has Tank'],
    },
    {
        key = 'hasHealer',
        atlas = 'groupfinder-icon-role-micro-heal',
        tooltip = L['Has Healer'],
    },
    {
        key = 'hasEither',
        label = L['Any'],
        tooltip = L['Has Either a Tank or Healer.'],
    },
}
local ROLE_STRIP_HEIGHT = 24
local ROLE_STRIP_GAP = 4
local ROLE_ICON_SIZE = 14
local ROLE_ICON_RESTING_ALPHA = 0.5

-- Filter buttons.
local FILTER_KEYS = {
    'needsRole',
    'noMySpec',
    'notDeclined',
}
local FILTER_LABELS = {
    needsRole = { L['Needs Role'], L['Only groups with an open slot for your role.'] },
    noMySpec = { L['No Duplicate Class'], L['Hides groups that already contain your class.'] },
    notDeclined = { L['Not Declined'], L['Hides groups that declined your application this session.'] },
}
local FILTER_HEIGHT = 22
local FILTER_PITCH = 26

-- Sort row.
local SORT_MODES = {
    {
        value = 'default',
        text = L['Default']
    },
    {
        value = 'overallScore',
        text = L['Leader Score'],
    },
    {
        value = 'dungeonScore',
        text = L['Dungeon Score'],
    },
}
local DROPDOWN_LABEL_HEIGHT = 14
local DROPDOWN_BUTTON_HEIGHT = 24
local ARROW_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga'
local ARROW_ICON = 16

-- Vault footer.
local FOOTER_HEIGHT = 24
local VAULT_SLOTS = { 1, 4, 8 }

-- Dungeon tooltip.
local UPGRADE_THREE_CHEST = 0.6
local UPGRADE_TWO_CHEST = 0.8

-- RaiderIO's default tuck.
local RAIDERIO_STOCK_OFFSET = -16
local RAIDERIO_PANEL_GAP_X = 0
local RAIDERIO_PANEL_GAP_Y = 1

-- Raider.IO coexistence --

function GroupFinder:EnsureRaiderIOAnchor()
    local anchor = _G.RaiderIO_ProfileTooltipAnchor
    if not anchor then return end

    if not anchor.NUIGroupFinderWrapped then
        anchor.NUIGroupFinderWrapped = true

        local original = anchor.SetPoint
        anchor.SetPoint = function(frame, point, relativeTo, relativePoint, x, y)
            local panel = GroupFinder.panel

            -- Remember RaiderIO's own tuck so reverting restores it exactly instead of drifting.
            if relativeTo == _G.PVEFrame then
                if type(x) == 'number' then
                    anchor.NUIStockOffsetX = x
                end
                if type(y) == 'number' then
                    anchor.NUIStockOffsetY = y
                end
            end

            if relativeTo == _G.PVEFrame or (panel and relativeTo == panel) then
                local stockX = anchor.NUIStockOffsetX or RAIDERIO_STOCK_OFFSET
                local stockY = anchor.NUIStockOffsetY or 0
                if panel and panel:IsShown() then
                    relativeTo = panel
                    x = stockX + RAIDERIO_PANEL_GAP_X
                    y = stockY + RAIDERIO_PANEL_GAP_Y
                else
                    relativeTo = _G.PVEFrame
                    x = stockX
                    y = stockY
                end
            end

            if relativePoint == nil and x == nil and y == nil then
                return original(frame, point, relativeTo)
            end
            return original(frame, point, relativeTo, relativePoint, x, y)
        end
    end

    -- Re-assert so a point that landed before the wrap (or before the panel moved) is corrected now.
    local point, relativeTo, relativePoint, x, y = anchor:GetPoint(1)
    if point then
        anchor:ClearAllPoints()
        anchor:SetPoint(point, relativeTo, relativePoint, x, y)
    end
end

---@return number
local function SearchSecondsLeft()
    local throttle = GroupFinder.ServerSearchThrottle
    local last = GroupFinder.lastServerSearch or 0

    return throttle - (GetTime() - last)
end

local DriveSearchCountdown

---A filler rather than a plain title, the throttle line only shows while one is running.
---@param tooltip GameTooltip
---@param button KajiGUIButton
local function FillSearchTooltip(tooltip, button)
    local accent = GroupFinder:GetAccentColors()
    local tS = Theme.textSecondary
    local throttle = GroupFinder.ServerSearchThrottle

    tooltip:SetText(L['Search'], accent[1], accent[2], accent[3], 1)
    tooltip:AddLine(format(L['Fetches a fresh list at most once every %d seconds. Clicks in between re-filter the current results.'], throttle), tS[1], tS[2], tS[3], true)

    local remaining = SearchSecondsLeft()
    if remaining > 0 then
        tooltip:AddLine(format(L['New search in %d sec.'], ceil(remaining)), accent[1], accent[2], accent[3])
        DriveSearchCountdown(button)
    end
end

---Rebuilds in place, for a countdown that started while the tooltip was already open.
---@param button KajiGUIButton
local function RefreshSearchTooltip(button)
    if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= button then return end

    GameTooltip:ClearLines()
    FillSearchTooltip(GameTooltip, button)
    GameTooltip:Show()
end

---A tooltip builds once on enter, so the countdown needs its own driver to keep ticking under a resting cursor.
---@param button KajiGUIButton
function DriveSearchCountdown(button)
    local panel = GroupFinder.panel
    if panel:GetScript('OnUpdate') then return end

    local shownSecond = ceil(SearchSecondsLeft())

    panel:SetScript('OnUpdate', function(self)
        if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= button then
            self:SetScript('OnUpdate', nil)
            return
        end

        local remaining = ceil(SearchSecondsLeft())
        if remaining == shownSecond then return end
        shownSecond = remaining

        -- The rebuild re-arms this driver, so it has to stop itself once the countdown is spent.
        if remaining <= 0 then
            self:SetScript('OnUpdate', nil)
        end

        RefreshSearchTooltip(button)
    end)
end

---@param tooltip GameTooltip
local function FillVaultTooltip(tooltip)
    local count, levels = GroupFinder:GetWeeklyRuns()
    local accent = GroupFinder:GetAccentColors()

    tooltip:SetText(format(L['Keys Done This Week: %d'], count), accent[1], accent[2], accent[3], 1)

    for _, slot in ipairs(VAULT_SLOTS) do
        local level = levels[slot]
        if level then
            local reward = GetRewardLevelForDifficultyLevel(level)
            tooltip:AddDoubleLine(format(L['Best %d'], slot), format('+%d  (%d)', level, reward or 0), 1, 1, 1, 1, 1, 1)
        else
            tooltip:AddDoubleLine(format(L['Best %d'], slot), '-', 1, 1, 1, 0.5, 0.5, 0.5)
        end
    end

    tooltip:AddLine(' ')
    tooltip:AddLine(L['Click to open the Great Vault.'], 1, 1, 1, true)
end

-- Panel construction --

function GroupFinder:GetPanelColors()
    if Skinning then
        return Skinning.db.General.BackgroundColor, Skinning.db.General.BorderColor
    end
    return Theme.bgDark, Theme.border
end

function GroupFinder:GetWidgetColors()
    if Skinning then
        return Skinning.db.General.WidgetBackgroundColor
    end
    return Theme.bgDark
end

function GroupFinder:GetAccentColors()
    if Skinning then
        local r, g, b, a = Skinning:GetAccentColor()
        return { r, g, b, a }
    end
    return Theme.accent
end

---Width changes reflow the layout rather than rebuilding the widgets.
function GroupFinder:ApplyPanelWidth()
    local panel = self.panel
    if not panel then return end

    panel:SetWidth(self.db.PanelWidth or PANEL_WIDTH)
    panel.laidOut = nil
end

function GroupFinder:CreatePanel()
    if self.panel then return self.panel end

    local pve = _G.PVEFrame
    if not pve then return end

    local panel = CreateFrame('Frame', 'NorskenUIGroupFinderPanel', pve, 'BackdropTemplate')
    panel:SetPoint('TOPLEFT', pve, 'TOPRIGHT', PANEL_GAP, -1)
    panel:SetPoint('BOTTOMLEFT', pve, 'BOTTOMRIGHT', PANEL_GAP, 1)
    panel:SetWidth(self.db.PanelWidth or PANEL_WIDTH)
    panel:SetBackdrop({ bgFile = NRSKNUI.WhiteTexture, edgeFile = NRSKNUI.WhiteTexture, edgeSize = 1 })

    local bgColor, borderColor = self:GetPanelColors()
    panel:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    panel:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    panel:Hide()

    panel.dungeonButtons = {}
    panel.filterButtons = {}
    panel.roleButtons = {}

    self.panel = panel
    self:BuildPanelWidgets()

    return panel
end

function GroupFinder:BuildPanelWidgets()
    local panel = self.panel

    local widgetColor = self:GetWidgetColors()
    local accent = self:GetAccentColors()

    panel.FiltersTitle = panel:CreateFontString(nil, 'OVERLAY')
    GUI:ApplyFont(panel.FiltersTitle, 'normal')
    panel.FiltersTitle:SetPoint('TOP', panel, 'TOP', 0, -10)
    panel.FiltersTitle:SetTextColor(accent[1], accent[2], accent[3], 1)
    panel.FiltersTitle:SetText(L['Filters'])

    for _, spec in ipairs(ROLE_STRIP) do
        panel.roleButtons[spec.key] = GUI:CreateButton(panel, spec.label or '', {
            height = ROLE_STRIP_HEIGHT,
            imageAtlas = spec.atlas,
            imageSize = ROLE_ICON_SIZE,
            bgColor = widgetColor,
            accentColor = accent,
            selectionStyle = 'both',
            tooltip = spec.tooltip,
            callback = function()
                self.filters[spec.key] = not self.filters[spec.key]
                self:OnFilterChanged()
            end,
        })
    end

    for _, key in ipairs(FILTER_KEYS) do
        panel.filterButtons[key] = GUI:CreateButton(panel, FILTER_LABELS[key][1], {
            height = FILTER_HEIGHT,
            bgColor = widgetColor,
            accentColor = accent,
            selectionStyle = 'both',
            tooltip = FILTER_LABELS[key][2],
            callback = function()
                self.filters[key] = not self.filters[key]
                self:OnFilterChanged()
            end,
        })
    end

    panel.SortDropdown = GUI:CreateDropdown(panel, L['Sort'], {
        options = SORT_MODES,
        value = self.db.SortBy,
        bgColor = widgetColor,
        accentColor = accent,
        callback = function(value)
            self.db.SortBy = value
            self:RefreshResults()
            self:RefreshPanel()
        end,
    })

    panel.SortDirection = GUI:CreateButton(panel, '', {
        width = ICON_BUTTON_WIDTH,
        height = DROPDOWN_BUTTON_HEIGHT,
        image = ARROW_TEXTURE,
        imageSize = ARROW_ICON,
        imageColor = accent,
        accentColor = accent,
        bgColor = widgetColor,
        tooltip = L['Sort direction'],
        callback = function()
            self.db.SortDescending = not self.db.SortDescending
            self:RefreshResults()
            self:RefreshPanel()
        end,
    })

    panel.SearchButton = GUI:CreateButton(panel, L['Search'], {
        height = BUTTON_HEIGHT,
        bgColor = widgetColor,
        accentColor = accent,
        callback = function()
            self:DoServerSearch()
            RefreshSearchTooltip(panel.SearchButton)
        end,
    })
    panel.SearchButton:SetTooltipContent(FillSearchTooltip)

    panel.ClearFilters = GUI:CreateButton(panel, '', {
        width = ICON_BUTTON_WIDTH,
        height = BUTTON_HEIGHT,
        image = CROSS_TEXTURE,
        imageSize = CROSS_ICON,
        imageRotation = rad(45),
        imageColor = { 1, 0, 0 },
        accentColor = accent,
        bgColor = widgetColor,
        tooltip = L['Clear Filters'],
        callback = function()
            self:ResetFilters()
            self:OnFilterChanged()
        end,
    })

    local footer = GUI:CreateButton(panel, '', {
        height = FOOTER_HEIGHT,
        fontSize = 'small',
        bgColor = widgetColor,
        accentColor = accent,
        callback = function() self:ToggleGreatVault() end,
    })
    footer:SetTooltipContent(FillVaultTooltip)
    footer:SetPoint('BOTTOMLEFT', panel, 'BOTTOMLEFT', INSET, 12)
    footer:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -INSET, 12)
    panel.Footer = footer

    self:LayoutPanel()
end

-- Dungeon tooltip --

---@param durationSec number
---@param timeLimit number
---@return string
local function KeystoneUpgrade(durationSec, timeLimit)
    if not timeLimit or timeLimit <= 0 or durationSec > timeLimit then return '' end
    if durationSec <= timeLimit * UPGRADE_THREE_CHEST then return '+++' end
    if durationSec <= timeLimit * UPGRADE_TWO_CHEST then return '++' end
    return '+'
end

---The upgrade suffix is the timed/depleted marker, so the run needs no further label.
---@param tooltip GameTooltip
---@param info table a MythicPlusRunInfo from GetSeasonBestForMap
---@param upgrade string
local function AddRunLine(tooltip, info, upgrade)
    local levelColor = GetKeystoneLevelRarityColor(info.level) or HIGHLIGHT_FONT_COLOR
    local scoreColor = GetScoreRarityColor(info.dungeonScore) or HIGHLIGHT_FONT_COLOR
    local key = format('|c%s+%d|r%s', levelColor:GenerateHexColor(), info.level, upgrade ~= '' and (' ' .. upgrade) or '')

    tooltip:AddDoubleLine(format('%s  %s', key, NRSKNUI:FormatTime(info.durationSec, 'M:SS')),
        format('%d', floor(info.dungeonScore)), 1, 1, 1, scoreColor.r, scoreColor.g, scoreColor.b)
end

---A filler rather than a plain title: the run lines carry their own rarity colors.
---@param tooltip GameTooltip
---@param button KajiGUIButton
local function FillDungeonTooltip(tooltip, button)
    local dungeon = button.dungeon
    local accent = GroupFinder:GetAccentColors()
    tooltip:SetText(dungeon.name, accent[1], accent[2], accent[3], 1)

    -- Only the challenge map carries season records, and it is absent until map info lands.
    if not dungeon.mapID then return end

    local intimeInfo, overtimeInfo = GetSeasonBestForMap(dungeon.mapID)
    if not (intimeInfo or overtimeInfo) then
        tooltip:AddLine(L['No runs this season.'], 0.6, 0.6, 0.6)
        return
    end

    if intimeInfo then
        AddRunLine(tooltip, intimeInfo, KeystoneUpgrade(intimeInfo.durationSec, dungeon.timeLimit))
    end

    if overtimeInfo then
        AddRunLine(tooltip, overtimeInfo, '')
    end
end

-- Layout --

function GroupFinder:LayoutPanel()
    local panel = self.panel
    local contentWidth = (self.db.PanelWidth or PANEL_WIDTH) - (INSET * 2)
    local columnWidth = (contentWidth - COLUMN_GAP) / 2
    local offset = -10 - TITLE_PITCH
    local widgetColor = self:GetWidgetColors()
    local accent = self:GetAccentColors()

    panel.SearchButton:SetWidth(contentWidth - ICON_BUTTON_WIDTH - COLUMN_GAP)
    panel.SearchButton:ClearAllPoints()
    panel.SearchButton:SetPoint('TOPLEFT', panel, 'TOPLEFT', INSET, offset)

    panel.ClearFilters:ClearAllPoints()
    panel.ClearFilters:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -INSET, offset)
    offset = offset - BUTTON_HEIGHT - SECTION_GAP

    local dungeons = self:GetSeasonDungeons()
    for index, dungeon in ipairs(dungeons) do
        local button = panel.dungeonButtons[index]
        if not button then
            button = GUI:CreateButton(panel, dungeon.short, {
                height = TOGGLE_HEIGHT,
                bgColor = widgetColor,
                accentColor = accent,
                selectionStyle = 'text',
                callback = function()
                    self:ToggleDungeon(index)
                end,
            })
            panel.dungeonButtons[index] = button
        end

        button.groupID = dungeon.id
        button.dungeon = dungeon
        button:SetBackgroundImage(dungeon.icon)
        button:SetLabel(dungeon.short)
        button:SetTooltipContent(FillDungeonTooltip)
        button:SetWidth(columnWidth)

        local column = (index - 1) % 2
        local row = floor((index - 1) / 2)
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', panel, 'TOPLEFT', INSET + (column * (columnWidth + COLUMN_GAP)), offset - (row * ROW_PITCH))
        button:Show()
    end

    for index = #panel.dungeonButtons, #dungeons + 1, -1 do
        GUI:ReleaseWidget(panel.dungeonButtons[index])
        panel.dungeonButtons[index] = nil
    end

    if #dungeons > 0 then
        offset = offset - (ceil(#dungeons / 2) * ROW_PITCH) - 4
    end

    local roleWidth = floor((columnWidth - ROLE_STRIP_GAP) / 2)
    local tank, healer, any = panel.roleButtons.hasTank, panel.roleButtons.hasHealer, panel.roleButtons.hasEither

    tank:SetWidth(roleWidth)
    tank:ClearAllPoints()
    tank:SetPoint('TOPLEFT', panel, 'TOPLEFT', INSET, offset)

    healer:SetWidth(columnWidth - roleWidth - ROLE_STRIP_GAP)
    healer:ClearAllPoints()
    healer:SetPoint('TOPLEFT', tank, 'TOPRIGHT', ROLE_STRIP_GAP, 0)

    any:SetWidth(columnWidth)
    any:ClearAllPoints()
    any:SetPoint('TOPLEFT', panel, 'TOPLEFT', INSET + columnWidth + COLUMN_GAP, offset)

    offset = offset - ROLE_STRIP_HEIGHT - SECTION_GAP

    for _, key in ipairs(FILTER_KEYS) do
        local button = panel.filterButtons[key]
        button:SetWidth(contentWidth)
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', panel, 'TOPLEFT', INSET, offset)
        offset = offset - FILTER_PITCH
    end

    offset = offset - SECTION_GAP

    panel.SortDropdown:SetWidth(contentWidth - ICON_BUTTON_WIDTH - COLUMN_GAP)
    panel.SortDropdown:ClearAllPoints()
    panel.SortDropdown:SetPoint('TOPLEFT', panel, 'TOPLEFT', INSET, offset)
    panel.SortDirection:ClearAllPoints()
    panel.SortDirection:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -INSET, offset - DROPDOWN_LABEL_HEIGHT)

    panel.laidOut = true
end

---@param index number
function GroupFinder:ToggleDungeon(index)
    local button = self.panel and self.panel.dungeonButtons[index]
    local groupID = button and button.groupID
    if not groupID then return end

    self.filters.dungeons[groupID] = (not self.filters.dungeons[groupID]) or nil
    self:OnFilterChanged()
end

-- State refresh --

function GroupFinder:RefreshPanel()
    local panel = self.panel
    if not panel or not panel:IsShown() then return end

    if not panel.laidOut then self:LayoutPanel() end

    for _, button in ipairs(panel.dungeonButtons) do
        local selected = self.filters.dungeons[button.groupID] == true
        button:SetSelected(selected)
        button.bgImage:SetAlpha(selected and DUNGEON_ART_SELECTED_ALPHA or DUNGEON_ART_ALPHA)
        button.bgImage:SetDesaturated(not selected)
    end

    for _, spec in ipairs(ROLE_STRIP) do
        local button = panel.roleButtons[spec.key]
        local selected = self.filters[spec.key] == true
        button:SetSelected(selected)

        if spec.atlas then
            button.icon:SetDesaturated(not selected)
            button.icon:SetAlpha(selected and 1 or ROLE_ICON_RESTING_ALPHA)
        end
    end

    for key, button in next, panel.filterButtons do
        button:SetSelected(self.filters[key] == true)
    end

    panel.SortDropdown:SetValue(self.db.SortBy, true)
    panel.SortDirection.icon:SetRotation(rad(self.db.SortDescending and 0 or 180))

    local count = self:GetWeeklyRuns()
    panel.Footer:SetLabel(format(L['Keys Done This Week: %d'], count))
    panel.Footer:SetLabelAlpha(count > 0 and 1 or 0.4)
end

function GroupFinder:UpdatePanelVisibility()
    local panel = self.panel
    if not panel then return end

    local searchPanel = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    local show = self.db.Enabled
        and self.db.ShowPanel
        and searchPanel
        and searchPanel:IsVisible()
        and self:IsDungeonMode()

    if not show then
        panel:Hide()
        self:EnsureRaiderIOAnchor()
        return
    end

    panel:Show()
    self:RefreshPanel()
    self:EnsureRaiderIOAnchor()
end

function GroupFinder:ToggleGreatVault()
    if NRSKNUI:InCombat() then
        NRSKNUI:Print(L['Cannot open the Great Vault in combat.'])
        return
    end

    if not IsAddOnLoaded('Blizzard_WeeklyRewards') then
        LoadAddOn('Blizzard_WeeklyRewards')
    end

    local frame = _G.WeeklyRewardsFrame
    if not frame then return end

    if frame:IsShown() then
        HideUIPanel(frame)
    else
        ShowUIPanel(frame)
    end
end
