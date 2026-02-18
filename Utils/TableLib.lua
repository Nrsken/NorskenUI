-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Module from p3lim

local assert = assert
local type = type
local select = select
local debugstack = debugstack
local error = error
local next = next
local CreateFromMixins = CreateFromMixins
local getmetatable, setmetatable = getmetatable, setmetatable
local rawset = rawset
local strlenutf8 = strlenutf8

function NRSKNUI:ArgCheck(arg, argIndex, ...)
    assert(type(argIndex) == 'number', 'Bad argument #2 to \'ArgCheck\' (number expected, got ' .. type(argIndex) .. ')')

    for index = 1, select('#', ...) do
        if type(arg) == select(index, ...) then
            return
        end
    end

    local types = string.join(', ', ...)
    local name = debugstack(2, 2, 0):match(': in function [`<](.-)[\'>]')
    error(string.format('Bad argument #%d to \'%s\' (%s expected, got %s)', argIndex, name, types, type(arg)), 3)
end

function NRSKNUI:tsize(tbl)
    local size = 0
    if tbl then
        for _ in next, tbl do
            size = size + 1
        end
    end
    return size
end

function NRSKNUI:startswith(str, contents)
    return str:sub(1, contents:len()) == contents
end

do
    local tableMethods = CreateFromMixins(table)
    function tableMethods:size()
        return NRSKNUI:tsize(self)
    end

    function tableMethods:merge(tbl)
        NRSKNUI:ArgCheck(tbl, 1, 'table')

        for k, v in next, tbl do
            if type(self[k] or false) == 'table' then
                tableMethods.merge(self[k], tbl[k])
            else
                self[k] = v
            end
        end

        return self
    end

    function tableMethods:contains(value)
        for _, v in next, self do
            if value == v then
                return true
            end
        end

        return false
    end

    function tableMethods:random()
        local size = self:size()
        if size > 0 then
            return self[math.random(size)]
        end
    end

    function tableMethods:copy(shallow)
        local tbl = NRSKNUI:T()
        for k, v in next, self do
            if type(v) == 'table' and not shallow then
                tbl[k] = tableMethods.copy(v)
            else
                tbl[k] = v
            end
        end
        return tbl
    end

    -- remove obsolete and deprecated methods present in the table library
    -- https://warcraft.wiki.gg/wiki/Lua_functions#Deprecated_functions
    tableMethods.foreach = nil
    tableMethods.foreachi = nil
    tableMethods.getn = nil
    tableMethods.setn = nil

    local function newIndex(self, key, value)
        -- turn child tables into this metatable too
        if type(value) == 'table' and not getmetatable(value) then
            rawset(self, key, NRSKNUI:T(value))
        else
            rawset(self, key, value)
        end
    end

    function NRSKNUI:T(tbl)
        NRSKNUI:ArgCheck(tbl, 1, 'table', 'nil')

        return setmetatable(tbl or {}, {
            __index = tableMethods,
            __newindex = newIndex,
            __add = tableMethods.merge,
        })
    end
end