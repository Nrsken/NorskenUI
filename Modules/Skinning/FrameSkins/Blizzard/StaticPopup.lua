---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G
local gsub = string.gsub
local strlower = strlower
local hooksecurefunc = hooksecurefunc

local YES_R, YES_G, YES_B = 0.30, 0.80, 0.40
local NO_R, NO_G, NO_B = 0.90, 0.30, 0.30

---@param popup Frame
---@param key string
---@return any
local function GetElement(popup, key)
    local element = popup[gsub(key, '^%w', strlower)] or popup[key]
    if element then return element end

    local name = popup:GetName()
    return name and _G[name .. key]
end

---One set of buttons serves every dialog, so the label is re-read rather than read once.
---@param button Button & SkinnedButtonMixin
local function TintConfirmButton(button)
    local label = button:GetText()

    if label == _G.YES then
        button:NUISetTextColor(YES_R, YES_G, YES_B)
    elseif label == _G.NO then
        button:NUISetTextColor(NO_R, NO_G, NO_B)
    else
        button:NUISetTextColor(1, 1, 1)
    end
end

---@param S SkinningModule
---@param popup Frame
local function SkinStaticPopup(S, popup)
    popup:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(popup)

    -- The button count varies per dialog, so walk until one is missing rather than assume four.
    local index = 1
    local button = GetElement(popup, 'Button' .. index)
    while button do
        S:HandleButton(button)

        hooksecurefunc(button, 'SetText', TintConfirmButton)
        TintConfirmButton(button)

        index = index + 1
        button = GetElement(popup, 'Button' .. index)
    end

    S:HandleButton(GetElement(popup, 'ExtraButton'))
    S:HandleCloseButton(GetElement(popup, 'CloseButton'), popup)
    S:HandleEditBox(GetElement(popup, 'EditBox'))

    local moneyInput = GetElement(popup, 'MoneyInputFrame')
    if moneyInput then
        S:HandleEditBox(moneyInput.gold)
        S:HandleEditBox(moneyInput.silver)
        S:HandleEditBox(moneyInput.copper)
    end

    local itemFrame = GetElement(popup, 'ItemFrame')
    if itemFrame then
        local nameFrame = itemFrame.NameFrame or GetElement(popup, 'ItemFrameNameFrame')
        if nameFrame then nameFrame:NUIStripTextures() end

        S:HandleItemButton(itemFrame.Item or itemFrame)
    end
end

Skinning:RegisterSkin(nil, 'StaticPopups', function(S)
    local index = 1
    local popup = _G['StaticPopup' .. index]

    while popup do
        SkinStaticPopup(S, popup)

        index = index + 1
        popup = _G['StaticPopup' .. index]
    end
end)
