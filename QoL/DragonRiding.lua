-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("DragonRiding: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local DR = NRSKNUI.Addon:NewModule("DragonRiding", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local VIGOR_SPELL = 372610
local THRILL_SPELL = 377234
local SECOND_WIND_SPELL = 425782
local WHIRLING_SURGE_SPELL = 361584

-- Module variables
local numVigor = 0
local BORDER_WIDTH = 1

-- Module frames
DR.container = nil
DR.parent = nil
DR.vigorFrame = nil
DR.surgeFrame = nil
DR.secondWindFrame = nil
DR.speedText = nil
DR.isPreview = false

-- Module init
function DR:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.DragonRiding
    self:SetEnabledState(false)
end

-- Create a pill
local function CreatePill(parent, height)
    local pill = CreateFrame("StatusBar", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    pill:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = BORDER_WIDTH,
        insets = { left = -1, right = -1, top = -1, bottom = -1 },
    })
    pill:SetBackdropColor(0, 0, 0, 0.8)
    pill:SetBackdropBorderColor(0, 0, 0, 1)
    pill:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    pill:SetHeight(height)
    pill:SetStatusBarColor(0.75, 0.75, 0.75)
    return pill
end

-- Resize pills to fit evenly within container
local function ResizePillsToFit(container, pills, numPills, spacing)
    spacing = spacing or 1
    local maxWidth = container:GetWidth()
    local totalSpacing = spacing * (numPills - 1)
    local availableForPills = maxWidth - totalSpacing
    local barWidth = math.floor(availableForPills / numPills)
    local leftover = math.floor(availableForPills - (barWidth * numPills))

    for index = 1, numPills do
        if pills[index] then
            if index <= leftover then
                pills[index]:SetWidth(barWidth + 1)
            else
                pills[index]:SetWidth(barWidth)
            end
        end
    end
end

-- Update Whirling Surge
local function UpdateWhirlingSurge(self)
    local pill = self.surgeFrame[1]
    if not pill then return end

    local charges = C_Spell.GetSpellCharges(WHIRLING_SURGE_SPELL)
    if charges and charges.currentCharges > 0 then
        local duration = C_Spell.GetSpellChargeDuration(WHIRLING_SURGE_SPELL)
        if duration and not duration:IsZero() then
            pill:SetTimerDuration(duration)
        else
            pill:SetMinMaxValues(0, 1)
            pill:SetValue(1)
        end
    else
        local duration = C_Spell.GetSpellCooldownDuration(WHIRLING_SURGE_SPELL)
        if duration and not duration:IsZero() then
            pill:SetTimerDuration(duration)
        else
            pill:SetMinMaxValues(0, 1)
            pill:SetValue(1)
        end
    end
end

-- Update Second Wind
local function UpdateSecondWind(self)
    local charges = C_Spell.GetSpellCharges(SECOND_WIND_SPELL)
    if not charges then return end

    for index = 1, 3 do
        local pill = self.secondWindFrame[index]
        if pill then
            if charges.currentCharges >= index then
                -- Full charge
                pill:SetMinMaxValues(0, 1)
                pill:SetValue(1)
            elseif charges.currentCharges + 1 == index then
                -- Currently charging
                local duration = C_Spell.GetSpellChargeDuration(SECOND_WIND_SPELL)
                if duration then
                    pill:SetTimerDuration(duration)
                end
            else
                -- Empty
                pill:SetMinMaxValues(0, 1)
                pill:SetValue(0)
            end
        end
    end
end

-- Update Vigor
local function UpdateVigor(self)
    local charges = C_Spell.GetSpellCharges(VIGOR_SPELL)
    if not charges then return end

    local spacing = self.db.Spacing or 1
    for index = 1, charges.maxCharges do
        local pill = self.vigorFrame[index]
        if not pill then
            pill = CreatePill(self.vigorFrame, self.vigorFrame:GetHeight())
            self.vigorFrame[index] = pill

            if index == 1 then
                pill:SetPoint('LEFT')
            else
                pill:SetPoint('LEFT', self.vigorFrame[index - 1], 'RIGHT', spacing, 0)
            end
        end

        if charges.currentCharges >= index then
            pill:SetMinMaxValues(0, 1)
            pill:SetValue(1)
        elseif charges.currentCharges + 1 == index then
            local duration = C_Spell.GetSpellChargeDuration(VIGOR_SPELL)
            if duration then
                pill:SetTimerDuration(duration)
            end
        else
            pill:SetMinMaxValues(0, 1)
            pill:SetValue(0)
        end
    end

    if numVigor ~= charges.maxCharges then
        numVigor = charges.maxCharges
        ResizePillsToFit(self.vigorFrame, self.vigorFrame, numVigor, spacing)
    end
end

-- Update Vigor color based on Thrill of the Skies buff
local function UpdateVigorColor(self)
    local db = self.db
    local r, g, b
    if C_UnitAuras.GetAuraDataBySpellName('player', C_Spell.GetSpellName(THRILL_SPELL), 'HELPFUL') then
        -- Thrill of the Skies active - use thrill color
        local color = db.Colors and db.Colors.VigorThrill or { 0.2, 0.8, 0.2, 1 }
        r, g, b = color[1], color[2], color[3]
    else
        -- Normal vigor color
        local color = db.Colors and db.Colors.Vigor or { 0.898, 0.063, 0.224, 1 }
        r, g, b = color[1], color[2], color[3]
    end

    -- Use 6 pills in preview mode, otherwise use actual numVigor
    local count = self.isPreview and 6 or numVigor
    for index = 1, count do
        if self.vigorFrame[index] then
            self.vigorFrame[index]:SetStatusBarColor(r, g, b)
        end
    end
end

-- Update Speed text
local function UpdateSpeed(self)
    local speed = self.speedText
    if not speed then return end

    -- Ensure font is set before attempting to update text
    local fontFile = speed:GetFont()
    if not fontFile then
        local font = NRSKNUI.FONT or "Fonts\\FRIZQT__.TTF"
        local db = self.db
        speed:SetFont(font, db and db.SpeedFontSize or 14, 'OUTLINE')
        -- Re-check if font was set successfully
        fontFile = speed:GetFont()
        if not fontFile then return end
    end

    local isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
    if isGliding then
        pcall(speed.SetFormattedText, speed, '%d%%', forwardSpeed / BASE_MOVEMENT_SPEED * 100 + 0.5)
    else
        pcall(speed.SetText, speed, '')
    end
end

-- Create all frames
function DR:CreateFrames()
    if self.container then return end
    local db = self.db
    local barWidth = db.Width or 252
    local barHeight = db.BarHeight or 12
    local spacing = db.Spacing or 1

    -- Create secure parent for state driver
    self.parent = CreateFrame('Frame', nil, UIParent, 'SecureHandlerStateTemplate')
    self.parent:Hide()

    -- Create container frame for EditMode
    self.container = CreateFrame('Frame', 'NRSKNUI_DragonRidingContainer', self.parent)
    local totalHeight = (barHeight * 3) + (spacing * 2) + 20
    self.container:SetSize(barWidth, totalHeight)
    self.container:SetPoint(
        db.Position.AnchorFrom or "CENTER",
        UIParent,
        db.Position.AnchorTo or "CENTER",
        db.Position.XOffset or 0,
        db.Position.YOffset or 220
    )
    NRSKNUI:SnapFrameToPixels(self.container)

    -- Row 3 Second Wind
    self.secondWindFrame = CreateFrame('Frame', nil, self.container)
    self.secondWindFrame:SetPoint('BOTTOMLEFT', self.container, 'BOTTOMLEFT', 0, 0)
    self.secondWindFrame:SetPoint('BOTTOMRIGHT', self.container, 'BOTTOMRIGHT', 0, 0)
    self.secondWindFrame:SetHeight(barHeight)

    -- Create 3 Second Wind pills
    local swColor = db.Colors and db.Colors.SecondWind or { 0.3, 0.7, 1, 1 }
    for i = 1, 3 do
        local pill = CreatePill(self.secondWindFrame, barHeight)
        pill:SetStatusBarColor(swColor[1], swColor[2], swColor[3])
        self.secondWindFrame[i] = pill

        if i == 1 then
            pill:SetPoint('LEFT')
        else
            pill:SetPoint('LEFT', self.secondWindFrame[i - 1], 'RIGHT', spacing, 0)
        end
    end
    ResizePillsToFit(self.secondWindFrame, self.secondWindFrame, 3, spacing)

    -- Row 2 Whirling Surge
    self.surgeFrame = CreateFrame('Frame', nil, self.container)
    self.surgeFrame:SetPoint('BOTTOMLEFT', self.secondWindFrame, 'TOPLEFT', 0, spacing)
    self.surgeFrame:SetPoint('BOTTOMRIGHT', self.secondWindFrame, 'TOPRIGHT', 0, spacing)
    self.surgeFrame:SetHeight(barHeight)

    local surgePill = CreatePill(self.surgeFrame, barHeight)
    local surgeColor = db.Colors and db.Colors.WhirlingSurge or { 0.6, 0.4, 0.9, 1 }
    surgePill:SetStatusBarColor(surgeColor[1], surgeColor[2], surgeColor[3])
    surgePill:SetPoint('LEFT')
    surgePill:SetPoint('RIGHT')
    self.surgeFrame[1] = surgePill

    -- Row 1 Vigor
    self.vigorFrame = CreateFrame('Frame', nil, self.container)
    self.vigorFrame:SetPoint('BOTTOMLEFT', self.surgeFrame, 'TOPLEFT', 0, spacing)
    self.vigorFrame:SetPoint('BOTTOMRIGHT', self.surgeFrame, 'TOPRIGHT', 0, spacing)
    self.vigorFrame:SetHeight(barHeight)

    -- Speed text above vigor
    self.speedText = self.vigorFrame:CreateFontString(nil, 'OVERLAY')
    local fontFile = NRSKNUI:GetFontPath(self.db.FontFace) or NRSKNUI.FONT or "Fonts\\FRIZQT__.TTF"
    local fontSize = self.db.SpeedFontSize or 14
    self.speedText:SetFont(fontFile, fontSize, "OUTLINE")
    self.speedText:SetWordWrap(false)
    self.speedText:SetPoint('BOTTOM', self.vigorFrame, 'TOP', 0, 2)
    self.speedText:SetShadowOffset(0, 0)
    self.speedText:SetText("")
end

-- Apply settings
function DR:ApplySettings()
    if not self.container then return end
    local db = self.db
    local barWidth = db.Width or 252
    local barHeight = db.BarHeight or 12
    local spacing = db.Spacing or 1
    local totalHeight = (barHeight * 3) + (spacing * 2) + 20

    -- Update container size
    self.container:SetSize(barWidth, totalHeight)

    -- Update row heights
    self.secondWindFrame:SetHeight(barHeight)
    self.surgeFrame:SetHeight(barHeight)
    self.vigorFrame:SetHeight(barHeight)

    -- Update row positions for spacing changes
    self.surgeFrame:ClearAllPoints()
    self.surgeFrame:SetPoint('BOTTOMLEFT', self.secondWindFrame, 'TOPLEFT', 0, spacing)
    self.surgeFrame:SetPoint('BOTTOMRIGHT', self.secondWindFrame, 'TOPRIGHT', 0, spacing)

    self.vigorFrame:ClearAllPoints()
    self.vigorFrame:SetPoint('BOTTOMLEFT', self.surgeFrame, 'TOPLEFT', 0, spacing)
    self.vigorFrame:SetPoint('BOTTOMRIGHT', self.surgeFrame, 'TOPRIGHT', 0, spacing)

    -- Update Second Wind pills
    local swColor = db.Colors and db.Colors.SecondWind or { 0.3, 0.7, 1, 1 }
    for i = 1, 3 do
        if self.secondWindFrame[i] then
            self.secondWindFrame[i]:SetHeight(barHeight)
            self.secondWindFrame[i]:SetStatusBarColor(swColor[1], swColor[2], swColor[3])
            -- Update pill spacing
            if i > 1 then
                self.secondWindFrame[i]:ClearAllPoints()
                self.secondWindFrame[i]:SetPoint('LEFT', self.secondWindFrame[i - 1], 'RIGHT', spacing, 0)
            end
        end
    end
    ResizePillsToFit(self.secondWindFrame, self.secondWindFrame, 3, spacing)

    -- Update Whirling Surge pill
    local surgeColor = db.Colors and db.Colors.WhirlingSurge or { 0.6, 0.4, 0.9, 1 }
    if self.surgeFrame[1] then
        self.surgeFrame[1]:SetHeight(barHeight)
        self.surgeFrame[1]:SetStatusBarColor(surgeColor[1], surgeColor[2], surgeColor[3])
    end

    -- Update Vigor pills
    local vigorCount = self.isPreview and 6 or numVigor
    for i = 1, vigorCount do
        if self.vigorFrame[i] then
            self.vigorFrame[i]:SetHeight(barHeight)
            -- Update pill spacing
            if i > 1 then
                self.vigorFrame[i]:ClearAllPoints()
                self.vigorFrame[i]:SetPoint('LEFT', self.vigorFrame[i - 1], 'RIGHT', spacing, 0)
            end
        end
    end
    if vigorCount > 0 then
        ResizePillsToFit(self.vigorFrame, self.vigorFrame, vigorCount, spacing)
    end
    UpdateVigorColor(self)

    -- Update speed font and keep preview text if in preview mode
    local fontFile = NRSKNUI:GetFontPath(self.db.FontFace) or NRSKNUI.FONT or "Fonts\\FRIZQT__.TTF"
    local fontSize = self.db.SpeedFontSize or 14
    self.speedText:SetFont(fontFile, fontSize, "OUTLINE")
    if self.isPreview then
        self.speedText:SetText('420%')
    end
end

-- Apply position from database
function DR:ApplyPosition()
    if not self.container then return end

    local db = self.db
    self.container:ClearAllPoints()
    self.container:SetPoint(
        db.Position.AnchorFrom or "CENTER",
        UIParent,
        db.Position.AnchorTo or "CENTER",
        db.Position.XOffset or 0,
        db.Position.YOffset or 220
    )
    NRSKNUI:SnapFrameToPixels(self.container)
end

-- Refresh all
function DR:Refresh()
    self:ApplySettings()
    self:ApplyPosition()

    -- Update displays if visible
    if self.parent and self.parent:IsShown() then
        UpdateVigor(self)
        UpdateVigorColor(self)
        UpdateWhirlingSurge(self)
        UpdateSecondWind(self)
    end
end

-- Preview mode
function DR:ShowPreview()
    if not self.container then
        self:CreateFrames()
    end
    self.isPreview = true

    -- Cancel any existing ticker and unregister events for clean preview state
    if self.speedTicker then
        self.speedTicker:Cancel()
        self.speedTicker = nil
    end
    if self.vigorFrame then
        self.vigorFrame:UnregisterAllEvents()
        self.vigorFrame:SetScript('OnEvent', nil)
    end
    if self.surgeFrame then
        self.surgeFrame:UnregisterAllEvents()
        self.surgeFrame:SetScript('OnEvent', nil)
    end
    if self.secondWindFrame then
        self.secondWindFrame:UnregisterAllEvents()
        self.secondWindFrame:SetScript('OnEvent', nil)
    end

    -- Disable state driver during preview so it doesn't hide the frame
    if self.parent then
        UnregisterStateDriver(self.parent, 'visibility')
        self.parent:Show()
    end

    -- Create preview vigor pills if needed
    local spacing = self.db.Spacing or 1
    for i = 1, 6 do
        if not self.vigorFrame[i] then
            local pill = CreatePill(self.vigorFrame, self.vigorFrame:GetHeight())
            self.vigorFrame[i] = pill
            if i == 1 then
                pill:SetPoint('LEFT')
            else
                pill:SetPoint('LEFT', self.vigorFrame[i - 1], 'RIGHT', spacing, 0)
            end
        end
    end

    -- Apply settings
    self:ApplySettings()

    -- Set preview values
    for i = 1, 6 do
        self.vigorFrame[i]:SetMinMaxValues(0, 1)
        if i <= 4 then
            self.vigorFrame[i]:SetValue(1)
        elseif i == 5 then
            self.vigorFrame[i]:SetValue(0.6)
        else
            self.vigorFrame[i]:SetValue(0)
        end
    end

    -- Preview Second Wind
    for i = 1, 3 do
        self.secondWindFrame[i]:SetMinMaxValues(0, 1)
        if i <= 2 then
            self.secondWindFrame[i]:SetValue(1)
        else
            self.secondWindFrame[i]:SetValue(0.3)
        end
    end

    -- Preview Whirling Surge
    self.surgeFrame[1]:SetMinMaxValues(0, 1)
    self.surgeFrame[1]:SetValue(1)
end

function DR:HidePreview()
    self.isPreview = false
    if self.parent then
        RegisterStateDriver(self.parent, 'visibility', '[bonusbar:5] show; hide')
        if self.parent:IsShown() then
            self:OnShowHandler()
        end
    end
end

-- Event handlers
function DR:OnShowHandler()
    if self.isPreview then return end

    -- Ensure speed text font is set before starting ticker
    if self.speedText then
        local fontFile = self.speedText:GetFont()
        if not fontFile then
            local font = NRSKNUI:GetFontPath(self.db.FontFace) or NRSKNUI.FONT or "Fonts\\FRIZQT__.TTF"
            local fontSize = self.db.SpeedFontSize or 14
            self.speedText:SetFont(font, fontSize, 'OUTLINE')
        end
    end

    self.vigorFrame:RegisterEvent('SPELL_UPDATE_CHARGES')
    self.vigorFrame:SetScript('OnEvent', function() UpdateVigor(self) end)
    self.vigorFrame:RegisterUnitEvent('UNIT_AURA', 'player')
    self.vigorFrame:HookScript('OnEvent', function() UpdateVigorColor(self) end)

    self.surgeFrame:RegisterEvent('SPELL_UPDATE_COOLDOWN')
    self.surgeFrame:RegisterEvent('SPELL_UPDATE_CHARGES')
    self.surgeFrame:SetScript('OnEvent', function() UpdateWhirlingSurge(self) end)

    self.secondWindFrame:RegisterEvent('SPELL_UPDATE_COOLDOWN')
    self.secondWindFrame:RegisterEvent('SPELL_UPDATE_CHARGES')
    self.secondWindFrame:SetScript('OnEvent', function() UpdateSecondWind(self) end)

    self.speedTicker = C_Timer.NewTicker(0.05, function() UpdateSpeed(self) end)

    UpdateVigor(self)
    UpdateVigorColor(self)
    UpdateWhirlingSurge(self)
    UpdateSecondWind(self)
end

function DR:OnHideHandler()
    if self.isPreview then return end

    self.vigorFrame:UnregisterEvent('SPELL_UPDATE_CHARGES')
    self.vigorFrame:UnregisterEvent('UNIT_AURA')
    self.surgeFrame:UnregisterEvent('SPELL_UPDATE_COOLDOWN')
    self.surgeFrame:UnregisterEvent('SPELL_UPDATE_CHARGES')
    self.secondWindFrame:UnregisterEvent('SPELL_UPDATE_COOLDOWN')
    self.secondWindFrame:UnregisterEvent('SPELL_UPDATE_CHARGES')

    if self.speedTicker then
        self.speedTicker:Cancel()
        self.speedTicker = nil
    end
end

-- Module OnEnable
function DR:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrames()
    self:ApplySettings()

    -- Setup show/hide handlers
    self.parent:HookScript('OnShow', function() self:OnShowHandler() end)
    self.parent:HookScript('OnHide', function() self:OnHideHandler() end)

    -- Register state driver for skyriding
    RegisterStateDriver(self.parent, 'visibility', '[bonusbar:5] show; hide')

    -- Register with EditMode using the container frame
    local config = {
        key = "DragonRiding",
        displayName = "Skyriding UI",
        frame = self.container,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            if self.container then
                self.container:ClearAllPoints()
                self.container:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        getParentFrame = function()
            return UIParent
        end,
        guiPath = "DragonRiding",
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

-- Module OnDisable
function DR:OnDisable()
    if self.parent then
        self.parent:Hide()
        UnregisterStateDriver(self.parent, 'visibility')
    end

    if self.speedTicker then
        self.speedTicker:Cancel()
        self.speedTicker = nil
    end
end
