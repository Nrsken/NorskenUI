---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G

-- The message starts past the Small portrait tab's cut, which ends 53 in, rather than centring under it.
local TEXT_LEFT, TEXT_RIGHT, TEXT_TOP = 58, -8, -30

Skinning:RegisterSkin(nil, 'ReadyCheck', function(S)
    local listener = _G.ReadyCheckListenerFrame
    if not listener then return end

    listener:NCStripTextures('Keyed')
    S:CreatePanelBackdrop(listener)

    local portrait = _G.ReadyCheckPortrait --[[@as Texture & { NUIHeader: NUIPortraitHeader? }]]
    portrait:NCStripTextures('Kill')
    portrait.NUIHeader = S:CreatePortraitHeader(listener, S.PortraitTabSize.Small)

    local title = listener.TitleContainer
    title:ClearAllPoints()
    title:NCSetPoint('TOPLEFT', listener, 'TOPLEFT', 0, -1)
    title:NCSetPoint('TOPRIGHT', listener, 'TOPRIGHT', 0, -1)
    S:HandleAccentFont(title.TitleText)

    local text = _G.ReadyCheckFrameText
    --text:ClearAllPoints()
    --text:NCSetPoint('TOPLEFT', listener, 'TOPLEFT', TEXT_LEFT, TEXT_TOP)
    --text:NCSetPoint('TOPRIGHT', listener, 'TOPRIGHT', TEXT_RIGHT, TEXT_TOP)
    S:HandleOutlineFont(text)

    local yesBtn, noBtn = _G.ReadyCheckFrameYesButton, _G.ReadyCheckFrameNoButton
    S:HandleButton(yesBtn)
    S:HandleButton(noBtn)
    ---@cast yesBtn Button & SkinnedButtonMixin
    yesBtn:NUISetPrimary(true)
end)
