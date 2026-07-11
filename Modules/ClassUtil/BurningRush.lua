---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class BurningRush: AceModule, AceEvent-3.0
local BURN = NRSKNUI:NewModule("BurningRush", "AceEvent-3.0")

local LCG = NRSKNUI.Libs.LCG

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local select = select
local IsSpellKnown = IsSpellKnown
local UIParent = UIParent

local SPELL_ID = 111400
local ICON_TEXTURE = 538043

local isPreviewActive = false
local iconFrame = nil
local eventFrame = nil

BURN.BurningRushActive = false

function BURN:UpdateDB()
    self.db = NRSKNUI.db.profile.BurningRush
end

function BURN:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function BURN:SetActive(active)
    if isPreviewActive then return end
    self.BurningRushActive = active
    if active then
        self:ShowDisplay()
    else
        self:HideDisplay()
    end
end

function BURN:CreateFrame()
    if iconFrame then return end

    iconFrame = NRSKNUI:CreateIconFrame(UIParent, self.db.IconSize, {
        name = "NRSKNUI_BurningRushIcon",
        zoom = NRSKNUI.GlobalZoom,
        borderColor = { 0, 0, 0, 1 },
    })
    iconFrame:EnableMouse(false)
    iconFrame:SetMouseClickEnabled(false)
    iconFrame:Hide()

    iconFrame.icon:SetTexture(ICON_TEXTURE)

    self.frame = iconFrame
    self.iconFrame = iconFrame

    self:ApplySettings()
end

function BURN:ApplySettings()
    if not iconFrame then return end

    iconFrame:SetSize(self.db.IconSize, self.db.IconSize)
    iconFrame.icon:SetAllPoints(iconFrame)

    self:ApplyPosition()

    if self.glowActive then
        self:StopGlow()
        self:StartGlow()
    elseif self.db.GlowEnabled and iconFrame:IsShown() then
        self:StartGlow()
    end
end

function BURN:ApplyPosition()
    if not self.db.Enabled then return end
    if not iconFrame then return end
    NRSKNUI:ApplyFramePosition(iconFrame, self.db.Position, self.db)
end

function BURN:StartGlow()
    if not iconFrame then return end
    if not self.db.GlowEnabled then return end
    if not LCG then return end

    if self.db.GlowType == "pixel" then
        LCG.PixelGlow_Start(iconFrame, self.db.GlowColor,
            self.db.GlowLines,
            self.db.GlowFrequency,
            self.db.GlowLength,
            self.db.GlowThickness,
            self.db.GlowXOffset, self.db.GlowYOffset,
            self.db.GlowBorder,
            nil)
    elseif self.db.GlowType == "autocast" then
        LCG.AutoCastGlow_Start(iconFrame, self.db.GlowColor,
            self.db.GlowLines,
            self.db.GlowFrequency,
            self.db.GlowScale,
            self.db.GlowXOffset, self.db.GlowYOffset,
            nil)
    elseif self.db.GlowType == "button" then
        LCG.ButtonGlow_Start(iconFrame, self.db.GlowColor,
            self.db.GlowFrequency)
    elseif self.db.GlowType == "proc" then
        LCG.ProcGlow_Start(iconFrame, {
            color = self.db.GlowColor,
            startAnim = self.db.GlowStartAnim,
            duration = self.db.GlowDuration,
            xOffset = self.db.GlowXOffset,
            yOffset = self.db.GlowYOffset,
        })
    end

    self.glowActive = true
end

function BURN:StopGlow()
    if not iconFrame then return end
    if not LCG then return end

    LCG.PixelGlow_Stop(iconFrame)
    LCG.AutoCastGlow_Stop(iconFrame)
    LCG.ButtonGlow_Stop(iconFrame)
    LCG.ProcGlow_Stop(iconFrame)

    self.glowActive = false
end

function BURN:ShowDisplay()
    if not iconFrame then self:CreateFrame() end
    if not iconFrame then return end

    self:StartGlow()
    iconFrame:Show()
end

function BURN:HideDisplay()
    if not iconFrame then return end

    self:StopGlow()
    iconFrame:Hide()
end

function BURN:OnSpellCast(spellID)
    if isPreviewActive then return end
    if spellID ~= SPELL_ID then return end

    self:SetActive(true)
end

function BURN:OnGlowHide(spellID)
    if isPreviewActive then return end
    if spellID ~= SPELL_ID then return end

    self:SetActive(false)
end

function BURN:ShowPreview()
    if not iconFrame then self:CreateFrame() end
    isPreviewActive = true
    self:ApplySettings()
    self:StartGlow()
    if iconFrame then iconFrame:Show() end

    NRSKNUI.EditMode:RegisterModuleElement(self, {
        key = "BurningRush",
        displayName = "Burning Rush",
        frame = iconFrame,
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
        guiPath = "BurningRush",
    })
end

function BURN:HidePreview()
    isPreviewActive = false
    self:StopGlow()
    if iconFrame then iconFrame:Hide() end
    if self.BurningRushActive then self:ShowDisplay() end

    NRSKNUI.EditMode:UnregisterModuleElement("BurningRush")
end

function BURN:TogglePreview()
    if isPreviewActive then
        self:HidePreview()
    else
        self:ShowPreview()
    end
    return isPreviewActive
end

function BURN:IsPreviewActive()
    return isPreviewActive
end

function BURN:OnEnable()
    local className = select(2, UnitClass("player"))
    local isKnown = IsSpellKnown(111400)
    if not className == "WARLOCK" or not isKnown then return end
    if not self.db or not self.db.Enabled then return end

    self:CreateFrame()
    C_Timer.After(0.5, function() self:ApplyPosition() end)

    if not eventFrame then eventFrame = CreateFrame("Frame") end
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    eventFrame:SetScript("OnEvent", function(_, event, arg1, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            self:OnSpellCast(spellID)
        elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
            self:OnGlowHide(arg1)
        end
    end)

    self:RegisterEvent("PLAYER_DEAD", function()
        self.BurningRushActive = false
        self:HideDisplay()
    end)

    if NRSKNUI.EditMode then
        NRSKNUI.EditMode:RegisterElement({
            key = "BurningRush",
            displayName = "Burning Rush",
            frame = iconFrame,
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
            guiPath = "BurningRush",
        })
    end
end

function BURN:OnDisable()
    if iconFrame then
        self:StopGlow()
        iconFrame:Hide()
    end
    self.BurningRushActive = false
    isPreviewActive = false
    self.glowActive = false
    self:UnregisterAllEvents()

    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
    if NRSKNUI.EditMode then NRSKNUI.EditMode:UnregisterElement("BurningRush") end
end
