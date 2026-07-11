---@class NRSKNUI
local NRSKNUI = select(2, ...)

local pairs = pairs
local type = type
local getmetatable = getmetatable
local CreateFrame = CreateFrame
local select = select
local pcall = pcall
local ipairs = ipairs
local Mixin = Mixin
local table_insert = table.insert
local EnumerateFrames = EnumerateFrames

local _G = _G

-- Exposed Injection API so that other modules can inject methods onto frame metatables.
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
local hidden = CreateFrame('Frame')
hidden:Hide()

---Hide objects safely and reparent them to a hidden frame
---@param object Frame|string The frame (or its global name) to hide.
---@param ... string? Optional keys to traverse the frame's children, e.g. 'Inset'.
function NRSKNUI:Banish(object, ...)
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

        object:SetParent(hidden)
    end
end

-- Expose frame so it can be accessed
NRSKNUI.HiddenFrame = hidden

local function Banish(object, ...)
    NRSKNUI:Banish(object, ...)
end

-- Texture utility --

-- Keyed children commonly carrying default Blizzard frame art
local STRIP_CHILD_KEYS = { 'Bg', 'BG', 'TitleBg', 'TopTileStreaks',
    'Background', 'background', 'NineSlice', 'Inset', 'inset',
    'InsetFrame', 'LeftInset', 'RightInset', 'PortraitContainer',
    'TitleContainer', 'PortraitOverlay', 'ArtOverlayFrame', 'Border',
    'border', 'BorderFrame', 'bottomInset', 'BottomInset', 'bgLeft', 'bgRight',
    'FilligreeOverlay', 'Portrait', 'portrait', 'ScrollFrameBorder', 'ScrollUpBorder', 'ScrollDownBorder',
}

---Strip textures/atlases from a frame in a controlled way.
---@param object Frame|string|Texture The frame (or its global name) to strip.
---@param stripType string? Selector:
---  nil     = clear every texture (SetTexture/SetAtlas nil) but leave regions live for state-driven frames,
---  'Kill'  = hide every texture and block re-show,
---  'Layer' = hide textures whose draw layer matches `key`,
---  'Atlas' = hide textures whose atlas matches `key`,
---  'ClearHide' = clear + force alpha 0, so state-driven frames can re-atlas but stay invisible,
---  'Keyed' = strip default art from known keyed children (NineSlice, Inset, Bg etc).
---  'Alpha' = Only sets alpha to 0 for all textures, leaving them live for state-driven frames.
---@param key string|string[]? Draw layer name(s) for 'Layer', atlas name(s) for 'Atlas'. Accepts a single value or a list.
function NRSKNUI:StripTextures(object, stripType, key)
    -- If the frame is a texture, clear it and return.
    if object:IsObjectType('Texture') then
        object:SetTexture(NRSKNUI.ClearTexture)
        object:SetAtlas('')
        return
    end

    -- If the frame is a string, look it up in the global table and reassign it to the frame variable.
    if type(object) == 'string' then
        object = _G[object]
    end

    -- If the frame is nil or not a valid frame, return early.
    if not object then
        return
    end

    -- Strip default art from a frame's known keyed children.
    if stripType == 'Keyed' then
        for _, childKey in ipairs(STRIP_CHILD_KEYS) do
            local child = object[childKey]
            if child then
                if child.IsObjectType and child:IsObjectType('Texture') then
                    -- Clear the texture and atlas, and force alpha 0 so state-driven frames can't re-show it.
                    child:SetTexture(nil)
                    child:SetAtlas('')
                    child:SetAlpha(0)
                elseif child.GetRegions then  -- Recurse into the child to strip its own keyed children.
                    self:StripTextures(child) -- clear the child's own art

                    -- If the child has a NineSlice, hide its regions too.
                    if child.NineSlice then
                        self:StripTextures(child.NineSlice)
                    end

                    -- If the child has a Bg, hide its regions too.
                    if child.Bg and child.Bg.SetTexture then
                        child.Bg:SetTexture(nil)
                        child.Bg:SetAtlas('')
                        child.Bg:SetAlpha(0)
                    end
                end
            end
        end
        return
    end

    if not object.GetRegions then return end

    -- When key is a list, turn it into a set so region matching is a single lookup.
    local keySet
    if type(key) == 'table' then
        keySet = {}
        for _, k in ipairs(key) do keySet[k] = true end
    end

    for _, region in ipairs({ object:GetRegions() }) do
        if region:IsObjectType('Texture') then
            if stripType == 'Kill' then
                -- Hide and block re-show, for frames that aggressively re-Show their art.
                region:Hide()
                region.Show = region.Hide
            elseif stripType == 'Layer' then
                -- Hide a specific draw layer (or any layer in the key list).
                local layer = region:GetDrawLayer()
                if keySet and keySet[layer] or layer == key then
                    region:Hide()
                    region:SetAlpha(0)
                end
            elseif stripType == 'Atlas' then
                -- Hide a specific atlas texture (or any atlas in the key list).
                local atlas = region:GetAtlas()
                if keySet and keySet[atlas] or atlas == key then
                    region:Hide()
                end
            elseif stripType == 'ClearHide' then
                -- Clear content and force invisible; alpha 0 survives Blizzard
                -- re-setting atlases on state changes, so the art can't come back.
                region:SetTexture(nil)
                region:SetAtlas('')
                region:SetAlpha(0)
            elseif stripType == 'Alpha' then
                -- Only set alpha to 0, leaving the texture/atlas live for state-driven frames.
                region:SetAlpha(0)
            else
                -- Default: clear texture + atlas but leave the region live, so
                -- state-driven Blizzard frames can re-drive it via SetAtlas.
                region:SetTexture(nil)
                region:SetAtlas('')
            end
        end
    end
end

local function StripTextures(object, stripType, key)
    NRSKNUI:StripTextures(object, stripType, key)
end

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
---@param template string? Optional template name, e.g. 'BorderTemplate'
function NRSKNUI:CreateBackdrop(frame, template)
    ---@cast frame Frame & PublicBackdropMixin
    Mixin(frame, PublicBackdropMixin)

    frame.BackDropBorders = {}

    if template ~= 'BorderTemplate' then
        local BG = CreateTextureMixin(frame, nil, 'BACKGROUND')
        BG:SetPoint('TOPLEFT', frame, 'TOPLEFT', 1, -1)
        BG:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -1, 1)
        frame.backdropBackground = BG
        NRSKNUI:PixelPerfect(BG)

        frame:SetBackgroundColor(0, 0, 0, 0.8)
    end

    local LB = CreateTextureMixin(frame, nil, 'BORDER')
    LB:SetPoint('TOPLEFT', frame, 1, -1)
    LB:SetPoint('BOTTOMLEFT', frame, 1, 1)
    table_insert(frame.BackDropBorders, LB)
    NRSKNUI:PixelPerfect(LB)

    local TB = CreateTextureMixin(frame, nil, 'BORDER')
    TB:SetPoint('TOPLEFT', frame, 1, -1)
    TB:SetPoint('TOPRIGHT', frame, -1, -1)
    table_insert(frame.BackDropBorders, TB)
    NRSKNUI:PixelPerfect(TB)

    local RB = CreateTextureMixin(frame, nil, 'BORDER')
    RB:SetPoint('TOPRIGHT', frame, -1, -1)
    RB:SetPoint('BOTTOMRIGHT', frame, -1, 1)
    table_insert(frame.BackDropBorders, RB)
    NRSKNUI:PixelPerfect(RB)

    local BB = CreateTextureMixin(frame, nil, 'BORDER')
    BB:SetPoint('BOTTOMLEFT', frame, 1, 1)
    BB:SetPoint('BOTTOMRIGHT', frame, -1, 1)
    table_insert(frame.BackDropBorders, BB)
    NRSKNUI:PixelPerfect(BB)

    frame:SetBorderColor(0, 0, 0, 1)
end

---Check if we already added a backdrop to the frame
---@param frame Frame
---@return boolean
function NRSKNUI:HasBackdrop(frame)
    return not not frame.BackDropBorders
end

local function CreateBackdrop(frame, template)
    NRSKNUI:CreateBackdrop(frame, template)
end

local function HasBackdrop(frame)
    return NRSKNUI:HasBackdrop(frame)
end

-- Positioning utility --

--TODO: Make local
-- Resolve anchor frame: SCREEN, UIPARENT or SELECTFRAME
---@param anchorFrameType string
---@param parentFrameName string
---@return Frame
function NRSKNUI:ResolveAnchorFrame(anchorFrameType, parentFrameName)
    if anchorFrameType == 'SCREEN' or anchorFrameType == 'UIPARENT' then
        return UIParent
    elseif anchorFrameType == 'SELECTFRAME' and parentFrameName then
        local frame = _G[parentFrameName]
        return frame or UIParent
    end
    return UIParent
end

-- ApplyPosition injected onto the frame widget types, frame:ApplyPosition(self, Config, setParent)
local function ApplyPosition(self, Config, setParent)
    if not self or not Config then return end
    local posConfig = Config.Position
    if not posConfig then return end

    local parent = NRSKNUI:ResolveAnchorFrame(Config.anchorFrameType, Config.ParentFrame)

    if setParent then self:SetParent(parent) end

    self:ClearAllPoints()
    self:SetPoint(posConfig.AnchorFrom or 'CENTER', parent, posConfig.AnchorTo or 'CENTER', posConfig.XOffset or 0,
        posConfig.YOffset or 0)
    self:SetFrameStrata(Config.Strata or 'MEDIUM')
    NRSKNUI:SnapFrameToPixels(self, Config.ForcePixelPerfect)
end

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

---@param obj Texture
---@param zoom number?
local function SetZoom(obj, zoom)
    local zoomMult = zoom or NRSKNUI.GlobalZoom
    local texMin = 0.25 * zoomMult
    local texMax = 1 - 0.25 * zoomMult

    obj:SetTexCoord(texMin, texMax, texMin, texMax)
end

do
    -- Inject methods in this file.
    local injectMethods = {
        CreateBackdrop = CreateBackdrop,
        HasBackdrop = HasBackdrop,
        StripTextures = StripTextures,
        ApplyPosition = ApplyPosition,
        Banish = Banish,
        StyleChildFontStrings = StyleChildFontStrings,
        SetZoom = SetZoom,
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
