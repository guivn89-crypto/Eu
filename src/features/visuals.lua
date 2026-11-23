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
local ESPConfig = BBC.Modules["utils.esp_config"]
local ESPPreview = BBC.Modules["features.esp_preview"]

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

local FEATURE_DEFINITIONS = {
    { key = "highlight", label = "Destaque" },
    { key = "box", label = "Caixa" },
    { key = "name", label = "Nome" },
    { key = "healthbar", label = "Barra de vida" },
    { key = "health", label = "Vida" },
    { key = "distance", label = "Distância" },
    { key = "tracers", label = "Linhas" },
    { key = "skeleton", label = "Esqueleto" },
}

local FEATURE_BY_KEY = {}
for _, definition in ipairs(FEATURE_DEFINITIONS) do
    FEATURE_BY_KEY[definition.key] = definition
end

local function featureEnabled(settings, key)
    local feature = settings and settings[key]
    return type(feature) == "table" and feature.on == true
end

local function setOption(kind, path, value)
    return ESPConfig.set(kind, path, value)
end

local function buildGeneralDrawer(container, kind, settings, controls)
    controls["maxDist"] = container:Slider({
        Name = "Distância máx.",
        Min = 100,
        Max = 5000,
        Default = settings.maxDist,
        Suffix = "m",
        Step = 50,
        Callback = function(value)
            setOption(kind, "maxDist", value)
        end,
    })
    controls["textSize"] = container:Slider({
        Name = "Tamanho do texto",
        Min = 8,
        Max = 20,
        Default = settings.textSize,
        Step = 1,
        Tooltip = "Escala o nome, a vida e a distância no ESP e na prévia.",
        Callback = function(value)
            setOption(kind, "textSize", value)
        end,
    })
    controls["prevDist"] = container:Slider({
        Name = "Distância da prévia",
        Min = 10,
        Max = 5000,
        Default = settings.prevDist,
        Suffix = "m",
        Step = 1,
        Callback = function(value)
            setOption(kind, "prevDist", value)
        end,
    })
    controls["prevHp"] = container:Slider({
        Name = "Vida da prévia",
        Min = 0,
        Max = 100,
        Default = settings.prevHp,
        Step = 1,
        Callback = function(value)
            setOption(kind, "prevHp", value)
        end,
    })
    controls["lod.on"] = container:Toggle({
        Name = "Detalhes só de perto",
        Default = settings.lod.on,
        Tooltip = "Longe, mostra só um ponto e a distância. Perto, mostra todos os detalhes.",
        Callback = function(value)
            setOption(kind, "lod.on", value)
        end,
    })
    controls["lod.near"] = container:Slider({
        Name = "Detalhes até",
        Min = 20,
        Max = 1000,
        Default = settings.lod.near,
        Suffix = "m",
        Step = 10,
        Callback = function(value)
            setOption(kind, "lod.near", value)
        end,
    })
    controls["ignoreDead"] = container:Toggle({
        Name = "Ignorar jogadores mortos",
        Default = settings.ignoreDead,
        Callback = function(value)
            setOption(kind, "ignoreDead", value)
        end,
    })
    controls["teamCheck"] = container:Toggle({
        Name = "Ignorar equipe",
        Default = settings.teamCheck,
        Callback = function(value)
            setOption(kind, "teamCheck", value)
        end,
    })
    controls["nearest.on"] = container:Toggle({
        Name = "Destacar mais próximo",
        Default = settings.nearest.on,
        Callback = function(value)
            setOption(kind, "nearest.on", value)
        end,
    })
    controls["nearest.color"] = container:ColorPicker({
        Name = "Cor do mais próximo",
        Default = settings.nearest.color,
        Callback = function(color)
            setOption(kind, "nearest.color", color)
        end,
    })
    controls["primaryColor"] = container:ColorPicker({
        Name = "Cor principal",
        Default = settings.primaryColor,
        Callback = function(color)
            ESPConfig.applyPrimaryColor(kind, color)
        end,
    })
end

local function buildFeatureDrawer(container, kind, key, settings, controls)
    local feature = settings[key]
    if type(feature) ~= "table" then
        return
    end

    if feature.color then
        controls[key .. ".color"] = container:ColorPicker({
            Name = "Cor",
            Default = feature.color,
            Callback = function(color)
                setOption(kind, key .. ".color", color)
            end,
        })
    end

    if key == "highlight" then
        controls["highlight.fillTransparency"] = container:Slider({
            Name = "Transparência do preenchimento",
            Min = 0,
            Max = 100,
            Default = feature.fillTransparency * 100,
            Suffix = "%",
            Step = 1,
            Callback = function(value)
                setOption(kind, "highlight.fillTransparency", value / 100)
            end,
        })
        controls["highlight.outlineTransparency"] = container:Slider({
            Name = "Transparência do contorno",
            Min = 0,
            Max = 100,
            Default = feature.outlineTransparency * 100,
            Suffix = "%",
            Step = 1,
            Callback = function(value)
                setOption(kind, "highlight.outlineTransparency", value / 100)
            end,
        })
        controls["highlight.outlineColor"] = container:ColorPicker({
            Name = "Cor do contorno",
            Default = feature.outlineColor,
            Callback = function(color)
                setOption(kind, "highlight.outlineColor", color)
            end,
        })
    elseif key == "box" then
        controls["box.style"] = container:Dropdown({
            Name = "Estilo",
            Options = { "Cantos", "Completa" },
            Default = feature.style,
            Callback = function(value)
                setOption(kind, "box.style", value)
            end,
        })
        controls["box.thick"] = container:Slider({
            Name = "Espessura",
            Min = 1,
            Max = 4,
            Default = feature.thick,
            Step = 0.5,
            Callback = function(value)
                setOption(kind, "box.thick", value)
            end,
        })
        controls["box.alpha"] = container:Slider({
            Name = "Opacidade",
            Min = 10,
            Max = 100,
            Default = feature.alpha * 100,
            Suffix = "%",
            Step = 1,
            Callback = function(value)
                setOption(kind, "box.alpha", value / 100)
            end,
        })
        controls["box.corner"] = container:Slider({
            Name = "Tamanho do canto",
            Min = 4,
            Max = 30,
            Default = feature.corner,
            Step = 1,
            Callback = function(value)
                setOption(kind, "box.corner", value)
            end,
        })
    elseif key == "name" then
        controls["name.size"] = container:Slider({
            Name = "Tamanho",
            Min = 8,
            Max = 20,
            Default = feature.size,
            Step = 1,
            Callback = function(value)
                setOption(kind, "name.size", value)
            end,
        })
        controls["name.outline"] = container:Toggle({
            Name = "Contorno do texto",
            Default = feature.outline,
            Callback = function(value)
                setOption(kind, "name.outline", value)
            end,
        })
    elseif key == "healthbar" then
        controls["healthbar.auto"] = container:Toggle({
            Name = "Cor automática",
            Default = feature.auto,
            Callback = function(value)
                setOption(kind, "healthbar.auto", value)
            end,
        })
        controls["healthbar.side"] = container:Dropdown({
            Name = "Posição",
            Options = { "Esquerda", "Direita" },
            Default = feature.side,
            Callback = function(value)
                setOption(kind, "healthbar.side", value)
            end,
        })
        controls["healthbar.width"] = container:Slider({
            Name = "Largura da barra",
            Min = 2,
            Max = 10,
            Default = feature.width,
            Step = 1,
            Callback = function(value)
                setOption(kind, "healthbar.width", value)
            end,
        })
    elseif key == "health" then
        controls["health.size"] = container:Slider({
            Name = "Tamanho",
            Min = 8,
            Max = 20,
            Default = feature.size,
            Step = 1,
            Callback = function(value)
                setOption(kind, "health.size", value)
            end,
        })
    elseif key == "distance" then
        controls["distance.unit"] = container:Dropdown({
            Name = "Unidade",
            Options = { "m", "studs" },
            Default = feature.unit,
            Callback = function(value)
                setOption(kind, "distance.unit", value)
            end,
        })
        controls["distance.size"] = container:Slider({
            Name = "Tamanho",
            Min = 8,
            Max = 20,
            Default = feature.size,
            Step = 1,
            Callback = function(value)
                setOption(kind, "distance.size", value)
            end,
        })
        controls["distance.outline"] = container:Toggle({
            Name = "Contorno do texto",
            Default = feature.outline,
            Callback = function(value)
                setOption(kind, "distance.outline", value)
            end,
        })
    elseif key == "tracers" then
        controls["tracers.origin"] = container:Dropdown({
            Name = "Origem",
            Options = { "Baixo", "Centro", "Cima" },
            Default = feature.origin,
            Callback = function(value)
                setOption(kind, "tracers.origin", value)
            end,
        })
        controls["tracers.thick"] = container:Slider({
            Name = "Espessura",
            Min = 1,
            Max = 4,
            Default = feature.thick,
            Step = 0.5,
            Callback = function(value)
                setOption(kind, "tracers.thick", value)
            end,
        })
    elseif key == "skeleton" then
        controls["skeleton.thick"] = container:Slider({
            Name = "Espessura",
            Min = 1,
            Max = 4,
            Default = feature.thick,
            Step = 0.5,
            Callback = function(value)
                setOption(kind, "skeleton.thick", value)
            end,
        })
    end
end

local function buildEspPanel(kind)
    return function(m)
        if not ESPConfig then
            return
        end
        ESPConfig.ensureDefaults(Library)

        local settings = Library.ESP and Library.ESP[kind]
        if type(settings) ~= "table" then
            return
        end
        local function currentSettings()
            local current = Library.ESP and Library.ESP[kind]
            return type(current) == "table" and current or settings
        end

        local settingControls = {}
        local left = m.Left
        local rightPanel = m.Right

        -- ============================================================
        --  LEFT SIDE: PRÉVIA
        -- ============================================================
        local previewFrame = create("Frame", {
            Name = "PreviewFrame",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(200, 268),
            BackgroundColor3 = Color3.fromRGB(15, 15, 20),
            BorderSizePixel = 0,
            ClipsDescendants = true,
        }, left)
        corner(previewFrame, 8)
        local previewStroke = stroke(previewFrame, "Accent", 0.2, 1)
        previewStroke.Color = Color3.fromRGB(255, 130, 0)

        local glow = create("Frame", {
            Name = "Glow",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.2, 1.2),
            BackgroundTransparency = 1,
            ZIndex = -1,
        }, previewFrame)
        create("UIGradient", {
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

        local previewContainer = create("Frame", {
            Name = "ESPPreviewContainer",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.95, 0.95),
            BackgroundTransparency = 1,
        }, previewFrame)

        local previewController = ESPPreview.build(previewContainer, settings)
        Library.ESPPreviewControllers = Library.ESPPreviewControllers or {}
        Library.ESPPreviewControllers[kind] = previewController

        -- Grade 2x4 de quick-toggles (8 botões: 4 por linha).
        local toggleButtonsFrame = create("Frame", {
            Name = "QuickTogglesGrid",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -3),
            Size = UDim2.new(1, 0, 0, 64),
        }, previewContainer)
        create("UIGridLayout", {
            CellSize = UDim2.fromOffset(44, 30),
            CellPadding = UDim2.fromOffset(4, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            StartCorner = Enum.StartCorner.TopLeft,
            FillDirectionMaxCells = 4,
        }, toggleButtonsFrame)

        local quickButtons = {}
        for index, definition in ipairs(FEATURE_DEFINITIONS) do
            local key = definition.key
            local button = create("TextButton", {
                Name = "Toggle_" .. key,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(44, 30),
                Text = definition.label,
                TextSize = 9,
                FontFace = Library.Fonts.Medium,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                TextWrapped = true,
                TextScaled = true,
                TextTruncate = Enum.TextTruncate.None,
                ClipsDescendants = false,
                LayoutOrder = index,
                AutoButtonColor = false,
            }, toggleButtonsFrame)
            corner(button, 4)
            local buttonStroke = stroke(button, "Stroke", 0, 1)
            create("UITextSizeConstraint", {
                MinTextSize = 7,
                MaxTextSize = 10,
            }, button)

            local function isOn()
                return featureEnabled(currentSettings(), key)
            end
            bind(button, "BackgroundColor3", function()
                return isOn() and Library.Theme.Accent or Library.Theme.Surface2
            end)
            bind(button, "TextColor3", function()
                return isOn() and Library.Theme.Text or Library.Theme.Muted
            end)
            bind(buttonStroke, "Color", function()
                return isOn() and Library.Theme.Accent or Library.Theme.Stroke
            end)

            button.MouseButton1Click:Connect(function()
                setOption(kind, key .. ".on", not isOn())
            end)
            quickButtons[key] = button
        end

        -- ============================================================
        --  RIGHT SIDE: AJUSTES DO JOGADOR / NPC
        -- ============================================================
        local generalDrawer = rightPanel:Drawer({
            Name = "Configurações gerais",
            Tooltip = "Ajustes gerais do ESP.",
            Parent = m.Overlay,
            Path = kind .. "/general",
            Width = 380,
            Height = 300,
            Build = function(container)
                buildGeneralDrawer(container, kind, settings, settingControls)
            end,
        })
        m.GeneralDrawer = generalDrawer

        local featureToggles = {}
        for _, definition in ipairs(FEATURE_DEFINITIONS) do
            local key = definition.key
            local toggle = rightPanel:Toggle({
                Name = definition.label,
                Default = featureEnabled(settings, key),
                Callback = function(value)
                    setOption(kind, key .. ".on", value)
                end,
                Drawer = function(container)
                    buildFeatureDrawer(container, kind, key, settings, settingControls)
                end,
                DrawerParent = m.Overlay,
                DrawerPath = kind .. "/feature/" .. key,
            })
            featureToggles[key] = toggle
        end

        -- The canonical config is shared by the engine, preview and both UI
        -- surfaces. A change event keeps every representation synchronized.
        local unsubscribe = ESPConfig.onChange(function(changedKind, path, value)
            if changedKind ~= kind then
                return
            end
            previewController.ApplySettings(currentSettings())

            local settingControl = settingControls[path]
            if settingControl and type(settingControl.Set) == "function" then
                settingControl:Set(value, true)
            end

            local featureKey = string.match(path, "^([^%.]+)")
            local definition = featureKey and FEATURE_BY_KEY[featureKey]
            if definition and path == featureKey .. ".on" then
                local toggle = featureToggles[definition.key]
                if toggle then
                    toggle:Set(value == true, true)
                end
            end
        end)
        m.Overlay.Destroying:Connect(unsubscribe)

        m.PreviewGrid = toggleButtonsFrame
        m.TogglePreviewGrid = function()
            toggleButtonsFrame.Visible = not toggleButtonsFrame.Visible
        end
        m.TogglePreviewLock = function()
            previewController.SetLocked(not previewController.IsLocked())
        end
        m.ResetPreview = function()
            previewController.ResetLayout()
        end

        -- Fixed footer with touch hints.
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

        label(footer, "Toque: ativar", 10, "Muted", false, {
            Size = UDim2.fromOffset(100, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        label(footer, "Arraste: mover", 10, "Muted", false, {
            Size = UDim2.fromOffset(100, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        label(footer, "Segure: ajustes", 10, "Muted", false, {
            Size = UDim2.fromOffset(100, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
    end
end

Features.buildEspPanel = buildEspPanel

-- ============================================================
--  Build Visuals Tab
-- ============================================================
function Features.buildVisuals(window)
    local visuals = window:Tab({ Name = "VISUAIS", Icon = "eye" })

    local group = visuals:Groupbox({ Name = "ESP", Icon = "scan-eye", Side = "Left" })
    -- Only character ESP kinds currently have reliable adapters. Unsupported
    -- world-object rows stay hidden instead of exposing dead controls.
    for _, name in ipairs({ "Jogador", "NPCs" }) do
        T(group, name, true)
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
