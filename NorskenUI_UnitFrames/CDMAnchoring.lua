---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local max = math.max
local CreateFrame = CreateFrame

local C_Timer = C_Timer

local IsAddOnLoaded = C_AddOns.IsAddOnLoaded

-- Resolve CDM addon used and return their anchor frames.
local function GetCDMFrames()
    if IsAddOnLoaded('SkironCooldownManager') then
        return _G['SCM_GroupAnchor_1'], _G['SCM_GroupAnchor_2']
    elseif IsAddOnLoaded('Coolinator') then
        return _G['CoolinatorPrimaryGroupAnchor'], nil
    end

    local Auras = _G.NorskenAuras --[[@as NRSKNUI?]]
    local CDM = Auras and Auras.CDM
    if CDM and CDM:IsEnabled() then
        local primary, secondary = CDM:GetAnchorGroups()
        if primary then return primary, secondary, CDM.db.AnchorMinWidth end
    end
    return _G['EssentialCooldownViewer'], _G['UtilityCooldownViewer']
end

-- Our anchor is in the CDM frames protected anchor family, so sizing it is a protected call.
local function ApplyCDMAnchorSize()
    local anchor = UF.CDMAnchor
    if not anchor then return end

    local essential, utility, minWidth = GetCDMFrames()
    if not essential then return end
    UF:HookCDMFrame(essential)
    if not NRSKNUI:SafeValue(essential:IsShown()) then return end

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

    local x, y = essential:GetCenter()
    if minWidth and not x then return end

    anchor:NCSetWidth(max(width, minWidth or 0))
    anchor:NCSetHeight(height)
    anchor:ClearAllPoints()
    if minWidth then
        -- Our groups get a copied rect: anchoring them under the secure unit frames would protect their Show/Hide.
        local scale = essential:GetEffectiveScale() / UIParent:GetEffectiveScale()
        anchor:NCSetGridPoint('CENTER', UIParent, 'BOTTOMLEFT', x * scale, y * scale)
    else
        anchor:NCSetGridPoint('CENTER', essential, 'CENTER', 0, 0) -- Without this we would need to use .1 offsets to avoid scuffed pixels.
    end
end

function UF:ScheduleCDMAnchorUpdate()
    if UF.CDMAnchor then
        UF.CDMAnchor:NCScheduleUpdate()
    end
end

function UF:HookCDMFrame(frame)
    if not frame or frame.nuiCDMHooked then return end
    frame.nuiCDMHooked = true

    frame:HookScript('OnSizeChanged', UF.ScheduleCDMAnchorUpdate)
    frame:HookScript('OnShow', UF.ScheduleCDMAnchorUpdate)
    frame:HookScript('OnHide', UF.ScheduleCDMAnchorUpdate)
end

-- Re-evaluate the anchor span on CDM layout changes.
---@param event string?
function UF:CDMLayoutEvent(event)
    -- A reload in combat locks the anchor right after this, before a scheduled update would run.
    if event == 'PLAYER_ENTERING_WORLD' then NRSKNUI:RunWhenSafe(ApplyCDMAnchorSize) end
    UF:ScheduleCDMAnchorUpdate()
    C_Timer.After(0.5, UF.ScheduleCDMAnchorUpdate)
end

function UF:CreateCDMAnchor()
    local anchor = _G['NRSKNUF_CDMAnchor']
    if not anchor then
        anchor = CreateFrame('Frame', 'NRSKNUF_CDMAnchor', UIParent)
        anchor:NCSetSize(1, 1)
        anchor:SetPoint('CENTER')
    end
    UF.CDMAnchor = anchor
    anchor:NCSetScheduledUpdate(function()
        NRSKNUI:RunWhenSafe(ApplyCDMAnchorSize)
    end)

    UF:RegisterEvent('PLAYER_ENTERING_WORLD', 'CDMLayoutEvent')
    UF:RegisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED', 'CDMLayoutEvent')
    UF:RegisterEvent('TRAIT_CONFIG_UPDATED', 'CDMLayoutEvent')
    UF:RegisterEvent('EDIT_MODE_LAYOUTS_UPDATED', 'CDMLayoutEvent')
    UF:RegisterMessage('NRSKNUI_CDM_LAYOUT_CHANGED', 'ScheduleCDMAnchorUpdate')
    UF:ScheduleCDMAnchorUpdate()
end
