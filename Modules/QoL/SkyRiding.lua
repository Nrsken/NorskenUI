---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkyRidingModule
local SkyRiding = NRSKNUI:GetModule('SkyRiding')
function SkyRiding:UpdateDB() self.db = NRSKNUI.db.profile.Miscellaneous.SkyRiding end

local Anchors = NRSKNUI.Anchors
local kajiGUI = NRSKNUI.GUI
local Pixel = NRSKNUI.Libs.KAJI.Pixel

local UnregisterStateDriver = UnregisterStateDriver
local RegisterStateDriver = RegisterStateDriver
local RunNextFrame = RunNextFrame
local CreateFrame = CreateFrame
local math_floor = math.floor
local ipairs = ipairs
local unpack = unpack

local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local GetGlidingInfo = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo
local GetSpellChargeDuration = C_Spell and C_Spell.GetSpellChargeDuration
local GetSpellCooldownDuration = C_Spell and C_Spell.GetSpellCooldownDuration
local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

local Immediate = Enum and Enum.StatusBarInterpolation.Immediate
local ElapsedTime = Enum and Enum.StatusBarTimerDirection.ElapsedTime

local UIParent = UIParent
local BASE_MOVEMENT_SPEED = BASE_MOVEMENT_SPEED

local VIGOR_SPELL = 372610
local SECOND_WIND_SPELL = 425782
local WHIRLING_SURGE_SPELL = 361584
local THRILL_SPELL = 377234

local ROWS = {
    { key = 'SecondWind',    order = 1, spell = SECOND_WIND_SPELL },
    { key = 'WhirlingSurge', order = 2, spell = WHIRLING_SURGE_SPELL, cooldown = true },
    { key = 'Vigor',         order = 3, spell = VIGOR_SPELL },
}

local PREVIEW = {
    SecondWind    = { filled = 2, total = 3 },
    WhirlingSurge = { filled = 1, total = 1 },
    Vigor         = { filled = 4, total = 6 },
}

---Spent pills empty out, the one refilling runs its own timer.
---@param row Frame
---@param filled number pills already full
---@param duration LuaDurationObject? window the next pill fills over, nil when nothing is refilling
local function SetRowFilled(row, filled, duration)
    for i = 1, row.count do
        local pill = row.pills[i]
        if filled + 1 == i and duration then
            pill:SetTimerDuration(duration, Immediate, ElapsedTime)
        else
            pill:SetMinMaxValues(0, 1)
            pill:SetValue(filled >= i and 1 or 0)
        end
    end
end

---Grow the row's pill pool to `count`, keeping any extras around but out of the layout.
---@param row Frame
---@param count number
local function SetRowCount(row, count)
    for i = #row.pills + 1, count do
        local pill = CreateFrame('StatusBar', nil, row)
        pill:NUICreateBackdrop(true, 0)
        pill:NUIAddBorders()
        pill:NUISetPixelSnap()
        row.pills[i] = pill
    end

    for i = 1, #row.pills do
        row.pills[i]:SetShown(i <= count)
    end
    row.count = count
end

function SkyRiding:CreateFrames()
    if self.group then return end
    self.rows = {}

    local host = CreateFrame('Frame', nil, UIParent, 'SecureHandlerStateTemplate')
    host:SetRolesets('actionBars')
    host:Hide()
    self.host = host

    local group = NRSKNUI:CreateDynamicGroup('NRSKNUI_SkyRiding', host)
    self.group = group

    for _, def in ipairs(ROWS) do
        local row = CreateFrame('Frame', nil, group)
        row.pills = {}
        row.count = 0

        self.rows[def.key] = row
        group:AttachChild(row, def.key, def.order)
    end

    self.speedFrame = CreateFrame('Frame', nil, group)
    self.speedText = self.speedFrame:CreateFontString(nil, 'OVERLAY')
    self.speedText:SetWordWrap(false)

    self.deferredUpdate = function()
        self.updatePending = false
        self:Update()
    end

    host:HookScript('OnShow', function() self:OnBarShow() end)
    host:HookScript('OnHide', function() self:OnBarHide() end)

    Anchors:Register(self, 'SkyridingUI', group, 'skyRiding')
end

---What a row draws, nil when it has nothing to show.
---@param def table
---@return number? filled, number? total, LuaDurationObject? duration
function SkyRiding:RowState(def)
    if not self.db[def.key].Enabled then return nil end

    if self.isPreview then
        local preview = PREVIEW[def.key]
        return preview.filled, preview.total
    end

    -- A chargeless ability is one pill driven straight off its cooldown.
    if def.cooldown then
        local duration = GetSpellCooldownDuration(def.spell)
        local running = duration ~= nil and not duration:IsZero()
        return running and 0 or 1, 1, running and duration or nil
    end

    -- Skyriding charges only resolve while mounted, so no table means nothing to draw.
    local charges = GetSpellCharges(def.spell)
    if not charges then return nil end

    return charges.currentCharges, charges.maxCharges, GetSpellChargeDuration(def.spell)
end

function SkyRiding:Update()
    if not self.group then return end

    for _, def in ipairs(ROWS) do
        local filled, total, duration = self:RowState(def)
        if filled then
            local row = self.rows[def.key]

            -- A charge cap moves with the player's skyriding talents, so the pool follows it.
            if row.count ~= total then
                SetRowCount(row, total)
                self:ApplyRowLook(row, def.key)
            end

            SetRowFilled(row, filled, duration)
            self.group:ActivateChild(def.key)
        else
            self.group:DeactivateChild(def.key)
        end
    end

    self.group:ForceLayout()
    self:UpdateVigorColor()
end

function SkyRiding:ScheduleUpdate()
    if self.updatePending then return end
    self.updatePending = true
    RunNextFrame(self.deferredUpdate)
end

---Thrill of the Skies recolors the whole row, so it rides UNIT_AURA rather than the charge events.
function SkyRiding:UpdateVigorColor()
    local vigorDB = self.db.Vigor
    local r, g, b, a
    if vigorDB.ThrillEnabled and GetPlayerAuraBySpellID(THRILL_SPELL) then
        r, g, b, a = NRSKNUI:GetAccentColor(vigorDB.ThrillColorMode, vigorDB.ThrillColor)
    else
        r, g, b, a = NRSKNUI:GetAccentColor(vigorDB.ColorMode, vigorDB.Color)
    end

    local row = self.rows.Vigor
    for i = 1, row.count do
        row.pills[i]:SetStatusBarColor(r, g, b, a)
    end
end

function SkyRiding:UpdateSpeed()
    local isGliding, _, forwardSpeed = GetGlidingInfo()
    if isGliding then
        self.speedText:SetFormattedText('%d%%', forwardSpeed / BASE_MOVEMENT_SPEED * 100 + 0.5)
    else
        self.speedText:SetText('')
    end
end

---Color the row's pills and size them so they fill its width exactly.
---@param row Frame
---@param key string
function SkyRiding:ApplyRowLook(row, key)
    if row.count < 1 then return end

    local texture = NRSKNUI:GetStatusbar(self.db)
    local r, g, b, a = NRSKNUI:GetAccentColor(self.db[key].ColorMode, self.db[key].Color)
    local bgR, bgG, bgB, bgA = unpack(self.db.BackgroundColor)
    local bR, bG, bB, bA = unpack(self.db.BorderColor)

    local mult = Pixel.GetMult()
    local gap = math_floor(self.db.PillSpacing / mult + 0.5)
    local available = math_floor(self.db.Width / mult + 0.5) - gap * (row.count - 1)
    local base = math_floor(available / row.count)
    local spare = available - base * row.count

    for i = 1, row.count do
        local pill = row.pills[i]
        pill:SetStatusBarTexture(texture)
        pill:SetStatusBarColor(r, g, b, a)
        pill:SetBackgroundColor(bgR, bgG, bgB, bgA)
        pill:SetBorderColor(bR, bG, bB, bA)
        pill:SetBorderShown(self.db.BorderEnabled)

        pill:SetSize((base + (i <= spare and 1 or 0)) * mult, Pixel.ToPixelGrid(self.db.BarHeight))
        pill:ClearAllPoints()
        if i == 1 then
            pill:SetPoint('LEFT', row, 'LEFT', 0, 0)
        else
            pill:SetPoint('LEFT', row.pills[i - 1], 'RIGHT', gap * mult, 0)
        end
    end
end

function SkyRiding:ApplySettings()
    if not self.group then return end

    self.group:SetConfig({ Grow = self.db.Grow, Align = 'CENTER', Spacing = self.db.Spacing, MinWidth = self.db.Width })
    self.group:UpdateGroupPosition(self.db, self.db.Grow)

    for _, def in ipairs(ROWS) do
        local row = self.rows[def.key]
        row:NUISetPixelSize(self.db.Width, self.db.BarHeight)
        self:ApplyRowLook(row, def.key)
        self.group:NotifyChildResized(row)
    end

    local speedDB = self.db.SpeedText
    self.speedFrame:SetShown(speedDB.Enabled)
    self.speedFrame:NUISetPixelSize(self.db.Width, speedDB.FontSize + 4)
    self.speedFrame:ClearAllPoints()
    self.speedFrame:NUISetPixelPoint('BOTTOM', self.group, 'TOP', speedDB.XOffset, speedDB.YOffset)

    self.speedText:SetFontStyle(speedDB)
    self.speedText:SetFontJustify('CENTER', self.speedFrame, 0, 0)
    self.speedText:SetTextColor(unpack(speedDB.TextColor))

    if self.isPreview or self.host:IsShown() then self:Update() end
end

function SkyRiding:OnBarShow()
    if self.isPreview then return end

    self:RegisterEvent('SPELL_UPDATE_CHARGES', 'ScheduleUpdate')
    self:RegisterEvent('SPELL_UPDATE_COOLDOWN', 'ScheduleUpdate')
    self:RegisterEvent('UNIT_AURA')

    if self.db.SpeedText.Enabled then
        self.speedFrame:NUIApplyOnUpdate(0.1, function() self:UpdateSpeed() end)
    end

    self:Update()
end

function SkyRiding:OnBarHide()
    self:UnregisterEvent('SPELL_UPDATE_CHARGES')
    self:UnregisterEvent('SPELL_UPDATE_COOLDOWN')
    self:UnregisterEvent('UNIT_AURA')

    self.speedFrame:NUIApplyOnUpdate()
    self.speedText:SetText('')
end

function SkyRiding:UNIT_AURA(_, unit)
    if unit ~= 'player' then return end
    if self.isPreview then return end

    self:UpdateVigorColor()
end

function SkyRiding:OnEnable()
    self.isPreview = false

    self:CreateFrames()
    self:ApplySettings()
    self.themeSub = kajiGUI:OnThemeChanged(function() self:ApplySettings() end)

    RegisterStateDriver(self.host, 'visibility', '[bonusbar:5] show; hide')
    if self.host:IsShown() then self:OnBarShow() end
end

function SkyRiding:OnDisable()
    self.isPreview = false

    if self.themeSub then
        self.themeSub()
        self.themeSub = nil
    end

    if not self.group then return end
    UnregisterStateDriver(self.host, 'visibility')
    self:OnBarHide()
    self.host:Hide()
end

function SkyRiding:ShowPreview()
    if not self.group then self:CreateFrames() end
    self.isPreview = true

    self:OnBarHide()
    UnregisterStateDriver(self.host, 'visibility')

    self:ApplySettings()
    self.speedText:SetText('420%')
    self.host:Show()
end

function SkyRiding:HidePreview()
    self.isPreview = false
    if not self.group then return end

    NRSKNUI:RunWhenSafe(function()
        if not self.db.Enabled then
            self.host:Hide()
            return
        end
        RegisterStateDriver(self.host, 'visibility', '[bonusbar:5] show; hide')
        self:ApplySettings()
        if self.host:IsShown() then self:OnBarShow() end
    end)
end
