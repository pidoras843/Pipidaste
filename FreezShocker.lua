--[[
	FREEZE WAND — СБОРКА МОДЕЛИ ПРЕДМЕТА
	=====================================
	Вставь этот скрипт в ServerScriptService (или запусти один раз
	через командную строку Studio) — он создаст готовый Tool
	("Морозный жезл") и положит его в StarterPack, чтобы предмет
	появился у каждого игрока при спавне.

	После создания модели ОБЯЗАТЕЛЬНО добавь внутрь получившегося
	Tool обычный Script и вставь туда код из файла
	freeze_wand_behavior.lua — это логика заморозки.
]]

local StarterPack = game:GetService("StarterPack")

-- Удаляем старую версию, если она уже есть
local old = StarterPack:FindFirstChild("Морозный жезл")
if old then old:Destroy() end

----------------------------------------------------------------
-- ОСНОВНОЙ Tool
----------------------------------------------------------------
local tool = Instance.new("Tool")
tool.Name = "Морозный жезл"
tool.RequiresHandle = true
tool.CanBeDropped = true

-- Хват в руке: по диагонали вверх и вправо
tool.GripPos = Vector3.new(0, -0.2, 0)
tool.GripForward = Vector3.new(-0.55, -0.6, -0.58).Unit
tool.GripRight   = Vector3.new(0.8, -0.2, -0.55).Unit
tool.GripUp      = Vector3.new(0.25, 0.85, -0.45).Unit

----------------------------------------------------------------
-- HANDLE — основной продолговатый цилиндрический корпус
----------------------------------------------------------------
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Shape = Enum.PartType.Cylinder
handle.Size = Vector3.new(2.6, 0.55, 0.55) -- длинная ось = X
handle.Color = Color3.fromRGB(32, 32, 36)   -- тёмно-серый/чёрный
handle.Material = Enum.Material.Metal
handle.TopSurface = Enum.SurfaceType.Smooth
handle.BottomSurface = Enum.SurfaceType.Smooth
handle.CanCollide = false
handle.Massless = true
handle.Parent = tool

----------------------------------------------------------------
-- НАКОНЕЧНИК (светлее, металлик, с лёгким свечением)
----------------------------------------------------------------
local tip = Instance.new("Part")
tip.Name = "Tip"
tip.Shape = Enum.PartType.Cylinder
tip.Size = Vector3.new(0.35, 0.66, 0.66)
tip.Color = Color3.fromRGB(185, 187, 192) -- светло-серый металлик
tip.Material = Enum.Material.Metal
tip.CanCollide = false
tip.Massless = true
tip.CFrame = handle.CFrame * CFrame.new(1.45, 0, 0)
tip.Parent = tool

local tipWeld = Instance.new("WeldConstraint")
tipWeld.Part0 = handle
tipWeld.Part1 = tip
tipWeld.Parent = handle

local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(150, 220, 255)
glow.Range = 8
glow.Brightness = 1.5
glow.Parent = tip

----------------------------------------------------------------
-- СОЕДИНИТЕЛЬНЫЕ КОЛЬЦА (светло-серые металлические полосы)
----------------------------------------------------------------
local ringOffsets = {-1.0, -0.35, 0.35, 1.05}
for i, offset in ipairs(ringOffsets) do
	local ring = Instance.new("Part")
	ring.Name = "Ring" .. i
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, 0.68, 0.68)
	ring.Color = Color3.fromRGB(195, 197, 200)
	ring.Material = Enum.Material.Metal
	ring.CanCollide = false
	ring.Massless = true
	ring.CFrame = handle.CFrame * CFrame.new(offset, 0, 0)
	ring.Parent = tool

	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = ring
	w.Parent = handle
end

----------------------------------------------------------------
-- РУКОЯТЬ ХВАТА (задняя часть, чуть темнее и толще для хвата)
----------------------------------------------------------------
local grip = Instance.new("Part")
grip.Name = "GripSection"
grip.Shape = Enum.PartType.Cylinder
grip.Size = Vector3.new(0.9, 0.62, 0.62)
grip.Color = Color3.fromRGB(20, 20, 22)
grip.Material = Enum.Material.Metal
grip.CanCollide = false
grip.Massless = true
grip.CFrame = handle.CFrame * CFrame.new(-1.55, 0, 0)
grip.Parent = tool

local gripWeld = Instance.new("WeldConstraint")
gripWeld.Part0 = handle
gripWeld.Part1 = grip
gripWeld.Parent = handle

tool.Parent = StarterPack

print("Готово: 'Морозный жезл' создан в StarterPack.")
--[[
	FREEZE WAND — ПОВЕДЕНИЕ (ЭФФЕКТ ЗАМОРОЗКИ)
	=============================================
	Это обычный Script (НЕ LocalScript).
	Помести его ВНУТРЬ Tool "Морозный жезл" (тот, что создаёт
	freeze_wand_builder.lua). Он выполняется на сервере и слушает
	событие Activated (клик ЛКМ / нажатие тачскрина при
	экипированном предмете).

	Эффект: цель НЕ превращается в кубик льда — она просто
	окрашивается в светло-голубой цвет и полностью замирает
	в той позе, в которой была застигнута (анимации
	останавливаются, части тела закрепляются).
]]

local tool = script.Parent
local handle = tool:WaitForChild("Handle")

local FROZEN_COLOR = Color3.fromRGB(173, 216, 230) -- светло-голубой
local RANGE = 60
local COOLDOWN = 0.6

local busy = false

local function freezeCharacter(character)
	if character:GetAttribute("Frozen") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	character:SetAttribute("Frozen", true)

	-- Останавливаем текущие анимации, чтобы поза застыла как есть
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true -- отключает стейт-машину (idle/walk и т.п.)

	-- Полностью фиксируем скелет в текущем положении
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.Color = FROZEN_COLOR
		end
	end
end

local function onActivated()
	if busy then
		return
	end
	busy = true

	local character = tool.Parent
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if rootPart then
		local origin = handle.Position
		local direction = rootPart.CFrame.LookVector * RANGE

		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = Enum.RaycastFilterType.Exclude

		local result = workspace:Raycast(origin, direction, params)
		if result and result.Instance then
			local targetModel = result.Instance:FindFirstAncestorOfClass("Model")
			if targetModel and targetModel:FindFirstChildOfClass("Humanoid") then
				freezeCharacter(targetModel)
			end
		end
	end

	task.wait(COOLDOWN)
	busy = false
end

tool.Activated:Connect(onActivated)
