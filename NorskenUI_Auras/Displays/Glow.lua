---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local pairs, ipairs = pairs, ipairs
local min, abs, ceil = math.min, math.abs, math.ceil
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local unpack = unpack
local wipe = wipe

local ICON_ALERT = 'Interface\\SpellActivationOverlay\\IconAlert'
local ICON_ALERT_ANTS = 'Interface\\SpellActivationOverlay\\IconAlertAnts'
local SHINE = 'Interface\\Artifacts\\Artifacts'
local SHINE_COORDS = { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 } -- LibCustomGlow's retail sparkle
local WHITE = 'Interface\\BUTTONS\\WHITE8X8'
local MASK_HOLE = 'Interface\\AdventureMap\\BrokenIsles\\AM_29' -- LibCustomGlow's mask: clear inside, white outside when clamped
local GOLD = { 0.95, 0.95, 0.32, 1 }

-- a glow saved before a setting existed draws that setting from the template
---@type table
CDM.GLOW_DEFAULTS = CDM.SUBREGION_TEMPLATES.glow

--[[
Glow sub elements: Blizzard's proc and assisted-combat art, the classic ants, a pixel border and autocast sparkles.
All of it runs on animation groups, since a glow inside an aura button never gets an OnUpdate.
]]

-- Parts --

---@param settings table
---@param tintable boolean flipbooks keep their own art color unless a color is picked
---@return number[]? color nil for the art's own color
local function ResolveColor(settings, tintable)
    if settings.ColorMode == 'class' then
        return NRSKNUI:GetPlayerClassColor()
    end
    if settings.ColorMode == 'custom' then
        return settings.Color
    end
    return tintable and GOLD or nil
end

---@param texture Texture
---@param color number[]?
local function Tint(texture, color)
    texture:SetDesaturated(color ~= nil)
    if color then
        texture:SetVertexColor(unpack(color))
    else
        texture:SetVertexColor(1, 1, 1, 1)
    end
end

---@class CDMGlow
local Glow = {}
Glow.__index = Glow

---A texture kept for the glow's lifetime; unused ones go to alpha 0, never Hide, since a pandemic
---region's shown state belongs to the client.
---@param key string
---@param layer DrawLayer?
---@param parent Frame? a frame of the glow's own, see Glow:Frame
---@return Texture
function Glow:Part(key, layer, parent)
    local texture = self.parts[key]
    if not texture then
        texture = (parent or self.host):CreateTexture(nil, layer or 'OVERLAY')
        texture:SetAlpha(0)
        self.parts[key] = texture
        if self.onTexture then
            self.onTexture(texture)
        end
    end
    self.active[key] = true
    return texture
end

---A plain frame inside the glow, for parts that need one (a clipping strip).
---@param key string
---@return Frame
function Glow:Frame(key)
    local frame = self.frames[key]
    if not frame then
        frame = CreateFrame('Frame', nil, self.host)
        self.frames[key] = frame
    end
    return frame
end

---A mask that hides everything further than `inset` inside the glow's edge.
---@param index number
---@param inset number
---@return MaskTexture
function Glow:Mask(index, inset)
    local mask = self.masks[index]
    if not mask then
        mask = self.host:CreateMaskTexture()
        mask:SetTexture(MASK_HOLE, 'CLAMPTOWHITE', 'CLAMPTOWHITE')
        self.masks[index] = mask
    end
    mask:ClearAllPoints()
    mask:SetPoint('TOPLEFT', self.host, 'TOPLEFT', inset, -inset)
    mask:SetPoint('BOTTOMRIGHT', self.host, 'BOTTOMRIGHT', -inset, inset)
    return mask
end

---@param key string
---@param texture Texture
---@param build fun(group: AnimationGroup)
---@return AnimationGroup
function Glow:Group(key, texture, build)
    local group = self.groups[key]
    if not group then
        group = texture:CreateAnimationGroup()
        build(group)
        self.groups[key] = group
    end
    return group
end

---@param texture Texture
---@param host Frame
---@param width number
---@param height number
---@param scale number
local function Centre(texture, host, width, height, scale)
    texture:ClearAllPoints()
    texture:NUISetPixelPoint('CENTER', host, 'CENTER', 0, 0)
    texture:NUISetPixelSize(width * scale, height * scale)
end

---@param group AnimationGroup
---@param rows number
---@param columns number
---@param frames number
---@param duration number
---@param frameWidth number?
---@param frameHeight number?
local function FlipBook(group, rows, columns, frames, duration, frameWidth, frameHeight)
    local anim = group:CreateAnimation('FlipBook')
    anim:SetFlipBookRows(rows)
    anim:SetFlipBookColumns(columns)
    anim:SetFlipBookFrames(frames)
    anim:SetFlipBookFrameWidth(frameWidth or 0)
    anim:SetFlipBookFrameHeight(frameHeight or 0)
    anim:SetDuration(duration)
    return anim
end

-- Types --

local BUILDERS = {}

-- Blizzard's proc glow (ActionButtonSpellAlerts.xml): a loop 20% outside the icon, a start burst first.
function BUILDERS.modern(self, settings, width, height, starting)
    local loop = self:Part('procLoop')
    loop:SetAtlas('UI-HUD-ActionBar-Proc-Loop-Flipbook')
    Centre(loop, self.host, width, height, 1.4)
    Tint(loop, ResolveColor(settings, false))
    loop:SetAlpha(1)
    self:Group('procLoop', loop, function(group)
        group:SetLooping('REPEAT')
        FlipBook(group, 6, 5, 30, 1)
    end):Play()

    if settings.StartAnim and starting then
        local burst = self:Part('procStart')
        burst:SetAtlas('UI-HUD-ActionBar-Proc-Start-Flipbook')
        burst:SetBlendMode('ADD')
        Centre(burst, self.host, width, height, 150 / 45)
        Tint(burst, ResolveColor(settings, false))
        burst:SetAlpha(1)
        local group = self:Group('procStart', burst, function(created)
            created:SetToFinalAlpha(true)
            FlipBook(created, 6, 5, 30, 0.7)
            local fade = created:CreateAnimation('Alpha')
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0)
            fade:SetDuration(0.001)
            fade:SetOrder(2)
        end)
        group:Stop()
        group:Play()
    end
end

-- The assisted-combat ants (ActionButtonComponentTemplate.xml): a 66px flipbook on a 45px button.
function BUILDERS.gcd(self, settings, width, height)
    local color = ResolveColor(settings, false)
    -- The blue art desaturates to a dark grey; an additive second copy lifts a picked color back to full brightness.
    local keys = color and { 'gcdAnts', 'gcdAntsBoost' } or { 'gcdAnts' }
    local groups, restart = {}, false
    for i, key in ipairs(keys) do
        local ants = self:Part(key)
        ants:SetAtlas('rotationhelper_ants_flipbook')
        ants:SetBlendMode(i == 2 and 'ADD' or 'BLEND')
        Centre(ants, self.host, width, height, 66 / 45)
        Tint(ants, color)
        ants:SetAlpha(1)
        local group = self:Group(key, ants, function(g)
            g:SetLooping('REPEAT')
            FlipBook(g, 6, 5, 30, 1)
        end)
        groups[i] = group
        restart = restart or not group:IsPlaying()
    end
    if restart then -- both copies start together so their frames line up
        for _, group in ipairs(groups) do
            group:Stop()
            group:Play()
        end
    end
end

---@param self CDMGlow
local function Ants(self, settings, width, height)
    local ants = self:Part('alertAnts')
    ants:SetTexture(ICON_ALERT_ANTS)
    Centre(ants, self.host, width, height, 1.4 * 0.85)
    Tint(ants, ResolveColor(settings, false))
    ants:SetAlpha(1)
    self:Group('alertAnts', ants, function(group)
        group:SetLooping('REPEAT')
        FlipBook(group, 5, 5, 22, 0.66, 48, 48) -- 48px frames on a 256px sheet
    end):Play()
end

function BUILDERS.classic(self, settings, width, height)
    Ants(self, settings, width, height)
end

-- LibCustomGlow's action button glow at rest: the outer halo and the ants.
function BUILDERS.button(self, settings, width, height)
    local halo = self:Part('alertHalo', 'ARTWORK')
    halo:SetTexture(ICON_ALERT)
    halo:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    Centre(halo, self.host, width, height, 1.4)
    Tint(halo, ResolveColor(settings, false))
    halo:SetAlpha(1)
    Ants(self, settings, width, height)
end

-- LibCustomGlow's pixel glow on native animations, since an aura button never runs our OnUpdate; clockwise from the bottom left.
local EDGES = {
    { key = 'left',   from = 'BOTTOMLEFT',  to = 'TOPLEFT',     anchor = 'BOTTOM', dx = 0,  dy = 1 },
    { key = 'top',    from = 'TOPLEFT',     to = 'TOPRIGHT',    anchor = 'LEFT',   dx = 1,  dy = 0 },
    { key = 'right',  from = 'TOPRIGHT',    to = 'BOTTOMRIGHT', anchor = 'TOP',    dx = 0,  dy = -1 },
    { key = 'bottom', from = 'BOTTOMRIGHT', to = 'BOTTOMLEFT',  anchor = 'RIGHT',  dx = -1, dy = 0 },
}

function BUILDERS.pixel(self, settings, width, height)
    local color = ResolveColor(settings, true)
    local th = settings.Thickness
    local length = min(settings.Length, width, height)
    local spacing = 2 * (width + height) / settings.Lines
    local step = 1 / settings.Frequency / settings.Lines -- seconds for a line to reach the next one's place
    local shape = width .. ':' .. height .. ':' .. th .. ':' .. length .. ':' .. settings.Lines .. ':' .. settings.Frequency
    local restart = self.pixelShape ~= shape -- restyles start the glow again; only a new shape may restart the lines
    local groups = {}
    local along = 0
    for _, edge in ipairs(EDGES) do
        local horizontal = edge.dx ~= 0
        local size = horizontal and width or height
        local strip = self:Frame('strip' .. edge.key)
        strip:SetClipsChildren(true)
        strip:ClearAllPoints()
        strip:SetPoint(edge.from, self.host, edge.from)
        strip:SetPoint(edge.to, self.host, edge.to)
        if horizontal then
            strip:SetHeight(th)
        else
            strip:SetWidth(th)
        end

        local scale = (size - th) / size -- a line's start only runs over size - th, so its end lands on the corner
        local gap = spacing * scale
        local dash = length * scale + th
        local phase = ((along + length / 2) * scale) % gap
        for j = -ceil(dash / gap), ceil(size / gap) do
            local key = 'line' .. edge.key .. j
            local line = self:Part(key, 'ARTWORK', strip)
            line:SetTexture(WHITE)
            line:SetDrawLayer('ARTWORK', 7)
            line:ClearAllPoints()
            local offset = j * gap - phase
            line:SetPoint(edge.anchor, strip, edge.anchor, edge.dx * offset, edge.dy * offset)
            if horizontal then
                line:SetSize(dash, th)
            else
                line:SetSize(th, dash)
            end
            Tint(line, color)
            line:SetAlpha(1)

            local group = self:Group(key, line, function(created)
                created:SetLooping('REPEAT')
                created.slide = created:CreateAnimation('Translation')
            end)
            group.dx, group.dy = edge.dx * gap, edge.dy * gap
            groups[#groups + 1] = group
            restart = restart or not group:IsPlaying()
        end
        along = along + size
    end
    if restart then -- every line starts together so they stay evenly spaced
        for _, group in ipairs(groups) do
            group:Stop()
            group.slide:SetOffset(group.dx, group.dy)
            group.slide:SetDuration(step)
        end
        for _, group in ipairs(groups) do
            group:Play()
        end
        self.pixelShape = shape
    end

    if settings.Border then
        local back = self:Part('lineBack', 'ARTWORK')
        back:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        back:SetDrawLayer('ARTWORK', 6)
        back:SetAllPoints(self.host)
        local outer = self:Mask(2, th + 1)
        if back:GetNumMaskTextures() < 1 then
            back:AddMaskTexture(outer)
        end
        back:SetAlpha(1)
    end
end

-- LibCustomGlow's four rings of four sparkles, each moving corner to corner on chained translations.
-- Ring n laps n times slower and starts a quarter lap on, so the rings drift apart instead of travelling as one.
local SPARKLE_SIZES = { 7, 6, 5, 4 }
local AUTOCAST_LAP = 2
local CORNERS = { 'TOPLEFT', 'TOPRIGHT', 'BOTTOMRIGHT', 'BOTTOMLEFT' }

function BUILDERS.autocast(self, settings, width, height)
    local color = ResolveColor(settings, true)
    local perimeter = 2 * (width + height)
    -- Clockwise moves from each corner, as offsets.
    local moves = { { width, 0 }, { 0, -height }, { -width, 0 }, { 0, height } }
    for ring, size in ipairs(SPARKLE_SIZES) do
        local lap = AUTOCAST_LAP * ring
        for dot = 1, 4 do
            local key = 'spark' .. ring .. '_' .. dot
            local texture = self:Part(key)
            texture:SetTexture(SHINE)
            texture:SetTexCoord(unpack(SHINE_COORDS))
            texture:SetBlendMode('ADD')
            texture:NUISetPixelSize(size, size)
            texture:ClearAllPoints()
            texture:NUISetPixelPoint('CENTER', self.host, CORNERS[dot], 0, 0)
            Tint(texture, color)
            texture:SetAlpha(1)

            local group = self:Group(key, texture, function(created)
                created:SetLooping('REPEAT')
                created.moves = {}
                for step = 1, 4 do
                    created.moves[step] = created:CreateAnimation('Translation')
                    created.moves[step]:SetOrder(step)
                end
            end)
            group:Stop()
            for step = 0, 3 do
                local move = moves[(dot - 1 + step) % 4 + 1]
                local anim = group.moves[step + 1]
                anim:SetOffset(move[1], move[2])
                anim:SetDuration(lap * (abs(move[1]) + abs(move[2])) / perimeter)
            end
            group:Play(false, lap * (ring - 1) / 4)
        end
    end
end

-- Glow --

---@param settings table
---@param width number
---@param height number
---@param starting boolean? play a start animation, when the type has one
function Glow:Start(settings, width, height, starting)
    local saved = settings
    settings = setmetatable({}, {
        __index = function(_, key)
            local value = saved[key]
            if value == nil then
                return CDM.GLOW_DEFAULTS[key]
            end
            return value
        end
    })
    local previous = self.active
    self.active = {}
    local build = BUILDERS[settings.Type] or BUILDERS.modern
    build(self, settings, width, height, starting)
    for key in pairs(previous) do
        if not self.active[key] then
            self.parts[key]:SetAlpha(0)
            if self.groups[key] then
                self.groups[key]:Stop()
            end
        end
    end
    self.host:Show()
end

function Glow:Stop()
    for key in pairs(self.active) do
        self.parts[key]:SetAlpha(0)
        if self.groups[key] then
            self.groups[key]:Stop()
        end
    end
    wipe(self.active)
end

---A glow drawing on `host`, which the caller sizes and places; `onTexture` sees every texture it makes.
---@param host Frame
---@param onTexture fun(texture: Texture)?
---@return CDMGlow
function CDM:CreateGlow(host, onTexture)
    return setmetatable({ host = host, parts = {}, groups = {}, masks = {}, frames = {}, active = {}, onTexture = onTexture }, Glow)
end
