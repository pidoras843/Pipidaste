-- ========================================================
-- DELTA EXECUTOR PORTAL SYSTEM (MEGA UPDATE)
-- ========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-----------------------------------------------------------
-- 1. НАСТРОЙКИ СКИНОРОВ И ПЕРЕМЕННЫЕ
-----------------------------------------------------------
local currentSkin = "Default" -- "Default", "EvilMorty", "RickPrime", "Kids"
local activePortals = { [1] = nil, [2] = nil }
local targetPlaceId = nil
local currentCoordNumber = math.random(0, 500)

-----------------------------------------------------------
-- 2. СОЗДАНИЕ ДЕТАЛИЗИРОВАННОЙ БЕЛОЙ ПУШКИ
-----------------------------------------------------------
local function createPortalGunModel()
  local tool = Instance.new("Tool")
  tool.Name = "PortalGun"
  tool.RequiresHandle = true
  tool.CanBeDropped = false

  -- Корпус пушки
  local handle = Instance.new("Part")
  handle.Name = "Handle"
  handle.Size = Vector3.new(0.8, 1.1, 2.2)
  handle.Color = (currentSkin == "RickPrime") and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(255, 255, 255)
  handle.Material = Enum.Material.SmoothPlastic
  handle.Parent = tool

  -- Штучка для держания (Рукоятка)
  local grip = Instance.new("Part")
  grip.Name = "Grip"
  grip.Size = Vector3.new(0.4, 1.2, 0.4)
  grip.Color = (currentSkin == "Kids") and Color3.fromRGB(255, 120, 0) or Color3.fromRGB(200, 200, 200)
  grip.CanCollide = false
  grip.Parent = tool
  local wGrip = Instance.new("Weld", handle)
  wGrip.Part0 = handle; wGrip.Part1 = grip
  wGrip.C0 = CFrame.new(0, -0.8, 0.4) * CFrame.Angles(math.rad(-20), 0, 0)

  -- Прозрачная колба с зелёной жидкостью наверху
  local glass = Instance.new("Part")
  glass.Name = "GlassTubing"
  glass.Size = Vector3.new(0.6, 0.5, 1.2)
  glass.Transparency = 0.6
  glass.Color = Color3.fromRGB(200, 240, 255)
  glass.Material = Enum.Material.Glass
  glass.CanCollide = false
  glass.Parent = tool
  local wGlass = Instance.new("Weld", handle)
  wGlass.Part0 = handle; wGlass.Part1 = glass
  wGlass.C0 = CFrame.new(0, 0.6, 0)

  local liquid = Instance.new("Part")
  liquid.Name = "GreenLiquid"
  liquid.Size = Vector3.new(0.5, 0.4, 1.1)
  liquid.Color = (currentSkin == "EvilMorty") and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(0, 255, 50)
  liquid.Material = Enum.Material.Neon
  liquid.CanCollide = false
  liquid.Parent = tool
  local wLiquid = Instance.new("Weld", glass)
  wLiquid.Part0 = glass; wLiquid.Part1 = liquid

  -- Черный дуло на конце (где стреляет)
  local nozzle = Instance.new("Part")
  nozzle.Name = "Nozzle"
  nozzle.Size = Vector3.new(0.6, 0.6, 0.3)
  nozzle.Color = Color3.fromRGB(25, 25, 25)
  nozzle.Material = Enum.Material.SmoothPlastic
  nozzle.CanCollide = false
  nozzle.Parent = tool
  local wNozzle = Instance.new("Weld", handle)
  wNozzle.Part0 = handle; wNozzle.Part1 = nozzle
  wNozzle.C0 = CFrame.new(0, 0, -1.25)

  -- 3 маленьких декоративных квадратика
  for i = 1, 3 do
    local sq = Instance.new("Part")
    sq.Size = Vector3.new(0.15, 0.15, 0.15)
    sq.Color = (currentSkin == "Kids") and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(50, 50, 50)
    sq.Material = Enum.Material.SmoothPlastic
    sq.CanCollide = false
    sq.Parent = tool
    local wSq = Instance.new("Weld", handle)
    wSq.Part0 = handle; wSq.Part1 = sq
    wSq.C0 = CFrame.new(0.42, 0.2 - (i * 0.2), 0)
  end

  -- Звук выстрела
  local sound = Instance.new("Sound", handle)
  sound.Name = "PortalSound"
  sound.SoundId = "rbxassetid://200632875"
  sound.Volume = 1

  tool.Parent = LocalPlayer:WaitForChild("Backpack")
end

-- Авто-выдача при спавне
LocalPlayer.CharacterAdded:Connect(function()
  task.wait(0.5)
  createPortalGunModel()
end)
createPortalGunModel()-----------------------------------------------------------
-- 3. ИНТЕРФЕЙС UI (ТОЛЬКО КНОПКИ, БЕЗ МЕНЮ)
-----------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuickButtonUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local btnContainer = Instance.new("Frame", screenGui)
btnContainer.Size = UDim2.new(0, 220, 0, 260)
btnContainer.Position = UDim2.new(0.02, 0, 0.35, 0)
btnContainer.BackgroundTransparency = 1
btnContainer.Active = true
btnContainer.Draggable = true

local function styleButton(btn, text, color)
  btn.Size = UDim2.new(1, 0, 0, 45)
  btn.BackgroundColor3 = color
  btn.Text = text
  btn.TextColor3 = Color3.fromRGB(255, 255, 255)
  btn.Font = Enum.Font.GothamBold
  btn.TextSize = 13
  Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
end

-- КНОПКА 1: Стрелять
local btnShoot = Instance.new("TextButton", btnContainer)
btnShoot.Position = UDim2.new(0, 0, 0, 0)
styleButton(btnShoot, "💥 СТРЕЛЯТЬ (СПАВН)", Color3.fromRGB(0, 170, 255))

-- КНОПКА 2: Координации (Белый фон, красный квадрат, тёмно-красный текст до 500)
local btnCoord = Instance.new("TextButton", btnContainer)
btnCoord.Position = UDim2.new(0, 0, 0, 55)
styleButton(btnCoord, "", Color3.fromRGB(255, 255, 255))

local redSquare = Instance.new("Frame", btnCoord)
redSquare.Size = UDim2.new(0, 25, 0, 25)
redSquare.Position = UDim2.new(0.05, 0, 0.22, 0)
redSquare.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
Instance.new("UICorner", redSquare).CornerRadius = UDim.new(0, 4)

local coordText = Instance.new("TextLabel", btnCoord)
coordText.Size = UDim2.new(0.7, 0, 1, 0)
coordText.Position = UDim2.new(0.25, 0, 0, 0)
coordText.BackgroundTransparency = 1
coordText.Text = "КООРДИНАТЫ: " .. currentCoordNumber
coordText.TextColor3 = Color3.fromRGB(139, 0, 0) -- Тёмно-красный
coordText.Font = Enum.Font.GothamBold
coordText.TextSize = 13

-- Вращатель-крутилка прямо на кнопке Координат
local dialSpinner = Instance.new("TextButton", btnCoord)
dialSpinner.Size = UDim2.new(0, 30, 0, 30)
dialSpinner.Position = UDim2.new(0.85, 0, 0.15, 0)
dialSpinner.Text = "🌀"
dialSpinner.TextSize = 16
dialSpinner.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
Instance.new("UICorner", dialSpinner).CornerRadius = UDim.new(1, 0)

-- Настройка крутилки
dialSpinner.MouseButton1Click:Connect(function()
  dialSpinner.Rotation = dialSpinner.Rotation + 45
  currentCoordNumber = (currentCoordNumber + math.random(1, 50)) % 501
  coordText.Text = "КООРДИНАТЫ: " .. currentCoordNumber
  
  -- Если скин Злого Морти — крутилка меняет PlaceId для портала!
  if currentSkin == "EvilMorty" then
    targetPlaceId = 155615604 -- Пример Place ID для перенаправления
  end
end)

-- КНОПКА 3: Shift Lock
local btnShiftLock = Instance.new("TextButton", btnContainer)
btnShiftLock.Position = UDim2.new(0, 0, 0, 110)
styleButton(btnShiftLock, "🔒 SHIFT LOCK: ВЫКЛ", Color3.fromRGB(180, 40, 40))

local slActive = false
btnShiftLock.MouseButton1Click:Connect(function()
  slActive = not slActive
  LocalPlayer.DevEnableMouseLock = slActive
  btnShiftLock.Text = slActive and "🔒 SHIFT LOCK: ВКЛ" or "🔒 SHIFT LOCK: ВЫКЛ"
  btnShiftLock.BackgroundColor3 = slActive and Color3.fromRGB(40, 180, 80) or Color3.fromRGB(180, 40, 40)
end)

-- КНОПКА 4: Скины
local btnSkins = Instance.new("TextButton", btnContainer)
btnSkins.Position = UDim2.new(0, 0, 0, 165)
styleButton(btnSkins, "🎨 СКИН: СТАНДАРТ", Color3.fromRGB(120, 50, 200))

local skinList = {"Default", "EvilMorty", "RickPrime", "Kids"}
local skinIndex = 1
btnSkins.MouseButton1Click:Connect(function()
  skinIndex = (skinIndex % #skinList) + 1
  currentSkin = skinList[skinIndex]
  btnSkins.Text = "🎨 СКИН: " .. currentSkin:upper()
  
  -- Пересоздаем модель пушки с выбранным скином
  if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("PortalGun") then
    LocalPlayer.Character.PortalGun:Destroy()
  end
  createPortalGunModel()
end)-----------------------------------------------------------
-- 4. СОЗДАНИЕ СТРЕЛКИ-УКАЗАТЕЛЯ
-----------------------------------------------------------
local arrowBillboard = Instance.new("BillboardGui")
arrowBillboard.Size = UDim2.new(0, 50, 0, 50)
arrowBillboard.AlwaysOnTop = true
arrowBillboard.Enabled = false

local arrowImage = Instance.new("TextLabel", arrowBillboard)
arrowImage.Size = UDim2.new(1, 0, 1, 0)
arrowImage.BackgroundTransparency = 1
arrowImage.Text = "⬇️"
arrowImage.TextSize = 35

-----------------------------------------------------------
-- 5. МАКСИМУМ 2 ПОРТАЛА + ВОРОНКИ + МЕЖПЛЕЙС
-----------------------------------------------------------
local portalSlot = 1

local function spawnPortalSystem()
  local char = LocalPlayer.Character
  if not char or not char:FindFirstChild("PortalGun") then return end

  local hitPos = Mouse.Hit
  if not Mouse.Target then return end

  -- Воспроизводим звук на пушке
  local gun = char.PortalGun
  if gun:FindFirstChild("Handle") and gun.Handle:FindFirstChild("PortalSound") then
    gun.Handle.PortalSound:Play()
  end

  -- Если выстрелили 3-й раз — удаляем самый старый (строго не больше 2 порталов)
  if activePortals[portalSlot] then
    activePortals[portalSlot]:Destroy()
  end

  -- Цвет портала и воронки в зависимости от скина
  local pColor = Color3.fromRGB(0, 255, 100) -- Стандартный ярко-зеленый
  local vColor = Color3.fromRGB(0, 70, 20)   -- Тёмно-зеленая воронка
  
  if currentSkin == "EvilMorty" then
    pColor = Color3.fromRGB(255, 215, 0) -- Золотой
    vColor = Color3.fromRGB(150, 100, 0) -- Тёмно-золотая воронка
  end

  -- Физическая деталь портала
  local portal = Instance.new("Part")
  portal.Name = "GlobalPhysicsPortal"
  portal.Shape = Enum.PartType.Cylinder
  portal.Size = Vector3.new(0.3, 8, 5)
  portal.Color = pColor
  portal.Material = Enum.Material.Neon
  portal.Anchored = true
  portal.CanCollide = false
  
  -- Воронка
  local att = Instance.new("Attachment", portal)
  local pe = Instance.new("ParticleEmitter", att)
  pe.Texture = "rbxassetid://243660364"
  pe.Color = ColorSequence.new(vColor)
  pe.Rate = 50
  pe.Lifetime = NumberRange.new(0.4, 0.8)
  pe.Speed = NumberRange.new(0)
  pe.RotSpeed = NumberRange.new(200, 400)
  pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4.5), NumberSequenceKeypoint.new(1, 0)})

  -- Ориентация на стенах и полу
  local norm = Mouse.TargetSurface
  local normVec = Vector3.FromNormalId(norm)
  portal.CFrame = CFrame.new(hitPos.Position, hitPos.Position + normVec) * CFrame.Angles(0, math.rad(90), 0)
  portal.Parent = workspace

  activePortals[portalSlot] = portal

  -- Указатель-стрелка над свежим порталом
  arrowBillboard.Adornee = portal
  arrowBillboard.Parent = portal
  arrowBillboard.Enabled = true

  -- Переключение слота (1 -> 2 -> 1)
  portalSlot = (portalSlot == 1) and 2 or 1
end

-- Стреляем при клике по кнопке 1 или ЛКМ на ПК
btnShoot.MouseButton1Click:Connect(spawnPortalSystem)

-----------------------------------------------------------
-- 6. ВСЕМ МОЖНО ТЕЛЕПОРТИРОВАТЬСЯ (ИГРОКИ И NPC)
-----------------------------------------------------------
local teleportCooldowns = {}

RunService.Heartbeat:Connect(function()
  if not activePortals[1] or not activePortals[2] then return end
  
  local p1 = activePortals[1]
  local p2 = activePortals[2]

  -- Сканируем ВСЕХ персонажей в игре (не только текущего игрока)
  for _, obj in pairs(workspace:GetChildren()) do
    local hrp = obj:FindFirstChild("HumanoidRootPart")
    local hum = obj:FindFirstChildOfClass("Humanoid")-- Помести этот скрипт в ServerScriptService (Script)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = ReplicatedStorage:WaitForChild("SpawnPortalEvent")

local playerPortals = {} -- Хранилище активных порталов для каждого игрока

remoteEvent.OnServerEvent:Connect(function(player, portalType, position)
  if not playerPortals[player.UserId] then
    playerPortals[player.UserId] = {PortalA = nil, PortalB = nil}
  end
  
  local pData = playerPortals[player.UserId]
  
  -- Удаляем старый портал этого же типа, если он есть
  if pData[portalType] and pData[portalType].Parent then
    pData[portalType]:Destroy()
  end
  
  -- Создание нового портала
  local portal = Instance.new("Part")
  portal.Name = portalType .. "_" .. player.Name
  portal.Size = Vector3.new(4, 6, 1)
  portal.Position = position
  portal.Anchored = true
  portal.CanCollide = false
  portal.Transparency = 0.3
  portal.Material = Enum.Material.Neon
  portal.Color = (portalType == "PortalA") and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(255, 170, 0)
  portal.Parent = workspace
  
  -- ВАЖНО: Мы НЕ добавляем Debris/task.delay для удаления через 10 секунд.
  -- Портал будет висеть бесконечно, пока не создашь новый той же кнопки!
  
  pData[portalType] = portal
  
  -- Логика телепортации при контакте с порталом
  portal.Touched:Connect(function(hit)
    local character = hit.Parent
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if humanoid and hrp and not hrp:GetAttribute("Teleporting") then
      local targetPortal = (portalType == "PortalA") and pData.PortalB or pData.PortalA
      
      if targetPortal and targetPortal.Parent then
        hrp:SetAttribute("Teleporting", true)
        -- Позиционируем игрока немного впереди целевого портала
        hrp.CFrame = targetPortal.CFrame * CFrame.new(0, 0, -3)
        
        task.wait(0.5) -- Задержка, чтобы не телепортировало бесконечно туда-обратно
        hrp:SetAttribute("Teleporting", nil)
      end
    end
  end)
end)-- Помести этот скрипт в ServerScriptService (Script)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = ReplicatedStorage:WaitForChild("SpawnPortalEvent")

local playerPortals = {} -- Хранилище активных порталов для каждого игрока

remoteEvent.OnServerEvent:Connect(function(player, portalType, position)
  if not playerPortals[player.UserId] then
    playerPortals[player.UserId] = {PortalA = nil, PortalB = nil}
  end
  
  local pData = playerPortals[player.UserId]
  
  -- Удаляем старый портал этого же типа, если он есть
  if pData[portalType] and pData[portalType].Parent then
    pData[portalType]:Destroy()
  end
  
  -- Создание нового портала
  local portal = Instance.new("Part")
  portal.Name = portalType .. "_" .. player.Name
  portal.Size = Vector3.new(4, 6, 1)
  portal.Position = position
  portal.Anchored = true
  portal.CanCollide = false
  portal.Transparency = 0.3
  portal.Material = Enum.Material.Neon
  portal.Color = (portalType == "PortalA") and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(255, 170, 0)
  portal.Parent = workspace
  
  -- ВАЖНО: Мы НЕ добавляем Debris/task.delay для удаления через 10 секунд.
  -- Портал будет висеть бесконечно, пока не создашь новый той же кнопки!
  
  pData[portalType] = portal
  
  -- Логика телепортации при контакте с порталом
  portal.Touched:Connect(function(hit)
    local character = hit.Parent
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if humanoid and hrp and not hrp:GetAttribute("Teleporting") then
      local targetPortal = (portalType == "PortalA") and pData.PortalB or pData.PortalA
      
      if targetPortal and targetPortal.Parent then
        hrp:SetAttribute("Teleporting", true)
        -- Позиционируем игрока немного впереди целевого портала
        hrp.CFrame = targetPortal.CFrame * CFrame.new(0, 0, -3)
        
        task.wait(0.5) -- Задержка, чтобы не телепортировало бесконечно туда-обратно
        hrp:SetAttribute("Teleporting", nil)
      end
    end
  end)
end)
