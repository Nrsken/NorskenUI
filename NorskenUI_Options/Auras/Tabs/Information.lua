---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tconcat = table.concat
local ipairs = ipairs
local tostring = tostring
local format = string.format

local Shared = NRSKNUI.CDMOptions
local RefreshTree, TYPE_NAMES = Shared.RefreshTree, Shared.TYPE_NAMES

local DESCRIPTION_HEIGHT = 80

---@param page table
---@param id string
local function BuildInformationTab(page, id)
    local display = CDM:Get(id)

    -- Card 1
    local infoCard = page:Card(L['Information'], 'all')
    infoCard:Row(rowH):EditBox(L['Name'], {
        width = 1,
        value = display.name,
        callback = function(text)
            text = strtrim(text or '')
            if text == '' then return end
            CDM:Rename(id, text)
            RefreshTree()
        end,
    })
    infoCard:Row(DESCRIPTION_HEIGHT + 18, 0):MultiLineEditBox(L['Description'], {
        width = 1,
        height = DESCRIPTION_HEIGHT,
        value = display.Description or '',
        callback = function(text)
            text = strtrim(text or '')
            display.Description = text ~= '' and text or nil
        end,
    })

    -- Card 2
    local names = {}
    local ancestors = CDM:GetAncestors(id)
    for i = #ancestors, 1, -1 do names[#names + 1] = CDM:GetName(ancestors[i]) end
    local lines = {
        format('%s: %s', L['ID'], id),
        format('%s: %s', L['UID'], tostring(display.uid)),
        format('%s: %s', L['Type'], TYPE_NAMES[display.type] or display.type),
        format('%s: %s', L['Group'], names[1] and tconcat(names, ' » ') or L['None']),
    }
    if CDM:IsGroup(id) then
        lines[#lines + 1] = format('%s: %d', L['Children'], #CDM:GetChildren(id))
        lines[#lines + 1] = format('%s: %d', L['Displays Inside'], #CDM:GetLeaves(id))
    elseif display.Triggers then
        lines[#lines + 1] = format('%s: %d', L['Triggers'], #display.Triggers)
        lines[#lines + 1] = format('%s: %d', L['Conditions'], #(display.Conditions or {}))
        lines[#lines + 1] = format('%s: %d', L['Sub Elements'], #(display.SubRegions or {}))
    end
    local metaHeight = #lines * 16
    page:Card(L['Metadata'], 'all'):Row(metaHeight, 0):Text(nil, { width = 1, height = metaHeight, autoHeight = true, bgMode = 'hide', text = lines })

    -- Card 3
    local warnings = CDM:GetWarnings(id)
    if warnings[1] then
        for i, warning in ipairs(warnings) do warnings[i] = NRSKNUI:ColorText(warning, Theme.warning) end
        local warnHeight = #warnings * 16
        page:Card(L['Warnings'], 'all'):Row(warnHeight, 0):Text(nil, { width = 1, height = warnHeight, autoHeight = true, bgMode = 'hide', text = warnings })
    end

    -- Card 4
    local debugHeight = 24
    page:Card(L['Debug'], 'all'):Row(debugHeight):Button(L['Create Debug Report'], {
        width = 1,
        height = debugHeight,
        tooltip = L['Sends a report of what this display is doing right now to BugSack, or to chat without it.'],
        callback = function() CDM:PrintDebug(id) end,
    })
end

Shared.BuildInformationTab = BuildInformationTab
