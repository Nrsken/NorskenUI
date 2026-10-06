---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local CreateFrame = CreateFrame
local CreateObjectPool = CreateObjectPool
local unpack = unpack

---@class CDMIcon : Frame, PublicBackdropMixin
---@field id string?
---@field Icon Texture
---@field Cooldown Cooldown
---@field Charges FontString
---@field Countdown FontString
---@field style table the icon's style, see CDM:GetStyle
---@field state table trigger state the conditions read
---@field shown boolean loaded or previewed
---@field groupId string?
---@field spellID number?
---@field baseSpellID number?

---@param frame CDMIcon
local function OnCooldownDone(frame)
    if frame.id then CDM:UpdateIcon(frame.id) end
end

---@return CDMIcon
local function CreateIcon()
    local frame = CreateFrame('Frame', nil, UIParent) --[[@as CDMIcon]]
    frame:Hide()
    frame:NUICreateBackdrop(nil, 0)

    local icon = frame:CreateTexture(nil, 'ARTWORK')
    icon:NUISetPixelInside(frame, 1, 1)
    frame.Icon = icon

    local cooldown = CreateFrame('Cooldown', nil, frame, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawBling(false)
    cooldown:SetCountdownFormatter(NRSKNUI:GetAuraDurationFormatter())
    cooldown:SetScript('OnCooldownDone', function() OnCooldownDone(frame) end)
    frame.Cooldown = cooldown
    frame.Countdown = cooldown:GetCountdownFontString()

    local overlay = CreateFrame('Frame', nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    frame.Charges = overlay:CreateFontString(nil, 'OVERLAY')

    return frame
end

---@param frame CDMIcon
local function ResetIcon(_, frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    frame.Cooldown:Clear()
    NRSKNUI:StopGlow(frame, 'cdm')
    frame.id = nil
end

local pool = CreateObjectPool(CreateIcon, ResetIcon)

---@param id string
---@return CDMIcon
function CDM:AcquireIcon(id)
    local frame = pool:Acquire()
    frame.id = id
    return frame
end

---@param frame CDMIcon
function CDM:ReleaseIcon(frame)
    pool:Release(frame)
end

---@param frame CDMIcon
---@param style table
function CDM:StyleIcon(frame, style)
    frame:NUISetPixelSize(style.Size, style.Size)
    frame.Icon:NUISetZoom(style.Zoom)
    frame:SetBorderColor(unpack(style.BorderColor))

    local cooldown = frame.Cooldown
    cooldown:SetDrawSwipe(style.DrawSwipe)
    cooldown:SetDrawEdge(style.DrawEdge)
    cooldown:SetReverse(style.Reverse)
    cooldown:SetSwipeColor(unpack(style.SwipeColor))
    cooldown:SetHideCountdownNumbers(not style.ShowCountdown)

    local countdown, countdownPos = style.CountdownFont, style.CountdownFont.Position
    frame.Countdown:SetFontStyle(style, countdown.FontSize, nil, nil, true)
    frame.Countdown:SetFontJustify(countdown, frame, countdownPos.XOffset, countdownPos.YOffset, true)

    local charges, chargesPos = style.ChargeFont, style.ChargeFont.Position
    frame.Charges:SetFontStyle(style, charges.FontSize, nil, nil, true)
    frame.Charges:SetFontJustify(charges, frame, chargesPos.XOffset, chargesPos.YOffset, true)
end
