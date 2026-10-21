---@class NRSKNUI
local NRSKNUI = select(2, ...)

local string_gsub = string.gsub
local format = string.format
local tostring = tostring
local ReloadUI = ReloadUI
local canaccessvalue = canaccessvalue
local GetMouseFocus = GetMouseFocus
local GetMouseFoci = GetMouseFoci
local pcall = pcall
local ipairs = ipairs
local type = type
local floor = math.floor
local loadAddOn = LoadAddOnWithErrorHandling or UIParentLoadAddOn -- UIParentLoadAddOn is renamed to: LoadAddOnWithErrorHandling in 12.1.X+

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

    self:Print('GUI position and size reset to defaults.')
end

-- Options --

local OPTIONS = 'NorskenUI_Options'

---The settings window lives in a LoadOnDemand addon, loaded the first time it's opened.
---@return boolean loaded
local function LoadOptions()
    if C_AddOns.IsAddOnLoaded(OPTIONS) then return true end

    local _, _, _, _, reason = C_AddOns.GetAddOnInfo(OPTIONS)
    if reason == 'MISSING' then
        NRSKNUI:Print(OPTIONS .. ' is missing, reinstall NorskenUI.')
        return false
    end

    -- a disabled options folder would leave /nui doing nothing, so turn it back on for this character
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
        NRSKNUI:Print(format('%s is version %s but NorskenUI is %s, update both.', OPTIONS, tostring(version), tostring(coreVersion)))
    end
    return true
end

---Open the settings window, on a page when given one.
---@param pageId string?
---@param context table? { tabId, itemKey } inside that page
function NRSKNUI:OpenOptions(pageId, context)
    -- loading builds the whole window, which waits until combat is over
    if InCombatLockdown() then
        self:Print('Options will open after combat ends.')
        self:RunWhenSafe(function()
            self:OpenOptions(pageId, context)
        end)
        return
    end
    if not LoadOptions() then return end

    local window = self.GUIFrame
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

    -- /fs instead of /fstack shortcut :)
    SLASH_NRSKNUI_FS1 = '/fs'
    SlashCmdList['NRSKNUI_FS'] = function()
        loadAddOn('Blizzard_DebugTools')
        FrameStackTooltip_Toggle()
    end

    local function CanRead(ok, val)
        return ok and (not canaccessvalue or canaccessvalue(val))
    end

    local function MouseFocus()
        if GetMouseFocus then
            return GetMouseFocus()
        end
        local foci = GetMouseFoci and GetMouseFoci()
        return foci and foci[1]
    end

    local function FrameName(f)
        if not f then
            return 'nil'
        end
        if f.GetDebugName then
            return f:GetDebugName()
        end
        if f.GetName then
            return f:GetName() or 'Anonymous'
        end
        return 'Anonymous'
    end

    -- /getpoint, print the anchor of a named frame or the one under the cursor
    SLASH_NRSKNUI_GETPOINT1 = '/getpoint'
    SlashCmdList['NRSKNUI_GETPOINT'] = function(arg)
        arg = string_gsub(arg or '', '%s', '')
        local frame = (arg ~= '' and _G[arg]) or MouseFocus()
        if not frame or not frame.GetPoint then return end
        local point, relativeTo, relativePoint, x, y = frame:GetPoint()
        print('|cffe51039NUI|r', FrameName(frame), point, FrameName(relativeTo), relativePoint, x, y)
    end

    -- /frame, set _G.INSPECTFRAME to a named frame or the one under the cursor
    SLASH_NRSKNUI_FRAME1 = '/frame'
    SlashCmdList['NRSKNUI_FRAME'] = function(arg)
        arg = string_gsub(arg or '', '%s', '')
        local frame = (arg ~= '' and _G[arg]) or MouseFocus()
        if not frame then return end
        _G.INSPECTFRAME = frame
        print('|cffe51039NUI|r _G.INSPECTFRAME set to:', FrameName(frame))
    end

    -- /texlist, list textures on a frame's regions
    SLASH_NRSKNUI_TEXLIST1 = '/texlist'
    SlashCmdList['NRSKNUI_TEXLIST'] = function(arg)
        arg = string_gsub(arg or '', '%s', '')
        local frame = (arg ~= '' and _G[arg]) or _G.INSPECTFRAME
        if not frame or not frame.GetRegions then return end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType('Texture') then
                print(region:GetTexture(), region:GetName() or region:GetDebugName(), region:GetDrawLayer())
            end
        end
    end

    -- /fontlist, prints the font objects behind a frame's text
    SLASH_NRSKNUI_FONTLIST1 = '/fontlist'
    SlashCmdList['NRSKNUI_FONTLIST'] = function(arg)
        arg = string_gsub(arg or '', '%s', '')
        local frame = (arg ~= '' and _G[arg]) or _G.INSPECTFRAME or MouseFocus()
        if not frame or not frame.GetRegions then
            print('|cffe51039NUI|r no frame, use /frame first, or hover a frame')
            return
        end

        local seenObj, found = {}, 0
        local function Walk(f, depth)
            if depth > 8 then return end
            local okR, regions = pcall(function() return { f:GetRegions() } end)
            if okR then
                for _, r in ipairs(regions) do
                    local okT, isFS = pcall(r.IsObjectType, r, 'FontString')
                    if CanRead(okT, isFS) and isFS then
                        local obj = r.GetFontObject and r:GetFontObject()
                        local objName = obj and obj.GetName and obj:GetName() or '(direct SetFont)'
                        local objText = r.GetText and r:GetText() or '(no text)'
                        if not seenObj[objName] then
                            seenObj[objName] = true
                            local okF, _, size, flags = pcall(r.GetFont, r)
                            local sz = (CanRead(okF, size) and type(size) == 'number') and floor(size + 0.5) or '?'
                            local fl = (CanRead(okF, flags) and (flags ~= '' and flags or '|cffff0000no outline|r')) or '?'
                            print(objText .. ('  |cffffffff%s|r  %s, |cff00ff00%s|r'):format(objName, sz, fl))
                            found = found + 1
                        end
                    end
                end
            end
            local okC, children = pcall(function() return { f:GetChildren() } end)
            if okC then
                for _, c in ipairs(children) do Walk(c, depth + 1) end
            end
        end

        print('|cffe51039NUI|r fonts in ' .. FrameName(frame) .. ':')
        Walk(frame, 0)
        if found == 0 then print('  (none found)') end
    end

    -- Powerful macro:
    -- /frame
    -- /fontlist or /texlist
end
