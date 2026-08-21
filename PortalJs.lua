--[[
    PortalService.server.lua
    Положить в: ServerScriptService

    Что делает:
    - Создаёт RemoteEvent'ы в ReplicatedStorage/PortalRemotes
    - Хранит "шарики" каждого игрока (Attribute PortalBalls, максимум 10)
    - Обрабатывает выстрел порталом (2 портала = 1 шарик)
    - Телепортирует игроков между связанной парой порталов
    - Обрабатывает крафт "Technological Portal"
    - Обрабатывает переключение "порталы не исчезают" и телепорт по местам (Places)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

----------------------------------------------------------------
-- 1. RemoteEvents
----------------------------------------------------------------
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "PortalRemotes"
remotesFolder.Parent = ReplicatedStorage

local function newRemote(name)
    local r = Instance.new("RemoteEvent")
    r.Name = name
    r.Parent = remotesFolder
    return r
end

local FirePortal              = newRemote("FirePortal")              -- клиент -> сервер: выстрел
local CraftTechnologicalPortal= newRemote("CraftTechnologicalPortal")-- клиент -> сервер: крафт
local TogglePersistence       = newRemote("TogglePersistence")       -- клиент -> сервер: кнопка меню 1
local TeleportToPlace         = newRemote("TeleportToPlace")         -- клиент -> сервер: кнопка меню 3
local BallsUpdated            = newRemote("BallsUpdated")            -- сервер -> клиент (не обязателен, т.к. Attribute реплицируется сам)
local PrepareBalls            = newRemote("PrepareBalls")            -- клиент -> сервер: инструмент "Preparation of portal balls"

----------------------------------------------------------------
-- 2. Игрок присоединился — стартовые атрибуты
----------------------------------------------------------------
local MAX_BALLS = 10

Players.PlayerAdded:Connect(function(player)
    player:SetAttribute("PortalBalls", MAX_BALLS)
    player:SetAttribute("PortalPersistent", false) -- не исчезают ли порталы
    player:SetAttribute("LastPortalCFrame", nil)
end)

----------------------------------------------------------------
-- 3. Хранилище активных порталов игрока: { [player] = {A = part_or_nil, B = part_or_nil} }
----------------------------------------------------------------
local pendingPortals = {}

local PORTAL_COLOR = Color3.fromRGB(90, 220, 60) -- зелёный, как на референсе
local PORTAL_LIFETIME_IF_NOT_PERSISTENT = 12 -- сек

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

    -- Немного "живого" эффекта портала (замена реальной GIF-текстуры с фото)
    local light = Instance.new("PointLight")
    light.Color = PORTAL_COLOR
    light.Range = 12
    light.Brightness = 3
    light.Parent = part

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(Color3.fromRGB(180,255,150), Color3.fromRGB(30,140,20))
    emitter.Size = NumberSequence.new(0.4, 0.1)
    emitter.Lifetime = NumberRange.new(0.6, 1.2)
    emitter.Rate = 40
    emitter.Speed = NumberRange.new(1, 3)
    emitter.Parent = part

    part.Parent = workspace
    return part
end

local function linkAndFinish(player, partA, partB)
    partA:SetAttribute("LinkedTo", partB:GetDebugId())
    partB:SetAttribute("LinkedTo", partA:GetDebugId())

    -- Телепорт по касанию, с защитой от дребезга (двойной телепорт туда-обратно)
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

    player:SetAttribute("LastPortalCFrame", partB.CFrame) -- для кнопки "Игроки" в меню

    if not player:GetAttribute("PortalPersistent") then
        task.delay(PORTAL_LIFETIME_IF_NOT_PERSISTENT, function()
            if partA then partA:Destroy() end
            if partB then partB:Destroy() end
        end)
    end
end

----------------------------------------------------------------
-- 4. Выстрел порталом (общий для PortalGun и PortalKids)
----------------------------------------------------------------
FirePortal.OnServerEvent:Connect(function(player, toolName, hitCFrame)
    if typeof(hitCFrame) ~= "CFrame" then return end

    local balls = player:GetAttribute("PortalBalls") or 0
    local state = pendingPortals[player]

    if not state or (state.A and state.B) then
        -- начинаем новую пару порталов
        if balls <= 0 then
            -- шариков нет — сообщаем клиенту, что нужен Technological Portal
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
        -- списываем 1 шарик за пару порталов (и для PortalGun, и для PortalKids)
        player:SetAttribute("PortalBalls", math.max(0, balls - 1))
        linkAndFinish(player, state.A, state.B)
        pendingPortals[player] = nil
    end
end)

----------------------------------------------------------------
-- 5. Крафт "Technological Portal" -> выдаёт новый PortalGun с полными шариками
----------------------------------------------------------------
-- Ссылку на ServerStorage.PortalGunTemplate нужно создать самостоятельно:
-- положите готовый инструмент PortalGun в ServerStorage под именем "PortalGunTemplate"
local ServerStorage = game:GetService("ServerStorage")

CraftTechnologicalPortal.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end

    -- Анимация "крафта" полностью проигрывается на клиенте (см. TechnologicalPortalTool.client.lua),
    -- сервер только выдаёт итоговый инструмент и обновляет шарики.
    task.wait(6) -- время "выпекания" + сборки, синхронизировано с клиентской анимацией

    player:SetAttribute("PortalBalls", MAX_BALLS)

    local template = ServerStorage:FindFirstChild("PortalGunTemplate")
    if template then
        local newTool = template:Clone()
        newTool.Parent = player.Backpack
    end

    -- убираем использованный Technological Portal (если один — расходуется)
    local tool = char:FindFirstChild("Technological portal")
    if tool then tool:Destroy() end
    local backpackTool = player.Backpack:FindFirstChild("Technological portal")
    if backpackTool then backpackTool:Destroy() end
end)

----------------------------------------------------------------
-- 5.5 "Preparation of portal balls" — бесконечная подготовка шариков
--     для детской пушки "kids portal". Каждое использование этого
--     инструмента пополняет шарики игрока до максимума (10).
--     Т.к. визуал колбы у "kids portal" завязан на Attribute PortalBalls
--     (см. KidsPortalTool.client.lua), шарики "появляются" в колбе сразу же.
----------------------------------------------------------------
local PREPARE_TIME = 3 -- сек, должно совпадать с длительностью клиентской анимации

local preparingNow = {}

PrepareBalls.OnServerEvent:Connect(function(player)
    if preparingNow[player] then return end -- защита от спама, но не ограничивает количество раз
    preparingNow[player] = true

    task.delay(PREPARE_TIME, function()
        local current = player:GetAttribute("PortalBalls") or 0
        player:SetAttribute("PortalBalls", math.min(MAX_BALLS, current + MAX_BALLS))
        preparingNow[player] = nil
    end)
end)

----------------------------------------------------------------
-- 6. Меню: кнопка 1 — включить/выключить "порталы не исчезают"
----------------------------------------------------------------
TogglePersistence.OnServerEvent:Connect(function(player)
    local cur = player:GetAttribute("PortalPersistent") or false
    player:SetAttribute("PortalPersistent", not cur)
end)

----------------------------------------------------------------
-- 7. Меню: кнопка 3 — телепорт в другое место (Place)
----------------------------------------------------------------
TeleportToPlace.OnServerEvent:Connect(function(player, placeId)
    if typeof(placeId) ~= "number" then return end
    local ok, err = pcall(function()
        TeleportService:Teleport(placeId, player)
    end)
    if not ok then
        warn("Teleport failed:", err)
    end
end)--[[
    KidsPortalTool.client.lua
    Положить в: Tool с именем "kids portal" -> этот LocalScript
    (У Tool должна быть основная часть Handle)

    Что делает:
    - Строит мини-колбу: белое стекло + 10 маленьких светло-зелёных шариков.
    - Шарики в колбе визуально показывают РЕАЛЬНОЕ количество (Attribute PortalBalls):
      сколько шариков осталось — столько и видно в колбе (остальные прозрачные).
    - Когда инструмент "Preparation of portal balls" пополняет шарики,
      колба у этой пушки заполняется заново автоматически (см. подписку ниже).
    - ЛКМ (Activated) -> первый клик ставит портал А, второй клик — портал B.
      2 портала = 1 шарик.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("PortalRemotes")
local FirePortal = remotes:WaitForChild("FirePortal")

local MAX_BALLS = 10
local ballParts = {} -- заполняется в buildFlask, индексы 1..10

----------------------------------------------------------------
-- 1. Построение мини-колбы (белое стекло + 10 светло-зелёных шариков)
----------------------------------------------------------------
local function buildFlask(handle)
    if handle:FindFirstChild("MiniFlask") then return end
    ballParts = {}

    local flask = Instance.new("Part")
    flask.Name = "MiniFlask"
    flask.Shape = Enum.PartType.Cylinder
    flask.Size = Vector3.new(0.4, 0.35, 0.35) -- маленькая, "детская"
    flask.Material = Enum.Material.Glass
    flask.Color = Color3.fromRGB(255, 255, 255) -- белое стекло
    flask.Transparency = 0.5
    flask.CanCollide = false
    flask.Massless = true

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = flask
    weld.Parent = flask

    flask.CFrame = handle.CFrame * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90))
    flask.Parent = handle

    for i = 1, MAX_BALLS do
        local ball = Instance.new("Part")
        ball.Name = "PortalBallVisual"
        ball.Shape = Enum.PartType.Ball
        ball.Size = Vector3.new(0.05, 0.05, 0.05)
        ball.Material = Enum.Material.Neon
        ball.Color = Color3.fromRGB(170, 255, 150) -- светло-зелёный свет
        ball.CanCollide = false
        ball.Massless = true

        local angle = (i / MAX_BALLS) * math.pi * 2
        local radius = 0.08
        local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, (math.random() - 0.5) * 0.1)

        local ballWeld = Instance.new("WeldConstraint")
        ballWeld.Part0 = flask
        ballWeld.Part1 = ball
        ballWeld.Parent = ball

        ball.CFrame = flask.CFrame * CFrame.new(offset)
        ball.Parent = flask

        local light = Instance.new("PointLight")
        light.Color = ball.Color
        light.Range = 1.5
        light.Brightness = 1.2
        light.Parent = ball

        ballParts[i] = ball
    end

    -- сразу показать актуальное количество
    local current = player:GetAttribute("PortalBalls") or MAX_BALLS
    for i, ball in ipairs(ballParts) do
        ball.Transparency = (i <= current) and 0 or 1
        local l = ball:FindFirstChildOfClass("PointLight")
        if l then l.Enabled = (i <= current) end
    end
end

----------------------------------------------------------------
-- 2. Живое обновление колбы при изменении количества шариков
--    (срабатывает и при выстреле, и при "Preparation of portal balls")
----------------------------------------------------------------
player:GetAttributeChangedSignal("PortalBalls"):Connect(function()
    local current = player:GetAttribute("PortalBalls") or 0
    for i, ball in ipairs(ballParts) do
        local visible = i <= current
        ball.Transparency = visible and 0 or 1
        local l = ball:FindFirstChildOfClass("PointLight")
        if l then l.Enabled = visible end
    end
end)

tool.Equipped:Connect(function()
    local handle = tool:FindFirstChild("Handle")
    if handle then
        buildFlask(handle)
    end
end)

----------------------------------------------------------------
-- 3. Выстрел: наводим мышкой и жмём ЛКМ (Activated)
----------------------------------------------------------------
tool.Activated:Connect(function()
    local mouse = player:GetMouse()
    local hit = mouse.Hit
    if not hit then return end
    FirePortal:FireServer(tool.Name, hit)
end)

----------------------------------------------------------------
-- 4. Сообщение "шарики закончились" -> подсказать взять
--    "Preparation of portal balls"
----------------------------------------------------------------
FirePortal.OnClientEvent:Connect(function(msg)
    if msg == "OUT_OF_BALLS" then
        local playerGui = player:WaitForChild("PlayerGui")
        local hud = playerGui:FindFirstChild("PortalHUD")
        if hud then
            local notice = hud:FindFirstChild("NoBallsNotice")
            if notice then
                notice.Visible = true
                task.delay(3, function() notice.Visible = false end)
            end
        end
    end
end)--[[
    PreparationOfPortalBallsTool.client.lua
    Положить в: Tool с именем "Preparation of portal balls" -> этот LocalScript
    (У Tool должна быть основная часть Handle)

    Что делает:
    - По ЛКМ проигрывает короткую анимацию "изготовления шариков" рядом с игроком
      (маленькая колба, в которой формируются зелёные шарики).
    - После анимации отправляет запрос на сервер (PrepareBalls), который
      пополняет PortalBalls игрока до 10.
    - Т.к. колба у "kids portal" следит за PortalBalls (см. KidsPortalTool.client.lua),
      шарики сразу же визуально появляются в колбе детской пушки.
    - Можно использовать сколько угодно раз подряд — шарики никогда не кончатся насовсем.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local tool = script.Parent
local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("PortalRemotes")
local PrepareBalls = remotes:WaitForChild("PrepareBalls")

local isPreparing = false

local function playPrepareAnimation()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local origin = hrp.CFrame * CFrame.new(1.5, 0, -2)

    local folder = Instance.new("Folder")
    folder.Name = "PrepareBallsScene"
    folder.Parent = workspace

    -- маленькая рабочая колба
    local flask = Instance.new("Part")
    flask.Name = "PrepFlask"
    flask.Shape = Enum.PartType.Cylinder
    flask.Anchored = true
    flask.CanCollide = false
    flask.Material = Enum.Material.Glass
    flask.Color = Color3.fromRGB(255, 255, 255)
    flask.Transparency = 0.4
    flask.Size = Vector3.new(0.5, 0.6, 0.6)
    flask.CFrame = origin * CFrame.Angles(0, 0, math.rad(90))
    flask.Parent = folder

    task.wait(0.3)

    -- шарики поочерёдно "формируются" внутри колбы и вспыхивают
    for i = 1, 10 do
        local ball = Instance.new("Part")
        ball.Shape = Enum.PartType.Ball
        ball.Anchored = true
        ball.CanCollide = false
        ball.Material = Enum.Material.Neon
        ball.Color = Color3.fromRGB(170, 255, 150)
        ball.Size = Vector3.new(0.05, 0.05, 0.05)

        local angle = (i / 10) * math.pi * 2
        local radius = 0.15
        local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
        ball.CFrame = flask.CFrame * CFrame.new(offset)
        ball.Transparency = 1
        ball.Parent = folder

        local light = Instance.new("PointLight")
        light.Color = ball.Color
        light.Range = 1.5
        light.Brightness = 2
        light.Parent = ball

        TweenService:Create(ball, TweenInfo.new(0.15), {Transparency = 0}):Play()
        task.wait(0.12)
    end

    task.wait(0.6)

    -- вспышка готовности
    local flash = Instance.new("PointLight")
    flash.Color = Color3.fromRGB(170, 255, 150)
    flash.Range = 10
    flash.Brightness = 6
    flash.Parent = flask
    task.wait(0.25)

    folder:Destroy()
end

tool.Activated:Connect(function()
    if isPreparing then return end
    isPreparing = true

    playPrepareAnimation()
    PrepareBalls:FireServer()

    task.wait(0.5)
    isPreparing = false
end)--[[
    PortalGunTool.client.lua
    Положить в: StarterPack (или ServerStorage) -> Tool "PortalGun" -> этот LocalScript
    У Tool должна быть основная часть Handle (Part) — на неё "навешивается" колба.

    Что делает:
    - Программно строит мини-колбу: белое стекло (Glass, полупрозрачное) +
      внутри 10 маленьких светло-зелёных светящихся шариков.
    - ЛКМ (Activated) -> первый клик ставит портал А, второй клик — портал B.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("PortalRemotes")
local FirePortal = remotes:WaitForChild("FirePortal")

----------------------------------------------------------------
-- 1. Построение мини-колбы (белое стекло + светло-зелёные шарики)
----------------------------------------------------------------
local function buildFlask(handle)
    if handle:FindFirstChild("MiniFlask") then return end

    local flask = Instance.new("Part")
    flask.Name = "MiniFlask"
    flask.Shape = Enum.PartType.Cylinder
    flask.Size = Vector3.new(0.6, 0.5, 0.5) -- маленькая колба
    flask.Material = Enum.Material.Glass
    flask.Color = Color3.fromRGB(255, 255, 255) -- белое стекло
    flask.Transparency = 0.55
    flask.CanCollide = false
    flask.Massless = true

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = flask
    weld.Parent = flask

    flask.CFrame = handle.CFrame * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
    flask.Parent = handle

    -- 10 маленьких светло-зелёных светящихся шариков внутри колбы
    for i = 1, 10 do
        local ball = Instance.new("Part")
        ball.Name = "PortalBallVisual"
        ball.Shape = Enum.PartType.Ball
        ball.Size = Vector3.new(0.08, 0.08, 0.08)
        ball.Material = Enum.Material.Neon
        ball.Color = Color3.fromRGB(170, 255, 150) -- светло-зелёный свет
        ball.CanCollide = false
        ball.Massless = true

        local angle = (i / 10) * math.pi * 2
        local radius = 0.12
        local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, (math.random() - 0.5) * 0.15)

        local ballWeld = Instance.new("WeldConstraint")
        ballWeld.Part0 = flask
        ballWeld.Part1 = ball
        ballWeld.Parent = ball

        ball.CFrame = flask.CFrame * CFrame.new(offset)
        ball.Parent = flask

        local light = Instance.new("PointLight")
        light.Color = ball.Color
        light.Range = 2
        light.Brightness = 1.5
        light.Parent = ball
    end
end

tool.Equipped:Connect(function()
    local handle = tool:FindFirstChild("Handle")
    if handle then
        buildFlask(handle)
    end
end)

----------------------------------------------------------------
-- 2. Выстрел: наводим мышкой и жмём ЛКМ (Activated)
----------------------------------------------------------------
tool.Activated:Connect(function()
    local mouse = player:GetMouse()
    local hit = mouse.Hit -- CFrame точки, куда навелись

    if not hit then return end

    FirePortal:FireServer(tool.Name, hit)
end)

----------------------------------------------------------------
-- 3. Сообщение "шарики закончились" -> подсказать скрафтить Technological Portal
----------------------------------------------------------------
FirePortal.OnClientEvent:Connect(function(msg)
    if msg == "OUT_OF_BALLS" then
        local playerGui = player:WaitForChild("PlayerGui")
        local hud = playerGui:FindFirstChild("PortalHUD")
        if hud then
            local notice = hud:FindFirstChild("NoBallsNotice")
            if notice then
                notice.Visible = true
                task.delay(3, function() notice.Visible = false end)
            end
        end
    end
end)--[[
    TechnologicalPortalTool.client.lua
    Положить в: Tool "Technological portal" -> этот LocalScript

    Активируется, когда шарики закончились. По ЛКМ проигрывает "мультяшную"
    анимацию крафта через TweenService (без риггинга персонажа):
      1) раскладной стол разворачивается
      2) появляются "научные" предметы (колба, реактивы)
      3) синяя + жёлтая жидкость смешиваются -> зелёная
      4) заливается в 2 формочки, формочки соединяются
      5) кладётся в микроволновку, ждём (сжато до нескольких секунд)
      6) достаётся новая PortalGun (выдаёт сервер) с полными шариками

    ВАЖНО: реальные 3D-модели стола/микроволновки/колбы нужно один раз
    расставить в StarterGui/Workspace как ObjectValue-ссылки, либо
    оставить этот скрипт создавать простые Part-заглушки (что он и делает
    по умолчанию, чтобы всё работало "из коробки").
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local tool = script.Parent
local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("PortalRemotes")
local CraftTechnologicalPortal = remotes:WaitForChild("CraftTechnologicalPortal")

local craftingNow = false

local function tween(obj, props, time)
    local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingStyle.Out and Enum.EasingDirection.Out or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function playCraftingAnimation()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local originCFrame = hrp.CFrame * CFrame.new(0, 0, -4)

    -- временная папка для всех декораций анимации
    local folder = Instance.new("Folder")
    folder.Name = "CraftingScene"
    folder.Parent = workspace

    -- 1) СТОЛ: начинается "сложенным" (тонкая доска), разворачивается в полноразмерный
    local table_ = Instance.new("Part")
    table_.Name = "FoldingTable"
    table_.Anchored = true
    table_.CanCollide = false
    table_.Material = Enum.Material.Wood
    table_.Color = Color3.fromRGB(120, 85, 55)
    table_.Size = Vector3.new(0.2, 0.1, 1.5)
    table_.CFrame = originCFrame
    table_.Parent = folder

    tween(table_, {Size = Vector3.new(3, 0.2, 1.5)}, 1.2)
    task.wait(1.3)

    -- 2) Научные предметы появляются на столе (колба + 2 реактива)
    local flask = Instance.new("Part")
    flask.Name = "ScienceFlask"
    flask.Shape = Enum.PartType.Cylinder
    flask.Anchored = true
    flask.CanCollide = false
    flask.Material = Enum.Material.Glass
    flask.Transparency = 0.3
    flask.Color = Color3.fromRGB(255,255,255)
    flask.Size = Vector3.new(0.6, 0.8, 0.8)
    flask.CFrame = table_.CFrame * CFrame.new(0, 0.6, 0) * CFrame.Angles(0,0,math.rad(90))
    flask.Parent = folder

    local blue = Instance.new("Part")
    blue.Name = "BlueReagent"
    blue.Shape = Enum.PartType.Ball
    blue.Anchored = true
    blue.CanCollide = false
    blue.Material = Enum.Material.Neon
    blue.Color = Color3.fromRGB(60,120,255)
    blue.Size = Vector3.new(0.4,0.4,0.4)
    blue.CFrame = table_.CFrame * CFrame.new(-0.8, 0.4, 0.3)
    blue.Parent = folder

    local yellow = Instance.new("Part")
    yellow.Name = "YellowReagent"
    yellow.Shape = Enum.PartType.Ball
    yellow.Anchored = true
    yellow.CanCollide = false
    yellow.Material = Enum.Material.Neon
    yellow.Color = Color3.fromRGB(255,230,60)
    yellow.Size = Vector3.new(0.4,0.4,0.4)
    yellow.CFrame = table_.CFrame * CFrame.new(0.8, 0.4, 0.3)
    yellow.Parent = folder

    task.wait(0.8)

    -- 3) Смешивание: синий и жёлтый двигаются в колбу и становятся зелёными
    tween(blue, {CFrame = flask.CFrame}, 0.8)
    tween(yellow, {CFrame = flask.CFrame}, 0.8)
    task.wait(0.9)

    blue:Destroy()
    yellow:Destroy()
    tween(flask, {Color = Color3.fromRGB(90, 220, 60)}, 0.6) -- жидкость становится зелёной
    task.wait(0.8)

    -- 4) Заливаем в 2 формочки, формочки соединяются в одну
    local moldA = Instance.new("Part")
    moldA.Name = "MoldA"
    moldA.Anchored = true
    moldA.CanCollide = false
    moldA.Material = Enum.Material.Neon
    moldA.Color = Color3.fromRGB(90, 220, 60)
    moldA.Size = Vector3.new(0.5,0.2,0.5)
    moldA.CFrame = table_.CFrame * CFrame.new(-0.5, 0.25, -0.3)
    moldA.Parent = folder

    local moldB = moldA:Clone()
    moldB.Name = "MoldB"
    moldB.CFrame = table_.CFrame * CFrame.new(0.5, 0.25, -0.3)
    moldB.Parent = folder

    task.wait(0.5)
    tween(moldA, {CFrame = table_.CFrame * CFrame.new(0, 0.25, -0.3)}, 0.6)
    tween(moldB, {CFrame = table_.CFrame * CFrame.new(0, 0.25, -0.3)}, 0.6)
    task.wait(0.7)
    moldB:Destroy() -- слились в одну деталь

    -- 5) Микроволновка: короткая "печка" в 1 секунду вместо 1 минуты
    local microwave = Instance.new("Part")
    microwave.Name = "Microwave"
    microwave.Anchored = true
    microwave.CanCollide = false
    microwave.Material = Enum.Material.Metal
    microwave.Color = Color3.fromRGB(200,200,200)
    microwave.Size = Vector3.new(1.2, 0.8, 1)
    microwave.CFrame = table_.CFrame * CFrame.new(0, 0.5, -1.5)
    microwave.Parent = folder

    tween(moldA, {CFrame = microwave.CFrame}, 0.6)
    task.wait(0.8)
    moldA.Transparency = 1 -- "скрылось внутри" микроволновки

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(90,220,60)
    light.Parent = microwave
    for i = 1, 4 do
        light.Enabled = true
        task.wait(0.15)
        light.Enabled = false
        task.wait(0.15)
    end

    task.wait(0.5)

    -- 6) Достаём новую PortalGun (визуально) — фактическую выдачу инструмента делает сервер
    moldA.Transparency = 0
    moldA.CFrame = microwave.CFrame + Vector3.new(0, 1, 0)
    tween(moldA, {CFrame = table_.CFrame * CFrame.new(0, 1.2, 0)}, 0.6)
    task.wait(1)

    folder:Destroy()
end

tool.Activated:Connect(function()
    if craftingNow then return end
    craftingNow = true

    playCraftingAnimation()
    CraftTechnologicalPortal:FireServer()

    task.wait(1)
    craftingNow = false
end)--[[
    PortalHUD.client.lua
    Положить в: StarterGui -> этот LocalScript (просто как LocalScript внутри StarterGui)

    Создаёт:
    1) Счётчик шариков сверху экрана: "Шарики: X/10"
    2) Меню из 3 кнопок:
        - "Порталы"  -> вкл/выкл, чтобы порталы НЕ исчезали
        - "Игроки"   -> список игроков, у кого какой портал/тип пушки, телепорт к их порталу
        - "Места"    -> список Place'ов, выбираешь -> телепортируешься
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("PortalRemotes")
local TogglePersistence = remotes:WaitForChild("TogglePersistence")
local TeleportToPlace = remotes:WaitForChild("TeleportToPlace")

----------------------------------------------------------------
-- ЗАПОЛНИТЕ СВОИМИ ID: список мест, куда можно телепортироваться (кнопка 3)
----------------------------------------------------------------
local PLACES = {
    {Name = "Лобби", PlaceId = 0},      -- <-- впишите свой PlaceId
    {Name = "Арена",  PlaceId = 0},      -- <-- впишите свой PlaceId
    {Name = "Дом",     PlaceId = 0},      -- <-- впишите свой PlaceId
}

----------------------------------------------------------------
-- Базовый ScreenGui
----------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PortalHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

----------------------------------------------------------------
-- 1) Счётчик шариков сверху
----------------------------------------------------------------
local counterLabel = Instance.new("TextLabel")
counterLabel.Name = "BallCounter"
counterLabel.AnchorPoint = Vector2.new(0.5, 0)
counterLabel.Position = UDim2.new(0.5, 0, 0.02, 0)
counterLabel.Size = UDim2.new(0, 220, 0, 40)
counterLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
counterLabel.BackgroundTransparency = 0.3
counterLabel.TextColor3 = Color3.fromRGB(170, 255, 150)
counterLabel.Font = Enum.Font.GothamBold
counterLabel.TextScaled = true
counterLabel.Text = "Шарики: 10/10"
counterLabel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = counterLabel

local function updateCounter()
    local balls = player:GetAttribute("PortalBalls") or 0
    counterLabel.Text = string.format("Шарики: %d/10", balls)
end

player:GetAttributeChangedSignal("PortalBalls"):Connect(updateCounter)
updateCounter()

-- Уведомление "шарики закончились" (используется PortalGunTool.client.lua)
local notice = Instance.new("TextLabel")
notice.Name = "NoBallsNotice"
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0.08, 0)
notice.Size = UDim2.new(0, 420, 0, 30)
notice.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
notice.BackgroundTransparency = 0.2
notice.TextColor3 = Color3.new(1,1,1)
notice.Font = Enum.Font.Gotham
notice.TextScaled = true
notice.Text = "Шарики закончились! Скрафтите Technological portal"
notice.Visible = false
notice.Parent = screenGui

----------------------------------------------------------------
-- 2) Меню из трёх кнопок (нижний правый угол)
----------------------------------------------------------------
local menuFrame = Instance.new("Frame")
menuFrame.Name = "MenuButtons"
menuFrame.AnchorPoint = Vector2.new(1, 1)
menuFrame.Position = UDim2.new(1, -20, 1, -20)
menuFrame.Size = UDim2.new(0, 160, 0, 140)
menuFrame.BackgroundTransparency = 1
menuFrame.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Parent = menuFrame

local function makeMenuButton(name, text)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.TextColor3 = Color3.fromRGB(170, 255, 150)
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.Text = text
    btn.Parent = menuFrame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn
    return btn
end

local btnPortals = makeMenuButton("BtnPortals", "Порталы")
local btnPlayers = makeMenuButton("BtnPlayers", "Игроки")
local btnPlaces  = makeMenuButton("BtnPlaces", "Места")

----------------------------------------------------------------
-- Панель 1: Порталы (вкл/выкл "не исчезают")
----------------------------------------------------------------
local panelPortals = Instance.new("Frame")
panelPortals.Name = "PanelPortals"
panelPortals.AnchorPoint = Vector2.new(1, 1)
panelPortals.Position = UDim2.new(1, -20, 1, -170)
panelPortals.Size = UDim2.new(0, 260, 0, 70)
panelPortals.BackgroundColor3 = Color3.fromRGB(20,20,20)
panelPortals.BackgroundTransparency = 0.2
panelPortals.Visible = false
panelPortals.Parent = screenGui
Instance.new("UICorner", panelPortals).CornerRadius = UDim.new(0,8)

local persistToggle = Instance.new("TextButton")
persistToggle.Size = UDim2.new(1, -20, 1, -20)
persistToggle.Position = UDim2.new(0, 10, 0, 10)
persistToggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
persistToggle.TextColor3 = Color3.new(1,1,1)
persistToggle.Font = Enum.Font.Gotham
persistToggle.TextScaled = true
persistToggle.Parent = panelPortals
Instance.new("UICorner", persistToggle).CornerRadius = UDim.new(0,6)

local function refreshPersistText()
    local persistent = player:GetAttribute("PortalPersistent")
    persistToggle.Text = persistent and "Порталы: НЕ исчезают" or "Порталы: исчезают"
end
player:GetAttributeChangedSignal("PortalPersistent"):Connect(refreshPersistText)
refreshPersistText()

persistToggle.MouseButton1Click:Connect(function()
    TogglePersistence:FireServer()
end)

----------------------------------------------------------------
-- Панель 2: Игроки (список + телепорт к их последнему порталу)
----------------------------------------------------------------
local panelPlayers = Instance.new("ScrollingFrame")
panelPlayers.Name = "PanelPlayers"
panelPlayers.AnchorPoint = Vector2.new(1, 1)
panelPlayers.Position = UDim2.new(1, -20, 1, -170)
panelPlayers.Size = UDim2.new(0, 260, 0, 220)
panelPlayers.BackgroundColor3 = Color3.fromRGB(20,20,20)
panelPlayers.BackgroundTransparency = 0.2
panelPlayers.CanvasSize = UDim2.new(0,0,0,0)
panelPlayers.ScrollBarThickness = 6
panelPlayers.Visible = false
panelPlayers.Parent = screenGui
Instance.new("UICorner", panelPlayers).CornerRadius = UDim.new(0,8)

local playersLayout = Instance.new("UIListLayout")
playersLayout.Padding = UDim.new(0,4)
playersLayout.Parent = panelPlayers

local function rebuildPlayerList()
    for _, child in ipairs(panelPlayers:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, -8, 0, 34)
            row.BackgroundColor3 = Color3.fromRGB(45,45,45)
            row.TextColor3 = Color3.fromRGB(170,255,150)
            row.Font = Enum.Font.Gotham
            row.TextScaled = true
            row.Text = other.Name .. " — зайти в портал"
            row.Parent = panelPlayers
            Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)

            row.MouseButton1Click:Connect(function()
                local targetCFrame = other:GetAttribute("LastPortalCFrame")
                local char = player.Character
                if targetCFrame and char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = targetCFrame + targetCFrame.LookVector * 3
                end
            end)
        end
    end
    panelPlayers.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 8)
end

Players.PlayerAdded:Connect(rebuildPlayerList)
Players.PlayerRemoving:Connect(rebuildPlayerList)
rebuildPlayerList()

----------------------------------------------------------------
-- Панель 3: Места (TeleportService)
----------------------------------------------------------------
local panelPlaces = Instance.new("Frame")
panelPlaces.Name = "PanelPlaces"
panelPlaces.AnchorPoint = Vector2.new(1, 1)
panelPlaces.Position = UDim2.new(1, -20, 1, -170)
panelPlaces.Size = UDim2.new(0, 260, 0, 160)
panelPlaces.BackgroundColor3 = Color3.fromRGB(20,20,20)
panelPlaces.BackgroundTransparency = 0.2
panelPlaces.Visible = false
panelPlaces.Parent = screenGui
Instance.new("UICorner", panelPlaces).CornerRadius = UDim.new(0,8)

local placesLayout = Instance.new("UIListLayout")
placesLayout.Padding = UDim.new(0,4)
placesLayout.Parent = panelPlaces

for _, placeInfo in ipairs(PLACES) do
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -20, 0, 34)
    row.Position = UDim2.new(0, 10, 0, 0)
    row.BackgroundColor3 = Color3.fromRGB(45,45,45)
    row.TextColor3 = Color3.fromRGB(170,255,150)
    row.Font = Enum.Font.Gotham
    row.TextScaled = true
    row.Text = placeInfo.Name
    row.Parent = panelPlaces
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)

    row.MouseButton1Click:Connect(function()
        TeleportToPlace:FireServer(placeInfo.PlaceId)
    end)
end

----------------------------------------------------------------
-- Переключение панелей по кнопкам (открыта только одна за раз)
----------------------------------------------------------------
local panels = {panelPortals, panelPlayers, panelPlaces}

local function togglePanel(target)
    for _, p in ipairs(panels) do
        if p == target then
            p.Visible = not p.Visible
        else
            p.Visible = false
        end
    end
end

btnPortals.MouseButton1Click:Connect(function() togglePanel(panelPortals) end)
btnPlayers.MouseButton1Click:Connect(function() togglePanel(panelPlayers); rebuildPlayerList() end)
btnPlaces.MouseButton1Click:Connect(function() togglePanel(panelPlaces) end)--[[
    PortalClient.client.lua
    Положить в: StarterPlayerScripts (StarterPlayer -> StarterPlayerScripts)
    Один единственный LocalScript обслуживает ОБА предмета:
        - "Portal gun jr"
        - "Technology for creating portal balls"
    Ничего внутрь самих Tool класть не нужно — они создаются сервером.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local remotes = ReplicatedStorage:WaitForChild("PortalRemotes")
local FirePortal = remotes:WaitForChild("FirePortal")
local PrepareBalls = remotes:WaitForChild("PrepareBalls")

local MAX_BALLS = 10
local ballParts = {} -- визуальные шарики текущей экипированной "Portal gun jr"
local isPreparing = false

----------------------------------------------------------------
-- Живое обновление колбы "Portal gun jr" при изменении PortalBalls
----------------------------------------------------------------
local function refreshBallVisuals()
    local current = player:GetAttribute("PortalBalls") or 0
    for i, ball in ipairs(ballParts) do
        local visible = i <= current
        ball.Transparency = visible and 0 or 1
        local l = ball:FindFirstChildOfClass("PointLight")
        if l then l.Enabled = visible end
    end
end

player:GetAttributeChangedSignal("PortalBalls"):Connect(refreshBallVisuals)

----------------------------------------------------------------
-- Анимация изготовления шариков (для "Technology for creating portal balls")
----------------------------------------------------------------
local function playPrepareAnimation(handle)
    local folder = Instance.new("Folder")
    folder.Name = "PrepareBallsScene"
    folder.Parent = workspace

    for i = 1, 10 do
        local ball = Instance.new("Part")
        ball.Shape = Enum.PartType.Ball
        ball.Anchored = true
        ball.CanCollide = false
        ball.Material = Enum.Material.Neon
        ball.Color = Color3.fromRGB(170, 255, 150)
        ball.Size = Vector3.new(0.05, 0.05, 0.05)

        local angle = (i / 10) * math.pi * 2
        local radius = 0.15
        local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
        ball.CFrame = handle.CFrame * CFrame.new(0, 0.6, 0) * CFrame.new(offset)
        ball.Transparency = 1
        ball.Parent = folder

        local light = Instance.new("PointLight")
        light.Color = ball.Color
        light.Range = 1.5
        light.Brightness = 2
        light.Parent = ball

        TweenService:Create(ball, TweenInfo.new(0.15), {Transparency = 0}):Play()
        task.wait(0.12)
    end

    task.wait(0.8)
    folder:Destroy()
end

----------------------------------------------------------------
-- Подключение обработчиков к конкретному инструменту
----------------------------------------------------------------
local function setupPortalGunJr(tool)
    local handle = tool:WaitForChild("Handle")

    tool.Equipped:Connect(function()
        ballParts = {}
        local flask = handle:FindFirstChild("MiniFlask")
        if flask then
            for _, child in ipairs(flask:GetChildren()) do
                if child.Name == "PortalBallVisual" then
                    table.insert(ballParts, child)
                end
            end
            table.sort(ballParts, function(a, b)
                return (a.Position - flask.Position).Magnitude < (b.Position - flask.Position).Magnitude
            end)
        end
        refreshBallVisuals()
    end)

    tool.Unequipped:Connect(function()
        ballParts = {}
    end)

    tool.Activated:Connect(function()
        local hit = mouse.Hit
        if not hit then return end
        FirePortal:FireServer(tool.Name, hit)
    end)
end

local function setupBallTechTool(tool)
    local handle = tool:WaitForChild("Handle")

    tool.Activated:Connect(function()
        if isPreparing then return end
        isPreparing = true

        playPrepareAnimation(handle)
        PrepareBalls:FireServer()

        task.wait(0.5)
        isPreparing = false
    end)
end

local function onToolAdded(tool)
    if not tool:IsA("Tool") then return end
    if tool.Name == "Portal gun jr" then
        setupPortalGunJr(tool)
    elseif tool.Name == "Technology for creating portal balls" then
        setupBallTechTool(tool)
    end
end

----------------------------------------------------------------
-- Подписка на Backpack и персонажа — ловим оба инструмента, когда они появляются
----------------------------------------------------------------
local function watchContainer(container)
    for _, child in ipairs(container:GetChildren()) do
        onToolAdded(child)
    end
    container.ChildAdded:Connect(onToolAdded)
end

local backpack = player:WaitForChild("Backpack")
watchContainer(backpack)

player.CharacterAdded:Connect(function(char)
    watchContainer(char)
end)
if player.Character then
    watchContainer(player.Character)
end

----------------------------------------------------------------
-- Уведомление "шарики закончились"
----------------------------------------------------------------
FirePortal.OnClientEvent:Connect(function(msg)
    if msg == "OUT_OF_BALLS" then
        local playerGui = player:WaitForChild("PlayerGui")
        local hud = playerGui:FindFirstChild("PortalHUD")
        if hud then
            local notice = hud:FindFirstChild("NoBallsNotice")
            if notice then
                notice.Visible = true
                task.delay(3, function() notice.Visible = false end)
            end
        end
    end
end)
