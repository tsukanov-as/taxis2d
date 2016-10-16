require "imgui"

local bodyColor = {100, 150, 100, 100}
local edgeColor = {100, 150, 100}
local sensorColor = {150, 150, 150, 100}
local effectorColor = {200, 0, 200, 100}

local meter = 50
local world
local xg, yg = 0, 0 -- гравитация
local damping = 3 -- затухание движений
local objects
local sensors, effectors, brains

local mouseJoint, mouseGrab, cursorGrabbing -- состояние захвата объекта мышкой
local curBody -- тело в фокусе

local pause = false

local speed = 1.0 -- скорость симуляции физики

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
    restitution = restitution or 0
    local b = love.physics.newBody(world, x, y, kind)
    local s = love.physics.newCircleShape(r)
    local f = love.physics.newFixture(b, s, density)
    f:setRestitution(restitution)
    b:setLinearDamping(damping)
    b:setAngularDamping(damping)
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
    restitution = restitution or 0
    local b = love.physics.newBody(world, x, y, kind)
    local s = love.physics.newRectangleShape(h, w)
    local f = love.physics.newFixture(b, s, density)
    f:setRestitution(restitution)
    b:setLinearDamping(damping)
    b:setAngularDamping(damping)
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
    restitution - упругость
--]]
local function newEdgeObject(x1, y1, x2, y2, restitution)
    restitution = restitution or 0.1
    local b = love.physics.newBody(world)
    local s = love.physics.newEdgeShape(x1, y1, x2, y2)
    local f = love.physics.newFixture(b, s)
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

--[[
    body - тело, на которое крепится сенсор
    dx1, dy1, dx2, dy2 - координаты луча сенсора относительно тела
--]]
local function newSensor(body, dx1, dy1, dx2, dy2)
    local minf = 1
    local hitx, hity = 0, 0
    local hitbody
    return {
        draw = function()
            love.graphics.setColor(sensorColor)
            love.graphics.line(body:getWorldPoints(dx1, dy1, dx2, dy2))
            if minf < 1 then
                love.graphics.setColor(255, 0, 0, 255 * (1.2-minf))
                love.graphics.circle("line", hitx, hity, 3)
            end
            minf = 1
        end,
        check = function()
            local cb = function(fixture, x, y, xn, yn, fraction)
                if fraction < minf then
                    minf = fraction
                    hitx, hity = x, y
                    hitbody = fixture:getBody()
                end
                return 1
            end
            local x1, y1, x2, y2 = body:getWorldPoints(dx1, dy1, dx2, dy2)
            world:rayCast(x1, y1, x2, y2, cb)
        end,
        get = function() return 1-minf, hitbody end
    }
end

local function newEffector(body, dx1, dy1, dx2, dy2)
    local fx, fy = dx1 - dx2, dy1 - dy2
    local k = 1
    return {
        draw = function()
            local oldLineWidth = love.graphics.getLineWidth()
            love.graphics.setLineWidth(4)
            love.graphics.setColor(effectorColor)
            love.graphics.line(body:getWorldPoints(dx1, dy1, dx2*k, dy2*k))
            love.graphics.setLineWidth(oldLineWidth)
            if k > 1 then
                k = k - 0.01
            else
                k = 1
            end
        end,
        pulse = function(df)
            if df > 1 then df = 1 end
            if df < 0 then df = 0 end
            k = 1 + df*2
            body:applyForce(body:getWorldVector(fx*df*100, fy*df*100))
        end,
    }
end

local function newTaxis(sensors, effectors)
    assert(#sensors % #effectors == 0)
    local k = #sensors / #effectors
    local taxis = {}
    local j = math.floor(#sensors / 2) - 1
    for _, e in ipairs(effectors) do
        local list = {}
        for i = 1, k do
            list[#list+1] = sensors[j % #sensors + 1]
            j = j + 1
        end
        taxis[e] = list
    end
    return {
        iter = function()
            for e, list in pairs(taxis) do
                local val = 0
                for _, s in ipairs(list) do
                    local v, body = s.get()
                    if body and body:getType() ~= "static" then
                        val = val + v
                    end
                end
                e.pulse(math.sin(val/k*math.pi))
            end
        end,
    }
end

--------------------------------------------------------------------------------
-- Управление сценой

local function loadScene()
    world = love.physics.newWorld(xg*meter, yg*meter, true)

    cursorGrabbing = love.mouse.newCursor("img/grabbing.png", 0, 0)

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    
    -- объекты сцены
    objects = {
        newCircleObject(w/2, h/2, 25, "dynamic", 0.1),
        newRectangleObject(w/2, h/2 + 100, 40, 70, "dynamic", 1),
    }
    
    sensors = {}
    do  -- генерация сенсоров
        local circleBody = objects[1].body
        local count = 28
        local r1, r2 = 25, 150
        local angle = 0
        for _ = 1, count do
            local x, y = math.cos(angle), math.sin(angle)
            sensors[#sensors+1] = newSensor(circleBody, x*r1, y*r1, x*r2, y*r2)
            angle = angle + math.pi/count*2
        end
    end
    
    effectors = {}
    do  -- генерация эффекторов
        local circleBody = objects[1].body
        local count = 7
        local r1, r2 = 25, 30
        local angle = 0
        for _ = 1, count do
            local x, y = math.cos(angle), math.sin(angle)
            effectors[#effectors+1] = newEffector(circleBody, x*r1, y*r1, x*r2, y*r2)
            angle = angle + math.pi/count*2
        end
    end
    
    brains = {
        newTaxis(sensors, effectors)
    }
    
    -- cцена в размер окна
    newEdgeObject(0, 0, w, 0) -- верхняя граница
    newEdgeObject(0, h, w, h) -- нижняя граница
    newEdgeObject(0, 0, 0, h) -- левая граница
    newEdgeObject(w, 0, w, h) -- правая граница
end

local function killScene()
    world:destroy()
    objects = {}
    sensors, effectors, brains = {}, {}, {}
    mouseJoint, mouseGrab, cursorGrabbing = nil, nil, nil
    curBody = nil
end

--------------------------------------------------------------------------------
-- Обработка событий

function love.load(arg)
    if arg[#arg] == "-debug" then require("mobdebug").start() end
    love.graphics.setBackgroundColor(240, 240, 240)
    loadScene()
end

function love.update(dt)
    
    imgui.NewFrame()
    if not pause then
        world:update(dt * speed)
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
    
    local sdata = {}
    for _, s in ipairs(sensors) do
        sdata[#sdata+1] = s.get()
    end
    
    local status, floatValue = imgui.SliderFloat("speed", speed, 0.0, 1.0)
    if status then
        speed = floatValue
    end
    
    local status, floatValue = imgui.SliderFloat("gravity", yg, 0, 9.81)
    if status then
        yg = floatValue
        world:setGravity(xg*meter, yg*meter)
    end
    
    imgui.PlotHistogram("sensors", sdata, #sdata, 0, nil, 0, 1, 0, 80)
    
    if curBody then
        local status, floatValue = imgui.SliderFloat("angle", curBody:getAngle() % (math.pi*2), 0, math.pi*2)
        if status then
            curBody:setAngle(floatValue)
        end
    end
    
    for _, b in ipairs(brains) do
        b.iter()
    end
    
end

function love.draw()
    
    -- отрисовка объектов
    for _, obj in ipairs(objects) do
        obj.draw()
    end
    
    if curBody then
        love.graphics.setColor(255, 0, 0)
        love.graphics.setPointSize(4)
        love.graphics.points(curBody:getPosition())    
    end
    
    for _, s in ipairs(sensors) do
        s.draw()
        s.check()
    end
    
    for _, e in ipairs(effectors) do
        e.draw()
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
        if mouseGrab then
            mouseGrab.body:setPosition(x + mouseGrab.dx, y + mouseGrab.dy)
        elseif mouseJoint then
            mouseJoint:setTarget(x, y)
        end
        
    end
end

function love.mousepressed(x, y, button)
    imgui.MousePressed(button)
    if not imgui.GetWantCaptureMouse() then
        
        -- захват объекта мышкой
        if button == 1 then
            curBody = nil
            for _, obj in ipairs(objects) do
                if obj.test(x, y) then
                    curBody = obj.body
                    if pause then
                        local bx, by = obj.body:getPosition()
                        mouseGrab = {body = obj.body, dx = bx - x, dy = by - y}
                        love.mouse.setCursor(cursorGrabbing)
                    else
                        mouseJoint = love.physics.newMouseJoint(obj.body, x, y)
                        love.mouse.setCursor(cursorGrabbing)
                    end
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
        if button == 1 then
            if mouseGrab then
                mouseGrab = nil
                love.mouse.setCursor()
            elseif mouseJoint then
                mouseJoint:destroy()
                mouseJoint = nil
                love.mouse.setCursor()
            end
        end
        
    end
end

function love.wheelmoved(x, y)
    imgui.WheelMoved(y)
    if not imgui.GetWantCaptureMouse() then
        --
    end
end