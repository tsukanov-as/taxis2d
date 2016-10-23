
local common = {}

function common.crop1(x, min, max)
    if x < min then
        return min
    end
    if x > max then
        return max
    end
    return x
end

function common.rider(t)

    local r = {}
    local i = nil

    function r.val()
        return t[i], i
    end

    function r.next()
        i = (i or 0) + 1
        if i > #t then
            i = nil
            return false
        else
            return true
        end
    end

    function r.prev()
        i = i and i - 1 or #t
        if i < 1 then
            i = nil
            return false
        else
            return true
        end
    end

    function r.reset()
        i = nil
    end

    return r

end

return common