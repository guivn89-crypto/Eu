--!strict
--[[
    BBC HUB - Live R6 ESP preview

    The preview reads the same configuration used by the in-game ESP engine.
    It is intentionally instance-based so it remains compatible with mobile
    executors that do not expose the Drawing API.
]]

local Preview = {}

local Utils = BBC.Utils
local Library = BBC.Library
local ESPLogic = BBC.Modules["utils.esp_logic"]
local UserInputService = game:GetService("UserInputService")

local create = Utils.create
local corner = Utils.corner
local stroke = Utils.stroke

local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(242, 242, 242)
local CYAN = Color3.fromRGB(45, 205, 190)

local function clampHealth(value)
    return math.clamp(tonumber(value) or 0, 0, 100)
end

local function healthRatio(value)
    return clampHealth(value) / 100
end

local function healthColor(settings, ratio)
    if not settings.healthbar.auto then
        return settings.healthbar.color
    end
    if ratio > 0.6 then
        return CYAN
    elseif ratio > 0.3 then
        return Color3.fromRGB(240, 200, 60)
    end
    return Color3.fromRGB(240, 80, 70)
end

local function formatDistance(settings, distance)
    if settings.distance.unit == "studs" then
        return tostring(math.floor(distance)) .. " st"
    end
    return tostring(math.floor(distance)) .. "m"
end

function Preview.build(previewContainer, initialSettings)
    local settings = initialSettings or {}
    local state = {
        enabled = settings.enabled == true,
        previewHealth = settings.prevHp or 100,
        previewDistance = settings.prevDist or 1133,
        dragOffsets = {},
    }

    local holder = create("Frame", {
        Name = "PreviewHolder",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(100, 108),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.3),
    }, previewContainer)

    local chamsParts = {}
    local chamsStrokes = {}

    local function createChamsPart(name, size, position, cornerRadius)
        local part = create("Frame", {
            Name = name,
            BackgroundColor3 = settings.highlight and settings.highlight.color or WHITE,
            BackgroundTransparency = settings.highlight and settings.highlight.fillTransparency or 0.55,
            Size = size,
            Position = position,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, holder)
        corner(part, cornerRadius or 4)

        -- Subtle vertical shading gives the R6 silhouette depth while the
        -- border remains a crisp, fully opaque 1px black outline.
        create("UIGradient", {
            Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(185, 185, 185)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 0.24),
            }),
            Rotation = 0,
        }, part)

        local outline = create("UIStroke", {
            Thickness = 1,
            Transparency = 0,
            Color = BLACK,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, part)

        chamsParts[name] = part
        chamsStrokes[name] = outline
        return part
    end

    createChamsPart("Head", UDim2.fromScale(0.28, 0.18), UDim2.fromScale(0.36, 0.02), 8)
    local torso = createChamsPart("Torso", UDim2.fromScale(0.46, 0.36), UDim2.fromScale(0.27, 0.22), 4)
    createChamsPart("LeftArm", UDim2.fromScale(0.20, 0.36), UDim2.fromScale(0.04, 0.22), 4)
    createChamsPart("RightArm", UDim2.fromScale(0.20, 0.36), UDim2.fromScale(0.76, 0.22), 4)
    createChamsPart("LeftLeg", UDim2.fromScale(0.21, 0.38), UDim2.fromScale(0.27, 0.60), 4)
    createChamsPart("RightLeg", UDim2.fromScale(0.21, 0.38), UDim2.fromScale(0.52, 0.60), 4)

    -- Centered BBC HUB badge.
    local badge = create("Frame", {
        Name = "BBCBadge",
        BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.18,
        Size = UDim2.fromScale(0.84, 0.40),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
        ZIndex = 3,
    }, torso)
    corner(badge, 3)
    create("UIStroke", {
        Thickness = 1,
        Transparency = 0.15,
        Color = WHITE,
    }, badge)
    create("TextLabel", {
        Name = "BBCLogo",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "BBC HUB",
        TextColor3 = WHITE,
        TextScaled = true,
        FontFace = (Library.Fonts and Library.Fonts.Bold) or Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 4,
    }, badge)

    local floorShadow = create("Frame", {
        Name = "FloorShadow",
        BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 1.0),
        Size = UDim2.fromScale(0.64, 0.05),
        ZIndex = 1,
    }, holder)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, floorShadow)
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, floorShadow)

    local dragLayer = create("Frame", {
        Name = "PreviewOverlayLayer",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Active = true,
        ZIndex = 3,
    }, holder)

    local boundingBox = create("Frame", {
        Name = "BoundingBox",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
    }, dragLayer)
    local boxStroke = stroke(boundingBox, "Accent", 0, 1)
    boxStroke.Thickness = 1

    local boxCorners = {}
    for index = 1, 8 do
        boxCorners[index] = create("Frame", {
            Name = "BoxCorner" .. index,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 4,
        }, dragLayer)
    end

    local joints = {
        HeadTop = Vector2.new(0.5, 0.02),
        Neck = Vector2.new(0.5, 0.21),
        LeftShoulder = Vector2.new(0.27, 0.22),
        RightShoulder = Vector2.new(0.73, 0.22),
        LeftElbow = Vector2.new(0.14, 0.40),
        RightElbow = Vector2.new(0.86, 0.40),
        LeftHand = Vector2.new(0.14, 0.58),
        RightHand = Vector2.new(0.86, 0.58),
        Pelvis = Vector2.new(0.5, 0.59),
        LeftKnee = Vector2.new(0.375, 0.78),
        RightKnee = Vector2.new(0.625, 0.78),
        LeftFoot = Vector2.new(0.375, 0.98),
        RightFoot = Vector2.new(0.625, 0.98),
    }
    local jointPairs = {
        { joints.HeadTop, joints.Neck },
        { joints.Neck, joints.Pelvis },
        { joints.LeftShoulder, joints.RightShoulder },
        { joints.LeftShoulder, joints.LeftElbow },
        { joints.LeftElbow, joints.LeftHand },
        { joints.RightShoulder, joints.RightElbow },
        { joints.RightElbow, joints.RightHand },
        { joints.Pelvis, joints.LeftKnee },
        { joints.LeftKnee, joints.LeftFoot },
        { joints.Pelvis, joints.RightKnee },
        { joints.RightKnee, joints.RightFoot },
    }

    local function lineGeometry(first, second, width, height)
        local deltaX = (second.X - first.X) * width
        local deltaY = (second.Y - first.Y) * height
        return math.sqrt(deltaX * deltaX + deltaY * deltaY), math.deg(math.atan2(deltaY, deltaX))
    end

    local function positionLine(frame, first, second, thickness)
        local length, angle = lineGeometry(first, second, holder.AbsoluteSize.X, holder.AbsoluteSize.Y)
        frame.Size = UDim2.fromOffset(length, thickness)
        frame.Position = UDim2.fromScale(first.X, first.Y)
        frame.Rotation = angle
    end

    local skeletonLines = {}
    for index, pair in ipairs(jointPairs) do
        local line = create("Frame", {
            Name = "SkeletonLine" .. index,
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(1, 1),
            AnchorPoint = Vector2.new(0, 0.5),
            ZIndex = 4,
        }, holder)
        positionLine(line, pair[1], pair[2], 1.5)
        skeletonLines[index] = line
    end

    local jointDots = {}
    for name, point in pairs(joints) do
        local dot = create("Frame", {
            Name = "Joint_" .. name,
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(4, 4),
            Position = UDim2.fromScale(point.X, point.Y),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 5,
        }, holder)
        corner(dot, 2)
        create("UIStroke", {
            Thickness = 1,
            Color = BLACK,
            Transparency = 0,
        }, dot)
        jointDots[name] = dot
    end

    local healthBarBg = create("Frame", {
        Name = "HealthBarBg",
        BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 4, 1, 0),
        Position = UDim2.fromScale(0, 0),
        AnchorPoint = Vector2.new(1, 0),
        ZIndex = 4,
        Visible = false,
    }, dragLayer)
    local healthBarFill = create("Frame", {
        Name = "HealthBarFill",
        BackgroundColor3 = CYAN,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
    }, healthBarBg)

    local healthLabel = create("TextLabel", {
        Name = "HealthLabel",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(32, 14),
        Position = UDim2.fromScale(0, 0.5),
        AnchorPoint = Vector2.new(0, 0.5),
        Text = "100",
        TextColor3 = WHITE,
        TextSize = 10,
        FontFace = (Library.Fonts and Library.Fonts.Medium) or Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextStrokeTransparency = 0.3,
        TextStrokeColor3 = BLACK,
        ZIndex = 6,
    }, dragLayer)

    local nameLabel = create("TextLabel", {
        Name = "NameLabel",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.fromScale(0.5, -0.03),
        AnchorPoint = Vector2.new(0.5, 1),
        Text = "Jogador",
        TextColor3 = WHITE,
        TextSize = 16,
        FontFace = (Library.Fonts and Library.Fonts.Bold) or Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextStrokeTransparency = 0.3,
        TextStrokeColor3 = BLACK,
        ZIndex = 6,
    }, dragLayer)

    local distanceLabel = create("TextLabel", {
        Name = "DistanceLabel",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.fromScale(0.5, 1.03),
        AnchorPoint = Vector2.new(0.5, 0),
        Text = "1133m",
        TextColor3 = WHITE,
        TextSize = 10,
        FontFace = (Library.Fonts and Library.Fonts.Medium) or Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextStrokeTransparency = 0.3,
        TextStrokeColor3 = BLACK,
        ZIndex = 6,
    }, dragLayer)

    local tracer = create("Frame", {
        Name = "Tracer",
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(1, 1),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Visible = false,
        ZIndex = 4,
    }, dragLayer)

    local function updateSkeletonGeometry()
        for index, pair in ipairs(jointPairs) do
            positionLine(skeletonLines[index], pair[1], pair[2], settings.skeleton and settings.skeleton.thick or 1.5)
        end
    end

    local function updateHealthBar()
        local ratio = healthRatio(state.previewHealth)
        local width = settings.healthbar and settings.healthbar.width or 4
        local onRight = settings.healthbar and settings.healthbar.side == "Direita"
        healthBarBg.Size = UDim2.new(0, width, 1, 0)
        healthBarBg.AnchorPoint = onRight and Vector2.new(0, 0) or Vector2.new(1, 0)
        healthBarBg.Position = onRight and UDim2.fromScale(1, 0) or UDim2.fromScale(0, 0)
        healthBarFill.Size = UDim2.fromScale(1, ratio)
        healthBarFill.BackgroundColor3 = healthColor(settings, ratio)
        healthLabel.Text = tostring(math.floor(clampHealth(state.previewHealth)))
        healthLabel.AnchorPoint = onRight and Vector2.new(0, 0.5) or Vector2.new(1, 0.5)
        healthLabel.Position = onRight
            and UDim2.fromScale(1.03, 0.5)
            or UDim2.fromScale(-0.03, 0.5)
        healthLabel.TextXAlignment = onRight and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    end

    local function updateBoxCorners()
        local cornerSize = settings.box and settings.box.corner or 14
        local width = holder.AbsoluteSize.X
        local height = holder.AbsoluteSize.Y
        local length = math.min(cornerSize, width / 2, height / 2)
        local thickness = settings.box and settings.box.thick or 1
        local segments = {
            { 0, 0, length, thickness },
            { 0, 0, thickness, length },
            { width - length, 0, length, thickness },
            { width - thickness, 0, thickness, length },
            { 0, height - thickness, length, thickness },
            { 0, height - length, thickness, length },
            { width - length, height - thickness, length, thickness },
            { width - thickness, height - length, thickness, length },
        }
        for index = 1, 8 do
            local frame = boxCorners[index]
            local segment = segments[index]
            frame.Position = UDim2.fromOffset(segment[1], segment[2])
            frame.Size = UDim2.fromOffset(segment[3], segment[4])
            frame.BackgroundColor3 = settings.box and settings.box.color or WHITE
            frame.BackgroundTransparency = settings.box and (1 - settings.box.alpha) or 0.5
        end
    end

    local function updateTracer()
        local origin = Vector2.new(0.5, 1.08)
        local target = Vector2.new(0.5, 0.56)
        local length, angle = lineGeometry(origin, target, holder.AbsoluteSize.X, holder.AbsoluteSize.Y)
        tracer.Size = UDim2.fromOffset(length, settings.tracers and settings.tracers.thick or 1)
        tracer.Position = UDim2.fromScale((origin.X + target.X) / 2, (origin.Y + target.Y) / 2)
        tracer.Rotation = angle
        tracer.BackgroundColor3 = settings.tracers and settings.tracers.color or WHITE
    end

    local function applyVisibility()
        local enabled = state.enabled
        local highlightOn = enabled and settings.highlight and settings.highlight.on
        local boxOn = enabled and settings.box and settings.box.on
        local nameOn = enabled and settings.name and settings.name.on
        local healthBarOn = enabled and settings.healthbar and settings.healthbar.on
        local healthOn = enabled and settings.health and settings.health.on
        local distanceOn = enabled and settings.distance and settings.distance.on
        local tracerOn = enabled and settings.tracers and settings.tracers.on
        local skeletonOn = enabled and settings.skeleton and settings.skeleton.on

        for _, part in pairs(chamsParts) do
            part.Visible = highlightOn == true
        end
        boundingBox.Visible = boxOn == true
        for _, frame in ipairs(boxCorners) do
            frame.Visible = false
        end
        if boxOn and settings.box.style == "Cantos" then
            for _, frame in ipairs(boxCorners) do
                frame.Visible = true
            end
        end
        nameLabel.Visible = nameOn == true
        healthBarBg.Visible = healthBarOn == true
        healthLabel.Visible = healthOn == true
        distanceLabel.Visible = distanceOn == true
        tracer.Visible = tracerOn == true
        for _, line in ipairs(skeletonLines) do
            line.Visible = skeletonOn == true
        end
        for _, dot in pairs(jointDots) do
            dot.Visible = skeletonOn == true
        end
    end

    local function applySettings(nextSettings)
        if type(nextSettings) == "table" then
            settings = nextSettings
        end
        state.enabled = settings.enabled == true
        state.previewHealth = clampHealth(settings.prevHp or state.previewHealth)
        state.previewDistance = tonumber(settings.prevDist) or state.previewDistance

        if settings.highlight then
            for _, part in pairs(chamsParts) do
                part.BackgroundColor3 = settings.highlight.color
                part.BackgroundTransparency = settings.highlight.fillTransparency
            end
        end
        if settings.box then
            boxStroke.Color = settings.box.color
            boxStroke.Thickness = settings.box.thick
            boxStroke.Transparency = 1 - settings.box.alpha
        end
        if settings.name then
            local nameSize = ESPLogic.scaledTextSize(settings, settings.name.size)
            nameLabel.TextColor3 = settings.name.color
            nameLabel.TextSize = nameSize
            nameLabel.Size = UDim2.new(1, 0, 0, nameSize + 4)
            nameLabel.TextStrokeTransparency = settings.name.outline and 0.3 or 1
        end
        if settings.health then
            local healthSize = ESPLogic.scaledTextSize(settings, settings.health.size)
            healthLabel.TextColor3 = settings.health.color
            healthLabel.TextSize = healthSize
            healthLabel.Size = UDim2.fromOffset(math.max(32, healthSize + 18), healthSize + 2)
        end
        if settings.distance then
            local distanceSize = ESPLogic.scaledTextSize(settings, settings.distance.size)
            distanceLabel.TextColor3 = settings.distance.color
            distanceLabel.TextSize = distanceSize
            distanceLabel.Size = UDim2.new(1, 0, 0, distanceSize + 2)
            distanceLabel.TextStrokeTransparency = settings.distance.outline and 0.3 or 1
            distanceLabel.Text = formatDistance(settings, state.previewDistance)
        end
        if settings.tracers then
            tracer.BackgroundColor3 = settings.tracers.color
        end
        if settings.skeleton then
            for _, line in ipairs(skeletonLines) do
                line.BackgroundColor3 = settings.skeleton.color
            end
            for _, dot in pairs(jointDots) do
                dot.BackgroundColor3 = settings.skeleton.color
            end
        end

        updateHealthBar()
        updateBoxCorners()
        updateSkeletonGeometry()
        updateTracer()
        applyVisibility()
    end

    local dragging = false
    local dragStart = nil
    local startPosition = nil
    local locked = false

    dragLayer.InputBegan:Connect(function(input)
        local inputType = input.UserInputType
        if locked then return end
        if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = dragLayer.Position
        end
    end)
    dragLayer.InputChanged:Connect(function(input)
        local inputType = input.UserInputType
        if dragging and (inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            dragLayer.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
            state.dragOffsets = {
                X = dragLayer.Position.X.Offset,
                Y = dragLayer.Position.Y.Offset,
            }
        end
    end)
    local inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
        local inputType = input.UserInputType
        if dragging and (inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch) then
            dragging = false
        end
    end)

    local sizeConnection = holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        updateSkeletonGeometry()
        updateBoxCorners()
        updateTracer()
    end)

    local function disconnectExternalConnections()
        if inputEndedConnection then
            inputEndedConnection:Disconnect()
            inputEndedConnection = nil
        end
        if sizeConnection then
            sizeConnection:Disconnect()
            sizeConnection = nil
        end
    end
    holder.Destroying:Connect(disconnectExternalConnections)

    local controller = {}

    function controller.ApplySettings(nextSettings)
        applySettings(nextSettings)
    end

    function controller.SetEnabled(enabled)
        state.enabled = enabled == true
        applyVisibility()
    end

    function controller.SetLocked(value)
        locked = value == true
        if locked then
            dragging = false
        end
    end

    function controller.IsLocked()
        return locked
    end

    function controller.ResetLayout()
        dragLayer.Position = UDim2.fromScale(0, 0)
        state.dragOffsets = { X = 0, Y = 0 }
    end

    function controller.SetPreviewHealth(value)
        state.previewHealth = clampHealth(value)
        updateHealthBar()
    end

    function controller.SetPreviewDistance(value)
        state.previewDistance = tonumber(value) or 0
        distanceLabel.Text = formatDistance(settings, state.previewDistance)
    end

    function controller.GetDragOffsets()
        return state.dragOffsets
    end

    function controller.SetDragOffsets(offsets)
        if type(offsets) == "table" and type(offsets.X) == "number" and type(offsets.Y) == "number" then
            state.dragOffsets = offsets
            dragLayer.Position = UDim2.new(0, offsets.X, 0, offsets.Y)
        end
    end

    applySettings(settings)
    return controller
end

Preview.healthRatio = healthRatio
Preview.formatDistance = formatDistance

return Preview
