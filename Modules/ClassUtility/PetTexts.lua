---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class PetTextsModule
local PetTexts = NRSKNUI:GetModule('PetTexts')
local Anchors = NRSKNUI.Anchors

local ipairs = ipairs
local unpack = unpack
local select = select
local CreateFrame = CreateFrame
local IsMounted = IsMounted
local UnitOnTaxi = UnitOnTaxi
local UnitInVehicle = UnitInVehicle
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitExists = UnitExists
local GetPetActionInfo = GetPetActionInfo
local PetHasActionBar = PetHasActionBar
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local RunNextFrame = RunNextFrame

local IsSpellKnown = C_SpellBook and C_SpellBook.IsSpellKnown
local IsSpellInSpellBook = C_SpellBook and C_SpellBook.IsSpellInSpellBook

local petStates = {
    { key = 'petMissing', order = 1, textKey = 'PetMissing', colorKey = 'MissingColor' },
    { key = 'petDead',    order = 2, textKey = 'PetDead',    colorKey = 'DeadColor' },
    { key = 'petPassive', order = 3, textKey = 'PetPassive', colorKey = 'PassiveColor' },
    { key = 'petWrong',   order = 4, textKey = 'PetWrong',   colorKey = 'WrongColor' },
}

function PetTexts:UpdateDB()
    self.db = NRSKNUI.db.profile.PetTexts
end

-- Check if the player's pet is on passive mode.
local function IsPetOnPassive()
    if not UnitExists('pet') or not PetHasActionBar() then return false end
    for slot = 1, 10 do
        local name, _, isToken, isActive = GetPetActionInfo(slot)
        if isToken and name == 'PET_MODE_PASSIVE' and isActive then return true end
    end
    return false
end

-- Demonology is the only spec locked to a specific pet, identified by Felstorm on the pet bar.
local function IsWrongWarlockPet()
    if NRSKNUI.MyClass ~= 'WARLOCK' or NRSKNUI.MySpec.id ~= 266 then return false end
    if not IsSpellInSpellBook(30146) then return false end
    if not UnitExists('pet') or not PetHasActionBar() then return false end

    for slot = 1, 10 do
        if select(7, GetPetActionInfo(slot)) == 89751 then return false end
    end
    return true
end

-- Check and return whether the player's pet is dead or not.
-- If the player has no pet, it will return the last known state of the pet i.e. dead or alive.
function PetTexts:IsPetDead()
    if UnitExists('pet') then
        self.petIsDead = UnitIsDeadOrGhost('pet')
        return self.petIsDead
    end
    return self.petIsDead
end

-- Check if we should even check for the pet state and show the pet texts.
function PetTexts:ShouldShow()
    if not self.parentGroup then return false end                                             -- If the parent group doesn't exist, we can't show the pet texts.
    if UnitIsDeadOrGhost('player') then return false end                                      -- Player is dead or a ghost, don't show pet texts
    if not self.petInfo then return false end                                                 -- Player is not a class that has a pet.
    if self.petInfo.specId and NRSKNUI.MySpec.id ~= self.petInfo.specId then return false end -- Class only has a pet on one spec, and this isn't it.

    local playerIsMounted = IsMounted() or
        UnitOnTaxi('player') or
        UnitInVehicle('player') or
        UnitHasVehicleUI('player')
    if playerIsMounted then return false end                                   -- Player is mounted, dont show pet texts

    if NRSKNUI.MySpec.id == 254 and IsSpellKnown(466867) then return false end -- MM Hunter with Unbreakable Bond talent doesn't need a pet
    if not IsSpellKnown(self.petInfo.summonSpellId) then return false end      -- Player is a class that has a pet, but the player does not know the summon spell for their pet.

    return true
end

function PetTexts:CreateGroup()
    if self.parentGroup then return end

    local parentGroup = NRSKNUI:CreateDynamicGroup(nil, UIParent)
    self.parentGroup = parentGroup

    for _, petType in ipairs(petStates) do
        local child = CreateFrame('Frame', nil, parentGroup)
        local text = child:CreateFontString(nil, 'OVERLAY')
        parentGroup:AttachChild(child, petType.key, petType.order)
        parentGroup[petType.key] = text
    end

    Anchors:Register(self, 'PetTexts', parentGroup, 'petTexts')
end

function PetTexts:ApplySettings()
    if not self.parentGroup then return end

    self.parentGroup:SetConfig(self.db.Config)
    self.parentGroup:UpdateGroupPosition(self.db, self.db.Config.Grow)

    for _, petType in ipairs(petStates) do
        local text = self.parentGroup[petType.key]
        local child = text:GetParent()

        text:NUISetPixelPoint('CENTER')
        text:SetFontStyle(self.db)

        text:SetText(self.db[petType.textKey])
        text:SetTextColor(unpack(self.db[petType.colorKey]))
        child:NUISetPixelSize(text:GetStringWidth(), text:GetStringHeight())
        self.parentGroup:NotifyChildResized(child)

        if self.isPreview and self.db.Enabled then
            self.parentGroup:ActivateChild(petType.key)
        else
            self.parentGroup:DeactivateChild(petType.key)
        end
    end
    self.parentGroup:ForceLayout()

    if not self.isPreview then
        self:UpdateStateText()
    end
end

-- Get the current state of the player's pet.
function PetTexts:GetState()
    if not self:ShouldShow() then return nil end

    -- Playeing demonology warlock and not using the Felstorm pet, show the "wrong pet" text.
    if IsWrongWarlockPet() then return 'petWrong' end

    -- No pet at all, the cached flag is the only thing separating "died and gone" from "never summoned".
    if not UnitExists('pet') then return self.petIsDead and 'petDead' or 'petMissing' end

    -- Dead pet has priority over passive, for obvious reasons. :)
    if self:IsPetDead() then return 'petDead' end
    if IsPetOnPassive() then return 'petPassive' end
    return nil
end

function PetTexts:UpdateStateText()
    if not self.parentGroup or self.isPreview or self.updateQueued then return end
    self.updateQueued = true
    RunNextFrame(function() -- Slight delay to avoid text flicker when the pet state changes.
        self.updateQueued = false
        -- The preview can start between scheduling and running, and it owns the children while it does.
        if not self.parentGroup or self.isPreview then return end

        local state = self:GetState()
        for _, petType in ipairs(petStates) do
            if state == petType.key then
                self.parentGroup:ActivateChild(petType.key)
            else
                self.parentGroup:DeactivateChild(petType.key)
            end
        end
    end)
end

function PetTexts:UNIT_PET(_, unit)
    if unit == 'player' then
        C_Timer.After(0.2, function()
            if UnitExists('pet') and not UnitIsDeadOrGhost('pet') then
                self.petIsDead = false
            end
            self:UpdateStateText()
        end)
    end
end

function PetTexts:OnEnable()
    self.petInfo = NRSKNUI.PET_CLASSES[NRSKNUI.MyClass]

    self:CreateGroup()
    self:ApplySettings()

    self:RegisterEvent('PLAYER_REGEN_ENABLED', 'UpdateStateText')
    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'UpdateStateText')
    self:RegisterEvent('PLAYER_MOUNT_DISPLAY_CHANGED', 'UpdateStateText') -- Check for pet state when the player mounts or dismounts.
    self:RegisterEvent('PLAYER_ALIVE', 'UpdateStateText')                 -- Check for pet state when the player is resurrected.
    self:RegisterEvent('SPELLS_CHANGED', 'UpdateStateText')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED', 'UpdateStateText')
    self:RegisterEvent('UNIT_DIED', 'UpdateStateText')
    self:RegisterEvent('PET_BAR_UPDATE', 'UpdateStateText')
    self:RegisterEvent('UNIT_PET') -- Fired when a unit's pet changes.
end

function PetTexts:OnDisable()
    self.isPreview = false
    if self.parentGroup then
        self.parentGroup:SetLimit(1)
        for _, petType in ipairs(petStates) do
            self.parentGroup:DeactivateChild(petType.key)
        end
    end
end

function PetTexts:ShowPreview()
    if not self.parentGroup then return end

    self.parentGroup:SetLimit(#petStates)
    self.isPreview = true
    self:ApplySettings()
end

function PetTexts:HidePreview()
    if not self.parentGroup then return end

    self.isPreview = false
    self.parentGroup:SetLimit(1)
    self:ApplySettings()
    self:UpdateStateText()
end
