---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local max = math.max
local CreateFrame = CreateFrame

local C_Timer = C_Timer

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

-- Resolve CDM addon used and return their anchor frames.
local function GetCDMFrames()
    if IsAddOnLoaded('SkironCooldownManager') then
        return _G['SCM_GroupAnchor_1'], _G['SCM_GroupAnchor_2']
    elseif IsAddOnLoaded('Coolinator') then
        return _G['CoolinatorPrimaryGroupAnchor'], nil
    end
    return _G['EssentialCooldownViewer'], _G['UtilityCooldownViewer']
end

-- Our anchor is in the CDM frames protected anchor family, so sizing it is a protected call.
local function ApplyCDMAnchorSize()
    local anchor = UF.CDMAnchor
    if not anchor then return end

    local essential, utility = GetCDMFrames()
    if not essential then return end

    local width = NRSKNUI:SafeValue(essential:GetWidth())
    local height = NRSKNUI:SafeValue(essential:GetHeight())
    if not width or not height then return end

    if utility then
        UF:HookCDMFrame(utility) -- Picks up lazy spawns + all future resizes.
        if NRSKNUI:SafeValue(utility:IsShown()) then
            local utilWidth = NRSKNUI:SafeValue(utility:GetWidth())
            if utilWidth then width = max(width, utilWidth) end
        end
    end

    anchor:NUISetPixelWidth(width)
    anchor:NUISetPixelHeight(height)
    anchor:ClearAllPoints()
    anchor:NUISetGridPoint('CENTER', essential, 'CENTER', 0, 0) -- Without this we would need to use .1 offsets to avoid scuffed pixels.
end

local function ScheduleCDMAnchorUpdate()
    if UF.CDMAnchor then
        UF.CDMAnchor:NUIScheduleUpdate()
    end
end

function UF:HookCDMFrame(frame)
    if not frame or frame.nuiCDMHooked then return end
    frame.nuiCDMHooked = true

    frame:HookScript('OnSizeChanged', ScheduleCDMAnchorUpdate)
    frame:HookScript('OnShow', ScheduleCDMAnchorUpdate)
    frame:HookScript('OnHide', ScheduleCDMAnchorUpdate)
end

-- Re-evaluate the anchor span on CDM layout changes.
function UF:CDMLayoutEvent()
    ScheduleCDMAnchorUpdate()
    C_Timer.After(0.5, ScheduleCDMAnchorUpdate)
end

function UF:CreateCDMAnchor()
    local essential = GetCDMFrames()
    if not (essential and NRSKNUI:SafeValue(essential:IsShown())) then return end

    local anchor = _G['NRSKNUF_CDMAnchor'] or CreateFrame('Frame', 'NRSKNUF_CDMAnchor', UIParent)
    UF.CDMAnchor = anchor
    anchor:NUISetScheduledUpdate(function()
        NRSKNUI:RunWhenSafe(ApplyCDMAnchorSize)
    end)

    UF:HookCDMFrame(essential)
    UF:RegisterEvent('PLAYER_ENTERING_WORLD', 'CDMLayoutEvent')
    UF:RegisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED', 'CDMLayoutEvent')
    UF:RegisterEvent('TRAIT_CONFIG_UPDATED', 'CDMLayoutEvent')
    UF:RegisterEvent('EDIT_MODE_LAYOUTS_UPDATED', 'CDMLayoutEvent')
    ScheduleCDMAnchorUpdate()
end
