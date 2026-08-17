---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CharacterPanelModule
local CharacterPanel = NRSKNUI:GetModule('CharacterPanel')
function CharacterPanel:UpdateDB() self.db = NRSKNUI.db.profile.CharacterPanel end

local Theme = NRSKNUI.Theme

local string_match, string_gsub, string_find = string.match, string.gsub, string.find
local math_abs, math_max, math_min = math.abs, math.max, math.min
local math_floor, string_format = math.floor, string.format
local GetAverageItemLevel = GetAverageItemLevel
local GetInventoryItemLink = GetInventoryItemLink
local SocketInventoryItem = SocketInventoryItem
local tinsert, twipe = table.insert, table.wipe
local UnitFactionGroup = UnitFactionGroup
local CloseSocketInfo = CloseSocketInfo
local hooksecurefunc = hooksecurefunc
local AcceptSockets = AcceptSockets
local ipairs, pairs = ipairs, pairs
local RunNextFrame = RunNextFrame
local GetRealmName = GetRealmName
local CreateFrame = CreateFrame
local ClearCursor = ClearCursor
local HideUIPanel = HideUIPanel
local tonumber = tonumber
local UnitRace = UnitRace
local unpack = unpack
local select = select
local type = type

local ClickSocketButton = C_ItemSocketInfo and C_ItemSocketInfo.ClickSocketButton
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo
local GetSlotTooltipData = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
local PickupContainerItem = C_Container and C_Container.PickupContainerItem
local UseContainerItem = C_Container and C_Container.UseContainerItem
local GetTooltipData = C_TooltipInfo and C_TooltipInfo.GetHyperlink
local GetItemLevel = C_Item and C_Item.GetDetailedItemLevelInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant
local GetItemIconByID = C_Item and C_Item.GetItemIconByID
local GetItemGem = C_Item and C_Item.GetItemGem

local LINE_UPGRADE = Enum and Enum.TooltipDataLineType.ItemUpgradeLevel
local ITEM_CLASS_ENHANCEMENT = Enum and Enum.ItemClass.ItemEnhancement
local ITEM_CLASS_GEM = Enum and Enum.ItemClass.Gem
local MAX_BAG = NUM_BAG_SLOTS or 4
local C_Timer = C_Timer
local MAX_SOCKETS = 3
local _G = _G

local ARMOR_KIT_SLOT = INVSLOT_LEGS
local ENCHANT_BUTTON_ICON = 4620672
local EMPTY_SOCKET_ICON = 458977

local HOVER_DURATION = 0.12
local POPUP_ICON_SIZE = 24
local LEAVE_DELAY = 0.05
local TITLE_HEIGHT = 24
local POPUP_WIDTH = 280
local POPUP_PADDING = 2
local ROW_PADDING = 4

local QUALITY_ATLAS_PATTERN = '|A:(Professions%-ChatIcon%-Quality%-[^:]+):%d+:%d+'

-- PVP_ITEM_LEVEL_TOOLTIP is a localized format string, turn it into a capture pattern.
local pvpPattern
do
    if PVP_ITEM_LEVEL_TOOLTIP then
        pvpPattern = string_gsub(PVP_ITEM_LEVEL_TOOLTIP, '([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
        pvpPattern = string_gsub(pvpPattern, '%%%%d', '(%%d+)')
    end
end

local gemCache = {}
local socketCache = {}
local enchantCache = {}

-- Panel texts --

local FACTION_TAGS = {
    Alliance = ' |cff3399ff(A)|r',
    Horde = ' |cffe63333(H)|r',
}
local FACTION_TAG_PATTERN = ' |c%x%x%x%x%x%x%x%x%([AH]%)|r$'
local RACE_TEXT_GAP = 2
local LEVEL_TEXT_GAP = -4

local function UpdateItemLevelText()
    local value = _G.CharacterStatsPane.ItemLevelFrame.Value
    value:SetFontStyle(CharacterPanel.db, CharacterPanel.db.IlvlValueSize)

    local _, avgItemLevelEquipped = GetAverageItemLevel()
    if CharacterPanel.db.DecimalItemLevel then
        value:SetText(string_format('%.2f', avgItemLevelEquipped))
    else
        value:SetText(string_format('%d', math_floor(avgItemLevelEquipped)))
    end
end

local function StyleCategory(category, db, r, g, b)
    if not category or not category.Title then return end

    category.Title:SetFontStyle(db, db.CategoryFontSize)
    category.Title:SetTextColor(r, g, b)
end

local function UpdateLevelTextWithFaction()
    local levelText = _G.CharacterLevelText
    local text = levelText:GetText()
    if not text then return end

    text = string_gsub(text, FACTION_TAG_PATTERN, '')
    if CharacterPanel.db.FactionTag then
        text = text .. (FACTION_TAGS[UnitFactionGroup('player')] or '')
    end

    levelText:SetText(text)
end

local function RaceTextLabel()
    return string_format('%s / %s', GetRealmName(), UnitRace('player'))
end

function CharacterPanel:ShowRaceText()
    if not self.raceText then
        self.raceText = PaperDollFrame:CreateFontString(nil, 'OVERLAY')
        self.raceText:SetPoint('TOP', _G.CharacterLevelText, 'BOTTOM', 0, RACE_TEXT_GAP)
    end

    self.raceText:SetFontStyle(self.db, self.db.LevelTextSize)
    self.raceText:SetText(RaceTextLabel())
    self.raceText:SetJustifyH('CENTER')
    self.raceText:Show()
end

function CharacterPanel:HideRaceText()
    if self.raceText then
        self.raceText:Hide()
    end
end

function CharacterPanel:StyleCharacterTexts()
    -- Character name + title, drawn on the frame header.
    local nameText = _G.CharacterFrameTitleText
    if nameText then
        nameText:SetFontStyle(self.db, self.db.NameTextSize)
        nameText:ClearAllPoints()
        nameText:SetPoint('TOP', PaperDollFrame, 'TOP', 0, -6)
        nameText:SetJustifyH('CENTER')
    end

    -- Level + class/spec line, this is also what carries the faction tag.
    local levelText = _G.CharacterLevelText
    if levelText then
        levelText:SetFontStyle(self.db, self.db.LevelTextSize)
        levelText:SetWidth(0)
        levelText:SetWordWrap(true)
        levelText:ClearAllPoints()
        levelText:SetPoint('TOP', _G.CharacterFrameTitleText, 'BOTTOM', 0, self.db.ShowRaceText and RACE_TEXT_GAP or LEVEL_TEXT_GAP)
        levelText:SetJustifyH('CENTER')
    end

    -- Category headers for item level, attributes and enhancements.
    local pane = _G.CharacterStatsPane
    local r, g, b = NRSKNUI:GetAccentColor(self.db.CategoryColorMode, self.db.CategoryColor)
    StyleCategory(pane.ItemLevelCategory, self.db, r, g, b)
    StyleCategory(pane.AttributesCategory, self.db, r, g, b)
    StyleCategory(pane.EnhancementsCategory, self.db, r, g, b)

    UpdateItemLevelText()
    UpdateLevelTextWithFaction()

    if self.db.ShowRaceText then
        self:ShowRaceText()
    else
        self:HideRaceText()
    end
end

-- Item track resolution --

-- The track name in the tooltip is localized game data with no enum behind it, so we have to resolve it by position in the track.
local function TrackFromPosition(itemLevel, level, maxLevel)
    if not itemLevel then return end

    local target = (level and maxLevel and maxLevel > 1) and (level - 1) / (maxLevel - 1) or 0
    local best, bestDelta

    local trackT = NRSKNUI.ITEM_TRACKS
    for _, track in ipairs(trackT) do
        if itemLevel >= track.min and itemLevel <= track.max then
            local span = track.max - track.min
            local delta = math_abs((span > 0 and (itemLevel - track.min) / span or 0) - target)
            if not bestDelta or delta < bestDelta then
                best, bestDelta = track.key, delta
            end
        end
    end

    return best
end

local function ResolveFromTooltipData(data, itemLevel)
    if not data or not data.lines then return end

    local trackText, level, maxLevel, difficulty, pvpLevel, isCrafted

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if line.type == LINE_UPGRADE then
            trackText = text
            level, maxLevel = string_match(text or '', '(%d+)%s*/%s*(%d+)')
        elseif text then
            local diffTagT = NRSKNUI.ITEM_DIFFICULTY_TAGS
            local craftedMarker = NRSKNUI.CRAFTED_ITEM_MARKER

            difficulty = difficulty or diffTagT[text]
            if not isCrafted and craftedMarker then
                isCrafted = string_find(text, craftedMarker, 1, true) ~= nil
            end
            if not pvpLevel and pvpPattern then
                pvpLevel = string_match(text, pvpPattern)
            end
        end
    end

    level, maxLevel, pvpLevel = tonumber(level), tonumber(maxLevel), tonumber(pvpLevel)

    -- A track line is authoritative whenever it exists.
    if trackText then
        return {
            track = TrackFromPosition(itemLevel, level, maxLevel),
            level = level,
            maxLevel = maxLevel,
            itemLevel = itemLevel,
            atMax = level ~= nil and level == maxLevel,
            difficulty = difficulty,
            trackText = trackText,
            source = 'TRACK',
        }
    end

    -- PvP gear has champion track, but the tooltip shows the PvP item level. This is authoritative for PvP gear.
    if pvpLevel then
        local pvpT = NRSKNUI.PVP_ITEM_TRACKS

        for _, track in ipairs(pvpT) do
            if pvpLevel == track.itemLevel then
                return {
                    track = track.key,
                    itemLevel = pvpLevel,
                    atMax = true,
                    difficulty = difficulty,
                    source = 'PVP',
                }
            end
        end
    end

    -- Crafted gear is tagged in the tooltip and banded by item level rather than by a track.
    if isCrafted and itemLevel then
        local craftedT = NRSKNUI.CRAFTED_ITEM_TRACKS

        for _, track in ipairs(craftedT) do
            if itemLevel >= track.itemLevel then
                return {
                    track = track.key,
                    itemLevel = itemLevel,
                    atMax = false,
                    difficulty = difficulty,
                    source = 'CRAFTED',
                }
            end
        end
    end

    -- No track line means the item dropped at the top of its track.
    local trackT = NRSKNUI.ITEM_TRACKS
    for _, track in ipairs(trackT) do
        if itemLevel == track.max then
            return {
                track = track.key,
                itemLevel = itemLevel,
                atMax = true,
                difficulty = difficulty,
                source = 'ILVL',
            }
        end
    end

    -- Untracked. Bands overlap, so this resolves upward and is only a guess.
    local band = TrackFromPosition(itemLevel, nil, nil)
    return {
        track = band,
        itemLevel = itemLevel,
        atMax = false,
        difficulty = difficulty,
        source = band and 'BAND' or 'UNKNOWN',
    }
end

-- Track indicators --

function CharacterPanel:CreateTrackOverlay(slotInfo)
    local slotFrame = slotInfo.frame
    if slotFrame.NUITrackOverlay then return slotFrame.NUITrackOverlay end

    local isRight = slotInfo.rightColumn
    local overlay = CreateFrame('Frame', nil, slotFrame)
    overlay:NUISetPixelSize(14, 14)
    overlay:SetFrameLevel(slotFrame:GetFrameLevel() + 10)

    overlay.text = overlay:CreateFontString(nil, 'OVERLAY')
    overlay.text:SetFontStyle(nil, 12, 'OUTLINE')

    if isRight then
        overlay:NUISetPixelPoint('BOTTOMRIGHT', slotFrame, 'BOTTOMRIGHT', 1, 1)
        overlay.text:NUISetPixelPoint('BOTTOMRIGHT', overlay, 'BOTTOMRIGHT', 0, 0)
        overlay.text:SetJustifyH('RIGHT')
    else
        overlay:NUISetPixelPoint('BOTTOMLEFT', slotFrame, 'BOTTOMLEFT', 0, 1)
        overlay.text:NUISetPixelPoint('BOTTOMLEFT', overlay, 'BOTTOMLEFT', 0, 0)
        overlay.text:SetJustifyH('LEFT')
    end

    overlay:Hide()
    slotFrame.NUITrackOverlay = overlay
    return overlay
end

function CharacterPanel:UpdateSlotTrackIndicator(slotID)
    local slotInfo = NRSKNUI.ITEM_SLOT_INFO[slotID]
    if not slotInfo or not slotInfo.frame then return end

    local overlay = self:CreateTrackOverlay(slotInfo)

    local itemLink = GetInventoryItemLink('player', slotID)
    if not itemLink then return end

    local info = ResolveFromTooltipData(GetSlotTooltipData('player', slotID), GetItemLevel and GetItemLevel(itemLink))
    local display = info and info.track and NRSKNUI.ITEM_TRACK_INFO[info.track]

    -- A band match is a guess, so it is not worth putting a letter on the paperdoll for.
    if not display or info.source == 'BAND' then
        overlay:Hide()
        return
    end

    overlay.text:SetText(display.letter)
    overlay.text:SetTextColor(display.color[1], display.color[2], display.color[3])
    overlay:Show()
end

function CharacterPanel:UpdateAllTrackIndicators()
    if not self.db.TrackIndicators.Enabled then return end

    local slotT = NRSKNUI.ITEM_SLOTS
    for _, slotInfo in ipairs(slotT) do
        self:UpdateSlotTrackIndicator(slotInfo.slot)
    end
end

function CharacterPanel:HideAllTrackIndicators()
    local slotT = NRSKNUI.ITEM_SLOTS
    for _, slotInfo in ipairs(slotT) do
        local overlay = slotInfo.frame and slotInfo.frame.NUITrackOverlay
        if overlay then
            overlay:Hide()
        end
    end
end

-- Scanning --

local function GetQualityAtlas(itemLink)
    if not itemLink then return end
    return string_match(itemLink, QUALITY_ATLAS_PATTERN)
end

local function SetQualityAtlas(texture, atlas)
    if not atlas then
        texture:Hide()
        return
    end
    texture:SetAtlas(atlas, false)
    texture:Show()
end

local function StripColorCodes(text)
    if not text then return end
    return (string_gsub(string_gsub(text, '|c%x%x%x%x%x%x%x%x', ''), '|r', ''))
end

-- First tooltip line that reads as a stat bonus, used as the gem's summary in the list.
local function GetGemStats(itemLink)
    if not itemLink or not GetTooltipData then return end

    local data = GetTooltipData(itemLink)
    if not data or not data.lines then return end

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text and string_match(text, '^%+%d+') then
            return StripColorCodes(text)
        end
    end
end

local function GetItemName(itemLink)
    if not itemLink or not GetTooltipData then return end

    local data = GetTooltipData(itemLink)
    if not data or not data.lines or not data.lines[1] then return end

    return StripColorCodes(data.lines[1].leftText)
end

function CharacterPanel:ScanItemSockets(slotID)
    local itemLink = GetInventoryItemLink('player', slotID)
    if not itemLink then return end

    local result = {
        slotID = slotID,
        itemLink = itemLink,
        sockets = {},
        totalCount = 0,
        filledCount = 0,
        emptyCount = 0,
    }

    local usedIndices = {}

    for socketIndex = 1, MAX_SOCKETS do
        local gemName, gemLink = GetItemGem(itemLink, socketIndex)
        if gemLink then
            local gemID = GetItemInfoInstant(gemLink)
            usedIndices[socketIndex] = true
            result.filledCount = result.filledCount + 1
            result.totalCount = result.totalCount + 1
            tinsert(result.sockets, {
                index = socketIndex,
                filled = true,
                gemLink = gemLink,
                gemName = gemName,
                gemID = gemID,
                icon = gemID and GetItemIconByID(gemID),
            })
        end
    end

    -- Empty sockets are not exposed by GetItemGem, so they come from the tooltip's socket lines.
    local data = GetSlotTooltipData and GetSlotTooltipData('player', slotID)
    if data and data.lines then
        local nextIndex = 1

        for _, line in ipairs(data.lines) do
            local text = line.leftText
            if text then
                local socketT = NRSKNUI.GEM_SOCKET_TYPES

                for _, socketType in ipairs(socketT) do
                    local localeString = _G[socketType.locale]
                    if localeString and string_find(text, localeString, 1, true) then
                        while usedIndices[nextIndex] do
                            nextIndex = nextIndex + 1
                        end

                        usedIndices[nextIndex] = true
                        result.emptyCount = result.emptyCount + 1
                        result.totalCount = result.totalCount + 1
                        tinsert(result.sockets, {
                            index = nextIndex,
                            filled = false,
                            socketType = socketType.name,
                            icon = socketType.icon,
                        })
                        nextIndex = nextIndex + 1
                    end
                end
            end
        end
    end

    return result.totalCount > 0 and result or nil
end

function CharacterPanel:ScanAllEquippedSockets()
    twipe(socketCache)

    local socketableSlots = NRSKNUI.SOCKETABLE_SLOTS
    for _, slotID in ipairs(socketableSlots) do
        local socketInfo = self:ScanItemSockets(slotID)
        if socketInfo then
            tinsert(socketCache, socketInfo)
        end
    end

    return socketCache
end

local function GetEnchantTargetSlots(itemLink)
    if not itemLink or not GetTooltipData then return end

    local data = GetTooltipData(itemLink)
    if not data or not data.lines then return end

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            local lowered = text:lower()
            local enchantSlotKeywords = NRSKNUI.ENCHANT_SLOT_KEYWORDS
            for _, entry in ipairs(enchantSlotKeywords) do
                if string_find(lowered, entry.keyword, 1, true) then
                    return entry.slots
                end
            end
        end
    end
end

local function IsArmorKit(targetSlots)
    return targetSlots and #targetSlots == 1 and targetSlots[1] == ARMOR_KIT_SLOT
end

local function IsMultiSlot(targetSlots)
    return targetSlots and #targetSlots > 1
end

local function ScanBags(classID, build)
    for bag = 0, MAX_BAG do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local itemClassID = select(6, GetItemInfoInstant(info.itemID))
                if itemClassID == classID then
                    build(info, bag, slot)
                end
            end
        end
    end
end

function CharacterPanel:ScanBagsForGems()
    twipe(gemCache)

    ScanBags(ITEM_CLASS_GEM, function(info, bag, slot)
        local existing = gemCache[info.itemID]
        if existing then
            existing.count = existing.count + info.stackCount
            return
        end

        gemCache[info.itemID] = {
            itemID = info.itemID,
            icon = info.iconFileID,
            count = info.stackCount,
            link = info.hyperlink,
            bagID = bag,
            slotID = slot,
        }
    end)

    return gemCache
end

function CharacterPanel:ScanBagsForEnchants()
    twipe(enchantCache)

    ScanBags(ITEM_CLASS_ENHANCEMENT, function(info, bag, slot)
        local existing = enchantCache[info.itemID]
        if existing then
            existing.count = existing.count + info.stackCount
            return
        end

        local targetSlots = GetEnchantTargetSlots(info.hyperlink)
        if not targetSlots or IsArmorKit(targetSlots) then return end

        enchantCache[info.itemID] = {
            itemID = info.itemID,
            icon = info.iconFileID,
            count = info.stackCount,
            link = info.hyperlink,
            bagID = bag,
            slotID = slot,
            targetSlots = targetSlots,
        }
    end)

    return enchantCache
end

function CharacterPanel:FindBestEnchantSlot(targetSlots)
    if not targetSlots then return end

    for _, slotID in ipairs(targetSlots) do
        if GetInventoryItemLink('player', slotID) then
            return slotID
        end
    end
end

-- Slot highlights --

function CharacterPanel:CreateSlotHighlight()
    local frame = CreateFrame('Frame', nil, UIParent)
    frame:SetFrameStrata('DIALOG')

    frame.texture = frame:CreateTexture(nil, 'OVERLAY')
    frame.texture:SetAllPoints()
    frame.texture:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.4)
    frame.texture:SetBlendMode('ADD')
    frame.texture:NUISetPixelSnap()

    frame:NUIAddBorders()
    frame:SetBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    frame:Hide()

    return frame
end

function CharacterPanel:ShowSlotHighlight(slotIDs)
    self:HideSlotHighlight()
    if not slotIDs then return end

    if type(slotIDs) == 'number' then
        slotIDs = { slotIDs }
    end
    self.slotHighlights = self.slotHighlights or {}

    for i, slotID in ipairs(slotIDs) do
        local slotInfo = NRSKNUI.ITEM_SLOT_INFO[slotID]
        local slotFrame = slotInfo and slotInfo.frame
        if slotFrame then
            self.slotHighlights[i] = self.slotHighlights[i] or self:CreateSlotHighlight()
            self.slotHighlights[i]:SetAllPoints(slotFrame)
            self.slotHighlights[i]:Show()
        end
    end
end

function CharacterPanel:HideSlotHighlight()
    if not self.slotHighlights then return end

    for _, highlight in pairs(self.slotHighlights) do
        highlight:Hide()
    end
end

-- Shared list popup --

local function IsHovered(frame, children)
    if not frame or not frame:IsShown() then return false end
    if frame:IsMouseOver() then return true end

    if children then
        for _, child in pairs(children) do
            if child:IsShown() and child:IsMouseOver() then return true end
        end
    end

    return false
end

local function IsMouseOverUI()
    local gemPopup, enchantPopup, bar = CharacterPanel.gemPopup, CharacterPanel.enchantPopup, CharacterPanel.socketBar

    return IsHovered(gemPopup, gemPopup and gemPopup.rows)
        or IsHovered(enchantPopup, enchantPopup and enchantPopup.rows)
        or IsHovered(bar, bar and bar.buttons)
        or IsHovered(CharacterPanel.enchantButton)
end

local function CloseAfterLeave()
    C_Timer.After(LEAVE_DELAY, function()
        if IsMouseOverUI() then return end
        CharacterPanel:HideGemPopup()
        CharacterPanel:HideEnchantPopup()
        CharacterPanel:HideSlotHighlight()
    end)
end

local function CreateQualityOverlay(parent, anchor)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + 10)
    frame:NUISetPixelSize(16, 16)
    frame:NUISetPixelPoint('TOPLEFT', anchor or parent, 'TOPLEFT', -5, 5)

    local texture = frame:CreateTexture(nil, 'OVERLAY')
    texture:NUISetPixelSnap()
    texture:SetAllPoints()
    texture:Hide()

    return frame, texture
end

local function CreateListPopup(globalName, titleText, onClick)
    local popup = CreateFrame('Frame', globalName, UIParent)
    popup:NUISetPixelSize(POPUP_WIDTH, 50)
    popup:SetFrameStrata('TOOLTIP')
    popup:SetClipsChildren(true)
    popup:EnableMouse(true)
    popup:Hide()

    popup:NUICreateBackdrop()
    popup:SetBackgroundColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 0.8)
    popup:SetBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    popup.title = popup:CreateFontString(nil, 'OVERLAY')
    popup.title:SetFontStyle(nil, 14, 'OUTLINE')
    popup.title:NUISetPixelPoint('TOPLEFT', popup, 'TOPLEFT', 6, -6)
    popup.title:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])
    popup.title:SetText(titleText)

    popup.separator = popup:CreateTexture(nil, 'ARTWORK')
    popup.separator:NUISetPixelHeight(1)
    popup.separator:NUISetPixelPoint('TOPLEFT', popup, 'TOPLEFT', 1, -TITLE_HEIGHT)
    popup.separator:NUISetPixelPoint('TOPRIGHT', popup, 'TOPRIGHT', -1, -TITLE_HEIGHT)
    popup.separator:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    popup.empty = popup:CreateFontString(nil, 'OVERLAY')
    popup.empty:SetFontStyle(nil, 12, 'OUTLINE')
    popup.empty:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3])
    popup.empty:NUISetPixelPoint('CENTER', popup, 'CENTER', 0, -8)
    popup.empty:Hide()

    popup:SetScript('OnLeave', CloseAfterLeave)

    popup.rows = {}
    popup.onClick = onClick

    return popup
end

local function CreateListRow(popup, index)
    if popup.rows[index] then return popup.rows[index] end

    local row = CreateFrame('Button', nil, popup)
    row:NUISetPixelHeight(POPUP_ICON_SIZE + ROW_PADDING)

    row.iconFrame = CreateFrame('Frame', nil, row)
    row.iconFrame:NUISetPixelSize(POPUP_ICON_SIZE, POPUP_ICON_SIZE)
    row.iconFrame:NUISetPixelPoint('LEFT', row, 'LEFT', -1, 0)
    row.iconFrame:NUIAddBorders()
    row.iconFrame:SetBorderColor(unpack(Theme.border))

    row.icon = row.iconFrame:CreateTexture(nil, 'ARTWORK')
    row.icon:SetAllPoints()
    row.icon:NUISetZoom()

    row.qualityFrame, row.quality = CreateQualityOverlay(row, row.iconFrame)

    row.text = row:CreateFontString(nil, 'OVERLAY')
    row.text:SetFontStyle(nil, 12, 'OUTLINE')
    row.text:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3])
    row.text:NUISetPixelPoint('LEFT', row.iconFrame, 'RIGHT', 6, 0)
    row.text:NUISetPixelWidth(POPUP_WIDTH - POPUP_ICON_SIZE - 60)
    row.text:SetJustifyH('LEFT')
    row.text:SetWordWrap(true)

    row.count = row:CreateFontString(nil, 'OVERLAY')
    row.count:SetFontStyle(nil, 12, 'OUTLINE')
    row.count:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3])
    row.count:NUISetPixelPoint('RIGHT', row, 'RIGHT', -4, 0)

    row.hoverBg = row:CreateTexture(nil, 'BACKGROUND')
    row.hoverBg:SetAllPoints()
    row.hoverBg:SetColorTexture(1, 1, 1, 0.05)
    row.hoverBg:SetAlpha(0)
    row.hoverTarget = 0

    row:SetScript('OnUpdate', function(button, elapsed)
        local current = button.hoverBg:GetAlpha()
        if math_abs(current - button.hoverTarget) <= 0.01 then return end

        local step = elapsed / HOVER_DURATION
        if button.hoverTarget > current then
            button.hoverBg:SetAlpha(math_min(current + step, button.hoverTarget))
        else
            button.hoverBg:SetAlpha(math_max(current - step, button.hoverTarget))
        end
    end)

    row:SetScript('OnEnter', function(button)
        button.hoverTarget = 1
        if button.highlightSlots then CharacterPanel:ShowSlotHighlight(button.highlightSlots) end
        if button.data and button.data.link then
            GameTooltip:SetOwner(button, 'ANCHOR_RIGHT', 40, 0)
            GameTooltip:SetHyperlink(button.data.link)
            GameTooltip:Show()
        end
    end)

    row:SetScript('OnLeave', function(button)
        button.hoverTarget = 0
        GameTooltip:Hide()
        CloseAfterLeave()
    end)

    row:SetScript('OnClick', function(button)
        popup.onClick(button)
    end)

    popup.rows[index] = row
    return row
end

---Lay rows out top to bottom and size the popup to fit. Rows are measured after their text is set
---because a gem's stat line can wrap to two lines.
local function LayoutRows(popup, entries, fill)
    local minRowHeight = POPUP_ICON_SIZE + ROW_PADDING

    if #entries == 0 then
        popup.empty:Show()
        popup.separator:Hide()
        for _, row in pairs(popup.rows) do row:Hide() end
        popup:NUISetPixelSize(math_max(200, popup.title:GetStringWidth() + 26), 50)
        return
    end

    popup.empty:Hide()
    popup.separator:Show()

    local yOffset = TITLE_HEIGHT

    for i, entry in ipairs(entries) do
        local row = CreateListRow(popup, i)
        row.data = entry
        row.icon:SetTexture(entry.icon)
        row.count:SetText(entry.count .. 'x')
        row.hoverBg:SetAlpha(0)
        row.hoverTarget = 0

        fill(row, entry)

        local rowHeight = math_max(minRowHeight, row.text:GetStringHeight() + ROW_PADDING)
        row:NUISetPixelHeight(rowHeight)
        row:ClearAllPoints()
        row:NUISetPixelPoint('TOPLEFT', popup, 'TOPLEFT', POPUP_PADDING, -yOffset)
        row:NUISetPixelPoint('TOPRIGHT', popup, 'TOPRIGHT', -POPUP_PADDING, -yOffset)

        SetQualityAtlas(row.quality, GetQualityAtlas(entry.link))
        row:Show()

        yOffset = yOffset + rowHeight
    end

    for i = #entries + 1, #popup.rows do popup.rows[i]:Hide() end

    popup:NUISetPixelSize(POPUP_WIDTH, yOffset)
end

local function AnchorPopup(popup, anchor)
    popup:ClearAllPoints()
    popup:NUISetPixelPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -1)
    popup:Show()
end

-- Gem popup --

function CharacterPanel:CreateGemPopup()
    if self.gemPopup then return self.gemPopup end

    self.gemPopup = CreateListPopup('NRSKNUI_GemPopup', 'Gems', function(row)
        if NRSKNUI:InCombat() then
            NRSKNUI:Print('Cannot socket during combat')
            return
        end
        if not row.data or not row.targetSlotID or not row.targetSocketIndex then return end

        SocketInventoryItem(row.targetSlotID)
        PickupContainerItem(row.data.bagID, row.data.slotID)
        ClickSocketButton(row.targetSocketIndex)
        ClearCursor()
        AcceptSockets()
        CloseSocketInfo()

        if ItemSocketingFrame then HideUIPanel(ItemSocketingFrame) end

        CharacterPanel:HideGemPopup()
        CharacterPanel:HideSlotHighlight()

        RunNextFrame(function()
            if NRSKNUI:InCombat() then return end
            CharacterPanel:RefreshSocketBar()
        end)
    end)

    self.gemPopup:SetScript('OnEnter', function()
        local button = CharacterPanel.activeSocketButton
        if button and button.socketInfo then
            CharacterPanel:ShowSlotHighlight(button.socketInfo.slotID)
        end
    end)

    return self.gemPopup
end

function CharacterPanel:ShowGemPopup(socketButton)
    if not socketButton.socket then
        self:HideGemPopup()
        return
    end

    local popup = self:CreateGemPopup()
    local currentGemID = socketButton.socket.gemID
    local entries = {}

    for _, gemData in pairs(self:ScanBagsForGems()) do
        if gemData.itemID ~= currentGemID then
            tinsert(entries, gemData)
        end
    end

    popup.title:SetText(socketButton.socket.filled and 'Replace Gem' or 'Socket Gem')
    popup.empty:SetText(socketButton.socket.filled and 'No replacement gems' or 'No compatible gems')

    LayoutRows(popup, entries, function(row, entry)
        row.targetSlotID = socketButton.socketInfo.slotID
        row.targetSocketIndex = socketButton.socket.index
        row.highlightSlots = socketButton.socketInfo.slotID
        row.text:SetText(GetGemStats(entry.link) or '')
    end)

    AnchorPopup(popup, socketButton)
end

function CharacterPanel:HideGemPopup()
    if self.gemPopup then self.gemPopup:Hide() end
end

-- Enchant popup --

function CharacterPanel:CreateEnchantPopup()
    if self.enchantPopup then return self.enchantPopup end

    self.enchantPopup = CreateListPopup('NRSKNUI_EnchantPopup', 'Enchants', function(row)
        if NRSKNUI:InCombat() then
            NRSKNUI:Print('Cannot enchant during combat')
            return
        end
        if not row.data then return end

        UseContainerItem(row.data.bagID, row.data.slotID)
        CharacterPanel:HideEnchantPopup()
        CharacterPanel:HideSlotHighlight()
    end)

    self.enchantPopup.empty:SetText('No enchants in bags')

    return self.enchantPopup
end

function CharacterPanel:ShowEnchantPopup(anchor)
    local popup = self:CreateEnchantPopup()
    local entries = {}

    for _, enchantData in pairs(self:ScanBagsForEnchants()) do
        local targetSlotID = self:FindBestEnchantSlot(enchantData.targetSlots)
        if targetSlotID then
            enchantData.resolvedSlotID = targetSlotID
            tinsert(entries, enchantData)
        end
    end

    LayoutRows(popup, entries, function(row, entry)
        row.targetSlotID = entry.resolvedSlotID
        -- Ring and weapon enchants apply to either of two slots, so highlight both.
        row.highlightSlots = IsMultiSlot(entry.targetSlots) and entry.targetSlots or entry.resolvedSlotID
        row.text:SetText(GetItemName(entry.link) or '')
    end)

    AnchorPopup(popup, anchor)
end

function CharacterPanel:HideEnchantPopup()
    if self.enchantPopup then self.enchantPopup:Hide() end
end

-- Socket bar --

function CharacterPanel:CreateSocketBar()
    if self.socketBar then return self.socketBar end

    local bar = CreateFrame('Frame', 'NRSKNUI_SocketBar', PaperDollFrame)
    bar:NUISetPixelPoint('TOPLEFT', CharacterFrameTab3 or CharacterFrameTab2, 'TOPRIGHT', 4, -6)
    bar:NUISetPixelSize(200, self.db.Sockets.ButtonSize)
    bar:Hide()

    bar.buttons = {}
    self.socketBar = bar
    return bar
end

function CharacterPanel:CreateSocketButton(index)
    local bar = self.socketBar
    if bar.buttons[index] then return bar.buttons[index] end

    local size = self.db.Sockets.ButtonSize
    local button = CreateFrame('Button', nil, bar)
    button:NUISetPixelSize(size, size)

    button.icon = button:CreateTexture(nil, 'ARTWORK')
    button.icon:SetAllPoints()
    button.icon:NUISetZoom()

    button:NUIAddBorders()
    button:SetBorderColor(unpack(Theme.border))

    button.highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    button.highlight:NUISetPixelInside(button, 1, 1)
    button.highlight:SetColorTexture(1, 1, 1, 0.2)
    button.highlight:SetBlendMode('ADD')

    button.qualityFrame, button.quality = CreateQualityOverlay(button)

    button:SetScript('OnEnter', function(btn)
        CharacterPanel:HideEnchantPopup()
        CharacterPanel.activeSocketButton = btn
        CharacterPanel:ShowGemPopup(btn)

        if btn.socketInfo then CharacterPanel:ShowSlotHighlight(btn.socketInfo.slotID) end

        if btn.socket and btn.socket.filled and btn.socket.gemLink then
            GameTooltip:SetOwner(btn, 'ANCHOR_RIGHT', 40, 0)
            GameTooltip:SetHyperlink(btn.socket.gemLink)
            GameTooltip:Show()
        end
    end)

    button:SetScript('OnLeave', function()
        GameTooltip:Hide()
        CloseAfterLeave()
    end)

    button:SetScript('OnClick', function(btn)
        if NRSKNUI:InCombat() then
            NRSKNUI:Print('Cannot socket during combat')
            return
        end
        if btn.socketInfo then SocketInventoryItem(btn.socketInfo.slotID) end
    end)

    bar.buttons[index] = button
    return button
end

function CharacterPanel:CreateEnchantButton()
    if self.enchantButton then return self.enchantButton end

    local size = self.db.Sockets.ButtonSize
    local button = CreateFrame('Button', nil, self.socketBar)
    button:NUISetPixelSize(size, size)

    button.icon = button:CreateTexture(nil, 'ARTWORK')
    button.icon:SetAllPoints()
    button.icon:SetTexture(ENCHANT_BUTTON_ICON)
    button.icon:NUISetZoom()

    button:NUIAddBorders()
    button:SetBorderColor(unpack(Theme.border))

    button.highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    button.highlight:NUISetPixelInside(button, 1, 1)
    button.highlight:SetColorTexture(1, 1, 1, 0.2)
    button.highlight:SetBlendMode('ADD')

    button:SetScript('OnEnter', function(btn)
        CharacterPanel:HideGemPopup()
        CharacterPanel:HideSlotHighlight()
        CharacterPanel:ShowEnchantPopup(btn)
    end)

    button:SetScript('OnLeave', CloseAfterLeave)

    button:Hide()
    self.enchantButton = button
    return button
end

function CharacterPanel:RefreshEnchantButton()
    if not self.db.Enchants.Enabled then
        if self.enchantButton then self.enchantButton:Hide() end
        return false
    end

    local button = self:CreateEnchantButton()
    local db = self.db.Sockets
    local last

    for i = #self.socketBar.buttons, 1, -1 do
        if self.socketBar.buttons[i]:IsShown() then
            last = self.socketBar.buttons[i]
            break
        end
    end

    button:NUISetPixelSize(db.ButtonSize, db.ButtonSize)
    button:ClearAllPoints()

    if last then
        button:NUISetPixelPoint('LEFT', last, 'RIGHT', db.ButtonSpacing, 0)
    else
        button:NUISetPixelPoint('LEFT', self.socketBar, 'LEFT', 0, 0)
    end

    button:Show()
    return true
end

---The bar hosts both features, so it stays alive while either one is on.
function CharacterPanel:RefreshSocketBar()
    if not self.socketBar then return end

    local db = self.db.Sockets
    local index = 1

    self.socketBar:NUISetPixelHeight(db.ButtonSize)

    if db.Enabled then
        for _, itemSocketInfo in ipairs(self:ScanAllEquippedSockets()) do
            for _, socket in ipairs(itemSocketInfo.sockets) do
                if not db.ShowOnlyEmpty or not socket.filled then
                    local button = self:CreateSocketButton(index)
                    button.socketInfo = itemSocketInfo
                    button.socket = socket

                    button:NUISetPixelSize(db.ButtonSize, db.ButtonSize)
                    button:ClearAllPoints()
                    if index == 1 then
                        button:NUISetPixelPoint('LEFT', self.socketBar, 'LEFT', 0, 0)
                    else
                        button:NUISetPixelPoint('LEFT', self.socketBar.buttons[index - 1], 'RIGHT', db.ButtonSpacing, 0)
                    end

                    if socket.filled then
                        button.icon:SetTexture(socket.icon)
                        button:SetAlpha(1)
                        SetQualityAtlas(button.quality, GetQualityAtlas(socket.gemLink))
                    else
                        button.icon:SetTexture(socket.icon or EMPTY_SOCKET_ICON)
                        button:SetAlpha(0.6)
                        button.quality:Hide()
                    end

                    button:Show()
                    index = index + 1
                end
            end
        end
    end

    for i = index, #self.socketBar.buttons do self.socketBar.buttons[i]:Hide() end

    local socketCount = index - 1
    local total = socketCount + (self:RefreshEnchantButton() and 1 or 0)

    if total == 0 then
        self.socketBar:Hide()
        return
    end

    self.socketBar:NUISetPixelWidth(total * (db.ButtonSize + db.ButtonSpacing))
    self.socketBar:Show()
end

function CharacterPanel:OnPaperDollHidden()
    if self.socketBar then self.socketBar:Hide() end
    self:HideGemPopup()
    self:HideEnchantPopup()
    self:HideSlotHighlight()
end

function CharacterPanel:ApplySettings()
    if not self.db.Enabled then return end
    -- The GUI and profile refreshes can reach us before Blizzard_UIPanels_Game has loaded.
    if not PaperDollFrame then return end

    self:StyleCharacterTexts()

    if self.db.Sockets.Enabled or self.db.Enchants.Enabled then self:CreateSocketBar() end
    if self.db.Sockets.Enabled then self:CreateGemPopup() end
    if self.db.Enchants.Enabled then self:CreateEnchantPopup() end

    if PaperDollFrame and PaperDollFrame:IsShown() then
        if self.db.TrackIndicators.Enabled then
            self:UpdateAllTrackIndicators()
        else
            self:HideAllTrackIndicators()
        end
        self:RefreshSocketBar()
    end
end

-- Everything here reaches into PaperDollFrame, which lives in the load-on-demand
-- Blizzard_UIPanels_Game. Callers come in through OnEnable's ContinueOnAddOnLoaded.
function CharacterPanel:SetupPanel()
    -- Initialize the socket bar and popups.
    if not self.hooked then
        if self.db.Sockets.Enabled or self.db.Enchants.Enabled then
            self:CreateSocketBar()
        end
        if self.db.Sockets.Enabled then self:CreateGemPopup() end
        if self.db.Enchants.Enabled then self:CreateEnchantPopup() end

        self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED', function(_, slotID)
            if self.db.TrackIndicators.Enabled then self:UpdateSlotTrackIndicator(slotID) end
            self:RefreshSocketBar()
        end)

        self:RegisterEvent('BAG_UPDATE_DELAYED', function()
            if self.socketBar and self.socketBar:IsShown() then self:RefreshSocketBar() end
        end)

        PaperDollFrame:HookScript('OnShow', function()
            self:UpdateAllTrackIndicators()
            self:RefreshSocketBar()
        end)
        PaperDollFrame:HookScript('OnHide', function() self:OnPaperDollHidden() end)

        -- Blizzard rebuilds these texts on its own schedule, so restyle from its own updates.
        -- hooksecurefunc can never be removed, hence the Enabled gate inside each one.
        hooksecurefunc('PaperDollFrame_SetItemLevel', function(_, unit)
            if not self.db.Enabled or unit ~= 'player' then return end
            UpdateItemLevelText()
        end)

        hooksecurefunc('PaperDollFrame_SetLabelAndText', function(statFrame)
            if not self.db.Enabled then return end
            -- The item level frame owns its own size setting, handled by UpdateItemLevelText.
            if statFrame == _G.CharacterStatsPane.ItemLevelFrame then return end

            statFrame.Label:SetFontStyle(self.db, self.db.StatsFontSize)
            statFrame.Value:SetFontStyle(self.db, self.db.StatsFontSize)
        end)

        hooksecurefunc('PaperDollFrame_SetLevel', function()
            if not self.db.Enabled then return end
            UpdateLevelTextWithFaction()
            if self.db.ShowRaceText then self:ShowRaceText() end
        end)

        self.hooked = true
    end
    self:ApplySettings()
end

function CharacterPanel:OnEnable()
    -- Fires immediately when the addon is already loaded, defers when it is not.
    EventUtil.ContinueOnAddOnLoaded('Blizzard_UIPanels_Game', function()
        if self:IsEnabled() then self:SetupPanel() end
    end)
end

function CharacterPanel:OnDisable()
    self:HideAllTrackIndicators()
    self:HideRaceText()
    self:OnPaperDollHidden()
end
