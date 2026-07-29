--[[
# Animation

* Animation helpers shared by the librarys widgets and the addon.

Access the animation helpers through the `Animations` table of the `LibKaji-1.0` library:
* ns.LibKaji = _G.LibStub('LibKaji-1.0')   -- Core file
* local Animations = ns.LibKaji.Animations -- Usage files calls like this

# Animations APIs

A! Creates a color animator for a frame, returning an animate(toR, toG, toB, toA) function and a setCurrent(r, g, b, a) function.
API: Animations:CreateColorAnimator(frame, setter, initialColor, duration)
* `frame`         -- Frame to animate.
* `setter`        -- Function that applies the current color.
* `initialColor`  -- Starting color value.
* `duration`      -- Tween length in seconds, falls back to 0.15s if not provided.

A! Creates a hover color animator for a frame, returning an animate(isHover) function and a setCurrent(r, g, b, a) function.
API: Animations:CreateHoverColorAnimator(frame, setter, baseColor, hoverColor, duration)
* `frame`         -- Frame to animate.
* `setter`        -- Function that applies the current color.
* `baseColor`     -- Resting color value.
* `hoverColor`    -- Color used while hovered.
* `duration`      -- Tween length in seconds, falls back to 0.15s if not provided.

A! Shakes a frame horizontally once, used to reject invalid input.
API: Animations:Wobble(frame)
* `frame`         -- Frame to shake.

## Examples

local anim = Animations:CreateColorAnimator(frame, setter, {1, 0, 0, 1}, 0.2)
anim(true)
anim(false)

local animHover = Animations:CreateHoverColorAnimator(frame, setter, {1, 0, 0, 1}, {0, 1, 0, 1}, 0.2)
animHover(true)
animHover(false)

local animWobble = Animations:Wobble(frame)

--]]

---@class LibKaji-1.0
local lib = _G.LibStub and _G.LibStub('LibKaji-1.0', true)
if not lib then return end
---@class LibKaji-1.0.Animations
local Animations = {}
lib.Animations = Animations

local ipairs = ipairs

local DEFAULT_DURATION = 0.15
local WOBBLE_OFFSETS = { -6, 5, -4, 3, -2, 1 }
local WOBBLE_DURATION = 0.4

local function EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

---Returns a function that tweens a color from an initial value to a target value over a duration, calling the provided setter with the current color each frame.
---@param frame Frame
---@param setter fun(r: number, g: number, b: number, a: number)
---@param initialColor table {r,g,b} or {r,g,b,a}
---@param duration? number
---@return fun(toR: number, toG: number, toB: number, toA?: number) animate
---@return fun(r: number, g: number, b: number, a?: number) setCurrent
function Animations:CreateColorAnimator(frame, setter, initialColor, duration)
    duration = duration or DEFAULT_DURATION

    local curR = initialColor.r or initialColor[1]
    local curG = initialColor.g or initialColor[2]
    local curB = initialColor.b or initialColor[3]
    local curA = initialColor.a or initialColor[4] or 1

    local animGroup = frame:CreateAnimationGroup()
    animGroup:CreateAnimation('Animation'):SetDuration(duration)

    local fromR, fromG, fromB, fromA = curR, curG, curB, curA
    local toR, toG, toB, toA = curR, curG, curB, curA

    animGroup:SetScript('OnUpdate', function()
        local progress = EaseOutQuad(animGroup:GetProgress() or 0)
        curR = fromR + (toR - fromR) * progress
        curG = fromG + (toG - fromG) * progress
        curB = fromB + (toB - fromB) * progress
        curA = fromA + (toA - fromA) * progress
        setter(curR, curG, curB, curA)
    end)

    animGroup:SetScript('OnFinished', function()
        curR, curG, curB, curA = toR, toG, toB, toA
        setter(curR, curG, curB, curA)
    end)

    local function animate(newR, newG, newB, newA)
        animGroup:Stop()
        fromR, fromG, fromB, fromA = curR, curG, curB, curA
        toR, toG, toB, toA = newR, newG, newB, newA or curA
        animGroup:Play()
    end

    local function setCurrent(r, g, b, a)
        animGroup:Stop()
        curR, curG, curB, curA = r, g, b, a or curA
    end

    return animate, setCurrent
end

---Convenience wrapper over CreateColorAnimator, returns a setter(isHover) that tweens between a base and hover color.
---@param frame Frame
---@param setter fun(r: number, g: number, b: number, a: number)
---@param baseColor table
---@param hoverColor table
---@param duration? number
---@return fun(isHover: boolean) animate
---@return fun(r: number, g: number, b: number, a?: number) setCurrent
function Animations:CreateHoverColorAnimator(frame, setter, baseColor, hoverColor, duration)
    local animate, setCurrent = self:CreateColorAnimator(frame, setter, baseColor, duration)

    local function applyHover(isHover)
        local color = isHover and hoverColor or baseColor
        animate(color.r or color[1], color.g or color[2], color.b or color[3])
    end

    return applyHover, setCurrent
end

---Shakes a frame horizontally once, used to reject invalid input.
---@param frame Frame
function Animations:Wobble(frame)
    if frame._kaji_wobble and frame._kaji_wobble:IsPlaying() then return end

    if not frame._kaji_wobble then
        local animGroup = frame:CreateAnimationGroup()
        local stepDuration = WOBBLE_DURATION / #WOBBLE_OFFSETS

        for i, offset in ipairs(WOBBLE_OFFSETS) do
            local anim = animGroup:CreateAnimation('Translation')
            anim:SetOffset(offset, 0)
            anim:SetDuration(stepDuration)
            anim:SetOrder(i)
            anim:SetSmoothing('OUT')
        end

        local reset = animGroup:CreateAnimation('Translation')
        reset:SetOffset(0, 0)
        reset:SetDuration(0.01)
        reset:SetOrder(#WOBBLE_OFFSETS + 1)

        frame._kaji_wobble = animGroup
    end

    frame._kaji_wobble:Play()
end
