---@class NRSKNUI
local NRSKNUI = select(2, ...)

local math_floor = math.floor
local math_max = math.max
local string_format = string.format
local tostring = tostring
local tconcat = table.concat
local CreateColor = CreateColor
local tonumber = tonumber
local unpack = unpack

local enumUp = Enum and Enum.NumericRuleFormatRounding.Up
local enumDown = Enum and Enum.NumericRuleFormatRounding.Down
local enumNearest = Enum and Enum.NumericRuleFormatRounding.Nearest

NRSKNUI.MINUTES_SECONDS_FORMAT = '%d:%02d' -- the one breakpoint format with two numbers, 2:10

local CreateNumericRuleFormatter = C_StringUtil and C_StringUtil.CreateNumericRuleFormatter

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

local POINT_KEYS = { 'pointOne', 'pointTwo', 'pointThree', 'pointFour', 'pointFive', 'pointSix' }
local COLOR_KEYS = { 'colorOne', 'colorTwo', 'colorThree', 'colorFour', 'colorFive', 'colorSix' }
local formatterCache = {}

---Minutes, hours and days round to nearest, seconds round up so a running timer never reads 0.
---@param fmt string
---@return number div seconds per displayed unit
---@return number step
---@return boolean nearest
function NRSKNUI:GetDurationFormatUnit(fmt)
    if fmt:find('dd$') then return 86400, 1, true end -- '%dd'; a bare d$ would also match seconds' '%d'
    if fmt:find('h$') then return 3600, 1, true end
    if fmt:find('m$') then return 60, 1, true end
    return 1, fmt:find('%.1f') and 0.1 or 1, false
end

local function DurationComponent(fmt)
    local div, step, nearest = NRSKNUI:GetDurationFormatUnit(fmt)
    -- Seconds leave div out, as the formatter was always fed them.
    return { div = div ~= 1 and div or nil, step = step, rounding = nearest and enumNearest or enumUp }
end

---Ordered rgba per breakpoint, nil when the format strings should stay uncolored.
local function ResolveBreakpointColors(useBreakpointColors, singleColor)
    if singleColor then
        local colors = {}
        for i = 1, #COLOR_KEYS do colors[i] = singleColor end
        return colors
    elseif not useBreakpointColors then
        return nil
    end

    local stored = NRSKNUI.db.profile.globalMedia.profileColorBreakPoint
    local colors = {}
    for i = 1, #COLOR_KEYS do colors[i] = stored[COLOR_KEYS[i]] end
    return colors
end

---@param colors? number[][] Per-breakpoint rgba from ResolveBreakpointColors.
local function BuildDurationBreakpoints(colors)
    local points = NRSKNUI.db.profile.globalMedia.profileBreakPoints
    local breakpoints, previous = {}, 0

    for i = 1, #POINT_KEYS do
        local point = points[POINT_KEYS[i]]
        -- Point one has to start at 0 so short durations are covered, the rest only need to stay ascending.
        local threshold = (i == 1) and 0 or math_max(tonumber(point.threshold) or 0, previous + 1)
        local format = colors and CreateColor(unpack(colors[i])):WrapTextInColorCode(point.format) or point.format

        if point.format == NRSKNUI.MINUTES_SECONDS_FORMAT then
            -- Whole seconds rounded up first, like the seconds formats, then split into minutes and the rest.
            breakpoints[i] = {
                threshold = threshold,
                step = 1,
                rounding = enumUp,
                format = format,
                components = { { div = 60, step = 1, rounding = enumDown }, { mod = 60, step = 1, rounding = enumDown } },
            }
        else
            breakpoints[i] = {
                threshold = threshold,
                format = format,
                components = { DurationComponent(point.format) },
            }
        end
        previous = threshold
    end

    return breakpoints
end

---A text's own Time Format: `precision` decimals below `below` seconds, whole seconds to a minute, then m / h / d.
---@param below number seconds, 0 for no decimals
---@param precision number decimals, 1 or 2
---@return table formatter
function NRSKNUI:GetPrecisionDurationFormatter(below, precision)
    local key = 'precision:' .. below .. ':' .. precision
    local formatter = formatterCache[key]
    if not formatter then
        local breakpoints = {}
        if below > 0 then
            breakpoints[1] = { threshold = 0, format = '%.' .. precision .. 'f', components = { { step = 10 ^ -precision, rounding = enumUp } } }
        end
        if below < 60 then
            breakpoints[#breakpoints + 1] = { threshold = below, format = '%d', components = { DurationComponent('%d') } }
        end
        breakpoints[#breakpoints + 1] = { threshold = 60, format = '%dm', components = { DurationComponent('%dm') } }
        breakpoints[#breakpoints + 1] = { threshold = 3600, format = '%dh', components = { DurationComponent('%dh') } }
        breakpoints[#breakpoints + 1] = { threshold = 86400, format = '%dd', components = { DurationComponent('%dd') } }
        formatter = CreateNumericRuleFormatter()
        formatter:SetBreakpoints(breakpoints)
        formatterCache[key] = formatter
    end
    return formatter
end

function NRSKNUI:RefreshAuraDurationFormatter()
    formatterCache = {}
end

---Formatter for aura duration text, tenths below the second breakpoint, whole seconds, then m / h / d.
---@param useBreakpointColors? boolean Use per-breakpoint colorized format strings for instant threshold color changes.
---@param singleColor? number[] Optional single RGBA color to apply across all breakpoints.
---@return table formatter A NumericFormatter usable as SetDurationText's `textFormatter` option.
function NRSKNUI:GetAuraDurationFormatter(useBreakpointColors, singleColor)
    local key = singleColor and tconcat(singleColor, ':') or useBreakpointColors and 'breakpoint' or 'plain'

    local formatter = formatterCache[key]
    if not formatter then
        formatter = CreateNumericRuleFormatter()
        formatter:SetBreakpoints(BuildDurationBreakpoints(ResolveBreakpointColors(useBreakpointColors, singleColor)))
        formatterCache[key] = formatter
    end

    return formatter
end
