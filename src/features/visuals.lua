--!strict
--[[
    BBC HUB - Feature: Visuals
    Aba VISUAIS: ESP, interface do jogo e efeitos locais.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

local Library = BBC.Library
local Utils = BBC.Utils
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Defensive: Ensure Library.Fonts exists before any UI code accesses it
local InitUtils = BBC.Modules["utils.init"]
if InitUtils and InitUtils.ensureFonts then
    InitUtils.ensureFonts(Library)
end

local create = Utils.create
local corner = Utils.corner
local stroke = Utils.stroke
local bind = Utils.bind
local label = Utils.label
local icon = Utils.icon
local pad = Utils.pad
local listLayout = Utils.listLayout
local tween = Utils.tween

-- ============================================================
--  SetupCharacterPreview: 2D R6 Chams/ESP Preview Builder
--  Injeta a pré-visualização dentro de um Frame existente (previewContainer)
-- ============================================================
local function SetupCharacterPreview(previewContainer)
    -- Colors
    local CHAMS_COLOR = Color3.fromRGB(255, 130, 0)
    local CHAMS_TRANSPARENCY = 0.45
    local STROKE_COLOR = Color3.fromRGB(0, 0, 0)
    local STROKE_TRANSPARENCY = 0.35
    local STROKE_THICKNESS = 1
    local BOX_STROKE_COLOR = Color3.fromRGB(255, 140, 0)
    local SKELETON_COLOR = Color3.fromRGB(255, 255, 255)
    local SKELETON_THICKNESS = 1.5
    local HEALTH_BAR_WIDTH = 4
    local HEALTH_BAR_COLOR = Color3.fromRGB(45, 205, 190)
    local HEALTH_BAR_BG = Color3.fromRGB(0, 0, 0)
    local SHADOW_COLOR = Color3.fromRGB(0, 0, 0)

    -- 1. Character Holder (reduzido e centralizado no terço superior, acima da grade 2x4)
    local holder = create("Frame", {
        Name = "PreviewHolder",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(100, 108),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.3),
    }, previewContainer)

    -- 2. R6 Chams Silhouette
    local chamsParts = {}

    local function createChamsPart(name, size, position, cornerRadius)
        local part = create("Frame", {
            Name = name,
            BackgroundColor3 = CHAMS_COLOR,
            BackgroundTransparency = CHAMS_TRANSPARENCY,
            Size = size,
            Position = position,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, holder)

        corner(part, cornerRadius or 4)

        -- Contorno escuro de 1px (independente do tema, igual ao outline do Chams no jogo)
        create("UIStroke", {
            Thickness = STROKE_THICKNESS,
            Transparency = STROKE_TRANSPARENCY,
            Color = STROKE_COLOR,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, part)

        -- Add BBC HUB logo on Torso (asset se configurado; senão, logo em texto)
        if name == "Torso" then
            local logoAssetId = BBC.Config and BBC.Config.LogoAssetId
            if logoAssetId and type(logoAssetId) == "string" and #logoAssetId > 0 then
                local logo = create("ImageLabel", {
                    Name = "BBCLogo",
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(0.6, 0.6),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Image = logoAssetId,
                    ImageColor3 = Color3.fromRGB(255, 255, 255),
                    ImageTransparency = 0.3,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 3,
                }, part)
            else
                create("TextLabel", {
                    Name = "BBCLogo",
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(0.92, 0.55),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Text = "BBC HUB",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextTransparency = 0.25,
                    TextScaled = true,
                    FontFace = (Library.Fonts and Library.Fonts.Bold) or Enum.Font.GothamBold,
                    ZIndex = 3,
                }, part)
            end
        end

        chamsParts[name] = part
        return part
    end

    createChamsPart("Head",     UDim2.fromScale(0.28, 0.18), UDim2.fromScale(0.36, 0.02), 8)
    createChamsPart("Torso",    UDim2.fromScale(0.46, 0.36), UDim2.fromScale(0.27, 0.22), 4)
    createChamsPart("LeftArm",  UDim2.fromScale(0.20, 0.36), UDim2.fromScale(0.04, 0.22), 4)
    createChamsPart("RightArm", UDim2.fromScale(0.20, 0.36), UDim2.fromScale(0.76, 0.22), 4)
    createChamsPart("LeftLeg",  UDim2.fromScale(0.21, 0.38), UDim2.fromScale(0.27, 0.60), 4)
    createChamsPart("RightLeg", UDim2.fromScale(0.21, 0.38), UDim2.fromScale(0.52, 0.60), 4)

    -- Sombra/glow sutil no chão (elipse escura sob os pés, atrás do boneco)
    local floorShadow = create("Frame", {
        Name = "FloorShadow",
        BackgroundColor3 = SHADOW_COLOR,
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

    -- 3. ESP Overlays
    -- Bounding Box
    local boundingBox = create("Frame", {
        Name = "BoundingBox",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        ZIndex = 3,
    }, holder)

    local boxStroke = stroke(boundingBox, "Accent", 0, 1)
    boxStroke.Color = BOX_STROKE_COLOR

    -- Skeleton Lines
    local skeletonLines = {}

    -- Joint positions (relative to holder scale 0-1)
    local joints = {
        HeadTop     = Vector2.new(0.5, 0.02),
        Neck        = Vector2.new(0.5, 0.21),
        LeftShoulder  = Vector2.new(0.27, 0.22),
        RightShoulder = Vector2.new(0.73, 0.22),
        LeftHand    = Vector2.new(0.14, 0.58),
        RightHand   = Vector2.new(0.86, 0.58),
        Pelvis      = Vector2.new(0.5, 0.59),
        LeftFoot    = Vector2.new(0.375, 0.98),
        RightFoot   = Vector2.new(0.625, 0.98),
    }

    -- Pares de juntas na ordem em que as linhas são criadas
    local jointPairs = {
        { joints.HeadTop, joints.Neck },
        { joints.Neck, joints.Pelvis },
        { joints.LeftShoulder, joints.RightShoulder },
        { joints.LeftShoulder, joints.LeftHand },
        { joints.RightShoulder, joints.RightHand },
        { joints.Pelvis, joints.LeftFoot },
        { joints.Pelvis, joints.RightFoot },
    }

    -- Comprimento/ângulo em PIXELS (antes usava a escala 0-1 e as linhas ficavam invisíveis)
    local function lineSpec(p1, p2)
        local abs = holder.AbsoluteSize
        local dx = (p2.X - p1.X) * abs.X
        local dy = (p2.Y - p1.Y) * abs.Y
        return math.sqrt(dx * dx + dy * dy), math.deg(math.atan2(dy, dx))
    end

    local function drawLine(p1, p2)
        local dist, angle = lineSpec(p1, p2)

        local line = create("Frame", {
            BackgroundColor3 = SKELETON_COLOR,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(dist, SKELETON_THICKNESS),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(p1.X, p1.Y),
            Rotation = angle,
            ZIndex = 4,
        }, holder)

        skeletonLines[#skeletonLines + 1] = line
        return line
    end

    local function buildSkeleton()
        for _, pair in ipairs(jointPairs) do
            drawLine(pair[1], pair[2])
        end
    end
    buildSkeleton()

    -- Health Bar (left side of box; altura em escala para não depender de AbsoluteSize)
    local healthBarBg = create("Frame", {
        Name = "HealthBarBg",
        BackgroundColor3 = HEALTH_BAR_BG,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Size = UDim2.new(0, HEALTH_BAR_WIDTH, 1, 0),
        Position = UDim2.fromScale(0, 0),
        AnchorPoint = Vector2.new(1, 0),
        ZIndex = 3,
        Visible = false,
    }, holder)

    local healthBarFill = create("Frame", {
        Name = "HealthBarFill",
        BackgroundColor3 = HEALTH_BAR_COLOR,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 4,
    }, healthBarBg)

    -- Labels
    local nameLabel = create("TextLabel", {
        Name = "NameLabel",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.fromScale(0.5, -0.03),
        AnchorPoint = Vector2.new(0.5, 1),
        Text = "Jogador",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 16,
        FontFace = Library.Fonts.Bold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 5,
    }, holder)

    local nameStroke = stroke(nameLabel, "Stroke", 0, 1)
    nameStroke.Color = Color3.fromRGB(0, 0, 0)

    local distanceLabel = create("TextLabel", {
        Name = "DistanceLabel",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.fromScale(0.5, 1.03),
        AnchorPoint = Vector2.new(0.5, 0),
        Text = "1133m",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        TextSize = 10,
        FontFace = Library.Fonts.Medium,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 5,
    }, holder)

    local distStroke = stroke(distanceLabel, "Stroke", 0, 1)
    distStroke.Color = Color3.fromRGB(0, 0, 0)

    -- 4. Controller API
    local state = {
        chams = true,
        box = true,
        skeleton = true,
        name = true,
        distance = true,
        healthbar = true,
        health = true,
        color = CHAMS_COLOR,
        previewHealth = 100,
        previewDistance = "1133m",
    }

    local function applyColor(c)
        for _, part in pairs(chamsParts) do
            part.BackgroundColor3 = c
        end
        for _, line in ipairs(skeletonLines) do
            line.BackgroundColor3 = c
        end
        boxStroke.Color = Color3.fromRGB(
            math.floor(c.R * 255 * 0.85),
            math.floor(c.G * 255 * 0.85),
            math.floor(c.B * 255 * 0.85)
        )
        healthBarFill.BackgroundColor3 = c
    end

    local function updateHealthBar()
        local ratio = math.clamp(state.previewHealth / 100, 0, 1)
        healthBarBg.Size = UDim2.new(0, HEALTH_BAR_WIDTH, 1, 0)
        healthBarBg.Position = UDim2.fromScale(0, 0)
        healthBarFill.Size = UDim2.fromScale(1, ratio)
    end

    -- Re-sincroniza overlays dependentes de tamanho quando o holder muda de tamanho
    -- (esqueleto em pixels e barra de vida), cobrindo o caso de layout inicial.
    holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        for i, pair in ipairs(jointPairs) do
            local line = skeletonLines[i]
            if line then
                local dist, angle = lineSpec(pair[1], pair[2])
                line.Size = UDim2.fromOffset(dist, SKELETON_THICKNESS)
                line.Rotation = angle
            end
        end
        if state.healthbar then updateHealthBar() end
    end)

    local controller = {}

    function controller.SetChams(enabled)
        state.chams = enabled
        for _, part in pairs(chamsParts) do
            part.Visible = enabled
        end
    end

    function controller.SetBox(enabled)
        state.box = enabled
        boundingBox.Visible = enabled
    end

    function controller.SetSkeleton(enabled)
        state.skeleton = enabled
        for _, line in ipairs(skeletonLines) do
            line.Visible = enabled
        end
    end

    function controller.SetName(enabled)
        state.name = enabled
        nameLabel.Visible = enabled
    end

    function controller.SetDistance(enabled)
        state.distance = enabled
        distanceLabel.Visible = enabled
    end

    function controller.SetHealthBar(enabled)
        state.healthbar = enabled
        healthBarBg.Visible = enabled
        if enabled then updateHealthBar() end
    end

    function controller.SetHealth(enabled)
        state.health = enabled
    end

    function controller.SetColor(c)
        state.color = c
        applyColor(c)
    end

    function controller.SetPreviewHealth(hp)
        state.previewHealth = math.clamp(hp, 0, 100)
        if state.healthbar then updateHealthBar() end
    end

    function controller.SetPreviewDistance(dist)
        state.previewDistance = dist
        distanceLabel.Text = dist
    end

    -- Draggable repositioning for preview elements
    local dragElements = {
        nameLabel = nameLabel,
        distanceLabel = distanceLabel,
        healthBarBg = healthBarBg,
        boundingBox = boundingBox,
    }
    local dragOffsets = {}

    local function makeDraggable(element, elementName)
        local dragging = false
        local dragStart = nil
        local startPos = nil

        local function updatePosition(input)
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            element.Position = newPos
            dragOffsets[elementName] = { X = newPos.X.Offset, Y = newPos.Y.Offset }
        end

        element.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = element.Position
                element.ZIndex = 10
            end
        end)

        element.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updatePosition(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    element.ZIndex = elementName == "boundingBox" and 3 or elementName == "healthBarBg" and 3 or 5
                end
            end
        end)
    end

    for name, elem in pairs(dragElements) do
        makeDraggable(elem, name)
    end

    function controller.GetDragOffsets()
        return dragOffsets
    end

    function controller.SetDragOffsets(offsets)
        dragOffsets = offsets or {}
        for name, offset in pairs(dragOffsets) do
            local elem = dragElements[name]
            if elem and offset then
                elem.Position = UDim2.new(elem.Position.X.Scale, offset.X, elem.Position.Y.Scale, offset.Y)
            end
        end
    end

    -- Initialize
    controller.SetChams(state.chams)
    controller.SetBox(state.box)
    controller.SetSkeleton(state.skeleton)
    controller.SetName(state.name)
    controller.SetDistance(state.distance)
    controller.SetHealthBar(state.healthbar)
    controller.SetHealth(state.health)
    controller.SetPreviewHealth(state.previewHealth)
    controller.SetPreviewDistance(state.previewDistance)

    return controller
end

-- ============================================================
--  Build ESP Panel with Preview + Settings (Modal Layout)
-- ============================================================
local function buildEspPanel(kind)
    return function(m)
        local Library = BBC.Library
        local S = Library.ESP and Library.ESP[kind]
        if not S then return end

        local L = m.Left
        local R = m.Right

        -- ============================================================
        --  LEFT SIDE: PRÉVIA
        -- ============================================================
        -- Header is now created by Window:_getModal with headerExtras (3 action icons: layout-grid, lock, star)

        -- Central Preview Frame (dark background with soft glow)
        local previewFrame = create("Frame", {
            Name = "PreviewFrame",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(200, 268),
            BackgroundColor3 = Color3.fromRGB(15, 15, 20),
            BorderSizePixel = 0,
            ClipsDescendants = true,
        }, L)
        corner(previewFrame, 8)
        local previewStroke = stroke(previewFrame, "Accent", 0.2, 1)
        previewStroke.Color = Color3.fromRGB(255, 130, 0)

        -- Soft center glow (gradient)
        local glow = create("Frame", {
            Name = "Glow",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.2, 1.2),
            BackgroundTransparency = 1,
            ZIndex = -1,
        }, previewFrame)
        local glowGrad = create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 130, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 130, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 20)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.95),
                NumberSequenceKeypoint.new(0.5, 0.85),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Rotation = 45,
        }, glow)

        -- Preview Container inside the frame
        local previewContainer = create("Frame", {
            Name = "ESPPreviewContainer",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.95, 0.95),
            BackgroundTransparency = 1,
        }, previewFrame)

        -- Build the character preview inside the container
        local previewController = SetupCharacterPreview(previewContainer)

        -- Store controller for external access
        Library.ESPPreviewControllers = Library.ESPPreviewControllers or {}
        Library.ESPPreviewControllers[kind] = previewController

        -- Quick-Toggle Button Grid at Preview Bottom (2 rows x 4 cols)
        -- 64px = 2 linhas de 30 + 1 gap de 4; fica 3px acima do container
        -- (~8px de respiro até a borda laranja) e abaixo do rótulo de distância.
        local toggleButtonsFrame = create("Frame", {
            Name = "QuickTogglesGrid",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -3),
            Size = UDim2.new(1, 0, 0, 64),
        }, previewContainer)
        local gridLayout = create("UIGridLayout", {
            CellSize = UDim2.fromOffset(44, 30),
            CellPadding = UDim2.fromOffset(4, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            StartCorner = Enum.StartCorner.TopLeft,
            FillDirectionMaxCells = 4,
        }, toggleButtonsFrame)

        local quickToggles = {
            { key = "highlight", label = "Destaque", setter = function(v) previewController.SetChams(v) end },
            { key = "box", label = "Caixa", setter = function(v) previewController.SetBox(v) end },
            { key = "name", label = "Nome", setter = function(v) previewController.SetName(v) end },
            { key = "healthbar", label = "Barra vida", setter = function(v) previewController.SetHealthBar(v) end },
            { key = "health", label = "Vida", setter = function(v) previewController.SetHealth(v) end },
            { key = "distance", label = "Distância", setter = function(v) previewController.SetDistance(v) end },
            -- "Linhas" (tracers) só existe no jogo: a flag S.tracers.on já é escrita pelo handler abaixo
            { key = "tracers", label = "Linhas" },
            { key = "skeleton", label = "Esqueleto", setter = function(v) previewController.SetSkeleton(v) end },
        }

        for i, tgl in ipairs(quickToggles) do
            local isEnabled = S[tgl.key] and S[tgl.key].on or false
            local btn = create("TextButton", {
                Name = "Toggle_" .. tgl.key,
                BackgroundColor3 = isEnabled and Library.Theme.Accent or Library.Theme.Surface2,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(44, 30),
                Text = tgl.label,
                TextColor3 = isEnabled and Color3.new(1,1,1) or Library.Theme.Text,
                TextSize = 9,
                FontFace = Library.Fonts.Medium,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                TextWrapped = true,
                TextScaled = true,
                TextTruncate = Enum.TextTruncate.None,
                ClipsDescendants = false,
                LayoutOrder = i,
                AutoButtonColor = false,
            }, toggleButtonsFrame)
            corner(btn, 4)
            local btnStroke = stroke(btn, "Stroke", 0, 1)
            btnStroke.Color = isEnabled and Library.Theme.Accent or Library.Theme.Stroke

            -- Ensure text doesn't overflow
            local textConstraint = create("UITextSizeConstraint", {
                MinTextSize = 7,
                MaxTextSize = 10,
            }, btn)

            btn.MouseButton1Click:Connect(function()
                isEnabled = not isEnabled
                if S[tgl.key] then S[tgl.key].on = isEnabled end
                if tgl.setter then tgl.setter(isEnabled) end
                btn.BackgroundColor3 = isEnabled and Library.Theme.Accent or Library.Theme.Surface2
                btn.TextColor3 = isEnabled and Color3.new(1,1,1) or Library.Theme.Text
                btnStroke.Color = isEnabled and Library.Theme.Accent or Library.Theme.Stroke
            end)

            -- Bind theme colors
            bind(btn, "BackgroundColor3", isEnabled and "Accent" or "Surface2")
            bind(btn, "TextColor3", isEnabled and "Text" or "Text")
            bind(btnStroke, "Color", isEnabled and "Accent" or "Stroke")
        end

        -- ============================================================
        --  RIGHT SIDE: AJUSTES DO JOGADOR
        -- ============================================================
        -- Header is now created by Window:_getModal with headerExtras (gear icon + X close)

        -- Scrolling content area (modal header is 28px + 4px separator = 32px, scroll starts at 32)
        local rightScroll = create("ScrollingFrame", {
            Name = "SettingsScroll",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 32),
            Size = UDim2.new(1, 0, 1, -32 - 50), -- Leave space for footer
            ScrollBarThickness = 2,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ClipsDescendants = true,
        }, m.RightBox)
        bind(rightScroll, "ScrollBarImageColor3", "Accent")
        local rsLayout = listLayout(rightScroll, 4)
        rsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        pad(rightScroll, 8, 8, 4, 4)

        local rightPanel = setmetatable({ List = rightScroll, _order = 0, Window = m.Right.Window, _path = m.Right._path .. "/settings" }, BBC.UI.Container)

        -- General settings foldout
        local fold = rightPanel:Foldout({ Name = "Configurações gerais", Build = function(p)
            p:Slider({ Name = "Distância máx.", Min = 100, Max = 3000, Default = 1000, Suffix = "m", Step = 50, Callback = function(v) S.maxDist = v end })
            p:Slider({ Name = "Tamanho do texto", Min = 9, Max = 16, Default = 10, Callback = function(v) S.textSize = v end })
            p:Slider({ Name = "Distância da prévia", Min = 10, Max = 2000, Default = 1133, Suffix = "m", Step = 1, Callback = function(v) S.prevDist = v; previewController.SetPreviewDistance(v .. "m") end })
            p:Slider({ Name = "Vida da prévia", Min = 0, Max = 100, Default = 100, Callback = function(v) S.prevHp = v; previewController.SetPreviewHealth(v) end })
            p:Toggle({ Name = "Só detalhes de perto", Default = true, Tooltip = "Longe, mostra só um ponto e a distância. Perto, mostra tudo.", Callback = function(v) S.lod.on = v end })
            p:Slider({ Name = "Detalhes até", Min = 20, Max = 1000, Default = 150, Suffix = "m", Step = 10, Callback = function(v) S.lod.near = v end })
            p:Toggle({ Name = "Destacar mais próximo", Default = false, Tooltip = "O alvo mais perto de você ganha outra cor e uma seta em cima.",
                Callback = function(v) S.nearest.on = v end,
                Settings = function(q) q:ColorPicker({ Name = "Cor", Default = S.nearest.color, Callback = function(c) S.nearest.color = c end }) end })
        end })

        -- Vertical toggle list with gear icons
        local function addToggle(key, labelText, extraSettings)
            local isEnabled = S[key] and S[key].on or false
            local toggle = rightPanel:Toggle({ Name = labelText, Default = isEnabled, Callback = function(v)
                if S[key] then S[key].on = v end
                -- Sync with preview controller
                if key == "highlight" then previewController.SetChams(v)
                elseif key == "box" then previewController.SetBox(v)
                elseif key == "skeleton" then previewController.SetSkeleton(v)
                elseif key == "name" then previewController.SetName(v)
                elseif key == "distance" then previewController.SetDistance(v)
                elseif key == "healthbar" then previewController.SetHealthBar(v)
                elseif key == "health" then previewController.SetHealth(v)
                end
            end,
            Settings = function(p)
                if S[key] then
                    p:ColorPicker({ Name = "Cor", Default = S[key].color, Callback = function(c)
                        if S[key] then S[key].color = c end
                        if key == "highlight" or key == "box" or key == "skeleton" then
                            previewController.SetColor(c)
                        end
                    end })
                end
                if extraSettings then extraSettings(p) end
            end })
        end

        addToggle("highlight", "Destaque", function(p)
            p:Slider({ Name = "Preenchimento", Min = 5, Max = 90, Default = 60, Suffix = "%", Callback = function(v) if S.highlight then S.highlight.alpha = v / 100 end end })
            p:Slider({ Name = "Contorno", Min = 0, Max = 4, Default = 2, Step = 0.5, Callback = function(v) if S.highlight then S.highlight.outline = v end end })
        end)
        addToggle("box", "Caixa", function(p)
            p:Dropdown({ Name = "Estilo", Options = { "Cantos", "Completa" }, Default = "Completa", Callback = function(v) if S.box then S.box.style = v end end })
            p:Slider({ Name = "Espessura", Min = 1, Max = 5, Default = 1, Callback = function(v) if S.box then S.box.thick = v end end })
            p:Slider({ Name = "Opacidade", Min = 10, Max = 100, Default = 50, Suffix = "%", Callback = function(v) if S.box then S.box.alpha = v / 100 end end })
            p:Slider({ Name = "Tamanho do canto", Min = 6, Max = 30, Default = 14, Callback = function(v) if S.box then S.box.corner = v end end })
        end)
        addToggle("name", "Nome")
        addToggle("healthbar", "Barra de vida", function(p)
            p:Toggle({ Name = "Cor automática", Default = true, Callback = function(v) if S.healthbar then S.healthbar.auto = v end end })
            p:Dropdown({ Name = "Posição", Options = { "Esquerda", "Direita" }, Default = "Esquerda", Callback = function(v) if S.healthbar then S.healthbar.side = v end end })
            p:Slider({ Name = "Largura da barra", Min = 2, Max = 10, Default = 2, Callback = function(v) if S.healthbar then S.healthbar.width = v end end })
        end)
        addToggle("health", "Vida")
        addToggle("distance", "Distância", function(p)
            p:Dropdown({ Name = "Unidade", Options = { "m", "studs" }, Default = "m", Callback = function(v) if S.distance then S.distance.unit = v end end })
        end)
        addToggle("tracers", "Linhas até alvos", function(p)
            p:Dropdown({ Name = "Origem", Options = { "Baixo", "Cima" }, Default = "Baixo", Callback = function(v) if S.tracers then S.tracers.origin = v end end })
            p:Slider({ Name = "Espessura", Min = 1, Max = 4, Default = 1, Callback = function(v) if S.tracers then S.tracers.thick = v end end })
        end)
        addToggle("skeleton", "Esqueleto", function(p)
            p:Slider({ Name = "Espessura", Min = 1, Max = 4, Default = 1.5, Step = 0.5, Callback = function(v) if S.skeleton then S.skeleton.thick = v end end })
        end)

        -- Fixed footer with touch hints
        local footer = create("Frame", {
            Name = "SettingsFooter",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -4),
            Size = UDim2.new(1, -16, 0, 40),
        }, m.RightBox)
        local footerLayout = listLayout(footer, 2)
        footerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        footerLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

        local hint1 = label(footer, "Toque: ativar", 10, "Muted", false, { Size = UDim2.fromOffset(100, 14), TextXAlignment = Enum.TextXAlignment.Right })
        local hint2 = label(footer, "Arraste: mover", 10, "Muted", false, { Size = UDim2.fromOffset(100, 14), TextXAlignment = Enum.TextXAlignment.Right })
        local hint3 = label(footer, "Segure: ajustes", 10, "Muted", false, { Size = UDim2.fromOffset(100, 14), TextXAlignment = Enum.TextXAlignment.Right })
    end
end

Features.buildEspPanel = buildEspPanel

-- ============================================================
--  Build Visuals Tab
-- ============================================================
function Features.buildVisuals(window)
    local visuals = window:Tab({ Name = "VISUAIS", Icon = "eye" })

    local group = visuals:Groupbox({ Name = "ESP", Icon = "scan-eye", Side = "Left" })
    for _, name in ipairs({ "Jogador", "NPCs", "Corpo", "Recipiente", "Item no chão", "Itens de missão" }) do
        T(group, name, name == "Jogador" or name == "NPCs" or name == "Corpo")
    end

    group = visuals:Groupbox({ Name = "INTERFACE DO JOGO", Icon = "layout-dashboard", Side = "Right" })
    T(group, "Mochila personalizada")
    T(group, "Mochila")
    T(group, "Barra rápida", true)

    group = visuals:Groupbox({
        Name = "LOCAL",
        Icon = "map-pin",
        Side = "Right",
        Checkbox = true,
        Default = true,
        Callback = function() end,
    })
    for _, name in ipairs({ "Aura", "Círculo de salto", "Auréola", "Rastro estelar" }) do
        T(group, name)
    end

    return visuals
end

return { buildVisuals = Features.buildVisuals }