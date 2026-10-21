---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local _G = _G

-- MerchantItem1..12, the merchant page fills 10 and buyback all 12
local ITEM_SLOTS = 12
local TINT_ALPHA = 0.15
local CELL_PADDING = 3 -- gap between an item's icon and its cell border
local ATLAS_CROP = 0.1 -- share of each repair/junk icon edge that is Blizzard's painted bevel
local EMPTY_ARROW_ALPHA = 0.4
local TEXT_GAP = 4 -- between an item's icon and its name and price
local MERCHANT_ITEMS_PER_PAGE = MERCHANT_ITEMS_PER_PAGE

local ICON_BUTTONS = { 'MerchantRepairItemButton', 'MerchantRepairAllButton', 'MerchantGuildBankRepairButton', 'MerchantSellAllJunkButton' }
local MONEY_FRAMES = { 'MerchantMoneyInset', 'MerchantMoneyBg', 'MerchantExtraCurrencyInset', 'MerchantExtraCurrencyBg' }

-- Item cells --

-- Blizzard warns about an unaffordable or locked item by tinting the name plate we hide, so carry the tint onto the cell
---@param tint Texture
---@param r number
---@param g number
---@param b number
local function SetCellTint(tint, r, g, b)
    if r == 1 and g == 1 and b == 1 then
        tint:Hide()
        return
    end
    tint:SetColorTexture(r, g, b, TINT_ALPHA)
    tint:Show()
end

---@param S SkinningModule
---@param item Frame a MerchantItemTemplate frame or MerchantBuyBackItem
local function SkinItem(S, item)
    local name = item:GetName()
    local nameFrame = _G[name .. 'NameFrame']

    -- the empty slot and the name plate are parchment art
    _G[name .. 'SlotTexture']:SetAlpha(0)
    nameFrame:SetAlpha(0)

    local button = _G[name .. 'ItemButton']
    S:HandleItemButton(button)

    -- the cell wraps the icon with a small margin, the price row is moved up beside the icon to sit inside it;
    -- a backdrop draws 1px inside its frame, which the outset adds on top of the margin
    local backdrop = S:CreatePanelBackdrop(item, 'Transparent')
    if backdrop then
        local outset = CELL_PADDING + 1
        backdrop:ClearAllPoints()
        backdrop:NUISetPixelPoint('TOPLEFT', button, 'TOPLEFT', -outset, outset)
        backdrop:NUISetPixelPoint('TOPRIGHT', item, 'TOPRIGHT', 1, outset)
        backdrop:NUISetPixelPoint('BOTTOM', button, 'BOTTOM', 0, -outset)

        local tint = backdrop:CreateTexture(nil, 'BACKGROUND', nil, 1)
        tint:NUISetPixelInside(backdrop, 1, 1) -- the backdrop's own fill area, under its border
        tint:Hide()
        hooksecurefunc(nameFrame, 'SetVertexColor', function(_, r, g, b) SetCellTint(tint, r, g, b) end)
    end

    -- HandleItemButton clears what it doesn't know, the quest-start marker is the merchant's own
    local quest = button.IconQuestTexture
    if quest then
        quest:SetAlpha(1)
        quest:NUISetPixelInside(button, 1, 1)
    end
end

---@param S SkinningModule
---@param button table? a repair/junk button, its Icon key isn't in the stubs
local function SkinIconButton(S, button)
    if not button then return end

    -- the icon is a region of a shared sheet; read that region as drawn, HandleItemButton's zoom
    -- texcoords would otherwise index the whole sheet
    local icon = button.Icon
    local left, top, _, bottom, right = icon:GetTexCoord()

    -- styled like the item slots above, HandleItemButton keeps the Icon and clears the slot art
    S:HandleItemButton(button)

    -- crop Blizzard's painted bevel off inside that region
    local x, y = (right - left) * ATLAS_CROP, (bottom - top) * ATLAS_CROP
    icon:SetTexCoord(left + x, right - x, top + y, bottom - y)
end

-- an item costing only a currency gets it re-anchored under the name plate on every update; next to gold
-- Blizzard's own LEFT-of-money anchor already follows the moved money frame
local function PlaceAltCurrency()
    for index = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G['MerchantItem' .. index .. 'ItemButton']
        if button.extendedCost and not button.price then
            local currency = _G['MerchantItem' .. index .. 'AltCurrencyFrame']
            currency:ClearAllPoints()
            currency:NUISetPixelPoint('BOTTOMLEFT', button, 'BOTTOMRIGHT', TEXT_GAP, 0)
        end
    end
end

-- Blizzard desaturates the undo arrow only while there's nothing to buy back; keep it grey to fit the skin
-- and carry that state as alpha instead
local applyingArrow = false

---@param arrow Texture
---@param empty boolean?
local function StyleUndoArrow(arrow, empty)
    if applyingArrow then return end

    applyingArrow = true
    arrow:SetDesaturated(true)
    applyingArrow = false
    arrow:SetAlpha(empty and EMPTY_ARROW_ALPHA or 1)
end

-- HandleButton centres every FontString as button text, but these labels sit beside their arrows
---@param S SkinningModule
---@param button Button
---@param isPrev boolean
local function SkinPageButton(S, button, isPrev)
    -- the arrow's texture mode points 90 degrees off its names, 'up' draws left and 'down' draws right
    S:HandleNextPrevButton(button, isPrev and 'up' or 'down')

    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType('FontString') then
            region:ClearAllPoints()
            if isPrev then
                region:NUISetPixelPoint('LEFT', button, 'RIGHT', 3, 0)
            else
                region:NUISetPixelPoint('RIGHT', button, 'LEFT', -3, 0)
            end
            S:HandleAccentFont(region)
        end
    end
end

-- Skin --

Skinning:RegisterSkin('Blizzard_UIPanels_Game', 'MerchantFrame', function(S)
    local frame = _G.MerchantFrame
    if not frame then return end

    S:HandlePortraitFrame(frame)
    S:HandleAccentFont(frame.TitleContainer and frame.TitleContainer.TitleText)
    S:HandleAccentFont(_G.MerchantPageText)

    -- shown and hidden per tab, alpha holds through that
    _G.BuybackBG:SetAlpha(0)
    _G.MerchantFrameBottomLeftBorder:SetAlpha(0)

    for index = 1, ITEM_SLOTS do
        local item = _G['MerchantItem' .. index]
        local button = _G['MerchantItem' .. index .. 'ItemButton']
        SkinItem(S, item)

        -- the price moves up beside the icon's bottom, so the name hangs from its top instead of centring
        -- into it; neither is re-anchored by Blizzard after load
        item.Name:ClearAllPoints()
        item.Name:NUISetPixelPoint('TOPLEFT', button, 'TOPRIGHT', TEXT_GAP, 0)
        item.Name:SetJustifyV('TOP')

        local money = _G['MerchantItem' .. index .. 'MoneyFrame']
        money:ClearAllPoints()
        money:NUISetPixelPoint('BOTTOMLEFT', button, 'BOTTOMRIGHT', TEXT_GAP, 0)
    end
    hooksecurefunc('MerchantFrame_UpdateMerchantInfo', PlaceAltCurrency)
    SkinItem(S, _G.MerchantBuyBackItem)

    local arrow = _G.MerchantBuyBackItemItemButton.UndoFrame.Arrow
    hooksecurefunc(arrow, 'SetDesaturated', StyleUndoArrow)
    StyleUndoArrow(arrow, arrow:IsDesaturated())

    for _, name in ipairs(ICON_BUTTONS) do
        SkinIconButton(S, _G[name])
    end

    for _, name in ipairs(MONEY_FRAMES) do
        _G[name]:NUIStripTextures('Keyed')
    end
    S:CreatePanelBackdrop(_G.MerchantMoneyBg, 'Transparent')
    S:CreatePanelBackdrop(_G.MerchantExtraCurrencyBg, 'Transparent')

    SkinPageButton(S, _G.MerchantPrevPageButton, true)
    SkinPageButton(S, _G.MerchantNextPageButton, false)
    S:HandleDropdownButton(frame.FilterDropdown)
    S:HandleTabRow('MerchantFrameTab', frame, true)
end)
