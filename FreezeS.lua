local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local TOOL_NAME = "Freeze Shocker"

local FREEZE_TIME = 5
local COOLDOWN = 3
local RANGE = 10

local frozen = {}
local cooldowns = {}

local function freeze(humanoid)
 if frozen[humanoid] then
  return
 end

 local character = humanoid.Parent
 if not character then
  return
 end

 frozen[humanoid] = true

 local oldWalkSpeed = humanoid.WalkSpeed
 local oldJumpPower = humanoid.JumpPower
 local oldAutoRotate = humanoid.AutoRotate

 local oldParts = {}

 for _, part in ipairs(character:GetDescendants()) do
  if part:IsA("BasePart") then
   oldParts[part] = {
    Color = part.Color,
    Material = part.Material
   }

   part.Color = Color3.fromRGB(120, 200, 255)
   part.Material = Enum.Material.Ice
  end
 end

 humanoid.WalkSpeed = 0
 humanoid.JumpPower = 0
 humanoid.AutoRotate = false

 local highlight = Instance.new("Highlight")
 highlight.Name = "FreezeEffect"
 highlight.FillColor = Color3.fromRGB(100, 200, 255)
 highlight.OutlineColor = Color3.fromRGB(220, 245, 255)
 highlight.FillTransparency = 0.45
 highlight.Parent = character

 task.delay(FREEZE_TIME, function()
  if humanoid and humanoid.Parent then
   humanoid.WalkSpeed = oldWalkSpeed
   humanoid.JumpPower = oldJumpPower
   humanoid.AutoRotate = oldAutoRotate

   for part, data in pairs(oldParts) do
    if part and part.Parent then
     part.Color = data.Color
     part.Material = data.Material
    end
   end
  end

  if highlight and highlight.Parent then
   highlight:Destroy()
  end

  frozen[humanoid] = nil
 end)
end

local function setupTool(tool)
 if not tool:IsA("Tool") then
  return
 end

 if tool:GetAttribute("FreezeShockerConnected") then
  return
 end

 tool:SetAttribute("FreezeShockerConnected", true)

 local handle = tool:WaitForChild("Handle")

 tool.Activated:Connect(function()
  local character = tool.Parent
  local myHumanoid = character:FindFirstChildOfClass("Humanoid")

  if not myHumanoid then
   return
  end

  local player = Players:GetPlayerFromCharacter(character)

  if player and cooldowns[player] then
   return
  end

  if player then
   cooldowns[player] = true
  end

  for _, targetPlayer in ipairs(Players:GetPlayers()) do
   local targetCharacter = targetPlayer.Character
   local targetHumanoid = targetCharacter
    and targetCharacter:FindFirstChildOfClass("Humanoid")
   local root = targetCharacter
    and targetCharacter:FindFirstChild("HumanoidRootPart")

   if targetHumanoid
    and root
    and targetHumanoid ~= myHumanoid
    and targetHumanoid.Health > 0 then

    local distance = (root.Position - handle.Position).Magnitude

    if distance <= RANGE then
     freeze(targetHumanoid)
    end
   end
  end

  task.delay(COOLDOWN, function()
   if player then
    cooldowns[player] = nil
   end
  end)
 end)
end

local function giveTool(player)
 local backpack = player:WaitForChild("Backpack")

 local tool = ServerStorage:FindFirstChild(TOOL_NAME)

 if not tool then
  warn("Freeze Shocker не найден в ServerStorage!")
  return
 end

 local clone = tool:Clone()
 clone.Parent = backpack

 setupTool(clone)
end

Players.PlayerAdded:Connect(function(player)
 player.CharacterAdded:Connect(function()
  task.wait(0.5)
  giveTool(player)
 end)
end)

for _, player in ipairs(Players:GetPlayers()) do
 task.spawn(function()
  giveTool(player)
 end)
end
