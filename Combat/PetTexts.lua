-- NorskenUI namespace
local _, NRSKNUI = ...

-- Safety check
if not NRSKNUI.Addon then
    error("PetTexts: Addon object not initialized. Check file load order!")
    return
end

local PET = NRSKNUI.Addon:NewModule("PetTexts", "AceEvent-3.0")

-- Localization
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
local ipairs = ipairs
local C_Timer = C_Timer
local C_SpellBook = C_SpellBook

-- Tracked pet classes
local PET_CLASSES = {
    ["HUNTER"] = { summonSpellId = 883, reviveSpellId = 982, specId = nil },
    ["WARLOCK"] = { summonSpellId = 688, reviveSpellId = nil, specId = nil },
    ["DEATHKNIGHT"] = { summonSpellId = 46584, reviveSpellId = nil, specId = 252 },
    ["MAGE"] = { summonSpellId = 31687, reviveSpellId = nil, specId = 64 },
}

-- Module State
local petInfo = nil
local petDeathTracked = false -- Track if we know the pet is dead

-- Pet status enum for internal tracking
local PET_STATUS = {
    NONE = 0,
    MISSING = 1,
    DEAD = 2,
    PASSIVE = 3,
}

-- Helper Functions
local function IsPlayerMounted()
    return IsMounted() or UnitOnTaxi("player") or UnitInVehicle("player") or UnitHasVehicleUI("player")
end

-- Check if pet is on passive stance
local function IsPetOnPassive()
    if not UnitExists("pet") or not PetHasActionBar() then return false end
    for slot = 1, 10 do
        local name, _, isToken, isActive = GetPetActionInfo(slot)
        -- Identify passive stance via token name and check if it's currently active
        if isToken and name == "PET_MODE_PASSIVE" and isActive then return true end
    end
    return false
end

-- Check if pet is dead and update tracking state
-- Uses both API check and tracked state to persist through player death/respawn for consistency
local function CheckAndUpdatePetDeathState()
    -- If pet exists and is alive, clear the death tracking
    if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
        petDeathTracked = false
        return false
    end

    -- If pet exists and is dead, set death tracking
    if UnitExists("pet") and UnitIsDeadOrGhost("pet") then
        petDeathTracked = true
        return true
    end

    -- Pet unit doesn't exist - check our tracked state
    -- If we previously tracked the pet as dead, it's still dead
    if petDeathTracked then return true end

    -- Pet doesn't exist and wasn't tracked as dead = missing/dismissed
    return false
end

-- Reset death tracking, called when pet is summoned/revived
local function ResetPetDeathTracking()
    petDeathTracked = false
end

-- Check pet status and return status code + text + color
local function CheckPetStatus()
    if not petInfo then return PET_STATUS.NONE, nil, nil end
    if IsPlayerMounted() then return PET_STATUS.NONE, nil, nil end

    -- Improved Spec Check
    if petInfo.specId then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            if specID ~= petInfo.specId then return PET_STATUS.NONE, nil, nil end
        end
    end

    if not C_SpellBook.IsSpellKnown(petInfo.summonSpellId) then return PET_STATUS.NONE, nil, nil end

    -- Priority here is Dead > Passive > Missing
    -- Check dead first using tracked state
    if CheckAndUpdatePetDeathState() then
        return PET_STATUS.DEAD, PET.db.PetDead, PET.db.DeadColor
    end

    if UnitExists("pet") then
        if IsPetOnPassive() then
            return PET_STATUS.PASSIVE, PET.db.PetPassive, PET.db.PassiveColor -- Check if pet is on passive
        end
        return PET_STATUS.NONE, nil, nil                                      -- Pet exists and is alive and not passive
    else
        return PET_STATUS.MISSING, PET.db.PetMissing, PET.db.MissingColor -- Pet is missing
    end
end

-- Create the Display
function PET:CreatePetTexts()
    if self.frame then return end
    local posDB = self.db.Position
    local frame = CreateFrame("Frame", "NRSKNUI_PetTextsFrame", UIParent)
    frame:SetSize(200, 50)

    local text = frame:CreateFontString(nil, "OVERLAY")
    local fontPath = NRSKNUI:GetFontPath(self.db.FontFace)
    text:SetFont(fontPath, self.db.FontSize, "")
    text:SetTextColor(1, 0.82, 0)
    text:ClearAllPoints()
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)

    self.frame = frame
    self.frame.text = text
    self.text = text

    local width, height = math.max(text:GetWidth(), 170), math.max(text:GetHeight(), 18)
    frame:SetSize(width + 5, height + 5)

    NRSKNUI:ApplyFontToText(self.text, self.db.FontFace, self.db.FontSize, self.db.FontOutline)
    NRSKNUI:ApplyFramePosition(self.frame, posDB, self.db)

    self.frame:Hide()
end

-- Update Display
function PET:UpdatePetText()
    local status, message, color = CheckPetStatus()

    if message and color then
        self.text:SetText(message)
        self.text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        self.frame:Show()
    else
        if self.frame then self.frame:Hide() end
    end
end

-- Module init
function PET:OnInitialize()
    self.db = NRSKNUI.db.profile.PetTexts

    local _, class = UnitClass("player")
    petInfo = PET_CLASSES[class]

    self:SetEnabledState(false)
end

-- Module OnEnable
function PET:OnEnable()
    if not self.db.Enabled then return end
    if not petInfo then return end

    self:CreatePetTexts()

    self:RegisterEvent("UNIT_PET", function(_, unit)
        if unit == "player" then
            C_Timer.After(0.2, function()
                -- Reset death tracking if pet is now alive
                if UnitExists("pet") and not UnitIsDeadOrGhost("pet") then
                    ResetPetDeathTracking()
                end
                self:UpdatePetText()
            end)
        end
    end)

    self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdatePetText")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, function() self:UpdatePetText() end) end)
    self:RegisterEvent("SPELLS_CHANGED", "UpdatePetText")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "UpdatePetText")
    self:RegisterEvent("UNIT_DIED", "UpdatePetText")

    -- Register for pet bar updates
    self:RegisterEvent("PET_BAR_UPDATE", function()
        C_Timer.After(0.1, function() self:UpdatePetText() end)
    end)

    -- Run initial check
    self:UpdatePetText()

    -- Delayed update, just to make sure object exists
    C_Timer.After(1, function()
        self:ApplySettings()
    end)

    -- Define the registration config
    if NRSKNUI.EditMode and not self.editModeRegistered then
        local config = {
            key = "PetTexts",
            displayName = "Pet Texts",
            frame = self.frame,
            -- getPosition must be a function that returns the table
            getPosition = function()
                return self.db.Position
            end,
            -- setPosition must be a function that saves the data and moves the frame
            setPosition = function(pos)
                self.db.Position.AnchorFrom = pos.AnchorFrom
                self.db.Position.AnchorTo = pos.AnchorTo
                self.db.Position.XOffset = pos.XOffset
                self.db.Position.YOffset = pos.YOffset

                self.frame:ClearAllPoints()
                self.frame:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end,
            guiPath = "PetTexts",
        }
        NRSKNUI.EditMode:RegisterElement(config)
        self.editModeRegistered = true
    end
end

function PET:OnDisable()
    if self.frame then self.frame:Hide() end
    self:UnregisterAllEvents()
end

-- Preview mode support for GUI and Edit Mode
-- state: "missing", "dead", "passive" (default: "missing")
function PET:ShowPreview(state)
    if not self.frame then
        self:CreatePetTexts()
    end

    -- Store preview state
    self.isPreview = true
    self.previewState = state or "missing"

    -- Get text and color based on preview state
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
    -- If module is enabled, update to real state; otherwise hide
    if self.db.Enabled then
        self:UpdatePetText()
    else
        if self.frame then self.frame:Hide() end
    end
end

-- Module update func
function PET:ApplySettings()
    if not self.frame then return end

    -- Update position settings
    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db)
    -- Update font settings
    NRSKNUI:ApplyFontToText(self.text, self.db.FontFace, self.db.FontSize, self.db.FontOutline)

    -- If in preview mode, update the preview text
    if self.isPreview then
        self:ShowPreview(self.previewState)
    end
end
