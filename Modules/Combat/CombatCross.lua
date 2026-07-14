---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class CombatCross: AceModule, AceEvent-3.0
local CC = NRSKNUI:NewModule("CombatCross", "AceEvent-3.0")

local select = select
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local C_Spell = C_Spell
local UnitExists = UnitExists

local FONT_SIZE_MULTIPLIER = 2
local RANGE_UPDATE_THROTTLE = 0.1

function CC:UpdateDB()
    self.db = NRSKNUI.db.profile.CombatCross
end

function CC:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function CC:ResolveRangeAbility()
    local specIndex = GetSpecialization()
    local specID = specIndex and select(1, GetSpecializationInfo(specIndex))

    if specID and NRSKNUI.MELEE_RANGE_ABILITIES[specID] then
        self.rangeAbility = NRSKNUI.MELEE_RANGE_ABILITIES[specID]
        self.specType = "melee"
    elseif specID and NRSKNUI.RANGED_RANGE_ABILITIES[specID] then
        self.rangeAbility = NRSKNUI.RANGED_RANGE_ABILITIES[specID]
        self.specType = "ranged"
    else
        self.rangeAbility = nil
        self.specType = nil
    end
end

function CC:UpdateRangeColor()
    if not self.text then return end

    if not UnitExists("target") then
        if self.lastInRange == false then self:ResetColor() end
        return
    end
    if not self.rangeAbility then return end
    local inRange = C_Spell.IsSpellInRange(self.rangeAbility, "target")
    if inRange == nil then
        if self.lastInRange ~= nil then self:ResetColor() end
        return
    end

    local nowInRange = (inRange == 1 or inRange == true)
    if nowInRange == self.lastInRange then return end
    self.lastInRange = nowInRange

    if nowInRange then
        local r, g, b, a = self:GetColor()
        self.text:SetTextColor(r, g, b, a)
    else
        local c = self.db.OutOfRangeColor
        self.text:SetTextColor(c[1], c[2], c[3], c[4])
    end
end

function CC:ShouldRunRangeUpdate()
    if not self.combatActive or not self.rangeAbility then return false end
    return (self.specType == "melee" and self.db.RangeColorMeleeEnabled)
        or (self.specType == "ranged" and self.db.RangeColorRangedEnabled)
end

function CC:UpdateOnUpdateState()
    if not self.frame then return end

    if self:ShouldRunRangeUpdate() then
        if not self.onUpdateActive then
            self.onUpdateActive = true
            self.rangeElapsed = 0
            self.frame:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)
        end
    elseif self.onUpdateActive then
        self.onUpdateActive = false
        self.frame:SetScript("OnUpdate", nil)
        self:ResetColor()
    end
end

function CC:OnUpdate(elapsed)
    self.rangeElapsed = self.rangeElapsed + elapsed
    if self.rangeElapsed < RANGE_UPDATE_THROTTLE then return end
    self.rangeElapsed = 0

    self:UpdateRangeColor()
end

function CC:OnEnable()
    self:CreateFrame()
    self:ApplySettings()
    self:ResolveRangeAbility()

    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnExitCombat")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
end

function CC:OnDisable()
    self:UnregisterAllEvents()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    self.rangeAbility = nil
    self.specType = nil
    self.lastInRange = nil
    self.onUpdateActive = false
end

function CC:OnSpecChanged()
    self:ResolveRangeAbility()
    self.lastInRange = nil
    self:UpdateOnUpdateState()
end

function CC:GetColor()
    return NRSKNUI:GetAccentColor(self.db.ColorMode, self.db.Color)
end

function CC:ResetColor()
    if not self.text then return end
    local r, g, b, a = self:GetColor()
    self.text:SetTextColor(r, g, b, a)
    self.lastInRange = nil
end

function CC:CreateFrame()
    if self.frame then return end

    self.frame = CreateFrame("Frame", "NRSKNUI_CombatCrossFrame", UIParent)
    self.frame:SetSize(30, 30)
    self.frame:SetPoint("CENTER")
    self.frame:SetFrameStrata("HIGH")
    self.frame:SetFrameLevel(100)
    self.frame:Hide()

    self.text = self.frame:CreateFontString(nil, "OVERLAY")
    self.text:SetPoint("CENTER")
    self.text:SetFontStyle("Expressway", self.db.Thickness * FONT_SIZE_MULTIPLIER, self.db.Outline and "OUTLINE" or "NONE")
    self.text:SetText("+")
end

function CC:ApplySettings()
    if not self.frame or not self.text then return end

    self.frame:ApplyPosition(self.db)
    self.text:SetFontStyle("Expressway", self.db.Thickness * FONT_SIZE_MULTIPLIER, self.db.Outline and "OUTLINE" or "NONE")

    self:ResetColor()
end

function CC:Show(isPreview)
    if not self.frame then
        self:CreateFrame()
        self:ApplySettings()
    end

    if isPreview then
        self.previewActive = true
    else
        self.combatActive = true
    end

    if not self.frame:IsShown() then
        self.frame:SetAlpha(1)
        self.frame:Show()
    end
end

function CC:Hide(isPreview)
    if not self.frame then return end

    if isPreview then
        self.previewActive = false
    else
        self.combatActive = false
        self:ResetColor()
    end

    if not self.previewActive and not self.combatActive then
        self.frame:Hide()
    end
end

function CC:ShowPreview()
    if InCombatLockdown() then return end
    self:Show(true)
end

function CC:HidePreview()
    if InCombatLockdown() then return end
    self:Hide(true)
end

function CC:OnEnterCombat()
    self:Show(false)
    self:UpdateOnUpdateState()
end

function CC:OnExitCombat()
    self:Hide(false)
    self:UpdateOnUpdateState()
end

function CC:Refresh()
    self:ApplySettings()
    self:UpdateOnUpdateState()
end
