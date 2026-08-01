-- =========================================================
-- Portal Gun Script for Delta Executor
-- =========================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- Update character reference on respawn
localPlayer.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
end)

------------------------------------------------------------
-- 1. ЭКРАН ЗАГРУЗКИ (LOADING SCREEN)
------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PortalGunGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local loadFrame = Instance.new("Frame")
loadFrame.Size = UDim2.new(1, 0, 1, 0)
loadFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
loadFrame.Parent = screenGui

local loadText = Instance.new("TextLabel")
loadText.Size = UDim2.new(0, 400, 0, 50)
loadText.Position = UDim2.new(0.5, -200, 0.4, -25)
loadText.BackgroundTransparency = 1
loadText.Text = "Инициализация Портальной Пушки..."
loadText.TextColor3 = Color3.fromRGB(0, 255, 150)
loadText.TextSize = 22
loadText.Font = Enum.Font.SourceSansBold
loadText.Parent = loadFrame

local progressBarBg = Instance.new("Frame")
progressBarBg.Size = UDim2.new(0, 300, 0, 15)
progressBarBg.Position = UDim2.new(0.5, -150, 0.5, 0)
progressBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
progressBarBg.BorderSizePixel = 0
progressBarBg.Parent = loadFrame

local progressBarFill = Instance.new("Frame")
progressBarFill.Size = UDim2.new(0, 0, 1, 0)
progressBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
progressBarFill.BorderSizePixel = 0
progressBarFill.Parent = progressBarBg

-- Анимация загрузки
TweenService:Create(progressBarFill, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = UDim2.new(1, 0, 1, 0)
}):Play()

task.wait(2.6)

-- Исчезновение загрузочного экрана
TweenService:Create(loadFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
TweenService:Create(loadText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
TweenService:Create(progressBarBg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
TweenService:Create(progressBarFill, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()

task.wait(0.5)
loadFrame:Destroy()

------------------------------------------------------------
-- 2. ВКТЮЧЕНИЕ SHIFT LOCK
------------------------------------------------------------
pcall(function()
    local userSettings = UserSettings():GetService("UserGameSettings")
    userSettings.ControlMode = Enum.ControlMode.MouseLockSwitch
    userSettings.RotationType = Enum.RotationType.CameraRelative
end)

------------------------------------------------------------
-- 3. ОСНОВНОЙ ИНТЕРФЕЙС УПРАВЛЕНИЯ
------------------------------------------------------------
local mainPanel = Instance.new("Frame")
mainPanel.Size = UDim2.new(0, 260, 0, 180)
mainPanel.Position = UDim2.new(0, 20, 0.5, -90)
mainPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainPanel.BorderSizePixel = 0
mainPanel.Active = true
mainPanel.Draggable = true
mainPanel.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = mainPanel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundTransparency = 1
title.Text = "PORTAL GUN V2"
title.TextColor3 = Color3.fromRGB(0, 255, 150)
title.TextSize = 18
title.Font = Enum.Font.SourceSansBold
title.Parent = mainPanel-- Кнопка 1: Режим стрельбы
local btnShootMode = Instance.new("TextButton")
btnShootMode.Size = UDim2.new(0.9, 0, 0, 40)
btnShootMode.Position = UDim2.new(0.05, 0, 0.25, 0)
btnShootMode.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
btnShootMode.Text = "1. Стрельба порталом (Вкл/Выкл)"
btnShootMode.TextColor3 = Color3.fromRGB(255, 255, 255)
btnShootMode.Font = Enum.Font.SourceSans
btnShootMode.TextSize = 14
btnShootMode.Parent = mainPanel

local btnCorner1 = Instance.new("UICorner")
btnCorner1.CornerRadius = UDim.new(0, 6)
btnCorner1.Parent = btnShootMode

-- Кнопка 2: Переключатель Координат
local btnCoordMode = Instance.new("TextButton")
btnCoordMode.Size = UDim2.new(0.9, 0, 0, 40)
btnCoordMode.Position = UDim2.new(0.05, 0, 0.52, 0)
btnCoordMode.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
btnCoordMode.Text = "2. Координаты и Дрифт"
btnCoordMode.TextColor3 = Color3.fromRGB(255, 255, 255)
btnCoordMode.Font = Enum.Font.SourceSans
btnCoordMode.TextSize = 14
btnCoordMode.Parent = mainPanel

local btnCorner2 = Instance.new("UICorner")
btnCorner2.CornerRadius = UDim.new(0, 6)
btnCorner2.Parent = btnCoordMode

------------------------------------------------------------
-- 4. РЕЖИМ 1: СТРЕЛОЧКА И ЗЕЛЕНАЯ ВОРОНКА (ПОРТАЛ)
------------------------------------------------------------
local aimingActive = false
local arrowMarker = Instance.new("Part")
arrowMarker.Name = "PortalAimArrow"
arrowMarker.Size = Vector3.new(0.8, 2.5, 0.8)
arrowMarker.Shape = Enum.PartType.Cylinder
arrowMarker.Color = Color3.fromRGB(0, 255, 120)
arrowMarker.Material = Enum.Material.Neon
arrowMarker.Anchored = true
arrowMarker.CanCollide = false
arrowMarker.Transparency = 1
arrowMarker.Parent = workspace

local entryPortal = nil
local exitPortal = nil

local function createVortex(position)
    local portal = Instance.new("Part")
    portal.Size = Vector3.new(5, 0.2, 5)
    portal.Position = position + Vector3.new(0, 0.1, 0)
    portal.Anchored = true
    portal.CanCollide = false
    portal.Color = Color3.fromRGB(0, 255, 100)
    portal.Material = Enum.Material.Neon
    portal.Parent = workspace

    -- Визуальная воронка
    local attachment = Instance.new("Attachment", portal)
    local particles = Instance.new("ParticleEmitter", attachment)
    particles.Texture = "rbxassetid://243664672"
    particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 120))
    particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0)})
    particles.Lifetime = NumberRange.new(0.5, 1)
    particles.Rate = 30
    particles.Speed = NumberRange.new(1, 3)

    return portal
end

btnShootMode.MouseButton1Click:Connect(function()
    aimingActive = not aimingActive
    btnShootMode.BackgroundColor3 = aimingActive and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(40, 40, 50)
    arrowMarker.Transparency = aimingActive and 0.2 or 1
end)

-- Обновление позиции стрелочки при наведении
RunService.RenderStepped:Connect(function()
    if aimingActive and mouse.Hit then
        arrowMarker.Position = mouse.Hit.Position + Vector3.new(0, 2, 0)
        arrowMarker.Orientation = Vector3.new(0, 0, 180)
    end
end)

-- Клик для создания порталов и телепортации
mouse.Button1Down:Connect(function()
    if not aimingActive or not mouse.Hit then return end
    
    local targetPos = mouse.Hit.Position

    if entryPortal then entryPortal:Destroy() end
    if exitPortal then exitPortal:Destroy() end

    -- Создаем входящий портал у игрока и исходящий портал у стрелочки
    entryPortal = createVortex(hrp.Position - Vector3.new(0, 2.5, 0))
    exitPortal = createVortex(targetPos)-- Проверка вхождения в портал
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if hrp and entryPortal and entryPortal.Parent then
            if (hrp.Position - entryPortal.Position).Magnitude < 4 then
                hrp.CFrame = exitPortal.CFrame + Vector3.new(0, 3, 0)
                connection:Disconnect()
                task.wait(1)
                if entryPortal then entryPortal:Destroy() end
                if exitPortal then exitPortal:Destroy() end
            end
        else
            connection:Disconnect()
        end
    end)
end)

------------------------------------------------------------
-- 5. РЕЖИМ 2: ОКОШКО КООРДИНАТ И СДВИГОВ
------------------------------------------------------------
local coordPanel = Instance.new("Frame")
coordPanel.Size = UDim2.new(0, 240, 0, 200)
coordPanel.Position = UDim2.new(0, 290, 0.5, -90)
coordPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
coordPanel.Visible = false
coordPanel.Parent = screenGui

local coordCorner = Instance.new("UICorner")
coordCorner.CornerRadius = UDim.new(0, 10)
coordCorner.Parent = coordPanel

local coordTitle = Instance.new("TextLabel")
coordTitle.Size = UDim2.new(1, 0, 0, 30)
coordTitle.BackgroundTransparency = 1
coordTitle.Text = "КООРДИНАТНЫЙ ТЕЛЕПОРТ"
coordTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
coordTitle.TextSize = 14
coordTitle.Font = Enum.Font.SourceSansBold
coordTitle.Parent = coordPanel

-- Крутилка / Дисплей координат (Пример: 137-V)
local numValue = 137
local letters = {"A", "B", "C", "D", "E", "F", "G", "H", "V", "Z"}
local letterIndex = 9 -- Буква 'V'

local displayBox = Instance.new("TextLabel")
displayBox.Size = UDim2.new(0.6, 0, 0, 35)
displayBox.Position = UDim2.new(0.2, 0, 0.2, 0)
displayBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
displayBox.TextColor3 = Color3.fromRGB(0, 255, 120)
displayBox.TextSize = 20
displayBox.Font = Enum.Font.Code
displayBox.Text = tostring(numValue) .. "-" .. letters[letterIndex]
displayBox.Parent = coordPanel

local function updateDisplay()
    displayBox.Text = tostring(numValue) .. "-" .. letters[letterIndex]
end

-- Кнопки "прокрутки" значения вверх/вниз
local btnUp = Instance.new("TextButton")
btnUp.Size = UDim2.new(0.15, 0, 0, 35)
btnUp.Position = UDim2.new(0.82, 0, 0.2, 0)
btnUp.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
btnUp.Text = "▲"
btnUp.TextColor3 = Color3.fromRGB(255, 255, 255)
btnUp.Parent = coordPanel

btnUp.MouseButton1Click:Connect(function()
    numValue = numValue + 10
    letterIndex = (letterIndex % #letters) + 1
    updateDisplay()
end)

local btnDown = Instance.new("TextButton")
btnDown.Size = UDim2.new(0.15, 0, 0, 35)
btnDown.Position = UDim2.new(0.03, 0, 0.2, 0)
btnDown.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
btnDown.Text = "▼"
btnDown.TextColor3 = Color3.fromRGB(255, 255, 255)
btnDown.Parent = coordPanel

btnDown.MouseButton1Click:Connect(function()
    numValue = numValue - 10
    letterIndex = letterIndex - 1
    if letterIndex < 1 then letterIndex = #letters end
    updateDisplay()
end)

-- Кнопки направления относительного телепорта
local directions = {
    {"Левее", Vector3.new(-15, 0, 0)},
    {"Правее", Vector3.new(15, 0, 0)},
    {"Вперед", Vector3.new(0, 0, -15)},
    {"Назад", Vector3.new(0, 0, 15)}
}

for i, dir in ipairs(directions) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.42, 0, 0, 30)
    
    local xPos = (i % 2 == 1) and 0.05 or 0.53
    local yPos = (i <= 2) and 0.45 or 0.65
    btn.Position = UDim2.new(xPos, 0, yPos, 0)
    
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    btn.Text = dir[1]
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 13
    btn.Parent = coordPanel

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn

    btn.MouseButton1Click:Connect(function()
        if hrp then
            hrp.CFrame = hrp.CFrame * CFrame.new(dir[2])
        end
    end)
end-- Кнопка быстрой телепортации по "координатам"
local btnTeleportCoord = Instance.new("TextButton")
btnTeleportCoord.Size = UDim2.new(0.9, 0, 0, 25)
btnTeleportCoord.Position = UDim2.new(0.05, 0, 0.83, 0)
btnTeleportCoord.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
btnTeleportCoord.Text = "ТП по коду (" .. displayBox.Text .. ")"
btnTeleportCoord.TextColor3 = Color3.fromRGB(255, 255, 255)
btnTeleportCoord.Font = Enum.Font.SourceSansBold
btnTeleportCoord.TextSize = 12
btnTeleportCoord.Parent = coordPanel

displayBox:GetPropertyChangedSignal("Text"):Connect(function()
    btnTeleportCoord.Text = "ТП по коду (" .. displayBox.Text .. ")"
end)

btnTeleportCoord.MouseButton1Click:Connect(function()
    if hrp then
        -- Смещение персонажа на основе выставленного числа
        hrp.CFrame = hrp.CFrame + Vector3.new(numValue % 50, 5, (letterIndex * 5))
    end
end)

btnCoordMode.MouseButton1Click:Connect(function()
    coordPanel.Visible = not coordPanel.Visible
end)
