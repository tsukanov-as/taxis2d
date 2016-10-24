local adt = {}

function adt.NewArray(array)

    array = array or {}

    function array.push(v)
        table.insert(array, v)
    end

    function array.pop() --> any
        return table.remove(array)
    end

    function array.peek() --> any
        return array[#array]
    end

    function array.clear()
        for i in ipairs(array) do
            array[i] = nil
        end
    end

    function array.insert(i, v)
        table.insert(array, i, v)
    end

    function array.shift() --> any
        return table.remove(array, 1)
    end

    function array.remove(i) --> any
        return table.remove(array, i)
    end

    function array.join(separator)
        return table.concat(array, separator)
    end

    return array
end

return adt