-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("CDM: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CDM = NRSKNUI.Addon:NewModule("CDM", "AceEvent-3.0")

-- Localization
local hooksecurefunc = hooksecurefunc
local next = next
local CreateFrame = CreateFrame
local unpack = unpack
local pairs = pairs
local SecureCmdOptionParse = SecureCmdOptionParse
local _G = _G

-- Module init
function CDM:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.CDM
    self:SetEnabledState(false)
end

-- Get spellInfo
local function getSpellID(button)
    local cooldownInfo = button:GetCooldownInfo()
    return cooldownInfo and (cooldownInfo.overrideSpellID or cooldownInfo.spellID)
end

-- Get cooldownInfo
local function updateCooldown(button)
    local duration, charge
    local cooldown
    local spellID = getSpellID(button)
    if spellID then
        charge = C_Spell.GetSpellChargeDuration(spellID)
        cooldown = C_Spell.GetSpellCooldown(spellID)
        if cooldown then
            duration = C_Spell.GetSpellCooldownDuration(spellID)
        end
    end

    -- Reset before trying to render the "cooldown state",
    -- Wont work with procs that can reset cooldowns otherwise
    button.CustomCooldown:Hide()
    button.Icon:SetDesaturation(0)
    button:SetAlpha(1)

    -- Check if any cooldown is active
    if charge or duration then
        button.CustomCooldown:SetCooldownFromDurationObject(charge or duration)

        -- Only desaturate for non-GCD cooldowns
        if duration and not (cooldown and cooldown.isOnGCD) then
            button.Icon:SetDesaturation(duration:EvaluateRemainingDuration(NRSKNUI.curves.ActionDesaturation))
        end
    end
end

-- Update cooldown icon
local function updateCooldownIcon(icon)
    updateCooldown(icon:GetParent())
end

-- Skin function
-- Very lightweight skinning so that it can work together with BCDM
local skinned = {}
local function skin(group, _, button)
    if skinned[button] then
        return
    else
        skinned[button] = true
    end
    local fontPath = NRSKNUI:GetFontPath(CDM.db.FontFace)

    -- hide overlay texture
    for _, child in next, { button:GetRegions() } do
        if child.GetAtlas and child:GetAtlas() == 'UI-HUD-CoolDownManager-IconOverlay' then
            child:SetAlpha(0)
        end
    end
    if button.DebuffBorder then
        button.DebuffBorder:SetAlpha(0)
    end

    -- Make cooldown animations ignore parent alpha
    if button.CooldownFlash then
        button.CooldownFlash:SetIgnoreParentAlpha(true)
    end

    -- Re-anchor and change font of charges
    if button.ChargeCount then
        button.ChargeCount.Current:ClearAllPoints()
        button.ChargeCount.Current:SetPoint('CENTER', button.Icon, 'TOP')
        button.ChargeCount.Current:SetFont(fontPath, CDM.db.Charges.Size, CDM.db.FontOutline)
        button.ChargeCount.Current:SetTextColor(unpack(CDM.db.Charges.FontColor))
    end

    -- Re-anchor and change font of applications
    if button.Applications then
        button.Applications.Applications:ClearAllPoints()
        button.Applications.Applications:SetPoint('CENTER', button.Icon, 'TOP')
        button.Applications.Applications:SetFont(fontPath, CDM.db.Charges.Size, CDM.db.FontOutline)
        button.Applications.Applications:SetTextColor(unpack(CDM.db.Charges.FontColor))
    end

    if button.RefreshSpellCooldownInfo then
        -- Remove the default cooldown widget as it also tracks buff/debuff uptime
        NRSKNUI:Hide(button, 'Cooldown')

        -- Prevent CDM from messing with desaturation
        hooksecurefunc(button.Icon, 'SetDesaturated', updateCooldownIcon) -- can't just noop it, that taints

        -- Add custom cooldown widget
        button.CustomCooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
        button.CustomCooldown:SetFrameStrata("LOW")
        button.CustomCooldown:SetAllPoints(button)
        button.CustomCooldown:SetDrawEdge(false)
        button.CustomCooldown:SetDrawBling(false)
        button.CustomCooldown:SetSwipeColor(0, 0, 0, 0.9)
        button.CustomCooldown:SetMinimumCountdownDuration(true and 1500 or 0)
        button.CustomCooldown:GetRegions():SetFont(fontPath,
            group == 'EssentialCooldownViewer' and CDM.db.Cooldown.SizeEssentials or CDM.db.Cooldown.SizeUtil,
            CDM.db.FontOutline)
        button.CustomCooldown:GetRegions():SetShadowOffset(0, 0)
        button.CustomCooldown:GetRegions():SetTextColor(unpack(CDM.db.Cooldown.FontColor))

        -- Update cooldowns
        hooksecurefunc(button, 'RefreshSpellCooldownInfo', updateCooldown)
        hooksecurefunc(button, 'RefreshSpellChargeInfo', updateCooldown)
        hooksecurefunc(button, 'RefreshIconDesaturation', updateCooldown)
        hooksecurefunc(button, 'RefreshIconColor', updateCooldown)
    else
        -- Re-anchor existing cooldown widget and adjust swipe texture
        button.Cooldown:SetAllPoints(button.Icon)
        button.Cooldown:SetSwipeTexture("Interface\\ChatFrame\\ChatFrameBackground")
    end
end

-- Update function for GUI changes
function CDM:UpdateSettings()
    if not self:IsEnabled() then return end
    local fontPath = NRSKNUI:GetFontPath(self.db.FontFace)

    -- Update all currently active CDM frames
    for _, group in next, {
        'EssentialCooldownViewer',
        'UtilityCooldownViewer',
        'BuffIconCooldownViewer',
    } do
        local viewer = _G[group]
        if viewer then
            for _, button in next, viewer:GetItemFrames() do
                -- Update charge count font
                if button.ChargeCount and button.ChargeCount.Current then
                    button.ChargeCount.Current:SetFont(
                        fontPath,
                        self.db.Charges.Size,
                        self.db.FontOutline
                    )
                    button.ChargeCount.Current:SetTextColor(unpack(CDM.db.Charges.FontColor))
                end

                -- Update applications font
                if button.Applications and button.Applications.Applications then
                    button.Applications.Applications:SetFont(
                        fontPath,
                        self.db.Charges.Size,
                        self.db.FontOutline
                    )
                    button.Applications.Applications:SetTextColor(unpack(CDM.db.Charges.FontColor))
                end

                -- Update custom cooldown font
                if button.CustomCooldown then
                    local size = group == 'EssentialCooldownViewer'
                        and self.db.Cooldown.SizeEssentials
                        or self.db.Cooldown.SizeUtil

                    button.CustomCooldown:GetRegions():SetFont(
                        fontPath,
                        size,
                        self.db.FontOutline
                    )
                    button.CustomCooldown:GetRegions():SetTextColor(unpack(CDM.db.Cooldown.FontColor))
                end
            end
        end
    end
end

-- Skin init
local function initCDMSkin()
    local stateFrames = {} -- Store state frames to update them later

    for _, group in next, {
        'EssentialCooldownViewer',
        'UtilityCooldownViewer',
        'BuffIconCooldownViewer',
    } do
        local viewer = _G[group]
        if not viewer then break end

        -- Create state handler frame for alpha control
        local stateFrame = CreateFrame('Frame', 'NRSKNUI_CDM_' .. group .. '_StateFrame', UIParent,
            'SecureHandlerStateTemplate')
        stateFrame:SetSize(1, 1)
        stateFrame:Hide()
        stateFrames[group] = stateFrame

        -- Store references
        stateFrame.viewer = viewer
        stateFrame.group = group

        -- State change handler
        stateFrame:SetAttribute('_onstate-cdmalphastate', [[
            self:CallMethod('OnAlphaStateChange', newstate)
        ]])

        -- Lua callback for state changes
        function stateFrame:OnAlphaStateChange(state)
            self.currentState = state -- Store current state for live updates
            local v = self.viewer
            if not v then return end

            if state == 'reduced' then
                -- In petbattle/bonusbar - use reduced alpha from DB
                local alpha = CDM.db.AlphaMountPet or 0.5
                v:SetAlpha(alpha)
                -- Update button borders
                for _, button in next, v:GetItemFrames() do
                    if button.SetBorderIgnoreParentAlpha then
                        button:SetBorderIgnoreParentAlpha(alpha < 1)
                    end
                end
            else
                -- Normal state - full alpha
                v:SetAlpha(1)
                for _, button in next, v:GetItemFrames() do
                    if button.SetBorderIgnoreParentAlpha then
                        button:SetBorderIgnoreParentAlpha(false)
                    end
                end
            end
        end

        -- Function to update the state driver based on DB setting
        local function updateStateDriver()
            if CDM.db.AlphaoutMountPet then
                RegisterStateDriver(stateFrame, 'cdmalphastate', '[petbattle][bonusbar:5] reduced; normal')
            else
                UnregisterStateDriver(stateFrame, 'cdmalphastate')
                -- Reset to full alpha when feature disabled
                viewer:SetAlpha(1)
                for _, button in next, viewer:GetItemFrames() do
                    if button.SetBorderIgnoreParentAlpha then
                        button:SetBorderIgnoreParentAlpha(false)
                    end
                end
            end
        end

        -- Initial setup
        updateStateDriver()

        -- Hook skin function
        hooksecurefunc(viewer, 'OnAcquireItemFrame', GenerateClosure(skin, group))
    end

    -- Store update function for later use in the GUI (toggle on/off)
    CDM.UpdateMountPetAlpha = function()
        -- Check current state using macro conditional
        local currentState = SecureCmdOptionParse('[petbattle][bonusbar:5] reduced; normal')

        for group, stateFrame in pairs(stateFrames) do
            local viewer = _G[group]
            if viewer then
                if CDM.db.AlphaoutMountPet then
                    RegisterStateDriver(stateFrame, 'cdmalphastate', '[petbattle][bonusbar:5] reduced; normal')
                    -- Immediately apply current state
                    stateFrame:OnAlphaStateChange(currentState)
                else
                    UnregisterStateDriver(stateFrame, 'cdmalphastate')
                    -- Reset to full alpha when feature disabled
                    stateFrame.currentState = 'normal'
                    viewer:SetAlpha(1)
                    for _, button in next, viewer:GetItemFrames() do
                        if button.SetBorderIgnoreParentAlpha then
                            button:SetBorderIgnoreParentAlpha(false)
                        end
                    end
                end
            end
        end
    end

    -- Live update function for alpha slider changes
    CDM.UpdateMountPetAlphaValue = function()
        for group, stateFrame in pairs(stateFrames) do
            -- Only update if we're currently in reduced state
            if stateFrame.currentState == 'reduced' then
                local viewer = _G[group]
                if viewer then
                    local alpha = CDM.db.AlphaMountPet or 0.5
                    viewer:SetAlpha(alpha)
                    for _, button in next, viewer:GetItemFrames() do
                        if button.SetBorderIgnoreParentAlpha then
                            button:SetBorderIgnoreParentAlpha(alpha < 1)
                        end
                    end
                end
            end
        end
    end
end

-- Module OnEnable
function CDM:OnEnable()
    if not self.db.Enabled then return end
    initCDMSkin()
end
