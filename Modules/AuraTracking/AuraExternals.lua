---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class ExternalBuffTracking: AceModule, AceEvent-3.0
local EXTERNALS = NRSKNUI:NewModule("ExternalBuffTracking", "AceEvent-3.0")

local LCG = NRSKNUI.Libs.LCG

EXTERNALS.buttons = {}

local CreateFrame = CreateFrame
local unpack = unpack
local GetTime = GetTime
local pairs, ipairs = pairs, ipairs
local wipe = wipe
local tinsert = table.insert
local tsort = table.sort
local math_min = math.min
local math_floor = math.floor
local GameTooltip = GameTooltip
local C_UnitAuras = C_UnitAuras

local UNIT = "player"
local pendingAuraUpdate = false
local auraDataCache = {}
local seenAuras = {}
local soundPlayedFor = {}

local function GetAnchorPoint(db)
    local h, v = db.GrowHorizontal or "LEFT", db.GrowVertical or "DOWN"
    if h == "LEFT" and v == "DOWN" then return "TOPRIGHT"
    elseif h == "LEFT" and v == "UP" then return "BOTTOMRIGHT"
    elseif h == "RIGHT" and v == "DOWN" then return "TOPLEFT"
    else return "BOTTOMLEFT" end
end

local FILTERS = {
    { filter = "HELPFUL|EXTERNAL_DEFENSIVE", filterPlayer = "HELPFUL|EXTERNAL_DEFENSIVE|PLAYER", isExternal = true },
    { filter = "HELPFUL|BIG_DEFENSIVE",      filterPlayer = "HELPFUL|BIG_DEFENSIVE|PLAYER",      isExternal = false },
}

local PREVIEW_ICONS = { 135936, 572025, 135966, 627485, 4622478, 237542, }
local PREVIEW_ICONS_DEF = { 135936, 136097, 135966, 615341, 627485, 136120, }

local function ApplyCooldownTextStyle(cooldown, db)
    local cooldownText = cooldown:GetRegions()
    if not cooldownText or not cooldownText.SetFont then return end

    NRSKNUI:ApplyFont(cooldownText, NRSKNUI:GetEffectiveFont(db), db.TimerFontSize, db.FontOutline)
    if cooldownText.SetShadowOffset then cooldownText:SetShadowOffset(0, 0) end

    local pos = db.TimerPosition
    cooldownText:ClearAllPoints()
    cooldownText:SetPoint(pos.AnchorFrom, cooldown:GetParent(), pos.AnchorTo, pos.XOffset, pos.YOffset)
end

function EXTERNALS:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.ExternalBuffTracking
end

function EXTERNALS:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function auraOnEnter(button)
    if not button.auraInstanceID then return end
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetUnitAuraByAuraInstanceID(UNIT, button.auraInstanceID)
    GameTooltip:Show()
end

local function auraOnLeave()
    GameTooltip:Hide()
end

local function CreateAuraButton(parent)
    local db = EXTERNALS.db

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(db.IconSize, db.IconSize)
    button:EnableMouse(true)

    EXTERNALS.buttons[button] = true

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(unpack(db.BackgroundColor))

    NRSKNUI:AddBorders(button, db.BorderColor)

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    NRSKNUI:ApplyZoom(button.Icon, NRSKNUI.GlobalZoom)

    button.Count = NRSKNUI:CreateText(button, "OVERLAY")
    button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.Count:SetJustifyH("RIGHT")
    NRSKNUI:ApplyFont(button.Count, NRSKNUI:GetEffectiveFont(db), db.FontSize, db.FontOutline)
    button.Count:SetShadowOffset(0, 0)

    button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.Cooldown:SetAllPoints()
    button.Cooldown:SetDrawEdge(false)
    button.Cooldown:SetDrawSwipe(db.Swipe)
    button.Cooldown:SetReverse(db.Reverse)
    button.Cooldown:SetDrawBling(false)
    button.Cooldown:SetHideCountdownNumbers(false)
    ApplyCooldownTextStyle(button.Cooldown, db)

    button:SetScript("OnEnter", auraOnEnter)
    button:SetScript("OnLeave", auraOnLeave)

    button:Hide()
    return button
end

local function StopGlow(button)
    if not LCG or not button.glowActive then return end
    LCG.PixelGlow_Stop(button)
    LCG.AutoCastGlow_Stop(button)
    LCG.ButtonGlow_Stop(button)
    LCG.ProcGlow_Stop(button)
    button.glowActive = false
end

local function StartGlow(button, forceRestart)
    if not LCG then return end
    local db = EXTERNALS.db
    if not db.GlowEnabled then return end
    if button.glowActive and not forceRestart then return end

    StopGlow(button)

    local glowType = db.GlowType
    if glowType == "pixel" then
        LCG.PixelGlow_Start(button, db.GlowColor, db.GlowLines, db.GlowFrequency, db.GlowLength, db.GlowThickness, 0, 0,
            db.GlowBorder, nil)
    elseif glowType == "autocast" then
        LCG.AutoCastGlow_Start(button, db.GlowColor, db.GlowLines, db.GlowFrequency, db.GlowScale, 1, 1, nil)
    elseif glowType == "button" then
        LCG.ButtonGlow_Start(button, db.GlowColor, db.GlowFrequency)
    elseif glowType == "proc" then
        LCG.ProcGlow_Start(button, { color = db.GlowColor, startAnim = db.GlowStartAnim, duration = db.GlowDuration })
    end

    button.glowActive = true
end

local function UpdateAuraButton(button, data)
    if not data then
        StopGlow(button)
        button:Hide()
        return
    end
    button.auraInstanceID = data.auraInstanceID
    button.isExternal = data.isExternal
    button.Icon:SetTexture(data.icon)
    local count = C_UnitAuras.GetAuraApplicationDisplayCount(UNIT, data.auraInstanceID, 2, 999)
    button.Count:SetText(count)
    local duration = C_UnitAuras.GetAuraDuration(UNIT, data.auraInstanceID)
    if duration then
        button.Cooldown:SetCooldownFromDurationObject(duration)
        button.Cooldown:Show()
    else
        button.Cooldown:Hide()
    end

    button:Show()

    if data.isExternal then
        StartGlow(button)
        if not soundPlayedFor[data.auraInstanceID] then
            local db = EXTERNALS.db
            if db.SoundEnabled and db.Sound and db.Sound ~= "None" then
                local LSM = NRSKNUI.Libs.LSM
                if LSM then
                    NRSKNUI:PlaySound(LSM:Fetch("sound", db.Sound))
                end
            end
            soundPlayedFor[data.auraInstanceID] = true
        end
    else
        StopGlow(button)
    end
end

local function PositionButtons(self)
    local db = self.db
    local spacing = db.IconSize + db.IconSpacing
    local iconsPerRow = db.IconsPerRow
    local growH = db.GrowHorizontal == "LEFT" and -1 or 1
    local growV = db.GrowVertical == "DOWN" and -1 or 1
    local anchorPoint = GetAnchorPoint(db)
    local visibleCount = 0

    for _, button in ipairs(self.buttonPool) do
        if button:IsShown() then
            visibleCount = visibleCount + 1
            local col = (visibleCount - 1) % iconsPerRow
            local row = math_floor((visibleCount - 1) / iconsPerRow)
            button:ClearAllPoints()
            button:SetPoint(anchorPoint, self.frame, anchorPoint, col * spacing * growH, row * spacing * growV)
        end
    end
end

local function SortAuras(a, b)
    return a.auraInstanceID < b.auraInstanceID
end

function EXTERNALS:UpdateAuras()
    if not self.frame then return end
    local db = self.db
    wipe(auraDataCache)
    wipe(seenAuras)
    local dataIndex = 0

    for _, filterInfo in ipairs(FILTERS) do
        if filterInfo.isExternal or db.ShowBigDefensives then
            local slots = { C_UnitAuras.GetAuraSlots(UNIT, filterInfo.filter) }

            for i = 2, #slots do
                local data = C_UnitAuras.GetAuraDataBySlot(UNIT, slots[i])
                if data and not seenAuras[data.auraInstanceID] then
                    seenAuras[data.auraInstanceID] = true
                    data.isExternal = filterInfo.isExternal
                    data.isPlayerAura = not C_UnitAuras.IsAuraFilteredOutByInstanceID(UNIT, data.auraInstanceID,
                        filterInfo.filterPlayer)
                    dataIndex = dataIndex + 1
                    auraDataCache[dataIndex] = data
                end
            end
        end
    end

    for auraID in pairs(soundPlayedFor) do
        if not seenAuras[auraID] then soundPlayedFor[auraID] = nil end
    end

    if dataIndex > 1 then tsort(auraDataCache, SortAuras) end
    local maxVisible = math_min(db.IconsPerRow * db.MaxRows, dataIndex)
    while #self.buttonPool < maxVisible do tinsert(self.buttonPool, CreateAuraButton(self.frame)) end

    for i = 1, #self.buttonPool do
        if i <= maxVisible and auraDataCache[i] then
            UpdateAuraButton(self.buttonPool[i], auraDataCache[i])
        else
            StopGlow(self.buttonPool[i])
            self.buttonPool[i]:Hide()
        end
    end

    PositionButtons(self)
end

local function ApplyButtonSettings(button, db)
    button:SetSize(db.IconSize, db.IconSize)
    if button.bg then button.bg:SetColorTexture(unpack(db.BackgroundColor)) end
    if button.SetBorderColor then button:SetBorderColor(unpack(db.BorderColor)) end
    if button.Count then
        NRSKNUI:ApplyFont(button.Count, NRSKNUI:GetEffectiveFont(db), db.FontSize, db.FontOutline)
        button.Count:SetShadowOffset(0, 0)
    end
    if button.Cooldown then
        ApplyCooldownTextStyle(button.Cooldown, db)
        button.Cooldown:SetDrawSwipe(db.Swipe)
        button.Cooldown:SetReverse(db.Reverse)
    end
    if button.Icon then NRSKNUI:ApplyZoom(button.Icon, NRSKNUI.GlobalZoom) end
end

local function GetFrameSize(db)
    local w = db.IconsPerRow * db.IconSize + (db.IconsPerRow - 1) * db.IconSpacing
    local h = db.MaxRows * db.IconSize + (db.MaxRows - 1) * db.IconSpacing
    return w, h
end

function EXTERNALS:ApplySettings()
    for button in pairs(self.buttons) do
        ApplyButtonSettings(button, self.db)
        if button:IsShown() and button.isExternal then
            StartGlow(button, true)
        elseif button.glowActive then
            StopGlow(button)
        end
    end
    if self.frame then
        self.frame:SetSize(GetFrameSize(self.db))
        self:ApplyPosition()
        PositionButtons(self)
    end
    if self.previewActive then self:ShowPreview() end
end

function EXTERNALS:CreateFrame()
    if self.frame then return end
    self.frame = CreateFrame("Frame", "NorskenUIExternalBuffFrame", UIParent)
    self.frame:SetSize(GetFrameSize(self.db))
    self.buttonPool = {}
    self:ApplyPosition()
    self.frame:Show()
end

function EXTERNALS:ApplyPosition()
    if not self.frame then return end
    local anchorPoint = GetAnchorPoint(self.db)
    local parent = NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(anchorPoint, parent, self.db.Position.AnchorTo, self.db.Position.XOffset, self.db.Position.YOffset)
    self.frame:SetFrameStrata(self.db.Strata or "MEDIUM")
    NRSKNUI:SnapFrameToPixels(self.frame, self.db.ForcePixelPerfect)
end

function EXTERNALS:UpdatePosition(pos)
    self.db.Position.AnchorTo = pos.AnchorTo
    self.db.Position.XOffset = pos.XOffset
    self.db.Position.YOffset = pos.YOffset
    self:ApplyPosition()
end

function EXTERNALS:UNIT_AURA(_, unit)
    if unit ~= UNIT or pendingAuraUpdate then return end
    if self.previewActive then return end
    pendingAuraUpdate = true
    C_Timer.After(0, function()
        pendingAuraUpdate = false
        if EXTERNALS.previewActive then return end
        EXTERNALS:UpdateAuras()
    end)
end

function EXTERNALS:OnEnable()
    if not self.db.Enabled then return end
    self:CreateFrame()
    self:RegisterEvent("UNIT_AURA")
    self:UpdateAuras()
    C_Timer.After(0.5, function() self:ApplyPosition() end)

    if not self.frame or not NRSKNUI.EditMode then return end
    NRSKNUI.EditMode:RegisterElement({
        key = "ExternalBuffTracking",
        displayName = "EXTERNALS",
        frame = self.frame,
        getPosition = function() return self.db.Position end,
        setPosition = function(pos) self:UpdatePosition(pos) end,
        getParentFrame = function() return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame) end,
        guiPath = "CustomSkin_Externals",
    })
end

function EXTERNALS:OnDisable()
    self:UnregisterEvent("UNIT_AURA")
    if self.frame then self.frame:Hide() end
end

-- Preview

function EXTERNALS:ShowPreview()
    if not self.frame then self:CreateFrame() end

    local db = self.db
    local spacing = db.IconSize + db.IconSpacing
    local previewCount = db.IconsPerRow * db.MaxRows
    local growH = db.GrowHorizontal == "LEFT" and -1 or 1
    local growV = db.GrowVertical == "DOWN" and -1 or 1
    local anchorPoint = GetAnchorPoint(db)

    while #self.buttonPool < previewCount do tinsert(self.buttonPool, CreateAuraButton(self.frame)) end

    for i, button in ipairs(self.buttonPool) do
        if i <= previewCount then
            ApplyButtonSettings(button, db)

            local col = (i - 1) % db.IconsPerRow
            local row = math_floor((i - 1) / db.IconsPerRow)
            button:ClearAllPoints()
            button:SetPoint(anchorPoint, self.frame, anchorPoint, col * spacing * growH, row * spacing * growV)

            if db.ShowBigDefensives then
                button.Icon:SetTexture(PREVIEW_ICONS_DEF[((i - 1) % #PREVIEW_ICONS_DEF) + 1])
                button.isExternal = (i % 2 == 1)
            else
                button.Icon:SetTexture(PREVIEW_ICONS[((i - 1) % #PREVIEW_ICONS) + 1])
                button.isExternal = true
            end
            button.auraInstanceID = nil

            local duration = 6 + ((i * 3) % 12)
            local startTime = GetTime() - (duration * (0.15 + (i % 4) * 0.1))
            button.Cooldown:SetCooldown(startTime, duration)
            button.Cooldown:Show()

            button:Show()

            if button.isExternal then
                StartGlow(button, true)
            else
                StopGlow(button)
            end
        else
            StopGlow(button)
            button:Hide()
        end
    end

    self.frame:Show()
    self.previewActive = true
end

function EXTERNALS:HidePreview()
    if not self.buttonPool then return end
    for _, button in ipairs(self.buttonPool) do StopGlow(button) end
    self.previewActive = false
    if self.frame and self.db.Enabled then
        self:UpdateAuras()
    elseif self.frame then
        for _, button in ipairs(self.buttonPool) do button:Hide() end
    end
end

function EXTERNALS:TogglePreview()
    if self.previewActive then
        self:HidePreview()
        self:ShowPreview()
    end
end

function EXTERNALS:IsPreviewActive()
    return self.previewActive or false
end
