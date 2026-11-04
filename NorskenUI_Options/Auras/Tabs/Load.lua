---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast
local Shared = NRSKNUI.CDMOptions

local Assign = NRSKNUI.CDMDisplayTab.Assign

local pairs, ipairs = pairs, ipairs
local type = type
local unpack = unpack
local CopyTable = CopyTable

---The values that differ between two load tables, by path. Unset and false are both unticked; the open category is the card's own.
---@param old table
---@param new table
---@param path string[]
---@param changes { path: string[], value: any }[]
local function Diff(old, new, path, changes)
    local keys = {}
    for key in pairs(old) do
        keys[key] = true
    end
    for key in pairs(new) do
        keys[key] = true
    end

    for key in pairs(keys) do
        local before, after = old[key], new[key]
        local at = { unpack(path) }
        at[#at + 1] = key
        if type(before) == 'table' or type(after) == 'table' then
            Diff(type(before) == 'table' and before or {}, type(after) == 'table' and after or {}, at, changes)
        elseif key ~= 'SelectedCategory' and (before or false) ~= (after or false) then
            changes[#changes + 1] = { path = at, value = after }
        end
    end
end

---Two load values read the same: unset, false, '' and an empty table all mean nothing picked; the open category is the card's own.
---@param a any
---@param b any
---@return boolean
local function Same(a, b)
    if type(a) == 'table' or type(b) == 'table' then
        local ta, tb = type(a) == 'table' and a or {}, type(b) == 'table' and b or {}
        for key, value in pairs(ta) do
            if key ~= 'SelectedCategory' and not Same(value, tb[key]) then return false end
        end
        for key, value in pairs(tb) do
            if key ~= 'SelectedCategory' and not Same(ta[key], value) then return false end
        end
        return true
    end
    if a == '' then
        a = nil
    end
    if b == '' then
        b = nil
    end
    return (a or false) == (b or false)
end

---@param load table
---@param path (string|number)[]
---@return any
local function Read(load, path)
    local node = load
    for _, key in ipairs(path) do
        if type(node) ~= 'table' then return nil end
        node = node[key]
    end
    return node
end

---@param page table
---@param id string
local function BuildLoadTab(page, id)
    local iconIds, multi = Shared.EditTargets(id)

    -- WA keeps its off switch here as Never; ours is each picked row's own Enabled, as Disable in the right-click menu
    local owners = multi and Shared.Tree():GetPicked() or { id }
    local off, mixed = 0, {}
    for i, key in ipairs(owners) do
        local enabled = CDM:Get(key).Enabled
        off = off + (enabled and 0 or 1)
        mixed[i] = { name = CDM:GetName(key), value = not enabled }
    end
    page:Card(L['Load'], 'all'):Row(rowHL, 0):Checkbox(L['Never'], {
        width = 0.5,
        tooltip = L['Never load this, whatever the conditions below say. A group takes everything inside it along.'],
        value = off == #owners,
        mixed = off > 0 and off < #owners and mixed or nil,
        callback = function(checked)
            for _, key in ipairs(owners) do
                CDM:Get(key).Enabled = not checked
            end
            -- only what's loaded changes; a disabled display keeps its frame, so nothing needs rebuilding
            CDM:RefreshLoad()
        end,
    })

    if #iconIds == 0 then
        page:Card(L['Load']):Row(rowHL, 0):Text(L['This group has no icons yet.'], { width = 1 })
        return
    end

    local first = CDM:Get(iconIds[1])
    local before = CopyTable(first.Load)
    page:LoadConditionsCard({
        db = first.Load,
        specs = true,
        -- each one's value where they disagree, which the card marks
        mixed = function(path)
            local base = Read(first.Load, path)
            local differs = false
            for i = 2, #iconIds do
                differs = differs or not Same(base, Read(CDM:Get(iconIds[i]).Load, path))
            end
            if not differs then return nil end

            local entries = {}
            for i, key in ipairs(iconIds) do
                entries[i] = { name = CDM:GetName(key), value = Read(CDM:Get(key).Load, path) }
            end
            return entries
        end,
        onChangeCallback = function(path, value)
            -- The card edits the first one in place; the rest take only what changed, so their other settings stay their own.
            -- One setting goes over as it is, even where the first already had it (a mixed box ticked); a bulk change
            -- (a class's specs, a talent pick) has no one path, so what changed on the first goes over instead.
            if path then
                for i = 2, #iconIds do
                    Assign(CDM:Get(iconIds[i]).Load, path, value)
                end
            else
                local changes = {}
                Diff(before, first.Load, {}, changes)
                for i = 2, #iconIds do
                    local load = CDM:Get(iconIds[i]).Load
                    for _, change in ipairs(changes) do
                        Assign(load, change.path, change.value)
                    end
                end
            end
            before = CopyTable(first.Load)

            CDM:RefreshLoad()
        end,
    })
end

Shared.BuildLoadTab = BuildLoadTab
