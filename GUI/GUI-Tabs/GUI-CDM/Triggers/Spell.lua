---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local Shared = NRSKNUI.CDMOptions
local CatalogueOptions = Shared.CatalogueOptions
local CataloguePicker = Shared.CataloguePicker
local TriggerRows = Shared.TriggerRows

function TriggerRows.spell(card, typeRow, display, trigger, id, apply)
    local Category = Enum.CooldownViewerCategory
    typeRow:Dropdown(L['Cooldown Manager'], {
        width = 0.5,
        tooltip = L["Spells Blizzard's Cooldown Manager tracks for your current spec."],
        options = CatalogueOptions({ Category.Essential, Category.Utility }),
        value = trigger.CooldownID,
        callback = CataloguePicker(trigger, display, id, apply),
    })
    card:Row(rowH):Checkbox(L['Ignore Override'], {
        width = 0.5,
        tooltip = L["Keep tracking this spell's own cooldown and charges while another spell replaces it."],
        value = trigger.IgnoreOverride,
        callback = function(checked)
            trigger.IgnoreOverride = checked or nil
            apply()
        end,
    })
end
