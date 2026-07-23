--[[
# Animations

* Small animation helpers shared by the widgets: smooth color tweens for hover/state transitions and a wobble for invalid-input feedback.
* Reached as `lib.Animations`.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end

local ipairs = ipairs

local Animations = {}
lib.Animations = Animations

local DEFAULT_DURATION = 0.15

local function EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

---Returns animate(r,g,b,a) that tweens a frame's color from its current value (alpha
---optional, kept if nil), and setCurrent(r,g,b,a) to adopt an externally-applied color
---so the next tween starts from it (e.g. after a direct hover recolor).
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
    animGroup:CreateAnimation("Animation"):SetDuration(duration)

    local fromR, fromG, fromB, fromA = curR, curG, curB, curA
    local toR, toG, toB, toA = curR, curG, curB, curA

    animGroup:SetScript("OnUpdate", function()
        local progress = EaseOutQuad(animGroup:GetProgress() or 0)
        curR = fromR + (toR - fromR) * progress
        curG = fromG + (toG - fromG) * progress
        curB = fromB + (toB - fromB) * progress
        curA = fromA + (toA - fromA) * progress
        setter(curR, curG, curB, curA)
    end)

    animGroup:SetScript("OnFinished", function()
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

---Convenience wrapper over CreateColorAnimator: returns a setter(isHover) that tweens between a base and hover color.
---@param frame Frame
---@param setter fun(r: number, g: number, b: number, a: number)
---@param baseColor table
---@param hoverColor table
---@param duration? number
---@return fun(isHover: boolean)
function Animations:CreateHoverColorAnimator(frame, setter, baseColor, hoverColor, duration)
    local animate = self:CreateColorAnimator(frame, setter, baseColor, duration)

    local baseR = baseColor.r or baseColor[1]
    local baseG = baseColor.g or baseColor[2]
    local baseB = baseColor.b or baseColor[3]
    local hoverR = hoverColor.r or hoverColor[1]
    local hoverG = hoverColor.g or hoverColor[2]
    local hoverB = hoverColor.b or hoverColor[3]

    return function(isHover)
        if isHover then
            animate(hoverR, hoverG, hoverB)
        else
            animate(baseR, baseG, baseB)
        end
    end
end

local WOBBLE_OFFSETS = { -6, 5, -4, 3, -2, 1 }
local WOBBLE_DURATION = 0.4

---Shakes a frame horizontally once — used to reject invalid input.
---@param frame table
function Animations:Wobble(frame)
    if frame._kaji_wobble and frame._kaji_wobble:IsPlaying() then return end

    if not frame._kaji_wobble then
        local animGroup = frame:CreateAnimationGroup()
        local stepDuration = WOBBLE_DURATION / #WOBBLE_OFFSETS

        for i, offset in ipairs(WOBBLE_OFFSETS) do
            local anim = animGroup:CreateAnimation("Translation")
            anim:SetOffset(offset, 0)
            anim:SetDuration(stepDuration)
            anim:SetOrder(i)
            anim:SetSmoothing("OUT")
        end

        local reset = animGroup:CreateAnimation("Translation")
        reset:SetOffset(0, 0)
        reset:SetDuration(0.01)
        reset:SetOrder(#WOBBLE_OFFSETS + 1)

        frame._kaji_wobble = animGroup
    end

    frame._kaji_wobble:Play()
end
