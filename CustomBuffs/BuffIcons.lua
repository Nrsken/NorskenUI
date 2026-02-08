-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("BuffIcons: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local BI = NRSKNUI.Addon:NewModule("BuffIcons", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local GetTime = GetTime
local GetItemSpell = GetItemSpell
local unpack = unpack
local pairs = pairs
local ipairs = ipairs
local next = next
local C_Spell = C_Spell
local C_Item = C_Item
local C_Timer = C_Timer
local _G = _G

-- Module state
BI.trackerFrames = {}
BI.containerFrame = nil
BI.activeTimers = {} -- Track active C_Timer handles by trackerIndex

-- Module init
function BI:OnInitialize()
    self.db = NRSKNUI.db.profile.CustomBuffs and NRSKNUI.db.profile.CustomBuffs.Icons
    self:SetEnabledState(false)
end

-- Get defaults
function BI:GetDefaults()
    return self.db and self.db.Defaults or {}
end

-- Get tracker config with defaults merged
function BI:GetTrackerConfig(tracker)
    local defaults = self:GetDefaults()
    return {
        SpellID = tracker.SpellID,
        Type = tracker.Type or "Spell",
        Enabled = tracker.Enabled ~= false,
        Duration = tracker.Duration or 10,
        UseCustomTexture = tracker.UseCustomTexture or false,
        CustomTexture = tracker.CustomTexture or nil,
        IconSize = defaults.IconSize or 40,
        ShowCooldownText = defaults.ShowCooldownText ~= false,
        CountdownSize = defaults.CountdownSize or 18,
        BorderColor = defaults.BorderColor or { 0, 0, 0, 1 },
        BorderSize = defaults.BorderSize or 1,
    }
end

-- Create container frame for all icons
function BI:CreateContainerFrame()
    if self.containerFrame then return self.containerFrame end

    local db = self.db
    if not db then return nil end

    self.containerFrame = CreateFrame("Frame", "NorskenUI_BuffIcons_Container", UIParent)
    self.containerFrame:SetSize(1, 1)
    self.containerFrame:SetFrameStrata("MEDIUM")

    -- Apply position from database
    local anchorFrom = db.Position and db.Position.AnchorFrom or "CENTER"
    local anchorTo = db.Position and db.Position.AnchorTo or "CENTER"
    local xOffset = db.Position and db.Position.XOffset or 0.1
    local yOffset = db.Position and db.Position.YOffset or 150.1

    local parentFrame = UIParent
    if db.anchorFrameType == "SELECTFRAME" and db.anchorFrameFrame then
        parentFrame = _G[db.anchorFrameFrame] or UIParent
    end

    self.containerFrame:ClearAllPoints()
    self.containerFrame:SetPoint(anchorFrom, parentFrame, anchorTo, xOffset, yOffset)

    return self.containerFrame
end

-- Create a buff icon frame for a tracker
function BI:CreateTrackerFrame(trackerIndex, config)
    local frame = CreateFrame("Frame", "NorskenUI_BuffIcon_" .. trackerIndex, self.containerFrame or UIParent)
    frame:SetSize(config.IconSize, config.IconSize)
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()

    -- Create border/backdrop
    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetAllPoints()
    frame.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = config.BorderSize,
    })
    frame.border:SetBackdropBorderColor(unpack(config.BorderColor))

    -- Icon texture with zoom to hide blizzard border
    local zoom = 0.3
    local texMin = 0.25 * zoom
    local texMax = 1 - 0.25 * zoom
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(texMin, texMax, texMin, texMax)

    -- Get icon based on type
    local iconTexture
    if config.UseCustomTexture and config.CustomTexture then
        iconTexture = config.CustomTexture
    elseif config.Type == "Item" then
        iconTexture = C_Item.GetItemIconByID(config.SpellID)
    else
        local spellInfo = C_Spell.GetSpellInfo(config.SpellID)
        iconTexture = spellInfo and spellInfo.iconID
    end
    if iconTexture then
        frame.icon:SetTexture(iconTexture)
    end

    -- Create cooldown frame
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetDrawBling(false)
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.6)
    frame.cooldown:SetReverse(true)

    -- Configure cooldown text
    if config.ShowCooldownText then
        frame.cooldown:SetHideCountdownNumbers(false)
        local region = frame.cooldown:GetRegions()
        if region and region.SetFont then
            region:SetFont(STANDARD_TEXT_FONT, config.CountdownSize, "OUTLINE")
            region:SetShadowOffset(0, 0)
            region:SetShadowColor(0, 0, 0, 0)
        end
    else
        frame.cooldown:SetHideCountdownNumbers(true)
    end

    frame.config = config
    frame.trackerIndex = trackerIndex

    return frame
end

-- Get growth offset for positioning icons
function BI:GetGrowthOffset(direction, index, totalCount, iconSize, spacing)
    local offset = (index - 1) * (iconSize + spacing)
    if direction == "UP" then
        return 0, offset
    elseif direction == "DOWN" then
        return 0, -offset
    elseif direction == "LEFT" then
        return -offset, 0
    elseif direction == "RIGHT" then
        return offset, 0
    elseif direction == "CENTER" then
        local totalWidth = (totalCount * iconSize) + ((totalCount - 1) * spacing)
        local startOffset = -totalWidth / 2 + iconSize / 2
        return startOffset + offset, 0
    end
    return offset, 0
end

-- Layout visible icons based on growth direction
function BI:LayoutIcons()
    local db = self.db
    if not db then return end

    local direction = db.GrowthDirection or "RIGHT"
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
        local iconSize = frame.config.IconSize
        local xOff, yOff = self:GetGrowthOffset(direction, i, totalCount, iconSize, spacing)

        frame:ClearAllPoints()
        frame:SetPoint("CENTER", self.containerFrame, "CENTER", xOff, yOff)
    end
end

-- Show a specific tracker
function BI:ShowTracker(trackerIndex)
    local frame = self.trackerFrames[trackerIndex]
    if not frame then return end
    if not frame.config.Enabled then return end

    local config = frame.config

    -- Cancel any existing timer for this tracker (prevents duplicate timers)
    if self.activeTimers[trackerIndex] then
        self.activeTimers[trackerIndex]:Cancel()
        self.activeTimers[trackerIndex] = nil
    end

    -- Reset the cooldown animation fresh
    frame.cooldown:SetCooldown(GetTime(), config.Duration)
    frame:Show()

    self:LayoutIcons()

    -- Hide after duration (store handle so we can cancel if spell is recast)
    self.activeTimers[trackerIndex] = C_Timer.NewTimer(config.Duration, function()
        self.activeTimers[trackerIndex] = nil
        if frame then
            frame:Hide()
            self:LayoutIcons()
        end
    end)
end

-- Show a specific tracker for preview
function BI:ShowTrackerPreview(trackerIndex)
    local frame = self.trackerFrames[trackerIndex]
    if not frame then return end

    local config = frame.config

    -- Cancel any existing timer for this tracker (prevents duplicate timers)
    if self.activeTimers[trackerIndex] then
        self.activeTimers[trackerIndex]:Cancel()
        self.activeTimers[trackerIndex] = nil
    end

    -- Reset the cooldown animation fresh
    frame.cooldown:SetCooldown(GetTime(), config.Duration)
    frame:Show()

    self:LayoutIcons()

    -- Hide after duration (store handle so we can cancel if previewed again)
    self.activeTimers[trackerIndex] = C_Timer.NewTimer(config.Duration, function()
        self.activeTimers[trackerIndex] = nil
        if frame then
            frame:Hide()
            self:LayoutIcons()
        end
    end)
end

-- Handle spell cast events
function BI:OnSpellCast(event, unit, _, spellID)
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

-- Create all tracker frames from database
function BI:CreateAllTrackers()
    -- Cancel all active timers before recreating frames
    for trackerIndex, timer in pairs(self.activeTimers) do
        timer:Cancel()
    end
    self.activeTimers = {}

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
function BI:ApplyPosition()
    if not self.containerFrame then return end

    local db = self.db
    if not db then return end

    local anchorFrom = db.Position and db.Position.AnchorFrom or "CENTER"
    local anchorTo = db.Position and db.Position.AnchorTo or "CENTER"
    local xOffset = db.Position and db.Position.XOffset or 0.1
    local yOffset = db.Position and db.Position.YOffset or 150.1

    local parentFrame = UIParent
    if db.anchorFrameType == "SELECTFRAME" and db.anchorFrameFrame then
        parentFrame = _G[db.anchorFrameFrame] or UIParent
    end

    self.containerFrame:ClearAllPoints()
    self.containerFrame:SetPoint(anchorFrom, parentFrame, anchorTo, xOffset, yOffset)
end

-- Module OnEnable
function BI:OnEnable()
    if not self.db.Enabled then return end

    self:CreateAllTrackers()

    -- Register events
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellCast")
end

-- Module OnDisable
function BI:OnDisable()
    -- Cancel all active timers
    for trackerIndex, timer in pairs(self.activeTimers) do
        timer:Cancel()
    end
    self.activeTimers = {}

    for _, frame in pairs(self.trackerFrames) do
        frame:Hide()
    end
    -- Unregister events
    self:UnregisterAllEvents()
end

-- Public API for GUI
function BI:Refresh()
    self:CreateAllTrackers()
end

function BI:ApplySettings()
    self.db = NRSKNUI.db.profile.CustomBuffs and NRSKNUI.db.profile.CustomBuffs.Icons
    if self.db and self.db.Enabled then
        if not self:IsEnabled() then
            NRSKNUI.Addon:EnableModule("BuffIcons")
        else
            self:CreateAllTrackers()
        end
    else
        if self:IsEnabled() then
            NRSKNUI.Addon:DisableModule("BuffIcons")
        end
    end
end

function BI:PreviewAll()
    if not next(self.trackerFrames) then
        self:CreateAllTrackers()
    end

    for index, _ in pairs(self.trackerFrames) do
        self:ShowTrackerPreview(index)
    end
end

function BI:HideAll()
    -- Cancel all active timers
    for trackerIndex, timer in pairs(self.activeTimers) do
        timer:Cancel()
    end
    self.activeTimers = {}

    for _, frame in pairs(self.trackerFrames) do
        frame:Hide()
    end
end
