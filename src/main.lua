require "imgui"

local bodyColor = {100, 150, 100, 100}
local edgeColor = {100, 150, 100}

local meter = 50
local world
local objects

local mouseJoint, cursorGrabbing

local pause = false

--------------------------------------------------------------------------------
-- Конструкторы объектов

--[[ 
    x, y - начальные координаты центра круга
    r - радиус
    kind ("static") - вид объекта
    density - плотность
    restitution - упругость
--]]
local function newCircleObject(x, y, r, kind, density, restitution)
    density = density or 1
    restitution = restitution or 0.9
    local b = love.physics.newBody(world, x, y, kind)
    local s = love.physics.newCircleShape(r)
    local f = love.physics.newFixture(b, s, density)
    f:setRestitution(restitution)
    return {
        body = b,
        draw = function()
            local x, y = b:getX(), b:getY()
            love.graphics.setColor(bodyColor)
            love.graphics.circle("fill", x, y, r)
            love.graphics.setColor(edgeColor)
            love.graphics.circle("line", x, y, r)
            -- линия для визулизации вращения
            local angle = b:getAngle()
            love.graphics.line(x, y, x + math.cos(angle)*r, y + math.sin(angle)*r)
        end,
        test = function(x, y)
            return f:testPoint(x, y)
        end
    }
end

--[[ 
    x, y - начальные координаты центра прямоугольника
    h, w - высота и ширина
    kind ("static") - вид объекта
    density - плотность
    restitution - упругость
--]]
function newRectangleObject(x, y, h, w, kind, density, restitution)
    density = density or 1
    restitution = restitution or 0.9
    local b = love.physics.newBody(world, x, y, kind)
    local s = love.physics.newRectangleShape(h, w)
    local f = love.physics.newFixture(b, s, density)
    f:setRestitution(restitution)
    return {
        body = b,
        draw = function()
            love.graphics.setColor(bodyColor)
            love.graphics.polygon("fill", b:getWorldPoints(s:getPoints()))
            love.graphics.setColor(edgeColor)
            love.graphics.polygon("line", b:getWorldPoints(s:getPoints()))
        end,
        test = function(x, y)
            return f:testPoint(x, y)
        end
    }
end

--[[ 
    x1, y1, x2, y2 - координаты грани
    kind ("static") - вид объекта
    density - плотность
    restitution - упругость
--]]
local function newEdgeObject(x1, y1, x2, y2, kind, density, restitution)
    density = density or 1
    restitution = restitution or 0.9
    local b = love.physics.newBody(world, 0, 0, kind)
    local s = love.physics.newEdgeShape(x1, y1, x2, y2)
    local f = love.physics.newFixture(b, s, density)
    f:setRestitution(restitution)
    return {
        body = b,
        draw = function()
            love.graphics.setColor(edgeColor)
            love.graphics.line(s:getPoints())
        end,
        test = function(x, y)
            return false
        end
    }
end

local function loadScene()
    world = love.physics.newWorld(0, 9.81 * meter, true)
    objects = {}

    cursorGrabbing = love.mouse.newCursor("img/grabbing.png", 0, 0)

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    objects[#objects+1] = newCircleObject(w/2, h/2, 25, "dynamic")
    objects[#objects+1] = newRectangleObject(w/2, h/2 + 100, 40, 70, "dynamic", 5)
    
    -- cцена в размер окна
    newEdgeObject(0, 0, w, 0) -- верхняя граница
    newEdgeObject(0, h, w, h) -- нижняя граница
    newEdgeObject(0, 0, 0, h) -- левая граница
    newEdgeObject(w, 0, w, h) -- правая граница
end

local function killScene()
    world:destroy()
    objects = {}
end

--------------------------------------------------------------------------------
-- Обработка событий

function love.load(arg)
    love.graphics.setBackgroundColor(240, 240, 240)
    loadScene()
end

function love.update(dt)
    
    imgui.NewFrame()
    if not pause then
        world:update(dt)
    end
    
    if imgui.Button("reset") then
        killScene(); loadScene() -- перезапуск сцены
    end
    
    if imgui.Button("pause") then
        pause = not pause 
    end
    
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    
    if imgui.Button("new circle") then   
        objects[#objects+1] = newCircleObject(w/2, h/2, 25, "dynamic") 
    end
    
    if imgui.Button("new rectangle") then
        objects[#objects+1] = newRectangleObject(w/2, h/2 + 100, 40, 70, "dynamic", 5) 
    end
    
end

function love.draw()
    
    -- отрисовка объектов
    for _, obj in ipairs(objects) do
        obj.draw()
    end

    -- отрисовка GUI
    love.graphics.setColor(255, 255, 255)
    imgui.Render()
end 

function love.resize(w, h)
    --
end

function love.quit()
    imgui.ShutDown();
end

--------------------------------------------------------------------------------
-- Обработка событий клавиатуры

function love.textinput(t)
    imgui.TextInput(t)
    if not imgui.GetWantCaptureKeyboard() then
        --
    end
end

function love.keypressed(key)
    imgui.KeyPressed(key)
    if not imgui.GetWantCaptureKeyboard() then
        --
    end
end

function love.keyreleased(key)
    imgui.KeyReleased(key)
    if not imgui.GetWantCaptureKeyboard() then
        --
    end
end

--------------------------------------------------------------------------------
-- Обработка событий мыши

function love.mousemoved(x, y)
    imgui.MouseMoved(x, y)
    if not imgui.GetWantCaptureMouse() then
        -- перемещение захваченного объекта
        if mouseJoint then
            mouseJoint:setTarget(x, y)
        end
    end
end

function love.mousepressed(x, y, button)
    imgui.MousePressed(button)
    if not imgui.GetWantCaptureMouse() then
        
        -- захват объекта мышкой
        if (button == 1) and not mouseJoint then
            for _, obj in ipairs(objects) do
                if obj.test(x, y) then
                    mouseJoint = love.physics.newMouseJoint(obj.body, x, y)
                    love.mouse.setCursor(cursorGrabbing)
                    break
                end
            end
        end
        
    end
end

function love.mousereleased(x, y, button)
    imgui.MouseReleased(button)
    if not imgui.GetWantCaptureMouse() then
        
        -- отмена захвата объекта мышкой
        if (button == 1) and mouseJoint then
            mouseJoint:destroy()
            mouseJoint = nil
            love.mouse.setCursor()
        end
        
    end
end

function love.wheelmoved(x, y)
    imgui.WheelMoved(y)
    if not imgui.GetWantCaptureMouse() then
        --
    end
end