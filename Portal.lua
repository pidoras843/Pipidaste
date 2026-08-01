-- // Portal Gun from Rick and Morty - Working Version
-- // Загрузка зависимостей
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local player = Players.LocalPlayer

-- // Ожидание загрузки персонажа
repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

local character = player.Character
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- // Включение Shift Lock
if player.DevEnableMouseLock then
    player.DevEnableMouseLock = true
end
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

-- // Создание GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = player.PlayerGui
screenGui.ResetOnSpawn = false

-- // Кнопка телепортации
local teleportButton = Instance.new("TextButton")
teleportButton.Size = UDim2.new(0, 200, 0, 50)
teleportButton.Position = UDim2.new(0.5, -100, 0.75, 0)
teleportButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
teleportButton.BorderSizePixel = 0
teleportButton.Text = "ТЕЛЕПОРТАЦИЯ"
teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
teleportButton.Font = Enum.Font.SourceSansBold
teleportButton.TextSize = 18
teleportButton.Parent = screenGui

-- // Кнопка смены координат
local shiftButton = Instance.new("TextButton")
shiftButton.Size = UDim2.new(0, 200, 0, 50)
shiftButton.Position = UDim2.new(0.5, -100, 0.85, 0)
shiftButton.BackgroundColor3 = Color3.fromRGB(255, 80, 0)
shiftButton.BorderSizePixel = 0
shiftButton.Text = "СМЕНА КООРДИНАТ"
shiftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shiftButton.Font = Enum.Font.SourceSansBold
shiftButton.TextSize = 18
shiftButton.Parent = screenGui

-- // Создание стрелки-указателя
local pointer = Instance.new("Part")
pointer.Size = Vector3.new(0.3, 0.3, 3)
pointer.BrickColor = BrickColor.new("Lime green")
pointer.Material = Enum.Material.Neon
pointer.Anchored = true
pointer.CanCollide = false
pointer.Transparency = 0.2
pointer.Parent = Workspace

-- // Создание конуса для стрелки
local cone = Instance.new("Part")
cone.Size = Vector3.new(1, 1, 1)
cone.BrickColor = BrickColor.new("Lime green")
cone.Material = Enum.Material.Neon
cone.Anchored = true
cone.CanCollide = false
cone.Transparency = 0.2
cone.Shape = Enum.PartType.Cylinder
cone.Parent = Workspace

-- // Свечение
local glow = Instance.new("PointLight")
glow.Brightness = 3
glow.Range = 15
glow.Color = Color3.fromRGB(0, 255, 0)
glow.Parent = pointer

-- // Переменные
local aimDistance = 20
local aimAngle = 0
local isTeleporting = false

-- // Анимация появления портальной пушки
local function showPortalGunEffect()
    -- Создаем эффект портала
    local portal = Instance.new("Part")
    portal.Size = Vector3.new(3, 5, 0.2)
    portal.Position = rootPart.Position + Vector3.new(0, 2, 0)
    portal.BrickColor = BrickColor.new("Lime green")
    portal.Material = Enum.Material.Neon
    portal.Anchored = true
    portal.CanCollide = false
    portal.Transparency = 1
    portal.Parent = Workspace
    
    -- Анимация появления
    for i = 1, 0, -0.1 do
        portal.Transparency = i
        portal.Size = Vector3.new(3 * (1-i), 5 * (1-i), 0.2)
        task.wait(0.03)
    end
    
    -- Эффект частиц
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxassetid://1284567890" -- Стандартная текстура
    particles.Rate = 100
    particles.Lifetime = NumberRange.new(0.5)
    particles.Speed = NumberRange.new(5)
    particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))
    particles.Parent = portal
    particles.Enabled = true
    
    task.wait(0.5)
    portal:Destroy()
end

-- // Функция телепортации
local function teleport()
    if isTeleporting then return end
    isTeleporting = true
    
    -- Позиция для телепортации
    local targetPos = rootPart.Position + (Camera.CFrame.LookVector * aimDistance)
    
    -- Проверка на препятствия
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character}
    
    local rayResult = Workspace:Raycast(rootPart.Position, Camera.CFrame.LookVector * aimDistance, raycastParams)
    if rayResult then
        targetPos = rayResult.Position + rayResult.Normal * 3
    end
    
    -- Эффект телепортации
    local tpEffect = Instance.new("Part")
    tpEffect.Size = Vector3.new(5, 7, 0.1)
    tpEffect.Position = targetPos
    tpEffect.BrickColor = BrickColor.new("Lime green")
    tpEffect.Material = Enum.Material.Neon
    tpEffect.Anchored = true
    tpEffect.CanCollide = false
    tpEffect.Parent = Workspace
    
    -- Телепортация персонажа
    rootPart.CFrame = CFrame.new(targetPos)
    
    -- Очистка
    task.wait(0.3)
    tpEffect:Destroy()
    isTeleporting = false
end

-- // Функция смены координат
local function shiftCoordinates()
    aimAngle = (aimAngle + 45) % 360
    local rad = math.rad(aimAngle)
    
    -- Новая позиция указателя
    local newPos = rootPart.Position + Vector3.new(
        math.cos(rad) * aimDistance,
        0,
        math.sin(rad) * aimDistance
    )
    
    -- Анимация перемещения стрелки
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(pointer, tweenInfo, {Position = newPos})
    local tween2 = TweenService:Create(cone, tweenInfo, {Position = newPos + Vector3.new(0, 0.5, 0)})
    tween:Play()
    tween2:Play()
    
    -- Эффект пушки
    showPortalGunEffect()
end

-- // Привязка кнопок
teleportButton.MouseButton1Click:Connect(function()
    showPortalGunEffect()
    teleport()
end)

shiftButton.MouseButton1Click:Connect(shiftCoordinates)

-- // Обновление позиции указателя
RunService.RenderStepped:Connect(function()
    if not character or not rootPart then return end
    
    local cameraPos = Camera.CFrame.Position
    local cameraLook = Camera.CFrame.LookVector
    
    -- Обновление позиции указателя
    local pointerPos = rootPart.Position + (cameraLook * aimDistance)
    pointer.Position = pointerPos
    cone.Position = pointerPos + Vector3.new(0, 0.5, 0)
    
    -- Направление указателя
    pointer.CFrame = CFrame.new(pointerPos, pointerPos + cameraLook)
end)

-- // Начальный эффект при активации
showPortalGunEffect()

-- // Сообщение об активации
game.StarterGui:SetCore("SendNotification", {
    Title = "Портальная пушка",
    Text = "Скрипт активирован! Используйте кнопки для управления.",
    Duration = 5,
    Icon = "rbxassetid://0"
})

print("Portal Gun Script Loaded Successfully!")
