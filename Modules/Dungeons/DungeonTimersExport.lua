---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class DungeonTimers
local DT = NRSKNUI:GetModule("DungeonTimers")
if not DT then return end

local AS = NRSKNUI.Libs.AS
local LD = NRSKNUI.Libs.LD

local pairs, ipairs = pairs, ipairs
local tostring, tonumber = tostring, tonumber
local type, wipe, next, time = type, wipe, next, time
local CopyTable = CopyTable
local table_insert = table.insert

local EXPORT_PREFIX_SINGLE = "!NRSKNUITIMERS1!"
local EXPORT_PREFIX_ALL = "!NRSKNUITIMERSALL1!"
local DUNGEON_INFO = NRSKNUI.DUNGEON_INFO

local function GetNextTriggerId(triggers)
    local maxId = 0
    for id in pairs(triggers) do
        local numId = tonumber(id)
        if numId and numId > maxId then maxId = numId end
    end
    return maxId + 1
end

local function TriggerExists(existingTriggers, newTrigger)
    if not existingTriggers or not newTrigger then return false end
    local newSpellId, newName = tostring(newTrigger.spellId or ""), newTrigger.name or ""
    for _, existing in pairs(existingTriggers) do
        if tostring(existing.spellId or "") == newSpellId and (existing.name or "") == newName then
            return true
        end
    end
    return false
end

local function MergeWithDefaults(trigger, defaults)
    if not defaults then return trigger end
    local merged = CopyTable(defaults)
    for k, v in pairs(trigger) do
        if type(v) == "table" and type(merged[k]) == "table" then
            for k2, v2 in pairs(v) do merged[k][k2] = v2 end
        else
            merged[k] = v
        end
    end
    return merged
end

local function EnsureDungeonExists(db, dungeonKey)
    if db.Dungeons[dungeonKey] then
        db.Dungeons[dungeonKey].Triggers = db.Dungeons[dungeonKey].Triggers or {}
        return db.Dungeons[dungeonKey]
    end
    local info = DUNGEON_INFO[dungeonKey]
    if not info then return nil end
    db.Dungeons[dungeonKey] = { Enabled = true, instanceId = info.instanceId, Triggers = {} }
    return db.Dungeons[dungeonKey]
end

local function ImportTriggersIntoDungeon(dungeonDb, triggers, defaults)
    local importCount, skipCount = 0, 0

    local sortedIds = {}
    for id in pairs(triggers) do
        table_insert(sortedIds, id)
    end
    table.sort(sortedIds, function(a, b)
        local numA, numB = tonumber(a), tonumber(b)
        if numA and numB then return numA < numB end
        return tostring(a) < tostring(b)
    end)

    for _, id in ipairs(sortedIds) do
        local trigger = triggers[id]
        if type(trigger) == "table" and trigger.name and trigger.triggerType then
            if TriggerExists(dungeonDb.Triggers, trigger) then
                skipCount = skipCount + 1
            else
                local newTrigger = MergeWithDefaults(trigger, defaults)
                newTrigger.id = GetNextTriggerId(dungeonDb.Triggers)
                dungeonDb.Triggers[newTrigger.id] = newTrigger
                importCount = importCount + 1
            end
        end
    end
    return importCount, skipCount
end

local function FormatResult(importCount, skipCount, dungeonCount)
    local result = dungeonCount
        and (importCount .. " timer(s) imported from " .. dungeonCount .. " dungeon(s)")
        or (importCount .. " timer(s) imported")
    return skipCount > 0 and (result .. ", " .. skipCount .. " duplicate(s) skipped") or result
end

local function EncodeData(data, prefix)
    local serialized = AS:Serialize(data)
    if not serialized then return nil, "Serialization failed" end
    local compressed = LD:CompressDeflate(serialized, { level = 9 })
    if not compressed then return nil, "Compression failed" end
    local encoded = LD:EncodeForPrint(compressed)
    if not encoded then return nil, "Encoding failed" end
    return prefix .. encoded
end

local function DecodeData(importString, prefix)
    if not importString or importString == "" then return nil, "Import string is empty" end
    if importString:sub(1, #prefix) ~= prefix then return nil, "Invalid format" end
    local compressed = LD:DecodeForPrint(importString:sub(#prefix + 1))
    if not compressed then return nil, "Decoding failed" end
    local serialized = LD:DecompressDeflate(compressed)
    if not serialized then return nil, "Decompression failed" end
    local success, data = AS:Deserialize(serialized)
    if not success or type(data) ~= "table" then return nil, "Deserialization failed" end
    return data
end

local function SerializeValue(val, indent)
    indent = indent or ""
    local nextIndent = indent .. "    "
    local valType = type(val)

    if valType == "string" then
        return "\"" .. val:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("|", "\\124") .. "\""
    elseif valType == "number" then
        return tostring(val)
    elseif valType == "boolean" then
        return val and "true" or "false"
    elseif valType == "table" then
        local parts, isArray, maxIndex = {}, true, 0
        for k in pairs(val) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                isArray = false; break
            end
            if k > maxIndex then maxIndex = k end
        end

        if isArray and maxIndex > 0 then
            for i = 1, maxIndex do
                if val[i] ~= nil then table_insert(parts, nextIndent .. SerializeValue(val[i], nextIndent)) end
            end
        else
            local keys = {}
            for k in pairs(val) do table_insert(keys, k) end
            table.sort(keys, function(a, b)
                return type(a) == type(b) and tostring(a) < tostring(b) or type(a) < type(b)
            end)
            for _, k in ipairs(keys) do
                local keyStr = type(k) == "number" and ("[" .. k .. "]")
                    or (type(k) == "string" and k:match("^[%a_][%w_]*$") and k)
                    or ("[" .. SerializeValue(k, nextIndent) .. "]")
                table_insert(parts, nextIndent .. keyStr .. " = " .. SerializeValue(val[k], nextIndent))
            end
        end
        return #parts == 0 and "{}" or "{\n" .. table.concat(parts, ",\n") .. ",\n" .. indent .. "}"
    end
    return "nil"
end

function DT:ExportDungeonTimers(dungeonKey)
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return nil, "Database not initialized" end
    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData then return nil, "Dungeon not found" end
    local info = DUNGEON_INFO[dungeonKey]
    if not info then return nil, "Unknown dungeon" end
    return EncodeData({
        _v = 1,
        _t = time(),
        _d = dungeonKey,
        _n = info.name,
        _i = info.instanceId,
        triggers = dungeonData.Triggers or {},
    }, EXPORT_PREFIX_SINGLE)
end

function DT:ExportAllDungeonTimers()
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return nil, "Database not initialized" end
    local dungeons = {}
    for key, info in pairs(DUNGEON_INFO) do
        local data = self.db.Dungeons[key]
        if data and data.Triggers then
            dungeons[key] = { instanceId = info.instanceId, triggers = data.Triggers }
        end
    end
    return EncodeData({ _v = 1, _t = time(), dungeons = dungeons }, EXPORT_PREFIX_ALL)
end

function DT:ImportDungeonTimers(importString, targetDungeonKey)
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return false, "Database not initialized" end
    local data, err = DecodeData(importString, EXPORT_PREFIX_SINGLE)
    if not data then return false, err end
    if not data.triggers then return false, "No triggers in import data" end
    local dungeonKey = targetDungeonKey or data._d
    if not dungeonKey then return false, "No dungeon key" end
    local dungeonDb = EnsureDungeonExists(self.db, dungeonKey)
    if not dungeonDb then return false, "Unknown dungeon" end
    local imported, skipped = ImportTriggersIntoDungeon(dungeonDb, data.triggers, self.db.TriggerDefaults)
    self:InvalidateInstanceCache()
    return true, FormatResult(imported, skipped)
end

function DT:ImportAllDungeonTimers(importString)
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return false, "Database not initialized" end
    local data, err = DecodeData(importString, EXPORT_PREFIX_ALL)
    if not data then return false, err end
    if not data.dungeons then return false, "No dungeons in import data" end
    local totalImport, totalSkip, dungeonCount = 0, 0, 0
    for key, dungeonData in pairs(data.dungeons) do
        if type(dungeonData) == "table" and dungeonData.triggers then
            local dungeonDb = EnsureDungeonExists(self.db, key)
            if dungeonDb then
                local imported, skipped = ImportTriggersIntoDungeon(dungeonDb, dungeonData.triggers,
                    self.db.TriggerDefaults)
                totalImport, totalSkip = totalImport + imported, totalSkip + skipped
                if imported > 0 then dungeonCount = dungeonCount + 1 end
            end
        end
    end
    self:InvalidateInstanceCache()
    return true, FormatResult(totalImport, totalSkip, dungeonCount)
end

function DT:ImportNUIPreset(dungeonKey)
    local presets = NRSKNUI.DungeonTimerPresets and NRSKNUI.DungeonTimerPresets[dungeonKey]
    if not presets or not presets.Triggers or not next(presets.Triggers) then
        return false, "No presets available"
    end
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return false, "Database not initialized" end
    local dungeonDb = EnsureDungeonExists(self.db, dungeonKey)
    if not dungeonDb then return false, "Unknown dungeon" end
    local imported, skipped = ImportTriggersIntoDungeon(dungeonDb, presets.Triggers, self.db.TriggerDefaults)
    self:InvalidateInstanceCache()
    return true, FormatResult(imported, skipped)
end

function DT:ImportAllNUIPresets()
    if not NRSKNUI.DungeonTimerPresets then return false, "Presets not loaded" end
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return false, "Database not initialized" end
    local totalImport, totalSkip, dungeonCount = 0, 0, 0
    for key, presets in pairs(NRSKNUI.DungeonTimerPresets) do
        if key ~= "_version" and type(presets) == "table" and presets.Triggers then
            local dungeonDb = EnsureDungeonExists(self.db, key)
            if dungeonDb then
                local imported, skipped = ImportTriggersIntoDungeon(dungeonDb, presets.Triggers, self.db.TriggerDefaults)
                totalImport, totalSkip = totalImport + imported, totalSkip + skipped
                if imported > 0 then dungeonCount = dungeonCount + 1 end
            end
        end
    end
    self:InvalidateInstanceCache()
    if totalImport == 0 and totalSkip == 0 then return false, "No presets available" end
    return true, FormatResult(totalImport, totalSkip, dungeonCount)
end

function DT:ResetDungeonTimers(dungeonKey)
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return false, "Database not initialized" end
    local dungeonDb = self.db.Dungeons[dungeonKey]
    if not dungeonDb then return false, "Dungeon not found" end

    local count = 0
    if dungeonDb.Triggers then
        for _ in pairs(dungeonDb.Triggers) do count = count + 1 end
        dungeonDb.Triggers = {}
    end

    for frameKey, frame in pairs(self.triggerFrames) do
        if frame.dungeonKey == dungeonKey then
            frame:Hide()
            self.triggerFrames[frameKey] = nil
            self.triggerBars[frameKey] = nil
        end
    end
    return true, count .. " timer(s) cleared"
end

function DT:ResetAllDungeonTimers()
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return false, "Database not initialized" end

    local totalCount, dungeonCount = 0, 0
    for _, dungeonDb in pairs(self.db.Dungeons) do
        if dungeonDb.Triggers then
            for _ in pairs(dungeonDb.Triggers) do totalCount = totalCount + 1 end
            if next(dungeonDb.Triggers) then dungeonCount = dungeonCount + 1 end
            dungeonDb.Triggers = {}
        end
    end

    for _, frame in pairs(self.triggerFrames) do frame:Hide() end
    wipe(self.triggerFrames)
    wipe(self.triggerBars)
    return true, totalCount .. " timer(s) cleared from " .. dungeonCount .. " dungeon(s)"
end

function DT:GeneratePresetsCode()
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return print("NorskenUI: Database not initialized") end

    local output = {
        "---@class NRSKNUI", "local NRSKNUI = select(2, ...)", "",
        "-- Auto Generated Dungeon Timer Presets", "",
        "NRSKNUI.DungeonTimerPresets = {", "    _version = 1,", "",
    }

    for dungeonKey, info in pairs(DUNGEON_INFO) do
        local triggers = self.db.Dungeons[dungeonKey] and self.db.Dungeons[dungeonKey].Triggers
        table_insert(output, "    -- " .. info.name .. " (instanceId " .. info.instanceId .. ")")

        if triggers and next(triggers) then
            table_insert(output, "    " .. dungeonKey .. " = {")
            table_insert(output, "        Triggers = {")
            local sortedIds = {}
            for id in pairs(triggers) do table_insert(sortedIds, id) end
            table.sort(sortedIds, function(a, b) return tonumber(a) < tonumber(b) end)
            for _, id in ipairs(sortedIds) do
                table_insert(output,
                    "            [" .. id .. "] = " .. SerializeValue(triggers[id], "            ") .. ",")
            end
            table_insert(output, "        },")
            table_insert(output, "    },")
        else
            table_insert(output, "    " .. dungeonKey .. " = {},")
        end
        table_insert(output, "")
    end

    table_insert(output, "}")
    NRSKNUI:CreateCopyDialog("Generated Presets Code", table.concat(output, "\n"),
        "Copy this code into DungeonTimerPresets.lua")
    print("NorskenUI: Presets code generated!")
end
