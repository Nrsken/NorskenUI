---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

local InCombatLockdown = InCombatLockdown
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local _G = _G

local MACROS = MACROS
local GAMEMENU_SUPPORT = GAMEMENU_SUPPORT

-- our own button, kept out of Blizzard's button pool so its pooled buttons never carry our taint
EventUtil.ContinueOnAddOnLoaded('Blizzard_GameMenu', function()
    local menu = _G.GameMenuFrame
    local button = CreateFrame('Button', 'NRSKNUI_GameMenuButton', menu, 'MainMenuFrameButtonTemplate')
    button:SetScript('OnClick', function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        menu:CloseMenu()
        NRSKNUI:OpenOptions()
    end)

    -- Layout re-anchors every pooled button from scratch, so this slots in below Macros each time
    hooksecurefunc(menu, 'Layout', function()
        local anchor
        for menuButton in menu.buttonPool:EnumerateActive() do
            local text = menuButton:GetText()
            if text == MACROS or (text == GAMEMENU_SUPPORT and not anchor) then
                anchor = menuButton
            end
        end
        -- a secure frame anchored to the menu protects it and resizing it is blocked in combat
        if not anchor or (InCombatLockdown() and menu:IsProtected()) then
            button:Hide()
            return
        end

        local height = anchor:GetHeight()
        button:SetText(NRSKNUI:GetTitle()) -- per open, so a theme change shows
        button:SetSize(anchor:GetWidth(), height)
        button:ClearAllPoints()
        button:SetPoint('TOP', anchor, 'BOTTOM')
        button:Show()

        for menuButton in menu.buttonPool:EnumerateActive() do
            if menuButton.layoutIndex > anchor.layoutIndex then
                menuButton:AdjustPointsOffset(0, -height)
            end
        end
        menu:SetHeight(menu:GetHeight() + height)
    end)
end)
