---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local LSM = NRSKNUI.Libs.LSM

local CreateObjectPool = CreateObjectPool
local CreateFrame = CreateFrame
local strfind = string.find
local gsub = string.gsub
local ipairs = ipairs
local unpack = unpack

local GameTooltip = GameTooltip

local CreateDurationTextBinding = C_DurationUtil and C_DurationUtil.CreateDurationTextBinding
local GetSpellDisplayCount = C_Spell and C_Spell.GetSpellDisplayCount
local GetSpellName = C_Spell and C_Spell.GetSpellName
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture

local BindingProperty = Enum.DurationTextBindingProperty

local WHITE = 'Interface\\Buttons\\WHITE8X8'
local PANDEMIC_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png'
local PANDEMIC_COLOR = { 1, 0.25, 0.25, 1 }
local AURA_FILTERS = { player = 'HELPFUL', target = 'HARMFUL' } -- spellID matching only holds for buffs on friends and debuffs on enemies
local QUESTION_MARK = 134400
local LEVELS_PER_LAYER = 3 -- layer, its cooldown, its texts

-- Text tokens: %p time left and %t total run through a duration binding, %s is the charge count.
local DURATION_TOKENS = { p = BindingProperty.RemainingDuration, t = BindingProperty.TotalDuration }

---@class CDMIconText
---@field fs FontString
---@field binding table? C_DurationUtil duration text binding, for duration texts
---@field kind 'duration'|'charges'|'static'
---@field format string
---@field tokens number how many %s a charges text holds

---One trigger's visuals; the icon stacks one per trigger, trigger 1 on top.
---@class CDMLayer : Frame
---@field owner CDMIcon
---@field Icon Texture
---@field Cooldown Cooldown
---@field textHost Frame
---@field texts CDMIconText[]
---@field textCount number? texts in use, the rest of the pool is hidden
---@field state table trigger state the conditions read
---@field duration LuaDurationObject? what time texts count, without the global cooldown
---@field spellID number?
---@field baseSpellID number?
---@field itemID number? item triggers: the item shown
---@field itemSlot number? item triggers: the equipment slot read
---@field itemFamily number[]? item triggers: the items counted together
---@field itemDuration LuaDurationObject? item triggers: built from plain cooldown numbers
---@field count number? a count to show for %s instead of spell charges
---@field subRegions table[]? the sub elements the layer was last styled with
---@field auraHost Frame? parent of the aura container, for aura triggers
---@field auraContainer table? native AuraContainer with the NorskenUI mixin
---@field auraSlots table<string, { refs: table, index: number }>? one slot per filter string
---@field auraRefs table? the slot on show: its button and the regions we gave it
---@field auraKey string? what the slot was last configured for

---@class CDMIcon : Frame
---@field id string?
---@field layers CDMLayer[]
---@field layerCount number layers in use
---@field activeLayer CDMLayer? the logic layer on show, for the tooltip
---@field overlay Frame borders, above every layer
---@field borders (Frame|BackdropTemplate)[]
---@field style table the icon's style, see CDM:GetStyle
---@field shown boolean loaded or previewed
---@field groupId string?

---@param layer CDMLayer
local function OnCooldownDone(layer)
    local id = layer.owner.id
    if id then CDM:UpdateIcon(id) end
end

---@param frame CDMIcon
local function OnEnter(frame)
    local layer = frame.activeLayer
    if not (frame.style and frame.style.Tooltip and layer and (layer.spellID or layer.itemID)) then return end
    GameTooltip:SetOwner(frame, 'ANCHOR_RIGHT')
    if layer.spellID then
        GameTooltip:SetSpellByID(layer.spellID)
    else
        GameTooltip:SetItemByID(layer.itemID)
    end
    GameTooltip:Show()
end

---@param frame CDMIcon
---@return CDMLayer
local function CreateLayer(frame)
    local layer = CreateFrame('Frame', nil, frame) --[[@as CDMLayer]]
    layer:SetAllPoints()
    layer.owner = frame

    local icon = layer:CreateTexture(nil, 'ARTWORK')
    icon:SetAllPoints()
    icon:NUISetPixelSnap()
    layer.Icon = icon

    local cooldown = CreateFrame('Cooldown', nil, layer, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawBling(false)
    cooldown:SetCountdownFormatter(NRSKNUI:GetAuraDurationFormatter())
    cooldown:SetScript('OnCooldownDone', function() OnCooldownDone(layer) end)
    layer.Cooldown = cooldown

    local textHost = CreateFrame('Frame', nil, layer)
    textHost:SetAllPoints()
    layer.textHost = textHost

    layer.texts = {}
    layer.state = {}
    return layer
end

---@return CDMIcon
local function CreateIcon()
    local frame = CreateFrame('Frame', nil, UIParent) --[[@as CDMIcon]]
    frame:Hide()

    frame.overlay = CreateFrame('Frame', nil, frame)
    frame.overlay:SetAllPoints()

    frame.layers = {}
    frame.layerCount = 0
    frame.borders = {}
    frame:SetScript('OnEnter', OnEnter)
    frame:SetScript('OnLeave', GameTooltip_Hide)

    return frame
end

---@param frame CDMIcon
local function ResetIcon(_, frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    for _, layer in ipairs(frame.layers) do
        layer.Cooldown:Clear()
        layer.duration = nil
        layer.state = {}
        CDM:ReleaseAuraLayer(layer)
    end
    frame.activeLayer = nil
    frame.id = nil
end

local pool = CreateObjectPool(CreateIcon, ResetIcon)

---@param id string
---@return CDMIcon
function CDM:AcquireIcon(id)
    local frame = pool:Acquire()
    frame.id = id
    return frame
end

---@param frame CDMIcon
function CDM:ReleaseIcon(frame)
    pool:Release(frame)
end

---The trigger's texture, unless the style picks one by hand.
---@param layer CDMLayer
---@param texture number?
function CDM:SetIconTexture(layer, texture)
    local style = layer.owner.style
    if style and style.IconSource == 'manual' and style.ManualIcon then texture = style.ManualIcon end
    layer.Icon:SetTexture(texture or QUESTION_MARK)
end

-- Text --

---Does this text use a duration token, and does it also ask for the charge count it can't show with one?
---@param text string
---@return boolean duration, boolean charges
function CDM:ClassifyText(text)
    return strfind(text, '%%[pt]') ~= nil, strfind(text, '%%s') ~= nil
end

---@param layer CDMLayer
---@param index number
---@return CDMIconText
local function AcquireText(layer, index)
    local text = layer.texts[index]
    if not text then
        local fs = layer.textHost:CreateFontString(nil, 'OVERLAY')
        text = { fs = fs, kind = 'static', format = '', tokens = 0 } --[[@as CDMIconText]]
        layer.texts[index] = text
    end
    return text
end

---@param element table
---@param spellName string
---@return string
local function ExpandText(element, spellName)
    return (gsub(element.Text or '', '%%n', (gsub(spellName, '%%', '%%%%'))))
end

---A text with %p/%t as a binding format: '{}' per token, with a component that renders it.
---@param raw string
---@return string format, table[] components
local function DurationFormat(raw)
    local components = {}
    local format = gsub(raw, '%%([pt])', function(token)
        components[#components + 1] = { property = DURATION_TOKENS[token], formatter = NRSKNUI:GetAuraDurationFormatter() }
        return '{}'
    end)
    return (gsub(format, '%%s', '')), components
end

---@param text CDMIconText
---@param element table
---@param spellName string
local function ConfigureText(text, element, spellName)
    local raw = ExpandText(element, spellName)
    local hasDuration, hasCharges = CDM:ClassifyText(raw)

    if hasDuration then
        text.binding = text.binding or CreateDurationTextBinding()
        text.binding:SetFontString(text.fs)
        text.binding:SetTextFormat(DurationFormat(raw))
        text.binding:SetZeroDurationText('')
        text.binding:SetExpiredText('')
        text.binding:SetEnabled(true)
        text.kind = 'duration'
    else
        if text.binding then text.binding:SetToDefaults() end
        if hasCharges then
            -- Every other % is escaped, so only the %s tokens take the count.
            local format, tokens = gsub(gsub(raw, '%%', '%%%%'), '%%%%s', '%%s')
            text.format, text.tokens, text.kind = format, tokens, 'charges'
        else
            text.kind = 'static'
            text.fs:SetText(raw)
        end
    end
end

-- Border --

---@param frame CDMIcon
---@param index number
---@return Frame|BackdropTemplate
local function AcquireBorder(frame, index)
    local border = frame.borders[index]
    if not border then
        border = CreateFrame('Frame', nil, frame.overlay, 'BackdropTemplate')
        frame.borders[index] = border
    end
    return border
end

---@param border Frame|BackdropTemplate
---@param frame CDMIcon
---@param element table
local function ConfigureBorder(border, frame, element)
    local offset = element.Offset or 0
    border:ClearAllPoints()
    border:NUISetPixelPoint('TOPLEFT', frame, 'TOPLEFT', -offset, offset)
    border:NUISetPixelPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', offset, -offset)

    local edgeFile = element.Style == 'Pixel' and WHITE or LSM:Fetch('border', element.Style)
    border:SetBackdrop({ edgeFile = edgeFile, edgeSize = element.Size or 1 })
    border:SetBackdropBorderColor(unpack(element.Color))
end

-- Style --

---Crop the icon to its frame's shape, so a wide icon isn't stretched.
---@param texture Texture
---@param style table
local function ApplyTexCoords(texture, style)
    local margin = 0.25 * (style.Zoom or NRSKNUI.GlobalZoom)
    local left, right, top, bottom = margin, 1 - margin, margin, 1 - margin
    if style.KeepAspectRatio and style.Width ~= style.Height then
        local span = 1 - 2 * margin
        if style.Width > style.Height then
            local cut = span * (1 - style.Height / style.Width) / 2
            top, bottom = top + cut, bottom - cut
        else
            local cut = span * (1 - style.Width / style.Height) / 2
            left, right = left + cut, right - cut
        end
    end
    texture:SetTexCoord(left, right, top, bottom)
end

---@param layer CDMLayer
---@param style table
---@param subRegions table[]
---@param spellName string
local function StyleLayer(layer, style, subRegions, spellName)
    local icon = layer.Icon
    ApplyTexCoords(icon, style)
    icon:SetVertexColor(unpack(style.Color))

    local cooldown = layer.Cooldown
    cooldown:SetDrawSwipe(style.DrawSwipe)
    cooldown:SetDrawEdge(style.DrawEdge)
    cooldown:SetReverse(style.Reverse)
    cooldown:SetSwipeColor(unpack(style.SwipeColor))
    cooldown:SetHideCountdownNumbers(style.HideCountdown)

    layer.subRegions = subRegions
    local textCount = 0
    for _, element in ipairs(subRegions) do
        if element.type == 'text' then
            textCount = textCount + 1
            local fs = AcquireText(layer, textCount).fs
            fs:SetFontStyle(element, element.FontSize, nil, nil, true)
            fs:SetFontJustify(element, layer, element.Position.XOffset, element.Position.YOffset, true)
            fs:SetTextColor(unpack(element.Color))
            fs:SetShown(element.Enabled)
            ConfigureText(layer.texts[textCount], element, spellName)
        end
    end

    for i = textCount + 1, #layer.texts do
        local text = layer.texts[i]
        if text.binding then text.binding:SetToDefaults() end
        text.fs:Hide()
    end
    layer.textCount = textCount
end

---@param frame CDMIcon
---@param display table
---@param style table
function CDM:StyleIcon(frame, display, style)
    frame:NUISetPixelSize(style.Width, style.Height)
    frame:SetAlpha(style.Alpha)
    frame:EnableMouse(style.Tooltip == true)

    local subRegions = display.SubRegions or {}
    local triggers = display.Triggers
    local count = #triggers
    local base = frame:GetFrameLevel()
    for i, trigger in ipairs(triggers) do
        local layer = frame.layers[i]
        if not layer then
            layer = CreateLayer(frame)
            frame.layers[i] = layer
        end
        local level = base + 1 + (count - i) * LEVELS_PER_LAYER
        layer:SetFrameLevel(level)
        layer.Cooldown:SetFrameLevel(level + 1)
        layer.textHost:SetFrameLevel(level + 2)
        StyleLayer(layer, style, subRegions, CDM:GetTriggerName(trigger) or '')
    end
    for i = count + 1, #frame.layers do
        local layer = frame.layers[i]
        layer.Cooldown:Clear()
        layer:Hide()
    end
    frame.layerCount = count
    frame.overlay:SetFrameLevel(base + 1 + count * LEVELS_PER_LAYER)

    local borderCount = 0
    for _, element in ipairs(subRegions) do
        if element.type == 'border' then
            borderCount = borderCount + 1
            local border = AcquireBorder(frame, borderCount)
            ConfigureBorder(border, frame, element)
            border:SetShown(element.Enabled)
        end
    end
    for i = borderCount + 1, #frame.borders do frame.borders[i]:Hide() end
end

---Feed a layer's texts its trigger's latest timing and charges.
---@param layer CDMLayer
function CDM:UpdateTexts(layer)
    local charges = layer.count or (layer.state.hasCharges and layer.spellID and GetSpellDisplayCount(layer.spellID)) or nil
    for i = 1, layer.textCount or 0 do
        local text = layer.texts[i]
        if text.kind == 'duration' then
            if layer.duration then text.binding:SetDuration(layer.duration) end
        elseif text.kind == 'charges' then
            if charges then
                text.fs:SetFormattedText(text.format, charges, charges, charges, charges) -- extra arguments are ignored
            else
                text.fs:SetText('')
            end
        end
    end
end

-- Aura layers --
-- An aura trigger draws through a one-slot native AuraContainer: the client shows the slot while the
-- aura is up, so nothing secret ever reaches Lua and the layer simply covers the triggers below it.

local targetContainers = {} ---@type table<table, true> containers following the target

-- AddSlot hands back a secret-wrapped button, so everything is reached through the refs filled in here,
-- the one place the real button is passed to us.
---@param button table native AuraButton
---@param host Frame
---@param refs table
local function InitAuraButton(button, host, refs)
    button:SetAllPoints(host)
    button:EnableMouse(false)
    refs.button = button

    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetAllPoints()
    refs.icon = icon
    button:SetIcon(icon)

    local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    refs.cooldown = cooldown
    button:SetDurationCooldown(cooldown)

    local textHost = CreateFrame('Frame', nil, button)
    textHost:SetAllPoints()
    textHost:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    refs.textHost = textHost
    refs.time = textHost:CreateFontString(nil, 'OVERLAY')
    refs.count = textHost:CreateFontString(nil, 'OVERLAY')
    refs.static = {}

    local pandemic = textHost:CreateTexture(nil, 'OVERLAY')
    pandemic:SetTexture(PANDEMIC_TEXTURE)
    pandemic:SetAllPoints()
    pandemic:SetVertexColor(unpack(PANDEMIC_COLOR))
    refs.pandemic = pandemic
    button:AddPandemicRegion(pandemic)
end

---@param fs FontString
---@param element table
---@param button table
local function StyleAuraText(fs, element, button)
    fs:SetFontStyle(element, element.FontSize, nil, nil, true)
    fs:SetFontJustify(element, button, element.Position.XOffset, element.Position.YOffset, true)
    fs:SetTextColor(unpack(element.Color))
end

---Style the slot on show from the icon's style and its sub elements: the first %p/%t text becomes the
---native duration text, the first %s text its stack count, the rest stay plain.
---@param layer CDMLayer
---@param trigger table
function CDM:StyleAuraButton(layer, trigger)
    local refs = layer.auraRefs
    local style = layer.owner.style
    if not (refs and refs.button and style) then return end
    local button = refs.button

    local icon = refs.icon
    ApplyTexCoords(icon, style)
    icon:SetVertexColor(unpack(style.Color))
    icon:SetDesaturated(style.Desaturate == true)
    if trigger.UseSpellIcon and trigger.SpellID then
        button:ClearIcon()
        icon:SetTexture(GetSpellTexture(trigger.SpellID) or QUESTION_MARK)
    else
        button:SetIcon(icon)
    end

    local cooldown = refs.cooldown
    cooldown:SetDrawSwipe(style.DrawSwipe)
    cooldown:SetDrawEdge(style.DrawEdge)
    cooldown:SetReverse(style.Reverse)
    cooldown:SetSwipeColor(unpack(style.SwipeColor))
    cooldown:SetHideCountdownNumbers(style.HideCountdown)

    refs.pandemic:SetAlpha(trigger.Pandemic and 1 or 0)

    local spellName = trigger.SpellID and GetSpellName(trigger.SpellID) or ''
    local hasTime, hasCount, staticCount = false, false, 0
    for _, element in ipairs(layer.subRegions or {}) do
        if element.type == 'text' and element.Enabled then
            local raw = ExpandText(element, spellName)
            local isDuration, isCount = CDM:ClassifyText(raw)
            if isDuration and not hasTime then
                hasTime = true
                StyleAuraText(refs.time, element, button)
                local format, components = DurationFormat(raw)
                button:SetDurationText(refs.time, { textFormat = { formatString = format, components = components } })
                refs.time:Show()
            elseif isCount and not hasCount and not isDuration then
                hasCount = true
                StyleAuraText(refs.count, element, button)
                button:SetApplicationCount(refs.count, {})
                refs.count:Show()
            elseif not isDuration and not isCount then
                staticCount = staticCount + 1
                local fs = refs.static[staticCount]
                if not fs then
                    fs = refs.textHost:CreateFontString(nil, 'OVERLAY')
                    refs.static[staticCount] = fs
                end
                StyleAuraText(fs, element, button)
                fs:SetText(raw)
                fs:Show()
            end
        end
    end

    if not hasTime then
        button:ClearDurationText()
        refs.time:Hide()
    end
    if not hasCount then
        button:ClearApplicationCount()
        refs.count:Hide()
    end
    for i = staticCount + 1, #refs.static do refs.static[i]:Hide() end
end

---Point a layer's aura slot at its trigger; builds the container on first use. Out of combat only.
---@param layer CDMLayer
---@param trigger table
---@param spellIDs table<number, true>
function CDM:ConfigureAuraLayer(layer, trigger, spellIDs)
    local unit = trigger.Unit == 'target' and 'target' or 'player'
    local filter = AURA_FILTERS[unit]
    local candidates = { includeSpellIDs = spellIDs, isFromPlayerOrPlayerPet = trigger.OwnOnly or nil }

    if not layer.auraHost then
        layer.auraHost = CreateFrame('Frame', nil, layer)
        layer.auraHost:SetAllPoints()
        layer.auraContainer = layer.auraHost:CreateAuraContainer({ disableMouse = true })
        layer.auraSlots = {}
    end
    local container = layer.auraContainer
    layer.auraHost:Show()

    local slot = layer.auraSlots[filter]
    if slot then
        container:SetSlotCandidates(slot.index, candidates)
    else
        local host, refs = layer.auraHost, {}
        local _, _, index = container:AddSlot(filter, {
            candidateFilters = candidates,
            initializeFrame = function(created) InitAuraButton(created, host, refs) end,
        })
        slot = { refs = refs, index = index }
        layer.auraSlots[filter] = slot
    end
    for key, other in pairs(layer.auraSlots) do container:SetSlotShown(other.index, key == filter) end
    layer.auraRefs = slot.refs

    container:SetEnabled(true)
    container:SetUnit(unit)
    container:UpdateUnitGate()
    container:UpdateAllAuras()
    targetContainers[container] = unit == 'target' or nil

    self:StyleAuraButton(layer, trigger)
end

---Stop a layer's aura container, when its trigger is no longer an aura or its icon goes back to the pool.
---@param layer CDMLayer
function CDM:ReleaseAuraLayer(layer)
    local container = layer.auraContainer
    if not container then return end
    layer.auraHost:Hide()
    layer.auraKey = nil
    targetContainers[container] = nil
    NRSKNUI:RunWhenSafe(function()
        if not layer.auraKey then container:SetEnabled(false) end
    end)
end

-- The container doesn't follow target changes on its own (Blizzard_AuraContainer.lua, live).
local targetWatcher = CreateFrame('Frame')
targetWatcher:RegisterEvent('PLAYER_TARGET_CHANGED')
targetWatcher:SetScript('OnEvent', function()
    for container in pairs(targetContainers) do
        container:UpdateUnitGate()
        container:UpdateAllAuras()
    end
end)
