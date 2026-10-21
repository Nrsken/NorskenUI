---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class MissingBuffsModule
local MissingBuffs = NRSKNUI:GetModule('MissingBuffs')

local ipairs = ipairs
local tostring = tostring
local format = string.format
local tinsert = table.insert
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver

local GetItemCount = C_Item and C_Item.GetItemCount
local GetItemIconByID = C_Item and C_Item.GetItemIconByID

local GameTooltip = GameTooltip

local SPACING = 1
local PADDING = 0
local MACRO_ITEM = '/use item:%d'
local USE_MAINHAND = '\n/use 16'
local USE_OFFHAND = '\n/use 17'
local DIRECTIONS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local BACKDROP_NAME = 'NRSKNUI_MissingBuffsFlyout'

MissingBuffs.flyoutButtons = {} ---@type MissingBuffs.FlyoutButton[]

---@param button MissingBuffs.FlyoutButton
local function OnFlyoutPostClick(button)
    if InCombatLockdown() then return end
    MissingBuffs:RememberItem(button.itemList, button.itemID)
    MissingBuffs:CloseFlyout()
    MissingBuffs:RequestUpdate()
end

---@param button MissingBuffs.FlyoutButton
local function OnFlyoutEnter(button)
    GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
    GameTooltip:SetItemByID(button.itemID)
    GameTooltip:Show()
end

---@return Frame
function MissingBuffs:GetFlyoutBackdrop()
    if self.flyoutBackdrop then return self.flyoutBackdrop end

    -- Only a backdrop behind the buttons, never their parent or anchor, so it stays unprotected.
    local backdrop = CreateFrame('Frame', BACKDROP_NAME, UIParent)
    backdrop:NUICreateBackdrop(true)
    backdrop:SetBackgroundColor(0, 0, 0, 0)
    backdrop:SetScript('OnHide', function() self:CloseFlyout() end)
    backdrop:Hide()
    tinsert(UISpecialFrames, BACKDROP_NAME)

    self.flyoutBackdrop = backdrop
    return backdrop
end

---@param index number
---@return MissingBuffs.FlyoutButton
function MissingBuffs:GetFlyoutButton(index)
    local button = self.flyoutButtons[index]
    if button then return button end

    button = CreateFrame('Button', nil, UIParent, 'SecureActionButtonTemplate') --[[@as MissingBuffs.FlyoutButton]]
    button:RegisterForClicks('AnyUp', 'AnyDown')
    button:SetAttribute('type', 'macro')
    button:NUIAddBorders()
    button.texture = button:CreateTexture(nil, 'BACKGROUND')
    button.count = button:CreateFontString(nil, 'OVERLAY')
    button:NUIStyleButton()
    button:SetScript('PostClick', OnFlyoutPostClick)
    button:SetScript('OnEnter', OnFlyoutEnter)
    button:SetScript('OnLeave', GameTooltip_Hide)
    button:Hide()

    self.flyoutButtons[index] = button
    return button
end

---@param key string
function MissingBuffs:ToggleFlyout(key)
    if InCombatLockdown() then return end
    local reopen = self.flyoutKey ~= key
    self:CloseFlyout()
    if not reopen then return end

    local result, icon = self.shown[key], self.icons[key]
    if not result or not icon or not icon:IsVisible() then return end

    local entry = result.entry
    local items = self:CollectBagItems(entry)
    if #items == 0 then return end

    local db = self.db.Groups[icon.groupName]
    local scale = icon:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local size = icon:GetWidth() * scale
    local left, bottom = icon:GetLeft() * scale, icon:GetBottom() * scale
    local direction = DIRECTIONS[self.db.FlyoutDirection]
    local dx, dy = direction[1], direction[2]
    local step = size + SPACING
    local border = NRSKNUI:GetBorderColor(db)

    for index, itemID in ipairs(items) do
        local button = self:GetFlyoutButton(index)
        local offset = (index - 1) * step + size + SPACING + PADDING

        local macro = format(MACRO_ITEM, itemID)
        if entry.useWeapon then macro = macro .. (entry.enchantSlot == 'offhand' and USE_OFFHAND or USE_MAINHAND) end
        button:SetAttribute('macrotext', macro)
        button.itemID = itemID
        button.itemList = entry.itemList

        button:ClearAllPoints()
        button:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', left + dx * offset, bottom + dy * offset)
        button:SetSize(size, size)
        button:SetFrameStrata('DIALOG')
        button:SetFrameLevel(10)
        button:SetBorderColor(border[1], border[2], border[3], border[4])
        button.texture:SetTexture(GetItemIconByID(itemID))
        button.texture:NUISetPixelInside(button, 1, 1)
        button.texture:NUISetZoom()
        button.count:SetFontStyle(db)
        button.count:SetFontJustify('BOTTOMRIGHT', button, -2, 2)
        button.count:SetText(tostring(GetItemCount(itemID, false, true)))

        RegisterStateDriver(button, 'visibility', '[combat] hide; show')
        button:Show()
    end
    self.flyoutCount = #items

    local length = #items * step - SPACING + PADDING * 2
    local along = (dx + dy > 0) and size + SPACING or -(SPACING + length)
    local thickness = size + PADDING * 2
    local backdrop = self:GetFlyoutBackdrop()
    backdrop:ClearAllPoints()
    if dx == 0 then
        backdrop:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', left - PADDING, bottom + along)
        backdrop:SetSize(thickness, length)
    else
        backdrop:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', left + along, bottom - PADDING)
        backdrop:SetSize(length, thickness)
    end
    backdrop:SetFrameStrata('DIALOG')
    backdrop:SetFrameLevel(1)
    backdrop:Show()

    self.flyoutKey = key
    self:RegisterEvent('GLOBAL_MOUSE_DOWN', 'OnFlyoutMouseDown')
end

function MissingBuffs:HideFlyoutFrames()
    for index = 1, self.flyoutCount or 0 do
        local button = self.flyoutButtons[index]
        UnregisterStateDriver(button, 'visibility')
        button:Hide()
    end
    self.flyoutCount = 0
    if self.flyoutBackdrop:IsShown() then self.flyoutBackdrop:Hide() end
end

function MissingBuffs:CloseFlyout()
    if not self.flyoutKey then return end
    self.flyoutKey = nil
    self:UnregisterEvent('GLOBAL_MOUSE_DOWN')

    -- Combat already hid the buttons through their drivers, their drivers still come off afterwards.
    if InCombatLockdown() then
        NRSKNUI:RunWhenSafe(function() self:HideFlyoutFrames() end)
    else
        self:HideFlyoutFrames()
    end
end

function MissingBuffs:OnFlyoutMouseDown()
    local owner = self.flyoutKey and self.buttons[self.flyoutKey]
    if owner and owner:IsMouseOver() then return end
    for index = 1, self.flyoutCount or 0 do
        if self.flyoutButtons[index]:IsMouseOver() then return end
    end
    self:CloseFlyout()
end
