---@class NRSKNUI
local NRSKNUI = select(2, ...)

local EnumerateFrames = EnumerateFrames
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown = IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown
local UnitExists = UnitExists
local UnitTokenFromGUID = UnitTokenFromGUID
local issecretvalue = issecretvalue
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local UnitIsPlayer = UnitIsPlayer
local UnitTreatAsPlayerForDisplay = UnitTreatAsPlayerForDisplay
local UnitClass = UnitClass
local UnitIsMinion = UnitIsMinion
local UnitSelectionColor = UnitSelectionColor
local UnitLevel = UnitLevel
local UnitRace = UnitRace
local GetMaxPlayerLevel = GetMaxPlayerLevel
local GetGuildInfo = GetGuildInfo
local select = select
local next = next
local UnitNameFromGUID = UnitNameFromGUID
local CreateFrame = CreateFrame
local format = string.format

local TooltipContainer = GameTooltipDefaultContainer
local GameTooltip = GameTooltip
local UIParent = UIParent
local _G = _G

local WHITE_FONT_COLOR = WHITE_FONT_COLOR
local FACTION_ALLIANCE = FACTION_ALLIANCE
local FACTION_HORDE = FACTION_HORDE
local MOUNT = MOUNT

local GetClassColor = C_ClassColor and C_ClassColor.GetClassColor
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local GetMountFromSpell = C_MountJournal and C_MountJournal.GetMountFromSpell
local GetMountInfoByID = C_MountJournal and C_MountJournal.GetMountInfoByID
local GetDisplayedItem = TooltipUtil and TooltipUtil.GetDisplayedItem
local GetItemQualityByID = C_Item and C_Item.GetItemQualityByID
local GetColorDataForItemQuality = ColorManager and ColorManager.GetColorDataForItemQuality
local GetCoinTextureString = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString

local preCall = TooltipDataProcessor and TooltipDataProcessor.AddLinePreCall
local postCall = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall

local itemEnum = Enum.TooltipDataType.Item
local unitEnum = Enum.TooltipDataType.Unit
local unitNameEnum = Enum.TooltipDataLineType.UnitName
local unitOwnerEnum = Enum.TooltipDataLineType.UnitOwner
local sellPriceEnum = Enum.TooltipDataLineType.SellPrice
local unitThreatEnum = Enum.TooltipDataLineType.UnitThreat
local toyEnum = Enum.TooltipDataType.Toy
local EquipmentSetEnum = Enum.TooltipDataType.EquipmentSet
local SpellEnum = Enum.TooltipDataType.Spell
local mountEnum = Enum.TooltipDataType.Mount
local macroEnum = Enum.TooltipDataType.Macro
local flyoutEnum = Enum.TooltipDataType.Flyout
local petActionEnum = Enum.TooltipDataType.PetAction
local unitAuraEnum = Enum.TooltipDataType.UnitAura

-- Tooltip types that can be hidden in combat, grouped as shown in the GUI.
---@type table<number, string>
local combatHideTypes = {
    [unitEnum] = 'Units',
    [itemEnum] = 'Items',
    [toyEnum] = 'Items',
    [EquipmentSetEnum] = 'Items',
    [SpellEnum] = 'Spells',
    [mountEnum] = 'Spells',
    [macroEnum] = 'Spells',
    [flyoutEnum] = 'Spells',
    [petActionEnum] = 'Spells',
    [unitAuraEnum] = 'Auras',
}

local tooltipTexts = {
    GameTooltipHeaderText = 'HeaderTextSize',
    GameTooltipText = 'TextSize',
    GameTooltipTextSmall = 'TextSmallSize',
}

local levelLineMatch1 = TOOLTIP_UNIT_LEVEL:gsub('%s?%%s%s?%-?', ''):lower()
local levelLineMatch2 = TOOLTIP_UNIT_LEVEL_RACE:gsub('^%%2$s%s?(.-)%s?%%1$s', '%1'):gsub('^%-?г?о?%s?', ''):gsub('%s?%%s%s?%-?', ''):lower()

local factionLineColors = {
    [FACTION_ALLIANCE] = { 0.25, 0.51, 1 },
    [FACTION_HORDE] = { 1, 0.16, 0.16 },
}

local nameRealmFormat = '%s %s'

local guildNameFormat = '<%s>'
local guildRankFormat = '<%s> [%s]'

local skinnedFrames = {}     -- Every frame we put a backdrop on, so GUI color changes can be reapplied.
local statusBarTooltips = {} -- Tooltips with a StatusBar

---@class Tooltips: AceModule, AceEvent-3.0
local TT = NRSKNUI:NewModule('Tooltips', 'AceEvent-3.0')

function TT:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.Tooltips
end

function TT:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

---@param group string
---@return boolean
local function ShouldHideInCombat(group)
    local db = TT.db
    if not db.HideInCombat or not db.HideInCombatTypes[group] then return false end
    if not InCombatLockdown() then return false end

    return not ((db.Mod == 'SHIFT' and IsShiftKeyDown()) or (db.Mod == 'CTRL' and IsControlKeyDown()) or (db.Mod == 'ALT' and IsAltKeyDown()))
end

-- Hides an already-shown tooltip when combat starts or the override key is released, tooltips opened during combat are handled by the post calls.
local function HideTooltipInCombat()
    if GameTooltip:IsForbidden() or not GameTooltip:IsShown() then return end

    for enum, group in next, combatHideTypes do
        if ShouldHideInCombat(group) and GameTooltip:IsTooltipType(enum) then
            GameTooltip:Hide()
            return
        end
    end
end

-- Creates the anchor frame on first call, then (re)applies the position from the db, so it can also be used to reposition on settings changes.
local customAnchor
local function CustomAnchorHandler()
    if not customAnchor then
        customAnchor = CreateFrame('Frame', 'NRSKNUI_ToolTipAnchorFrame', UIParent)
        customAnchor:SetSize(170, 60)
        customAnchor:SetClampedToScreen(true)
        TT.TTAnchor = customAnchor
    end

    local pos = TT.db.Position
    customAnchor:ClearAllPoints()
    customAnchor:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
end

-- Re-points default-anchored tooltips to the custom anchor.
---@param tooltip Tooltip
local function AnchorTooltip(tooltip)
    if not tooltip or tooltip:IsForbidden() then return end
    if not customAnchor or not TT.db.Enabled then return end

    tooltip:ClearAllPoints()
    tooltip:SetPoint('BOTTOMRIGHT', customAnchor, 'BOTTOMRIGHT', 0, 0)
end

-- Override key, pressing it while hovering a unit in combat shows its tooltip immediately, releasing it hides hidden types again.
---@param key string
---@param down number
local function OnModifierChanged(_, key, down)
    if key:sub(2) ~= TT.db.Mod then return end
    if not TT.db.HideInCombat or not InCombatLockdown() then return end
    if GameTooltip:IsForbidden() then return end

    if down == 1 then
        if UnitExists('mouseover') and not GameTooltip:IsShown() then
            GameTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
            AnchorTooltip(GameTooltip)
            GameTooltip:SetUnit('mouseover')
        end
    else
        HideTooltipInCombat()
    end
end

-- Runs both on OnShow and whenever item data is set on an already-shown tooltip, so the border always matches the currently displayed item.
---@param tooltip GameTooltip & PublicBackdropMixin
local function UpdateBorderColor(tooltip)
    if not TT.db.ShowItemQualityBorder then return end
    if tooltip:IsForbidden() then return end
    if not NRSKNUI:BackdropExists(tooltip) then return end

    if GetDisplayedItem and GetColorDataForItemQuality and tooltip.IsTooltipType then
        local _, link = GetDisplayedItem(tooltip)
        local itemQuality = link and GetItemQualityByID(link)
        local colorData = itemQuality and GetColorDataForItemQuality(itemQuality)
        if colorData then
            tooltip:SetBorderColor(colorData.r, colorData.g, colorData.b, 1)
            return
        end
    end

    local BC = TT.db.BorderColor
    tooltip:SetBorderColor(BC[1], BC[2], BC[3], BC[4])
end

---@param tooltip Tooltip
---@return table colorRGBA
local function GetUnitColor(tooltip)
    local tooltipData = tooltip.processingInfo and tooltip.processingInfo.tooltipData
    local unitGUID = tooltipData and tooltipData.guid
    if unitGUID then
        local unit = UnitTokenFromGUID(unitGUID)
        if issecretvalue(unit) then
            local classToken = select(2, GetPlayerInfoByGUID(unitGUID))
            -- Unit is a player
            if classToken ~= nil then
                return GetClassColor(classToken)
            else
                -- Unit is an NPC
                return tooltipData.lines[1].leftColor
            end
        elseif unit ~= nil then
            -- Unit is a player
            if UnitIsPlayer(unit) or UnitTreatAsPlayerForDisplay(unit) then
                local classToken = select(2, UnitClass(unit))
                return GetClassColor(classToken)
            elseif UnitIsMinion(unit) then
                -- Unit is a pet/minion
                return NRSKNUI:CreateColor(UnitSelectionColor(unit, true))
            else
                -- Unit is an NPC
                return tooltipData.lines[1].leftColor
            end
        end
    end

    return WHITE_FONT_COLOR
end

-- Reapply our cached color after Blizzard recolors the bar on health updates.
local function tooltipHealthChanged(self)
    local color = self.nrsknui_barcolor
    if color then
        self:SetStatusBarColor(color[1], color[2], color[3])
    else
        self:SetStatusBarColor(GetUnitColor(self:GetParent()):GetRGB())
    end
end

---@param tooltip Tooltip
local function StyleStatusBar(tooltip)
    if TT.db.ShowStatusBar then
        tooltip.StatusBar:SetAlpha(1)
        tooltip.StatusBar:ClearAllPoints()
        tooltip.StatusBar:SetPoint('BOTTOMLEFT', tooltip, 'BOTTOMLEFT', 2, 2)
        tooltip.StatusBar:SetPoint('BOTTOMRIGHT', tooltip, 'BOTTOMRIGHT', -2, 2)
        tooltip.StatusBar:SetHeight(3)
        tooltip.StatusBar:SetStatusBarTexture(NRSKNUI:GetBarTexture(TT.db))
    else
        tooltip.StatusBar:Hide()
        tooltip.StatusBar:SetAlpha(0)
    end
end

-- The queue status texts are created on demand, so we need to run the fontstyling when Update() is called.
-- Also calling Update() ourselves when we change font size in the GUI for live update, so we need a recursion block.
local stylingQueueStatus = false
local function StyleQueueStatusFonts()
    if not QueueStatusFrame or stylingQueueStatus then return end
    stylingQueueStatus = true
    NRSKNUI:StyleChildFontStrings(QueueStatusFrame, TT.db, function(region, child)
        if region == child.Title then return TT.db.HeaderTextSize end
        return TT.db.TextSize
    end)
    QueueStatusFrame:Update()
    stylingQueueStatus = false
end

local function SkinQueueStatus()
    if not QueueStatusFrame then return end
    if NRSKNUI:BackdropExists(QueueStatusFrame) then return end

    -- Hide original border & background and create our own
    NRSKNUI:Hide(QueueStatusFrame, 'NineSlice')

    ---@cast QueueStatusFrame Frame & PublicBackdropMixin
    NRSKNUI:CreateBackdrop(QueueStatusFrame)

    skinnedFrames[#skinnedFrames + 1] = QueueStatusFrame

    -- Restyle whenever entries are (re)built
    hooksecurefunc(QueueStatusFrame, 'Update', StyleQueueStatusFonts)
end

---@param tooltip Tooltip
local function SetupSkinning(tooltip)
    if tooltip:IsForbidden() then return end
    if not tooltip.NineSlice or tooltip.IsEmbedded then return end -- Not skinnable
    if NRSKNUI:BackdropExists(tooltip) then return end

    -- Hide original border & background and create our own
    NRSKNUI:Hide(tooltip, 'NineSlice')

    ---@cast tooltip Tooltip & PublicBackdropMixin
    NRSKNUI:CreateBackdrop(tooltip)

    skinnedFrames[#skinnedFrames + 1] = tooltip

    tooltip:HookScript('OnShow', UpdateBorderColor)

    -- Style the compare header
    if tooltip.CompareHeader and not NRSKNUI:BackdropExists(tooltip.CompareHeader) then
        -- Hide original texture and create our own border & background.
        NRSKNUI:HideTextures(tooltip.CompareHeader, 'tooltip-compare-label')
        NRSKNUI:CreateBackdrop(tooltip.CompareHeader)
        tooltip.CompareHeader:SetPoint('BOTTOMLEFT', tooltip, 'TOPLEFT', 0, -1)
    end

    if tooltip.StatusBar then
        statusBarTooltips[#statusBarTooltips + 1] = tooltip
        hooksecurefunc(tooltip.StatusBar, 'Show', function(bar)
            if not TT.db.ShowStatusBar then bar:Hide() end
        end)
        tooltip.StatusBar:HookScript('OnValueChanged', tooltipHealthChanged)
        StyleStatusBar(tooltip)
    end
end

-- Enumerate every single non-forbidden tooltip on enable.
-- This way you do not need to setup a table with common tooltip types manually.
local function TooltipInit()
    -- Source: https://warcraft.wiki.gg/wiki/API_EnumerateFrames
    local nextFrame = EnumerateFrames() -- If omitted, returns the first frame.
    while nextFrame do                  -- Returns nil if there are no more frames.
        if nextFrame:GetObjectType() == 'GameTooltip' then
            SetupSkinning(nextFrame)
        end
        nextFrame = EnumerateFrames(nextFrame)
    end
end

-- Level 1 = red, max level = green, yellow in between.
---@param level number
---@return string hex
local function GetLevelColorHex(level)
    local maxLevel = GetMaxPlayerLevel() or level
    local r, g, b = NRSKNUI:ColorGradient(level - 1, maxLevel - 1, 1, 0.15, 0.15, 1, 0.85, 0.1, 0.2, 0.95, 0.2)

    return NRSKNUI:RGBAToHex(r, g, b)
end

---@param tooltip Tooltip
---@param startLine number First line to consider, skips past the guild line
---@return FontString? levelLine
---@return FontString? specLine
local function GetLevelLine(tooltip, startLine)
    for i = startLine, tooltip:NumLines() do
        local line = _G['GameTooltipTextLeft' .. i]
        local text = line and line:GetText()

        if not issecretvalue(text) and text and text ~= '' then
            local lowerText = text:lower()
            if lowerText:find(levelLineMatch1, 1, true) or lowerText:find(levelLineMatch2, 1, true) then
                return line, _G['GameTooltipTextLeft' .. (i + 1)]
            end
        end
    end
end

-- Resolves the unit token from tooltip data, nil for secrets and non-players.
---@param data TooltipData
---@return string? unit
local function GetPlayerUnit(data)
    local unitGUID = data and data.guid
    if not unitGUID or issecretvalue(unitGUID) then return end

    local unit = UnitTokenFromGUID(unitGUID)
    if not unit or issecretvalue(unit) then return end

    local isPlayer = UnitIsPlayer(unit)
    if issecretvalue(isPlayer) or not isPlayer then return end

    return unit
end

---@param tooltip Tooltip
---@param data TooltipData
local function StyleLevelLine(tooltip, data)
    local unit = GetPlayerUnit(data)
    if not unit then return end

    local level = UnitLevel(unit)
    if issecretvalue(level) or not level or level <= 0 then return end

    local race = UnitRace(unit)
    if issecretvalue(race) or not race then return end

    local guildName = GetGuildInfo(unit)
    local startLine = (not issecretvalue(guildName) and guildName) and 3 or 2

    local line, specLine = GetLevelLine(tooltip, startLine)
    if not line then return end

    line:SetText(('|cFF%s%d|r %s'):format(GetLevelColorHex(level), level, race))

    -- The line after the level line is the spec/class line, unless the player has no spec, then it is the faction line.
    local specText = specLine and specLine:GetText()
    if not issecretvalue(specText) and specText and not factionLineColors[specText] then
        specLine:SetTextColor(GetUnitColor(tooltip):GetRGB())
    end
end

---@param tooltip Tooltip
local function StyleFactionLine(tooltip)
    for i = 2, tooltip:NumLines() do
        local line = _G['GameTooltipTextLeft' .. i]
        local text = line and line:GetText()

        if not issecretvalue(text) and text then
            local color = factionLineColors[text]
            if color then
                line:SetTextColor(color[1], color[2], color[3])
                return
            end
        end
    end
end

---@param data TooltipData
local function StyleGuildLine(data)
    local unit = GetPlayerUnit(data)
    if not unit then return end

    local guildName, guildRank = GetGuildInfo(unit)
    if issecretvalue(guildName) or not guildName then return end

    local line = _G['GameTooltipTextLeft2']
    local text = line and line:GetText()
    if issecretvalue(text) or not text then return end

    -- Only overwrite if line 2 really is the guild line.
    if not text:find(guildName, 1, true) then return end

    local coloredGuildName = NRSKNUI:ColorText(guildName, TT.db.GuildNameColor)
    local coloredRankname = NRSKNUI:ColorText(guildRank, TT.db.GuildRankColor)

    if not issecretvalue(guildRank) and guildRank then
        line:SetText(guildRankFormat:format(coloredGuildName, coloredRankname))
    else
        line:SetText(guildNameFormat:format(coloredGuildName))
    end
end

-- Add line to tooltip with a player units mount info.
---@param tooltip Tooltip
---@param data TooltipData
local function AddMountLine(tooltip, data)
    if not TT.db.ShowMountInfo or not GetMountFromSpell or InCombatLockdown() then return end
    if NRSKNUI:IsRestricted() then return end

    local unit = GetPlayerUnit(data)
    if not unit then return end

    for i = 1, 40 do
        local aura = GetAuraDataByIndex(unit, i, 'HELPFUL')
        if not aura then return end
        if issecretvalue(aura.spellId) then return end

        -- GetMountFromSpell returns a sentinel instead of nil for non-mounts, so validate through the journal.
        local mountID = aura.spellId and GetMountFromSpell(aura.spellId)
        local mountName = mountID and GetMountInfoByID(mountID)
        if mountName and IsShiftKeyDown() then
            tooltip:AddDoubleLine(MOUNT .. ':', mountName, nil, nil, nil, WHITE_FONT_COLOR:GetRGB())
            return
        end
    end
end

-- Track processed state
local tooltipTypeProcessed = {
    threat = false,
    item = false,
    alwaysEnabled = false
}

local function TooltipProcessor()
    -- Remove unit threat line, very useless xd
    if TT.db.HideThreatLine and not tooltipTypeProcessed.threat then
        preCall(unitThreatEnum, function(tooltip)
            if not TT.db.Enabled or not TT.db.HideThreatLine then return end
            if not tooltip:IsForbidden() then return true end
        end)
        tooltipTypeProcessed.threat = true
    end

    -- Style tooltip border color based on item quality
    if TT.db.ShowItemQualityBorder and not tooltipTypeProcessed.item then
        postCall(itemEnum, UpdateBorderColor)
        tooltipTypeProcessed.item = true
    end

    if tooltipTypeProcessed.alwaysEnabled then return end

    -- Hide selected tooltip types during combat, overridden by holding the modifier key
    for enum, group in next, combatHideTypes do
        postCall(enum, function(tooltip)
            if not TT.db.Enabled then return end
            if tooltip:IsForbidden() or tooltip ~= GameTooltip then return end
            if ShouldHideInCombat(group) then tooltip:Hide() end
        end)
    end

    postCall(unitEnum, function(tooltip, data)
        if not TT.db.Enabled then return end
        if tooltip:IsForbidden() then return end
        -- Skip styling when the tooltip was combat-hidden above
        if tooltip == GameTooltip and ShouldHideInCombat('Units') then return end

        -- Style level and faction lines for units
        StyleLevelLine(tooltip, data)
        StyleFactionLine(tooltip)
        -- Style the guild name line for players
        StyleGuildLine(data)
        AddMountLine(tooltip, data)
    end)

    -- Color unit name, style realm name: 'Norsken (TarrenMill)' and apply statusbar coloring.
    preCall(unitNameEnum, function(tooltip, data)
        if not TT.db.Enabled then return end
        if tooltip:IsForbidden() or not tooltip:IsTooltipType(unitEnum) then return end

        local unitGUID = select(3, tooltip:GetUnit())
        if not unitGUID then return end

        local r, g, b = GetUnitColor(tooltip):GetRGB()
        local bar = tooltip.StatusBar
        if bar then
            local color = bar.nrsknui_barcolor
            if not color then
                color = {}
                bar.nrsknui_barcolor = color
            end
            color[1], color[2], color[3] = r, g, b
            bar:SetStatusBarColor(r, g, b)
        end

        local name, realm = UnitNameFromGUID(unitGUID)
        if realm ~= nil then
            local coloredRealm = NRSKNUI:ColorText(format("(%s)", realm), TT.db.NameRealmColor)
            tooltip:AddLine(nameRealmFormat:format(name, coloredRealm), r, g, b)
        elseif name ~= nil then
            tooltip:AddLine(name, r, g, b)
        else
            tooltip:AddLine(data.leftText, r, g, b)
        end

        return true
    end)

    -- Color unitOwner name, for example 'Norsken's Pet/Minion/Statue'
    preCall(unitOwnerEnum, function(tooltip, data)
        if not TT.db.Enabled then return end
        if tooltip:IsForbidden() or not tooltip:IsTooltipType(unitEnum) then return end

        tooltip:AddLine(data.leftText, TT.db.MinionColor[1], TT.db.MinionColor[2], TT.db.MinionColor[3])
        return true
    end)

    -- Fully replace money frame tooltips and add our own styleable line
    preCall(sellPriceEnum, function(tooltip, lineData)
        if not TT.db.Enabled or not GetCoinTextureString then return end
        if tooltip:IsForbidden() then return end

        tooltip:AddLine(SELL_PRICE .. ': ' .. GetCoinTextureString(lineData.price), WHITE_FONT_COLOR:GetRGB())
        return true
    end)

    tooltipTypeProcessed.alwaysEnabled = true
end

-- Expose setting application globally for GUI and profile changes.
function TT:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end

    TooltipProcessor()
    CustomAnchorHandler()
    StyleQueueStatusFonts()

    NRSKNUI:StyleFontstringTable(tooltipTexts, self.db, true)

    for _, tooltip in next, statusBarTooltips do StyleStatusBar(tooltip) end
    for _, frame in next, skinnedFrames do frame:UpdateBackdropFromDB(self.db) end
end

local hooksDone = false
function TT:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end -- Don't enable module if ElvUI is enabled.
    if not self.db.Enabled then return end

    -- One-time setup, everything re-appliable runs through ApplySettings.
    SkinQueueStatus()
    TooltipInit()
    self:ApplySettings()

    -- Register events.
    self:RegisterEvent('PLAYER_REGEN_DISABLED', HideTooltipInCombat)
    self:RegisterEvent('MODIFIER_STATE_CHANGED', OnModifierChanged)

    if not hooksDone then
        -- Hook when blizzard tries to anchor tooltip and anchor to our custom one instead.
        hooksecurefunc('GameTooltip_SetDefaultAnchor', AnchorTooltip)
        -- Hook when blizzard tries to set backdrop style, this catches and styles any tooltip that we might have missed in the initial check.
        hooksecurefunc('SharedTooltip_SetBackdropStyle', function(tooltip)
            if not TT.db.Enabled then return end
            if tooltip:GetObjectType() == 'GameTooltip' then
                SetupSkinning(tooltip)
            end
        end)
        hooksDone = true
    end

    -- Kill tooltip handling in Blizzards editmode, we control it with out custom anchor.
    NRSKNUI:Hide(TooltipContainer)

    -- Register the custom anchor with addons editmode.
    local config = {
        key = 'TooltipModule',
        displayName = 'Tooltip Anchor',
        frame = self.TTAnchor,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            CustomAnchorHandler()
        end,
        getParentFrame = function()
            return UIParent
        end,
        guiPath = 'tooltips',
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

function TT:OnDisable()
    self:UnregisterAllEvents()
end
