---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL

local string_gsub = string.gsub
local format = string.format
local tostring = tostring
local ReloadUI = ReloadUI

---Wipes the saved GUI window position/size and snaps the live window back to its defaults.
function NRSKNUI:ResetGUIState()
    -- Rebuild the saved state rather than nil it, AceDB only refills defaults on load.
    if self.db and self.db.global then
        self.db.global.GUIState = { frame = {} }
    end

    local GUIFrame = self.GUIFrame
    if GUIFrame and GUIFrame.ResetPosition then
        GUIFrame:ResetPosition()
    end

    self:Print(L['GUI position and size reset to defaults.'])
end

-- Options --

local OPTIONS = 'NorskenUI_Options'

---The settings window lives in a LoadOnDemand addon, loaded the first time it's opened.
---@return boolean loaded
local function LoadOptions()
    if C_AddOns.IsAddOnLoaded(OPTIONS) then return true end

    local _, _, _, _, reason = C_AddOns.GetAddOnInfo(OPTIONS)
    if reason == 'MISSING' then
        NRSKNUI:Print(format(L['%s is missing, reinstall NorskenUI.'], OPTIONS))
        return false
    end

    -- a disabled options folder would leave /nui doing nothing, so turn it back on for this character
    C_AddOns.EnableAddOn('NorskenCore_Options', NRSKNUI.MyGUID)
    C_AddOns.EnableAddOn(OPTIONS, NRSKNUI.MyGUID)
    local loaded, failure = C_AddOns.LoadAddOn(OPTIONS)
    if not loaded then
        NRSKNUI:Print(OPTIONS .. ': ' .. (_G['ADDON_' .. tostring(failure)] or tostring(failure)))
        return false
    end

    -- folders from different releases mixed together break in odd ways, so say so up front
    -- raw TOC values on both sides: NRSKNUI.Version shows a dev checkout as 'Development Version'
    local version = C_AddOns.GetAddOnMetadata(OPTIONS, 'Version')
    local coreVersion = C_AddOns.GetAddOnMetadata('NorskenUI', 'Version')
    if version ~= coreVersion then
        NRSKNUI:Print(format(L['%s is version %s but NorskenUI is %s, update both.'], OPTIONS, tostring(version), tostring(coreVersion)))
    end
    return true
end

---Open the settings window, on a page when given one.
---@param pageId string?
---@param context table? { tabId, itemKey } inside that page
function NRSKNUI:OpenOptions(pageId, context)
    -- loading builds the whole window, which waits until combat is over
    if InCombatLockdown() then
        self:Print(L['Options will open after combat ends.'])
        self:RunWhenSafe(function()
            self:OpenOptions(pageId, context)
        end)
        return
    end
    if not LoadOptions() then return end

    local window = self.PageWindows[pageId] or self.GUIFrame
    if not window:IsShown() then
        window:Show()
    end
    if pageId then
        window:ShowPage(pageId, context)
    end
end

function NRSKNUI:ToggleOptions()
    local window = C_AddOns.IsAddOnLoaded(OPTIONS) and self.GUIFrame
    if window and window:IsShown() then
        window:Hide()
    else
        self:OpenOptions()
    end
end

-- Game menu entry, kept out of Blizzard's button pool so its pooled buttons never carry our taint.
function NRSKNUI:SetupGameMenuButton()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_GameMenu', function()
        local menu = _G.GameMenuFrame
        local button = CreateFrame('Button', 'NRSKNUI_GameMenuButton', menu, 'MainMenuFrameButtonTemplate')
        button:SetScript('OnClick', function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            menu:CloseMenu()
            NRSKNUI:OpenOptions()
        end)

        -- Layout re-anchors every pooled button from scratch, so this slots in below Macros each time.
        hooksecurefunc(menu, 'Layout', function()
            local anchor
            for menuButton in menu.buttonPool:EnumerateActive() do
                local text = menuButton:GetText()
                if text == MACROS or (text == GAMEMENU_SUPPORT and not anchor) then anchor = menuButton end
            end
            -- A secure frame anchored to the menu protects it, and resizing it is blocked in combat.
            if not anchor or (InCombatLockdown() and menu:IsProtected()) then
                button:Hide()
                return
            end

            local height = anchor:GetHeight()
            button:SetText(NRSKNUI:ColorTextByTheme('Norsken') .. '|cffb3b3b3UI|r') -- per open, so a theme change shows
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
end

-- Setup slash commands
function NRSKNUI:SetupSlashCommands()
    SLASH_NRSKNUI1 = '/nui'
    SLASH_NRSKNUI2 = '/norskenui'
    SlashCmdList['NRSKNUI'] = function(msg)
        msg = (msg or ''):lower()
        msg = string_gsub(msg, '^%s+', '')
        msg = string_gsub(msg, '%s+$', '')
        if msg == '' or msg == 'gui' then
            NRSKNUI:ToggleOptions()
        elseif msg == 'anchors' then
            if NRSKNUI.Anchors then
                NRSKNUI.Anchors:Toggle()
            end
        elseif msg == 'guireset' then
            NRSKNUI:ResetGUIState()
        end
    end

    -- /rl instead of /reload shortcut :)
    SLASH_NRSKNUI_RL1 = '/rl'
    SlashCmdList['NRSKNUI_RL'] = function() ReloadUI() end
end
