-- NorskenUI namespace
local _, NRSKNUI = ...

-- Soft Outline Object and global font util

-- Example usage
--[[
-- Create the softoutline object
frame.softOutline = NRSKNUI:CreateSoftOutline(MyFontString, {
    thickness = 1,
    color = {0, 0, 0},
    alpha = 0.9,
})

-- Adjustments
frame.softOutline:SetThickness(2)
frame.softOutline:SetShadowColor(0, 0, 0, 1)
frame.softOutline:SetAlpha(0.8)
frame.softOutline:SetShown(false)

-- Cleanup
frame.softOutline:Release()
--]]

local SoftOutline = {}
SoftOutline.__index = SoftOutline

-- Localization
local ipairs = ipairs
local hooksecurefunc = hooksecurefunc
local setmetatable = setmetatable
local unpack = unpack

-- 8-direction offsets
local SHADOW_OFFSETS = {
    { 0,  1 },  -- N
    { 1,  1 },  -- NE
    { 1,  0 },  -- E
    { 1,  -1 }, -- SE
    { 0,  -1 }, -- S
    { -1, -1 }, -- SW
    { -1, 0 },  -- W
    { -1, 1 },  -- NW
}

-- Alpha falloff
local ALPHA_STRENGTH = {
    1.0, 0.7,
    1.0, 0.7,
    1.0, 0.7,
    1.0, 0.7,
}

-- Strip WoW color codes from text for solid outline
-- We do this so that the actual text color when |cAARRGGBB|r format is used
-- does not "bleed" into the outline
local function StripColorCodes(text)
    if not text then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "") -- Remove |cAARRGGBB
    text = text:gsub("|r", "")                 -- Remove |r (reset)
    return text                                -- Return cleaned text
end

-- Internal Helpers
function SoftOutline:_ApplyOffsets()
    if not self.shadows then return end
    for i, shadow in ipairs(self.shadows) do
        local offset = SHADOW_OFFSETS[i]
        local x = offset[1] * self.thickness
        local y = offset[2] * self.thickness

        shadow:ClearAllPoints()
        shadow:SetPoint("CENTER", self.main, "CENTER", x, y)
    end
end

function SoftOutline:_ApplyColor()
    if not self.shadows then return end
    for i, shadow in ipairs(self.shadows) do
        local strength = ALPHA_STRENGTH[i] or 1
        shadow:SetTextColor(
            self.color[1],
            self.color[2],
            self.color[3],
            self.alpha * strength
        )
    end
end

-- Public API
function SoftOutline:SetText(text)
    if not self.shadows then return end
    local cleanText = StripColorCodes(text)
    for _, shadow in ipairs(self.shadows) do
        shadow:SetText(cleanText)
    end
end

function SoftOutline:SetFont(fontPath, fontSize, flags)
    if not self.shadows then return false end

    -- Validate and fix inputs
    if not fontPath or fontPath == "" then
        fontPath = "Fonts\\FRIZQT__.TTF"
    end
    if not fontSize or fontSize <= 0 then
        fontSize = 14
    end
    flags = flags or ""

    local success = true
    for _, shadow in ipairs(self.shadows) do
        local ok = shadow:SetFont(fontPath, fontSize, flags)
        if not ok then
            -- Try fallback
            shadow:SetFont("Fonts\\FRIZQT__.TTF", fontSize, flags)
            success = false
        end
    end
    return success
end

function SoftOutline:SetShadowColor(r, g, b, a)
    self.color = { r, g, b }
    if a then
        self.alpha = a
    end
    self:_ApplyColor()
end

function SoftOutline:SetThickness(value)
    self.thickness = value or 1
    self:_ApplyOffsets()
end

function SoftOutline:SetAlpha(a)
    self.alpha = a or 1
    self:_ApplyColor()
end

function SoftOutline:SetShown(shown)
    if not self.shadows then return end
    self.isShown = shown
    for _, shadow in ipairs(self.shadows) do
        shadow:SetShown(shown)
    end
end

function SoftOutline:IsShown()
    return self.isShown
end

function SoftOutline:Release()
    if not self.shadows then return end
    for _, shadow in ipairs(self.shadows) do
        shadow:Hide()
        shadow:ClearAllPoints()
        shadow:SetParent(nil)
    end

    -- Clear reference on main text
    if self.main then
        self.main._nrsknSoftOutline = nil
    end

    self.main = nil
    self.shadows = nil
    self.isShown = false
end

-- Hook Sync - Only hooks once per FontString
function SoftOutline:_HookMain()
    local main = self.main

    -- Check if already hooked to prevent duplicate hooks
    if main._nrsknSoftOutlineHooked then return end
    main._nrsknSoftOutlineHooked = true

    -- Store reference on main text so hooks can find current outline
    -- This is updated each time a new soft outline is created for this text
    main._nrsknSoftOutline = self

    -- Hook SetText
    hooksecurefunc(main, "SetText", function(_, text)
        local outline = main._nrsknSoftOutline
        if outline and outline.shadows and outline.isShown then
            outline:SetText(text)
        end
    end)

    -- Hook SetFormattedText (used by timers, etc.)
    hooksecurefunc(main, "SetFormattedText", function(self)
        local outline = main._nrsknSoftOutline
        if outline and outline.shadows and outline.isShown then
            -- GetText() returns the formatted result
            outline:SetText(self:GetText() or "")
        end
    end)

    -- Hook SetFont
    hooksecurefunc(main, "SetFont", function(_, font, size, flags)
        local outline = main._nrsknSoftOutline
        if outline and outline.shadows and outline.isShown then
            -- Validate parameters before passing to soft outline
            if font and font ~= "" and size and size > 0 then
                outline:SetFont(font, size, flags or "")
            end
        end
    end)

    -- Hook SetJustifyH
    hooksecurefunc(main, "SetJustifyH", function(_, justify)
        local outline = main._nrsknSoftOutline
        if outline and outline.shadows and outline.isShown then
            for _, shadow in ipairs(outline.shadows) do
                shadow:SetJustifyH(justify)
            end
        end
    end)

    -- Hook SetJustifyV
    hooksecurefunc(main, "SetJustifyV", function(_, justify)
        local outline = main._nrsknSoftOutline
        if outline and outline.shadows and outline.isShown then
            for _, shadow in ipairs(outline.shadows) do
                shadow:SetJustifyV(justify)
            end
        end
    end)

    -- Hook SetAlpha to handle fade effects
    -- When main text alpha is 0, hide shadows to prevent ghost outline
    hooksecurefunc(main, "SetAlpha", function(_, a)
        local outline = main._nrsknSoftOutline
        if outline and outline.shadows then
            if a == 0 then
                -- Hide shadows when text is fully transparent
                for _, shadow in ipairs(outline.shadows) do
                    shadow:Hide()
                end
            elseif outline.isShown then
                -- Show shadows when text becomes visible again
                for _, shadow in ipairs(outline.shadows) do
                    shadow:Show()
                end
            end
        end
    end)

    -- Hook parent frame visibility
    local parent = main:GetParent()
    if parent and not parent._nrsknSoftOutlineHooked then
        parent._nrsknSoftOutlineHooked = true

        hooksecurefunc(parent, "Hide", function()
            local outline = main._nrsknSoftOutline
            if outline and outline.shadows then
                for _, shadow in ipairs(outline.shadows) do
                    shadow:Hide()
                end
            end
        end)

        hooksecurefunc(parent, "Show", function()
            local outline = main._nrsknSoftOutline
            if outline and outline.shadows and outline.isShown then
                for _, shadow in ipairs(outline.shadows) do
                    shadow:Show()
                end
            end
        end)
    end
end

-- Factory
function NRSKNUI:CreateSoftOutline(mainText, options)
    if not mainText then return nil end

    options = options or {}

    -- If this text already has a soft outline, reuse it instead of creating new one
    local existingOutline = mainText._nrsknSoftOutline
    if existingOutline and existingOutline.shadows then
        -- Update existing outline with new options
        existingOutline.color = options.color or existingOutline.color or { 0, 0, 0 }
        existingOutline.alpha = options.alpha or existingOutline.alpha or 0.9
        existingOutline.thickness = options.thickness or existingOutline.thickness or 1

        -- Get font settings
        local font, size, flags = mainText:GetFont()
        font = (font and font ~= "") and font or options.fontPath or "Fonts\\FRIZQT__.TTF"
        size = (size and size > 0) and size or options.fontSize or 14
        flags = flags or ""

        -- Update shadows
        existingOutline:SetFont(font, size, "")
        existingOutline:SetText(mainText:GetText() or "")
        existingOutline:_ApplyOffsets()
        existingOutline:_ApplyColor()
        existingOutline:SetShown(true)

        return existingOutline
    end

    local outline = setmetatable({}, SoftOutline)

    outline.main = mainText
    outline.shadows = {}
    outline.color = options.color or { 0, 0, 0 }
    outline.alpha = options.alpha or 0.9
    outline.thickness = options.thickness or 1
    outline.isShown = true

    -- Disable Blizzard shadow
    mainText:SetShadowColor(0, 0, 0, 0)
    mainText:SetShadowOffset(0, 0)

    -- Get font from main text, with fallbacks from options
    -- Note to self: GetFont() can return -1 for size if font is not set, so we check > 0
    local font, size, flags = mainText:GetFont()
    font = (font and font ~= "") and font or options.fontPath or "Fonts\\FRIZQT__.TTF"
    size = (size and size > 0) and size or options.fontSize or 14
    flags = flags or ""

    -- Create shadows
    -- Use ARTWORK layer with sublevel 7 so shadows appear above icon textures (sublevel 0)
    -- but below OVERLAY layer where the main text lives
    local parent = mainText:GetParent()
    for i = 1, #SHADOW_OFFSETS do
        local shadow = parent:CreateFontString(nil, "ARTWORK", nil, 7)
        shadow:SetFont(font, size, "")
        shadow:SetText(StripColorCodes(mainText:GetText() or ""))
        shadow:SetJustifyH(mainText:GetJustifyH())
        shadow:SetJustifyV(mainText:GetJustifyV())

        outline.shadows[i] = shadow
    end

    outline:_ApplyOffsets()
    outline:_ApplyColor()
    outline:_HookMain()

    -- Store reference on main text
    mainText._nrsknSoftOutline = outline

    return outline
end

-- Global apply font settings func w/ softoutline support
-- Example usage:
-- NRSKNUI:ApplyFontSettings(self.frame, self.db. true/nil)
function NRSKNUI:ApplyFontSettings(frame, settings, color)
    if not frame or not frame.text or not settings then return false end
    local text = frame.text

    -- Get settings with fallbacks
    local fontName = settings.FontFace or "Friz Quadrata TT"
    local fontSize = settings.FontSize
    if not fontSize or fontSize <= 0 then
        fontSize = 14
    end
    local fontOutline = settings.FontOutline or "OUTLINE"

    if color then
        text:SetTextColor(unpack(settings.Color or { 1, 1, 1, 1 }))
    end

    -- Softoutline mode
    if fontOutline == "SOFTOUTLINE" then
        -- Set font on main text FIRST before creating/updating soft outline
        -- Use ApplyFont with SOFTOUTLINE which returns "" for outline flags
        local success = self:ApplyFont(text, fontName, fontSize, "SOFTOUTLINE")
        text:SetShadowOffset(0, 0)
        text:SetShadowColor(0, 0, 0, 0)

        -- Get fontPath for soft outline creation
        local fontPath = self:GetFontPath(fontName)

        if not frame.softOutline then
            frame.softOutline = self:CreateSoftOutline(text, {
                thickness = 1,
                color = { 0, 0, 0 },
                alpha = 0.9,
                fontPath = fontPath,
                fontSize = fontSize,
            })
        else
            -- Update existing soft outline
            frame.softOutline:SetFont(fontPath, fontSize, "")
            frame.softOutline:SetText(text:GetText() or "")
            frame.softOutline:SetShown(true)
        end

        return success
    else
        -- Hide soft outline if it exists
        if frame.softOutline then
            frame.softOutline:SetShown(false)
        end

        -- Use ApplyFont from Globals.lua (handles GetFontPath and GetFontOutline)
        local success = self:ApplyFont(text, fontName, fontSize, fontOutline)

        -- Font shadow
        local shadow = settings.FontShadow or {}
        if shadow.Enabled then
            local shadowColor = shadow.Color or { 0, 0, 0, 1 }
            local shadowAlpha = (shadowColor[4] and shadowColor[4] > 0) and shadowColor[4] or 0.9
            text:SetShadowColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowAlpha)
            text:SetShadowOffset(shadow.OffsetX or 1, shadow.OffsetY or -1)
        else
            text:SetShadowOffset(0, 0)
            text:SetShadowColor(0, 0, 0, 0)
        end

        return success
    end
end

-- Lower-level helper for applying font to a FontString directly, used for modules with multiple text elements
-- Unlike ApplyFontSettings, this works directly on a fontString without needing a frame wrapper
-- Example usage:
-- NRSKNUI:ApplyFontToText(self.frame.timerText, "Expressway", 18, "SOFTOUTLINE", shadowSettings)
function NRSKNUI:ApplyFontToText(fontString, fontName, fontSize, fontOutline, shadowSettings)
    if not fontString then return false end

    -- Defaults
    fontName = fontName or "Friz Quadrata TT"
    fontSize = (fontSize and fontSize > 0) and fontSize or 14
    fontOutline = fontOutline or "OUTLINE"
    shadowSettings = shadowSettings or {}

    -- Softoutline mode
    if fontOutline == "SOFTOUTLINE" then
        local success = self:ApplyFont(fontString, fontName, fontSize, "SOFTOUTLINE")
        fontString:SetShadowOffset(0, 0)
        fontString:SetShadowColor(0, 0, 0, 0)

        local fontPath = self:GetFontPath(fontName)

        if not fontString.softOutline then
            fontString.softOutline = self:CreateSoftOutline(fontString, {
                thickness = 1,
                color = { 0, 0, 0 },
                alpha = 0.9,
                fontPath = fontPath,
                fontSize = fontSize,
            })
        else
            fontString.softOutline:SetFont(fontPath, fontSize, "")
            fontString.softOutline:SetText(fontString:GetText() or "")
            fontString.softOutline:SetShown(true)
        end

        return success
    else
        -- Hide soft outline if it exists
        if fontString.softOutline then
            fontString.softOutline:SetShown(false)
        end

        local success = self:ApplyFont(fontString, fontName, fontSize, fontOutline)

        -- Apply shadow settings
        if shadowSettings.Enabled then
            local shadowColor = shadowSettings.Color or { 0, 0, 0, 1 }
            local shadowAlpha = (shadowColor[4] and shadowColor[4] > 0) and shadowColor[4] or 0.9
            fontString:SetShadowColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowAlpha)
            fontString:SetShadowOffset(shadowSettings.OffsetX or 1, shadowSettings.OffsetY or -1)
        else
            fontString:SetShadowOffset(0, 0)
            fontString:SetShadowColor(0, 0, 0, 0)
        end

        return success
    end
end
