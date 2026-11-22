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

local create = Utils.create
local corner = Utils.corner
local stroke = Utils.stroke
local bind = Utils.bind
local label = Utils.label
local icon = Utils.icon

-- ============================================================
--  SetupCharacterPreview: 2D R6 Chams/ESP Preview Builder
--  Injeta a pré-visualização dentro de um Frame existente (previewContainer)
-- ============================================================
local function SetupCharacterPreview(previewContainer)
    local CHAMS_COLOR = Color3.fromRGB(255, 130, 0)
    local CHAMS_TRANSPARENCY = 0.45
    local STROKE_COLOR = Color3.fromRGB(255, 165, 0)
    local STROKE_THICKNESS = 1.5
    local BOX_STROKE_COLOR = Color3.fromRGB(255, 140, 0)
    local SKELETON_COLOR = Color3.fromRGB(255, 255, 255)
    local SKELETON_THICKNESS = 1.5

    -- 1. Character Holder (centralizado no container)
    local holder = create("Frame", {
        Name = "PreviewHolder",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(130, 200),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
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

        local partStroke = stroke(part, "Accent", 0, STROKE_THICKNESS)
        partStroke.Color = STROKE_COLOR

        chamsParts[name] = part
        return part
    end

    createChamsPart("Head",     UDim2.fromScale(0.28, 0.18), UDim2.fromScale(0.36, 0.02), 8)
    createChamsPart("Torso",    UDim2.fromScale(0.46, 0.36), UDim2.fromScale(0.27, 0.22), 4)
    createChamsPart("LeftArm",  UDim2.fromScale(0.20, 0.36), UDim2.fromScale(0.04, 0.22), 4)
    createChamsPart("RightArm", UDim2.fromScale(0.20, 0.36), UDim2.fromScale(0.76, 0.22), 4)
    createChamsPart("LeftLeg",  UDim2.fromScale(0.21, 0.38), UDim2.fromScale(0.27, 0.60), 4)
    createChamsPart("RightLeg", UDim2.fromScale(0.21, 0.38), UDim2.fromScale(0.52, 0.60), 4)

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

    local function drawLine(p1, p2)
        local dx = p2.X - p1.X
        local dy = p2.Y - p1.Y
        local dist = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(dy, dx)

        local line = create("Frame", {
            BackgroundColor3 = SKELETON_COLOR,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(dist, SKELETON_THICKNESS),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(p1.X, p1.Y),
            Rotation = math.deg(angle),
            ZIndex = 4,
        }, holder)

        skeletonLines[#skeletonLines + 1] = line
        return line
    end

    -- Joint positions (relative to holder scale 0-1)
    local joints = {
        HeadTop     = Vector2.new(0.5, 0.02),
        Neck        = Vector2.new(0.5, 0.20),
        LeftShoulder  = Vector2.new(0.27, 0.22),
        RightShoulder = Vector2.new(0.73, 0.22),
        LeftHand    = Vector2.new(0.04, 0.58),
        RightHand   = Vector2.new(0.96, 0.58),
        Pelvis      = Vector2.new(0.5, 0.58),
        LeftFoot    = Vector2.new(0.37, 0.98),
        RightFoot   = Vector2.new(0.63, 0.98),
    }

    local function buildSkeleton()
        -- Head -> Neck -> Pelvis
        drawLine(joints.HeadTop, joints.Neck)
        drawLine(joints.Neck, joints.Pelvis)
        -- Shoulders
        drawLine(joints.LeftShoulder, joints.RightShoulder)
        -- Arms
        drawLine(joints.LeftShoulder, joints.LeftHand)
        drawLine(joints.RightShoulder, joints.RightHand)
        -- Legs
        drawLine(joints.Pelvis, joints.LeftFoot)
        drawLine(joints.Pelvis, joints.RightFoot)
    end
    buildSkeleton()

    -- Labels
    local nameLabel = create("TextLabel", {
        Name = "NameLabel",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.fromScale(0.5, -0.08),
        AnchorPoint = Vector2.new(0.5, 1),
        Text = "Jogador",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        FontFace = Library.Fonts.Bold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 5,
    }, holder)

    local nameStroke = stroke(nameLabel, "Stroke", 0, 1)
    nameStroke.Color = Color3.fromRGB(0, 0, 0)

    local distanceLabel = create("TextLabel", {
        Name = "DistanceLabel",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.fromScale(0.5, 1.05),
        AnchorPoint = Vector2.new(0.5, 0),
        Text = "1175m",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        TextSize = 11,
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
        color = CHAMS_COLOR,
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
    end

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

    function controller.SetColor(c)
        state.color = c
        applyColor(c)
    end

    -- Initialize
    controller.SetChams(state.chams)
    controller.SetBox(state.box)
    controller.SetSkeleton(state.skeleton)
    controller.SetName(state.name)
    controller.SetDistance(state.distance)

    return controller
end

-- ============================================================
--  Build ESP Panel with Preview + Settings
-- ============================================================
local function buildEspPanel(kind)
    return function(m)
        local Library = BBC.Library
        local S = Library.ESP and Library.ESP[kind] or {}
        if not next(S) then
            S = {
                highlight = { on = true, color = kind == "NPCs" and Color3.fromRGB(240, 95, 95) or Color3.fromRGB(245, 160, 30), alpha = 0.6, outline = 2 },
                box = { on = true, color = Color3.fromRGB(215, 215, 215), thick = 1, style = "Completa", corner = 14, alpha = 0.5 },
                name = { on = true, color = Color3.fromRGB(235, 235, 235) },
                healthbar = { on = true, auto = true, color = Color3.fromRGB(45, 205, 190), width = 2, side = "Esquerda" },
                health = { on = true, color = Color3.fromRGB(70, 220, 90) },
                distance = { on = true, color = Color3.fromRGB(235, 235, 235), unit = "m" },
                kdr = { on = false, color = Color3.fromRGB(255, 200, 90) },
                reports = { on = false, color = Color3.fromRGB(255, 140, 90) },
                tracers = { on = false, color = Color3.fromRGB(255, 255, 255), thick = 1, origin = "Baixo" },
                arrows = { on = false, color = Color3.fromRGB(255, 90, 90), size = 18 },
                skeleton = { on = false, color = Color3.fromRGB(255, 255, 255), thick = 1.5 },
                frozen = false, locked = false,
                lod = { on = true, near = 150 }, nearest = { on = false, color = Color3.fromRGB(255, 60, 60) },
                maxDist = 1000, textSize = 10, prevDist = 120, prevHp = 100,
            }
            Library.ESP = Library.ESP or {}
            Library.ESP[kind] = S
        end

        local L = m.Left
        local R = m.Right

        -- Preview Container (Frame onde o preview será injetado)
        local previewContainer = create("Frame", {
            Name = "ESPPreviewContainer",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 4),
            Size = UDim2.fromOffset(212, 205),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            BackgroundTransparency = 1,
        }, L)

        -- Build the character preview inside the container
        local previewController = SetupCharacterPreview(previewContainer)

        -- Store controller for external access
        Library.ESPPreviewControllers = Library.ESPPreviewControllers or {}
        Library.ESPPreviewControllers[kind] = previewController

        -- Background grid (scanner effect)
        local cv = previewContainer
        local CVW, CVH = 212, 205
        for i = 1, 8 do
            local v = create("Frame", { Position = UDim2.fromOffset(i * 26.5, 0), Size = UDim2.fromOffset(1, CVH), BorderSizePixel = 0, BackgroundTransparency = 0.94 }, cv)
            bind(v, "BackgroundColor3", "Text")
        end
        for i = 1, 6 do
            local h = create("Frame", { Position = UDim2.fromOffset(0, i * 34), Size = UDim2.fromOffset(CVW, 1), BorderSizePixel = 0, BackgroundTransparency = 0.94 }, cv)
            bind(h, "BackgroundColor3", "Text")
        end

        -- Pedestal
        local shadow = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0 }, cv)
        local pedBase = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(1, 0.8), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, BorderSizePixel = 0 }, shadow)
        corner(pedBase, 0, true) -- UICorner with CornerRadius = UDim.new(1, 0)
        local pedTop = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1, 0.8), BorderSizePixel = 0 }, shadow)
        bind(pedTop, "BackgroundColor3", "Surface2")
        corner(pedTop, 0, true)
        local pedStroke = stroke(pedTop, "Accent", 0.1, 1.5)
        local pedInner = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.6), BackgroundTransparency = 1 }, pedTop)
        corner(pedInner, 0, true)
        local pedInnerStroke = stroke(pedInner, "Accent", 0.5, 1)

        -- ============================================================
        --  Right Side Settings (bind to preview controller)
        -- ============================================================
        local fold = R:Foldout({ Name = "Configurações gerais", Build = function(p)
            p:Slider({ Name = "Distância máx.", Min = 100, Max = 3000, Default = 1000, Suffix = "m", Step = 50, Callback = function(v) S.maxDist = v end })
            p:Slider({ Name = "Tamanho do texto", Min = 9, Max = 16, Default = 10, Callback = function(v) S.textSize = v end })
            p:Slider({ Name = "Distância da prévia", Min = 10, Max = 2000, Default = 120, Suffix = "m", Step = 10, Callback = function(v) S.prevDist = v end })
            p:Slider({ Name = "Vida da prévia", Min = 0, Max = 100, Default = 100, Callback = function(v) S.prevHp = v end })
            p:Toggle({ Name = "Só detalhes de perto", Default = true, Tooltip = "Longe, mostra só um ponto e a distância. Perto, mostra tudo.", Callback = function(v) S.lod.on = v end })
            p:Slider({ Name = "Detalhes até", Min = 20, Max = 1000, Default = 150, Suffix = "m", Step = 10, Callback = function(v) S.lod.near = v end })
            p:Toggle({ Name = "Destacar mais próximo", Default = false, Tooltip = "O alvo mais perto de você ganha outra cor e uma seta em cima.",
                Callback = function(v) S.nearest.on = v end,
                Settings = function(q) q:ColorPicker({ Name = "Cor", Default = S.nearest.color, Callback = function(c) S.nearest.color = c end }) end })
        end })

        local function add(key, labelText, extra)
            local toggle = R:Toggle({ Name = labelText, Default = S[key] and S[key].on or false, Callback = function(v)
                if S[key] then S[key].on = v end
                -- Sync with preview controller
                if key == "highlight" then previewController.SetChams(v)
                elseif key == "box" then previewController.SetBox(v)
                elseif key == "skeleton" then previewController.SetSkeleton(v)
                elseif key == "name" then previewController.SetName(v)
                elseif key == "distance" then previewController.SetDistance(v)
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
                if extra then extra(p) end
            end })
        end

        add("highlight", "Destaque", function(p)
            p:Slider({ Name = "Preenchimento", Min = 5, Max = 90, Default = 60, Suffix = "%", Callback = function(v) if S.highlight then S.highlight.alpha = v / 100 end end })
            p:Slider({ Name = "Contorno", Min = 0, Max = 4, Default = 2, Step = 0.5, Callback = function(v) if S.highlight then S.highlight.outline = v end end })
        end)
        add("box", "Caixa", function(p)
            p:Dropdown({ Name = "Estilo", Options = { "Cantos", "Completa" }, Default = "Completa", Callback = function(v) if S.box then S.box.style = v end end })
            p:Slider({ Name = "Espessura", Min = 1, Max = 5, Default = 1, Callback = function(v) if S.box then S.box.thick = v end end })
            p:Slider({ Name = "Opacidade", Min = 10, Max = 100, Default = 50, Suffix = "%", Callback = function(v) if S.box then S.box.alpha = v / 100 end end })
            p:Slider({ Name = "Tamanho do canto", Min = 6, Max = 30, Default = 14, Callback = function(v) if S.box then S.box.corner = v end end })
        end)
        add("name", "Nome")
        add("healthbar", "Barra de vida", function(p)
            p:Toggle({ Name = "Cor automática", Default = true, Callback = function(v) if S.healthbar then S.healthbar.auto = v end end })
            p:Dropdown({ Name = "Posição", Options = { "Esquerda", "Direita" }, Default = "Esquerda", Callback = function(v) if S.healthbar then S.healthbar.side = v end end })
            p:Slider({ Name = "Largura da barra", Min = 2, Max = 10, Default = 2, Callback = function(v) if S.healthbar then S.healthbar.width = v end end })
        end)
        add("health", "Vida")
        add("distance", "Distância", function(p)
            p:Dropdown({ Name = "Unidade", Options = { "m", "studs" }, Default = "m", Callback = function(v) if S.distance then S.distance.unit = v end end })
        end)
        if kind ~= "NPCs" then add("kdr", "K/D"); add("reports", "Denúncias") end
        add("tracers", "Linhas até alvos", function(p)
            p:Dropdown({ Name = "Origem", Options = { "Baixo", "Cima" }, Default = "Baixo", Callback = function(v) if S.tracers then S.tracers.origin = v end end })
            p:Slider({ Name = "Espessura", Min = 1, Max = 4, Default = 1, Callback = function(v) if S.tracers then S.tracers.thick = v end end })
        end)
        add("arrows", "Setas", function(p)
            p:Slider({ Name = "Tamanho", Min = 12, Max = 30, Default = 18, Callback = function(v) if S.arrows then S.arrows.size = v end end })
        end)
        add("skeleton", "Esqueleto", function(p)
            p:Slider({ Name = "Espessura", Min = 1, Max = 4, Default = 1.5, Step = 0.5, Callback = function(v) if S.skeleton then S.skeleton.thick = v end end })
        end)

        local hint = create("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.new(1, -16, 0, 34),
            Text = "TOQUE: ALTERNAR · SEGURE: O QUE É\nTOQUE NO ÍCONE: AJUSTES", TextSize = 10, FontFace = Library.Fonts.Regular, TextWrapped = true }, m.RightBox)
        bind(hint, "TextColor3", "Muted")
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