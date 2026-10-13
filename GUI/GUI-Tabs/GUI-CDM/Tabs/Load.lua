---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast

local CopyTable = CopyTable

local Shared = NRSKNUI.CDMOptions

---A group's load settings are its icons' and aura groups', edited together as in WeakAuras.
---@param page table
---@param id string
local function BuildLoadTab(page, id)
    local iconIds = CDM:IsGroup(id) and CDM:GetLeaves(id) or { id }
    if #iconIds == 0 then
        page:Card(L['Load']):Row(rowHL, 0):Text(L['This group has no icons yet.'], { width = 1 })
        return
    end

    local first = CDM:Get(iconIds[1])
    page:LoadConditionsCard({
        db = first.Load,
        specs = true,
        onChangeCallback = function()
            for i = 2, #iconIds do CDM:Get(iconIds[i]).Load = CopyTable(first.Load) end
            CDM:RefreshLoad()
        end,
    })
end

Shared.BuildLoadTab = BuildLoadTab
