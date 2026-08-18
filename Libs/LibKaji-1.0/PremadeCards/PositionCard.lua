--[[
# PositionCard

* Premade card for configuring a frame's position with anchor points and offsets.
* Uses a 9-point anchor selector (see AnchorPicker) and sliders for X/Y offsets.

## Examples

    page:PositionCard({
        db = db,
        showStrata = true,
        onChangeCallback = Apply
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall

lib.premadeCards = lib.premadeCards or {}

local ipairs, pairs = ipairs, pairs
local tinsert = table.insert

local ANCHOR_FRAME_TYPES = {
    { key = "SCREEN",      text = "Screen Center" },
    { key = "UIPARENT",    text = "Screen (UIParent)" },
    { key = "SELECTFRAME", text = "Select Frame" },
}

local STRATA_LIST = {
    { key = "TOOLTIP",           text = "Tooltip" },
    { key = "FULLSCREEN_DIALOG", text = "Fullscreen Dialog" },
    { key = "FULLSCREEN",        text = "Fullscreen" },
    { key = "DIALOG",            text = "Dialog" },
    { key = "HIGH",              text = "High" },
    { key = "MEDIUM",            text = "Medium" },
    { key = "LOW",               text = "Low" },
    { key = "BACKGROUND",        text = "Background" },
}

--- 9-point anchor selector + offset sliders bound to a db table.
lib.premadeCards.PositionCard = {
    title = "Position Settings",

    ---@param card KajiGUIFluentCard
    ---@param config table
    ---@param gui KajiGUIInstance
    build = function(card, config, gui)
        local theme = gui.theme
        local db = config.db
        local dbKeys = config.dbKeys or {}
        local defaults = config.defaults or {}
        local onChange = config.onChangeCallback
        local onContextChange = config.onContextChange
        local showAnchorFrameType = config.showAnchorFrameType ~= false
        local showStrata = config.showStrata == true
        local sliderRange = config.sliderRange or { -2000, 2000 }
        local contextOptions = config.contextOptions
        local splitToggleKey = config.splitToggleKey
        local disableAnchorFrom = config.disableAnchorFrom == true

        local keys = {
            anchorFrameType = dbKeys.anchorFrameType or "anchorFrameType",
            anchorFrameFrame = dbKeys.anchorFrameFrame or "ParentFrame",
            selfPoint = dbKeys.selfPoint or "AnchorFrom",
            anchorPoint = dbKeys.anchorPoint or "AnchorTo",
            xOffset = dbKeys.xOffset or "XOffset",
            yOffset = dbKeys.yOffset or "YOffset",
            strata = dbKeys.strata or "Strata",
        }
        local rootKeys = { [keys.anchorFrameType] = true, [keys.anchorFrameFrame] = true, [keys.strata] = true }

        local currentContext = config.defaultContext
        local currentPositionKey = "Position"
        if contextOptions and #contextOptions > 0 then
            currentContext = currentContext or contextOptions[1].key
            for _, opt in ipairs(contextOptions) do
                if opt.key == currentContext then
                    currentPositionKey = opt.positionKey
                    break
                end
            end
        end

        local function getPositionTable() return db[currentPositionKey] end

        local function getValue(key, default)
            if rootKeys[key] then
                if db[key] ~= nil then return db[key] end
                return default
            end
            local posTable = getPositionTable()
            if posTable and posTable[key] ~= nil then
                return posTable[key]
            elseif db[key] ~= nil then
                return db[key]
            end
            return default
        end

        local function setValue(key, val)
            if rootKeys[key] then
                db[key] = val
            else
                local posTable = getPositionTable()
                if posTable then posTable[key] = val else db[key] = val end
            end
            if onChange then onChange() end

            -- Let the host's mover overlay follow the change. Safe against feedback:
            -- the host only re-reads and RefreshPositions pushes back silently.
            local sync = gui.services.positionSync
            if sync then safecall(sync.Changed) end
        end

        local selfPointWidget, anchorPointWidget, xSlider, ySlider, contextDropdown

        -- Sliders are pushed silently: SetValue fires the callback, which would write the
        -- value straight back to the db and re-notify, looping with the anchor overlay.
        local function refreshPositionWidgets()
            if selfPointWidget then selfPointWidget:SetValue(getValue(keys.selfPoint, defaults.selfPoint or "CENTER")) end
            if anchorPointWidget then anchorPointWidget:SetValue(getValue(keys.anchorPoint, defaults.anchorPoint or "CENTER")) end
            if xSlider then xSlider:SetValueSilent(getValue(keys.xOffset, defaults.xOffset or 0)) end
            if ySlider then ySlider:SetValueSilent(getValue(keys.yOffset, defaults.yOffset or 0)) end
        end

        local currentType = getValue(keys.anchorFrameType, defaults.anchorFrameType or "SCREEN")

        if contextOptions and #contextOptions > 0 then
            local contextRow = card:Row(theme.rowHeight)
            local contextList = {}
            for _, opt in ipairs(contextOptions) do tinsert(contextList, { key = opt.key, text = opt.text }) end

            if splitToggleKey then
                contextRow:Checkbox("Split Positioning", {
                    width = 0.5,
                    value = db[splitToggleKey],
                    callback = function(checked)
                        db[splitToggleKey] = checked
                        if not checked then
                            currentPositionKey = contextOptions[1].positionKey
                            refreshPositionWidgets()
                        end
                        if onChange then onChange() end
                    end,
                })
            end

            contextDropdown = contextRow:Dropdown("Configure For", {
                width = 0.5,
                options = contextList,
                value = currentContext,
                callback = function(key)
                    currentContext = key
                    for _, opt in ipairs(contextOptions) do
                        if opt.key == key then
                            currentPositionKey = opt.positionKey
                            break
                        end
                    end
                    refreshPositionWidgets()
                    if onContextChange then onContextChange(key, currentPositionKey) end
                end,
            })

            card:Separator()
        end

        if showAnchorFrameType then
            local anchorTypeList = {}
            for _, opt in ipairs(ANCHOR_FRAME_TYPES) do anchorTypeList[opt.key] = opt.text end

            card:Row(40):Dropdown("Anchored To", {
                width = 1,
                options = anchorTypeList,
                value = currentType,
                callback = function(key)
                    setValue(keys.anchorFrameType, key)
                    -- SELECTFRAME adds a row, and the anchor label changes with the type.
                    card:Rebuild()
                end,
            })

            if currentType == "SELECTFRAME" then
                local row2 = card:Row(40)
                local frameInput = row2:EditBox("Frame", {
                    width = 0.5,
                    value = getValue(keys.anchorFrameFrame, ""),
                    callback = function(val) setValue(keys.anchorFrameFrame, val ~= "" and val or nil) end,
                })

                -- The host may inject its own picker; otherwise the library's is used.
                local frameChooser = gui.services.frameChooser or gui:GetFrameChooser()
                row2:Button("Select Frame", {
                    width = 0.5,
                    height = 24,
                    yOffset = -14,
                    callback = function()
                        frameChooser:Start(function(frameName, isPreview)
                            if frameName then
                                frameInput:SetValue(frameName)
                                if not isPreview then setValue(keys.anchorFrameFrame, frameName) end
                            end
                        end, getValue(keys.anchorFrameFrame, ""))
                    end,
                })
            end
        end

        local row3 = card:Row(80)
        selfPointWidget = row3:AnchorPicker("Anchor From", {
            width = 0.5,
            value = getValue(keys.selfPoint, defaults.selfPoint or "CENTER"),
            callback = function(val) setValue(keys.selfPoint, val) end,
        })
        if disableAnchorFrom then selfPointWidget:SetEnabled(false) end

        local anchorPointLabel = showAnchorFrameType and (currentType == "SELECTFRAME" and "To Frame's" or "To Screen's") or
            "To Frame's"
        anchorPointWidget = row3:AnchorPicker(anchorPointLabel, {
            width = 0.5,
            value = getValue(keys.anchorPoint, defaults.anchorPoint or "CENTER"),
            callback = function(val) setValue(keys.anchorPoint, val) end,
        })

        local row4 = card:Row(40, showStrata and nil or 0)
        xSlider = row4:Slider("X Offset", {
            width = 0.5,
            min = sliderRange[1],
            max = sliderRange[2],
            step = 1,
            value = getValue(keys.xOffset, defaults.xOffset or 0),
            labelWidth = 55,
            callback = function(val) setValue(keys.xOffset, val) end,
        })

        ySlider = row4:Slider("Y Offset", {
            width = 0.5,
            min = sliderRange[1],
            max = sliderRange[2],
            step = 1,
            value = getValue(keys.yOffset, defaults.yOffset or 0),
            labelWidth = 55,
            callback = function(val) setValue(keys.yOffset, val) end,
        })

        if showStrata then
            card:Row(theme.rowHeightLast, 0):Dropdown("Strata", {
                width = 1,
                options = STRATA_LIST,
                value = getValue(keys.strata, defaults.strata or "HIGH"),
                callback = function(key) setValue(keys.strata, key) end,
            })
        end

        -- Two controls are not purely a function of the card's enabled state, so they are
        -- re-derived after the manager's blanket pass.
        card:SetEnabledHandler(function(enabled)
            if not enabled then return end
            if contextDropdown and splitToggleKey and not db[splitToggleKey] then
                contextDropdown:SetEnabled(false)
            end
            if disableAnchorFrom and selfPointWidget then
                selfPointWidget:SetEnabled(false)
            end
        end)

        -- Lets the host's mover overlay push dragged values back into the sliders.
        card:OnExternalRefresh(refreshPositionWidgets)
    end,
}

---Re-syncs every live position card from the db, e.g. after a mover drag.
---The acquired set is already exactly the live widgets, so there is no separate card
---list to keep pruned: a card released with the page simply stops being visited.
function InstanceMixin:RefreshPositionCards()
    for widget in pairs(self._acquired) do
        if widget._refreshPositions then widget._refreshPositions() end
    end
end
