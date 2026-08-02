-- ========================================================
-- DELTA EXECUTOR PORTAL GUN SCRIPT (GREEN RE-DESIGN UPDATE)
-- ========================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-----------------------------------------------------------
-- 1. UI С КРУЖКАМИ, КООРДИНАТАМИ И КНОПКОЙ SHIFT LOCK
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
mainFrame.Size = UDim2.new(0, 260, 0, 180)
mainFrame.Position = UDim2.new(0.05, 0, 0.55, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true

local uiCorner = Instance.new("UICorner", mainFrame)
uiCorner.CornerRadius = UDim.new(0, 12)

local dimText = Instance.new("TextLabel", mainFrame)
dimText.Size = UDim2.new(1, 0, 0.25, 0)
dimText.BackgroundTransparency = 1
dimText.Text = "ИЗМЕРЕНИЕ: " .. getDimensionCode()
dimText.TextColor3 = Color3.fromRGB(0, 255, 127)
dimText.TextSize = 16
dimText.Font = Enum.Font.GothamBold

-- Кружки-вращатели (Без стрелок)
local dialLeft = Instance.new("TextButton", mainFrame)
dialLeft.Size = UDim2.new(0, 50, 0, 50)
dialLeft.Position = UDim2.new(0.12, 0, 0.3, 0)
dialLeft.Text = "🌀"
dialLeft.TextSize = 22
dialLeft.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", dialLeft).CornerRadius = UDim.new(1, 0)

local dialRight = Instance.new("TextButton", mainFrame)
dialRight.Size = UDim2.new(0, 50, 0, 50)
dialRight.Position = UDim2.new(0.68, 0, 0.3, 0)
dialRight.Text = "🌀"
dialRight.TextSize = 22
dialRight.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", dialRight).CornerRadius = UDim.new(1, 0)

local function spinDial(btn)
  btn.Rotation = btn.Rotation + 45
  dimText.Text = "ИЗМЕРЕНИЕ: " .. getDimensionCode()
end

dialLeft.MouseButton1Click:Connect(function() spinDial(dialLeft) end)
dialRight.MouseButton1Click:Connect(function() spinDial(dialRight) end)

-- КНОПКА ОТКЛЮЧЕНИЯ / ВКЛЮЧЕНИЯ SHIFT LOCK
local shiftLockButton = Instance.new("TextButton", mainFrame)
shiftLockButton.Size = UDim2.new(0.8, 0, 0.22, 0)
shiftLockButton.Position = UDim2.new(0.1, 0, 0.7, 0)
shiftLockButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
shiftLockButton.Text = "SHIFT LOCK: ВЫКЛ"
shiftLockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shiftLockButton.Font = Enum.Font.GothamBold
shiftLockButton.TextSize = 13
Instance.new("UICorner", shiftLockButton).CornerRadius = UDim.new(0, 8)

local shiftLockEnabled = false
shiftLockButton.MouseButton1Click:Connect(function()
  shiftLockEnabled = not shiftLockEnabled
  LocalPlayer.DevEnableMouseLock = shiftLockEnabled
  if shiftLockEnabled then
    shiftLockButton.Text = "SHIFT LOCK: ВКЛ"
    shiftLockButton.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
  else
    shiftLockButton.Text = "SHIFT LOCK: ВЫКЛ"
    shiftLockButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
  end
end)

-----------------------------------------------------------
-- 2. СОЗДАНИЕ БЕЛОЙ ПУШКИ С РУКОЯТКОЙ (И СПАВН ПРИ СМЕРТИ)
-----------------------------------------------------------
local function createWhitePortalGun()
  local tool = Instance.new("Tool")
  tool.Name = "WhitePortalGun"
  tool.RequiresHandle = true
  tool.CanBeDropped = false-- Корпус пушки (Белый)
  local handle = Instance.new("Part")
  handle.Name = "Handle"
  handle.Size = Vector3.new(0.8, 1, 2.2)
  handle.Color = Color3.fromRGB(255, 255, 255)
  handle.Material = Enum.Material.SmoothPlastic
  handle.Parent = tool

  -- Штучка для держания (Рукоятка)
  local gripHandle = Instance.new("Part")
  gripHandle.Name = "GripHandle"
  gripHandle.Size = Vector3.new(0.5, 1.2, 0.5)
  gripHandle.Color = Color3.fromRGB(240, 240, 240)
  gripHandle.Material = Enum.Material.SmoothPlastic
  gripHandle.CanCollide = false
  gripHandle.Parent = tool

  local weld = Instance.new("Weld", handle)
  weld.Part0 = handle
  weld.Part1 = gripHandle
  weld.C0 = CFrame.new(0, -0.8, 0.4) * CFrame.Angles(math.rad(-20), 0, 0)

  -- Звук активации
  local sound = Instance.new("Sound", handle)
  sound.Name = "PortalOpenSound"
  sound.SoundId = "rbxassetid://200632875"
  sound.Volume = 1

  -- Выстрел при нажатии (ЛКМ / Тап)
  tool.Activated:Connect(function()
    _G.SpawnGreenPortal(1)
  end)

  tool.Parent = LocalPlayer:WaitForChild("Backpack")
end

-- Автоматическое добавление пушки при каждом спавне
LocalPlayer.CharacterAdded:Connect(function()
  task.wait(0.5)
  createWhitePortalGun()
end)

-- Создаем пушку сразу при запуске
createWhitePortalGun()

-----------------------------------------------------------
-- 3. КРУГЛЫЕ ЗЕЛЕНЫЕ ПОРТАЛЫ С ТЁМНО-ЗЕЛЁНОЙ ВОРОНКОЙ
-----------------------------------------------------------
local activePortals = { [1] = nil, [2] = nil }
local isTeleporting = false

local function createGreenPortalPart()
  local portal = Instance.new("Part")
  portal.Name = "DeltaGreenPortal"
  portal.Shape = Enum.PartType.Cylinder
  portal.Size = Vector3.new(0.3, 7.5, 5) -- Круглый и чуть удлиненный
  portal.Color = Color3.fromRGB(0, 255, 100) -- Ярко-зелёный
  portal.Material = Enum.Material.Neon
  portal.Anchored = true
  portal.CanCollide = false
  
  -- Визуал тёмно-зелёной воронки
  local att = Instance.new("Attachment", portal)
  local particles = Instance.new("ParticleEmitter", att)
  particles.Texture = "rbxassetid://243660364"
  particles.Color = ColorSequence.new(Color3.fromRGB(0, 80, 20)) -- Тёмно-зелёный цвет воронки
  particles.Rate = 50
  particles.Lifetime = NumberRange.new(0.4, 0.8)
  particles.Speed = NumberRange.new(0)
  particles.RotSpeed = NumberRange.new(250, 450)
  particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4.5), NumberSequenceKeypoint.new(1, 0)})

  return portal
end

_G.SpawnGreenPortal = function(portalType)
  -- БЕЗ БЕЛОЙ ПУШКИ В РУКАХ ПОРТАЛ НЕ РАБОТАЕТ!
  local char = LocalPlayer.Character
  if not char or not char:FindFirstChild("WhitePortalGun") then return end

  local targetPos = Mouse.Hit
  local targetPart = Mouse.Target
  if not targetPart then return end

  -- Воспроизводим звук пушки
  local tool = char:FindFirstChild("WhitePortalGun")
  if tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("PortalOpenSound") then
    tool.Handle.PortalOpenSound:Play()
  end

  -- Удаляем прошлый портал этого типа
  if activePortals[portalType] then
    activePortals[portalType]:Destroy()
  end

  -- Спавн нового зелёного портала
  local newPortal = createGreenPortalPart()
  
  -- Ориентация на стене или полу
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

-- ПКМ для создания второго зелёного портала
UserInputService.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if input.UserInputType == Enum.UserInputType.MouseButton2 then
    _G.SpawnGreenPortal(2)
  end
end)-----------------------------------------------------------
-- 4. ТЕЛЕПОРТАЦИЯ ДЛЯ ВСЕХ УСТРОЙСТВ (ПОДОШЕЛ -> ТЕЛЕПОРТ)
-----------------------------------------------------------
RunService.Heartbeat:Connect(function()
  local char = LocalPlayer.Character
  local hrp = char and char:FindFirstChild("HumanoidRootPart")
  if not hrp or isTeleporting then return end

  for pType, portal in pairs(activePortals) do
    if portal and portal.Parent then
      local dist = (hrp.Position - portal.Position).Magnitude
      if dist <= 3.5 then -- Нужно подойти близко
        local otherType = (pType == 1) and 2 or 1
        local destPortal = activePortals[otherType]

        if destPortal and destPortal.Parent then
          isTeleporting = true
          
          -- Выталкиваем немного вперед, чтобы не дотрагиваться сразу
          local exitOffset = destPortal.CFrame * CFrame.new(0, 0, -4)
          hrp.CFrame = CFrame.new(exitOffset.Position, exitOffset.Position + destPortal.CFrame.LookVector)

          task.wait(1.2) -- Кулдаун для возможности шага назад
          isTeleporting = false
        end
      end
    end
  end
end)
