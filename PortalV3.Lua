-- ========================================================
-- DELTA EXECUTOR PORTAL GUN SCRIPT
-- ========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-----------------------------------------------------------
-- 1. ОТКЛЮЧЕНИЕ SHIFT LOCK И НАСТРОЙКА ИГРОКА
-----------------------------------------------------------
LocalPlayer.DevEnableMouseLock = false

-----------------------------------------------------------
-- 2. СОЗДАНИЕ UI (БЕЗ СТРЕЛОК, ТОЛЬКО КРУЖКИ-КРУТИЛКИ)
-----------------------------------------------------------
local letters = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}

local function getDimensionCode()
  return string.format("%d-%s", math.random(0, 999), letters[math.random(1, #letters)])
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaPortalUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 260, 0, 140)
mainFrame.Position = UDim2.new(0.05, 0, 0.65, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true -- Можно двигать пальцем/мышкой

local uiCorner = Instance.new("UICorner", mainFrame)
uiCorner.CornerRadius = UDim.new(0, 12)

local dimText = Instance.new("TextLabel", mainFrame)
dimText.Size = UDim2.new(1, 0, 0.35, 0)
dimText.BackgroundTransparency = 1
dimText.Text = "ИЗМЕРЕНИЕ: " .. getDimensionCode()
dimText.TextColor3 = Color3.fromRGB(0, 255, 170)
dimText.TextSize = 16
dimText.Font = Enum.Font.GothamBold

-- Кружки-вращатели (Дрифт/Координаты без стрелок)
local dialLeft = Instance.new("TextButton", mainFrame)
dialLeft.Size = UDim2.new(0, 60, 0, 60)
dialLeft.Position = UDim2.new(0.12, 0, 0.45, 0)
dialLeft.Text = "🌀"
dialLeft.TextSize = 25
dialLeft.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", dialLeft).CornerRadius = UDim.new(1, 0)

local dialRight = Instance.new("TextButton", mainFrame)
dialRight.Size = UDim2.new(0, 60, 0, 60)
dialRight.Position = UDim2.new(0.65, 0, 0.45, 0)
dialRight.Text = "🌀"
dialRight.TextSize = 25
dialRight.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", dialRight).CornerRadius = UDim.new(1, 0)

local function spinDial(btn)
  btn.Rotation = btn.Rotation + 45
  dimText.Text = "ИЗМЕРЕНИЕ: " .. getDimensionCode()
end

dialLeft.MouseButton1Click:Connect(function() spinDial(dialLeft) end)
dialRight.MouseButton1Click:Connect(function() spinDial(dialRight) end)

-----------------------------------------------------------
-- 3. СОЗДАНИЕ БЕЛОЙ ПОРТАЛЬНОЙ ПУШКИ
-----------------------------------------------------------
local tool = Instance.new("Tool")
tool.Name = "WhitePortalGun"
tool.RequiresHandle = true
tool.CanBeDropped = false

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(1, 1.2, 2.5)
handle.Color = Color3.fromRGB(255, 255, 255) -- Белая пушка
handle.Material = Enum.Material.SmoothPlastic
handle.Parent = tool

-- Звук открытия портала
local sound = Instance.new("Sound", handle)
sound.Name = "PortalOpenSound"
sound.SoundId = "rbxassetid://200632875" -- Звук портала
sound.Volume = 1

tool.Parent = LocalPlayer:WaitForChild("Backpack")

-----------------------------------------------------------
-- 4. ЛОГИКА И СОЗДАНИЕ ПОРТАЛОВ (5 СЕКУНД, ВОРОНКА, ВЫХОД)
-----------------------------------------------------------
local activePortals = { [1] = nil, [2] = nil }
local isTeleporting = falselocal function createPortalPart(color)
  local portal = Instance.new("Part")
  portal.Name = "DeltaPortal"
  portal.Shape = Enum.PartType.Cylinder
  portal.Size = Vector3.new(0.3, 8, 5) -- Круглый и немного длиннее
  portal.Color = color
  portal.Material = Enum.Material.Neon
  portal.Anchored = true
  portal.CanCollide = false
  
  -- Визуал воронки внутри
  local att = Instance.new("Attachment", portal)
  local particles = Instance.new("ParticleEmitter", att)
  particles.Texture = "rbxassetid://243660364" -- Текстура воронки
  particles.Rate = 40
  particles.Lifetime = NumberRange.new(0.4, 0.8)
  particles.Speed = NumberRange.new(0)
  particles.RotSpeed = NumberRange.new(200, 400)
  particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0)})

  return portal
end

local function spawnPortal(portalType)
  -- Проверка: БЕЗ ПУШКИ В РУКАХ ПОРТАЛЫ НЕ РАБОТАЮТ!
  local char = LocalPlayer.Character
  if not char or not char:FindFirstChild("WhitePortalGun") then return end

  local targetPos = Mouse.Hit
  local targetPart = Mouse.Target
  if not targetPart then return end

  -- Воспроизводим звук
  sound:Play()

  -- Удаляем прошлый портал этого типа
  if activePortals[portalType] then
    activePortals[portalType]:Destroy()
  end

  -- Создаем новый портал на стене или полу
  local color = (portalType == 1) and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(255, 170, 0)
  local newPortal = createPortalPart(color)
  
  -- Выравнивание на поверхности (пол / стена)
  local normal = Mouse.TargetSurface
  local normalVec = Vector3.FromNormalId(normal)
  newPortal.CFrame = CFrame.new(targetPos.Position, targetPos.Position + normalVec) * CFrame.Angles(0, math.rad(90), 0)
  newPortal.Parent = workspace
  
  activePortals[portalType] = newPortal

  -- Удаление ровно через 5 секунд
  task.delay(5, function()
    if newPortal and newPortal.Parent then
      newPortal:Destroy()
      if activePortals[portalType] == newPortal then
        activePortals[portalType] = nil
      end
    end
  end)
end

-- Обработка выстрелов (Подходит для PC, Mobile, Tablet, VR)
tool.Activated:Connect(function()
  spawnPortal(1) -- Левая кнопка / Тап по экрану = Портал 1
end)

UserInputService.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if input.UserInputType == Enum.UserInputType.MouseButton2 then
    spawnPortal(2) -- ПКМ = Портал 2
  end
end)

-----------------------------------------------------------
-- 5. КРОСС-ПЛАТФОРМЕННАЯ ФИЗИЧЕСКАЯ ТЕЛЕПОРТАЦИЯ
-----------------------------------------------------------
RunService.Heartbeat:Connect(function()
  local char = LocalPlayer.Character
  local hrp = char and char:FindFirstChild("HumanoidRootPart")
  if not hrp or isTeleporting then return end

  for pType, portal in pairs(activePortals) do
    if portal and portal.Parent then
      -- Игрок телепортируется только если подошел БЛИЗКО к воронке
      local dist = (hrp.Position - portal.Position).Magnitude
      if dist <= 3.5 then
        local otherType = (pType == 1) and 2 or 1
        local destPortal = activePortals[otherType]

        if destPortal and destPortal.Parent then
          isTeleporting = true
          
          -- Ставим персонажа чуть-чуть ДАЛЬШЕ выходящего портала (чтобы не дотрагивался сразу)
          local exitOffset = destPortal.CFrame * CFrame.new(0, 0, -4)
          hrp.CFrame = CFrame.new(exitOffset.Position, exitOffset.Position + destPortal.CFrame.LookVector)

          -- Задержка перед тем, как можно зайти обратно
          task.wait(1.2)
          isTeleporting = false
        end
      end
    end
  end
end)
