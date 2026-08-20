--[[
	FREEZE SHOKER — ВСЁ В ОДНОМ СКРИПТЕ
	=====================================
	Вставь этот скрипт в ServerScriptService.
	При запуске игры он:
	  1) Строит модель предмета "Freeze Shoker" (форма, цвета, хват).
	  2) Подключает логику заморозки прямо тут же (не нужен
	     отдельный дочерний Script внутри Tool).
	  3) Сразу выдаёт предмет всем игрокам, которые уже в игре,
	     и каждому новому игроку при входе / респавне.
 
	Просто запусти игру — предмет появится в инвентаре (Backpack)
	сразу, без лишних действий.
]]
 
local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
 
local TOOL_NAME = "Freeze Shoker"
local FROZEN_COLOR = Color3.fromRGB(173, 216, 230) -- светло-голубой
local RANGE = 60
local COOLDOWN = 0.6
 
----------------------------------------------------------------
-- СОЗДАНИЕ МОДЕЛИ ПРЕДМЕТА
----------------------------------------------------------------
local function buildTool()
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = true
 
	-- Хват в руке: по диагонали вверх и вправо
	tool.GripPos = Vector3.new(0, -0.2, 0)
	tool.GripForward = Vector3.new(-0.55, -0.6, -0.58).Unit
	tool.GripRight   = Vector3.new(0.8, -0.2, -0.55).Unit
	tool.GripUp      = Vector3.new(0.25, 0.85, -0.45).Unit
 
	-- Основной корпус: продолговатый цилиндр, тёмно-серый/чёрный
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(2.6, 0.55, 0.55)
	handle.Color = Color3.fromRGB(32, 32, 36)
	handle.Material = Enum.Material.Metal
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
 
	-- Наконечник: светло-серый металлик + свечение
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Cylinder
	tip.Size = Vector3.new(0.35, 0.66, 0.66)
	tip.Color = Color3.fromRGB(185, 187, 192)
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
 
	-- Соединительные кольца: светло-серые металлические
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
 
	-- Задняя часть рукояти (потемнее, для хвата)
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
 
	return tool, handle
end
 
----------------------------------------------------------------
-- ЛОГИКА ЗАМОРОЗКИ
----------------------------------------------------------------
local function freezeCharacter(character)
	if character:GetAttribute("Frozen") then
		return
	end
 
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
 
	character:SetAttribute("Frozen", true)
 
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
	humanoid.PlatformStand = true
 
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.Color = FROZEN_COLOR
		end
	end
end
 
local function attachBehavior(tool, handle)
	local busy = false
 
	tool.Activated:Connect(function()
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
	end)
end
 
----------------------------------------------------------------
-- ВЫДАЧА ПРЕДМЕТА ИГРОКАМ
----------------------------------------------------------------
local function giveTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
	if backpack:FindFirstChild(TOOL_NAME) then
		return
	end
 
	local tool, handle = buildTool()
	attachBehavior(tool, handle)
	tool.Parent = backpack
end
 
-- Шаблон в StarterPack — чтобы предмет выдавался и при возрождении
local existingTemplate = StarterPack:FindFirstChild(TOOL_NAME)
if existingTemplate then
	existingTemplate:Destroy()
end
do
	local templateTool, templateHandle = buildTool()
	attachBehavior(templateTool, templateHandle)
	templateTool.Parent = StarterPack
end
 
-- Немедленная выдача всем, кто уже в игре
for _, player in ipairs(Players:GetPlayers()) do
	giveTool(player)
end
 
-- Выдача каждому новому игроку сразу при входе
Players.PlayerAdded:Connect(function(player)
	giveTool(player)
end)
 
print(TOOL_NAME .. " готов и выдан игрокам.")
 
