local imgui = require "imgui"
local adt = require "adt"

ui = {}

local tabBars = {}
local tabFont = love.graphics.newFont("res/FreePixel.ttf", 16);

local treeStack = adt.NewStack()
local drawStack = adt.NewStack()
local eventStack = adt.NewStack()


local function newTabBar(label, x, y, w, h) --> table

    local tabs = {}
    local curtab
    local tabsDrawStack = adt.NewStack()
    local tabsEventStack = adt.NewStack()

    local tb = {}

    function tb.Type()
        return "tabBar"
    end

    function tb.Label()
        return label
    end

    function tb.Insert(label)
        local tab = tabs[label]
        if not tab then
            tab = {
                label = label,
                x = 0,
                y = 0,
                w = 0,
                h = 0,
            }
            tabs[label] = tab
        end
        if not curtab then
            curtab = tab
        end
        tabsDrawStack.push(tab)
        return tab == curtab
    end

    function tb.Draw()

        -- TODO: Убрать магические числа

        local space = 6

        love.graphics.setColor(150, 150, 150)
        love.graphics.rectangle("fill", x, y, w, h)

        local dx = 0
        tabsEventStack.clear()
        tab = tabsDrawStack.pop()
        while tab do
            if tab == curtab then
                love.graphics.setColor(240, 240, 240)
            else
                love.graphics.setColor(180, 180, 180)
            end
            dx = dx + space
            tab.x = x + dx
            tab.y = y + 5
            tab.w = 100
            tab.h = 20
            love.graphics.rectangle("fill", tab.x, tab.y, tab.w, tab.h)
            love.graphics.setColor(0, 0, 0)
            local text = love.graphics.newText(tabFont, tab.label)
            if text:getWidth() > 90 then
                text:set(tab.label:sub(1, 8).."...")
            end
            love.graphics.draw(text, tab.x+5, tab.y)
            dx = dx + tab.w
            tabsEventStack.push(tab)
            tab = tabsDrawStack.pop()
        end
    end

    function tb.MousePressed(mx, my)
        if x < mx and mx < x+w and
           y < my and my < y+h then
            for _, tab in ipairs(tabsEventStack) do
                if tab.x < mx and mx < tab.x+tab.w and
                   tab.y < my and my < tab.y+tab.h then
                    curtab = tab
                    break
                end
            end
        end
        return false
    end

    return tb
end

function ui.BeginTabBar(label, x, y, w, h) --> bool
    local tabBar = tabBars[label]
    if not tabBar then
        tabBar = newTabBar(label, x, y, w, h)
        tabBars[label] = tabBar
    end
    treeStack.push(tabBar)
    return true
end

function ui.EndTabBar()
    local tabBar = treeStack.pop()
    assert(tabBar.Type() == "tabBar")
    drawStack.push(tabBar)
end

function ui.TabItem(label) --> bool
    local tabBar = treeStack.peek()
    assert(tabBar.Type() == "tabBar")
    return tabBar.Insert(label)
end


function ui.NewFrame()
    imgui.NewFrame()
end


function ui.BeginMainMenuBar() --> bool
    return imgui.BeginMainMenuBar()
end

function ui.EndMainMenuBar()
    imgui.EndMainMenuBar()
end


function ui.BeginMenuBar() --> bool
    return imgui.BeginMenuBar()
end

function ui.EndMenuBar()
    imgui.EndMenuBar()
end


function ui.BeginMenu(
        label,  -- string
        enabled -- bool = true
    ) --> bool
    return imgui.BeginMenu(label, enabled or true)
end

function ui.EndMenu()
    imgui.EndMenu()
end


function ui.MenuItem(
        label,    -- string
        shortcut, -- string
        selected, -- bool = false
        enabled   -- bool = true
    ) --> bool
    return imgui.MenuItem(label, shortcut, selected or false, enabled or true)
end


function ui.MenuItem2(
        label,    -- string
        shortcut, -- string
        selected, -- bool
        enabled   -- bool = true
    ) --> bool
    return imgui.MenuItem2(label, shortcut, selected, enabled or true)
end


function ui.Button(
        label, -- string
        width, -- number
        height -- number
    ) --> bool
    return imgui.Button(label, width, height)
end


function ui.SliderFloat(
        label,  -- string
        value,  -- float
        min,    -- float
        max,    -- float
        format, -- string = "%.3f"
        power   -- 1.0
    ) --> bool, float
    return imgui.SliderFloat("speed", value, min, max, format, power)
end


function ui.Render()
    eventStack.clear()
    local element = drawStack.pop()
    while element do
        element.Draw()
        eventStack.push(element)
        element = drawStack.pop()
    end
    love.graphics.setColor(255, 255, 255)
    imgui.Render()
end


function ui.ShutDown()
    imgui.ShutDown()
end


function ui.TextInput(t)
    imgui.TextInput(t)
    return imgui.GetWantCaptureKeyboard()
end

function ui.KeyPressed(key) --> bool
    imgui.KeyPressed(key)
    return imgui.GetWantCaptureKeyboard()
end

function ui.KeyReleased(key) --> bool
    imgui.KeyReleased(key)
    return imgui.GetWantCaptureKeyboard()
end


function ui.MouseMoved(x, y) --> bool
    imgui.MouseMoved(x, y)
    return imgui.GetWantCaptureMouse()
end

function ui.MousePressed(x, y, button) --> bool
    imgui.MousePressed(button)
    if imgui.GetWantCaptureMouse() then
        return true
    else
        if button == 1 then
            for _, element in ipairs(eventStack) do
                if element.MousePressed(x, y) then
                    return true
                end
            end
        end
    end
    return false
end

function ui.MouseReleased(x, y, button) --> bool
    imgui.MouseReleased(button)
    return imgui.GetWantCaptureMouse()
end

function ui.WheelMoved(x, y) --> bool
    imgui.WheelMoved(y)
    return imgui.GetWantCaptureMouse()
end