local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")

local FREEZE_TIME = 5      -- сколько секунд держится заморозка
local COOLDOWN    = 3      -- перезарядка
local RANGE       = 10     -- радиус действия

local onCooldown = false
local frozen = {}

local function freeze(humanoid)
	if frozen[humanoid] then return end
	frozen[humanoid] = true

	local char = humanoid.Parent
	local oldWalk, oldJump = humanoid.WalkSpeed, humanoid.JumpPower

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	-- визуальный эффект льда
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(120, 200, 255)
			part.Material = Enum.Material.Ice
		end
	end

	task.delay(FREEZE_TIME, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = oldWalk
			humanoid.JumpPower = oldJump
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Material = Enum.Material.Plastic
				end
			end
		end
		frozen[humanoid] = nil
	end)
end

Tool.Activated:Connect(function()
	if onCooldown then return end
	onCooldown = true

	local myChar = Tool.Parent
	local myHum = myChar:FindFirstChildOfClass("Humanoid")

	for _, plr in ipairs(game.Players:GetPlayers()) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum ~= myHum and hum.Health > 0 then
			if (hrp.Position - Handle.Position).Magnitude <= RANGE then
				freeze(hum)
			end
		end
	end

	task.wait(COOLDOWN)
	onCooldown = false
end)-- Script в ServerScriptService
game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		game.ServerStorage["Freeze Shocker"]:Clone().Parent = plr.Backpack
	end)
end)
