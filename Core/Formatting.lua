---@class NRSKNUI
local NRSKNUI = select(2, ...)

local math_floor = math.floor
local string_format = string.format
local tostring = tostring
local tconcat = table.concat
local CreateColor = CreateColor

local enumUp = Enum.NumericRuleFormatRounding.Up
local enumNearest = Enum.NumericRuleFormatRounding.Nearest

local TOKEN_NORMAL, TOKEN_PERCENT, TOKEN_PLACEHOLDER = 0, 1, 2

---Format a duration in seconds into one of the NRSKNUI.TimeFormats styles.
---@param seconds number
---@param format? string A key from NRSKNUI.TimeFormats (defaults to "MM:SS")
---@return string
function NRSKNUI:FormatTime(seconds, format)
    seconds = seconds or 0
    if seconds < 0 then seconds = 0 end

    if format == 'MM:SS.f' then
        -- Sub-second display, so keep the fraction instead of rounding to whole seconds.
        local whole = math_floor(seconds)
        local tenths = math_floor((seconds - whole) * 10)
        return string_format('%02d:%02d.%d', math_floor(whole / 60), whole % 60, tenths)
    end

    local total = math_floor(seconds + 0.5)
    local mins = math_floor(total / 60)
    local secs = total % 60

    if format == 'M:SS' then
        return string_format('%d:%02d', mins, secs)
    elseif format == 'MmSs' then
        return string_format('%02dm %02ds', mins, secs)
    elseif format == 'MmSs_c' then
        if mins > 0 then return string_format('%dm %ds', mins, secs) end
        return string_format('%ds', secs)
    elseif format == 'Ss' then
        return string_format('%ds', total)
    elseif format == 'S' then
        return tostring(total)
    elseif format == 'Smart' then
        if total >= 60 then return string_format('%dm', mins) end
        return string_format('%ds', total)
    end

    return string_format('%02d:%02d', mins, secs)
end

---Turn tokens in a format string into their replacements, idea based on WA patterns where %p becomes a timer.
---@param formatStr string
---@param replacements table<string, string> Token name without the leading "%" -> replacement text, may already contain color codes.
---@param wrapLiteral? fun(text: string): string Wrap each literal run, e.g. to color it, omit to leave literals untouched.
---@return string
function NRSKNUI:FormatTokens(formatStr, replacements, wrapLiteral)
    if not formatStr or formatStr == "" then return "" end

    local result = {}
    local state = TOKEN_NORMAL
    local pos, len = 1, #formatStr
    local literalStart = 1 -- First char of the pending literal run
    local percentStart     -- Position of the '%' that opened the current token attempt
    local nameStart        -- First char of the current token name
    local braced = false

    -- Emit sub(literalStart, endExclusive - 1) as one literal run, color-wrapped if requested.
    local function FlushLiteral(endExclusive)
        if endExclusive > literalStart then
            local text = formatStr:sub(literalStart, endExclusive - 1)
            result[#result + 1] = wrapLiteral and wrapLiteral(text) or text
        end
    end

    while pos <= len do
        local byte = formatStr:byte(pos)

        if state == TOKEN_NORMAL then
            if byte == 37 then -- %
                state = TOKEN_PERCENT
                percentStart = pos
            end
        elseif state == TOKEN_PERCENT then
            if byte == 37 then             -- %% -> a single literal %
                FlushLiteral(percentStart) -- Text before the first %
                literalStart = pos         -- Keep the second % as the start of the next run
                state = TOKEN_NORMAL
            elseif byte == 123 then        -- %{  braced token
                nameStart = pos + 1
                braced = true
                state = TOKEN_PLACEHOLDER
            elseif (byte >= 97 and byte <= 122) or (byte >= 65 and byte <= 90) or (byte >= 48 and byte <= 57) then
                nameStart = pos
                braced = false
                state = TOKEN_PLACEHOLDER
            else
                -- % followed by punctuation/space, the % stays part of the literal run.
                state = TOKEN_NORMAL
            end
        elseif state == TOKEN_PLACEHOLDER then
            local finished, nameEnd, consumeTerminator
            if braced then
                if byte == 125 then -- } closes the braced token
                    finished, nameEnd, consumeTerminator = true, pos - 1, true
                end
            elseif not ((byte >= 97 and byte <= 122) or (byte >= 65 and byte <= 90) or (byte >= 48 and byte <= 57)) then
                finished, nameEnd, consumeTerminator = true, pos - 1, false
            end

            if finished then
                local seg = replacements[formatStr:sub(nameStart, nameEnd)]
                if seg then
                    FlushLiteral(percentStart) -- Text before the token
                    result[#result + 1] = seg
                    literalStart = consumeTerminator and pos + 1 or pos
                end
                -- Unknown token, leave literalStart put so the whole "%name" stays literal

                if not consumeTerminator and byte == 37 then
                    -- The terminator is itself the start of another token
                    state = TOKEN_PERCENT
                    percentStart = pos
                else
                    state = TOKEN_NORMAL
                end
            end
        end

        pos = pos + 1
    end

    -- An unbraced token can run to the end of the string, no terminating char.
    if state == TOKEN_PLACEHOLDER and not braced then
        local seg = replacements[formatStr:sub(nameStart, len)]
        if seg then
            FlushLiteral(percentStart)
            result[#result + 1] = seg
            literalStart = len + 1
        end
    end

    -- Flush any remaining literal run at the end of the string.
    FlushLiteral(len + 1)

    return tconcat(result)
end

-- Aura duration text --

local auraDurationFormatter
local auraDurationFormatterColored
local auraDurationFormatterSingleColorCache = {}

local DEFAULT_DURATION_BREAKPOINT_COLORS = {
    colorOne = { 1, 0.25, 0.25, 1 },
    colorTwo = { 1, 1, 1, 1 },
    colorThree = { 1, 1, 1, 1 },
    colorFour = { 1, 1, 1, 1 },
    colorFive = { 1, 1, 1, 1 },
}

local DEFAULT_DURATION_BREAKPOINTS = {
    pointOne = { threshold = 0, step = 0.1, format = '%0.1f', },
    pointTwo = { threshold = 3, step = 1, format = '%d', },
    pointThree = { threshold = 10, step = 1, format = '%d', },
    pointFour = { threshold = 60, format = '%dm', },
    pointFive = { threshold = 3600, format = '%dh', },
}

local function GetDurationBreakpointRules()
    local db = NRSKNUI.db
    local media = db and db.profile and db.profile.globalMedia
    local points = media and media.profileBreakPoints or DEFAULT_DURATION_BREAKPOINTS

    local p1 = points.pointOne or DEFAULT_DURATION_BREAKPOINTS.pointOne
    local p2 = points.pointTwo or DEFAULT_DURATION_BREAKPOINTS.pointTwo
    local p3 = points.pointThree or DEFAULT_DURATION_BREAKPOINTS.pointThree
    local p4 = points.pointFour or DEFAULT_DURATION_BREAKPOINTS.pointFour
    local p5 = points.pointFive or DEFAULT_DURATION_BREAKPOINTS.pointFive

    local secondThreshold = tonumber(p2.threshold) or DEFAULT_DURATION_BREAKPOINTS.pointTwo.threshold
    if secondThreshold < 1 then secondThreshold = DEFAULT_DURATION_BREAKPOINTS.pointTwo.threshold end

    -- Keep supporting older profiles where pointThree/pointFour used `step` as the threshold value.
    local minuteThreshold = tonumber(p3.threshold) or tonumber(p3.step) or DEFAULT_DURATION_BREAKPOINTS.pointThree.threshold
    if minuteThreshold <= secondThreshold then minuteThreshold = secondThreshold + 1 end

    local hourThreshold = tonumber(p4.threshold) or tonumber(p4.step) or DEFAULT_DURATION_BREAKPOINTS.pointFour.threshold
    if hourThreshold <= minuteThreshold then
        hourThreshold = minuteThreshold + 1
    end

    local dayThreshold = tonumber(p5.threshold) or tonumber(p5.step) or DEFAULT_DURATION_BREAKPOINTS.pointFive.threshold
    if dayThreshold <= hourThreshold then
        dayThreshold = hourThreshold + 1
    end

    return {
        pointOne = {
            threshold = DEFAULT_DURATION_BREAKPOINTS.pointOne.threshold,
            step = DEFAULT_DURATION_BREAKPOINTS.pointOne.step,
            format = p1.format or DEFAULT_DURATION_BREAKPOINTS.pointOne.format,
        },
        pointTwo = {
            threshold = secondThreshold,
            step = DEFAULT_DURATION_BREAKPOINTS.pointTwo.step,
            format = p2.format or DEFAULT_DURATION_BREAKPOINTS.pointTwo.format,
        },
        pointThree = {
            threshold = minuteThreshold,
            format = p3.format or DEFAULT_DURATION_BREAKPOINTS.pointThree.format,
        },
        pointFour = {
            threshold = hourThreshold,
            format = p4.format or DEFAULT_DURATION_BREAKPOINTS.pointFour.format,
        },
        pointFive = {
            threshold = dayThreshold,
            format = p5.format or DEFAULT_DURATION_BREAKPOINTS.pointFive.format,
        },
    }
end

local function GetDurationBreakpointColors()
    local db = NRSKNUI.db
    if db and db.profile and db.profile.globalMedia and db.profile.globalMedia.profileColorBreakPoint then
        return db.profile.globalMedia.profileColorBreakPoint
    end
    return DEFAULT_DURATION_BREAKPOINT_COLORS
end

local function WrapFormatWithColor(formatStr, color)
    local rgba = color or DEFAULT_DURATION_BREAKPOINT_COLORS.colorTwo
    return CreateColor(unpack(rgba)):WrapTextInColorCode(formatStr)
end

local function BuildAuraDurationFormatterForSingleColor(color)
    local points = GetDurationBreakpointRules()
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:SetBreakpoints({
        { threshold = points.pointOne.threshold,   format = WrapFormatWithColor(points.pointOne.format, color),   components = { { step = points.pointOne.step, rounding = enumUp }, } },
        { threshold = points.pointTwo.threshold,   format = WrapFormatWithColor(points.pointTwo.format, color),   components = { { step = points.pointTwo.step, rounding = enumUp } } },
        { threshold = points.pointThree.threshold, format = WrapFormatWithColor(points.pointThree.format, color), components = { { step = points.pointThree.step, rounding = enumUp }, } },
        { threshold = points.pointFour.threshold,  format = WrapFormatWithColor(points.pointFour.format, color),  components = { { div = points.pointFour.threshold, step = 1, rounding = enumNearest }, } },
        { threshold = points.pointFive.threshold,  format = WrapFormatWithColor(points.pointFive.format, color),  components = { { div = points.pointFive.threshold, step = 1, rounding = enumNearest } } }, })
    return formatter
end

function NRSKNUI:RefreshAuraDurationFormatter()
    auraDurationFormatter = nil
    auraDurationFormatterColored = nil
    auraDurationFormatterSingleColorCache = {}
end

---Formatter for aura duration text, tenths + red under 3s, whole seconds under a minute, then m / h.
---@param useBreakpointColors? boolean Use per-breakpoint colorized format strings for instant threshold color changes.
---@param singleColor? number[] Optional single RGBA color to apply across all breakpoints.
---@return table formatter A NumericFormatter usable as SetDurationText's `textFormatter` option.
function NRSKNUI:GetAuraDurationFormatter(useBreakpointColors, singleColor)
    if singleColor then
        local key = table.concat(singleColor, ':')
        local formatter = auraDurationFormatterSingleColorCache[key]
        if formatter then return formatter end
        formatter = BuildAuraDurationFormatterForSingleColor(singleColor)
        auraDurationFormatterSingleColorCache[key] = formatter
        return formatter
    end

    if useBreakpointColors then
        if auraDurationFormatterColored then return auraDurationFormatterColored end

        local points = GetDurationBreakpointRules()
        local colors = GetDurationBreakpointColors()
        auraDurationFormatterColored = C_StringUtil.CreateNumericRuleFormatter()
        auraDurationFormatterColored:SetBreakpoints({
            { threshold = points.pointOne.threshold,   format = WrapFormatWithColor(points.pointOne.format, colors.colorOne),     components = { { step = points.pointOne.step, rounding = enumUp }, } },
            { threshold = points.pointTwo.threshold,   format = WrapFormatWithColor(points.pointTwo.format, colors.colorTwo),     components = { { step = points.pointTwo.step, rounding = enumUp } } },
            { threshold = points.pointThree.threshold, format = WrapFormatWithColor(points.pointThree.format, colors.colorThree), components = { { step = points.pointThree.step, rounding = enumUp }, } },
            { threshold = points.pointFour.threshold,  format = WrapFormatWithColor(points.pointFour.format, colors.colorFour),   components = { { div = points.pointFour.threshold, step = 1, rounding = enumNearest }, } },
            { threshold = points.pointFive.threshold,  format = WrapFormatWithColor(points.pointFive.format, colors.colorFive),   components = { { div = points.pointFive.threshold, step = 1, rounding = enumNearest } } },
        })

        return auraDurationFormatterColored
    end

    if auraDurationFormatter then return auraDurationFormatter end

    local points = GetDurationBreakpointRules()
    auraDurationFormatter = C_StringUtil.CreateNumericRuleFormatter()
    auraDurationFormatter:SetBreakpoints({
        { threshold = points.pointOne.threshold,   format = points.pointOne.format,   components = { { step = points.pointOne.step, rounding = enumUp }, } },
        { threshold = points.pointTwo.threshold,   format = points.pointTwo.format,   components = { { step = points.pointTwo.step, rounding = enumUp } } },
        { threshold = points.pointThree.threshold, format = points.pointThree.format, components = { { step = points.pointThree.step, rounding = enumUp }, } },
        { threshold = points.pointFour.threshold,  format = points.pointFour.format,  components = { { div = points.pointFour.threshold, step = 1, rounding = enumNearest }, } },
        { threshold = points.pointFive.threshold,  format = points.pointFive.format,  components = { { div = points.pointFive.threshold, step = 1, rounding = enumNearest } } },
    })

    return auraDurationFormatter
end
