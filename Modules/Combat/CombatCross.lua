---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatCrossModule
local CombatCross = NRSKNUI:GetModule('CombatCross')

local GetSpecializationInfo = GetSpecializationInfo
local GetSpecialization = GetSpecialization
local CreateFrame = CreateFrame
local unpack = unpack

local EnableSpellRangeCheck = C_Spell and C_Spell.EnableSpellRangeCheck
local IsSpellInRange = C_Spell and C_Spell.IsSpellInRange
local SpellHasRange = C_Spell and C_Spell.SpellHasRange

local DOT_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\whiteCircle.png'
local DIAMON_ATLAS = 'progress-bar-diamond-pip-mask'

-- The cross sits at a fixed screen position and registers no anchor, so PreviewManager cannot resolve
-- its page out of the anchor registry the way every other display is resolved.
CombatCross.previewPages = 'combatCross'

function CombatCross:UpdateDB()
    self.db = NRSKNUI.db.profile.CombatCross
end

function CombatCross:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Line creation helper.
local function CreateLines(pointFrom, frame, width, height)
    local lineFrame = CreateFrame('Frame', nil, frame)
    lineFrame:NUISetPixelSize(width, height)
    lineFrame:NUISetPixelPoint(pointFrom, frame, 'CENTER')
    lineFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
    lineFrame:NUIAddBorders()

    lineFrame.texture = lineFrame:CreateTexture(nil, 'OVERLAY')
    lineFrame.texture:SetTexture(NRSKNUI.WhiteTexture)
    lineFrame.texture:NUISetPixelInside()
    lineFrame.texture:NUISetPixelSnap()

    return lineFrame
end

function CombatCross:CreateFrame()
    if self.coreFrame then return end

    -- Core base frame, all lines and dot are children of this.
    local coreFrame = CreateFrame('Frame', 'NRSKNUI_CombatCrossCoreFrame', UIParent)
    coreFrame:NUISetPixelSize(40)
    coreFrame:SetFrameStrata('HIGH')
    coreFrame:SetFrameLevel(100)

    -- Cross lines
    coreFrame.textureUp = CreateLines('BOTTOM', coreFrame, self.db.CrossThickness, self.db.CrossLength)
    coreFrame.textureDown = CreateLines('TOP', coreFrame, self.db.CrossThickness, self.db.CrossLength)
    coreFrame.textureLeft = CreateLines('RIGHT', coreFrame, self.db.CrossLength, self.db.CrossThickness)
    coreFrame.textureRight = CreateLines('LEFT', coreFrame, self.db.CrossLength, self.db.CrossThickness)

    -- Cross middle dot
    coreFrame.textureCrossDot = CreateLines('CENTER', coreFrame, self.db.CrossThickness, self.db.CrossThickness)

    -- Dot backdrop that acts like a border.
    coreFrame.dotBG = coreFrame:CreateTexture(nil, 'ARTWORK')
    coreFrame.dotBG:SetTexture(DOT_TEXTURE)
    coreFrame.dotBG:NUISetPixelPoint('CENTER', coreFrame, 'CENTER')
    coreFrame.dotBG:NUISetPixelSnap()
    coreFrame.dotBG:SetVertexColor(0, 0, 0)

    -- Dot texture
    coreFrame.dot = coreFrame:CreateTexture(nil, 'OVERLAY')
    coreFrame.dot:SetTexture(DOT_TEXTURE)
    coreFrame.dot:NUISetPixelPoint('CENTER', coreFrame, 'CENTER')
    coreFrame.dot:NUISetPixelSnap()

    -- Diamond backdrop that acts like a border.
    coreFrame.diamondBG = coreFrame:CreateTexture(nil, 'ARTWORK')
    coreFrame.diamondBG:SetAtlas(DIAMON_ATLAS)
    coreFrame.diamondBG:NUISetPixelPoint('CENTER', coreFrame, 'CENTER')
    coreFrame.diamondBG:NUISetPixelSnap()
    coreFrame.diamondBG:SetVertexColor(0, 0, 0)

    -- Diamond texture
    coreFrame.diamond = coreFrame:CreateTexture(nil, 'OVERLAY')
    coreFrame.diamond:SetAtlas(DIAMON_ATLAS)
    coreFrame.diamond:NUISetPixelPoint('CENTER', coreFrame, 'CENTER')
    coreFrame.diamond:NUISetPixelSnap()

    self.coreFrame = coreFrame
    coreFrame:Hide()
end

-- Paint all 4 cross lines and dot the same color.
function CombatCross:SetColor(r, g, b, a)
    if not self.coreFrame then return end

    -- Cross coloring
    self.coreFrame.textureUp.texture:SetColorTexture(r, g, b, a)
    self.coreFrame.textureDown.texture:SetColorTexture(r, g, b, a)
    self.coreFrame.textureLeft.texture:SetColorTexture(r, g, b, a)
    self.coreFrame.textureRight.texture:SetColorTexture(r, g, b, a)
    self.coreFrame.textureCrossDot.texture:SetColorTexture(r, g, b, a)

    -- Dot coloring
    self.coreFrame.dot:SetVertexColor(r, g, b, a)

    -- Diamond coloring
    self.coreFrame.diamond:SetVertexColor(r, g, b, a)
end

-- The cross lines normal color.
function CombatCross:SetBaseColor()
    self:SetColor(unpack(CombatCross.BaseColor))
end

function CombatCross:ApplySettings()
    if not self.coreFrame then return end

    -- Cache the base color for use when range coloring is disabled or in-range.
    local r, g, b, a = NRSKNUI:GetAccentColor(self.db.ColorMode, self.db.Color)
    CombatCross.BaseColor = { r, g, b, a }

    -- Position
    self.coreFrame:NUIApplyPosition(self.db)

    -- Gap, one time offset so that 0 gap really is no gap.
    local gap = self.db.CrossGap - 2
    self.coreFrame.textureUp:NUISetPixelPoint('BOTTOM', self.coreFrame, 'CENTER', 0, gap)
    self.coreFrame.textureDown:NUISetPixelPoint('TOP', self.coreFrame, 'CENTER', 0, -gap)
    self.coreFrame.textureLeft:NUISetPixelPoint('RIGHT', self.coreFrame, 'CENTER', -gap, 0)
    self.coreFrame.textureRight:NUISetPixelPoint('LEFT', self.coreFrame, 'CENTER', gap, 0)

    -- Thickness and length
    self.coreFrame.textureUp:NUISetPixelSize(self.db.CrossThickness, self.db.CrossLength)
    self.coreFrame.textureDown:NUISetPixelSize(self.db.CrossThickness, self.db.CrossLength)
    self.coreFrame.textureLeft:NUISetPixelSize(self.db.CrossLength, self.db.CrossThickness)
    self.coreFrame.textureRight:NUISetPixelSize(self.db.CrossLength, self.db.CrossThickness)
    self.coreFrame.textureCrossDot:NUISetPixelSize(self.db.CrossThickness, self.db.CrossThickness)

    -- Outline
    self.coreFrame.textureUp:SetBorderShown(self.db.Outline)
    self.coreFrame.textureDown:SetBorderShown(self.db.Outline)
    self.coreFrame.textureLeft:SetBorderShown(self.db.Outline)
    self.coreFrame.textureRight:SetBorderShown(self.db.Outline)
    self.coreFrame.textureCrossDot:SetBorderShown(self.db.Outline)

    -- Modes
    local dotMode = self.db.Mode == 'dot'
    local diamondMode = self.db.Mode == 'diamond'
    local crossMode = self.db.Mode == 'cross'

    -- Cross
    self.coreFrame.textureUp:SetShown(crossMode)
    self.coreFrame.textureDown:SetShown(crossMode)
    self.coreFrame.textureLeft:SetShown(crossMode)
    self.coreFrame.textureRight:SetShown(crossMode)
    self.coreFrame.textureCrossDot:SetShown(crossMode and self.db.CrossCenterDotEnabled)

    -- Dot
    self.coreFrame.dotBG:NUISetPixelSize(self.db.CenterDotSize + 2)
    self.coreFrame.dot:NUISetPixelSize(self.db.CenterDotSize)
    self.coreFrame.dot:SetShown(dotMode)
    self.coreFrame.dotBG:SetShown(dotMode and self.db.Outline)

    -- Diamond, slight adjustmest since original texture is square and we want it to be a diamond shape.
    local diamondWidth = self.db.DiamondSize - 2
    local diamondHeight = self.db.DiamondSize + 4
    local diamondHeightBG, diamondWidthBG = diamondHeight + 4, diamondWidth + 4
    self.coreFrame.diamondBG:NUISetPixelSize(diamondWidthBG, diamondHeightBG)
    self.coreFrame.diamond:NUISetPixelSize(diamondWidth, diamondHeight)
    self.coreFrame.diamond:SetShown(diamondMode)
    self.coreFrame.diamondBG:SetShown(diamondMode and self.db.Outline)

    -- Base color, then let the range system repaint over it if it applies.
    self:SetBaseColor()
    self:ResolveRangeAbility()
    self:SyncRangeCheck()
end

-- Resolve the spell we range-check against for the current spec.
function CombatCross:ResolveRangeAbility()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)

    -- Determine the ability we use for range checking, based on spec data from Core\Constants.lua.
    if specID and NRSKNUI.MELEE_RANGE_ABILITIES[specID] then
        self.rangeAbility = NRSKNUI.MELEE_RANGE_ABILITIES[specID]
        self.specType = 'melee'
    elseif specID and NRSKNUI.RANGED_RANGE_ABILITIES[specID] then
        self.rangeAbility = NRSKNUI.RANGED_RANGE_ABILITIES[specID]
        self.specType = 'ranged'
    else
        self.rangeAbility = nil
        self.specType = nil
    end
end

-- Whether range coloring should currently be running.
function CombatCross:ShouldCheckRange()
    if not NRSKNUI:InCombat() then return false end

    -- We don't have a valid ability to check against.
    if not self.rangeAbility then
        return false
    end

    local meleeCheck = self.specType == 'melee' and self.db.RangeColorMeleeEnabled
    local rangedCheck = self.specType == 'ranged' and self.db.RangeColorRangedEnabled
    local enabled = meleeCheck or rangedCheck

    -- The user has disabled range coloring for this spec type.
    if not enabled then
        return false
    end

    return SpellHasRange(self.rangeAbility) == true
end

-- Apply a color for the given range state.
-- checksRange is false when there is no valid target for the spell to test.
function CombatCross:ApplyRangeColor(inRange, checksRange)
    if not checksRange then
        if self.lastInRange ~= nil then
            self.lastInRange = nil
            self:SetBaseColor()
        end
        return
    end

    local nowInRange = inRange == true
    if nowInRange == self.lastInRange then return end
    self.lastInRange = nowInRange

    if nowInRange then
        self:SetBaseColor()
    else
        local c = self.db.OutOfRangeColor
        self:SetColor(c[1], c[2], c[3], c[4])
    end
end

function CombatCross:StartRangeCheck()
    if self.rangeCheckActive then return end

    self.rangeCheckActive = true
    self.rangeCheckSpellID = self.rangeAbility
    EnableSpellRangeCheck(self.rangeCheckSpellID, true)
    self:RegisterEvent('SPELL_RANGE_CHECK_UPDATE')

    -- Seed the initial color from the current state.
    self.lastInRange = nil
    local inRange = IsSpellInRange(self.rangeCheckSpellID)
    self:ApplyRangeColor(inRange == true, inRange ~= nil)
end

function CombatCross:StopRangeCheck()
    if not self.rangeCheckActive then return end

    self.rangeCheckActive = false
    if self.rangeCheckSpellID then
        EnableSpellRangeCheck(self.rangeCheckSpellID, false)
    end
    self.rangeCheckSpellID = nil
    self:UnregisterEvent('SPELL_RANGE_CHECK_UPDATE')
    self.lastInRange = nil
    self:SetBaseColor()
end

-- Start/stop/restart the range check to match the current spec + settings.
function CombatCross:SyncRangeCheck()
    if not self:ShouldCheckRange() then
        self:StopRangeCheck()
        return
    end

    -- (Re)start when idle or the resolved ability changed because of a spec swap.
    if not self.rangeCheckActive or self.rangeCheckSpellID ~= self.rangeAbility then
        self:StopRangeCheck()
        self:StartRangeCheck()
        return
    end

    -- Already watching the right spell, just refresh the color.
    self.lastInRange = nil
    local inRange = IsSpellInRange(self.rangeCheckSpellID)
    self:ApplyRangeColor(inRange == true, inRange ~= nil)
end

function CombatCross:SPELL_RANGE_CHECK_UPDATE(_, spellID, inRange, checksRange)
    if spellID ~= self.rangeCheckSpellID then return end
    self:ApplyRangeColor(inRange, checksRange)
end

-- Update the range ability when the player changes spec, then sync the range check to match the new spec.
function CombatCross:PLAYER_SPECIALIZATION_CHANGED()
    self:ResolveRangeAbility()
    self:SyncRangeCheck()
end

-- Cross is visible while previewing or in combat.
function CombatCross:UpdateVisibility()
    if not self.coreFrame then return end

    if self.isPreview or NRSKNUI:InCombat() then
        self.coreFrame:Show()
    else
        self.coreFrame:Hide()
    end
end

function CombatCross:PLAYER_REGEN_DISABLED()
    self:UpdateVisibility()
    self:SyncRangeCheck()
end

function CombatCross:PLAYER_REGEN_ENABLED()
    self:UpdateVisibility()
    self:StopRangeCheck()
end

function CombatCross:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()

    -- Grab preview state
    self.isPreview = (NRSKNUI.PreviewManager and NRSKNUI.PreviewManager:IsPreviewActive()) or false

    self:ApplySettings()
    self:UpdateVisibility()

    self.themeSub = NRSKNUI.GUI:OnThemeChanged(function()
        if self.db.ColorMode ~= "theme" then return end
        self:ApplySettings()
    end)

    -- Reg events
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'SyncRangeCheck')
    self:RegisterEvent('PLAYER_REGEN_DISABLED')
    self:RegisterEvent('PLAYER_REGEN_ENABLED')
end

function CombatCross:OnDisable()
    self.isPreview = false
    self:StopRangeCheck()
    if self.coreFrame then
        self.coreFrame:Hide()
        if self.themeSub then
            self.themeSub()
            self.themeSub = nil
        end
    end
end

function CombatCross:ShowPreview()
    if not self.coreFrame then
        self:CreateFrame()
        self:ApplySettings()
    end

    self.isPreview = true
    self:UpdateVisibility()
end

function CombatCross:HidePreview()
    if not self.coreFrame then return end

    self.isPreview = false
    self:UpdateVisibility()
end
