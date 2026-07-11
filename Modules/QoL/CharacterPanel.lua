---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

---@class CharacterPanel: AceModule, AceEvent-3.0, AceHook-3.0
local CHAR = NRSKNUI:NewModule("CharacterPanel", "AceEvent-3.0", "AceHook-3.0")

local GetAverageItemLevel = GetAverageItemLevel
local GetInventoryItemLink = GetInventoryItemLink
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo
local CreateFrame = CreateFrame
local UnitRace = UnitRace
local UnitFactionGroup = UnitFactionGroup
local hooksecurefunc = hooksecurefunc
local pairs = pairs
local ipairs = ipairs
local GetRealmName = GetRealmName
local tonumber = tonumber
local unpack = unpack
local format = string.format
local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local tinsert = table.insert
local wipe = table.wipe
local C_Timer = C_Timer
local C_Item = C_Item
local C_Container = C_Container

local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4
local LE_ITEM_CLASS_GEM = Enum.ItemClass.Gem or 3
local LE_ITEM_CLASS_ITEM_ENHANCEMENT = Enum.ItemClass.ItemEnhancement or 8
local SocketInventoryItem = SocketInventoryItem
local AcceptSockets = AcceptSockets
local CloseSocketInfo = CloseSocketInfo
local InCombatLockdown = InCombatLockdown
local ClearCursor = ClearCursor
local HideUIPanel = HideUIPanel
local UseContainerItem = C_Container.UseContainerItem

local SLOT_FRAMES = {
    [1] = "CharacterHeadSlot",
    [2] = "CharacterNeckSlot",
    [3] = "CharacterShoulderSlot",
    [5] = "CharacterChestSlot",
    [6] = "CharacterWaistSlot",
    [7] = "CharacterLegsSlot",
    [8] = "CharacterFeetSlot",
    [9] = "CharacterWristSlot",
    [10] = "CharacterHandsSlot",
    [11] = "CharacterFinger0Slot",
    [12] = "CharacterFinger1Slot",
    [13] = "CharacterTrinket0Slot",
    [14] = "CharacterTrinket1Slot",
    [15] = "CharacterBackSlot",
    [16] = "CharacterMainHandSlot",
    [17] = "CharacterSecondaryHandSlot",
}

-- Season Configuration: S1 Midnight
local SEASON = {
    -- PvP arena ilvls
    conquestIlvl = 289,
    honorIlvl = 276,
    -- Crafted ilvls
    craftedVoidforged = 295,
    craftedMyth = 285,
    craftedHero = 272,
}

local TIER_COLORS = {
    myth       = { letter = "M", color = { 1.00, 0.50, 0.00 } },
    conquest   = { letter = "C", color = { 1.00, 0.50, 0.00 } },
    hero       = { letter = "H", color = { 0.78, 0.30, 0.78 } },
    honor      = { letter = "H", color = { 0.78, 0.30, 0.78 } },
    champion   = { letter = "C", color = { 0.00, 0.70, 1.00 } },
    veteran    = { letter = "V", color = { 0.00, 0.80, 0.00 } },
    adventurer = { letter = "A", color = { 0.70, 0.70, 0.70 } },
}

local ITEM_TRACK_LOOKUP = {
    Myth       = "myth",
    Hero       = "hero",
    Champion   = "champion",
    Veteran    = "veteran",
    Adventurer = "adventurer",
}

local VOIDFORGED_LOOKUP = {
    M = "myth",
    H = "hero",
}

local SPOREFUSED_LOOKUP = {
    Myth     = "myth",
    Hero     = "hero",
    Champion = "champion",
    Veteran  = "veteran",
}

local CRAFTED_TIERS = {
    { ilvl = SEASON.craftedVoidforged, tier = "myth" },
    { ilvl = SEASON.craftedMyth,       tier = "myth" },
    { ilvl = SEASON.craftedHero,       tier = "hero" },
}

local PVP_TIERS = {
    { ilvl = SEASON.conquestIlvl, tier = "conquest" },
    { ilvl = SEASON.honorIlvl,    tier = "honor" },
}

local qualityAtlasPattern = "|A:(Professions%-ChatIcon%-Quality%-[^:]+):%d+:%d+"

local function GetQualityAtlasFromLink(link)
    if not link then return nil end
    return link:match(qualityAtlasPattern)
end

local function SetQualityAtlas(texture, atlas)
    if not atlas then
        texture:Hide()
        return
    end
    texture:SetAtlas(atlas, false)
    texture:Show()
end

local function GetGemStatsFromLink(link)
    if not link then return nil end
    local data = C_TooltipInfo.GetHyperlink(link)
    if not data or not data.lines then return nil end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text and text:match("^%+%d+") then
            return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        end
    end
    return nil
end

function CHAR:UpdateDB() self.db = NRSKNUI.db.profile.CharacterPanel end

function CHAR:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function UpdateItemLevelText()
    local ivlText = _G.CharacterStatsPane.ItemLevelFrame.Value
    ivlText:SetFontStyle(CHAR.db, CHAR.db.IlvlValueSize)

    local _, avgItemLevelEquipped = GetAverageItemLevel()
    if CHAR.db.Enabled and CHAR.db.DecimalItemLevel then
        ivlText:SetText(format("%.2f", avgItemLevelEquipped))
    else
        ivlText:SetText(format("%d", floor(avgItemLevelEquipped)))
    end
end

function CHAR:StyleCharacterTexts()
    -- Level + Class spec text, has (H)/(A) as faction indicator aswell
    _G.CharacterLevelText:SetFontStyle(CHAR.db, CHAR.db.LevelTextSize)
    _G.CharacterLevelText:SetWidth(0)
    _G.CharacterLevelText:SetWordWrap(true)

    -- Character name + title text
    if _G.CharacterFrameTitleText then
        _G.CharacterFrameTitleText:SetFontStyle(CHAR.db, CHAR.db.NameTextSize)
    end

    -- "Item level" Title text
    _G.CharacterStatsPane.ItemLevelCategory.Title:SetFontStyle(CHAR.db, CHAR.db.CategoryFontSize)
    _G.CharacterStatsPane.ItemLevelCategory.Title:SetTextColor(unpack(NRSKNUI:GetPlayerClassColor()))

    -- "Attributes & Enhancements" Title texts
    local categories = {
        _G.CharacterStatsPane.AttributesCategory,
        _G.CharacterStatsPane.EnhancementsCategory,
    }
    for _, category in ipairs(categories) do
        if category and category.Title then
            category.Title:SetFontStyle(CHAR.db, CHAR.db.CategoryFontSize)
            category.Title:SetTextColor(unpack(NRSKNUI:GetPlayerClassColor()))
        end
    end

    UpdateItemLevelText()
end

-- Item Track Indicators --

function CHAR:GetItemTrack(slotID)
    local data = C_TooltipInfo.GetInventoryItem("player", slotID)
    if not data or not data.lines then return nil end

    local isCrafted = false
    local pvpIlvl = nil
    local normalTier = nil
    local voidforgedTier = nil
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            -- Normal upgrade track items
            local trackKeyword = text:match("Upgrade Level: (%a+)")
            if trackKeyword then
                normalTier = ITEM_TRACK_LOOKUP[trackKeyword]
            end

            -- Voidforged items
            local voidforgedMatch = text:match("Ascendant Voidforged: (%a)")
            if voidforgedMatch then
                voidforgedTier = VOIDFORGED_LOOKUP[voidforgedMatch]
            end

            -- Sporefused items
            local sporefusedMatch = text:match("Sporefused: (%a+)")
            if sporefusedMatch then
                voidforgedTier = SPOREFUSED_LOOKUP[sporefusedMatch]
            end

            -- Crafted items
            if text:find("Radiance Crafted") then isCrafted = true end

            -- PvP items
            local pvpMatch = text:match("Increases item level to a minimum of (%d+)")
            if pvpMatch then
                pvpIlvl = tonumber(pvpMatch)
            end
        end
    end

    -- Priority: Voidforged > PvP > Normal > Crafted
    if voidforgedTier then
        return TIER_COLORS[voidforgedTier]
    end

    if pvpIlvl then
        for _, tier in ipairs(PVP_TIERS) do
            if pvpIlvl >= tier.ilvl then
                return TIER_COLORS[tier.tier]
            end
        end
    end

    if normalTier then
        return TIER_COLORS[normalTier]
    end

    if isCrafted then
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local ilvl = GetDetailedItemLevelInfo(itemLink)
            if ilvl then
                for _, tier in ipairs(CRAFTED_TIERS) do
                    if ilvl >= tier.ilvl then
                        return TIER_COLORS[tier.tier]
                    end
                end
            end
        end
    end

    return nil
end

local RIGHT_SLOTS = {
    [6] = true,  -- Waist
    [7] = true,  -- Legs
    [8] = true,  -- Feet
    [10] = true, -- Hands
    [11] = true, -- Finger0
    [12] = true, -- Finger1
    [13] = true, -- Trinket0
    [14] = true, -- Trinket1
    [17] = true, -- SecondaryHand
}

function CHAR:CreateTrackOverlay(slotFrame, slotID)
    if slotFrame._trackOverlay then return slotFrame._trackOverlay end

    local isRight = RIGHT_SLOTS[slotID]
    local overlay = CreateFrame("Frame", nil, slotFrame)
    overlay:SetSize(14, 14)
    overlay:SetFrameLevel(slotFrame:GetFrameLevel() + 10)

    if isRight then
        overlay:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", 1, 1)
    else
        overlay:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMLEFT", 0, 1)
    end

    overlay.text = NRSKNUI:CreateText(overlay, "OVERLAY")
    NRSKNUI:SetTextFont(overlay.text, "Expressway", 12, "OUTLINE", {})
    overlay.text:SetShadowColor(0, 0, 0, 0)

    if isRight then
        overlay.text:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
        overlay.text:SetJustifyH("RIGHT")
    else
        overlay.text:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
        overlay.text:SetJustifyH("LEFT")
    end

    overlay:Hide()
    slotFrame._trackOverlay = overlay
    return overlay
end

function CHAR:UpdateSlotTrackIndicator(slotID)
    local frameName = SLOT_FRAMES[slotID]
    if not frameName then return end

    local slotFrame = _G[frameName]
    if not slotFrame then return end

    local overlay = self:CreateTrackOverlay(slotFrame, slotID)
    local track = self:GetItemTrack(slotID)

    if track then
        overlay.text:SetText(track.letter)
        overlay.text:SetTextColor(track.color[1], track.color[2], track.color[3])
        overlay:Show()
    else
        overlay:Hide()
    end
end

function CHAR:UpdateAllTrackIndicators()
    if not self.db.TrackIndicators or not self.db.TrackIndicators.Enabled then return end
    for slotID in pairs(SLOT_FRAMES) do
        self:UpdateSlotTrackIndicator(slotID)
    end
end

function CHAR:HideAllTrackIndicators()
    for _, frameName in pairs(SLOT_FRAMES) do
        local slotFrame = _G[frameName]
        if slotFrame and slotFrame._trackOverlay then
            slotFrame._trackOverlay:Hide()
        end
    end
end

local function UpdateLevelTextWithFaction()
    local text = _G.CharacterLevelText:GetText()
    if not text then return end

    text = text:gsub(" |c%x%x%x%x%x%x%x%x%([AH]%)|r$", "")

    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        text = text .. " |cff3399ff(A)|r"
    elseif faction == "Horde" then
        text = text .. " |cffe63333(H)|r"
    end

    _G.CharacterLevelText:SetText(text)
end

function CHAR:CreateRaceText()
    if self._raceText then return self._raceText end

    local text = PaperDollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall2")
    text:SetPoint("TOP", CharacterLevelText, "BOTTOM", 0, 5)
    text:SetText(GetRealmName() .. " - " .. UnitRace("player"))
    text:Hide()

    self._raceText = text
    return text
end

function CHAR:UpdateRaceTextPosition()
    if not self._raceText then return end
    if not self.db.ShowRaceText then return end
    CharacterLevelText:SetPointsOffset(0, -37)
end

function CHAR:ShowRaceText()
    if not self.db.ShowRaceText then return end

    local text = self:CreateRaceText()
    text:SetFontStyle(self.db, self.db.LevelTextSize)
    text:SetText(GetRealmName() .. " - " .. UnitRace("player"))
    text:Show()
    self:UpdateRaceTextPosition()
end

function CHAR:HideRaceText()
    if self._raceText then
        self._raceText:Hide()
    end
    if CharacterLevelText then
        CharacterLevelText:SetPointsOffset(0, 0)
    end
end

function CHAR:ApplySettings()
    if not self.db.Enabled then return end

    UpdateItemLevelText()
    self:StyleCharacterTexts()
    UpdateLevelTextWithFaction()
    self:SetupGemSocketHelper()
    if self.db.ShowRaceText then
        self:ShowRaceText()
    else
        self:HideRaceText()
    end
    if self.db.GemSocketHelper.Enabled and PaperDollFrame and PaperDollFrame:IsShown() then
        self:RefreshSocketButtons()
    end
    if self.db.TrackIndicators and self.db.TrackIndicators.Enabled and PaperDollFrame and PaperDollFrame:IsShown() then
        self:UpdateAllTrackIndicators()
    end
end

local hooks = {
    SetItemLevel = false,
    SetLabelAndText = false,
    SetLevel = false,
    TrackIndicators = false,

}

local function SetupHooks()
    if not hooks.SetItemLevel then
        CHAR:SecureHook("PaperDollFrame_SetItemLevel", function(_, unit)
            if not CHAR.db.DecimalItemLevel then return end
            if unit ~= "player" then return end
            UpdateItemLevelText()
        end)
        hooks.SetItemLevel = true
    end

    if not hooks.SetLabelAndText then
        hooksecurefunc("PaperDollFrame_SetLabelAndText", function(statFrame)
            if not CHAR.db.Enabled then return end
            if CharacterStatsPane and statFrame == _G.CharacterStatsPane.ItemLevelFrame then return end

            statFrame.Label:SetFontStyle(CHAR.db, CHAR.db.StatsFontSize)
            statFrame.Value:SetFontStyle(CHAR.db, CHAR.db.StatsFontSize)
        end)
        hooks.SetLabelAndText = true
    end

    if not hooks.SetLevel then
        hooksecurefunc("PaperDollFrame_SetLevel", function()
            if CHAR.db.Enabled then
                UpdateLevelTextWithFaction()
                CHAR:UpdateRaceTextPosition()
            end
        end)
        hooks.SetLevel = true
    end

    if CHAR.db.TrackIndicators.Enabled and not hooks.SetLabelAndText then
        CHAR:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slotID)
            if CHAR.db.TrackIndicators and CHAR.db.TrackIndicators.Enabled then
                CHAR:UpdateSlotTrackIndicator(slotID)
            end
        end)

        if PaperDollFrame then
            PaperDollFrame:HookScript("OnShow", function()
                if CHAR.db.TrackIndicators and CHAR.db.TrackIndicators.Enabled then
                    CHAR:UpdateAllTrackIndicators()
                end
            end)
        end
        hooks.SetLabelAndText = true
    end
end

function CHAR:OnEnable()
    if not self.db.Enabled then return end

    SetupHooks()

    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)
end

function CHAR:OnDisable()
    self:DisableGemSocketHelper()
    self:HideAllTrackIndicators()
    self:HideRaceText()
end

-- Gem Socket Helper --

local scanTooltip
local gemCache = {}
local socketCache = {}

local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "NRSKNUIScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTooltip
end

function CHAR:ScanItemSockets(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then return nil end

    local result = {
        slotID = slotID,
        itemLink = itemLink,
        sockets = {},
        totalCount = 0,
        filledCount = 0,
        emptyCount = 0,
    }

    local filledIndices = {}

    for socketIndex = 1, 3 do
        local gemName, gemLink = C_Item.GetItemGem(itemLink, socketIndex)
        if gemLink then
            result.filledCount = result.filledCount + 1
            result.totalCount = result.totalCount + 1
            filledIndices[socketIndex] = true
            local gemID = C_Item.GetItemInfoInstant(gemLink)
            local gemIcon = gemID and C_Item.GetItemIconByID(gemID)
            tinsert(result.sockets, {
                index = socketIndex,
                filled = true,
                gemLink = gemLink,
                gemName = gemName,
                gemID = gemID,
                icon = gemIcon,
            })
        end
    end

    local tt = GetScanTooltip()
    tt:ClearLines()
    tt:SetInventoryItem("player", slotID, false, false)

    local nextEmptyIndex = 1

    for i = 1, tt:NumLines() do
        local line = _G["NRSKNUIScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                for _, socketType in ipairs(NRSKNUI.GEM_SOCKET_TYPES) do
                    local localeString = _G[socketType.locale]
                    if localeString and text:find(localeString, 1, true) then
                        while filledIndices[nextEmptyIndex] do
                            nextEmptyIndex = nextEmptyIndex + 1
                        end

                        result.emptyCount = result.emptyCount + 1
                        result.totalCount = result.totalCount + 1
                        filledIndices[nextEmptyIndex] = true
                        tinsert(result.sockets, {
                            index = nextEmptyIndex,
                            filled = false,
                            socketType = socketType.name,
                            icon = socketType.icon,
                        })
                        nextEmptyIndex = nextEmptyIndex + 1
                    end
                end
            end
        end
    end

    return result.totalCount > 0 and result or nil
end

function CHAR:ScanAllEquippedSockets()
    wipe(socketCache)
    for _, slotID in ipairs(NRSKNUI.SOCKETABLE_SLOTS) do
        local socketInfo = self:ScanItemSockets(slotID)
        if socketInfo then tinsert(socketCache, socketInfo) end
    end
    return socketCache
end

function CHAR:ScanBagsForGems()
    wipe(gemCache)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
                if classID == LE_ITEM_CLASS_GEM then
                    local existing = gemCache[info.itemID]
                    if existing then
                        existing.count = existing.count + info.stackCount
                    else
                        gemCache[info.itemID] = {
                            itemID = info.itemID,
                            icon = info.iconFileID,
                            count = info.stackCount,
                            link = info.hyperlink,
                            bagID = bag,
                            slotID = slot,
                        }
                    end
                end
            end
        end
    end
    return gemCache
end

local TITLE_HEIGHT = 24
local HOVER_DURATION = 0.12
local ITEM_ROW_PADDING = 4
local POPUP_PADDING = 2
local STANDARD_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function IsMouseOverSocketUI()
    if CHAR.gemPopup and CHAR.gemPopup:IsMouseOver() then return true end
    if CHAR.gemPopup then
        for _, btn in pairs(CHAR.gemPopup.buttons) do
            if btn:IsShown() and btn:IsMouseOver() then return true end
        end
    end
    if CHAR.enchantPopup and CHAR.enchantPopup:IsMouseOver() then return true end
    if CHAR.enchantPopup then
        for _, btn in pairs(CHAR.enchantPopup.buttons) do
            if btn:IsShown() and btn:IsMouseOver() then return true end
        end
    end
    if CHAR.currentSocketBtn and CHAR.currentSocketBtn:IsMouseOver() then return true end
    if CHAR.enchantButton and CHAR.enchantButton:IsMouseOver() then return true end
    if CHAR.socketContainer then
        for _, socketBtn in pairs(CHAR.socketContainer.buttons) do
            if socketBtn:IsShown() and socketBtn:IsMouseOver() then return true end
        end
    end
    return false
end

local function CreateQualityOverlay(parent, anchor)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + 10)
    frame:SetSize(16, 16)
    frame:SetPoint("TOPLEFT", anchor or parent, "TOPLEFT", -5, 5)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:Hide()
    return frame, texture
end

function CHAR:CreateSocketContainer()
    if self.socketContainer then return self.socketContainer end

    local db = self.db.GemSocketHelper
    local container = CreateFrame("Frame", "NRSKNUISocketContainer", PaperDollFrame)
    container:SetPoint("TOPLEFT", CharacterFrameTab3 or CharacterFrameTab2, "TOPRIGHT", 4, -6)
    container:SetSize(200, db.SocketButtonSize)
    container:Hide()

    container.buttons = {}
    self.socketContainer = container
    return container
end

function CHAR:CreateSocketButton(index)
    local db = self.db.GemSocketHelper
    local container = self.socketContainer

    if container.buttons[index] then return container.buttons[index] end

    local btn = CreateFrame("Button", nil, container)
    btn:SetSize(db.SocketButtonSize, db.SocketButtonSize)

    if index == 1 then
        btn:SetPoint("LEFT", container, "LEFT", 0, 0)
    else
        btn:SetPoint("LEFT", container.buttons[index - 1], "RIGHT", db.SocketButtonSpacing, 0)
    end

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    NRSKNUI:ApplyZoom(btn.icon, NRSKNUI.GlobalZoom)

    NRSKNUI:AddBorders(btn, Theme.border)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    btn.highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.highlight:SetColorTexture(1, 1, 1, 0.2)
    btn.highlight:SetBlendMode("ADD")

    btn.qualityFrame, btn.quality = CreateQualityOverlay(btn)

    btn:SetScript("OnEnter", function(button)
        CHAR:HideEnchantPopup()
        CHAR.currentSocketBtn = button
        CHAR:ShowGemPopup(button)
        if button.socketInfo then
            CHAR:ShowSlotHighlight(button.socketInfo.slotID)
        end
        if button.socket and button.socket.filled and button.socket.gemLink then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT", 40, 0)
            GameTooltip:SetHyperlink(button.socket.gemLink)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        C_Timer.After(0.05, function()
            if IsMouseOverSocketUI() then return end
            CHAR:HideGemPopup()
            CHAR:HideEnchantPopup()
            CHAR:HideSlotHighlight()
        end)
    end)

    btn:SetScript("OnClick", function(button)
        if InCombatLockdown() then
            NRSKNUI:Print("Cannot socket during combat")
            return
        end
        if button.socketInfo then
            SocketInventoryItem(button.socketInfo.slotID)
        end
    end)

    container.buttons[index] = btn
    return btn
end

function CHAR:CreateGemPopup()
    if self.gemPopup then return self.gemPopup end

    local popup = CreateFrame("Frame", "NRSKNUIGemPopup", UIParent, "BackdropTemplate")
    popup:SetBackdrop(STANDARD_BACKDROP)
    popup:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
    popup:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    popup:SetSize(280, 50)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetClipsChildren(true)
    popup:Hide()

    popup.title = NRSKNUI:CreateText(popup, "OVERLAY")
    popup.title:SetPoint("TOPLEFT", 6, -6)
    NRSKNUI:SetTextFont(popup.title, "Expressway", 14, "OUTLINE", {})
    popup.title:SetText("Gems")
    popup.title:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])

    popup.separator = popup:CreateTexture(nil, "ARTWORK")
    popup.separator:SetHeight(1)
    popup.separator:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, -TITLE_HEIGHT)
    popup.separator:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, -TITLE_HEIGHT)
    popup.separator:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    popup.noGems = NRSKNUI:CreateText(popup, "OVERLAY")
    popup.noGems:SetPoint("CENTER", 0, -8)
    NRSKNUI:SetTextFont(popup.noGems, "Expressway", 14, "OUTLINE", {})
    popup.noGems:SetText("No compatible gems")
    popup.noGems:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3])
    popup.noGems:Hide()

    popup:EnableMouse(true)
    popup:SetScript("OnEnter", function()
        if CHAR.currentSocketBtn and CHAR.currentSocketBtn.socketInfo then
            CHAR:ShowSlotHighlight(CHAR.currentSocketBtn.socketInfo.slotID)
        end
    end)
    popup:SetScript("OnLeave", function()
        C_Timer.After(0.05, function()
            if IsMouseOverSocketUI() then return end
            CHAR:HideGemPopup()
            CHAR:HideSlotHighlight()
        end)
    end)

    popup.buttons = {}
    self.gemPopup = popup
    return popup
end

local POPUP_ICON_SIZE = 24

function CHAR:CreateGemButton(index)
    local popup = self.gemPopup
    local iconSize = POPUP_ICON_SIZE
    local rowHeight = POPUP_ICON_SIZE + ITEM_ROW_PADDING

    if popup.buttons[index] then return popup.buttons[index] end

    local btn = CreateFrame("Button", "NRSKNUIGemBtn" .. index, popup)
    btn:SetHeight(rowHeight)
    btn:SetPoint("TOPLEFT", popup, "TOPLEFT", POPUP_PADDING, -TITLE_HEIGHT - (index - 1) * rowHeight)
    btn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -POPUP_PADDING, -TITLE_HEIGHT - (index - 1) * rowHeight)

    btn.iconFrame = CreateFrame("Frame", nil, btn)
    btn.iconFrame:SetSize(iconSize, iconSize)
    btn.iconFrame:SetPoint("LEFT", 0, 0)
    NRSKNUI:AddBorders(btn.iconFrame, Theme.border)

    btn.icon = btn.iconFrame:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    NRSKNUI:ApplyZoom(btn.icon, NRSKNUI.GlobalZoom)

    btn.qualityFrame, btn.quality = CreateQualityOverlay(btn, btn.iconFrame)

    btn.stats = NRSKNUI:CreateText(btn, "OVERLAY")
    btn.stats:SetPoint("LEFT", btn.iconFrame, "RIGHT", 6, 0)
    btn.stats:SetWidth(220)
    btn.stats:SetJustifyH("LEFT")
    btn.stats:SetWordWrap(true)
    NRSKNUI:SetTextFont(btn.stats, "Expressway", 12, "OUTLINE", {})
    btn.stats:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3])
    btn.stats:SetShadowColor(0, 0, 0, 0)

    btn.count = NRSKNUI:CreateText(btn, "OVERLAY")
    btn.count:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    NRSKNUI:SetTextFont(btn.count, "Expressway", 12, "OUTLINE", {})
    btn.count:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])
    btn.count:SetShadowColor(0, 0, 0, 0)

    local hoverBg = btn:CreateTexture(nil, "BACKGROUND")
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(1, 1, 1, 0.05)
    hoverBg:SetAlpha(0)
    btn._hoverBg = hoverBg
    btn._hoverTarget = 0

    btn:SetScript("OnUpdate", function(button, elapsed)
        local current = button._hoverBg:GetAlpha()
        if abs(current - button._hoverTarget) > 0.01 then
            local speed = elapsed / HOVER_DURATION
            if button._hoverTarget > current then
                button._hoverBg:SetAlpha(min(current + speed, button._hoverTarget))
            else
                button._hoverBg:SetAlpha(max(current - speed, button._hoverTarget))
            end
        end
    end)

    btn:SetScript("OnEnter", function(button)
        button._hoverTarget = 1
        if button.targetSlotID then CHAR:ShowSlotHighlight(button.targetSlotID) end
        if button.gemData and button.gemData.link then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT", 40, 0)
            GameTooltip:SetHyperlink(button.gemData.link)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(button)
        button._hoverTarget = 0
        GameTooltip:Hide()
        C_Timer.After(0.05, function()
            if IsMouseOverSocketUI() then return end
            CHAR:HideGemPopup()
            CHAR:HideSlotHighlight()
        end)
    end)

    btn:SetScript("OnClick", function(button)
        if InCombatLockdown() then
            NRSKNUI:Print("Cannot socket during combat")
            return
        end
        if button.gemData and button.targetSlotID and button.targetSocketIndex then
            SocketInventoryItem(button.targetSlotID)
            C_Container.PickupContainerItem(button.gemData.bagID, button.gemData.slotID)
            C_ItemSocketInfo.ClickSocketButton(button.targetSocketIndex)
            ClearCursor()
            AcceptSockets()
            CloseSocketInfo()
            if ItemSocketingFrame then
                HideUIPanel(ItemSocketingFrame)
            end
            CHAR:HideGemPopup()
            CHAR:HideSlotHighlight()
            C_Timer.After(0.1, function()
                if InCombatLockdown() then return end
                CHAR:RefreshSocketButtons()
            end)
        end
    end)

    popup.buttons[index] = btn
    return btn
end

function CHAR:RefreshSocketButtons()
    if not self.socketContainer then return end
    if not self.db.GemSocketHelper.Enabled then return end

    local allSockets = self:ScanAllEquippedSockets()
    local db = self.db.GemSocketHelper
    local buttonIndex = 1

    self.socketContainer:SetHeight(db.SocketButtonSize)

    for _, itemSocketInfo in ipairs(allSockets) do
        for _, socket in ipairs(itemSocketInfo.sockets) do
            if not db.ShowOnlyEmpty or not socket.filled then
                local btn = self:CreateSocketButton(buttonIndex)
                btn.socketInfo = itemSocketInfo
                btn.socket = socket

                btn:SetSize(db.SocketButtonSize, db.SocketButtonSize)
                btn:ClearAllPoints()
                if buttonIndex == 1 then
                    btn:SetPoint("LEFT", self.socketContainer, "LEFT", 0, 0)
                else
                    btn:SetPoint("LEFT", self.socketContainer.buttons[buttonIndex - 1], "RIGHT", db.SocketButtonSpacing,
                        0)
                end

                if socket.filled and socket.icon then
                    btn.icon:SetTexture(socket.icon)
                    btn:SetAlpha(1)
                    local atlas = GetQualityAtlasFromLink(socket.gemLink)
                    SetQualityAtlas(btn.quality, atlas)
                else
                    btn.icon:SetTexture(socket.icon or 458977)
                    btn:SetAlpha(0.6)
                    btn.quality:Hide()
                end

                btn:Show()
                buttonIndex = buttonIndex + 1
            end
        end
    end

    for i = buttonIndex, #self.socketContainer.buttons do self.socketContainer.buttons[i]:Hide() end

    self:RefreshEnchantButton()

    local socketCount = buttonIndex - 1
    local enchantCount = (self.enchantButton and self.enchantButton:IsShown()) and 1 or 0
    local totalButtons = socketCount + enchantCount
    local totalWidth = totalButtons * (db.SocketButtonSize + db.SocketButtonSpacing)
    self.socketContainer:SetWidth(totalWidth > 0 and totalWidth or 1)

    if totalButtons > 0 then
        self.socketContainer:Show()
    else
        self.socketContainer:Hide()
    end
end

function CHAR:ShowGemPopup(socketBtn)
    if not socketBtn.socket then
        self:HideGemPopup()
        return
    end

    local popup = self:CreateGemPopup()
    local gems = self:ScanBagsForGems()

    local gemList = {}
    local currentGemID = socketBtn.socket.gemID
    for _, gemData in pairs(gems) do
        if gemData.itemID ~= currentGemID then tinsert(gemList, gemData) end
    end

    if socketBtn.socket.filled then
        popup.title:SetText("Replace Gem")
    else
        popup.title:SetText("Socket Gem")
    end

    local minWidth = popup.title:GetStringWidth() + 26
    local minRowHeight = POPUP_ICON_SIZE + ITEM_ROW_PADDING

    local targetHeight
    if #gemList == 0 then
        popup.noGems:Show()
        popup.separator:Hide()
        popup.noGems:SetText(socketBtn.socket.filled and "No replacement gems" or "No compatible gems")
        for _, btn in pairs(popup.buttons) do btn:Hide() end
        popup:SetWidth(max(200, minWidth))
        targetHeight = 50
    else
        popup.noGems:Hide()
        popup.separator:Show()

        local yOffset = TITLE_HEIGHT
        for i, gemData in ipairs(gemList) do
            local btn = self:CreateGemButton(i)
            btn.gemData = gemData
            btn.targetSlotID = socketBtn.socketInfo.slotID
            btn.targetSocketIndex = socketBtn.socket.index
            btn.icon:SetTexture(gemData.icon)
            btn.count:SetText(gemData.count .. "x")
            btn._hoverBg:SetAlpha(0)
            btn._hoverTarget = 0

            local stats = GetGemStatsFromLink(gemData.link)
            btn.stats:SetText(stats or "")

            local textHeight = btn.stats:GetStringHeight() -- Need to check height since some tooltip can have multiple lines.
            local rowHeight = max(minRowHeight, textHeight + ITEM_ROW_PADDING)

            btn:SetHeight(rowHeight)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", popup, "TOPLEFT", POPUP_PADDING, -yOffset)
            btn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -POPUP_PADDING, -yOffset)
            btn.iconFrame:SetSize(POPUP_ICON_SIZE, POPUP_ICON_SIZE)

            local atlas = GetQualityAtlasFromLink(gemData.link)
            SetQualityAtlas(btn.quality, atlas)

            btn:Show()
            yOffset = yOffset + rowHeight
        end
        for i = #gemList + 1, #popup.buttons do popup.buttons[i]:Hide() end

        popup:SetWidth(280)
        targetHeight = yOffset
    end

    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", socketBtn, "BOTTOMLEFT", 0, -1)
    popup:SetHeight(targetHeight)
    popup:Show()
end

function CHAR:HideGemPopup()
    if self.gemPopup then self.gemPopup:Hide() end
end

function CHAR:CreateSlotHighlightFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("DIALOG")

    frame.texture = frame:CreateTexture(nil, "OVERLAY")
    frame.texture:SetAllPoints()
    frame.texture:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.4)
    frame.texture:SetBlendMode("ADD")

    NRSKNUI:AddBorders(frame, { Theme.accent[1], Theme.accent[2], Theme.accent[3], 1 })
    frame:Hide()
    return frame
end

function CHAR:ShowSlotHighlight(slotID)
    self:HideSlotHighlight()

    local frameName = SLOT_FRAMES[slotID]
    if not frameName then return end

    local slotFrame = _G[frameName]
    if not slotFrame then return end

    if not self.slotHighlights then self.slotHighlights = {} end
    if not self.slotHighlights[1] then
        self.slotHighlights[1] = self:CreateSlotHighlightFrame()
    end

    self.slotHighlights[1]:SetAllPoints(slotFrame)
    self.slotHighlights[1]:Show()
end

function CHAR:ShowMultiSlotHighlight(slotIDs)
    self:HideSlotHighlight()
    if not slotIDs then return end

    if not self.slotHighlights then self.slotHighlights = {} end

    for i, slotID in ipairs(slotIDs) do
        local frameName = SLOT_FRAMES[slotID]
        if frameName then
            local slotFrame = _G[frameName]
            if slotFrame then
                if not self.slotHighlights[i] then
                    self.slotHighlights[i] = self:CreateSlotHighlightFrame()
                end
                self.slotHighlights[i]:SetAllPoints(slotFrame)
                self.slotHighlights[i]:Show()
            end
        end
    end
end

function CHAR:HideSlotHighlight()
    if self.slotHighlights then
        for _, highlight in pairs(self.slotHighlights) do
            highlight:Hide()
        end
    end
end

function CHAR:SetupGemSocketHelper()
    if not self.db.GemSocketHelper.Enabled then return end
    if self._gemSocketHooked then return end
    self._gemSocketHooked = true

    self:CreateSocketContainer()
    self:CreateGemPopup()
    self:CreateEnchantPopup()

    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "RefreshSocketButtons")
    self:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if self.socketContainer and self.socketContainer:IsShown() then self:RefreshSocketButtons() end
    end)

    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function()
            if CHAR.db.GemSocketHelper.Enabled then CHAR:RefreshSocketButtons() end
        end)
        PaperDollFrame:HookScript("OnHide", function()
            if CHAR.socketContainer then CHAR.socketContainer:Hide() end
            CHAR:HideGemPopup()
            CHAR:HideEnchantPopup()
            CHAR:HideSlotHighlight()
        end)
    end
end

function CHAR:DisableGemSocketHelper()
    if self.socketContainer then self.socketContainer:Hide() end
    self:HideGemPopup()
    self:HideEnchantPopup()
end

-- Enchant Helper --

local enchantCache = {}
local ENCHANT_BUTTON_ICON = 4620672

local ENCHANT_SLOT_KEYWORDS = {
    ["chest"] = { 5 },
    ["cloak"] = { 15 },
    ["back"] = { 15 },
    ["cape"] = { 15 },
    ["legs"] = { 7 },
    ["leg"] = { 7 },
    ["boot"] = { 8 },
    ["feet"] = { 8 },
    ["bracer"] = { 9 },
    ["wrist"] = { 9 },
    ["ring"] = { 11, 12 },
    ["weapon"] = { 16, 17 },
    ["staff"] = { 16 },
    ["2h weapon"] = { 16 },
    ["glove"] = { 10 },
    ["hand"] = { 10 },
    ["helm"] = { 1 },
    ["head"] = { 1 },
    ["shoulder"] = { 3 },
    ["belt"] = { 6 },
    ["waist"] = { 6 },
    ["neck"] = { 2 },
    ["trinket"] = { 13, 14 },
}

local function GetEnchantTargetSlots(itemLink)
    if not itemLink then return nil end
    local data = C_TooltipInfo.GetHyperlink(itemLink)
    if not data or not data.lines then return nil end

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            local lowerText = text:lower()
            for keyword, slots in pairs(ENCHANT_SLOT_KEYWORDS) do
                if lowerText:find(keyword, 1, true) then
                    return slots
                end
            end
        end
    end
    return nil
end

local function GetEnchantName(itemLink)
    if not itemLink then return nil end
    local data = C_TooltipInfo.GetHyperlink(itemLink)
    if not data or not data.lines or not data.lines[1] then return nil end
    local name = data.lines[1].leftText
    if name then
        name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end
    return name
end

local function IsRingEnchant(targetSlots)
    if not targetSlots then return false end
    for _, slotID in ipairs(targetSlots) do
        if slotID == 11 or slotID == 12 then return true end
    end
    return false
end

local function IsArmorKit(targetSlots)
    if not targetSlots then return false end
    for _, slotID in ipairs(targetSlots) do
        if slotID == 7 then return true end
    end
    return false
end

function CHAR:ScanBagsForEnchants()
    wipe(enchantCache)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
                if classID == LE_ITEM_CLASS_ITEM_ENHANCEMENT then
                    local targetSlots = GetEnchantTargetSlots(info.hyperlink)
                    if targetSlots and not IsArmorKit(targetSlots) then
                        local existing = enchantCache[info.itemID]
                        if existing then
                            existing.count = existing.count + info.stackCount
                        else
                            enchantCache[info.itemID] = {
                                itemID = info.itemID,
                                icon = info.iconFileID,
                                count = info.stackCount,
                                link = info.hyperlink,
                                bagID = bag,
                                slotID = slot,
                                targetSlots = targetSlots,
                            }
                        end
                    end
                end
            end
        end
    end
    return enchantCache
end

function CHAR:CreateEnchantButton()
    if self.enchantButton then return self.enchantButton end

    local db = self.db.GemSocketHelper
    local btn = CreateFrame("Button", nil, self.socketContainer)
    btn:SetSize(db.SocketButtonSize, db.SocketButtonSize)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexture(ENCHANT_BUTTON_ICON)
    NRSKNUI:ApplyZoom(btn.icon, NRSKNUI.GlobalZoom)

    NRSKNUI:AddBorders(btn, Theme.border)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    btn.highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.highlight:SetColorTexture(1, 1, 1, 0.2)
    btn.highlight:SetBlendMode("ADD")

    btn:SetScript("OnEnter", function()
        CHAR:HideGemPopup()
        CHAR:HideSlotHighlight()
        CHAR:ShowEnchantPopup(btn)
    end)

    btn:SetScript("OnLeave", function()
        C_Timer.After(0.05, function()
            if IsMouseOverSocketUI() then return end
            CHAR:HideGemPopup()
            CHAR:HideEnchantPopup()
            CHAR:HideSlotHighlight()
        end)
    end)

    btn:Hide()
    self.enchantButton = btn
    return btn
end

function CHAR:CreateEnchantPopup()
    if self.enchantPopup then return self.enchantPopup end

    local popup = CreateFrame("Frame", "NRSKNUIEnchantPopup", UIParent, "BackdropTemplate")
    popup:SetBackdrop(STANDARD_BACKDROP)
    popup:SetBackdropColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], Theme.bgMedium[4])
    popup:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)
    popup:SetSize(280, 50)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetClipsChildren(true)
    popup:Hide()

    popup.title = NRSKNUI:CreateText(popup, "OVERLAY")
    popup.title:SetPoint("TOPLEFT", 6, -6)
    NRSKNUI:SetTextFont(popup.title, "Expressway", 14, "OUTLINE", {})
    popup.title:SetText("Enchants")
    popup.title:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])

    popup.separator = popup:CreateTexture(nil, "ARTWORK")
    popup.separator:SetHeight(1)
    popup.separator:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, -TITLE_HEIGHT)
    popup.separator:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, -TITLE_HEIGHT)
    popup.separator:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    popup.noEnchants = NRSKNUI:CreateText(popup, "OVERLAY")
    popup.noEnchants:SetPoint("CENTER", 0, -8)
    NRSKNUI:SetTextFont(popup.noEnchants, "Expressway", 14, "OUTLINE", {})
    popup.noEnchants:SetText("No enchants in bags")
    popup.noEnchants:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3])
    popup.noEnchants:Hide()

    popup:EnableMouse(true)
    popup:SetScript("OnEnter", function() end)
    popup:SetScript("OnLeave", function()
        C_Timer.After(0.05, function()
            if IsMouseOverSocketUI() then return end
            CHAR:HideEnchantPopup()
            CHAR:HideSlotHighlight()
        end)
    end)

    popup.buttons = {}
    self.enchantPopup = popup
    return popup
end

function CHAR:CreateEnchantButton_Popup(index)
    local popup = self.enchantPopup
    local iconSize = POPUP_ICON_SIZE
    local rowHeight = POPUP_ICON_SIZE + ITEM_ROW_PADDING

    if popup.buttons[index] then return popup.buttons[index] end

    local btn = CreateFrame("Button", "NRSKNUIEnchantBtn" .. index, popup)
    btn:SetHeight(rowHeight)
    btn:SetPoint("TOPLEFT", popup, "TOPLEFT", POPUP_PADDING, -TITLE_HEIGHT - (index - 1) * rowHeight)
    btn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -POPUP_PADDING, -TITLE_HEIGHT - (index - 1) * rowHeight)

    btn.iconFrame = CreateFrame("Frame", nil, btn)
    btn.iconFrame:SetSize(iconSize, iconSize)
    btn.iconFrame:SetPoint("LEFT", 0, 0)
    NRSKNUI:AddBorders(btn.iconFrame, Theme.border)

    btn.icon = btn.iconFrame:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    NRSKNUI:ApplyZoom(btn.icon, NRSKNUI.GlobalZoom)

    btn.qualityFrame, btn.quality = CreateQualityOverlay(btn, btn.iconFrame)

    btn.stats = NRSKNUI:CreateText(btn, "OVERLAY")
    btn.stats:SetPoint("LEFT", btn.iconFrame, "RIGHT", 6, 0)
    btn.stats:SetWidth(220)
    btn.stats:SetJustifyH("LEFT")
    btn.stats:SetWordWrap(true)
    NRSKNUI:SetTextFont(btn.stats, "Expressway", 12, "OUTLINE", {})
    btn.stats:SetTextColor(Theme.textPrimary[1], Theme.textPrimary[2], Theme.textPrimary[3])
    btn.stats:SetShadowColor(0, 0, 0, 0)

    btn.count = NRSKNUI:CreateText(btn, "OVERLAY")
    btn.count:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    NRSKNUI:SetTextFont(btn.count, "Expressway", 12, "OUTLINE", {})
    btn.count:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])
    btn.count:SetShadowColor(0, 0, 0, 0)

    local hoverBg = btn:CreateTexture(nil, "BACKGROUND")
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(1, 1, 1, 0.05)
    hoverBg:SetAlpha(0)
    btn._hoverBg = hoverBg
    btn._hoverTarget = 0

    btn:SetScript("OnUpdate", function(button, elapsed)
        local current = button._hoverBg:GetAlpha()
        if abs(current - button._hoverTarget) > 0.01 then
            local speed = elapsed / HOVER_DURATION
            if button._hoverTarget > current then
                button._hoverBg:SetAlpha(min(current + speed, button._hoverTarget))
            else
                button._hoverBg:SetAlpha(max(current - speed, button._hoverTarget))
            end
        end
    end)

    btn:SetScript("OnEnter", function(button)
        button._hoverTarget = 1
        if button.enchantData and IsRingEnchant(button.enchantData.targetSlots) then
            CHAR:ShowMultiSlotHighlight(button.enchantData.targetSlots)
        elseif button.targetSlotID then
            CHAR:ShowSlotHighlight(button.targetSlotID)
        end
        if button.enchantData and button.enchantData.link then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT", 40, 0)
            GameTooltip:SetHyperlink(button.enchantData.link)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(button)
        button._hoverTarget = 0
        GameTooltip:Hide()
        C_Timer.After(0.05, function()
            if IsMouseOverSocketUI() then return end
            CHAR:HideEnchantPopup()
            CHAR:HideSlotHighlight()
        end)
    end)

    btn:SetScript("OnClick", function(button)
        if InCombatLockdown() then
            NRSKNUI:Print("Cannot enchant during combat")
            return
        end
        if button.enchantData then
            UseContainerItem(button.enchantData.bagID, button.enchantData.slotID)
            CHAR:HideEnchantPopup()
            CHAR:HideSlotHighlight()
        end
    end)

    popup.buttons[index] = btn
    return btn
end

function CHAR:FindBestEnchantSlot(targetSlots)
    if not targetSlots or #targetSlots == 0 then return nil end

    for _, slotID in ipairs(targetSlots) do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            return slotID
        end
    end
    return nil
end

function CHAR:ShowEnchantPopup(enchantBtn)
    local popup = self:CreateEnchantPopup()
    local enchants = self:ScanBagsForEnchants()

    local enchantList = {}
    for _, enchantData in pairs(enchants) do
        local targetSlotID = self:FindBestEnchantSlot(enchantData.targetSlots)
        if targetSlotID then
            enchantData.resolvedSlotID = targetSlotID
            tinsert(enchantList, enchantData)
        end
    end

    local minWidth = popup.title:GetStringWidth() + 26
    local minRowHeight = POPUP_ICON_SIZE + ITEM_ROW_PADDING

    local targetHeight
    if #enchantList == 0 then
        popup.noEnchants:Show()
        popup.separator:Hide()
        for _, btn in pairs(popup.buttons) do btn:Hide() end
        popup:SetWidth(max(200, minWidth))
        targetHeight = 50
    else
        popup.noEnchants:Hide()
        popup.separator:Show()

        local yOffset = TITLE_HEIGHT
        for i, enchantData in ipairs(enchantList) do
            local btn = self:CreateEnchantButton_Popup(i)
            btn.enchantData = enchantData
            btn.targetSlotID = enchantData.resolvedSlotID
            btn.icon:SetTexture(enchantData.icon)
            btn.count:SetText(enchantData.count .. "x")
            btn._hoverBg:SetAlpha(0)
            btn._hoverTarget = 0

            local name = GetEnchantName(enchantData.link)
            btn.stats:SetText(name or "")

            local textHeight = btn.stats:GetStringHeight()
            local rowHeight = max(minRowHeight, textHeight + ITEM_ROW_PADDING)

            btn:SetHeight(rowHeight)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", popup, "TOPLEFT", POPUP_PADDING, -yOffset)
            btn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -POPUP_PADDING, -yOffset)
            btn.iconFrame:SetSize(POPUP_ICON_SIZE, POPUP_ICON_SIZE)

            local atlas = GetQualityAtlasFromLink(enchantData.link)
            SetQualityAtlas(btn.quality, atlas)

            btn:Show()
            yOffset = yOffset + rowHeight
        end
        for i = #enchantList + 1, #popup.buttons do popup.buttons[i]:Hide() end

        popup:SetWidth(280)
        targetHeight = yOffset
    end

    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", enchantBtn, "BOTTOMLEFT", 0, -1)
    popup:SetHeight(targetHeight)
    popup:Show()
end

function CHAR:HideEnchantPopup()
    if self.enchantPopup then self.enchantPopup:Hide() end
end

function CHAR:RefreshEnchantButton()
    if not self.db.GemSocketHelper.EnchantHelper then
        if self.enchantButton then self.enchantButton:Hide() end
        return
    end

    local btn = self:CreateEnchantButton()
    local db = self.db.GemSocketHelper

    btn:SetSize(db.SocketButtonSize, db.SocketButtonSize)
    btn:ClearAllPoints()

    local lastSocketBtn = nil
    for i = #self.socketContainer.buttons, 1, -1 do
        if self.socketContainer.buttons[i]:IsShown() then
            lastSocketBtn = self.socketContainer.buttons[i]
            break
        end
    end

    if lastSocketBtn then
        btn:SetPoint("LEFT", lastSocketBtn, "RIGHT", db.SocketButtonSpacing, 0)
    else
        btn:SetPoint("LEFT", self.socketContainer, "LEFT", 0, 0)
    end

    btn:Show()
end
