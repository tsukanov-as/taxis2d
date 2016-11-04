local adt = require "adt"

local marshal = {}

function marshal.Dump(x)
    local space = "\t"
    local indent = 0
    local function dump(x)
        if type(x) == "table" then
            local list = adt.NewArray()
            if #x > 0 then
                list.push "[\n"
                local count = #list
                indent = indent + 1
                for _, v in ipairs(x) do
                    local vd = dump(v)
                    if vd then
                        list.push(space:rep(indent), vd, ",\n")
                    end
                end
                indent = indent - 1
                if count == #list then
                    return "null"
                end
                list.push(space:rep(indent), "]")
            elseif next(x) then
                list.push "{\n"
                local count = #list
                indent = indent + 1
                for k, v in pairs(x) do
                    local kd = dump(k)
                    if kd then
                        local vd = dump(v)
                        if vd then
                            list.push(space:rep(indent), kd, ": ", vd, ",\n")
                        end
                    end
                end
                indent = indent - 1
                if count == #list then
                    return "null"
                end
                list.push(space:rep(indent), "}")
            else
                return "null"
            end
            return list.join()
        elseif type(x) == "string"   then return string.format("%q", x)
        elseif type(x) == "number"   then return tostring(x)
        elseif type(x) == "boolean"  then return tostring(x)
        elseif type(x) == "function" then return nil
        elseif type(x) == "userdata" then return nil
        elseif type(x) == "thread"   then return nil
        else
            error("unknown type: "..type(x))
        end
    end
    return dump(x)
end

-- http://stackoverflow.com/questions/19961598/substitute-double-backslash-from-input-with-single-backslash-in-lua
local function unbackslashed(s)
    local ch = {
        ["\\a"] = '\\007', --'\a' alarm             Ctrl+G BEL
        ["\\b"] = '\\008', --'\b' backspace         Ctrl+H BS
        ["\\f"] = '\\012', --'\f' formfeed          Ctrl+L FF
        ["\\n"] = '\\010', --'\n' newline           Ctrl+J LF
        ["\\r"] = '\\013', --'\r' carriage return   Ctrl+M CR
        ["\\t"] = '\\009', --'\t' horizontal tab    Ctrl+I HT
        ["\\v"] = '\\011', --'\v' vertical tab      Ctrl+K VT
        ["\\\n"] = '\\010',--     newline
        ["\\\\"] = '\\092',--     backslash
        ['\\"'] = '\\034', --     quote
    }
    return s:gsub("(\\.)", ch)
        :gsub("\\(%d%d?%d?)", function(n)
            return string.char(tonumber(n))
        end)
end

function marshal.Load(s)

    local c, pos = nil, 0
    local eof = ''

    local function getc(n)
        pos = pos + n
        c = s:sub(pos, pos)
    end

    local function skip(x)
        while c <= ' ' and c ~= eof do getc(1) end
        assert(c == x, c)
        repeat getc(1) until c > ' ' or c == eof
    end

    repeat getc(1) until c > ' ' or c == eof

    local parse

    local function parse_table()
        local t = {}
        skip('{')
        while c ~= '}' and c ~= eof do
            local k = parse()
            skip(':')
            local v = parse()
            skip(',')
            t[k] = v
        end
        skip('}')
        return t
    end

    local function parse_array()
        local a = {}
        local i = 1
        skip('[')
        while c ~= ']' and c ~= eof do
            local v = parse()
            skip(',')
            a[i] = v
            i = i + 1
        end
        skip(']')
        return a
    end

    local function parse_string()
        skip('"')
        local start = pos
        while c ~= '"' and c ~= eof do
            getc(1)
            if c == '\\' then
                getc(1)
                if c == '"' then
                    getc(1)
                end
            end
        end
        local stop = pos-1
        skip('"')
        return unbackslashed(s:sub(start, stop))
    end

    local function parse_integer()
        local len = 0
        while c ~= eof and '0' <= c and c <= '9' do
            getc(1); len = len + 1
        end
        return len
    end

    local function parse_number()
        local start = pos
        local n = parse_integer()
        if c == '.' then
            getc(1)
            n = n + parse_integer()
        end
        if c == 'e' then
            getc(1)
            if c == '-' then
                getc(1)
            end
            assert(parse_integer())
        end
        assert(n > 0)
        local stop = pos-1
        return assert(tonumber(s:sub(start, stop)))
    end

    parse = function()
        local res
        if c == '{' then
            res = parse_table()
        elseif c == '[' then
            res = parse_array()
        elseif c == '"' then
            res = parse_string()
        elseif '0' <= c and c <= '9' then
            res = parse_number()
        elseif c == '-' then
            getc(1)
            res = parse_number()
        elseif s:sub(pos, pos+3) == "true" then
            getc(4)
            res = true
        elseif s:sub(pos, pos+4) == "false" then
            getc(5)
            res = false
        elseif s:sub(pos, pos+3) == "null" then
            getc(4)
            res = {}
        else
            error("unknown symbol: "..c)
        end
        return res
    end

    return parse()

end

return marshal