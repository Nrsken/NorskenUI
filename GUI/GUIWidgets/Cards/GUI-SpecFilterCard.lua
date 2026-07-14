---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local ipairs = ipairs
local math_ceil = math.ceil
local table_insert = table.insert
local table_sort = table.sort
local CreateFrame = CreateFrame
local GetNumClasses = GetNumClasses
local GetClassInfo = GetClassInfo
local GetNumSpecializationsForClassID = C_SpecializationInfo.GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local ICON_SIZE = 30
local ICON_SPACING = 2
local CLASS_GAP = 14
local LABEL_HEIGHT = 12
local ROW_HEIGHT = ICON_SIZE + LABEL_HEIGHT + 4

local function BuildClassSpecData()
    local classes = {}
    for classID = 1, GetNumClasses() do
        local className, classFile = GetClassInfo(classID)
        if className and classFile then
            local specs = {}
            local numSpecs = GetNumSpecializationsForClassID(classID)
            for specIndex = 1, numSpecs do
                local specID, specName, _, specIcon = GetSpecializationInfoForClassID(classID, specIndex)
                if specID then
                    table_insert(specs, {
                        id = specID,
                        name = specName,
                        icon = specIcon,
                        classFile = classFile,
                    })
                end
            end
            if #specs > 0 then
                table_insert(classes, {
                    id = classID,
                    name = className,
                    file = classFile,
                    color = RAID_CLASS_COLORS[classFile] or { r = 1, g = 1, b = 1 },
                    specs = specs,
                })
            end
        end
    end
    table_sort(classes, function(a, b) return a.name < b.name end)
    return classes
end

local cachedClassSpecData = nil
local function GetClassSpecData()
    if not cachedClassSpecData then
        cachedClassSpecData = BuildClassSpecData()
    end
    return cachedClassSpecData
end

local function CreateSpecIcon(parent, spec, classColor, isSelected, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE - 2, ICON_SIZE - 2)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexture(spec.icon)
    icon:SetZoom()

    local function UpdateVisual(selected)
        if selected then
            btn:SetBackdropColor(0, 0, 0, 1)
            btn:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
            icon:SetDesaturated(false)
            icon:SetAlpha(1)
        else
            btn:SetBackdropColor(0, 0, 0, 0.5)
            btn:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
            icon:SetDesaturated(true)
            icon:SetAlpha(0.35)
        end
    end

    btn.selected = isSelected
    UpdateVisual(isSelected)

    btn:SetScript("OnClick", function()
        btn.selected = not btn.selected
        UpdateVisual(btn.selected)
        if onClick then onClick(btn.selected) end
    end)

    btn:SetScript("OnEnter", function()
        icon:SetAlpha(1)
        icon:SetDesaturated(false)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT", 4, 0)
        GameTooltip:SetText(spec.name, classColor.r, classColor.g, classColor.b, 1)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        UpdateVisual(btn.selected)
        GameTooltip:Hide()
    end)

    btn.SetSelected = function(_, selected)
        btn.selected = selected
        UpdateVisual(selected)
    end

    return btn
end

local function CreateClassGroup(parent, classData, selectedSpecs, db, keys, onChange, specButtons)
    local container = CreateFrame("Frame", nil, parent)
    local classColor = classData.color
    local numSpecs = #classData.specs
    local groupWidth = numSpecs * (ICON_SIZE + ICON_SPACING) - ICON_SPACING

    container:SetSize(groupWidth, ICON_SIZE + LABEL_HEIGHT)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 2)
    NRSKNUI:ApplyThemeFont(label, "small")
    label:SetText(classData.name)
    label:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
    label:SetShadowColor(0, 0, 0, 0)

    for specIndex, spec in ipairs(classData.specs) do
        local isSelected = selectedSpecs[spec.id] == true
        local specBtn = CreateSpecIcon(container, spec, classColor, isSelected, function(selected)
            db[keys.specs] = db[keys.specs] or {}
            if selected then
                db[keys.specs][spec.id] = true
            else
                db[keys.specs][spec.id] = nil
            end
            if onChange then onChange() end
        end)

        specBtn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", (specIndex - 1) * (ICON_SIZE + ICON_SPACING), 0)
        specBtn.specID = spec.id
        table_insert(specButtons, specBtn)
    end

    return container, groupWidth
end

---Spec filter card with enable toggle and compact icon grid
---@param scrollChild Frame
---@param yOffset number
---@param config table
---@return table card
---@return number newYOffset
function GUIFrame:CreateSpecFilterCard(scrollChild, yOffset, config)
    config = config or {}
    local title = config.title or "Specialization Filter"
    local db = config.db
    local dbKeys = config.dbKeys or {}
    local onChange = config.onChangeCallback

    local keys = {
        enabled = dbKeys.enabled or "loadSpecEnabled",
        specs = dbKeys.specs or "loadSpecs",
    }

    local specButtons = {}
    local card = GUIFrame:CreateCard(scrollChild, title, yOffset)

    local isEnabled = db[keys.enabled] or false
    local selectedSpecs = db[keys.specs] or {}

    local row1 = GUIFrame:CreateRow(card.content, Theme.rowHeight)
    local specToggle = GUIFrame:CreateCheckbox(row1, "Filter by Specialization", {
        value = isEnabled,
        callback = function(checked)
            db[keys.enabled] = checked
            if onChange then onChange() end
        end
    })
    row1:AddWidget(specToggle, 1)
    card:AddRow(row1, Theme.rowHeight)

    if isEnabled then
        local separator = GUIFrame:CreateSeparator(card.content)
        card:AddRow(separator, Theme.rowHeightSeparator)

        local btnRow = GUIFrame:CreateRow(card.content, 26)
        local selectAllBtn = GUIFrame:CreateButton(btnRow, "All", {
            height = 22,
            callback = function()
                db[keys.specs] = db[keys.specs] or {}
                for _, btn in ipairs(specButtons) do
                    db[keys.specs][btn.specID] = true
                    btn:SetSelected(true)
                end
                if onChange then onChange() end
            end,
        })
        btnRow:AddWidget(selectAllBtn, 0.5)

        local clearAllBtn = GUIFrame:CreateButton(btnRow, "None", {
            height = 22,
            callback = function()
                db[keys.specs] = {}
                for _, btn in ipairs(specButtons) do
                    btn:SetSelected(false)
                end
                if onChange then onChange() end
            end,
        })
        btnRow:AddWidget(clearAllBtn, 0.5)
        card:AddRow(btnRow, 26)

        local classSpecData = GetClassSpecData()
        local numClasses = #classSpecData
        local numRows = math_ceil(numClasses / 2)

        for rowIndex = 1, numRows do
            local gridRow = GUIFrame:CreateRow(card.content, ROW_HEIGHT)
            local rowContainer = CreateFrame("Frame", nil, gridRow)
            rowContainer:SetPoint("TOPLEFT", gridRow, "TOPLEFT", 4, 0)
            rowContainer:SetPoint("BOTTOMRIGHT", gridRow, "BOTTOMRIGHT", -4, 0)

            local leftIdx = (rowIndex - 1) * 2 + 1
            local rightIdx = leftIdx + 1

            local leftClass = classSpecData[leftIdx]
            if leftClass then
                local leftGroup = CreateClassGroup(rowContainer, leftClass, selectedSpecs, db, keys, onChange,
                    specButtons)
                leftGroup:SetPoint("LEFT", rowContainer, "LEFT", 0, 0)
            end

            local rightClass = classSpecData[rightIdx]
            if rightClass then
                local rightGroup = CreateClassGroup(rowContainer, rightClass, selectedSpecs, db, keys, onChange,
                    specButtons)
                rightGroup:SetPoint("LEFT", rowContainer, "CENTER", CLASS_GAP / 2, 0)
            end

            card:AddRow(gridRow, ROW_HEIGHT)
        end
    end

    card.specButtons = specButtons

    function card:SetEnabled(enabled)
        if enabled then
            self:SetAlpha(1)
        else
            self:SetAlpha(0.5)
        end
        for _, btn in ipairs(self.specButtons) do
            btn:EnableMouse(enabled)
        end
    end

    return card, card:GetNextOffset()
end
