-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("CombatCursor: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CC = NRSKNUI.Addon:NewModule("CursorCircle", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local C_Spell = C_Spell
local UIParent = UIParent

-- GCD spell ID (standard global cooldown reference)
local GCD_SPELL_ID = 61304

-- Define available textures
CC.Textures = {
    ["Circle 1"] = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Circle.tga",
    ["Circle 2"] = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Aura73.tga",
    ["Circle 3"] = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Aura103.tga",
    ["Circle 4"] = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraThin.png",
    ["Circle 5"] = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraMedium.png",
    ["Circle 6"] = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraThick.png",
}

-- Texture display order for GUI
CC.TextureOrder = { "Circle 1", "Circle 2", "Circle 3", "Circle 4", "Circle 5", "Circle 6" }

-- GCD Ring textures (same as main circle textures)
CC.GCDRingTextures = CC.Textures
CC.GCDRingTextureOrder = CC.TextureOrder

-- GCD Mode options for GUI
CC.GCDModeOptions = {
    ["disabled"] = "Disabled",
    ["integrated"] = "Integrated (overlay on circle)",
    ["separate"] = "Separate (own ring)",
}

-- Module state
CC.frame = nil
CC.gcdFrame = nil

-- Module init
function CC:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.CursorCircle
    self:SetEnabledState(false)
end

-- Read GCD cooldown info (spell 61304 is always safe to query)
local function GetGCDCooldown()
    local info = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
    if info then
        return info.startTime, info.duration, info.modRate
    end
    return nil, nil, nil
end

-- Create the cursor circle frame
function CC:CreateFrame()
    if self.frame then return end

    local db = self.db
    local mainTexPath = CC.Textures[db.Texture] or CC.Textures["Circle 3"]

    local f = CreateFrame("Frame", "NRSKNUI_CursorCircleFrame", UIParent)
    f:SetSize(db.Size or 50, db.Size or 50)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(9999)
    f:EnableMouse(false)

    f.texture = f:CreateTexture(nil, "BACKGROUND")
    f.texture:SetAllPoints()
    f.texture:SetTexture(mainTexPath)
    f:Hide()

    -- Create integrated GCD cooldown overlay (on main circle)
    local gcdIntegrated = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    gcdIntegrated:SetAllPoints()
    gcdIntegrated:EnableMouse(false)
    gcdIntegrated:SetDrawSwipe(true)
    gcdIntegrated:SetDrawEdge(false)
    gcdIntegrated:SetHideCountdownNumbers(true)
    if gcdIntegrated.SetDrawBling then gcdIntegrated:SetDrawBling(false) end
    if gcdIntegrated.SetUseCircularEdge then gcdIntegrated:SetUseCircularEdge(true) end

    if gcdIntegrated.SetSwipeTexture then
        gcdIntegrated:SetSwipeTexture(mainTexPath)
    end
    gcdIntegrated:SetFrameLevel(f:GetFrameLevel() + 2)
    gcdIntegrated:Hide()
    f.gcdCooldown = gcdIntegrated

    -- OnUpdate for cursor following
    local updateElapsed = 0
    f:SetScript("OnUpdate", function(frame, elapsed)
        local useThrottle = db.UseUpdateInterval
        if useThrottle then
            local updateInterval = db.UpdateInterval or 0.016
            updateElapsed = updateElapsed + elapsed
            if updateElapsed < updateInterval then return end
            updateElapsed = 0
        end

        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)

    self.frame = f
    self:ApplyColor()
    self:CreateGCDRing()
end

-- Create the separate GCD ring frame
function CC:CreateGCDRing()
    if self.gcdFrame then return end

    local db = self.db
    local gcdSettings = db.GCD or {}
    local texPath = CC.GCDRingTextures[gcdSettings.Texture] or CC.GCDRingTextures["Circle 5"]

    local gf = CreateFrame("Frame", "NRSKNUI_GCDRingFrame", UIParent)
    gf:SetSize(gcdSettings.Size or 25, gcdSettings.Size or 25)
    gf:SetFrameStrata("FULLSCREEN_DIALOG")
    gf:SetFrameLevel(9998)
    gf:EnableMouse(false)

    gf.texture = gf:CreateTexture(nil, "BACKGROUND")
    gf.texture:SetAllPoints()
    gf.texture:SetTexture(texPath)

    local gcdCooldown = CreateFrame("Cooldown", nil, gf, "CooldownFrameTemplate")
    gcdCooldown:SetAllPoints()
    gcdCooldown:EnableMouse(false)
    gcdCooldown:SetDrawSwipe(true)
    gcdCooldown:SetDrawEdge(false)
    gcdCooldown:SetHideCountdownNumbers(true)
    if gcdCooldown.SetDrawBling then gcdCooldown:SetDrawBling(false) end
    if gcdCooldown.SetUseCircularEdge then gcdCooldown:SetUseCircularEdge(true) end
    if gcdCooldown.SetSwipeTexture then
        gcdCooldown:SetSwipeTexture(texPath)
    end
    gcdCooldown:SetFrameLevel(gf:GetFrameLevel() + 2)
    gf.gcdCooldown = gcdCooldown
    gf:Hide()

    -- OnUpdate for cursor following
    local updateElapsed = 0
    gf:SetScript("OnUpdate", function(frame, elapsed)
        local useThrottle = db.UseUpdateInterval
        if useThrottle then
            local updateInterval = db.UpdateInterval or 0.016
            updateElapsed = updateElapsed + elapsed
            if updateElapsed < updateInterval then return end
            updateElapsed = 0
        end

        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)

    self.gcdFrame = gf
    self:ApplyGCDColor()
end

-- Apply color to the cursor circle
function CC:ApplyColor()
    if not self.frame or not self.frame.texture then return end

    local db = self.db
    local r, g, b, a = NRSKNUI:GetAccentColor(db.ColorMode, db.Color)
    self.frame.texture:SetVertexColor(r, g, b, a)
end

-- Apply color to GCD ring
function CC:ApplyGCDColor()
    local db = self.db
    local gcd = db.GCD or {}

    local ringR, ringG, ringB, ringA = NRSKNUI:GetAccentColor(gcd.RingColorMode or "theme", gcd.RingColor)
    local swipeR, swipeG, swipeB, swipeA = NRSKNUI:GetAccentColor(gcd.SwipeColorMode or "custom", gcd.SwipeColor)

    -- Apply to separate GCD frame
    if self.gcdFrame then
        if self.gcdFrame.texture then
            self.gcdFrame.texture:SetVertexColor(ringR, ringG, ringB, ringA)
        end
        if self.gcdFrame.gcdCooldown then
            self.gcdFrame.gcdCooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeA)
            if self.gcdFrame.gcdCooldown.SetSwipeTexture then
                local texPath = CC.GCDRingTextures[gcd.Texture] or CC.GCDRingTextures["Circle 5"]
                self.gcdFrame.gcdCooldown:SetSwipeTexture(texPath)
            end
            if self.gcdFrame.gcdCooldown.SetReverse then
                self.gcdFrame.gcdCooldown:SetReverse(gcd.Reverse or false)
            end
        end
    end

    -- Apply to integrated GCD cooldown
    if self.frame and self.frame.gcdCooldown then
        self.frame.gcdCooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeA)
        if self.frame.gcdCooldown.SetSwipeTexture then
            local texPath = CC.Textures[db.Texture] or CC.Textures["Circle 3"]
            self.frame.gcdCooldown:SetSwipeTexture(texPath)
        end
        if self.frame.gcdCooldown.SetReverse then
            self.frame.gcdCooldown:SetReverse(gcd.Reverse or false)
        end
    end
end

-- Apply all settings
function CC:ApplySettings()
    local db = self.db

    if not self.frame then
        self:CreateFrame()
    end
    if not self.frame then return end

    -- Update main circle
    self.frame:SetSize(db.Size or 50, db.Size or 50)
    local texPath = CC.Textures[db.Texture] or CC.Textures["Circle 3"]
    self.frame.texture:SetTexture(texPath)
    if self.frame.gcdCooldown and self.frame.gcdCooldown.SetSwipeTexture then
        self.frame.gcdCooldown:SetSwipeTexture(texPath)
    end

    self:ApplyColor()

    -- Update GCD ring
    local gcd = db.GCD or {}
    if not self.gcdFrame then
        self:CreateGCDRing()
    end
    if self.gcdFrame then
        self.gcdFrame:SetSize(gcd.Size or 25, gcd.Size or 25)
        local gcdTexPath = CC.GCDRingTextures[gcd.Texture] or CC.GCDRingTextures["Circle 5"]
        if self.gcdFrame.texture then
            self.gcdFrame.texture:SetTexture(gcdTexPath)
        end
    end

    self:ApplyGCDColor()
    self:UpdateGCDVisibility()

    if db.Enabled then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

-- Update GCD visibility based on mode and combat state
function CC:UpdateGCDVisibility()
    local db = self.db
    local gcd = db.GCD or {}
    local mode = gcd.Mode or "integrated"

    local shouldShow = db.Enabled
    if gcd.HideOutOfCombat and not InCombatLockdown() then
        shouldShow = false
    end

    if self.gcdFrame then
        if mode == "separate" and shouldShow then
            self.gcdFrame:Show()
        else
            self.gcdFrame:Hide()
        end
    end
end

-- Update GCD cooldown display
function CC:UpdateGCDCooldown()
    local db = self.db
    local gcd = db.GCD or {}
    local mode = gcd.Mode or "integrated"

    if mode == "disabled" then
        if self.frame and self.frame.gcdCooldown then
            self.frame.gcdCooldown:Hide()
        end
        if self.gcdFrame and self.gcdFrame.gcdCooldown then
            self.gcdFrame.gcdCooldown:Hide()
        end
        return
    end

    if gcd.HideOutOfCombat and not InCombatLockdown() then
        if self.frame and self.frame.gcdCooldown then
            self.frame.gcdCooldown:Hide()
        end
        if self.gcdFrame then
            self.gcdFrame:Hide()
        end
        return
    end

    local start, duration, modRate = GetGCDCooldown()

    if start and duration and duration > 0 then
        if mode == "integrated" and self.frame and self.frame.gcdCooldown then
            self.frame.gcdCooldown:Show()
            if modRate then
                self.frame.gcdCooldown:SetCooldown(start, duration, modRate)
            else
                self.frame.gcdCooldown:SetCooldown(start, duration)
            end
        elseif mode == "separate" and self.gcdFrame and self.gcdFrame.gcdCooldown then
            if db.Enabled then
                self.gcdFrame:Show()
            end
            self.gcdFrame.gcdCooldown:Show()
            if modRate then
                self.gcdFrame.gcdCooldown:SetCooldown(start, duration, modRate)
            else
                self.gcdFrame.gcdCooldown:SetCooldown(start, duration)
            end
        end
    else
        if self.frame and self.frame.gcdCooldown then
            self.frame.gcdCooldown:Hide()
        end
        if self.gcdFrame and self.gcdFrame.gcdCooldown then
            self.gcdFrame.gcdCooldown:Hide()
        end
    end
end

-- Combat handlers
function CC:OnCombatStart()
    self:UpdateGCDVisibility()
    self:UpdateGCDCooldown()
end

function CC:OnCombatEnd()
    self:UpdateGCDVisibility()
end

-- Module OnEnable
function CC:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()
    self:ApplySettings()

    -- Register events
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateGCDCooldown")
    self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", "UpdateGCDCooldown")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    if self.db.Enabled then
        self.frame:Show()
    end
end

-- Handle spell cast for immediate GCD update
function CC:UNIT_SPELLCAST_SUCCEEDED(_, unit)
    if unit ~= "player" then return end

    local gcd = self.db.GCD or {}
    if gcd.Mode == "disabled" then return end

    self:UpdateGCDCooldown()
end

-- Module OnDisable
function CC:OnDisable()
    if self.frame then
        self.frame:Hide()
    end
    if self.gcdFrame then
        self.gcdFrame:Hide()
    end
    self:UnregisterAllEvents()
end
