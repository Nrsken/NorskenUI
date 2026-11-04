---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

local tconcat, tsort = table.concat, table.sort
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local format = string.format
local tostring = tostring
local GetTime = GetTime
local ceil = math.ceil
local unpack = unpack
local next = next

local NewTimer = C_Timer and C_Timer.NewTimer

local IsPreviewing, PreviewDuration = CDM.IsPreviewingLayer, CDM.PreviewDuration
local PREVIEW_LENGTH, PREVIEW_PANDEMIC = CDM.PREVIEW_LENGTH, CDM.PREVIEW_PANDEMIC
local QUESTION_MARK = 134400

--[[
Aura and Aura Overlay triggers. The game shows the aura through an aura button and never tells us it's up,
so this file points the button at its spells and draws the options preview and placeholder with the layer's own parts.
]]

-- Restyle --

---Restyle a layer's aura button now or once the restriction lifts: existing buttons deny tainted access while
---auras are secret, not just in combat. The restriction queue keeps every entry, so a layer waits there once with its latest.
---@param layer CDMLayer
---@param restyle fun()
function CDM:QueueAuraRestyle(layer, restyle)
    if not NRSKNUI:AreAurasSecret() then
        restyle()
        return
    end

    layer.restyleAura = restyle
    if NRSKNUI:IsRestricted() and not layer.restyleQueued then
        layer.restyleQueued = true
        NRSKNUI:DeferUntilUnrestricted(0, function()
            layer.restyleQueued = nil
            local queued = layer.restyleAura
            layer.restyleAura = nil
            if queued then
                queued()
            end
        end)
    end
end

-- Stand-in --

---A lone aura layer's own parts, the preview stand-in or its placeholder: the style, with `changes` over it.
---@param layer CDMLayer
---@param display table
---@param style table
---@param changes table<string, any> a placeholder's While Missing changes, empty for the plain style
---@param textsShown boolean whether texts nothing changes show by their own Enabled (a placeholder's start hidden)
local function PaintStandIn(layer, display, style, changes, textsShown)
    local alpha = changes.alpha or 1
    local desaturate = changes.desaturate
    if desaturate == nil then
        desaturate = style.Desaturate
    end
    layer.Icon:SetVertexColor(unpack(changes.color or style.Color))
    layer.Icon:SetDesaturated(desaturate == true)
    layer.Icon:SetAlpha(alpha)
    layer.borderHost:SetAlpha(alpha)
    layer.textHost:SetAlpha(alpha)
    if layer.isBar then
        layer.Bar:SetAlpha(alpha)
        layer.Bar.bg:SetVertexColor(unpack(changes.backgroundColor or style.BackgroundColor))
    end
    local borders, texts = 0, 0
    for n, element in ipairs(display.SubRegions or {}) do
        local visible = changes['sub.' .. n .. '.visible']
        local color = changes['sub.' .. n .. '.color'] or element.Color
        if element.type == 'border' then
            borders = borders + 1
            local border = layer.borders[borders]
            if border then
                if visible == nil then
                    visible = element.Enabled
                end
                border:SetShown(visible == true)
                for _, edge in ipairs(border.edges) do
                    edge:SetColorTexture(unpack(color))
                end
            end
        elseif element.type == 'text' then
            texts = texts + 1
            local text = layer.texts[texts]
            if text then
                if visible == nil then
                    visible = textsShown and element.Enabled
                end
                text.fs:SetShown(visible == true)
                text.fs:SetTextColor(unpack(color))
            end
        end
    end
end

---The aura spell IDs a trigger watches: a Cooldown Manager entry's spell and its linked spells, or a custom list.
---@param trigger table
---@return table<number, true>? spellIDs
function CDM:GetAuraSpellIDs(trigger)
    local ids = {}
    if trigger.Source == 'custom' then
        for _, spellID in ipairs(trigger.SpellIDs or {}) do
            ids[spellID] = true
        end
    else
        local info = trigger.CooldownID and self.Catalogue:GetEntry(trigger.CooldownID)
        if info then
            if info.spellID then
                ids[info.spellID] = true
            end
            if info.overrideSpellID then
                ids[info.overrideSpellID] = true
            end
            for _, linked in ipairs(info.linkedSpellIDs or {}) do
                ids[linked] = true
            end
        elseif trigger.SpellID then
            ids[trigger.SpellID] = true
        end
    end
    if next(ids) == nil then return nil end
    return ids
end

---What an aura slot is configured for, so an unchanged trigger skips the out-of-combat rebuild.
---@param trigger table
---@param spellIDs table<number, true>
---@return string
local function AuraKey(trigger, spellIDs)
    local ids = {}
    for spellID in pairs(spellIDs) do
        ids[#ids + 1] = spellID
    end
    tsort(ids)
    return tconcat(ids, ',') .. '|' .. tostring(trigger.Unit) .. '|' .. tostring(trigger.OwnOnly)
end

-- Trigger --

-- Secret: we never learn whether the aura is up; the layer's slot shows itself while it is.
CDM.TriggerTypes.aura = {
    Secret = true,

    ---@param trigger table
    ---@return boolean
    IsKnown = function(trigger) return CDM:GetAuraSpellIDs(trigger) ~= nil end,

    ---@param layer CDMLayer
    ---@param trigger table
    Resolve = function(layer, trigger)
        local spellIDs = CDM:GetAuraSpellIDs(trigger)
        if not spellIDs then
            CDM:ReleaseAuraLayer(layer)
            return
        end

        local key = AuraKey(trigger, spellIDs)
        local configured = layer.auraKey == key
        layer.auraKey = key
        local function Restyle()
            if layer.auraKey == key then
                CDM:StyleAuraButton(layer, trigger)
            end
        end
        local function Apply()
            if layer.auraKey ~= key then return end
            if not configured then
                CDM:ConfigureAuraLayer(layer, trigger, spellIDs)
            end
            if configured or NRSKNUI:AreAurasSecret() then
                CDM:QueueAuraRestyle(layer, Restyle)
            end
        end
        -- Re-resolved on every catalogue change: a fresh closure each time would pile up in the combat queue.
        layer.applyAura = Apply
        layer.runAura = layer.runAura or function()
            local apply = layer.applyAura
            layer.applyAura = nil
            if apply then
                apply()
            end
        end
        NRSKNUI:RunWhenSafe(layer.runAura)
    end,

    -- The container only shows real auras; the options preview fakes one with the layer's own spare parts.
    ---@param layer CDMLayer
    ---@param style table
    ---@param trigger table
    Update = function(layer, style, trigger)
        CDM:SetStackTicks(layer, trigger)
        local preview = IsPreviewing(layer)
        local display = layer.owner.id and CDM:Get(layer.owner.id)
        local active, pandemicColor, pandemic, missing = {}, nil, {}, {}
        if display then
            active, pandemicColor, pandemic, missing = CDM:GetAuraConditionChanges(display, layer.index)
        end
        local overlay = trigger.Type == 'auraoverlay'
        local showIcon = not overlay or active.auraIcon == true
        layer.Icon:SetShown(preview and showIcon and CDM:ShowsIcon(layer, style, display))
        layer.Cooldown:SetShown(preview and showIcon)
        layer.textHost:SetShown(preview)
        layer.borderHost:SetShown(preview and not overlay)
        if layer.isBar then
            layer.Bar:SetShown(preview)
        end
        if layer.auraHost then
            layer.auraHost:SetShown(not preview and layer.auraKey ~= nil)
        end
        if overlay and display and display.type == 'bar' and (preview or layer.previewOverlayShown) then
            layer.previewOverlay = layer.previewOverlay or {}
            CDM:PaintBarOverlay(layer, layer.previewOverlay, layer, preview and active or {})
            layer.previewOverlayShown = preview
        end
        if layer.previewPandemicTimer then
            layer.previewPandemicTimer:Cancel()
            layer.previewPandemicTimer = nil
        end
        if not preview then
            if layer.previewPandemic then
                layer.previewPandemic:Hide()
            end
            for _, glow in ipairs(layer.glows) do
                glow:Stop()
            end
            if trigger.Placeholder and not overlay and display then
                -- The layer's own parts under the aura button, which covers them while it's up; While Missing is read onto them once.
                CDM:SetIconTexture(layer, CDM:GetTriggerTexture(trigger))
                layer.Icon:SetShown(CDM:ShowsIcon(layer, style, display))
                PaintStandIn(layer, display, style, missing, false)
                layer.Cooldown:Clear()
                layer.borderHost:Show()
                layer.textHost:Show()
                if layer.isBar then
                    layer.Bar:SetMinMaxValues(0, 1)
                    layer.Bar:SetValue(0)
                    layer.Bar.spark:SetAlpha(0)
                    layer.Bar:Show()
                end
            end
            return
        end

        if overlay then
            layer.Icon:SetAlpha(1)
            layer.Icon:SetTexture(active.auraTexture or CDM:GetTriggerTexture(trigger) or QUESTION_MARK)
        else
            CDM:SetIconTexture(layer, CDM:GetTriggerTexture(trigger))
            if display then
                PaintStandIn(layer, display, style, {}, true)
            end
        end
        layer.duration = PreviewDuration(layer, PREVIEW_LENGTH)
        CDM:SetLayerTimer(layer, layer.duration)
        layer.Cooldown:SetShown(showIcon) -- setting a timer shows a Cooldown frame again
        layer.count = 1
        if layer.isBar and trigger.BarMode == 'stacks' then
            -- An explicit value takes the bar off the preview timer; the timer still loops the stand-in.
            local maxStacks = CDM:GetMaxStacks(layer, trigger)
            layer.count = ceil(maxStacks * 0.6)
            layer.Bar:SetMinMaxValues(0, maxStacks)
            layer.Bar:SetValue(layer.count)
            layer.Bar.spark:SetAlpha(1)
        end
        if overlay and showIcon then
            local desaturate, swipe, reverse = active.auraDesaturate, active.auraSwipe, active.auraInverse
            if desaturate == nil then
                desaturate = style.Desaturate
            end
            if swipe == nil then
                swipe = style.DrawSwipe
            end
            if reverse == nil then
                reverse = style.Reverse
            end
            layer.Icon:SetVertexColor(unpack(active.auraColor or style.Color))
            layer.Icon:SetDesaturated(desaturate == true)
            layer.Cooldown:SetDrawSwipe(swipe == true)
            layer.Cooldown:SetReverse(reverse == true)
        end
        CDM:UpdateTexts(layer)
        if overlay and display then
            local ordinal = 0
            for index, element in ipairs(display.SubRegions or {}) do
                if element.type == 'text' then
                    ordinal = ordinal + 1
                    local text = layer.texts[ordinal]
                    if text then
                        text.fs:SetShown(active['sub.' .. index .. '.visible'] == true)
                    end
                end
            end
        end

        local window = PREVIEW_LENGTH * PREVIEW_PANDEMIC
        local remaining = layer.previewEnd - GetTime()
        local inWindow = remaining <= window

        -- The stand-in shows a glow element as the aura would: its own Enabled, while active, in the window.
        local hasPandemicGlow = false
        for key in pairs(pandemic) do
            if key:find('%.visible$') then
                hasPandemicGlow = true
                break
            end
        end
        if display then
            for index, element in ipairs(display.SubRegions or {}) do
                if element.type == 'glow' then
                    local key = 'sub.' .. index .. '.visible'
                    local shown = active[key]
                    if shown == nil then
                        shown = not overlay and element.Enabled
                    end
                    if inWindow and pandemic[key] then
                        shown = true
                    end
                    local glow = layer.glows[CDM:GlowOrdinal(display, index)]
                    if glow and shown then
                        glow:Start(element, style.Width, style.Height)
                    elseif glow then
                        glow:Stop()
                    end
                end
            end
        end
        if (pandemicColor or hasPandemicGlow) and not inWindow then
            layer.previewPandemicTimer = NewTimer(remaining - window, function()
                layer.previewPandemicTimer = nil
                CDM:UpdateLayer(layer)
            end)
        end

        local border = layer.previewPandemic
        if not pandemicColor then
            if border then
                border:Hide()
            end
            return
        end
        if not border then
            local host = CreateFrame('Frame', nil, layer)
            host:SetAllPoints()
            border = host:CreateTexture(nil, 'OVERLAY')
            border:SetTexture(CDM.PANDEMIC_TEXTURE)
            border:NUISetPixelInside(layer)
            layer.previewPandemic = border
        end
        border:GetParent():SetFrameLevel(layer:GetFrameLevel() + 2) -- over the swipe, under the sub elements
        border:SetVertexColor(unpack(pandemicColor))
        border:SetShown(inWindow)
    end,

    IsActive = function() return false end,
}
CDM.TriggerTypes.auraoverlay = CDM.TriggerTypes.aura

---@param i number
---@param trigger table
---@param warnings string[]
CDM.TriggerTypes.aura.Warnings = function(i, trigger, warnings)
    if trigger.Source == 'custom' then
        if not (trigger.SpellIDs and trigger.SpellIDs[1]) then
            warnings[#warnings + 1] = format(L['Trigger %d: no aura spell IDs.'], i)
        end
        for _, spellID in ipairs(trigger.SpellIDs or {}) do
            CDM:WarnUnknownSpell(warnings, i, spellID)
        end
    elseif not (trigger.CooldownID or trigger.SpellID) then
        warnings[#warnings + 1] = format(L['Trigger %d: no aura chosen.'], i)
    end
end

-- Conditions --

-- A lone aura is the icon, so only its pandemic window, its time's colour and its placeholder's look are left; an overlay draws nothing until While Up adds to it.
CDM.ConditionChecks.aura = {
    pandemic  = { type = 'bool', secret = true },
    missing   = { type = 'bool', secret = true },
    remaining = { type = 'number', curve = true },
    stacks    = { type = 'number', curve = true },
}

CDM.ConditionChecks.auraoverlay = {
    active    = { type = 'bool', secret = true },
    pandemic  = { type = 'bool', secret = true },
    remaining = { type = 'number', curve = true },
    stacks    = { type = 'number', curve = true },
}
