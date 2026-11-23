--!strict
--[[
    BBC HUB - ESP engine

    Owns the Roblox-side ESP visuals. Configuration lives in utils.esp_config,
    while the model registry is centralized in utils.esp_runtime so a character
    can never receive more than one Highlight.
]]

local Engine = {}

local ESPConfig = BBC.Modules["utils.esp_config"]
local ESPLogic = BBC.Modules["utils.esp_logic"]
local ESPRuntime = BBC.Modules["utils.esp_runtime"]

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local FEATURE_KEYS = {
    highlight = true,
    box = true,
    name = true,
    healthbar = true,
    health = true,
    distance = true,
    tracers = true,
    skeleton = true,
}

local R15 = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local R6 = {
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local MAX_TARGETS = 24

local runtime: any = nil
local espGui: any = nil
local markHolder: any = nil
local started = false
local registered = false
local stopped = false
local errorCount = 0
local renderConnection: any = nil
local unsubscribeConfig: (() -> ())? = nil
local unsubscribePanic: (() -> ())? = nil
local npcScanStarted = false
local npcScanConnection: any = nil
local npcs: { [any]: any } = {}
local modelHeights: { [any]: { height: number, updatedAt: number } } = {}
local playerConnections: { any } = {}
local hookedPlayers: { [any]: boolean } = {}

local function log(message)
    warn("[BBC][ESP] " .. tostring(message))
end

local function library()
    return BBC.Library
end

local function globalState()
    if type(getgenv) ~= "function" then
        return nil
    end
    local ok, state = pcall(getgenv)
    if ok and type(state) == "table" then
        return state
    end
    return nil
end

local function ensureConfig()
    local lib = library()
    if not lib or not ESPConfig then
        return nil
    end
    return ESPConfig.ensureDefaults(lib)
end

local function anyFeatureEnabled(settings)
    if type(settings) ~= "table" then
        return false
    end
    for key in pairs(FEATURE_KEYS) do
        local feature = settings[key]
        if type(feature) == "table" and feature.on == true then
            return true
        end
    end
    return false
end

local function featureFromPath(path)
    local root = string.match(tostring(path or ""), "^([^%.]+)")
    if root and FEATURE_KEYS[root] then
        return root
    end
    return nil
end

local function guiParent()
    if type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok and parent then
            return parent
        end
    end

    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        return playerGui
    end
    return nil
end

local function make(className, properties, parent)
    local instance = Instance.new(className)
    for key, value in pairs(properties) do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end

local function isPlayerOwned(model)
    if model == nil then
        return false
    end
    local ok, player = pcall(function()
        return Players:GetPlayerFromCharacter(model)
    end)
    return ok and player ~= nil
end

local function hideSkeleton(drawing)
    for _, line in ipairs(drawing.skel) do
        line.Visible = false
    end
    drawing.skelOn = false
end

local function hideDraw(drawing)
    if not drawing then
        return
    end
    drawing.root.Visible = false
    if drawing.hl then
        drawing.hl.Enabled = false
    end
    drawing.boxFull.Visible = false
    for _, cornerFrame in ipairs(drawing.corners) do
        cornerFrame.Visible = false
    end
    drawing.hbBg.Visible = false
    drawing.name.Visible = false
    drawing.hp.Visible = false
    drawing.dist.Visible = false
    drawing.near.Visible = false
    drawing.tracer.Visible = false
    drawing.dot.Visible = false
    hideSkeleton(drawing)
end

local function hideFeature(drawing, feature)
    if not drawing then
        return
    end

    if feature == "highlight" and drawing.hl then
        drawing.hl.Enabled = false
    elseif feature == "box" then
        drawing.boxFull.Visible = false
        for _, cornerFrame in ipairs(drawing.corners) do
            cornerFrame.Visible = false
        end
    elseif feature == "name" then
        drawing.name.Visible = false
    elseif feature == "healthbar" then
        drawing.hbBg.Visible = false
    elseif feature == "health" then
        drawing.hp.Visible = false
    elseif feature == "distance" then
        drawing.dist.Visible = false
    elseif feature == "tracers" then
        drawing.tracer.Visible = false
    elseif feature == "skeleton" then
        hideSkeleton(drawing)
    end
end

local function newDraw()
    local drawing = { skel = {}, skelOn = false }

    drawing.root = make("Frame", {
        Name = "ESPDrawing",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Active = false,
    }, espGui)

    drawing.boxFull = make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        Active = false,
    }, drawing.root)

    drawing.boxStroke = make("UIStroke", { Thickness = 1 }, drawing.boxFull)
    drawing.corners = {}
    for index = 1, 8 do
        drawing.corners[index] = make("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            Active = false,
        }, drawing.root)
    end

    drawing.hbBg = make("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Visible = false,
        Active = false,
    }, drawing.root)

    drawing.hbFill = make("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
    }, drawing.hbBg)

    local fonts = library().Fonts
    local font = fonts and (fonts.Code or fonts.Medium or fonts.Regular)
    local function textLabel(anchor)
        return make("TextLabel", {
            BackgroundTransparency = 1,
            FontFace = font,
            TextStrokeTransparency = 0.3,
            TextStrokeColor3 = Color3.new(0, 0, 0),
            AnchorPoint = anchor,
            Size = UDim2.fromOffset(120, 14),
            Visible = false,
            TextColor3 = Color3.new(1, 1, 1),
            Active = false,
        }, drawing.root)
    end

    drawing.name = textLabel(Vector2.new(0.5, 1))
    drawing.hp = textLabel(Vector2.new(1, 0.5))
    drawing.dist = textLabel(Vector2.new(0.5, 0))
    drawing.near = textLabel(Vector2.new(0.5, 1))
    drawing.near.Text = "▼"

    drawing.tracer = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        Visible = false,
        Active = false,
    }, drawing.root)

    drawing.dot = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(8, 8),
        BorderSizePixel = 0,
        Visible = false,
        Active = false,
    }, drawing.root)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, drawing.dot)

    drawing.hideAll = function()
        hideDraw(drawing)
    end

    drawing.hideFeature = function(feature)
        hideFeature(drawing, feature)
    end

    drawing.destroy = function()
        drawing.root:Destroy()
    end

    return drawing
end

local function hpColor(settings, ratio)
    if not settings.healthbar.auto then
        return settings.healthbar.color
    end
    if ratio > 0.6 then
        return Color3.fromRGB(45, 205, 190)
    elseif ratio > 0.3 then
        return Color3.fromRGB(240, 200, 60)
    end
    return Color3.fromRGB(240, 80, 70)
end

local function lineTo(frame, x0, y0, x1, y1, thickness, color)
    local deltaX, deltaY = x1 - x0, y1 - y0
    frame.Size = UDim2.fromOffset(math.sqrt(deltaX * deltaX + deltaY * deltaY), thickness)
    frame.Position = UDim2.fromOffset((x0 + x1) / 2, (y0 + y1) / 2)
    frame.Rotation = math.deg(math.atan2(deltaY, deltaX))
    frame.BackgroundColor3 = color
    frame.Visible = true
end

local function modelHeight(model)
    local now = os.clock()
    local cached = modelHeights[model]
    if cached and now - cached.updatedAt < 0.5 then
        return cached.height
    end

    local ok, size = pcall(function()
        return model:GetExtentsSize()
    end)
    local height = ok and size and size.Y or 5
    modelHeights[model] = { height = height, updatedAt = now }
    return height
end

local function drawTarget(drawing, target, settings, camera, viewport, isNearest)
    hideDraw(drawing)

    local model = target.model
    local humanoid = target.hum
    if not model or not humanoid or not camera then
        return
    end

    local height3D = modelHeight(model)
    local center = target.hrp and target.hrp.Position or model:GetPivot().Position
    local topPoint = camera:WorldToViewportPoint(center + Vector3.new(0, height3D / 2, 0))
    local bottomPoint = camera:WorldToViewportPoint(center - Vector3.new(0, height3D / 2, 0))

    local onScreen = topPoint.Z > 0
        and bottomPoint.Z > 0
        and topPoint.X > -60
        and topPoint.X < viewport.X + 60
        and topPoint.Y > -120
        and bottomPoint.Y < viewport.Y + 120
    if not onScreen then
        if drawing.hl then
            drawing.hl.Enabled = false
        end
        return
    end

    local nearest = isNearest and settings.nearest.on == true
    local nearestColor = settings.nearest.color
    local featureColor = nearest and nearestColor or settings.highlight.color
    local top, bottom = topPoint.Y, bottomPoint.Y
    local height = math.max(bottom - top, 8)
    local width = height * 0.55
    local centerX = topPoint.X
    local left = centerX - width / 2
    local far = settings.lod.on and target.m > settings.lod.near

    drawing.root.Visible = true

    if drawing.hl then
        drawing.hl.Adornee = model
        drawing.hl.Enabled = settings.highlight.on and not far
        drawing.hl.FillColor = featureColor
        drawing.hl.FillTransparency = settings.highlight.fillTransparency
        drawing.hl.OutlineColor = settings.highlight.outlineColor
        drawing.hl.OutlineTransparency = settings.highlight.outlineTransparency
    end

    local distanceText = settings.distance.unit == "studs"
        and (math.floor(target.studs) .. " st")
        or (math.floor(target.m) .. "m")

    if far then
        drawing.dot.Visible = true
        drawing.dot.BackgroundColor3 = nearest and nearestColor or settings.box.color
        drawing.dot.Position = UDim2.fromOffset(centerX, (top + bottom) / 2)
        if settings.distance.on then
            local distanceSize = ESPLogic.scaledTextSize(settings, settings.distance.size)
            drawing.dist.Visible = true
            drawing.dist.Text = distanceText
            drawing.dist.TextSize = distanceSize
            drawing.dist.TextColor3 = settings.distance.color
            drawing.dist.TextStrokeTransparency = settings.distance.outline and 0.3 or 1
            drawing.dist.Size = UDim2.fromOffset(120, distanceSize + 2)
            drawing.dist.Position = UDim2.fromOffset(centerX - drawing.dist.TextBounds.X / 2, (top + bottom) / 2 + 6)
        end
    else
        if settings.box.on then
            local thickness = settings.box.thick
            if settings.box.style == "Completa" then
                drawing.boxFull.Visible = true
                drawing.boxFull.Position = UDim2.fromOffset(left, top)
                drawing.boxFull.Size = UDim2.fromOffset(width, height)
                drawing.boxStroke.Color = nearest and nearestColor or settings.box.color
                drawing.boxStroke.Thickness = thickness
                drawing.boxStroke.Transparency = 1 - settings.box.alpha
            else
                local cornerLength = math.min(settings.box.corner, width / 2, height / 2)
                local segments = {
                    { left, top, cornerLength, thickness },
                    { left, top, thickness, cornerLength },
                    { left + width - cornerLength, top, cornerLength, thickness },
                    { left + width - thickness, top, thickness, cornerLength },
                    { left, top + height - thickness, cornerLength, thickness },
                    { left, top + height - cornerLength, thickness, cornerLength },
                    { left + width - cornerLength, top + height - thickness, cornerLength, thickness },
                    { left + width - thickness, top + height - cornerLength, thickness, cornerLength },
                }
                for index = 1, 8 do
                    local frame = drawing.corners[index]
                    local segment = segments[index]
                    frame.Visible = true
                    frame.BackgroundColor3 = nearest and nearestColor or settings.box.color
                    frame.BackgroundTransparency = 1 - settings.box.alpha
                    frame.Position = UDim2.fromOffset(segment[1], segment[2])
                    frame.Size = UDim2.fromOffset(segment[3], segment[4])
                end
            end
        end

        local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
        if settings.healthbar.on then
            local barWidth = settings.healthbar.width
            local barX = settings.healthbar.side == "Direita"
                and (left + width + 3)
                or (left - 3 - barWidth)
            drawing.hbBg.Visible = true
            drawing.hbBg.Position = UDim2.fromOffset(barX, top)
            drawing.hbBg.Size = UDim2.fromOffset(barWidth, height)
            drawing.hbFill.Size = UDim2.fromScale(1, ratio)
            drawing.hbFill.BackgroundColor3 = hpColor(settings, ratio)
        end

        if settings.health.on then
            drawing.hp.Visible = true
            drawing.hp.Text = tostring(math.floor(humanoid.Health))
            drawing.hp.TextSize = ESPLogic.scaledTextSize(settings, settings.health.size)
            drawing.hp.TextColor3 = settings.healthbar.auto and ratio <= 0.6
                and hpColor(settings, ratio)
                or settings.health.color
            drawing.hp.Position = UDim2.fromOffset(
                left - 5 - (settings.healthbar.on and settings.healthbar.width or 0),
                (top + bottom) / 2
            )
        end

        if nearest then
            drawing.near.Visible = true
            drawing.near.TextSize = ESPLogic.scaledTextSize(settings, settings.textSize + 2)
            drawing.near.TextColor3 = nearestColor
            drawing.near.Position = UDim2.fromOffset(centerX, top - 2 - (settings.name.on and (settings.textSize + 3) or 0))
        end

        if settings.name.on then
            local nameSize = ESPLogic.scaledTextSize(settings, settings.name.size)
            drawing.name.Visible = true
            drawing.name.Text = target.name
            drawing.name.TextSize = nameSize
            drawing.name.TextColor3 = settings.name.color
            drawing.name.TextStrokeTransparency = settings.name.outline and 0.3 or 1
            drawing.name.Size = UDim2.fromOffset(200, nameSize + 2)
            drawing.name.Position = UDim2.fromOffset(centerX - drawing.name.TextBounds.X / 2, top - 2)
        end

        if settings.distance.on then
            local distanceSize = ESPLogic.scaledTextSize(settings, settings.distance.size)
            drawing.dist.Visible = true
            drawing.dist.Text = distanceText
            drawing.dist.TextSize = distanceSize
            drawing.dist.TextColor3 = settings.distance.color
            drawing.dist.TextStrokeTransparency = settings.distance.outline and 0.3 or 1
            drawing.dist.Size = UDim2.fromOffset(120, distanceSize + 2)
            drawing.dist.Position = UDim2.fromOffset(centerX - drawing.dist.TextBounds.X / 2, bottom + 2)
        end

        if settings.skeleton.on then
            local joints = model:FindFirstChild("UpperTorso") and R15 or R6
            drawing.skelOn = true
            for index, pair in ipairs(joints) do
                local line = drawing.skel[index]
                if not line then
                    line = make("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BorderSizePixel = 0,
                        Active = false,
                    }, drawing.root)
                    drawing.skel[index] = line
                end
                local first = model:FindFirstChild(pair[1])
                local second = model:FindFirstChild(pair[2])
                if first and second and first:IsA("BasePart") and second:IsA("BasePart") then
                    local firstPoint = camera:WorldToViewportPoint(first.Position)
                    local secondPoint = camera:WorldToViewportPoint(second.Position)
                    if firstPoint.Z > 0 and secondPoint.Z > 0 then
                        lineTo(
                            line,
                            firstPoint.X,
                            firstPoint.Y,
                            secondPoint.X,
                            secondPoint.Y,
                            settings.skeleton.thick,
                            nearest and nearestColor or settings.skeleton.color
                        )
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
            for index = #joints + 1, #drawing.skel do
                drawing.skel[index].Visible = false
            end
        end
    end

    if settings.tracers.on then
        local originY = viewport.Y
        if settings.tracers.origin == "Cima" or settings.tracers.origin == "Topo" then
            originY = 0
        elseif settings.tracers.origin == "Centro" then
            originY = viewport.Y / 2
        end
        lineTo(
            drawing.tracer,
            viewport.X / 2,
            originY,
            centerX,
            settings.tracers.origin == "Cima" and top or bottom,
            settings.tracers.thick,
            nearest and nearestColor or settings.tracers.color
        )
    end
end

local function addHumanoid(humanoid)
    if not humanoid or not humanoid:IsA("Humanoid") then
        return
    end
    local model = humanoid.Parent
    if not model or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
        return
    end
    if model:FindFirstAncestorWhichIsA("ViewportFrame") then
        return
    end
    local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if not rootPart or not rootPart:IsA("BasePart") then
        return
    end
    if not isPlayerOwned(model) then
        npcs[model] = humanoid
    end
end

local function startNpcScan()
    if npcScanStarted then
        return
    end
    npcScanStarted = true

    task.spawn(function()
        local count = 0
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            addHumanoid(descendant)
            count += 1
            if count % 400 == 0 then
                task.wait()
            end
        end
    end)

    npcScanConnection = Workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Humanoid") then
            task.defer(addHumanoid, descendant)
        end
    end)
end

local function gatherPlayers(output)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if character and humanoid and rootPart then
                output[#output + 1] = {
                    model = character,
                    hum = humanoid,
                    hrp = rootPart,
                    player = player,
                    name = player.DisplayName ~= "" and player.DisplayName or player.Name,
                    stableId = tostring(player.UserId),
                }
            end
        end
    end
end

local function cleanupNpcs()
    for model in pairs(npcs) do
        if not model.Parent or not model:IsDescendantOf(Workspace) then
            npcs[model] = nil
        end
    end
end

local function gatherNpcs(output)
    startNpcScan()
    for model, humanoid in pairs(npcs) do
        if not model.Parent or not model:IsDescendantOf(Workspace) then
            npcs[model] = nil
        elseif not isPlayerOwned(model) and model ~= LocalPlayer.Character then
            local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            if rootPart and rootPart:IsA("BasePart") and humanoid.Parent then
                output[#output + 1] = {
                    model = model,
                    hum = humanoid,
                    hrp = rootPart,
                    player = nil,
                    name = model.Name,
                    stableId = tostring(model),
                }
            end
        end
    end
end

local function candidateSettings(candidate)
    local lib = library()
    return lib and lib.ESP and lib.ESP[candidate.kind]
end

local function renderFrame()
    if not runtime or stopped then
        return
    end

    local lib = library()
    if not lib or lib.Panic then
        runtime:forEachKind("Jogador", hideDraw)
        runtime:forEachKind("NPCs", hideDraw)
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end
    local viewport = camera.ViewportSize
    cleanupNpcs()
    local playerCandidates, npcCandidates = {}, {}

    local playerSettings = lib.ESP and lib.ESP.Jogador
    if playerSettings and playerSettings.enabled and anyFeatureEnabled(playerSettings) then
        gatherPlayers(playerCandidates)
    end

    local npcSettings = lib.ESP and lib.ESP.NPCs
    if npcSettings and npcSettings.enabled and anyFeatureEnabled(npcSettings) then
        gatherNpcs(npcCandidates)
    end

    local reconciled = ESPLogic.reconcileCandidates(playerCandidates, npcCandidates, LocalPlayer.Character)
    local visible = {}

    for _, entry in ipairs(reconciled) do
        local candidate = entry.candidate
        local settings = candidateSettings(entry)
        if candidate.model and candidate.model.Parent and candidate.hum and candidate.hum.Parent then
            local rootPart = candidate.hrp
            if rootPart and rootPart.Parent and rootPart:IsA("BasePart")
                and ESPConfig.shouldIncludeTarget(candidate, LocalPlayer, settings)
            then
                candidate.studs = (rootPart.Position - camera.CFrame.Position).Magnitude
                candidate.m = candidate.studs * 0.28
                if candidate.m <= settings.maxDist then
                    visible[#visible + 1] = candidate
                end
            end
        end
    end

    local selected = ESPLogic.selectTargets(visible, MAX_TARGETS)
    local seen = {}

    for index, candidate in ipairs(selected) do
        local model = candidate.model
        seen[model] = true
        local drawing = runtime:getDrawing(model)
        if not drawing then
            drawing = newDraw()
            drawing.model = model
        end
        runtime:register(model, candidate.kind, drawing)
        drawing.kind = candidate.kind

        local settings = candidateSettings(candidate)
        if settings.highlight.on then
            local highlight = runtime:ensureHighlight(model, function()
                local instance = make("Highlight", {
                    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                    Enabled = false,
                }, markHolder)
                return instance
            end)
            drawing.hl = highlight
        elseif drawing.hl then
            drawing.hl.Enabled = false
        end
        drawTarget(drawing, candidate, settings, camera, viewport, index == 1)
    end

    runtime:forEachKind("Jogador", function(drawing)
        if not seen[drawing.model] then
            hideDraw(drawing)
            if drawing.model and not drawing.model.Parent then
                modelHeights[drawing.model] = nil
                runtime:release(drawing.model)
            end
        end
    end)
    runtime:forEachKind("NPCs", function(drawing)
        if not seen[drawing.model] then
            hideDraw(drawing)
            if drawing.model and not drawing.model.Parent then
                modelHeights[drawing.model] = nil
                runtime:release(drawing.model)
            end
        end
    end)
end

local function onConfigChanged(kind, path, value)
    if not runtime then
        return
    end

    if path == "enabled" and value == false then
        runtime:releaseKind(kind)
        return
    end

    local feature = featureFromPath(path)
    if feature and value == false then
        runtime:hideFeature(kind, feature)
    end

    renderFrame()
end

function Engine.start()
    if started then
        return true
    end

    local state = globalState()
    if state and state.BBC_HUB and state.BBC_HUB.ESP
        and type(state.BBC_HUB.ESP.stop) == "function"
        and state.BBC_HUB.ESP.instance ~= Engine
    then
        pcall(function() state.BBC_HUB.ESP.stop() end)
    end

    local lib = library()
    if not lib or not ESPConfig or not ESPLogic or not ESPRuntime then
        log("dependências indisponíveis")
        return false
    end
    ensureConfig()

    local parent = guiParent()
    if not parent then
        log("PlayerGui indisponível")
        return false
    end

    espGui = make("ScreenGui", {
        Name = "BBCESP",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 990,
    }, parent)
    markHolder = make("Folder", { Name = "BBCMarks" }, Workspace)

    runtime = ESPRuntime.new()
    -- BindToClose é exclusivo do servidor; no cliente (Delta/UNC) use
    -- eventos de ciclo de vida do cliente, protegidos com pcall.
    local okClose, closeConn = pcall(function()
        return espGui.Destroying:Connect(function()
            Engine.stop()
        end)
    end)
    if not okClose then
        warn("[BBC][ESP] falha ao registrar limpeza do cliente: " .. tostring(closeConn))
    end
    started = true
    stopped = false
    errorCount = 0
    unsubscribeConfig = ESPConfig.onChange(onConfigChanged)
    if lib.OnPanic then
        unsubscribePanic = lib:OnPanic(function(isPanic)
            if not isPanic then
                renderFrame()
                return
            end
            if runtime then
                runtime:forEachKind("Jogador", hideDraw)
                runtime:forEachKind("NPCs", hideDraw)
            end
        end)
    end

    local function releasePlayerCharacter(player)
        if player and player.Character and runtime then
            runtime:release(player.Character)
        end
    end

    local function hookPlayer(player)
        if not player or hookedPlayers[player] then
            return
        end
        hookedPlayers[player] = true
        if player.CharacterRemoving then
            table.insert(playerConnections, player.CharacterRemoving:Connect(function(character)
                if runtime then
                    runtime:release(character)
                end
            end))
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        hookPlayer(player)
    end
    table.insert(playerConnections, Players.PlayerAdded:Connect(hookPlayer))
    table.insert(playerConnections, Players.PlayerRemoving:Connect(releasePlayerCharacter))

    renderConnection = RunService.RenderStepped:Connect(function()
        if stopped then
            return
        end
        local ok, err = pcall(renderFrame)
        if not ok then
            errorCount += 1
            log(tostring(err))
            if errorCount >= 5 then
                stopped = true
                runtime:forEachKind("Jogador", hideDraw)
                runtime:forEachKind("NPCs", hideDraw)
                if lib.Notify then
                    lib:Notify({
                        Title = "BBC HUB",
                        Content = "O ESP parou por causa de um erro (veja o console).",
                        Duration = 5,
                    })
                end
            end
        end
    end)

    if state then
        state.BBC_HUB = state.BBC_HUB or {}
        state.BBC_HUB.ESP = {
            instance = Engine,
            stop = Engine.stop,
        }
    end

    return true
end

function Engine.stop()
    stopped = true
    started = false

    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    if npcScanConnection then
        npcScanConnection:Disconnect()
        npcScanConnection = nil
    end
    for _, connection in ipairs(playerConnections) do
        connection:Disconnect()
    end
    table.clear(playerConnections)
    table.clear(hookedPlayers)
    if unsubscribeConfig then
        unsubscribeConfig()
        unsubscribeConfig = nil
    end
    if unsubscribePanic then
        unsubscribePanic()
        unsubscribePanic = nil
    end
    if runtime then
        runtime:destroyAll()
        runtime = nil
    end
    if espGui then
        espGui:Destroy()
        espGui = nil
    end
    if markHolder then
        markHolder:Destroy()
        markHolder = nil
    end
    npcScanStarted = false
    table.clear(npcs)
end

function Engine.register()
    if registered then
        return true
    end

    local lib = library()
    if not lib or not ESPConfig then
        return false
    end
    ensureConfig()
    lib.Features = lib.Features or {}

    local function setMaster(kind, enabled)
        ESPConfig.set(kind, "enabled", enabled == true)
        Engine.start()
    end

    lib.Features["Jogador"] = function(enabled)
        setMaster("Jogador", enabled)
    end
    lib.Features["NPCs"] = function(enabled)
        setMaster("NPCs", enabled)
    end
    lib.Features["Corpo"] = function(enabled)
        setMaster("Corpo", enabled)
    end
    lib.Features["Recipiente"] = function(enabled)
        setMaster("Recipiente", enabled)
    end
    lib.Features["Item no chão"] = function(enabled)
        setMaster("Item no chão", enabled)
    end
    lib.Features["Itens de missão"] = function(enabled)
        setMaster("Itens de missão", enabled)
    end

    local legacyFeatures = {
        { "Destaque", "highlight" },
        { "Caixa", "box" },
        { "Nome", "name" },
        { "Barra de vida", "healthbar" },
        { "Vida", "health" },
        { "Distância", "distance" },
        { "Linhas", "tracers" },
        { "Esqueleto", "skeleton" },
    }
    for _, entry in ipairs(legacyFeatures) do
        lib.Features[entry[1]] = function(enabled)
            ESPConfig.set("Jogador", entry[2] .. ".on", enabled == true)
            Engine.start()
        end
    end

    lib.Features["Destaque próprio"] = function(enabled)
        ESPConfig.set("Jogador", "nearest.on", enabled == true)
    end

    registered = true

    -- The row state in the visuals tab is created before this deferred
    -- registration can run. Mirror that state into the canonical ESP config.
    for _, kind in ipairs({ "Jogador", "NPCs", "Corpo", "Recipiente", "Item no chão", "Itens de missão" }) do
        if lib.FS[kind] ~= nil then
            ESPConfig.set(kind, "enabled", lib.FS[kind] == true)
        end
    end

    Engine.start()
    return true
end

function Engine.setFeature(kind, feature, enabled)
    if not ESPConfig then
        return false
    end
    local value = ESPConfig.set(kind, feature .. ".on", enabled == true)
    Engine.start()
    return value ~= nil
end

function Engine.isStarted()
    return started == true
end

BBC.Features.ESPEngine = Engine
return Engine
