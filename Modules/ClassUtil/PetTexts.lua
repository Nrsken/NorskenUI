---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class PetTexts: AceModule, AceEvent-3.0
local PET = NRSKNUI:NewModule("PetTexts", "AceEvent-3.0")

local UnitClass = UnitClass
local IsMounted = IsMounted
local UnitOnTaxi = UnitOnTaxi
local UnitInVehicle = UnitInVehicle
local UnitHasVehicleUI = UnitHasVehicleUI
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local UnitExists = UnitExists
local CreateFrame = CreateFrame
local GetPetActionInfo = GetPetActionInfo
local PetHasActionBar = PetHasActionBar
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local C_Timer = C_Timer
local C_SpellBook = C_SpellBook

local PET_CLASSES = {
    HUNTER = { summonSpellId = 883, specId = nil },
    WARLOCK = { summonSpellId = 688, specId = nil },
    DEATHKNIGHT = { summonSpellId = 46584, specId = 252 },
    MAGE = { summonSpellId = 31687, specId = 64 },
}

local petInfo = nil
local petDeathTracked = false

local function IsPlayerMounted()
    return IsMounted() or UnitOnTaxi("player") or UnitInVehicle("player") or UnitHasVehicleUI("player")
end

local function IsPetOnPassive()
    if not UnitExists("pet") or not PetHasActionBar() then return false end
    for slot = 1, 10 do
        local name, _, isToken, isActive = GetPetActionInfo(slot)
        if isToken and name == "PET_MODE_PASSIVE" and isActive then return true end
    end
    return false
end

local function CheckAndUpdatePetDeathState()
    if UnitExists("pet") then
        petDeathTracked = UnitIsDeadOrGhost("pet")
        return petDeathTracked
    end
    return petDeathTracked
end

local function ResetPetDeathTracking()
    petDeathTracked = false
end

local function CheckPetStatus()
    if not petInfo or IsPlayerMounted() then return nil, nil end

    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)

    -- MM Hunter with Unbreakable Bond talent doesn't need a pet
    if specID == 254 and C_SpellBook.IsSpellKnown(466867) then
        return nil, nil
    end

    if petInfo.specId and specID ~= petInfo.specId then
        return nil, nil
    end

    if not C_SpellBook.IsSpellKnown(petInfo.summonSpellId) then
        return nil, nil
    end

    if CheckAndUpdatePetDeathState() then
        return PET.db.PetDead, PET.db.DeadColor
    end

    if UnitExists("pet") then
        if IsPetOnPassive() then
            return PET.db.PetPassive, PET.db.PassiveColor
        end
        return nil, nil
    end

    return PET.db.PetMissing, PET.db.MissingColor
end

function PET:CreatePetTexts()
    if self.frame then return end

    local frame = CreateFrame("Frame", "NRSKNUI_PetTextsFrame", UIParent)
    frame:SetSize(200, 50)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetTextColor(1, 0.82, 0, 1)
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)

    self.frame = frame
    self.frame.text = text
    self.text = text

    local width = math.max(text:GetWidth(), 170)
    local height = math.max(text:GetHeight(), 18)
    frame:SetSize(width + 5, height + 5)
    frame:Hide()
end

function PET:UpdatePetText()
    local message, color = CheckPetStatus()

    if message and color then
        self.text:SetText(message)
        self.text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        self.frame:Show()
    elseif self.frame then
        self.frame:Hide()
    end
end

function PET:UpdateDB()
    self.db = NRSKNUI.db.profile.PetTexts
end

function PET:OnInitialize()
    self:UpdateDB()

    local _, class = UnitClass("player")
    petInfo = PET_CLASSES[class]

    self:SetEnabledState(false)
end

function PET:RegWithEditMode()
    if NRSKNUI.EditMode and not self.editModeRegistered then
        NRSKNUI.EditMode:RegisterElement({
            key = "PetTexts",
            displayName = "Pet Texts",
            frame = self.frame,
            getPosition = function()
                return self.db.Position
            end,
            setPosition = function(pos)
                self.db.Position.AnchorFrom = pos.AnchorFrom
                self.db.Position.AnchorTo = pos.AnchorTo
                self.db.Position.XOffset = pos.XOffset
                self.db.Position.YOffset = pos.YOffset

                self.frame:ClearAllPoints()
                self.frame:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end,
            guiPath = "PetTexts",
        })
        self.editModeRegistered = true
    end
end

function PET:OnEnable()
    if not self.db.Enabled or not petInfo then return end

    self:CreatePetTexts()
    self:RegWithEditMode()

    self:RegisterEvent("UNIT_PET", function(_, unit)
        if unit == "player" then
            C_Timer.After(0.2, function()
                if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
                    ResetPetDeathTracking()
                end
                self:UpdatePetText()
            end)
        end
    end)

    self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdatePetText")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(1, function() self:UpdatePetText() end)
    end)
    self:RegisterEvent("SPELLS_CHANGED", "UpdatePetText")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "UpdatePetText")
    self:RegisterEvent("UNIT_DIED", "UpdatePetText")
    self:RegisterEvent("PET_BAR_UPDATE", function()
        C_Timer.After(0.1, function() self:UpdatePetText() end)
    end)

    self:UpdatePetText()

    C_Timer.After(1, function()
        self:ApplySettings()
    end)
end

function PET:OnDisable()
    if self.frame then self.frame:Hide() end
    self:UnregisterAllEvents()
end

---@param state "missing"|"dead"|"passive"|nil
function PET:ShowPreview(state)
    local frameJustCreated = not self.frame
    if frameJustCreated then
        self:CreatePetTexts()
        self:RegWithEditMode()
        self.frame:ApplyPosition(self.db)
        self.text:SetFontStyle(self.db)
    end

    self.isPreview = true
    self.previewState = state or "missing"

    local previewText, previewColor
    if self.previewState == "dead" then
        previewText = self.db.PetDead or "PET DEAD"
        previewColor = self.db.DeadColor or { 1, 0.2, 0.2, 1 }
    elseif self.previewState == "passive" then
        previewText = self.db.PetPassive or "PET PASSIVE"
        previewColor = self.db.PassiveColor or { 0.3, 0.7, 1, 1 }
    else
        previewText = self.db.PetMissing or "PET MISSING"
        previewColor = self.db.MissingColor or { 1, 0.82, 0, 1 }
    end

    self.text:SetText(previewText)
    self.text:SetTextColor(previewColor[1], previewColor[2], previewColor[3], previewColor[4] or 1)
    self.frame:Show()
end

function PET:HidePreview()
    self.isPreview = false
    if self.db.Enabled then
        self:UpdatePetText()
    elseif self.frame then
        self.frame:Hide()
    end
end

function PET:ApplySettings()
    if not self.frame and NRSKNUI.PreviewManager and NRSKNUI.PreviewManager:IsPreviewActive() and self.db.Enabled then
        self:ShowPreview()
    end

    if not self.frame then return end

    self.frame:ApplyPosition(self.db)
    self.text:SetFontStyle(self.db)

    if self.isPreview then
        self:ShowPreview(self.previewState)
    end
end
