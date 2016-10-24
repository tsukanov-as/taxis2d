
local editor = {}

function editor.openScene(path)
	-- body
end

function editor.newScene(n) --> table
	local scene = {}

    scene.path = "Untitled #"..n

	local x, y = 0, 0
    local dx, dy = 500, 500

	function scene.load()
		-- body
	end

	function scene.update(dt)
        local w, h = love.graphics.getDimensions()
        if (w < x) or (x < 0) then
            dx = -dx
        end
        if (h < y) or (y < 0) then
            dy = -dy
        end
        x = x + dx*dt
        y = y + dy*dt
	end

	function scene.draw(x1, y1, x2, y2)
		love.graphics.push()
        love.graphics.translate(x1, y1)
		love.graphics.setColor({255, 100, 100})
		local r = 20
        love.graphics.circle("fill", x, y, r)
		love.graphics.pop()
	end

	return scene
end

function editor.openAgent(path)
	-- body
end

return editor