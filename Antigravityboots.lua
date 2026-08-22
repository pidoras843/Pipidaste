--[[
	AntiGravityBoots — один обычный Script (не LocalScript, не разделено на сервер/клиент).
	Поместить в ServerScriptService (или прямо в Workspace) — при запуске игры
	сразу появится предмет "anti gravity boots".

	Как пользоваться:
	1) Клик по ботинкам "anti gravity boots" — надеть/снять (приваривается к ногам).
	2) Клик по серой кнопке (работает только если ботинки надеты) — включить/выключить
	   режим. Кнопка станет синей и засветится.
	3) Пока режим включён — можно ходить по полу, стенам и потолку (кроме воздуха).
	4) При смерти/респауне ботинки и режим сбрасываются, сам предмет остаётся в мире —
	   нужно снова надеть и включить.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ===================== СОЗДАНИЕ ПРЕДМЕТА =====================

local bootsModel = Instance.new("Model")
bootsModel.Name = "anti gravity boots"
bootsModel.Parent = Workspace

local BASE_CFRAME = CFrame.new(0, 5, 0) -- где предмет появляется, поправьте под свою карту

local function makeBootPart(name, offset, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = BASE_CFRAME * CFrame.new(offset)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(140, 180, 190)
	part.Parent = bootsModel
	return part
end

local bootLeft = makeBootPart("BootLeft", Vector3.new(-0.9, 0, 0), Vector3.new(1.2, 1.4, 2.2))
local bootRight = makeBootPart("BootRight", Vector3.new(0.9, 0, 0), Vector3.new(1.2, 1.4, 2.2))
bootsModel.PrimaryPart = bootLeft

local strap = Instance.new("Part")
strap.Name = "Strap"
strap.Size = Vector3.new(2.6, 0.6, 0.5)
strap.CFrame = BASE_CFRAME * CFrame.new(0, 0.5, -0.6)
strap.Anchored = true
strap.CanCollide = false
strap.Material = Enum.Material.SmoothPlastic
strap.Color = Color3.fromRGB(230, 110, 40)
strap.Parent = bootsModel

local buttons = {}
for i = 1, 2 do
	local btn = Instance.new("Part")
	btn.Name = "Button" .. i
	btn.Shape = Enum.PartType.Cylinder
	btn.Size = Vector3.new(0.3, 0.5, 0.5)
	btn.CFrame = BASE_CFRAME * CFrame.new(-0.5 + (i - 1), 0.5, -0.6) * CFrame.Angles(0, 0, math.rad(90))
	btn.Anchored = true
	btn.CanCollide = false
	btn.Material = Enum.Material.SmoothPlastic
	btn.Color = Color3.fromRGB(120, 120, 120) -- серый = выключено
	btn.Parent = strap
	buttons[i] = btn
end

local function updateButtonsVisual(anyOn)
	for _, btn in ipairs(buttons) do
		if anyOn then
			btn.Color = Color3.fromRGB(60, 140, 255)
			btn.Material = Enum.Material.Neon
		else
			btn.Color = Color3.fromRGB(120, 120, 120)
			btn.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- ===================== СОСТОЯНИЕ ИГРОКОВ =====================

local STICK_RANGE = 6
local WALK_SPEED = 16

local playerData = {} -- [player] = {hasBoots, antiGravOn, wornVisuals, forces={attachment,alignPos,alignOri}, currentNormal}

local function getData(player)
	local d = playerData[player]
	if not d then
		d = {hasBoots = false, antiGravOn = false, wornVisuals = {}, forces = {}, currentNormal = Vector3.new(0, 1, 0)}
		playerData[player] = d
	end
	return d
end

local function removeWornVisual(player)
	local d = getData(player)
	if d.wornVisuals.leftClone then d.wornVisuals.leftClone:Destroy() end
	if d.wornVisuals.rightClone then d.wornVisuals.rightClone:Destroy() end
	d.wornVisuals = {}
end

local function equipBootsVisual(player)
	local character = player.Character
	if not character then return end
	local leftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
	local rightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
	if not (leftFoot and rightFoot) then return end

	removeWornVisual(player)
	local d = getData(player)

	local leftClone = bootLeft:Clone()
	leftClone.Anchored = false
	leftClone.CanCollide = false
	leftClone.Parent = character
	local weldL = Instance.new("WeldConstraint")
	weldL.Part0 = leftClone
	weldL.Part1 = leftFoot
	weldL.Parent = leftClone
	leftClone.CFrame = leftFoot.CFrame

	local rightClone = bootRight:Clone()
	rightClone.Anchored = false
	rightClone.CanCollide = false
	rightClone.Parent = character
	local weldR = Instance.new("WeldConstraint")
	weldR.Part0 = rightClone
	weldR.Part1 = rightFoot
	weldR.Parent = rightClone
	rightClone.CFrame = rightFoot.CFrame

	d.wornVisuals = {leftClone = leftClone, rightClone = rightClone}
end

local function cleanupForces(player)
	local d = getData(player)
	if d.forces.alignOrientation then d.forces.alignOrientation:Destroy() end
	if d.forces.alignPosition then d.forces.alignPosition:Destroy() end
	if d.forces.attachment then d.forces.attachment:Destroy() end
	d.forces = {}
end

local function setupForces(player)
	cleanupForces(player)
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local attachment = Instance.new("Attachment")
	attachment.Parent = rootPart

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.RigidityEnabled = false
	alignOrientation.MaxTorque = 400000
	alignOrientation.Responsiveness = 25
	alignOrientation.Parent = rootPart

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.MaxForce = 40000
	alignPosition.Responsiveness = 20
	alignPosition.Parent = rootPart

	local d = getData(player)
	d.forces = {attachment = attachment, alignOrientation = alignOrientation, alignPosition = alignPosition}
end

local function startAntiGrav(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) then return end

	setupForces(player)
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = WALK_SPEED
end

local function stopAntiGrav(player)
	cleanupForces(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end
	local d = getData(player)
	d.currentNormal = Vector3.new(0, 1, 0)
end

local function broadcastButtons()
	local anyOn = false
	for _, d in pairs(playerData) do
		if d.antiGravOn then
			anyOn = true
			break
		end
	end
	updateButtonsVisual(anyOn)
end

-- ===================== КЛИКИ =====================

local function onBootsClicked(player)
	local d = getData(player)
	if d.hasBoots then
		d.hasBoots = false
		d.antiGravOn = false
		removeWornVisual(player)
		stopAntiGrav(player)
		broadcastButtons()
	else
		d.hasBoots = true
		equipBootsVisual(player)
	end
end

for _, boot in ipairs({bootLeft, bootRight}) do
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 12
	click.Parent = boot
	click.MouseClick:Connect(onBootsClicked)
end

for _, btn in ipairs(buttons) do
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 12
	click.Parent = btn
	click.MouseClick:Connect(function(player)
		local d = getData(player)
		if not d.hasBoots then
			return -- без ботинок кнопка не работает
		end
		d.antiGravOn = not d.antiGravOn
		if d.antiGravOn then
			startAntiGrav(player)
		else
			stopAntiGrav(player)
		end
		broadcastButtons()
	end)
end

-- ===================== ДВИЖЕНИЕ ПО СТЕНАМ/ПОТОЛКУ =====================

local function findSurfaceNormal(character, rootPart, currentNormal)
	local origin = rootPart.Position
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}

	local down = -currentNormal
	local directions = {
		down,
		rootPart.CFrame.LookVector,
		-rootPart.CFrame.LookVector,
		rootPart.CFrame.RightVector,
		-rootPart.CFrame.RightVector,
		-down,
	}

	for _, dir in ipairs(directions) do
		local result = Workspace:Raycast(origin, dir.Unit * STICK_RANGE, rayParams)
		if result then
			return result.Normal, result.Position
		end
	end
	return nil, nil
end

RunService.Heartbeat:Connect(function()
	for player, d in pairs(playerData) do
		if d.antiGravOn and d.hasBoots then
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local forces = d.forces

			if character and rootPart and humanoid and forces.alignPosition and humanoid.Health > 0 then
				local normal, hitPos = findSurfaceNormal(character, rootPart, d.currentNormal)

				if normal then
					d.currentNormal = normal
					humanoid.PlatformStand = false

					local desiredPos = hitPos + normal * 3
					forces.alignPosition.Position = desiredPos

					local look = rootPart.CFrame.LookVector
					local flatLook = look - look:Dot(normal) * normal
					if flatLook.Magnitude < 0.01 then
						flatLook = rootPart.CFrame.RightVector - rootPart.CFrame.RightVector:Dot(normal) * normal
					end
					flatLook = flatLook.Unit

					forces.alignOrientation.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook, normal)
				end
				-- если поверхности рядом нет — персонаж падает по обычной гравитации,
				-- пока не найдёт следующую поверхность
			end
		end
	end
end)

-- ===================== СБРОС ПРИ РЕСПАУНЕ =====================

Players.PlayerAdded:Connect(function(player)
	getData(player)
	player.CharacterAdded:Connect(function()
		local d = getData(player)
		d.hasBoots = false
		d.antiGravOn = false
		removeWornVisual(player)
		stopAntiGrav(player)
		broadcastButtons()
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	removeWornVisual(player)
	cleanupForces(player)
	playerData[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	getData(player)
end
