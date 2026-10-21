---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
local L = NRSKNUI.Libs.AL

local Shared = NRSKNUI.CDMOptions
local CatalogueOptions = Shared.CatalogueOptions
local CataloguePicker = Shared.CataloguePicker
local TriggerRows = Shared.TriggerRows

function TriggerRows.totem(card, typeRow, display, trigger, id, apply)
    local Category = Enum.CooldownViewerCategory
    typeRow:Dropdown(L['Cooldown Manager'], {
        width = 0.5,
        tooltip = L['The spell that summons the totem.'],
        options = CatalogueOptions({ Category.Essential, Category.Utility }),
        value = trigger.CooldownID,
        callback = CataloguePicker(trigger, display, id, apply),
    })
end
