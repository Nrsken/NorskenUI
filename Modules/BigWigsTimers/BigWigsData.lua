---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BigWigsTimersModule
local BigWigsTimers = NRSKNUI:GetModule('BigWigsTimers')

BigWigsTimers.spellCache = {}
BigWigsTimers.bossCache = {}

local tonumber, tostring = tonumber, tostring
local insert = table.insert
local GetTime = GetTime
local ipairs = ipairs
local type = type

local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local LoadAddOn = C_AddOns and C_AddOns.LoadAddOn

---Retrieves the bar, text and background colors for a given BigWigs module and spell ID from BigWigs.
---@param bwModule BigWigs.Module?
---@param key number|string|nil
---@return number[]? barColor, number[]? textColor, number[]? bgColor
function BigWigsTimers:GetBigWigsColors(bwModule, key)
    local barColor, textColor, bgColor

    if BigWigs and BigWigs.GetPlugin then
        local colorModule = BigWigs:GetPlugin('Colors', true) --[[@as BigWigs.ColorsPlugin?]]

        if colorModule and colorModule.GetColorTable then
            barColor = colorModule:GetColorTable('barColor', bwModule, key)
            textColor = colorModule:GetColorTable('barText', bwModule, key)
            bgColor = colorModule:GetColorTable('barBackground', bwModule, key)
        end
    end
    return barColor, textColor, bgColor
end

---Creates a bar data table for a given addon, spell ID, duration, text, count and icon.
---@param bwModule BigWigs.Module?
---@param key number|string|nil
---@param duration number
---@param text string
---@param count number
---@param icon number|string|nil
---@return table barData
function BigWigsTimers:CreateBarData(bwModule, key, duration, text, count, icon)
    local barColor, textColor, bgColor = self:GetBigWigsColors(bwModule, key)
    local spellName, spellIcon
    local spellIdNum = tonumber(key)

    if spellIdNum and spellIdNum > 0 then
        local spellInfo = GetSpellInfo(spellIdNum)

        if spellInfo then
            spellName = spellInfo.name
            spellIcon = spellInfo.iconID
        end
    end

    local barData = {
        bwModule = bwModule,
        key = tostring(key or ''),
        text = text or '',
        duration = duration or 0,
        expirationTime = GetTime() + (duration or 0),
        icon = icon or spellIcon,
        count = count or 0,
        paused = nil,
        pausedTime = nil,
        bwBarColor = barColor,
        bwTextColor = textColor,
        bwBgColor = bgColor,
        spellName = spellName,
    }

    return barData
end

---Retrieves all BigWigs modules for a given instance ID.
---@param instanceId number
---@return BigWigs.Module[] modules
function BigWigsTimers:GetBigWigsModulesForInstance(instanceId)
    if BigWigsLoader and BigWigsLoader.GetZoneMenus then
        local moduleList = BigWigsLoader:GetZoneMenus()[instanceId]

        if type(moduleList) == 'table' then return moduleList end
    end

    local modules = {}

    if not BigWigs or not BigWigs.IterateBossModules then return modules end

    for _, bwModule in BigWigs:IterateBossModules() do
        local zone = bwModule.instanceId

        if zone == instanceId then
            insert(modules, bwModule)
        elseif type(zone) == 'table' then
            for i = 1, #zone do
                if zone[i] == instanceId then
                    insert(modules, bwModule)
                    break
                end
            end
        end
    end

    return modules
end

---A zone's modules only reach the menu list once its BigWigs addon is in, so pull it in first.
---@param instanceId number
---@return BigWigs.Module[] modules in TOC order, which is encounter order
function BigWigsTimers:LoadInstanceModules(instanceId)
    if BigWigsLoader then
        if not BigWigs then LoadAddOn('BigWigs_Core') end
        -- Module registration runs off ADDON_LOADED, so every module is ready once this returns.
        if BigWigs then BigWigsLoader:LoadZone(instanceId) end
    end

    return self:GetBigWigsModulesForInstance(instanceId)
end

---Every encounter BigWigs has a module for in an instance, in encounter order; trash modules carry
---no journal ID and are left out.
---@param instanceId number
---@param forceRefresh boolean?
---@return BigWigsTimers.BossEntry[]
function BigWigsTimers:GetBossesForInstance(instanceId, forceRefresh)
    if not self:GetSeasonData()[instanceId] then return {} end

    if forceRefresh then self.bossCache[instanceId] = nil end
    if self.bossCache[instanceId] then return self.bossCache[instanceId] end

    local bosses = {}

    for _, bwModule in ipairs(self:LoadInstanceModules(instanceId)) do
        local journalId = bwModule.journalId

        if journalId and journalId > 0 then
            insert(bosses, {
                journalId = journalId,
                name = bwModule.displayName or bwModule.moduleName,
                num = #bosses + 1,
            })
        end
    end

    -- An empty result is only worth keeping once BigWigs is actually there to answer.
    if BigWigs then self.bossCache[instanceId] = bosses end

    return bosses
end

---Every spell BigWigs has an option for in an instance, in encounter order.
---@param instanceId number
---@param forceRefresh boolean?
---@return BigWigsTimers.SpellEntry[]
function BigWigsTimers:GetSpellsForDungeon(instanceId, forceRefresh)
    if not self:GetSeasonData()[instanceId] then return {} end

    if forceRefresh then self.spellCache[instanceId] = nil end
    if self.spellCache[instanceId] then return self.spellCache[instanceId] end

    local spells = {}
    local seenSpells = {}
    local bossNumbers = {}

    for _, boss in ipairs(self:GetBossesForInstance(instanceId)) do bossNumbers[boss.journalId] = boss.num end

    for _, bwModule in ipairs(self:LoadInstanceModules(instanceId)) do
        local options = bwModule.toggleOptions

        if options then
            local bossName = bwModule.displayName or bwModule.moduleName
            local journalId = bwModule.journalId

            for _, option in ipairs(options) do
                local spellId, isPrivateAura

                if type(option) == 'number' then
                    spellId = option
                elseif type(option) == 'table' then
                    if type(option[1]) == 'number' then spellId = option[1] end
                    for j = 2, #option do
                        if option[j] == 'PRIVATE' then
                            isPrivateAura = true
                            break
                        end
                    end
                end

                if spellId and spellId > 0 and not isPrivateAura and not seenSpells[spellId] then
                    seenSpells[spellId] = true
                    local spellInfo = GetSpellInfo(spellId)

                    if spellInfo then
                        insert(spells, {
                            spellId = spellId,
                            name = spellInfo.name,
                            icon = spellInfo.iconID,
                            bossName = bossName,
                            bossNum = journalId and bossNumbers[journalId],
                            journalId = journalId,
                        })
                    end
                end
            end
        end
    end

    -- An empty result is only worth keeping once BigWigs is actually there to answer.
    if BigWigs then
        self.spellCache[instanceId] = spells
    end

    return spells
end
