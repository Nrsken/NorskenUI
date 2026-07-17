---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class CursorCircle: AceModule, AceEvent-3.0
local CC = NRSKNUI:NewModule("CursorCircle", "AceEvent-3.0")

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local ipairs = ipairs
local C_Spell = C_Spell
local UIParent = UIParent

CC.Textures = {
    { key = "Circle 1", path = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Circle.tga" },
    { key = "Circle 2", path = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Aura73.tga" },
    { key = "Circle 3", path = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\Aura103.tga" },
    { key = "Circle 4", path = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraThin.png" },
    { key = "Circle 5", path = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraMedium.png" },
    { key = "Circle 6", path = "Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraThick.png" },
}

CC.GCDModeOptions = {
    { key = "disabled", text = "Disabled" },
    { key = "integrated", text = "Integrated" },
    { key = "separate", text = "Separate Ring" },
}

CC.VisibilityModeOptions = {
    { key = "always", text = "Always Visible" },
    { key = "mouseDown", text = "Mouse Button Held" },
}

function CC:GetTexturePath(textureKey)
    for _, tex in ipairs(self.Textures) do
        if tex.key == textureKey then return tex.path end
    end
    return self.Textures[1].path
end

function CC:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.CursorCircle
end

function CC:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function GetGCDCooldown()
    local info = C_Spell.GetSpellCooldown(61304)
    if info then
        return info.startTime, info.duration, info.modRate
    end
    return nil, nil, nil
end

function CC:CreateFrame()
    if self.frame then return end

    local db = self.db
    local mainTexPath = self:GetTexturePath(db.Texture)

    local f = CreateFrame("Frame", "NRSKNUI_CursorCircleFrame", UIParent)
    f:SetSize(db.Size, db.Size)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(9999)
    f:EnableMouse(false)

    f.texture = f:CreateTexture(nil, "BACKGROUND")
    f.texture:SetAllPoints()
    f.texture:SetTexture(mainTexPath)
    f:Hide()

    local gcdIntegrated = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    gcdIntegrated:SetAllPoints()
    gcdIntegrated:EnableMouse(false)
    gcdIntegrated:SetDrawSwipe(true)
    gcdIntegrated:SetDrawEdge(false)
    gcdIntegrated:SetHideCountdownNumbers(true)
    if gcdIntegrated.SetDrawBling then gcdIntegrated:SetDrawBling(false) end
    if gcdIntegrated.SetUseCircularEdge then gcdIntegrated:SetUseCircularEdge(true) end
    if gcdIntegrated.SetSwipeTexture then gcdIntegrated:SetSwipeTexture(mainTexPath) end
    gcdIntegrated:SetFrameLevel(f:GetFrameLevel() + 2)
    gcdIntegrated:Hide()
    f.gcdCooldown = gcdIntegrated

    local updateElapsed = 0
    local mouseHoldTime = 0
    f:SetScript("OnUpdate", function(frame, elapsed)
        if db.UseUpdateInterval then
            updateElapsed = updateElapsed + elapsed
            if updateElapsed < db.UpdateInterval then return end
            updateElapsed = 0
        end

        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

        if db.VisibilityMode == "mouseDown" then
            local isMouseDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
            local r, g, b, a = NRSKNUI:GetAccentColor(db.ColorMode, db.Color)

            if isMouseDown then
                mouseHoldTime = mouseHoldTime + elapsed
                if mouseHoldTime >= 0.15 then
                    frame.texture:SetVertexColor(r, g, b, a)
                end
            else
                mouseHoldTime = 0
                frame.texture:SetVertexColor(r, g, b, 0)
            end
        end
    end)

    self.frame = f
    self:ApplyColor()
    self:CreateGCDRing()
end

function CC:CreateGCDRing()
    if self.gcdFrame then return end

    local db = self.db
    local gcdSettings = db.GCD
    local texPath = self:GetTexturePath(gcdSettings.Texture)

    local gf = CreateFrame("Frame", "NRSKNUI_GCDRingFrame", UIParent)
    gf:SetSize(gcdSettings.Size, gcdSettings.Size)
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
    if gcdCooldown.SetSwipeTexture then gcdCooldown:SetSwipeTexture(texPath) end
    gcdCooldown:SetFrameLevel(gf:GetFrameLevel() + 2)
    gf.gcdCooldown = gcdCooldown
    gf:Hide()

    local updateElapsed = 0
    local mouseHoldTime = 0
    gf:SetScript("OnUpdate", function(frame, elapsed)
        if db.UseUpdateInterval then
            updateElapsed = updateElapsed + elapsed
            if updateElapsed < db.UpdateInterval then return end
            updateElapsed = 0
        end

        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

        if db.VisibilityMode == "mouseDown" then
            local isMouseDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
            local gcd = db.GCD
            local r, g, b, a = NRSKNUI:GetAccentColor(gcd.RingColorMode, gcd.RingColor)

            if isMouseDown then
                mouseHoldTime = mouseHoldTime + elapsed
                if mouseHoldTime >= 0.15 then
                    frame.texture:SetVertexColor(r, g, b, a)
                end
            else
                mouseHoldTime = 0
                frame.texture:SetVertexColor(r, g, b, 0)
            end
        end
    end)

    self.gcdFrame = gf
    self:ApplyGCDColor()
end

function CC:ApplyColor()
    if not self.frame or not self.frame.texture then return end
    local db = self.db
    local r, g, b, a = NRSKNUI:GetAccentColor(db.ColorMode, db.Color)

    if db.VisibilityMode == "mouseDown" then
        self.frame.texture:SetVertexColor(r, g, b, 0)
    else
        self.frame.texture:SetVertexColor(r, g, b, a)
    end
end

function CC:ApplyGCDColor()
    local db = self.db
    local gcd = db.GCD

    local ringR, ringG, ringB, ringA = NRSKNUI:GetAccentColor(gcd.RingColorMode, gcd.RingColor)
    local swipeR, swipeG, swipeB, swipeA = NRSKNUI:GetAccentColor(gcd.SwipeColorMode, gcd.SwipeColor)

    if self.gcdFrame then
        if self.gcdFrame.texture then
            if db.VisibilityMode == "mouseDown" then
                self.gcdFrame.texture:SetVertexColor(ringR, ringG, ringB, 0)
            else
                self.gcdFrame.texture:SetVertexColor(ringR, ringG, ringB, ringA)
            end
        end
        if self.gcdFrame.gcdCooldown then
            self.gcdFrame.gcdCooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeA)
            if self.gcdFrame.gcdCooldown.SetSwipeTexture then
                self.gcdFrame.gcdCooldown:SetSwipeTexture(self:GetTexturePath(gcd.Texture))
            end
            if self.gcdFrame.gcdCooldown.SetReverse then
                self.gcdFrame.gcdCooldown:SetReverse(gcd.Reverse)
            end
        end
    end

    if self.frame and self.frame.gcdCooldown then
        self.frame.gcdCooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeA)
        if self.frame.gcdCooldown.SetSwipeTexture then
            self.frame.gcdCooldown:SetSwipeTexture(self:GetTexturePath(db.Texture))
        end
        if self.frame.gcdCooldown.SetReverse then
            self.frame.gcdCooldown:SetReverse(gcd.Reverse)
        end
    end
end

function CC:ApplySettings()
    local db = self.db
    if not self.frame then self:CreateFrame() end
    if not self.frame then return end

    self.frame:SetSize(db.Size, db.Size)
    local texPath = self:GetTexturePath(db.Texture)
    self.frame.texture:SetTexture(texPath)
    if self.frame.gcdCooldown and self.frame.gcdCooldown.SetSwipeTexture then
        self.frame.gcdCooldown:SetSwipeTexture(texPath)
    end

    self:ApplyColor()

    local gcd = db.GCD
    if not self.gcdFrame then self:CreateGCDRing() end
    if self.gcdFrame then
        self.gcdFrame:SetSize(gcd.Size, gcd.Size)
        if self.gcdFrame.texture then
            self.gcdFrame.texture:SetTexture(self:GetTexturePath(gcd.Texture))
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

function CC:UpdateGCDVisibility()
    local db = self.db
    local gcd = db.GCD

    local shouldShow = db.Enabled
    if gcd.HideOutOfCombat and not NRSKNUI:InCombat() then
        shouldShow = false
    end

    if self.gcdFrame then
        if gcd.Mode == "separate" and shouldShow then
            self.gcdFrame:Show()
        else
            self.gcdFrame:Hide()
        end
    end
end

function CC:UpdateGCDCooldown()
    local db = self.db
    local gcd = db.GCD

    if gcd.Mode == "disabled" then
        if self.frame and self.frame.gcdCooldown then self.frame.gcdCooldown:Hide() end
        if self.gcdFrame and self.gcdFrame.gcdCooldown then self.gcdFrame.gcdCooldown:Hide() end
        return
    end

    if gcd.HideOutOfCombat and not NRSKNUI:InCombat() then
        if self.frame and self.frame.gcdCooldown then self.frame.gcdCooldown:Hide() end
        if self.gcdFrame then self.gcdFrame:Hide() end
        return
    end

    local start, duration, modRate = GetGCDCooldown()

    if start and duration and duration > 0 then
        if gcd.Mode == "integrated" and self.frame and self.frame.gcdCooldown then
            self.frame.gcdCooldown:Show()
            if modRate then
                self.frame.gcdCooldown:SetCooldown(start, duration, modRate)
            else
                self.frame.gcdCooldown:SetCooldown(start, duration)
            end
        elseif gcd.Mode == "separate" and self.gcdFrame and self.gcdFrame.gcdCooldown then
            if db.Enabled then self.gcdFrame:Show() end
            self.gcdFrame.gcdCooldown:Show()
            if modRate then
                self.gcdFrame.gcdCooldown:SetCooldown(start, duration, modRate)
            else
                self.gcdFrame.gcdCooldown:SetCooldown(start, duration)
            end
        end
    else
        if self.frame and self.frame.gcdCooldown then self.frame.gcdCooldown:Hide() end
        if self.gcdFrame and self.gcdFrame.gcdCooldown then self.gcdFrame.gcdCooldown:Hide() end
    end
end

function CC:OnCombatStart()
    self:UpdateGCDVisibility()
    self:UpdateGCDCooldown()
end

function CC:OnCombatEnd()
    self:UpdateGCDVisibility()
end

function CC:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()
    self:ApplySettings()

    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateGCDCooldown")
    self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", "UpdateGCDCooldown")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    if self.db.Enabled then self.frame:Show() end
end

function CC:UNIT_SPELLCAST_SUCCEEDED(_, unit)
    if unit ~= "player" then return end
    if self.db.GCD.Mode == "disabled" then return end
    self:UpdateGCDCooldown()
end

function CC:OnDisable()
    if self.frame then self.frame:Hide() end
    if self.gcdFrame then self.gcdFrame:Hide() end
    self:UnregisterAllEvents()
end

function CC:ShowPreview()
    self.isPreview = true
    if not self.frame then self:CreateFrame() end
    if self.frame then self.frame:Show() end
    self:UpdateGCDVisibility()
end

function CC:HidePreview()
    self.isPreview = false
    if not self.db.Enabled and self.frame then
        self.frame:Hide()
    end
end
