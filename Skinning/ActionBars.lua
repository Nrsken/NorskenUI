-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("ActionBars: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local ACB = NRSKNUI.Addon:NewModule("ActionBars", "AceEvent-3.0")

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

    -- Return config
    return {
        name = barKey,
        dbReference = barDB,
        frame = frame,
        buttonPrefix = frameInfo.prefix,
        spacing = barDB.Spacing or 1,
        buttonSize = barDB.ButtonSize or 40,
        totalButtons = barDB.TotalButtons or 12,
        layout = barDB.Layout or "HORIZONTAL",
        growthDirection = barDB.GrowthDirection or "RIGHT",
        buttonsPerLine = barDB.ButtonsPerLine or 12,
        anchorFrom = barDB.Position and barDB.Position.AnchorFrom or "BOTTOM",
        relativeTo = _G[barDB.ParentFrame] or UIParent,
        anchorTO = barDB.Position and barDB.Position.AnchorTo or "BOTTOM",
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

-- Module init
function ACB:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.ActionBars
    self:SetEnabledState(false)
end

-- Build configTable from DB, called on enable so DB is ready
-- This way i only need to create defaults once in the Core/Defaults.lua
function ACB:BuildConfigTable()
    configTable = {}
    if not self.db or not self.db.Bars then return end
    local globalMouseover = self.db.Mouseover or {}

    -- Build config for each bar defined in BAR_FRAME_MAP
    for barKey, _ in pairs(BAR_FRAME_MAP) do
        BlizzBarMouseToggle(barKey)
        local barDB = self.db.Bars[barKey]
        if barDB then
            local cfg = BuildBarConfig(barKey, barDB, globalMouseover)
            if cfg then
                table_insert(configTable, cfg)
            end
        end
    end
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

-- Style button texts
function ACB:StyleButtonText(button, barKey)
    if not button then return end
    local hotkey = button.HotKey
    local name = button.Name
    local count = button.Count
    local cooldown = button.cooldown
    local fontpath = NRSKNUI:GetFontPath(self.db.FontFace)

    -- Get font sizes and text positions for this bar
    local fontSizes = self:GetFontSizes(barKey)
    local textPos = self:GetTextPositions(barKey)

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

    -- Style keybind text
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

        -- Store original info for later use in hooks, so we can reapply styling and positioning when hotkeys are updated
        hotkey._nrsknAnchor = textPos.keybindAnchor
        hotkey._nrsknXOffset = textPos.keybindXOffset
        hotkey._nrsknYOffset = textPos.keybindYOffset
        hotkey._nrsknFontPath = fontpath
        hotkey._nrsknFontSize = fontSize
        hotkey._nrsknFontOutline = self.db.FontOutline

        -- Hook SetVertexColor to apply white color unless range check red coloring is applied
        -- Uses metatable method instead of normal hooksecurefunc, infinite loop otherwise
        if not hotkey._nrsknColorHooked then
            hotkey._nrsknColorHooked = true
            hotkey._nrsknStyled = true
            local metaSetVertexColor = getmetatable(hotkey).__index.SetVertexColor
            hooksecurefunc(hotkey, "SetVertexColor", function(self, r, g, b, a)
                if not (r and r > 0.9 and g < 0.2 and b < 0.2) then
                    metaSetVertexColor(self, 1, 1, 1, 1)
                end
            end)
        end
        -- Set white color initially
        getmetatable(hotkey).__index.SetVertexColor(hotkey, 1, 1, 1, 1)

        -- Hook UpdateHotkeys to reapply styling and remap text whenever hotkeys are updated
        -- such as when changing bindings or action paging
        if button.UpdateHotkeys and not button._nrsknHotkeyHooked then
            button._nrsknHotkeyHooked = true
            hooksecurefunc(button, 'UpdateHotkeys', function(self)
                local hk = self.HotKey
                if hk and hk._nrsknStyled then
                    hk:ClearAllPoints()
                    hk:SetPoint(hk._nrsknAnchor, self, hk._nrsknAnchor,
                        hk._nrsknXOffset, hk._nrsknYOffset)
                    hk:SetWidth((self:GetWidth() - 2) or 0)
                    hk:SetFont(hk._nrsknFontPath, hk._nrsknFontSize, hk._nrsknFontOutline)
                    hk:SetWordWrap(false)
                end
                RemapKeyText(self)
            end)
        end
        RemapKeyText(button)
    end

    -- Style macro name text or hide if HideMacroText is enabled
    if name then
        if self.db.HideMacroText then
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

    -- Style count text
    if count then
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
        return button.action and HasAction(button.action)
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

    -- Create backdrop frame with dynamic name
    local backdrop = CreateFrame("Frame", "NRSKNUI_" .. barName .. "Backdrop" .. index, UIParent, "BackdropTemplate")
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

    -- Resize and re-anchor the Blizzard button to backdrop
    button:SetParent(backdrop)
    button:ClearAllPoints()
    button:SetSize(buttonSize, buttonSize)
    button:SetPoint("CENTER", backdrop, "CENTER", 0, 0)

    -- Setup empty backdrop visibility tracking
    -- Always set up tracking so it can be toggled on/off without reload
    local function UpdateBackdropVisibility()
        -- Always show while dragging
        if ACB.isDraggingSpell then
            backdrop:SetAlpha(1)
            return
        end

        local currentConfig = self:GetBarConfig(barName)
        local shouldHideEmpty = currentConfig and currentConfig.HideEmptyBackdrops == true

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

    -- Register for action bar updates
    backdrop:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    backdrop:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    backdrop:SetScript("OnEvent", function(self, event, slot)
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

    -- Hide profession texture if enabled in GUI
    if self.db.HideProfTexture then
        C_Timer.After(0.5, function()
            if button["ProfessionQualityOverlayFrame"] then button["ProfessionQualityOverlayFrame"]:SetAlpha(0) end
        end)
    end

    -- Blizzard elements hide/skin
    if button.SlotArt then button.SlotArt:Hide() end                                           -- Hides the default slot background
    if button.IconMask then button.IconMask:Hide() end                                         -- Hides the default circular mask on icons
    if button.InterruptDisplay then button.InterruptDisplay:SetAlpha(0) end                    -- Hides the "slash" texture for interruptible spells
    if button.SpellCastAnimFrame then button.SpellCastAnimFrame:SetAlpha(0) end                -- Hides the "shine" animation
    if button.icon then button.icon:SetAllPoints(button) end                                   -- Resize the icon to fit properly
    if button.cooldown then button.cooldown:SetAllPoints(button) end                           -- Fix cooldown/GCD swipe to match button size
    if button.SpellHighlightTexture then button.SpellHighlightTexture:SetAllPoints(button) end -- Fix action bar glow (proc highlights)
    if button.AutoCastable then button.AutoCastable:SetDrawLayer("OVERLAY", 7) end             -- Ensure glow is above the button

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

    -- Icon zoom stuff bcs blizz border uggy
    NRSKNUI:ApplyZoom(button.icon, 0.6)

    -- Create range overlay, red tint when out of range
    local rangeOverlay = button:CreateTexture(nil, "OVERLAY", nil, 1)
    rangeOverlay:SetAllPoints(button)
    rangeOverlay:SetColorTexture(1, 0, 0, 0.2)
    rangeOverlay:Hide()
    button._nrsknRangeOverlay = rangeOverlay

    -- Store reference
    button.nrsknui_backdrop = backdrop
    return backdrop
end

-- Calculate button position based on layout
local function CalculateButtonPosition(index, layout, columns, rows, growLeft, buttonSize, spacing)
    local col, row
    if layout == "HORIZONTAL" then
        col = index % columns
        row = math.floor(index / columns)
    else
        row = index % rows
        col = math.floor(index / rows)
    end
    local dx = (growLeft and (columns - 1 - col) or col) * (buttonSize + spacing)
    local dy = -(row * (buttonSize + spacing))
    return dx, dy
end

-- Layout function, supports vertical and horizontal grid
local function SkinBar(cfg)
    if not cfg or not cfg.frame then return end
    local buttonsPerLine = math.max(1, math.min(cfg.buttonsPerLine, cfg.totalButtons))
    local growLeft = cfg.growthDirection == "LEFT"

    -- Calculate grid dimensions based on layout
    local columns, rows
    if cfg.layout == "HORIZONTAL" then
        columns = buttonsPerLine
        rows = math.ceil(cfg.totalButtons / columns)
    else
        rows = buttonsPerLine
        columns = math.ceil(cfg.totalButtons / rows)
    end

    -- Create container
    local container = CreateFrame("Frame", "NRSKNUI_" .. cfg.name .. "_Container", UIParent)
    container:SetSize(columns * cfg.buttonSize + (columns - 1) * cfg.spacing,
        rows * cfg.buttonSize + (rows - 1) * cfg.spacing)
    container:SetPoint(cfg.anchorFrom, cfg.relativeTo, cfg.anchorTO, cfg.x, cfg.y)
    container:SetFrameStrata("LOW")

    -- Initialize mouseover settings
    local mouseoverEnabled = cfg.mouseover and cfg.mouseover.enabled
    container:SetAlpha(mouseoverEnabled and (cfg.mouseover.alpha or 0) or 1)
    container._fadeAlpha = cfg.mouseover and cfg.mouseover.alpha or 0
    container._fadeInDur = cfg.mouseover and cfg.mouseover.fadeInDuration or 0.3
    container._fadeOutDur = cfg.mouseover and cfg.mouseover.fadeOutDuration or 1
    container._mouseoverEnabled = mouseoverEnabled
    container._isMouseOver = false
    cfg.nrsknui_container = container

    -- Iterate through buttons and lay them out
    for i = 1, cfg.totalButtons do
        local button = _G[cfg.buttonPrefix .. i]
        if button then
            ACB:StyleButtonTextures(button)
            ACB:StyleButtonText(button, cfg.name)

            local backdrop = ACB:CreateButtonBackdrop(button, cfg.name, i, cfg.buttonSize)
            if backdrop then
                backdrop:SetParent(container)
                local dx, dy = CalculateButtonPosition(i - 1, cfg.layout, columns, rows, growLeft, cfg.buttonSize,
                    cfg.spacing)
                backdrop:ClearAllPoints()
                backdrop:SetPoint("TOPLEFT", container, "TOPLEFT", dx, dy)
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

-- Mouseover function
-- Uses position-based polling to detect mouse over container without blocking clicks/drags
-- Always sets up the OnUpdate script so mouseover can be toggled dynamically
local function SetupMouseoverScript(container)
    if not container then return end
    if container._mouseoverScriptSetup then return end -- Skip if script already set up
    container._mouseoverScriptSetup = true

    -- Check if mouse is within container bounds
    local function IsMouseOverContainer()
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
local function SetupSpecialBarVisibility(container, blizzFrame, events, visibilityCheckFn)
    if not container then return end

    -- Move the blizzard frame offscreen, this way we can still use it for updates and checks
    if blizzFrame then
        blizzFrame:SetParent(UIParent)
        blizzFrame:ClearAllPoints()
        blizzFrame:SetPoint("TOP", UIParent, "BOTTOM", 0, -500)
        blizzFrame:EnableMouse(false)
    end

    local pendingUpdate = false
    local function UpdateVisibility()
        if InCombatLockdown() then
            pendingUpdate = true
            return
        end

        pendingUpdate = false
        if visibilityCheckFn() then
            container:Show()
        else
            container:Hide()
        end
    end

    local eventFrame = CreateFrame("Frame")
    for _, event in ipairs(events) do
        eventFrame:RegisterEvent(event)
    end
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingUpdate then
                UpdateVisibility()
            end
        else
            UpdateVisibility()
        end
    end)

    if not InCombatLockdown() then
        UpdateVisibility()
    else
        pendingUpdate = true
    end

    container._visibilityFrame = eventFrame
end

-- Setup PetBar visibility based on whether the player has a pet action bar
local function SetupPetBarVisibility(container)
    SetupSpecialBarVisibility(
        container,
        PetActionBar,
        { "PET_BAR_UPDATE", "UNIT_PET", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST", "PLAYER_FARSIGHT_FOCUS_CHANGED" },
        PetHasActionBar
    )
end

-- Setup StanceBar visibility based on whether the player has shapeshift forms
local function SetupStanceBarVisibility(container)
    SetupSpecialBarVisibility(
        container,
        StanceBar,
        { "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" },
        function() return GetNumShapeshiftForms() > 0 end
    )
end

-- Register each bar with my custom edit mode
local function RegisterBarWithEditMode(barName, barDB, barContainer, relativeTo)
    local db = barDB
    local frame = barContainer
    local rel = relativeTo or UIParent

    local config = {
        key = "ActionBars_" .. barName,
        displayName = barName,
        frame = frame,

        getPosition = function()
            -- Pulling directly from the locked 'db' reference
            return {
                AnchorFrom = (db.Position and db.Position.AnchorFrom) or "CENTER",
                AnchorTo = (db.Position and db.Position.AnchorTo) or "CENTER",
                XOffset = (db.Position and db.Position.XOffset) or 0,
                YOffset = (db.Position and db.Position.YOffset) or 0,
            }
        end,

        setPosition = function(pos)
            if not db.Position then db.Position = {} end

            -- Update the SavedVariables
            db.Position.AnchorFrom = pos.AnchorFrom
            db.Position.AnchorTo = pos.AnchorTo
            db.Position.XOffset = pos.XOffset
            db.Position.YOffset = pos.YOffset

            -- Apply to frame
            frame:ClearAllPoints()
            frame:SetPoint(pos.AnchorFrom, rel, pos.AnchorTo, pos.XOffset, pos.YOffset)
        end,

        getParentFrame = function()
            -- Return the captured relativeTo or get current from db
            local parentName = db.ParentFrame
            if parentName and _G[parentName] then
                return _G[parentName]
            end
            return rel
        end,

        guiPath = "ActionBars",
        guiContext = barName, -- Pass the bar key
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

-- Module OnEnable
function ACB:OnEnable()
    if not self.db.Enabled then return end
    self:BuildConfigTable()

    -- Delay skinning until after Blizzard's initial setup to avoid taint issues and ensure all elements exist
    C_Timer.After(0.5, function()
        for _, cfg in ipairs(configTable) do
            if cfg.enabled then
                SkinBar(cfg)
                SetupMouseoverScript(cfg.nrsknui_container)
                RegisterBarWithEditMode(
                    cfg.name,
                    cfg.dbReference,
                    cfg.nrsknui_container,
                    cfg.relativeTo
                )

                -- Setup bonusbar override for Bar1
                if cfg.name == "Bar1" and cfg.nrsknui_container then
                    SetupBonusBarOverride(cfg.nrsknui_container, self.db)
                    self:UpdateBonusBarOverride() -- Send an update incase player is mounted when loading in
                end

                -- Setup visibility handling for Pet and Stance bars
                if cfg.name == "PetBar" and cfg.nrsknui_container then
                    SetupPetBarVisibility(cfg.nrsknui_container)
                elseif cfg.name == "StanceBar" and cfg.nrsknui_container then
                    SetupStanceBarVisibility(cfg.nrsknui_container)
                end
            end
        end

        -- Disable native actionbars
        for i = 2, 8 do
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. i, false)
        end
        C_CVar.SetCVar("countdownForCooldowns", 1)
        SettingsPanel:CommitSettings(true)

        -- Re-apply styling after delays to catch Blizzard's late initialization
        C_Timer.After(1, function() ACB:UpdateButtonTexts() end)
        C_Timer.After(2, function() ACB:UpdateButtonTexts() end)

        -- Setup drag detection and rangeindicator hook
        self:SetupDragDetection()
        self:SetupRangeIndicatorHook()
    end)
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
    local hideProf = self.db.HideProfTexture
    for _, cfg in ipairs(configTable) do
        if cfg.enabled then
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

    local anchor = barDB.Position and barDB.Position.AnchorFrom or "BOTTOM"
    local relTo = _G[barDB.ParentFrame] or UIParent
    local relPt = barDB.Position and barDB.Position.AnchorTo or "BOTTOM"
    local x = barDB.Position and barDB.Position.XOffset or 0
    local y = barDB.Position and barDB.Position.YOffset or 0

    container:ClearAllPoints()
    container:SetPoint(anchor, relTo, relPt, x, y)
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
        if mouseoverEnabled then
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

-- Update bar size and layout, requires more complex update
function ACB:UpdateBarLayout(barKey)
    local barDB, container = GetBarData(barKey)
    if not barDB or not container then return end

    local buttonSize = barDB.ButtonSize or 40
    local spacing = barDB.Spacing or 1
    local totalButtons = barDB.TotalButtons or 12
    local layout = barDB.Layout or "HORIZONTAL"
    local growthDirection = barDB.GrowthDirection or "RIGHT"
    local growLeft = growthDirection == "LEFT"
    local buttonsPerLine = math.max(1, math.min(barDB.ButtonsPerLine or 12, totalButtons))
    local frameInfo = BAR_FRAME_MAP[barKey]

    -- Calculate new container size
    local columns, rows
    if layout == "HORIZONTAL" then
        columns = buttonsPerLine
        rows = math.ceil(totalButtons / columns)
    else
        rows = buttonsPerLine
        columns = math.ceil(totalButtons / rows)
    end
    container:SetSize(
        columns * buttonSize + (columns - 1) * spacing,
        rows * buttonSize + (rows - 1) * spacing
    )

    -- Update visible buttons and their backdrops
    for i = 1, totalButtons do
        local button = _G[frameInfo.prefix .. i]
        if button then
            local backdrop = button.nrsknui_backdrop

            -- Create backdrop if it doesn't exist
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
                -- Show backdrop for visible buttons
                backdrop:Show()

                -- Update button size
                button:SetSize(buttonSize, buttonSize)
                backdrop:SetSize(buttonSize, buttonSize)

                -- Recalculate position using helper
                local dx, dy = CalculateButtonPosition(i - 1, layout, columns, rows, growLeft, buttonSize, spacing)
                backdrop:ClearAllPoints()
                backdrop:SetPoint("TOPLEFT", container, "TOPLEFT", dx, dy)

                -- Update icon and cooldown to match new size
                if button.icon then button.icon:SetAllPoints(button) end
                if button.cooldown then button.cooldown:SetAllPoints(button) end
                if button.SpellHighlightTexture then button.SpellHighlightTexture:SetAllPoints(button) end

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

-- Toggle bar visibility
function ACB:UpdateBarEnabled(barKey)
    local barDB, container = GetBarData(barKey)
    if not barDB or not container then return end

    if barDB.Enabled then
        container:Show()
    else
        container:Hide()
    end
end

-- Main update function, called from GUI
-- updateType can be: "all", "fonts", "positions", "mouseover", "layout", "bar"
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
    end
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