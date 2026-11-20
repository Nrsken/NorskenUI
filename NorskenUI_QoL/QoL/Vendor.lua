---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class VendorModule
local Vendor = NRSKNUI:GetModule('Vendor')
function Vendor:UpdateDB() self.db = self.namespace.profile end

local L = NRSKNUI.Libs.AL

local SetItemButtonNormalTextureVertexColor = SetItemButtonNormalTextureVertexColor
local SetItemButtonNameFrameVertexColor = SetItemButtonNameFrameVertexColor
local MerchantFrameItem_UpdateQuality = MerchantFrameItem_UpdateQuality
local SetItemButtonTextureVertexColor = SetItemButtonTextureVertexColor
local StackSplitCancelButton_OnClick = StackSplitCancelButton_OnClick
local MoneyFrame_SetMaxDisplayWidth = MoneyFrame_SetMaxDisplayWidth
local SetItemButtonSlotVertexColor = SetItemButtonSlotVertexColor
local SetItemButtonDesaturated = SetItemButtonDesaturated
local AltCurrencyFrame_Update = AltCurrencyFrame_Update
local GetMerchantItemCostInfo = GetMerchantItemCostInfo
local GetMerchantItemCostItem = GetMerchantItemCostItem
local CanAffordMerchantItem = CanAffordMerchantItem
local SetItemButtonTexture = SetItemButtonTexture
local GetMerchantItemLink = GetMerchantItemLink
local GetMerchantNumItems = GetMerchantNumItems
local SetItemButtonCount = SetItemButtonCount
local SetItemButtonStock = SetItemButtonStock
local SetMoneyFrameColor = SetMoneyFrameColor
local GetMerchantItemID = GetMerchantItemID
local MoneyFrame_Update = MoneyFrame_Update
local hooksecurefunc = hooksecurefunc
local MenuResponse = MenuResponse
local PlayerHasToy = PlayerHasToy
local CreateFrame = CreateFrame
local strfind = string.find
local wipe = table.wipe
local ceil = math.ceil
local ipairs = ipairs
local select = select
local unpack = unpack
local max = math.max
local pairs = pairs
local _G = _G

local PlayerHasTransmogByItemInfo = C_TransmogCollection.PlayerHasTransmogByItemInfo
local IsMerchantItemRefundable = C_MerchantFrame.IsMerchantItemRefundable
local GetSetPrimaryAppearances = C_TransmogSets.GetSetPrimaryAppearances
local GetItemLearnTransmogSet = C_Item.GetItemLearnTransmogSet
local RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID
local GetNumCollectedInfo = C_PetJournal.GetNumCollectedInfo
local GetPetInfoByItemID = C_PetJournal.GetPetInfoByItemID
local GetMerchantTooltip = C_TooltipInfo.GetMerchantItem
local GetMountFromItem = C_MountJournal.GetMountFromItem
local GetMountInfoByID = C_MountJournal.GetMountInfoByID
local IsItemDataCachedByID = C_Item.IsItemDataCachedByID
local GetMerchantItemInfo = C_MerchantFrame.GetItemInfo
local PlayerHasHeirloom = C_Heirloom.PlayerHasHeirloom
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local IsItemHeirloom = C_Heirloom.IsItemHeirloom
local IsCosmeticItem = C_Item.IsCosmeticItem
local GetToyInfo = C_ToyBox.GetToyInfo

local GetCurrencyContainerInfo = CurrencyContainerUtil.GetCurrencyContainerInfo

local USAGE_REQUIREMENT = Enum.TooltipDataLineType.UsageRequirement
local MiscSubclass = Enum.ItemMiscellaneousSubclass
local ArmorSubclass = Enum.ItemArmorSubclass
local ItemClass = Enum.ItemClass

local MERCHANT_ITEMS_PER_PAGE = MERCHANT_ITEMS_PER_PAGE
local TEXTURE_ITEM_QUEST_BANG = TEXTURE_ITEM_QUEST_BANG
local BUYBACK_ITEMS_PER_PAGE = BUYBACK_ITEMS_PER_PAGE
local MERCHANT_PAGE_NUMBER = MERCHANT_PAGE_NUMBER
local ITEM_SPELL_KNOWN = ITEM_SPELL_KNOWN
local ITEM_MIN_SKILL = ITEM_MIN_SKILL
local MAX_ITEM_COST = MAX_ITEM_COST
local UNCHECK_ALL = UNCHECK_ALL
local CHECK_ALL = CHECK_ALL

local slots = {} ---@type MerchantItemTemplate[]
local filterButton ---@type DropdownButton?
local expandButton ---@type MaximizeMinimizeButtonFrameTemplate?
local refillFrame ---@type Frame?
local baseWidth ---@type number? Blizzards own width, read before we first change it

---@param db NRSKNUI.DBProfile.Miscellaneous.Vendor
---@return boolean
local function IsDefault(db)
    if db.HideCollected then return false end

    for _, hidden in pairs(db.Hidden) do
        if hidden then return false end
    end
    return true
end

-- Classify --

local TABARD_SLOT = 'INVTYPE_TABARD'

-- Requires <skill> (25) in any language, markers let a reordered %1$s survive the escape
local SKILL_PATTERN = '^' .. ITEM_MIN_SKILL:gsub('%%%d*%$?s', '\001'):gsub('%%%d*%$?d', '\002'):gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%0'):gsub('\001', '.+'):gsub('\002', '%%d+') .. '$'

local CLASS_CATEGORY = {
    [ItemClass.Housing] = 'Housing',
    [ItemClass.Battlepet] = 'Pets',
    [ItemClass.Recipe] = 'Recipes',
    [ItemClass.Consumable] = 'Consumables',
    [ItemClass.Weapon] = 'Gear',
    [ItemClass.Armor] = 'Gear',
}

local MISC_CATEGORY = {
    [MiscSubclass.Mount] = 'Mounts',
    [MiscSubclass.CompanionPet] = 'Pets',
}

-- Profession books and known recipes only show as a requirement line on the tooltip
---@param index number
---@param pattern string
---@param plain boolean?
---@return boolean
local function HasRequirementLine(index, pattern, plain)
    local data = GetMerchantTooltip(index)
    if not data then return false end

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if line.type == USAGE_REQUIREMENT and text and strfind(text, pattern, 1, plain) then
            return true
        end
    end
    return false
end

-- Held back until its data loads, so an owned one never flashes in first
---@param itemID number
---@return boolean
local function IsHeldBack(itemID)
    if IsItemDataCachedByID(itemID) then return false end

    RequestLoadItemDataByID(itemID)
    return true
end

-- Toys and ensembles come as consumables or misc, so they're asked for before the class
-- Nil while a weapon or armor piece hasn't loaded, as it might still turn out cosmetic
---@param index number
---@param itemID number?
---@return string?
local function GetCategory(index, itemID)
    if not itemID then
        return 'Other'
    end
    if GetToyInfo(itemID) then
        return 'Toys'
    end
    if GetItemLearnTransmogSet(itemID) then
        return 'Transmog'
    end

    local _, _, _, itemEquipLoc, _, classID, subclassID = GetItemInfoInstant(itemID)
    if itemEquipLoc == TABARD_SLOT then
        return 'Tabards'
    end
    if classID == ItemClass.Armor and subclassID == ArmorSubclass.Cosmetic then
        return 'Transmog'
    end

    -- Cosmetic weapons keep their weapon class, so only the game can tell them from gear
    if classID == ItemClass.Weapon or classID == ItemClass.Armor then
        if IsHeldBack(itemID) then return nil end

        if IsCosmeticItem(itemID) then
            return 'Transmog'
        end
    end
    if classID == ItemClass.Miscellaneous then
        if subclassID == MiscSubclass.Other and HasRequirementLine(index, SKILL_PATTERN) then
            return 'Profession'
        end
        return MISC_CATEGORY[subclassID] or 'Other'
    end
    return CLASS_CATEGORY[classID] or 'Other'
end

-- An ensemble counts once every piece is owned, as buying it still teaches the missing ones
---@param setID number
---@return boolean
local function IsSetCollected(setID)
    local appearances = GetSetPrimaryAppearances(setID)
    if not appearances then return false end

    for _, appearance in ipairs(appearances) do
        if not appearance.collected then return false end
    end
    return #appearances > 0
end

-- Owned looks only count for cosmetics, a piece of gear is still worth seeing for its stats
---@param index number
---@param itemID number
---@param category string
---@return boolean
local function IsCollected(index, itemID, category)
    if category == 'Recipes' then
        return IsHeldBack(itemID) or HasRequirementLine(index, ITEM_SPELL_KNOWN, true)
    end
    if category == 'Transmog' or category == 'Tabards' then
        local setID = GetItemLearnTransmogSet(itemID)
        if setID then
            return IsSetCollected(setID)
        end
        return PlayerHasTransmogByItemInfo(itemID)
    end
    if PlayerHasHeirloom(itemID) or PlayerHasToy(itemID) then return true end

    local mountID = GetMountFromItem(itemID)
    if mountID then
        return (select(11, GetMountInfoByID(mountID)))
    end

    local speciesID = select(13, GetPetInfoByItemID(itemID))
    if speciesID then
        return GetNumCollectedInfo(speciesID) > 0
    end

    return (category == 'Mounts' or category == 'Pets') and IsHeldBack(itemID)
end

-- Fill --

-- Sourced from MAX_MONEY_DISPLAY_WIDTH in Blizzard's MerchantFrame.lua
local MAX_MONEY_WIDTH = 120

-- Name plate, slot and icon colors, sourced from MerchantFrame_UpdateMerchantInfo
local TINT_SOLD_OUT_LOCKED = { { 0.5, 0, 0 }, { 0.5, 0, 0 }, { 0.5, 0, 0 } }
local TINT_SOLD_OUT = { { 0.5, 0.5, 0.5 }, { 0.5, 0.5, 0.5 }, { 0.5, 0.5, 0.5 } }
local TINT_LOCKED = { { 1, 0, 0 }, { 1, 0, 0 }, { 0.9, 0, 0 } }
local TINT_NORMAL = { { 0.5, 0.5, 0.5 }, { 1, 1, 1 }, { 1, 1, 1 } }

-- Copied from MerchantFrame_UpdateAltCurrency, which only finds slots named MerchantItem<n>
---@param item MerchantItemTemplate
---@param index number
---@param canAfford boolean?
---@return number
local function UpdateAltCurrency(item, index, canAfford)
    local frameName = item:GetName() .. 'AltCurrencyFrame'
    local used = 0
    local width = 0
    if GetMerchantItemCostInfo(index) > 0 then
        for cost = 1, MAX_ITEM_COST do
            local texture, value, link = GetMerchantItemCostItem(index, cost)
            if texture then
                used = used + 1
                local button = _G[frameName .. 'Item' .. used]
                button.index = index
                button.item = cost
                button.itemLink = link
                AltCurrencyFrame_Update(frameName .. 'Item' .. used, texture, value, canAfford)
                width = width + button:GetWidth()
                if used > 1 then
                    width = width + 4
                end
                button:Show()
            end
        end
    end
    for cost = used + 1, MAX_ITEM_COST do
        _G[frameName .. 'Item' .. cost]:Hide()
    end
    return width
end

-- Copied from MerchantFrame_UpdateMerchantInfo in Blizzard's MerchantFrame.lua
-- The slot shows merchant item index rather than its own place on the page
---@param item MerchantItemTemplate
---@param index number?
local function FillSlot(item, index)
    local prefix = item:GetName()
    local button = item.ItemButton
    local money = _G[prefix .. 'MoneyFrame']
    local altCurrency = _G[prefix .. 'AltCurrencyFrame']
    local info = index and GetMerchantItemInfo(index)
    if not info then
        button.price = nil
        button.hasItem = nil
        button.name = nil
        button:Hide()
        SetItemButtonNameFrameVertexColor(item, 0.5, 0.5, 0.5)
        SetItemButtonSlotVertexColor(item, 0.4, 0.4, 0.4)
        item.Name:SetText('')
        money:Hide()
        altCurrency:Hide()
        return
    end

    if info.currencyID then
        info.name, info.texture, info.numAvailable = GetCurrencyContainerInfo(info.currencyID, info.numAvailable, info.name, info.texture, nil)
    end

    local canAfford = CanAffordMerchantItem(index)
    local link = GetMerchantItemLink(index)
    item.Name:SetText(info.name)
    SetItemButtonCount(button, info.stackCount)
    SetItemButtonStock(button, info.numAvailable)
    SetItemButtonTexture(button, info.texture)
    button.name = info.name
    button.link = link
    button.texture = info.texture

    -- Price row, a currency alone sits under the name and next to gold it follows the money
    if info.hasExtendedCost and info.price <= 0 then
        button.price = nil
        button.extendedCost = true
        UpdateAltCurrency(item, index, canAfford)
        altCurrency:ClearAllPoints()
        altCurrency:SetPoint('BOTTOMLEFT', prefix .. 'NameFrame', 'BOTTOMLEFT', 0, 31)
        money:Hide()
        altCurrency:Show()
    else
        local width = MAX_MONEY_WIDTH
        button.price = info.price
        if info.hasExtendedCost then
            button.extendedCost = true
            width = width - UpdateAltCurrency(item, index, canAfford)
            altCurrency:ClearAllPoints()
            altCurrency:SetPoint('LEFT', money:GetName(), 'RIGHT', -14, 0)
            altCurrency:Show()
        else
            button.extendedCost = nil
            altCurrency:Hide()
        end
        MoneyFrame_SetMaxDisplayWidth(money, width)
        MoneyFrame_Update(money:GetName(), info.price)
        SetMoneyFrameColor(money:GetName(), canAfford == false and 'gray' or nil)
        money:Show()
    end

    if info.isQuestStartItem then
        button.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
        button.IconQuestTexture:Show()
    else
        button.IconQuestTexture:Hide()
    end
    MerchantFrameItem_UpdateQuality(item, link)

    local itemID = GetMerchantItemID(index)
    local isHeirloom = itemID and IsItemHeirloom(itemID)
    local isKnownHeirloom = isHeirloom and PlayerHasHeirloom(itemID)
    button.showNonrefundablePrompt = not IsMerchantItemRefundable(index)
    button.hasItem = true
    button:SetID(index)
    button:Show()
    SetItemButtonDesaturated(button, isKnownHeirloom)

    local locked = not info.isPurchasable or (not info.isUsable and not isHeirloom)
    local tint = TINT_NORMAL
    if info.numAvailable == 0 or isKnownHeirloom then
        tint = locked and TINT_SOLD_OUT_LOCKED or TINT_SOLD_OUT
    elseif locked then
        tint = TINT_LOCKED
    end

    SetItemButtonNameFrameVertexColor(item, unpack(tint[1]))
    SetItemButtonSlotVertexColor(item, unpack(tint[2]))
    SetItemButtonTextureVertexColor(button, unpack(tint[3]))
    SetItemButtonNormalTextureVertexColor(button, unpack(tint[3]))
end

-- Layout --

-- Slot spacing, block width and the Next and buyback anchors, sourced from MerchantFrame.xml
local SLOT_GAP = 12
local ROW_GAP = 8
local BLOCK_WIDTH = 330
local NEXT_PAGE_X = 310
local PAGE_BUTTON_Y = 96
local BUYBACK_ITEM_X = 30
local BUYBACK_ITEM_Y = -53

-- Sourced from MerchantFrame_UpdateBuybackInfo
local BUYBACK_ROW_GAP = 15

---@param blocks number blocks of ten across, 1 is Blizzard's own width
---@param buyback boolean? Blizzard's twelve buyback slots spread across that width instead
local function ApplyLayout(blocks, buyback)
    local count = buyback and 0 or blocks * MERCHANT_ITEMS_PER_PAGE

    -- Extra blocks of ten sit right of Blizzard's, laid out as MerchantFrame.xml lays its own
    for slot = #slots + 1, count do
        local item = CreateFrame('Frame', 'NRSKNUI_VendorItem' .. slot, MerchantFrame, 'MerchantItemTemplate')
        local place = (slot - 1) % MERCHANT_ITEMS_PER_PAGE + 1
        if place == 1 then
            item:NCSetPoint('TOPLEFT', slots[slot - MERCHANT_ITEMS_PER_PAGE + 1], 'TOPRIGHT', SLOT_GAP, 0)
        elseif place % 2 == 0 then
            item:NCSetPoint('TOPLEFT', slots[slot - 1], 'TOPRIGHT', SLOT_GAP, 0)
        else
            item:NCSetPoint('TOPLEFT', slots[slot - 2], 'BOTTOMLEFT', 0, -ROW_GAP)
        end
        if MerchantFrame.NUISkinned then
            NRSKNUI.Skinning:SkinMerchantSlot(item)
        end
        slots[slot] = item
    end

    -- Next and the last buyback move out with the width, as the repair row does
    local extraWidth = (blocks - 1) * BLOCK_WIDTH
    MerchantFrame:NCSetWidth(baseWidth + extraWidth)
    MerchantNextPageButton:ClearAllPoints()
    MerchantNextPageButton:NCSetPoint('CENTER', MerchantFrame, 'BOTTOMLEFT', NEXT_PAGE_X + extraWidth, PAGE_BUTTON_Y)
    MerchantBuyBackItem:ClearAllPoints()
    MerchantBuyBackItem:NCSetPoint('TOPLEFT', MerchantItem10, 'BOTTOMLEFT', BUYBACK_ITEM_X + extraWidth, BUYBACK_ITEM_Y)
    for slot = MERCHANT_ITEMS_PER_PAGE + 1, #slots do
        slots[slot]:SetShown(slot <= count)
    end

    -- Blizzard's slots in rows as wide as the page, all of them as it only resets the odd ones
    local columns = buyback and blocks * 2 or 2
    local rowGap = buyback and BUYBACK_ROW_GAP or ROW_GAP
    for slot = 2, BUYBACK_ITEMS_PER_PAGE do
        local item = _G['MerchantItem' .. slot]
        item:ClearAllPoints()
        if (slot - 1) % columns == 0 then
            item:NCSetPoint('TOPLEFT', _G['MerchantItem' .. (slot - columns)], 'BOTTOMLEFT', 0, -rowGap)
        else
            item:NCSetPoint('TOPLEFT', _G['MerchantItem' .. (slot - 1)], 'TOPRIGHT', SLOT_GAP, 0)
        end
    end
end

-- Blizzard places these for its own width, so they're kept at that spot from one edge
---@param region Frame
---@param edge 'BOTTOMLEFT'|'BOTTOMRIGHT'
local function PinToEdge(region, edge)
    local point, relativeTo, relativePoint, x, y = region:GetPoint()
    if relativeTo ~= MerchantFrame or relativePoint == edge then return end

    local shift = edge == 'BOTTOMLEFT' and baseWidth or -baseWidth
    region:ClearAllPoints()
    region:NCSetPoint(point, MerchantFrame, edge, x + shift, y)
end

-- Gold sits in the left box only when the vendor takes currencies, which fill the right box
-- Repair moves out with the right edge, sell junk and guild repair hang off it or already do
local function PinBottomRow()
    if not baseWidth then return end

    if MerchantExtraCurrencyInset:IsShown() then
        PinToEdge(MerchantMoneyFrame, 'BOTTOMLEFT')
    end
    PinToEdge(MerchantRepairAllButton, 'BOTTOMRIGHT')
end

-- Refill --

local shown = {} ---@type number[]

---@param showAll boolean? every item on Blizzard's ten slots, for putting its page back
function Vendor:Refill(showAll)
    local blocks = 1
    if self.db.Expanded and not showAll then
        blocks = self.db.Blocks
    end
    ApplyLayout(blocks)
    local count = blocks * MERCHANT_ITEMS_PER_PAGE

    wipe(shown)
    for index = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(index)
        local category = GetCategory(index, itemID)
        local hidden = not category or self.db.Hidden[category]
            or (self.db.HideCollected and itemID and IsCollected(index, itemID, category))
        if showAll or not hidden then
            shown[#shown + 1] = index
        end
    end

    -- Hiding late loaders can leave the page past the end
    local frame = MerchantFrame
    local pages = max(ceil(#shown / count), 1)
    if frame.page > pages then
        frame.page = pages
    end

    -- Blizzard only closes the split window for its own slots on its own page turns
    local splitOwner = StackSplitFrame:IsShown() and StackSplitFrame.owner
    local splitID = splitOwner and splitOwner:GetID()
    local offset = (frame.page - 1) * count
    for slot = 1, count do
        FillSlot(slots[slot], shown[offset + slot])
    end
    if splitOwner and splitOwner:GetID() ~= splitID then
        StackSplitCancelButton_OnClick()
    end

    local paged = #shown > count
    MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, frame.page, pages)
    MerchantPageText:SetShown(paged)
    MerchantPrevPageButton:SetShown(paged)
    MerchantNextPageButton:SetShown(paged)
    MerchantPrevPageButton:SetEnabled(frame.page > 1)
    MerchantNextPageButton:SetEnabled(frame.page < pages)

    -- The skin placed a currency-only price on Blizzard's update, before our fill moved it
    if frame.NUISkinned then
        NRSKNUI.Skinning.PlaceMerchantAltCurrency()
    end
end

-- Defined with the controls, the update can reach them before MERCHANT_SHOW does
local CreateControls

local function OnMerchantUpdate()
    if not Vendor:IsEnabled() or (IsDefault(Vendor.db) and not Vendor.db.Expanded) then return end
    if not MerchantFrame:IsShown() or MerchantFrame.selectedTab ~= 1 then return end

    if not filterButton then
        CreateControls()
    end
    Vendor:Refill()
end

-- Buyback takes the same width as the merchant page, its twelve slots spread across it
local function OnBuybackUpdate()
    if not baseWidth then return end

    ApplyLayout(Vendor:IsEnabled() and Vendor.db.Expanded and Vendor.db.Blocks or 1, true)
end

-- Filter menu --

local BUTTON_GAP = 6

-- Menu order
local CATEGORIES = {
    'Housing', 'Mounts', 'Pets', 'Toys', 'Transmog',
    'Tabards', 'Recipes', 'Profession',
    'Consumables', 'Gear', 'Other',
}

---@param category string
---@return boolean
local function IsCategoryShown(category)
    return not Vendor.db.Hidden[category]
end

---@return boolean
local function IsHidingCollected()
    return Vendor.db.HideCollected
end

function Vendor:ApplyFilters()
    -- A new filter starts on the first page, as Blizzard's own filter does
    MerchantFrame.page = 1
    if not MerchantFrame:IsShown() then return end

    if MerchantFrame.selectedTab == 1 then
        self:Refill()
    else
        OnBuybackUpdate()
    end
end

---@param category string
local function ToggleCategory(category)
    local hidden = Vendor.db.Hidden
    hidden[category] = not hidden[category]
    Vendor:ApplyFilters()
end

local function ToggleCollected()
    Vendor.db.HideCollected = not Vendor.db.HideCollected
    Vendor:ApplyFilters()
end

-- Walks the category list, pairs on the saved table skips categories at their default
---@param categoryShown boolean
---@return MenuResponse
local function SetAllCategories(categoryShown)
    local hidden = Vendor.db.Hidden
    for _, category in ipairs(CATEGORIES) do
        hidden[category] = not categoryShown
    end
    Vendor:ApplyFilters()

    return MenuResponse.Refresh
end

local function ResetFilters()
    Vendor.db.HideCollected = false
    SetAllCategories(true)
end

---@param root RootMenuDescriptionProxy
local function BuildMenu(_, root)
    root:CreateTitle(L['Show'])
    root:CreateButton(CHECK_ALL, SetAllCategories, true)
    root:CreateButton(UNCHECK_ALL, SetAllCategories, false)
    for _, category in ipairs(CATEGORIES) do
        root:CreateCheckbox(L[category], IsCategoryShown, ToggleCategory, category)
    end
    root:CreateDivider()
    root:CreateCheckbox(L['Hide Collected'], IsHidingCollected, ToggleCollected)
end

local function IsFilterDefault()
    return IsDefault(Vendor.db)
end

---@param expanded boolean
local function SetExpanded(expanded)
    Vendor.db.Expanded = expanded
    Vendor:ApplyFilters()
end

function CreateControls()
    local frame = MerchantFrame
    baseWidth = frame:GetWidth()
    for slot = 1, MERCHANT_ITEMS_PER_PAGE do
        slots[slot] = _G['MerchantItem' .. slot]
    end

    -- Blizzard placed the bottom row before there was a width to pin it to
    PinBottomRow()

    local button = CreateFrame('DropdownButton', nil, frame, 'WowStyle1FilterDropdownTemplate')
    button:NCSetPoint('RIGHT', frame.FilterDropdown, 'LEFT', -BUTTON_GAP, 0)
    button:SetupMenu(BuildMenu)
    button:SetDefaultCallback(ResetFilters)
    button:SetIsDefaultCallback(IsFilterDefault)
    filterButton = button

    -- The Spellbook's expand button, left of the close button as PlayerSpellsFrame places it
    local minMax = CreateFrame('Frame', nil, frame, 'MaximizeMinimizeButtonFrameTemplate')
    minMax:SetOnMaximizedCallback(function() SetExpanded(true) end)
    minMax:SetOnMinimizedCallback(function() SetExpanded(false) end)
    expandButton = minMax

    -- Match the merchant window when its skin ran
    if frame.NUISkinned then
        NRSKNUI.Skinning:HandleButton(button)
        NRSKNUI.Skinning:HandleCloseButton(button.ResetButton, button, 8, 8, 14)
        NRSKNUI.Skinning:PlaceMinMaxButton(minMax, frame.CloseButton, 'TOPLEFT')
    else
        minMax:NCSetPoint('RIGHT', frame.CloseButton, 'LEFT', 0, 0)
    end

    -- One refill per frame however many items load at once
    refillFrame = CreateFrame('Frame')
    refillFrame:NCSetScheduledUpdate(OnMerchantUpdate)
end

-- Events --

-- Shows the saved state without firing the callback, a profile change can flip it
local function ShowSavedExpanded()
    if Vendor.db.Expanded then
        expandButton:Maximize(true, true)
    else
        expandButton:Minimize(true, true)
    end
end

function Vendor:MERCHANT_SHOW()
    if not filterButton then
        CreateControls()
    end
    ShowSavedExpanded()
    self:RegisterEvent('GET_ITEM_INFO_RECEIVED')
end

-- Back to Blizzard's ten so no extra slot opens the next vendor holding this one's items
function Vendor:MERCHANT_CLOSED()
    self:UnregisterEvent('GET_ITEM_INFO_RECEIVED')
    if baseWidth then
        ApplyLayout(1)
    end
end

-- Mounts and pets only know they're collected once their item loads
-- Blizzard also repaints quality borders by unfiltered index on each load
function Vendor:GET_ITEM_INFO_RECEIVED()
    refillFrame:NCScheduleUpdate()
end

-- Module --

local hooked = false

-- Filters and page size both live on the open merchant page, so every part refills it
---@param part NorskenCore.Apply
function Vendor:ApplySettings(part)
    if not self:IsEnabled() or not MerchantFrame:IsShown() then return end

    if filterButton then
        ShowSavedExpanded()
    end
    self:ApplyFilters()
end

function Vendor:OnEnable()
    if not hooked then
        hooked = true
        hooksecurefunc('MerchantFrame_UpdateMerchantInfo', OnMerchantUpdate)
        hooksecurefunc('MerchantFrame_UpdateBuybackInfo', OnBuybackUpdate)
        hooksecurefunc('MerchantFrame_UpdateCurrencies', PinBottomRow)
        hooksecurefunc('MerchantFrame_UpdateRepairButtons', PinBottomRow)
    end
    if filterButton then
        filterButton:Show()
        expandButton:Show()
    end
    self:RegisterEvent('MERCHANT_SHOW')
    self:RegisterEvent('MERCHANT_CLOSED')

    -- Turned on from the settings with a merchant already open
    if MerchantFrame:IsShown() then
        self:MERCHANT_SHOW()
        OnMerchantUpdate()
    end
end

function Vendor:OnDisable()
    if filterButton then
        filterButton:Hide()
        expandButton:Hide()
        ApplyLayout(1, MerchantFrame.selectedTab ~= 1)
    end

    if MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 and (self.db.Expanded or not IsDefault(self.db)) then
        self:Refill(true)
    end
end
