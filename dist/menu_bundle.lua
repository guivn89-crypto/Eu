--!nocheck
--[[
    BBC HUB - menu_bundle.lua
    Arquivo gerado automaticamente por build.py. NÃO EDITE DIRETAMENTE.
    Edite os módulos em src/ e rode: python3 build.py

    Ordem de carga: utils -> ui -> features -> main.
    Single-file: não usa require(), module() nem dependências locais.
]]

local BBC = {
    Modules = {},
    Utils = {},
    UI = {},
    Features = {},
    State = {},
}

local function __module(name, loader)
    local ok, result = pcall(loader, BBC)
    if not ok then
        warn(string.format("[BBC] falha ao carregar o módulo '%s': %s", name, tostring(result)))
        return nil
    end
    BBC.Modules[name] = result
    return result
end

-- ============================================================
-- módulo: utils.security  (utils/security.lua)
-- ============================================================
__module("utils.security", function(BBC)
--[[
    BBC HUB - Security
    Camada de proteção e utilitários seguros.

    Responsabilidades:
      * chamadas protegidas (pcall) para callbacks e código de terceiros;
      * detecção de capacidades do executor (filesystem / config);
      * leitura e escrita segura de arquivos JSON;
      * validação de acesso (FREE / VIP) e expiração de licença;
      * checagem básica do ambiente de execução.
]]

local Security = {}
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local function log(message)
    warn("[BBC][security] " .. tostring(message))
end

-- Executa um callback sem deixar o erro derrubar o hub.
function Security.safeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        log(err)
    end
    return ok, err
end

-- Executa e devolve o resultado, ou nil em caso de falha.
function Security.safeInvoke(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        log(result)
        return nil
    end
    return result
end

function Security.canFS()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

function Security.ensureFolder(path)
    if type(path) ~= "string" or path == "" then
        return false
    end
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return false
    end
    local ok = pcall(function()
        if not isfolder(path) then
            makefolder(path)
        end
    end)
    return ok
end

function Security.readJSON(path)
    if not Security.canFS() or type(path) ~= "string" then
        return nil
    end
    local ok, data = pcall(function()
        if isfile(path) then
            return HttpService:JSONDecode(readfile(path))
        end
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

function Security.writeJSON(path, data)
    if not Security.canFS() or type(path) ~= "string" then
        return false
    end
    local ok = pcall(function()
        writefile(path, HttpService:JSONEncode(data or {}))
    end)
    return ok
end

-- Configuração injetada pelo executor antes do load:
--   getgenv().BBC_CONFIG = { Access = "VIP", Expiry = os.time() + 3600, Version = "x.y.z" }
function Security.getConfig()
    local env = type(getgenv) == "function" and getgenv() or nil
    local cfg = env and env.BBC_CONFIG
    if type(cfg) ~= "table" then
        return {}
    end
    return cfg
end

function Security.isVIP()
    local library = BBC.Library
    return library ~= nil and library.Access == "VIP"
end

function Security.resolveExpiry(expiry)
    if type(expiry) == "function" then
        local ok, value = pcall(expiry)
        expiry = ok and value or nil
    end
    if type(expiry) == "number" then
        return expiry
    end
    return nil
end

function Security.remaining(expiry)
    local at = Security.resolveExpiry(expiry)
    if not at then
        return nil
    end
    return math.max(at - os.time(), 0)
end

function Security.isExpired(expiry)
    local left = Security.remaining(expiry)
    return left ~= nil and left <= 0
end

-- Retorna true quando o recurso pode ser usado.
function Security.hasAccess(opts)
    opts = opts or {}
    if opts.Premium and not Security.isVIP() then
        return false
    end
    if Security.isExpired(BBC.State and BBC.State.Config and BBC.State.Config.Expiry) then
        return false
    end
    return true
end

function Security.checkEnvironment()
    local problems = {}
    if typeof(game) ~= "Instance" then
        problems[#problems + 1] = "game indisponível"
    end
    if not Players.LocalPlayer then
        problems[#problems + 1] = "LocalPlayer indisponível"
    end
    if type(getgenv) ~= "function" then
        problems[#problems + 1] = "getgenv ausente"
    end
    if #problems > 0 then
        log(table.concat(problems, ", "))
        return false
    end
    return true
end

-- Marca a sessão como protegida e congela a tabela de config.
function Security.init()
    Security.checkEnvironment()
    pcall(function()
        local env = getgenv()
        env.BBC_HUB_SECURE = true
        env.BBC_HUB_VERSION = "0.0.8.2"
        if type(env.BBC_CONFIG) == "table" then
            table.freeze(env.BBC_CONFIG)
        end
    end)
    return true
end

BBC.Security = Security
return Security

end)

-- ============================================================
-- módulo: utils.drawing  (utils/drawing.lua)
-- ============================================================
__module("utils.drawing", function(BBC)
--[[
    BBC HUB - Drawing / UI primitives
    Helpers de criação de instâncias, ícones, notificações e utilitários visuais.
]]

local Utils = BBC.Utils or {}
BBC.Utils = Utils

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Security = BBC.Security
local safeCall = Security.safeCall

-- ---------- Instâncias ----------
function Utils.create(class, props, parent)
    local instance = Instance.new(class)
    for key, value in pairs(props or {}) do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

local create = Utils.create

function Utils.corner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, parent)
end

function Utils.stroke(parent, key, transparency, thickness)
    local instance = create("UIStroke", {
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
    Utils.bind(instance, "Color", key or "Stroke")
    return instance
end

function Utils.pad(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

function Utils.listLayout(parent, padding, direction)
    return create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, padding or 0),
        FillDirection = direction or Enum.FillDirection.Vertical,
    }, parent)
end

function Utils.tween(instance, props, duration, style)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props
    )
    tween:Play()
    return tween
end

function Utils.label(parent, text, size, key, bold, props)
    local library = BBC.Library
    local instance = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextSize = size or 13,
        FontFace = bold and library.Fonts.Bold or library.Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, 0, 0, (size or 13) + 4),
    }, parent)
    Utils.bind(instance, "TextColor3", key or "Text")
    for prop, value in pairs(props or {}) do
        instance[prop] = value
    end
    return instance
end

-- ---------- Ícones (Lucide) ----------
local LUCIDE_URL = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"
local GLYPHS = {
    ["eye"] = "◉", ["user"] = "☺", ["crosshair"] = "⌖", ["globe"] = "◍", ["layout-grid"] = "▦", ["package-search"] = "▣",
    ["server"] = "▤", ["palette"] = "✎", ["scroll-text"] = "☰", ["shopping-cart"] = "▲", ["settings"] = "⚙", ["search"] = "⌕",
    ["flame"] = "♨", ["save"] = "▣", ["box"] = "◆", ["sliders-horizontal"] = "≡", ["message-circle"] = "✉", ["lock"] = "⚿",
}

local lucide = nil
local iconsGaveUp = false
local allIcons = {}
local iconsStarted = false

local function resolveIcon(name)
    if not lucide then
        return nil
    end
    local entry = (lucide.Icons and lucide.Icons[name]) or lucide[name]
    if type(entry) == "string" then
        return entry
    end
    if type(entry) ~= "table" then
        return nil
    end
    local image = entry.Image
    if type(image) == "number" then
        image = "rbxassetid://" .. tostring(image)
    end
    local sheet = (lucide.Spritesheets and lucide.Spritesheets[tostring(image)]) or image
    return sheet, entry.ImageRectPosition, entry.ImageRectSize
end

local function showGlyph(record)
    if record.glyph or not record.img.Parent then
        return
    end
    record.img.Image = ""
    local glyph = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = GLYPHS[record.name] or "•",
        TextSize = 15,
        FontFace = BBC.Library.Fonts.Bold,
    }, record.img)
    Utils.bind(glyph, "TextColor3", function()
        return record.img.ImageColor3
    end)
    record.glyph = glyph
end

local function applyIconNow(record)
    local sheet, position, size = resolveIcon(record.name)
    if not sheet then
        showGlyph(record)
        return
    end
    record.img.Image = sheet
    if position then
        record.img.ImageRectOffset = position
    end
    if size then
        record.img.ImageRectSize = size
    end
    if record.glyph then
        record.glyph:Destroy()
        record.glyph = nil
    end
end

local function setIcon(image, name)
    if type(name) == "string" and (name:match("^%d+$") or name:find("^rbxassetid://")) then
        image.Image = name:match("^%d+$") and ("rbxassetid://" .. name) or name
        return
    end
    local record = { img = image, name = name }
    allIcons[#allIcons + 1] = record
    if lucide then
        applyIconNow(record)
    elseif iconsGaveUp then
        showGlyph(record)
    end
end

function Utils.init()
    if iconsStarted then
        return
    end
    iconsStarted = true
    task.spawn(function()
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(LUCIDE_URL))()
        end)
        if ok and type(result) == "table" then
            lucide = result
            for _, record in ipairs(allIcons) do
                if record.img.Parent then
                    applyIconNow(record)
                end
            end
        else
            warn("[BBC] ícones indisponíveis, usando símbolos: " .. tostring(result))
            iconsGaveUp = true
            for _, record in ipairs(allIcons) do
                showGlyph(record)
            end
        end
    end)
end

function Utils.waitIcons(timeout)
    local started = os.clock()
    while not lucide and not iconsGaveUp and os.clock() - started < (timeout or 25) do
        task.wait(0.1)
    end
    if not lucide then
        iconsGaveUp = true
        for _, record in ipairs(allIcons) do
            showGlyph(record)
        end
    end
end

function Utils.icon(parent, name, size, key, props)
    local image = create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size or 16, size or 16),
        ScaleType = Enum.ScaleType.Fit,
    }, parent)
    Utils.bind(image, "ImageColor3", key or "Text")
    for prop, value in pairs(props or {}) do
        image[prop] = value
    end
    setIcon(image, name)
    return image
end

-- ---------- Raiz da interface ----------
function Utils.guiParent()
    if type(gethui) == "function" then
        local ok, handler = pcall(gethui)
        if ok and handler then
            return handler
        end
    end
    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and core then
        return core
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ---------- Notificações ----------
local notifyGui, notifyHolder
function Utils.notify(opts)
    opts = opts or {}
    if not notifyGui or not notifyGui.Parent then
        notifyGui = create("ScreenGui", {
            Name = "BBCNotify",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 1000,
        }, Utils.guiParent())
        notifyHolder = create("Frame", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -14, 1, -14),
            Size = UDim2.fromOffset(250, 400),
            BackgroundTransparency = 1,
        }, notifyGui)
        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
        }, notifyHolder)
    end
    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, notifyHolder)
    Utils.bind(card, "BackgroundColor3", "Surface")
    Utils.corner(card, 5)
    Utils.stroke(card, "Stroke")
    local bar = create("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 }, card)
    Utils.bind(bar, "BackgroundColor3", "Accent")
    Utils.corner(bar, 2)
    local inner = create("Frame", {
        Size = UDim2.new(1, -14, 0, 0),
        Position = UDim2.fromOffset(12, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, card)
    Utils.pad(inner, 0, 6, 7, 8)
    Utils.listLayout(inner, 2)
    if opts.Title then
        Utils.label(inner, opts.Title, 13, "Text", true, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 17) })
    end
    if opts.Content then
        Utils.label(inner, opts.Content, 12, "Muted", false, {
            LayoutOrder = 2,
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            Size = UDim2.new(1, 0, 0, 16),
        })
    end
    card.BackgroundTransparency = 1
    Utils.tween(card, { BackgroundTransparency = 0 }, 0.2)
    task.delay(opts.Duration or 3, function()
        if card.Parent then
            Utils.tween(card, { BackgroundTransparency = 1 }, 0.25)
            task.wait(0.27)
            card:Destroy()
        end
    end)
end

function Utils.notifyText(text, duration)
    return Utils.notify({ Title = "BBC HUB", Content = tostring(text), Duration = duration or 2 })
end

-- ---------- Medidas e bandeiras ----------
function Utils.textWidth(text, size)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(tostring(text), size or 12, Enum.Font.Arimo, Vector2.new(1000, 60))
    end)
    return ok and bounds.X or (#tostring(text) * 7)
end

function Utils.makeFlag(parent, code, props)
    local flag = create("Frame", {
        Size = UDim2.fromOffset(22, 15),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, parent)
    for key, value in pairs(props or {}) do
        flag[key] = value
    end
    Utils.corner(flag, 2)
    local function rect(x, y, width, height, color, rotation)
        return create("Frame", {
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Rotation = rotation or 0,
        }, flag)
    end
    if code == "pt" then
        flag.BackgroundColor3 = Color3.fromRGB(0, 155, 58)
        rect(6, 2.5, 10, 10, Color3.fromRGB(255, 222, 0), 45)
        local circle = rect(7.5, 4.5, 7, 7, Color3.fromRGB(0, 39, 118))
        Utils.corner(circle, 4)
    elseif code == "en" then
        flag.BackgroundColor3 = Color3.fromRGB(1, 33, 105)
        rect(-3, 6, 28, 3, Color3.new(1, 1, 1), 33)
        rect(-3, 6, 28, 3, Color3.new(1, 1, 1), -33)
        rect(0, 5, 22, 5, Color3.new(1, 1, 1))
        rect(8.5, 0, 5, 15, Color3.new(1, 1, 1))
        rect(0, 6, 22, 3, Color3.fromRGB(200, 16, 46))
        rect(9.5, 0, 3, 15, Color3.fromRGB(200, 16, 46))
    elseif code == "es" then
        flag.BackgroundColor3 = Color3.fromRGB(170, 21, 27)
        rect(0, 4, 22, 7, Color3.fromRGB(241, 191, 0))
    elseif code == "zh" then
        flag.BackgroundColor3 = Color3.fromRGB(222, 41, 16)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(2, -1),
            Size = UDim2.fromOffset(10, 10),
            Text = "★",
            TextSize = 10,
            TextColor3 = Color3.fromRGB(255, 222, 0),
            FontFace = BBC.Library.Fonts.Bold,
        }, flag)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 1),
            Size = UDim2.fromOffset(6, 6),
            Text = "★",
            TextSize = 5,
            TextColor3 = Color3.fromRGB(255, 222, 0),
        }, flag)
    elseif code == "ru" then
        rect(0, 5, 22, 5, Color3.fromRGB(0, 57, 166))
        rect(0, 10, 22, 5, Color3.fromRGB(213, 43, 30))
    end
    return flag
end

function Utils.chipBox(parent)
    local chip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        BackgroundTransparency = 0,
    }, parent)
    Utils.bind(chip, "BackgroundColor3", "Surface2")
    Utils.corner(chip, 4)
    local stroke = Utils.stroke(chip, "Stroke", 0)
    return chip, stroke
end

-- ---------- Teclas ----------
local KEY_SHORT = {
    RightShift = "RShift", LeftShift = "LShift", RightControl = "RCtrl", LeftControl = "LCtrl",
    RightAlt = "RAlt", LeftAlt = "LAlt", MouseButton3 = "MB3", MouseButton2 = "MB2",
    Backspace = "Bksp", Return = "Enter",
}

function Utils.keyText(value)
    if not value then
        return "None"
    end
    return KEY_SHORT[value.Name] or value.Name
end

function Utils.parseKey(value)
    if typeof(value) == "EnumItem" then
        return value
    end
    if type(value) ~= "string" then
        return nil
    end
    if value == "MB3" or value == "MouseButton3" then
        return Enum.UserInputType.MouseButton3
    end
    if value == "MB2" or value == "MouseButton2" then
        return Enum.UserInputType.MouseButton2
    end
    local ok, key = pcall(function()
        return Enum.KeyCode[value]
    end)
    return ok and key or nil
end

Utils.safeCall = safeCall
Utils.TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
Utils.HttpService = HttpService

return Utils

end)

-- ============================================================
-- módulo: ui.theme  (ui/theme.lua)
-- ============================================================
__module("ui.theme", function(BBC)
--[[
    BBC HUB - Theme / Core Library
    Fonte única de verdade do estado da biblioteca: fontes, temas, bindings,
    registro de controles, keybinds e ciclo de FPS.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Library = {
    Windows = {},
    Registry = {},
    _themeListeners = {},
    _bindings = {},
    ThemeName = "Orange",
    Theme = {},
    Access = "FREE",
    Keybinds = {},
    _kbListeners = {},
    Tr = function(text)
        return text
    end,
}

function Library:_kbChanged()
    for _, callback in ipairs(Library._kbListeners) do
        pcall(callback)
    end
end

-- ---------- Fontes ----------
Library.Fonts = {
    Regular = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular),
    Medium = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Medium),
    Bold = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold),
}

local FONT_WEIGHTS = {
    Regular = { 400, Enum.FontWeight.Regular },
    Medium = { 500, Enum.FontWeight.Medium },
    SemiBold = { 600, Enum.FontWeight.SemiBold },
    Bold = { 700, Enum.FontWeight.Bold },
}

function Library:LoadFont(opts)
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[BBC] fontes personalizadas precisam de writefile, isfile e getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    local weights = opts.Weights
    if type(weights) ~= "table" then
        return false
    end
    local folder = "BBC_HUB_Fontes"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
            makefolder(folder)
        end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local info = FONT_WEIGHTS[weightName]
        if info then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then
                ok = pcall(function()
                    writefile(path, game:HttpGet(url))
                end)
            end
            if ok then
                table.insert(faces, {
                    name = weightName,
                    weight = info[1],
                    style = "normal",
                    assetId = getcustomasset(path),
                })
            end
        end
    end
    if #faces == 0 then
        return false
    end
    local familyPath = folder .. "/" .. name .. ".json"
    if not pcall(function()
        writefile(familyPath, HttpService:JSONEncode({ name = name, faces = faces }))
    end) then
        return false
    end
    local family = getcustomasset(familyPath)
    local function face(weightName, fallback)
        local info = FONT_WEIGHTS[weightName]
        if info and weights[weightName] then
            return Font.new(family, info[2])
        end
        return fallback
    end
    Library.Fonts.Regular = face("Regular", Library.Fonts.Regular)
    Library.Fonts.Medium = face("Medium", face("Regular", Library.Fonts.Medium))
    Library.Fonts.Bold = face("Bold", face("SemiBold", Library.Fonts.Bold))
    return true
end

-- ---------- Temas ----------
local function preset(accent, mode, backgroundOverride)
    local hue = accent:ToHSV()
    local function derive(saturation, value)
        if mode == "neutral" then
            return Color3.fromHSV(0, 0, value)
        end
        return Color3.fromHSV(hue, saturation, value)
    end
    local theme = {
        Accent = accent,
        Background = derive(0.55, 0.04),
        Surface = derive(0.55, 0.055),
        Surface2 = derive(0.5, 0.08),
        Surface3 = derive(0.45, 0.125),
        Stroke = derive(0.45, 0.2),
        Text = Color3.fromRGB(242, 242, 242),
        Muted = Color3.fromRGB(150, 150, 150),
        Warning = Color3.fromRGB(240, 176, 108),
        Error = Color3.fromRGB(240, 100, 100),
    }
    if backgroundOverride then
        for key, value in pairs(backgroundOverride) do
            theme[key] = value
        end
    end
    return theme
end

Library.ThemeOrder = {
    "Gold", "Purple", "Yellow", "Red", "Blue", "Orange", "Green",
    "Halloween", "Ocean", "Mono", "Cyan", "Pink", "Copper",
}

Library.ThemePresets = {
    Gold = preset(Color3.fromRGB(255, 192, 40), "neutral"),
    Purple = preset(Color3.fromRGB(150, 100, 255), "tint"),
    Yellow = preset(Color3.fromRGB(240, 232, 60), "neutral"),
    Red = preset(Color3.fromRGB(240, 52, 72), "tint"),
    Blue = preset(Color3.fromRGB(80, 125, 255), "tint"),
    Orange = preset(Color3.fromRGB(255, 130, 25), "neutral"),
    Green = preset(Color3.fromRGB(45, 215, 105), "tint"),
    Halloween = preset(Color3.fromRGB(255, 120, 10), "tint", {
        Background = Color3.fromRGB(14, 8, 22),
        Surface = Color3.fromRGB(19, 11, 30),
        Surface2 = Color3.fromRGB(27, 16, 42),
        Surface3 = Color3.fromRGB(40, 26, 60),
        Stroke = Color3.fromRGB(58, 38, 84),
    }),
    Cyan = preset(Color3.fromRGB(30, 175, 245), "tint"),
    Mono = preset(Color3.fromRGB(235, 235, 235), "neutral"),
    Pink = preset(Color3.fromRGB(242, 85, 175), "tint"),
    Ocean = preset(Color3.fromRGB(40, 120, 255), "tint"),
    Copper = preset(Color3.fromRGB(222, 150, 62), "neutral"),
}

for key, value in pairs(Library.ThemePresets.Orange) do
    Library.Theme[key] = value
end

local function bind(instance, property, key)
    local resolver = type(key) == "function" and key or function()
        return Library.Theme[key]
    end
    instance[property] = resolver()
    Library._bindings[#Library._bindings + 1] = { instance, property, resolver }
end

function Library:SetTheme(name)
    local palette = Library.ThemePresets[name]
    if not palette then
        return
    end
    Library.ThemeName = name
    for key, value in pairs(palette) do
        Library.Theme[key] = value
    end
    for index = #Library._bindings, 1, -1 do
        local binding = Library._bindings[index]
        if binding[1] and binding[1].Parent then
            pcall(function()
                binding[1][binding[2]] = binding[3]()
            end)
        else
            table.remove(Library._bindings, index)
        end
    end
    for _, callback in ipairs(Library._themeListeners) do
        pcall(callback)
    end
end

-- ---------- Servidores ----------
function Library:FetchServers(order, cursor)
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100%s",
        game.PlaceId,
        order or "Desc",
        cursor and ("&cursor=" .. cursor) or ""
    )
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(body) ~= "string" then
        return nil
    end
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then
        return nil
    end
    return data.data, data.nextPageCursor
end

function Library:JoinServer(jobId)
    return pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end)
end

-- ---------- FPS compartilhado ----------
Library._fps = 60
do
    local frames, last = 0, os.clock()
    RunService.RenderStepped:Connect(function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            Library._fps = math.floor(frames / (now - last) + 0.5)
            frames = 0
            last = now
        end
    end)
end

-- ---------- Integração com a camada de desenho ----------
function Library:Notify(opts)
    return BBC.Utils.notify(opts)
end

function Library.MakeIcon(...)
    return BBC.Utils.icon(...)
end

Library.ParseKey = function(value)
    return BBC.Utils.parseKey(value)
end

BBC.Library = Library
BBC.Theme = Library.Theme
BBC.Utils.bind = bind
BBC.Utils.safeCall = BBC.Security.safeCall
BBC.Utils.LocalPlayer = LocalPlayer

if type(getgenv) == "function" then
    pcall(function()
        getgenv().BBCLib = Library
    end)
end

return Library

end)

-- ============================================================
-- módulo: ui.components  (ui/components.lua)
-- ============================================================
__module("ui.components", function(BBC)
--[[
    BBC HUB - Components
    Elementos reutilizáveis (Toggle, Slider, Dropdown, Keybind, ColorPicker,
    PlayerPreview, etc.) e helpers de layout compartilhados por abas/grupos.
]]

local Library = BBC.Library
local Utils = BBC.Utils
local Security = BBC.Security

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local create = Utils.create
local corner = Utils.corner
local stroke = Utils.stroke
local pad = Utils.pad
local listLayout = Utils.listLayout
local tween = Utils.tween
local label = Utils.label
local icon = Utils.icon
local bind = Utils.bind
local textWidth = Utils.textWidth
local makeFlag = Utils.makeFlag
local chipBox = Utils.chipBox
local keyText = Utils.keyText
local parseKey = Utils.parseKey
local safeCall = Security.safeCall

-- ============================================================
--  Elementos (compartilhados por abas, grupos e submenus)
-- ============================================================
local Container = {}
Container.__index = Container

function Container:_nextOrder()
    self._order = (self._order or 0) + 1
    return self._order
end

local function register(self, name, getter, setter)
    Library.Registry[(self._path or "") .. "/" .. tostring(name)] = { get = getter, set = setter }
end

local function separator(parent)
    local line = create("Frame", {
        Size = UDim2.new(1, -16, 0, 1),
        Position = UDim2.new(0, 8, 1, -1),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.5,
    }, parent)
    bind(line, "BackgroundColor3", "Stroke")
end

local function newOuter(self, name)
    local outer = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = self:_nextOrder(),
    }, self.List)
    outer:SetAttribute("SearchName", name or "")
    listLayout(outer, 0)
    return outer
end

local function attachTip(self, row, name, tip)
    if not tip or tip == "" then
        return
    end
    local token, hovering = 0, false
    local function show()
        self.Window:_tip(name, tip)
    end
    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            token += 1
            local mine = token
            task.delay(0.5, function()
                if token == mine then
                    show()
                end
            end)
        end
    end)
    row.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            token += 1
        end
    end)
    row.MouseEnter:Connect(function()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            return
        end
        hovering = true
        task.delay(0.8, function()
            if hovering then
                show()
            end
        end)
    end)
    row.MouseLeave:Connect(function()
        hovering = false
    end)
end

local function subPanel(self, parentOuter, order)
    local panel = create("Frame", {
        Size = UDim2.new(1, -16, 0, 0),
        Position = UDim2.fromOffset(8, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = order,
    }, parentOuter)
    bind(panel, "BackgroundColor3", "Surface2")
    corner(panel, 4)
    stroke(panel, "Stroke", 0.3)
    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, panel)
    pad(inner, 0, 0, 3, 3)
    listLayout(inner, 0)
    local sub = setmetatable({
        List = inner,
        _order = 0,
        Window = self.Window,
        _path = (self._path or "") .. "/sub",
        Frame = panel,
    }, Container)
    return sub, panel
end

-- ---------- Toggle ----------
function Container:Toggle(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
    }, outer)
    separator(row)
    local locked = (opts.Premium and Library.Access ~= "VIP") or opts.Disabled == true
    local nameRow = create("Frame", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -110, 1, 0),
        BackgroundTransparency = 1,
    }, row)
    local nameLayout = listLayout(nameRow, 6, Enum.FillDirection.Horizontal)
    nameLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    label(nameRow, opts.Name, 13, locked and "Muted" or "Text", false, {
        LayoutOrder = 1,
        Size = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.X,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    if opts.Premium then
        local star = label(nameRow, "★", 13, "Text", true, {
            LayoutOrder = 2,
            Size = UDim2.fromOffset(14, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        })
        star.TextColor3 = Color3.fromRGB(80, 170, 255)
        bind(star, "TextColor3", function()
            return Color3.fromRGB(80, 170, 255)
        end)
    end
    if opts.Warning then
        label(nameRow, "⚠", 13, "Warning", true, {
            LayoutOrder = 3,
            Size = UDim2.fromOffset(14, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        })
    end
    local state = opts.Default == true and not locked
    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(34, 18),
        BorderSizePixel = 0,
    }, row)
    corner(pill, 9)
    stroke(pill, "Stroke", 0.2)
    bind(pill, "BackgroundColor3", function()
        return state and Library.Theme.Accent or Library.Theme.Surface3
    end)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        BackgroundTransparency = locked and 0.55 or 0,
    }, pill)
    corner(knob, 6)
    local function paint(instant)
        local target = state and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        local color = state and Library.Theme.Accent or Library.Theme.Surface3
        if instant then
            knob.Position = target
            pill.BackgroundColor3 = color
        else
            tween(knob, { Position = target }, 0.12)
            tween(pill, { BackgroundColor3 = color }, 0.12)
        end
    end
    paint(true)
    local object = { Value = state, Frame = outer }
    function object:Set(value, silent)
        if locked then
            return
        end
        state = value == true
        self.Value = state
        paint()
        if not silent then
            safeCall(opts.Callback, state)
        end
    end
    function object:Get()
        return state
    end
    row.MouseButton1Click:Connect(function()
        if locked then
            Library:Notify({
                Title = "BBC HUB",
                Content = opts.Premium and "Recurso exclusivo VIP." or "Indisponível.",
                Duration = 2,
            })
            return
        end
        object:Set(not state)
    end)
    register(self, opts.Name, function()
        return state
    end, function(value)
        object:Set(value)
    end)
    attachTip(self, row, opts.Name, opts.Tooltip)

    if type(opts.Settings) == "function" then
        local gear = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -(12 + 34 + 6), 0.5, 0),
            Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 3,
        }, row)
        local gearIcon = icon(gear, opts.SettingsIcon or "settings", 17, "Text", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            ZIndex = 3,
        })
        local sub, panel = subPanel(self, outer, 2)
        local open = false
        gear.MouseButton1Click:Connect(function()
            open = not open
            panel.Visible = open
            gearIcon.ImageColor3 = open and Library.Theme.Accent or Library.Theme.Text
        end)
        object.SettingsPanel = sub
        safeCall(opts.Settings, sub)
    end
    if state then
        safeCall(opts.Callback, state)
    end
    return object
end

-- ---------- Player Preview ----------
function Container:PlayerPreview(opts)
    opts = opts or {}
    local parentList = self.List
    if type(self._column) == "function" then
        parentList = self:_column(opts.Side or "Left")
        self.List.Visible = false
    end
    local outer = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = opts.Order or 0,
    }, parentList)
    outer:SetAttribute("SearchName", "Player Preview")
    listLayout(outer, 0)

    local card = create("Frame", { Size = UDim2.new(1, 0, 0, 236), BackgroundTransparency = 0.3 }, outer)
    bind(card, "BackgroundColor3", "Surface2")
    corner(card, 6)
    stroke(card, "Accent", 0.3)
    label(card, "PREVIEW", 11, "Muted", true, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(70, 16) })
    local nameLabel = label(card, "", 11, "Accent", false, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 8),
        Size = UDim2.fromOffset(95, 16),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    nameLabel.Text = LocalPlayer.DisplayName or LocalPlayer.Name

    local characterArea = create("Frame", {
        Position = UDim2.fromOffset(10, 28),
        Size = UDim2.new(1, -20, 0, 148),
        BackgroundTransparency = 0.8,
    }, card)
    bind(characterArea, "BackgroundColor3", "Background")
    corner(characterArea, 4)

    local viewport = create("ViewportFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(170, 170, 170),
        LightColor = Color3.new(1, 1, 1),
        LightDirection = Vector3.new(-1, -0.6, -1),
    }, characterArea)
    corner(viewport, 4)
    local world = create("WorldModel", {}, viewport)
    local camera = create("Camera", { FieldOfView = 30, CameraType = Enum.CameraType.Scriptable }, viewport)
    viewport.CurrentCamera = camera

    local healthLabel = label(characterArea, "100", 10, "Accent", false, {
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(40, 14),
        ZIndex = 2,
    })
    label(characterArea, "1000m", 10, "Muted", false, {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -4),
        Size = UDim2.fromOffset(50, 14),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 2,
    })

    -- ---------- avatar 3D ----------
    local model, basePivot, yaw = nil, CFrame.new(), 0
    local healthConnection
    local function setHealth(health)
        healthLabel.Text = tostring(math.clamp(math.floor((tonumber(health) or 0) + 0.5), 0, 9999))
    end
    local function mount(instance, healthSource)
        if healthConnection then
            healthConnection:Disconnect()
            healthConnection = nil
        end
        if model then
            model:Destroy()
            model = nil
        end
        model = instance
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanQuery = false
                descendant.CanTouch = false
                descendant.LocalTransparencyModifier = 0
            elseif descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
                descendant:Destroy()
            end
        end
        model.Parent = world
        local boundingBox, size = model:GetBoundingBox()
        basePivot = model:GetPivot() - boundingBox.Position
        yaw = 0
        model:PivotTo(basePivot)
        local maxDimension = math.max(size.X, size.Y, size.Z)
        local distance = (maxDimension > 0 and maxDimension or 6) * 2.2
        camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -distance), Vector3.new(0, 0, 0))
        viewport.CurrentCamera = camera
        local mounted = model
        task.defer(function()
            if mounted == model and mounted.Parent == world then
                mounted.Parent = nil
                mounted.Parent = world
                viewport.CurrentCamera = camera
            end
        end)
        local humanoid = healthSource or model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Parent then
            setHealth(humanoid.Health)
            healthConnection = humanoid.HealthChanged:Connect(setHealth)
        else
            setHealth(100)
        end
    end

    local function fallbackFigure()
        local figure = Instance.new("Model")
        local function piece(name, size, position)
            return create("Part", {
                Name = name,
                Size = size,
                Position = position,
                Anchored = true,
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                Material = Enum.Material.SmoothPlastic,
                Color = Color3.fromRGB(45, 215, 105),
                TopSurface = Enum.SurfaceType.Smooth,
                BottomSurface = Enum.SurfaceType.Smooth,
            }, figure)
        end
        piece("Head", Vector3.new(2, 2, 2), Vector3.new(0, 4.6, 0))
        piece("Torso", Vector3.new(4, 4, 2), Vector3.new(0, 1.6, 0))
        piece("Left Arm", Vector3.new(1, 4, 1), Vector3.new(-2.5, 1.6, 0))
        piece("Right Arm", Vector3.new(1, 4, 1), Vector3.new(2.5, 1.6, 0))
        piece("Left Leg", Vector3.new(1.6, 4, 1), Vector3.new(-1, -2.4, 0))
        piece("Right Leg", Vector3.new(1.6, 4, 1), Vector3.new(1, -2.4, 0))
        return figure
    end

    local function loadAvatar()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local archivable = character.Archivable
            character.Archivable = true
            local ok, clone = pcall(function()
                return character:Clone()
            end)
            character.Archivable = archivable
            if ok and clone then
                mount(clone, humanoid)
                return
            end
        end
        task.spawn(function()
            local ok, avatar = pcall(function()
                return Players:CreateHumanoidModelFromUserId(LocalPlayer.UserId)
            end)
            if ok and avatar and world.Parent then
                mount(avatar)
            end
        end)
    end
    mount(fallbackFigure())
    loadAvatar()

    local characterConnection = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if world.Parent then
            loadAvatar()
        end
    end)

    -- ---------- botões rápidos ----------
    local buttonRow = create("Frame", {
        Position = UDim2.fromOffset(10, 184),
        Size = UDim2.new(1, -20, 0, 44),
        BackgroundTransparency = 1,
    }, card)
    create("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -3, 0, 20),
        CellPadding = UDim2.fromOffset(4, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, buttonRow)
    local buttons = { "Highlight", "Box", "KDR", "Reports", "Tracers", "Arrows" }
    for index, buttonName in ipairs(buttons) do
        local state = false
        local button = create("TextButton", {
            Size = UDim2.fromScale(1, 1),
            Text = buttonName,
            TextSize = 9,
            FontFace = Library.Fonts.Regular,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = index,
            BackgroundTransparency = 0.2,
        }, buttonRow)
        corner(button, 3)
        bind(button, "BackgroundColor3", function()
            return state and Library.Theme.Accent or Library.Theme.Surface3
        end)
        bind(button, "TextColor3", function()
            return state and Color3.fromRGB(20, 20, 20) or Library.Theme.Text
        end)
        local function paint()
            button.BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.Surface3
            button.TextColor3 = state and Color3.fromRGB(20, 20, 20) or Library.Theme.Text
        end
        paint()
        button.MouseButton1Click:Connect(function()
            state = not state
            paint()
            Library:Notify({
                Title = "BBC HUB",
                Content = buttonName .. (state and " ativado" or " desativado"),
                Duration = 1.5,
            })
        end)
    end

    local connection
    connection = RunService.RenderStepped:Connect(function(deltaTime)
        if not card.Parent then
            connection:Disconnect()
            if characterConnection then
                characterConnection:Disconnect()
            end
            if healthConnection then
                healthConnection:Disconnect()
            end
            return
        end
        if viewport.CurrentCamera ~= camera then
            viewport.CurrentCamera = camera
        end
        if model then
            yaw += deltaTime * 0.5
            model:PivotTo(CFrame.Angles(0, yaw, 0) * basePivot)
        end
    end)

    return { Frame = outer, Viewport = viewport, Card = card }
end

-- ---------- Slider ----------
function Container:Slider(opts)
    opts = opts or {}
    local min, max = opts.Min or 0, opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local decimals = 0
    if step < 1 then
        decimals = #(string.match(tostring(step), "%.(%d+)") or "")
    end
    local value = math.clamp(opts.Default or min, min, max)
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -90, 0, 18) })
    local valueLabel = label(row, "", 13, "Muted", false, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 4),
        Size = UDim2.fromOffset(80, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = create("Frame", { Position = UDim2.fromOffset(18, 29), Size = UDim2.new(1, -36, 0, 5), BorderSizePixel = 0 }, row)
    bind(track, "BackgroundColor3", "Surface3")
    corner(track, 3)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
    bind(fill, "BackgroundColor3", "Accent")
    corner(fill, 3)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(13, 13),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, track)
    bind(knob, "BackgroundColor3", "Background")
    corner(knob, 7)
    local knobStroke = create("UIStroke", { Thickness = 2 }, knob)
    bind(knobStroke, "Color", "Accent")
    local function format(current)
        if decimals > 0 then
            return string.format("%." .. decimals .. "f", current)
        end
        return tostring(math.floor(current + 0.5))
    end
    local function paint()
        local fraction = (max > min) and (value - min) / (max - min) or 0
        fill.Size = UDim2.fromScale(fraction, 1)
        knob.Position = UDim2.fromScale(fraction, 0.5)
        valueLabel.Text = format(value) .. suffix
    end
    paint()
    local object = { Value = value, Frame = outer }
    function object:Set(newValue, silent)
        newValue = math.clamp(tonumber(newValue) or min, min, max)
        newValue = math.floor((newValue - min) / step + 0.5) * step + min
        newValue = math.clamp(newValue, min, max)
        value = newValue
        self.Value = newValue
        paint()
        if not silent then
            safeCall(opts.Callback, newValue)
        end
    end
    local hit = create("TextButton", {
        Position = UDim2.fromOffset(6, 18),
        Size = UDim2.new(1, -12, 0, 26),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 3,
    }, row)
    local dragging = false
    local function fromInput(position)
        local width = track.AbsoluteSize.X
        if width <= 0 then
            return
        end
        local relative = math.clamp((position.X - track.AbsolutePosition.X) / width, 0, 1)
        object:Set(min + relative * (max - min))
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromInput(input.Position)
        end
    end)
    self.Window:_connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromInput(input.Position)
        end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    register(self, opts.Name, function()
        return value
    end, function(newValue)
        object:Set(newValue)
    end)
    attachTip(self, row, opts.Name, opts.Tooltip)
    return object
end

-- ---------- Dropdown ----------
function Container:Dropdown(opts)
    opts = opts or {}
    local options = opts.Options or {}
    local flags = opts.Flags
    local multi = opts.Multi == true
    local selected = {}
    local function setDefault(default)
        selected = {}
        if type(default) == "table" then
            for _, value in ipairs(default) do
                selected[value] = true
            end
        elseif default ~= nil then
            selected[default] = true
        end
    end
    setDefault(opts.Default)
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
    }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -150, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local chip = chipBox(row)
    pad(chip, 7, 6, 0, 0)
    local chipLayout = listLayout(chip, 6, Enum.FillDirection.Horizontal)
    chipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    local flagHolder
    if flags then
        flagHolder = create("Frame", { Size = UDim2.fromOffset(22, 15), BackgroundTransparency = 1, LayoutOrder = 0 }, chip)
    end
    local valueLabel = label(chip, "", 12, "Text", false, {
        LayoutOrder = 1,
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        TextTruncate = Enum.TextTruncate.None,
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local arrow = label(chip, "▶", 9, "Text", false, {
        LayoutOrder = 2,
        Size = UDim2.fromOffset(10, 24),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local list = create("Frame", {
        Size = UDim2.new(1, -16, 0, 0),
        Position = UDim2.fromOffset(8, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 2,
    }, outer)
    bind(list, "BackgroundColor3", "Surface2")
    corner(list, 4)
    stroke(list, "Stroke", 0.3)
    pad(list, 4, 4, 4, 4)
    listLayout(list, 2)
    local buttons = {}
    local function ordered()
        local result = {}
        for _, option in ipairs(options) do
            if selected[option] then
                table.insert(result, option)
            end
        end
        return result
    end
    local function text()
        local order = ordered()
        if #order == 0 then
            return multi and "—" or ""
        end
        if multi and #order > 1 then
            return order[1] .. " +" .. (#order - 1)
        end
        return order[1]
    end
    local function paint()
        valueLabel.Text = text()
        if flagHolder then
            for _, child in ipairs(flagHolder:GetChildren()) do
                child:Destroy()
            end
            local first = ordered()[1]
            if first and flags[first] then
                makeFlag(flagHolder, flags[first])
            end
        end
        for option, button in pairs(buttons) do
            local active = selected[option] == true
            button.BackgroundTransparency = active and 0.15 or 1
            button.TextColor3 = active and Color3.new(1, 1, 1) or Library.Theme.Text
        end
    end
    local function current()
        if multi then
            return ordered()
        end
        return ordered()[1]
    end
    local object = { Frame = outer }
    local function closeList()
        list.Visible = false
        arrow.Text = "▶"
    end
    function object:Set(value, silent)
        setDefault(value)
        paint()
        if not silent then
            safeCall(opts.Callback, current())
        end
    end
    function object:Get()
        return current()
    end
    function object:SetOptions(newOptions)
        options = newOptions
        for _, button in pairs(buttons) do
            button:Destroy()
        end
        buttons = {}
        for index, option in ipairs(options) do
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, flags and 28 or 26),
                BackgroundTransparency = 1,
                Text = option,
                TextSize = 13,
                FontFace = Library.Fonts.Regular,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                LayoutOrder = index,
                BorderSizePixel = 0,
            }, list)
            bind(button, "BackgroundColor3", "Accent")
            corner(button, 3)
            pad(button, flags and 38 or 14, 6, 0, 0)
            if flags and flags[option] then
                makeFlag(button, flags[option], { Position = UDim2.new(0, -28, 0.5, -7.5) })
            end
            buttons[option] = button
            button.MouseButton1Click:Connect(function()
                if multi then
                    selected[option] = not selected[option] or nil
                else
                    selected = { [option] = true }
                    closeList()
                end
                paint()
                safeCall(opts.Callback, current())
            end)
        end
        paint()
    end
    object:SetOptions(options)
    local function toggleList()
        list.Visible = not list.Visible
        arrow.Text = list.Visible and "▼" or "▶"
    end
    row.MouseButton1Click:Connect(toggleList)
    chip.MouseButton1Click:Connect(toggleList)
    register(self, opts.Name, current, function(value)
        object:Set(value, true)
    end)
    return object
end

-- ---------- Keybind ----------
function Container:Keybind(opts)
    opts = opts or {}
    local value = parseKey(opts.Default)
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -110, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local chip, chipStroke = chipBox(row)
    chip.AutomaticSize = Enum.AutomaticSize.None
    local chipLabel = label(chip, keyText(value), 12, "Text", false, {
        Size = UDim2.fromScale(1, 1),
        TextTruncate = Enum.TextTruncate.None,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local function fit(text)
        chip.Size = UDim2.fromOffset(math.max(46, textWidth(text, 12) + 22), 24)
    end
    fit(chipLabel.Text)
    local listening = false
    local object = { Frame = outer }
    local function show(text)
        chipLabel.Text = text
        fit(text)
    end
    function object:Set(newValue, silent)
        value = parseKey(newValue)
        self.Value = value
        show(keyText(value))
        Library:_kbChanged()
        if not silent then
            safeCall(opts.OnChanged, value)
        end
    end
    function object:Get()
        return value
    end
    object.Value = value
    local function beginListen()
        listening = true
        Library._listening = true
        chipStroke.Color = Library.Theme.Accent
        show("...")
        Library:_kbChanged()
    end
    table.insert(Library.Keybinds, {
        name = opts.Name,
        get = function()
            return value
        end,
        begin = beginListen,
        listening = function()
            return listening
        end,
    })
    chip.MouseButton1Click:Connect(beginListen)
    self.Window:_connect(UserInputService.InputBegan, function(input, processed)
        local inputType = input.UserInputType
        local isMouse = inputType == Enum.UserInputType.MouseButton2 or inputType == Enum.UserInputType.MouseButton3
        if inputType ~= Enum.UserInputType.Keyboard and not isMouse then
            return
        end
        local code = isMouse and inputType or input.KeyCode
        if listening then
            listening = false
            Library._listening = false
            Library._lastBind = os.clock()
            chipStroke.Color = Library.Theme.Stroke
            if code == Enum.KeyCode.Escape then
                show(keyText(value))
                Library:_kbChanged()
            else
                object:Set(code)
            end
            return
        end
        if not processed and value ~= nil and code == value then
            safeCall(opts.Callback, code)
        end
    end)
    register(self, opts.Name, function()
        return value and value.Name or "None"
    end, function(newValue)
        object:Set(newValue)
    end)
    return object
end

-- ---------- Botão ----------
function Container:Button(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
        BorderSizePixel = 0,
    }, outer)
    bind(row, "BackgroundColor3", "Accent")
    separator(row)
    label(row, opts.Name, 13, "Text", false, {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -40, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    if opts.Arrow then
        label(row, "▶", 11, "Text", false, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(14, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
    end
    row.MouseButton1Click:Connect(function()
        row.BackgroundTransparency = 0.8
        tween(row, { BackgroundTransparency = 1 }, 0.25)
        safeCall(opts.Callback)
    end)
    return { Frame = outer }
end

-- ---------- Input ----------
function Container:Input(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -130, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local box = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(100, 22),
        Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "",
        ClearTextOnFocus = false,
        TextSize = 12,
        FontFace = Library.Fonts.Regular,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.2,
    }, row)
    bind(box, "BackgroundColor3", "Background")
    bind(box, "TextColor3", "Text")
    bind(box, "PlaceholderColor3", "Muted")
    corner(box, 3)
    stroke(box, "Stroke", 0.1)
    box.FocusLost:Connect(function()
        safeCall(opts.Callback, box.Text)
    end)
    register(self, opts.Name, function()
        return box.Text
    end, function(value)
        box.Text = tostring(value)
    end)
    return { Frame = outer, Box = box }
end

-- ---------- Seletor de cor ----------
local PALETTE = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 160, 160), Color3.fromRGB(30, 30, 30),
    Color3.fromRGB(240, 52, 72), Color3.fromRGB(255, 130, 25), Color3.fromRGB(255, 205, 40),
    Color3.fromRGB(45, 215, 105), Color3.fromRGB(30, 175, 245), Color3.fromRGB(110, 90, 255),
    Color3.fromRGB(242, 85, 175),
}

function Container:ColorPicker(opts)
    opts = opts or {}
    local color = opts.Default or Color3.fromRGB(255, 255, 255)
    local hue, saturation, value = color:ToHSV()
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
    }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -120, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local arrow = label(row, "▶", 9, "Text", false, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(10, 16),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local swatch = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -28, 0.5, 0),
        Size = UDim2.fromOffset(32, 18),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
    }, row)
    corner(swatch, 4)
    stroke(swatch, "Stroke", 0.1)
    local panel = create("Frame", {
        Size = UDim2.new(1, -16, 0, 150),
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 2,
    }, outer)
    bind(panel, "BackgroundColor3", "Surface2")
    corner(panel, 4)
    stroke(panel, "Stroke", 0.3)
    local saturationValue = create("TextButton", {
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -16, 0, 84),
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
    }, panel)
    corner(saturationValue, 4)
    local white = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, saturationValue)
    corner(white, 4)
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, white)
    local black = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, saturationValue)
    corner(black, 4)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, black)
    local saturationKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, saturationValue)
    corner(saturationKnob, 6)
    create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, saturationKnob)
    local hueBar = create("TextButton", {
        Position = UDim2.fromOffset(8, 100),
        Size = UDim2.new(1, -16, 0, 12),
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, panel)
    corner(hueBar, 6)
    local sequence = {}
    for index = 0, 6 do
        sequence[#sequence + 1] = ColorSequenceKeypoint.new(
            index / 6,
            Color3.fromHSV(index / 6 % 1 == 0 and (index == 6 and 0.9999 or 0) or index / 6, 1, 1)
        )
    end
    create("UIGradient", { Color = ColorSequence.new(sequence) }, hueBar)
    local hueKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(6, 16),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
    }, hueBar)
    corner(hueKnob, 3)
    create("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }, hueKnob)
    local hex = create("TextBox", {
        Position = UDim2.fromOffset(8, 120),
        Size = UDim2.fromOffset(70, 22),
        Text = "",
        TextSize = 12,
        FontFace = Library.Fonts.Regular,
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
    }, panel)
    bind(hex, "BackgroundColor3", "Background")
    bind(hex, "TextColor3", "Text")
    corner(hex, 3)
    stroke(hex, "Stroke", 0.1)
    local object = { Frame = outer }
    local function apply(silent)
        color = Color3.fromHSV(hue, saturation, value)
        swatch.BackgroundColor3 = color
        saturationValue.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        saturationKnob.Position = UDim2.fromScale(saturation, 1 - value)
        hueKnob.Position = UDim2.fromScale(hue, 0.5)
        hex.Text = "#" .. color:ToHex():upper()
        object.Value = color
        if not silent then
            safeCall(opts.Callback, color)
        end
    end
    local paletteX = 84
    for index, paletteColor in ipairs(PALETTE) do
        local button = create("TextButton", {
            Position = UDim2.fromOffset(paletteX + (index - 1) * 19, 122),
            Size = UDim2.fromOffset(16, 16),
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = paletteColor,
            BorderSizePixel = 0,
        }, panel)
        corner(button, 8)
        create("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.7 }, button)
        button.MouseButton1Click:Connect(function()
            hue, saturation, value = paletteColor:ToHSV()
            apply()
        end)
    end
    row.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
        arrow.Text = panel.Visible and "▼" or "▶"
    end)
    local draggingSV, draggingHue = false, false
    local function fromSV(position)
        local size = saturationValue.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then
            return
        end
        saturation = math.clamp((position.X - saturationValue.AbsolutePosition.X) / size.X, 0, 1)
        value = 1 - math.clamp((position.Y - saturationValue.AbsolutePosition.Y) / size.Y, 0, 1)
        apply()
    end
    local function fromHue(position)
        local width = hueBar.AbsoluteSize.X
        if width <= 0 then
            return
        end
        hue = math.clamp((position.X - hueBar.AbsolutePosition.X) / width, 0, 0.999)
        apply()
    end
    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
    end
    saturationValue.InputBegan:Connect(function(input)
        if isPress(input) then
            draggingSV = true
            fromSV(input.Position)
        end
    end)
    hueBar.InputBegan:Connect(function(input)
        if isPress(input) then
            draggingHue = true
            fromHue(input.Position)
        end
    end)
    self.Window:_connect(UserInputService.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if draggingSV then
                fromSV(input.Position)
            elseif draggingHue then
                fromHue(input.Position)
            end
        end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(input)
        if isPress(input) then
            draggingSV, draggingHue = false, false
        end
    end)
    hex.FocusLost:Connect(function()
        local text = string.gsub(hex.Text, "#", "")
        local ok, newColor = pcall(Color3.fromHex, text)
        if ok and newColor then
            hue, saturation, value = newColor:ToHSV()
        end
        apply()
    end)
    function object:Set(newColor, silent)
        hue, saturation, value = newColor:ToHSV()
        apply(silent)
    end
    apply(true)
    register(self, opts.Name, function()
        return { color.R, color.G, color.B }
    end, function(newColor)
        if type(newColor) == "table" then
            object:Set(Color3.new(newColor[1], newColor[2], newColor[3]))
        end
    end)
    return object
end

-- ---------- Seção que abre ----------
function Container:Foldout(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1,
    }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -40, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local arrow = label(row, "▶", 11, "Text", false, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(14, 16),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local sub, panel = subPanel(self, outer, 2)
    row.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
        arrow.Text = panel.Visible and "▼" or "▶"
    end)
    safeCall(opts.Build, sub)
    return { Frame = outer, Panel = sub }
end

-- ---------- Botões lado a lado ----------
function Container:Segmented(opts)
    opts = opts or {}
    local options, icons = opts.Options or {}, opts.Icons or {}
    local selected = opts.Default or options[1]
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    local holder = create("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 28), BackgroundTransparency = 1 }, row)
    listLayout(holder, 4, Enum.FillDirection.Horizontal)
    local count = math.max(#options, 1)
    local items = {}
    local object = { Frame = outer }
    local function paint()
        for option, item in pairs(items) do
            local active = option == selected
            item.stroke.Color = active and Library.Theme.Accent or Library.Theme.Stroke
            item.stroke.Thickness = active and 1.5 or 1
            item.button.BackgroundColor3 = active and Library.Theme.Surface3 or Library.Theme.Surface2
            item.text.TextColor3 = active and Library.Theme.Text or Library.Theme.Muted
            if item.icon then
                item.icon.ImageColor3 = active and Library.Theme.Accent or Library.Theme.Muted
            end
        end
    end
    for index, option in ipairs(options) do
        local button = create("TextButton", {
            Size = UDim2.new(1 / count, -4 * (count - 1) / count, 1, 0),
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = index,
            BorderSizePixel = 0,
        }, holder)
        corner(button, 4)
        local itemStroke = create("UIStroke", { Thickness = 1 }, button)
        local itemIcon = icons[index] and icon(button, icons[index], 14, "Muted", { Position = UDim2.new(0, 7, 0.5, -7) }) or nil
        local itemText = label(button, option, 12, "Muted", false, {
            Position = UDim2.fromOffset(itemIcon and 24 or 6, 0),
            Size = UDim2.new(1, itemIcon and -28 or -12, 1, 0),
            TextYAlignment = Enum.TextYAlignment.Center,
            TextXAlignment = itemIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
        })
        items[option] = { button = button, stroke = itemStroke, text = itemText, icon = itemIcon }
        button.MouseButton1Click:Connect(function()
            selected = option
            paint()
            safeCall(opts.Callback, option)
        end)
    end
    paint()
    table.insert(Library._themeListeners, paint)
    function object:Set(newValue, silent)
        selected = newValue
        paint()
        if not silent then
            safeCall(opts.Callback, newValue)
        end
    end
    register(self, opts.Name, function()
        return selected
    end, function(value)
        object:Set(value)
    end)
    return object
end

-- ---------- Texto ----------
function Container:Label(opts)
    opts = type(opts) == "table" and opts or { Text = opts }
    local outer = newOuter(self, opts.Text)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, outer)
    local textLabel = label(row, opts.Text, 12, "Muted", false, {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    return {
        Frame = outer,
        Label = textLabel,
        Set = function(_, text)
            textLabel.Text = text
        end,
    }
end

function Container:Section(text)
    local outer = newOuter(self, text)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, outer)
    label(row, string.upper(text or ""), 12, "Muted", true, {
        Position = UDim2.fromOffset(12, 4),
        Size = UDim2.new(1, -24, 0, 18),
    })
    return { Frame = outer }
end

-- ============================================================
--  Helpers de alto nível usados pelas features
-- ============================================================
local GEARS = {}
for _, name in ipairs({
    "Jogador", "NPCs", "Corpo", "Recipiente", "Item no chão", "Itens de missão", "Mochila personalizada", "Mochila", "Barra rápida",
    "Aura", "Círculo de salto", "Auréola", "Rastro estelar",
    "Hack de velocidade", "Sprint automático", "Voar", "Aranha", "Deslocamento", "Trocar personagem", "Personagem",
    "Corpo em 1ª pessoa", "Mãos", "Item na mão", "Terceira pessoa", "Câmera livre", "Saque automático", "Painel do jogador",
    "Renascer automático", "Remover água",
    "Pausa inteligente", "Tiro por paredes", "Aura letal", "Espiada subterrânea", "Anti aim", "Sob o chão", "Fantasma",
    "Trajetória do arremesso", "Recarga automática", "Abastecer cargadores", "Mira falsa", "Retícula", "Círculo da mira",
    "Rastro personalizado", "Marca de acerto", "Números de dano", "Efeitos de acerto", "Efeitos de eliminação", "Dados do alvo",
    "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens", "Florescer", "Desfoque",
    "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade", "Buscar chefes", "Pontos de saída", "Radar",
    "Modo pânico", "Avisos de entrada", "Criador", "Testador", "Moderador", "Trapaceiro", "Jump", "Pegadas", "Pouso",
    "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue", "Fundo", "Sombra", "Destaque próprio",
}) do
    GEARS[name] = true
end

local PREMIUM = {
    ["Anti aim"] = true,
    ["Sob o chão"] = true,
    ["Espiada subterrânea"] = true,
    ["Saque automático"] = true,
    ["Sem dano de queda"] = true,
}

local SETTINGS_ICON = {
    ["Notificar"] = "message-circle",
    ["Avisos de denúncias"] = "message-circle",
}

GEARS["Notificar"] = true
GEARS["Avisos de denúncias"] = true

local TIPS = {
    ["Transp. fundo"] = "Ajusta a transparência do fundo.",
    ["Transp. do texto"] = "Ajusta a transparência do texto.",
    ["Transp. da borda"] = "Ajusta a transparência da borda.",
    ["Raio dos cantos"] = "Arredonda os cantos do painel.",
    ["Largura"] = "Define a largura do painel.",
    ["Altura máxima"] = "Define a altura máxima do painel.",
    ["Tamanho"] = "Muda o tamanho do painel.",
    ["Suavização"] = "Quanto maior, mais suave o movimento.",
    ["Raio da mira"] = "Alcance do círculo da mira.",
    ["Cursor livre"] = "Segure a tecla do cursor para liberar o mouse.",
    ["Limite de verificações"] = "Quantas checagens por quadro.",
    ["Fixar"] = "Impede que o painel seja arrastado.",
}

local function buildSettings(name)
    return function(panel)
        if name == "Jogador" then
            local built = false
            local function ensure()
                if built then
                    return
                end
                built = true
                panel:PlayerPreview({})
            end
            if panel.Frame then
                panel.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
                    if panel.Frame.Visible then
                        ensure()
                    end
                end)
                if panel.Frame.Visible then
                    ensure()
                end
            else
                ensure()
            end
        end
        panel:Dropdown({
            Name = "Modo",
            Options = { "Sempre", "Ao segurar", "Alternar" },
            Default = "Alternar",
            Callback = function() end,
        })
        panel:Slider({ Name = "Intensidade", Min = 0, Max = 100, Default = 50, Suffix = "%", Callback = function() end })
        panel:Slider({ Name = "Distância", Min = 10, Max = 1000, Default = 300, Suffix = "m", Callback = function() end })
        panel:Toggle({ Name = "Notificar", Default = false, Callback = function() end })
    end
end

local Controls = {
    GEARS = GEARS,
    PREMIUM = PREMIUM,
    SETTINGS_ICON = SETTINGS_ICON,
    TIPS = TIPS,
    buildSettings = buildSettings,
}

function Controls.T(tab, name, default, tip)
    local opts = {
        Name = name,
        Default = default or false,
        Tooltip = tip or TIPS[name],
        Callback = function() end,
    }
    if GEARS[name] then
        opts.Settings = buildSettings(name)
        opts.SettingsIcon = SETTINGS_ICON[name]
    end
    if PREMIUM[name] then
        opts.Premium = true
    end
    if name == "Buscar chefes" then
        opts.Warning = true
    end
    return tab:Toggle(opts)
end

function Controls.S(tab, name, min, max, default, suffix, step)
    return tab:Slider({
        Name = name,
        Min = min,
        Max = max,
        Default = default,
        Suffix = suffix or "",
        Step = step or 1,
        Tooltip = TIPS[name],
        Callback = function() end,
    })
end

BBC.UI = BBC.UI or {}
BBC.UI.Container = Container
BBC.UI.register = register
BBC.UI.newOuter = newOuter
BBC.UI.separator = separator
BBC.UI.subPanel = subPanel
BBC.UI.Controls = Controls

return Container

end)

-- ============================================================
-- módulo: ui.window  (ui/window.lua)
-- ============================================================
__module("ui.window", function(BBC)
--[[
    BBC HUB - Window
    Abas, grupos, janela principal, persistência de configuração,
    ilha de FPS e overlays (watermark / lista de atalhos).
]]

local Library = BBC.Library
local Utils = BBC.Utils
local Security = BBC.Security

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local create = Utils.create
local corner = Utils.corner
local stroke = Utils.stroke
local pad = Utils.pad
local listLayout = Utils.listLayout
local tween = Utils.tween
local label = Utils.label
local icon = Utils.icon
local bind = Utils.bind
local keyText = Utils.keyText
local parseKey = Utils.parseKey
local safeCall = Security.safeCall
local guiParent = Utils.guiParent

local Container = BBC.UI.Container
local Tab = setmetatable({}, { __index = Container })
Tab.__index = Tab
local Window = {}
Window.__index = Window

local CFG_FOLDER = "BBC_HUB/configs"

local function canFS()
    return Security.canFS()
end

local function fmtLeft(seconds)
    seconds = math.max(math.floor(seconds), 0)
    local days = math.floor(seconds / 86400)
    local hours = math.floor(seconds % 86400 / 3600)
    local minutes = math.floor(seconds % 3600 / 60)
    if days > 0 then
        return days .. "d " .. hours .. "h"
    end
    return hours .. "h " .. minutes .. "m"
end

function Window:_connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self._conns, connection)
    return connection
end

-- colunas com rolagem independente (criadas na primeira vez que se usa Groupbox)
function Tab:_column(side)
    if not self._cols then
        self.List.Visible = false
        local holder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, self.Page)
        self._cols = {}
        for index, name in ipairs({ "Left", "Right" }) do
            local scroller = create("ScrollingFrame", {
                Size = UDim2.new(0.5, -4, 1, 0),
                Position = UDim2.new(index == 1 and 0 or 0.5, index == 1 and 0 or 4, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
            }, holder)
            bind(scroller, "ScrollBarImageColor3", "Accent")
            pad(scroller, 1, 6, 1, 10)
            listLayout(scroller, 8)
            self._cols[name] = scroller
        end
    end
    if side ~= "Left" and side ~= "Right" then
        local left, right = #self._cols.Left:GetChildren(), #self._cols.Right:GetChildren()
        side = left <= right and "Left" or "Right"
    end
    return self._cols[side]
end

function Tab:Groupbox(opts)
    opts = opts or {}
    local column = self:_column(opts.Side)
    local box = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        LayoutOrder = (#column:GetChildren()) + 1,
    }, column)
    bind(box, "BackgroundColor3", "Surface")
    corner(box, 4)
    local boxStroke = create("UIStroke", { Thickness = 1, Transparency = 0.2 }, box)
    bind(boxStroke, "Color", "Accent")
    listLayout(box, 0)
    local head = create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, box)
    local x = 10
    if opts.Icon then
        icon(head, opts.Icon, 15, "Text", { Position = UDim2.fromOffset(10, 6.5) })
        x = 31
    end
    label(head, opts.Name, 13, "Muted", false, {
        Position = UDim2.fromOffset(x, 0),
        Size = UDim2.new(1, -x - (opts.Checkbox and 36 or 8), 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    local checkboxObject
    if opts.Checkbox then
        local on = opts.Default ~= false
        local checkbox = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, head)
        corner(checkbox, 4)
        stroke(checkbox, "Accent", 0.1)
        bind(checkbox, "BackgroundColor3", function()
            return on and Library.Theme.Accent or Library.Theme.Surface3
        end)
        local mark = label(checkbox, "✓", 13, "Text", true, {
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = on,
        })
        checkboxObject = {}
        function checkboxObject:Set(value, silent)
            on = value == true
            checkbox.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface3
            mark.Visible = on
            if not silent then
                safeCall(opts.Callback, on)
            end
        end
        function checkboxObject:Get()
            return on
        end
        checkbox.MouseButton1Click:Connect(function()
            checkboxObject:Set(not on)
        end)
        BBC.UI.register(self, tostring(opts.Name) .. "#ativo", function()
            return on
        end, function(value)
            checkboxObject:Set(value)
        end)
        if on then
            safeCall(opts.Callback, true)
        end
    end
    local line = create("Frame", {
        Size = UDim2.new(1, -16, 0, 1),
        Position = UDim2.new(0, 8, 1, -1),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.4,
    }, head)
    bind(line, "BackgroundColor3", "Stroke")
    local body = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
    }, box)
    listLayout(body, 0)
    return setmetatable({
        List = body,
        _order = 0,
        Window = self.Window,
        _path = self._path .. "/" .. tostring(opts.Name),
        Frame = box,
        Checkbox = checkboxObject,
    }, Container)
end

function Window:_select(tab)
    if not tab then
        return
    end
    for _, current in ipairs(self.Tabs) do
        current.Page.Visible = (current == tab)
        if current.TabBtn then
            local on = current == tab
            current.Sel.BackgroundTransparency = on and 0 or 1
            current.Text.TextColor3 = on and Library.Theme.Text or Library.Theme.Muted
            current.IconImg.ImageColor3 = on and Library.Theme.Text or Library.Theme.Muted
            current.Active = on
        end
    end
    if self.HomeTab then
        self.HomeTab.Page.Visible = (tab == self.HomeTab)
    end
    self.Current = tab
    if self._flameBtn then
        local home = tab == self.HomeTab
        self._flameStroke.Color = home and Library.Theme.Accent or Library.Theme.Stroke
        self._flameIcon.ImageColor3 = home and Library.Theme.Accent or Library.Theme.Text
    end
    if self._gearBtn then
        local settings = tab and tab.IsSettings
        self._gearStroke.Color = settings and Library.Theme.Accent or Library.Theme.Stroke
        self._gearIcon.ImageColor3 = settings and Library.Theme.Accent or Library.Theme.Text
    end
end

function Window:Tab(opts)
    opts = opts or {}
    local tab = setmetatable({
        Name = opts.Name,
        Window = self,
        _order = 0,
        _path = tostring(opts.Name),
        IsSettings = (opts.Name == "CONFIGURAÇÕES") or opts.IsSettings,
    }, Tab)
    tab.Page = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, self._content)
    tab.List = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, tab.Page)
    bind(tab.List, "ScrollBarImageColor3", "Accent")
    pad(tab.List, 1, 6, 1, 10)
    listLayout(tab.List, 8)
    tab.Frame = tab.Page
    if opts.Hidden then
        if opts.Name == "Home" then
            self.HomeTab = tab
        end
        table.insert(self.Tabs, tab)
        return tab
    end
    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 27),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = #self.Tabs + 1,
    }, self._tabList)
    tab.TabBtn = button
    tab.Sel = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1 }, button)
    bind(tab.Sel, "BackgroundColor3", "Accent")
    corner(tab.Sel, 4)
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, tab.Sel)
    tab.IconImg = icon(button, opts.Icon or "circle", 16, "Muted", { Position = UDim2.fromOffset(12, 5.5) })
    tab.Text = label(button, string.upper(opts.Name or ""), 13, "Muted", false, {
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -40, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
    })
    table.insert(self.Tabs, tab)
    button.MouseButton1Click:Connect(function()
        self:_select(tab)
    end)
    if not self.Current or self.Current == self.HomeTab then
        self:_select(tab)
    end
    return tab
end

-- ---------- Configurações salvas ----------
function Window:SaveConfig(name)
    if not canFS() then
        Library:Notify({ Title = "BBC HUB", Content = "Salvar precisa de writefile no executor." })
        return false
    end
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("BBC_HUB") then
                makefolder("BBC_HUB")
            end
            if not isfolder(CFG_FOLDER) then
                makefolder(CFG_FOLDER)
            end
        end
    end)
    local data = {}
    for key, record in pairs(Library.Registry) do
        local ok, value = pcall(record.get)
        if ok and value ~= nil then
            data[key] = value
        end
    end
    local ok = pcall(function()
        writefile(CFG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    Library:Notify({
        Title = "BBC HUB",
        Content = ok and ("Configuração salva: " .. name) or "Falha ao salvar.",
    })
    return ok
end

function Window:LoadConfig(name)
    if not canFS() then
        return false
    end
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, data = pcall(function()
        if isfile(path) then
            return HttpService:JSONDecode(readfile(path))
        end
    end)
    if not ok or type(data) ~= "table" then
        return false
    end
    for key, value in pairs(data) do
        local record = Library.Registry[key]
        if record then
            pcall(record.set, value)
        end
    end
    Library:Notify({ Title = "BBC HUB", Content = "Configuração carregada: " .. name })
    return true
end

-- ---------- Identidade ----------
function Window:SetHideName(hidden)
    self._hideName = hidden == true
    self:_renderIdentity()
end

function Window:SetHideAvatar(hidden)
    self._hideAvatar = hidden == true
    self:_renderIdentity()
end

function Window:_renderIdentity()
    if not self._pName then
        return
    end
    self._pName.Text = self._hideName and "••••••" or LocalPlayer.DisplayName
    self._pAvatar.Image = self._hideAvatar and "" or (self._thumb or "")
end

-- ---------- Visibilidade e botão flutuante ----------
function Window:_updateIsland()
    if self._island then
        self._island.Visible = (self._islandOn ~= false) and not self._main.Visible
    end
end

function Window:SetIsland(on)
    self._islandOn = on == true
    self:_updateIsland()
end

function Window:SetVisible(visible)
    self._main.Visible = visible
    self:_updateIsland()
end

function Window:SetLogo(visible)
    self._logo.Visible = visible == true
end

function Window:SetBorderAccent(enabled)
    self._accentBorder = enabled == true
    self._mainStroke.Color = self._accentBorder and Library.Theme.Accent or Library.Theme.Stroke
end

function Window:SetBackgroundTransparency(transparency)
    self._main.BackgroundTransparency = math.clamp(transparency or 0, 0, 0.85)
end

function Window:SetShadow(enabled)
    self._mainStroke.Thickness = enabled and 3 or 1
    self._mainStroke.Transparency = enabled and 0.45 or 0
end

function Window:Toggle()
    self._main.Visible = not self._main.Visible
    self:_updateIsland()
end

function Window:SetKeybind(key)
    self._key = parseKey(key)
end

function Window:SetIslandDraggable(enabled)
    self._btnDraggable = enabled == true
end

function Window:SetToggleButton(enabled)
    if not enabled then
        if self._toggleBtn then
            self._toggleBtn:Destroy()
            self._toggleBtn = nil
        end
        return
    end
    if self._toggleBtn then
        return
    end
    local button = create("TextButton", {
        Name = "BBCToggle",
        Size = UDim2.fromOffset(46, 46),
        Position = UDim2.new(0, 14, 0.38, 0),
        Text = "BBC",
        TextSize = 15,
        FontFace = Library.Fonts.Bold,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, self.Gui)
    bind(button, "BackgroundColor3", "Surface")
    bind(button, "TextColor3", "Text")
    corner(button, 8)
    stroke(button, "Accent", 0.2)
    self._toggleBtn = button
    local dragging, moved, startPosition, startInput = false, false, nil, nil
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved, startInput, startPosition = true, false, input.Position, button.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if dragging and self._btnDraggable ~= false and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startInput
            if delta.Magnitude > 6 then
                moved = true
            end
            if moved then
                button.Position = UDim2.new(
                    startPosition.X.Scale,
                    startPosition.X.Offset + delta.X,
                    startPosition.Y.Scale,
                    startPosition.Y.Offset + delta.Y
                )
            end
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if not moved then
                self:Toggle()
            end
        end
    end)
end

function Window:_tip(title, text)
    if self._tipFrame then
        self._tipFrame:Destroy()
    end
    local frame = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.fromOffset(250, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 50,
    }, self._main)
    bind(frame, "BackgroundColor3", "Surface3")
    corner(frame, 5)
    stroke(frame, "Accent", 0.2)
    pad(frame, 10, 10, 7, 8)
    listLayout(frame, 2)
    label(frame, tostring(title), 12, "Accent", true, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), ZIndex = 51 })
    label(frame, tostring(text), 12, "Text", false, {
        LayoutOrder = 2,
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        Size = UDim2.new(1, 0, 0, 16),
        ZIndex = 51,
    })
    self._tipFrame = frame
    task.delay(3.2, function()
        if self._tipFrame == frame then
            frame:Destroy()
            self._tipFrame = nil
        end
    end)
end

function Window:_filter(query)
    query = string.lower(query or "")
    for _, descendant in ipairs(self.Gui:GetDescendants()) do
        if descendant:IsA("Frame") then
            local name = descendant:GetAttribute("SearchName")
            if name ~= nil then
                descendant.Visible = (query == "" or string.find(string.lower(name), query, 1, true) ~= nil)
            end
        end
    end
end

function Window:Destroy()
    for _, connection in ipairs(self._conns) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    if self.Gui then
        self.Gui:Destroy()
    end
    for index, window in ipairs(Library.Windows) do
        if window == self then
            table.remove(Library.Windows, index)
            break
        end
    end
end

-- ---------- Ilha: pílula no topo que aparece quando o menu está fechado ----------
function Window:_buildIsland()
    local gui = self.Gui
    local MarketplaceService = game:GetService("MarketplaceService")
    local StatsService = game:GetService("Stats")
    local W0, H0, W1, H1 = 196, 34, 306, 116
    local started = os.clock()
    local island = create("TextButton", {
        Name = "Island",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 8),
        Size = UDim2.fromOffset(W0, H0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 30,
        ClipsDescendants = true,
    }, gui)
    local islandCorner = corner(island, 17)
    stroke(island, "Stroke", 0.2)
    local disc = create("Frame", {
        Position = UDim2.fromOffset(5, 5),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        ZIndex = 31,
    }, island)
    bind(disc, "BackgroundColor3", "Accent")
    corner(disc, 12)
    icon(disc, "box", 14, "Accent", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        ZIndex = 32,
    })
    label(island, "BBC HUB", 13, "Text", true, {
        Position = UDim2.fromOffset(37, 0),
        Size = UDim2.fromOffset(72, 34),
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 31,
    })
    local dot = create("Frame", {
        Position = UDim2.new(1, -82, 0, 14),
        Size = UDim2.fromOffset(6, 6),
        BorderSizePixel = 0,
        ZIndex = 31,
    }, island)
    corner(dot, 3)
    local fpsLabel = label(island, "60 FPS", 12, "Text", true, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 0),
        Size = UDim2.fromOffset(66, 34),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 31,
    })
    local line1 = label(island, "", 13, "Text", true, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 17), ZIndex = 31 })
    local line2 = label(island, "", 12, "Muted", false, { Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local line3 = label(island, "", 12, "Muted", false, { Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local line4 = label(island, "", 12, "Accent", true, { Position = UDim2.fromOffset(16, 94), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local gameName = "Roblox"
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)
        if ok and info and info.Name then
            gameName = info.Name
        end
    end)
    local function fmtClock(seconds)
        seconds = math.floor(seconds)
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor(seconds % 3600 / 60)
        local secs = seconds % 60
        if hours > 0 then
            return string.format("%d:%02d:%02d", hours, minutes, secs)
        end
        return string.format("%02d:%02d", minutes, secs)
    end
    local function update()
        local fps = Library._fps or 60
        fpsLabel.Text = fps .. " FPS"
        local color = fps >= 50 and Color3.fromRGB(70, 210, 110)
            or (fps >= 30 and Color3.fromRGB(240, 176, 108) or Color3.fromRGB(240, 100, 100))
        dot.BackgroundColor3 = color
        local ok, ping = pcall(function()
            return math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        line1.Text = self._hideName and "••••••" or LocalPlayer.DisplayName
        line2.Text = gameName
        line3.Text = Library.Tr("Sessão") .. " " .. fmtClock(os.clock() - started) .. "   ·   "
            .. (ok and (ping .. " ms") or "— ms") .. "   ·   " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        line4.Text = (self._key and keyText(self._key) or "—") .. "  ·  " .. Library.Tr("Toque para abrir")
    end
    update()
    local expanded, longPressed = false, false
    local function setExpanded(value)
        if expanded == value then
            return
        end
        expanded = value
        tween(island, { Size = UDim2.fromOffset(value and W1 or W0, value and H1 or H0) }, 0.22, Enum.EasingStyle.Quint)
        tween(islandCorner, { CornerRadius = UDim.new(0, value and 20 or 17) }, 0.22, Enum.EasingStyle.Quint)
    end
    island.MouseEnter:Connect(function()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            return
        end
        setExpanded(true)
    end)
    island.MouseLeave:Connect(function()
        setExpanded(false)
    end)
    island.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            longPressed = false
            task.delay(0.45, function()
                if island.Parent and island.Visible then
                    longPressed = true
                    setExpanded(true)
                    task.delay(3.5, function()
                        setExpanded(false)
                    end)
                end
            end)
        end
    end)
    island.MouseButton1Click:Connect(function()
        if longPressed then
            longPressed = false
            return
        end
        self:SetVisible(true)
    end)
    task.spawn(function()
        while gui.Parent do
            task.wait(0.5)
            if island.Visible then
                update()
            end
        end
    end)
    self._island = island
    self:_updateIsland()
end

-- ---------- Janela ----------
function Library:Window(opts)
    opts = opts or {}
    Utils.waitIcons(25)
    if opts.Theme and Library.ThemePresets[opts.Theme] then
        Library:SetTheme(opts.Theme)
    end
    local window = setmetatable({
        Tabs = {},
        _conns = {},
        _hideName = false,
        _hideAvatar = false,
        _btnDraggable = true,
    }, Window)
    local width = (opts.Size and opts.Size.X.Offset > 0) and opts.Size.X.Offset or 640
    local height = (opts.Size and opts.Size.Y.Offset > 0) and opts.Size.Y.Offset or 360
    local gui = create("ScreenGui", {
        Name = "BBCHub",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, guiParent())
    window.Gui = gui
    local main = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height),
        BorderSizePixel = 0,
    }, gui)
    bind(main, "BackgroundColor3", "Background")
    corner(main, 6)
    window._mainStroke = stroke(main, "Stroke", 0)
    bind(window._mainStroke, "Color", function()
        return window._accentBorder and Library.Theme.Accent or Library.Theme.Stroke
    end)
    window._main = main
    local scale = create("UIScale", {}, main)
    local function fit()
        local viewport = gui.AbsoluteSize
        if viewport.X <= 0 or viewport.Y <= 0 then
            return
        end
        scale.Scale = math.clamp(math.min(viewport.X * 0.8 / width, viewport.Y * 0.92 / height), 0.45, 1.3)
    end
    fit()
    window:_connect(gui:GetPropertyChangedSignal("AbsoluteSize"), fit)
    window._key = parseKey(opts.Keybind or "RightShift")
    window:_connect(UserInputService.InputBegan, function(input, processed)
        if processed or Library._listening or os.clock() - (Library._lastBind or 0) < 0.25 then
            return
        end
        local inputType = input.UserInputType
        local code = inputType == Enum.UserInputType.Keyboard and input.KeyCode or inputType
        if window._key and code == window._key then
            window:Toggle()
        end
    end)

    -- cabeçalho
    local header = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, main)
    window._logo = icon(header, "box", 30, "Accent", { Position = UDim2.fromOffset(12, 11) })
    label(header, "BBC", 17, "Accent", true, { Position = UDim2.fromOffset(50, 6), Size = UDim2.fromOffset(70, 20) })
    label(header, "HUB", 17, "Text", true, { Position = UDim2.fromOffset(50, 25), Size = UDim2.fromOffset(70, 20) })
    local dragging, dragStart, startPosition = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPosition = true, input.Position, main.Position
        end
    end)
    window:_connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
    window:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- barra de configuração ("default" + salvar)
    local configName = "default"
    local configBar = create("Frame", {
        Position = UDim2.fromOffset(130, 11),
        Size = UDim2.new(1, -330, 0, 30),
        BorderSizePixel = 0,
    }, header)
    bind(configBar, "BackgroundColor3", "Surface2")
    corner(configBar, 3)
    stroke(configBar, "Stroke", 0.1)
    local saveButton = create("TextButton", {
        Size = UDim2.fromOffset(30, 30),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, configBar)
    icon(saveButton, "save", 18, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    local configBox = create("TextBox", {
        Position = UDim2.fromOffset(34, 0),
        Size = UDim2.new(1, -38, 1, 0),
        BackgroundTransparency = 1,
        Text = configName,
        TextSize = 14,
        FontFace = Library.Fonts.Regular,
        ClearTextOnFocus = false,
        PlaceholderText = "default",
    }, configBar)
    bind(configBox, "TextColor3", "Text")
    bind(configBox, "PlaceholderColor3", "Muted")
    saveButton.MouseButton1Click:Connect(function()
        configName = (configBox.Text ~= "" and configBox.Text) or "default"
        window:SaveConfig(configName)
    end)
    configBox.FocusLost:Connect(function(enter)
        if enter and configBox.Text ~= "" then
            configName = configBox.Text
            if not window:LoadConfig(configName) then
                configBox.Text = configName
            end
        end
    end)

    -- busca
    local searchBox = create("TextBox", {
        Position = UDim2.fromOffset(130, 11),
        Size = UDim2.new(1, -330, 0, 30),
        Text = "",
        PlaceholderText = "Search",
        TextSize = 14,
        FontFace = Library.Fonts.Regular,
        ClearTextOnFocus = false,
        Visible = false,
        BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    bind(searchBox, "BackgroundColor3", "Surface2")
    bind(searchBox, "TextColor3", "Text")
    bind(searchBox, "PlaceholderColor3", "Muted")
    corner(searchBox, 3)
    stroke(searchBox, "Accent", 0.2)
    pad(searchBox, 10, 8, 0, 0)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        window:_filter(searchBox.Text)
    end)

    -- botões do canto
    local function headerButton(iconName, offset)
        local button = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -offset, 0, 11),
            Size = UDim2.fromOffset(30, 30),
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, header)
        bind(button, "BackgroundColor3", "Surface2")
        corner(button, 3)
        local buttonStroke = stroke(button, "Stroke", 0.05)
        local buttonIcon = icon(button, iconName, 16, "Text", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
        })
        return button, buttonIcon, buttonStroke
    end
    local searchButton = headerButton("search", 12 + 36 + 36)
    local flameButton, flameIcon, flameStroke = headerButton("flame", 12 + 36)
    local gearButton, gearIcon, gearStroke = headerButton("settings", 12)
    window._flameBtn, window._flameIcon, window._flameStroke = flameButton, flameIcon, flameStroke
    window._gearBtn, window._gearIcon, window._gearStroke = gearButton, gearIcon, gearStroke
    searchButton.MouseButton1Click:Connect(function()
        local on = not searchBox.Visible
        searchBox.Visible = on
        configBar.Visible = not on
        if on then
            searchBox:CaptureFocus()
        else
            searchBox.Text = ""
        end
    end)
    flameButton.MouseButton1Click:Connect(function()
        window:_select(window.HomeTab)
    end)
    gearButton.MouseButton1Click:Connect(function()
        for _, tab in ipairs(window.Tabs) do
            if tab.IsSettings then
                window:_select(tab)
                break
            end
        end
    end)

    -- barra lateral
    local side = create("Frame", {
        Position = UDim2.fromOffset(0, 52),
        Size = UDim2.new(0, 152, 1, -52),
        BackgroundTransparency = 1,
    }, main)
    window._tabList = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -54),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, side)
    pad(window._tabList, 6, 4, 2, 2)
    listLayout(window._tabList, 2)
    local divider = create("Frame", {
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, -6),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.4,
    }, side)
    bind(divider, "BackgroundColor3", "Stroke")

    -- cartão do jogador
    local card = create("TextButton", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 6, 1, -6),
        Size = UDim2.new(1, -12, 0, 44),
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, side)
    bind(card, "BackgroundColor3", "Surface2")
    corner(card, 4)
    stroke(card, "Accent", 0.15)
    window._pAvatar = create("ImageLabel", {
        Position = UDim2.fromOffset(6, 7),
        Size = UDim2.fromOffset(30, 30),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ScaleType = Enum.ScaleType.Crop,
    }, card)
    bind(window._pAvatar, "BackgroundColor3", "Surface3")
    corner(window._pAvatar, 15)
    window._pName = label(card, LocalPlayer.DisplayName, 13, "Text", false, {
        Position = UDim2.fromOffset(42, 5),
        Size = UDim2.new(1, -46, 0, 17),
    })
    local playerSub = label(card, "", 11, "Muted", false, {
        Position = UDim2.fromOffset(42, 23),
        Size = UDim2.new(1, -46, 0, 15),
    })
    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
        end)
        if ok then
            window._thumb = image
            window:_renderIdentity()
        end
    end)
    local home = type(opts.Home) == "table" and opts.Home or {}
    local function subText()
        local expiry = home.Expiry
        if type(expiry) == "function" then
            local ok, result = pcall(expiry)
            expiry = ok and result or nil
        end
        if type(expiry) == "number" then
            local left = expiry - os.time()
            return left > 0 and (fmtLeft(left) .. " left") or "Expired"
        end
        return "Ilimitado"
    end
    playerSub.Text = subText()
    task.spawn(function()
        while gui.Parent do
            task.wait(20)
            playerSub.Text = subText()
        end
    end)
    card.MouseButton1Click:Connect(function()
        window:_select(window.HomeTab)
    end)

    -- conteúdo
    window._content = create("Frame", {
        Position = UDim2.fromOffset(160, 54),
        Size = UDim2.new(1, -168, 1, -62),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, main)

    -- página inicial (perfil), escondida da barra lateral
    if opts.Home ~= false then
        local homeTab = window:Tab({ Name = "Home", Hidden = true })
        if type(home.Build) == "function" then
            safeCall(home.Build, window, homeTab, homeTab.List)
        end
    end
    window:_buildIsland()
    table.insert(Library.Windows, window)
    table.insert(Library._themeListeners, function()
        if gui.Parent and window.Current then
            window:_select(window.Current)
        end
    end)
    window:_renderIdentity()
    return window
end

-- ============================================================
--  Overlays (watermark + lista de atalhos)
-- ============================================================
local Overlays = {}

function Overlays.create()
    local overlayParent = (type(gethui) == "function" and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
    local overlay = Instance.new("ScreenGui")
    overlay.Name = "BBCOverlay"
    overlay.ResetOnSpawn = false
    overlay.IgnoreGuiInset = true
    overlay.DisplayOrder = 998
    overlay.Parent = overlayParent

    local function tr(text)
        return BBC.I18n and BBC.I18n.tr(text) or text
    end

    local function makePanel(name, position)
        local frame = Instance.new("Frame")
        frame.Name = name
        frame.Position = position
        frame.AutomaticSize = Enum.AutomaticSize.None
        frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        frame.BorderSizePixel = 0
        frame.Parent = overlay
        local panelCorner = Instance.new("UICorner", frame)
        local panelStroke = Instance.new("UIStroke", frame)
        panelStroke.Color = Library.Theme.Accent
        local text = Instance.new("TextLabel", frame)
        text.BackgroundTransparency = 1
        text.Size = UDim2.new(1, -16, 1, -8)
        text.Position = UDim2.fromOffset(8, 4)
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.TextYAlignment = Enum.TextYAlignment.Top
        text.FontFace = Library.Fonts.Regular
        text.TextSize = 14
        text.TextColor3 = Color3.fromRGB(235, 235, 235)
        text.RichText = true
        text.Text = ""
        return frame, panelCorner, panelStroke, text
    end

    local WM = {
        Shadow = true, On = false, Pin = false, Size = 100, Width = 285, MaxH = 290,
        BgT = 0.10, TxtT = 0, BrdT = 0, Radius = 6, Fields = { "Nome", "FPS", "Ping" },
    }
    local KL = {
        Shadow = true, Pin = false, On = false, Size = 100, Width = 250, MaxH = 260,
        BgT = 0.05, TxtT = 0, BrdT = 0.75, Radius = 7,
    }
    local wmFrame, wmCorner, wmStroke, wmText = makePanel("Watermark", UDim2.fromOffset(12, 12))
    local klPinToggle
    local klFrame = Instance.new("Frame")
    klFrame.Name = "KeybindList"
    klFrame.BorderSizePixel = 0
    klFrame.ClipsDescendants = true
    klFrame.Position = UDim2.new(0, 14, 0.28, 0)
    klFrame.Size = UDim2.fromOffset(250, 150)
    klFrame.Parent = overlay
    local klCorner = Instance.new("UICorner", klFrame)
    local klStroke = Instance.new("UIStroke", klFrame)
    local klScale = Instance.new("UIScale", klFrame)
    local klHead = Instance.new("Frame", klFrame)
    klHead.BackgroundTransparency = 1
    klHead.Size = UDim2.new(1, 0, 0, 34)
    klHead.Active = true
    Library.MakeIcon(klHead, "align-left", 16, "Muted", { Position = UDim2.fromOffset(12, 9) })
    local klTitle = Instance.new("TextLabel", klHead)
    klTitle.BackgroundTransparency = 1
    klTitle.Position = UDim2.fromOffset(38, 0)
    klTitle.Size = UDim2.new(1, -80, 1, 0)
    klTitle.TextXAlignment = Enum.TextXAlignment.Left
    klTitle.FontFace = Library.Fonts.Bold
    klTitle.TextSize = 14
    local klPin = Instance.new("TextButton", klHead)
    klPin.AnchorPoint = Vector2.new(1, 0.5)
    klPin.Position = UDim2.new(1, -8, 0.5, 0)
    klPin.Size = UDim2.fromOffset(28, 28)
    klPin.BackgroundTransparency = 1
    klPin.Text = ""
    klPin.AutoButtonColor = false
    local klPinIcon = Library.MakeIcon(klPin, "pin", 16, "Muted", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
    })
    local function paintPin()
        klPinIcon.ImageColor3 = KL.Pin and Library.Theme.Accent or Library.Theme.Muted
    end
    klPin.MouseButton1Click:Connect(function()
        KL.Pin = not KL.Pin
        paintPin()
        if klPinToggle then
            klPinToggle:Set(KL.Pin, true)
        end
    end)
    local klScroll = Instance.new("ScrollingFrame", klFrame)
    klScroll.BackgroundTransparency = 1
    klScroll.BorderSizePixel = 0
    klScroll.Position = UDim2.fromOffset(0, 36)
    klScroll.Size = UDim2.new(1, 0, 1, -40)
    klScroll.ScrollBarThickness = 2
    klScroll.CanvasSize = UDim2.new()
    klScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    klScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    local klList = Instance.new("UIListLayout", klScroll)
    klList.SortOrder = Enum.SortOrder.LayoutOrder
    klList.Padding = UDim.new(0, 0)
    local klRowsRef = {}
    local function recolorKL()
        local theme = Library.Theme
        klFrame.BackgroundColor3 = theme.Background
        klStroke.Color = theme.Stroke
        klTitle.TextColor3 = theme.Text
        klScroll.ScrollBarImageColor3 = theme.Muted
        paintPin()
        for _, row in ipairs(klRowsRef) do
            if row.name.Parent then
                row.name.TextColor3 = theme.Text
                row.key.TextColor3 = row.listening and theme.Accent or theme.Muted
            end
        end
    end
    local KL_FIRST = { ["Tecla do menu"] = 1, ["Tecla do cursor"] = 2 }
    local function renderKL()
        for _, child in ipairs(klScroll:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        klRowsRef = {}
        klTitle.Text = tr("Atalhos")
        local items = {}
        for index, keybind in ipairs(Library.Keybinds) do
            local value = keybind.get()
            if value then
                table.insert(items, {
                    kb = keybind,
                    v = value,
                    order = KL_FIRST[keybind.name] or (10 + index),
                })
            end
        end
        table.sort(items, function(a, b)
            return a.order < b.order
        end)
        for index, item in ipairs(items) do
            local keybind, value = item.kb, item.v
            local row = Instance.new("Frame", klScroll)
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(1, 0, 0, 28)
            row.LayoutOrder = index
            local listening = keybind.listening and keybind.listening()
            local keyLabel = Instance.new("TextLabel", row)
            keyLabel.BackgroundTransparency = 1
            keyLabel.Position = UDim2.fromOffset(12, 0)
            keyLabel.Size = UDim2.fromOffset(76, 28)
            keyLabel.TextXAlignment = Enum.TextXAlignment.Left
            keyLabel.FontFace = Library.Fonts.Regular
            keyLabel.TextSize = 12
            keyLabel.TextTruncate = Enum.TextTruncate.AtEnd
            keyLabel.Text = listening and "..."
                or ((value.Name == "MouseButton3" and "MB3")
                    or (value.Name == "MouseButton2" and "MB2")
                    or value.Name)
            local nameLabel = Instance.new("TextLabel", row)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Position = UDim2.fromOffset(92, 0)
            nameLabel.Size = UDim2.new(1, -128, 1, 0)
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.FontFace = Library.Fonts.Bold
            nameLabel.TextSize = 13
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Text = tr(keybind.name)
            local edit = Instance.new("TextButton", row)
            edit.AnchorPoint = Vector2.new(1, 0.5)
            edit.Position = UDim2.new(1, -8, 0.5, 0)
            edit.Size = UDim2.fromOffset(26, 26)
            edit.BackgroundTransparency = 1
            edit.Text = ""
            edit.AutoButtonColor = false
            Library.MakeIcon(edit, "sliders-horizontal", 16, "Muted", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
            })
            edit.MouseButton1Click:Connect(function()
                if keybind.begin then
                    keybind.begin()
                end
            end)
            table.insert(klRowsRef, { key = keyLabel, name = nameLabel, listening = listening })
        end
        klFrame.Size = UDim2.fromOffset(KL.Width, math.min(42 + #items * 28, KL.MaxH))
        recolorKL()
    end
    table.insert(Library._kbListeners, renderKL)
    table.insert(Library._themeListeners, recolorKL)

    local function applyPanel(cfg, frame, panelCorner, panelStroke, text, height)
        frame.Visible = cfg.On
        local scale = cfg.Size / 100
        frame.Size = UDim2.fromOffset(math.min(cfg.Width, 600) * scale, math.min(height, cfg.MaxH) * scale)
        frame.BackgroundTransparency = cfg.BgT
        text.TextTransparency = cfg.TxtT
        text.TextSize = math.floor(14 * scale)
        panelStroke.Transparency = cfg.BrdT
        panelCorner.CornerRadius = UDim.new(0, cfg.Radius)
        text.TextStrokeTransparency = cfg.Shadow and 0.6 or 1
    end

    local function refreshPanels()
        applyPanel(WM, wmFrame, wmCorner, wmStroke, wmText, 28)
        klFrame.Visible = KL.On
        klScale.Scale = KL.Size / 100
        klFrame.BackgroundTransparency = KL.BgT
        klStroke.Transparency = KL.BrdT
        klCorner.CornerRadius = UDim.new(0, KL.Radius)
        renderKL()
    end

    -- arrastar painéis (mouse ou toque), a menos que "Fixar" esteja ligado
    local function makeDraggable(handle, cfg, target)
        local frame = target or handle
        handle.Active = true
        local dragging, startPosition, startInput
        handle.InputBegan:Connect(function(input)
            if cfg.Pin then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, startInput, startPosition = true, input.Position, frame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - startInput
                frame.Position = UDim2.new(
                    startPosition.X.Scale,
                    startPosition.X.Offset + delta.X,
                    startPosition.Y.Scale,
                    startPosition.Y.Offset + delta.Y
                )
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end
    makeDraggable(wmFrame, WM)
    makeDraggable(klHead, KL, klFrame)

    -- Cursor livre: segurando a tecla do cursor, o mouse é liberado para clicar no menu
    local cursorFree, cursorHeld, cursorKey = true, false, Enum.KeyCode.LeftAlt
    UserInputService.InputBegan:Connect(function(input)
        if cursorFree and input.KeyCode == cursorKey then
            cursorHeld = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == cursorKey then
            cursorHeld = false
        end
    end)
    RunService.RenderStepped:Connect(function()
        if cursorHeld then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end)

    local frames, last = 0, os.clock()
    local fps = 60
    RunService.Heartbeat:Connect(function()
        frames += 1
        if os.clock() - last >= 1 then
            fps = frames
            frames = 0
            last = os.clock()
        end
        local parts = { "<b>BBC HUB</b>" }
        for _, field in ipairs(WM.Fields) do
            if field == "Nome" then
                table.insert(parts, LocalPlayer.Name)
            elseif field == "FPS" then
                table.insert(parts, fps .. " FPS")
            elseif field == "Ping" then
                local ok, ping = pcall(function()
                    return math.floor(LocalPlayer:GetNetworkPing() * 2000)
                end)
                table.insert(parts, (ok and ping or 0) .. " ms")
            elseif field == "Hora" then
                table.insert(parts, os.date("%H:%M"))
            end
        end
        wmText.Text = table.concat(parts, "  |  ")
    end)
    refreshPanels()

    return {
        overlay = overlay,
        WM = WM,
        KL = KL,
        wmFrame = wmFrame,
        wmStroke = wmStroke,
        klFrame = klFrame,
        refresh = refreshPanels,
        recolor = recolorKL,
        setAccent = function(color)
            wmStroke.Color = color
            recolorKL()
        end,
        setPinToggle = function(toggle)
            klPinToggle = toggle
        end,
        setCursorFree = function(value)
            cursorFree = value == true
        end,
        setCursorKey = function(key)
            cursorKey = key
        end,
        destroy = function()
            overlay:Destroy()
        end,
    }
end

BBC.UI = BBC.UI or {}
BBC.UI.Tab = Tab
BBC.UI.Window = Window
BBC.UI.Overlays = Overlays
BBC.UI.fmtLeft = fmtLeft

return Window

end)

-- ============================================================
-- módulo: features.visuals  (features/visuals.lua)
-- ============================================================
__module("features.visuals", function(BBC)
--[[
    BBC HUB - Feature: Visuals
    Aba VISUAIS: ESP, interface do jogo e efeitos locais.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T

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

return Features.buildVisuals

end)

-- ============================================================
-- módulo: features.player  (features/player.lua)
-- ============================================================
__module("features.player", function(BBC)
--[[
    BBC HUB - Feature: Player
    Aba JOGADOR + painel de perfil (dados reais da conta, sessão e jogo).
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Library = BBC.Library
local Utils = BBC.Utils
local Security = BBC.Security
local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local StatsService = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

local function tr(text)
    return BBC.I18n and BBC.I18n.tr(text) or text
end

local function notify(text)
    Utils.notifyText(text)
end

local function onLanguageChanged(callback)
    if BBC.I18n then
        table.insert(BBC.I18n.onChanged, callback)
    end
end

-- ============================================================
--  Aba JOGADOR
-- ============================================================
function Features.buildPlayer(window)
    local player = window:Tab({ Name = "JOGADOR", Icon = "user" })

    local group = player:Groupbox({ Name = "MOVIMENTO", Icon = "move", Side = "Left" })
    T(group, "Hack de velocidade")
    T(group, "Sprint automático", true)
    T(group, "Pulos seguidos")
    T(group, "Controle no ar")
    T(group, "Voar")
    T(group, "Sem dano de queda")
    T(group, "Sempre no chão")
    T(group, "Jesus")
    T(group, "Aranha")

    group = player:Groupbox({ Name = "CÂMERA", Icon = "camera", Side = "Left" })
    T(group, "Terceira pessoa")
    T(group, "Câmera livre")

    group = player:Groupbox({ Name = "SAQUE", Icon = "package", Side = "Left" })
    T(group, "Saque automático")

    group = player:Groupbox({ Name = "MÃOS E ARMA", Icon = "hand", Side = "Right" })
    for _, name in ipairs({ "Deslocamento", "Trocar personagem", "Personagem", "Corpo em 1ª pessoa", "Mãos", "Item na mão" }) do
        T(group, name)
    end

    group = player:Groupbox({ Name = "CAMPO DE VISÃO", Icon = "focus", Side = "Right" })
    S(group, "Campo de visão", 30, 120, 120)
    S(group, "Visão com zoom", 5, 120, 5)
    group:Keybind({
        Name = "Zoom",
        Default = "N",
        OnChanged = function(key)
            BBC.State.Keys.zoom = key.Name
            BBC.State.refreshPanels()
        end,
        Callback = function() end,
    })

    group = player:Groupbox({ Name = "ANIMAÇÕES", Icon = "activity", Side = "Right" })
    group:Dropdown({
        Name = "Animação",
        Options = { "Swish", "Padrão" },
        Default = "Swish",
        Callback = function() end,
    })
    T(group, "Repetir")
    S(group, "Velocidade", 0.1, 3, 1, "x", 0.1)
    S(group, "Peso", 0, 100, 100, "%")
    group:Button({
        Name = "Reproduzir",
        Callback = function()
            notify("Reproduzir")
        end,
    })

    group = player:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Right" })
    T(group, "Painel do jogador")
    T(group, "Anti AFK")
    T(group, "Renascer automático")
    T(group, "Remover água")
    T(group, "Não se afogar")
    T(group, "Mapa e navegação", true)

    return player
end

-- ============================================================
--  Painel de perfil (Home)
-- ============================================================
function Features.buildProfile(win, page, list)
    local config = BBC.State.Config or {}
    local version = config.Version or "0.0.8.2"
    local access = config.Access or "FREE"

    -- ---------- Persistência ----------
    local folder = "BBC_HUB"
    local file = folder .. "/perfil_" .. LocalPlayer.UserId .. ".json"
    local data = { kills = 0, deaths = 0, damage = 0, played = 0, runs = 0 }
    local canFS = Security.canFS()
    if canFS then
        Security.ensureFolder(folder)
        local saved = Security.readJSON(file)
        if type(saved) == "table" then
            for key, value in pairs(saved) do
                data[key] = value
            end
        end
    end
    data.runs = (tonumber(data.runs) or 0) + 1
    local function save()
        if canFS then
            Security.writeJSON(file, data)
        end
    end
    save()

    -- ---------- Rastreamento real ----------
    local function hookCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then
            return
        end
        local lastHealth = humanoid.Health
        humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth then
                data.damage += lastHealth - health
            end
            lastHealth = health
        end)
        humanoid.Died:Connect(function()
            data.deaths += 1
        end)
    end
    if LocalPlayer.Character then
        task.spawn(hookCharacter, LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(hookCharacter)

    local function hookVictim(player)
        if player == LocalPlayer then
            return
        end
        local function onCharacter(character)
            local humanoid = character:WaitForChild("Humanoid", 10)
            if not humanoid then
                return
            end
            humanoid.Died:Connect(function()
                local tag = humanoid:FindFirstChild("creator")
                if tag and tag.Value == LocalPlayer then
                    data.kills += 1
                end
            end)
        end
        if player.Character then
            task.spawn(onCharacter, player.Character)
        end
        player.CharacterAdded:Connect(onCharacter)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        hookVictim(player)
    end
    Players.PlayerAdded:Connect(hookVictim)

    local function leaderStat(patterns)
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if not leaderstats then
            return nil
        end
        for _, value in ipairs(leaderstats:GetChildren()) do
            if value:IsA("ValueBase") then
                local name = string.lower(value.Name)
                for _, pattern in ipairs(patterns) do
                    if string.find(name, pattern, 1, true) then
                        return tonumber(value.Value)
                    end
                end
            end
        end
        return nil
    end

    -- ---------- Leituras ----------
    local function fmtDuration(seconds, withSeconds)
        seconds = math.max(math.floor(seconds), 0)
        local days = math.floor(seconds / 86400)
        local hours = math.floor(seconds % 86400 / 3600)
        local minutes = math.floor(seconds % 3600 / 60)
        local secs = seconds % 60
        if days > 0 then
            return days .. "d " .. hours .. "h"
        end
        if hours > 0 then
            return hours .. "h " .. minutes .. "m"
        end
        if withSeconds then
            return minutes .. "m " .. secs .. "s"
        end
        return minutes .. "m"
    end
    local function fmtBig(number)
        number = tonumber(number) or 0
        if number >= 1e6 then
            return string.format("%.1fM", number / 1e6)
        end
        if number >= 1e3 then
            return string.format("%.1fK", number / 1e3)
        end
        return tostring(math.floor(number))
    end
    local function getPing()
        local ok, value = pcall(function()
            return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and value then
            return math.floor(value)
        end
        local ok2, ping = pcall(function()
            return LocalPlayer:GetNetworkPing() * 2000
        end)
        return ok2 and math.floor(ping) or 0
    end
    local function getDevice()
        local keyboard = UserInputService.KeyboardEnabled
        if UserInputService.TouchEnabled and not keyboard then
            return tr("Celular")
        end
        if UserInputService.GamepadEnabled and not keyboard then
            return tr("Console")
        end
        return "PC"
    end
    local frames, fps = 0, 0
    RunService.RenderStepped:Connect(function()
        frames += 1
    end)

    -- ---------- UI ----------
    local themed = {}
    local function th(instance, property, key)
        themed[#themed + 1] = { instance, property, key }
        instance[property] = Library.Theme[key]
    end
    table.insert(Library._themeListeners, function()
        for _, item in ipairs(themed) do
            if item[1].Parent then
                item[1][item[2]] = Library.Theme[item[3]]
            end
        end
    end)
    local function mk(class, props, parent)
        local instance = Instance.new(class)
        for key, value in pairs(props) do
            instance[key] = value
        end
        instance.Parent = parent
        return instance
    end
    local function txt(parent, text, size, key, bold, extra)
        local textLabel = mk("TextLabel", {
            BackgroundTransparency = 1,
            Text = text,
            TextSize = size,
            FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.new(1, 0, 0, size + 4),
        }, parent)
        th(textLabel, "TextColor3", key or "Text")
        for property, value in pairs(extra or {}) do
            textLabel[property] = value
        end
        return textLabel
    end
    local function decorate(frame, key, radius)
        th(frame, "BackgroundColor3", key)
        frame.BorderSizePixel = 0
        mk("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, frame)
        th(mk("UIStroke", {}, frame), "Color", "Stroke")
    end
    local function box(parent, title, order, size)
        local frame = mk("Frame", {
            Size = size or UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = order,
        }, parent)
        decorate(frame, "Surface2", 8)
        mk("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 10),
        }, frame)
        mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
        txt(frame, string.upper(title), 12, "Muted", false, { LayoutOrder = 0 })
        return frame
    end
    local function grid(parent, columns, order)
        local frame = mk("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = order,
        }, parent)
        mk("UIGridLayout", {
            CellPadding = UDim2.fromOffset(6, 6),
            CellSize = UDim2.new(1 / columns, -(6 * (columns - 1) / columns), 0, 46),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, frame)
        return frame
    end
    local function cell(parent, title, order, big)
        local frame = mk("Frame", { LayoutOrder = order }, parent)
        decorate(frame, "Background", 6)
        txt(frame, title, 12, "Muted", false, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 15) })
        local value = txt(frame, "…", big or 16, "Text", true, {
            Position = UDim2.fromOffset(8, 20),
            Size = UDim2.new(1, -16, 0, 22),
        })
        return value, frame
    end
    local function spark(parent)
        local width, height, count = 56, 22, 20
        local holder = mk("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 4),
            Size = UDim2.fromOffset(width, height),
            ClipsDescendants = true,
        }, parent)
        local segments, samples = {}, {}
        for index = 1, count - 1 do
            local segment = mk("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(0, 2),
                Visible = false,
            }, holder)
            th(segment, "BackgroundColor3", "Accent")
            segments[index] = segment
        end
        return function(value)
            table.insert(samples, value)
            if #samples > count then
                table.remove(samples, 1)
            end
            local low, high = math.huge, -math.huge
            for _, sample in ipairs(samples) do
                low = math.min(low, sample)
                high = math.max(high, sample)
            end
            if high - low < 1 then
                high = low + 1
            end
            local offset, step, points = count - #samples, width / (count - 1), {}
            for index, sample in ipairs(samples) do
                points[index] = Vector2.new(
                    (offset + index - 1) * step,
                    height - 2 - ((sample - low) / (high - low)) * (height - 4)
                )
            end
            for index = 1, count - 1 do
                local a, b = points[index - offset], points[index - offset + 1]
                local segment = segments[index]
                if a and b then
                    local delta = b - a
                    segment.Visible = true
                    segment.Size = UDim2.fromOffset(delta.Magnitude + 1, 2)
                    segment.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                    segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                else
                    segment.Visible = false
                end
            end
        end
    end

    local root = mk("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    }, list)
    mk("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, root)

    -- Identidade
    local identity = mk("Frame", { Size = UDim2.new(1, 0, 0, 78), LayoutOrder = 1 }, root)
    decorate(identity, "Surface2", 8)
    local avatar = mk("ImageLabel", {
        Position = UDim2.fromOffset(10, 9),
        Size = UDim2.fromOffset(60, 60),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ScaleType = Enum.ScaleType.Crop,
    }, identity)
    th(avatar, "BackgroundColor3", "Surface3")
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, avatar)
    local thumbnail
    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
        end)
        if ok then
            thumbnail = image
            avatar.Image = image
        end
    end)
    local nameLabel = txt(identity, LocalPlayer.DisplayName, 20, "Text", true, {
        Position = UDim2.fromOffset(82, 12),
        Size = UDim2.new(1, -230, 0, 26),
    })
    local userLabel = txt(identity, "@" .. LocalPlayer.Name, 15, "Muted", false, {
        Position = UDim2.fromOffset(82, 42),
        Size = UDim2.new(1, -230, 0, 20),
    })
    local badge = mk("TextLabel", {
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.fromOffset(0, 16),
        Size = UDim2.fromOffset(46, 20),
        BackgroundTransparency = 0.6,
        Text = access,
        TextSize = 12,
        FontFace = Library.Fonts.Bold,
    }, identity)
    decorate(badge, "Surface3", 4)
    th(badge, "TextColor3", "Text")
    local function placeBadge()
        badge.Position = UDim2.fromOffset(82 + nameLabel.TextBounds.X + 8, 15)
    end
    nameLabel:GetPropertyChangedSignal("TextBounds"):Connect(placeBadge)
    placeBadge()
    local hidden = false
    local hideButton = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(44, 44),
        Text = "OCULTAR",
        TextSize = 9,
        AutoButtonColor = false,
        FontFace = Library.Fonts.Bold,
    }, identity)
    decorate(hideButton, "Background", 6)
    th(hideButton, "TextColor3", "Text")
    hideButton.MouseButton1Click:Connect(function()
        hidden = not hidden
        pcall(function()
            win:SetHideName(hidden)
            win:SetHideAvatar(hidden)
        end)
        nameLabel.Text = hidden and "••••••" or LocalPlayer.DisplayName
        userLabel.Text = hidden and "@••••••" or ("@" .. LocalPlayer.Name)
        avatar.Image = hidden and "" or (thumbnail or "")
        th(hideButton, "TextColor3", hidden and "Accent" or "Text")
    end)

    -- Estatísticas
    local stats = box(root, "Estatísticas", 2)
    local statsGrid = grid(stats, 6, 1)
    local vKills = cell(statsGrid, "Abates", 1, 15)
    local vDeaths = cell(statsGrid, "Mortes", 2, 15)
    local vKD = cell(statsGrid, "Proporção K/D", 3, 15)
    local vReports = cell(statsGrid, "Denúncias", 4, 15)
    local vPlayed = cell(statsGrid, "Tempo jogado", 5, 15)
    local vDamage = cell(statsGrid, "Dano recebido", 6, 15)
    th(vKD, "TextColor3", "Accent")

    -- Sessão e Conta lado a lado
    local row = mk("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 3,
    }, root)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    local sessionBox = box(row, "Sessão", 1, UDim2.new(0.5, -5, 0, 0))
    local accountBox = box(row, "Conta", 2, UDim2.new(0.5, -5, 0, 0))
    local sessionGrid, accountGrid = grid(sessionBox, 2, 1), grid(accountBox, 2, 1)
    local vFps, fpsCell = cell(sessionGrid, "FPS", 1)
    local vPing, pingCell = cell(sessionGrid, "Ping", 2)
    local vSession = cell(sessionGrid, "Tempo da sessão", 3)
    local vPlayers = cell(sessionGrid, "Jogadores", 4)
    local vDevice = cell(sessionGrid, "Dispositivo", 5)
    local vResolution = cell(sessionGrid, "Resolução", 6)
    local pushFps, pushPing = spark(fpsCell), spark(pingCell)
    local vAge = cell(accountGrid, "Idade da conta", 1)
    local vUserId = cell(accountGrid, "ID do usuário", 2)
    local vRuns = cell(accountGrid, "Execuções", 3)
    local vAccess = cell(accountGrid, "Acesso", 4)
    local vLeft = cell(accountGrid, "Tempo restante", 5)
    local vVersion = cell(accountGrid, "Versão do script", 6)

    -- Servidores
    local serversBox = box(root, "Servidores", 4)
    local serversGrid = grid(serversBox, 3, 1)
    local vMap = cell(serversGrid, "ID do mapa", 1)
    local vMapVersion = cell(serversGrid, "Versão do mapa", 2)
    local vJob = cell(serversGrid, "ID do servidor", 3, 14)

    -- Valores estáticos (reais)
    vUserId.Text = tostring(LocalPlayer.UserId)
    vAge.Text = LocalPlayer.AccountAge .. " " .. tr("dias")
    vAccess.Text = access
    vVersion.Text = version
    vDevice.Text = getDevice()
    onLanguageChanged(function()
        vDevice.Text = getDevice()
        vAge.Text = LocalPlayer.AccountAge .. " " .. tr("dias")
    end)
    vMap.Text = tostring(game.PlaceId)
    vMapVersion.Text = tostring(game.PlaceVersion)
    vJob.Text = (game.JobId ~= "" and game.JobId) or tr("Servidor local")
    vRuns.Text = tostring(data.runs)
    vReports.Text = "—"

    local started, lastSave, lastTick = os.clock(), os.clock(), os.clock()
    local function refresh()
        local now = os.clock()
        data.played += now - lastTick
        lastTick = now
        fps = frames
        frames = 0
        local ping = getPing()
        vFps.Text = tostring(fps)
        pushFps(fps)
        vPing.Text = ping .. " ms"
        pushPing(ping)
        vFps.TextColor3 = fps >= 50 and Library.Theme.Text or (fps >= 30 and Library.Theme.Warning or Library.Theme.Error)
        vPing.TextColor3 = ping <= 90 and Library.Theme.Text or (ping <= 180 and Library.Theme.Warning or Library.Theme.Error)
        vSession.Text = fmtDuration(now - started, true)
        vPlayers.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
        local camera = workspace.CurrentCamera
        if camera then
            vResolution.Text = math.floor(camera.ViewportSize.X) .. " x " .. math.floor(camera.ViewportSize.Y)
        end
        local kills = leaderStat({ "kill", "abate", "elimin" }) or data.kills
        local deaths = leaderStat({ "death", "morte", "died" }) or data.deaths
        vKills.Text = tostring(kills)
        vDeaths.Text = tostring(deaths)
        vKD.Text = string.format("%.2f", kills / math.max(deaths, 1))
        vPlayed.Text = fmtDuration(data.played)
        vDamage.Text = fmtBig(data.damage)
        local expiry = config.Expiry
        if type(expiry) == "function" then
            local ok, result = pcall(expiry)
            expiry = ok and result or nil
        end
        if type(expiry) == "number" then
            local left = expiry - os.time()
            vLeft.Text = left > 0 and fmtDuration(left) or tr("Expirado")
        else
            vLeft.Text = tr("Ilimitado")
        end
        if now - lastSave >= 30 then
            lastSave = now
            save()
        end
    end
    refresh()
    task.spawn(function()
        while list.Parent do
            task.wait(1)
            pcall(refresh)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        if player == LocalPlayer then
            save()
        end
    end)

    return root
end

return Features

end)

-- ============================================================
-- módulo: features.combat  (features/combat.lua)
-- ============================================================
__module("features.combat", function(BBC)
--[[
    BBC HUB - Feature: Combat
    Aba COMBATE: mira, alvos, espada, arma, efeitos, anti-aim e granadas.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

local function notify(text)
    BBC.Utils.notifyText(text)
end

function Features.buildCombat(window)
    local combat = window:Tab({ Name = "COMBATE", Icon = "crosshair" })

    local group = combat:Groupbox({
        Name = "MIRA",
        Icon = "crosshair",
        Side = "Left",
        Checkbox = true,
        Default = true,
        Callback = function() end,
    })
    group:Segmented({
        Name = "Modo",
        Options = { "Silencioso", "Fixar", "Agressivo" },
        Icons = { "crosshair", "lock", "flame" },
        Default = "Fixar",
        Callback = function() end,
    })
    group:Dropdown({
        Name = "Ativação",
        Options = { "Ao mirar", "Sempre" },
        Default = "Ao mirar",
        Callback = function() end,
    })
    T(group, "Alvo fixo")
    T(group, "Previsão")
    S(group, "Suavização", 0, 300, 80, "ms")
    T(group, "Pausa inteligente")
    T(group, "Notificar", true)

    group = combat:Groupbox({ Name = "ALVOS", Icon = "target", Side = "Left" })
    S(group, "Raio da mira", 10, 500, 70)
    T(group, "FOV dinâmico", true)
    group:Dropdown({
        Name = "Ponto de mira",
        Options = { "Partes selecionadas", "Mais próximo" },
        Default = "Partes selecionadas",
        Callback = function() end,
    })
    group:Dropdown({
        Name = "Partes do corpo",
        Options = { "Cabeça", "Corpo", "Braços", "Pernas" },
        Default = { "Cabeça" },
        Multi = true,
        Callback = function() end,
    })
    T(group, "Alternativa visível", true)
    T(group, "Mirar em NPCs", true)
    T(group, "Tiro por paredes", true)
    group:Keybind({ Name = "Adicionar amigo", Default = "MB3", Callback = function() end })
    S(group, "Limite de verificações", 1, 20, 7)

    group = combat:Groupbox({ Name = "ESPIADA", Icon = "eye", Side = "Left" })
    T(group, "Espiada subterrânea")

    group = combat:Groupbox({ Name = "CORPO A CORPO", Icon = "swords", Side = "Left" })
    T(group, "Aura letal", true)

    group = combat:Groupbox({ Name = "ARMA", Icon = "target", Side = "Right" })
    T(group, "Recarga automática", true)
    T(group, "Abastecer cargadores", true)
    group:Button({
        Name = "Manuseio da arma",
        Arrow = true,
        Callback = function()
            notify("Manuseio da arma")
        end,
    })
    T(group, "Mira falsa", true)

    group = combat:Groupbox({ Name = "EFEITOS DE COMBATE", Icon = "sparkles", Side = "Right" })
    T(group, "Retícula")
    T(group, "Círculo da mira", true)
    T(group, "Rastro personalizado", true)
    T(group, "Rastros do jogo", true)
    T(group, "Marca de acerto", true)
    T(group, "Números de dano", true)
    T(group, "Efeitos de acerto", true)
    T(group, "Efeitos de eliminação")
    T(group, "Dados do alvo", true)
    T(group, "Só acertos confirmados", true)

    group = combat:Groupbox({ Name = "ANTI AIM", Icon = "shield", Side = "Right" })
    T(group, "Anti aim")
    T(group, "Sob o chão")
    T(group, "Fantasma", true)

    group = combat:Groupbox({ Name = "GRANADAS", Icon = "bomb", Side = "Right" })
    T(group, "Trajetória do arremesso", true)
    T(group, "Sem tremor", true)

    return combat
end

return Features.buildCombat

end)

-- ============================================================
-- módulo: features.world  (features/world.lua)
-- ============================================================
__module("features.world", function(BBC)
--[[
    BBC HUB - Feature: World
    Aba MUNDO, EXTRAS, busca de saque, skins, missões, comerciantes
    e navegador de servidores (API pública do Roblox).
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Library = BBC.Library
local Utils = BBC.Utils
local Security = BBC.Security
local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local function tr(text)
    return BBC.I18n and BBC.I18n.tr(text) or text
end

local function notify(text)
    Utils.notifyText(text)
end

local function onLanguageChanged(callback)
    if BBC.I18n then
        table.insert(BBC.I18n.onChanged, callback)
    end
end

-- ============================================================
--  Navegador de servidores
-- ============================================================
function Features.buildServers(tab)
    local list = tab.List
    local themed = {}
    local function th(instance, property, key)
        themed[#themed + 1] = { instance, property, key }
        instance[property] = Library.Theme[key]
    end
    table.insert(Library._themeListeners, function()
        for _, item in ipairs(themed) do
            if item[1].Parent then
                item[1][item[2]] = Library.Theme[item[3]]
            end
        end
    end)
    local function mk(class, props, parent)
        local instance = Instance.new(class)
        for key, value in pairs(props) do
            instance[key] = value
        end
        instance.Parent = parent
        return instance
    end
    local function txt(parent, text, size, key, bold, extra)
        local textLabel = mk("TextLabel", {
            BackgroundTransparency = 1,
            Text = text,
            TextSize = size,
            FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.new(1, 0, 0, size + 4),
        }, parent)
        th(textLabel, "TextColor3", key or "Text")
        for property, value in pairs(extra or {}) do
            textLabel[property] = value
        end
        return textLabel
    end
    local function decorate(frame, key, radius)
        th(frame, "BackgroundColor3", key)
        frame.BorderSizePixel = 0
        mk("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, frame)
        th(mk("UIStroke", {}, frame), "Color", "Stroke")
    end
    local function button(parent, text, width, onClick, order)
        local instance = mk("TextButton", {
            Size = UDim2.fromOffset(width, 28),
            Text = text,
            TextSize = 13,
            AutoButtonColor = false,
            FontFace = Library.Fonts.Bold,
            LayoutOrder = order or 0,
        }, parent)
        decorate(instance, "Surface3", 6)
        th(instance, "TextColor3", "Text")
        instance.MouseButton1Click:Connect(onClick)
        return instance
    end

    local historyFile = "BBC_HUB/historico_servidores.json"
    local history = Security.readJSON(historyFile) or {}
    local function saveHistory()
        Security.ensureFolder("BBC_HUB")
        Security.writeJSON(historyFile, history)
    end
    local mapName = "Servidor"
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)
        if ok and info and info.Name then
            mapName = info.Name
        end
    end)

    local root = mk("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    }, list)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, root)

    local state = {
        all = {},
        sort = "players",
        desc = true,
        query = "",
        hideFull = true,
        hideMine = false,
        showHistory = false,
        selected = nil,
        loading = false,
        failed = false,
    }

    -- Cabeçalho
    local head = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 }, root)
    local title = txt(head, "", 15, "Text", true, { Size = UDim2.new(0.5, 0, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local right = mk("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0.6, 0, 1, 0),
    }, head)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, right)
    local refreshButton, historyButton, filtersButton
    local filtersFrame

    -- Busca + ordenação
    local bar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2 }, root)
    local searchBox = mk("TextBox", {
        Size = UDim2.new(1, -190, 1, 0),
        Text = "",
        TextSize = 13,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Library.Fonts.Regular,
    }, bar)
    decorate(searchBox, "Surface2", 6)
    th(searchBox, "TextColor3", "Text")
    th(searchBox, "PlaceholderColor3", "Muted")
    mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, searchBox)
    local sortButton = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -34, 0, 0),
        Size = UDim2.fromOffset(150, 30),
        TextSize = 13,
        AutoButtonColor = false,
        FontFace = Library.Fonts.Bold,
        Text = "",
    }, bar)
    decorate(sortButton, "Surface2", 6)
    th(sortButton, "TextColor3", "Text")
    local directionButton = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(28, 30),
        TextSize = 16,
        AutoButtonColor = false,
        FontFace = Library.Fonts.Bold,
        Text = "↓",
    }, bar)
    decorate(directionButton, "Surface2", 6)
    th(directionButton, "TextColor3", "Accent")

    -- Colunas
    local columns = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 }, root)
    local columnName = txt(columns, "", 12, "Muted", false, { Size = UDim2.new(0.34, 0, 1, 0), Position = UDim2.fromOffset(10, 0) })
    local columnPing = txt(columns, "", 12, "Muted", false, { Size = UDim2.new(0.15, 0, 1, 0), Position = UDim2.new(0.37, 0, 0, 0) })
    local columnPlayers = txt(columns, "", 12, "Muted", false, { Size = UDim2.new(0.17, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0) })
    local columnFps = txt(columns, "", 12, "Muted", false, { Size = UDim2.new(0.12, 0, 1, 0), Position = UDim2.new(0.69, 0, 0, 0) })

    -- Lista com rolagem própria
    local scroller = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 220),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        LayoutOrder = 5,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, root)
    th(scroller, "ScrollBarImageColor3", "Accent")
    local rowLayout = mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, scroller)
    mk("UIPadding", { PaddingRight = UDim.new(0, 8) }, scroller)
    rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local scale = scroller.AbsoluteSize.Y > 0 and (scroller.AbsoluteSize.Y / 220) or 1
        scroller.CanvasSize = UDim2.fromOffset(0, rowLayout.AbsoluteContentSize.Y / math.max(scale, 0.05) + 4)
    end)

    -- Cartão de detalhes
    local details = mk("Frame", { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 6 }, root)
    decorate(details, "Surface2", 8)
    local detailsName = txt(details, "", 15, "Text", true, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -190, 0, 20) })
    local detailsSub = txt(details, "", 12, "Muted", false, { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -190, 0, 18) })
    local detailsButtons = mk("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(170, 28),
    }, details)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, detailsButtons)
    local detailsButton, joinButton

    local function shortId(id)
        return string.sub(id or "", 1, 13)
    end

    local function visibleList()
        local result = {}
        if state.showHistory then
            for _, entry in ipairs(history) do
                table.insert(result, {
                    id = entry.id,
                    playing = entry.playing,
                    maxPlayers = entry.maxPlayers,
                    ping = entry.ping,
                    fps = entry.fps,
                    when = entry.when,
                })
            end
            return result
        end
        local query = string.lower(state.query)
        for _, server in ipairs(state.all) do
            local pass = true
            if state.hideFull and server.playing >= server.maxPlayers then
                pass = false
            end
            if state.hideMine and server.id == game.JobId then
                pass = false
            end
            if pass and query ~= "" then
                local haystack = string.lower(mapName .. " " .. server.id .. " " .. server.playing .. "/" .. server.maxPlayers)
                if not string.find(haystack, query, 1, true) then
                    pass = false
                end
            end
            if pass then
                table.insert(result, server)
            end
        end
        local key = state.sort == "ping" and "ping" or (state.sort == "fps" and "fps" or "playing")
        table.sort(result, function(a, b)
            local x, y = tonumber(a[key]) or 0, tonumber(b[key]) or 0
            if x == y then
                return a.id < b.id
            end
            if state.desc then
                return x > y
            end
            return x < y
        end)
        return result
    end

    local function joinServer(server)
        if not server then
            return
        end
        table.insert(history, 1, {
            id = server.id,
            playing = server.playing,
            maxPlayers = server.maxPlayers,
            ping = server.ping,
            fps = server.fps,
            when = os.time(),
        })
        while #history > 30 do
            table.remove(history)
        end
        saveHistory()
        notify(tr("Entrando no servidor..."))
        Library:JoinServer(server.id)
    end

    local function renderDetails()
        local server = state.selected
        if not server then
            detailsName.Text = mapName
            detailsSub.Text = tr("Pronto para entrar")
            return
        end
        detailsName.Text = mapName .. (server.id == game.JobId and ("  •  " .. tr("Seu servidor")) or "")
        detailsSub.Text = tr("Pronto para entrar") .. "  ·  " .. string.sub(server.id or "", 1, 22)
    end

    local render
    local function selectServer(server)
        state.selected = server
        renderDetails()
        render()
    end

    render = function()
        for _, child in ipairs(scroller:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        for index = #themed, 1, -1 do
            if not themed[index][1].Parent then
                table.remove(themed, index)
            end
        end
        local items = visibleList()
        local total = #state.all
        title.Text = string.upper(tr("Servidor")) .. "   " .. #items .. " / " .. total .. " " .. tr("servidores")
        columnName.Text = tr("Servidor")
        columnPing.Text = "Ping"
        columnPlayers.Text = tr("Jogadores")
        columnFps.Text = "FPS"
        sortButton.Text = tr("Ordenar") .. ": "
            .. (state.sort == "players" and tr("Jogadores") or (state.sort == "ping" and "Ping" or "FPS"))
        directionButton.Text = state.desc and "↓" or "↑"
        searchBox.PlaceholderText = tr("Buscar mapa, nome ou ID do servidor")
        refreshButton.Text = tr("Atualizar")
        historyButton.Text = tr("Histórico")
        filtersButton.Text = tr("Filtros")
        detailsButton.Text = tr("Detalhes")
        joinButton.Text = tr("Entrar")
        if state.loading then
            txt(scroller, tr("Carregando servidores..."), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        elseif state.failed and not state.showHistory then
            txt(scroller, tr("Falha ao carregar a lista"), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        elseif #items == 0 then
            txt(scroller, tr(state.showHistory and "Histórico vazio" or "Nenhum servidor encontrado"), 14, "Muted", false, {
                Size = UDim2.new(1, 0, 0, 24),
            })
        end
        for index, server in ipairs(items) do
            if index > 150 then
                break
            end
            local row = mk("TextButton", {
                Size = UDim2.new(1, 0, 0, 44),
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
            }, scroller)
            decorate(row, "Surface2", 6)
            local selected = state.selected and state.selected.id == server.id
            if selected then
                th(row:FindFirstChildOfClass("UIStroke"), "Color", "Accent")
            end
            txt(row, mapName, 14, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.34, -10, 0, 18) })
            txt(row, (server.id == game.JobId and (tr("Seu servidor") .. " · ") or "") .. shortId(server.id), 11, "Muted", false, {
                Position = UDim2.fromOffset(10, 24),
                Size = UDim2.new(0.34, -10, 0, 16),
            })
            local ping = tonumber(server.ping)
            txt(row, ping and (math.floor(ping) .. " ms") or "—", 13, "Text", false, {
                Position = UDim2.new(0.37, 0, 0, 12),
                Size = UDim2.new(0.15, 0, 0, 18),
            })
            txt(row, (server.playing or 0) .. "/" .. (server.maxPlayers or 0), 13, "Text", false, {
                Position = UDim2.new(0.52, 0, 0, 12),
                Size = UDim2.new(0.17, 0, 0, 18),
            })
            local fps = tonumber(server.fps)
            txt(row, fps and tostring(math.floor(fps)) or "—", 13, "Text", false, {
                Position = UDim2.new(0.69, 0, 0, 12),
                Size = UDim2.new(0.12, 0, 0, 18),
            })
            local full = (server.playing or 0) >= (server.maxPlayers or 0) and (server.maxPlayers or 0) > 0
            local join = mk("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(62, 28),
                Text = tr("Entrar"),
                TextSize = 13,
                AutoButtonColor = false,
                FontFace = Library.Fonts.Bold,
                BorderSizePixel = 0,
                ZIndex = 3,
            }, row)
            th(join, "BackgroundColor3", full and "Surface3" or "Accent")
            th(join, "TextColor3", "Text")
            mk("UICorner", { CornerRadius = UDim.new(0, 5) }, join)
            join.MouseButton1Click:Connect(function()
                state.selected = server
                renderDetails()
                joinServer(server)
            end)
            row.MouseButton1Click:Connect(function()
                selectServer(server)
            end)
        end
    end

    local function load()
        if state.loading then
            return
        end
        state.loading, state.failed = true, false
        render()
        task.spawn(function()
            local all, cursor = {}, nil
            for _ = 1, 3 do
                local page, nextCursor = Library:FetchServers("Desc", cursor)
                if not page then
                    if #all == 0 then
                        state.failed = true
                    end
                    break
                end
                for _, server in ipairs(page) do
                    if type(server) == "table" and server.id then
                        table.insert(all, {
                            id = server.id,
                            playing = tonumber(server.playing) or 0,
                            maxPlayers = tonumber(server.maxPlayers) or 0,
                            ping = server.ping,
                            fps = server.fps,
                        })
                    end
                end
                cursor = nextCursor
                if not cursor then
                    break
                end
            end
            state.all, state.loading = all, false
            render()
        end)
    end

    refreshButton = button(right, "", 88, function()
        state.showHistory = false
        load()
    end, 3)
    historyButton = button(right, "", 88, function()
        state.showHistory = not state.showHistory
        render()
    end, 2)
    filtersButton = button(right, "", 78, function()
        filtersFrame.Visible = not filtersFrame.Visible
    end, 1)
    detailsButton = button(detailsButtons, "", 80, function()
        local server = state.selected
        if not server then
            return
        end
        local info = string.format(
            "%s | %d/%d | %s ms | %s fps",
            server.id,
            server.playing or 0,
            server.maxPlayers or 0,
            tostring(server.ping and math.floor(server.ping) or "—"),
            tostring(server.fps and math.floor(server.fps) or "—")
        )
        if not pcall(function()
            setclipboard(server.id)
        end) then
            notify(info)
        else
            notify(tr("Copiar ID") .. ": " .. string.sub(server.id, 1, 13))
        end
    end, 1)
    joinButton = button(detailsButtons, "", 80, function()
        joinServer(state.selected)
    end, 2)

    -- Filtros
    filtersFrame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        LayoutOrder = 3,
    }, root)
    decorate(filtersFrame, "Surface2", 6)
    mk("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
    }, filtersFrame)
    mk("UIListLayout", {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, filtersFrame)
    local function filterToggle(key, label, order)
        local toggle = mk("TextButton", {
            Size = UDim2.fromOffset(150, 26),
            TextSize = 13,
            AutoButtonColor = false,
            FontFace = Library.Fonts.Regular,
            LayoutOrder = order,
            Text = "",
        }, filtersFrame)
        decorate(toggle, "Surface3", 6)
        th(toggle, "TextColor3", "Text")
        local function paint()
            toggle.Text = (state[key] and "● " or "○ ") .. tr(label)
        end
        paint()
        toggle.MouseButton1Click:Connect(function()
            state[key] = not state[key]
            paint()
            render()
        end)
        onLanguageChanged(paint)
    end
    filterToggle("hideFull", "Ocultar cheios", 1)
    filterToggle("hideMine", "Ocultar meu servidor", 2)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        state.query = searchBox.Text
        render()
    end)
    sortButton.MouseButton1Click:Connect(function()
        state.sort = state.sort == "players" and "ping" or (state.sort == "ping" and "fps" or "players")
        render()
    end)
    directionButton.MouseButton1Click:Connect(function()
        state.desc = not state.desc
        render()
    end)
    onLanguageChanged(function()
        renderDetails()
        render()
    end)
    renderDetails()
    load()
end

-- ============================================================
--  Abas MUNDO / EXTRAS / CONTEÚDO
-- ============================================================
function Features.buildWorld(window)
    local world = window:Tab({ Name = "MUNDO", Icon = "globe" })

    local group = world:Groupbox({ Name = "MUNDO", Icon = "globe", Side = "Left" })
    group:Foldout({
        Name = "Cores do terreno",
        Build = function(panel)
            panel:ColorPicker({ Name = "Grama", Default = Color3.fromRGB(72, 160, 76), Callback = function() end })
            panel:ColorPicker({ Name = "Areia", Default = Color3.fromRGB(214, 190, 120), Callback = function() end })
            panel:ColorPicker({ Name = "Rocha", Default = Color3.fromRGB(120, 120, 126), Callback = function() end })
            panel:ColorPicker({ Name = "Terra", Default = Color3.fromRGB(110, 78, 52), Callback = function() end })
        end,
    })
    group:Foldout({
        Name = "Folhas",
        Build = function(panel)
            panel:ColorPicker({ Name = "Cor das folhas", Default = Color3.fromRGB(70, 150, 70), Callback = function() end })
        end,
    })
    group:Foldout({
        Name = "Troncos",
        Build = function(panel)
            panel:ColorPicker({ Name = "Cor dos troncos", Default = Color3.fromRGB(100, 70, 45), Callback = function() end })
        end,
    })
    group:ColorPicker({ Name = "Cor da água", Default = Color3.fromRGB(40, 70, 75), Callback = function() end })
    T(group, "Sem grama", true)
    T(group, "Desativar minas", true)

    group = world:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Left" })
    T(group, "Carregar jogadores")
    T(group, "Buscar chefes")
    T(group, "Pontos de saída", true)
    T(group, "Radar")

    group = world:Groupbox({
        Name = "ILUMINAÇÃO",
        Icon = "lightbulb",
        Side = "Right",
        Checkbox = true,
        Default = true,
        Callback = function() end,
    })
    for _, name in ipairs({
        "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens",
        "Florescer", "Desfoque", "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade",
    }) do
        T(group, name, name == "Luz" or name == "Hora e sol")
    end

    -- EXTRAS
    local extras = window:Tab({ Name = "EXTRAS", Icon = "layout-grid" })
    group = extras:Groupbox({ Name = "EXTRAS", Icon = "layout-grid", Side = "Left" })
    T(group, "Troca rápida")
    T(group, "Modo pânico")
    group:Button({
        Name = "Atravessar porta",
        Callback = function()
            notify("Atravessar porta")
        end,
    })
    T(group, "Remover efeitos")
    T(group, "Avisos de denúncias", true)
    T(group, "Avisos de entrada")

    group = extras:Groupbox({ Name = "SONS", Icon = "volume-2", Side = "Left" })
    group:Input({ Name = "Adicionar ID de som", Placeholder = "ID", Callback = function() end })
    for _, name in ipairs({
        "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo",
        "Abate", "Disparo", "Acerto com sangue",
    }) do
        T(group, name, name == "Disparo")
    end

    group = extras:Groupbox({ Name = "DETECÇÃO", Icon = "radar", Side = "Right" })
    T(group, "Criador")
    T(group, "Testador")
    T(group, "Moderador", true)
    T(group, "Trapaceiro")

    group = extras:Groupbox({ Name = "ORDENAR DEPÓSITO", Icon = "arrow-down-up", Side = "Right" })
    group:Button({ Name = "Por valor", Callback = function() notify("Por valor") end })
    group:Button({ Name = "Por tipo", Callback = function() notify("Por tipo") end })
    group:Button({ Name = "Por nome", Callback = function() notify("Por nome") end })

    group = extras:Groupbox({ Name = "VER INVENTÁRIO", Icon = "backpack", Side = "Right" })
    group:Keybind({ Name = "Ver inventário", Default = "Backquote", Callback = function() end })
    group:Dropdown({
        Name = "Mostrar",
        Options = { "Jogadores", "NPCs", "Todos" },
        Default = "Jogadores",
        Callback = function() end,
    })
    T(group, "Sempre mostrar")

    -- Conteúdo
    local loot = window:Tab({ Name = "BUSCAR SAQUE", Icon = "package-search" })
    loot:Section("BUSCAR SAQUE")
    loot:Label({ Text = "Resultados da busca aparecerão aqui." })

    local servers = window:Tab({ Name = "SERVIDORES", Icon = "server" })
    Features.buildServers(servers)

    local skins = window:Tab({ Name = "SKINS", Icon = "palette" })
    skins:Section("SKINS")

    local quests = window:Tab({ Name = "MISSÕES", Icon = "scroll-text" })
    quests:Section("MISSÕES")

    local merchants = window:Tab({ Name = "COMERCIANTES", Icon = "shopping-cart" })
    merchants:Section("COMERCIANTES")

    return world
end

return Features

end)

-- ============================================================
-- módulo: main  (main.lua)
-- ============================================================
__module("main", function(BBC)
--[[
    BBC HUB - Entry point
    Bootstrap da aplicação: i18n, configuração, janela, overlays,
    features e aba de configurações.
]]

local Library = BBC.Library
local Utils = BBC.Utils
local Security = BBC.Security
local UI = BBC.UI
local Controls = UI.Controls
local T = Controls.T

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

Security.init()

-- ============================================================
--  IDIOMAS (English / Español / Português / 简体中文 / Русский)
-- ============================================================
local LANG_CODES = {
    ["English"] = "en",
    ["Español"] = "es",
    ["Português (Brasil)"] = "pt",
    ["简体中文"] = "zh",
    ["Русский"] = "ru",
}
local LANG_NAMES = {
    en = "English",
    es = "Español",
    pt = "Português (Brasil)",
    zh = "简体中文",
    ru = "Русский",
}
local DICT = {}
do
    local RAW = [==[
OCULTAR|HIDE|OCULTAR|隐藏|СКРЫТЬ
Ilimitado|Unlimited|Ilimitado|无限|Безлимит
Expirado|Expired|Expirado|已过期|Истёк
Celular|Mobile|Móvil|手机|Телефон
Console|Console|Consola|主机|Консоль
Servidor local|Local server|Servidor local|本地服务器|Локальный сервер
dias|days|días|天|дн.
Menu|Menu|Menú|菜单|Меню
Cursor|Cursor|Cursor|光标|Курсор
Modo|Mode|Modo|模式|Режим
Intensidade|Intensity|Intensidad|强度|Интенсивность
Distância|Distance|Distancia|距离|Дистанция
Notificar|Notify|Notificar|通知|Уведомлять
VISUAIS|VISUALS|VISUALES|视觉|ВИЗУАЛ
INTERFACE DO JOGO|GAME INTERFACE|INTERFAZ DEL JUEGO|游戏界面|ИНТЕРФЕЙС ИГРЫ
LOCAL|LOCAL|LOCAL|本地|ЛОКАЛЬНО
JOGADOR|PLAYER|JUGADOR|玩家|ИГРОК
MOVIMENTO|MOVEMENT|MOVIMIENTO|移动|ДВИЖЕНИЕ
CÂMERA|CAMERA|CÁMARA|相机|КАМЕРА
SAQUE|LOOT|BOTÍN|战利品|ЛУТ
MÃOS E ARMA|HANDS AND WEAPON|MANOS Y ARMA|手和武器|РУКИ И ОРУЖИЕ
CAMPO DE VISÃO|FIELD OF VIEW|CAMPO DE VISIÓN|视野|УГОЛ ОБЗОРА
Campo de visão|Field of view|Campo de visión|视野|Угол обзора
Visão com zoom|Zoom view|Visión con zoom|缩放视野|Обзор с зумом
Zoom|Zoom|Zoom|缩放|Зум
ANIMAÇÕES|ANIMATIONS|ANIMACIONES|动画|АНИМАЦИИ
Animação|Animation|Animación|动画|Анимация
Velocidade|Speed|Velocidad|速度|Скорость
Peso|Weight|Peso|权重|Вес
Reproduzir|Play|Reproducir|播放|Играть
RECURSOS|FEATURES|RECURSOS|功能|ФУНКЦИИ
COMBATE|COMBAT|COMBATE|战斗|БОЙ
MIRA|AIM|PUNTERÍA|瞄准|ПРИЦЕЛ
Ativação|Activation|Activación|触发|Активация
Suavização|Smoothing|Suavizado|平滑|Сглаживание
ALVOS|TARGETS|OBJETIVOS|目标|ЦЕЛИ
Raio da mira|Aim radius|Radio de puntería|瞄准半径|Радиус прицела
Limite de verificações|Check limit|Límite de verificaciones|检查上限|Лимит проверок
Ponto de mira|Aim point|Punto de mira|瞄准点|Точка прицела
Partes do corpo|Body parts|Partes del cuerpo|身体部位|Части тела
Adicionar amigo|Add friend|Añadir amigo|添加好友|Добавить друга
ESPIADA|PEEK|ASOMARSE|探头|ВЫГЛЯДЫВАНИЕ
CORPO A CORPO|MELEE|CUERPO A CUERPO|近战|БЛИЖНИЙ БОЙ
ARMA|WEAPON|ARMA|武器|ОРУЖИЕ
Manuseio da arma|Weapon handling|Manejo del arma|武器操作|Управление оружием
EFEITOS DE COMBATE|COMBAT EFFECTS|EFECTOS DE COMBATE|战斗特效|БОЕВЫЕ ЭФФЕКТЫ
ANTI AIM|ANTI AIM|ANTI AIM|反瞄准|АНТИ АИМ
GRANADAS|GRENADES|GRANADAS|手雷|ГРАНАТЫ
MUNDO|WORLD|MUNDO|世界|МИР
Cores do terreno|Terrain colors|Colores del terreno|地形颜色|Цвета местности
Folhas|Leaves|Hojas|树叶|Листва
Troncos|Trunks|Troncos|树干|Стволы
Cor da água|Water color|Color del agua|水的颜色|Цвет воды
ILUMINAÇÃO|LIGHTING|ILUMINACIÓN|光照|ОСВЕЩЕНИЕ
EXTRAS|MISC|EXTRAS|杂项|ДОПОЛНИТЕЛЬНО
Atravessar porta|Pass through door|Atravesar puerta|穿过门|Проход через дверь
SONS|SOUNDS|SONIDOS|声音|ЗВУКИ
Adicionar ID de som|Add sound ID|Añadir ID de sonido|添加声音ID|Добавить ID звука
DETECÇÃO|DETECTION|DETECCIÓN|检测|ОБНАРУЖЕНИЕ
ORDENAR DEPÓSITO|SORT STORAGE|ORDENAR ALMACÉN|整理仓库|СОРТИРОВКА СКЛАДА
Por valor|By value|Por valor|按价值|По цене
Por tipo|By type|Por tipo|按类型|По типу
Por nome|By name|Por nombre|按名称|По имени
VER INVENTÁRIO|VIEW INVENTORY|VER INVENTARIO|查看背包|ПРОСМОТР ИНВЕНТАРЯ
Ver inventário|View inventory|Ver inventario|查看背包|Смотреть инвентарь
Mostrar|Show|Mostrar|显示|Показать
BUSCAR SAQUE|LOOTFINDER|BUSCAR BOTÍN|搜索战利品|ПОИСК ЛУТА
Resultados da busca aparecerão aqui.|Search results will appear here.|Los resultados aparecerán aquí.|搜索结果将显示在这里。|Результаты поиска появятся здесь.
SERVIDORES|SERVER|SERVIDORES|服务器|СЕРВЕРЫ
Trocar de servidor|Switch server|Cambiar de servidor|切换服务器|Сменить сервер
SKINS|SKINCHANGER|SKINS|换肤|СКИНЧЕНДЖЕР
MISSÕES|QUESTS|MISIONES|任务|МИССИИ
COMERCIANTES|MERCHANTS|COMERCIANTES|商人|ТОРГОВЦЫ
CONFIGURAÇÕES|SETTINGS|AJUSTES|设置|НАСТРОЙКИ
GERAL|GENERAL|GENERAL|通用|ОБЩЕЕ
Idioma|Language|Idioma|语言|Язык
Tecla do menu|Menu key|Tecla del menú|菜单键|Клавиша меню
Tecla do cursor|Cursor key|Tecla del cursor|光标键|Клавиша курсора
Rever tutorial|Review tutorial|Ver tutorial|重看教程|Повторить обучение
Sair|Exit|Salir|退出|Выход
APARÊNCIA|APPEARANCE|APARIENCIA|外观|ВНЕШНИЙ ВИД
Tema (cores)|Theme (colors)|Tema (colores)|主题(颜色)|Тема (цвета)
Fonte|Font|Fuente|字体|Шрифт
MARCA D'ÁGUA|WATERMARK|MARCA DE AGUA|水印|ВОДЯНОЙ ЗНАК
Ativar|Enable|Activar|启用|Включить
Campos visíveis|Visible fields|Campos visibles|可见字段|Видимые поля
LISTA DE ATALHOS|KEYBIND LIST|LISTA DE ATAJOS|快捷键列表|СПИСОК КЛАВИШ
Exibir|Display|Mostrar|显示方式|Показ
Interface carregada.|Interface loaded.|Interfaz cargada.|界面已加载。|Интерфейс загружен.
Tamanho|Size|Tamaño|大小|Размер
Largura|Width|Anchura|宽度|Ширина
Altura máxima|Max height|Altura máxima|最大高度|Макс. высота
Transp. fundo|Bg. transparency|Transp. fondo|背景透明度|Прозр. фона
Transp. do texto|Text transparency|Transp. del texto|文字透明度|Прозр. текста
Transp. da borda|Border transparency|Transp. del borde|边框透明度|Прозр. границы
Raio dos cantos|Corner radius|Radio de esquinas|圆角半径|Радиус углов
Mochila personalizada|Custom backpack|Mochila personalizada|自定义背包|Свой рюкзак
Mochila|Backpack|Mochila|背包|Рюкзак
Barra rápida|Hotbar|Barra rápida|快捷栏|Панель быстрого доступа
Hack de velocidade|Speed hack|Hack de velocidad|速度修改|Спидхак
Sprint automático|Auto sprint|Sprint automático|自动冲刺|Авто-спринт
Pulos seguidos|Bunny hop|Saltos seguidos|连续跳跃|Серия прыжков
Controle no ar|Air control|Control en el aire|空中控制|Контроль в воздухе
Voar|Fly|Volar|飞行|Полёт
Sem dano de queda|No fall damage|Sin daño por caída|无坠落伤害|Без урона от падения
Sempre no chão|Always grounded|Siempre en el suelo|始终在地面|Всегда на земле
Jesus|Jesus|Jesús|水上行走|Хождение по воде
Aranha|Spider|Araña|蜘蛛攀爬|Паук
Terceira pessoa|Third person|Tercera persona|第三人称|Третье лицо
Câmera livre|Free camera|Cámara libre|自由相机|Свободная камера
Saque automático|Auto loot|Botín automático|自动拾取|Авто-лут
Repetir|Repeat|Repetir|重复|Повтор
Painel do jogador|Player panel|Panel del jugador|玩家面板|Панель игрока
Anti AFK|Anti AFK|Anti AFK|防挂机|Анти АФК
Renascer automático|Auto respawn|Reaparición automática|自动重生|Авто-возрождение
Remover água|Remove water|Quitar agua|移除水|Убрать воду
Não se afogar|No drowning|No ahogarse|不会溺水|Не тонуть
Mapa e navegação|Map and navigation|Mapa y navegación|地图和导航|Карта и навигация
Alvo fixo|Fixed target|Objetivo fijo|固定目标|Фиксированная цель
Previsão|Prediction|Predicción|预测|Упреждение
Pausa inteligente|Smart pause|Pausa inteligente|智能暂停|Умная пауза
FOV dinâmico|Dynamic FOV|FOV dinámico|动态视野|Динамический FOV
Alternativa visível|Visible fallback|Alternativa visible|可见备选|Видимая альтернатива
Mirar em NPCs|Target NPCs|Apuntar a NPCs|瞄准NPC|Целиться в NPC
Tiro por paredes|Shoot through walls|Disparo a través de paredes|穿墙射击|Стрельба сквозь стены
Espiada subterrânea|Underground peek|Asomarse bajo tierra|地下探头|Подземное выглядывание
Aura letal|Lethal aura|Aura letal|致命光环|Смертельная аура
Recarga automática|Auto reload|Recarga automática|自动换弹|Авто-перезарядка
Abastecer cargadores|Refill magazines|Rellenar cargadores|补充弹匣|Пополнение магазинов
Mira falsa|Fake aim|Punto de mira falso|假瞄准|Ложный прицел
Retícula|Reticle|Retícula|准星|Сетка прицела
Círculo da mira|Aim circle|Círculo de puntería|瞄准圈|Круг прицела
Rastro personalizado|Custom trail|Rastro personalizado|自定义轨迹|Свой след
Rastros do jogo|Game trails|Rastros del juego|游戏轨迹|Следы игры
Marca de acerto|Hit marker|Marca de impacto|命中标记|Маркер попадания
Números de dano|Damage numbers|Números de daño|伤害数字|Числа урона
Efeitos de acerto|Hit effects|Efectos de impacto|命中特效|Эффекты попадания
Efeitos de eliminação|Kill effects|Efectos de eliminación|击杀特效|Эффекты убийства
Dados do alvo|Target data|Datos del objetivo|目标数据|Данные цели
Só acertos confirmados|Confirmed hits only|Solo impactos confirmados|仅确认命中|Только подтверждённые попадания
Anti aim|Anti aim|Anti aim|反瞄准|Анти аим
Sob o chão|Under the ground|Bajo el suelo|地面之下|Под землёй
Fantasma|Ghost|Fantasma|幽灵|Призрак
Trajetória do arremesso|Throw trajectory|Trayectoria del lanzamiento|投掷轨迹|Траектория броска
Sem tremor|No shake|Sin temblor|无抖动|Без тряски
Sem grama|No grass|Sin hierba|无草地|Без травы
Desativar minas|Disable mines|Desactivar minas|禁用地雷|Отключить мины
Carregar jogadores|Load players|Cargar jugadores|加载玩家|Загрузить игроков
Buscar chefes|Find bosses|Buscar jefes|查找首领|Поиск боссов
Pontos de saída|Exit points|Puntos de salida|撤离点|Точки выхода
Radar|Radar|Radar|雷达|Радар
Troca rápida|Quick swap|Cambio rápido|快速切换|Быстрая смена
Modo pânico|Panic mode|Modo pánico|紧急模式|Режим паники
Remover efeitos|Remove effects|Quitar efectos|移除特效|Убрать эффекты
Avisos de denúncias|Report alerts|Avisos de denuncias|举报提醒|Уведомления о жалобах
Avisos de entrada|Join alerts|Avisos de entrada|进入提醒|Уведомления о входе
Criador|Creator|Creador|创作者|Создатель
Testador|Tester|Probador|测试员|Тестер
Moderador|Moderator|Moderador|管理员|Модератор
Trapaceiro|Cheater|Tramposo|作弊者|Читер
Sempre mostrar|Always show|Mostrar siempre|始终显示|Всегда показывать
Cursor livre|Free cursor|Cursor libre|自由光标|Свободный курсор
Ocultar indisponíveis|Hide unavailable|Ocultar no disponibles|隐藏不可用|Скрыть недоступное
Fixar botão móvel|Lock floating button|Fijar botón móvil|固定悬浮按钮|Закрепить кнопку
Cubo|Cube|Cubo|立方体|Куб
Bordas estáticas|Static borders|Bordes estáticos|静态边框|Статичные границы
Fundo|Background|Fondo|背景|Фон
Sombra|Shadow|Sombra|阴影|Тень
Fixar|Pin|Fijar|固定|Закрепить
Destaque próprio|Highlight self|Resaltarme|突出自己|Выделить себя
Abates|Kills|Bajas|击杀|Убийства
Mortes|Deaths|Muertes|死亡|Смерти
Proporção K/D|K/D ratio|Ratio K/D|K/D比|Соотношение K/D
Denúncias|Reports|Denuncias|举报|Жалобы
Tempo jogado|Time played|Tiempo jugado|游戏时长|Время в игре
Dano recebido|Damage taken|Daño recibido|受到伤害|Полученный урон
ESTATÍSTICAS|STATISTICS|ESTADÍSTICAS|统计|СТАТИСТИКА
SESSÃO|SESSION|SESIÓN|会话|СЕССИЯ
CONTA|ACCOUNT|CUENTA|账号|АККАУНТ
Ping|Ping|Ping|延迟|Пинг
Tempo da sessão|Session time|Tiempo de sesión|会话时长|Время сессии
Jogadores|Players|Jugadores|玩家数|Игроки
Dispositivo|Device|Dispositivo|设备|Устройство
Resolução|Resolution|Resolución|分辨率|Разрешение
Idade da conta|Account age|Edad de la cuenta|账号年龄|Возраст аккаунта
ID do usuário|User ID|ID de usuario|用户ID|ID пользователя
Execuções|Executions|Ejecuciones|执行次数|Запуски
Acesso|Access|Acceso|权限|Доступ
Tempo restante|Time left|Tiempo restante|剩余时间|Осталось времени
Versão do script|Script version|Versión del script|脚本版本|Версия скрипта
ID do mapa|Map ID|ID del mapa|地图ID|ID карты
Versão do mapa|Map version|Versión del mapa|地图版本|Версия карты
ID do servidor|Server ID|ID del servidor|服务器ID|ID сервера
Sempre|Always|Siempre|始终|Всегда
Ao segurar|While holding|Al mantener|按住时|При удержании
Alternar|Toggle|Alternar|切换|Переключить
Padrão|Default|Predeterminado|默认|По умолчанию
Silencioso|Silent|Silencioso|静默|Тихий
Agressivo|Aggressive|Agresivo|激进|Агрессивный
Ao mirar|On aim|Al apuntar|瞄准时|При прицеливании
Partes selecionadas|Selected parts|Partes seleccionadas|选定部位|Выбранные части
Mais próximo|Closest|Más cercano|最近|Ближайший
Cabeça|Head|Cabeza|头部|Голова
Corpo|Body|Cuerpo|身体|Тело
Braços|Arms|Brazos|手臂|Руки
Pernas|Legs|Piernas|腿部|Ноги
Todos|All|Todos|全部|Все
Nome|Name|Nombre|名称|Имя
Hora|Time|Hora|时间|Время
Mostrar tudo|Show all|Mostrar todo|显示全部|Показать всё
Ocultar|Hide|Ocultar|隐藏|Скрыть
Jogador|Player|Jugador|玩家|Игрок
Recipiente|Container|Contenedor|容器|Контейнер
Item no chão|Item on ground|Objeto en el suelo|地上物品|Предмет на земле
Itens de missão|Quest items|Objetos de misión|任务物品|Предметы заданий
Aura|Aura|Aura|光环|Аура
Círculo de salto|Jump circle|Círculo de salto|跳跃圈|Круг прыжка
Auréola|Halo|Aureola|光晕|Нимб
Rastro estelar|Star trail|Rastro estelar|星光轨迹|Звёздный след
Deslocamento|Offset|Desplazamiento|偏移|Смещение
Trocar personagem|Swap character|Cambiar personaje|更换角色|Сменить персонажа
Personagem|Character|Personaje|角色|Персонаж
Corpo em 1ª pessoa|First-person body|Cuerpo en 1ª persona|第一人称身体|Тело от первого лица
Mãos|Hands|Manos|双手|Руки
Item na mão|Held item|Objeto en mano|手持物品|Предмет в руке
Luz|Light|Luz|光|Свет
Hora e sol|Time and sun|Hora y sol|时间和太阳|Время и солнце
Sombras|Shadows|Sombras|阴影|Тени
Renderização|Rendering|Renderizado|渲染|Рендеринг
Neblina|Fog|Niebla|雾|Туман
Atmosfera|Atmosphere|Atmósfera|大气|Атмосфера
Céu|Sky|Cielo|天空|Небо
Nuvens|Clouds|Nubes|云|Облака
Florescer|Bloom|Resplandor|泛光|Свечение
Desfoque|Blur|Desenfoque|模糊|Размытие
Ajuste de cor|Color correction|Ajuste de color|色彩校正|Цветокоррекция
Profundidade|Depth|Profundidad|景深|Глубина
Raios de sol|Sun rays|Rayos de sol|阳光射线|Лучи солнца
Tonalidade|Tint|Tonalidad|色调|Оттенок
Jump|Jump|Salto|跳跃|Прыжок
Pegadas|Footsteps|Pasos|脚步声|Шаги
Pouso|Landing|Aterrizaje|落地|Приземление
Capacete|Helmet|Casco|头盔|Шлем
Tiro na cabeça|Headshot|Disparo a la cabeza|爆头|Выстрел в голову
Tiro no corpo|Body shot|Disparo al cuerpo|命中身体|Выстрел в тело
Abate|Kill|Baja|击杀|Убийство
Disparo|Shot|Disparo|射击|Выстрел
Acerto com sangue|Blood hit|Impacto con sangre|流血命中|Попадание с кровью
Histórico|History|Historial|历史|История
Filtros|Filters|Filtros|筛选|Фильтры
Atualizar|Refresh|Actualizar|刷新|Обновить
Buscar mapa, nome ou ID do servidor|Search map, name or server ID|Buscar mapa, nombre o ID del servidor|搜索地图、名称或服务器ID|Поиск по карте, имени или ID сервера
Ordenar|Sort|Ordenar|排序|Сортировка
Servidor|Server|Servidor|服务器|Сервер
Detalhes|Details|Detalles|详情|Детали
Entrar|Join|Unirse|加入|Войти
Pronto para entrar|Ready to join|Listo para unirse|可以加入|Готов к входу
Carregando servidores...|Loading servers...|Cargando servidores...|正在加载服务器...|Загрузка серверов...
Nenhum servidor encontrado|No servers found|No se encontraron servidores|未找到服务器|Серверы не найдены
Ocultar cheios|Hide full|Ocultar llenos|隐藏已满|Скрыть полные
Ocultar meu servidor|Hide my server|Ocultar mi servidor|隐藏我的服务器|Скрыть мой сервер
Copiar ID|Copy ID|Copiar ID|复制ID|Копировать ID
Seu servidor|Your server|Tu servidor|你的服务器|Ваш сервер
Histórico vazio|History is empty|Historial vacío|历史为空|История пуста
Entrando no servidor...|Joining server...|Uniéndose al servidor...|正在加入服务器...|Вход на сервер...
Falha ao carregar a lista|Could not load the list|No se pudo cargar la lista|无法加载列表|Не удалось загрузить список
servidores|servers|servidores|服务器|серверов
Mais vagos primeiro|Emptiest first|Más vacíos primero|空闲优先|Сначала пустые
Cor do tema|Theme color|Color del tema|主题颜色|Цвет темы
HOME|HOME|INICIO|首页|ГЛАВНАЯ
Grama|Grass|Hierba|草地|Трава
Areia|Sand|Arena|沙子|Песок
Rocha|Rock|Roca|岩石|Камень
Terra|Dirt|Tierra|泥土|Земля
Cor das folhas|Leaf color|Color de las hojas|树叶颜色|Цвет листьев
Cor dos troncos|Trunk color|Color de los troncos|树干颜色|Цвет стволов
Transparência|Transparency|Transparencia|透明度|Прозрачность
Recurso exclusivo VIP.|VIP-only feature.|Función exclusiva VIP.|仅限VIP功能。|Только для VIP.
Lista de atalhos|Keybind list|Lista de atajos|快捷键列表|Список клавиш
Ilha de FPS|FPS island|Isla de FPS|FPS 灵动岛|Остров FPS
Toque para abrir|Tap to open|Toca para abrir|点击打开|Нажмите, чтобы открыть
Sessão|Session|Sesión|会话|Сессия
Idioma alterado|Language changed|Idioma cambiado|语言已更改|Язык изменён
Atalhos|Keybinds|Atajos|快捷键|Горячие клавиши
Em breve|Coming soon|Próximamente|即将推出|Скоро
Pressione a tecla do menu para abrir ou fechar.|Press the menu key to open or close.|Pulsa la tecla del menú para abrir o cerrar.|按菜单键打开或关闭。|Нажмите клавишу меню, чтобы открыть или закрыть.
Toque no botão flutuante para abrir o menu.|Tap the floating button to open the menu.|Toca el botón flotante para abrir el menú.|点击悬浮按钮打开菜单。|Нажмите на плавающую кнопку, чтобы открыть меню.
]==]
    for line in string.gmatch(RAW, "[^\n]+") do
        local parts = string.split(line, "|")
        if #parts >= 5 then
            DICT[parts[1]] = { en = parts[2], es = parts[3], zh = parts[4], ru = parts[5] }
        end
    end
end

local currentLang = "pt"
local notify = function(text)
    pcall(function()
        Library:Notify({ Title = "BBC HUB", Content = text, Duration = 2 })
    end)
end
local keys = { menu = "RightShift", cursor = "LeftAlt", zoom = "N" }
local LANG_FILE = "BBC_HUB/idioma.txt"
pcall(function()
    if type(isfile) == "function" and isfile(LANG_FILE) then
        local code = string.gsub(readfile(LANG_FILE), "%s", "")
        if LANG_NAMES[code] then
            currentLang = code
        end
    end
end)

local function tr(text)
    if currentLang == "pt" then
        return text
    end
    local entry = DICT[text]
    return entry and entry[currentLang] or text
end

local function trKey(text)
    text = string.gsub(text, "&apos;", "'")
    text = string.gsub(text, "&amp;", "&")
    return text
end

local function translateInstance(instance)
    if not (instance:IsA("TextLabel") or instance:IsA("TextButton")) then
        return
    end
    local current = instance.Text
    local original, last = instance:GetAttribute("pt"), instance:GetAttribute("tx")
    if original ~= nil and current ~= last then
        original = nil
    end
    if original == nil then
        local key = trKey(current)
        if DICT[key] then
            original = key
        else
            return
        end
    end
    local translated = tr(original)
    instance:SetAttribute("pt", original)
    instance:SetAttribute("tx", translated)
    if current ~= translated then
        instance.Text = translated
    end
end

local onLanguageChanged = {}
local function setLanguage(code, silent)
    if not LANG_NAMES[code] or code == currentLang then
        return
    end
    currentLang = code
    pcall(function()
        if type(writefile) == "function" then
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then
                makefolder("BBC_HUB")
            end
            writefile(LANG_FILE, code)
        end
    end)
    for _, callback in ipairs(onLanguageChanged) do
        pcall(callback)
    end
end

local Config = Security.getConfig()
Library.Access = Config.Access or "FREE"

BBC.State = {
    Config = Config,
    Keys = keys,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    refreshPanels = function() end,
    notify = notify,
}

BBC.I18n = {
    tr = tr,
    trKey = trKey,
    translateInstance = translateInstance,
    setLanguage = setLanguage,
    onChanged = onLanguageChanged,
    LANG_NAMES = LANG_NAMES,
    LANG_CODES = LANG_CODES,
    current = function()
        return currentLang
    end,
}
Library.Tr = tr

Utils.init()

local Window = Library:Window({
    Title = "BBC HUB",
    Subtitle = "v0.0.8.2",
    Size = UDim2.fromOffset(640, 388),
    Keybind = "RightShift",
    Theme = "Orange",
    Home = { Build = BBC.Features.buildProfile, Expiry = Config.Expiry },
})
local IS_MOBILE = BBC.State.IsMobile
pcall(function()
    Window:SetToggleButton(true)
end)

-- tradução automática de tudo que aparece na janela
do
    local gui = Window.Gui or Window.ScreenGui or Window.Root
    if gui then
        for _, descendant in ipairs(gui:GetDescendants()) do
            translateInstance(descendant)
        end
        gui.DescendantAdded:Connect(function(descendant)
            task.defer(translateInstance, descendant)
        end)
        table.insert(onLanguageChanged, function()
            for _, descendant in ipairs(gui:GetDescendants()) do
                translateInstance(descendant)
            end
        end)
    else
        warn("[BBC HUB] não achei a ScreenGui da janela para traduzir")
    end
end

-- Overlays (watermark / lista de atalhos)
local overlays = UI.Overlays.create()
BBC.State.refreshPanels = overlays.refresh
local WM, KL = overlays.WM, overlays.KL

-- Features
BBC.Features.buildVisuals(Window)
BBC.Features.buildPlayer(Window)
BBC.Features.buildCombat(Window)
BBC.Features.buildWorld(Window)

local FONT_URLS = {
    ["Press Start 2P"] = {
        Name = "PressStart2P",
        Weights = {
            Regular = "https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf",
        },
    },
    ["Silkscreen"] = {
        Name = "Silkscreen",
        Weights = {
            Regular = "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Regular.ttf",
            Bold = "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Bold.ttf",
        },
    },
}

local function retagFonts(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
            local bold = descendant:GetAttribute("bbcBold")
            if bold == nil then
                bold = descendant.FontFace.Weight.Value >= 600
                descendant:SetAttribute("bbcBold", bold)
            end
            descendant.FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular
        end
    end
end

local function setFont(name)
    if name == "Arimo" then
        Library.Fonts.Regular = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular)
        Library.Fonts.Medium = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Medium)
        Library.Fonts.Bold = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold)
    elseif name == "Arcade" or name == "Code" then
        local font = Font.fromEnum(name == "Arcade" and Enum.Font.Arcade or Enum.Font.Code)
        Library.Fonts.Regular, Library.Fonts.Medium, Library.Fonts.Bold = font, font, font
    elseif FONT_URLS[name] then
        if not Library:LoadFont(FONT_URLS[name]) then
            notify("Fonte indisponível neste executor (precisa de writefile e getcustomasset).")
            return
        end
    else
        return
    end
    if Window.Gui then
        retagFonts(Window.Gui)
    end
    retagFonts(overlays.overlay)
end

-- ============================================================
--  CONFIGURAÇÕES
-- ============================================================
local settings = Window:Tab({ Name = "CONFIGURAÇÕES", Icon = "settings", Hidden = true, IsSettings = true })

local function bindCfg(cfg, key, value)
    cfg[key] = value
    overlays.refresh()
end

local function SB(group, name, min, max, default, suffix, step, cfg, key)
    return group:Slider({
        Name = name,
        Min = min,
        Max = max,
        Default = default,
        Suffix = suffix or "",
        Step = step or 1,
        Tooltip = Controls.TIPS[name],
        Callback = function(value)
            bindCfg(cfg, key, value)
        end,
    })
end

-- Geral
local group = settings:Groupbox({ Name = "GERAL", Icon = "settings", Side = "Left" })
group:Dropdown({
    Name = "Idioma",
    Options = { "English", "Español", "Português (Brasil)", "简体中文", "Русский" },
    Default = LANG_NAMES[currentLang],
    Flags = {
        ["English"] = "en",
        ["Español"] = "es",
        ["Português (Brasil)"] = "pt",
        ["简体中文"] = "zh",
        ["Русский"] = "ru",
    },
    Callback = function(value)
        local code = LANG_CODES[type(value) == "table" and value[1] or value] or "pt"
        setLanguage(code)
        notify(tr("Idioma alterado") .. ": " .. LANG_NAMES[code])
    end,
})
group:Keybind({
    Name = "Tecla do menu",
    Default = "RightShift",
    OnChanged = function(key)
        Window:SetKeybind(key)
        keys.menu = key.Name
        overlays.refresh()
    end,
    Callback = function() end,
})
group:Keybind({
    Name = "Tecla do cursor",
    Default = "LeftAlt",
    OnChanged = function(key)
        overlays.setCursorKey(key)
        keys.cursor = key.Name
        overlays.refresh()
    end,
    Callback = function() end,
})
group:Toggle({
    Name = "Cursor livre",
    Default = true,
    Callback = function(value)
        overlays.setCursorFree(value)
    end,
})
group:Toggle({
    Name = "Lista de atalhos",
    Default = false,
    Callback = function(value)
        bindCfg(KL, "On", value)
    end,
})
group:Toggle({
    Name = "Ilha de FPS",
    Default = true,
    Callback = function(value)
        Window:SetIsland(value)
    end,
})
T(group, "Ocultar indisponíveis")
group:Toggle({
    Name = "Fixar botão móvel",
    Default = false,
    Callback = function(value)
        pcall(function()
            Window:SetIslandDraggable(not value)
        end)
    end,
})
group:Button({
    Name = "Rever tutorial",
    Callback = function()
        notify(tr(IS_MOBILE and "Toque no botão flutuante para abrir o menu." or "Pressione a tecla do menu para abrir ou fechar."))
    end,
})
group:Button({
    Name = "Sair",
    Callback = function()
        overlays.destroy()
        Window:Destroy()
    end,
})

-- Aparência
local presetNames = Library.ThemeOrder
group = settings:Groupbox({ Name = "APARÊNCIA", Icon = "palette", Side = "Left" })
do
    local swatches = Instance.new("Frame")
    swatches.BackgroundTransparency = 1
    swatches.Size = UDim2.new(1, 0, 0, 0)
    swatches.AutomaticSize = Enum.AutomaticSize.Y
    swatches.LayoutOrder = group:_nextOrder()
    local swatchPadding = Instance.new("UIPadding", swatches)
    swatchPadding.PaddingTop = UDim.new(0, 8)
    swatchPadding.PaddingBottom = UDim.new(0, 8)
    swatchPadding.PaddingLeft = UDim.new(0, 12)
    swatchPadding.PaddingRight = UDim.new(0, 8)
    local swatchGrid = Instance.new("UIGridLayout", swatches)
    swatchGrid.CellSize = UDim2.fromOffset(24, 24)
    swatchGrid.CellPadding = UDim2.fromOffset(5, 6)
    swatchGrid.SortOrder = Enum.SortOrder.LayoutOrder
    swatches.Parent = group.List
    local rings = {}
    local function accentOf(name)
        local palette = Library.ThemePresets[name]
        local accent = palette and palette.Accent
        if typeof(accent) == "Color3" then
            return accent
        end
        if type(accent) == "string" then
            local ok, result = pcall(Color3.fromHex, accent)
            if ok then
                return result
            end
        end
        if type(accent) == "table" and #accent == 3 then
            return Color3.fromRGB(accent[1], accent[2], accent[3])
        end
        return Color3.fromRGB(200, 200, 200)
    end
    for index, name in ipairs(presetNames) do
        local accent = accentOf(name)
        local button = Instance.new("TextButton")
        button.Text = ""
        button.AutoButtonColor = false
        button.BackgroundColor3 = Color3.new(1, 1, 1)
        button.LayoutOrder = index
        button.BorderSizePixel = 0
        Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
        local gradient = Instance.new("UIGradient", button)
        gradient.Rotation = 55
        gradient.Color = ColorSequence.new(
            accent:Lerp(Color3.new(1, 1, 1), 0.35),
            accent:Lerp(Color3.new(0, 0, 0), 0.3)
        )
        local ring = Instance.new("UIStroke", button)
        ring.Thickness = 2.5
        ring.Color = Color3.new(1, 1, 1)
        ring.Transparency = (Library.ThemeName == name) and 0 or 1
        local tick = Instance.new("TextLabel", button)
        tick.BackgroundTransparency = 1
        tick.Size = UDim2.fromScale(1, 1)
        tick.Text = "✓"
        tick.TextSize = 13
        tick.TextColor3 = Color3.new(1, 1, 1)
        tick.FontFace = Library.Fonts.Bold
        tick.Visible = (Library.ThemeName == name)
        local pumpkin
        if name == "Halloween" then
            pumpkin = Instance.new("TextLabel", button)
            pumpkin.BackgroundTransparency = 1
            pumpkin.Size = UDim2.fromScale(1, 1)
            pumpkin.Text = "🎃"
            pumpkin.TextSize = 14
            pumpkin.Visible = not (Library.ThemeName == name)
        end
        rings[name] = { ring = ring, tick = tick, pumpkin = pumpkin }
        button.MouseButton1Click:Connect(function()
            Library:SetTheme(name)
            for themeName, themeRing in pairs(rings) do
                themeRing.ring.Transparency = (themeName == name) and 0 or 1
                themeRing.tick.Visible = (themeName == name)
                if themeRing.pumpkin then
                    themeRing.pumpkin.Visible = (themeName ~= name)
                end
            end
            overlays.setAccent(Library.Theme.Accent)
            notify(name)
        end)
        button.Parent = swatches
    end
end
group:Toggle({
    Name = "Cubo",
    Default = true,
    Callback = function(value)
        Window:SetLogo(value)
    end,
})
group:Dropdown({
    Name = "Fonte",
    Options = { "Arimo", "Arcade", "Code", "Press Start 2P", "Silkscreen" },
    Default = "Arimo",
    Callback = function(value)
        setFont(type(value) == "table" and value[1] or value)
    end,
})
group:Toggle({
    Name = "Bordas estáticas",
    Default = false,
    Callback = function(value)
        Window:SetBorderAccent(value)
    end,
})
local bgOn, bgValue = false, 25
group:Toggle({
    Name = "Fundo",
    Default = false,
    Callback = function(value)
        bgOn = value
        Window:SetBackgroundTransparency(value and bgValue / 100 or 0)
    end,
    Settings = function(panel)
        panel:Slider({
            Name = "Transparência",
            Min = 0,
            Max = 80,
            Default = 25,
            Suffix = "%",
            Callback = function(value)
                bgValue = value
                if bgOn then
                    Window:SetBackgroundTransparency(value / 100)
                end
            end,
        })
    end,
})
group:Toggle({
    Name = "Sombra",
    Default = false,
    Callback = function(value)
        Window:SetShadow(value)
    end,
})

-- Marca d'água
group = settings:Groupbox({
    Name = "MARCA D'ÁGUA",
    Icon = "scan",
    Side = "Right",
    Checkbox = true,
    Default = false,
    Callback = function(value)
        bindCfg(WM, "On", value)
    end,
})
group:Toggle({
    Name = "Fixar",
    Default = false,
    Callback = function(value)
        WM.Pin = value
    end,
})
group:Dropdown({
    Name = "Campos visíveis",
    Options = { "Nome", "FPS", "Ping", "Hora" },
    Default = { "Nome", "FPS", "Ping" },
    Multi = true,
    Callback = function(value)
        WM.Fields = value
    end,
})
SB(group, "Tamanho", 50, 200, 100, "%", 1, WM, "Size")
SB(group, "Largura", 150, 600, 285, "", 1, WM, "Width")
SB(group, "Altura máxima", 20, 500, 290, "", 1, WM, "MaxH")
SB(group, "Transp. fundo", 0, 1, 0.10, "", 0.01, WM, "BgT")
SB(group, "Transp. do texto", 0, 1, 0, "", 0.01, WM, "TxtT")
SB(group, "Transp. da borda", 0, 1, 0, "", 0.01, WM, "BrdT")
SB(group, "Raio dos cantos", 0, 20, 6, " px", 1, WM, "Radius")
group:Toggle({
    Name = "Sombra",
    Default = true,
    Callback = function(value)
        bindCfg(WM, "Shadow", value)
    end,
})

-- Lista de atalhos
group = settings:Groupbox({ Name = "LISTA DE ATALHOS", Icon = "keyboard", Side = "Right" })
local klPinToggle = group:Toggle({
    Name = "Fixar",
    Default = false,
    Callback = function(value)
        KL.Pin = value
        overlays.recolor()
    end,
})
overlays.setPinToggle(klPinToggle)
group:Toggle({
    Name = "Sombra",
    Default = true,
    Callback = function(value)
        bindCfg(KL, "Shadow", value)
    end,
})
SB(group, "Tamanho", 50, 200, 100, "%", 1, KL, "Size")
SB(group, "Largura", 200, 420, 250, "", 1, KL, "Width")
SB(group, "Altura máxima", 100, 500, 260, "", 1, KL, "MaxH")
SB(group, "Transp. fundo", 0, 1, 0.05, "", 0.01, KL, "BgT")
SB(group, "Transp. do texto", 0, 1, 0, "", 0.01, KL, "TxtT")
SB(group, "Transp. da borda", 0, 1, 0.75, "", 0.01, KL, "BrdT")
SB(group, "Raio dos cantos", 0, 20, 7, " px", 1, KL, "Radius")

overlays.refresh()
Library.Tr = tr
Library:Notify({ Title = "BBC HUB", Content = tr("Interface carregada."), Duration = 4 })

end)


return BBC
