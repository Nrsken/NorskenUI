-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("BuffBars: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local BB = NRSKNUI.Addon:NewModule("BuffBars", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local GetTime = GetTime
local GetItemSpell = GetItemSpell
local unpack = unpack
local floor = math.floor
local pairs = pairs
local ipairs = ipairs
local next = next
local C_Spell = C_Spell
local C_Item = C_Item
local _G = _G

-- Constants
local BAR_UPDATE_THRESHOLD = 0.1

-- Module state
BB.trackerFrames = {}
BB.updateFrame = nil
BB.containerFrame = nil

-- Module init
function BB:OnInitialize()
    self.db = NRSKNUI.db.profile.CustomBuffs and NRSKNUI.db.profile.CustomBuffs.Bars
    self:SetEnabledState(false)
end

-- Get defaults
function BB:GetDefaults()
    return self.db and self.db.Defaults or {}
end

-- Get tracker config with defaults merged
function BB:GetTrackerConfig(tracker)
    local defaults = self:GetDefaults()
    return {
        SpellID = tracker.SpellID,
        Type = tracker.Type or "Spell",
        Enabled = tracker.Enabled ~= false,
        Duration = tracker.Duration or 10,
        SpellText = tracker.SpellText or "",
        BarWidth = tracker.BarWidth or defaults.BarWidth or 244,
        BarHeight = tracker.BarHeight or defaults.BarHeight or 24,
        IconSize = tracker.IconSize or defaults.IconSize or 20,
        ShowIcon = tracker.ShowIcon ~= false and (defaults.ShowIcon ~= false),
        ShowTimeText = tracker.ShowTimeText ~= false and (defaults.ShowTimeText ~= false),
        ShowSpellText = tracker.ShowSpellText ~= false and (defaults.ShowSpellText ~= false),
        FontSize = tracker.FontSize or defaults.FontSize or 12,
        BarColor = tracker.BarColor or defaults.BarColor or { 0.65, 0.65, 0.65, 1 },
        BackgroundColor = tracker.BackgroundColor or defaults.BackgroundColor or { 0, 0, 0, 0.8 },
        BorderColor = tracker.BorderColor or defaults.BorderColor or { 0, 0, 0, 1 },
        Reverse = tracker.Reverse or defaults.Reverse or false,
    }
end

-- Create container frame for all bars
function BB:CreateContainerFrame()
    if self.containerFrame then return self.containerFrame end

    local db = self.db
    if not db then return nil end

    self.containerFrame = CreateFrame("Frame", "NorskenUI_BuffBars_Container", UIParent)
    self.containerFrame:SetSize(1, 1)
    self.containerFrame:SetFrameStrata("MEDIUM")

    -- Position
    local anchorFrom = db.Position and db.Position.AnchorFrom or "CENTER"
    local anchorTo = db.Position and db.Position.AnchorTo or "CENTER"
    local xOffset = db.Position and db.Position.XOffset or 0.1
    local yOffset = db.Position and db.Position.YOffset or 100.1

    local parentFrame = UIParent
    if db.anchorFrameType == "SELECTFRAME" and db.anchorFrameFrame then
        parentFrame = _G[db.anchorFrameFrame] or UIParent
    end

    self.containerFrame:ClearAllPoints()
    self.containerFrame:SetPoint(anchorFrom, parentFrame, anchorTo, xOffset, yOffset)

    return self.containerFrame
end

-- Create a buff statusbar frame for a tracker
function BB:CreateTrackerFrame(trackerIndex, config)
    local iconSize = config.ShowIcon and config.BarHeight or 0

    local frame = CreateFrame("Frame", "NorskenUI_BuffBar_" .. trackerIndex, self.containerFrame or UIParent,
        "BackdropTemplate")
    frame:SetSize(config.BarWidth, config.BarHeight)
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()

    frame.totalWidth = config.BarWidth

    -- Bar container with border
    frame.barContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.barContainer:SetAllPoints()
    frame.barContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame.barContainer:SetBackdropColor(unpack(config.BackgroundColor))
    frame.barContainer:SetBackdropBorderColor(unpack(config.BorderColor))

    -- StatusBar
    frame.bar = CreateFrame("StatusBar", nil, frame.barContainer)
    frame.bar:SetPoint("TOPLEFT", 1, -1)
    frame.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar:SetStatusBarColor(unpack(config.BarColor))
    frame.bar:SetMinMaxValues(0, config.Duration)
    frame.bar:SetValue(config.Duration)

    -- Icon
    if config.ShowIcon then
        frame.iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.iconFrame:SetSize(iconSize, iconSize)
        frame.iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
        frame.iconFrame:SetFrameLevel(frame.bar:GetFrameLevel() + 2)

        frame.iconFrame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame.iconFrame:SetBackdropBorderColor(unpack(config.BorderColor))

        frame.iconFrame.bg = frame.iconFrame:CreateTexture(nil, "BACKGROUND")
        frame.iconFrame.bg:SetAllPoints()
        frame.iconFrame.bg:SetColorTexture(0, 0, 0, 1)

        local zoom = 0.3
        local texMin = 0.25 * zoom
        local texMax = 1 - 0.25 * zoom
        frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetPoint("TOPLEFT", 1, -1)
        frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.icon:SetTexCoord(texMin, texMax, texMin, texMax)

        local iconTexture
        if config.Type == "Item" then
            iconTexture = C_Item.GetItemIconByID(config.SpellID)
        else
            local spellInfo = C_Spell.GetSpellInfo(config.SpellID)
            iconTexture = spellInfo and spellInfo.iconID
        end
        if iconTexture then
            frame.icon:SetTexture(iconTexture)
        end
    end

    -- Time text
    if config.ShowTimeText then
        frame.timeText = frame.bar:CreateFontString(nil, "OVERLAY")
        frame.timeText:SetFont(STANDARD_TEXT_FONT, config.FontSize, "OUTLINE")
        frame.timeText:SetPoint("RIGHT", frame.bar, "RIGHT", -2, 0)
        frame.timeText:SetTextColor(1, 1, 1, 1)
        frame.timeText:SetShadowOffset(0, 0)
    end

    -- Spell text
    if config.ShowSpellText then
        frame.spellText = frame.bar:CreateFontString(nil, "OVERLAY")
        frame.spellText:SetFont(STANDARD_TEXT_FONT, config.FontSize, "OUTLINE")
        local textOffset = config.ShowIcon and (iconSize + 4) or 2
        frame.spellText:SetPoint("LEFT", frame.bar, "LEFT", textOffset, 0)
        frame.spellText:SetTextColor(1, 1, 1, 1)
        frame.spellText:SetShadowOffset(0, 0)
        frame.spellText:SetText(config.SpellText)
    end

    frame.config = config
    frame.trackerIndex = trackerIndex
    frame.endTime = 0
    frame.lastBarValue = 0

    return frame
end

-- Get growth offset for positioning bars
function BB:GetGrowthOffset(direction, index, totalCount, size, spacing)
    local offset = (index - 1) * (size + spacing)
    if direction == "UP" then
        return 0, offset
    elseif direction == "DOWN" then
        return 0, -offset
    elseif direction == "LEFT" then
        return -offset, 0
    elseif direction == "RIGHT" then
        return offset, 0
    elseif direction == "CENTER" then
        local totalWidth = (totalCount * size) + ((totalCount - 1) * spacing)
        local startOffset = -totalWidth / 2 + size / 2
        return startOffset + offset, 0
    end
    return 0, -offset
end

-- Layout visible bars based on growth direction
function BB:LayoutBars()
    local db = self.db
    if not db then return end

    local direction = db.GrowthDirection or "DOWN"
    local spacing = db.Spacing or 2

    local visibleFrames = {}
    for index, frame in pairs(self.trackerFrames) do
        if frame:IsShown() then
            table.insert(visibleFrames, { index = index, frame = frame })
        end
    end
    table.sort(visibleFrames, function(a, b) return a.index < b.index end)

    local totalCount = #visibleFrames

    for i, entry in ipairs(visibleFrames) do
        local frame = entry.frame
        local size = (direction == "LEFT" or direction == "RIGHT" or direction == "CENTER")
            and frame.totalWidth or frame.config.BarHeight
        local xOff, yOff = self:GetGrowthOffset(direction, i, totalCount, size, spacing)

        frame:ClearAllPoints()
        frame:SetPoint("CENTER", self.containerFrame, "CENTER", xOff, yOff)
    end
end

-- OnUpdate handler for bar updates
function BB:OnUpdate(elapsed)
    local now = GetTime()
    local anyActive = false
    local needsLayout = false

    for _, frame in pairs(self.trackerFrames) do
        if frame:IsShown() then
            local remaining = frame.endTime - now
            if remaining <= 0 then
                frame:Hide()
                needsLayout = true
            else
                anyActive = true
                local config = frame.config
                local value = config.Reverse and (config.Duration - remaining) or remaining

                if math.abs(value - frame.lastBarValue) >= BAR_UPDATE_THRESHOLD then
                    frame.lastBarValue = value
                    frame.bar:SetValue(value, Enum.StatusBarInterpolation.ExponentialEaseOut)
                end

                if config.ShowTimeText and frame.timeText then
                    if remaining >= 1 then
                        frame.timeText:SetText(floor(remaining + 0.5))
                    else
                        frame.timeText:SetFormattedText("%.1f", remaining)
                    end
                end
            end
        end
    end

    if needsLayout then
        self:LayoutBars()
    end

    if not anyActive and self.updateFrame then
        self.updateFrame:SetScript("OnUpdate", nil)
    end
end

-- Show a specific tracker
function BB:ShowTracker(trackerIndex)
    local frame = self.trackerFrames[trackerIndex]
    if not frame then return end
    if not frame.config.Enabled then return end

    local config = frame.config
    frame.endTime = GetTime() + config.Duration

    frame.bar:SetMinMaxValues(0, config.Duration)
    if config.Reverse then
        frame.bar:SetValue(0, Enum.StatusBarInterpolation.Immediate)
        frame.lastBarValue = 0
    else
        frame.bar:SetValue(config.Duration, Enum.StatusBarInterpolation.Immediate)
        frame.lastBarValue = config.Duration
    end
    frame.bar:SetToTargetValue()
    frame:Show()

    self:LayoutBars()

    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
    end
    self.updateFrame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)
end

-- Show a specific tracker for preview
function BB:ShowTrackerPreview(trackerIndex)
    local frame = self.trackerFrames[trackerIndex]
    if not frame then return end

    local config = frame.config
    frame.endTime = GetTime() + config.Duration

    frame.bar:SetMinMaxValues(0, config.Duration)
    if config.Reverse then
        frame.bar:SetValue(0, Enum.StatusBarInterpolation.Immediate)
        frame.lastBarValue = 0
    else
        frame.bar:SetValue(config.Duration, Enum.StatusBarInterpolation.Immediate)
        frame.lastBarValue = config.Duration
    end
    frame.bar:SetToTargetValue()
    frame:Show()

    self:LayoutBars()

    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
    end
    self.updateFrame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)
end

-- Handle spell cast events
function BB:OnSpellCast(event, unit, _, spellID)
    if unit ~= "player" then return end
    if not self.db or not self.db.Enabled or not self.db.Trackers then return end

    for index, tracker in pairs(self.db.Trackers) do
        if tracker.Enabled ~= false and tracker.SpellID then
            local shouldTrigger = false

            if tracker.Type == "Item" then
                local _, itemSpellID = GetItemSpell(tracker.SpellID)
                if itemSpellID and itemSpellID == spellID then
                    shouldTrigger = true
                end
            else
                if tracker.SpellID == spellID then
                    shouldTrigger = true
                end
            end

            if shouldTrigger then
                self:ShowTracker(index)
            end
        end
    end
end

-- Create all tracker frames
function BB:CreateAllTrackers()
    -- Clean up existing frames
    for _, frame in pairs(self.trackerFrames) do
        frame:Hide()
        frame:SetParent(nil)
    end
    self.trackerFrames = {}

    -- Clean up container
    if self.containerFrame then
        self.containerFrame:Hide()
        self.containerFrame:SetParent(nil)
        self.containerFrame = nil
    end
    local db = self.db
    if not db or not db.Trackers then return end
    self:CreateContainerFrame()
    if not self.containerFrame then return end
    for index, tracker in pairs(db.Trackers) do
        if tracker.SpellID then
            local config = self:GetTrackerConfig(tracker)
            self.trackerFrames[index] = self:CreateTrackerFrame(index, config)
        end
    end
end

-- Apply position
function BB:ApplyPosition()
    if not self.containerFrame then return end
    local db = self.db
    if not db then return end
    local anchorFrom = db.Position and db.Position.AnchorFrom or "CENTER"
    local anchorTo = db.Position and db.Position.AnchorTo or "CENTER"
    local xOffset = db.Position and db.Position.XOffset or 0.1
    local yOffset = db.Position and db.Position.YOffset or 100.1
    local parentFrame = UIParent
    if db.anchorFrameType == "SELECTFRAME" and db.anchorFrameFrame then
        parentFrame = _G[db.anchorFrameFrame] or UIParent
    end
    self.containerFrame:ClearAllPoints()
    self.containerFrame:SetPoint(anchorFrom, parentFrame, anchorTo, xOffset, yOffset)
end

-- Module OnEnable
function BB:OnEnable()
    if not self.db.Enabled then return end
    self:CreateAllTrackers()
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellCast")
end

-- Module OnDisable
function BB:OnDisable()
    for _, frame in pairs(self.trackerFrames) do frame:Hide() end
    if self.updateFrame then self.updateFrame:SetScript("OnUpdate", nil) end
    self:UnregisterAllEvents()
end

-- Public API for GUI
function BB:Refresh()
    self:CreateAllTrackers()
end

function BB:ApplySettings()
    self.db = NRSKNUI.db.profile.CustomBuffs and NRSKNUI.db.profile.CustomBuffs.Bars
    if self.db and self.db.Enabled then
        if not self:IsEnabled() then
            NRSKNUI.Addon:EnableModule("BuffBars")
        else
            self:CreateAllTrackers()
        end
    else
        if self:IsEnabled() then
            NRSKNUI.Addon:DisableModule("BuffBars")
        end
    end
end

function BB:PreviewAll()
    if not next(self.trackerFrames) then
        self:CreateAllTrackers()
    end

    for index, _ in pairs(self.trackerFrames) do
        self:ShowTrackerPreview(index)
    end
end

function BB:HideAll()
    for _, frame in pairs(self.trackerFrames) do
        frame:Hide()
    end
    if self.updateFrame then
        self.updateFrame:SetScript("OnUpdate", nil)
    end
end
