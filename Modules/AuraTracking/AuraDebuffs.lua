---@class NRSKNUI
local NRSKNUI = select(2, ...)

if not NorskenUI then
    error("AuraDebuffs: Addon object not initialized!")
    return
end

local CreateFrame = CreateFrame
local ipairs = ipairs

---@class AuraDebuffs: AceModule, AceEvent-3.0
local DBF = NorskenUI:NewModule("AuraDebuffs", "AceEvent-3.0")

DBF.buttons = {}

function DBF:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.DebuffTracking
end

function DBF:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function CreateAuraContainer()
    local db = DBF.db
    local container = CreateFrame("AuraContainer", "NRSKNUI_DebuffContainer", UIParent, "CustomAuraContainerTemplate") -- TODO: change to "ManagedAuraContainerTemplate" once PTR4 is live
    NRSKNUI:ApplyAuraMixin(container)

    local width, height = container:GetContainerSizeMix(db)
    container:SetSize(width, height)
    container:SetUnit("player")
    container:AddAuraFilter("HARMFUL", { maxFrameCount = db.MaxIcons })
    container:ApplyContainerPositionMix(container, db)

    return container
end

-- TODO: Probably fully remove once PTR4 is live, since the new ManagedAuraContainerTemplate handles everything
local function CreateAuraButtons(container)
    local db = DBF.db

    for i = 1, db.MaxIcons do
        -- Create an AuraButton for the container
        local auraButton = NRSKNUI:ApplyAuraMixin(CreateFrame("AuraButton", nil, container, "CustomAuraButtonTemplate"))
        auraButton:SetSize(db.IconSize, db.IconSize)
        auraButton:SetButtonPositionMix(container, db, i)
        auraButton:SetBorderMix(auraButton)
        auraButton:SetMouseMotionEnabled(db.ShowTooltips)

        table.insert(DBF.buttons, auraButton)

        -- Dispel border
        if db.ShowDispelBorder then
            auraButton.DispelBorder = auraButton:CreateTexture(nil, "OVERLAY")
            auraButton:SetOverlayMix(auraButton, auraButton.DispelBorder)
            auraButton:SetAuraBorder(auraButton.DispelBorder, {
                showWhenHarmful = true,
                showWhenHelpful = false,
                style = 1, -- 0: Atlas texture, 1: Color, can be used with custom texture
            })
        end

        -- Dispel text, only shown if colorblind mode is enabled
        if db.ColorBlindText and db.ShowDispelBorder == true then
            local CBPos = db.ColorBlindPosition
            auraButton.Symbol = auraButton:CreateFontString(nil, "OVERLAY")
            auraButton.Symbol:SetPoint(CBPos.AnchorFrom, auraButton, CBPos.AnchorTo, CBPos.XOffset, CBPos.YOffset)
            auraButton:SetTextStyleMix(auraButton.Symbol, db, db.ColorBlindFontSize)
            auraButton:SetAuraSymbol(auraButton.Symbol, {
                showWhenHarmful = true,
                showWhenHelpful = false,
            })
        end

        -- Icon texture
        auraButton.Icon = auraButton:CreateTexture(nil, "BORDER")
        auraButton.Icon:SetAllPoints()
        auraButton:SetIcon(auraButton.Icon)
        auraButton:SetZoomMix(auraButton.Icon)

        -- Cooldown swipe + text
        auraButton.Cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        auraButton:SetCooldownStyleMix(auraButton, auraButton.Cooldown, db)
        auraButton:SetCooldownTextStyleMix(auraButton.Cooldown, db)

        -- Count text
        local StackPos = db.StackPosition
        auraButton.CountText = auraButton.Cooldown:CreateFontString(nil, "OVERLAY")
        auraButton.CountText:SetPoint(StackPos.AnchorFrom, auraButton, StackPos.AnchorTo, StackPos.XOffset, StackPos.YOffset)
        auraButton:SetTextStyleMix(auraButton.CountText, db, db.StackFontSize)
        auraButton:SetApplicationCount(auraButton.CountText, {})

        -- Add the AuraButton to the container
        container:AddAuraFrame(auraButton)
    end
end

local function StyleButton(auraButton, i)
    if not auraButton then return end
    local db = DBF.db

    if auraButton.Cooldown then
        auraButton.Cooldown:SetReverse(db.Reverse)
        auraButton.Cooldown:SetDrawSwipe(db.Swipe)
        auraButton:SetCooldownTextStyleMix(auraButton.Cooldown, db)
    end

    if auraButton.CountText then
        local StackPos = db.StackPosition
        auraButton.CountText:ClearAllPoints()
        auraButton.CountText:SetPoint(StackPos.AnchorFrom, auraButton, StackPos.AnchorTo, StackPos.XOffset, StackPos.YOffset)
        auraButton:SetTextStyleMix(auraButton.CountText, db, db.StackFontSize)
    end

    auraButton:SetSize(db.IconSize, db.IconSize)
    auraButton:SetButtonPositionMix(DBF.container, db, i)
    auraButton:SetMouseMotionEnabled(db.ShowTooltips)
end

function DBF:ApplySettings()
    if not self.db.Enabled or not self.container then return end

    local width, height = self.container:GetContainerSizeMix(self.db)
    self.container:SetSize(width, height)
    self.container:ApplyContainerPositionMix(self.container, self.db)

    for i, auraButton in ipairs(self.buttons) do
        StyleButton(auraButton, i)
    end
end

function DBF:OnEnable()
    if not self.db.Enabled then return end

    local container = CreateAuraContainer()
    if container then
        CreateAuraButtons(container)
        self.container = container
    end
end
