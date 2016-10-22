local adt = {}

function adt.NewStack()

	local stack = {}
	
	function stack.push(v)
		stack[#stack+1] = v
	end

	function stack.pop() --> any
		local v = stack[#stack]
		stack[#stack] = nil
		return v
	end

	function stack.peek() --> any
		return stack[#stack]
	end
    
    function stack.clear()
        for i in ipairs(stack) do
            stack[i] = nil
        end 
    end
    
    return stack
end

return adt