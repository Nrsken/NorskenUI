---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class MiscVarsModule
local MiscVars = NRSKNUI:GetModule('MiscVars')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs

local function AddCVarWidget(card, def, isLast)
    local key = def.key
    local tooltip = def.description and { text = def.description, default = def.default } or nil
    local currentValue = MiscVars:GetCVar(key)
    local row = card:Row(isLast and rowHL or rowH, isLast and 0 or nil)

    if def.type == 'boolean' then
        row:Checkbox(def.label, {
            width = 1,
            value = currentValue,
            tooltip = tooltip,
            cvartooltip = true,
            callback = function(checked)
                MiscVars:SetCVar(key, checked)
            end,
        })
    elseif def.type == 'number' then
        row:Slider(def.label, {
            width = 1,
            min = def.min,
            max = def.max,
            step = def.step,
            value = currentValue or def.default,
            tooltip = tooltip,
            cvartooltip = true,
            callback = function(val)
                MiscVars:SetCVar(key, val)
            end,
        })
    end
end

-- General CVars Tab.
local function BuildGeneralSettingsTab(page, db)
    local generalDefs = {}
    for _, def in ipairs(MiscVars.DEFS) do
        if not def.category then
            generalDefs[#generalDefs + 1] = def
        end
    end

    local card = page:Card(L['CVar Browser'])
    for i, def in ipairs(generalDefs) do
        AddCVarWidget(card, def, i == #generalDefs)
        if i < #generalDefs then card:Separator() end
    end
end

-- Spell Queue Window Tab.
local function BuildSQWCVarSettingsTab(page, db)
    local card = page:Card(L['Spell Queue Window'])
    local position = NRSKNUI.MySpec and NRSKNUI.MySpec.position

    for i, def in ipairs(MiscVars.SQW_DEFS) do
        local label = def.label
        if def.position == 'MELEE' then
            label = label .. ' ' .. (position == 'MELEE' and '|cff00ff00(Active)|r' or '|cffaaaaaa(Inactive)|r')
        elseif def.position == 'RANGED' then
            label = label .. ' ' .. (position == 'RANGED' and '|cff00ff00(Active)|r' or '|cffaaaaaa(Inactive)|r')
        end

        local key = def.key
        local tooltip = def.description and { text = def.description, default = def.default } or nil
        card:Row(rowH):Slider(label, {
            width = 1,
            min = def.min,
            max = def.max,
            step = def.step,
            value = MiscVars:GetSQW(key),
            tooltip = tooltip,
            cvartooltip = true,
            callback = function(val)
                MiscVars:SetSQW(key, val)
            end,
        })
        if i < #MiscVars.SQW_DEFS then card:Separator() end
    end

    card:Separator()

    local infoHeight = 70
    local infoRow = card:Row(infoHeight, 0)
    infoRow:Text(NRSKNUI:ColorTextByTheme(L['Learn More']), {
        width = 0.65,
        text =
        "The spell queue window determines how early you can\nqueue your next ability before your current cast finishes.\nVisit |cff8788EEXerwo|r's maxroll guide for more information.",
        height = infoHeight,
        autoHeight = true,
        bgMode = 'hide',
    })
    infoRow:Button(L['Open Guide'], {
        width = 0.35,
        height = 36,
        callback = function()
            NRSKNUI:CreateCopyDialog(
                'Spell Queue Window Guide',
                'https://maxroll.gg/wow/resources/spell-queue-window',
                'Copy to clipboard by pressing CTRL + C'
            )
        end,
    })
end

-- Combat Text CVars Tab.
local function BuildCombatTextCVarSettingsTab(page, db)
    local combatTextDefs = {}
    for _, def in ipairs(MiscVars.DEFS) do
        if def.category == 'combatTexts' then
            combatTextDefs[#combatTextDefs + 1] = def
        end
    end

    local card = page:Card(L['Combat Text CVars'])
    for i, def in ipairs(combatTextDefs) do
        AddCVarWidget(card, def, i == #combatTextDefs)
        if i < #combatTextDefs then card:Separator() end
    end
end

-- Dev CVars Tab.
local function BuildDevCVarSettingsTab(page, db)
    local devDefs = {}
    for _, def in ipairs(MiscVars.DEFS) do
        if def.category == 'dev' then
            devDefs[#devDefs + 1] = def
        end
    end

    local card = page:Card(L['Dev CVars'])
    for i, def in ipairs(devDefs) do
        AddCVarWidget(card, def, i == #devDefs)
        if i < #devDefs then card:Separator() end
    end
end

GUI:RegisterPage('miscVars', {
    mode = 'tabs',
    search = {},
    tabs = {
        { id = 'general',         text = L['General CVars'] },
        { id = 'sqwCvars',        text = L['SQW CVar'] },
        { id = 'combatTextCvars', text = L['Combat Text CVars'] },
        { id = 'devCvars',        text = L['Dev CVars'] },
    },
    build = function(page, tabId)
        local db = NRSKNUI.db.profile.Miscellaneous.MiscVars
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if tabId == 'general' then
            BuildGeneralSettingsTab(page, db)
        elseif tabId == 'sqwCvars' then
            BuildSQWCVarSettingsTab(page, db)
        elseif tabId == 'combatTextCvars' then
            BuildCombatTextCVarSettingsTab(page, db)
        elseif tabId == 'devCvars' then
            BuildDevCVarSettingsTab(page, db)
        end
    end,
})
