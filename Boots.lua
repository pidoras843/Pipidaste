--[[
	AntiGravityBoots — один обычный Script (ServerScriptService или Workspace).
	При запуске игры сразу появляется предмет "anti gravity boots".

	Управление одним кликом по ботинкам (цикл состояний на игрока):
	  1-й клик  -> надеть ботинки (приваривается к ногам)
	  2-й клик  -> включить антигравитацию (кружок на ремне светится синим),
	               можно ходить по полу/стенам/потолку — везде, кроме воздуха
	  3-й клик  -> выключить антигравитацию (ботинки остаются надеты)
	  4-й клик  -> снова включить, и т.д.

	При смерти/респауне состояние сбрасывается в "не надето", сам предмет
	остаётся в мире — нужно снова надеть и включить.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ===================== СОЗДАНИЕ ПРЕДМЕТА (как на картинке) =====================

local bootsModel = Instance.new("Model")
bootsModel.Name = "anti gravity boots"
bootsModel.Parent = Workspace

local BASE_CFRAME = CFrame.new(0, 5, 0) -- где предмет появляется, поправьте под свою карту

local BOOT_COLOR = Color3.fromRGB(151, 196, 205)      -- голубовато-серый, как на картинке
local BOOT_COLOR_DARK = Color3.fromRGB(120, 165, 175)  -- подошва/тень
local STRAP_COLOR = Color3.fromRGB(232, 92, 30)        -- оранжевый ремень
local BADGE_OFF_COLOR = Color3.fromRGB(70, 95, 105)    -- тёмный кружок (выключено)
local BADGE_ON_COLOR = Color3.fromRGB(70, 160, 255)    -- синий светящийся кружок (включено)

local function makeBoot(name, offset)
	local boot = Instance.new("Part")
	boot.Name = name
	boot.Size = Vector3.new(1.3, 1.5, 2.6)
	boot.CFrame = BASE_CFRAME * CFrame.new(offset)
	boot.Anchored = true
	boot.CanCollide = false
	boot.Material = Enum.Material.SmoothPlastic
	boot.Color = BOOT_COLOR
	boot.Parent = bootsModel

	-- подошва потемнее, чтобы был объём как на референсе
	local sole = Instance.new("Part")
	sole.Name = name .. "Sole"
	sole.Size = Vector3.new(1.3, 0.3, 2.6)
	sole.CFrame = boot.CFrame * CFrame.new(0, -0.9, 0)
	sole.Anchored = true
	sole.CanCollide = false
	sole.Material = Enum.Material.SmoothPlastic
	sole.Color = BOOT_COLOR_DARK
	sole.Parent = bootsModel

	return boot
end

local bootLeft = makeBoot("BootLeft", Vector3.new(-0.85, 0, 0))
local bootRight = makeBoot("BootRight", Vector3.new(0.85, 0, 0))
bootsModel.PrimaryPart = bootLeft

-- оранжевый ремень поперёк обоих ботинок (как на картинке)
local strap = Instance.new("Part")
strap.Name = "Strap"
strap.Size = Vector3.new(2.7, 0.9, 0.35)
strap.CFrame = BASE_CFRAME * CFrame.new(0, 0.55, -0.9)
strap.Anchored = true
strap.CanCollide = false
strap.Material = Enum.Material.SmoothPlastic
strap.Color = STRAP_COLOR
strap.Parent = bootsModel

-- круглый значок-кнопка по центру ремня, светится синим при включении
local badge = Instance.new("Part")
badge.Name = "Badge"
badge.Shape = Enum.PartType.Cylinder
badge.Size = Vector3.new(0.25, 0.55, 0.55)
badge.CFrame = BASE_CFRAME * CFrame.new(0, 0.55, -1.08) * CFrame.Angles(0, 0, math.rad(90))
badge.Anchored = true
badge.CanCollide = false
badge.Material = Enum.Material.SmoothPlastic
badge.Color = BADGE_OFF_COLOR
badge.Parent = bootsModel

local badgeLight = Instance.new("PointLight")
badgeLight.Brightness = 0
badgeLight.Range = 6
badgeLight.Color = BADGE_ON_COLOR
badgeLight.Parent = badge

local function setBadgeState(isOn)
	if isOn then
		badge.Color = BADGE_ON_COLOR
		badge.Material = Enum.Material.Neon
		badgeLight.Brightness = 2
	else
		badge.Color = BADGE_OFF_COLOR
		badge.Material = Enum.Material.SmoothPlastic
		badgeLight.Brightness = 0
	end
end

-- клик работает по любой части предмета
local clickableParts = {bootLeft, bootRight, strap, badge}

-- ===================== СОСТОЯНИЕ ИГРОКОВ =====================

local STICK_RANGE = 6
local WALK_SPEED = 16

-- state: 0 = не надето, 1 = надето и выключено, 2 = надето и включено
local playerData = {}

local function getData(player)
	local d = playerData[player]
	if not d then
		d = {state = 0, wornVisuals = {}, forces = {}, currentNormal = Vector3.new(0, 1, 0)}
		playerData[player] = d
	end
	return d
end

local function anyPlayerOn()
	for _, d in pairs(playerData) do
		if d.state == 2 then
			return true
		end
	end
	return false
end

local function refreshBadgeVisual()
	setBadgeState(anyPlayerOn())
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

-- ===================== КЛИК = ЦИКЛ СОСТОЯНИЙ =====================

local function onBootsClicked(player)
	local d = getData(player)

	if d.state == 0 then
		-- надеть
		d.state = 1
		equipBootsVisual(player)

	elseif d.state == 1 then
		-- включить антигравитацию
		d.state = 2
		startAntiGrav(player)

	else -- d.state == 2
		-- выключить (остаётся надето)
		d.state = 1
		stopAntiGrav(player)
	end

	refreshBadgeVisual()
end

for _, part in ipairs(clickableParts) do
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 12
	click.Parent = part
	click.MouseClick:Connect(onBootsClicked)
end

-- ===================== ДВИЖЕНИЕ ПО ПОЛУ/СТЕНАМ/ПОТОЛКУ =====================

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
		if d.state == 2 then
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
				-- нет поверхности рядом (открытый воздух) -> обычная гравитация,
				-- пока не найдётся следующая поверхность
			end
		end
	end
end)

-- ===================== СБРОС ПРИ РЕСПАУНЕ =====================

Players.PlayerAdded:Connect(function(player)
	getData(player)
	player.CharacterAdded:Connect(function()
		local d = getData(player)
		d.state = 0
		removeWornVisual(player)
		stopAntiGrav(player)
		refreshBadgeVisual()
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	removeWornVisual(player)
	cleanupForces(player)
	playerData[player] = nil
	refreshBadgeVisual()
end)

for _, player in ipairs(Players:GetPlayers()) do
	getData(player)
end
