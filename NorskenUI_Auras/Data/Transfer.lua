---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL

--[[
Import and export strings: a display and everything inside it, packed into one string.
An import either lands as a copy or updates the displays it matches by uid, one picked category at a time.
]]

local pairs, ipairs, next = pairs, ipairs, next
local type = type
local abs = math.abs
local tsort = table.sort
local CopyTable = CopyTable
local time = time

local SerializeCBOR = C_EncodingUtil and C_EncodingUtil.SerializeCBOR
local DeserializeCBOR = C_EncodingUtil and C_EncodingUtil.DeserializeCBOR
local CompressString = C_EncodingUtil and C_EncodingUtil.CompressString
local DecompressString = C_EncodingUtil and C_EncodingUtil.DecompressString
local EncodeBase64 = C_EncodingUtil and C_EncodingUtil.EncodeBase64
local DecodeBase64 = C_EncodingUtil and C_EncodingUtil.DecodeBase64

local DEFLATE = Enum and Enum.CompressionMethod.Deflate
local OPTIMIZE_SIZE = Enum and Enum.CompressionLevel.OptimizeForSize

local PREFIX = '!NUICDM1!'
local FORMAT_VERSION = 1
local MAX_DEPTH = 32

-- What an import may contain.
local TYPES = { icon = true, bar = true, text = true, group = true, dynamicgroup = true, auragroup = true }
local GROUP_TYPES = { group = true, dynamicgroup = true }

-- The parts an update can take from an import, as the import page lists them.
CDM.IMPORT_CATEGORIES = {
    { key = 'name',        label = L['Names'],                    fields = { 'name' },                                                                                        default = true },
    { key = 'position',    label = L['Size & Position'],          fields = { 'Position', 'anchorFrameType', 'ParentFrame', 'Strata', 'MatchWidth', 'MatchSide', 'MatchGap' }, default = false },
    { key = 'display',     label = L['Display'],                  fields = {},                                                                                                default = true },
    { key = 'trigger',     label = L['Trigger'],                  fields = { 'Triggers', 'Trigger', 'Activation', 'DynamicTrigger' },                                         default = true },
    { key = 'conditions',  label = L['Conditions'],               fields = { 'Conditions' },                                                                                  default = true },
    { key = 'load',        label = L['Load'],                     fields = { 'Load', 'Enabled' },                                                                             default = true },
    { key = 'arrangement', label = L['Group Arrangement'],        fields = { 'Layout' },                                                                                      default = true },
    { key = 'metadata',    label = L['Meta Data'],                fields = { 'Description' },                                                                                 default = true },
    { key = 'newchildren', label = L['Add Missing Displays'],     fields = {},                                                                                                default = true },
    { key = 'oldchildren', label = L['Remove Obsolete Displays'], fields = {},                                                                                                default = true },
}

local FIELD_CATEGORY = {}
for _, category in ipairs(CDM.IMPORT_CATEGORIES) do
    for _, field in ipairs(category.fields) do
        FIELD_CATEGORY[field] = category.key
    end
end

-- Tree bookkeeping, never compared or copied between a match.
local INTERNAL = { uid = true, parent = true, order = true, builtin = true, preferToUpdate = true }
local SIZE_KEYS = { Width = true, Height = true }

-- Shared --

---Size and position are the root's own; inside a group they are part of how the group is arranged.
---@param key string
---@param isRoot boolean
---@return string
local function FieldCategory(key, isRoot)
    local category = FIELD_CATEGORY[key] or 'display'
    if category == 'position' and not isRoot then
        return 'arrangement'
    end
    return category
end

---@param a any
---@param b any
---@return boolean
local function Equal(a, b)
    if type(a) == 'number' and type(b) == 'number' then
        return abs(a - b) < 1e-6
    end
    if type(a) ~= 'table' or type(b) ~= 'table' then
        return a == b
    end
    for key, value in pairs(a) do
        if not Equal(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

---@param value any
---@return any
local function Copy(value)
    return type(value) == 'table' and CopyTable(value) or value
end

---@param id string
---@param into string[]
---@return string[]
local function CollectSubtree(id, into)
    into[#into + 1] = id
    for _, child in ipairs(CDM:GetChildren(id)) do
        CollectSubtree(child.key, into)
    end

    return into
end

---Children of `parentKey` inside a payload, in their saved order.
---@param d table<string, table>
---@param parentKey string
---@return string[]
local function PayloadChildren(d, parentKey)
    local keys = {}
    for key, display in pairs(d) do
        if display.parent == parentKey then
            keys[#keys + 1] = key
        end
    end

    tsort(keys, function(a, b)
        local oa, ob = d[a].order or 0, d[b].order or 0
        if oa ~= ob then
            return oa < ob
        end
        return a < b
    end)
    return keys
end

-- Export --

---A display and everything inside it as an import string.
---@param id string
---@return string? text
function CDM:Export(id)
    if not self:Get(id) then return nil end

    self:EnsureUids()

    local d = {}
    for _, key in ipairs(CollectSubtree(id, {})) do
        local copy = CopyTable(self:Get(key))
        copy.builtin, copy.preferToUpdate = nil, nil -- a shared built-in is the importer's own
        d[key] = copy
    end
    d[id].parent = nil
    d[id].order = nil
    for _, copy in pairs(d) do
        if copy.MatchWidth and not d[copy.MatchWidth] then
            copy.MatchWidth = nil
        end
    end

    local payload = { _v = FORMAT_VERSION, _s = self:GetSchemaVersion(), _a = NRSKNUI.Version, _t = time(), root = id, d = d }
    local ok, encoded = pcall(function()
        return EncodeBase64(CompressString(SerializeCBOR(payload), DEFLATE, OPTIMIZE_SIZE))
    end)
    if not ok or not encoded then return nil end
    return PREFIX .. encoded
end

-- Decode --

---As WA's validate: a missing or wrongly typed field takes the default, nested tables included; a field the
---default doesn't have is left alone.
---@param input table
---@param default table
local function Conform(input, default)
    for key, value in pairs(default) do
        local have = input[key]
        if type(value) == 'table' then
            if type(have) ~= 'table' then
                input[key] = CopyTable(value)
            else
                Conform(have, value)
            end
        elseif type(have) ~= type(value) then
            input[key] = value
        end
    end
end

---Puts an imported display's fields in shape, so nothing reads a wrong type later. Its lists can't be patched
---without changing what a trigger or condition number points at, so a broken one fails the whole string.
---@param display table
---@return boolean ok
local function ConformDisplay(display)
    local conditions = display.Conditions
    if conditions ~= nil and type(conditions) ~= 'table' then return false end
    for _, condition in ipairs(conditions or {}) do
        if type(condition) ~= 'table' then return false end
        if condition.check ~= nil and type(condition.check) ~= 'table' then return false end
        if condition.changes ~= nil and type(condition.changes) ~= 'table' then return false end
    end
    Conform(display, { Position = CDM.POSITION_TEMPLATE })

    if CDM.LAYERED_TYPES[display.type] then
        for _, trigger in ipairs(display.Triggers) do
            if type(trigger) ~= 'table' or type(trigger.Type) ~= 'string' then return false end
        end

        local elements = display.SubRegions
        if elements ~= nil and type(elements) ~= 'table' then return false end
        for _, element in ipairs(elements or {}) do
            local template = type(element) == 'table' and CDM.SUBREGION_TEMPLATES[element.type]
            if not template then return false end
            Conform(element, template)
        end

        Conform(display.Style, CDM.STYLE_TEMPLATES[display.type] or CDM.STYLE_TEMPLATE)
        Conform(display, { Load = NRSKNUI.LoadConditions:GetDefaults() })
    elseif display.type == 'auragroup' then
        if type(display.Trigger) ~= 'table' then return false end
        Conform(display, CDM.AURA_GROUP_TEMPLATE)
        Conform(display, { Load = NRSKNUI.LoadConditions:GetDefaults() })
    elseif display.type == 'dynamicgroup' then
        Conform(display, { Layout = CDM.LAYOUT_TEMPLATE })
    end

    return true
end

---Every display in a payload is reachable from the root and the tree follows the group rules.
---@param d table<string, table>
---@param root string
---@return string? error
local function ValidateTree(d, root)
    for key, display in pairs(d) do
        if type(key) ~= 'string' or type(display) ~= 'table' then
            return L['The string is damaged.']
        end
        if type(display.name) ~= 'string' or not TYPES[display.type] or type(display.uid) ~= 'string' then
            return L['The string is damaged.']
        end
        if CDM.LAYERED_TYPES[display.type] and (type(display.Triggers) ~= 'table' or type(display.Style) ~= 'table') then
            return L['The string is damaged.']
        end
        if not ConformDisplay(display) then
            return L['The string is damaged.']
        end

        if key == root then
            if display.parent ~= nil then
                return L['The string is damaged.']
            end
        else
            local parent = d[display.parent]
            if not parent or not GROUP_TYPES[parent.type] then
                return L['The string is damaged.']
            end
            if parent.type == 'dynamicgroup' and not CDM.LAYERED_TYPES[display.type] then
                return L['The string is damaged.']
            end

            local walk, depth = display, 0
            while walk.parent ~= nil do
                depth = depth + 1
                if depth > MAX_DEPTH then
                    return L['The string is damaged.']
                end
                walk = d[walk.parent]
                if not walk then
                    return L['The string is damaged.']
                end
            end
        end

        -- A Match Width group that didn't come along is dropped.
        if display.MatchWidth ~= nil and (type(display.MatchWidth) ~= 'string' or not d[display.MatchWidth]) then
            display.MatchWidth = nil
        end
    end
end

---Read an import string; nil and an error the page can show when it isn't one.
---@param text string
---@return table? payload
---@return string? error
function CDM:DecodeImport(text)
    text = (text or ''):gsub('%s+', '') -- Base64 has no whitespace; a string copied in wrapped lines still reads
    if text == '' then return nil end
    if text:sub(1, #PREFIX) ~= PREFIX then
        return nil, L['This is not a NorskenUI Cooldown Manager string.']
    end

    -- Untrusted pasted text and these natives raise rather than return nil.
    local ok, payload = pcall(function()
        local compressed = DecodeBase64(text:sub(#PREFIX + 1))
        local serialized = compressed and DecompressString(compressed, DEFLATE)
        return serialized and DeserializeCBOR(serialized)
    end)
    if not ok or type(payload) ~= 'table' or type(payload.d) ~= 'table' or type(payload.root) ~= 'string'
        or type(payload.d[payload.root]) ~= 'table' or type(payload._s) ~= 'number' then
        return nil, L['The string is damaged.']
    end
    if payload._s > self:GetSchemaVersion() then
        return nil, L['This string was made with a newer NorskenUI; update to import it.']
    end
    if payload._s < self:GetSchemaVersion() then
        return nil, L['The string is damaged.']
    end

    local treeError = ValidateTree(payload.d, payload.root)
    if treeError then
        return nil, treeError
    end

    return payload
end

-- Match --

---Which categories differ between a local display and its import.
---@param old table
---@param new table
---@param isRoot boolean
---@param into table<string, true>
local function Differences(old, new, isRoot, into)
    local sizeCategory = isRoot and 'position' or 'arrangement'
    local function Compare(key)
        if INTERNAL[key] then return end
        if key == 'Style' and type(old.Style) == 'table' and type(new.Style) == 'table' then
            for styleKey in pairs(SIZE_KEYS) do
                if not Equal(old.Style[styleKey], new.Style[styleKey]) then
                    into[sizeCategory] = true
                end
            end
            for styleKey, value in pairs(old.Style) do
                if not SIZE_KEYS[styleKey] and not Equal(value, new.Style[styleKey]) then
                    into.display = true
                end
            end
            for styleKey in pairs(new.Style) do
                if not SIZE_KEYS[styleKey] and old.Style[styleKey] == nil then
                    into.display = true
                end
            end
        elseif not Equal(old[key], new[key]) then
            into[FieldCategory(key, isRoot)] = true
        end
    end
    for key in pairs(old) do
        Compare(key)
    end
    for key in pairs(new) do
        if old[key] == nil then
            Compare(key)
        end
    end
end

---What importing a payload would do: a match to update or a plain copy.
---@param payload table
---@return table plan
function CDM:PlanImport(payload)
    self:EnsureUids()

    local d, root = payload.d, payload.root
    local count = 0
    for _ in pairs(d) do
        count = count + 1
    end
    local plan = { payload = payload, count = count, matches = {}, added = {}, modified = {}, removed = {}, categories = {} }

    local target = self:GetByUid(d[root].uid)
    if not target or self:Get(target).type ~= d[root].type then
        plan.blocked = target ~= nil -- same uid, other kind of display: only a copy makes sense
        return plan
    end

    local localByUid = {}
    for _, id in ipairs(CollectSubtree(target, {})) do
        localByUid[self:Get(id).uid] = id
    end
    plan.target = target
    plan.matches[root] = target
    for key, display in pairs(d) do
        local id = key ~= root and localByUid[display.uid]
        if id then
            if self:Get(id).type ~= display.type then
                plan.blocked = true
                return plan
            end
            plan.matches[key] = id
        end
    end

    local matchedLocal = {}
    for key, id in pairs(plan.matches) do
        matchedLocal[id] = key
        local changed = {}
        Differences(self:Get(id), d[key], key == root, changed)
        if next(changed) then
            plan.modified[key] = changed
            for category in pairs(changed) do
                plan.categories[category] = true
            end
        end
        -- A matched display moved to another group.
        if key ~= root and plan.matches[d[key].parent] ~= self:Get(id).parent then
            plan.categories.arrangement = true
        end
    end
    for key in pairs(d) do
        if not plan.matches[key] then
            plan.added[#plan.added + 1] = key
        end
    end
    for _, id in ipairs(CollectSubtree(target, {})) do
        if not matchedLocal[id] then
            plan.removed[#plan.removed + 1] = id
        end
    end
    if plan.added[1] then
        plan.categories.newchildren = true
    end
    if plan.removed[1] then
        plan.categories.oldchildren = true
    end

    -- Sibling order changed among displays both sides have.
    for key, id in pairs(plan.matches) do
        if GROUP_TYPES[d[key].type] then
            local newOrder, oldOrder = {}, {}
            for _, childKey in ipairs(PayloadChildren(d, key)) do
                if plan.matches[childKey] then
                    newOrder[#newOrder + 1] = plan.matches[childKey]
                end
            end
            for _, child in ipairs(self:GetChildren(id)) do
                if matchedLocal[child.key] and plan.matches[d[matchedLocal[child.key]].parent] == id then
                    oldOrder[#oldOrder + 1] = child.key
                end
            end
            if not Equal(newOrder, oldOrder) then
                plan.categories.arrangement = true
            end
        end
    end

    return plan
end

-- Apply --

---@param parentId string
local function Renumber(parentId)
    for index, child in ipairs(CDM:GetChildren(parentId)) do
        CDM:Get(child.key).order = index
    end
end

---Write an import as new displays at the top level; uids already in use get fresh ones.
---@param payload table
---@return string rootId
local function ImportAsCopy(payload)
    local d, root = payload.d, payload.root
    local store = CDM.db.Displays
    local used = {}
    for _, display in pairs(store) do
        used[display.uid] = true
    end

    local ids = {}
    for key, display in pairs(d) do
        local id = CDM:NextId()
        local copy = CopyTable(display)
        if used[copy.uid] then
            copy.uid = CDM:NewUid()
        end
        used[copy.uid] = true
        store[id] = copy
        ids[key] = id
    end
    for key, id in pairs(ids) do
        local display = store[id]
        display.parent = d[key].parent and ids[d[key].parent]
        display.MatchWidth = display.MatchWidth and ids[display.MatchWidth]
    end

    store[ids[root]].order = nil
    return ids[root]
end

---Update the matched displays in place with the picked categories.
---@param plan table
---@param picked table<string, boolean>
---@return string rootId
local function ImportAsUpdate(plan, picked)
    local d, root = plan.payload.d, plan.payload.root
    local store = CDM.db.Displays
    local sizeCategory = function(key) return key == root and 'position' or 'arrangement' end

    -- Final id of every import key that ends up in the store.
    local ids = {}
    for key, id in pairs(plan.matches) do
        ids[key] = id
    end
    if picked.newchildren then
        local used = {}
        for _, display in pairs(store) do
            used[display.uid] = true
        end
        for _, key in ipairs(plan.added) do
            local id = CDM:NextId()
            local copy = CopyTable(d[key])
            if used[copy.uid] then
                copy.uid = CDM:NewUid() -- moved out of the group locally, so it stays a separate display
            end
            used[copy.uid] = true
            store[id] = copy
            ids[key] = id
        end
        for _, key in ipairs(plan.added) do
            local copy = store[ids[key]]
            copy.MatchWidth = copy.MatchWidth and ids[copy.MatchWidth]
        end
    end

    for key, id in pairs(plan.matches) do
        local old, new = store[id], d[key]
        local keys = {}
        for field in pairs(old) do
            keys[field] = true
        end
        for field in pairs(new) do
            keys[field] = true
        end
        for field in pairs(keys) do
            if not INTERNAL[field] and field ~= 'Style' and picked[FieldCategory(field, key == root)] then
                if field == 'MatchWidth' then
                    old.MatchWidth = new.MatchWidth and ids[new.MatchWidth] -- an import key, so it needs the id it got here
                else
                    old[field] = Copy(new[field])
                end
            end
        end
        if type(new.Style) == 'table' then
            local style = picked.display and CopyTable(new.Style) or old.Style
            if type(style) == 'table' and type(old.Style) == 'table' then
                for sizeKey in pairs(SIZE_KEYS) do
                    style[sizeKey] = picked[sizeCategory(key)] and new.Style[sizeKey] or old.Style[sizeKey]
                end
            end
            old.Style = style
        end
    end

    -- Tree: the import's when Group Arrangement is picked, the local one otherwise; the root keeps its own place.
    local touched = {}
    for key, id in pairs(ids) do
        if key ~= root and (picked.arrangement or not plan.matches[key]) then
            -- A new display's parent is always here: missing ones are added together or not at all.
            local parentId = ids[d[key].parent]
            if parentId then
                store[id].parent = parentId
                store[id].order = d[key].order
                touched[parentId] = true
            end
        end
    end

    -- A new display goes right after the one before it in the import, when that one is here too.
    if not picked.arrangement then
        for _, key in ipairs(plan.added) do
            local id = ids[key]
            if id then
                local siblings, previous = PayloadChildren(d, d[key].parent), nil
                for _, sibling in ipairs(siblings) do
                    if sibling == key then break end
                    if ids[sibling] then
                        previous = ids[sibling]
                    end
                end
                local parentId = store[id].parent
                if previous and store[previous].parent == parentId then
                    store[id].order = (store[previous].order or 0) + 0.5 -- between it and the next; Renumber evens it out
                else
                    store[id].order = math.huge
                end
            end
        end
    end

    if picked.oldchildren then
        local removed = CopyTable(plan.removed)
        tsort(removed, function(a, b) return CDM:GetDepth(a) > CDM:GetDepth(b) end)
        for _, id in ipairs(removed) do
            if CDM:Get(id) and not (CDM:IsGroup(id) and CDM:GetChildren(id)[1]) then
                touched[store[id].parent or ''] = true
                CDM:Delete(id)
            end
        end
    end

    for parentId in pairs(touched) do
        if store[parentId] then
            Renumber(parentId)
        end
    end

    return plan.target
end

---Add or update displays from a planned import; the caller refreshes the runtime and the page.
---@param plan table from CDM:PlanImport
---@param mode 'copy'|'update'
---@param picked table<string, boolean>? update categories that were ticked
---@return string rootId
function CDM:ApplyImport(plan, mode, picked)
    local rootId
    if mode == 'update' and plan.target and not plan.blocked then
        rootId = ImportAsUpdate(plan, picked or {})
        self:Get(rootId).preferToUpdate = true -- next time this string's newer version comes in, Update is the default
    else
        rootId = ImportAsCopy(plan.payload)
    end
    self:EnsureUids()
    return rootId
end

---@return string
function CDM:GetImportPrefix()
    return PREFIX
end
