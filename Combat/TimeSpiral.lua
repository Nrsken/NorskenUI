-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Safety check
if not NorskenUI then
    error("TimeSpiral: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class TimeSpiral: AceModule, AceEvent-3.0
local TSP = NorskenUI:NewModule("TimeSpiral", "AceEvent-3.0")

-- Libraries
local LCG = LibStub("LibCustomGlow-1.0", true)

-- Localization
local CreateFrame = CreateFrame
local GetSpellTexture = C_Spell.GetSpellTexture
local IsPlayerSpell = IsPlayerSpell
local GetTime = GetTime
local pairs = pairs
local next = next
local UnitClass = UnitClass

-- Module state
TSP.activeProcs = {}

-- Default Time Spiral icon texture
local TIME_SPIRAL_ICON = 4622479
local TIME_SPIRAL_DURATION = 10.5

-- Table that holds movement spells that can proc from Time Spiral
local MOVEMENT_SPELLS = {
    [48265]  = "DEATHKNIGHT", -- Death's Advance
    [195072] = "DEMONHUNTER", -- Fel Rush
    [189110] = "DEMONHUNTER", -- Infernal Strike
    [1850]   = "DRUID",       -- Dash
    [252216] = "DRUID",       -- Tiger Dash
    [358267] = "EVOKER",      -- Hover
    [186257] = "HUNTER",      -- Aspect of the Cheetah
    [1953]   = "MAGE",        -- Blink
    [212653] = "MAGE",        -- Shimmer
    [109132] = "MONK",        -- Roll
    [119085] = "MONK",        -- Chi Torpedo
    [190784] = "PALADIN",     -- Divine Steed
    [73325]  = "PRIEST",      -- Leap of Faith
    [2983]   = "ROGUE",       -- Sprint
    [192063] = "SHAMAN",      -- Gust of Wind
    [58875]  = "SHAMAN",      -- Spirit Walk
    [79206]  = "SHAMAN",      -- Spiritwalker's Grace
    [48020]  = "WARLOCK",     -- Demonic Circle: Teleport
    [6544]   = "WARRIOR",     -- Heroic Leap
}

-- Filter some spells that can cause false procs
local FILTER_TALENTS = {
    [427640] = { [195072] = true }, -- Inertia
    [427794] = { [195072] = true }, -- Dash of Chaos
    [385899] = { [385899] = true }, -- Soulburn
}

-- Update db, used for profile changes
function TSP:UpdateDB()
    self.db = NRSKNUI.db.profile.TimeSpiral
end

-- Detect the player's movement spell
function TSP:DetectPlayerSpell()
    local _, playerClass = UnitClass("player")
    for spellId, class in pairs(MOVEMENT_SPELLS) do
        if class == playerClass and IsPlayerSpell(spellId) then
            self.playerSpellId = spellId
            return spellId
        end
    end
    return nil
end

-- Get the icon texture for the display
function TSP:GetDisplayIcon()
    if self.playerSpellId then
        local texture = GetSpellTexture(self.playerSpellId)
        if texture then
            return texture
        end
    end

    -- Try to detect the spell if we haven't yet
    local spellId = self:DetectPlayerSpell()
    if spellId then
        local texture = GetSpellTexture(spellId)
        if texture then
            return texture
        end
    end

    -- Fallback to Time Spiral icon
    return TIME_SPIRAL_ICON
end

-- Module init
function TSP:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Create the display frame
function TSP:CreateFrame()
    if self.frame then return end

    -- icon with borders and text
    local iconFrame = NRSKNUI:CreateIconFrame(UIParent, self.db.IconSize, {
        name = "NRSKNUI_TimeSpiralFrame",
        zoom = 0.3,
        borderColor = { 0, 0, 0, 1 },
    })
    iconFrame:EnableMouse(false)
    iconFrame:SetMouseClickEnabled(false)
    iconFrame:Hide()

    -- Set icon texture
    iconFrame.icon:SetTexture(self:GetDisplayIcon())

    -- Set text pos
    iconFrame.text:ClearAllPoints()
    iconFrame.text:SetPoint("TOP", iconFrame, "BOTTOM", 0, -2)
    iconFrame.text:SetJustifyH("CENTER")

    -- Add cooldown spiral overlay
    local cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(iconFrame)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetReverse(true)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetDrawBling(false)

    -- Store references
    self.frame = iconFrame
    self.iconFrame = iconFrame
    self.icon = iconFrame.icon
    self.text = iconFrame.text
    self.cooldown = cooldown

    self:ApplySettings()
end

-- Check if a spell should be filtered out to avoid false procs
function TSP:FilterSpell(spellId)
    for talentId, spells in pairs(FILTER_TALENTS) do
        if spells[spellId] and IsPlayerSpell(talentId) then
            return true
        end
    end
    return false
end

-- Apply settings, called from GUI or profile switching
function TSP:ApplySettings()
    if not self.frame then return end
    local showText = self.db.ShowText ~= false

    -- Update frame and icon size
    self.frame:SetSize(self.db.IconSize, self.db.IconSize)
    self.iconFrame:SetSize(self.db.IconSize, self.db.IconSize)

    -- Update icon texture
    self.icon:SetTexture(self:GetDisplayIcon())

    -- Update text
    self.text:SetText(self.db.TextLabel or "FREE MOVE")
    NRSKNUI:ApplyFontToText(self.text, self.db.FontFace, self.db.FontSize, self.db.FontOutline, {})

    -- Apply text color
    local textColor = self.db.TextColor or { 1, 1, 1, 1 }
    self.text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)

    if showText then
        self.text:Show()
        if self.text.softOutline then
            local usingSoftOutline = (self.db.FontOutline == "SOFTOUTLINE")
            self.text.softOutline:SetShown(usingSoftOutline)
        end
    else
        self.text:Hide()
        if self.text.softOutline then
            self.text.softOutline:SetShown(false)
        end
    end

    -- Apply position
    self:ApplyPosition()

    -- Handle glow state
    if self.glowActive then
        self:StopGlow()
        self:StartGlow()
    elseif self.db.GlowEnabled and self.frame:IsShown() then
        self:StartGlow()
    end
end

-- Apply position
function TSP:ApplyPosition()
    if not self.db.Enabled then return end
    if not self.frame then return end
    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db)
end

-- Setup and start the glow effect
function TSP:StartGlow()
    if not self.frame or not self.iconFrame then return end
    if not self.db.GlowEnabled then return end
    if not LCG then return end

    local color = self.db.GlowColor or { 0.95, 0.95, 0.32, 1 }
    local glowType = self.db.GlowType or "proc"

    if glowType == "pixel" then
        LCG.PixelGlow_Start(self.iconFrame, color, 8, 0.25, 8, 2, 1, 1, false, nil)
    elseif glowType == "autocast" then
        LCG.AutoCastGlow_Start(self.iconFrame, color, 8, 0.25, 1, 1, 1, nil)
    elseif glowType == "button" then
        LCG.ButtonGlow_Start(self.iconFrame, color, 0)
    elseif glowType == "proc" then
        LCG.ProcGlow_Start(self.iconFrame, {
            color = color,
            startAnim = false,
            duration = 1,
        })
    end

    self.glowActive = true
end

-- Stop the glow effect
function TSP:StopGlow()
    if not self.frame or not self.iconFrame then return end
    if not LCG then return end

    -- Stop all glow types to be safe, prob redundant but w/e
    LCG.PixelGlow_Stop(self.iconFrame)
    LCG.AutoCastGlow_Stop(self.iconFrame)
    LCG.ButtonGlow_Stop(self.iconFrame)
    LCG.ProcGlow_Stop(self.iconFrame)

    self.glowActive = false
end

-- Show the proc indicator
function TSP:ShowProc()
    if not self.frame then self:CreateFrame() end
    if not self.frame then return end
    self.procStartTime = GetTime()

    -- Set up cooldown spiral
    self.cooldown:SetCooldown(self.procStartTime, TIME_SPIRAL_DURATION)

    -- Start glow
    self:StartGlow()

    -- Show frame
    self.frame:Show()

    -- Set up timer to hide when proc expires
    if self.hideTimer then self.hideTimer:Cancel() end
    self.hideTimer = C_Timer.NewTimer(TIME_SPIRAL_DURATION, function() self:HideProc() end)
end

-- Hide the proc indicator
function TSP:HideProc()
    if not self.frame then return end

    self:StopGlow()
    self.frame:Hide()
    self.procStartTime = nil

    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
end

-- Preview stuff
function TSP:ShowPreview()
    if not self.frame then self:CreateFrame() end
    self.isPreview = true
    self:ApplySettings()

    -- Show with fake cooldown
    self.cooldown:SetCooldown(GetTime(), TIME_SPIRAL_DURATION)
    self:StartGlow()
    self.frame:Show()
end

function TSP:HidePreview()
    self.isPreview = false
    self:StopGlow()
    if self.frame then
        self.frame:Hide()
    end
end

-- Module OnEnable
function TSP:OnEnable()
    if not self.db.Enabled then return end
    self:DetectPlayerSpell()
    self:CreateFrame()
    C_Timer.After(0.5, function() self:ApplyPosition() end)

    -- Register events and their funcs
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, spellId)
        if not spellId then return end
        if not MOVEMENT_SPELLS[spellId] then return end
        if self:FilterSpell(spellId) then return end

        self.playerSpellId = spellId
        if self.icon then
            self.icon:SetTexture(self:GetDisplayIcon())
        end

        self.activeProcs[spellId] = true
        self:ShowProc()
    end)

    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, spellId)
        if not spellId then return end
        if not MOVEMENT_SPELLS[spellId] then return end
        self.activeProcs[spellId] = nil
        if not next(self.activeProcs) then
            self:HideProc()
        end
    end)

    -- Register with EditMode
    NRSKNUI.EditMode:RegisterElement({
        key = "TimeSpiral",
        displayName = "Time Spiral",
        frame = self.frame,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            self:ApplyPosition()
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
        end,
        guiPath = "TimeSpiral",
    })
end

-- Module OnDisable
function TSP:OnDisable()
    if self.frame then
        self:StopGlow()
        self.frame:Hide()
    end
    self.isPreview = false
    self.activeProcs = {}
    self.glowActive = false
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self:UnregisterAllEvents()
end
