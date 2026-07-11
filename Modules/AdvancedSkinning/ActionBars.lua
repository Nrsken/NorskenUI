-- NRSKNUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Check for addon object
-- Create module
---@class ActionBars: AceModule, AceEvent-3.0
local ACB = NRSKNUI:NewModule("ActionBars", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local InCombatLockdown = InCombatLockdown
local PetHasActionBar = PetHasActionBar
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetCursorPosition = GetCursorPosition
local pcall = pcall
local SecureCmdOptionParse = SecureCmdOptionParse
local hooksecurefunc = hooksecurefunc
local GetPetActionInfo = GetPetActionInfo
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local getmetatable = getmetatable
local table_insert = table.insert
local _G = _G

-- Frame map, maps DB key to frame name and button prefix so we can iterate through them later
local BAR_FRAME_MAP = {
    Bar1 = { frame = "MainActionBar", prefix = "ActionButton" },
    Bar2 = { frame = "MultiBarBottomLeft", prefix = "MultiBarBottomLeftButton" },
    Bar3 = { frame = "MultiBarBottomRight", prefix = "MultiBarBottomRightButton" },
    Bar4 = { frame = "MultiBarRight", prefix = "MultiBarRightButton" },
    Bar5 = { frame = "MultiBarLeft", prefix = "MultiBarLeftButton" },
    Bar6 = { frame = "MultiBar5", prefix = "MultiBar5Button" },
    Bar7 = { frame = "MultiBar6", prefix = "MultiBar6Button" },
    Bar8 = { frame = "MultiBar7", prefix = "MultiBar7Button" },
    PetBar = { frame = "PetActionBar", prefix = "PetActionButton" },
    StanceBar = { frame = "StanceBar", prefix = "StanceButton" },
}

-- Function used to make sure blizzards own actionabars do not interfere with clicking on my custom ones
-- Mainly for actionbar 1 since it cannot be turned off properly.
local function BlizzBarMouseToggle(barKey)
    local frameInfo = BAR_FRAME_MAP[barKey]
    local frame = _G[frameInfo.frame]
    frame:EnableMouse(false)
end

-- Build config for a single bar from DB
local configTable = {}
local function BuildBarConfig(barKey, barDB, globalMouseover)
    local frameInfo = BAR_FRAME_MAP[barKey]
    if not frameInfo or not barDB then return nil end

    local frame = _G[frameInfo.frame]
    if not frame then return nil end

    -- Determine mouseover settings, uses global if globalOverride is true
    local useGlobal = barDB.Mouseover and barDB.Mouseover.GlobalOverride
    local mouseoverEnabled, mouseoverAlpha

    -- Use global mouseover settings
    if useGlobal then
        mouseoverEnabled = globalMouseover.Enabled == true
        mouseoverAlpha = globalMouseover.Alpha or 1
    else
        -- Use per-bar mouseover settings
        mouseoverEnabled = barDB.Mouseover and barDB.Mouseover.Enabled == true
        mouseoverAlpha = (barDB.Mouseover and barDB.Mouseover.Alpha) or 1
    end

    local layout = barDB.Layout or "HORIZONTAL"
    local growth = barDB.GrowthDirection or "RIGHT"
    local point
    if layout == "HORIZONTAL" then
        point = (growth == "LEFT") and "BOTTOMRIGHT" or "BOTTOMLEFT"
    else
        point = (growth == "LEFT") and "TOPRIGHT" or "TOPLEFT"
    end

    -- Return config
    return {
        name = barKey,
        dbReference = barDB,
        frame = frame,
        buttonPrefix = frameInfo.prefix,
        spacing = barDB.Spacing or 1,
        buttonSize = barDB.ButtonSize or 40,
        totalButtons = barDB.TotalButtons or 12,
        point = point,
        buttonsPerLine = barDB.ButtonsPerLine or 12,
        anchorPoint = barDB.Position and barDB.Position.AnchorPoint or "BOTTOM",
        x = barDB.Position and barDB.Position.XOffset or 0,
        y = barDB.Position and barDB.Position.YOffset or 0,
        enabled = barDB.Enabled ~= false,
        mouseover = {
            enabled = mouseoverEnabled,
            fadeInDuration = globalMouseover.FadeInDuration or 0.3,
            fadeOutDuration = globalMouseover.FadeOutDuration or 1,
            alpha = mouseoverAlpha,
        }
    }
end

-- Update db, used for profile changes
function ACB:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.ActionBars
end

-- Module init
function ACB:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Build configTable from DB, called on enable so DB is ready
-- This way i only need to create defaults once in the Core/Defaults.lua
-- skipBlizzToggle: if true, don't disable Blizzard bar mouse (used during combat)
function ACB:BuildConfigTable(skipBlizzToggle)
    configTable = {}
    if not self.db or not self.db.Bars then return end
    local globalMouseover = self.db.Mouseover or {}

    -- Build config for each bar defined in BAR_FRAME_MAP
    for barKey, _ in pairs(BAR_FRAME_MAP) do
        if not skipBlizzToggle then
            BlizzBarMouseToggle(barKey)
        end
        local barDB = self.db.Bars[barKey]
        if barDB then
            local cfg = BuildBarConfig(barKey, barDB, globalMouseover)
            if cfg then
                table_insert(configTable, cfg)
            end
        end
    end
end

-- Check if keybind text is valid
-- RANGE_INDICATOR is a placeholder square character Blizzard uses for empty keybinds
local function HasValidKeybindText(text)
    if not text or text == "" then return false end
    if text == RANGE_INDICATOR then return false end
    return true
end

-- Remap keybind text to shorter versions, use only uppercase letters and remove spaces
-- For example "Middle Mouse" becomes "M3"
local function RemapKeyText(button)
    local text = button.HotKey:GetText() or ''
    if not text or text == "" then return end
    text = text:upper()
    text = text:gsub(' ', '')
    text = text:gsub('%-', '')
    text = text:gsub("SPACEBAR", "SP")
    text = text:gsub("MIDDLEMOUSE", "M3")
    text = text:gsub("MOUSEWHEELUP", "MWU")
    text = text:gsub("MOUSEWHEELDOWN", "MWD")
    text = text:gsub("MOUSEBUTTON4", "M4")
    text = text:gsub("MOUSEBUTTON5", "M5")
    text = text:gsub("NUMPAD%s*(%d)", "NP%1")
    text = text:gsub("NUMPAD", "NP")
    button.HotKey:SetText(text)
end

-- Get font sizes for a bar, respects GlobalOverride
function ACB:GetFontSizes(barKey)
    local barDB = self.db.Bars and self.db.Bars[barKey]
    local globalFontSizes = self.db.FontSizes or {}
    local barFontSizes = barDB and barDB.FontSizes or {}
    local useGlobal = barFontSizes.GlobalOverride == true
    if useGlobal then
        return {
            keybind = globalFontSizes.KeybindSize or 12,
            cooldown = globalFontSizes.CooldownSize or 14,
            charge = globalFontSizes.ChargeSize or 12,
            macro = globalFontSizes.MacroSize or 10,
        }
    else
        return {
            keybind = barFontSizes.KeybindSize or 12,
            cooldown = barFontSizes.CooldownSize or 14,
            charge = barFontSizes.ChargeSize or 12,
            macro = barFontSizes.MacroSize or 10,
        }
    end
end

-- Get text positions for a bar, respects GlobalOverride
function ACB:GetTextPositions(barKey)
    local barDB = self.db.Bars and self.db.Bars[barKey]
    local barTextPos = barDB and barDB.TextPositions or {}
    local useGlobal = barTextPos.GlobalOverride ~= false -- Default to true
    if useGlobal then
        return {
            keybindAnchor = self.db.KeybindAnchor or "TOPRIGHT",
            keybindXOffset = self.db.KeybindXOffset or -2,
            keybindYOffset = self.db.KeybindYOffset or -2,
            chargeAnchor = self.db.ChargeAnchor or "BOTTOMRIGHT",
            chargeXOffset = self.db.ChargeXOffset or -2,
            chargeYOffset = self.db.ChargeYOffset or 2,
            macroAnchor = self.db.MacroAnchor or "BOTTOM",
            macroXOffset = self.db.MacroXOffset or 0,
            macroYOffset = self.db.MacroYOffset or -2,
            cooldownAnchor = self.db.CooldownAnchor or "CENTER",
            cooldownXOffset = self.db.CooldownXOffset or 0,
            cooldownYOffset = self.db.CooldownYOffset or 0,
        }
    else
        return {
            keybindAnchor = barTextPos.KeybindAnchor or "TOPRIGHT",
            keybindXOffset = barTextPos.KeybindXOffset or -2,
            keybindYOffset = barTextPos.KeybindYOffset or -2,
            chargeAnchor = barTextPos.ChargeAnchor or "BOTTOMRIGHT",
            chargeXOffset = barTextPos.ChargeXOffset or -2,
            chargeYOffset = barTextPos.ChargeYOffset or 2,
            macroAnchor = barTextPos.MacroAnchor or "BOTTOM",
            macroXOffset = barTextPos.MacroXOffset or 0,
            macroYOffset = barTextPos.MacroYOffset or -2,
            cooldownAnchor = barTextPos.CooldownAnchor or "CENTER",
            cooldownXOffset = barTextPos.CooldownXOffset or 0,
            cooldownYOffset = barTextPos.CooldownYOffset or 0,
        }
    end
end

-- Get bar-specific config
function ACB:GetBarConfig(barKey)
    return self.db.Bars and self.db.Bars[barKey]
end

-- Track all backdrops for config refresh
local allBackdrops = {}

function ACB:RegisterBackdrop(backdrop)
    allBackdrops[#allBackdrops + 1] = backdrop
end

-- Refresh cached bar configs when settings change
function ACB:RefreshBackdropConfigs()
    for _, backdrop in ipairs(allBackdrops) do
        local barName = backdrop._barName
        if barName and backdrop._updateVisibility then
            backdrop._barConfig = self:GetBarConfig(barName)
            backdrop._updateVisibility()
        end
    end
end

-- Get text visibility settings for a bar, respects GlobalOverride
function ACB:GetTextVisibility(barKey)
    local barDB = self.db.Bars and self.db.Bars[barKey]
    local barTextVis = barDB and barDB.TextVisibility or {}
    local useGlobal = barTextVis.GlobalOverride ~= false -- Default to true
    if useGlobal then
        return {
            hideMacroText = self.db.HideMacroText == true,
            hideKeybindText = self.db.HideKeybindText == true,
            hideChargeText = self.db.HideChargeText == true,
            hideProfTexture = self.db.HideProfTexture == true,
        }
    else
        return {
            hideMacroText = barTextVis.HideMacroText == true,
            hideKeybindText = barTextVis.HideKeybindText == true,
            hideChargeText = barTextVis.HideChargeText == true,
            hideProfTexture = barTextVis.HideProfTexture == true,
        }
    end
end

-- Style button texts
function ACB:StyleButtonText(button, barKey)
    if not button then return end
    local hotkey = button.HotKey
    local name = button.Name
    local count = button.Count
    local cooldown = button.cooldown
    local fontpath = NRSKNUI:GetFontPath(NRSKNUI:GetEffectiveFont(self.db))

    -- Get font sizes, text positions, and visibility for this bar
    local fontSizes = self:GetFontSizes(barKey)
    local textPos = self:GetTextPositions(barKey)
    local textVis = self:GetTextVisibility(barKey)

    -- Style cooldown text
    if cooldown then
        local fontSize = math.max(8, fontSizes.cooldown)

        -- Iterate through each button and apply cooldown text styling
        for _, region in ipairs({ cooldown:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                pcall(function()
                    region:ClearAllPoints()
                    region:SetPoint(textPos.cooldownAnchor, button, textPos.cooldownAnchor,
                        textPos.cooldownXOffset, textPos.cooldownYOffset)
                    region:SetFont(fontpath, fontSize, self.db.FontOutline)
                    region:SetTextColor(1, 1, 1, 1)
                    region:SetShadowOffset(0, 0)
                    region:SetShadowColor(0, 0, 0, 0)
                    region:SetAlpha(1)
                    region:SetJustifyH("CENTER")
                end)
            end
        end
    end

    -- Store barKey on button for hooks to access
    button._nrsknBarKey = barKey

    -- Style keybind text or hide if HideKeybindText is enabled
    if hotkey then
        local fontSize = math.max(6, fontSizes.keybind)
        hotkey:ClearAllPoints()
        hotkey:SetPoint(textPos.keybindAnchor, button, textPos.keybindAnchor,
            textPos.keybindXOffset, textPos.keybindYOffset)
        hotkey:SetWidth((button:GetWidth() - 2) or 0)
        hotkey:SetFont(fontpath, fontSize, self.db.FontOutline)
        hotkey:SetShadowColor(0, 0, 0, 0)
        hotkey:SetJustifyH("RIGHT")
        hotkey:SetWordWrap(false)

        -- Store original info for later use in hooks
        hotkey._nrsknAnchor = textPos.keybindAnchor
        hotkey._nrsknXOffset = textPos.keybindXOffset
        hotkey._nrsknYOffset = textPos.keybindYOffset
        hotkey._nrsknFontPath = fontpath
        hotkey._nrsknFontSize = fontSize
        hotkey._nrsknFontOutline = self.db.FontOutline
        hotkey._nrsknBarKey = barKey

        -- Helper to check if keybind should be hidden for this button's bar
        local function ShouldHideKeybind(btn)
            local bk = btn._nrsknBarKey or btn:GetParent() and btn:GetParent()._nrsknBarKey
            if bk then
                local vis = ACB:GetTextVisibility(bk)
                return vis.hideKeybindText
            end
            return ACB.db and ACB.db.HideKeybindText
        end

        -- Hook SetVertexColor to apply white color unless range check red coloring is applied
        -- Hook Show/SetShown/SetAlpha to enforce hide setting
        if not hotkey._nrsknColorHooked then
            hotkey._nrsknColorHooked = true
            hotkey._nrsknStyled = true
            local meta = getmetatable(hotkey).__index
            local metaSetVertexColor = meta.SetVertexColor
            local metaSetAlpha = meta.SetAlpha
            local metaHide = meta.Hide

            hooksecurefunc(hotkey, "SetVertexColor", function(self, r, g, b, a)
                if not (r and r > 0.9 and g < 0.2 and b < 0.2) then
                    metaSetVertexColor(self, 1, 1, 1, 1)
                end
            end)

            hooksecurefunc(hotkey, "SetAlpha", function(self, alpha)
                if ShouldHideKeybind(button) and alpha > 0 then
                    metaSetAlpha(self, 0)
                end
            end)

            hooksecurefunc(hotkey, "Show", function(self)
                if ShouldHideKeybind(button) then
                    metaHide(self)
                elseif not HasValidKeybindText(self:GetText()) then
                    metaHide(self)
                end
            end)

            hooksecurefunc(hotkey, "SetShown", function(self, shown)
                if shown then
                    if ShouldHideKeybind(button) then
                        metaHide(self)
                    elseif not HasValidKeybindText(self:GetText()) then
                        metaHide(self)
                    end
                end
            end)
        end
        getmetatable(hotkey).__index.SetVertexColor(hotkey, 1, 1, 1, 1)

        -- Hook UpdateHotkeys to reapply styling and enforce hide setting
        if button.UpdateHotkeys and not button._nrsknHotkeyHooked then
            button._nrsknHotkeyHooked = true
            hooksecurefunc(button, 'UpdateHotkeys', function(self)
                local hk = self.HotKey
                if hk and hk._nrsknStyled then
                    local meta = getmetatable(hk).__index
                    local hideKeybind = ShouldHideKeybind(self)
                    local hasValidText = HasValidKeybindText(hk:GetText())

                    if hideKeybind or not hasValidText then
                        meta.SetAlpha(hk, 0)
                        meta.Hide(hk)
                    else
                        meta.Show(hk)
                        meta.SetAlpha(hk, 1)
                        hk:ClearAllPoints()
                        hk:SetPoint(hk._nrsknAnchor, self, hk._nrsknAnchor,
                            hk._nrsknXOffset, hk._nrsknYOffset)
                        hk:SetWidth((self:GetWidth() - 2) or 0)
                        hk:SetFont(hk._nrsknFontPath, hk._nrsknFontSize, hk._nrsknFontOutline)
                        hk:SetWordWrap(false)
                        RemapKeyText(self)
                    end
                end
            end)
        end

        -- Apply hide setting using metatable methods to bypass our own hooks
        local meta = getmetatable(hotkey).__index
        local hasValidText = HasValidKeybindText(hotkey:GetText())

        if textVis.hideKeybindText or not hasValidText then
            meta.SetAlpha(hotkey, 0)
            meta.Hide(hotkey)
        else
            meta.Show(hotkey)
            meta.SetAlpha(hotkey, 1)
            RemapKeyText(button)
        end
    end

    -- Style macro name text or hide if HideMacroText is enabled
    if name then
        if textVis.hideMacroText then
            name:SetAlpha(0)
        else
            name:SetAlpha(1)
            local fontSize = math.max(6, fontSizes.macro)
            name:ClearAllPoints()
            name:SetPoint(textPos.macroAnchor, button, textPos.macroAnchor,
                textPos.macroXOffset, textPos.macroYOffset)
            name:SetFont(fontpath, fontSize, self.db.FontOutline)
            name:SetTextColor(1, 1, 1, 1)
            name:SetShadowColor(0, 0, 0, 0)
            name:SetJustifyH("CENTER")
        end
    end

    -- Style count text or hide if HideChargeText is enabled
    if count then
        if textVis.hideChargeText then
            count:SetAlpha(0)
        else
            count:SetAlpha(1)
            local fontSize = math.max(6, fontSizes.charge)
            count:ClearAllPoints()
            count:SetPoint(textPos.chargeAnchor, button, textPos.chargeAnchor,
                textPos.chargeXOffset, textPos.chargeYOffset)
            count:SetFont(fontpath, fontSize, self.db.FontOutline)
            count:SetTextColor(1, 1, 1, 1)
            count:SetShadowColor(0, 0, 0, 0)
            count:SetJustifyH("RIGHT")
        end
    end
end

-- Button texture styling/hiding
function ACB:StyleButtonTextures(button)
    if not button then return end

    -- Hide blizzard textures we don't need
    NRSKNUI:Hide(button, 'Border')           -- equipped border
    NRSKNUI:Hide(button, 'Flash')            -- red flash when out of mana or unusable
    NRSKNUI:Hide(button, 'NewActionTexture') -- glow texture for new actions
    NRSKNUI:Hide(button, 'SpellHighlightTexture')
    NRSKNUI:Hide(button, 'SlotBackground')   -- Hides the default slot background on action buttons

    -- Hide the normal texture
    local normalTex = button:GetNormalTexture()
    if normalTex then
        normalTex:SetAlpha(0)
    end
    -- Hide checked texture
    if button.CheckedTexture then
        button:GetCheckedTexture():SetColorTexture(0, 0, 0, 0)
    end

    -- Style highlight texture
    if button.HighlightTexture then
        NRSKNUI.DisablePixelSnap(button.HighlightTexture)
        button.HighlightTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.HighlightTexture:SetTexCoord(0, 1, 0, 1)
        button.HighlightTexture:ClearAllPoints()
        button.HighlightTexture:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.HighlightTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.HighlightTexture:SetBlendMode("ADD")
        button.HighlightTexture:SetVertexColor(1, 1, 1, 0.3)
    end

    -- Style pushed texture
    local pushed = button:GetPushedTexture()
    if pushed then
        NRSKNUI.DisablePixelSnap(pushed)
        pushed:SetTexture("Interface\\Buttons\\WHITE8x8")
        pushed:SetTexCoord(0, 1, 0, 1)
        pushed:ClearAllPoints()
        pushed:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        pushed:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        pushed:SetBlendMode("ADD")
        pushed:SetVertexColor(1, 1, 1, 0.4)
    end
end

-- Check if a button has content for empty backdrop handling
local function ButtonHasContent(barName, button)
    if barName == "PetBar" then
        local id = button:GetID()
        local name = GetPetActionInfo(id)
        return name ~= nil
    elseif barName == "StanceBar" then
        local id = button:GetID()
        local texture = GetShapeshiftFormInfo(id)
        return texture ~= nil
    else
        return button.action and C_ActionBar.HasAction(button.action)
    end
end

-- Create backdrop for individual button
function ACB:CreateButtonBackdrop(button, barName, index, buttonSize)
    if not button then return end
    buttonSize = buttonSize or 40

    -- Get bar-specific colors
    local barConfig = self:GetBarConfig(barName)
    local backdropColor = barConfig and barConfig.BackdropColor or { 0, 0, 0, 0.8 }
    local borderColor = barConfig and barConfig.BorderColor or { 0, 0, 0, 1 }

    -- Create backdrop frame with raw integer size (pixel-perfect approach)
    local backdrop = CreateFrame("Frame", "NRSKNUI_" .. barName .. "Backdrop" .. index, UIParent, "BackdropTemplate")
    NRSKNUI.DisablePixelSnap(backdrop)
    backdrop:SetSize(buttonSize, buttonSize)
    backdrop:SetFrameStrata("BACKGROUND")
    backdrop:SetFrameLevel(1)

    -- Apply backdrop with per-bar color
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    backdrop:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3], backdropColor[4] or 0.8)

    -- Create border container at higher frame level
    local borderFrame = CreateFrame("Frame", nil, backdrop)
    borderFrame:SetAllPoints(backdrop)
    borderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 1)
    backdrop._borderFrame = borderFrame

    -- Add borders using helper with textures on borderFrame, stored on backdrop
    NRSKNUI:AddBorders(backdrop, borderColor, borderFrame)
    backdrop._barName = barName

    -- Resize and re-anchor the Blizzard button with raw integer size
    button:SetParent(backdrop)
    button:ClearAllPoints()
    NRSKNUI.DisablePixelSnap(button)
    button:SetSize(buttonSize, buttonSize)
    button:SetPoint("CENTER", backdrop, "CENTER", 0, 0)

    -- Setup empty backdrop visibility tracking
    -- Cache the bar config reference - only changes on settings update
    backdrop._barConfig = barConfig
    backdrop._button = button

    local function UpdateBackdropVisibility()
        -- Always show while dragging
        if ACB.isDraggingSpell then
            backdrop:SetAlpha(1)
            return
        end

        -- Use cached config instead of calling GetBarConfig every time
        local cachedConfig = backdrop._barConfig
        local shouldHideEmpty = cachedConfig and cachedConfig.HideEmptyBackdrops == true

        if shouldHideEmpty then
            if ButtonHasContent(barName, button) then
                backdrop:SetAlpha(1)
            else
                backdrop:SetAlpha(0)
            end
        else
            backdrop:SetAlpha(1)
        end
    end

    -- Hook button updates, only if method exists
    if button.Update then
        hooksecurefunc(button, "Update", UpdateBackdropVisibility)
    end
    if button.UpdateAction then
        hooksecurefunc(button, "UpdateAction", UpdateBackdropVisibility)
    end

    -- Register for action bar updates (individual handlers to avoid taint)
    backdrop:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    backdrop:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    backdrop:SetScript("OnEvent", function(_, event, slot)
        if event == "ACTIONBAR_SLOT_CHANGED" then
            if slot == button.action then
                UpdateBackdropVisibility()
            end
        else
            UpdateBackdropVisibility()
        end
    end)

    -- Initial update
    UpdateBackdropVisibility()
    backdrop._updateVisibility = UpdateBackdropVisibility

    -- Register for config refresh
    ACB:RegisterBackdrop(backdrop)

    -- Hide profession texture if enabled (uses per-bar setting)
    local textVis = self:GetTextVisibility(barName)
    if textVis.hideProfTexture then
        C_Timer.After(0.5, function()
            if button["ProfessionQualityOverlayFrame"] then button["ProfessionQualityOverlayFrame"]:SetAlpha(0) end
        end)
    end

    -- Blizzard elements hide/skin
    if button.SlotArt then button.SlotArt:Hide() end                            -- Hides the default slot background
    if button.IconMask then button.IconMask:Hide() end                          -- Hides the default circular mask on icons
    if button.InterruptDisplay then button.InterruptDisplay:SetAlpha(0) end     -- Hides the "slash" texture for interruptible spells
    if button.SpellCastAnimFrame then button.SpellCastAnimFrame:SetAlpha(0) end -- Hides the "shine" animation
    if button.icon then
        NRSKNUI.DisablePixelSnap(button.icon)
        button.icon:SetAllPoints(button)
    end
    if button.cooldown then
        NRSKNUI.DisablePixelSnap(button.cooldown)
        button.cooldown:SetAllPoints(button)
    end
    if button.SpellHighlightTexture then
        NRSKNUI.DisablePixelSnap(button.SpellHighlightTexture)
        button.SpellHighlightTexture:SetAllPoints(button)
    end
    if button.AutoCastable then button.AutoCastable:SetDrawLayer("OVERLAY", 7) end -- Ensure glow is above the button

    -- Reposition auto cast overlay and shine to match button size
    if button.AutoCastOverlay then
        button.AutoCastOverlay:ClearAllPoints()
        button.AutoCastOverlay:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        button.AutoCastOverlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        if button.AutoCastOverlay.Shine then
            button.AutoCastOverlay.Shine:ClearAllPoints()
            button.AutoCastOverlay.Shine:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            button.AutoCastOverlay.Shine:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        end
    end

    -- Reposition proc glow (SpellActivationAlert) to match button size
    if button.SpellActivationAlert then
        local alert = button.SpellActivationAlert
        local glowOverflow = buttonSize * 0.2
        alert:ClearAllPoints()
        alert:SetPoint("TOPLEFT", button, "TOPLEFT", -glowOverflow, glowOverflow)
        alert:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", glowOverflow, -glowOverflow)
    end

    -- Icon zoom stuff bcs blizz border uggy
    NRSKNUI:ApplyZoom(button.icon, NRSKNUI.GlobalZoom)

    -- Create range overlay, red tint when out of range
    local rangeOverlay = button:CreateTexture(nil, "OVERLAY", nil, 1)
    NRSKNUI.DisablePixelSnap(rangeOverlay)
    rangeOverlay:SetAllPoints(button)
    local rangeColor = self.db.RangeOverlayColor
    rangeOverlay:SetColorTexture(rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4])
    rangeOverlay:Hide()
    button._nrsknRangeOverlay = rangeOverlay

    -- Store reference
    button.nrsknui_backdrop = backdrop
    return backdrop
end

-- Get growth directions from point
local function GetGrowth(point)
    local vertical = (point == "TOPLEFT" or point == "TOPRIGHT") and "DOWN" or "UP"
    local horizontal = (point == "BOTTOMLEFT" or point == "TOPLEFT") and "RIGHT" or "LEFT"
    local anchorUp = vertical == "UP"
    local anchorLeft = horizontal == "LEFT"
    return vertical, horizontal, anchorUp, anchorLeft
end

-- Calculate auto flyout direction based on bar position
local function CalculateAutoFlyoutDirection(container, anchorPoint)
    if not container then return "UP" end

    local width, height = container:GetSize()

    -- If bar is taller than wide (vertical layout), flyout goes left or right
    if width < height then
        if anchorPoint and anchorPoint:find("RIGHT") then
            return "LEFT"
        end
        return "RIGHT"
    end

    -- If bar is wider than tall (horizontal layout), flyout goes up or down
    if anchorPoint and anchorPoint:find("TOP") then
        return "DOWN"
    end
    return "UP"
end

-- Get the effective flyout direction for a bar (resolves AUTO)
local function GetEffectiveFlyoutDirection(barKey, container)
    local barDB = ACB.db and ACB.db.Bars and ACB.db.Bars[barKey]
    if not barDB then return "UP" end

    local direction = barDB.FlyoutDirection or "AUTO"
    if direction == "AUTO" then
        local anchorPoint = barDB.Position and barDB.Position.AnchorPoint or "BOTTOM"
        return CalculateAutoFlyoutDirection(container, anchorPoint)
    end
    return direction
end

-- Set flyout direction on a button
local function SetButtonFlyoutDirection(button, direction)
    if not button or InCombatLockdown() then return end
    button:SetAttribute("flyoutDirection", direction)
end

-- Calculate edge-relative anchor point and offsets from frame position
-- This ensures bars stay in the same relative screen position across resolutions
local function CalculateEdgePosition(frame)
    local centerX, centerY = UIParent:GetCenter()
    local screenWidth = UIParent:GetRight()
    local frameX, frameY = frame:GetCenter()

    if not frameX or not frameY then
        return "BOTTOM", 0, 0
    end

    local point = "BOTTOM"
    local x, y

    if frameY >= centerY then
        point = "TOP"
        y = -(UIParent:GetTop() - frame:GetTop())
    else
        y = frame:GetBottom()
    end

    if frameX >= (screenWidth * 2 / 3) then
        point = point .. "RIGHT"
        x = frame:GetRight() - screenWidth
    elseif frameX <= (screenWidth / 3) then
        point = point .. "LEFT"
        x = frame:GetLeft()
    else
        x = frameX - centerX
    end

    return point, math.floor(x + 0.5), math.floor(y + 0.5)
end

-- Apply edge-relative position to a frame
-- Uses BOTTOMLEFT anchoring internally for pixel-perfect positioning
local function ApplyEdgePosition(frame, anchorPoint, xOffset, yOffset)
    local screenWidth = math.floor(UIParent:GetWidth() + 0.5)
    local screenHeight = math.floor(UIParent:GetHeight() + 0.5)
    local frameWidth, frameHeight = frame:GetSize()
    frameWidth = math.floor(frameWidth + 0.5)
    frameHeight = math.floor(frameHeight + 0.5)

    -- Convert edge-relative anchor to absolute BOTTOMLEFT position
    local left, bottom

    -- Calculate horizontal position
    if anchorPoint:find("LEFT") then
        left = xOffset
    elseif anchorPoint:find("RIGHT") then
        left = screenWidth + xOffset - frameWidth
    else
        left = math.floor(screenWidth / 2) + xOffset - math.floor(frameWidth / 2)
    end

    -- Calculate vertical position
    if anchorPoint:find("BOTTOM") then
        bottom = yOffset
    elseif anchorPoint:find("TOP") then
        bottom = screenHeight + yOffset - frameHeight
    else
        bottom = math.floor(screenHeight / 2) + yOffset - math.floor(frameHeight / 2)
    end

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

-- Position backdrop using raw SetPoint with integer pixel values
-- Uses direct positioning without widget methods to ensure exact pixel alignment
local function PositionBackdrop(bar, backdrop, index, buttonsPerRow, point, buttonSpacing, lastBackdrop, lastRowBackdrop)
    local _, _, anchorUp, anchorLeft = GetGrowth(point)

    local anchorPoint, relFrame, relPoint, x, y

    if index == 1 then
        anchorPoint = point
        relFrame = bar
        relPoint = point
        x, y = 0, 0
    elseif (index - 1) % buttonsPerRow == 0 then
        anchorPoint, relFrame, relPoint, x, y = "TOP", lastRowBackdrop, "BOTTOM", 0, -buttonSpacing
        if anchorUp then
            anchorPoint, relPoint, y = "BOTTOM", "TOP", buttonSpacing
        end
    else
        anchorPoint, relFrame, relPoint, x, y = "LEFT", lastBackdrop, "RIGHT", buttonSpacing, 0
        if anchorLeft then
            anchorPoint, relPoint, x = "RIGHT", "LEFT", -buttonSpacing
        end
    end

    backdrop:ClearAllPoints()
    backdrop:SetPoint(anchorPoint, relFrame, relPoint, x, y)
end

-- Create sizer frame anchored to first/last backdrops
-- Copy sizer's derived size to container
local function SkinBar(cfg)
    if not cfg or not cfg.frame then return end

    local point = cfg.point or "BOTTOMLEFT"
    local buttonSize = cfg.buttonSize
    local buttonSpacing = cfg.spacing
    local numButtons = cfg.totalButtons
    local buttonsPerRow = math.max(1, math.min(cfg.buttonsPerLine, numButtons))

    if numButtons < buttonsPerRow then buttonsPerRow = numButtons end

    local rows = math.ceil(numButtons / buttonsPerRow)
    local columns = buttonsPerRow

    -- Calculate size using raw integer values (pixel-perfect approach)
    local containerWidth = columns * buttonSize + (columns - 1) * buttonSpacing
    local containerHeight = rows * buttonSize + (rows - 1) * buttonSpacing

    -- Create container with size and position
    local container = CreateFrame("Frame", "NRSKNUI_" .. cfg.name .. "_Container", UIParent)
    NRSKNUI.DisablePixelSnap(container)
    container:SetFrameStrata("LOW")
    container:SetSize(containerWidth, containerHeight)
    cfg.nrsknui_container = container

    -- Position using edge-relative anchoring for resolution independence
    local anchorPoint = cfg.anchorPoint or "BOTTOM"
    local xOffset = cfg.x or 0
    local yOffset = cfg.y or 0
    ApplyEdgePosition(container, anchorPoint, xOffset, yOffset)

    -- Mouseover settings
    local mouseoverEnabled = cfg.mouseover and cfg.mouseover.enabled
    container:SetAlpha(mouseoverEnabled and (cfg.mouseover.alpha or 0) or 1)
    container._fadeAlpha = cfg.mouseover and cfg.mouseover.alpha or 0
    container._fadeInDur = cfg.mouseover and cfg.mouseover.fadeInDuration or 0.3
    container._fadeOutDur = cfg.mouseover and cfg.mouseover.fadeOutDuration or 1
    container._mouseoverEnabled = mouseoverEnabled
    container._isMouseOver = false

    -- Track for positioning
    local lastBackdrop = nil
    local lastRowBackdrop = nil

    -- Calculate flyout direction for this bar
    local flyoutDirection = GetEffectiveFlyoutDirection(cfg.name, container)

    for i = 1, numButtons do
        local button = _G[cfg.buttonPrefix .. i]
        if button then
            ACB:StyleButtonTextures(button)
            ACB:StyleButtonText(button, cfg.name)

            -- Set flyout direction on button
            if cfg.name:match("^Bar%d$") then
                SetButtonFlyoutDirection(button, flyoutDirection)
            end

            local backdrop = ACB:CreateButtonBackdrop(button, cfg.name, i, buttonSize)
            if backdrop then
                backdrop:SetParent(container)

                PositionBackdrop(container, backdrop, i, buttonsPerRow, point, buttonSpacing, lastBackdrop,
                    lastRowBackdrop)

                if i == 1 or (i - 1) % buttonsPerRow == 0 then
                    lastRowBackdrop = backdrop
                end
                lastBackdrop = backdrop
            end
        end
    end
end

-- Smoothly fade a frame to target alpha over duration, combat safe
local function CombatSafeFade(frame, targetAlpha, duration)
    if frame._fadeTimer then frame._fadeTimer:Hide() end -- stop previous fade

    local startAlpha = frame:GetAlpha()
    local diff = targetAlpha - startAlpha
    if diff == 0 or duration <= 0 then
        frame:SetAlpha(targetAlpha)
        return
    end

    -- Create a tiny helper frame
    local fadeFrame = frame._fadeTimer or CreateFrame("Frame")
    fadeFrame:Show()
    fadeFrame.elapsed = 0

    fadeFrame:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        local progress = math.min(self.elapsed / duration, 1)
        frame:SetAlpha(startAlpha + diff * progress)
        if progress >= 1 then
            self:Hide()
        end
    end)

    frame._fadeTimer = fadeFrame
end

-- Check if mouse is over the SpellFlyout frame (flyout buttons from action bars)
local function IsMouseOverFlyout()
    local flyout = SpellFlyout
    if not flyout or not flyout:IsShown() then return false end

    local left, bottom, width, height = flyout:GetRect()
    if not left then return false end

    local scale = flyout:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale

    return x >= left and x <= (left + width) and y >= bottom and y <= (bottom + height)
end

-- Mouseover function
-- Uses position-based polling to detect mouse over container without blocking clicks/drags
-- Always sets up the OnUpdate script so mouseover can be toggled dynamically
local function SetupMouseoverScript(container)
    if not container then return end
    if container._mouseoverScriptSetup then return end -- Skip if script already set up
    container._mouseoverScriptSetup = true

    -- Check if mouse is within container bounds or over an open flyout
    local function IsMouseOverContainer()
        -- Check flyout first - if mouse is over flyout, keep the bar visible
        if IsMouseOverFlyout() then return true end

        local left, bottom, width, height = container:GetRect()
        if not left then return false end

        local scale = container:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x, y = x / scale, y / scale

        return x >= left and x <= (left + width) and y >= bottom and y <= (bottom + height)
    end

    -- Fade in function
    local function FadeIn()
        if container._isMouseOver then return end
        if not container._mouseoverEnabled then return end
        container._isMouseOver = true

        -- For pet/stance bars: only fade in if pet/stance is active (nil means not a pet/stance bar)
        if container._hasPetOrStance ~= nil and not container._hasPetOrStance then return end

        local dur = container._fadeInDur or 0.3
        if InCombatLockdown() then
            dur = 0.1 -- Force a faster fade in combat, make more sense to me since you want info faster
        end
        CombatSafeFade(container, 1, dur)
    end

    -- Fade out function
    local function FadeOut()
        if not container._isMouseOver then return end
        container._isMouseOver = false

        -- Don't fade out if bonusbar override is active
        if container._bonusBarActive then return end

        -- Check if mouseover is currently enabled
        if not container._mouseoverEnabled then
            container:SetAlpha(1)
            return
        end

        -- For pet/stance bars: if no pet/stance, stay at 0 (nil means not a pet/stance bar)
        if container._hasPetOrStance ~= nil and not container._hasPetOrStance then
            CombatSafeFade(container, 0, 0.3)
            return
        end

        -- Read current fade alpha from container
        local alpha = container._fadeAlpha or 0
        local dur = container._fadeOutDur or 0.5
        CombatSafeFade(container, alpha, dur)
    end

    -- Polling interval
    local pollInterval = 0.1
    local elapsed = 0

    container:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < pollInterval then return end
        elapsed = 0

        local isOver = IsMouseOverContainer()
        if isOver and not self._isMouseOver then
            FadeIn()
        elseif not isOver and self._isMouseOver then
            FadeOut()
        end
    end)
end

-- Setup vehicle/bonusbar override for Bar1
-- When in a vehicle or dragonriding, always show Bar1 at full alpha
local function SetupBonusBarOverride(bar1Container, db)
    if not bar1Container then return end

    -- Create a hidden frame to use with RegisterStateDriver
    local stateFrame = CreateFrame("Frame", "NRSKNUI_BonusBarStateFrame", UIParent, "SecureHandlerStateTemplate")
    stateFrame:SetSize(1, 1)
    stateFrame:Hide()

    -- Store reference to container and fade alpha
    stateFrame.container = bar1Container
    stateFrame.fadeAlpha = bar1Container._fadeAlpha or 0

    -- State change handler
    stateFrame:SetAttribute("_onstate-bonusbar", [[
        self:CallMethod("OnBonusBarChange", newstate)
    ]])

    -- Callback for state changes
    function stateFrame:OnBonusBarChange(state)
        local container = self.container
        if not container then return end

        -- Clear range overlays and reset keybind colors on Bar1 buttons when state changes
        for i = 1, 12 do
            local button = _G["ActionButton" .. i]
            if button then
                if button._nrsknRangeOverlay then
                    button._nrsknRangeOverlay:Hide()
                end
                if button.HotKey and button.HotKey._nrsknColorHooked then
                    getmetatable(button.HotKey).__index.SetVertexColor(button.HotKey, 1, 1, 1, 1)
                end
            end
        end

        -- Check if override is enabled
        if not container._bonusBarOverrideEnabled then
            container._bonusBarActive = false
            return
        end

        -- In vehicle/bonusbar, force alpha 1
        if state == "vehicle" then
            container._bonusBarActive = true
            CombatSafeFade(container, 1, 0.3)
        else
            -- Normal state, restore appropriate alpha
            container._bonusBarActive = false
            if not container._isMouseOver then
                -- Only apply fade alpha if mouseover is enabled
                if container._mouseoverEnabled then
                    local fadeAlpha = container._fadeAlpha or 0
                    container:SetAlpha(fadeAlpha)
                else
                    container:SetAlpha(1)
                end
            end
        end
    end

    -- Register state driver: detects bonusbar:5 (dragonriding/vehicle) and other vehicle states
    RegisterStateDriver(stateFrame, "bonusbar", "[bonusbar:5][vehicleui][overridebar][possessbar] vehicle; normal")

    -- Store enabled state on container
    bar1Container._bonusBarOverrideEnabled = db.MouseoverOverride == true
    bar1Container._stateFrame = stateFrame
end

-- Toggle bonusbar override on/off dynamically
function ACB:UpdateBonusBarOverride()
    local bar1Container = _G["NRSKNUI_Bar1_Container"]
    if not bar1Container then return end
    local enabled = self.db.MouseoverOverride == true
    bar1Container._bonusBarOverrideEnabled = enabled

    -- If disabling, clear the bonusbar active state and restore proper alpha
    if not enabled then
        bar1Container._bonusBarActive = false
        if not bar1Container._isMouseOver then
            if bar1Container._mouseoverEnabled then
                bar1Container:SetAlpha(bar1Container._fadeAlpha or 0)
            else
                bar1Container:SetAlpha(1)
            end
        end
    else
        -- If enabling, trigger a state check by calling the handler
        if bar1Container._stateFrame and bar1Container._stateFrame.OnBonusBarChange then
            -- Get current state from the state driver
            local currentState = SecureCmdOptionParse("[bonusbar:5][vehicleui][overridebar][possessbar] vehicle; normal")
            bar1Container._stateFrame:OnBonusBarChange(currentState)
        end
    end
end

-- Generic visibility handler for Pet and Stance bars
-- Uses alpha-based visibility so mouseover system continues to work
local function SetupSpecialBarVisibility(container, blizzFrame, events, visibilityCheckFn, barKey)
    if not container then return end

    -- Move the blizzard frame offscreen, this way we can still use it for updates and checks
    if blizzFrame then
        blizzFrame:SetParent(UIParent)
        blizzFrame:ClearAllPoints()
        blizzFrame:SetPoint("TOP", UIParent, "BOTTOM", 0, -500)
        blizzFrame:EnableMouse(false)
    end

    -- Store whether pet/stance is active (separate from mouseover state)
    container._hasPetOrStance = false

    local function UpdateVisibility()
        -- Check if bar is enabled in settings
        local barDB = ACB.db and ACB.db.Bars and ACB.db.Bars[barKey]
        local isEnabled = barDB and barDB.Enabled ~= false
        local hasPetOrStance = isEnabled and visibilityCheckFn()

        container._hasPetOrStance = hasPetOrStance

        -- Determine target alpha based on pet state and mouseover settings
        local targetAlpha
        if not hasPetOrStance then
            -- No pet/stance: always hidden
            targetAlpha = 0
        elseif container._mouseoverEnabled and not container._isMouseOver then
            -- Has pet/stance, mouseover enabled, not hovering: use fade alpha
            targetAlpha = container._fadeAlpha or 0
        else
            -- Has pet/stance, either no mouseover or currently hovering: full visibility
            targetAlpha = 1
        end

        CombatSafeFade(container, targetAlpha, 0.3)
    end

    -- Store the update function so mouseover can call it
    container._updatePetVisibility = UpdateVisibility

    local eventFrame = CreateFrame("Frame")
    for _, event in ipairs(events) do
        eventFrame:RegisterEvent(event)
    end
    eventFrame:SetScript("OnEvent", function()
        UpdateVisibility()
    end)

    -- Initial update
    UpdateVisibility()

    container._visibilityFrame = eventFrame
end

-- Setup PetBar visibility based on whether the player has a pet action bar
local function SetupPetBarVisibility(container)
    SetupSpecialBarVisibility(
        container,
        PetActionBar,
        { "PET_BAR_UPDATE", "UNIT_PET", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST", "PLAYER_FARSIGHT_FOCUS_CHANGED" },
        PetHasActionBar,
        "PetBar"
    )
end

-- Setup StanceBar visibility based on whether the player has shapeshift forms
local function SetupStanceBarVisibility(container)
    SetupSpecialBarVisibility(
        container,
        StanceBar,
        { "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" },
        function() return GetNumShapeshiftForms() > 0 end,
        "StanceBar"
    )
end

-- Register each bar with my custom edit mode
local function RegisterBarWithEditMode(barName, barDB, barContainer)
    local db = barDB
    local frame = barContainer

    local config = {
        key = "ActionBars_" .. barName,
        displayName = barName,
        frame = frame,

        getPosition = function()
            return {
                AnchorFrom = db.Position and db.Position.AnchorPoint or "BOTTOM",
                AnchorTo = db.Position and db.Position.AnchorPoint or "BOTTOM",
                XOffset = (db.Position and db.Position.XOffset) or 0,
                YOffset = (db.Position and db.Position.YOffset) or 0,
            }
        end,

        setPosition = function(pos)
            if not db.Position then db.Position = {} end

            local anchorPoint, x, y

            -- If position values provided, use them directly
            -- Otherwise recalculate from current frame location (used after drag)
            if pos and pos.XOffset and pos.YOffset then
                anchorPoint = pos.AnchorFrom or db.Position.AnchorPoint or "BOTTOM"
                x = pos.XOffset
                y = pos.YOffset
            else
                anchorPoint, x, y = CalculateEdgePosition(frame)
            end

            -- Save edge-relative position
            db.Position.AnchorPoint = anchorPoint
            db.Position.XOffset = x
            db.Position.YOffset = y

            -- Apply the position
            ApplyEdgePosition(frame, anchorPoint, x, y)
        end,

        getParentFrame = function() return UIParent end,

        -- Flag for edit mode to use edge-relative positioning logic
        usesEdgeRelativePositioning = true,

        guiPath = "ActionBars",
        guiContext = barName, -- Pass the bar key
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

-- Migration to edge-relative positioning (resolution-independent)
local function RunEdgeRelativeMigration(db)
    if db.EdgeRelativeMigrationV2 then return end

    local defaults = NRSKNUI:GetDefaultDB()
    local defaultBars = defaults and defaults.profile and defaults.profile.Skinning
        and defaults.profile.Skinning.ActionBars and defaults.profile.Skinning.ActionBars.Bars

    if not defaultBars or not db.Bars then
        db.EdgeRelativeMigrationV2 = true
        return
    end

    -- Reset all bar positions to new edge-relative defaults
    for barKey, defaultBar in pairs(defaultBars) do
        if db.Bars[barKey] and defaultBar.Position then
            db.Bars[barKey].Position = {
                AnchorPoint = defaultBar.Position.AnchorPoint,
                XOffset = defaultBar.Position.XOffset,
                YOffset = defaultBar.Position.YOffset,
            }
        end
    end

    db.EdgeRelativeMigrationV2 = true

    NRSKNUI:CreatePrompt({
        title = "Action Bar Update",
        text = "Action bar positions have been reset for better positioning across different resolutions.",
        onAccept = function() end,
        onCancel = function() end,
        acceptText = "Ok",
        cancelText = "Oke",
    })
end

-- Module OnEnable
function ACB:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end
    RunEdgeRelativeMigration(self.db)

    -- If in combat, defer entire initialization to keep Blizzard bars functional
    if InCombatLockdown() then
        NRSKNUI:DeferUntilUnrestricted(0, function()
            ACB:OnEnable()
        end)
        return
    end

    self:BuildConfigTable()

    -- Delay skinning until after Blizzard's initial setup to avoid taint issues and ensure all elements exist
    C_Timer.After(0.5, function()
        self:InitializeBars()
    end)
end

-- Separated initialization for deferred execution
function ACB:InitializeBars()
    if InCombatLockdown() then
        NRSKNUI:DeferUntilUnrestricted(0, function() ACB:InitializeBars() end)
        return
    end

    self:HideBlizzardBars()

    for _, cfg in ipairs(configTable) do
        SkinBar(cfg)
        SetupMouseoverScript(cfg.nrsknui_container)

        if cfg.enabled then
            RegisterBarWithEditMode(
                cfg.name,
                cfg.dbReference,
                cfg.nrsknui_container
            )
        end

        if cfg.name == "Bar1" and cfg.nrsknui_container then
            SetupBonusBarOverride(cfg.nrsknui_container, self.db)
            self:UpdateBonusBarOverride()
        end

        if cfg.name == "PetBar" and cfg.nrsknui_container then
            SetupPetBarVisibility(cfg.nrsknui_container)
        elseif cfg.name == "StanceBar" and cfg.nrsknui_container then
            SetupStanceBarVisibility(cfg.nrsknui_container)
        end

        if not cfg.enabled and cfg.nrsknui_container then
            cfg.nrsknui_container:Hide()
        end
    end

    C_CVar.SetCVar("countdownForCooldowns", 1)

    C_Timer.After(1, function() ACB:UpdateButtonTexts() end)
    C_Timer.After(2, function() ACB:UpdateButtonTexts() end)

    self:SetupDragDetection()
    self:SetupRangeIndicatorHook()
    self:SetupProcGlowHook()
end

-- Setup hook for proc glow to resize SpellActivationAlert to match button size
function ACB:SetupProcGlowHook()
    if self._procGlowHookSetup then return end
    self._procGlowHookSetup = true

    if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.ShowAlert then
        hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
            if not button or not button.SpellActivationAlert then return end
            if not button.nrsknui_backdrop then return end -- Only for our skinned buttons

            local alert = button.SpellActivationAlert

            -- Hide the proc start animation texture (makes intro invisible)
            if alert.ProcStartFlipbook then
                alert.ProcStartFlipbook:SetAlpha(0)
            end

            -- Resize glow to match button size
            local buttonSize = button:GetWidth()
            local glowOverflow = buttonSize * 0.2
            alert:ClearAllPoints()
            alert:SetPoint("TOPLEFT", button, "TOPLEFT", -glowOverflow, glowOverflow)
            alert:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", glowOverflow, -glowOverflow)
        end)
    end
end

-- Setup hook for range indicator to maintain white keybind color
function ACB:SetupRangeIndicatorHook()
    if self._rangeHookSetup then return end
    self._rangeHookSetup = true

    -- Hook the function that updates the range indicator on action buttons
    hooksecurefunc("ActionButton_UpdateRangeIndicator", function(self, checksRange, inRange)
        local hotkey = self.HotKey
        if not hotkey or not hotkey._nrsknStyled then return end

        -- Update range overlay (keybind color handled by SetVertexColor hook)
        if self._nrsknRangeOverlay then
            if checksRange and not inRange then
                self._nrsknRangeOverlay:Show()
            else
                self._nrsknRangeOverlay:Hide()
            end
        end
    end)
end

-- Helper to iterate all backdrops and call a function on each
local function ForEachBackdrop(callback)
    local bars = { "Bar1", "Bar2", "Bar3", "Bar4", "Bar5", "Bar6", "Bar7", "Bar8", "PetBar", "StanceBar" }
    for _, barKey in ipairs(bars) do
        local i = 1
        while true do
            local backdrop = _G["NRSKNUI_" .. barKey .. "Backdrop" .. i]
            if not backdrop then break end
            callback(backdrop)
            i = i + 1
        end
    end
end

-- Show all backdrops temporarily during drag
function ACB:ShowAllBackdropsTemporary()
    ForEachBackdrop(function(backdrop)
        backdrop:SetAlpha(1)
    end)
end

-- Restore backdrop visibility after drag ends
function ACB:RestoreBackdropVisibility()
    ForEachBackdrop(function(backdrop)
        if backdrop._updateVisibility then
            backdrop._updateVisibility()
        else
            backdrop:SetAlpha(1)
        end
    end)
end

-- Setup drag detection for showing backdrops while dragging spells
function ACB:SetupDragDetection()
    if self.dragFrame then return end

    local dragFrame = CreateFrame("Frame")
    dragFrame:RegisterEvent("ACTIONBAR_SHOWGRID")
    dragFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
    dragFrame:SetScript("OnEvent", function(_, event)
        if event == "ACTIONBAR_SHOWGRID" then
            ACB.isDraggingSpell = true
            ACB:ShowAllBackdropsTemporary()
        elseif event == "ACTIONBAR_HIDEGRID" then
            ACB.isDraggingSpell = false
            ACB:RestoreBackdropVisibility()
        end
    end)

    self.dragFrame = dragFrame
end

-- Update section for GUI changes --

-- Update all button text styles (fonts, sizes, anchors)
function ACB:UpdateButtonTexts()
    for _, cfg in ipairs(configTable) do
        if cfg.enabled then
            for i = 1, cfg.totalButtons do
                local button = _G[cfg.buttonPrefix .. i]
                if button then
                    self:StyleButtonText(button, cfg.name)
                end
            end
        end
    end
end

-- Update profession texture visibility
function ACB:UpdateProfessionTextures()
    for _, cfg in ipairs(configTable) do
        if cfg.enabled then
            local textVis = self:GetTextVisibility(cfg.name)
            local hideProf = textVis.hideProfTexture
            for i = 1, cfg.totalButtons do
                local button = _G[cfg.buttonPrefix .. i]
                if button and button.ProfessionQualityOverlayFrame then
                    button.ProfessionQualityOverlayFrame:SetAlpha(hideProf and 0 or 1)
                end
            end
        end
    end
end

-- Helper to get validated bar data
local function GetBarData(barKey)
    local barDB = ACB.db and ACB.db.Bars and ACB.db.Bars[barKey]
    local container = _G["NRSKNUI_" .. barKey .. "_Container"]
    if not barDB or not container then return nil, nil end
    return barDB, container
end

-- Update container position for a specific bar
function ACB:UpdateBarPosition(barKey)
    local barDB, container = GetBarData(barKey)
    if not barDB or not container then return end

    -- Use edge-relative positioning for resolution independence
    local anchorPoint = barDB.Position and barDB.Position.AnchorPoint or "BOTTOM"
    local x = barDB.Position and barDB.Position.XOffset or 0
    local y = barDB.Position and barDB.Position.YOffset or 0

    ApplyEdgePosition(container, anchorPoint, x, y)
end

-- Update all bar positions
function ACB:UpdateAllPositions()
    for barKey, _ in pairs(BAR_FRAME_MAP) do
        self:UpdateBarPosition(barKey)
    end
end

-- Update mouseover settings for a specific bar
function ACB:UpdateBarMouseover(barKey)
    local barDB, container = GetBarData(barKey)
    if not barDB or not container then return end

    local globalMouseover = self.db.Mouseover or {}
    local useGlobal = barDB.Mouseover and barDB.Mouseover.GlobalOverride == true

    local mouseoverEnabled, mouseoverAlpha, fadeInDur, fadeOutDur
    if useGlobal then
        mouseoverEnabled = globalMouseover.Enabled == true
        mouseoverAlpha = globalMouseover.Alpha or 0
        fadeInDur = globalMouseover.FadeInDuration or 0.3
        fadeOutDur = globalMouseover.FadeOutDuration or 1
    else
        mouseoverEnabled = barDB.Mouseover and barDB.Mouseover.Enabled == true
        mouseoverAlpha = (barDB.Mouseover and barDB.Mouseover.Alpha) or 0
        -- Per-bar uses global fade durations
        fadeInDur = globalMouseover.FadeInDuration or 0.3
        fadeOutDur = globalMouseover.FadeOutDuration or 1
    end

    -- Update all container mouseover settings
    container._fadeAlpha = mouseoverAlpha
    container._fadeInDur = fadeInDur
    container._fadeOutDur = fadeOutDur
    container._mouseoverEnabled = mouseoverEnabled

    -- If not currently moused over, apply the appropriate alpha
    if not container._isMouseOver and not container._bonusBarActive then
        -- For pet/stance bars: respect the pet/stance state
        if container._hasPetOrStance ~= nil and not container._hasPetOrStance then
            container:SetAlpha(0)
        elseif mouseoverEnabled then
            container:SetAlpha(mouseoverAlpha)
        else
            container:SetAlpha(1)
        end
    end
end

-- Update all mouseover settings
function ACB:UpdateAllMouseover()
    for barKey, _ in pairs(BAR_FRAME_MAP) do
        self:UpdateBarMouseover(barKey)
    end
end

function ACB:UpdateBarLayout(barKey)
    local barDB, container = GetBarData(barKey)
    if not barDB or not container then return end

    local buttonSize = barDB.ButtonSize or 40
    local buttonSpacing = barDB.Spacing or 1
    local totalButtons = barDB.TotalButtons or 12
    local buttonsPerRow = math.max(1, math.min(barDB.ButtonsPerLine or 12, totalButtons))
    local frameInfo = BAR_FRAME_MAP[barKey]

    -- Determine point from layout and growth direction
    local layout = barDB.Layout or "HORIZONTAL"
    local growth = barDB.GrowthDirection or "RIGHT"
    local point
    if layout == "HORIZONTAL" then
        point = (growth == "LEFT") and "BOTTOMRIGHT" or "BOTTOMLEFT"
    else
        point = (growth == "LEFT") and "TOPRIGHT" or "TOPLEFT"
    end

    -- Calculate container size using raw integer values (pixel-perfect approach)
    if totalButtons < buttonsPerRow then buttonsPerRow = totalButtons end
    local rows = math.ceil(totalButtons / buttonsPerRow)
    local columns = buttonsPerRow

    local containerWidth = columns * buttonSize + (columns - 1) * buttonSpacing
    local containerHeight = rows * buttonSize + (rows - 1) * buttonSpacing
    container:SetSize(containerWidth, containerHeight)

    -- Track for relative positioning
    local lastBackdrop = nil
    local lastRowBackdrop = nil

    -- Update visible buttons and their backdrops using widget methods with UNSCALED values
    for i = 1, totalButtons do
        local button = _G[frameInfo.prefix .. i]
        if button then
            local backdrop = button.nrsknui_backdrop

            -- Create backdrop if it doesn't exist (use UNSCALED size)
            if not backdrop then
                self:StyleButtonTextures(button)
                self:StyleButtonText(button, barKey)
                backdrop = self:CreateButtonBackdrop(button, barKey, i, buttonSize)
                if backdrop then
                    backdrop:SetParent(container)
                end
            end

            -- If backdrop exist, style it with new settings
            if backdrop then
                backdrop:Show()

                -- Update sizes using raw SetSize (pixel-perfect approach)
                button:SetSize(buttonSize, buttonSize)
                backdrop:SetSize(buttonSize, buttonSize)

                -- Position using raw SetPoint via PositionBackdrop
                PositionBackdrop(container, backdrop, i, buttonsPerRow, point, buttonSpacing, lastBackdrop,
                    lastRowBackdrop)

                -- Track for next iteration
                if i == 1 or (i - 1) % buttonsPerRow == 0 then
                    lastRowBackdrop = backdrop
                end
                lastBackdrop = backdrop

                -- Update icon and cooldown to match new size
                if button.icon then
                    NRSKNUI.DisablePixelSnap(button.icon)
                    button.icon:SetAllPoints(button)
                end
                if button.cooldown then
                    NRSKNUI.DisablePixelSnap(button.cooldown)
                    button.cooldown:SetAllPoints(button)
                end
                if button.SpellHighlightTexture then
                    NRSKNUI.DisablePixelSnap(button.SpellHighlightTexture)
                    button.SpellHighlightTexture:SetAllPoints(button)
                end

                -- Update proc glow to match new size
                if button.SpellActivationAlert then
                    local glowOverflow = math.floor(buttonSize * 0.2 + 0.5)
                    button.SpellActivationAlert:ClearAllPoints()
                    button.SpellActivationAlert:SetPoint("TOPLEFT", button, "TOPLEFT", -glowOverflow, glowOverflow)
                    button.SpellActivationAlert:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", glowOverflow,
                        -glowOverflow)
                end

                -- Re-style text elements with new size
                self:StyleButtonText(button, barKey)
            end
        end
    end

    -- Hide backdrops for buttons beyond totalButtons
    for i = totalButtons + 1, 12 do
        local button = _G[frameInfo.prefix .. i]
        if button and button.nrsknui_backdrop then
            button.nrsknui_backdrop:Hide()
        end
    end
end

-- Update all bar layouts
function ACB:UpdateAllLayouts()
    for barKey, _ in pairs(BAR_FRAME_MAP) do
        self:UpdateBarLayout(barKey)
    end
end

-- Update flyout direction for a specific bar
function ACB:UpdateBarFlyoutDirection(barKey)
    if InCombatLockdown() then return end

    local barDB, container = GetBarData(barKey)
    if not barDB or not container then return end

    -- Only update for main action bars (Bar1-Bar8)
    if not barKey:match("^Bar%d$") then return end

    local frameInfo = BAR_FRAME_MAP[barKey]
    if not frameInfo then return end

    local flyoutDirection = GetEffectiveFlyoutDirection(barKey, container)

    for i = 1, 12 do
        local button = _G[frameInfo.prefix .. i]
        if button then
            SetButtonFlyoutDirection(button, flyoutDirection)
        end
    end
end

-- Update flyout direction for all bars
function ACB:UpdateAllFlyoutDirections()
    for barKey, _ in pairs(BAR_FRAME_MAP) do
        self:UpdateBarFlyoutDirection(barKey)
    end
end

-- Toggle bar visibility and edit mode registration
function ACB:UpdateBarEnabled(barKey)
    local barDB, container = GetBarData(barKey)
    if not barDB or not container then return end

    if barDB.Enabled then
        -- For pet/stance bars, trigger their visibility update instead of Show()
        if container._updatePetVisibility then
            container._updatePetVisibility()
        else
            container:Show()
        end
        -- Register with edit mode when enabled
        RegisterBarWithEditMode(barKey, barDB, container)
    else
        -- For pet/stance bars, trigger visibility update (will set alpha to 0)
        if container._updatePetVisibility then
            container._updatePetVisibility()
        else
            container:Hide()
        end
        -- Unregister from edit mode when disabled
        NRSKNUI.EditMode:UnregisterElement("ActionBars_" .. barKey)
    end
end

-- Main update function, called from GUI
-- updateType can be: "all", "fonts", "positions", "mouseover", "layout", "flyout", "bar"
-- barKey is optional, used when updating a specific bar
-- This way i can do targeted updates in the GUI instead of always doing a full update
function ACB:UpdateSettings(updateType, barKey)
    if not self:IsEnabled() then return end
    updateType = updateType or "all"

    if updateType == "all" then
        self:UpdateButtonTexts()
        self:UpdateAllPositions()
        self:UpdateAllMouseover()
        self:UpdateAllLayouts()
        self:UpdateProfessionTextures()
        self:UpdateAllFlyoutDirections()
    elseif updateType == "fonts" then
        self:UpdateButtonTexts()
    elseif updateType == "positions" then
        if barKey then
            self:UpdateBarPosition(barKey)
        else
            self:UpdateAllPositions()
        end
    elseif updateType == "mouseover" then
        if barKey then
            self:UpdateBarMouseover(barKey)
        else
            self:UpdateAllMouseover()
        end
    elseif updateType == "layout" then
        if barKey then
            self:UpdateBarLayout(barKey)
        else
            self:UpdateAllLayouts()
        end
    elseif updateType == "flyout" then
        if barKey then
            self:UpdateBarFlyoutDirection(barKey)
        else
            self:UpdateAllFlyoutDirections()
        end
    elseif updateType == "enabled" and barKey then
        self:UpdateBarEnabled(barKey)
    elseif updateType == "profTextures" then
        self:UpdateProfessionTextures()
    elseif updateType == "backdrops" then
        if barKey then
            self:UpdateBarBackdropColors(barKey)
        else
            self:UpdateAllBackdropColors()
        end
    elseif updateType == "rangeOverlay" then
        self:UpdateRangeOverlayColor()
    end
end

function ACB:UpdateRangeOverlayColor()
    local color = self.db.RangeOverlayColor or { 1, 0, 0, 0.2 }
    for _, barInfo in pairs(BAR_FRAME_MAP) do
        local prefix = barInfo.prefix
        local i = 1
        while true do
            local button = _G[prefix .. i]
            if not button then break end
            if button._nrsknRangeOverlay then
                button._nrsknRangeOverlay:SetColorTexture(color[1], color[2], color[3], color[4])
            end
            i = i + 1
        end
    end
end

-- Hide Blizzard bar frames, called on enable and profile changes
function ACB:HideBlizzardBars()
    -- Hide special bars
    if PetActionBar then
        PetActionBar:SetParent(UIParent)
        PetActionBar:ClearAllPoints()
        PetActionBar:SetPoint("TOP", UIParent, "BOTTOM", 0, -500)
        PetActionBar:EnableMouse(false)
    end
    if StanceBar then
        StanceBar:SetParent(UIParent)
        StanceBar:ClearAllPoints()
        StanceBar:SetPoint("TOP", UIParent, "BOTTOM", 0, -500)
        StanceBar:EnableMouse(false)
    end

    -- Hide regular Blizzard bar frames by yeeting them outside the screen
    local blizzBars = { "MultiBar5", "MultiBar6", "MultiBar7" }
    for _, barName in ipairs(blizzBars) do
        local frame = _G[barName]
        if frame then
            frame:SetParent(UIParent)
            frame:ClearAllPoints()
            frame:SetPoint("TOP", UIParent, "BOTTOM", 0, -500)
            frame:EnableMouse(false)
        end
    end
end

-- Apply all settings, standard module interface
function ACB:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    C_Timer.After(0.1, function()
        if InCombatLockdown() then
            NRSKNUI:DeferUntilUnrestricted(0, function()
                ACB:ApplySettings()
            end)
            return
        end
        self:HideBlizzardBars()

        -- Rebuild config with new profile settings
        self:BuildConfigTable()

        -- Update existing containers and handle enabled state
        for barKey, _ in pairs(BAR_FRAME_MAP) do
            local barDB = self.db.Bars and self.db.Bars[barKey]
            local container = _G["NRSKNUI_" .. barKey .. "_Container"]

            if container then
                -- For pet/stance bars (which use alpha-based visibility), trigger their visibility update
                if container._updatePetVisibility then
                    container._updatePetVisibility()
                elseif barDB and barDB.Enabled then
                    -- Regular bars: show/hide based on enabled state
                    container:Show()
                else
                    container:Hide()
                end
            end
        end

        self:UpdateSettings("all")
        self:UpdateAllBackdropColors()
        self:RefreshBackdropConfigs()
    end)
end

-- Update backdrop colors and visibility for a bar
function ACB:UpdateBarBackdropColors(barKey)
    local barConfig = self:GetBarConfig(barKey)
    if not barConfig then return end

    local backdropColor = barConfig.BackdropColor or { 0, 0, 0, 0.8 }
    local borderColor = barConfig.BorderColor or { 0, 0, 0, 1 }
    local hideEmpty = barConfig.HideEmptyBackdrops == true

    -- Find all backdrops for this bar
    local i = 1
    while true do
        local backdrop = _G["NRSKNUI_" .. barKey .. "Backdrop" .. i]
        if not backdrop then break end

        -- Update backdrop color
        backdrop:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3], backdropColor[4] or 0.8)

        -- Update border colors
        backdrop:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

        -- Update visibility based on HideEmptyBackdrops setting
        if backdrop._updateVisibility and hideEmpty then
            backdrop._updateVisibility()
        elseif not hideEmpty then
            backdrop:SetAlpha(1)
        end

        i = i + 1
    end
end

-- Update all bar backdrop colors
function ACB:UpdateAllBackdropColors()
    local bars = { "Bar1", "Bar2", "Bar3", "Bar4", "Bar5", "Bar6", "Bar7", "Bar8", "PetBar", "StanceBar" }
    for _, barKey in ipairs(bars) do
        self:UpdateBarBackdropColors(barKey)
    end
end
