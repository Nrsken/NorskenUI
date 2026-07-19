---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatRes
local CombatRes = NRSKNUI:GetModule("CombatRes")
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local GetTime = GetTime
local CreateColor = CreateColor
local tostring = tostring
local WrapTextInColorCode = WrapTextInColorCode

local UIParent = UIParent

local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges

local BATTLE_RES_SPELL = 20484
local UPDATE_INTERVAL = 0.25
local PREVIEW_CHARGES, PREVIEW_REMAINING = 2, 90

function CombatRes:UpdateDB()
    self.db = NRSKNUI.db.profile.BattleRes
end

function CombatRes:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Cache/refresh a ColorMixin from a {r,g,b,a} db table so segments can use WrapTextInColorCode.
---@param existing ColorMixin|nil
---@param t colorRGBA|nil
---@return ColorMixin
local function RefreshColor(existing, t)
    t = t or { 1, 1, 1, 1 }
    if existing then
        existing:SetRGBA(t[1], t[2], t[3], t[4] or 1)
        return existing
    end
    return CreateColor(t[1], t[2], t[3], t[4] or 1)
end

-- Strip a single leading "%" so a db token ("%s") becomes the placeholder the parser matches ("s").
---@param token string
---@return string|nil
local function TokenKey(token)
    if not token then return nil end
    return (token:gsub("^%%", ""))
end

function CombatRes:CreateFrame()
    if self.coreFrame then return end

    local coreFrame = CreateFrame("Frame", "NRSKNUI_CombatResFrame", UIParent)
    coreFrame:SetPixelSize(100, 25)
    coreFrame:SetFrameLevel(100)
    coreFrame:EnableMouse(false)
    coreFrame:SetMouseClickEnabled(false)
    coreFrame:CreateBackdrop()

    coreFrame.text = coreFrame:CreateFontString(nil, 'OVERLAY')

    -- Finalize the frame and register it with Anchors.
    ---@type Frame
    self.coreFrame = coreFrame
    EM:Register(self, 'CombatRes', self.coreFrame, 'BattleRes')
    self.coreFrame:Hide()
end

---Map the tokens to their colored values, then let the shared parser assemble the string.
---@param chargeCount number
---@param timeText string
---@param hasCharges boolean
---@return string
function CombatRes:ResolveText(chargeCount, timeText, hasCharges)
    local db = self.db
    local chargeColor = hasCharges and self.colChargeAvail or self.colChargeUnavail
    local timerText = self.colTimer
    local sepText = self.colSep

    local replacements = {
        [self.tokCharge] = chargeColor:WrapTextInColorCode(tostring(chargeCount)),
        [self.tokTimer]  = timerText:WrapTextInColorCode(timeText),
        [self.tokSep]    = sepText:WrapTextInColorCode(db.Separator or ""),
    }

    return NRSKNUI:FormatTokens(db.TextFormat, replacements, self.WrapFormat)
end

-- Seconds until the next charge comes off cooldown (0 when fully charged).
---@return number
function CombatRes:GetRemaining()
    local info = self.chargeInfo
    if not info or not info.cooldownStartTime then return 0 end
    local remaining = (info.cooldownStartTime + info.cooldownDuration) - GetTime()
    if remaining < 0 then remaining = 0 end
    return remaining
end

-- Resolve current state, push the string, and size the frame to fit.
function CombatRes:Render()
    local frame = self.coreFrame
    if not frame then return end

    local info = self.chargeInfo
    local chargeCount, hasCharges, remaining

    if info and info.currentCharges and (info.maxCharges or 0) > 0 then
        chargeCount = info.currentCharges
        hasCharges = chargeCount > 0
        remaining = self:GetRemaining()
    elseif self.isPreview then
        chargeCount, hasCharges, remaining = PREVIEW_CHARGES, true, PREVIEW_REMAINING
    else
        frame:Hide()
        return
    end

    -- This will happen like never but w/e, we add it.
    local zeroValues = {
        ['0s']      = true,
        ['0']       = true,
        ['0:00']    = true,
        ['00:00']   = true,
        ['00m 00s'] = true,
    }

    local timeText = NRSKNUI:FormatTime(remaining, self.db.TimeFormat)
    if zeroValues[timeText] then
        timeText = 'Max'
    end

    local text = self:ResolveText(chargeCount, timeText, hasCharges)

    -- Re-fit the backdrop only when the string's shape changes, never per tick.
    if frame:FitBackdropToText(frame.text, text, self.db.BackdropWidth, self.db.BackdropHeight) then
        self.lastText = nil -- the helper clobbers the fontstring, so force the re-apply below
    end

    if text ~= self.lastText then
        self.lastText = text
        frame.text:SetText(text)
    end

    frame:Show()
end

function CombatRes:UpdateCharges()
    self.chargeInfo = GetSpellCharges(BATTLE_RES_SPELL)
    self:Render()
end

-- Schedule a delayed charge update with AceTimer, charge info is slightly behind the events.
function CombatRes:ScheduleChargeUpdate()
    if self.chargeTimer then self:CancelTimer(self.chargeTimer) end
    self.chargeTimer = self:ScheduleTimer("UpdateCharges", UPDATE_INTERVAL)
end

function CombatRes:ApplySettings()
    if not self.coreFrame then return end
    local db = self.db

    -- Token placeholders and segment colors used by ResolveText.
    self.tokCharge = TokenKey(db.TextCharge)
    self.tokTimer = TokenKey(db.TextTimer)
    self.tokSep = TokenKey(db.TextSeparator)

    -- Update colors
    self.colFormat = RefreshColor(self.colFormat, db.ColorFormat)
    self.WrapFormat = self.WrapFormat or function(text) return self.colFormat:WrapTextInColorCode(text) end
    self.colSep = RefreshColor(self.colSep, db.ColorSeparator)
    self.colTimer = RefreshColor(self.colTimer, db.ColorTimer)
    self.colChargeAvail = RefreshColor(self.colChargeAvail, db.ColorChargeAvailable)
    self.colChargeUnavail = RefreshColor(self.colChargeUnavail, db.ColorChargeUnavailable)

    -- Update position
    self.coreFrame:ApplyPosition(db)

    -- Update backdrop settings
    if db.BackdropEnabled then
        self.coreFrame:UpdateBackdropFromDB(db)
        self.coreFrame:ToggleBackdrop(true)
    else
        self.coreFrame:ToggleBackdrop(false)
    end

    -- Update font settings
    self.coreFrame.text:SetFontStyle(db)
    self.coreFrame.text:SetFontJustify(db, nil, self.db.Position.AnchorFrom == 'CENTER' and 0 or 4, 0, nil, nil, true)

    -- Mark for a resize on the next update, since the backdrop may have changed.
    self.coreFrame.NUIBackdropShape = nil
    self.coreFrame:FitBackdropToText(self.coreFrame.text,
        self:ResolveText(PREVIEW_CHARGES, NRSKNUI:FormatTime(PREVIEW_REMAINING, db.TimeFormat), true),
        db.BackdropWidth, db.BackdropHeight)
    self.lastText = nil
    self:Render()
end

function CombatRes:OnEnable()
    if not self.db.Enabled then return end

    self.lastText = nil
    self.isPreview = false

    self:CreateFrame()
    self:ApplySettings()

    self.coreFrame:ApplyOnUpdate(UPDATE_INTERVAL, function() self:Render() end)
    self:RegisterEvent("SPELL_UPDATE_CHARGES", "ScheduleChargeUpdate")
    self:RegisterEvent("CHALLENGE_MODE_START", "ScheduleChargeUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScheduleChargeUpdate")

    self:UpdateCharges()
end

function CombatRes:OnDisable()
    if self.coreFrame then
        self.coreFrame:ApplyOnUpdate()
        self.coreFrame:Hide()
    end
    self.isPreview = false
end

function CombatRes:ShowPreview()
    if not self.coreFrame then
        self:CreateFrame()
        self:ApplySettings()
    end
    self.isPreview = true
    self:Render()
    self.coreFrame:Show()
end

function CombatRes:HidePreview()
    self.isPreview = false
    self:UpdateCharges()
end
