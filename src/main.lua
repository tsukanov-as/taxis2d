
require "ui"
local editor = require "editor"

local openFiles = {}
local currentFile

function love.load(arg)
    if arg[#arg] == "-debug" then require("mobdebug").start() end
end

function love.update(dt)

    ui.NewFrame()

    if ui.BeginMainMenuBar() then
        if ui.BeginMenu("Scene") then

            if ui.MenuItem("New") then
                openFiles[#openFiles+1] = editor.newScene(#openFiles)
            end

            if ui.MenuItem("Open") then
                openFiles[#openFiles+1] = editor.openScene()
            end

            ui.EndMenu()
        end
        ui.EndMainMenuBar()
    end

    if ui.BeginTabBar("main", 0, 19, love.graphics.getWidth(), 23) then
        for _, file in ipairs(openFiles) do
            if ui.TabItem(file.path) then
                currentFile = file
            end
        end
        ui.EndTabBar()
    end

    if currentFile then
        currentFile.update(dt)
    end

end


function love.draw()

    love.graphics.setBackgroundColor(240, 240, 240)

    if currentFile then
        currentFile.draw(1, 44)
    end

    ui.Render()
end

function love.resize(w, h)
    ui.Resize(w, h)
end

function love.quit()
    ui.ShutDown();
end

function love.textinput(t)
    ui.TextInput(t)
end

function love.keypressed(key)
    ui.KeyPressed(key)
end

function love.keyreleased(key)
    ui.KeyReleased(key)
end

function love.mousemoved(x, y)
    ui.MouseMoved(x, y)
end

function love.mousepressed(x, y, button)
    ui.MousePressed(x, y, button)
end

function love.mousereleased(x, y, button)
    ui.MouseReleased(x, y, button)
end

function love.wheelmoved(x, y)
    ui.WheelMoved(x, y)
end