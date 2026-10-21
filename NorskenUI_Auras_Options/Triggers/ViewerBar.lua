---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL

local Shared = NRSKNUI.CDMOptions
local CatalogueOptions = Shared.CatalogueOptions
local CataloguePicker = Shared.CataloguePicker
local TriggerRows = Shared.TriggerRows

function TriggerRows.viewerbar(card, typeRow, display, trigger, id, apply)
    typeRow:Dropdown(L['Cooldown Manager'], {
        width = 0.5,
        tooltip = L['A Tracked Bar from the Cooldown Manager, mirrored onto this bar. For entries that are not real auras, like Crusading Strikes.'],
        options = CatalogueOptions({ Enum.CooldownViewerCategory.TrackedBar }),
        value = trigger.CooldownID,
        callback = CataloguePicker(trigger, display, id, apply),
    })
end
