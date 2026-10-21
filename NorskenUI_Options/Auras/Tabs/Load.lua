---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast
local Shared = NRSKNUI.CDMOptions

local CopyTable = CopyTable

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
