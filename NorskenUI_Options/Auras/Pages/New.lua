---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local pixel = NRSKNUI.Libs.KAJI.Pixel

local CreateFrame = CreateFrame
local GetTime = GetTime
local ipairs = ipairs
local floor = math.floor

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture

local Shared = NRSKNUI.CDMOptions
local IMPORT, NEW_TILE_HEIGHT, NEW_TILE_ICON, NEW_TILE_PREVIEW = Shared.IMPORT, Shared.NEW_TILE_HEIGHT, Shared.NEW_TILE_ICON, Shared.NEW_TILE_PREVIEW
local NewAuraGroup, NewGroup, NewIcon, NewProgressBar = Shared.NewAuraGroup, Shared.NewGroup, Shared.NewIcon, Shared.NewProgressBar
local NewResourceBar, NewText, Reopen = Shared.NewResourceBar, Shared.NewText, Shared.Reopen

-- New page pictures: small versions of each type, drawn from the player's own spec --

local SAMPLE_ICONS = { -- when the Cooldown Manager has fewer spells than a picture needs
    'Interface\\Icons\\Spell_Holy_SealOfSalvation',
    'Interface\\Icons\\INV_Sword_62',
    'Interface\\Icons\\Spell_Holy_WordFortitude',
    'Interface\\Icons\\Spell_Nature_Lightning',
    'Interface\\Icons\\Ability_Rogue_Sprint',
    'Interface\\Icons\\Spell_Fire_Fireball02',
}
local SAMPLE_BAR = { type = 'bar', Style = {} } -- the default bar style, for its texture and background
local SAMPLE_STACKS = { 3, nil, 2 }
local SAMPLE_COOLDOWN = 10
local SAMPLE_SLOTS = 6
local DYNAMIC_CYCLE = 8  -- seconds for the Dynamic Group picture: an icon leaves the row and comes back
local DYNAMIC_STEP = 0.5 -- each fade and slide in it

---The textures of the spec's first known Cooldown Manager spells in some categories, stock icons after them.
---@param categories number[] Enum.CooldownViewerCategory values
---@param count number
---@return (string|number)[]
local function SampleIcons(categories, count)
    local icons = {}
    for _, category in ipairs(categories) do
        for _, cooldownID in ipairs(CDM.Catalogue:GetList(category)) do
            local info = CDM.Catalogue:GetEntry(cooldownID)
            local texture = info and info.isKnown and info.spellID and GetSpellTexture(info.spellID)
            if texture and #icons < count then icons[#icons + 1] = texture end
        end
    end
    for i = #icons + 1, count do icons[i] = SAMPLE_ICONS[i] end
    return icons
end

---@param canvas Frame
---@param layer DrawLayer
---@return Texture
local function SampleTexture(canvas, layer)
    local texture = canvas:CreateTexture(nil, layer)
    texture:NUISetPixelSnap()
    return texture
end

---The regions a New tile's picture is drawn with, kept on its canvas; the Icon widget hides them before each draw.
---@param canvas Frame
---@return table
local function SampleParts(canvas)
    local parts = canvas.nuiSample
    if parts then return parts end
    parts = { icons = {}, edges = {}, stacks = {}, pips = {} }
    for i = 1, SAMPLE_SLOTS do
        parts.edges[i] = SampleTexture(canvas, 'BORDER')
        parts.edges[i]:SetColorTexture(0, 0, 0, 1)
        parts.icons[i] = SampleTexture(canvas, 'ARTWORK')
        parts.icons[i]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        parts.stacks[i] = canvas:CreateFontString(nil, 'OVERLAY')
        parts.pips[i] = SampleTexture(canvas, 'ARTWORK')
    end
    parts.frame = SampleTexture(canvas, 'BACKGROUND') -- a bar's black edge
    parts.frame:SetColorTexture(0, 0, 0, 1)
    parts.barBg = SampleTexture(canvas, 'BORDER')
    parts.barFill = SampleTexture(canvas, 'ARTWORK')
    parts.timer = canvas:CreateFontString(nil, 'OVERLAY')
    parts.cooldown = CreateFrame('Cooldown', nil, canvas, 'CooldownFrameTemplate')
    parts.cooldown:SetDrawEdge(false)
    parts.cooldown:SetDrawBling(false)
    parts.cooldown:SetScript('OnCooldownDone', function(cooldown) cooldown:SetCooldown(GetTime(), SAMPLE_COOLDOWN) end)
    parts.driver = CreateFrame('Frame', nil, canvas) --[[@as CDMSampleDriver]] -- runs an animated picture; hidden with the canvas, which stops it
    canvas.nuiSample = parts
    return parts
end

---Place a texture at `x`, `y` from the canvas's top left.
---@param region Texture
---@param x number
---@param y number
---@param width number
---@param height number
local function Place(region, x, y, width, height)
    region:ClearAllPoints()
    region:NUISetPixelSize(width, height)
    region:NUISetPixelPoint('TOPLEFT', region:GetParent(), 'TOPLEFT', x, -y)
    region:Show()
end

---The `n`th icon of a picture, with its black edge, `size` square at `x`, `y`.
---@param parts table
---@param n number
---@param texture string|number
---@param size number
---@param x number
---@param y number
---@return Texture icon
local function SampleIcon(parts, n, texture, size, x, y)
    Place(parts.edges[n], x, y, size, size)
    parts.edges[n]:SetAlpha(1)
    local icon = parts.icons[n]
    Place(icon, x + 1, y + 1, size - 2, size - 2)
    icon:SetTexture(texture)
    icon:SetAlpha(1)
    return icon
end

---A row of `count` icons `size` square with 1px between them, centred in the picture.
---@param parts table
---@param icons (string|number)[]
---@param count number
---@param size number
---@param width number
---@param height number
---@return Texture[]
local function SampleRow(parts, icons, count, size, width, height)
    local x, y = floor((width - (count * size + count - 1)) / 2), floor((height - size) / 2)
    local placed = {}
    for i = 1, count do placed[i] = SampleIcon(parts, i, icons[i], size, x + (i - 1) * (size + 1), y) end
    return placed
end

---Icon: the spec's first cooldown with a swipe running round.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawIconSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local icon = SampleIcon(parts, 1, SampleIcons({ Enum.CooldownViewerCategory.Essential }, 1)[1], height, floor((width - height) / 2), 0)
    local cooldown = parts.cooldown
    cooldown:ClearAllPoints()
    -- through Kaji directly, a Cooldown frame isn't sure to carry the injected NUI methods
    pixel.SetPixelInside(cooldown, icon, 0, 0)
    cooldown:Show()
    cooldown:SetCooldown(GetTime(), SAMPLE_COOLDOWN)
    -- Blizzard's countdown carries its own shadowed font; the GUI's texts are outlined without a shadow.
    local countdown = cooldown:GetCountdownFontString()
    if countdown then GUI:ApplyFont(countdown, 'large') end
    return true
end

---Progress Bar: the default bar texture in the class colour, a cooldown as its icon and a timer at its end.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawProgressSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local style = CDM:GetStyle(SAMPLE_BAR)
    local barHeight = floor(height * 0.45)
    local y = floor((height - barHeight) / 2)
    Place(parts.frame, 0, y, width, barHeight)
    SampleIcon(parts, 1, SampleIcons({ Enum.CooldownViewerCategory.Essential }, 1)[1], barHeight, 0, y)
    local inner = width - barHeight - 1
    Place(parts.barBg, barHeight, y + 1, inner, barHeight - 2)
    parts.barBg:SetColorTexture(unpack(style.BackgroundColor))
    Place(parts.barFill, barHeight, y + 1, floor(inner * 0.65), barHeight - 2)
    parts.barFill:SetTexture(NRSKNUI:GetStatusbar(style))
    parts.barFill:SetVertexColor(unpack(NRSKNUI:GetPlayerClassColor()))
    local timer = parts.timer
    GUI:ApplyFont(timer, 'small')
    timer:SetText('6.2')
    timer:ClearAllPoints()
    timer:NUISetPixelPoint('RIGHT', parts.barBg, 'RIGHT', -2, 0)
    timer:Show()
    return true
end

---Resource Bar: the spec's own points or main bar, a little over half full, in their power colour.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawResourceSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local resource = CDM:GetSpecResource()
    local powerType = resource == 'primary' and UnitPowerType('player') or resource
    local color = NRSKNUI.Colors.power[powerType]
    local r, g, b = 1, 0.96, 0.41
    if color then r, g, b = color:GetRGB() end
    local barHeight = floor(height * 0.35)
    local y = floor((height - barHeight) / 2)

    if not CDM.SEGMENTED_POWER[resource] then
        Place(parts.frame, 0, y, width, barHeight)
        parts.barBg:SetColorTexture(0.15, 0.15, 0.17, 1)
        Place(parts.barBg, 1, y + 1, width - 2, barHeight - 2)
        parts.barFill:SetColorTexture(r, g, b, 1)
        Place(parts.barFill, 1, y + 1, floor((width - 2) * 0.6), barHeight - 2)
        return true
    end

    -- Maelstrom Weapon is a buff's stacks, not a power type UnitPowerMax can read
    local max = type(powerType) == 'number' and UnitPowerMax('player', powerType) or 5
    local count = math.max(3, math.min(max, SAMPLE_SLOTS))
    local pipWidth = floor((width - 1) / count) - 1
    local barWidth = count * (pipWidth + 1) + 1
    local x = floor((width - barWidth) / 2)
    Place(parts.frame, x, y, barWidth, barHeight)
    for i = 1, count do
        local pip = parts.pips[i]
        local filled = i <= math.ceil(count * 0.6)
        pip:SetColorTexture(filled and r or 0.15, filled and g or 0.15, filled and b or 0.17, 1)
        Place(pip, x + 1 + (i - 1) * (pipWidth + 1), y + 1, pipWidth, barHeight - 2)
    end
    return true
end

---Group: six of the spec's cooldowns in two rows.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawGroupSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local icons = SampleIcons({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }, 6)
    local size = floor((height - 1) / 2)
    local x = floor((width - (3 * size + 2)) / 2)
    for i = 1, 6 do
        SampleIcon(parts, i, icons[i], size, x + ((i - 1) % 3) * (size + 1), floor((i - 1) / 3) * (size + 1))
    end
    return true
end

---@param p number
---@return number
local function Ease(p)
    p = math.max(0, math.min(p, 1))
    return p * p * (3 - 2 * p)
end

---One frame of the Dynamic Group picture: the middle icon fades out and the other two close up, centred, then
---they part and it fades back in.
---@param driver CDMSampleDriver
---@param elapsed number
local function StepDynamic(driver, elapsed)
    driver.t = (driver.t + elapsed) % DYNAMIC_CYCLE
    local t = driver.t
    -- Full row 2.5s, middle fades out, the others close up, hold 2.5s, they part, it fades back in.
    local step = DYNAMIC_STEP
    local gone = Ease((t - 2.5) / step) * (1 - Ease((t - 6.5) / step))
    local closed = Ease((t - 3) / step) * (1 - Ease((t - 6) / step))
    local parts, icons, size = driver.parts, driver.icons, driver.size
    local three = floor((driver.width - (3 * size + 2)) / 2)
    local two = floor((driver.width - (2 * size + 1)) / 2)
    local y = floor((driver.height - size) / 2)
    SampleIcon(parts, 1, icons[1], size, floor(three + (two - three) * closed + 0.5), y)
    SampleIcon(parts, 2, icons[2], size, three + size + 1, y)
    SampleIcon(parts, 3, icons[3], size, floor(three + 2 * (size + 1) + (two - three - size - 1) * closed + 0.5), y)
    parts.icons[2]:SetAlpha(1 - gone)
    parts.edges[2]:SetAlpha(1 - gone)
end

---Dynamic Group: a row of cooldowns that stays centred as one leaves it and comes back.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawDynamicSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local driver = parts.driver
    driver.parts, driver.t = parts, 0
    driver.icons = SampleIcons({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }, 3)
    driver.size, driver.width, driver.height = math.min(height, floor((width - 2) / 3)), width, height
    StepDynamic(driver, 0)
    driver:SetScript('OnUpdate', StepDynamic)
    driver:Show()
    return true
end

---Aura Group: three of the spec's tracked buffs, two with stacks.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawAuraSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local icons = SampleIcons({ Enum.CooldownViewerCategory.TrackedBuff, Enum.CooldownViewerCategory.TrackedBar }, 3)
    local placed = SampleRow(parts, icons, 3, math.min(height, floor((width - 2) / 3)), width, height)
    for i, icon in ipairs(placed) do
        local stack = parts.stacks[i]
        if SAMPLE_STACKS[i] then
            GUI:ApplyFont(stack, 'normal')
            stack:SetText(SAMPLE_STACKS[i])
            stack:ClearAllPoints()
            stack:NUISetPixelPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', 1, 0)
            stack:Show()
        end
    end
    return true
end

---The Text type's picture: a word in the accent.
---@param canvas Frame
---@return boolean
local function DrawTextSample(canvas)
    local fs = canvas.nuiTextSample or canvas:CreateFontString(nil, 'OVERLAY')
    canvas.nuiTextSample = fs
    GUI:ApplyFont(fs, 'large')
    fs:SetText('Abc')
    fs:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    fs:ClearAllPoints()
    fs:NUISetPixelPoint('CENTER', canvas, 'CENTER', 0, 0)
    fs:Show()
    return true
end

---The Texture type's picture, until it exists: a ring tinted in the accent.
---@param canvas Frame
---@param height number
---@return boolean
local function DrawTextureSample(canvas, height)
    local texture = canvas.nuiTextureSample or canvas:CreateTexture(nil, 'ARTWORK')
    canvas.nuiTextureSample = texture
    texture:SetTexture('Interface\\AddOns\\NorskenCore\\Media\\CursorCircles\\nauraThick.png')
    texture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    texture:ClearAllPoints()
    texture:NUISetPixelSize(height, height)
    texture:NUISetPixelPoint('CENTER', canvas, 'CENTER', 0, 0)
    texture:NUISetPixelSnap()
    texture:Show()
    return true
end

-- Four to a row; a type that isn't built yet shows greyed out.
local NEW_SECTIONS = {
    {
        title = L['Displays'],
        types = {
            {
                text = L['Icon'],
                description = L['Spell or aura'],
                draw = DrawIconSample,
                create = function() NewIcon() end,
            },
            {
                text = L['Progress Bar'],
                description = L['Timer bar'],
                draw = DrawProgressSample,
                create = function() NewProgressBar() end,
            },
            {
                text = L['Text'],
                description = L['Words or timers'],
                draw = DrawTextSample,
                create = function() NewText() end,
            },
            { text = L['Texture'], description = L['Any image'], draw = DrawTextureSample, disabled = true },
        },
    },
    {
        title = L['Groups & Premade Trackers'],
        types = {
            {
                text = L['Resource Bar'],
                description = L["Your spec's resource"],
                draw = DrawResourceSample,
                create = function() NewResourceBar() end,
            },
            {
                text = L['Aura Group'],
                description = L['Multiple auras'],
                draw = DrawAuraSample,
                create = function() NewAuraGroup() end,
            },
            {
                text = L['Group'],
                description = L['Move together'],
                draw = DrawGroupSample,
                create = function() NewGroup(false) end,
            },
            {
                text = L['Dynamic Group'],
                description = L['Auto layout'],
                draw = DrawDynamicSample,
                create = function() NewGroup(true) end,
            },
        },
    },
}

---@param page table
local function BuildNewPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    -- The card's side padding is the gap between the tiles and below the last row too.
    local gap, edge = Theme.paddingMedium, Theme.paddingMedium - Theme.paddingSmall
    local card = page:Card(L['New Display'], 'all')
    for s, section in ipairs(NEW_SECTIONS) do
        NRSKNUI.CDMDisplayTab.Heading(card, section.title)
        local row = card:Row(NEW_TILE_HEIGHT, s == #NEW_SECTIONS and edge or gap):Even()
        for _, entry in ipairs(section.types) do
            row:Icon({
                width = 1 / #section.types,
                spacing = gap,
                size = NEW_TILE_ICON,
                previewWidth = NEW_TILE_PREVIEW,
                showBorder = false,
                tile = true,
                tileHeight = NEW_TILE_HEIGHT,
                disabled = entry.disabled,
                texture = entry.icon,
                draw = entry.draw,
                text = { text = entry.text, description = entry.description, color = Theme.textPrimary },
                onClick = entry.create and function(button) if button == 'LeftButton' then entry.create() end end or nil,
            })
        end
    end

    local importH = 24
    page:Card(L['Import'], 'all'):Row(importH):Button(L['Import a String'], {
        width = 1,
        height = importH,
        tooltip = L['Add displays someone shared, or update the ones you have.'],
        callback = function() Reopen(IMPORT) end,
    })
end

Shared.BuildNewPage = BuildNewPage
