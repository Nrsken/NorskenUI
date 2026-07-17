---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Recuperate
local Recuperate = NRSKNUI:GetModule('Recuperate')
local EM = NRSKNUI.EditMode

local UnitHealthPercent = UnitHealthPercent
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local CreateFrame = CreateFrame
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local InCombatLockdown = InCombatLockdown

local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo

local RECUPERATE_SPELL_ID = 1231411

function Recuperate:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.Recuperate
end

function Recuperate:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function Recuperate:CreateButton()
    if self.button then return end

    local button = CreateFrame('Button', 'NRSKNUI_RecuperateButton', UIParent, 'SecureActionButtonTemplate, SecureHandlerStateTemplate')
    button:SetPixelSize(self.db.Size, self.db.Size)
    button:RegisterForClicks('AnyUp', 'AnyDown')
    button:SetAttribute('type', 'spell')
    button:SetAttribute('spell', RECUPERATE_SPELL_ID)
    button:AddBorders()
    button:StyleButton()

    RegisterStateDriver(button, 'visibility', self:GetVisibilityString())

    button.icon = button:CreateTexture(nil, 'BORDER')
    button.icon:SetPixelInside(button, 0, 0)
    button.icon:SetZoom()

    local iconID = GetSpellInfo(RECUPERATE_SPELL_ID).iconID
    button.icon:SetTexture(iconID)

    self.button = button
    EM:Register(self, 'RecuperateButton', self.button, 'Recuperate')
    button:Hide()
end

function Recuperate:UpdateAlpha()
    if self.isPreview then return end
    if not self.button then return end

    -- Player is dead, hide button.
    if UnitIsDeadOrGhost('player') then
        self.button:SetAlpha(0)
        return
    end

    -- Curve returns 0 if health is full and 1 if health is missing.
    ---@type number
    local alpha = UnitHealthPercent('player', true, NRSKNUI.curves.HealthMissingAlpha)
    self.button:SetAlpha(alpha)
end

function Recuperate:GetVisibilityString()
    if not self.db.LoadInRaid and not self.db.LoadInParty then -- Always show the button regardless of group status.
        return '[combat] hide; [dead] hide; show'
    end
    if self.db.LoadInRaid and self.db.LoadInParty then -- Show the button in all group situations.
        return '[combat] hide; [nogroup] hide; [dead] hide; show'
    end
    if self.db.LoadInRaid then -- Show the button in raid situations but not in party.
        return '[combat] hide; [nogroup:raid] hide; [dead] hide; show'
    end
    if self.db.LoadInParty then -- Show the button in party situations but not in raid.
        return '[combat] hide; [group:raid] hide; [nogroup] hide; [dead] hide; show'
    end
end

function Recuperate:UpdateStateDriver()
    if not self.button then return end
    if self.isPreview then return end

    UnregisterStateDriver(self.button, 'visibility')
    RegisterStateDriver(self.button, 'visibility', self:GetVisibilityString())
    self:UpdateAlpha()
end

function Recuperate:ApplySettings()
    if not self.button then return end

    self.button:SetPixelSize(self.db.Size, self.db.Size)
    self.button:ApplyPosition(self.db)
end

function Recuperate:UNIT_HEALTH(_, unit)
    if unit ~= 'player' then return end -- Only update the alpha if the player health changes.
    if self.isPreview then return end

    self:UpdateAlpha()
end

function Recuperate:OnEnable()
    if not self.db.Enabled then return end

    -- Dealing with a secure button, so don't do anything until combat is over.
    NRSKNUI:RunWhenSafe(function()
        self:CreateButton()
        self:ApplySettings()
        self:UpdateAlpha()

        -- Reigster events.
        self:RegisterEvent('PLAYER_ENTERING_WORLD', 'UpdateAlpha')
        self:RegisterEvent('PLAYER_REGEN_ENABLED', 'UpdateAlpha')
        self:RegisterEvent('GROUP_ROSTER_UPDATE', 'UpdateAlpha')
        self:RegisterEvent('UNIT_HEALTH')
        self:RegisterEvent('PLAYER_DEAD', 'UpdateAlpha')
        self:RegisterEvent('PLAYER_UNGHOST', 'UpdateAlpha')
    end)
end

function Recuperate:OnDisable()
    if self.button then
        UnregisterStateDriver(self.button, 'visibility')
        self.button:Hide()
    end
    self.isPreview = false
end

function Recuperate:ShowPreview()
    if not self.button then return end
    self.isPreview = true
    UnregisterStateDriver(self.button, 'visibility')
    self.button:SetAlpha(1)
    self.button:Show()
    self:ApplySettings()
end

function Recuperate:HidePreview()
    self.isPreview = false
    if not self.button then return end

    -- Run when safe in case GUI is auto closed because the player entered combat.
    NRSKNUI:RunWhenSafe(function()
        if self.db.Enabled then
            RegisterStateDriver(self.button, 'visibility', self:GetVisibilityString())
            self:UpdateAlpha()
        else
            self.button:Hide()
        end
    end)
end
