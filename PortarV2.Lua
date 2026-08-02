-- =========================================================
-- Advanced Portal Controller Script for Delta Executor
-- =========================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

localPlayer.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
end)

------------------------------------------------------------
-- 1. СОЗДАНИЕ ПУШКИ (СЕРЫЙ МЕТАЛЛИЧЕСКИЙ КОНТРОЛЛЕР)
------------------------------------------------------------
local function givePortalGun()
    local backpack = localPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    local existingTool = backpack:FindFirstChild("Портальный Контроллер") or (character and character:FindFirstChild("Портальный Контроллер"))
    if existingTool then existingTool:Destroy() end

    local tool = Instance.new("Tool")
    tool.Name = "Портальный Контроллер"
    tool.RequiresHandle = true

    -- Основной корпус пульта
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.6, 0.3, 1.4)
    handle.Color = Color3.fromRGB(110, 115, 120) -- Серый металл
    handle.Material = Enum.Material.Metal
    handle.Parent = tool

    -- Неоновый индикатор на пульте
    local led = Instance.new("Part")
    led.Name = "LED"
    led.Size = Vector3.new(0.2, 0.1, 0.2)
    led.Color = Color3.fromRGB(0, 255, 120)
    led.Material = Enum.Material.Neon
    led.CanCollide = false
    led.Parent = tool

    local weld = Instance.new("Weld")
    weld.Part0 = handle
    weld.Part1 = led
    weld.C0 = CFrame.new(0, 0.15, -0.4)
    weld.Parent = handle

    tool.Parent = backpack
end

givePortalGun()

------------------------------------------------------------
-- 2. ЭКРАН ЗАГРУЗКИ (LOADING SCREEN)
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
loadText.Text = "Загрузка Контроллера..."
loadText.TextColor3 = Color3.fromRGB(0, 255, 120)
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

TweenService:Create(progressBarFill, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = UDim2.new(1, 0, 1, 0)
}):Play()

task.wait(2.1)

TweenService:Create(loadFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
TweenService:Create(loadText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
TweenService:Create(progressBarBg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
TweenService:Create(progressBarFill, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()

task.wait(0.5)
loadFrame:Destroy()------------------------------------------------------------
-- 3. ВКЛЮЧЕНИЕ SHIFT LOCK
------------------------------------------------------------
pcall(function()
    local userSettings = UserSettings():GetService("UserGameSettings")
    userSettings.ControlMode = Enum.ControlMode.MouseLockSwitch
    userSettings.RotationType = Enum.RotationType.CameraRelative
end)

------------------------------------------------------------
-- 4. ГЛАВНОЕ МЕНЮ
------------------------------------------------------------
local mainPanel = Instance.new("Frame")
mainPanel.Size = UDim2.new(0, 240, 0, 150)
mainPanel.Position = UDim2.new(0, 20, 0.5, -75)
mainPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
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
title.Text = "ПУЛЬТ УПРАВЛЕНИЯ"
title.TextColor3 = Color3.fromRGB(0, 255, 120)
title.TextSize = 16
title.Font = Enum.Font.SourceSansBold
title.Parent = mainPanel

local btnShootMode = Instance.new("TextButton")
btnShootMode.Size = UDim2.new(0.9, 0, 0, 40)
btnShootMode.Position = UDim2.new(0.05, 0, 0.28, 0)
btnShootMode.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
btnShootMode.Text = "1. Режим Стрельбы"
btnShootMode.TextColor3 = Color3.fromRGB(255, 255, 255)
btnShootMode.Font = Enum.Font.SourceSans
btnShootMode.TextSize = 14
btnShootMode.Parent = mainPanel

local btnCorner1 = Instance.new("UICorner")
btnCorner1.CornerRadius = UDim.new(0, 6)
btnCorner1.Parent = btnShootMode

local btnCoordMode = Instance.new("TextButton")
btnCoordMode.Size = UDim2.new(0.9, 0, 0, 40)
btnCoordMode.Position = UDim2.new(0.05, 0, 0.62, 0)
btnCoordMode.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
btnCoordMode.Text = "2. Координаты"
btnCoordMode.TextColor3 = Color3.fromRGB(255, 255, 255)
btnCoordMode.Font = Enum.Font.SourceSans
btnCoordMode.TextSize = 14
btnCoordMode.Parent = mainPanel

local btnCorner2 = Instance.new("UICorner")
btnCorner2.CornerRadius = UDim.new(0, 6)
btnCorner2.Parent = btnCoordMode

------------------------------------------------------------
-- 5. РЕЖИМ 1: СТРЕЛКА И ЗЕЛЕНАЯ ВОРОНКА (15 СЕКУНД)
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

local function createVortex(position)
    local portal = Instance.new("Part")
    portal.Size = Vector3.new(6, 0.2, 6)
    portal.Position = position + Vector3.new(0, 0.1, 0)
    portal.Anchored = true
    portal.CanCollide = false
    portal.Color = Color3.fromRGB(0, 255, 100)
    portal.Material = Enum.Material.Neon
    portal.Parent = workspace

    local attachment = Instance.new("Attachment", portal)
    local particles = Instance.new("ParticleEmitter", attachment)
    particles.Texture = "rbxassetid://243664672"
    particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 120))
    particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0)})
    particles.Lifetime = NumberRange.new(0.5, 1)
    particles.Rate = 40
    particles.Speed = NumberRange.new(1, 3)

    return portal
end

btnShootMode.MouseButton1Click:Connect(function()
    aimingActive = not aimingActive
    btnShootMode.BackgroundColor3 = aimingActive and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(50, 50, 60)
    arrowMarker.Transparency = aimingActive and 0.2 or 1
end)RunService.RenderStepped:Connect(function()
    if aimingActive and mouse.Hit then
        arrowMarker.Position = mouse.Hit.Position + Vector3.new(0, 2, 0)
        arrowMarker.Orientation = Vector3.new(0, 0, 180)
    end
end)

-- Создание порталов при клике
mouse.Button1Down:Connect(function()
    if not aimingActive or not mouse.Hit then return end
    
    local targetPos = mouse.Hit.Position
    local entryPos = hrp.Position - Vector3.new(0, 2.5, 0)

    local entryPortal = createVortex(entryPos)
    local exitPortal = createVortex(targetPos)

    local isTeleported = false

    -- Проверка приближения к воронке
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if hrp and entryPortal and entryPortal.Parent then
            -- Телепортация только если подойти близко (< 4.5 studs)
            if not isTeleported and (hrp.Position - entryPortal.Position).Magnitude < 4.5 then
                isTeleported = true
                hrp.CFrame = exitPortal.CFrame + Vector3.new(0, 3, 0)
            end
        else
            connection:Disconnect()
        end
    end)

    -- Воронка исчезает РОВНО через 15 секунд
    task.delay(15, function()
        if connection then connection:Disconnect() end
        if entryPortal then entryPortal:Destroy() end
        if exitPortal then exitPortal:Destroy() end
    end)
end)

------------------------------------------------------------
-- 6. РЕЖИМ 2: КООРДИНАТЫ (БЕЛЫЙ ФОН, ЧЕРНЫЙ КВАДРАТ, КРАСНЫЕ ЦИФРЫ, КРУТИЛКА)
------------------------------------------------------------
local coordPanel = Instance.new("Frame")
coordPanel.Size = UDim2.new(0, 260, 0, 260)
coordPanel.Position = UDim2.new(0, 280, 0.5, -130)
coordPanel.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- БЕЛЫЙ ФОН
coordPanel.Visible = false
coordPanel.Active = true
coordPanel.Draggable = true
coordPanel.Parent = screenGui

local coordCorner = Instance.new("UICorner")
coordCorner.CornerRadius = UDim.new(0, 12)
coordCorner.Parent = coordPanel

-- Черная рамка вокруг белой панели для стиля
local borderStroke = Instance.new("UIStroke")
borderStroke.Color = Color3.fromRGB(0, 0, 0)
borderStroke.Thickness = 3
borderStroke.Parent = coordPanel

local coordTitle = Instance.new("TextLabel")
coordTitle.Size = UDim2.new(1, 0, 0, 30)
coordTitle.BackgroundTransparency = 1
coordTitle.Text = "СИСТЕМА КООРДИНАТ"
coordTitle.TextColor3 = Color3.fromRGB(0, 0, 0)
coordTitle.TextSize = 14
coordTitle.Font = Enum.Font.SourceSansBold
coordTitle.Parent = coordPanel

-- ЧЕРНЫЙ КВАДРАТ (ЭКРАН)
local blackSquare = Instance.new("Frame")
blackSquare.Size = UDim2.new(0, 180, 0, 65)
blackSquare.Position = UDim2.new(0.5, -90, 0.16, 0)
blackSquare.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- ЧЕРНЫЙ КВАДРАТ
blackSquare.Parent = coordPanel

local squareCorner = Instance.new("UICorner")
squareCorner.CornerRadius = UDim.new(0, 6)
squareCorner.Parent = blackSquare

-- Список доступных координат
local coordList = {"137-C", "138-C", "139-C", "140-G", "141-X", "142-Z", "143-A", "144-V"}
local currentCoordIndex = 1

-- КРАСНЫЕ ЦИФРЫ ВНУТРИ ЧЕРНОГО КВАДРАТА
local redDisplayText = Instance.new("TextLabel")
redDisplayText.Size = UDim2.new(1, 0, 1, 0)
redDisplayText.BackgroundTransparency = 1
redDisplayText.TextColor3 = Color3.fromRGB(255, 0, 0) -- КРАСНЫЙ ЦВЕТ ЦИФР
redDisplayText.TextSize = 28
redDisplayText.Font = Enum.Font.Code
redDisplayText.Text = coordList[currentCoordIndex]
redDisplayText.Parent = blackSquare

-- КРУТИЛКА (ВРАЩАЮЩИЙСЯ ДИСК И КНОПКИ ВЛЕВО/ВПРАВО)
local knobFrame = Instance.new("Frame")
knobFrame.Size = UDim2.new(0, 80, 0, 80)
knobFrame.Position = UDim2.new(0.5, -40, 0.48, 0)
knobFrame.BackgroundColor3 = Color3.fromRGB(200, 200, 205)
knobFrame.Parent = coordPanel

local knobCorner = Instance.new("UICorner")
knobCorner.CornerRadius = UDim.new(1, 0) -- Круглая ручка
knobCorner.Parent = knobFrame

local knobPointer = Instance.new("Frame")
knobPointer.Size = UDim2.new(0, 6, 0, 30)
knobPointer.Position = UDim2.new(0.5, -3, 0.1, 0)
knobPointer.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
knobPointer.Parent = knobFramelocal knobAngle = 0

local function rotateKnob(direction)
    -- Вращение только влево или вправо
    if direction == "Left" then
        currentCoordIndex = currentCoordIndex - 1
        if currentCoordIndex < 1 then currentCoordIndex = #coordList end
        knobAngle = knobAngle - 45
    elseif direction == "Right" then
        currentCoordIndex = currentCoordIndex + 1
        if currentCoordIndex > #coordList then currentCoordIndex = 1 end
        knobAngle = knobAngle + 45
    end

    redDisplayText.Text = coordList[currentCoordIndex]

    -- Анимация вращения крутилки
    TweenService:Create(knobFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Rotation = knobAngle
    }):Play()
end

-- Кнопки управления вращением крутилки
local btnRotateLeft = Instance.new("TextButton")
btnRotateLeft.Size = UDim2.new(0, 40, 0, 40)
btnRotateLeft.Position = UDim2.new(0.12, 0, 0.55, 0)
btnRotateLeft.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
btnRotateLeft.Text = "◄"
btnRotateLeft.TextColor3 = Color3.fromRGB(255, 255, 255)
btnRotateLeft.TextSize = 18
btnRotateLeft.Parent = coordPanel

local btnLeftCorner = Instance.new("UICorner")
btnLeftCorner.CornerRadius = UDim.new(1, 0)
btnLeftCorner.Parent = btnRotateLeft

local btnRotateRight = Instance.new("TextButton")
btnRotateRight.Size = UDim2.new(0, 40, 0, 40)
btnRotateRight.Position = UDim2.new(0.72, 0, 0.55, 0)
btnRotateRight.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
btnRotateRight.Text = "►"
btnRotateRight.TextColor3 = Color3.fromRGB(255, 255, 255)
btnRotateRight.TextSize = 18
btnRotateRight.Parent = coordPanel

local btnRightCorner = Instance.new("UICorner")
btnRightCorner.CornerRadius = UDim.new(1, 0)
btnRightCorner.Parent = btnRotateRight

btnRotateLeft.MouseButton1Click:Connect(function()
    rotateKnob("Left")
end)

btnRotateRight.MouseButton1Click:Connect(function()
    rotateKnob("Right")
end)

-- КНОПКА ТЕЛЕПОРТАЦИИ
local btnTeleport = Instance.new("TextButton")
btnTeleport.Size = UDim2.new(0.85, 0, 0, 32)
btnTeleport.Position = UDim2.new(0.075, 0, 0.83, 0)
btnTeleport.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
btnTeleport.Text = "ТЕЛЕПОРТ"
btnTeleport.TextColor3 = Color3.fromRGB(0, 255, 120)
btnTeleport.Font = Enum.Font.SourceSansBold
btnTeleport.TextSize = 14
btnTeleport.Parent = coordPanel

local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 6)
tpCorner.Parent = btnTeleport

btnTeleport.MouseButton1Click:Connect(function()
    if hrp then
        -- Телепортируем игрока на смещение в зависимости от выбранного кода
        local offset = currentCoordIndex * 20
        hrp.CFrame = hrp.CFrame + Vector3.new(offset % 60, 5, offset)
    end
end)

btnCoordMode.MouseButton1Click:Connect(function()
    coordPanel.Visible = not coordPanel.Visible
end)local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Удаленная функция для запроса создания порталов
local CreatePortalEvent = Instance.new("RemoteEvent")
CreatePortalEvent.Name = "CreatePortalEvent"
CreatePortalEvent.Parent = ReplicatedStorage

-- Функция спавна круглого вытянутого портала с воронкой
local function createPortalModel(color)
  local portal = Instance.new("Part")
  portal.Name = "CustomPortal"
  portal.Shape = Enum.PartType.Cylinder
  portal.Size = Vector3.new(0.4, 8, 5) -- Круглый и немного удлиненный
  portal.Color = color
  portal.Material = Enum.Material.Neon
  portal.Anchored = true
  portal.CanCollide = false
  
  -- Добавляем визуал воронки
  local attachment = Instance.new("Attachment", portal)
  local particles = Instance.new("ParticleEmitter", attachment)
  particles.Texture = "rbxassetid://243660364" -- Текстура спирали/воронки
  particles.Rate = 30
  particles.Lifetime = NumberRange.new(0.5, 1)
  particles.Speed = NumberRange.new(0)
  particles.RotSpeed = NumberRange.new(180, 360)
  particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0)})

  return portal
end

local activePortals = {}

CreatePortalEvent.OnServerEvent:Connect(function(player, targetCFrame, portalType)
  local character = player.Character
  if not character or not character:FindFirstChild("PortalGun") then 
    -- Без портальной пушки порталы НЕ работают!
    return 
  end

  -- Воспроизведение звука на пушке
  local tool = character:FindFirstChild("PortalGun")
  if tool:FindFirstChild("PortalOpenSound") then
    tool.PortalOpenSound:Play()
  end

  -- Удаляем старый портал этого типа, если был
  if activePortals[player.UserId] and activePortals[player.UserId][portalType] then
    activePortals[player.UserId][portalType]:Destroy()
  else
    if not activePortals[player.UserId] then
      activePortals[player.UserId] = {}
    end
  end

  -- Создание нового физического портала
  local portalColor = (portalType == 1) and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(255, 170, 0)
  local newPortal = createPortalModel(portalColor)
  newPortal.CFrame = targetCFrame
  newPortal.Parent = workspace
  
  activePortals[player.UserId][portalType] = newPortal

  -- Логика телепортации (Кроссплатформенная: PC, Phone, Tablet, VR)
  local touchCooldown = {}
  
  newPortal.Touched:Connect(function(hit)
    local hrp = hit.Parent:FindFirstChild("HumanoidRootPart")
    local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
    
    if hrp and hum and not touchCooldown[hrp] then
      -- Проверяем наличие парного портала
      local otherType = (portalType == 1) and 2 or 1
      local destinationPortal = activePortals[player.UserId] and activePortals[player.UserId][otherType]
      
      if destinationPortal then
        touchCooldown[hrp] = true
        
        -- Телепортируем чуть-чуть ВПЕРЕДИ портала, чтобы не дотрагиваться сразу и не застревать
        local spawnOffset = destinationPortal.CFrame * CFrame.new(0, 0, -3)
        hrp.CFrame = CFrame.new(spawnOffset.Position, spawnOffset.Position + destinationPortal.CFrame.LookVector)
        
        task.wait(1.2) -- Кулдаун, чтобы можно было зайти обратно
        touchCooldown[hrp] = nil
      end
    end
  end)

  -- Авто-удаление портала ровно через 5 секунд
  task.delay(5, function()
    if newPortal and newPortal.Parent then
      newPortal:Destroy()
      if activePortals[player.UserId] then
        activePortals[player.UserId][portalType] = nil
      end
    end
  end)
end)ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Удаленная функция для запроса создания порталов
local CreatePortalEvent = Instance.new("RemoteEvent")
CreatePortalEvent.Name = "CreatePortalEvent"
CreatePortalEvent.Parent = ReplicatedStorage

-- Функция спавна круглого вытянутого портала с воронкой
local function createPortalModel(color)
  local portal = Instance.new("Part")
  portal.Name = "CustomPortal"
  portal.Shape = Enum.PartType.Cylinder
  portal.Size = Vector3.new(0.4, 8, 5) -- Круглый и немного удлиненный
  portal.Color = color
  portal.Material = Enum.Material.Neon
  portal.Anchored = true
  portal.CanCollide = false
  
  -- Добавляем визуал воронки
  local attachment = Instance.new("Attachment", portal)
  local particles = Instance.new("ParticleEmitter", attachment)
  particles.Texture = "rbxassetid://243660364" -- Текстура спирали/воронки
  particles.Rate = 30
  particles.Lifetime = NumberRange.new(0.5, 1)
  particles.Speed = NumberRange.new(0)
  particles.RotSpeed = NumberRange.new(180, 360)
  particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0)})

  return portal
end

local activePortals = {}

CreatePortalEvent.OnServerEvent:Connect(function(player, targetCFrame, portalType)
  local character = player.Character
  if not character or not character:FindFirstChild("PortalGun") then 
    -- Без портальной пушки порталы НЕ работают!
    return 
  end

  -- Воспроизведение звука на пушке
  local tool = character:FindFirstChild("PortalGun")
  if tool:FindFirstChild("PortalOpenSound") then
    tool.PortalOpenSound:Play()
  end

  -- Удаляем старый портал этого типа, если был
  if activePortals[player.UserId] and activePortals[player.UserId][portalType] then
    activePortals[player.UserId][portalType]:Destroy()
  else
    if not activePortals[player.UserId] then
      activePortals[player.UserId] = {}
    end
  end

  -- Создание нового физического портала
  local portalColor = (portalType == 1) and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(255, 170, 0)
  local newPortal = createPortalModel(portalColor)
  newPortal.CFrame = targetCFrame
  newPortal.Parent = workspace
  
  activePortals[player.UserId][portalType] = newPortal

  -- Логика телепортации (Кроссплатформенная: PC, Phone, Tablet, VR)
  local touchCooldown = {}
  
  newPortal.Touched:Connect(function(hit)
    local hrp = hit.Parent:FindFirstChild("HumanoidRootPart")
    local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
    
    if hrp and hum and not touchCooldown[hrp] then
      -- Проверяем наличие парного портала
      local otherType = (portalType == 1) and 2 or 1
      local destinationPortal = activePortals[player.UserId] and activePortals[player.UserId][otherType]
      
      if destinationPortal then
        touchCooldown[hrp] = true
        
        -- Телепортируем чуть-чуть ВПЕРЕДИ портала, чтобы не дотрагиваться сразу и не застревать
        local spawnOffset = destinationPortal.CFrame * CFrame.new(0, 0, -3)
        hrp.CFrame = CFrame.new(spawnOffset.Position, spawnOffset.Position + destinationPortal.CFrame.LookVector)
        
        task.wait(1.2) -- Кулдаун, чтобы можно было зайти обратно
        touchCooldown[hrp] = nil
      end
    end
  end)

  -- Авто-удаление портала ровно через 5 секунд
  task.delay(5, function()
    if newPortal and newPortal.Parent then
      newPortal:Destroy()
      if activePortals[player.UserId] then
        activePortals[player.UserId][portalType] = nil
      end
    end
  end)
end)
