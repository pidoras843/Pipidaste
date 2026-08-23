local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("BootsRemote")

local active = false
local wearing = false
local connection

local function getCharacter()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	return character, humanoid, root
end

-- Ищем пол, стену или потолок
local function findSurface(character, root)
	local directions = {
		Vector3.new(0, -1, 0),
		Vector3.new(0, 1, 0),
		root.CFrame.RightVector,
		-root.CFrame.RightVector,
		root.CFrame.LookVector,
		-root.CFrame.LookVector,
	}

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local closest
	local distance = 5

	for _, direction in ipairs(directions) do
		local result = workspace:Raycast(
			root.Position,
			direction * distance,
			params
		)

		if result and result.Distance < distance then
			closest = result
			distance = result.Distance
		end
	end

	return closest
end

local function stopGravity()
	active = false

	if connection then
		connection:Disconnect()
		connection = nil
	end

	local character, humanoid, root = getCharacter()
	if not root then return end

	local force = root:FindFirstChild("BootGravity")
	local attachment = root:FindFirstChild("BootAttachment")

	if force then force:Destroy() end
	if attachment then attachment:Destroy() end
end

local function startGravity()
	if active then return end
	if not wearing then return end

	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root then return end

	local firstSurface = findSurface(character, root)

	-- В воздухе ботинки не работают
	if not firstSurface then
		return
	end

	active = true

	local attachment = Instance.new("Attachment")
	attachment.Name = "BootAttachment"
	attachment.Parent = root

	local force = Instance.new("VectorForce")
	force.Name = "BootGravity"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Parent = root

	connection = RunService.RenderStepped:Connect(function()
		if not active then return end

		local surface = findSurface(character, root)

		-- Нет стены/пола/потолка = выключаем
		if not surface then
			stopGravity()
			return
		end

		local normal = surface.Normal
		local mass = root.AssemblyMass

		-- Притягиваем игрока к поверхности
		force.Force = -normal * workspace.Gravity * mass * 2

		-- Разворачиваем персонажа ногами к поверхности
		local forward = root.CFrame.LookVector

		-- Убираем компонент, направленный в поверхность
		forward = forward - normal * forward:Dot(normal)

		if forward.Magnitude > 0.1 then
			forward = forward.Unit

			local right = forward:Cross(normal).Unit
			local newForward = normal:Cross(right).Unit

			root.CFrame = CFrame.lookAt(
				root.Position,
				root.Position + newForward,
				normal
			)
		end
	end)
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- Q включает/выключает антигравитацию
	if input.KeyCode == Enum.KeyCode.Q then
		if not wearing then return end

		if active then
			stopGravity()
		else
			startGravity()
		end
	end
end)

-- Нажатие предмета
local function setupTool(tool)
	if tool.Name ~= "Boots" then return end

	tool.Activated:Connect(function()
		wearing = not wearing

		if wearing then
			remote:FireServer("Wear")
		else
			stopGravity()
			remote:FireServer("Remove")
		end
	end)

	tool.Unequipped:Connect(function()
		stopGravity()
	end)
end

local function watchContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		setupTool(child)
	end

	container.ChildAdded:Connect(setupTool)
end

watchContainer(player:WaitForChild("Backpack"))

player.CharacterAdded:Connect(function(character)
	stopGravity()
	wearing = false
	watchContainer(character)
end)
