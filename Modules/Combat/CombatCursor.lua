---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CursorCircle
local CursorCircle = NRSKNUI:GetModule('CursorCircle')

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local ipairs = ipairs

local UIParent = UIParent

local GCD_ID = 61304
local HOLD_DELAY = 0.15 -- For mouse button held visibility modes, without delay normal clicks shows the ring.

---@class CursorCircleTexture
---@field key string
---@field path string
local circleTypes = {
    { key = 'Circle 1', path = 'Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Circle.tga' },
    { key = 'Circle 2', path = 'Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Aura73.tga' },
    { key = 'Circle 3', path = 'Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Aura103.tga' },
    { key = 'Circle 4', path = 'Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraThin.png' },
    { key = 'Circle 5', path = 'Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraMedium.png' },
    { key = 'Circle 6', path = 'Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraThick.png' },
}

---@class GCDModeOption
---@field key string
---@field text string
local gcdModes = {
    { key = 'disabled',   text = 'Disabled' },
    { key = 'integrated', text = 'Integrated' },
    { key = 'separate',   text = 'Separate Ring' },
}

---@class VisibilityModeOption
---@field key string
---@field text string
local visibilityModes = {
    { key = 'always',          text = 'Always Visible' },
    { key = 'mouseDown',       text = 'Mouse Button Held' },
    { key = 'mouseDownCombat', text = 'Mouse Button Held In Combat' },
    { key = 'combat',          text = 'In Combat Only' },
}

-- Expose for GUI
CursorCircle.Textures = circleTypes
CursorCircle.GCDModeOptions = gcdModes
CursorCircle.VisibilityModeOptions = visibilityModes

---Resolve a texture path from a given texture key.
---@param textureKey string
---@return string texturePath
local function ResolveTexturePath(textureKey)
    for _, tex in ipairs(circleTypes) do
        if tex.key == textureKey then
            return tex.path
        end
    end
    return circleTypes[1].path
end

---Shared swipe cooldown setup, used by both the integrated and separate rings.
---@param cooldown CooldownFrame
---@param frameLevel number
local function ConfigureCooldown(cooldown, frameLevel)
    cooldown:SetAllPoints()
    cooldown:EnableMouse(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetDrawBling(false)
    cooldown:SetUseCircularEdge(true)
    cooldown:SetFrameLevel(frameLevel)
end

function CursorCircle:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.CursorCircle
end

function CursorCircle:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function CursorCircle:CreateFrames()
    if self.follower then return end

    -- Create the main follower frame that will follow the cursor.
    local follower = CreateFrame('Frame', 'NRSKNUI_CursorCircleFrame', UIParent)
    follower:SetPixelSize(1)
    follower:SetPixelPoint('CENTER')
    follower:EnableMouse(false)
    follower:Hide()

    -- Main ring
    local ring = CreateFrame('Frame', nil, follower)
    ring:SetPixelPoint('CENTER')
    ring:SetFrameStrata('TOOLTIP')
    ring:EnableMouse(false)

    -- Main ring texture
    ring.texture = ring:CreateTexture(nil, 'BACKGROUND')
    ring.texture:SetAllPoints()
    ring.texture:SetPixelSnap()

    -- Main ring cooldown swipe
    ring.cooldown = CreateFrame('Cooldown', nil, ring, 'CooldownFrameTemplate')
    ConfigureCooldown(ring.cooldown, ring:GetFrameLevel() + 2)
    ring.cooldown:Hide()

    -- GCD ring
    local gcdRing = CreateFrame('Frame', nil, follower)
    gcdRing:SetPixelPoint('CENTER')
    gcdRing:SetFrameStrata('TOOLTIP')
    gcdRing:EnableMouse(false)

    -- GCD ring texture
    gcdRing.texture = gcdRing:CreateTexture(nil, 'BACKGROUND')
    gcdRing.texture:SetAllPoints()
    gcdRing.texture:SetPixelSnap()

    -- GCD ring cooldown swipe
    gcdRing.cooldown = CreateFrame('Cooldown', nil, gcdRing, 'CooldownFrameTemplate')
    ConfigureCooldown(gcdRing.cooldown, gcdRing:GetFrameLevel() + 2)
    gcdRing.cooldown:Hide()
    gcdRing:Hide()

    -- Store references to the created frames for later use.
    self.follower = follower
    self.holdTime = 0
    self.ring = ring
    self.gcdRing = gcdRing

    -- Install OnUpdate script, follows the 1x1px follower frame.
    follower:SetScript('OnUpdate', function(_, elapsed)
        local scale = 1 / UIParent:GetEffectiveScale()
        local posX, posY = GetCursorPosition()
        follower:SetPixelPoint('CENTER', UIParent, 'BOTTOMLEFT', posX * scale, posY * scale)
        self:ResolveAlpha(elapsed)
    end)
end

-- Update the visibility of the follower based on the current combat state.
function CursorCircle:UpdateTracking()
    if not self.follower then return end

    local mode = self.db.VisibilityMode
    local combatOnly = mode == 'combat' or mode == 'mouseDownCombat'
    local show = self.db.Enabled and (not combatOnly or self.inCombat)

    if not show then
        self.holdTime = 0
    end
    self.follower:SetShown(show) -- combatOnly modes are fully hidden so that the OnUpdate stops when not needed.
end

---Resolves the alpha of the follower based on the visibility mode and mouse button state.
---@param elapsed number
function CursorCircle:ResolveAlpha(elapsed)
    local mode = self.db.VisibilityMode

    -- Mouse button held / mouse button held in combat, fade in after briefly holding a mouse button.
    if mode == 'mouseDown' or mode == 'mouseDownCombat' then
        if IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton') then
            self.holdTime = self.holdTime + (elapsed or 0)
            self.follower:SetAlpha(self.holdTime >= HOLD_DELAY and 1 or 0)
        else
            self.holdTime = 0
            self.follower:SetAlpha(0)
        end
        return
    end

    -- Always / Combat, fully visible whenever the follower is running.
    self.follower:SetAlpha(1)
end

function CursorCircle:ApplySettings()
    if not self.follower then return end

    -- User settings
    local ringPath = ResolveTexturePath(self.db.Texture)
    local gcdPath = ResolveTexturePath(self.db.GCD.Texture)
    local r, g, b, a = NRSKNUI:GetAccentColor(self.db.ColorMode, self.db.Color)
    local rr, rg, rb, ra = NRSKNUI:GetAccentColor(self.db.GCD.RingColorMode, self.db.GCD.RingColor)
    local sr, sg, sb, sa = NRSKNUI:GetAccentColor(self.db.GCD.SwipeColorMode, self.db.GCD.SwipeColor)

    -- Main ring
    self.ring:SetPixelSize(self.db.Size, self.db.Size)
    self.ring.texture:SetTexture(ringPath)
    self.ring.texture:SetVertexColor(r, g, b, a)

    -- Separate GCD ring
    self.gcdRing:SetPixelSize(self.db.GCD.Size, self.db.GCD.Size)
    self.gcdRing.texture:SetTexture(gcdPath)
    self.gcdRing.texture:SetVertexColor(rr, rg, rb, ra)

    -- GCD swipe, integrated draws over the main ring texture, separate over the GCD ring.
    self.ring.cooldown:SetSwipeTexture(ringPath, sr, sg, sb, sa)
    self.ring.cooldown:SetReverse(self.db.GCD.Reverse)
    self.gcdRing.cooldown:SetSwipeTexture(gcdPath, sr, sg, sb, sa)
    self.gcdRing.cooldown:SetReverse(self.db.GCD.Reverse)

    self:UpdateTracking()
    self:ResolveAlpha(0)
    self:UpdateGCDVisibility()
    self:UpdateGCDCooldown()
end

-- The separate ring's texture visibility.
function CursorCircle:UpdateGCDVisibility()
    if not self.gcdRing then return end

    local show = self.db.Enabled and self.db.GCD.Mode == 'separate'
    if self.db.GCD.HideOutOfCombat and not self.inCombat then
        show = false
    end

    if show then
        self.gcdRing:Show()
    else
        self.gcdRing:Hide()
    end
end

function CursorCircle:UpdateGCDCooldown()
    if not self.ring then return end
    local integrated = self.ring.cooldown
    local separate = self.gcdRing.cooldown

    -- If GCD is disabled or hidden out of combat, hide both cooldowns.
    if self.db.GCD.Mode == 'disabled' or (self.db.GCD.HideOutOfCombat and not self.inCombat) then
        integrated:Hide()
        separate:Hide()
        return
    end

    -- Get the GCD cooldown info and update the appropriate ring based on the mode.
    local info = NRSKNUI:GetSpellCooldownInfo(GCD_ID)
    if info and info.duration and info.duration > 0 then
        if self.db.GCD.Mode == 'integrated' then
            integrated:SetCooldown(info.startTime, info.duration, info.modRate)
            integrated:Show()
            separate:Hide()
        else
            separate:SetCooldown(info.startTime, info.duration, info.modRate)
            separate:Show()
            integrated:Hide()
        end
    else
        integrated:Hide()
        separate:Hide()
    end
end

---PLAYER_REGEN event pair handler.
---@param event string
function CursorCircle:OnCombatChanged(event)
    self.inCombat = (event == 'PLAYER_REGEN_DISABLED')
    self:UpdateTracking()
    self:UpdateGCDVisibility()
    self:UpdateGCDCooldown()
end

function CursorCircle:UNIT_SPELLCAST_SUCCEEDED(_, unit)
    if unit ~= 'player' then return end
    if self.db.GCD.Mode == 'disabled' then return end

    self:UpdateGCDCooldown()
end

function CursorCircle:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrames()
    self.inCombat = NRSKNUI:InCombat() -- Get initial combat state.
    self:ApplySettings()

    self:RegisterEvent('PLAYER_REGEN_DISABLED', 'OnCombatChanged')
    self:RegisterEvent('PLAYER_REGEN_ENABLED', 'OnCombatChanged')
    self:RegisterEvent('SPELL_UPDATE_COOLDOWN', 'UpdateGCDCooldown')
    self:RegisterEvent('ACTIONBAR_UPDATE_COOLDOWN', 'UpdateGCDCooldown')
    self:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
end

function CursorCircle:OnDisable()
    if self.follower then
        self.follower:Hide()
    end
end
