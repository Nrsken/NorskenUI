---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G

Skinning:RegisterSkin(nil, 'ReadyCheck', function(S)
    local listener = _G.ReadyCheckListenerFrame
    if not listener then return end

    listener:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(listener)

    -- SetPortraitTexture re-fills it on every check, so it has to be killed, not cleared.
    local portrait = _G.ReadyCheckPortrait
    portrait:NUIStripTextures('Kill')

    local title = listener.TitleContainer
    title:ClearAllPoints()
    title:NUISetPixelPoint('TOPLEFT', listener, 'TOPLEFT', 0, -1)
    title:NUISetPixelPoint('TOPRIGHT', listener, 'TOPRIGHT', 0, -1)
    S:HandleAccentFont(title.TitleText)

    local text = _G.ReadyCheckFrameText
    text:ClearAllPoints()
    text:NUISetPixelPoint('TOP', listener, 'TOP', 0, -30)
    text:NUISetPixelWidth(300)
    S:HandleOutlineFont(text)

    local yesBtn, noBtn = _G.ReadyCheckFrameYesButton, _G.ReadyCheckFrameNoButton
    S:HandleButton(yesBtn)
    S:HandleButton(noBtn)
    ---@cast yesBtn Button & SkinnedButtonMixin
    yesBtn:NUISetPrimary(true)
end)
