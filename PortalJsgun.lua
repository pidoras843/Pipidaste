--[[
    PortalService.server.lua
    Положить в: ServerScriptService (один Script — всё остальное
    создаётся кодом, руками в Studio ничего собирать не нужно).

    Порядок при входе игрока:
      1) Ставятся атрибуты (PortalBalls и т.д.)
      2) Небольшая "загрузка" (имитация, синхронизирована с клиентским
         экраном загрузки в PortalHUD.client.lua)
      3) Выдаются 2 предмета в Backpack:
            - "kids portal"  — портальная пушка
            - "Experiment"   — станок для шариков
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local MAX_BALLS = 10
local PORTAL_COLOR = Color3.fromRGB(90, 220, 60)
local BALL_COLOR = Color3.fromRGB(170, 255, 150)
local LOADING_TIME = 3 -- сек, должно совпадать с PortalHUD.client.lua (см. LOADING_TIME там же)

----------------------------------------------------------------
-- 1. RemoteEvents
----------------------------------------------------------------
local remotesFolder = ReplicatedStorage:FindFirstChild("PortalRemotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "PortalRemotes"
    remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name)
    local r = remotesFolder:FindFirstChild(name)
    if not r then
        r = Instance.new("RemoteEvent")
        r.Name = name
        r.Parent = remotesFolder
    end
    return r
end

local FirePortal        = getOrCreateRemote("FirePortal")        -- клиент -> сервер: выстрел
local PrepareBalls      = getOrCreateRemote("PrepareBalls")      -- клиент -> сервер: изготовить шарики (Experiment)
local TogglePersistence = getOrCreateRemote("TogglePersistence") -- меню
local TeleportToPlace   = getOrCreateRemote("TeleportToPlace")   -- меню, кнопка "Places"
local PortalsChanged    = getOrCreateRemote("PortalsChanged")    -- сервер -> клиент: список моих порталов
local DeletePortal      = getOrCreateRemote("DeletePortal")      -- клиент -> сервер: удалить портал по id
local RequestJoinPlayer = getOrCreateRemote("RequestJoinPlayer") -- клиент -> сервер: телепорт к игроку

----------------------------------------------------------------
-- 2. Постройка предмета "kids portal" (Tool + Handle + колба + шарики)
----------------------------------------------------------------
local function buildFlaskOnHandle(handle)
    local flask = Instance.new("Part")
    flask.Name = "MiniFlask"
    flask.Shape = Enum.PartType.Cylinder
    flask.Size = Vector3.new(0.4, 0.35, 0.35)
    flask.Material = Enum.Material.Glass
    flask.Color = Color3.fromRGB(255, 255, 255) -- белое стекло
    flask.Transparency = 0.5
    flask.CanCollide = false
    flask.Massless = true
    flask.CFrame = handle.CFrame * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90))
    flask.Parent = handle

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = flask
    weld.Parent = flask

    for i = 1, MAX_BALLS do
        local ball = Instance.new("Part")
        ball.Name = "PortalBallVisual"
        ball.Shape = Enum.PartType.Ball
        ball.Size = Vector3.new(0.05, 0.05, 0.05)
        ball.Material = Enum.Material.Neon
        ball.Color = BALL_COLOR
        ball.CanCollide = false
        ball.Massless = true

        local angle = (i / MAX_BALLS) * math.pi * 2
        local radius = 0.08
        local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, (math.random() - 0.5) * 0.1)
        ball.CFrame = flask.CFrame * CFrame.new(offset)
        ball.Parent = flask

        local ballWeld = Instance.new("WeldConstraint")
        ballWeld.Part0 = flask
        ballWeld.Part1 = ball
        ballWeld.Parent = ball

        local light = Instance.new("PointLight")
        light.Color = BALL_COLOR
        light.Range = 1.5
        light.Brightness = 1.2
        light.Parent = ball
    end

    return flask
end

local function createKidsPortal()
    local tool = Instance.new("Tool")
    tool.Name = "kids portal"
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.6, 1.6, 0.6)
    handle.Material = Enum.Material.Metal
    handle.Color = Color3.fromRGB(60, 60, 60)
    handle.Parent = tool

    buildFlaskOnHandle(handle)

    return tool
end

----------------------------------------------------------------
-- 3. Постройка предмета "Experiment" (станок для шариков)
----------------------------------------------------------------
local function createExperimentTool()
    local tool = Instance.new("Tool")
    tool.Name = "Experiment"
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.8, 0.8, 1.6)
    handle.Material = Enum.Material.Metal
    handle.Color = Color3.fromRGB(90, 90, 90)
    handle.Parent = tool

    local flask = Instance.new("Part")
    flask.Name = "TechFlask"
    flask.Shape = Enum.PartType.Cylinder
    flask.Size = Vector3.new(0.5, 0.6, 0.6)
    flask.Material = Enum.Material.Glass
    flask.Color = Color3.fromRGB(255, 255, 255)
    flask.Transparency = 0.4
    flask.CanCollide = false
    flask.Massless = true
    flask.CFrame = handle.CFrame * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
    flask.Parent = handle

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = flask
    weld.Parent = flask

    return tool
end

----------------------------------------------------------------
-- 4. Выдать оба предмета игроку (если их ещё нет)
----------------------------------------------------------------
local function grantStartingTools(player)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end

    local char = player.Character
    local hasGun = backpack:FindFirstChild("kids portal") or (char and char:FindFirstChild("kids portal"))
    local hasExp = backpack:FindFirstChild("Experiment") or (char and char:FindFirstChild("Experiment"))

    if not hasGun then
        createKidsPortal().Parent = backpack
    end
    if not hasExp then
        createExperimentTool().Parent = backpack
    end
end

----------------------------------------------------------------
-- 5. Игрок присоединился — атрибуты, "загрузка", выдача предметов
----------------------------------------------------------------
local loadedOnce = {}

local function onPlayerAdded(player)
    player:SetAttribute("PortalBalls", MAX_BALLS)
    player:SetAttribute("PortalPersistent", false)
    player:SetAttribute("IsLoading", true)

    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        grantStartingTools(player)
    end)

    player:WaitForChild("Backpack")

    if not loadedOnce[player] then
        loadedOnce[player] = true
        task.wait(LOADING_TIME) -- имитация загрузки, см. LOADING_TIME в PortalHUD.client.lua
    end

    player:SetAttribute("IsLoading", false)
    grantStartingTools(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
    loadedOnce[player] = nil
end)

----------------------------------------------------------------
-- 6. Порталы: создание, связывание, телепорт, список "мои порталы"
----------------------------------------------------------------
local pendingPortals = {}   -- [player] = {A = part, B = nil}
local playerPortals = {}    -- [player] = { [id] = {A = part, B = part} }
local portalCounter = {}    -- [player] = number
local PORTAL_LIFETIME_IF_NOT_PERSISTENT = 12

local function sendPortalList(player)
    local list = {}
    local data = playerPortals[player]
    if data then
        for id, pair in pairs(data) do
            if pair.A and pair.A.Parent then
                table.insert(list, {id = id, position = pair.A.Position})
            end
        end
    end
    PortalsChanged:FireClient(player, list)
end

local function makePortalPart(cframe)
    local part = Instance.new("Part")
    part.Name = "Portal"
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(0.3, 6, 4)
    part.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = PORTAL_COLOR

    local light = Instance.new("PointLight")
    light.Color = PORTAL_COLOR
    light.Range = 12
    light.Brightness = 3
    light.Parent = part

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(Color3.fromRGB(180, 255, 150), Color3.fromRGB(30, 140, 20))
    emitter.Size = NumberSequence.new(0.4, 0.1)
    emitter.Lifetime = NumberRange.new(0.6, 1.2)
    emitter.Rate = 40
    emitter.Speed = NumberRange.new(1, 3)
    emitter.Parent = part

    part.Parent = workspace
    return part
end

local function linkAndFinish(player, partA, partB)
    portalCounter[player] = (portalCounter[player] or 0) + 1
    local id = tostring(portalCounter[player])
    playerPortals[player] = playerPortals[player] or {}
    playerPortals[player][id] = {A = partA, B = partB}
    sendPortalList(player)

    local cooldown = {}
    local function connectTouch(a, b)
        a.Touched:Connect(function(hit)
            local char = hit.Parent
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                if cooldown[char] then return end
                cooldown[char] = true
                hrp.CFrame = b.CFrame + b.CFrame.LookVector * 4
                task.delay(1, function() cooldown[char] = nil end)
            end
        end)
    end
    connectTouch(partA, partB)
    connectTouch(partB, partA)

    if not player:GetAttribute("PortalPersistent") then
        task.delay(PORTAL_LIFETIME_IF_NOT_PERSISTENT, function()
            if partA then partA:Destroy() end
            if partB then partB:Destroy() end
            local data = playerPortals[player]
            if data and data[id] then
                data[id] = nil
                sendPortalList(player)
            end
        end)
    end
end

FirePortal.OnServerEvent:Connect(function(player, toolName, hitCFrame)
    if typeof(hitCFrame) ~= "CFrame" then return end

    local balls = player:GetAttribute("PortalBalls") or 0
    local state = pendingPortals[player]

    if not state or (state.A and state.B) then
        if balls <= 0 then
            FirePortal:FireClient(player, "OUT_OF_BALLS")
            return
        end
        local partA = makePortalPart(hitCFrame)
        pendingPortals[player] = {A = partA, B = nil}
        return
    end

    if state.A and not state.B then
        local partB = makePortalPart(hitCFrame)
        state.B = partB
        player:SetAttribute("PortalBalls", math.max(0, balls - 1))
        linkAndFinish(player, state.A, state.B)
        pendingPortals[player] = nil
    end
end)

----------------------------------------------------------------
-- 6.1 Удаление портала из меню ("Порталы" -> кнопка "Удалить")
----------------------------------------------------------------
DeletePortal.OnServerEvent:Connect(function(player, id)
    local data = playerPortals[player]
    if not data then return end
    local pair = data[tostring(id)]
    if pair then
        if pair.A then pair.A:Destroy() end
        if pair.B then pair.B:Destroy() end
        data[tostring(id)] = nil
        sendPortalList(player)
    end
end)

----------------------------------------------------------------
-- 7. "Experiment" — бесконечное пополнение шариков
----------------------------------------------------------------
local PREPARE_TIME = 3 -- сек, совпадает с клиентской анимацией
local preparingNow = {}

PrepareBalls.OnServerEvent:Connect(function(player)
    if preparingNow[player] then return end
    preparingNow[player] = true

    task.delay(PREPARE_TIME, function()
        local current = player:GetAttribute("PortalBalls") or 0
        player:SetAttribute("PortalBalls", math.min(MAX_BALLS, current + MAX_BALLS))
        preparingNow[player] = nil
    end)
end)

----------------------------------------------------------------
-- 8. Меню: персистентность порталов
----------------------------------------------------------------
TogglePersistence.OnServerEvent:Connect(function(player)
    local cur = player:GetAttribute("PortalPersistent") or false
    player:SetAttribute("PortalPersistent", not cur)
end)

----------------------------------------------------------------
-- 9. Меню: телепорт к игроку ("нажал на ник -> играть в портал")
----------------------------------------------------------------
RequestJoinPlayer.OnServerEvent:Connect(function(player, targetPlayer)
    if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then return end

    local char = player.Character
    local targetChar = targetPlayer.Character
    if not (char and targetChar) then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    if hrp and targetHrp then
        hrp.CFrame = targetHrp.CFrame * CFrame.new(4, 0, 0)
    end
end)

----------------------------------------------------------------
-- 10. Меню: телепорт по ID места ("Places")
----------------------------------------------------------------
TeleportToPlace.OnServerEvent:Connect(function(player, placeId)
    if typeof(placeId) ~= "number" then return end
    local ok, err = pcall(function()
        TeleportService:Teleport(placeId, player)
    end)
    if not ok then
        warn("Teleport failed:", err)
    end
end)
