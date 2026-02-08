-- NorskenUI namespace
local _, NRSKNUI = ...
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme


-- Localization Setup
local LSM = NRSKNUI.LSM or LibStub("LibSharedMedia-3.0", true)
local table_insert = table.insert
local PlaySoundFile = PlaySoundFile

-- Database access
local function GetWhisperSoundsDB()
    if not NRSKNUI.db or not NRSKNUI.db.profile then return nil end
    if not NRSKNUI.db.profile.Miscellaneous then
        NRSKNUI.db.profile.Miscellaneous = {}
    end
    if not NRSKNUI.db.profile.Miscellaneous.WhisperSounds then
        NRSKNUI.db.profile.Miscellaneous.WhisperSounds = {
            Enabled = false,
            WhisperSound = "None",
            BNetWhisperSound = "None",
        }
    end
    return NRSKNUI.db.profile.Miscellaneous.WhisperSounds
end

-- Apply settings helper
local function ApplySettings()
    if NRSKNUI.ApplyWhisperSoundSettings then
        NRSKNUI:ApplyWhisperSoundSettings()
    end
end

-- Register Whisper Sounds tab content
GUIFrame:RegisterContent("whisperSounds", function(scrollChild, yOffset)
    -- Safety check for database
    local db = GetWhisperSoundsDB()
    if not db then
        local errorCard = GUIFrame:CreateCard(scrollChild, "Error", yOffset)
        errorCard:AddLabel("Database not available")
        return yOffset + errorCard:GetContentHeight() + Theme.paddingMedium
    end

    -- Track dependent widgets
    local dependentWidgets = {}

    -- Helper to update dependent widget states
    local function UpdateDependentWidgets(enabled)
        for _, widget in ipairs(dependentWidgets) do
            if widget.SetEnabled then
                widget:SetEnabled(enabled)
            end
        end
    end

    ----------------------------------------------------------------
    -- Card 1: Whisper Sounds (Enable)
    ----------------------------------------------------------------
    local card1 = GUIFrame:CreateCard(scrollChild, "Whisper Sound Alerts", yOffset)

    -- Description row
    local row1a = GUIFrame:CreateRow(card1.content, 14)
    local descLabel = card1.content:CreateFontString(nil, "OVERLAY")
    descLabel:SetPoint("TOPLEFT", row1a, "TOPLEFT", 0, 0)
    descLabel:SetPoint("TOPRIGHT", row1a, "TOPRIGHT", 0, 0)
    descLabel:SetJustifyH("LEFT")
    if NRSKNUI.ApplyThemeFont then
        NRSKNUI:ApplyThemeFont(descLabel, "small")
    else
        descLabel:SetFontObject("GameFontNormalSmall")
    end
    descLabel:SetText("Play custom sounds when you receive whispers or Battle.net messages.")
    descLabel:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
    card1:AddRow(row1a, 14)

    -- Enable checkbox
    local row1b = GUIFrame:CreateRow(card1.content, 34)
    local enableCheck = GUIFrame:CreateCheckbox(row1b, "Enable Whisper Sounds", db.Enabled == true,
        function(checked)
            db.Enabled = checked
            ApplySettings()
            UpdateDependentWidgets(checked)
        end)
    row1b:AddWidget(enableCheck, 1)
    card1:AddRow(row1b, 34)

    yOffset = yOffset + card1:GetContentHeight() + Theme.paddingSmall

    ----------------------------------------------------------------
    -- Card 2: Sound Selection
    ----------------------------------------------------------------
    local card2 = GUIFrame:CreateCard(scrollChild, "Sound Selection", yOffset)
    table_insert(dependentWidgets, card2)


    -- Build sound list from LibSharedMedia
    local soundList = {}
    if LSM then
        for name in pairs(LSM:HashTable("sound")) do
            soundList[name] = name
        end
    end
    soundList["None"] = "None"

    -- Whisper Sound dropdown
    local row2a = GUIFrame:CreateRow(card2.content, 40)
    local whisperDropdown = GUIFrame:CreateDropdown(row2a, "Whisper Sound", soundList, db.WhisperSound or "None",
        60,
        function(key)
            db.WhisperSound = key
            ApplySettings()
        end)
    row2a:AddWidget(whisperDropdown, 0.6)
    table_insert(dependentWidgets, whisperDropdown)

    -- Test Whisper button
    local testWhisperBtn = GUIFrame:CreateButton(row2a, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db.WhisperSound
            if soundName and soundName ~= "None" and LSM then
                local file = LSM:Fetch("sound", soundName)
                if file then PlaySoundFile(file, "Master") end
            end
        end,
    })
    row2a:AddWidget(testWhisperBtn, 0.4, nil, 0, -14)
    table_insert(dependentWidgets, testWhisperBtn)
    card2:AddRow(row2a, 40)

    -- Battle.net Sound dropdown
    local row2b = GUIFrame:CreateRow(card2.content, 37)
    local bnetDropdown = GUIFrame:CreateDropdown(row2b, "Battle.net Whisper Sound", soundList,
        db.BNetWhisperSound or "None", 60,
        function(key)
            db.BNetWhisperSound = key
            ApplySettings()
        end)
    row2b:AddWidget(bnetDropdown, 0.6)
    table_insert(dependentWidgets, bnetDropdown)

    -- Test BNet button
    local testBnetBtn = GUIFrame:CreateButton(row2b, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db.BNetWhisperSound
            if soundName and soundName ~= "None" and LSM then
                local file = LSM:Fetch("sound", soundName)
                if file then PlaySoundFile(file, "Master") end
            end
        end,
    })
    row2b:AddWidget(testBnetBtn, 0.4, nil, 0, -14)
    table_insert(dependentWidgets, testBnetBtn)
    card2:AddRow(row2b, 37)

    yOffset = yOffset + card2:GetContentHeight() + Theme.paddingSmall

    -- Apply initial enabled state
    UpdateDependentWidgets(db.Enabled == true)

    return yOffset
end)
