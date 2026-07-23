---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatMessage
local CombatMessage = NRSKNUI:GetModule('CombatMessage')
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local unpack = unpack
local ipairs = ipairs
local select = select
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local GetTime = GetTime
local gmatch = string.gmatch
local gsub = string.gsub
local strlower = string.lower

local UNKNOWN = UNKNOWN

-- Throttle, cap party death announcements to avoid raid-wipe spam.
local THROTTLE_LIMIT = 4
local THROTTLE_WINDOW = 10

local messageTypes = {
    { key = 'enterCombat', order = 4, dbKey = 'EnterCombat' },
    { key = 'exitCombat',  order = 3, dbKey = 'ExitCombat' },
    { key = 'noTarget',    order = 2, dbKey = 'NoTarget' },
    { key = 'partyDeath',  order = 1, dbKey = 'PartyDeath' },
}

function CombatMessage:UpdateDB()
    self.db = NRSKNUI.db.profile.CombatMessage
end

function CombatMessage:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Replace {rtN} raidmarkers with their texture escape.
local function ProcessRaidTargetIcons(text)
    local ICON_LIST = _G.ICON_LIST
    local ICON_TAG_LIST = _G.ICON_TAG_LIST
    if not ICON_LIST or not ICON_TAG_LIST then return text end

    for tag in gmatch(text, '%b{}') do
        local term = strlower(gsub(tag, '[{}]', ''))
        local index = ICON_TAG_LIST[term]
        if index and ICON_LIST[index] then
            text = gsub(text, tag, ICON_LIST[index] .. '0|t')
        end
    end
    return text
end

-- Build the party death string for a unit with %name substitution and raid icons.
function CombatMessage:FormatPartyDeath(unit)
    local mdb = self.db.PartyDeath
    local name = NRSKNUI:GetSafeUnitName(unit) or UNKNOWN

    if mdb.UseClassColor then
        local classToken = select(2, UnitClass(unit))
        if NRSKNUI:IsSafeValue(classToken) then
            name = NRSKNUI:ColorTextByClass(name, classToken)
        end
    end

    local text = gsub(mdb.Text, '%%name', name)
    text = ProcessRaidTargetIcons(text)
    return text, mdb.Color
end

function CombatMessage:CreateGroup()
    if self.parentGroup then return end

    local parentGroup = NRSKNUI:CreateDynamicGroup(nil, UIParent)
    self.parentGroup = parentGroup

    for _, msgType in ipairs(messageTypes) do
        local child = CreateFrame('Frame', nil, parentGroup)

        local text = child:CreateFontString(nil, 'OVERLAY')
        parentGroup:AttachChild(child, msgType.key, msgType.order)
        parentGroup:ActivateChild(msgType.key)
        parentGroup[msgType.key] = text
    end

    EM:Register(self, 'CombatMessages', parentGroup, 'combatMessage')
end

function CombatMessage:ApplySettings()
    if not self.parentGroup then return end

    self.parentGroup:SetConfig(self.db.Config)
    self.parentGroup:UpdateGroupPosition(self.db, self.db.Config.Grow)

    for _, msgType in ipairs(messageTypes) do
        local mdb = self.db[msgType.dbKey]
        local text = self.parentGroup[msgType.key]
        local child = text:GetParent()

        text:SetPixelPoint(self.db.Config.Align)
        text:SetFontStyle(self.db, mdb.FontSize)

        if msgType.key == 'partyDeath' then
            local sample, color = self:FormatPartyDeath('player')
            text:SetText(sample)
            text:SetTextColor(unpack(color))
            child:SetPixelSize(text:GetStringWidth(), text:GetStringHeight())
            self.parentGroup:NotifyChildResized(child)
        else
            text:SetText(mdb.Text)
            text:SetTextColor(unpack(mdb.Color))
            child:SetPixelSize(text:GetStringWidth(), text:GetStringHeight())
            self.parentGroup:NotifyChildResized(child)
        end

        if self.isPreview and mdb.Enabled then
            self.parentGroup:ActivateChild(msgType.key)
        else
            self.parentGroup:DeactivateChild(msgType.key)
        end
    end
    self.parentGroup:ForceLayout()
end

-- Make use of AceTimer to handle scheduling the hide of messages.
function CombatMessage:FlashMessage(key)
    if not self.parentGroup then return end
    self.parentGroup:ActivateChild(key)

    if self.hideTimers[key] then
        self:CancelTimer(self.hideTimers[key])
    end
    self.hideTimers[key] = self:ScheduleTimer('HideMessage', self.db.Duration, key)
end

function CombatMessage:HideMessage(key)
    self.hideTimers[key] = nil
    if self.parentGroup then
        self.parentGroup:DeactivateChild(key)
    end
end

-- Show the party death message for a unit, and schedule it to hide after the configured duration.
function CombatMessage:ShowPartyDeathText(text, color)
    if not self.parentGroup then return end

    local fontString = self.parentGroup['partyDeath']
    local child = fontString:GetParent()

    fontString:SetText(text)
    fontString:SetTextColor(unpack(color))
    child:SetPixelSize(fontString:GetStringWidth(), fontString:GetStringHeight())
    self.parentGroup:NotifyChildResized(child)
    self:FlashMessage('partyDeath')
end

-- Play the alert sound for the dead unit's role, falling back to the damager sound.
function CombatMessage:PlayPartyDeathSound(unit)
    local mdb = self.db.PartyDeath

    local role = UnitGroupRolesAssigned(unit)
    if not NRSKNUI:IsSafeValue(role) then role = nil end

    local soundName
    if role == 'TANK' then
        soundName = mdb.SoundTank
    elseif role == 'HEALER' then
        soundName = mdb.SoundHealer
    else
        soundName = mdb.SoundDamager
    end

    if not soundName or soundName == 'None' then return end
    NRSKNUI:PlaySafeSound(soundName)
end

-- Rolling window throttle so raid wipes don't spam the message.
function CombatMessage:PassPartyDeathThrottle()
    local now = GetTime()
    local throttle = self.deathThrottle
    if now - throttle.windowStart > THROTTLE_WINDOW then
        throttle.windowStart = now
        throttle.count = 0
    end
    if throttle.count >= THROTTLE_LIMIT then return false end
    throttle.count = throttle.count + 1
    return true
end

-- Whether the party death message should run given the current group state.
function CombatMessage:IsPartyDeathLoadConditionMet()
    local condition = self.db.PartyDeath.LoadCondition
    if condition == 'ALWAYS' then return true end
    if condition == 'ANYGROUP' then return IsInGroup() end
    if condition == 'PARTY' then return IsInGroup() and not IsInRaid() end
    if condition == 'RAID' then return IsInRaid() end
    return true
end

function CombatMessage:CheckTargetStatus()
    if not self.parentGroup then return end
    if self.isPreview then return end
    if not self.db.NoTarget.Enabled then return end

    -- If the player is not in combat or is dead, deactivate the noTarget message and return early.
    if not NRSKNUI:InCombat() or UnitIsDeadOrGhost('player') then
        if self.parentGroup:IsChildActive('noTarget') then
            self.parentGroup:DeactivateChild('noTarget')
        end
        return
    end

    -- Check if the player has a target and activate/deactivate the noTarget message accordingly.
    local hasTarget = UnitExists('target')
    if hasTarget then
        if self.parentGroup:IsChildActive('noTarget') then
            self.parentGroup:DeactivateChild('noTarget')
        end
    else
        if not self.parentGroup:IsChildActive('noTarget') then
            self.parentGroup:ActivateChild('noTarget')
        end
    end
end

function CombatMessage:UNIT_DIED(_, destGUID)
    if self.isPreview then return end
    local mdb = self.db.PartyDeath
    if not mdb.Enabled then return end
    if not NRSKNUI:InCombat() then return end
    if not self:IsPartyDeathLoadConditionMet() then return end

    local unit = NRSKNUI:SafeGetUnitFromGUID(destGUID)
    if not unit then return end

    local isGroupUnit = unit:match('^party%d') or unit:match('^raid%d')
    if not isGroupUnit then return end

    if not self:PassPartyDeathThrottle() then return end

    local text, color = self:FormatPartyDeath(unit)
    self:ShowPartyDeathText(text, color)
    self:PlayPartyDeathSound(unit)
end

function CombatMessage:PLAYER_REGEN_DISABLED()
    if not self.isPreview and self.db.EnterCombat.Enabled then
        if self.parentGroup:IsChildActive('exitCombat') then
            self.parentGroup:DeactivateChild('exitCombat')
        end

        self:FlashMessage('enterCombat')
    end

    self:CheckTargetStatus()
end

function CombatMessage:PLAYER_REGEN_ENABLED()
    if not self.isPreview and self.db.ExitCombat.Enabled then
        if self.parentGroup:IsChildActive('enterCombat') then
            self.parentGroup:DeactivateChild('enterCombat')
        end

        self:FlashMessage('exitCombat')
    end

    self:CheckTargetStatus()
end

function CombatMessage:OnEnable()
    if not self.db.Enabled then return end

    self:CreateGroup()

    self.isPreview = (NRSKNUI.PreviewManager and NRSKNUI.PreviewManager:IsPreviewActive()) or false
    self.deathThrottle = { windowStart = 0, count = 0 }
    self.hideTimers = {}

    self:ApplySettings()
    self:CheckTargetStatus()

    self:RegisterEvent('UNIT_DIED')
    self:RegisterEvent('PLAYER_REGEN_DISABLED')
    self:RegisterEvent('PLAYER_REGEN_ENABLED')
    self:RegisterEvent("PLAYER_TARGET_CHANGED", 'CheckTargetStatus')
    self:RegisterEvent("PLAYER_DEAD", 'CheckTargetStatus')
end

function CombatMessage:OnDisable()
    self.isPreview = false
    if self.parentGroup then
        for _, msgType in ipairs(messageTypes) do
            self.parentGroup:DeactivateChild(msgType.key)
        end
    end
end

function CombatMessage:ShowPreview()
    if not self.parentGroup then
        self:CreateGroup()
    end

    self.isPreview = true
    self:ApplySettings()
end

function CombatMessage:HidePreview()
    if not self.parentGroup then return end

    self.isPreview = false
    self:ApplySettings()
    self:CheckTargetStatus()
end
