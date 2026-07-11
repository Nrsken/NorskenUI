---@class NRSKNUI
local NRSKNUI = select(2, ...)

local ipairs, type = ipairs, type
local setmetatable = setmetatable
local hooksecurefunc = hooksecurefunc
local UIFrameFade, UIFrameFadeIn, UIFrameFadeOut = UIFrameFade, UIFrameFadeIn, UIFrameFadeOut
local issecretvalue = issecretvalue
local InCombatLockdown = InCombatLockdown

-- STANDARD_TEXT_FONT is locale-correct (ARKai_T on zhCN, 2002 on koKR, etc) a hardcoded FRIZQT__ fallback renders CJK text as boxes on those clients.
local FALLBACK_FONT = STANDARD_TEXT_FONT or (GameFontNormal and GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"

local SoftOutline = {}
SoftOutline.__index = SoftOutline

local SOFT_OUTLINE_FADEOUT_SPEED = 0.85
local fadeHookRunning = false

local SHADOW_OFFSETS = {
    { 0, 1 }, { 1, 1 }, { 1, 0 }, { 1, -1 },
    { 0, -1 }, { -1, -1 }, { -1, 0 }, { -1, 1 },
}

local ALPHA_STRENGTH = { 1.0, 0.7, 1.0, 0.7, 1.0, 0.7, 1.0, 0.7 }

local function StripEscapeCodes(text)
    if type(text) ~= "string" then return "" end
    if issecretvalue and issecretvalue(text) then return text end
    return text
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|cn[^:]-:", "")
        :gsub("|r", "")
        :gsub("|T.-|t", "   ")
        :gsub("|A.-|a", "   ")
        :gsub("|H.-|h(.-)|h", "%1")
end

local function HandleFadeHook(frame, outline, startAlpha)
    if not outline.shadows or not outline.isShown then return end
    local _, _, _, textAlpha = frame:GetTextColor()
    if not (issecretvalue and issecretvalue(textAlpha)) and textAlpha == 0 then return end

    fadeHookRunning = true
    for _, shadow in ipairs(outline.shadows) do
        shadow:SetAlpha(startAlpha)
        shadow:Show()
    end
    fadeHookRunning = false
end

local function SetupFadeHooks()
    hooksecurefunc("UIFrameFade", function(frame, fadeInfo)
        if not frame or not fadeInfo or fadeHookRunning then return end
        local outline = frame._nrsknSoftOutline
        if not outline or not outline.shadows then return end

        fadeHookRunning = true
        local isFadeOut = fadeInfo.mode == "OUT" or
            (fadeInfo.startAlpha and fadeInfo.endAlpha and fadeInfo.endAlpha < fadeInfo.startAlpha)

        for _, shadow in ipairs(outline.shadows) do
            local shadowFade = {
                mode = fadeInfo.mode,
                startAlpha = fadeInfo.startAlpha,
                endAlpha = fadeInfo.endAlpha,
                diffAlpha = fadeInfo.diffAlpha,
                timeToFade = isFadeOut and (fadeInfo.timeToFade * SOFT_OUTLINE_FADEOUT_SPEED) or fadeInfo.timeToFade,
            }
            if fadeInfo.endAlpha == 0 then
                shadowFade.finishedFunc = function() shadow:Hide() end
            end
            UIFrameFade(shadow, shadowFade)
        end
        fadeHookRunning = false
    end)

    if UIFrameFadeIn then
        hooksecurefunc("UIFrameFadeIn", function(frame, _, startAlpha)
            if not frame or fadeHookRunning then return end
            local outline = frame._nrsknSoftOutline
            if outline then HandleFadeHook(frame, outline, startAlpha or 0) end
        end)
    end

    if UIFrameFadeOut then
        hooksecurefunc("UIFrameFadeOut", function(frame, _, startAlpha)
            if not frame or fadeHookRunning then return end
            local outline = frame._nrsknSoftOutline
            if outline then HandleFadeHook(frame, outline, startAlpha or 1) end
        end)
    end
end

if InCombatLockdown() then
    NRSKNUI:DeferUntilUnrestricted(0, SetupFadeHooks)
else
    SetupFadeHooks()
end

function SoftOutline:_ForEach(fn)
    if not self.shadows then return end
    for i, shadow in ipairs(self.shadows) do
        fn(shadow, i)
    end
end

function SoftOutline:_ApplyOffsets()
    local point = self.main:GetPoint(1)
    if not point then return end
    self:_ForEach(function(shadow, i)
        local offset = SHADOW_OFFSETS[i]
        shadow:ClearAllPoints()
        shadow:SetPoint(point, self.main, point, offset[1] * self.thickness, offset[2] * self.thickness)
    end)
end

function SoftOutline:_ApplyColor()
    self:_ForEach(function(shadow, i)
        shadow:SetTextColor(self.color[1], self.color[2], self.color[3], self.alpha * (ALPHA_STRENGTH[i] or 1))
    end)
end

function SoftOutline:_SyncWidth()
    if not self.main then return end
    local width = self.main:GetWidth()
    self:_ForEach(function(shadow) shadow:SetWidth(width) end)
    self.hasExplicitWidth = true
end

function SoftOutline:_SyncWrapSettings()
    if not self.main then return end
    local wordWrap, nonSpaceWrap = self.main:CanWordWrap(), self.main:CanNonSpaceWrap()
    self:_ForEach(function(shadow)
        if wordWrap ~= nil then shadow:SetWordWrap(wordWrap) end
        if nonSpaceWrap ~= nil then shadow:SetNonSpaceWrap(nonSpaceWrap) end
    end)
end

function SoftOutline:_SyncJustify()
    if not self.main then return end
    local justifyH, justifyV = self.main:GetJustifyH(), self.main:GetJustifyV()
    self:_ForEach(function(shadow)
        shadow:SetJustifyH(justifyH)
        shadow:SetJustifyV(justifyV)
    end)
end

function SoftOutline:_SyncAll()
    local font, size = self.main:GetFont()
    if font and font ~= "" and size and size > 0 then
        self:SetFont(font, size)
    end
    self:SetText(self.main:GetText() or "")
    self:_SyncJustify()
    self:_SyncWrapSettings()
    if self.hasExplicitWidth then self:_SyncWidth() end
end

function SoftOutline:SetText(text)
    local cleanText = StripEscapeCodes(text)
    self:_ForEach(function(shadow) shadow:SetText(cleanText) end)
end

function SoftOutline:SetFont(fontPath, fontSize)
    if not self.shadows then return false end
    fontPath = (fontPath and fontPath ~= "") and fontPath or FALLBACK_FONT
    fontSize = (fontSize and fontSize > 0) and fontSize or 14

    local success = true
    for _, shadow in ipairs(self.shadows) do
        if not shadow:SetFont(fontPath, fontSize, "") then
            shadow:SetFont(FALLBACK_FONT, fontSize, "")
            success = false
        end
    end
    return success
end

function SoftOutline:SyncWidth()
    self:_SyncWidth()
end

function SoftOutline:SetShadowColor(r, g, b, a)
    self.color = { r, g, b }
    if a then self.alpha = a end
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

function SoftOutline:_IsTextVisible()
    if not self.main then return false end
    local _, _, _, textAlpha = self.main:GetTextColor()
    local frameAlpha = self.main:GetAlpha()
    if issecretvalue and (issecretvalue(textAlpha) or issecretvalue(frameAlpha)) then
        return true
    end
    return textAlpha ~= 0 and frameAlpha ~= 0
end

function SoftOutline:SetShown(shown)
    if not self.shadows then return end
    self.isShown = shown

    if not shown or not self:_IsTextVisible() then
        self:_ForEach(function(shadow) shadow:SetShown(false) end)
        return
    end

    self:_SyncAll()
    self:_ApplyColor()

    self:_ForEach(function(shadow) shadow:SetShown(true) end)
end

function SoftOutline:SetShownFromBoolean(condition, trueVal, falseVal)
    if not self.shadows then return end
    local showTrue = trueVal ~= false
    local showFalse = falseVal == true

    if showTrue and self:_IsTextVisible() then
        self:_SyncAll()
    end

    local trueAlpha = showTrue and 1 or 0
    local falseAlpha = showFalse and 1 or 0
    self:_ForEach(function(shadow)
        shadow:SetAlphaFromBoolean(condition, trueAlpha, falseAlpha)
    end)
end

function SoftOutline:IsShown()
    return self.isShown
end

function SoftOutline:Release()
    self:_ForEach(function(shadow)
        if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(shadow) end
        shadow:Hide()
        shadow:ClearAllPoints()
        shadow:SetParent(nil)
    end)

    if self.main then self.main._nrsknSoftOutline = nil end
    self.main = nil
    self.shadows = nil
    self.isShown = false
end

function SoftOutline:_HookMain()
    local main = self.main
    if not main then return end
    if main._nrsknSoftOutlineHooked then return end
    main._nrsknSoftOutlineHooked = true
    main._nrsknSoftOutline = self

    local function getOutline()
        local outline = main._nrsknSoftOutline
        return (outline and outline.shadows) and outline or nil
    end

    hooksecurefunc(main, "SetText", function(_, text)
        local outline = getOutline()
        if outline and outline.isShown then
            outline:SetText(text)
            outline:_ForEach(function(shadow) shadow:Show() end)
        end
    end)

    hooksecurefunc(main, "SetFormattedText", function(self)
        local outline = getOutline()
        if outline and outline.isShown then
            outline:SetText(self:GetText() or "")
            outline:_ForEach(function(shadow) shadow:Show() end)
        end
    end)

    hooksecurefunc(main, "SetFont", function(_, font, size)
        local outline = getOutline()
        if outline and outline.isShown and font and font ~= "" and size and size > 0 then
            outline:SetFont(font, size)
        end
    end)

    hooksecurefunc(main, "SetJustifyH", function(_, justify)
        local outline = getOutline()
        if outline and outline.isShown then
            outline:_ForEach(function(shadow) shadow:SetJustifyH(justify) end)
        end
    end)

    hooksecurefunc(main, "SetJustifyV", function(_, justify)
        local outline = getOutline()
        if outline and outline.isShown then
            outline:_ForEach(function(shadow) shadow:SetJustifyV(justify) end)
        end
    end)

    hooksecurefunc(main, "SetWidth", function()
        local outline = getOutline()
        if outline then outline:_SyncWidth() end
    end)

    hooksecurefunc(main, "SetWordWrap", function(_, wrap)
        local outline = getOutline()
        if outline then outline:_ForEach(function(shadow) shadow:SetWordWrap(wrap) end) end
    end)

    hooksecurefunc(main, "SetNonSpaceWrap", function(_, wrap)
        local outline = getOutline()
        if outline then outline:_ForEach(function(shadow) shadow:SetNonSpaceWrap(wrap) end) end
    end)

    local function handleAlphaChange(a)
        local outline = getOutline()
        if not outline then return end
        if issecretvalue and issecretvalue(a) then
            if outline.isShown then
                outline:_ForEach(function(shadow) shadow:Show() end)
            end
            return
        end
        if a == 0 then
            outline:_ForEach(function(shadow) shadow:Hide() end)
        elseif outline.isShown then
            outline:_ForEach(function(shadow) shadow:Show() end)
        end
    end

    hooksecurefunc(main, "SetAlpha", function(_, a) handleAlphaChange(a) end)
    hooksecurefunc(main, "SetTextColor", function(_, _, _, _, a) handleAlphaChange(a) end)
end

local function GetFontWithFallback(fontString, options)
    local font, size = fontString:GetFont()
    font = (font and font ~= "") and font or options.fontPath or FALLBACK_FONT
    size = (size and size > 0) and size or options.fontSize or 14
    return font, size
end

---@param mainText FontString
---@param options table?
---@return table?
function NRSKNUI:CreateSoftOutline(mainText, options)
    if not mainText then return nil end
    options = options or {}

    local existingOutline = mainText._nrsknSoftOutline
    if existingOutline and existingOutline.shadows then
        existingOutline.color = options.color or existingOutline.color or { 0, 0, 0 }
        existingOutline.alpha = options.alpha or existingOutline.alpha or 0.9
        existingOutline.thickness = options.thickness or existingOutline.thickness or 1
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

    mainText:SetShadowColor(0, 0, 0, 0)
    mainText:SetShadowOffset(0, 0)

    local font, size = GetFontWithFallback(mainText, options)
    local parent = mainText:GetParent()
    if not parent then return nil end

    local text = StripEscapeCodes(mainText:GetText() or "")
    local justifyH, justifyV = mainText:GetJustifyH(), mainText:GetJustifyV()

    for i = 1, #SHADOW_OFFSETS do
        local shadow = parent:CreateFontString(nil, "ARTWORK", nil)
        shadow:SetFont(font, size, "")
        shadow:SetText(text)
        shadow:SetJustifyH(justifyH)
        shadow:SetJustifyV(justifyV)
        outline.shadows[i] = shadow
    end

    outline:_ApplyOffsets()
    outline:_ApplyColor()
    outline:_SyncWrapSettings()
    outline:_HookMain()
    mainText._nrsknSoftOutline = outline

    if not outline:_IsTextVisible() then
        outline:_ForEach(function(shadow) shadow:Hide() end)
    end

    return outline
end
