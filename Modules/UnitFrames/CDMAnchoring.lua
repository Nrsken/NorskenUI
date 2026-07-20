---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF

local max = math.max
local CreateFrame = CreateFrame

local C_Timer = C_Timer

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

-- Resolve CDM addon used and return their anchor frames.
local function GetCDMFrames()
    if IsAddOnLoaded("SkironCooldownManager") then
        return _G["SCM_GroupAnchor_1"], _G["SCM_GroupAnchor_2"]
    elseif IsAddOnLoaded("Coolinator") then
        return _G["CoolinatorPrimaryGroupAnchor"], nil
    end
    return _G["EssentialCooldownViewer"], _G["UtilityCooldownViewer"]
end

local function HookCDMFrame(frame, anchor)
    if not frame or frame.nuiCDMHooked then return end
    frame.nuiCDMHooked = true

    local function refresh() UpdateCDMAnchorSize(anchor) end
    frame:HookScript("OnSizeChanged", refresh)
    frame:HookScript("OnShow", refresh)
    frame:HookScript("OnHide", refresh)
end

-- Making sure values are safe to access before using them, just in case because i dont trust WoW API :)
local function UpdateCDMAnchorSize(anchor)
    local essential, utility = GetCDMFrames()
    if not essential then return end

    local width = NRSKNUI:SafeValue(essential:GetWidth())
    local height = NRSKNUI:SafeValue(essential:GetHeight())
    if not width or not height then return end

    if utility then
        HookCDMFrame(utility, anchor) -- Picks up lazy spawns + all future resizes.
        if NRSKNUI:SafeValue(utility:IsShown()) then
            local utilWidth = NRSKNUI:SafeValue(utility:GetWidth())
            if utilWidth then width = max(width, utilWidth) end
        end
    end

    anchor:SetWidth(width)
    anchor:SetHeight(height)
end

-- Re-evaluate the anchor span on CDM layout changes.
function UF:CDMLayoutEvent()
    local anchor = self.CDMAnchor
    if not anchor then return end

    UpdateCDMAnchorSize(anchor)
    C_Timer.After(0.5, function()
        UpdateCDMAnchorSize(anchor)
    end)
end

function UF:CreateCDMAnchor()
    local essential, utility = GetCDMFrames()
    if not (essential and NRSKNUI:SafeValue(essential:IsShown())) then return end

    local anchor = _G["NRSKNUF_CDMAnchor"] or CreateFrame("Frame", "NRSKNUF_CDMAnchor", UIParent)
    UF.CDMAnchor = anchor
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", essential, "CENTER", 0, 0)

    HookCDMFrame(essential, anchor)
    UF:RegisterEvent("PLAYER_ENTERING_WORLD", "CDMLayoutEvent")
    UF:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "CDMLayoutEvent")
    UF:RegisterEvent("TRAIT_CONFIG_UPDATED", "CDMLayoutEvent")
    UF:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "CDMLayoutEvent")
    UpdateCDMAnchorSize(anchor)
end
