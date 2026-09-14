---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G
local hooksecurefunc = hooksecurefunc

-- The frame keeps 48px above the first button, so this drops the title text into the middle of it.
local HEADER_OFFSET = -4

---@param button Button & SkinnedButtonMixin
local function RehookHoverState(button)
    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)
    button:NUIUpdateState()
end

---InitButtons runs on every open, and AddButton's SetScript('OnEnter'/'OnLeave') discards the whole
---script chain, so an already-skinned button has lost its hover hooks by the time this runs.
---@param menu NUIGameMenuFrame
local function SkinMenuButtons(menu)
    if not menu.buttonPool then return end

    for button in menu.buttonPool:EnumerateActive() do
        if button.NUISkinned then
            RehookHoverState(button)
        else
            Skinning:HandleButton(button)
        end
    end
end

Skinning:RegisterSkin('Blizzard_GameMenu', 'GameMenu', function(S)
    ---@type NUIGameMenuFrame
    local menu = _G.GameMenuFrame
    if not menu then return end

    menu:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(menu)

    local header = menu.Header
    if header then
        header:NUIStripTextures()
        header:ClearAllPoints()
        header:NUISetPixelPoint('TOP', menu, 'TOP', 0, HEADER_OFFSET)
        S:HandleAccentFont(header.Text)
    end

    hooksecurefunc(menu, 'InitButtons', SkinMenuButtons)
    SkinMenuButtons(menu)
end)
