---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local ipairs, pairs = ipairs, pairs
local type = type
local CopyTable = CopyTable
local tsort = table.sort

local BUILTIN_PRESETS, PlaceAt, FromTracker = CDM.BUILTIN_PRESETS, CDM.PlaceAt, CDM.FromTracker
local function NextId() return CDM:NextId() end

---The Auras page's trackers become aura groups, its folders plain Groups holding them.
---@param db table profile.CDM
local function MigrateAuraDisplays(db)
    local profile = NRSKNUI.db.profile
    local AuraDisplay = NRSKNUI:GetModule('AuraDisplay')
    local store = db.Displays

    local groups = {}
    for groupKey, group in pairs(profile.AuraDisplayGroups or {}) do
        local folder = { type = 'group', name = group.name or groupKey, Enabled = true, Icon = group.Icon }
        PlaceAt(folder)
        folder.Strata = group.Strata
        local id = NextId()
        store[id] = folder
        groups[groupKey] = id
    end

    -- A profile with its own General Buffs tracker keeps that one rather than gaining the newer built-in beside it.
    local ownNames = {}
    for key, tracker in pairs(profile.AuraDisplays or {}) do
        if not BUILTIN_PRESETS[key] then ownNames[tracker.name or key] = true end
    end

    local anyEnabled = false
    for key in pairs(profile.AuraDisplays or {}) do
        local skip = key == 'builtin:generalBuffs' and ownNames[profile.AuraDisplays[key].name]
        local tracker = not skip and AuraDisplay:Get(key) -- seeds a built-in's preset trigger on an old save
        if tracker then
            local display = FromTracker(tracker, tracker.group and groups[tracker.group] or nil)
            display.builtin = BUILTIN_PRESETS[key] and key or nil
            anyEnabled = anyEnabled or display.Enabled == true
            store[NextId()] = display
        end
    end

    db.AurasMerged = true -- the Auras page and its module stand down for this profile
    if anyEnabled then db.Enabled = true end
end

-- Style keys a lone aura's old Active conditions stood in for.
local AURA_STYLE_KEYS = { desaturate = 'Desaturate', color = 'Color', swipe = 'DrawSwipe', inverse = 'Reverse', edge = 'DrawEdge', swipeColor = 'SwipeColor' }
-- The old Active changes an overlay keeps for its Aura Icon.
local OVERLAY_KEYS = { color = 'auraColor', desaturate = 'auraDesaturate', swipe = 'auraSwipe' }

---@param value any
---@return any
local function Copy(value)
    return type(value) == 'table' and CopyTable(value) or value
end

---An aura alone is the icon; with other triggers it becomes an Aura Overlay. Its old Active changes (conditions,
---or v9's AuraLook) fold into the style, or become the overlay's While Up changes so it looks the same.
---@param db table profile.CDM
local function MigrateAuraOverlays(db)
    for _, display in pairs(db.Displays) do
        local triggers = display.Triggers
        if triggers then
            local looks = {} -- [trigger index] = { active = {}, pandemic = {} }
            local function Look(index)
                looks[index] = looks[index] or { active = {}, pandemic = {} }
                return looks[index]
            end

            local kept, breakChain = {}, false
            for _, condition in ipairs(display.Conditions or {}) do
                local check = condition.check or {}
                local variable = check.variable
                local trigger = check.trigger and check.trigger > 0 and triggers[check.trigger]
                if trigger and trigger.Type == 'aura' and (variable == 'active' or variable == 'pandemic') then
                    if check.value ~= false then
                        local set = Look(check.trigger)[variable]
                        for _, change in ipairs(condition.changes or {}) do
                            if change.property and change.property ~= 'sound' then set[change.property] = change.value end
                        end
                    end
                    -- It never matched, so an Else If chained only to it was always checked on its own.
                    if not condition.linked then breakChain = true end
                else
                    if breakChain and condition.linked then condition.linked = nil end
                    breakChain = false
                    kept[#kept + 1] = condition
                end
            end
            display.Conditions = kept

            local subRegions = display.SubRegions or {}
            display.SubRegions = subRegions
            local solo = #triggers == 1
            for index, trigger in ipairs(triggers) do
                if trigger.Type == 'aura' then
                    local look = Look(index)
                    local old = trigger.AuraLook
                    if old then
                        for key, value in pairs(old.active or {}) do look.active[key] = value end
                        for key, value in pairs(old.pandemic or {}) do look.pandemic[key] = value end
                        if old.pandemicColor then look.pandemic.pandemicColor = old.pandemicColor end
                    end

                    local changes = {}
                    if trigger.ShowAs == 'glow' then
                        subRegions[#subRegions + 1] = CDM:NewSubRegion('glow', trigger.Glow)
                        if solo then
                            subRegions[#subRegions].Enabled = true
                        else
                            changes[1] = { property = 'sub.' .. #subRegions .. '.visible', value = true }
                        end
                    elseif solo then
                        display.Style = display.Style or {}
                        for property, key in pairs(AURA_STYLE_KEYS) do
                            if look.active[property] ~= nil then display.Style[key] = Copy(look.active[property]) end
                        end
                        for key, value in pairs(look.active) do
                            local n, name = key:match('^sub%.(%d+)%.(%a+)$')
                            local element = n and subRegions[tonumber(n)]
                            if element and name == 'visible' then
                                element.Enabled = value
                            elseif element and name == 'color' then
                                element.Color = Copy(value)
                            end
                        end
                    else
                        changes[1] = { property = 'auraIcon', value = true }
                        for property, key in pairs(OVERLAY_KEYS) do
                            if look.active[property] ~= nil then changes[#changes + 1] = { property = key, value = Copy(look.active[property]) } end
                        end
                        for n, element in ipairs(subRegions) do
                            if element.type == 'glow' or element.type == 'text' then
                                local visible = look.active['sub.' .. n .. '.visible']
                                if visible == nil then visible = element.Enabled end
                                -- The base draws its own shown glows above the overlay already.
                                if visible and not (element.type == 'glow' and element.Enabled) then
                                    changes[#changes + 1] = { property = 'sub.' .. n .. '.visible', value = true }
                                end
                                local color = look.active['sub.' .. n .. '.color']
                                if color then changes[#changes + 1] = { property = 'sub.' .. n .. '.color', value = Copy(color) } end
                            end
                        end
                    end
                    if changes[1] then
                        kept[#kept + 1] = { check = { trigger = index, variable = 'active', value = true }, changes = changes }
                    end

                    local pandemic = {}
                    for key, value in pairs(look.pandemic) do pandemic[#pandemic + 1] = { property = key, value = Copy(value) } end
                    if pandemic[1] then
                        kept[#kept + 1] = { check = { trigger = index, variable = 'pandemic', value = true }, changes = pandemic }
                    end

                    trigger.ShowAs, trigger.Glow, trigger.AuraLook = nil, nil, nil
                    if not solo then trigger.Type = 'auraoverlay' end
                end
            end
        end
    end
end

---Use Spell Icon leaves the trigger: a lone aura takes the spell's icon as its Manual Icon, an overlay as its While Up Aura Icon Texture.
---@param db table profile.CDM
local function MigrateSpellIcons(db)
    for _, display in pairs(db.Displays) do
        for index, trigger in ipairs(display.Triggers or {}) do
            local spellID = trigger.UseSpellIcon and CDM:GetTriggerSpell(trigger)
            local texture = spellID and C_Spell.GetSpellTexture(spellID)
            if texture and trigger.Type == 'aura' then
                display.Style = display.Style or {}
                if display.Style.IconSource ~= 'manual' then display.Style.IconSource, display.Style.ManualIcon = 'manual', texture end
            elseif texture and trigger.Type == 'auraoverlay' then
                for _, condition in ipairs(display.Conditions or {}) do
                    local check = condition.check
                    if check and check.trigger == index and check.variable == 'active' then
                        condition.changes[#condition.changes + 1] = { property = 'auraTexture', value = texture }
                        break
                    end
                end
            end
            trigger.UseSpellIcon = nil
        end
    end
end

-- The old fixed stack, bottom first: borders, glows, texts; with an overlay the texts went under it.
local STACK_RANK = { tick = 0, border = 1, glow = 2, text = 3 }
local OVERLAY_STACK_RANK = { tick = 0, text = 1, border = 2, glow = 3 }

---Sub elements now draw in list order, so each list is reordered into the stack it used to draw in.
---@param db table profile.CDM
local function MigrateDrawOrder(db)
    for _, display in pairs(db.Displays) do
        local list = display.SubRegions
        if list and list[1] and display.Triggers then
            local overlays = {}
            for _, trigger in ipairs(display.Triggers) do
                if trigger.Type == 'auraoverlay' then overlays[#overlays + 1] = trigger end
            end
            local rank = overlays[1] and OVERLAY_STACK_RANK or STACK_RANK
            local order = {}
            for n in ipairs(list) do order[n] = n end
            tsort(order, function(a, b)
                local ra, rb = rank[list[a].type] or 0, rank[list[b].type] or 0
                if ra ~= rb then return ra < rb end
                return a < b
            end)
            local sorted, newIndex, texts = {}, {}, 0
            for position, old in ipairs(order) do
                sorted[position] = list[old]
                newIndex[old] = position
                if list[old].type == 'text' then texts = texts + 1 end
            end
            display.SubRegions = sorted
            CDM:RemapConditionSubRegions(display, function(n) return newIndex[n] end)
            for _, trigger in ipairs(overlays) do trigger.Slot = texts end
        end
    end
end

---Steps from 13 on must only read db.Displays: imports migrate a bare { Version, Displays } table.
---@param db table profile.CDM
function CDM:Migrate(db)
    local version = db.Version or 0
    local schema = CDM:GetSchemaVersion()
    if version >= schema then return end
    if version < 8 then MigrateAuraDisplays(db) end
    if version < 10 then MigrateAuraOverlays(db) end
    if version < 11 then MigrateSpellIcons(db) end
    if version < 12 then MigrateDrawOrder(db) end
    db.Version = schema
end
