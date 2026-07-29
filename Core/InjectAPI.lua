---@class NRSKNUI
local NRSKNUI = select(2, ...)
local PixelMixin = NRSKNUI.Libs.KAJI.PixelMixin

-- Injection API for adding methods to frame metatables.

local next = next
local pairs = pairs
local type = type
local getmetatable = getmetatable
local CreateFrame = CreateFrame
local select = select
local pcall = pcall
local ipairs = ipairs
local Mixin = Mixin
local EnumerateFrames = EnumerateFrames

local insert = table.insert

local _G = _G

---Exposed Injection API so that other modules can inject methods onto frame metatables.
---@param object table A representative instance whose type metatable receives the methods
---@param methods table<string, function> name -> function pairs to inject
function NRSKNUI:InjectAPI(object, methods)
    if not object or type(methods) ~= 'table' then return end

    local mt = getmetatable(object)
    local index = mt and mt.__index
    if type(index) ~= 'table' then return end

    for name, fn in pairs(methods) do
        if index[name] == nil then
            index[name] = fn
        end
    end
end

-- Hide object utility --

-- Hidden dummy frame we anchor stuff we want to hide to
local hideFrame = CreateFrame('Frame')
hideFrame:Hide()

---Hide objects safely and reparent them to a hidden frame
---@param object Frame|string The frame (or its global name) to hide.
---@param ... string? Optional keys to traverse the frame's children, e.g. 'Inset'.
local function Banish(object, ...)
    if type(object) == 'string' then
        object = _G[object]
    end

    if ... then
        -- Iterate through arguments, they're children referenced by key
        for index = 1, select('#', ...) do
            object = object[select(index, ...)]
        end
    end

    if object then
        if object.HideBase then
            -- Edit mode adds this fallback when it overrides Hide
            object:HideBase(true)
        else
            object:Hide()
        end

        if object.EnableMouse then
            object:EnableMouse(false)
        end

        if object.UnregisterAllEvents then
            object:UnregisterAllEvents()
            -- Useful for hiding secure template based objects
            object:SetAttribute('statehidden', true)
        end

        -- Useful for hiding blizzard objects that respect user placement
        if object.SetUserPlaced then
            pcall(object.SetUserPlaced, object, true)
            pcall(object.SetDontSavePosition, object, true)
        end

        object:SetParent(hideFrame)
    end
end
-- Expose frame so it can be accessed
NRSKNUI.HiddenFrame = hideFrame

-- Texture utility --

---@param object Texture
---@param zoom number? Falls back to NRSKNUI.GlobalZoom if not provided.
local function SetZoom(object, zoom)
    local zoomMult = zoom or NRSKNUI.GlobalZoom
    local texMin = 0.25 * zoomMult
    local texMax = 1 - 0.25 * zoomMult

    object:SetTexCoord(texMin, texMax, texMin, texMax)
end

-- Keyed children commonly carrying default Blizzard frame art
local STRIP_CHILD_KEYS = { 'Bg', 'BG', 'TitleBg', 'TopTileStreaks',
    'Background', 'background', 'NineSlice', 'Inset', 'inset',
    'InsetFrame', 'LeftInset', 'RightInset', 'PortraitContainer',
    'TitleContainer', 'PortraitOverlay', 'ArtOverlayFrame', 'Border',
    'border', 'BorderFrame', 'bottomInset', 'BottomInset', 'bgLeft', 'bgRight',
    'FilligreeOverlay', 'Portrait', 'portrait', 'ScrollFrameBorder', 'ScrollUpBorder', 'ScrollDownBorder',
}

---Strip a single texture region according to the mode.
---@param region Texture
---@param stripType string?
---@param a string|table<string, boolean>|boolean|nil
---@param b boolean?
local function StripRegion(region, stripType, a, b)
    if stripType == 'Kill' then -- Hide and block re-show, for frames that aggressively re-Show their art.
        region:Hide()
        region.Show = region.Hide
    elseif stripType == 'Layer' then -- Hide a specific draw layer (or any layer in the set).
        local layer = region:GetDrawLayer()
        if (type(a) == 'table' and a[layer]) or layer == a then
            region:Hide()
            region:SetAlpha(0)
        end
    elseif stripType == 'Atlas' then -- Hide a specific atlas texture (or any atlas in the set).
        local atlas = region:GetAtlas()
        if (type(a) == 'table' and a[atlas]) or atlas == a then
            region:Hide()
        end
    elseif stripType == 'ClearHide' then -- Clear content and force invisible; alpha 0 survives Blizzard re-setting atlases on state changes, so the art can't come back.
        region:SetTexture(nil)
        region:SetAtlas('')
        region:SetAlpha(0)
    elseif stripType == 'Alpha' then -- Only set alpha to 0, leaving the texture/atlas live for state-driven frames.
        region:SetAlpha(0)
    elseif stripType == 'Keyed' then -- Recurse known keyed children, then clear own regions.
        if a then
            region:Hide()
            region.Show = region.Hide
        elseif b then
            region:SetAlpha(0)
        else
            region:SetTexture(nil)
            region:SetAtlas('')
        end
    else -- Default, clear texture + atlas but leave the region live, so state-driven Blizzard frames can re-drive it via SetAtlas.
        region:SetTexture(nil)
        region:SetAtlas('')
    end
end

---Strip textures/atlases from a frame (or texture) in a controlled way.
---@param object Frame|Texture|string The frame (or its global name) to strip.
---@param stripType string? Selector: nil, 'Keyed', 'Kill', 'Layer', 'Atlas', 'ClearHide', 'Alpha'.
---@param a string|string[]|boolean? For 'Layer'/'Atlas': draw layer / atlas name(s), single or list. For 'Keyed': banish (kill) flag.
---@param b boolean? For 'Keyed': alphaZero — set alpha 0 instead of clearing. Ignored by other modes.
local function StripTextures(object, stripType, a, b)
    -- Resolve a global name to its frame.
    if type(object) == 'string' then
        object = _G[object]
    end
    if not object then return end

    -- Normalize a 'Layer'/'Atlas' key list into a set.
    local matcher = a
    if type(matcher) == 'table' then
        local set = {}
        for _, k in ipairs(matcher) do
            set[k] = true
        end
        matcher = set
    end

    -- A single texture, strip it directly.
    if object:IsObjectType('Texture') then
        ---@cast object Texture
        StripRegion(object, stripType, matcher, b)
        return
    end

    -- 'Keyed', recurse into known keyed children then fall through to strip this frame's own regions.
    if stripType == 'Keyed' then
        local FrameName = object.GetName and object:GetName()

        for _, childKey in next, STRIP_CHILD_KEYS do
            local child = object[childKey] or (FrameName and _G[FrameName .. childKey])

            if child and child.StripTextures then
                -- 'Keyed' never normalizes a arg aka banish, so forward it as-is.
                StripTextures(child, 'Keyed', a, b)
            end
        end
    end

    if not object.GetRegions then return end

    ---@cast object Frame
    for _, region in ipairs({ object:GetRegions() }) do
        if region:IsObjectType('Texture') then
            StripRegion(region, stripType, matcher, b)
        end
    end
end

-- Backdrop utility --

---@class PublicBackdropMixin : Frame
---@field BackDropBorders table
local PublicBackdropMixin = {}

---Set the color of the background
---@param r number
---@param g number
---@param b number
---@param a? number
function PublicBackdropMixin:SetBackgroundColor(r, g, b, a)
    if self.backdropBackground then
        self.backdropBackground:SetColorTexture(r, g, b, a)
    end
end

---Set the color of the backdrops borders
---@param r number
---@param g number
---@param b number
---@param a? number
function PublicBackdropMixin:SetBorderColor(r, g, b, a)
    if self.BackDropBorders then
        for _, edge in pairs(self.BackDropBorders) do
            edge:SetColorTexture(r, g, b, a)
        end
    end
end

---Helper that can be used by ApplySettings function to update coloring with db values.
---@param db table
function PublicBackdropMixin:UpdateBackdropFromDB(db)
    if self.backdropBackground then
        self.backdropBackground:SetColorTexture(db.BackgroundColor[1], db.BackgroundColor[2], db.BackgroundColor[3], db.BackgroundColor[4])
    end
    if self.BackDropBorders then
        for _, edge in pairs(self.BackDropBorders) do
            edge:SetColorTexture(db.BorderColor[1], db.BorderColor[2], db.BorderColor[3], db.BorderColor[4])
        end
    end
end

---Hide or show the backdrop and borders. Used to toggle the backdrop on/off without destroying it.
---@param show boolean
function PublicBackdropMixin:ToggleBackdrop(show)
    if self.backdropBackground then
        if show then
            self.backdropBackground:Show()
        else
            self.backdropBackground:Hide()
        end
    end
    if self.BackDropBorders then
        for _, edge in pairs(self.BackDropBorders) do
            if show then
                edge:Show()
            else
                edge:Hide()
            end
        end
    end
end

local CreateTextureMixin = CreateFrame('Frame').CreateTexture

---@param frame Frame
---@param noBorders boolean? Sometime a manual border is needed, so skip creating the default borders if true.
---@param inset number? Optional inset for the background texture, defaults to 1.
local function CreateBackdrop(frame, noBorders, inset)
    ---@cast frame Frame & PublicBackdropMixin
    Mixin(frame, PublicBackdropMixin)

    local insetBG = inset or 1

    local BG = CreateTextureMixin(frame, nil, 'BACKGROUND')
    BG:SetPixelPoint('TOPLEFT', frame, 'TOPLEFT', insetBG, -insetBG)
    BG:SetPixelPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -insetBG, insetBG)
    frame.backdropBackground = BG
    BG:SetPixelSnap()

    frame:SetBackgroundColor(0, 0, 0, 0.8)

    if noBorders then return end

    frame.BackDropBorders = {}

    local LB = CreateTextureMixin(frame, nil, 'BORDER')
    LB:SetPixelPoint('TOPLEFT', frame, insetBG, -insetBG)
    LB:SetPixelPoint('BOTTOMLEFT', frame, insetBG, insetBG)
    insert(frame.BackDropBorders, LB)
    LB:SetPixelSnap()

    local TB = CreateTextureMixin(frame, nil, 'BORDER')
    TB:SetPixelPoint('TOPLEFT', frame, insetBG, -insetBG)
    TB:SetPixelPoint('TOPRIGHT', frame, -insetBG, -insetBG)
    insert(frame.BackDropBorders, TB)
    TB:SetPixelSnap()

    local RB = CreateTextureMixin(frame, nil, 'BORDER')
    RB:SetPixelPoint('TOPRIGHT', frame, -insetBG, -insetBG)
    RB:SetPixelPoint('BOTTOMRIGHT', frame, -insetBG, insetBG)
    insert(frame.BackDropBorders, RB)
    RB:SetPixelSnap()

    local BB = CreateTextureMixin(frame, nil, 'BORDER')
    BB:SetPixelPoint('BOTTOMLEFT', frame, insetBG, insetBG)
    BB:SetPixelPoint('BOTTOMRIGHT', frame, -insetBG, insetBG)
    insert(frame.BackDropBorders, BB)
    BB:SetPixelSnap()

    frame:SetBorderColor(0, 0, 0, 1)
end

local function HasBackdrop(frame)
    return (not not frame.BackDropBorders) or (not not frame.backdropBackground)
end

---Expose the CreateBackdrop function so it can be used by AuraContainer stuff.
---@param frame Frame
---@param noBorders boolean?
function NRSKNUI:CreateBackdrop(frame, noBorders, inset)
    return CreateBackdrop(frame, noBorders, inset)
end

-- Border utility --

---@class PublicBorderMixin : Frame
---@field Borders table
local PublicBorderMixin = {}

---Set the color of the backdrops borders
---@param r number
---@param g number
---@param b number
---@param a? number
function PublicBorderMixin:SetBorderColor(r, g, b, a)
    if self.Borders then
        for _, edge in pairs(self.Borders) do
            edge:SetColorTexture(r, g, b, a)
        end
    end
end

---Helper that can be used by ApplySettings function to update coloring with db values.
---@param db table
function PublicBorderMixin:UpdateBorderFromDB(db)
    if self.Borders then
        for _, edge in pairs(self.Borders) do
            edge:SetColorTexture(db.BorderColor[1], db.BorderColor[2], db.BorderColor[3], db.BorderColor[4])
        end
    end
end

---@param parent Frame
function PublicBorderMixin:SetBorderParent(parent)
    if self.Borders then
        for _, edge in pairs(self.Borders) do
            edge:SetParent(parent)
        end
    end
end

---@param layer string
---@param sublevel number
function PublicBorderMixin:SetBorderLayer(layer, sublevel)
    if self.Borders then
        for _, edge in pairs(self.Borders) do
            edge:SetDrawLayer(layer, sublevel)
        end
    end
end

---@param shown boolean
function PublicBorderMixin:SetBorderShown(shown)
    if self.Borders then
        for _, edge in pairs(self.Borders) do
            edge:SetShown(shown)
        end
    end
end

---@param parent Frame
function PublicBorderMixin:SetBorderParent(parent)
    if self.Borders then
        for _, edge in pairs(self.Borders) do
            edge:SetParent(parent)
        end
    end
end

---@param frame Frame
local function AddBorders(frame)
    if not frame then return end
    ---@cast frame Frame & PublicBackdropMixin
    Mixin(frame, PublicBorderMixin)

    frame.Borders = {}

    -- Top border
    local TB = CreateTextureMixin(frame, nil, 'OVERLAY')
    TB:SetPixelHeight(1)
    TB:SetPixelPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    TB:SetPixelPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    TB:SetPixelSnap()
    insert(frame.Borders, TB)

    -- Left border
    local LB = CreateTextureMixin(frame, nil, 'OVERLAY')
    LB:SetPixelWidth(1)
    LB:SetPixelPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    LB:SetPixelPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    LB:SetPixelSnap()
    insert(frame.Borders, LB)

    -- Bottom border
    local BB = CreateTextureMixin(frame, nil, 'OVERLAY')
    BB:SetPixelHeight(1)
    BB:SetPixelPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    BB:SetPixelPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    BB:SetPixelSnap()
    insert(frame.Borders, BB)

    -- Right border
    local RB = CreateTextureMixin(frame, nil, 'OVERLAY')
    RB:SetPixelWidth(1)
    RB:SetPixelPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    RB:SetPixelPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    RB:SetPixelSnap()
    insert(frame.Borders, RB)

    frame:SetBorderColor(0, 0, 0, 1)
end

local function HasBorder(frame)
    return not not frame.Borders
end

-- Button utility --

-- Each interactive state swaps Blizzard's art for a flat additive overlay clamped inside
-- the button. Driven from a table so all three states share one code path.
local BUTTON_STATES = {
    { field = 'hover',   set = 'SetHighlightTexture', get = 'GetHighlightTexture', r = 1,   g = 1,   b = 1,   a = 0.3 },
    { field = 'pushed',  set = 'SetPushedTexture',    get = 'GetPushedTexture',    r = 0.4, g = 0.4, b = 0.4, a = 0.3 },
    { field = 'checked', set = 'SetCheckedTexture',   get = 'GetCheckedTexture',   r = 1,   g = 1,   b = 1,   a = 0.3 },
}

---@param button Button
---@param noHover boolean?
---@param noPushed boolean?
---@param noChecked boolean?
local function StyleButton(button, noHover, noPushed, noChecked)
    if not button.CreateTexture then return end

    local skip = { hover = noHover, pushed = noPushed, checked = noChecked }

    for _, state in ipairs(BUTTON_STATES) do
        if button[state.set] and not button[state.field] and not skip[state.field] then
            button[state.set](button, NRSKNUI.ClearTexture)

            local texture = button[state.get](button)
            texture:SetPixelInside()
            texture:SetBlendMode('ADD')
            texture:SetColorTexture(state.r, state.g, state.b, state.a)
            button[state.field] = texture
        end
    end
end

-- Positioning utility --

-- ApplyPosition injected onto the frame widget types.
local function ApplyPosition(self, Config, setParent)
    if not self or not Config then return end
    local posConfig = Config.Position
    if not posConfig then return end

    local parent
    if Config.anchorFrameType == 'SCREEN' or Config.anchorFrameType == 'UIPARENT' then
        parent = UIParent
    elseif Config.anchorFrameType == 'SELECTFRAME' and Config.ParentFrame then
        local frame = _G[Config.ParentFrame]
        parent = frame or UIParent
    end
    parent = parent or UIParent

    if setParent then
        self:SetParent(parent)
    end

    self:ClearAllPoints()
    self:SetPixelPoint(posConfig.AnchorFrom or 'CENTER', parent, posConfig.AnchorTo or 'CENTER', posConfig.XOffset or 0, posConfig.YOffset or 0)
    self:SetFrameStrata(Config.Strata or 'MEDIUM')
end

-- Fontstring utility --

---Iterates over a frame's child frames and styles each FontString region with the configured font, outline, and a caller-defined size.
---@param frame Frame
---@param source table
---@param getSize fun(fontString: FontString, parent: Frame): number?
local function StyleChildFontStrings(frame, source, getSize, outline, shadow, skip, setOwner)
    if type(frame) == 'string' then
        frame = _G[frame]
    end

    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())

        for j = 1, child:GetNumRegions() do
            local region = select(j, child:GetRegions())

            if region:IsObjectType('FontString') then
                local size = getSize and getSize(region, child) or source.FontSize

                region:SetFontStyle(source, size, outline, shadow, skip, setOwner)
            end
        end
    end
end

-- OnUpdate Utility --

---@param frame Frame
---@param throttle? number Omit together with callback to clear the OnUpdate handler
---@param callback? fun(frame: Frame)
local function ApplyOnUpdate(frame, throttle, callback)
    if throttle and callback then
        local total = 0
        frame:SetScript('OnUpdate', function(_, elapsed)
            total = total + elapsed
            if total > throttle then
                total = 0
                callback(frame)
            end
        end)
    else
        frame:SetScript('OnUpdate', nil)
    end
end

-- Coalesced One-Shot Update --
-- Blizzard's dirty pattern: install a handler once, then arm it. Repeated arms before the next frame
-- collapse into a single run, and the engine auto-disarms (resets to Disabled) right before firing.


local RunOnce = Enum and Enum.OnUpdateMode.RunOnce
local RunWhenVisibleOnce = Enum and Enum.OnUpdateMode.RunWhenVisibleOnce
local OnUpdateDisabled = Enum and Enum.OnUpdateMode.Disabled

local function RunScheduledUpdate(frame)
    local callback = frame._scheduledUpdate
    if callback then callback(frame) end
end

---Install a coalesced one-shot handler, pair with ScheduleUpdate to run it once on the next frame.
---Overwrites any existing OnUpdate script on the frame.
---@param frame Frame
---@param callback fun(frame: Frame)
---@param whenVisible? boolean only run while the frame is shown; omit to run regardless of visibility
local function SetScheduledUpdate(frame, callback, whenVisible)
    frame._scheduledUpdate = callback
    frame._scheduledMode = whenVisible and RunWhenVisibleOnce or RunOnce
    frame:SetScript('OnUpdate', RunScheduledUpdate)
    frame:SetOnUpdateMode(OnUpdateDisabled)
end

---Arm the handler set by SetScheduledUpdate to run once on the next frame, repeated calls coalesce.
---@param frame Frame
local function ScheduleUpdate(frame)
    if frame._scheduledMode then
        frame:SetOnUpdateMode(frame._scheduledMode)
    end
end

---Size a backdrop to fit a FontString's widest possible text.
---@param self Frame
---@param fontString FontString The string region measured and, on resize, temporarily clobbered.
---@param text string The exact (possibly colored) text about to be displayed.
---@param padX number Horizontal padding added to each side.
---@param padY number Vertical padding added to each side.
---@return boolean resized True when the backdrop was resized this call (caller must re-apply text).
local function FitBackdropToText(self, fontString, text, padX, padY)
    -- Strip color escapes and mask digits: two values with the same skeleton keep one width.
    local bare = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
    local key = (bare:gsub('%d', '#'))
    if key == self.NUIBackdropShape then return false end
    self.NUIBackdropShape = key

    -- Widest glyph in every digit slot is a true upper bound for this shape, so it can't overflow.
    local worst = (bare:gsub('%d', fontString:GetWidestDigit()))
    fontString:SetText(worst)
    self:SetPixelSize(fontString:GetStringWidth() + padX * 2, fontString:GetStringHeight() + padY * 2)
    return true
end

do
    -- Inject methods in this file.
    local injectMethods = {
        CreateBackdrop = CreateBackdrop,
        FitBackdropToText = FitBackdropToText,
        AddBorders = AddBorders,
        HasBackdrop = HasBackdrop,
        HasBorder = HasBorder,
        StripTextures = StripTextures,
        ApplyPosition = ApplyPosition,
        Banish = Banish,
        StyleChildFontStrings = StyleChildFontStrings,
        SetZoom = SetZoom,
        SetPixelSize = PixelMixin.SetPixelSize,
        SetPixelWidth = PixelMixin.SetPixelWidth,
        SetPixelHeight = PixelMixin.SetPixelHeight,
        SetPixelPoint = PixelMixin.SetPixelPoint,
        SetGridPoint = PixelMixin.SetGridPoint,
        SetPixelInside = PixelMixin.SetPixelInside,
        SetPixelOutside = PixelMixin.SetPixelOutside,
        SetPixelSnap = PixelMixin.SetPixelSnap,
        StyleButton = StyleButton,
        ApplyOnUpdate = ApplyOnUpdate,
        SetScheduledUpdate = SetScheduledUpdate,
        ScheduleUpdate = ScheduleUpdate,
    }

    -- Small wrapper to call the NRSKNUI:InjectAPI method, so we don't have to pass the methods
    local function InjectAPI(object)
        NRSKNUI:InjectAPI(object, injectMethods)
    end

    local handledAPI = { Frame = true }
    local object = CreateFrame('Frame')

    InjectAPI(object)
    InjectAPI(object:CreateTexture())
    InjectAPI(object:CreateMaskTexture())
    InjectAPI(object:CreateFontString())

    object = EnumerateFrames()
    while object do
        local objectType = object:GetObjectType()
        if not object:IsForbidden() and not handledAPI[objectType] then
            InjectAPI(object)
            handledAPI[objectType] = true
        end

        object = EnumerateFrames(object)
    end

    InjectAPI(CreateFrame('ScrollFrame'))
end
