-- NorskenUI namespace
local _, NRSKNUI = ...

-- TODO: Revisit keybind coloring, not done properly and gets overriden by blizzy

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
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
local PetHasActionBar = PetHasActionBar
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetCursorPosition = GetCursorPosition
local pcall = pcall
local SecureCmdOptionParse = SecureCmdOptionParse
local hooksecurefunc = hooksecurefunc
local GetPetActionInfo = GetPetActionInfo
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
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

    -- Determine mouseover settings (use global if globalOverride is true)
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

-- Remap keybind text to shorter versions
-- For example "Middle Mouse" becomes "M3"
local function RemapKeyText(text)
    if not text or text == "" then return "" end
    text = text:gsub("s%-", "S")
        :gsub("c%-", "C")
        :gsub("a%-", "A")
    text = text:gsub("Spacebar", "Sp")
        :gsub("Middle Mouse", "M3")
        :gsub("Mouse Wheel Up", "MWU")
        :gsub("Mouse Wheel Down", "MWD")
        :gsub("Mouse Button 4", "M4")
        :gsub("Mouse Button 5", "M5")
        :gsub("Num Pad%s*(%d)", "NP%1")
    if not text:match("[%w-=`]") then return "" end
    return text
end

-- Helper to get font sizes for a bar (respects GlobalOverride)
function ACB:GetFontSizes(barKey)
    local barDB = self.db.Bars and self.db.Bars[barKey]
    local globalFontSizes = self.db.FontSizes or {}
    local barFontSizes = barDB and barDB.FontSizes or {}
    -- Check if using global override
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

-- Helper to get text positions for a bar (respects GlobalOverride)
function ACB:GetTextPositions(barKey)
    local barDB = self.db.Bars and self.db.Bars[barKey]
    local barTextPos = barDB and barDB.TextPositions or {}
    -- Check if using global override
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
            cooldownAnchor = self.db.CooldownAnchor or "CENTER",
            cooldownXOffset = self.db.CooldownXOffset or 0,
            cooldownYOffset = self.db.CooldownYOffset or 0,
        }
    end
end

-- Helper to get bar-specific config
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
        hotkey:SetFont(fontpath, fontSize, self.db.FontOutline)
        hotkey:SetTextColor(1, 1, 1, 1)
        hotkey:SetShadowColor(0, 0, 0, 0)
        hotkey:SetJustifyH("RIGHT")

        -- Override SetTextColor to prevent Blizzard from changing our color
        if not hotkey._nrsknColorLocked then
            hotkey._nrsknColorLocked = true
            hotkey.SetTextColor = function() end -- nop
        end

        -- Remap keybind text
        C_Timer.After(0.5, function()
            if hotkey then
                local remapped = RemapKeyText(hotkey:GetText())
                if remapped ~= hotkey:GetText() then
                    button.HotKey:SetText(remapped)
                end
            end
        end)
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

            -- Override SetTextColor to prevent Blizzard from changing our color
            if not name._nrsknColorLocked then
                name._nrsknColorLocked = true
                name.SetTextColor = function() end
            end
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

        -- Override SetTextColor to prevent Blizzard from changing our color
        if not count._nrsknColorLocked then
            count._nrsknColorLocked = true
            count.SetTextColor = function() end
        end
    end
end

-- Button texture styling/hiding
function ACB:StyleButtonTextures(button)
    if not button then return end

    -- Hide textures
    NRSKNUI:Hide(button, 'Border')
    NRSKNUI:Hide(button, 'Flash')
    NRSKNUI:Hide(button, 'NewActionTexture')
    NRSKNUI:Hide(button, 'SpellHighlightTexture')
    NRSKNUI:Hide(button, 'SlotBackground')

    -- Hide the normal texture
    if button.NormalTexture then
        button.NormalTexture:SetTexture(nil)
        button.NormalTexture:Hide()
    end
    -- Hide checked texture
    if button.CheckedTexture then
        button.CheckedTexture:SetTexture(nil)
        button.CheckedTexture:Hide()
    end

    -- Style highlight texture
    if button.HighlightTexture then
        button.HighlightTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.HighlightTexture:SetTexCoord(0, 1, 0, 1)
        button.HighlightTexture:ClearAllPoints()
        button.HighlightTexture:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.HighlightTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
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

    -- Hook to show/hide push texture
    button:HookScript("OnMouseDown", function(self)
        if self.nrsknui_PushTexture then
            self.nrsknui_PushTexture:Show()
        end
    end)
    button:HookScript("OnMouseUp", function(self)
        if self.nrsknui_PushTexture then
            self.nrsknui_PushTexture:Hide()
        end
    end)
end

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
    local hideEmpty = barConfig and barConfig.HideEmptyBackdrops or false

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

    -- Hook button updates (only if method exists)
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
    if button.SlotArt then button.SlotArt:Hide() end
    if button.IconMask then button.IconMask:Hide() end
    if button.InterruptDisplay then button.InterruptDisplay:SetAlpha(0) end
    if button.SpellCastAnimFrame then button.SpellCastAnimFrame:SetAlpha(0) end
    if button.icon then button.icon:SetAllPoints(button) end                                   -- Resize the icon to fit properly
    if button.cooldown then button.cooldown:SetAllPoints(button) end                           -- Fix cooldown/GCD swipe to match button size
    if button.SpellHighlightTexture then button.SpellHighlightTexture:SetAllPoints(button) end -- Fix action bar glow (proc highlights)
    if button.AutoCastable then button.AutoCastable:SetDrawLayer("OVERLAY", 7) end             -- Ensure glow is above the button
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

    -- Store reference
    button.nrsknui_backdrop = backdrop
    return backdrop
end

-- Helper to check if its safe to call :Show(), :Hide() in combat
-- We then later either do a clean animation fadein/fadeout if not in combat
-- Or if in combat, simply set alpha 1/0, this way i aboid forbidden errors happening
-- Can probably solve cleaner, but this works
local function SafeFadeIn(frame, fadeTime, startAlpha, endAlpha)
    --if InCombatLockdown() then return end
    UIFrameFadeIn(frame, fadeTime, startAlpha, endAlpha)
end
local function SafeFadeOut(frame, fadeTime, startAlpha, endAlpha)
    --if InCombatLockdown() then return end
    UIFrameFadeOut(frame, fadeTime, startAlpha, endAlpha)
end

-- Layout function, supports vertical and horizontal grid
local function SkinBar(cfg)
    if not cfg or not cfg.frame then return end
    local spacing = cfg.spacing
    local buttonSize = cfg.buttonSize
    local totalButtons = cfg.totalButtons
    local layout = cfg.layout
    local buttonsPerLine = cfg.buttonsPerLine
    buttonsPerLine = math.max(1, math.min(buttonsPerLine, totalButtons))
    local anchor = cfg.anchorFrom
    local relTo = cfg.relativeTo
    local relPt = cfg.anchorTO
    local offsetX = cfg.x
    local offsetY = cfg.y

    -- Horizontal layout styling
    if layout == "HORIZONTAL" then
        local columns   = buttonsPerLine
        local rows      = math.ceil(totalButtons / columns)
        local growLeft  = cfg.growthDirection == "LEFT"

        -- Create container to help with mouseover functionality
        local container = CreateFrame("Frame", "NRSKNUI_" .. cfg.name .. "_Container", UIParent)
        container:SetSize(columns * buttonSize + (columns - 1) * spacing, rows * buttonSize + (rows - 1) * spacing)
        container:SetPoint(anchor, relTo, relPt, offsetX, offsetY)
        container:SetFrameStrata("LOW")

        -- Initialize mouseover settings
        local mouseoverEnabled = cfg.mouseover and cfg.mouseover.enabled
        local initialAlpha = mouseoverEnabled and (cfg.mouseover.alpha or 0) or 1
        container:SetAlpha(initialAlpha)
        container._fadeAlpha = cfg.mouseover and cfg.mouseover.alpha or 0
        container._fadeInDur = cfg.mouseover and cfg.mouseover.fadeInDuration or 0.3
        container._fadeOutDur = cfg.mouseover and cfg.mouseover.fadeOutDuration or 1
        container._mouseoverEnabled = mouseoverEnabled
        container._isMouseOver = false
        cfg.nrsknui_container = container

        -- Iterate through buttons and lay them out properly
        for i = 1, totalButtons do
            local button = _G[cfg.buttonPrefix .. i]
            if button then
                ACB:StyleButtonTextures(button)
                ACB:StyleButtonText(button, cfg.name)

                local backdrop = ACB:CreateButtonBackdrop(button, cfg.name, i, buttonSize)
                if backdrop then
                    backdrop:SetParent(container)

                    local index = i - 1
                    local col = index % columns
                    local row = math.floor(index / columns)

                    -- For grow left, reverse the column position
                    local dx
                    if growLeft then
                        dx = (columns - 1 - col) * (buttonSize + spacing)
                    else
                        dx = col * (buttonSize + spacing)
                    end
                    local dy = -(row * (buttonSize + spacing))

                    backdrop:ClearAllPoints()
                    backdrop:SetPoint("TOPLEFT", container, "TOPLEFT", dx, dy)
                end
            end
        end
    else
        -- Vertical layout styling
        local rows = buttonsPerLine
        local columns = math.ceil(totalButtons / rows)
        local growLeft = cfg.growthDirection == "LEFT"

        -- Create container
        local container = CreateFrame("Frame", "NRSKNUI_" .. cfg.name .. "_Container", UIParent)
        container:SetSize(columns * buttonSize + (columns - 1) * spacing, rows * buttonSize + (rows - 1) * spacing)
        container:SetPoint(anchor, relTo, relPt, offsetX, offsetY)
        container:SetFrameStrata("LOW")

        -- Initialize mouseover settings
        local mouseoverEnabled = cfg.mouseover and cfg.mouseover.enabled
        local initialAlpha = mouseoverEnabled and (cfg.mouseover.alpha or 0) or 1
        container:SetAlpha(initialAlpha)
        container._fadeAlpha = cfg.mouseover and cfg.mouseover.alpha or 0
        container._fadeInDur = cfg.mouseover and cfg.mouseover.fadeInDuration or 0.3
        container._fadeOutDur = cfg.mouseover and cfg.mouseover.fadeOutDuration or 1
        container._mouseoverEnabled = mouseoverEnabled
        container._isMouseOver = false
        cfg.nrsknui_container = container

        -- Iterate through buttons and lay them out properly
        for i = 1, totalButtons do
            local button = _G[cfg.buttonPrefix .. i]
            if button then
                ACB:StyleButtonTextures(button)
                ACB:StyleButtonText(button, cfg.name)

                local backdrop = ACB:CreateButtonBackdrop(button, cfg.name, i, buttonSize)
                if backdrop then
                    backdrop:SetParent(container)

                    local index = i - 1
                    local row = index % rows
                    local col = math.floor(index / rows)

                    -- For grow left, reverse the column position
                    local dx
                    if growLeft then
                        dx = (columns - 1 - col) * (buttonSize + spacing)
                    else
                        dx = col * (buttonSize + spacing)
                    end
                    local dy = -(row * (buttonSize + spacing))

                    backdrop:ClearAllPoints()
                    backdrop:SetPoint("TOPLEFT", container, "TOPLEFT", dx, dy)
                end
            end
        end
    end
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
        -- Check if mouseover is currently enabled
        if not container._mouseoverEnabled then return end
        container._isMouseOver = true
        local dur = container._fadeInDur or 0.3
        if not InCombatLockdown() then
            SafeFadeIn(container, dur, container:GetAlpha(), 1)
        else
            container:SetAlpha(1)
        end
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

        -- Read current fade alpha from container (allows dynamic updates)
        local alpha = container._fadeAlpha or 0
        local dur = container._fadeOutDur or 0.5
        if not InCombatLockdown() then
            SafeFadeOut(container, dur, container:GetAlpha(), alpha)
        else
            container:SetAlpha(alpha)
        end
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

    -- Create a hidden frame to use with RegisterStateDriver (always create it)
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

        -- In vehicle/bonusbar - force alpha 1
        if state == "vehicle" then
            container._bonusBarActive = true
            container:SetAlpha(1)
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

-- Toggle a single bar on/off
function ACB:ToggleBar(cfg, enabled)
    if not cfg or not cfg.nrsknui_container then return end
    if InCombatLockdown() then return end -- Don't toggle during combat

    local container = cfg.nrsknui_container
    if enabled then
        container:Show()
        local alpha = cfg.mouseover and cfg.mouseover.alpha or 1
        container:SetAlpha(alpha)
    else
        container:Hide()
    end
end

-- Setup visibility handling for Pet Bar (show only when pet has action bar)
local function SetupPetBarVisibility(container)
    if not container then return end

    -- Hide Blizzard's default pet bar frame
    if PetActionBar then
        PetActionBar:SetParent(UIParent)
        PetActionBar:ClearAllPoints()
        PetActionBar:SetPoint("TOP", UIParent, "BOTTOM", 0, -500)
        PetActionBar:EnableMouse(false)
    end

    local pendingUpdate = false

    local function UpdatePetBarVisibility()
        -- Don't modify frames during combat
        if InCombatLockdown() then
            pendingUpdate = true
            return
        end

        pendingUpdate = false
        if PetHasActionBar() then
            container:Show()
        else
            container:Hide()
        end
    end

    -- Create event frame
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PET_BAR_UPDATE")
    eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("PLAYER_CONTROL_GAINED")
    eventFrame:RegisterEvent("PLAYER_CONTROL_LOST")
    eventFrame:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            -- Combat ended, process pending update
            if pendingUpdate then
                UpdatePetBarVisibility()
            end
        else
            UpdatePetBarVisibility()
        end
    end)

    -- Initial update (only if not in combat)
    if not InCombatLockdown() then
        UpdatePetBarVisibility()
    else
        pendingUpdate = true
    end

    container._visibilityFrame = eventFrame
end

-- Setup visibility handling for Stance Bar (show only when stances are available)
local function SetupStanceBarVisibility(container)
    if not container then return end

    -- Hide Blizzard's default stance bar frame
    if StanceBar then
        StanceBar:SetParent(UIParent)
        StanceBar:ClearAllPoints()
        StanceBar:SetPoint("TOP", UIParent, "BOTTOM", 0, -500)
        StanceBar:EnableMouse(false)
    end

    local pendingUpdate = false

    local function UpdateStanceBarVisibility()
        -- Don't modify frames during combat
        if InCombatLockdown() then
            pendingUpdate = true
            return
        end

        pendingUpdate = false
        local numForms = GetNumShapeshiftForms()
        if numForms and numForms > 0 then
            container:Show()
        else
            container:Hide()
        end
    end

    -- Create event frame
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingUpdate then
                UpdateStanceBarVisibility()
            end
        else
            UpdateStanceBarVisibility()
        end
    end)

    -- Initial update (only if not in combat)
    if not InCombatLockdown() then
        UpdateStanceBarVisibility()
    else
        pendingUpdate = true
    end

    container._visibilityFrame = eventFrame
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
    -- Build config from DB
    self:BuildConfigTable()

    C_Timer.After(0.5, function()
        -- Skin and setup each bar
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

                -- Setup bonusbar override for Bar1 (main action bar)
                if cfg.name == "Bar1" and cfg.nrsknui_container then
                    SetupBonusBarOverride(cfg.nrsknui_container, self.db)
                end

                -- Setup visibility handling for Pet and Stance bars
                if cfg.name == "PetBar" and cfg.nrsknui_container then
                    SetupPetBarVisibility(cfg.nrsknui_container)
                elseif cfg.name == "StanceBar" and cfg.nrsknui_container then
                    SetupStanceBarVisibility(cfg.nrsknui_container)
                end
            end
        end

        Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. 2, false);
        Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. 3, false);
        Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. 4, false);
        Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. 5, false);
        Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. 6, false);
        Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. 7, false);
        Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. 8, false);
        C_CVar.SetCVar("countdownForCooldowns", 1)
        SettingsPanel:CommitSettings(true)

        -- Disable action bar cast feedback
        local castEvents = {
            "UNIT_SPELLCAST_INTERRUPTED",
            "UNIT_SPELLCAST_SUCCEEDED",
            "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_START",
            "UNIT_SPELLCAST_STOP",
            "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP",
            "UNIT_SPELLCAST_RETICLE_TARGET",
            "UNIT_SPELLCAST_RETICLE_CLEAR",
            "UNIT_SPELLCAST_EMPOWER_START",
            "UNIT_SPELLCAST_EMPOWER_STOP",
            "UNIT_SPELLCAST_SENT",
        }
        if ActionBarActionEventsFrame then
            for _, event in ipairs(castEvents) do
                ActionBarActionEventsFrame:UnregisterEvent(event)
            end
        end

        -- Re-apply styling after delays to catch Blizzard's late initialization
        C_Timer.After(1, function() ACB:UpdateButtonTexts() end)
        C_Timer.After(2, function() ACB:UpdateButtonTexts() end)

        -- Setup drag detection to show backdrops while dragging spells
        self:SetupDragDetection()
    end)
end

-- Show all backdrops temporarily (during spell drag)
function ACB:ShowAllBackdropsTemporary()
    local bars = { "Bar1", "Bar2", "Bar3", "Bar4", "Bar5", "Bar6", "Bar7", "Bar8" }
    for _, barKey in ipairs(bars) do
        local i = 1
        while true do
            local backdrop = _G["NRSKNUI_" .. barKey .. "Backdrop" .. i]
            if not backdrop then break end
            backdrop:SetAlpha(1)
            i = i + 1
        end
    end
end

-- Restore backdrop visibility after drag ends
function ACB:RestoreBackdropVisibility()
    local bars = { "Bar1", "Bar2", "Bar3", "Bar4", "Bar5", "Bar6", "Bar7", "Bar8" }
    for _, barKey in ipairs(bars) do
        local i = 1
        while true do
            local backdrop = _G["NRSKNUI_" .. barKey .. "Backdrop" .. i]
            if not backdrop then break end
            -- Call the visibility update function if it exists
            if backdrop._updateVisibility then
                backdrop._updateVisibility()
            else
                backdrop:SetAlpha(1)
            end
            i = i + 1
        end
    end
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

-- Update container position for a specific bar
function ACB:UpdateBarPosition(barKey)
    if not self.db or not self.db.Bars or not self.db.Bars[barKey] then return end

    local barDB = self.db.Bars[barKey]
    local container = _G["NRSKNUI_" .. barKey .. "_Container"]
    if not container then return end

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
    if not self.db or not self.db.Bars or not self.db.Bars[barKey] then return end

    local barDB = self.db.Bars[barKey]
    local container = _G["NRSKNUI_" .. barKey .. "_Container"]
    if not container then return end

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
    if not self.db or not self.db.Bars or not self.db.Bars[barKey] then return end
    local barDB = self.db.Bars[barKey]
    local container = _G["NRSKNUI_" .. barKey .. "_Container"]
    if not container then return end
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

            -- Create backdrop if it doesn't exist (for newly added buttons)
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

                -- Recalculate position
                local index = i - 1
                local col, row
                if layout == "HORIZONTAL" then
                    col = index % columns
                    row = math.floor(index / columns)
                else
                    row = index % rows
                    col = math.floor(index / rows)
                end

                -- For grow left, reverse the column position
                local dx
                if growLeft then
                    dx = (columns - 1 - col) * (buttonSize + spacing)
                else
                    dx = col * (buttonSize + spacing)
                end
                local dy = -(row * (buttonSize + spacing))

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
    if not self.db or not self.db.Bars or not self.db.Bars[barKey] then return end

    local barDB = self.db.Bars[barKey]
    local container = _G["NRSKNUI_" .. barKey .. "_Container"]
    if not container then return end

    if barDB.Enabled then
        container:Show()
    else
        container:Hide()
    end
end

-- Main update function, called from GUI
-- updateType can be: "all", "fonts", "positions", "mouseover", "layout", "bar"
-- barKey is optional, used when updating a specific bar
-- This way i can do targeted updates in the GUI
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
            -- If we have the visibility function and hiding is enabled, update it
            backdrop._updateVisibility()
        elseif not hideEmpty then
            -- If hiding is disabled, always show the backdrop
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

-- Full refresh
function ACB:Refresh()
    self:UpdateSettings("all")
    self:UpdateAllBackdropColors()
end
