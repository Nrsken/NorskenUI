---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class MissingBuffsModule
local MissingBuffs = NRSKNUI:GetModule('MissingBuffs')
local L = NRSKNUI.Libs.AL

local pairs = pairs
local ipairs = ipairs
local format = string.format
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local IsShiftKeyDown, IsAltKeyDown, IsControlKeyDown = IsShiftKeyDown, IsAltKeyDown, IsControlKeyDown

local GetSpellName = C_Spell and C_Spell.GetSpellName
local GetItemNameByID = C_Item and C_Item.GetItemNameByID

local GameTooltip = GameTooltip

local MACRO_CAST = '/cast %s'
local MACRO_SELF = '/cast [@player] %s'
local MACRO_TARGETED = '/cast [@target,help,nodead][] %s'
local MACRO_ITEM = '/use item:%d'
local USE_MAINHAND = '\n/use 16'
local USE_OFFHAND = '\n/use 17'

local MODIFIERS = { 'shift', 'alt', 'ctrl' }
local MODIFIER_TEXT = { shift = L['Shift'], alt = L['Alt'], ctrl = L['Ctrl'] }
local MODIFIER_DOWN = { shift = IsShiftKeyDown, alt = IsAltKeyDown, ctrl = IsControlKeyDown }
local FLYOUT_TYPE = 'nuiFlyout'

MissingBuffs.buttons = {} ---@type table<string, MissingBuffs.Button>

---@return boolean
function MissingBuffs:IsFlyoutModifierDown()
    return MODIFIER_DOWN[self.db.FlyoutModifier]() or false
end

-- A plain click that used a consumable makes it this spec's choice.
---@param button MissingBuffs.Button
local function OnMainPostClick(button)
    if InCombatLockdown() or MissingBuffs:IsFlyoutModifierDown() then return end
    local result = MissingBuffs.shown[button.key]
    if result and result.useItem then
        MissingBuffs:RememberItem(result.entry.itemList, result.useItem)
    end
end

---@param button MissingBuffs.Button
local function OnMainEnter(button)
    local result = MissingBuffs.shown[button.key]
    if not result then return end
    local entry = result.entry

    local title, action
    if result.useItem then
        title = GetItemNameByID(result.useItem) or ''
        action = not entry.useWeapon and L['Left-Click to use']
            or entry.enchantSlot == 'offhand' and L['Left-Click to use on your off hand']
            or L['Left-Click to use on your main hand']
    else
        title = GetSpellName(result.castSpell --[[@as number]]) or ''
        action = (result.category == 'Targeted' or entry.targeted) and L['Left-Click to cast on your target']
            or L['Left-Click to cast']
    end

    GameTooltip:SetOwner(button, 'ANCHOR_NONE')
    GameTooltip:SetPoint('BOTTOMRIGHT', _G.NRSKNUI_TooltipAnchorFrame or GameTooltipDefaultContainer)
    GameTooltip:AddLine(NRSKNUI:ColorTextByTheme(title))
    GameTooltip:AddLine(action, 0.70, 0.70, 0.70)
    if entry.itemList then
        GameTooltip:AddLine(format(L['%s-Click to pick another'], MODIFIER_TEXT[MissingBuffs.db.FlyoutModifier]), 0.70, 0.70, 0.70)
    end
    GameTooltip:Show()
    MissingBuffs:SetTooltipIcon(result.icon)
end

---@param result MissingBuffs.Result
---@return string?
local function GetMacro(result)
    local entry = result.entry
    local macro
    if result.useItem then
        macro = format(MACRO_ITEM, result.useItem)
    else
        local name = result.castSpell and GetSpellName(result.castSpell)
        if not name then return nil end
        if result.category == 'Targeted' or entry.targeted then return format(MACRO_TARGETED, name) end
        macro = format(entry.selfCast and MACRO_SELF or MACRO_CAST, name)
    end

    if entry.useWeapon then
        macro = macro .. (entry.enchantSlot == 'offhand' and USE_OFFHAND or USE_MAINHAND)
    end
    return macro
end

---@param key string
---@return MissingBuffs.Button
function MissingBuffs:GetButton(key)
    local button = self.buttons[key]
    if button then return button end

    -- Parented to UIParent and placed by coordinates, anchoring to our icon would protect the whole group.
    button = CreateFrame('Button', nil, UIParent, 'SecureActionButtonTemplate') --[[@as MissingBuffs.Button]]
    button:RegisterForClicks('AnyUp', 'AnyDown')
    button:SetAttribute('type', 'macro')
    button:NCStyleButton()
    button:SetScript('PostClick', OnMainPostClick)
    button:SetScript('OnEnter', OnMainEnter)
    button:SetScript('OnLeave', GameTooltip_Hide)
    button:Hide()
    button.key = key

    -- Custom action types call the same-named function on the button, the modifier click lands here instead of using the item.
    button[FLYOUT_TYPE] = function() self:ToggleFlyout(key) end

    self.buttons[key] = button
    return button
end

---@param button Button
local function Deactivate(button)
    if not button.active then return end
    button.active = false
    UnregisterStateDriver(button, 'visibility')
    button:Hide()
end

---@param button Button
---@param icon Frame
---@return boolean placed
local function PlaceOver(button, icon)
    local left, bottom = icon:GetLeft(), icon:GetBottom()
    if not left or not bottom then return false end

    local scale = icon:GetEffectiveScale() / UIParent:GetEffectiveScale()
    button:ClearAllPoints()
    button:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', left * scale, bottom * scale)
    button:SetSize(icon:GetWidth() * scale, icon:GetHeight() * scale)
    button:SetFrameStrata(icon:GetFrameStrata())
    button:SetFrameLevel(icon:GetFrameLevel() + 10)
    return true
end

-- Out of combat only, a pull hides every button through its state driver until the next sync.
function MissingBuffs:SyncButtons()
    if InCombatLockdown() then
        if not self.syncQueued then
            self.syncQueued = true
            NRSKNUI:RunWhenSafe(function()
                self.syncQueued = false
                self:SyncButtons()
            end)
        end
        return
    end

    local enabled = self.db.ClickToCast and not self.isPreview and self:IsEnabled()
    if enabled then
        for _, group in pairs(self.groups) do group:ForceLayout() end
    end

    for key, icon in pairs(self.icons) do
        local result = enabled and self.shown[key]
        local macro = result and icon:IsVisible() and GetMacro(result)
        local button = self.buttons[key]

        if macro then
            button = self:GetButton(key)
            if PlaceOver(button, icon) then
                button:SetAttribute('macrotext', macro)
                for _, modifier in ipairs(MODIFIERS) do
                    local flyout = modifier == self.db.FlyoutModifier and result.entry.itemList ~= nil
                    button:SetAttribute(modifier .. '-type1', flyout and FLYOUT_TYPE or nil)
                end
                if not button.active then
                    button.active = true
                    RegisterStateDriver(button, 'visibility', '[combat] hide; show')
                end
            else
                Deactivate(button)
            end
        elseif button then
            Deactivate(button)
        end
    end

    if self.flyoutKey and not (enabled and self.shown[self.flyoutKey]) then
        self:CloseFlyout()
    end
end
