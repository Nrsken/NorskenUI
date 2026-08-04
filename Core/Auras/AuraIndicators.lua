---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuraIndicators
local AuraIndicators = {}
NRSKNUI.AuraIndicators = AuraIndicators
local L = NRSKNUI.Libs.AL

local tsort, tremove = table.sort, table.remove
local ipairs, pairs = ipairs, pairs
local format = string.format
local CopyTable = CopyTable
local tonumber = tonumber
local CreateFrame = CreateFrame
local type = type
local CheckSetAtlas = CheckSetAtlas

local DISPEL_BORDER_ATLAS = 'RaidFrame-DispelHighlight'

AuraIndicators.Styles = {
    Overlay = 'Overlay',
    Square = 'Square',
    Icon = 'Icon',
    Duration = 'Duration',
    DispelBorder = 'DispelBorder',
    DispelOverlay = 'DispelOverlay',
}

-- Styles that cover their attach target whole, so they have neither size nor offset of their own.
AuraIndicators.FullCover = {
    [AuraIndicators.Styles.Overlay] = true,
    [AuraIndicators.Styles.DispelOverlay] = true,
    [AuraIndicators.Styles.DispelBorder] = true,
}

-- Styles with a width and height of their own.
AuraIndicators.Sized = {
    [AuraIndicators.Styles.Square] = true,
    [AuraIndicators.Styles.Icon] = true,
}

-- The dispel styles are left out: their artwork is whatever a live aura's dispel type gives them.
AuraIndicators.Previewable = {
    [AuraIndicators.Styles.Overlay] = true,
    [AuraIndicators.Styles.Square] = true,
    [AuraIndicators.Styles.Icon] = true,
    [AuraIndicators.Styles.Duration] = true,
}

-- What an indicator's proxy can be anchored to. The element resolves these against its unit frame.
AuraIndicators.Attach = {
    Frame = 'frame',
    Health = 'health',
    HealthFill = 'healthFill',
}

AuraIndicators.MatchTypes = {
    SpellIDs = 'SpellIDs',
    Preset = 'Preset',
    Filter = 'Filter',
}

-- Tokens are read from the live client rather than written out, since they can change between patches.
local AF = AuraUtil.AuraFilters
local CreateFilterString = AuraUtil.CreateFilterString

-- The categories worth a one-click entry. Anything outside this list is what the Filter match type and the full builder are for.
-- type is the base the filter string was built from, which a compiled string no longer separates out.
AuraIndicators.Presets = {
    { value = 'BigDefensive',      text = L['Big Defensives'],        type = AF.Helpful, filterString = CreateFilterString(AF.Helpful, AF.BigDefensive), },
    { value = 'ExternalDefensive', text = L['External Defensives'],   type = AF.Helpful, filterString = CreateFilterString(AF.Helpful, AF.ExternalDefensive), },
    { value = 'DispelByYou',       text = L['Dispellable by You'],    type = AF.Harmful, filterString = CreateFilterString(AF.Harmful, AF.Raid), },
    { value = 'DispelByAnyone',    text = L['Dispellable by Anyone'], type = AF.Harmful, filterString = CreateFilterString(AF.Harmful, AF.Dispellable), },
    { value = 'CrowdControl',      text = L['Crowd Control'],         type = AF.Harmful, filterString = CreateFilterString(AF.Harmful, AF.CrowdControl), },
    { value = 'OwnBuffs',          text = L['Your Own Buffs'],        type = AF.Helpful, filterString = CreateFilterString(AF.Helpful, AF.Player), },
    { value = 'BossDebuffs',       text = L['Boss Debuffs'],          type = AF.Harmful, filterString = AF.Harmful,                                           candidateFilters = { isBossAura = true }, },
}

local PresetsByValue = {}
for _, preset in ipairs(AuraIndicators.Presets) do
    PresetsByValue[preset.value] = preset
end

AuraIndicators.AuraTypes = {
    { value = AF.Helpful,                                text = L['Helpful'] },
    { value = CreateFilterString(AF.Helpful, AF.Player), text = L['Helpful (Applied by You)'] },
    { value = AF.Harmful,                                text = L['Harmful'] },
    { value = CreateFilterString(AF.Harmful, AF.Player), text = L['Harmful (Applied by You)'] },
}

local function GetStore()
    return NRSKNUI.db.global.AuraIndicators
end

---Parse the spell ID box into the map candidateFilters wants. Anything that is not a positive integer is
---skipped, so a half-typed or comma-happy entry narrows the match rather than erroring.
---@param text string?
---@return table? map
local function ParseSpellIDs(text)
    if type(text) ~= 'string' then return nil end

    local map, found = {}, false
    for id in text:gmatch('%d+') do
        local spellID = tonumber(id)
        if spellID and spellID > 0 then
            map[spellID] = true
            found = true
        end
    end

    return found and map or nil
end

---Compile an indicator's match settings into the branches its slots run, in the same shape
---NRSKNUI:GetAuraFilter returns so both paths feed the same machinery.
---@param spec table
---@return table[] branches
function AuraIndicators:GetBranches(spec)
    local matchType = spec.MatchType

    if matchType == self.MatchTypes.Filter then
        return NRSKNUI:GetAuraFilter(spec.Filter) or {}
    end

    if matchType == self.MatchTypes.Preset then
        local preset = PresetsByValue[spec.Preset]
        if not preset then return {} end

        return { {
            type = preset.type,
            filterString = preset.filterString,
            candidateFilters = preset.candidateFilters and CopyTable(preset.candidateFilters) or nil,
        } }
    end

    -- Spell IDs. Note this only bites where the client honours identity filters: helpful auras on units
    -- you can assist and harmful ones on units you cannot. See AuraContainerUtil.CanApplyIdentityCandidateFilters.
    local spellIDs = ParseSpellIDs(spec.SpellIDs)
    local auraType = spec.AuraType or AF.Helpful
    return { { type = auraType, filterString = auraType, candidateFilters = spellIDs and { includeSpellIDs = spellIDs } or nil, } }
end

---Return true when the indicator is a SpellIDs match and at least one ID parses,
---so the GUI can warn the user that the match is conditional.
---@param spec table
---@return boolean
function AuraIndicators:HasConditionalSpellIDMatch(spec)
    if spec.MatchType ~= self.MatchTypes.SpellIDs then return false end

    return ParseSpellIDs(spec.SpellIDs) ~= nil
end

---The spell IDs an indicator matches on, for the GUI to list back. Sorted rather than left in map order,
---so the list keeps the same order every time the card redraws.
---@param spec table
---@return number[]? ids nil unless the indicator matches on spell IDs and at least one parsed
function AuraIndicators:GetSpellIDs(spec)
    if spec.MatchType ~= self.MatchTypes.SpellIDs then return nil end

    local map = ParseSpellIDs(spec.SpellIDs)
    if not map then return nil end

    local ids = {}
    for id in pairs(map) do tinsert(ids, id) end
    tsort(ids)

    return ids
end

---@param key string?
---@return table? spec
function AuraIndicators:GetSpec(key)
    local store = GetStore()
    return key and store and store[key]
end

---@param key string?
---@return boolean
function AuraIndicators:Exists(key)
    return self:GetSpec(key) ~= nil
end

---Sorted { key, text } list for GUI sidebars and per-unit assignment lists.
---@return table[]
function AuraIndicators:GetList()
    local list = {}
    local store = GetStore()
    if store then
        for key, spec in pairs(store) do
            tinsert(list, { key = key, text = (type(spec) == 'table' and spec.name) or key })
        end
        tsort(list, function(a, b) return a.text < b.text end)
    end
    return list
end

---Readable summary of what an indicator matches, for the GUI card.
---@param key string?
---@return string[] lines
---@return string heading
function AuraIndicators:Describe(key)
    local spec = self:GetSpec(key)
    if not spec then
        return {}, NRSKNUI:ColorTextByTheme(L['This indicator no longer exists.'])
    end

    local matchTypes = self.MatchTypes
    local lines = {}

    if spec.MatchType == matchTypes.Filter then
        -- The escape hatch, so hand the whole description back to the filter registry.
        lines = NRSKNUI.AuraFilters:Describe(spec.Filter)
    else
        for _, branch in ipairs(self:GetBranches(spec)) do
            tinsert(lines, NRSKNUI:ColorTextByTheme(branch.filterString))
        end

        if self:HasConditionalSpellIDMatch(spec) then
            tinsert(lines, NRSKNUI:ColorText(L['Spell IDs are ignored for debuffs on friendly units and buffs on hostile units.'], NRSKNUI.Colors.warning))
        end
    end

    if not lines[1] then
        return {}, NRSKNUI:ColorTextByTheme(L['This indicator matches nothing yet.'])
    end

    return lines, NRSKNUI:ColorTextByTheme(L['Shows while a matching aura is up:'])
end

-- What an indicator is: the aura it means and the colour it carries. Everything about how it is drawn lives per unit, in PlacementDefaults below.
local SpecDefaults = {
    MatchType = AuraIndicators.MatchTypes.SpellIDs,
    SpellIDs = '',
    AuraType = AF.Helpful,
    Preset = 'BigDefensive',
    Filter = '',
    sortMethod = 'ExpirationOnly',
    sortDirection = 'Normal',
    Color = { 0, 0.9, 0.5, 1 },
}

-- What a unit does with an indicator: where it draws it, how big it is, what font it uses and so on.
local PlacementDefaults = {
    Name = '',
    Keys = {},
    Alpha = 1,
    Style = AuraIndicators.Styles.Overlay,
    Layer = 1,
    Attach = AuraIndicators.Attach.Health,
    Position = { AnchorFrom = 'CENTER', AnchorTo = 'CENTER', XOffset = 0, YOffset = 0 },
    Size = { Width = 24, Height = 24 },
    Texture = '',
    ShowWithoutDispelType = false,
    Font = {
        UseGlobalFont = true,
        FontFace = 'Expressway',
        FontOutline = 'OUTLINE',
        FontSize = 12,
    },
    StackFont = { FontSize = 10, Position = { AnchorFrom = 'BOTTOMRIGHT', XOffset = 0, YOffset = 2 } },
    DurationFont = { FontSize = 12, Position = { AnchorFrom = 'CENTER', XOffset = 0, YOffset = 0 } },
    Icon = {
        showCooldown = true,
        showStacks = true,
        showDuration = true,
        showBorder = false,
        drawSwipe = true,
        drawEdge = false,
        reverseSwipe = true,
    },
}

---Add a fully populated indicator to the store.
---@param key string
---@param name string
---@return table? spec
function AuraIndicators:Create(key, name)
    local store = GetStore()
    if not store or store[key] then return nil end

    local spec = CopyTable(SpecDefaults)
    spec.name = name

    store[key] = spec
    self:Invalidate(key)

    return spec
end

---Give a unit another spot to draw indicators in, appended to its list.
---@param uDB table
---@return table placement
function AuraIndicators:AddPlacement(uDB)
    local placement = CopyTable(PlacementDefaults)

    tinsert(uDB.AuraIndicators, placement)
    return placement
end

---@param placement table
---@return table[] specs
function AuraIndicators:GetPlacementSpecs(placement)
    local specs = {}

    for _, key in ipairs(placement.Keys) do
        local spec = self:GetSpec(key)
        if spec then
            tinsert(specs, spec)
        end
    end

    return specs
end

---@param placement table
---@param index number
---@return string
function AuraIndicators:GetPlacementName(placement, index)
    if placement.Name and placement.Name ~= '' then return placement.Name end

    return format(L['Indicator %d'], index)
end

---@param uDB table
---@param index number
function AuraIndicators:RemovePlacement(uDB, index)
    tremove(uDB.AuraIndicators, index)
end

---@param uDB table
---@param key string
function AuraIndicators:RemoveKeyEverywhere(uDB, key)
    for _, placement in ipairs(uDB.AuraIndicators) do
        for index = #placement.Keys, 1, -1 do
            if placement.Keys[index] == key then tremove(placement.Keys, index) end
        end
    end
end

---@param key string
function AuraIndicators:Delete(key)
    local store = GetStore()
    if not store or not store[key] then return end

    store[key] = nil
    self:Invalidate(key)
end

-- Consumer callbacks for live updates when a spec changes. Keyed by consumer table.
local callbacks = {}

---@param consumer table
---@param callback fun(consumer: table, key: string?)
function AuraIndicators:RegisterCallback(consumer, callback)
    callbacks[consumer] = callback
end

---@param consumer table
function AuraIndicators:UnregisterCallback(consumer)
    callbacks[consumer] = nil
end

---Notify consumers that an indicator (or all of them) changed.
---@param key string?
function AuraIndicators:Invalidate(key)
    for consumer, callback in pairs(callbacks) do
        callback(consumer, key)
    end
end

---Build a look table from the indicator's spec and the placement's own settings.
---@param spec table an entry from db.global.AuraIndicators
---@param placement table that indicator's entry in uDB.AuraIndicators
---@param fontDB table? the host's shared font block, for placements that opted into it
---@return table look
local function ResolveLook(spec, placement, fontDB)
    local color = spec.Color
    local alpha = (color[4] or 1) * (placement.Alpha or 1)

    return {
        Color = { color[1], color[2], color[3], alpha },
        Alpha = placement.Alpha or 1,
        Texture = placement.Texture,
        Icon = placement.Icon,
        Position = placement.Position,
        Font = placement.Font,
        StackFont = placement.StackFont,
        DurationFont = placement.DurationFont,
        FontSource = (placement.Font.UseGlobalFont and fontDB) or placement.Font,
        FontOutline = (placement.Font.UseGlobalFont and fontDB and fontDB.FontOutline) or placement.Font.FontOutline,
        ShowWithoutDispelType = placement.ShowWithoutDispelType,
    }
end

---Color a plain texture, used by every style that owns its own artwork.
---@param texture Texture
---@param look table
local function ApplyTextureLook(texture, look)
    local color = look.Color
    local path = look.Texture ~= '' and look.Texture or nil

    if path then
        texture:SetTexture(NRSKNUI:ResolveMediaPath('statusbar', path))
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    else
        texture:SetColorTexture(color[1], color[2], color[3], color[4])
    end
    texture:SetBlendMode('ADD')
end

---Overlay and Square are the same build, they differ only in whether the proxy covers its target.
---Neither binds to a native setter, so both stay entirely ours to restyle at any time.
---@param slot table
---@param look table
---@return table regions
local function BuildTexture(slot, look)
    local texture = slot:CreateTexture(nil, 'ARTWORK')
    texture:SetAllPoints(slot)
    ApplyTextureLook(texture, look)

    return { texture = texture }
end

---Fade a dispel indicator through its holder rather than its texture.
---@param regions table
---@param look table
local function ApplyDispelAlpha(regions, look)
    regions.holder:SetAlpha(look.Alpha)
end

---Put artwork on a dispel texture.
---@param texture Texture
---@param look table
---@param defaultAtlas string?
local function ApplyDispelAsset(texture, look, defaultAtlas)
    local asset = (look.Texture ~= '' and look.Texture) or defaultAtlas

    if asset and CheckSetAtlas(texture, asset) then return end
    texture:SetTexture(asset and NRSKNUI:ResolveMediaPath('statusbar', asset) or NRSKNUI.WhiteTexture)
end

---Build a dispel indicator.
---@param slot table
---@param look table
---@param defaultAtlas string?
---@param level number
---@return table regions
local function BuildDispel(slot, look, defaultAtlas, level)
    local holder = CreateFrame('Frame', nil, slot)
    holder:SetAllPoints(slot)
    holder:SetFrameLevel(level)

    local texture = holder:CreateTexture(nil, 'ARTWORK')
    texture:SetAllPoints(holder)
    ApplyDispelAsset(texture, look, defaultAtlas)

    slot:AddDispelTypeTexture(texture, {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWhenHarmful = true,
        showWhenHelpful = true,
        showWithoutDispelType = look.ShowWithoutDispelType == true,
        customDispelColorMap = NRSKNUI.Colors.dispel,
    })

    local regions = { holder = holder, texture = texture }
    ApplyDispelAlpha(regions, look)
    return regions
end

---Icon is a whole aura button in one slot, so the existing skin does all of it. Sizing comes from the
---proxy, which the slot is already anchored to, so the skin's own SetSize is a no-op here.
---@param slot table
---@param look table
---@param container table
---@return table regions
local function BuildIcon(slot, look, container)
    local icon = look.Icon

    NRSKNUI:SkinAuraButton(container, {
        disableMouse = true,
        disableCooldown = not icon.showCooldown,
        drawSwipe = icon.drawSwipe,
        drawEdge = icon.drawEdge,
        reverseSwipe = icon.reverseSwipe,
        showApplicationCount = icon.showStacks,
        showDurationText = icon.showDuration,
        showBuffBorder = icon.showBorder or nil,
        showDebuffBorder = icon.showBorder or nil,
        fontDB = look.FontSource,
        stackFont = look.StackFont,
        durationFont = look.DurationFont,
    }, slot)

    return {} -- the skin owns every region, and none can be touched again after build
end

---Restyle a Duration indicator's text.
---@param regions table
---@param look table
local function ApplyDuration(regions, look)
    local text, pos = regions.text, look.Position

    text:SetFontStyle(look.FontSource, look.Font.FontSize, look.FontOutline, nil, true)
    text:SetFontJustify(look, regions.parent, pos.XOffset, pos.YOffset, true)

    local color = look.Color
    text:SetTextColor(color[1], color[2], color[3], color[4])
end

---A bare duration readout, no icon.
---@param slot table
---@param look table
---@return table regions
local function BuildDuration(slot, look)
    local text = slot:CreateFontString(nil, 'OVERLAY')

    text:SetFontStyle(look.FontSource, look.Font.FontSize, look.FontOutline, nil, true)
    slot:SetDurationText(text, { textFormatter = NRSKNUI:GetAuraDurationFormatter(false, nil), })

    local regions = { text = text, parent = slot }
    ApplyDuration(regions, look)
    return regions
end

local Styles = AuraIndicators.Styles

local StyleBuilders = {
    [Styles.Overlay] = BuildTexture,
    [Styles.Square] = BuildTexture,
    [Styles.Icon] = BuildIcon,
    [Styles.Duration] = BuildDuration,
    [Styles.DispelOverlay] = function(slot, look, _, level) return BuildDispel(slot, look, nil, level) end,
    [Styles.DispelBorder] = function(slot, look, _, level) return BuildDispel(slot, look, DISPEL_BORDER_ATLAS, level) end,
}

---Draw an indicator on a preview dummy, through the same builder its real slot runs. The dummy stands
---in for the slot and owner for the container, so nothing here reaches a restricted object.
---@param dummy table
---@param owner table
---@param placement table
---@param spec table
---@param level number
---@param fontDB table?
---@return boolean drawn
function NRSKNUI:BuildAuraIndicatorPreview(dummy, owner, placement, spec, level, fontDB)
    local build = AuraIndicators.Previewable[placement.Style] and StyleBuilders[placement.Style]
    if not build then return false end

    build(dummy, ResolveLook(spec, placement, fontDB), owner, level)
    return true
end

---Set up a unit's indicator slot for a spec or update it if it already exists.
---@param container table
---@param handle table?
---@param placement table
---@param proxy Frame
---@param level number
---@param fontDB table?
---@return table? handle
function NRSKNUI:SyncAuraIndicator(container, handle, placement, proxy, level, fontDB)
    local build = StyleBuilders[placement.Style]
    if not build then return nil end

    handle = handle or {
        proxy = proxy,
        slots = {},
        slotKeys = {},
        filters = {}, -- restored when a slot is shown again
        regions = {},
        builtKeys = {},
    }
    handle.container = container

    for _, key in ipairs(placement.Keys) do
        local spec = not handle.builtKeys[key] and AuraIndicators:GetSpec(key)

        if spec then
            handle.builtKeys[key] = true
            local look = ResolveLook(spec, placement, fontDB)

            for _, branch in ipairs(AuraIndicators:GetBranches(spec)) do
                local index = #handle.slots + 1

                handle.filters[index] = branch.candidateFilters
                handle.slots[index], handle.slotKeys[index] = container:AddSlot(branch.filterString, {
                    candidateFilters = branch.candidateFilters,
                    sortMethod = AuraContainerSortMethod[spec.sortMethod],
                    sortDirection = AuraContainerSortDirection[spec.sortDirection],
                    initializeFrame = function(button)
                        button:EnableMouse(false) -- an indicator must never eat the unit frame's clicks
                        button:SetFrameLevel(level)
                        button:SetAllPoints(proxy)
                        handle.regions[index] = build(button, look, container, level)
                    end,
                })

                local regions = handle.regions[index]
                regions.key, regions.spec = key, spec
            end
        end
    end

    return handle
end

-- An empty include map matches nothing, and is not skipped the way a spellID map can be.
local NEVER_MATCH = { includeDispelTypes = {} }

---Show or hide a slot by starving it of candidates, since its regions cannot be touched after build.
---@param handle table
---@param index number
---@param shown boolean
local function SetSlotShown(handle, index, shown)
    local key = handle.slotKeys[index]
    if not key then return end

    local filters = NEVER_MATCH
    if shown then
        filters = handle.filters[index] -- may be nil, which and/or would turn back into NEVER_MATCH
    end

    handle.container:SetAuraSlotCandidateFilters(key, filters)
end

---Hide every slot an indicator owns.
---@param handle table
---@param shown boolean
function NRSKNUI:SetAuraIndicatorShown(handle, shown)
    for index in ipairs(handle.slots) do
        SetSlotShown(handle, index, shown)
    end
end

---Settle which of an indicator's slots are showing. Looks are not re-applied: the regions belong to
---the slot's aura button, which the client closes to us once aura values are secret.
---@param handle table
---@param placement table
function NRSKNUI:ApplyAuraIndicator(handle, placement)
    local assigned = {}
    for _, key in ipairs(placement.Keys) do
        assigned[key] = true
    end

    for index, regions in ipairs(handle.regions) do
        -- The spec behind an assigned key can have been deleted since.
        local spec = assigned[regions.key] and AuraIndicators:GetSpec(regions.key)
        SetSlotShown(handle, index, spec ~= nil)
    end
end
