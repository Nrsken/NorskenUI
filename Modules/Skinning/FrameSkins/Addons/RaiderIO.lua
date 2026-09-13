---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

-- Skins and repositions the RaiderIO button that exports info about the group members.

local _G = _G

local BUTTON_SIZE = 20
local X_GAP = 0
local Y_GAP = 0
local ICON_INSET = 2
local ICON_TEXCOORD = 0.05

local LOGO_TEXTURE = [[Interface\AddOns\RaiderIO\icons\logo]]

local skinned = false
local function SkinExportButton()
    if skinned then return end

    local button = _G.RaiderIO_ExportButton
    if not button then return end
    skinned = true

    Skinning:HandleButton(button)
    button:NUISetPixelSize(BUTTON_SIZE, BUTTON_SIZE)

    local logo = button:CreateTexture(nil, 'ARTWORK')
    logo:NUISetPixelPoint('TOPLEFT', button, 'TOPLEFT', ICON_INSET, -ICON_INSET)
    logo:NUISetPixelPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -ICON_INSET, ICON_INSET)
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetTexCoord(ICON_TEXCOORD, 1 - ICON_TEXCOORD, ICON_TEXCOORD, 1 - ICON_TEXCOORD)
    logo:NUISetPixelSnap()

    local close = _G.PVEFrame and _G.PVEFrame.CloseButton
    if not close then return end

    button:ClearAllPoints()
    button:NUISetPixelPoint('RIGHT', close, 'LEFT', X_GAP, Y_GAP)
end

Skinning:RegisterSkin('RaiderIO', 'RaiderIO', function()
    local frame = _G.LFGListFrame
    if not frame then return end

    frame:HookScript('OnShow', SkinExportButton)
    SkinExportButton()
end)
