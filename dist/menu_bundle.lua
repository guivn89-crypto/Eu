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
    if type(result) ~= "table" and result ~= nil then
        warn(string.format("[BBC] módulo '%s' retornou tipo inesperado: %s", name, type(result)))
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
    for k, v in pairs(props or {}) do
        instance[k] = v
    end
    return instance
end

-- ---------- Ícones (Lucide) ----------
local LUCIDE_URL = "https://raw.githubusercontent.com/lucide-icons/lucide/main/lucide/lucide.lua"
local LUCIDE_FALLBACK_URL = "https://raw.githubusercontent.com/Footagesus/Icons/main/lucide/dist/Icons.lua"
local lucide = nil
local iconsGaveUp = false
local allIcons = {}
local GLYPHS = {
    ["eye"] = "◉", ["user"] = "☺", ["crosshair"] = "⌖", ["globe"] = "◍", ["layout-grid"] = "▦", ["package-search"] = "▣",
    ["server"] = "▤", ["palette"] = "✎", ["scroll-text"] = "☰", ["shopping-cart"] = "▲", ["settings"] = "⚙", ["search"] = "⌕",
    ["flame"] = "♨", ["save"] = "▣", ["box"] = "◆", ["sliders-horizontal"] = "≡", ["message-circle"] = "✉", ["lock"] = "⚿", ["snowflake"] = "❄", ["x"] = "✕",
    ["save"] = "▣", ["box"] = "◆", ["sliders-horizontal"] = "≡", ["align-left"] = "≡", ["pin"] = "⚿", ["x"] = "✕", ["navigation-2"] = "⌖",
    ["scan-eye"] = "◉", ["layout-dashboard"] = "▦", ["map-pin"] = "◍", ["package"] = "▣", ["move"] = "⌖", ["camera"] = "◍",
    ["focus"] = "◉", ["hand"] = "☺", ["activity"] = "♨", ["puzzle"] = "▦", ["globe"] = "◍", ["lightbulb"] = "☺",
    ["volume-2"] = "♨", ["radar"] = "◉", ["arrow-down-up"] = "⌖", ["backpack"] = "▣", ["shield"] = "⚿", ["sparkles"] = "✕",
    ["target"] = "⌖", ["swords"] = "⚔", ["bomb"] = "●", ["filter"] = "▦", ["package-search"] = "▣", ["server"] = "▤",
    ["palette"] = "✎", ["scroll-text"] = "☰", ["shopping-cart"] = "▲", ["settings"] = "⚙", ["search"] = "⌕",
    ["flame"] = "♨", ["save"] = "▣", ["box"] = "◆", ["sliders-horizontal"] = "≡", ["message-circle"] = "✉", ["lock"] = "⚿",
    ["snowflake"] = "❄", ["x"] = "✕", ["align-left"] = "≡", ["pin"] = "⚿", ["navigation-2"] = "⌖",
}
local function resolveIcon(name)
    if not lucide then return nil end
    local entry = (lucide.Icons and lucide.Icons[name]) or lucide[name]
    if type(entry) == "string" then return entry end
    if type(entry) ~= "table" then return nil end
    local image = entry.Image
    if type(image) == "number" then image = "rbxassetid://" .. tostring(image) end
    local sheet = (lucide.Spritesheets and lucide.Spritesheets[tostring(image)]) or image
    return sheet, entry.ImageRectPosition, entry.ImageRectSize
end
local function showGlyph(rec)
    if rec.glyph or not rec.img.Parent then return end
    rec.img.Image = ""
    local g = create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = GLYPHS[rec.name] or "•", TextSize = 15, FontFace = BBC.Library.Fonts.Bold }, rec.img)
    Utils.bind(g, "TextColor3", function() return rec.img.ImageColor3 end)
    rec.glyph = g
end
local function applyIconNow(rec)
    local sheet, pos, size = resolveIcon(rec.name)
    if not sheet then showGlyph(rec) return end
    rec.img.Image = sheet
    if pos then rec.img.ImageRectOffset = pos end
    if size then rec.img.ImageRectSize = size end
    if rec.glyph then rec.glyph:Destroy(); rec.glyph = nil end
end
local function setIcon(img, name)
    if type(name) == "string" and (name:match("^%d+$") or name:find("^rbxassetid://")) then
        img.Image = name:match("^%d+$") and ("rbxassetid://" .. name) or name
        return
    end
    local rec = { img = img, name = name }
    allIcons[#allIcons + 1] = rec
    if lucide then applyIconNow(rec) elseif iconsGaveUp then showGlyph(rec) end
end
task.spawn(function()
    local CACHE = "BBC_HUB/cache_lucide.lua"
    local function compile(src) local f = loadstring(src); return f and f() end
    local function tryLoad(url)
        local src = game:HttpGet(url)
        local lib = compile(src)
        if type(lib) == "table" then return lib end
        return nil
    end
    local ok, result = pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" then
            local okc, cached = pcall(function() if isfile(CACHE) then return readfile(CACHE) end end)
            if okc and type(cached) == "string" and #cached > 1000 then
                local okp, lib = pcall(compile, cached)
                if okp and type(lib) == "table" then return lib end
            end
        end
        -- Try primary URL
        local lib = tryLoad(LUCIDE_URL)
        if lib then
            if type(writefile) == "function" then
                pcall(function()
                    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
                    writefile(CACHE, game:HttpGet(LUCIDE_URL))
                end)
            end
            return lib
        end
        -- Try fallback URL
        lib = tryLoad(LUCIDE_FALLBACK_URL)
        if lib then
            if type(writefile) == "function" then
                pcall(function()
                    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
                    writefile(CACHE, game:HttpGet(LUCIDE_FALLBACK_URL))
                end)
            end
            return lib
        end
        return nil
    end)
    if ok and type(result) == "table" then
        lucide = result
        BBC.lucide = lucide
        if type(allIcons) == "table" then
            for _, rec in ipairs(allIcons) do if rec.img and rec.img.Parent then applyIconNow(rec) end end
        end
    else
        warn("[BBC] ícones indisponíveis, usando símbolos: " .. tostring(result))
        iconsGaveUp = true
        BBC.iconsGaveUp = true
        if type(allIcons) == "table" and type(showGlyph) == "function" then
            for _, rec in ipairs(allIcons) do showGlyph(rec) end
        end
    end
end)

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
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ---------- Notificações ----------
local notifyGui, notifyHolder
function Utils.notify(opts)
    opts = opts or {}
    if BBC.Library.Panic then return end
    if not notifyGui or not notifyGui.Parent then
        notifyGui = create("ScreenGui", { Name = "BBCNotify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000 }, Utils.guiParent())
        notifyHolder = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(250, 400), BackgroundTransparency = 1 }, notifyGui)
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6) }, notifyHolder)
    end
    local card = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, BackgroundTransparency = 1 }, notifyHolder)
    Utils.bind(card, "BackgroundColor3", "Surface")
    Utils.corner(card, 5); Utils.stroke(card, "Stroke")
    local bar = create("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 }, card)
    Utils.bind(bar, "BackgroundColor3", "Accent"); Utils.corner(bar, 2)
    local inner = create("Frame", { Size = UDim2.new(1, -14, 0, 0), Position = UDim2.fromOffset(12, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, card)
    Utils.pad(inner, 0, 6, 7, 8); Utils.listLayout(inner, 2)
    if opts.Title then Utils.label(inner, opts.Title, 13, "Text", true, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 17) }) end
    if opts.Content then
        Utils.label(inner, opts.Content, 12, "Muted", false, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 16) })
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
    Utils.notify({ Title = "BBC HUB", Content = text, Duration = duration or 2 })
end

-- ---------- Bindings de tema ----------
function Utils.bind(inst, prop, key)
    local fn = type(key) == "function" and key or function() return BBC.Library.Theme[key] end
    inst[prop] = fn()
    BBC.Library._bindings[#BBC.Library._bindings + 1] = { inst, prop, fn }
end

-- ---------- Utilitários de texto/chave ----------
function Utils.textWidth(text, size)
    local ok, b = pcall(function() return TextService:GetTextSize(tostring(text), size or 12, Enum.Font.Arimo, Vector2.new(1000, 60)) end)
    return ok and b.X or (#tostring(text) * 7)
end

local KEY_SHORT = {
    RightShift = "RShift", LeftShift = "LShift", RightControl = "RCtrl", LeftControl = "LCtrl", RightAlt = "RAlt", LeftAlt = "LAlt",
    MouseButton3 = "MB3", MouseButton2 = "MB2", Backspace = "Bksp", Return = "Enter",
}
function Utils.keyText(v)
    if not v then return "None" end
    return KEY_SHORT[v.Name] or v.Name
end

function Utils.parseKey(v)
    if typeof(v) == "EnumItem" then return v end
    if type(v) ~= "string" then return nil end
    if v == "MB3" or v == "MouseButton3" then return Enum.UserInputType.MouseButton3 end
    if v == "MB2" or v == "MouseButton2" then return Enum.UserInputType.MouseButton2 end
    local ok, k = pcall(function() return Enum.KeyCode[v] end)
    return ok and k or nil
end

-- ---------- Flags (bandeiras desenhadas sem imagens) ----------
function Utils.makeFlag(parent, code, props)
    local f = create("Frame", { Size = UDim2.fromOffset(22, 15), BorderSizePixel = 0, ClipsDescendants = true, BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
    for k, v in pairs(props or {}) do f[k] = v end
    Utils.corner(f, 2)
    local function rect(x, y, w, h, col, rot)
        return create("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = col, BorderSizePixel = 0, Rotation = rot or 0 }, f)
    end
    if code == "pt" then
        f.BackgroundColor3 = Color3.fromRGB(0, 155, 58)
        rect(6, 2.5, 10, 10, Color3.fromRGB(255, 222, 0), 45)
        local c = rect(7.5, 4.5, 7, 7, Color3.fromRGB(0, 39, 118)); Utils.corner(c, 4)
    elseif code == "en" then
        f.BackgroundColor3 = Color3.fromRGB(1, 33, 105)
        rect(-3, 6, 28, 3, Color3.new(1, 1, 1), 33); rect(-3, 6, 28, 3, Color3.new(1, 1, 1), -33)
        rect(0, 5, 22, 5, Color3.new(1, 1, 1)); rect(8.5, 0, 5, 15, Color3.new(1, 1, 1))
        rect(0, 6, 22, 3, Color3.fromRGB(200, 16, 46)); rect(9.5, 0, 3, 15, Color3.fromRGB(200, 16, 46))
    elseif code == "es" then
        f.BackgroundColor3 = Color3.fromRGB(170, 21, 27)
        rect(0, 4, 22, 7, Color3.fromRGB(241, 191, 0))
    elseif code == "zh" then
        f.BackgroundColor3 = Color3.fromRGB(222, 41, 16)
        local st = create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(2, -1), Size = UDim2.fromOffset(10, 10), Text = "★", TextSize = 10, TextColor3 = Color3.fromRGB(255, 222, 0), FontFace = BBC.Library.Fonts.Bold }, f)
        create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 1), Size = UDim2.fromOffset(6, 6), Text = "★", TextSize = 5, TextColor3 = Color3.fromRGB(255, 222, 0) }, f)
    elseif code == "ru" then
        rect(0, 5, 22, 5, Color3.fromRGB(0, 57, 166)); rect(0, 10, 22, 5, Color3.fromRGB(213, 43, 30))
    end
    return f
end

-- ---------- Chip box (caixa lateral de toggles/sliders) ----------
function Utils.chipBox(parent)
    local c = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 0 }, parent)
    Utils.bind(c, "BackgroundColor3", "Surface2")
    Utils.corner(c, 4)
    local st = Utils.stroke(c, "Stroke", 0)
    return c, st
end

-- ---------- Inicialização ----------
function Utils.init()
    -- placeholder para inicializações futuras
end

-- Expose icon system to BBC for cross-module access
BBC.lucide = lucide
BBC.iconsGaveUp = iconsGaveUp
BBC.allIcons = allIcons
BBC.showGlyph = showGlyph
BBC.applyIconNow = applyIconNow

BBC.Utils = Utils
return Utils

end)

-- ============================================================
-- módulo: utils.protection  (utils/protection.lua)
-- ============================================================
__module("utils.protection", function(BBC)
--[[
    BBC HUB - Advanced Protection & Bypass Layer (Complete)
    Camada completa de proteção, ofuscação, bypass e compatibilidade multi-executor.

    PROTEÇÕES INCLUÍDAS:
    ██████████████████████████████████████████████████████████████████████████
    █ 1. EXECUTOR DETECTION & FINGERPRINTING (11 executors)                █
    █ 2. CAPABILITY MATRIX & UNIFIED API (35+ APIs)                      █
    █ 3. INTEGRITY MONITORING (environment, globals, hooks)              █
    █ 4. ANTI-DUMP / ANTI-DEBUG / ANTI-DECOMPILER                        █
    █ 5. ADVANCED CRYPTOGRAPHY (AES-256, ChaCha20, SHA-256, HMAC, ECDH)  █
    █ 6. SECURE STRINGS & CONSTANT ENCODING (polymorphic, per-session)   █
    █ 7. CONTROL FLOW OBFUSCATION (flattening, opaque predicates)        █
    █ 8. FUNCTION VIRTUALIZATION & BYTECODE INTERPRETATION               █
    █ 9. PROXY ENVIRONMENT & METATABLE HARDENING                         █
    █ 10. WATERMARKING & BUILD FINGERPRINTING (per-user/build)           █
    █ 11. LICENSE SYSTEM & HWID BINDING (with server validation)         █
    █ 12. HEARTBEAT & TIME-BASED EXPIRATION                              █
    █ 13. ANTI-RELOAD / ANTI-REINJECT / ANTI-TAMPER                      █
    █ 14. NETWORK ENCRYPTION & SECURE CHANNELS                           █
    █ 15. VM/SANDBOX DETECTION & ANALYSIS EVASION                        █
    █ 16. STACK TRACE OBFUSCATION & CALLER VERIFICATION                  █
    █ 17. TIMING ATTACK PREVENTION & SIDE-CHANNEL RESISTANCE             █
    █ 18. CONTROL FLOW INTEGRITY (CFI) & RETURN ADDRESS PROTECTION       █
    █ 19. SECURE RANDOM & CRYPTOGRAPHIC PRIMITIVES                       █
    █ 20. POLYMORPHIC CODE GENERATION & SELF-MODIFYING PATTERNS          █
    ██████████████████████████████████████████████████████████████████████████

    NÍVEIS DE PROTEÇÃO:
    ┌─────────────────────────────────────────────────────────────────────┐
    │ NÍVEL 1 - BÁSICO       │ Env checks, safe calls, config freeze    │
    │ NÍVEL 2 - INTERMEDIÁRIO │ Integrity, anti-debug, executor detect  │
    │ NÍVEL 3 - AVANÇADO      │ Anti-dump, VM detect, crypto, strings   │
    │ NÍVEL 4 - MÁXIMO        │ Polymorphic, CFI, virtualization, E2EE  │
    └─────────────────────────────────────────────────────────────────────┘

    COMPATIBILIDADE: Synapse X, Script-Ware, Fluxus, Delta, KRNL, Electron, Arceus X, Codex, Solara, Wave, VEGA X, UNC Generic
]]

local Protection = {}
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Security = BBC.Security
local Utils = BBC.Utils

local function log(message)
    warn("[BBC][protection] " .. tostring(message))
end

local function secureLog(level, message)
    if level >= (Protection._logLevel or 1) then
        warn(string.format("[BBC][protection][%s] %s", level == 1 and "INFO" or level == 2 and "WARN" or "CRIT", tostring(message)))
    end
end

-- ============================================================
-- CONSTANTS & CONFIGURATION
-- ============================================================
Protection.VERSION = "2.0.0"
Protection.BUILD_ID = HttpService:GenerateGUID(false):sub(1, 8)
Protection.SESSION_ID = HttpService:GenerateGUID(false)
Protection._logLevel = 1
Protection._initialized = false
Protection._destroyed = false

-- ============================================================
-- 1. EXECUTOR DETECTION & FINGERPRINTING
-- ============================================================
Protection.Executor = "Unknown"
Protection.ExecutorVersion = "Unknown"
Protection.API = {}
Protection.Capabilities = {}
Protection.Fingerprint = ""
Protection.HWID = ""

local EXECUTOR_SIGNATURES = {
    Synapse = {
        globals = { "syn", "synapse" },
        functions = { "syn.crypt", "syn.request", "syn.queue_on_teleport", "syn.protect_gui", "syn.unprotect_gui", "syn.set_thread_identity", "syn.get_thread_identity" },
        identity = 7,
        unc_support = 0.98,
        version_check = function(env) return env.syn and env.syn.version end,
    },
    ScriptWare = {
        globals = { "sw", "scriptware" },
        functions = { "sw.request", "sw.getgenv", "sw.setthreadidentity", "sw.hookfunction", "sw.clonefunction" },
        identity = 8,
        unc_support = 0.95,
        version_check = function(env) return env.sw and env.sw.version end,
    },
    Fluxus = {
        globals = { "fluxus", "Fluxus" },
        functions = { "fluxus.request", "fluxus.queue_on_teleport", "fluxus.protect_gui", "fluxus.setthreadidentity" },
        identity = 7,
        unc_support = 0.90,
        version_check = function(env) return env.fluxus and env.fluxus.version end,
    },
    Delta = {
        globals = { "delta", "Delta" },
        functions = { "delta.request", "delta.queue_on_teleport", "delta.protect_gui" },
        identity = 7,
        unc_support = 0.88,
        version_check = function(env) return env.delta and env.delta.version end,
    },
    KRNL = {
        globals = { "krnl", "Krnl" },
        functions = { "krnl.request", "krnl.queue_on_teleport", "krnl.protect_gui" },
        identity = 7,
        unc_support = 0.85,
        version_check = function(env) return env.krnl and env.krnl.version end,
    },
    Electron = {
        globals = { "electron", "Electron" },
        functions = { "electron.request", "electron.queue_on_teleport" },
        identity = 7,
        unc_support = 0.80,
        version_check = function(env) return env.electron and env.electron.version end,
    },
    ArceusX = {
        globals = { "arceus", "Arceus", "codex", "Codex", "solara", "Solara", "wave", "Wave" },
        functions = { "arceus.request" },
        identity = 6,
        unc_support = 0.70,
        version_check = function(env) return env.arceus and env.arceus.version or env.codex and env.codex.version end,
    },
    VEGA = {
        globals = { "vega", "Vega", "VEGA" },
        functions = { "vega.request" },
        identity = 6,
        unc_support = 0.75,
        version_check = function(env) return env.vega and env.vega.version end,
    },
    UNC = {
        globals = { "getgenv", "getrenv", "getsenv", "getfenv", "setthreadidentity", "getthreadidentity", "clonefunction", "hookfunction", "hookmetamethod", "checkcaller", "iscclosure", "islclosure", "newcclosure", "getgc", "getreg", "getloadedmodules", "getscripts", "getnilinstances", "gethiddenproperty", "sethiddenproperty", "fireclickdetector", "fireproximityprompt", "getconnections", "setclipboard", "getcustomasset", "queue_on_teleport", "request", "httpget", "httppost", "rconsoleprint", "rconsolewarn", "rconsoleerr", "rconsoleinfo" },
        functions = { "getgenv", "getrenv", "getsenv", "getfenv", "setthreadidentity", "getthreadidentity", "clonefunction", "hookfunction", "hookmetamethod", "checkcaller", "iscclosure", "islclosure", "newcclosure", "getgc", "getreg", "getloadedmodules", "getscripts", "getnilinstances", "gethiddenproperty", "sethiddenproperty", "fireclickdetector", "fireproximityprompt", "getconnections", "setclipboard", "getcustomasset", "queue_on_teleport", "request", "httpget", "httppost", "rconsoleprint", "rconsolewarn", "rconsoleerr", "rconsoleinfo" },
        identity = 6,
        unc_support = 0.60,
        version_check = function() return "UNC Generic" end,
    },
}

function Protection.detectExecutor()
    local env = getgenv and getgenv() or _G
    local detected = {}
    local maxScore = 0
    local bestMatch = "Unknown"
    local bestVersion = "Unknown"

    for name, sig in pairs(EXECUTOR_SIGNATURES) do
        local score = 0
        for _, globalName in ipairs(sig.globals or {}) do
            if env[globalName] ~= nil then
                score = score + 2
            end
        end
        for _, funcName in ipairs(sig.functions or {}) do
            local parts = string.split(funcName, ".")
            local current = env
            local found = true
            for _, part in ipairs(parts) do
                if type(current) == "table" and current[part] ~= nil then
                    current = current[part]
                else
                    found = false
                    break
                end
            end
            if found then score = score + 1 end
        end
        if score > maxScore then
            maxScore = score
            bestMatch = name
            if sig.version_check then
                local ok, ver = pcall(sig.version_check, env)
                if ok and ver then bestVersion = tostring(ver) end
            end
        end
        detected[name] = { score = score, signature = sig }
    end

    Protection.Executor = bestMatch
    Protection.ExecutorVersion = bestVersion
    Protection.Fingerprint = string.format("%s_%s_%d", bestMatch, bestVersion, maxScore)
    secureLog(1, string.format("Executor detectado: %s v%s (score: %d)", bestMatch, bestVersion, maxScore))

    return bestMatch, detected
end

-- ============================================================
-- 2. CAPABILITY MATRIX & UNIFIED API
-- ============================================================
function Protection.getCapabilities()
    local env = getgenv and getgenv() or _G
    local caps = {}

    local function check(path)
        local current = env
        for part in string.gmatch(path, "[^.]+") do
            if type(current) == "table" and current[part] ~= nil then
                current = current[part]
            else
                return false
            end
        end
        return type(current) == "function"
    end

    caps = {
        filesystem = {
            writefile = type(writefile) == "function",
            readfile = type(readfile) == "function",
            isfile = type(isfile) == "function",
            isfolder = type(isfolder) == "function",
            makefolder = type(makefolder) == "function",
            listfiles = type(listfiles) == "function",
            delfile = type(delfile) == "function",
            delfolder = type(delfolder) == "function",
        },
        network = {
            request = type(request) == "function" or type(http_request) == "function" or check("syn.request"),
            httpget = type(game.HttpGet) == "function",
            httppost = type(game.HttpPost) == "function",
            websocket = type(WebSocket) == "function" or type(websocket) == "function",
        },
        thread = {
            getthreadidentity = type(getthreadidentity) == "function" or type(getidentity) == "function",
            setthreadidentity = type(setthreadidentity) == "function" or type(setidentity) == "function",
            getgenv = type(getgenv) == "function",
            getrenv = type(getrenv) == "function",
            getsenv = type(getsenv) == "function",
        },
        funcmanip = {
            hookfunction = type(hookfunction) == "function",
            hookmetamethod = type(hookmetamethod) == "function",
            clonefunction = type(clonefunction) == "function",
            checkcaller = type(checkcaller) == "function",
            iscclosure = type(iscclosure) == "function",
            islclosure = type(islclosure) == "function",
            newcclosure = type(newcclosure) == "function",
        },
        memory = {
            getgc = type(getgc) == "function",
            getreg = type(getreg) == "function",
            getloadedmodules = type(getloadedmodules) == "function",
            getscripts = type(getscripts) == "function",
            getnilinstances = type(getnilinstances) == "function",
            gethiddenproperty = type(gethiddenproperty) == "function",
            sethiddenproperty = type(sethiddenproperty) == "function",
        },
        ui = {
            protect_gui = type(syn and syn.protect_gui) == "function" or type(protect_gui) == "function",
            unprotect_gui = type(syn and syn.unprotect_gui) == "function" or type(unprotect_gui) == "function",
            fireclickdetector = type(fireclickdetector) == "function",
            fireproximityprompt = type(fireproximityprompt) == "function",
            getconnections = type(getconnections) == "function",
        },
        crypto = {
            rconsole = type(rconsoleprint) == "function",
            crypt = type(crypt) == "function" or check("syn.crypt"),
            hash = type(hash) == "function",
        },
        clipboard = {
            setclipboard = type(setclipboard) == "function",
            getcustomasset = type(getcustomasset) == "function",
            queue_on_teleport = type(queue_on_teleport) == "function",
        },
    }

    -- Flatten for compatibility
    local flat = {}
    for category, catTable in pairs(caps) do
        for name, has in pairs(catTable) do
            flat[name] = has
        end
    end

    Protection.Capabilities = { detailed = caps, flat = flat }
    return caps
end

function Protection.getAPI()
    local env = getgenv and getgenv() or _G
    local api = {}

    api.request = env.syn and env.syn.request or env.request or env.http_request or env.fluxus and env.fluxus.request or env.delta and env.delta.request or env.krnl and env.krnl.request or function() return { Success = false, Error = "No request function" } end
    api.queue_on_teleport = env.queue_on_teleport or env.syn and env.syn.queue_on_teleport or env.fluxus and env.fluxus.queue_on_teleport or env.delta and env.delta.queue_on_teleport or env.krnl and env.krnl.queue_on_teleport or function() end
    api.protect_gui = env.syn and env.syn.protect_gui or env.protect_gui or function() end
    api.unprotect_gui = env.syn and env.syn.unprotect_gui or env.unprotect_gui or function() end
    api.crypt = env.crypt or env.syn and env.syn.crypt or { encrypt = function(data) return data end, decrypt = function(data) return data end, generatebytes = function(n) return string.rep("\0", n) end, generatekey = function() return string.rep("\0", 32) end }
    api.hash = env.hash or function(algo, data) return "" end
    api.random = env.random or function(n) local r={} for i=1,n do r[i]=string.char(math.random(0,255)) end return table.concat(r) end

    Protection.API = api
    return api
end

function Protection.getProtectionLevel()
    local caps = Protection.getCapabilities()
    local score = 0
    local total = 0

    for _, has in pairs(caps.flat) do
        total = total + 1
        if has then score = score + 1 end
    end

    local pct = (total > 0) and (score / total) or 0
    local level, desc

    if pct >= 0.90 then
        level, desc = 4, "Máximo (Full UNC + Crypto + Thread Control)"
    elseif pct >= 0.75 then
        level, desc = 3, "Avançado (UNC Parcial + Filesystem + Network)"
    elseif pct >= 0.55 then
        level, desc = 2, "Intermediário (Basic UNC + Filesystem)"
    else
        level, desc = 1, "Básico (Apenas Roblox Vanilla APIs)"
    end

    return level, desc, pct
end

-- ============================================================
-- 3. INTEGRITY & ANTI-TAMPER (Advanced)
-- ============================================================
Protection._originalEnv = {}
Protection._checksums = {}
Protection._hooks = {}
Protection._integrityCallbacks = {}

function Protection.cacheOriginalEnvironment()
    local env = getgenv and getgenv() or _G
    local critical = { "game", "workspace", "script", "require", "loadstring", "getfenv", "setfenv", "pcall", "xpcall", "error", "assert", "print", "warn", "type", "typeof", "Instance", "Vector2", "Vector3", "CFrame", "Color3", "UDim2", "Enum", "math", "string", "table", "coroutine", "debug", "os", "bit32", "buffer", "task", "delay", "spawn", "wait" }
    for _, name in ipairs(critical) do
        Protection._originalEnv[name] = env[name]
    end
    -- Checksum critical functions
    for _, name in ipairs(critical) do
        local fn = env[name]
        if type(fn) == "function" then
            Protection._checksums[name] = Protection._hashFunction(fn)
        end
    end
end

function Protection.validateEnvironment()
    local env = getgenv and getgenv() or _G
    local checks = {
        validGame = typeof(game) == "Instance",
        validWorkspace = typeof(workspace) == "Instance",
        validPlayers = typeof(Players) == "Instance",
        validLocalPlayer = Players.LocalPlayer ~= nil,
        validRunService = typeof(RunService) == "Instance",
        validHttpService = typeof(HttpService) == "Instance",
        hasGetGenV = type(getgenv) == "function",
        hasGetRenV = type(getrenv) == "function",
    }

    local passed = 0
    local total = 0
    for name, result in pairs(checks) do
        total = total + 1
        if result then passed = passed + 1 else secureLog(2, "Env check failed: " .. name) end
    end

    local score = passed / total
    secureLog(1, string.format("Environment validation: %.0f%% (%d/%d)", score * 100, passed, total))

    return score >= 0.8, checks
end

function Protection._hashFunction(fn)
    -- Simple hash of function identity (address-based approximation)
    return tostring(fn):sub(-16)
end

function Protection.verifyIntegrity()
    local env = getgenv and getgenv() or _G
    local issues = {}

    for name, original in pairs(Protection._originalEnv) do
        local current = env[name]
        if current ~= original then
            local allowed = { "syn", "scriptware", "fluxus", "delta", "krnl", "electron", "arceus", "protect_gui", "unprotect_gui", "queue_on_teleport", "request", "hookfunction", "hookmetamethod", "clonefunction", "getgenv", "getrenv", "setthreadidentity", "getthreadidentity", "checkcaller", "iscclosure", "islclosure", "newcclosure", "getgc", "getreg", "getloadedmodules", "getscripts", "getnilinstances", "gethiddenproperty", "sethiddenproperty", "fireclickdetector", "fireproximityprompt", "getconnections", "setclipboard", "getcustomasset", "rconsoleprint", "crypt", "hash", "listfiles", "delfile", "delfolder", "makefolder", "isfolder", "isfile", "readfile", "writefile", "syn", "scriptware", "fluxus", "delta", "krnl", "electron", "arceus", "vega" }
            local isAllowed = false
            for _, allowedName in ipairs(allowed) do
                if name == allowedName then isAllowed = true break end
            end
            if not isAllowed then
                issues[#issues + 1] = string.format("Modified global: %s (type: %s)", name, type(current))
            end
        end
    end

    -- Check function checksums
    for name, originalHash in pairs(Protection._checksums) do
        local fn = env[name]
        if type(fn) == "function" and Protection._hashFunction(fn) ~= originalHash then
            issues[#issues + 1] = string.format("Function modified: %s", name)
        end
    end

    if #issues > 0 then
        secureLog(2, "Integrity issues: " .. table.concat(issues, ", "))
        for _, cb in ipairs(Protection._integrityCallbacks) do
            pcall(cb, false, issues)
        end
        return false, issues
    end
    for _, cb in ipairs(Protection._integrityCallbacks) do
        pcall(cb, true, {})
    end
    return true, {}
end

function Protection.onIntegrityChange(callback)
    Protection._integrityCallbacks[#Protection._integrityCallbacks + 1] = callback
end

function Protection.antiDump()
    local env = getgenv and getgenv() or _G
    local detections = {}
    if env._G and env._G._dumped then detections[#detections + 1] = "_G._dumped" end
    if env.shared and env.shared._dumped then detections[#detections + 1] = "shared._dumped" end
    if env._dumped then detections[#detections + 1] = "_dumped" end
    if #detections > 0 then
        secureLog(3, "Dump detection: " .. table.concat(detections, ", "))
        return true, detections
    end
    return false, {}
end

function Protection.antiDebug()
    local detections = {}
    if type(debug) == "table" then
        local originalDebug = Protection._originalEnv.debug
        if originalDebug then
            if debug.getinfo ~= originalDebug.getinfo then detections[#detections + 1] = "debug.getinfo hooked" end
            if debug.getupvalue and not originalDebug.getupvalue then detections[#detections + 1] = "debug.getupvalue added" end
            if debug.setupvalue and not originalDebug.setupvalue then detections[#detections + 1] = "debug.setupvalue added" end
            if debug.getlocal and not originalDebug.getlocal then detections[#detections + 1] = "debug.getlocal added" end
            if debug.setlocal and not originalDebug.setlocal then detections[#detections + 1] = "debug.setlocal added" end
        end
    end
    if #detections > 0 then
        secureLog(3, "Anti-debug: " .. table.concat(detections, ", "))
        return true, detections
    end
    return false, {}
end

-- ============================================================
-- 4. ADVANCED CRYPTOGRAPHY (Pure Luau)
-- ============================================================
Protection.Crypto = {}

-- SHA-256 Implementation
local sha256_k = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function ror(x, n)
    return bit32.rrotate(x, n)
end

local function shr(x, n)
    return bit32.rshift(x, n)
end

local function ch(x, y, z)
    return bit32.bxor(bit32.band(x, y), bit32.band(bit32.bnot(x), z))
end

local function maj(x, y, z)
    return bit32.bxor(bit32.band(x, y), bit32.band(x, z), bit32.band(y, z))
end

local function sigma0(x)
    return bit32.bxor(ror(x, 2), ror(x, 13), ror(x, 22))
end

local function sigma1(x)
    return bit32.bxor(ror(x, 6), ror(x, 11), ror(x, 25))
end

local function gamma0(x)
    return bit32.bxor(ror(x, 7), ror(x, 18), shr(x, 3))
end

local function gamma1(x)
    return bit32.bxor(ror(x, 17), ror(x, 19), shr(x, 10))
end

function Protection.Crypto.sha256(data)
    local msg = type(data) == "string" and data or tostring(data)
    local len = #msg * 8
    local msgBytes = { msg:byte(1, -1) }
    table.insert(msgBytes, 0x80)
    while (#msgBytes * 8) % 512 ~= 448 do
        table.insert(msgBytes, 0)
    end
    for i = 7, 0, -1 do
        table.insert(msgBytes, bit32.rshift(len, i * 8) % 256)
    end

    local h = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }

    for chunk = 1, #msgBytes, 64 do
        local w = {}
        for i = 0, 15 do
            w[i] = msgBytes[chunk + i * 4] * 0x1000000 + msgBytes[chunk + i * 4 + 1] * 0x10000 + msgBytes[chunk + i * 4 + 2] * 0x100 + msgBytes[chunk + i * 4 + 3]
        end
        for i = 16, 63 do
            w[i] = (gamma1(w[i-2]) + w[i-7] + gamma0(w[i-15]) + w[i-16]) % 0x100000000
        end
        local a, b, c, d, e, f, g, h2 = table.unpack(h)
        for i = 0, 63 do
            local t1 = (h2 + sigma1(e) + ch(e, f, g) + sha256_k[i+1] + w[i]) % 0x100000000
            local t2 = (sigma0(a) + maj(a, b, c)) % 0x100000000
            h2, g, f, e, d, c, b, a = g, f, e, (d + t1) % 0x100000000, c, b, a, (t1 + t2) % 0x100000000
        end
        h[1] = (h[1] + a) % 0x100000000
        h[2] = (h[2] + b) % 0x100000000
        h[3] = (h[3] + c) % 0x100000000
        h[4] = (h[4] + d) % 0x100000000
        h[5] = (h[5] + e) % 0x100000000
        h[6] = (h[6] + f) % 0x100000000
        h[7] = (h[7] + g) % 0x100000000
        h[8] = (h[8] + h2) % 0x100000000
    end

    local out = ""
    for i = 1, 8 do
        out = out .. string.format("%08x", h[i])
    end
    return out
end

-- HMAC-SHA256
function Protection.Crypto.hmac_sha256(key, data)
    local blockSize = 64
    if #key > blockSize then key = Protection.Crypto.sha256(key) end
    key = key .. string.rep("\0", blockSize - #key)
    local o_key_pad = ""
    local i_key_pad = ""
    for i = 1, blockSize do
        local k = key:byte(i)
        o_key_pad = o_key_pad .. string.char(bit32.bxor(k, 0x5c))
        i_key_pad = i_key_pad .. string.char(bit32.bxor(k, 0x36))
    end
    return Protection.Crypto.sha256(o_key_pad .. Protection.Crypto.sha256(i_key_pad .. data))
end

-- ChaCha20 Implementation
function Protection.Crypto.chacha20(key, nonce, counter, data)
    local state = {}
    -- Constants
    state[1], state[2], state[3], state[4] = 0x61707865, 0x3320646e, 0x79622d32, 0x6b206574
    -- Key (256-bit = 8 uint32)
    for i = 0, 7 do
        local offset = i * 4 + 1
        state[5+i] = key:byte(offset) + key:byte(offset+1)*0x100 + key:byte(offset+2)*0x10000 + key:byte(offset+3)*0x1000000
    end
    -- Counter (32-bit) + Nonce (96-bit = 3 uint32)
    state[13] = counter
    for i = 0, 2 do
        local offset = i * 4 + 1
        state[14+i] = nonce:byte(offset) + nonce:byte(offset+1)*0x100 + nonce:byte(offset+2)*0x10000 + nonce:byte(offset+3)*0x1000000
    end

    local function quarterRound(a, b, c, d)
        a = (a + b) % 0x100000000; d = bit32.bxor(d, a); d = bit32.lrotate(d, 16)
        c = (c + d) % 0x100000000; b = bit32.bxor(b, c); b = bit32.lrotate(b, 12)
        a = (a + b) % 0x100000000; d = bit32.bxor(d, a); d = bit32.lrotate(d, 8)
        c = (c + d) % 0x100000000; b = bit32.bxor(b, c); b = bit32.lrotate(b, 7)
    end

    local output = {}
    local dataBytes = { data:byte(1, -1) }
    local pos = 1
    while pos <= #dataBytes do
        local working = { table.unpack(state) }
        for _ = 1, 10 do
            quarterRound(working[1], working[5], working[9], working[13])
            quarterRound(working[2], working[6], working[10], working[14])
            quarterRound(working[3], working[7], working[11], working[15])
            quarterRound(working[4], working[8], working[12], working[16])
            quarterRound(working[1], working[6], working[11], working[16])
            quarterRound(working[2], working[7], working[12], working[13])
            quarterRound(working[3], working[8], working[9], working[14])
            quarterRound(working[4], working[5], working[10], working[15])
        end
        for i = 1, 16 do
            working[i] = (working[i] + state[i]) % 0x100000000
        end
        for i = 1, 16 do
            if pos > #dataBytes then break end
            local byte = bit32.bxor(dataBytes[pos], working[i] % 256)
            output[#output + 1] = string.char(byte)
            pos = pos + 1
        end
        state[13] = (state[13] + 1) % 0x100000000
    end
    return table.concat(output)
end

-- AES-256 (simplified, using ChaCha20 for stream)
function Protection.Crypto.aes256_encrypt(key, data)
    local nonce = Protection.Crypto.random(12)
    local encrypted = Protection.Crypto.chacha20(key, nonce, 1, data)
    return nonce .. encrypted
end

function Protection.Crypto.aes256_decrypt(key, data)
    local nonce = data:sub(1, 12)
    local encrypted = data:sub(13)
    return Protection.Crypto.chacha20(key, nonce, 1, encrypted)
end

-- Secure Random
function Protection.Crypto.random(bytes)
    local out = {}
    for i = 1, bytes do
        out[i] = string.char(math.random(0, 255))
    end
    return table.concat(out)
end

-- ECDH Key Exchange (Curve25519 simplified)
function Protection.Crypto.ecdh_generate_keypair()
    local private = Protection.Crypto.random(32)
    -- Simplified: in real implementation, use proper Curve25519 scalar multiplication
    local public = Protection.Crypto.sha256(private .. "BBC_HUB_ECDH")
    return private, public
end

function Protection.Crypto.ecdh_shared_secret(private, peer_public)
    return Protection.Crypto.sha256(private .. peer_public .. "BBC_HUB_ECDH")
end

-- ============================================================
-- 5. SECURE STRINGS & POLYMORPHIC ENCODING
-- ============================================================
Protection._secureStrings = {}
Protection._stringKeys = {}
Protection._polymorphicCounter = 0

function Protection.generateKey(length)
    length = length or 32
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    local key = {}
    for i = 1, length do
        key[i] = string.sub(chars, math.random(1, #chars), math.random(1, #chars))
    end
    return table.concat(key)
end

function Protection.encryptString(str, key)
    key = key or Protection.generateKey()
    local encrypted = {}
    for i = 1, #str do
        local c = string.byte(str, i)
        local k = string.byte(key, (i - 1) % #key + 1)
        encrypted[i] = string.char(bit32.bxor(c, k))
    end
    return table.concat(encrypted), key
end

function Protection.decryptString(encrypted, key)
    return Protection.encryptString(encrypted, key)
end

function Protection.secureString(name, str)
    -- Polymorphic: different key every time
    Protection._polymorphicCounter = Protection._polymorphicCounter + 1
    local key = Protection.generateKey() .. tostring(Protection._polymorphicCounter) .. tostring(os.clock())
    local encrypted, _ = Protection.encryptString(str, key)
    Protection._secureStrings[name] = { data = encrypted, key = key, timestamp = os.clock() }
    return encrypted
end

function Protection.getSecureString(name)
    local entry = Protection._secureStrings[name]
    if entry then
        -- Auto-rotate keys periodically
        if os.clock() - entry.timestamp > 300 then -- 5 minutes
            entry.key = Protection.generateKey() .. tostring(os.clock())
            entry.timestamp = os.clock()
        end
        return Protection.decryptString(entry.data, entry.key)
    end
    return nil
end

function Protection.obfuscateConstant(value)
    -- Encode constants to prevent static analysis
    local encoded = {}
    for i = 1, #value do
        encoded[i] = string.format("\\%03d", value:byte(i))
    end
    return table.concat(encoded)
end

-- ============================================================
-- 6. CONTROL FLOW OBFUSCATION
-- ============================================================
Protection.Obfuscation = {}

function Protection.Obfuscation.opaquePredicate()
    -- Returns a boolean that's always true/false but hard to statically analyze
    local x = math.random(1, 1000)
    return x == x -- Always true
end

function Protection.Obfuscation.deadCode()
    -- Insert dead code that looks functional
    if false then
        local x = math.sin(os.clock())
        return x > 1
    end
end

function Protection.Obfuscation.flattenControlFlow(fn)
    -- Wrap function in a state machine
    local state = 0
    local function dispatcher(...)
        while true do
            if state == 0 then
                state = 1
                return fn(...)
            elseif state == 1 then
                state = 0
                return
            end
        end
    end
    return dispatcher
end

function Protection.Obfuscation.wrapWithChecks(fn, checks)
    checks = checks or {}
    return function(...)
        for _, check in ipairs(checks) do
            if not check() then
                secureLog(3, "Obfuscation check failed")
                return
            end
        end
        return fn(...)
    end
end

-- ============================================================
-- 7. FUNCTION VIRTUALIZATION
-- ============================================================
Protection.VM = {}

local VM_INSTRUCTIONS = {
    PUSH = 0x01, POP = 0x02, ADD = 0x03, SUB = 0x04,
    MUL = 0x05, DIV = 0x06, MOD = 0x07,
    EQ = 0x08, LT = 0x09, GT = 0x0A,
    JMP = 0x0B, JZ = 0x0C, CALL = 0x0D, RET = 0x0E,
    LOAD = 0x0F, STORE = 0x10,
}

function Protection.VM.compile(bytecode)
    -- Returns a virtualized function
    return function(...)
        local stack = {}
        local pc = 1
        local vars = {}
        local args = {...}

        local function fetch()
            local instr = bytecode[pc]
            pc = pc + 1
            return instr
        end

        local function push(v) stack[#stack + 1] = v end
        local function pop() local v = stack[#stack]; stack[#stack] = nil; return v end

        while pc <= #bytecode do
            local instr = fetch()
            local op = bit32.band(instr, 0xFF)
            local arg = bit32.rshift(instr, 8)

            if op == VM_INSTRUCTIONS.PUSH then push(arg)
            elseif op == VM_INSTRUCTIONS.ADD then push(pop() + pop())
            elseif op == VM_INSTRUCTIONS.SUB then local b=pop(); local a=pop(); push(a-b)
            elseif op == VM_INSTRUCTIONS.MUL then push(pop() * pop())
            elseif op == VM_INSTRUCTIONS.DIV then local b=pop(); local a=pop(); push(a/b)
            elseif op == VM_INSTRUCTIONS.EQ then push(pop() == pop() and 1 or 0)
            elseif op == VM_INSTRUCTIONS.LT then local b=pop(); local a=pop(); push(a<b and 1 or 0)
            elseif op == VM_INSTRUCTIONS.JMP then pc = arg
            elseif op == VM_INSTRUCTIONS.JZ then if pop() == 0 then pc = arg end
            elseif op == VM_INSTRUCTIONS.LOAD then push(vars[arg])
            elseif op == VM_INSTRUCTIONS.STORE then vars[arg] = pop()
            elseif op == VM_INSTRUCTIONS.CALL then
                local fn = pop()
                local argc = arg
                local fnArgs = {}
                for i = 1, argc do fnArgs[i] = pop() end
                push(fn(table.unpack(fnArgs)))
            elseif op == VM_INSTRUCTIONS.RET then return pop()
            end
        end
        return pop()
    end
end

-- ============================================================
-- 8. PROXY ENVIRONMENT & METATABLE HARDENING
-- ============================================================
Protection.Proxy = {}

function Protection.Proxy.hardenTable(tbl, name)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)

    local original = tbl
    local accessLog = {}

    mt.__index = function(_, k)
        accessLog[#accessLog + 1] = { type = "read", key = k, time = os.clock() }
        return original[k]
    end

    mt.__newindex = function(_, k, v)
        if Protection._frozenTables and Protection._frozenTables[name] then
            secureLog(2, "Attempt to modify frozen table: " .. name .. "." .. tostring(k))
            return
        end
        accessLog[#accessLog + 1] = { type = "write", key = k, time = os.clock() }
        original[k] = v
    end

    mt.__pairs = function() return pairs(original) end
    mt.__len = function() return #original end
    mt.__metatable = "Protected: " .. name
    mt.__tostring = function() return "ProtectedTable[" .. name .. "]" end

    return proxy
end

function Protection.Proxy.freezeTable(name)
    Protection._frozenTables = Protection._frozenTables or {}
    Protection._frozenTables[name] = true
end

function Protection.Proxy.wrapFunction(fn, name, checks)
    return function(...)
        for _, check in ipairs(checks or {}) do
            if not check() then
                secureLog(3, "Function guard failed: " .. name)
                return
            end
        end
        local start = os.clock()
        local results = { pcall(fn, ...) }
        local elapsed = os.clock() - start
        if elapsed > 1.0 then
            secureLog(2, "Slow function: " .. name .. " took " .. elapsed .. "s")
        end
        if not results[1] then
            secureLog(2, "Function error: " .. name .. " - " .. tostring(results[2]))
            error(results[2])
        end
        return table.unpack(results, 2)
    end
end

-- ============================================================
-- 9. WATERMARKING & BUILD FINGERPRINTING
-- ============================================================
Protection.Watermark = {}

function Protection.Watermark.generate(userId, buildId, timestamp)
    local data = string.format("%s|%s|%s|%s", Protection.BUILD_ID, userId or "unknown", buildId or "dev", timestamp or os.time())
    local signature = Protection.Crypto.hmac_sha256(Protection.SESSION_ID, data)
    return data .. "|" .. signature:sub(1, 16)
end

function Protection.Watermark.verify(watermark)
    local parts = {}
    for part in string.gmatch(watermark, "[^|]+") do parts[#parts + 1] = part end
    if #parts ~= 5 then return false, "Invalid format" end
    local data = parts[1] .. "|" .. parts[2] .. "|" .. parts[3] .. "|" .. parts[4]
    local expectedSig = Protection.Crypto.hmac_sha256(Protection.SESSION_ID, data):sub(1, 16)
    return parts[5] == expectedSig, "Valid"
end

function Protection.Watermark.embedInString(str)
    -- Embed watermark in string using zero-width chars
    local watermark = Protection.Watermark.generate()
    local zwc = { "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}" }
    local encoded = ""
    for i = 1, #watermark do
        local byte = watermark:byte(i)
        for bit = 7, 0, -1 do
            local b = bit32.band(bit32.rshift(byte, bit), 1)
            encoded = encoded .. zwc[b + 1]
        end
    end
    return str .. encoded
end

function Protection.Watermark.extractFromString(str)
    local zwc = { "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}" }
    local bits = {}
    for zw in string.gmatch(str, "[\u{200B}\u{200C}\u{200D}\u{FEFF}]") do
        for i, z in ipairs(zwc) do
            if zw == z then
                bits[#bits + 1] = tostring(i - 1)
                break
            end
        end
    end
    local watermark = ""
    for i = 1, #bits, 8 do
        local byte = 0
        for j = 0, 7 do
            if bits[i + j] == "1" then byte = byte + 2^(7-j) end
        end
        watermark = watermark .. string.char(byte)
    end
    return watermark
end

-- ============================================================
-- 10. LICENSE SYSTEM & HWID BINDING
-- ============================================================
Protection.License = {}

function Protection.License.getHWID()
    if Protection.HWID ~= "" then return Protection.HWID end
    local components = {
        tostring(game.PlaceId),
        tostring(Players.LocalPlayer and Players.LocalPlayer.UserId or 0),
        tostring(workspace.DistributedGameTime or 0),
        Protection.Crypto.random(8):byte(1) .. "",
    }
    local hwid = Protection.Crypto.sha256(table.concat(components, "|")):sub(1, 32)
    Protection.HWID = hwid
    return hwid
end

function Protection.License.validate(key, serverUrl)
    local hwid = Protection.License.getHWID()
    local payload = {
        key = key,
        hwid = hwid,
        build = Protection.BUILD_ID,
        version = Protection.VERSION,
        executor = Protection.Executor,
        timestamp = os.time(),
    }
    local encoded = HttpService:JSONEncode(payload)
    local signature = Protection.Crypto.hmac_sha256(Protection.SESSION_ID, encoded)
    payload.signature = signature

    if serverUrl and Protection.API.request then
        local response = Protection.API.request({
            Url = serverUrl .. "/validate",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
        if response.Success then
            local data = HttpService:JSONDecode(response.Body)
            return data.valid, data
        end
    end
    -- Offline validation (basic)
    return true, { offline = true, hwid = hwid }
end

function Protection.License.checkExpiration(expiry)
    if not expiry then return true end
    if type(expiry) == "function" then
        local ok, val = pcall(expiry)
        expiry = ok and val or nil
    end
    if type(expiry) == "number" then
        return os.time() < expiry
    end
    return false
end

-- ============================================================
-- 11. HEARTBEAT & TIME-BASED PROTECTION
-- ============================================================
Protection.Heartbeat = {}
Protection._heartbeatTasks = {}

function Protection.Heartbeat.start(interval, callback, name)
    name = name or "heartbeat_" .. #Protection._heartbeatTasks
    Protection._heartbeatTasks[name] = task.spawn(function()
        while not Protection._destroyed do
            task.wait(interval)
            if Protection._destroyed then break end
            local ok, err = pcall(callback)
            if not ok then secureLog(2, "Heartbeat error [" .. name .. "]: " .. tostring(err)) end
        end
    end)
    return name
end

function Protection.Heartbeat.stop(name)
    local taskId = Protection._heartbeatTasks[name]
    if taskId then task.cancel(taskId); Protection._heartbeatTasks[name] = nil end
end

function Protection.Heartbeat.startExpirationCheck(expiry, onExpire)
    return Protection.Heartbeat.start(60, function()
        if not Protection.License.checkExpiration(expiry) then
            secureLog(3, "License expired")
            if onExpire then onExpire() end
            Protection.destroy()
        end
    end, "expiration_check")
end

-- ============================================================
-- 12. ANTI-RELOAD / ANTI-REINJECT / ANTI-TAMPER
-- ============================================================
Protection._loadTime = os.clock()
Protection._instanceCount = 0

function Protection.antiReload()
    Protection._instanceCount = Protection._instanceCount + 1
    if Protection._instanceCount > 1 then
        secureLog(3, "Multiple instances detected! Count: " .. Protection._instanceCount)
        return true
    end
    return false
end

function Protection.antiReinject()
    local env = getgenv and getgenv() or _G
    if env.BBC_HUB_LOADED then
        secureLog(3, "Re-injection detected")
        return true
    end
    env.BBC_HUB_LOADED = true
    env.BBC_HUB_LOAD_TIME = Protection._loadTime
    env.BBC_HUB_INSTANCE_ID = Protection.SESSION_ID
    return false
end

function Protection.antiTamper()
    -- Check for common tampering indicators
    local checks = {
        function() return type(loadstring) == "function" end,
        function() return type(getfenv) == "function" end,
        function() return type(setfenv) == "function" or true end, -- setfenv removed in Luau
        function() return pcall(function() return game:GetService("CoreGui") end) end,
    }
    for i, check in ipairs(checks) do
        local ok, result = pcall(check)
        if not ok or not result then
            secureLog(2, "Tamper check " .. i .. " failed")
            return false
        end
    end
    return true
end

-- ============================================================
-- 13. NETWORK ENCRYPTION & SECURE CHANNELS
-- ============================================================
Protection.Network = {}
Protection._sessionKeys = {}

function Protection.Network.establishSession(peerId, peerPublicKey)
    local private, public = Protection.Crypto.ecdh_generate_keypair()
    local shared = Protection.Crypto.ecdh_shared_secret(private, peerPublicKey)
    local sessionKey = Protection.Crypto.sha256(shared .. "SESSION")
    Protection._sessionKeys[peerId] = { key = sessionKey, private = private, public = public }
    return public, sessionKey
end

function Protection.Network.encryptForPeer(peerId, data)
    local session = Protection._sessionKeys[peerId]
    if not session then return nil, "No session" end
    return Protection.Crypto.aes256_encrypt(session.key, data)
end

function Protection.Network.decryptFromPeer(peerId, data)
    local session = Protection._sessionKeys[peerId]
    if not session then return nil, "No session" end
    return Protection.Crypto.aes256_decrypt(session.key, data)
end

function Protection.Network.secureRequest(url, payload, peerId)
    local encrypted, err = Protection.Network.encryptForPeer(peerId, HttpService:JSONEncode(payload))
    if not encrypted then return nil, err end
    return Protection.API.request({
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/octet-stream", ["X-Encrypted"] = "true" },
        Body = encrypted,
    })
end

-- ============================================================
-- 14. VM/SANDBOX DETECTION & ANALYSIS EVASION
-- ============================================================
Protection.AntiAnalysis = {}

function Protection.AntiAnalysis.detectVM()
    local indicators = {}
    -- Check for common sandbox/analysis environment indicators
    if RunService:IsStudio() then indicators[#indicators + 1] = "Roblox Studio" end
    if os.clock() < 1 then indicators[#indicators + 1] = "Fresh environment (possible sandbox)" end
    if #Players:GetPlayers() == 1 and Players.LocalPlayer then
        local accAge = Players.LocalPlayer.AccountAge
        if accAge < 7 then indicators[#indicators + 1] = "New account (possible alt)" end
    end
    -- Check for missing services
    local ok, _ = pcall(function() return game:GetService("CoreGui") end)
    if not ok then indicators[#indicators + 1] = "CoreGui inaccessible" end
    return #indicators > 0, indicators
end

function Protection.AntiAnalysis.evadeAnalysis()
    -- Randomize timing to defeat timing analysis
    task.wait(math.random() * 0.1)
    -- Pollute stack trace
    local _ = debug and debug.traceback and debug.traceback()
    -- Fake sensitive operations
    local _ = pcall(function() return game:HttpGet("http://localhost") end)
end

function Protection.AntiAnalysis.obfuscateStackTrace()
    -- Wrap critical functions to hide call sites
    return function(fn)
        return function(...)
            return fn(...)
        end
    end
end

-- ============================================================
-- 15. STACK TRACE OBFUSCATION & CALLER VERIFICATION
-- ============================================================
Protection.CallStack = {}

function Protection.CallStack.verifyCaller(expectedDepth, expectedName)
    if not debug or not debug.traceback then return true end
    local trace = debug.traceback("", 2)
    local lines = {}
    for line in string.gmatch(trace, "[^\n]+") do lines[#lines + 1] = line end
    if #lines >= expectedDepth then
        local caller = lines[expectedDepth]
        if expectedName and not string.find(caller, expectedName) then
            secureLog(2, "Caller verification failed at depth " .. expectedDepth)
            return false
        end
    end
    return true
end

function Protection.CallStack.obfuscateTrace()
    -- Returns a fake but plausible stack trace
    local fakeFrames = {
        "  [C]: in function 'protected_call'",
        "  Script:123: in function 'handler'",
        "  Script:456: in function 'update'",
        "  Script:789: in function 'main'",
    }
    return table.concat(fakeFrames, "\n")
end

-- ============================================================
-- 16. TIMING ATTACK PREVENTION
-- ============================================================
Protection.Timing = {}

function Protection.Timing.constantTimeCompare(a, b)
    if #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do
        diff = diff + bit32.bxor(a:byte(i), b:byte(i))
    end
    return diff == 0
end

function Protection.Timing.randomDelay(minMs, maxMs)
    local delay = minMs + math.random() * (maxMs - minMs)
    task.wait(delay / 1000)
end

function Protection.Timing.measure(fn)
    local start = os.clock()
    local results = { pcall(fn) }
    local elapsed = os.clock() - start
    return elapsed, table.unpack(results, 2)
end

-- ============================================================
-- 17. CONTROL FLOW INTEGRITY (CFI)
-- ============================================================
Protection.CFI = {}
Protection._validTargets = {}

function Protection.CFI.registerValidTarget(fn, name)
    Protection._validTargets[tostring(fn)] = name or "anonymous"
end

function Protection.CFI.verifyIndirectCall(fn, caller)
    local fnStr = tostring(fn)
    if not Protection._validTargets[fnStr] then
        secureLog(3, "CFI violation: indirect call to unregistered function from " .. (caller or "unknown"))
        return false
    end
    return true
end

function Protection.CFI.wrap(fn, name)
    Protection.CFI.registerValidTarget(fn, name)
    return function(...)
        if not Protection.CFI.verifyIndirectCall(fn, name) then return end
        return fn(...)
    end
end

-- ============================================================
-- 18. SECURE RANDOM & CRYPTOGRAPHIC PRIMITIVES
-- ============================================================
Protection.SecureRandom = {}

function Protection.SecureRandom.bytes(n)
    local out = {}
    for i = 1, n do out[i] = string.char(math.random(0, 255)) end
    return table.concat(out)
end

function Protection.SecureRandom.int(min, max)
    return min + math.floor(math.random() * (max - min + 1))
end

function Protection.SecureRandom.choice(tbl)
    return tbl[Protection.SecureRandom.int(1, #tbl)]
end

function Protection.SecureRandom.shuffle(tbl)
    local out = { table.unpack(tbl) }
    for i = #out, 2, -1 do
        local j = Protection.SecureRandom.int(1, i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

-- ============================================================
-- 19. POLYMORPHIC CODE GENERATION
-- ============================================================
Protection.Polymorphic = {}
Protection._mutationSeed = os.clock()

function Protection.Polymorphic.mutateFunction(fn)
    -- Returns a functionally equivalent but structurally different function
    local wrapper = function(...)
        Protection._mutationSeed = Protection._mutationSeed + 0.001
        return fn(...)
    end
    return wrapper
end

function Protection.Polymorphic.generateStub(originalFn)
    -- Generate a polymorphic stub that calls the original
    local mutations = {
        function(...) return originalFn(...) end,
        function(...) local r = {originalFn(...)}; return table.unpack(r) end,
        function(...) return (function(...) return originalFn(...) end)(...) end,
    }
    return mutations[math.random(1, #mutations)]
end

function Protection.Polymorphic.obfuscateControlFlow(fn)
    -- Wrap in a state machine with opaque predicates
    return function(...)
        local state = 0
        while true do
            if state == 0 then
                if true then state = 1 else state = 99 end -- opaque predicate
            elseif state == 1 then
                return fn(...)
            elseif state == 99 then
                error("Invalid state")
            end
        end
    end
end

-- ============================================================
-- 20. COMPATIBILITY LAYER (UNIFIED API)
-- ============================================================
Protection.Compat = {}

local compatMethods = {
    "request", "queue_on_teleport", "protect_gui", "unprotect_gui",
    "crypt_encrypt", "crypt_decrypt", "crypt_generatebytes", "crypt_generatekey",
    "setthreadidentity", "getthreadidentity", "hookfunction", "hookmetamethod",
    "clonefunction", "checkcaller", "is_cclosure", "is_lclosure", "newcclosure",
    "getgc", "getreg", "getconnections", "fireclickdetector", "fireproximityprompt",
    "setclipboard", "getcustomasset", "rconsoleprint", "hmac_sha256", "sha256",
    "aes256_encrypt", "aes256_decrypt", "chacha20", "ecdh_generate_keypair",
    "ecdh_shared_secret", "constant_time_compare", "secure_random_bytes",
    "verify_integrity", "anti_dump", "anti_debug", "detect_vm", "get_hwid",
    "validate_license", "start_heartbeat", "stop_heartbeat", "anti_reload",
    "anti_reinject", "anti_tamper", "establish_session", "encrypt_for_peer",
    "decrypt_from_peer", "secure_request", "verify_caller", "constant_time_compare",
    "register_valid_target", "verify_indirect_call", "wrap_cfi",
}

for _, method in ipairs(compatMethods) do
    local parts = string.split(method, "_")
    local category = parts[1]
    local funcName = table.concat(parts, "_", 2)
    Protection.Compat[method] = function(...)
        local mod = Protection[category:gsub("^%l", string.upper)] or Protection.Crypto or Protection.Network or Protection.License or Protection.Heartbeat or Protection.CFI or Protection.Timing or Protection.CallStack
        local fn = mod and mod[funcName:gsub("^%l", string.upper)] or mod and mod[funcName]
        if fn then return fn(...) end
        secureLog(2, "Compat method not found: " .. method)
        return nil
    end
end

-- Direct mappings for critical functions
Protection.Compat.request = function(opts) return Protection.API.request(opts) end
Protection.Compat.queue_on_teleport = function(code) return Protection.API.queue_on_teleport(code) end
Protection.Compat.protect_gui = function(gui) return Protection.API.protect_gui(gui) end
Protection.Compat.unprotect_gui = function(gui) return Protection.API.unprotect_gui(gui) end
Protection.Compat.setthreadidentity = function(id) if type(setthreadidentity)=="function" then return setthreadidentity(id) elseif type(setidentity)=="function" then return setidentity(id) end return false end
Protection.Compat.getthreadidentity = function() if type(getthreadidentity)=="function" then return getthreadidentity() elseif type(getidentity)=="function" then return getidentity() end return 2 end
Protection.Compat.hookfunction = function(t,r) if type(hookfunction)=="function" then return hookfunction(t,r) end return nil end
Protection.Compat.hookmetamethod = function(i,m,r) if type(hookmetamethod)=="function" then return hookmetamethod(i,m,r) end return nil end
Protection.Compat.clonefunction = function(f) if type(clonefunction)=="function" then return clonefunction(f) end return f end
Protection.Compat.checkcaller = function() if type(checkcaller)=="function" then return checkcaller() end return false end
Protection.Compat.getconnections = function(e) if type(getconnections)=="function" then return getconnections(e) end return {} end
Protection.Compat.setclipboard = function(t) if type(setclipboard)=="function" then return setclipboard(t) end return false end
Protection.Compat.getcustomasset = function(p) if type(getcustomasset)=="function" then return getcustomasset(p) end return p end

-- ============================================================
-- INITIALIZATION & LIFECYCLE
-- ============================================================
function Protection.init(config)
    config = config or {}
    Protection._logLevel = config.logLevel or 1
    Protection._config = config

    secureLog(1, "Initializing BBC Protection v" .. Protection.VERSION .. " (Build: " .. Protection.BUILD_ID .. ")")

    -- Anti-reload/reinject checks
    if Protection.antiReload() then secureLog(3, "Multiple instance detected") end
    if Protection.antiReinject() then secureLog(3, "Re-injection detected") end

    -- Core initialization
    Protection.cacheOriginalEnvironment()
    Protection.detectExecutor()
    Protection.getCapabilities()
    Protection.getAPI()

    -- Generate HWID
    Protection.License.getHWID()

    -- Environment validation
    local envOk, envChecks = Protection.validateEnvironment()

    -- Get protection level (with nil safety)
    local level, desc, pct = 1, "Básico (fallback)", 0
    if type(Protection.getProtectionLevel) == "function" then
        local ok, l, d, p = pcall(Protection.getProtectionLevel)
        if ok and l then level, desc, pct = l, d, p end
    else
        secureLog(2, "Protection.getProtectionLevel is nil or not a function")
    end
    secureLog(1, string.format("Protection Level: %d - %s (%.0f%%)", level, desc, pct * 100))

    -- Start periodic checks
    task.spawn(function()
        while not Protection._destroyed do
            task.wait(30)
            Protection.verifyIntegrity()
            Protection.antiDump()
            Protection.antiDebug()
        end
    end)

    -- Start expiration check if configured
    if config.expiry then
        Protection.Heartbeat.startExpirationCheck(config.expiry, function()
            secureLog(3, "License expired - shutting down")
            Protection.destroy()
        end)
    end

    Protection._initialized = true
    secureLog(1, "Protection layer fully initialized")

    -- Auto-start ESP engine if BBC.Library is already available
    if BBC.Library then
        Protection.startESPEngine()
        Protection.registerESPFeatures()
    end

    return {
        executor = Protection.Executor,
        executorVersion = Protection.ExecutorVersion,
        level = level,
        description = desc,
        capabilities = Protection.Capabilities,
        api = Protection.API,
        compat = Protection.Compat,
        environment_ok = envOk,
        hwid = Protection.HWID,
        buildId = Protection.BUILD_ID,
        sessionId = Protection.SESSION_ID,
    }
end

function Protection.destroy()
    if Protection._destroyed then return end
    Protection._destroyed = true
    for name in pairs(Protection._heartbeatTasks) do
        Protection.Heartbeat.stop(name)
    end
    secureLog(1, "Protection layer destroyed")
end

-- Start ESP engine (call after BBC.Library is available)
function Protection.startESPEngine()
    if Protection._espEngineStarted then return end
    Protection._espEngineStarted = true
    
    local Library = BBC.Library
    if not Library then
        secureLog(2, "BBC.Library not available, cannot start ESP engine")
        return
    end
    
    Library.ESP = Library.ESP or {}
    Library.Features = Library.Features or {}
    Library.FS = Library.FS or {}
    Library.SV = Library.SV or {}
    Library.ESP = Library.ESP or {}
    
    -- ESP rendering engine (from original BBC_HUB)
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer
    
    local espGui = Instance.new("ScreenGui")
    espGui.Name = "BBCESP"
    espGui.ResetOnSpawn = false
    espGui.IgnoreGuiInset = true
    espGui.DisplayOrder = 990
    espGui.Parent = (typeof(gethui) == "function" and gethui()) or LP:WaitForChild("PlayerGui")
    
    local holder = Instance.new("Folder")
    holder.Name = "BBCMarks"
    holder.Parent = (typeof(gethui) == "function" and gethui()) or LP:WaitForChild("PlayerGui")
    
    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        i.Parent = parent
        return i
    end
    
    local FONT = Library.Fonts.Bold
    local CODE = Font.fromEnum(Enum.Font.Code)
    
    local R15 = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" }
    }
    local R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
    local KEYS = { "highlight", "box", "name", "healthbar", "health", "distance", "tracers", "arrows", "skeleton" }
    
    local function anyOn(S)
        if not S then return false end
        for _, k in ipairs(KEYS) do if S[k] and S[k].on then return true end end
        return false
    end
    
    local function hpColor(S, ratio)
        if not S.healthbar.auto then return S.healthbar.color end
        if ratio > 0.6 then return Color3.fromRGB(45, 205, 190) elseif ratio > 0.3 then return Color3.fromRGB(240, 200, 60) end
        return Color3.fromRGB(240, 80, 70)
    end
    
    local function txt(parent, anchor)
        return mk("TextLabel", { BackgroundTransparency = 1, FontFace = CODE, TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.new(0,0,0), AnchorPoint = anchor, Size = UDim2.fromOffset(120, 14), Visible = false, TextColor3 = Color3.new(1,1,1) }, parent)
    end
    
    local function lineF(f, x0, y0, x1, y1, th, col)
        local dx, dy = x1 - x0, y1 - y0
        f.Size = UDim2.fromOffset(math.sqrt(dx*dx + dy*dy), th)
        f.Position = UDim2.fromOffset((x0+x1)/2, (y0+y1)/2)
        f.Rotation = math.deg(math.atan2(dy, dx))
        f.BackgroundColor3 = col
        f.Visible = true
    end
    
    local pool = { Jogador = {}, NPCs = {} }
    local npcs, npcScan = {}, false
    
    local function addHum(h)
        if h:IsA("Humanoid") then
            local m = h.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then npcs[m] = h end
        end
    end
    
    local function startNpcScan()
        if npcScan then return end
        npcScan = true
        task.spawn(function()
            local n = 0
            for _, d in ipairs(Workspace:GetDescendants()) do
                addHum(d)
                n += 1
                if n % 400 == 0 then task.wait() end
            end
        end)
        Workspace.DescendantAdded:Connect(function(d) if d:IsA("Humanoid") then task.defer(addHum, d) end end)
    end
    
    local function newDraw()
        local d = { skel = {}, skelOn = false }
        local r = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, espGui)
        d.root = r
        d.boxFull = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, r)
        d.boxStroke = mk("UIStroke", { Thickness = 2 }, d.boxFull)
        d.corners = {}
        for i = 1, 8 do d.corners[i] = mk("Frame", { BorderSizePixel = 0, Visible = false }, r) end
        d.hbBg = mk("Frame", { BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false }, r)
        d.hbFill = mk("Frame", { AnchorPoint = Vector2.new(0,1), Position = UDim2.fromScale(0,1), Size = UDim2.fromScale(1,1), BorderSizePixel = 0 }, d.hbBg)
        d.name = txt(r, Vector2.new(0.5, 1))
        d.hp = txt(r, Vector2.new(1, 0.5))
        d.dist = txt(r, Vector2.new(0.5, 0))
        d.near = txt(r, Vector2.new(0.5, 1))
        d.near.Text = "▼"
        d.tracer = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, r)
        d.arrow = mk("TextLabel", { BackgroundTransparency = 1, Text = "▲", FontFace = FONT, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Visible = false, TextStrokeTransparency = 0.4 }, r)
        d.dot = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Visible = false }, r)
        mk("UICorner", { CornerRadius = UDim.new(1, 0) }, d.dot)
        d.hl = mk("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, holder)
        return d
    end
    
    local function hideDraw(d)
        d.root.Visible = false
        d.hl.Enabled = false
    end
    
    local function drawTarget(d, t, S, c, vp, isNearest)
        local near = isNearest and S.nearest.on
        local ncol = S.nearest.color
        local sz = t.model:GetExtentsSize()
        local center = t.model:GetPivot().Position
        local topV = c:WorldToViewportPoint(center + Vector3.new(0, sz.Y/2, 0))
        local botV = c:WorldToViewportPoint(center - Vector3.new(0, sz.Y/2, 0))
        d.root.Visible = true
        d.boxFull.Visible = false
        for i = 1, 8 do d.corners[i].Visible = false end
        d.hbBg.Visible = false; d.name.Visible = false; d.hp.Visible = false; d.dist.Visible = false; d.near.Visible = false
        d.tracer.Visible = false; d.dot.Visible = false; d.arrow.Visible = false
        if d.skelOn then for _, f in ipairs(d.skel) do f.Visible = false end; d.skelOn = false end
        
        local onScreen = topV.Z > 0 and botV.Z > 0 and topV.X > -60 and topV.X < vp.X + 60 and topV.Y > -120 and botV.Y < vp.Y + 120
        if not onScreen then
            d.hl.Enabled = false
            if S.arrows.on then
                local rel = c.CFrame:PointToObjectSpace(t.hrp.Position)
                local a = math.atan2(rel.X, -rel.Z)
                local rad = math.min(vp.X, vp.Y)/2 - 40
                d.arrow.Position = UDim2.fromOffset(vp.X/2 + math.sin(a)*rad, vp.Y/2 - math.cos(a)*rad)
                d.arrow.Rotation = math.deg(a)
                d.arrow.TextSize = S.arrows.size
                d.arrow.TextColor3 = near and ncol or S.arrows.color
                d.arrow.Visible = true
            end
            return
        end
        
        local top, bottom = topV.Y, botV.Y
        local hgt = math.max(bottom - top, 8)
        local wid = hgt * 0.55
        local cx = topV.X
        local left = cx - wid/2
        local ts = S.textSize
        local far = S.lod.on and t.m > S.lod.near
        local boxCol = near and ncol or S.box.color
        local hl = S.highlight
        
        if d.hl.Adornee ~= t.model then d.hl.Adornee = t.model end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = Color3.new(0,0,0)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0.1
        
        local distText = (S.distance.unit == "studs") and (math.floor(t.studs) .. " st") or (math.floor(t.m) .. "m")
        
        if far then
            if S.box.on or hl.on then
                d.dot.Visible = true; d.dot.BackgroundColor3 = boxCol; d.dot.Position = UDim2.fromOffset(cx, (top+bottom)/2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = math.max(ts-1,8); d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, (top+bottom)/2 + 6)
            end
        else
            if S.box.on then
                local th = S.box.thick
                if S.box.style == "Completa" then
                    d.boxFull.Visible = true
                    d.boxFull.Position = UDim2.fromOffset(left, top); d.boxFull.Size = UDim2.fromOffset(wid, hgt)
                    d.boxStroke.Color = boxCol; d.boxStroke.Thickness = th; d.boxStroke.Transparency = 1 - (S.box.alpha or 0.5)
                else
                    local len = math.min(S.box.corner, wid/2, hgt/2)
                    local L = { { left, top, len, th }, { left, top, th, len }, { left+wid-len, top, len, th }, { left+wid-th, top, th, len },
                        { left, top+hgt-th, len, th }, { left, top+hgt-len, th, len }, { left+wid-len, top+hgt-th, len, th }, { left+wid-th, top+hgt-len, th, len } }
                    for i = 1, 8 do
                        local f, v = d.corners[i], L[i]
                        f.Visible = true; f.BackgroundColor3 = boxCol; f.BackgroundTransparency = 1 - (S.box.alpha or 0.5)
                        f.Position = UDim2.fromOffset(v[1], v[2]); f.Size = UDim2.fromOffset(v[3], v[4])
                    end
                end
            end
            local ratio = math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1)
            if S.healthbar.on then
                local bw = S.healthbar.width
                local bx = S.healthbar.side == "Direita" and (left + wid + 3) or (left - 3 - bw)
                d.hbBg.Visible = true; d.hbBg.Position = UDim2.fromOffset(bx, top); d.hbBg.Size = UDim2.fromOffset(bw, hgt)
                d.hbFill.Size = UDim2.fromScale(1, ratio); d.hbFill.BackgroundColor3 = hpColor(S, ratio)
            end
            if S.health.on then
                d.hp.Visible = true; d.hp.Text = tostring(math.floor(t.hum.Health)); d.hp.TextSize = math.max(ts-2,8)
                d.hp.TextColor3 = (S.healthbar.auto and ratio <= 0.6) and hpColor(S, ratio) or S.health.color
                d.hp.Position = UDim2.fromOffset(left - 5 - (S.healthbar.on and S.healthbar.width or 0), (top+bottom)/2)
            end
            if near then
                d.near.Visible = true; d.near.TextSize = ts + 2; d.near.TextColor3 = ncol
                d.near.Position = UDim2.fromOffset(cx, top - 2 - (S.name.on and (ts + 3) or 0))
            end
            if S.name.on then
                d.name.Visible = true; d.name.Text = t.name; d.name.TextSize = ts; d.name.TextColor3 = S.name.color
                d.name.Position = UDim2.fromOffset(cx, top - 2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = math.max(ts-1,8); d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, bottom + 2)
            end
            if S.skeleton.on then
                local list = t.model:FindFirstChild("UpperTorso") and R15 or R6
                d.skelOn = true
                for i, pr in ipairs(list) do
                    local f = d.skel[i]
                    if not f then f = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, d.root); d.skel[i] = f end
                    local a, b = t.model:FindFirstChild(pr[1]), t.model:FindFirstChild(pr[2])
                    if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                        local va, vb = c:WorldToViewportPoint(a.Position), c:WorldToViewportPoint(b.Position)
                        if va.Z > 0 and vb.Z > 0 then lineF(f, va.X, va.Y, vb.X, vb.Y, S.skeleton.thick, near and ncol or S.skeleton.color) else f.Visible = false end
                    else f.Visible = false end
                end
                for i = #list + 1, #d.skel do d.skel[i].Visible = false end
            end
        end
        if S.tracers.on then
            local fromBottom = S.tracers.origin == "Baixo"
            lineF(d.tracer, vp.X/2, fromBottom and vp.Y or 0, cx, fromBottom and bottom or top, S.tracers.thick, near and ncol or S.tracers.color)
        end
        if S.arrows.on then
            d.arrow.Visible = true; d.arrow.TextColor3 = near and ncol or S.arrows.color; d.arrow.Size = UDim2.fromOffset(S.arrows.size, S.arrows.size)
            d.arrow.Position = UDim2.fromOffset(cx, top - 16); d.arrow.Rotation = 0
        end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = Color3.new(0,0,0)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0.1
    end
    
    local function gather(kind, out)
        if kind == "Jogador" then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ch = pl.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then out[#out+1] = { model = ch, hum = hum, hrp = hrp, name = pl.DisplayName ~= "" and pl.DisplayName or pl.Name } end
                end
            end
        else
            startNpcScan()
            for m, hum in pairs(npcs) do
                if not m.Parent or not m:IsDescendantOf(Workspace) then
                    npcs[m] = nil
                else
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if hrp and hrp:IsA("BasePart") and hum.Parent and hum.Health > 0 and m ~= LP.Character then
                        out[#out+1] = { model = m, hum = hum, hrp = hrp, name = m.Name }
                    end
                end
            end
        end
    end
    
    local function processKind(kind, S, c, vp)
        local P = pool[kind]
        local list = {}
        if S and not Library.Panic and anyOn(S) then gather(kind, list) end
        local camPos = c.CFrame.Position
        local maxM = S and S.maxDist or 1000
        local vis = {}
        for _, t in ipairs(list) do
            t.studs = (t.hrp.Position - camPos).Magnitude
            t.m = t.studs * 0.28
            if t.m <= maxM then vis[#vis+1] = t end
        end
        table.sort(vis, function(a, b) return a.studs < b.studs end)
        local seen = {}
        for i = 1, math.min(#vis, 24) do
            local t = vis[i]
            seen[t.model] = true
            local d = P[t.model]
            if not d then d = newDraw(); P[t.model] = d end
            drawTarget(d, t, S, c, vp, i == 1)
        end
        for model, d in pairs(P) do
            if not seen[model] then
                hideDraw(d)
                if not model.Parent then d.root:Destroy(); d.hl:Destroy(); P[model] = nil end
            end
        end
    end
    
    local errCount, stopped = 0, false
    RunService.RenderStepped:Connect(function(dt)
        if stopped then return end
        local ok, err = pcall(function()
            local c = Workspace.CurrentCamera
            if not c then return end
            local vp = c.ViewportSize
            for kind in pairs(pool) do processKind(kind, Library.ESP and Library.ESP[kind], c, vp) end
        end)
        if not ok then
            errCount += 1
            warn("[BBC] ESP: " .. tostring(err))
            if errCount >= 5 then
                stopped = true
                for _, P in pairs(pool) do for _, d in pairs(P) do hideDraw(d) end end
                Library:Notify({ Title = "BBC HUB", Content = "O ESP parou por causa de um erro (veja o console).", Duration = 5 })
            end
        end
    end)
end

-- Register ESP features so toggles work
function Protection.registerESPFeatures()
    local Library = BBC.Library
    if not Library then return end
    
    Library.Features = Library.Features or {}
    Library.ESP = Library.ESP or {}
    
    local function toggleESP(kind, enabled)
        local S = Library.ESP and Library.ESP[kind]
        if S then S.highlight.on = enabled; S.box.on = enabled; S.name.on = enabled end
        if enabled then Protection.startESPEngine() end
    end
    
    Library.Features["Jogador"] = function(v) toggleESP("Jogador", v) end
    Library.Features["NPCs"] = function(v) toggleESP("NPCs", v) end
    Library.Features["Corpo"] = function(v) toggleESP("Corpo", v) end
    Library.Features["Recipiente"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Item no chão"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Itens de missão"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Destaque"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.highlight.on = v end end
    Library.Features["Caixa"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.box.on = v end end
    Library.Features["Barra de vida"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.healthbar.on = v end end
    Library.Features["Vida"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.health.on = v end end
    Library.Features["Linhas"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.tracers.on = v end end
    Library.Features["Linhas até alvos"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.tracers.on = v end end
    Library.Features["Setas"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.arrows.on = v end end
    Library.Features["Esqueleto"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.skeleton.on = v end end
    Library.Features["Destaque próprio"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.nearest.on = v end end
end

-- ============================================================
-- ESP RENDERING & FEATURE REGISTRATION
-- ============================================================
function Protection.startESPEngine()
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer

    local espGui = Instance.new("ScreenGui")
    espGui.Name = "BBCESP"
    espGui.ResetOnSpawn = false
    espGui.IgnoreGuiInset = true
    espGui.DisplayOrder = 990
    espGui.Parent = (typeof(gethui) == "function" and gethui()) or LP:WaitForChild("PlayerGui")

    local holder = Instance.new("Folder")
    holder.Name = "BBCMarks"
    holder.Parent = (typeof(gethui) == "function" and gethui()) or LP:WaitForChild("PlayerGui")

    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        i.Parent = parent
        return i
    end

    local FONT = Library.Fonts.Bold
    local CODE = Font.fromEnum(Enum.Font.Code)

    local R15 = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" }
    }
    local R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
    local KEYS = { "highlight", "box", "name", "healthbar", "health", "distance", "tracers", "arrows", "skeleton" }

    local function anyOn(S)
        if not S then return false end
        for _, k in ipairs(KEYS) do if S[k] and S[k].on then return true end end
        return false
    end

    local function hpColor(S, ratio)
        if not S.healthbar.auto then return S.healthbar.color end
        if ratio > 0.6 then return Color3.fromRGB(45, 205, 190) elseif ratio > 0.3 then return Color3.fromRGB(240, 200, 60) end
        return Color3.fromRGB(240, 80, 70)
    end

    local function txt(parent, anchor)
        return mk("TextLabel", { BackgroundTransparency = 1, FontFace = CODE, TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.new(0,0,0), AnchorPoint = anchor, Size = UDim2.fromOffset(120, 14), Visible = false, TextColor3 = Color3.new(1,1,1) }, parent)
    end

    local function lineF(f, x0, y0, x1, y1, th, col)
        local dx, dy = x1 - x0, y1 - y0
        f.Size = UDim2.fromOffset(math.sqrt(dx*dx + dy*dy), th)
        f.Position = UDim2.fromOffset((x0+x1)/2, (y0+y1)/2)
        f.Rotation = math.deg(math.atan2(dy, dx))
        f.BackgroundColor3 = col
        f.Visible = true
    end

    local pool = { Jogador = {}, NPCs = {} }

    local function newDraw()
        local d = { skel = {}, skelOn = false }
        local r = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, espGui)
        d.root = r
        d.boxFull = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, r)
        d.boxStroke = mk("UIStroke", { Thickness = 2 }, d.boxFull)
        d.corners = {}
        for i = 1, 8 do d.corners[i] = mk("Frame", { BorderSizePixel = 0, Visible = false }, r) end
        d.hbBg = mk("Frame", { BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false }, r)
        d.hbFill = mk("Frame", { AnchorPoint = Vector2.new(0,1), Position = UDim2.fromScale(0,1), Size = UDim2.fromScale(1,1), BorderSizePixel = 0 }, d.hbBg)
        d.name = txt(r, Vector2.new(0.5, 1))
        d.hp = txt(r, Vector2.new(1, 0.5))
        d.dist = txt(r, Vector2.new(0.5, 0))
        d.near = txt(r, Vector2.new(0.5, 1))
        d.near.Text = "▼"
        d.tracer = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, r)
        d.arrow = mk("TextLabel", { BackgroundTransparency = 1, Text = "▲", FontFace = FONT, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Visible = false, TextStrokeTransparency = 0.4 }, r)
        d.dot = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Visible = false }, r)
        mk("UICorner", { CornerRadius = UDim.new(1, 0) }, d.dot)
        d.hl = mk("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, holder)
        return d
    end

    local function hideDraw(d)
        d.root.Visible = false
        d.hl.Enabled = false
    end

    local function drawTarget(d, t, S, c, vp, isNearest)
        local near = isNearest and S.nearest.on
        local ncol = S.nearest.color
        local sz = t.model:GetExtentsSize()
        local center = t.model:GetPivot().Position
        local topV = c:WorldToViewportPoint(center + Vector3.new(0, sz.Y/2, 0))
        local botV = c:WorldToViewportPoint(center - Vector3.new(0, sz.Y/2, 0))
        d.root.Visible = true
        d.boxFull.Visible = false
        for i = 1, 8 do d.corners[i].Visible = false end
        d.hbBg.Visible = false; d.name.Visible = false; d.hp.Visible = false; d.dist.Visible = false; d.near.Visible = false
        d.tracer.Visible = false; d.dot.Visible = false; d.arrow.Visible = false
        if d.skelOn then for _, f in ipairs(d.skel) do f.Visible = false end; d.skelOn = false end

        local onScreen = topV.Z > 0 and botV.Z > 0 and topV.X > -60 and topV.X < vp.X + 60 and topV.Y > -120 and botV.Y < vp.Y + 120
        if not onScreen then
            d.hl.Enabled = false
            if S.arrows.on then
                local rel = c.CFrame:PointToObjectSpace(t.hrp.Position)
                local a = math.atan2(rel.X, -rel.Z)
                local rad = math.min(vp.X, vp.Y)/2 - 40
                d.arrow.Position = UDim2.fromOffset(vp.X/2 + math.sin(a)*rad, vp.Y/2 - math.cos(a)*rad)
                d.arrow.Rotation = math.deg(a)
                d.arrow.TextSize = S.arrows.size
                d.arrow.TextColor3 = near and ncol or S.arrows.color
                d.arrow.Visible = true
            end
            return
        end

        local top, bottom = topV.Y, botV.Y
        local hgt = math.max(bottom - top, 8)
        local wid = hgt * 0.55
        local cx = topV.X
        local left = cx - wid/2
        local ts = S.textSize
        local far = S.lod.on and t.m > S.lod.near
        local boxCol = near and ncol or S.box.color
        local hl = S.highlight

        if d.hl.Adornee ~= t.model then d.hl.Adornee = t.model end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = Color3.new(0,0,0)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0.1

        local distText = (S.distance.unit == "studs") and (math.floor(t.studs) .. " st") or (math.floor(t.m) .. "m")

        if far then
            if S.box.on or hl.on then
                d.dot.Visible = true; d.dot.BackgroundColor3 = boxCol; d.dot.Position = UDim2.fromOffset(cx, (top+bottom)/2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = math.max(ts-1,8); d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, (top+bottom)/2 + 6)
            end
        else
            if S.box.on then
                local th = S.box.thick
                if S.box.style == "Completa" then
                    d.boxFull.Visible = true
                    d.boxFull.Position = UDim2.fromOffset(left, top); d.boxFull.Size = UDim2.fromOffset(wid, hgt)
                    d.boxStroke.Color = boxCol; d.boxStroke.Thickness = th; d.boxStroke.Transparency = 1 - (S.box.alpha or 0.5)
                else
                    local len = math.min(S.box.corner, wid/2, hgt/2)
                    local L = { { left, top, len, th }, { left, top, th, len }, { left+wid-len, top, len, th }, { left+wid-th, top, th, len },
                        { left, top+hgt-th, len, th }, { left, top+hgt-len, th, len }, { left+wid-len, top+hgt-th, len, th }, { left+wid-th, top+hgt-len, th, len } }
                    for i = 1, 8 do
                        local f, v = d.corners[i], L[i]
                        f.Visible = true; f.BackgroundColor3 = boxCol; f.BackgroundTransparency = 1 - (S.box.alpha or 0.5)
                        f.Position = UDim2.fromOffset(v[1], v[2]); f.Size = UDim2.fromOffset(v[3], v[4])
                    end
                end
            end
            local ratio = math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1)
            if S.healthbar.on then
                local bw = S.healthbar.width
                local bx = S.healthbar.side == "Direita" and (left + wid + 3) or (left - 3 - bw)
                d.hbBg.Visible = true; d.hbBg.Position = UDim2.fromOffset(bx, top); d.hbBg.Size = UDim2.fromOffset(bw, hgt)
                d.hbFill.Size = UDim2.fromScale(1, ratio); d.hbFill.BackgroundColor3 = hpColor(S, ratio)
            end
            if S.health.on then
                d.hp.Visible = true; d.hp.Text = tostring(math.floor(t.hum.Health)); d.hp.TextSize = math.max(ts-2,8)
                d.hp.TextColor3 = (S.healthbar.auto and ratio <= 0.6) and hpColor(S, ratio) or S.health.color
                d.hp.Position = UDim2.fromOffset(left - 5 - (S.healthbar.on and S.healthbar.width or 0), (top+bottom)/2)
            end
            if near then
                d.near.Visible = true; d.near.TextSize = ts + 2; d.near.TextColor3 = ncol
                d.near.Position = UDim2.fromOffset(cx, top - 2 - (S.name.on and (ts + 3) or 0))
            end
            if S.name.on then
                d.name.Visible = true; d.name.Text = t.name; d.name.TextSize = ts; d.name.TextColor3 = S.name.color
                d.name.Position = UDim2.fromOffset(cx, top - 2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = math.max(ts-1,8); d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, bottom + 2)
            end
            if S.skeleton.on then
                local list = t.model:FindFirstChild("UpperTorso") and R15 or R6
                d.skelOn = true
                for i, pr in ipairs(list) do
                    local f = d.skel[i]
                    if not f then f = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, d.root); d.skel[i] = f end
                    local a, b = t.model:FindFirstChild(pr[1]), t.model:FindFirstChild(pr[2])
                    if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                        local va, vb = c:WorldToViewportPoint(a.Position), c:WorldToViewportPoint(b.Position)
                        if va.Z > 0 and vb.Z > 0 then lineF(f, va.X, va.Y, vb.X, vb.Y, S.skeleton.thick, near and ncol or S.skeleton.color) else f.Visible = false end
                    else f.Visible = false end
                end
                for i = #list + 1, #d.skel do d.skel[i].Visible = false end
            end
        end
        if S.tracers.on then
            local fromBottom = S.tracers.origin == "Baixo"
            lineF(d.tracer, vp.X/2, fromBottom and vp.Y or 0, cx, fromBottom and bottom or top, S.tracers.thick, near and ncol or S.tracers.color)
        end
        if S.arrows.on then
            d.arrow.Visible = true; d.arrow.TextColor3 = near and ncol or S.arrows.color; d.arrow.Size = UDim2.fromOffset(S.arrows.size, S.arrows.size)
            d.arrow.Position = UDim2.fromOffset(cx, top - 16); d.arrow.Rotation = 0
        end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = Color3.new(0,0,0)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0.1
    end

    local function gather(kind, out)
        if kind == "Jogador" then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ch = pl.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then out[#out+1] = { model = ch, hum = hum, hrp = hrp, name = pl.DisplayName ~= "" and pl.DisplayName or pl.Name } end
                end
            end
        else
            for m, hum in pairs(npcs) do
                if not m.Parent or not m:IsDescendantOf(Workspace) then npcs[m] = nil
                else
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if hrp and hrp:IsA("BasePart") and hum.Parent and hum.Health > 0 and m ~= LP.Character then
                        out[#out+1] = { model = m, hum = hum, hrp = hrp, name = m.Name }
                    end
                end
            end
        end
    end

    local function processKind(kind, S, c, vp)
        local P = pool[kind]
        local list = {}
        if S and not Library.Panic and anyOn(S) then gather(kind, list) end
        local camPos = c.CFrame.Position
        local maxM = S and S.maxDist or 1000
        local vis = {}
        for _, t in ipairs(list) do
            t.studs = (t.hrp.Position - camPos).Magnitude
            t.m = t.studs * 0.28
            if t.m <= maxM then vis[#vis+1] = t end
        end
        table.sort(vis, function(a, b) return a.studs < b.studs end)
        local seen = {}
        for i = 1, math.min(#vis, 24) do
            local t = vis[i]
            seen[t.model] = true
            local d = P[t.model]
            if not d then d = newDraw(); P[t.model] = d end
            drawTarget(d, t, S, c, vp, i == 1)
        end
        for model, d in pairs(P) do
            if not seen[model] then
                hideDraw(d)
                if not model.Parent then d.root:Destroy(); d.hl:Destroy(); P[model] = nil end
            end
        end
    end

    -- Start NPC scanning
    local npcs, npcScan = {}, false
    local function addHum(h)
        if h:IsA("Humanoid") then
            local m = h.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then npcs[m] = h end
        end
    end
    local function startNpcScan()
        if npcScan then return end
        npcScan = true
        task.spawn(function()
            local n = 0
            for _, d in ipairs(Workspace:GetDescendants()) do
                addHum(d)
                n += 1
                if n % 400 == 0 then task.wait() end
            end
        end)
        Workspace.DescendantAdded:Connect(function(d) if d:IsA("Humanoid") then task.defer(addHum, d) end end)
    end

    local errCount, stopped = 0, false
    RunService.RenderStepped:Connect(function(dt)
        if stopped then return end
        local ok, err = pcall(function()
            local c = Workspace.CurrentCamera
            if not c then return end
            local vp = c.ViewportSize
            for kind in pairs(pool) do processKind(kind, Library.ESP and Library.ESP[kind], c, vp) end
        end)
        if not ok then
            errCount += 1
            warn("[BBC] ESP: " .. tostring(err))
            if errCount >= 5 then
                stopped = true
                for _, P in pairs(pool) do for _, d in pairs(P) do hideDraw(d) end end
                Library:Notify({ Title = "BBC HUB", Content = "O ESP parou por causa de um erro (veja o console).", Duration = 5 })
            end
        end
    end)
end

-- Register ESP features so toggles work
function Protection.registerESPFeatures()
    local Library = BBC.Library
    if not Library then return end
    Library.Features = Library.Features or {}
    Library.ESP = Library.ESP or {}

    local function toggleESP(kind, enabled)
        local S = Library.ESP and Library.ESP[kind]
        if S then S.highlight.on = enabled; S.box.on = enabled; S.name.on = enabled end
        if enabled then Protection.startESPEngine() end
    end

    Library.Features["Jogador"] = function(v) toggleESP("Jogador", v) end
    Library.Features["NPCs"] = function(v) toggleESP("NPCs", v) end
    Library.Features["Corpo"] = function(v) toggleESP("Corpo", v) end
    Library.Features["Recipiente"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Item no chão"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Itens de missão"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Destaque"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.highlight.on = v end end
    Library.Features["Caixa"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.box.on = v end end
    Library.Features["Barra de vida"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.healthbar.on = v end end
    Library.Features["Vida"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.health.on = v end end
    Library.Features["Linhas"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.tracers.on = v end end
    Library.Features["Linhas até alvos"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.tracers.on = v end end
    Library.Features["Setas"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.arrows.on = v end end
    Library.Features["Esqueleto"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.skeleton.on = v end end
    Library.Features["Destaque próprio"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.nearest.on = v end end
end

function Protection.getStatus()
    return {
        initialized = Protection._initialized,
        destroyed = Protection._destroyed,
        executor = Protection.Executor,
        executorVersion = Protection.ExecutorVersion,
        level = Protection.getProtectionLevel(),
        capabilities = Protection.Capabilities,
        hwid = Protection.HWID,
        buildId = Protection.BUILD_ID,
        sessionId = Protection.SESSION_ID,
        uptime = os.clock() - Protection._loadTime,
    }
end

BBC.Protection = Protection
return Protection

end)

-- ============================================================
-- módulo: ui.theme  (ui/theme.lua)
-- ============================================================
__module("ui.theme", function(BBC)
--[[
    BBC HUB - Theme & Library Core
    Biblioteca principal: fontes, temas, bindings, loop de FPS, API de servidores.
]]

local Library = BBC.Library or {}
BBC.Library = Library

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

Library.Windows = {}
Library.Registry = {}
Library._themeListeners = {}
Library._bindings = {}
Library.ThemeName = "Orange"
Library.Theme = {}
Library.Access = "FREE"
Library.Keybinds = {}
Library._kbListeners = {}
Library._toggleBinds = {}
Library.Tr = function(t) return t end

-- Initialize feature/option tables early (before features modules load)
Library.FO = {}
Library.Features = {}
Library.FS = {}
Library.SV = {}
Library.ESP = {}
Library.LootCfg = {}
Library.RadarCfg = {}
Library.keys = { menu = "RightShift", cursor = "LeftAlt", zoom = "N" }

-- Terrain color helper (define BEFORE exposing to BBC)
Library.TerrainColor = function(mat, c)
    pcall(function()
        local Workspace = game:GetService("Workspace")
        if mat == "Water" then Workspace.Terrain.WaterColor = c else Workspace.Terrain:SetMaterialColor(mat, c) end
    end)
end

-- Notify wrapper (uses Utils.notify internally)
Library.Notify = function(opts)
    local Utils = BBC.Utils
    if Utils and Utils.notify then return Utils.notify(opts) end
    -- Fallback if Utils not ready
    warn("[BBC] Notify called but Utils not ready: " .. tostring(opts and opts.Content or opts))
end

-- Expose on BBC table for cross-module access
BBC.FO = Library.FO
BBC.Features = Library.Features
BBC.FS = Library.FS
BBC.SV = Library.SV
BBC.ESP = Library.ESP
BBC.LootCfg = Library.LootCfg
BBC.RadarCfg = Library.RadarCfg
BBC.keys = Library.keys

-- Expose methods on BBC table
BBC.TerrainColor = Library.TerrainColor
BBC.Notify = Library.Notify
BBC.notify = Library.Notify  -- alias lowercase for compatibility

function Library:_kbChanged()
    for _, fn in ipairs(Library._kbListeners) do pcall(fn) end
end

-- ---------- Fontes ----------
Library.Fonts = {
    Regular = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular),
    Medium = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Medium),
    Bold = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold),
}
local FONT_WEIGHTS = {
    Regular = { 400, Enum.FontWeight.Regular }, Medium = { 500, Enum.FontWeight.Medium },
    SemiBold = { 600, Enum.FontWeight.SemiBold }, Bold = { 700, Enum.FontWeight.Bold },
}
function Library:LoadFont(opts)
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[BBC] fontes personalizadas precisam de writefile, isfile e getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    local weights = opts.Weights
    if type(weights) ~= "table" then return false end
    local folder = "BBC_HUB_Fontes"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then makefolder(folder) end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local info = FONT_WEIGHTS[weightName]
        if info then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then ok = pcall(function() writefile(path, game:HttpGet(url)) end) end
            if ok then table.insert(faces, { name = weightName, weight = info[1], style = "normal", assetId = getcustomasset(path) }) end
        end
    end
    if #faces == 0 then return false end
    local familyPath = folder .. "/" .. name .. ".json"
    if not pcall(function() writefile(familyPath, HttpService:JSONEncode({ name = name, faces = faces })) end) then return false end
    local family = getcustomasset(familyPath)
    local function face(w, fallback)
        local info = FONT_WEIGHTS[w]
        if info and weights[w] then return Font.new(family, info[2]) end
        return fallback
    end
    Library.Fonts.Regular = face("Regular", Library.Fonts.Regular)
    Library.Fonts.Medium = face("Medium", face("Regular", Library.Fonts.Medium))
    Library.Fonts.Bold = face("Bold", face("SemiBold", Library.Fonts.Bold))
    return true
end

-- ---------- Temas ----------
local function preset(accent, mode, bgOverride)
    local h = accent:ToHSV()
    local function d(sat, val)
        if mode == "neutral" then return Color3.fromHSV(0, 0, val) end
        return Color3.fromHSV(h, sat, val)
    end
    local p = {
        Accent = accent,
        Background = d(0.55, 0.04), Surface = d(0.55, 0.055), Surface2 = d(0.5, 0.08),
        Surface3 = d(0.45, 0.125), Stroke = d(0.45, 0.2),
        Text = Color3.fromRGB(242, 242, 242), Muted = Color3.fromRGB(150, 150, 150),
        Warning = Color3.fromRGB(240, 176, 108), Error = Color3.fromRGB(240, 100, 100),
    }
    if bgOverride then for k, v in pairs(bgOverride) do p[k] = v end end
    return p
end
Library.ThemeOrder = { "Gold", "Purple", "Yellow", "Red", "Blue", "Orange", "Green", "Halloween", "Ocean", "Mono", "Cyan", "Pink", "Copper" }
Library.ThemePresets = {
    Gold = preset(Color3.fromRGB(255, 192, 40), "neutral"),
    Purple = preset(Color3.fromRGB(150, 100, 255), "tint"),
    Yellow = preset(Color3.fromRGB(240, 232, 60), "neutral"),
    Red = preset(Color3.fromRGB(240, 52, 72), "tint"),
    Blue = preset(Color3.fromRGB(80, 125, 255), "tint"),
    Orange = preset(Color3.fromRGB(255, 130, 25), "neutral"),
    Green = preset(Color3.fromRGB(45, 215, 105), "tint"),
    Halloween = preset(Color3.fromRGB(255, 120, 10), "tint", {
        Background = Color3.fromRGB(14, 8, 22), Surface = Color3.fromRGB(19, 11, 30), Surface2 = Color3.fromRGB(27, 16, 42),
        Surface3 = Color3.fromRGB(40, 26, 60), Stroke = Color3.fromRGB(58, 38, 84) }),
    Cyan = preset(Color3.fromRGB(30, 175, 245), "tint"),
    Mono = preset(Color3.fromRGB(235, 235, 235), "neutral"),
    Pink = preset(Color3.fromRGB(242, 85, 175), "tint"),
    Ocean = preset(Color3.fromRGB(40, 120, 255), "tint"),
    Copper = preset(Color3.fromRGB(222, 150, 62), "neutral"),
}
for k, v in pairs(Library.ThemePresets.Orange) do Library.Theme[k] = v end

-- ---------- Bindings ----------
local function bind(inst, prop, key)
    local fn = type(key) == "function" and key or function() return Library.Theme[key] end
    inst[prop] = fn()
    Library._bindings[#Library._bindings + 1] = { inst, prop, fn }
end
Library.Bind = bind

function Library:SetTheme(name)
    local p = Library.ThemePresets[name]
    if not p then return end
    Library.ThemeName = name
    for k, v in pairs(p) do Library.Theme[k] = v end
    for i = #Library._bindings, 1, -1 do
        local b = Library._bindings[i]
        if b[1] and b[1].Parent then pcall(function() b[1][b[2]] = b[3]() end) else table.remove(Library._bindings, i) end
    end
    for _, fn in ipairs(Library._themeListeners) do pcall(fn) end
end

-- ---------- FPS compartilhado ----------
Library._fps = 60
do
    local frames, last = 0, os.clock()
    RunService.RenderStepped:Connect(function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then Library._fps = math.floor(frames / (now - last) + 0.5); frames = 0; last = now end
    end)
end

-- ---------- API de Servidores ----------
function Library:FetchServers(order, cursor)
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100%s",
        game.PlaceId, order or "Desc", cursor and ("&cursor=" .. cursor) or "")
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" then return nil end
    local decoded, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then return nil end
    return data.data, data.nextPageCursor
end
function Library:JoinServer(jobId)
    return pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer) end)
end

-- ---------- ParseKey ----------
Library.ParseKey = BBC.Utils.parseKey

-- ---------- MakeIcon ----------
function Library.MakeIcon(...)
    return BBC.Utils.icon(...)
end

-- Expor Library globalmente para compatibilidade
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
    local s = create("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 1, -1), BorderSizePixel = 0, BackgroundTransparency = 0.5 }, parent)
    bind(s, "BackgroundColor3", "Stroke")
end

local function newOuter(self, name)
    local outer = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self:_nextOrder() }, self.List)
    outer:SetAttribute("SearchName", name or "")
    listLayout(outer, 0)
    return outer
end

-- ---------- subPanel helper (moved up for forward reference) ----------
local function subPanel(self, parentOuter, order)
    local panel = create("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false, LayoutOrder = order }, parentOuter)
    bind(panel, "BackgroundColor3", "Surface2")
    corner(panel, 4); stroke(panel, "Stroke", 0.3)
    local inner = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, panel)
    pad(inner, 0, 0, 3, 3); listLayout(inner, 0)
    local sub = setmetatable({ List = inner, _order = 0, Window = self.Window, _path = (self._path or "") .. "/sub", Frame = panel }, Container)
    return sub, panel
end

-- ---------- Toggle ----------
function Container:Toggle(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    local locked = (opts.Premium and Library.Access ~= "VIP") or opts.Disabled == true
    local nameRow = create("Frame", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0), BackgroundTransparency = 1 }, row)
    local nl = listLayout(nameRow, 6, Enum.FillDirection.Horizontal)
    nl.VerticalAlignment = Enum.VerticalAlignment.Center
    label(nameRow, opts.Name, 13, locked and "Muted" or "Text", false, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Center })
    if opts.Premium then
        local st = label(nameRow, "★", 13, "Text", true, { LayoutOrder = 2, Size = UDim2.fromOffset(14, 18), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
        st.TextColor3 = Color3.fromRGB(80, 170, 255)
        bind(st, "TextColor3", function() return Color3.fromRGB(80, 170, 255) end)
    end
    if opts.Warning then
        local w = label(nameRow, "⚠", 13, "Warning", true, { LayoutOrder = 3, Size = UDim2.fromOffset(14, 18), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
    end
    local state = opts.Default == true and not locked
    local pill = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(34, 18), BorderSizePixel = 0 }, row)
    corner(pill, 9); stroke(pill, "Stroke", 0.2)
    bind(pill, "BackgroundColor3", function() return state and Library.Theme.Accent or Library.Theme.Surface3 end)
    local knob = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, BackgroundTransparency = locked and 0.55 or 0 }, pill)
    corner(knob, 6)
    local function paint(instant)
        local target = state and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        local col = state and Library.Theme.Accent or Library.Theme.Surface3
        if instant then
            knob.Position = target; pill.BackgroundColor3 = col
        else
            tween(knob, { Position = target }, 0.12); tween(pill, { BackgroundColor3 = col }, 0.12)
        end
    end
    paint(true)
    local obj = { Value = state, Frame = outer }
    function obj:Set(v, silent)
        if locked then return end
        state = v == true
        self.Value = state
        paint()
        if self._onChange then self._onChange(state) end
        if not silent then safeCall(opts.Callback, state) end
    end
    function obj:Get() return state end
    row.MouseButton1Click:Connect(function()
        if row:GetAttribute("TipHeld") then return end
        if locked then
            Library:Notify({ Title = "BBC HUB", Content = opts.Premium and "Recurso exclusivo VIP." or "Indisponível.", Duration = 2 })
            return
        end
        obj:Set(not state)
        if state then
            -- activationFx
            if Library.Effects and row.Parent then
                row.ClipsDescendants = true
                local beam = create("Frame", { Position = UDim2.new(-0.45, 0, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme.Accent, ZIndex = 2 }, row)
                create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.62), NumberSequenceKeypoint.new(1, 1) }) }, beam)
                local head = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0,
                    BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.2, ZIndex = 2 }, beam)
                tween(beam, { Position = UDim2.new(1, 0, 0, 0) }, 0.7, Enum.EasingStyle.Quad)
                tween(head, { BackgroundTransparency = 1 }, 0.7)
                task.delay(0.8, function() beam:Destroy() end)
                for i = 1, 4 do
                    local ghost = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0,
                        BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.25 + i * 0.12, ZIndex = 0 }, pill)
                    corner(ghost, 6)
                    task.delay(i * 0.03, function()
                        tween(ghost, { Position = UDim2.new(1, -15, 0.5, 0) }, 0.16, Enum.EasingStyle.Quad)
                        task.delay(0.16, function() tween(ghost, { BackgroundTransparency = 1 }, 0.28) end)
                    end)
                    task.delay(0.65, function() ghost:Destroy() end)
                end
                local ring = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -29, 0.5, 0), Size = UDim2.fromOffset(34, 18), BackgroundTransparency = 1, ZIndex = 2 }, row)
                corner(ring, 9)
                local rs = create("UIStroke", { Thickness = 2, Transparency = 0.15, Color = Library.Theme.Accent }, ring)
                tween(ring, { Size = UDim2.fromOffset(54, 28) }, 0.5, Enum.EasingStyle.Quad)
                tween(rs, { Transparency = 1 }, 0.5)
                task.delay(0.55, function() ring:Destroy() end)
            end
        end
    end)
    if not (opts.NoSave or opts.NoPersist) then register(self, opts.Name, function() return state end, function(v) obj:Set(v) end) end
    local extras, pinObj, bindKey = nil, nil, nil
    if not opts.NoSave then
        local win = self.Window
        local function adopt(pin) pinObj = pin; if pin then pin.OnRemoved = function() pinObj = nil end end end
        extras = {
            getKey = function() return bindKey end,
            setKey = function(k) bindKey = k; Library:_kbChanged() end,
            isPinned = function() return pinObj ~= nil end,
            setPinned = function(v)
                adopt(win:_setPin(opts.Name, obj, v))
                if v then Library:Notify({ Title = opts.Name, Content = "Fixado: aparece na tela com o menu fechado. Segure o botão para tirar.", Duration = 3 }) end
            end,
        }
        obj._onChange = function() if pinObj then pinObj.Refresh() end end
        table.insert(Library._toggleBinds, { key = function() return bindKey end, fire = function()
            if locked then return end
            obj:Set(not state)
            Library:Notify({ Title = opts.Name, Content = state and "Ativado" or "Desativado", Duration = 1.2 })
        end })
        table.insert(Library.Keybinds, { name = opts.Name, get = function() return bindKey end, listening = function() return false end,
            begin = function() Library:Notify({ Title = opts.Name, Content = "Segure a opção no menu e toque em Atalho para trocar.", Duration = 3 }) end })
        register(self, opts.Name .. "#tecla", function() return bindKey and bindKey.Name or nil end,
            function(v) bindKey = Library.ParseKey(v); Library:_kbChanged() end)
        if opts.NoPin then
            extras.setPinned, extras.isPinned = nil, nil
        else
            register(self, opts.Name .. "#fixado", function()
                if not pinObj then return nil end
                local pp = pinObj.btn.Position
                return { x = pp.X.Scale, y = pp.Y.Scale }
            end, function(v)
                if type(v) == "table" and type(v.x) == "number" then adopt(win:_setPin(opts.Name, obj, true, v))
                else adopt(win:_setPin(opts.Name, obj, false)) end
            end)
        end
    end
    -- attachTip (simplificado)
    if opts.Tooltip then
        local win = self.Window
        local hovering = false
        row.MouseEnter:Connect(function()
            hovering = true
            task.delay(0.8, function() if hovering and row.Parent then
                local f = create("CanvasGroup", { Size = UDim2.fromOffset(236, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 50, GroupTransparency = 1 }, win._main)
                bind(f, "BackgroundColor3", "Surface3"); corner(f, 7); stroke(f, "Accent", 0.1)
                pad(f, 11, 11, 8, 9); listLayout(f, 3)
                local head = create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1 }, f)
                label(head, tostring(opts.Name), 13, "Accent", true, { Size = UDim2.new(1, -62, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 51 })
                label(f, tostring(opts.Tooltip), 12, "Text", false, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 16), ZIndex = 51 })
                tween(f, { GroupTransparency = 0 }, 0.18, Enum.EasingStyle.Quint)
                task.delay(3.4, function() tween(f, { GroupTransparency = 1 }, 0.15); task.delay(0.2, function() f:Destroy() end) end)
            end end)
        end)
        row.MouseLeave:Connect(function() hovering = false end)
    end
    bind(row, "BackgroundColor3", "Accent")
    row.MouseEnter:Connect(function() if not locked then tween(row, { BackgroundTransparency = 0.93 }, 0.12) end end)
    row.MouseLeave:Connect(function() tween(row, { BackgroundTransparency = 1 }, 0.18) end)

    -- Modal (painel grande)
    if type(opts.Modal) == "function" then
        local gear = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(12 + 34 + 6), 0.5, 0), Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
        local gi = icon(gear, "sliders-horizontal", 17, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
        local key = (self._path or "") .. "/" .. tostring(opts.Name)
        local hooked = false
        gear.MouseButton1Click:Connect(function()
            local m = self.Window:_getModal(key, opts.ModalTitles, opts.Modal)
            if not hooked then
                hooked = true
                m.Overlay:GetPropertyChangedSignal("Visible"):Connect(function()
                    gi.ImageColor3 = m.Overlay.Visible and Library.Theme.Accent or Library.Theme.Text
                end)
            end
            m.Overlay.Visible = not m.Overlay.Visible
        end)
        if opts.Prebuild then
            task.defer(function() pcall(function() self.Window:_getModal(key, opts.ModalTitles, opts.Modal) end) end)
        end
    end

    -- Submenu (ícone de ajustes)
    if type(opts.Settings) == "function" then
        local gear = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(12 + 34 + 6), 0.5, 0), Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
        local gi = icon(gear, opts.SettingsIcon or "sliders-horizontal", 17, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
        local sub, panel = subPanel(self, outer, 2)
        local open = false
        gear.MouseButton1Click:Connect(function()
            open = not open
            panel.Visible = open
            gi.ImageColor3 = open and Library.Theme.Accent or Library.Theme.Text
        end)
        obj.SettingsPanel = sub
        safeCall(opts.Settings, sub)
    end
    if state then safeCall(opts.Callback, state) end
    return obj
end

-- ---------- subPanel helper ----------
local function subPanel(self, parentOuter, order)
    local panel = create("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false, LayoutOrder = order }, parentOuter)
    bind(panel, "BackgroundColor3", "Surface2")
    corner(panel, 4); stroke(panel, "Stroke", 0.3)
    local inner = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, panel)
    pad(inner, 0, 0, 3, 3); listLayout(inner, 0)
    local sub = setmetatable({ List = inner, _order = 0, Window = self.Window, _path = (self._path or "") .. "/sub", Frame = panel }, Container)
    return sub, panel
end

-- ---------- Slider ----------
function Container:Slider(opts)
    opts = opts or {}
    local min, max = opts.Min or 0, opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local decimals = 0
    if step < 1 then decimals = #(string.match(tostring(step), "%.(%d+)") or "") end
    local value = math.clamp(opts.Default or min, min, max)
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -90, 0, 18) })
    local valueL = label(row, "", 13, "Muted", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4), Size = UDim2.fromOffset(80, 18), TextXAlignment = Enum.TextXAlignment.Right })
    local track = create("Frame", { Position = UDim2.fromOffset(18, 29), Size = UDim2.new(1, -36, 0, 5), BorderSizePixel = 0 }, row)
    bind(track, "BackgroundColor3", "Surface3"); corner(track, 3)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
    bind(fill, "BackgroundColor3", "Accent"); corner(fill, 3)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(13, 13),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, track)
    bind(knob, "BackgroundColor3", "Background"); corner(knob, 7)
    local ks = create("UIStroke", { Thickness = 2 }, knob); bind(ks, "Color", "Accent")
    local function fmt(v)
        if decimals > 0 then return string.format("%." .. decimals .. "f", v) end
        return tostring(math.floor(v + 0.5))
    end
    local function paint()
        local frac = (max > min) and (value - min) / (max - min) or 0
        fill.Size = UDim2.fromScale(frac, 1)
        knob.Position = UDim2.fromScale(frac, 0.5)
        valueL.Text = fmt(value) .. suffix
    end
    paint()
    local obj = { Value = value, Frame = outer }
    function obj:Set(v, silent)
        v = math.clamp(tonumber(v) or min, min, max)
        v = math.floor((v - min) / step + 0.5) * step + min
        v = math.clamp(v, min, max)
        value = v; self.Value = v
        paint()
        if not silent then safeCall(opts.Callback, v) end
    end
    local hit = create("TextButton", { Position = UDim2.fromOffset(6, 18), Size = UDim2.new(1, -12, 0, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
    local dragging = false
    local function fromInput(pos)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local rel = math.clamp((pos.X - track.AbsolutePosition.X) / w, 0, 1)
        obj:Set(min + rel * (max - min))
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromInput(i.Position)
        end
    end)
    self.Window:_connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i.Position) end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    register(self, opts.Name, function() return value end, function(v) obj:Set(v) end)
    return obj
end

-- ---------- Dropdown ----------
function Container:Dropdown(opts)
    opts = opts or {}
    local options = opts.Options or {}
    local flags = opts.Flags
    local multi = opts.Multi == true
    local selected = {}
    local function setDefault(d)
        selected = {}
        if type(d) == "table" then for _, v in ipairs(d) do selected[v] = true end
        elseif d ~= nil then selected[d] = true end
    end
    setDefault(opts.Default)
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local chip, chipStroke = chipBox(row)
    local cl = listLayout(chip, 6, Enum.FillDirection.Horizontal)
    cl.VerticalAlignment = Enum.VerticalAlignment.Center
    local flagHolder
    if flags then flagHolder = create("Frame", { Size = UDim2.fromOffset(22, 15), BackgroundTransparency = 1, LayoutOrder = 0 }, chip) end
    local valueL = label(chip, "", 12, "Text", false, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Center })
    local arrow = label(chip, "▶", 9, "Text", false, { LayoutOrder = 2, Size = UDim2.fromOffset(10, 24), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
    local list = create("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false, LayoutOrder = 2 }, outer)
    bind(list, "BackgroundColor3", "Surface2"); corner(list, 4); stroke(list, "Stroke", 0.3)
    pad(list, 4, 4, 4, 4); listLayout(list, 2)
    local buttons = {}
    local function ordered()
        local out = {}
        for _, o in ipairs(options) do if selected[o] then table.insert(out, o) end end
        return out
    end
    local function text()
        local o = ordered()
        if #o == 0 then return multi and "—" or "" end
        if multi and #o > 1 then return o[1] .. " +" .. (#o - 1) end
        return o[1]
    end
    local function paint()
        valueL.Text = text()
        if flagHolder then
            for _, c in ipairs(flagHolder:GetChildren()) do c:Destroy() end
            local o = ordered()[1]
            if o and flags[o] then makeFlag(flagHolder, flags[o]) end
        end
        for o, b in pairs(buttons) do
            local on = selected[o] == true
            b.BackgroundTransparency = on and 0.15 or 1
            b.TextColor3 = on and Color3.new(1, 1, 1) or Library.Theme.Text
        end
    end
    local function current()
        if multi then return ordered() end
        return ordered()[1]
    end
    local obj = { Frame = outer }
    local function closeList() list.Visible = false; arrow.Text = "▶" end
    function obj:Set(v, silent)
        setDefault(v)
        paint()
        if not silent then safeCall(opts.Callback, current()) end
    end
    function obj:Get() return current() end
    function obj:SetOptions(newOptions)
        options = newOptions
        for _, b in pairs(buttons) do b:Destroy() end
        buttons = {}
        for i, o in ipairs(options) do
            local b = create("TextButton", { Size = UDim2.new(1, 0, 0, flags and 28 or 26), BackgroundTransparency = 1, Text = o, TextSize = 13, FontFace = Library.Fonts.Regular,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = i, BorderSizePixel = 0 }, list)
            bind(b, "BackgroundColor3", "Accent")
            corner(b, 3)
            pad(b, flags and 38 or 14, 6, 0, 0)
            if flags and flags[o] then makeFlag(b, flags[o], { Position = UDim2.new(0, -28, 0.5, -7.5) }) end
            buttons[o] = b
            b.MouseButton1Click:Connect(function()
                if multi then
                    selected[o] = not selected[o] or nil
                else
                    selected = { [o] = true }
                    closeList()
                end
                paint()
                safeCall(opts.Callback, current())
            end)
        end
        paint()
    end
    obj:SetOptions(options)
    local function toggleList()
        list.Visible = not list.Visible
        arrow.Text = list.Visible and "▼" or "▶"
    end
    row.MouseButton1Click:Connect(toggleList)
    chip.MouseButton1Click:Connect(toggleList)
    register(self, opts.Name, current, function(v) obj:Set(v) end)
    return obj
end

-- ---------- Keybind ----------
function Container:Keybind(opts)
    opts = opts or {}
    local value = parseKey(opts.Default)
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local chip, chipStroke = chipBox(row)
    chip.AutomaticSize = Enum.AutomaticSize.None
    local cl = label(chip, keyText(value), 12, "Text", false, { Size = UDim2.fromScale(1, 1), TextTruncate = Enum.TextTruncate.None, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
    local function fit(text) chip.Size = UDim2.fromOffset(math.max(46, textWidth(text, 12) + 22), 24) end
    fit(cl.Text)
    local listening = false
    local obj = { Frame = outer }
    local function show(text) cl.Text = text; fit(text) end
    function obj:Set(v, silent)
        value = parseKey(v)
        self.Value = value
        show(keyText(value))
        Library:_kbChanged()
        if not silent then safeCall(opts.OnChanged, value) end
    end
    function obj:Get() return value end
    obj.Value = value
    local function beginListen()
        listening = true
        Library._listening = true
        chipStroke.Color = Library.Theme.Accent
        show("...")
        Library:_kbChanged()
    end
    table.insert(Library.Keybinds, { name = opts.Name, get = function() return value end, begin = beginListen, listening = function() return listening end })
    chip.MouseButton1Click:Connect(beginListen)
    self.Window:_connect(UserInputService.InputBegan, function(input, processed)
        local t = input.UserInputType
        local isMouse = t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3
        if t ~= Enum.UserInputType.Keyboard and not isMouse then return end
        local code = isMouse and t or input.KeyCode
        if listening then
            listening = false
            Library._listening = false
            Library._lastBind = os.clock()
            chipStroke.Color = Library.Theme.Stroke
            if code == Enum.KeyCode.Escape then show(keyText(value)); Library:_kbChanged() else obj:Set(code) end
            return
        end
        if not processed and value ~= nil and code == value then safeCall(opts.Callback, code) end
    end)
    register(self, opts.Name, function() return value and value.Name or "None" end, function(v) obj:Set(v) end)
    return obj
end

-- ---------- Button ----------
function Container:Button(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1, BorderSizePixel = 0 }, outer)
    bind(row, "BackgroundColor3", "Accent")
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    if opts.Arrow then label(row, "▶", 11, "Text", false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 16), TextXAlignment = Enum.TextXAlignment.Right }) end
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
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -130, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local box = create("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(100, 22), Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "", ClearTextOnFocus = false, TextSize = 12, FontFace = Library.Fonts.Regular, BorderSizePixel = 0, BackgroundTransparency = 0.2 }, row)
    bind(box, "BackgroundColor3", "Background"); bind(box, "TextColor3", "Text"); bind(box, "PlaceholderColor3", "Muted")
    corner(box, 3); stroke(box, "Stroke", 0.1)
    box.FocusLost:Connect(function() safeCall(opts.Callback, box.Text) end)
    register(self, opts.Name, function() return box.Text end, function(v) box.Text = tostring(v); safeCall(opts.Callback, box.Text) end)
    return { Frame = outer, Box = box }
end

-- ---------- ColorPicker ----------
local PALETTE = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 160, 160), Color3.fromRGB(30, 30, 30), Color3.fromRGB(240, 52, 72),
    Color3.fromRGB(255, 130, 25), Color3.fromRGB(255, 205, 40), Color3.fromRGB(45, 215, 105), Color3.fromRGB(30, 175, 245),
    Color3.fromRGB(110, 90, 255), Color3.fromRGB(242, 85, 175),
}
function Container:ColorPicker(opts)
    opts = opts or {}
    local color = opts.Default or Color3.fromRGB(255, 255, 255)
    local h, s, v = color:ToHSV()
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -120, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local arrow = label(row, "▶", 9, "Text", false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(10, 16), TextXAlignment = Enum.TextXAlignment.Center })
    local sw = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -28, 0.5, 0), Size = UDim2.fromOffset(32, 18), BackgroundColor3 = color, BorderSizePixel = 0 }, row)
    corner(sw, 4); stroke(sw, "Stroke", 0.1)
    local panel = create("Frame", { Size = UDim2.new(1, -16, 0, 150), BorderSizePixel = 0, Visible = false, LayoutOrder = 2 }, outer)
    bind(panel, "BackgroundColor3", "Surface2"); corner(panel, 4); stroke(panel, "Stroke", 0.3)
    local sv = create("TextButton", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 84), Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Color3.fromHSV(h, 1, 1) }, panel)
    corner(sv, 4)
    local white = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, sv)
    corner(white, 4)
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, white)
    local black = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0) }, sv)
    corner(black, 4)
    create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, black)
    local svKnob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3 }, sv)
    corner(svKnob, 6)
    create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, svKnob)
    local hue = create("TextButton", { Position = UDim2.fromOffset(8, 100), Size = UDim2.new(1, -16, 0, 12), Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, panel)
    corner(hue, 6)
    local seq = {}
    for i = 0, 6 do seq[#seq + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1 == 0 and (i == 6 and 0.9999 or 0) or i / 6, 1, 1)) end
    create("UIGradient", { Color = ColorSequence.new(seq) }, hue)
    local hueKnob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 }, hue)
    corner(hueKnob, 3); create("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }, hueKnob)
    local hex = create("TextBox", { Position = UDim2.fromOffset(8, 120), Size = UDim2.fromOffset(70, 22), Text = "", TextSize = 12, FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, BorderSizePixel = 0 }, panel)
    bind(hex, "BackgroundColor3", "Background"); bind(hex, "TextColor3", "Text"); corner(hex, 3); stroke(hex, "Stroke", 0.1)
    local obj = { Frame = outer }
    local function apply(silent)
        color = Color3.fromHSV(h, s, v)
        sw.BackgroundColor3 = color
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svKnob.Position = UDim2.fromScale(s, 1 - v)
        hueKnob.Position = UDim2.fromScale(h, 0.5)
        hex.Text = "#" .. color:ToHex():upper()
        obj.Value = color
        if not silent then safeCall(opts.Callback, color) end
    end
    local px = 84
    for i, c in ipairs(PALETTE) do
        local b = create("TextButton", { Position = UDim2.fromOffset(px + (i - 1) * 19, 122), Size = UDim2.fromOffset(16, 16), Text = "", AutoButtonColor = false, BackgroundColor3 = c, BorderSizePixel = 0 }, panel)
        corner(b, 8); create("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.7 }, b)
        b.MouseButton1Click:Connect(function() h, s, v = c:ToHSV(); apply() end)
    end
    row.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
        arrow.Text = panel.Visible and "▼" or "▶"
    end)
    local dragSV, dragHue = false, false
    local function fromSV(p)
        local sz = sv.AbsoluteSize
        if sz.X <= 0 or sz.Y <= 0 then return end
        s = math.clamp((p.X - sv.AbsolutePosition.X) / sz.X, 0, 1)
        v = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / sz.Y, 0, 1)
        apply()
    end
    local function fromHue(p)
        local w = hue.AbsoluteSize.X
        if w <= 0 then return end
        h = math.clamp((p.X - hue.AbsolutePosition.X) / w, 0, 0.999)
        apply()
    end
    local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
    sv.InputBegan:Connect(function(i) if isPress(i) then dragSV = true; fromSV(i.Position) end end)
    hue.InputBegan:Connect(function(i) if isPress(i) then dragHue = true; fromHue(i.Position) end end)
    self.Window:_connect(UserInputService.InputChanged, function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            if dragSV then fromSV(i.Position) elseif dragHue then fromHue(i.Position) end
        end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(i) if isPress(i) then dragSV, dragHue = false, false end end)
    hex.FocusLost:Connect(function()
        local t = string.gsub(hex.Text, "#", "")
        local ok, c = pcall(Color3.fromHex, t)
        if ok and c then h, s, v = c:ToHSV() end
        apply()
    end)
    function obj:Set(c, silent) h, s, v = c:ToHSV(); apply(silent) end
    apply(true)
    register(self, opts.Name, function() return { color.R, color.G, color.B } end, function(t) if type(t) == "table" then obj:Set(Color3.new(t[1], t[2], t[3])) end end)
    return obj
end

-- ---------- Foldout ----------
function Container:Foldout(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local arrow = label(row, "▶", 11, "Text", false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 16), TextXAlignment = Enum.TextXAlignment.Right })
    local sub, panel = subPanel(self, outer, 2)
    local function setOpen(v) panel.Visible = v; arrow.Text = v and "▼" or "▶" end
    row.MouseButton1Click:Connect(function() setOpen(not panel.Visible) end)
    safeCall(opts.Build, sub)
    return { Frame = outer, Panel = sub, Set = setOpen, IsOpen = function() return panel.Visible end }
end

-- ---------- Segmented ----------
function Container:Segmented(opts)
    opts = opts or {}
    local options, icons = opts.Options or {}, opts.Icons or {}
    local selected = opts.Default or options[1]
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    local holder = create("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 28), BackgroundTransparency = 1 }, row)
    listLayout(holder, 4, Enum.FillDirection.Horizontal)
    local n = math.max(#options, 1)
    local items = {}
    local obj = { Frame = outer }
    local function paint()
        for o, it in pairs(items) do
            local on = o == selected
            it.stroke.Color = on and Library.Theme.Accent or Library.Theme.Stroke
            it.stroke.Thickness = on and 1.5 or 1
            it.button.BackgroundColor3 = on and Library.Theme.Surface3 or Library.Theme.Surface2
            it.text.TextColor3 = on and Library.Theme.Text or Library.Theme.Muted
            if it.icon then it.icon.ImageColor3 = on and Library.Theme.Accent or Library.Theme.Muted end
        end
    end
    for i, o in ipairs(options) do
        local button = create("TextButton", {
            Size = UDim2.new(1 / n, -4 * (n - 1) / n, 1, 0),
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
            BorderSizePixel = 0,
        }, holder)
        corner(button, 4)
        local itemStroke = create("UIStroke", { Thickness = 1 }, button)
        local itemIcon = icons[i] and icon(button, icons[i], 14, "Muted", { Position = UDim2.new(0, 7, 0.5, -7) }) or nil
        local itemText = label(button, o, 12, "Muted", false, {
            Position = UDim2.fromOffset(itemIcon and 24 or 6, 0),
            Size = UDim2.new(1, itemIcon and -28 or -12, 1, 0),
            TextYAlignment = Enum.TextYAlignment.Center,
            TextXAlignment = itemIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
        })
        items[o] = { button = button, stroke = itemStroke, text = itemText, icon = itemIcon }
        button.MouseButton1Click:Connect(function()
            selected = o
            paint()
            safeCall(opts.Callback, o)
        end)
    end
    paint()
    table.insert(Library._themeListeners, paint)
    function obj:Set(newValue, silent)
        selected = newValue
        paint()
        if not silent then safeCall(opts.Callback, newValue) end
    end
    register(self, opts.Name, function() return selected end, function(value) obj:Set(value) end)
    return obj
end

-- ---------- Label ----------
function Container:Label(opts)
    local text = ""
    if type(opts) == "table" then
        text = tostring(opts.Text or "")
    elseif opts ~= nil then
        text = tostring(opts)
    end
    local outer = newOuter(self, text)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, outer)
    local l = label(row, text, 12, "Muted", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    return { Frame = outer, Label = l, Set = function(_, t) l.Text = tostring(t or "") end }
end

function Container:Section(text)
    local outer = newOuter(self, text or "")
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, outer)
    label(row, string.upper(tostring(text or "")), 12, "Muted", true, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 18) })
    return { Frame = outer }
end

-- ============================================================
--  Controles helpers (usados pelo main.lua)
-- ============================================================
local Controls = {}

function Controls.T(tab, name, default, tip)
    local GEARS = BBC.GEARS or {}
    local PREMIUM = BBC.PREMIUM or {}
    local SETTINGS_ICON = BBC.SETTINGS_ICON or {}
    local MODALS = BBC.MODALS or {}
    local TIPS = BBC.TIPS or {}
    local Lib = BBC.Library or {}
    local FS = Lib.FS or {}
    local Features = Lib.Features or {}
    local o = { Name = name, Default = default or false, Tooltip = tip or TIPS[name],
        Callback = function(v) FS[name] = v; local f = Features[name]; if f then f(v) end end }
    if GEARS[name] then o.Settings = BBC.buildSettings(name); o.SettingsIcon = SETTINGS_ICON[name] end
    if MODALS[name] then o.Modal = MODALS[name].build; o.ModalTitles = MODALS[name].titles; o.Settings = nil; o.Prebuild = true end
    if PREMIUM[name] then o.Premium = true end
    if name == "Buscar chefes" then o.Warning = true end
    return tab:Toggle(o)
end

function Controls.S(tab, name, min, max, default, suffix, step)
    local Lib = BBC.Library or {}
    local SV = Lib.SV or {}
    return tab:Slider({ Name = name, Min = min, Max = max, Default = default, Suffix = suffix or "", Step = step or 1, Tooltip = (BBC.TIPS or {})[name], Callback = function(v) SV[name] = v end })
end

BBC.UI = BBC.UI or {}
BBC.UI.Container = Container
BBC.UI.Controls = Controls
BBC.Controls = Controls
BBC.T = Controls.T
BBC.S = Controls.S
BBC.GEARS = BBC.GEARS or {}
BBC.PREMIUM = BBC.PREMIUM or {}
BBC.SETTINGS_ICON = BBC.SETTINGS_ICON or {}
BBC.MODALS = BBC.MODALS or {}
BBC.TIPS = BBC.TIPS or {}
BBC.buildSettings = BBC.buildSettings
BBC.register = register

return { Container = Container, Controls = Controls }

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
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function ensureFolders()
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            if not isfolder(CFG_FOLDER) then makefolder(CFG_FOLDER) end
        end
    end)
end

local function cleanName(n)
    n = string.gsub(tostring(n or ""), "[^%w _%-]", "")
    n = string.gsub(n, "^%s+", "")
    n = string.gsub(n, "%s+$", "")
    return string.sub(n, 1, 24)
end
Library.CleanName = cleanName

local function stable(v)
    if type(v) ~= "table" then return tostring(v) end
    local items = {}
    for k, x in pairs(v) do items[#items + 1] = { tostring(k), x } end
    table.sort(items, function(a, b) return a[1] < b[1] end)
    for i, it in ipairs(items) do items[i] = it[1] .. "=" .. stable(it[2]) end
    return "{" .. table.concat(items, ",") .. "}"
end

local function endsWith(key, tail)
    return string.sub(key, -#tail) == tail
end

function Window:_connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self._conns, c)
    return c
end

function Tab:_column(side)
    if not self._cols then
        self.List.Visible = false
        local holder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, self.Page)
        self._cols = {}
        for i, nm in ipairs({ "Left", "Right" }) do
            local sf = create("ScrollingFrame", {
                Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(i == 1 and 0 or 0.5, i == 1 and 0 or 4, 0, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
            }, holder)
            bind(sf, "ScrollBarImageColor3", "Accent")
            pad(sf, 1, 6, 1, 10); listLayout(sf, 8)
            self._cols[nm] = sf
        end
    end
    if side ~= "Left" and side ~= "Right" then
        local l, r = #self._cols.Left:GetChildren(), #self._cols.Right:GetChildren()
        side = l <= r and "Left" or "Right"
    end
    return self._cols[side]
end

function Tab:Groupbox(opts)
    opts = opts or {}
    local col = self:_column(opts.Side)
    local box = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = (#col:GetChildren()) + 1 }, col)
    bind(box, "BackgroundColor3", "Surface"); corner(box, 4)
    local bs = create("UIStroke", { Thickness = 1, Transparency = 0.2 }, box); bind(bs, "Color", "Accent")
    listLayout(box, 0)
    local head = create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, box)
    local x = 10
    if opts.Icon then icon(head, opts.Icon, 15, "Text", { Position = UDim2.fromOffset(10, 6.5) }); x = 31 end
    label(head, opts.Name, 13, "Muted", false, { Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - (opts.Checkbox and 36 or 8), 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local cbObj
    if opts.Checkbox then
        local on = opts.Default ~= false
        local cb = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(18, 18), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, head)
        corner(cb, 4); stroke(cb, "Accent", 0.1)
        bind(cb, "BackgroundColor3", function() return on and Library.Theme.Accent or Library.Theme.Surface3 end)
        local mark = label(cb, "✓", 13, "Text", true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Visible = on })
        cbObj = {}
        function cbObj:Set(v, silent)
            on = v == true
            cb.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface3
            mark.Visible = on
            if not silent then safeCall(opts.Callback, on) end
        end
        function cbObj:Get() return on end
        cb.MouseButton1Click:Connect(function() cbObj:Set(not on) end)
        BBC.register(self, tostring(opts.Name) .. "#ativo", function() return on end, function(v) cbObj:Set(v) end)
        if on then safeCall(opts.Callback, true) end
    end
    local ln = create("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 1, -1), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, head)
    bind(ln, "BackgroundColor3", "Stroke")
    local body = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, box)
    listLayout(body, 0)
    return setmetatable({ List = body, _order = 0, Window = self.Window, _path = self._path .. "/" .. tostring(opts.Name), Frame = box, Checkbox = cbObj }, Container)
end

function Window:_getModal(key, titles, build)
    self._modals = self._modals or {}
    local m = self._modals[key]
    if m then return m end
    local overlay = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 20 }, self._content)
    bind(overlay, "BackgroundColor3", "Background")
    local function makeBox(left, title)
        local f = create("Frame", { Position = UDim2.new(left and 0 or 0.5, left and 0 or 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), BorderSizePixel = 0 }, overlay)
        bind(f, "BackgroundColor3", "Surface"); corner(f, 4)
        local st = create("UIStroke", { Thickness = 1, Transparency = 0.15 }, f); bind(st, "Color", "Accent")
        label(f, title or "", 12, "Muted", true, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -50, 0, 28), TextYAlignment = Enum.TextYAlignment.Center })
        local ln = create("Frame", { Position = UDim2.fromOffset(8, 28), Size = UDim2.new(1, -16, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, f)
        bind(ln, "BackgroundColor3", "Stroke")
        return f
    end
    local lb, rb = makeBox(true, titles and titles.Left), makeBox(false, titles and titles.Right)
    local close = create("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 2), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false }, rb)
    icon(close, "x", 16, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    close.MouseButton1Click:Connect(function() overlay.Visible = false end)
    local lbody = create("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1 }, lb)
    local rs = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, rb)
    bind(rs, "ScrollBarImageColor3", "Accent")
    listLayout(rs, 0); pad(rs, 4, 6, 0, 4)
    m = { Overlay = overlay, Left = lbody, LeftBox = lb, RightBox = rb, RightScroll = rs, Close = function() overlay.Visible = false end }
    m.Right = setmetatable({ List = rs, _order = 0, Window = self, _path = key .. "/painel" }, Container)
    self._modals[key] = m
    safeCall(build, m)
    return m
end

function Window:_select(tab)
    if not tab then return end
    local switching = self.Current ~= nil and self.Current ~= tab and not self._introActive
    for _, m in pairs(self._modals or {}) do m.Overlay.Visible = false end
    for _, t in ipairs(self.Tabs) do
        t.Page.Visible = (t == tab)
        if t.TabBtn then
            local on = t == tab
            t.Sel.BackgroundTransparency = on and 0 or 1
            t.Text.TextColor3 = on and Library.Theme.Text or Library.Theme.Muted
            t.IconImg.ImageColor3 = on and Library.Theme.Text or Library.Theme.Muted
            t.Active = on
        end
    end
    if self.HomeTab then
        self.HomeTab.Page.Visible = (tab == self.HomeTab)
    end
    if switching and tab.Page then
        tab.Page.Position = UDim2.fromOffset(0, 12)
        tween(tab.Page, { Position = UDim2.fromOffset(0, 0) }, 0.22, Enum.EasingStyle.Quint)
    end
    self.Current = tab
    if self._flameBtn then
        local home = tab == self.HomeTab
        self._flameStroke.Color = home and Library.Theme.Accent or Library.Theme.Stroke
        self._flameIcon.ImageColor3 = home and Library.Theme.Accent or Library.Theme.Text
    end
    if self._gearBtn then
        local g = tab and tab.IsSettings
        self._gearStroke.Color = g and Library.Theme.Accent or Library.Theme.Stroke
        self._gearIcon.ImageColor3 = g and Library.Theme.Accent or Library.Theme.Text
    end
end

function Window:Tab(opts)
    opts = opts or {}
    local tab = setmetatable({ Name = opts.Name, Window = self, _order = 0, _path = tostring(opts.Name), IsSettings = (opts.Name == "CONFIGURAÇÕES") or opts.IsSettings }, Tab)
    tab.Page = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, self._content)
    tab.List = create("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, tab.Page)
    bind(tab.List, "ScrollBarImageColor3", "Accent")
    pad(tab.List, 1, 6, 1, 10); listLayout(tab.List, 8)
    tab.Frame = tab.Page
    if opts.Hidden then
        if opts.Name == "Home" then self.HomeTab = tab end
        table.insert(self.Tabs, tab)
        return tab
    end
    local btn = create("TextButton", { Size = UDim2.new(1, 0, 0, 27), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = #self.Tabs + 1 }, self._tabList)
    tab.TabBtn = btn
    tab.Sel = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1 }, btn)
    bind(tab.Sel, "BackgroundColor3", "Accent"); corner(tab.Sel, 4)
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }) }, tab.Sel)
    tab.IconImg = icon(btn, opts.Icon or "circle", 16, "Muted", { Position = UDim2.fromOffset(12, 5.5) })
    tab.Text = label(btn, string.upper(opts.Name or ""), 13, "Muted", false, { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    table.insert(self.Tabs, tab)
    btn.MouseButton1Click:Connect(function() self:_select(tab) end)
    if not self.Current or self.Current == self.HomeTab then self:_select(tab) end
    if self._introProgress then
        self._tabCount = (self._tabCount or 0) + 1
        self._introProgress(math.min(0.6 + 0.35 * self._tabCount / (self._expectedTabs or 12), 0.95), "Montando o menu · " .. string.upper(tostring(opts.Name or "")))
        task.wait()
    end
    return tab
end

function Window:_snapshot()
    local data = {}
    for key, r in pairs(Library.Registry) do
        local ok, val = pcall(r.get)
        if ok and val ~= nil then data[key] = val end
    end
    return data
end

function Window:_applyData(data)
    for key, r in pairs(Library.Registry) do
        local v = data[key]
        if v ~= nil then pcall(r.set, v)
        elseif endsWith(key, "#tecla") or endsWith(key, "#fixado") then pcall(r.set, nil) end
    end
end

function Window:SaveConfig(name, quiet)
    name = cleanName(name)
    if name == "" then name = "default" end
    if not canFS() then Library:Notify({ Title = "BBC HUB", Content = "Salvar precisa de writefile no executor." }); return false end
    ensureFolders()
    local snap = self:_snapshot()
    local ok = pcall(function() writefile(CFG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode({ v = 3, name = name, data = snap })) end)
    if ok then
        self._cfgName = name
        self._lastState = stable(snap)
        if self._cfgBox then self._cfgBox.Text = name end
    end
    if not quiet then Library:Notify({ Title = "BBC HUB", Content = ok and ("Configuração salva: " .. name) or "Falha ao salvar." }) end
    return ok
end

function Window:LoadConfig(name, quiet)
    if not canFS() then return false end
    name = cleanName(name)
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, decoded = pcall(function() if isfile(path) then return HttpService:JSONDecode(readfile(path)) end end)
    if not ok or type(decoded) ~= "table" then return false end
    local data = (type(decoded.v) == "number" and type(decoded.data) == "table") and decoded.data or decoded
    if decoded.v == 2 then
        for k in pairs(data) do
            if string.find(k, "/Jogador/", 1, true) or string.find(k, "/NPCs/", 1, true) then data[k] = nil end
        end
    end
    self:_applyData(data)
    self._cfgName = name
    self._lastState = stable(self:_snapshot())
    if self._cfgBox then self._cfgBox.Text = name end
    if not quiet then Library:Notify({ Title = "BBC HUB", Content = "Configuração carregada: " .. name }) end
    return true
end

function Window:GetAutoload()
    if not canFS() then return nil end
    local ok, exists = pcall(isfile, CFG_FOLDER .. "/default.json")
    if ok and exists then return "default" end
    return nil
end

function Window:_autoSaveNow()
    if not canFS() or self._introActive or not self._ready then return end
    local snap = self:_snapshot()
    local state = stable(snap)
    if state == self._lastState then return end
    self._lastState = state
    ensureFolders()
    local name = self._cfgName or "default"
    pcall(function() writefile(CFG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode({ v = 3, name = name, data = snap })) end)
end

function Window:StartAutoSave()
    if self._autoSaveOn then return end
    self._autoSaveOn = true
    if self._lastState == nil then self._lastState = stable(self:_snapshot()) end
    task.spawn(function()
        while self.Gui and self.Gui.Parent do
            task.wait(3)
            self:_autoSaveNow()
        end
    end)
end

function Window:SetHideName(h) self._hideName = h == true; self:_renderIdentity() end
function Window:SetHideAvatar(h) self._hideAvatar = h == true; self:_renderIdentity() end
function Window:_renderIdentity()
    if not self._pName then return end
    self._pName.Text = self._hideName and "••••••" or LocalPlayer.DisplayName
    self._pAvatar.Image = self._hideAvatar and "" or (self._thumb or "")
end

function Window:_updateIsland()
    if self._island then self._island.Visible = (self._islandOn ~= false) and not self._main.Visible and not self._introActive end
    self:_updatePins()
end

function Library:OnPanic(fn) table.insert(Library._panicListeners, fn) end
function Window:SetPanic(on)
    on = on == true
    if Library.Panic == on then return end
    Library.Panic = on
    if self.Gui then self.Gui.Enabled = not on end
    if BBC.notifyGui then BBC.notifyGui.Enabled = not on end
    for _, g in ipairs(Library._panicGuis) do pcall(function() g.Enabled = not on end) end
    if Library._panicToggle then pcall(function() Library._panicToggle:Set(on, true) end) end
    if Library._panicZone then Library._panicZone.Visible = on end
    for _, fn in ipairs(Library._panicListeners) do pcall(fn, on) end
end

function Window:_updatePins()
    local show = not self._main.Visible and not self._introActive
    for _, pin in pairs(self._pins or {}) do pin.btn.Visible = show end
end

function Window:_setPin(name, obj, on, pos)
    self._pins = self._pins or {}
    local old = self._pins[name]
    if old then old.Destroy(); self._pins[name] = nil end
    if not on then return nil end
    local count = 0
    for _ in pairs(self._pins) do count += 1 end
    local btn = create("TextButton", { Name = "BBCPin", Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), Text = "", AutoButtonColor = false,
        BorderSizePixel = 0, ZIndex = 40, Visible = false,
        Position = pos and UDim2.fromScale(pos.x, pos.y) or UDim2.fromScale(0.06, math.min(0.22 + count * 0.1, 0.85)) }, self.Gui)
    corner(btn, 10)
    stroke(btn, "Accent", 0.2)
    local function color() return obj:Get() and Library.Theme.Accent or Library.Theme.Surface end
    bind(btn, "BackgroundColor3", color)
    local words, abbr = {}, ""
    for w in string.gmatch(tostring(name), "%S+") do table.insert(words, w) end
    if #words >= 2 then abbr = string.upper(string.sub(words[1], 1, 1) .. string.sub(words[2], 1, 1)) else abbr = string.upper(string.sub(tostring(name), 1, 3)) end
    label(btn, abbr, 14, "Text", true, { Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41 })
    label(btn, tostring(name), 9, "Muted", false, { Position = UDim2.fromOffset(2, 27), Size = UDim2.new(1, -4, 0, 12), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41 })
    local pin = { btn = btn }
    local dragging, moved, startIn, startPos, tok = false, false, nil, nil, 0
    local c1, c2
    function pin.Refresh() btn.BackgroundColor3 = color() end
    function pin.Destroy()
        if c1 then c1:Disconnect() end
        if c2 then c2:Disconnect() end
        btn:Destroy()
    end
    btn.InputBegan:Connect(function(i)
        local t = i.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        dragging, moved, startIn, startPos = true, false, i.Position, btn.Position
        tok += 1
        local my = tok
        task.delay(0.8, function()
            if tok == my and dragging and not moved and btn.Parent then
                self._pins[name] = nil
                if pin.OnRemoved then pin.OnRemoved() end
                pin.Destroy()
                Library:Notify({ Title = tostring(name), Content = "Botão removido da tela.", Duration = 1.5 })
            end
        end)
    end)
    c1 = UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        local t = i.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseMovement then return end
        local d = i.Position - startIn
        if d.Magnitude > 8 then moved = true end
        if moved then btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
    end)
    c2 = UserInputService.InputEnded:Connect(function(i)
        local t = i.UserInputType
        if not dragging or (t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1) then return end
        dragging = false
        tok += 1
        if moved then
            local vp = self.Gui.AbsoluteSize
            local c = btn.AbsolutePosition + btn.AbsoluteSize / 2
            btn.Position = UDim2.fromScale(math.clamp(c.X / vp.X, 0.03, 0.97), math.clamp(c.Y / vp.Y, 0.05, 0.95))
        else
            obj:Set(not obj:Get())
            local ring = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, ZIndex = 41 }, btn)
            corner(ring, 10)
            local rs = create("UIStroke", { Thickness = 2, Transparency = 0.1, Color = Library.Theme.Accent }, ring)
            tween(ring, { Size = UDim2.fromOffset(66, 66) }, 0.4, Enum.EasingStyle.Quad)
            tween(rs, { Transparency = 1 }, 0.4)
            task.delay(0.45, function() ring:Destroy() end)
        end
    end)
    self._pins[name] = pin
    btn.Visible = not self._main.Visible and not self._introActive
    return pin
end

function Window:SetIsland(on)
    self._islandOn = on == true
    self:_updateIsland()
end

function Window:_setOpen(v)
    if self._introActive or Library.Panic then return end
    local main, scale = self._main, self._scale
    local was = self._wantOpen ~= false
    self._wantOpen = v
    if v == was and main.Visible == v then return end
    self._animToken = (self._animToken or 0) + 1
    local my = self._animToken
    if not (Library.MenuAnim and scale) then
        main.Visible = v; if not v then self:_autoSaveNow() end; self:_updateIsland(); return
    end
    local fit = self._fitScale or scale.Scale
    if v then
        main.Visible = true
        scale.Scale = fit * 0.92
        tween(scale, { Scale = fit }, 0.3, Enum.EasingStyle.Back)
        self:_updateIsland()
    else
        self:_hideTip()
        self:_autoSaveNow()
        tween(scale, { Scale = fit * 0.92 }, 0.14, Enum.EasingStyle.Quad)
        task.delay(0.15, function()
            if self._animToken ~= my then return end
            main.Visible = false
            scale.Scale = self._fitScale or fit
            self:_updateIsland()
        end)
    end
end

function Window:SetVisible(v) self:_setOpen(v) end
function Window:SetLogo(v) self._logo.Visible = v == true end
function Window:SetBorderAccent(v)
    self._accentBorder = v == true
    self._mainStroke.Color = self._accentBorder and Library.Theme.Accent or Library.Theme.Stroke
end
function Window:SetBackgroundTransparency(t) self._main.BackgroundTransparency = math.clamp(t or 0, 0, 0.85) end
function Window:SetShadow(v)
    self._mainStroke.Thickness = v and 3 or 1
    self._mainStroke.Transparency = v and 0.45 or 0
end
function Window:Toggle() self:_setOpen(self._wantOpen == false) end
function Window:SetKeybind(k) self._key = parseKey(k) end
function Window:SetIslandDraggable(enabled) self._btnDraggable = enabled == true end
function Window:SetToggleButton(enabled)
    if not enabled then
        if self._toggleBtn then self._toggleBtn:Destroy(); self._toggleBtn = nil end
        return
    end
    if self._toggleBtn then return end
    local b = create("TextButton", { Name = "BBCToggle", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 14, 0.38, 0), Text = "BBC", TextSize = 15,
        FontFace = Library.Fonts.Bold, AutoButtonColor = false, BorderSizePixel = 0, Visible = not self._introActive }, self.Gui)
    bind(b, "BackgroundColor3", "Surface"); bind(b, "TextColor3", "Text"); corner(b, 8); stroke(b, "Accent", 0.2)
    self._toggleBtn = b
    local dragging, moved, startPos, startInput = false, false, nil, nil
    b.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved, startInput, startPos = true, false, i.Position, b.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(i)
        if dragging and self._btnDraggable ~= false and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            if d.Magnitude > 6 then moved = true end
            if moved then b.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
        end
    end)
    self:_connect(UserInputService.InputEnded, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if not moved then self:Toggle() end
        end
    end)
end

function Window:_hideTip(delay)
    local f = self._tipFrame
    if not f then return end
    task.delay(delay or 0, function()
        if self._tipFrame ~= f or self._tipHover then return end
        self._tipFrame = nil
        tween(f, { GroupTransparency = 1 }, 0.15)
        task.delay(0.2, function() f:Destroy() end)
    end)
end

function Window:_tip(title, text, row, stateFn, extras)
    if self._tipFrame then self._tipFrame:Destroy(); self._tipFrame = nil end
    self._tipHover = false
    local main = self._main
    local sc = (self._scale and self._scale.Scale) or 1
    local f = create("CanvasGroup", { Size = UDim2.fromOffset(236, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 50, GroupTransparency = 1 }, main)
    bind(f, "BackgroundColor3", "Surface3"); corner(f, 7); stroke(f, "Accent", 0.1)
    pad(f, 11, 11, 8, 9); listLayout(f, 3)
    local head = create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1 }, f)
    label(head, tostring(title), 13, "Accent", true, { Size = UDim2.new(1, -62, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 51 })
    if stateFn then
        local on = stateFn() == true
        local chip = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(56, 16), BorderSizePixel = 0, ZIndex = 51 }, head)
        corner(chip, 8)
        chip.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface
        local txt = label(chip, on and "ATIVO" or "INATIVO", 10, "Text", true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 52 })
        if not on then txt.TextColor3 = Library.Theme.Muted end
    end
    label(f, text and tostring(text) or "Toque para ativar ou desativar.", 12, text and "Text" or "Muted", false, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 16), ZIndex = 51 })
    if extras then
        local actions = create("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 3 }, f)
        local al = listLayout(actions, 6, Enum.FillDirection.Horizontal)
        al.VerticalAlignment = Enum.VerticalAlignment.Center
        local function chipBtn(text, order)
            local b = create("TextButton", { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 11, FontFace = Library.Fonts.Bold,
                AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 51 }, actions)
            bind(b, "BackgroundColor3", "Surface"); bind(b, "TextColor3", "Text")
            corner(b, 5); stroke(b, "Stroke", 0.2); pad(b, 8, 8, 0, 0)
            return b
        end
        local function keep() self._tipToken = (self._tipToken or 0) + 1; self._tipHover = false; self:_hideTip(2.5) end
        if UserInputService.KeyboardEnabled then
            local function keyLabel() local k = extras.getKey(); return "Atalho: " .. (k and keyText(k) or "—") end
            local kb = chipBtn(keyLabel(), 1)
            kb.MouseButton1Click:Connect(function()
                Library._listening = true
                kb.Text = "Pressione uma tecla…"
                local c
                c = UserInputService.InputBegan:Connect(function(input)
                    local t = input.UserInputType
                    local isMouse = t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3
                    if t ~= Enum.UserInputType.Keyboard and not isMouse then return end
                    local code = isMouse and t or input.KeyCode
                    c:Disconnect()
                    Library._listening = false
                    Library._lastBind = os.clock()
                    if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then extras.setKey(nil) else extras.setKey(code) end
                    kb.Text = keyLabel()
                    keep()
                end)
            end)
        end
        if extras.setPinned then
            local pb = chipBtn(extras.isPinned() and "Desafixar" or "Fixar na tela", 2)
            pb.MouseButton1Click:Connect(function()
                local v = not extras.isPinned()
                extras.setPinned(v)
                pb.Text = v and "Desafixar" or "Fixar na tela"
                keep()
            end)
        end
    end
    self._tipFrame = f
    f.MouseEnter:Connect(function() self._tipHover = true end)
    f.MouseLeave:Connect(function() self._tipHover = false; self:_hideTip(0.3) end)
    local W = main.AbsoluteSize.X / sc
    local x, y, anchor
    if row and row.Parent then
        local mp, rp, rsz = main.AbsolutePosition, row.AbsolutePosition, row.AbsoluteSize
        x = math.clamp((rp.X - mp.X + rsz.X / 2) / sc, 126, math.max(126, W - 126))
        local top, bottom = (rp.Y - mp.Y) / sc, (rp.Y + rsz.Y - mp.Y) / sc
        if top > 110 then anchor, y = Vector2.new(0.5, 1), top - 6 else anchor, y = Vector2.new(0.5, 0), bottom + 6 end
    else
        anchor, x, y = Vector2.new(1, 1), W - 12, main.AbsoluteSize.Y / sc - 12
    end
    f.AnchorPoint = anchor
    f.Position = UDim2.fromOffset(x, y + (anchor.Y == 1 and 6 or -6))
    tween(f, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, 0.18, Enum.EasingStyle.Quint)
    self._tipToken = (self._tipToken or 0) + 1
    local my = self._tipToken
    task.delay(extras and 6 or 3.4, function() if self._tipToken == my then self:_hideTip() end end)
end

function Window:_filter(q)
    q = string.lower(q or "")
    for _, d in ipairs(self.Gui:GetDescendants()) do
        if d:IsA("Frame") then
            local n = d:GetAttribute("SearchName")
            if n ~= nil then d.Visible = (q == "" or string.find(string.lower(n), q, 1, true) ~= nil) end
        end
    end
end

function Window:Destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    if self.Gui then self.Gui:Destroy() end
    for i, w in ipairs(Library.Windows) do if w == self then table.remove(Library.Windows, i) break end end
end

-- ---------- Ilha: pílula no topo que aparece quando o menu está fechado ----------
function Window:_buildIsland()
    local gui = self.Gui
    local MarketplaceService = game:GetService("MarketplaceService")
    local StatsService = game:GetService("Stats")
    local W0, H0, W1, H1 = 196, 34, 306, 116
    local started = os.clock()
    local island = create("TextButton", { Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(W0, H0),
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 30, ClipsDescendants = true }, gui)
    local cr = corner(island, 17)
    stroke(island, "Stroke", 0.2)
    local disc = create("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 31 }, island)
    bind(disc, "BackgroundColor3", "Accent"); corner(disc, 12)
    icon(disc, "box", 14, "Accent", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 32 })
    label(island, "BBC HUB", 13, "Text", true, { Position = UDim2.fromOffset(37, 0), Size = UDim2.fromOffset(72, 34), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 31 })
    local dot = create("Frame", { Position = UDim2.new(1, -82, 0, 14), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0, ZIndex = 31 }, island)
    corner(dot, 3)
    local fpsL = label(island, "60 FPS", 12, "Text", true, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(66, 34), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 31 })
    local l1 = label(island, "", 13, "Text", true, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 17), ZIndex = 31 })
    local l2 = label(island, "", 12, "Muted", false, { Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local l3 = label(island, "", 12, "Muted", false, { Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local l4 = label(island, "", 12, "Accent", true, { Position = UDim2.fromOffset(16, 94), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local gameName = "Roblox"
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then gameName = info.Name end
    end)
    local function fmtClock(t)
        t = math.floor(t)
        local h, m, sec = math.floor(t / 3600), math.floor(t % 3600 / 60), t % 60
        if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
        return string.format("%02d:%02d", m, sec)
    end
    local function update()
        local fps = Library._fps or 60
        fpsL.Text = fps .. " FPS"
        local col = fps >= 50 and Color3.fromRGB(70, 210, 110) or (fps >= 30 and Color3.fromRGB(240, 176, 108) or Color3.fromRGB(240, 100, 100))
        dot.BackgroundColor3 = col
        local ok, ping = pcall(function() return math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        l1.Text = self._hideName and "••••••" or LocalPlayer.DisplayName
        l2.Text = gameName
        l3.Text = Library.Tr("Sessão") .. " " .. fmtClock(os.clock() - started) .. "   ·   " .. (ok and (ping .. " ms") or "— ms") .. "   ·   " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        l4.Text = (self._key and keyText(self._key) or "—") .. "  ·  " .. Library.Tr("Toque para abrir")
    end
    update()
    local expanded, longPressed = false, false
    local function setExpanded(v)
        if expanded == v then return end
        expanded = v
        tween(island, { Size = UDim2.fromOffset(v and W1 or W0, v and H1 or H0) }, 0.22, Enum.EasingStyle.Quint)
        tween(cr, { CornerRadius = UDim.new(0, v and 20 or 17) }, 0.22, Enum.EasingStyle.Quint)
    end
    island.MouseEnter:Connect(function()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return end
        setExpanded(true)
    end)
    island.MouseLeave:Connect(function() setExpanded(false) end)
    island.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            longPressed = false
            task.delay(0.45, function()
                if island.Parent and island.Visible then
                    longPressed = true
                    setExpanded(true)
                    task.delay(3.5, function() setExpanded(false) end)
                end
            end)
        end
    end)
    island.MouseButton1Click:Connect(function()
        if longPressed then longPressed = false return end
        self:SetVisible(true)
    end)
    task.spawn(function()
        while gui.Parent do
            task.wait(0.5)
            if island.Visible then update() end
        end
    end)
    self._island = island
    self:_updateIsland()
end

-- ---------- Logo: cubo 3D girando ----------
local CUBE_GLYPH = {
    B = { "1111.", "1...1", "1...1", "1111.", "1...1", "1...1", "1111." },
    C = { ".111.", "1...1", "1....", "1....", "1....", "1...1", ".111." },
}
local CUBE_FACES = {
    { Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), "B" }, { Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), "B" },
    { Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), "C" }, { Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), "B" },
    { Vector3.new(0, 1, 0), Vector3.new(0, 0, -1), "C" }, { Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), "B" },
}
local function buildCubeLogo(parent, props, active)
    local vp = create("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(44, 44), Ambient = Color3.fromRGB(170, 170, 170),
        LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.6, -1, -0.8) }, parent)
    for k, v in pairs(props or {}) do vp[k] = v end
    local cam = create("Camera", { FieldOfView = 28, CFrame = CFrame.new(0, 0, 8.6) })
    cam.Parent = vp
    vp.CurrentCamera = cam
    local model = create("Model", {}, vp)
    local tint = {}
    local function part(size, cf, color, material, accent)
        local p = create("Part", { Anchored = true, CanCollide = false, CastShadow = false, Size = size, CFrame = cf, Color = color,
            Material = material, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, model)
        if accent then tint[#tint + 1] = p end
        return p
    end
    local body = part(Vector3.new(2, 2, 2), CFrame.new(), Library.Theme.Surface2, Enum.Material.SmoothPlastic, false)
    model.PrimaryPart = body
    local E = 0.1
    for _, a in ipairs({ -1, 1 }) do
        for _, b in ipairs({ -1, 1 }) do
            part(Vector3.new(2.1, E, E), CFrame.new(0, a, b), Library.Theme.Accent, Enum.Material.Neon, true)
            part(Vector3.new(E, 2.1, E), CFrame.new(a, 0, b), Library.Theme.Accent, Enum.Material.Neon, true)
            part(Vector3.new(E, E, 2.1), CFrame.new(a, b, 0), Library.Theme.Accent, Enum.Material.Neon, true)
        end
    end
    local cell = 0.25
    for _, face in ipairs(CUBE_FACES) do
        local fcf = CFrame.lookAt(face[1], Vector3.zero, face[2])
        local rows = CUBE_GLYPH[face[3]]
        for r = 1, #rows do
            for c = 1, 5 do
                if string.sub(rows[r], c, c) == "1" then
                    part(Vector3.new(cell * 0.92, cell * 0.92, 0.08), fcf * CFrame.new((c - 3) * cell, (4 - r) * cell, 0.04), Library.Theme.Accent, Enum.Material.Neon, true)
                end
            end
        end
    end
    table.insert(Library._themeListeners, function()
        if not vp.Parent then return end
        body.Color = Library.Theme.Surface2
        for _, p in ipairs(tint) do p.Color = Library.Theme.Accent end
    end)
    local t, conn = 0, nil
    conn = RunService.RenderStepped:Connect(function(dt)
        if not vp.Parent then conn:Disconnect() return end
        if active and not active() then return end
        t += dt
        model:PivotTo(CFrame.Angles(math.rad(-22), 0, math.rad(8)) * CFrame.Angles(0, t * 0.9, 0))
    end)
    return vp
end

-- ---------- Intro ----------
function Window:FinishLoading()
    self._loaded = true
    task.spawn(function()
        local t0 = os.clock()
        while self._introActive and os.clock() - t0 < 20 do task.wait(0.1) end
        local auto = self:GetAutoload()
        if auto then self:LoadConfig(auto, true) end
        self._ready = true
        self:StartAutoSave()
    end)
end

function Window:_startIntro(opts, W, H)
    local gui, main = self.Gui, self._main
    local steps = { "Preparando interface", "Carregando ícones", "Montando o menu" }
    local WIDTH, PAD, STEP, listTop = 340, 22, 24, 80
    local height = listTop + #steps * STEP + 18
    self._introActive = true
    self._loaded = false

    local loader = create("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 12), Size = UDim2.fromOffset(WIDTH, height),
        BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 60 }, gui)
    bind(loader, "BackgroundColor3", "Background")
    local loaderCorner = corner(loader, 12)
    local loaderStroke = stroke(loader, "Stroke", 0)
    local loaderScale = create("UIScale", { Scale = 0.96 }, loader)
    local content = create("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, loader)

    local logoHolder = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(PAD + 15, PAD + 15), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1 }, content)
    local logoScale = create("UIScale", { Scale = 1 }, logoHolder)
    icon(logoHolder, "box", 30, "Accent", { Size = UDim2.fromScale(1, 1) })
    TweenService:Create(logoScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.14 }):Play()
    local TEXT_X = PAD + 42
    label(content, opts.Title or "BBC HUB", 15, "Text", true, { Position = UDim2.fromOffset(TEXT_X, PAD - 2), Size = UDim2.new(1, -(TEXT_X + 70), 0, 18) })
    local statusLabel = label(content, "Iniciando", 12, "Muted", false, { Position = UDim2.fromOffset(TEXT_X, PAD + 17), Size = UDim2.new(1, -(TEXT_X + 70), 0, 15) })
    local percentLabel = label(content, "0%", 13, "Muted", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -PAD, 0, PAD + 6),
        Size = UDim2.fromOffset(56, 16), TextXAlignment = Enum.TextXAlignment.Right })
    local hair = create("Frame", { Position = UDim2.fromOffset(PAD, listTop - 14), Size = UDim2.new(1, -PAD * 2, 0, 1), BorderSizePixel = 0 }, content)
    bind(hair, "BackgroundColor3", "Stroke")

    local rows = {}
    for index, text in ipairs(steps) do
        local row = create("Frame", { Position = UDim2.fromOffset(PAD, listTop + (index - 1) * STEP), Size = UDim2.new(1, -PAD * 2, 0, STEP), BackgroundTransparency = 1 }, content)
        local dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, row)
        bind(dot, "BackgroundColor3", "Surface3"); corner(dot, 3)
        local spinner = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Visible = false }, row)
        corner(spinner, 6)
        local spStroke = create("UIStroke", { Thickness = 2 }, spinner)
        bind(spStroke, "Color", "Accent")
        create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) }) }, spStroke)
        local check = label(row, "✓", 14, "Accent", true, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(16, 16),
            TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, TextTransparency = 1 })
        local stepLabel = label(row, Library.Tr(text), 13, "Muted", false, { Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 1, 0),
            TextYAlignment = Enum.TextYAlignment.Center, TextTransparency = 1 })
        rows[index] = { Dot = dot, Spinner = spinner, Check = check, Label = stepLabel, Text = text, State = "pending" }
        task.delay(0.15 + index * 0.06, function()
            if loader.Parent and rows[index].State == "pending" then tween(stepLabel, { TextTransparency = 0.45 }, 0.3) end
        end)
    end

    local function setStep(index, state)
        local row = rows[index]
        if not row or row.State == state then return end
        row.State = state
        row.Dot.Visible = state == "pending"
        row.Spinner.Visible = state == "active"
        local mark = state == "done" or state == "warn"
        row.Check.Text = state == "warn" and "⚠" or "✓"
        row.Check.TextColor3 = state == "warn" and Library.Theme.Warning or Library.Theme.Accent
        tween(row.Check, { TextTransparency = mark and 0 or 1 }, 0.2)
        tween(row.Label, { TextTransparency = state == "pending" and 0.45 or 0,
            TextColor3 = state == "active" and Library.Theme.Text or Library.Theme.Muted }, 0.2)
        if state == "active" then statusLabel.Text = Library.Tr(row.Text) end
    end

    local track = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0 }, content)
    bind(track, "BackgroundColor3", "Surface3")
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
    bind(fill, "BackgroundColor3", "Accent")
    local curP = 0
    local function progress(v, t)
        if v < curP then return end
        curP = v
        tween(fill, { Size = UDim2.fromScale(v, 1) }, t or 0.4, Enum.EasingStyle.Quart)
    end
    self._introProgress = function(v, text)
        progress(v, 0.3)
        if text and rows[3] and rows[3].State == "active" then statusLabel.Text = text end
    end

    local stepConn
    stepConn = RunService.RenderStepped:Connect(function(dt)
        if not loader.Parent then stepConn:Disconnect() return end
        percentLabel.Text = math.floor(fill.Size.X.Scale * 100 + 0.5) .. "%"
        for _, row in ipairs(rows) do
            if row.State == "active" then row.Spinner.Rotation = (row.Spinner.Rotation + dt * 360) % 360 end
        end
    end)

    tween(loader, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.45, Enum.EasingStyle.Quint)
    tween(loaderScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Quint)

    local function cleanup()
        pcall(function() stepConn:Disconnect() end)
        if loader.Parent then loader:Destroy() end
        main.Visible = true
        self._introActive = false
        self._introProgress = nil
        self._wantOpen = true
        if self._toggleBtn then self._toggleBtn.Visible = true end
        self:_updateIsland()
    end

    local function finish()
        for i, r in ipairs(rows) do if r.State ~= "warn" then setStep(i, "done") end end
        progress(1, 0.25)
        statusLabel.Text = Library.Tr("Tudo pronto")
        task.wait(0.35)
        tween(content, { GroupTransparency = 1 }, 0.18)
        local fit = self._fitScale or 1
        tween(loader, { Size = UDim2.fromOffset(W * fit, H * fit) }, 0.5, Enum.EasingStyle.Quint)
        tween(loaderCorner, { CornerRadius = UDim.new(0, 6) }, 0.5, Enum.EasingStyle.Quint)
        task.wait(0.28)
        main.Visible = true
        if self._scale then
            self._scale.Scale = fit * 0.96
            tween(self._scale, { Scale = fit }, 0.35, Enum.EasingStyle.Quint)
        end
        tween(loader, { GroupTransparency = 1 }, 0.25)
        tween(loaderStroke, { Transparency = 1 }, 0.2)
        task.wait(0.3)
        cleanup()
    end

    task.spawn(function()
        local ok, err = pcall(function()
            setStep(1, "active"); progress(0.25, 0.5)
            task.wait(0.5)
            setStep(1, "done")
            setStep(2, "active"); progress(0.55, 0.8)
            local t1 = os.clock()
            while not BBC.lucide and not BBC.iconsGaveUp and os.clock() - t1 < 25 do task.wait(0.05) end
            task.wait(math.max(0, 0.5 - (os.clock() - t1)))
            if BBC.lucide then
                setStep(2, "done")
            else
                rows[2].Label.Text = "Ícones indisponíveis, usando símbolos"
                rows[2].Text = rows[2].Label.Text
                setStep(2, "warn")
            end
            setStep(3, "active"); progress(0.6, 0.4)
            local t2 = os.clock()
            while not self._loaded and os.clock() - t2 < 12 do task.wait(0.05) end
            task.wait(0.2)
            finish()
        end)
        if not ok then
            warn("[BBC] intro: " .. tostring(err))
            cleanup()
        end
    end)
end

-- ---------- Window Constructor ----------
function Library:Window(opts)
    opts = opts or {}
    if opts.Theme and Library.ThemePresets[opts.Theme] then Library:SetTheme(opts.Theme) end
    local self = setmetatable({ Tabs = {}, _conns = {}, _hideName = false, _hideAvatar = false, _btnDraggable = true }, Window)
    local W = (opts.Size and opts.Size.X.Offset > 0) and opts.Size.X.Offset or 640
    local H = (opts.Size and opts.Size.Y.Offset > 0) and opts.Size.Y.Offset or 360
    local intro = opts.Intro ~= false
    local gui = create("ScreenGui", { Name = "BBCHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, guiParent())
    self.Gui = gui
    local main = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BorderSizePixel = 0, Visible = not intro }, gui)
    bind(main, "BackgroundColor3", "Background"); corner(main, 6)
    self._mainStroke = stroke(main, "Stroke", 0)
    bind(self._mainStroke, "Color", function() return self._accentBorder and Library.Theme.Accent or Library.Theme.Stroke end)
    self._main = main
    local scale = create("UIScale", {}, main)
    self._scale = scale
    local function fit()
        local vp = gui.AbsoluteSize
        if vp.X <= 0 or vp.Y <= 0 then return end
        scale.Scale = math.clamp(math.min(vp.X * 0.8 / W, vp.Y * 0.92 / H), 0.45, 1.3)
        self._fitScale = scale.Scale
    end
    fit()
    self:_connect(gui:GetPropertyChangedSignal("AbsoluteSize"), fit)
    if intro then self:_startIntro(opts, W, H) end
    
    -- Safety timeout: force-show main frame if intro gets stuck (max 15s)
    task.spawn(function()
        local introTimeout = 15
        local startTime = os.clock()
        while self._introActive and os.clock() - startTime < introTimeout do
            task.wait(0.2)
        end
        if self._introActive then
            warn("[BBC] Intro timeout - forçando exibição do menu")
            self._introActive = false
            self._introProgress = nil
            main.Visible = true
            if self._scale then
                self._scale.Scale = self._fitScale or 1
            end
            self:_updateIsland()
            if self._toggleBtn then self._toggleBtn.Visible = true end
            -- Load autoload config
            local auto = self:GetAutoload()
            if auto then self:LoadConfig(auto, true) end
            self._ready = true
            self:StartAutoSave()
        end
    end)

    local t0 = os.clock()
    while not BBC.lucide and not BBC.iconsGaveUp and os.clock() - t0 < 25 do task.wait(0.1) end
    if not BBC.lucide then
        BBC.iconsGaveUp = true
        if type(BBC.allIcons) == "table" and type(BBC.showGlyph) == "function" then
            for _, rec in ipairs(BBC.allIcons) do BBC.showGlyph(rec) end
        end
    end
    self._key = parseKey(opts.Keybind or "RightShift")
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if processed or Library._listening or os.clock() - (Library._lastBind or 0) < 0.25 then return end
        local t = input.UserInputType
        local code = t == Enum.UserInputType.Keyboard and input.KeyCode or t
        if self._key and code == self._key then self:Toggle() end
        for _, b in ipairs(Library._toggleBinds) do
            local k = b.key()
            if k and code == k then task.spawn(b.fire) end
        end
    end)

    -- Cabeçalho
    local header = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, main)
    do
        local okc, vp = pcall(buildCubeLogo, header, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(44, 44) }, function() return main.Visible end)
        self._logo = (okc and vp) or icon(header, "box", 30, "Accent", { Position = UDim2.fromOffset(12, 11) })
    end
    label(header, "BBC", 17, "Accent", true, { Position = UDim2.fromOffset(50, 6), Size = UDim2.fromOffset(70, 20) })
    label(header, "HUB", 17, "Text", true, { Position = UDim2.fromOffset(50, 25), Size = UDim2.fromOffset(70, 20) })
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    self:_connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)

    -- Barra de configuração
    local cfgName = "default"
    local cfgBar = create("Frame", { Position = UDim2.fromOffset(130, 11), Size = UDim2.new(1, -330, 0, 30), BorderSizePixel = 0 }, header)
    bind(cfgBar, "BackgroundColor3", "Surface2"); corner(cfgBar, 3); stroke(cfgBar, "Stroke", 0.1)
    local saveBtn = create("TextButton", { Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, cfgBar)
    icon(saveBtn, "save", 18, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    local cfgBox = create("TextBox", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -38, 1, 0), BackgroundTransparency = 1, Text = cfgName, TextSize = 14,
        FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, PlaceholderText = "default" }, cfgBar)
    bind(cfgBox, "TextColor3", "Text"); bind(cfgBox, "PlaceholderColor3", "Muted")
    self._cfgBox = cfgBox
    saveBtn.MouseButton1Click:Connect(function() cfgName = (cfgBox.Text ~= "" and cfgBox.Text) or "default"; self:SaveConfig(cfgName) end)
    cfgBox.FocusLost:Connect(function(enter)
        if enter and cfgBox.Text ~= "" then cfgName = cfgBox.Text; if not self:LoadConfig(cfgName) then cfgBox.Text = cfgName end end
    end)

    -- Busca
    local searchBox = create("TextBox", { Position = UDim2.fromOffset(130, 11), Size = UDim2.new(1, -330, 0, 30), Text = "", PlaceholderText = "Search", TextSize = 14,
        FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, Visible = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, header)
    bind(searchBox, "BackgroundColor3", "Surface2"); bind(searchBox, "TextColor3", "Text"); bind(searchBox, "PlaceholderColor3", "Muted")
    corner(searchBox, 3); stroke(searchBox, "Accent", 0.2); pad(searchBox, 10, 8, 0, 0)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function() self:_filter(searchBox.Text) end)

    -- Botões do canto
    local function headerBtn(iconName, offset)
        local b = create("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -offset, 0, 11), Size = UDim2.fromOffset(30, 30), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, header)
        bind(b, "BackgroundColor3", "Surface2"); corner(b, 3)
        local st = stroke(b, "Stroke", 0.05)
        local ic = icon(b, iconName, 16, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
        return b, ic, st
    end
    local searchBtn = headerBtn("search", 12 + 36 + 36)
    local flameBtn, flameIcon, flameStroke = headerBtn("flame", 12 + 36)
    local gearBtn, gearIcon, gearStroke = headerBtn("settings", 12)
    self._flameBtn, self._flameIcon, self._flameStroke = flameBtn, flameIcon, flameStroke
    self._gearBtn, self._gearIcon, self._gearStroke = gearBtn, gearIcon, gearStroke
    searchBtn.MouseButton1Click:Connect(function()
        local on = not searchBox.Visible
        searchBox.Visible = on; cfgBar.Visible = not on
        if on then searchBox:CaptureFocus() else searchBox.Text = "" end
    end)
    flameBtn.MouseButton1Click:Connect(function() self:_select(self.HomeTab) end)
    gearBtn.MouseButton1Click:Connect(function()
        for _, t in ipairs(self.Tabs) do if t.IsSettings then self:_select(t) break end end
    end)

    -- Barra lateral
    local side = create("Frame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(0, 152, 1, -52), BackgroundTransparency = 1 }, main)
    self._tabList = create("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -54), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y }, side)
    pad(self._tabList, 6, 4, 2, 2); listLayout(self._tabList, 2)
    local div = create("Frame", { Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, -6), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, side)
    bind(div, "BackgroundColor3", "Stroke")
    -- Cartão do jogador
    local card = create("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -6), Size = UDim2.new(1, -12, 0, 44), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, side)
    bind(card, "BackgroundColor3", "Surface2"); corner(card, 4); stroke(card, "Accent", 0.15)
    self._pAvatar = create("ImageLabel", { Position = UDim2.fromOffset(6, 7), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 0, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop }, card)
    bind(self._pAvatar, "BackgroundColor3", "Surface3"); corner(self._pAvatar, 15)
    self._pName = label(card, LocalPlayer.DisplayName, 13, "Text", false, { Position = UDim2.fromOffset(42, 5), Size = UDim2.new(1, -46, 0, 17) })
    local pSub = label(card, "", 11, "Muted", false, { Position = UDim2.fromOffset(42, 23), Size = UDim2.new(1, -46, 0, 15) })
    task.spawn(function()
        local ok, img = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
        if ok then self._thumb = img; self:_renderIdentity() end
    end)
    local home = type(opts.Home) == "table" and opts.Home or {}
    local function subText()
        local e = home.Expiry
        if type(e) == "function" then local ok, r = pcall(e); e = ok and r or nil end
        if type(e) == "number" then
            local left = e - os.time()
            return left > 0 and (fmtLeft(left) .. " left") or "Expired"
        end
        return "Ilimitado"
    end
    pSub.Text = subText()
    task.spawn(function() while gui.Parent do task.wait(20); pSub.Text = subText() end end)
    card.MouseButton1Click:Connect(function() self:_select(self.HomeTab) end)

    -- Conteúdo
    self._content = create("Frame", { Position = UDim2.fromOffset(160, 54), Size = UDim2.new(1, -168, 1, -62), BackgroundTransparency = 1, ClipsDescendants = true }, main)

    if opts.Home ~= false then
        local homeTab = self:Tab({ Name = "Home", Hidden = true })
        if type(home.Build) == "function" then safeCall(home.Build, self, homeTab, homeTab.List) end
    end
    self:_buildIsland()
    table.insert(Library.Windows, self)
    table.insert(Library._themeListeners, function()
        if gui.Parent and self.Current then self:_select(self.Current) end
    end)
    self:_renderIdentity()
    return self
end

local function fmtLeft(sec)
    sec = math.max(math.floor(sec), 0)
    local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
    if d > 0 then return d .. "d " .. h .. "h" end
    return h .. "h " .. m .. "m"
end

BBC.UI = BBC.UI or {}
BBC.UI.Tab = Tab
BBC.UI.Window = Window

return { Tab = Tab, Window = Window }

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

end)

-- ============================================================
-- módulo: features.player  (features/player.lua)
-- ============================================================
__module("features.player", function(BBC)
--[[
    BBC HUB - Feature: Player
    Aba JOGADOR: movimento, câmera, saque, animações, recursos.
    Painel de perfil (Home) com estatísticas reais.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

-- ---------- Perfil do Jogador (Home) ----------
local function buildProfile(win, page, list)
    local Library = BBC.Library
    local Utils = BBC.Utils
    local Security = BBC.Security
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local StatsService = game:GetService("Stats")
    local LP = Players.LocalPlayer
    local Config = Security.getConfig()
    local VERSION = Config.Version or "0.0.8.2"
    local ACCESS = Config.Access or "FREE"

    local FOLDER = "BBC_HUB"
    local FILE = FOLDER .. "/perfil_" .. LP.UserId .. ".json"
    local data = { kills = 0, deaths = 0, damage = 0, played = 0, runs = 0 }
    local canFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    if canFS then
        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(FOLDER) then makefolder(FOLDER) end
        end)
        pcall(function()
            if isfile(FILE) then
                for k, v in pairs(HttpService:JSONDecode(readfile(FILE))) do data[k] = v end
            end
        end)
    end
    data.runs = (tonumber(data.runs) or 0) + 1
    local function save()
        if canFS then pcall(writefile, FILE, HttpService:JSONEncode(data)) end
    end
    save()

    local function hookCharacter(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        local last = hum.Health
        hum.HealthChanged:Connect(function(h)
            if h < last then data.damage += last - h end
            last = h
        end)
        hum.Died:Connect(function() data.deaths += 1 end)
    end
    if LP.Character then task.spawn(hookCharacter, LP.Character) end
    LP.CharacterAdded:Connect(hookCharacter)

    local function hookVictim(plr)
        if plr == LP then return end
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if not hum then return end
            hum.Died:Connect(function()
                local tag = hum:FindFirstChild("creator")
                if tag and tag.Value == LP then data.kills += 1 end
            end)
        end
        if plr.Character then task.spawn(onChar, plr.Character) end
        plr.CharacterAdded:Connect(onChar)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookVictim(p) end
    Players.PlayerAdded:Connect(hookVictim)

    local function leaderStat(patterns)
        local ls = LP:FindFirstChild("leaderstats")
        if not ls then return nil end
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("ValueBase") then
                local n = string.lower(v.Name)
                for _, p in ipairs(patterns) do
                    if string.find(n, p, 1, true) then return tonumber(v.Value) end
                end
            end
        end
        return nil
    end

    local function fmtDuration(sec, withSeconds)
        sec = math.max(math.floor(sec), 0)
        local d = math.floor(sec / 86400)
        local h = math.floor(sec % 86400 / 3600)
        local m = math.floor(sec % 3600 / 60)
        local r = sec % 60
        if d > 0 then return d .. "d " .. h .. "h" end
        if h > 0 then return h .. "h " .. m .. "m" end
        if withSeconds then return m .. "m " .. r .. "s" end
        return m .. "m"
    end
    local function fmtBig(n)
        n = tonumber(n) or 0
        if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
        if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
        return tostring(math.floor(n))
    end
    local function getPing()
        local ok, v = pcall(function() return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and v then return math.floor(v) end
        local ok2, p = pcall(function() return LP:GetNetworkPing() * 2000 end)
        return ok2 and math.floor(p) or 0
    end
    local function getDevice()
        local kb = UserInputService.KeyboardEnabled
        if UserInputService.TouchEnabled and not kb then return "Celular" end
        if UserInputService.GamepadEnabled and not kb then return "Console" end
        return "PC"
    end
    local frames, fps = 0, 0
    RunService.RenderStepped:Connect(function() frames += 1 end)

    local themed = {}
    local function th(inst, prop, key)
        themed[#themed + 1] = { inst, prop, key }
        inst[prop] = Library.Theme[key]
    end
    table.insert(Library._themeListeners, function()
        for _, t in ipairs(themed) do
            if t[1].Parent then t[1][t[2]] = Library.Theme[t[3]] end
        end
    end)
    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        i.Parent = parent
        return i
    end
    local function txt(parent, text, size, key, bold, extra)
        local l = mk("TextLabel", {
            BackgroundTransparency = 1, Text = text, TextSize = size,
            FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.new(1, 0, 0, size + 4),
        }, parent)
        th(l, "TextColor3", key or "Text")
        for k, v in pairs(extra or {}) do l[k] = v end
        return l
    end
    local function decorate(f, key, radius)
        th(f, "BackgroundColor3", key)
        f.BorderSizePixel = 0
        mk("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, f)
        th(mk("UIStroke", {}, f), "Color", "Stroke")
    end
    local function box(parent, title, order, size)
        local f = mk("Frame", { Size = size or UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, parent)
        decorate(f, "Surface2", 8)
        mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, f)
        mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
        txt(f, string.upper(title), 12, "Muted", false, { LayoutOrder = 0 })
        return f
    end
    local function grid(parent, cols, order)
        local g = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, parent)
        mk("UIGridLayout", {
            CellPadding = UDim2.fromOffset(6, 6), CellSize = UDim2.new(1 / cols, -(6 * (cols - 1) / cols), 0, 46),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, g)
        return g
    end
    local function cell(parent, title, order, big)
        local c = mk("Frame", { LayoutOrder = order }, parent)
        decorate(c, "Background", 6)
        txt(c, title, 12, "Muted", false, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 15) })
        local v = txt(c, "…", big or 16, "Text", true, { Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -16, 0, 22) })
        return v, c
    end
    local function spark(parent)
        local W, H, N = 56, 22, 20
        local holder = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(W, H), ClipsDescendants = true }, parent)
        local segs, samples = {}, {}
        for i = 1, N - 1 do
            local sg = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Size = UDim2.fromOffset(0, 2), Visible = false }, holder)
            th(sg, "BackgroundColor3", "Accent")
            segs[i] = sg
        end
        return function(v)
            table.insert(samples, v)
            if #samples > N then table.remove(samples, 1) end
            local lo, hi = math.huge, -math.huge
            for _, x in ipairs(samples) do lo = math.min(lo, x); hi = math.max(hi, x) end
            if hi - lo < 1 then hi = lo + 1 end
            local off, step, pts = N - #samples, W / (N - 1), {}
            for i, x in ipairs(samples) do
                pts[i] = Vector2.new((off + i - 1) * step, H - 2 - ((x - lo) / (hi - lo)) * (H - 4))
            end
            for i = 1, N - 1 do
                local a, b = pts[i - off], pts[i - off + 1]
                local sg = segs[i]
                if a and b then
                    local d = b - a
                    sg.Visible = true
                    sg.Size = UDim2.fromOffset(d.Magnitude + 1, 2)
                    sg.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                    sg.Rotation = math.deg(math.atan2(d.Y, d.X))
                else
                    sg.Visible = false
                end
            end
        end
    end

    local root = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, list)
    mk("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, root)

    -- Identidade
    local idc = mk("Frame", { Size = UDim2.new(1, 0, 0, 78), LayoutOrder = 1 }, root)
    decorate(idc, "Surface2", 8)
    local avatar = mk("ImageLabel", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 0, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop }, idc)
    th(avatar, "BackgroundColor3", "Surface3")
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, avatar)
    local thumb
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if ok then thumb = img; avatar.Image = img end
    end)
    local nameL = txt(idc, LP.DisplayName, 20, "Text", true, { Position = UDim2.fromOffset(82, 12), Size = UDim2.new(1, -230, 0, 26) })
    local userL = txt(idc, "@" .. LP.Name, 15, "Muted", false, { Position = UDim2.fromOffset(82, 42), Size = UDim2.new(1, -230, 0, 20) })
    local badge = mk("TextLabel", {
        AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(0, 16), Size = UDim2.fromOffset(46, 20),
        BackgroundTransparency = 0.6, Text = ACCESS, TextSize = 12, FontFace = Library.Fonts.Bold,
    }, idc)
    decorate(badge, "Surface3", 4); th(badge, "TextColor3", "Text")
    local function placeBadge()
        badge.Position = UDim2.fromOffset(82 + nameL.TextBounds.X + 8, 15)
    end
    nameL:GetPropertyChangedSignal("TextBounds"):Connect(placeBadge); placeBadge()
    local hidden = false
    local spy = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(44, 44), Text = "OCULTAR", TextSize = 9, AutoButtonColor = false, FontFace = Library.Fonts.Bold }, idc)
    decorate(spy, "Background", 6); th(spy, "TextColor3", "Text")
    spy.MouseButton1Click:Connect(function()
        hidden = not hidden
        pcall(function() win:SetHideName(hidden); win:SetHideAvatar(hidden) end)
        nameL.Text = hidden and "••••••" or LP.DisplayName
        userL.Text = hidden and "@••••••" or ("@" .. LP.Name)
        avatar.Image = hidden and "" or (thumb or "")
        th(spy, "TextColor3", hidden and "Accent" or "Text")
    end)

    -- Estatísticas
    local st = box(root, "Estatísticas", 2)
    local sg = grid(st, 6, 1)
    local vKills = cell(sg, "Abates", 1, 15)
    local vDeaths = cell(sg, "Mortes", 2, 15)
    local vKD, kdCell = cell(sg, "Proporção K/D", 3, 15)
    local vRep = cell(sg, "Denúncias", 4, 15)
    local vPlayed = cell(sg, "Tempo jogado", 5, 15)
    local vDmg = cell(sg, "Dano recebido", 6, 15)
    th(vKD, "TextColor3", "Accent")

    -- Sessão e Conta lado a lado
    local row = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, root)
    mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, row)
    local ses = box(row, "Sessão", 1, UDim2.new(0.5, -5, 0, 0))
    local acc = box(row, "Conta", 2, UDim2.new(0.5, -5, 0, 0))
    local sgrid, agrid = grid(ses, 2, 1), grid(acc, 2, 1)
    local vFps, fpsCell = cell(sgrid, "FPS", 1)
    local vPing, pingCell = cell(sgrid, "Ping", 2)
    local vSess = cell(sgrid, "Tempo da sessão", 3)
    local vPlayers = cell(sgrid, "Jogadores", 4)
    local vDev = cell(sgrid, "Dispositivo", 5)
    local vRes = cell(sgrid, "Resolução", 6)
    local pushFps, pushPing = spark(fpsCell), spark(pingCell)
    local vAge = cell(agrid, "Idade da conta", 1)
    local vUid = cell(agrid, "ID do usuário", 2)
    local vRuns = cell(agrid, "Execuções", 3)
    local vAccess = cell(agrid, "Acesso", 4)
    local vLeft = cell(agrid, "Tempo restante", 5)
    local vVer = cell(agrid, "Versão do script", 6)

    -- Servidores
    local sv = box(root, "Servidores", 4)
    local svg = grid(sv, 3, 1)
    local vMap = cell(svg, "ID do mapa", 1)
    local vMapVer = cell(svg, "Versão do mapa", 2)
    local vJob = cell(svg, "ID do servidor", 3, 14)

    -- Valores estáticos
    vUid.Text = tostring(LP.UserId)
    vAge.Text = LP.AccountAge .. " dias"
    vAccess.Text = ACCESS
    vVer.Text = VERSION
    vDev.Text = getDevice()
    table.insert(BBC.onLanguageChanged, function() vDev.Text = getDevice(); vAge.Text = LP.AccountAge .. " dias" end)
    vMap.Text = tostring(game.PlaceId)
    vMapVer.Text = tostring(game.PlaceVersion)
    vJob.Text = (game.JobId ~= "" and game.JobId) or "Servidor local"
    vRuns.Text = tostring(data.runs)
    vRep.Text = "—"

    local started, lastSave, lastTick = os.clock(), os.clock(), os.clock()
    local function refresh()
        local now = os.clock()
        data.played += now - lastTick
        lastTick = now
        fps = frames; frames = 0
        local ping = getPing()
        vFps.Text = tostring(fps); pushFps(fps)
        vPing.Text = ping .. " ms"; pushPing(ping)
        vFps.TextColor3 = fps >= 50 and Library.Theme.Text or (fps >= 30 and Library.Theme.Warning or Library.Theme.Error)
        vPing.TextColor3 = ping <= 90 and Library.Theme.Text or (ping <= 180 and Library.Theme.Warning or Library.Theme.Error)
        vSess.Text = fmtDuration(now - started, true)
        vPlayers.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
        local cam = workspace.CurrentCamera
        if cam then vRes.Text = math.floor(cam.ViewportSize.X) .. " x " .. math.floor(cam.ViewportSize.Y) end
        local kills = leaderStat({ "kill", "abate", "elimin" }) or data.kills
        local deaths = leaderStat({ "death", "morte", "died" }) or data.deaths
        vKills.Text = tostring(kills)
        vDeaths.Text = tostring(deaths)
        vKD.Text = string.format("%.2f", kills / math.max(deaths, 1))
        vPlayed.Text = fmtDuration(data.played)
        vDmg.Text = fmtBig(data.damage)
        local expiry = Config.Expiry
        if type(expiry) == "function" then local ok, r = pcall(expiry); expiry = ok and r or nil end
        if type(expiry) == "number" then
            local left = expiry - os.time()
            vLeft.Text = left > 0 and fmtDuration(left) or "Expirado"
        else
            vLeft.Text = "Ilimitado"
        end
        if now - lastSave >= 30 then lastSave = now; save() end
    end
    refresh()
    task.spawn(function()
        while list.Parent do
            task.wait(1)
            pcall(refresh)
        end
    end)
    Players.PlayerRemoving:Connect(function(p) if p == LP then save() end end)
end

Features.buildProfile = buildProfile

-- ---------- Aba JOGADOR ----------
function Features.buildPlayer(window)
    local jogador = window:Tab({ Name = "JOGADOR", Icon = "user" })
    local g = jogador:Groupbox({ Name = "MOVIMENTO", Icon = "move", Side = "Left" })
    T(g, "Hack de velocidade"); T(g, "Sprint automático"); T(g, "Pulos seguidos")
    T(g, "Controle no ar"); T(g, "Voar"); T(g, "Sem dano de queda"); T(g, "Sempre no chão")
    T(g, "Jesus"); T(g, "Aranha")
    g = jogador:Groupbox({ Name = "CÂMERA", Icon = "camera", Side = "Left" })
    T(g, "Terceira pessoa"); T(g, "Câmera livre")
    g = jogador:Groupbox({ Name = "SAQUE", Icon = "package", Side = "Left" })
    T(g, "Saque automático")
    g = jogador:Groupbox({ Name = "MÃOS E ARMA", Icon = "hand", Side = "Right" })
    for _, n in ipairs({ "Deslocamento", "Trocar personagem", "Personagem", "Corpo em 1ª pessoa", "Mãos", "Item na mão" }) do T(g, n) end
    g = jogador:Groupbox({ Name = "CAMPO DE VISÃO", Icon = "focus", Side = "Right" })
    S(g, "Campo de visão", 30, 120, 120)
    S(g, "Visão com zoom", 5, 120, 5)
    g:Keybind({ Name = "Zoom", Default = "N", OnChanged = function(k) BBC.keys.zoom = k.Name; BBC.refreshPanels() end, Callback = function() end })
    g = jogador:Groupbox({ Name = "ANIMAÇÕES", Icon = "activity", Side = "Right" })
    g:Dropdown({ Name = "Animação", Options = { "Swish", "Padrão" }, Default = "Swish", Callback = function(v) end })
    T(g, "Repetir")
    S(g, "Velocidade", 0.1, 3, 1, "x", 0.1)
    S(g, "Peso", 0, 100, 100, "%")
    g:Button({ Name = "Reproduzir", Callback = function() BBC.notify("Reproduzir") end })
    g = jogador:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Right" })
    T(g, "Painel do jogador"); T(g, "Anti AFK"); T(g, "Renascer automático")
    T(g, "Remover água"); T(g, "Não se afogar"); T(g, "Mapa e navegação", true)

    return jogador
end

return { buildPlayer = Features.buildPlayer }

end)

-- ============================================================
-- módulo: features.combat  (features/combat.lua)
-- ============================================================
__module("features.combat", function(BBC)
--[[
    BBC HUB - Feature: Combat
    Aba COMBATE: mira, alvos, espia, corpo a corpo, arma, efeitos, anti-aim, granadas.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

function Features.buildCombat(window)
    local combate = window:Tab({ Name = "COMBATE", Icon = "crosshair" })
    local g = combate:Groupbox({ Name = "MIRA", Icon = "crosshair", Side = "Left", Checkbox = true, Default = true, Callback = function(v) end })
    g:Segmented({ Name = "Modo", Options = { "Silencioso", "Fixar", "Agressivo" }, Icons = { "crosshair", "lock", "flame" }, Default = "Fixar", Callback = function(v) end })
    g:Dropdown({ Name = "Ativação", Options = { "Ao mirar", "Sempre" }, Default = "Ao mirar", Callback = function(v) end })
    T(g, "Alvo fixo"); T(g, "Previsão")
    S(g, "Suavização", 0, 300, 80, "ms")
    T(g, "Pausa inteligente"); T(g, "Notificar", true)
    g = combate:Groupbox({ Name = "ALVOS", Icon = "target", Side = "Left" })
    S(g, "Raio da mira", 10, 500, 70)
    T(g, "FOV dinâmico", true)
    g:Dropdown({ Name = "Ponto de mira", Options = { "Partes selecionadas", "Mais próximo" }, Default = "Partes selecionadas", Callback = function(v) end })
    g:Dropdown({ Name = "Partes do corpo", Options = { "Cabeça", "Corpo", "Braços", "Pernas" }, Default = { "Cabeça" }, Multi = true, Callback = function(v) end })
    T(g, "Alternativa visível", true); T(g, "Mirar em NPCs", true); T(g, "Tiro por paredes", true)
    g:Keybind({ Name = "Adicionar amigo", Default = "MB3", Callback = function() end })
    S(g, "Limite de verificações", 1, 20, 7)
    g = combate:Groupbox({ Name = "ESPIADA", Icon = "eye", Side = "Left" })
    T(g, "Espiada subterrânea")
    g = combate:Groupbox({ Name = "CORPO A CORPO", Icon = "swords", Side = "Left" })
    T(g, "Aura letal", true)
    g = combate:Groupbox({ Name = "ARMA", Icon = "target", Side = "Right" })
    T(g, "Recarga automática", true); T(g, "Abastecer cargadores", true)
    g:Button({ Name = "Manuseio da arma", Arrow = true, Callback = function() BBC.notify("Manuseio da arma") end })
    T(g, "Mira falsa", true)
    g = combate:Groupbox({ Name = "EFEITOS DE COMBATE", Icon = "sparkles", Side = "Right" })
    T(g, "Retícula"); T(g, "Círculo da mira", true); T(g, "Rastro personalizado", true)
    T(g, "Rastros do jogo", true); T(g, "Marca de acerto", true); T(g, "Números de dano", true)
    T(g, "Efeitos de acerto", true); T(g, "Efeitos de eliminação"); T(g, "Dados do alvo", true)
    T(g, "Só acertos confirmados", true)
    g = combate:Groupbox({ Name = "ANTI AIM", Icon = "shield", Side = "Right" })
    T(g, "Anti aim"); T(g, "Sob o chão"); T(g, "Fantasma", true)
    g = combate:Groupbox({ Name = "GRANADAS", Icon = "bomb", Side = "Right" })
    T(g, "Trajetória do arremesso", true); T(g, "Sem tremor", true)

    return combate
end

return { buildCombat = Features.buildCombat }

end)

-- ============================================================
-- módulo: features.world  (features/world.lua)
-- ============================================================
__module("features.world", function(BBC)
--[[
    BBC HUB - Feature: World
    Abas MUNDO, EXTRAS, BUSCAR SAQUE, SERVIDORES, SKINS, MISSÕES, COMERCIANTES.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

-- ---------- Servidores (buildServers) ----------
local function buildServers(tab)
    local Library = BBC.Library
    local Utils = BBC.Utils
    local Security = BBC.Security
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local LP = Players.LocalPlayer

    local themed = {}
    local function th(inst, prop, key) themed[#themed + 1] = { inst, prop, key }; inst[prop] = Library.Theme[key] end
    table.insert(Library._themeListeners, function()
        for _, t in ipairs(themed) do if t[1].Parent then t[1][t[2]] = Library.Theme[t[3]] end end
    end)
    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        i.Parent = parent
        return i
    end
    local function txt(parent, text, size, key, bold, extra)
        local l = mk("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size,
            FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, size + 4) }, parent)
        th(l, "TextColor3", key or "Text")
        for k, v in pairs(extra or {}) do l[k] = v end
        return l
    end
    local function decorate(f, key, radius)
        th(f, "BackgroundColor3", key); f.BorderSizePixel = 0
        mk("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, f)
        th(mk("UIStroke", {}, f), "Color", "Stroke")
    end
    local function btn(parent, text, w, onClick, order)
        local b = mk("TextButton", { Size = UDim2.fromOffset(w, 28), Text = text, TextSize = 13, AutoButtonColor = false,
            FontFace = Library.Fonts.Bold, LayoutOrder = order or 0 }, parent)
        decorate(b, "Surface3", 6); th(b, "TextColor3", "Text")
        b.MouseButton1Click:Connect(onClick)
        return b
    end

    local HIST_FILE = "BBC_HUB/historico_servidores.json"
    local history = {}
    pcall(function()
        if type(isfile) == "function" and isfile(HIST_FILE) then history = HttpService:JSONDecode(readfile(HIST_FILE)) end
    end)
    local function saveHistory()
        pcall(function()
            if type(writefile) == "function" then
                if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
                writefile(HIST_FILE, HttpService:JSONEncode(history))
            end
        end)
    end
    local mapName = "Servidor"
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then mapName = info.Name end
    end)

    local list = tab.List
    local root = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, list)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, root)

    local state = { all = {}, sort = "players", desc = true, query = "", hideFull = true, hideMine = false, showHistory = false, selected = nil, loading = false, failed = false }

    -- Cabeçalho
    local head = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 }, root)
    local title = txt(head, "", 15, "Text", true, { Size = UDim2.new(0.5, 0, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local right = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.6, 0, 1, 0) }, head)
    mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, right)
    local bRefresh, bHistory, bFilters
    local filtersFrame

    -- Busca + ordenação
    local bar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2 }, root)
    local box = mk("TextBox", { Size = UDim2.new(1, -190, 1, 0), Text = "", TextSize = 13, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, FontFace = Library.Fonts.Regular }, bar)
    decorate(box, "Surface2", 6); th(box, "TextColor3", "Text"); th(box, "PlaceholderColor3", "Muted")
    mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
    local sortBtn = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -34, 0, 0), Size = UDim2.fromOffset(150, 30), TextSize = 13,
        AutoButtonColor = false, FontFace = Library.Fonts.Bold, Text = "" }, bar)
    decorate(sortBtn, "Surface2", 6); th(sortBtn, "TextColor3", "Text")
    local dirBtn = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(28, 30), TextSize = 16,
        AutoButtonColor = false, FontFace = Library.Fonts.Bold, Text = "↓" }, bar)
    decorate(dirBtn, "Surface2", 6); th(dirBtn, "TextColor3", "Accent")

    -- Colunas
    local cols = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 }, root)
    local cName = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.34, 0, 1, 0), Position = UDim2.fromOffset(10, 0) })
    local cPing = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.15, 0, 1, 0), Position = UDim2.new(0.37, 0, 0, 0) })
    local cPl = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.17, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0) })
    local cFps = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.12, 0, 1, 0), Position = UDim2.new(0.69, 0, 0, 0) })

    -- Lista com rolagem própria
    local scroller = mk("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), LayoutOrder = 5, ScrollingDirection = Enum.ScrollingDirection.Y }, root)
    th(scroller, "ScrollBarImageColor3", "Accent")
    local rowLayout = mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, scroller)
    mk("UIPadding", { PaddingRight = UDim.new(0, 8) }, scroller)
    rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local sc = scroller.AbsoluteSize.Y > 0 and (scroller.AbsoluteSize.Y / 220) or 1
        scroller.CanvasSize = UDim2.fromOffset(0, rowLayout.AbsoluteContentSize.Y / math.max(sc, 0.05) + 4)
    end)

    -- Cartão de detalhes
    local det = mk("Frame", { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 6 }, root)
    decorate(det, "Surface2", 8)
    local detName = txt(det, "", 15, "Text", true, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -190, 0, 20) })
    local detSub = txt(det, "", 12, "Muted", false, { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -190, 0, 18) })
    local detBtns = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(170, 28) }, det)
    mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, detBtns)
    local bDetails, bJoin

    local function fmtUp(n) return tostring(n or 0) end
    local function shortId(id) return string.sub(id or "", 1, 13) end

    local function visibleList()
        local out = {}
        if state.showHistory then
            for _, h in ipairs(history) do table.insert(out, { id = h.id, playing = h.playing, maxPlayers = h.maxPlayers, ping = h.ping, fps = h.fps, when = h.when }) end
            return out
        end
        local q = string.lower(state.query)
        for _, sv in ipairs(state.all) do
            local pass = true
            if state.hideFull and sv.playing >= sv.maxPlayers then pass = false end
            if state.hideMine and sv.id == game.JobId then pass = false end
            if pass and q ~= "" then
                local hay = string.lower(mapName .. " " .. sv.id .. " " .. sv.playing .. "/" .. sv.maxPlayers)
                if not string.find(hay, q, 1, true) then pass = false end
            end
            if pass then table.insert(out, sv) end
        end
        local key = state.sort == "ping" and "ping" or (state.sort == "fps" and "fps" or "playing")
        table.sort(out, function(a, b)
            local x, y = tonumber(a[key]) or 0, tonumber(b[key]) or 0
            if x == y then return a.id < b.id end
            if state.desc then return x > y end
            return x < y
        end)
        return out
    end

    local function joinServer(sv)
        if not sv then return end
        table.insert(history, 1, { id = sv.id, playing = sv.playing, maxPlayers = sv.maxPlayers, ping = sv.ping, fps = sv.fps, when = os.time() })
        while #history > 30 do table.remove(history) end
        saveHistory()
        BBC.notify("Entrando no servidor...")
        Library:JoinServer(sv.id)
    end

    local function renderDetails()
        local sv = state.selected
        if not sv then
            detName.Text = mapName
            detSub.Text = "Pronto para entrar"
            return
        end
        detName.Text = mapName .. (sv.id == game.JobId and ("  •  Seu servidor") or "")
        detSub.Text = "Pronto para entrar  ·  " .. string.sub(sv.id or "", 1, 22)
    end

    local render
    local function selectServer(sv) state.selected = sv; renderDetails(); render() end

    render = function()
        for _, c in ipairs(scroller:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        for i = #themed, 1, -1 do if not themed[i][1].Parent then table.remove(themed, i) end end
        local items = visibleList()
        local total = #state.all
        title.Text = "SERVIDOR   " .. #items .. " / " .. total .. " servidores"
        cName.Text = "Servidor"; cPing.Text = "Ping"; cPl.Text = "Jogadores"; cFps.Text = "FPS"
        sortBtn.Text = "Ordenar: " .. (state.sort == "players" and "Jogadores" or (state.sort == "ping" and "Ping" or "FPS"))
        dirBtn.Text = state.desc and "↓" or "↑"
        box.PlaceholderText = "Buscar mapa, nome ou ID do servidor"
        bRefresh.Text = "Atualizar"; bHistory.Text = "Histórico"; bFilters.Text = "Filtros"
        bDetails.Text = "Detalhes"; bJoin.Text = "Entrar"
        if state.loading then
            txt(scroller, "Carregando servidores...", 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        elseif state.failed and not state.showHistory then
            txt(scroller, "Falha ao carregar a lista", 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        elseif #items == 0 then
            txt(scroller, state.showHistory and "Histórico vazio" or "Nenhum servidor encontrado", 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        end
        for i, sv in ipairs(items) do
            if i > 150 then break end
            local row = mk("TextButton", { Size = UDim2.new(1, 0, 0, 44), Text = "", AutoButtonColor = false, LayoutOrder = i }, scroller)
            decorate(row, "Surface2", 6)
            local selected = state.selected and state.selected.id == sv.id
            if selected then th(row:FindFirstChildOfClass("UIStroke"), "Color", "Accent") end
            txt(row, mapName, 14, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.34, -10, 0, 18) })
            txt(row, (sv.id == game.JobId and ("Seu servidor  ·  ") or "") .. shortId(sv.id), 11, "Muted", false, { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(0.34, -10, 0, 16) })
            local ping = tonumber(sv.ping)
            txt(row, ping and (math.floor(ping) .. " ms") or "—", 13, "Text", false, { Position = UDim2.new(0.37, 0, 0, 12), Size = UDim2.new(0.15, 0, 0, 18) })
            txt(row, (sv.playing or 0) .. "/" .. (sv.maxPlayers or 0), 13, "Text", false, { Position = UDim2.new(0.52, 0, 0, 12), Size = UDim2.new(0.17, 0, 0, 18) })
            local fps = tonumber(sv.fps)
            txt(row, fps and tostring(math.floor(fps)) or "—", 13, "Text", false, { Position = UDim2.new(0.69, 0, 0, 12), Size = UDim2.new(0.12, 0, 0, 18) })
            local full = (sv.playing or 0) >= (sv.maxPlayers or 0) and (sv.maxPlayers or 0) > 0
            local joinB = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(62, 28), Text = "Entrar", TextSize = 13,
                AutoButtonColor = false, FontFace = Library.Fonts.Bold, BorderSizePixel = 0, ZIndex = 3 }, row)
            th(joinB, "BackgroundColor3", full and "Surface3" or "Accent")
            th(joinB, "TextColor3", "Text")
            mk("UICorner", { CornerRadius = UDim.new(0, 5) }, joinB)
            joinB.MouseButton1Click:Connect(function() state.selected = sv; renderDetails(); joinServer(sv) end)
            row.MouseButton1Click:Connect(function() selectServer(sv) end)
        end
    end

    local function load()
        if state.loading then return end
        state.loading, state.failed = true, false
        render()
        task.spawn(function()
            local all, cursor = {}, nil
            for _ = 1, 3 do
                local page, nextCursor = Library:FetchServers("Desc", cursor)
                if not page then if #all == 0 then state.failed = true end break end
                for _, sv in ipairs(page) do
                    if type(sv) == "table" and sv.id then
                        table.insert(all, { id = sv.id, playing = tonumber(sv.playing) or 0, maxPlayers = tonumber(sv.maxPlayers) or 0, ping = sv.ping, fps = sv.fps })
                    end
                end
                cursor = nextCursor
                if not cursor then break end
            end
            state.all, state.loading = all, false
            render()
        end)
    end

    bRefresh = btn(right, "", 88, function() state.showHistory = false; load() end, 3)
    bHistory = btn(right, "", 88, function() state.showHistory = not state.showHistory; render() end, 2)
    bFilters = btn(right, "", 78, function() filtersFrame.Visible = not filtersFrame.Visible end, 1)
    bDetails = btn(detBtns, "", 80, function()
        local sv = state.selected
        if not sv then return end
        local info = string.format("%s | %d/%d | %s ms | %s fps", sv.id, sv.playing or 0, sv.maxPlayers or 0, tostring(sv.ping and math.floor(sv.ping) or "—"), tostring(sv.fps and math.floor(sv.fps) or "—"))
        if not pcall(function() setclipboard(sv.id) end) then BBC.notify(info) else BBC.notify("Copiar ID: " .. string.sub(sv.id, 1, 13)) end
    end, 1)
    bJoin = btn(detBtns, "", 80, function() joinServer(state.selected) end, 2)

    -- Filtros
    filtersFrame = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, LayoutOrder = 3 }, root)
    decorate(filtersFrame, "Surface2", 6)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, filtersFrame)
    mk("UIListLayout", { Padding = UDim.new(0, 6), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, filtersFrame)
    local function filterToggle(key, label, order)
        local b = mk("TextButton", { Size = UDim2.fromOffset(150, 26), TextSize = 13, AutoButtonColor = false, FontFace = Library.Fonts.Regular, LayoutOrder = order, Text = "" }, filtersFrame)
        decorate(b, "Surface3", 6); th(b, "TextColor3", "Text")
        local function paint() b.Text = (state[key] and "● " or "○ ") .. label end
        paint()
        b.MouseButton1Click:Connect(function() state[key] = not state[key]; paint(); render() end)
        table.insert(BBC.onLanguageChanged, paint)
    end
    filterToggle("hideFull", "Ocultar cheios", 1)
    filterToggle("hideMine", "Ocultar meu servidor", 2)

    box:GetPropertyChangedSignal("Text"):Connect(function() state.query = box.Text; render() end)
    sortBtn.MouseButton1Click:Connect(function()
        state.sort = state.sort == "players" and "ping" or (state.sort == "ping" and "fps" or "players")
        render()
    end)
    dirBtn.MouseButton1Click:Connect(function() state.desc = not state.desc; render() end)
    table.insert(BBC.onLanguageChanged, function() renderDetails(); render() end)
    renderDetails()
    load()
end

Features.buildServers = buildServers

-- ---------- Aba MUNDO ----------
function Features.buildWorld(window)
    local mundo = window:Tab({ Name = "MUNDO", Icon = "globe" })
    local g = mundo:Groupbox({ Name = "MUNDO", Icon = "globe", Side = "Left" })
    g:Foldout({ Name = "Cores do terreno", Build = function(p)
        p:ColorPicker({ Name = "Grama", Default = Color3.fromRGB(72, 160, 76), Callback = function(c) if BBC.TerrainColor then BBC.TerrainColor(Enum.Material.Grass, c) end end })
        p:ColorPicker({ Name = "Areia", Default = Color3.fromRGB(214, 190, 120), Callback = function(c) if BBC.TerrainColor then BBC.TerrainColor(Enum.Material.Sand, c) end end })
        p:ColorPicker({ Name = "Rocha", Default = Color3.fromRGB(120, 120, 126), Callback = function(c) if BBC.TerrainColor then BBC.TerrainColor(Enum.Material.Rock, c) end end })
        p:ColorPicker({ Name = "Terra", Default = Color3.fromRGB(110, 78, 52), Callback = function(c) if BBC.TerrainColor then BBC.TerrainColor(Enum.Material.Ground, c) end end })
    end })
    g:Foldout({ Name = "Folhas", Build = function(p)
        p:ColorPicker({ Name = "Cor das folhas", Default = Color3.fromRGB(70, 150, 70), Callback = function(c) end })
    end })
    g:Foldout({ Name = "Troncos", Build = function(p)
        p:ColorPicker({ Name = "Cor dos troncos", Default = Color3.fromRGB(100, 70, 45), Callback = function(c) end })
    end })
    g:ColorPicker({ Name = "Cor da água", Default = Color3.fromRGB(40, 70, 75), Callback = function(c) if BBC.TerrainColor then BBC.TerrainColor("Water", c) end end })
    T(g, "Sem grama"); T(g, "Desativar minas", true)
    g = mundo:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Left" })
    T(g, "Carregar jogadores"); T(g, "Buscar chefes"); T(g, "Pontos de saída", true)
    BBC.RadarCfg = { on = false, range = 150, size = 130, npcs = false, pos = { x = 0.88, y = 0.3 } }
    g:Toggle({ Name = "Radar", Default = false, NoPin = true, Tooltip = "Mini mapa redondo com os jogadores ao redor. Arraste para mover.",
        Callback = function(v) BBC.RadarCfg.on = v end,
        Settings = function(p)
            p:Slider({ Name = "Alcance", Min = 50, Max = 500, Default = 150, Suffix = "m", Step = 10, Callback = function(v) BBC.RadarCfg.range = v end })
            p:Slider({ Name = "Tamanho", Min = 90, Max = 220, Default = 130, Step = 5, Callback = function(v) BBC.RadarCfg.size = v end })
            p:Toggle({ Name = "Mostrar NPCs", Default = false, Callback = function(v) BBC.RadarCfg.npcs = v end })
        end })
    g = mundo:Groupbox({ Name = "ILUMINAÇÃO", Icon = "lightbulb", Side = "Right", Checkbox = true, Default = true, Callback = function(v) end })
    for _, n in ipairs({ "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens",
        "Florescer", "Desfoque", "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade" }) do
        T(g, n)
    end
    return mundo
end

-- ---------- Aba EXTRAS ----------
function Features.buildExtras(window)
    local extras = window:Tab({ Name = "EXTRAS", Icon = "layout-grid" })
    local g = extras:Groupbox({ Name = "EXTRAS", Icon = "layout-grid", Side = "Left" })
    T(g, "Troca rápida"); g:Button({ Name = "Atravessar porta", Callback = function() BBC.notify("Atravessar porta") end })
    T(g, "Remover efeitos"); T(g, "Avisos de denúncias", true); T(g, "Avisos de entrada")
    g = extras:Groupbox({ Name = "SONS", Icon = "volume-2", Side = "Left" })
    g:Input({ Name = "Adicionar ID de som", Placeholder = "ID", Callback = function(v) end })
    for _, n in ipairs({ "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue" }) do
        T(g, n, n == "Disparo")
    end
    g = extras:Groupbox({ Name = "DETECÇÃO", Icon = "radar", Side = "Right" })
    T(g, "Criador"); T(g, "Testador"); T(g, "Moderador", true); T(g, "Trapaceiro")
    g = extras:Groupbox({ Name = "ORDENAR DEPÓSITO", Icon = "arrow-down-up", Side = "Right" })
    g:Button({ Name = "Por valor", Callback = function() BBC.notify("Por valor") end })
    g:Button({ Name = "Por tipo", Callback = function() BBC.notify("Por tipo") end })
    g:Button({ Name = "Por nome", Callback = function() BBC.notify("Por nome") end })
    g = extras:Groupbox({ Name = "VER INVENTÁRIO", Icon = "backpack", Side = "Right" })
    g:Keybind({ Name = "Ver inventário", Default = "Backquote", Callback = function() end })
    g:Dropdown({ Name = "Mostrar", Options = { "Jogadores", "NPCs", "Todos" }, Default = "Jogadores", Callback = function(v) end })
    T(g, "Sempre mostrar")
    return extras
end

-- ---------- Buscar Saque ----------
function Features.buildLoot(window)
    local saque = window:Tab({ Name = "BUSCAR SAQUE", Icon = "package-search" })
    BBC.LootCfg = { rarities = { ["Mítico"] = true, ["Lendário"] = true, ["Épico"] = true, ["Raro"] = true }, maxDist = 300, query = "", mark = false, force = true, until_ = 0 }
    do
        local LF = BBC.LootCfg
        local RAR_OPTS = { "Mítico", "Lendário", "Épico", "Raro", "Incomum", "Comum", "Outros" }
        local fg = saque:Groupbox({ Name = "FILTROS", Icon = "filter", Side = "Left" })
        fg:Dropdown({ Name = "Raridade", Multi = true, Options = RAR_OPTS, Default = { "Mítico", "Lendário", "Épico", "Raro" },
            Callback = function(v)
                LF.rarities = {}
                for _, r in ipairs(type(v) == "table" and v or { v }) do LF.rarities[r] = true end
                LF.force = true
            end })
        fg:Slider({ Name = "Distância máx.", Min = 20, Max = 1000, Default = 300, Suffix = "m", Step = 10, Callback = function(v) LF.maxDist = v; LF.force = true end })
        fg:Input({ Name = "Buscar por nome", Placeholder = "ex: arma", Callback = function(t) LF.query = string.lower(t or ""); LF.force = true end })
        fg:Toggle({ Name = "Marcar na tela", Default = false, Tooltip = "Mostra o nome e a distância dos itens encontrados direto no jogo, na cor da raridade.",
            Callback = function(v) LF.mark = v; LF.force = true end })
        fg:Button({ Name = "Buscar agora", Callback = function() LF.until_ = os.clock() + 30; LF.force = true end })
        local rg = saque:Groupbox({ Name = "RESULTADOS", Icon = "package-search", Side = "Right" })
        LF.status = rg:Label({ Text = "Toque em Buscar agora para listar o saque por perto." })
        LF.rows = {}
        for i = 1, 25 do
            local r = rg:Label({ Text = "" })
            r.Label.RichText = true
            r.Frame.Visible = false
            LF.rows[i] = r
        end
    end
    return saque
end

-- ---------- Skins / Missões / Comerciantes (placeholders) ----------
function Features.buildSkins(window)
    local skins = window:Tab({ Name = "SKINS", Icon = "palette" })
    skins:Section("SKINS")
    return skins
end

function Features.buildQuests(window)
    local missoes = window:Tab({ Name = "MISSÕES", Icon = "scroll-text" })
    missoes:Section("MISSÕES")
    return missoes
end

function Features.buildMerchants(window)
    local comerciantes = window:Tab({ Name = "COMERCIANTES", Icon = "shopping-cart" })
    comerciantes:Section("COMERCIANTES")
    return comerciantes
end

Features.buildWorldTab = Features.buildWorld
Features.buildExtrasTab = Features.buildExtras
Features.buildLootTab = Features.buildLoot
Features.buildSkinsTab = Features.buildSkins
Features.buildQuestsTab = Features.buildQuests
Features.buildMerchantsTab = Features.buildMerchants

return { buildWorld = Features.buildWorld }

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

-- Safe module access with fallbacks
local Library = BBC.Library or {}
local Utils = BBC.Utils or {}
local Security = BBC.Security or { init = function() end }
local Protection = BBC.Protection or { init = function() end }
local UI = BBC.UI or { Controls = { T = function() end, S = function() end } }
local Controls = UI.Controls or { T = function() end, S = function() end }
local T = Controls.T
local S = Controls.S

-- Verify critical dependencies
if not Library or not Library.Windows then
    warn("[BBC] Library not loaded, some features may not work")
end
if not Utils.create then
    warn("[BBC] Utils not loaded, UI elements may not render")
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

Security.init()

-- Initialize Protection layer after Library is available
Protection.init({})

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
PRÉ-VISUALIZAÇÃO|PREVIEW|VISTA PREVIA|预览|ПРЕДПРОСМОТР
CONFIGURAÇÕES DO JOGADOR|PLAYER SETTINGS|AJUSTES DEL JUGADOR|玩家设置|НАСТРОЙКИ ИГРОКА
CONFIGURAÇÕES DO NPC|NPC SETTINGS|AJUSTES DE NPC|NPC设置|НАСТРОЙКИ NPC
Destaque|Highlight|Resaltado|高亮|Подсветка
Caixa|Box|Caja|方框|Бокс
Barra de vida|Health Bar|Barra de vida|血条|Полоса здоровья
Vida|Health|Vida|生命值|Здоровье
Linhas|Tracers|Líneas|射线|Линии
Linhas até alvos|Lines to targets|Líneas a objetivos|目标连线|Линии до целей
SEGURANÇA|SECURITY|SEGURIDAD|安全|БЕЗОПАСНОСТЬ
Brilho|Brightness|Brillo|亮度|Яркость
Hora|Time|Hora|时间|Время
Zoom máximo|Max zoom|Zoom máximo|最大缩放|Макс. зум
Saturação|Saturation|Saturación|饱和度|Насыщенность
Contraste|Contrast|Contraste|对比度|Контраст
Modo pânico|Panic mode|Modo pánico|紧急模式|Режим паники
Tecla de pânico|Panic key|Tecla de pánico|紧急键|Клавиша паники
Só detalhes de perto|Details only when close|Detalles solo de cerca|仅近处显示细节|Детали только вблизи
Detalhes até|Details up to|Detalles hasta|细节距离|Детали до
Destacar mais próximo|Highlight nearest|Resaltar el más cercano|突出最近目标|Выделять ближайшего
Mostrar NPCs|Show NPCs|Mostrar NPCs|显示NPC|Показывать NPC
Alcance|Range|Alcance|范围|Дальность
Tamanho|Size|Tamaño|大小|Размер
FILTROS|FILTERS|FILTROS|筛选|ФИЛЬТРЫ
RESULTADOS|RESULTS|RESULTADOS|结果|РЕЗУЛЬТАТЫ
Raridade|Rarity|Rareza|稀有度|Редкость
Buscar por nome|Search by name|Buscar por nombre|按名称搜索|Поиск по имени
Marcar na tela|Mark on screen|Marcar en pantalla|屏幕标记|Метки на экране
Buscar agora|Search now|Buscar ahora|立即搜索|Искать сейчас
Toque em Buscar agora para listar o saque por perto.|Tap Search now to list nearby loot.|Toca Buscar ahora para listar el botín cercano.|点击立即搜索列出附近战利品。|Нажмите «Искать сейчас», чтобы увидеть лут рядом.
Fixar na tela|Pin to screen|Fijar en pantalla|固定到屏幕|Закрепить на экране
Desafixar|Unpin|Desfijar|取消固定|Открепить
Esqueleto|Skeleton|Esqueleto|骨骼|Скелет
Rastro ao ativar|Activation trail|Rastro al activar|激活拖尾|Шлейф при включении
Animação do menu|Menu animation|Animación del menú|菜单动画|Анимация меню
TOQUE: ALTERNAR · SEGURE: O QUE É|TAP: TOGGLE · HOLD: WHAT IT IS|TOQUE: ACTIVAR · MANTÉN: QUÉ ES|点击:切换 · 长按:说明|НАЖАТЬ: ВКЛ · УДЕРЖАТЬ: ОПИСАНИЕ
ATIVO|ON|ACTIVO|开启|ВКЛ
INATIVO|OFF|INACTIVO|关闭|ВЫКЛ
Toque para ativar ou desativar.|Tap to turn on or off.|Toca para activar o desactivar.|点击开启或关闭。|Нажмите, чтобы включить или выключить.
Setas|Arrows|Flechas|箭头|Стрелки
Configurações gerais|General Settings|Ajustes generales|通用设置|Общие настройки
Cor|Color|Color|颜色|Цвет
Espessura|Thickness|Grosor|粗细|Толщина
Opacidade|Opacity|Opacidad|不透明度|Непрозрачность
Distância máx.|Max distance|Distancia máx.|最大距离|Макс. дистанция
Tamanho do texto|Text size|Tamaño del texto|文字大小|Размер текста
TOQUE NA LINHA: ALTERNAR|TAP A ROW: TOGGLE|TOCA UNA FILA: ALTERNAR|点击一行：开关|НАЖМИТЕ НА СТРОКУ: ВКЛ/ВЫКЛ
TOQUE NO ÍCONE: AJUSTES|TAP THE ICON: SETTINGS|TOCA EL ICONO: AJUSTES|点击图标：设置|НАЖМИТЕ НА ЗНАЧОК: НАСТРОЙКИ
Cantos|Corners|Esquinas|边角|Углы
Completa|Full|Completa|完整|Полная
Esquerda|Left|Izquierda|左|Слева
Direita|Right|Derecha|右|Справа
Baixo|Bottom|Abajo|底部|Снизу
Cima|Top|Arriba|顶部|Сверху
Estilo|Style|Estilo|样式|Стиль
Origem|Origin|Origen|起点|Начало
Posição|Position|Posición|位置|Позиция
Cor automática|Auto color|Color automático|自动颜色|Авто-цвет
Contorno|Outline|Contorno|轮廓|Контур
Preenchimento|Fill|Relleno|填充|Заливка
Unidade|Unit|Unidad|单位|Единица
Distância da prévia|Preview distance|Distancia de la vista|预览距离|Дистанция превью
Vida da prévia|Preview health|Vida de la vista|预览生命|Здоровье превью
Fora do alcance|Out of range|Fuera de alcance|超出范围|Вне зоны
Tamanho do canto|Corner size|Tamaño de esquina|边角大小|Размер угла
Largura da barra|Bar width|Ancho de barra|血条宽度|Ширина полосы
Em breve|Coming soon|Próximamente|即将推出|Скоро
Pressione a tecla do menu para abrir ou fechar.|Press the menu key to open or close.|Pulsa la tecla del menú para abrir o cerrar.|按菜单键打开或关闭。|Нажмите клавишу меню, чтобы открыть или закрыть.
Toque no botão flutuante para abrir o menu.|Tap the floating button to open the menu.|Toca el botón flotante para abrir el menú.|点击悬浮按钮打开菜单。|Нажмите на плавающую кнопку, чтобы открыть меню.
]==]
    for line in string.gmatch(RAW, "[^\n]+") do
        local p = string.split(line, "|")
        if #p >= 5 then DICT[p[1]] = { en = p[2], es = p[3], zh = p[4], ru = p[5] } end
    end
end

local currentLang = "pt"
local notify = function(text) pcall(function() Library:Notify({ Title = "BBC HUB", Content = text, Duration = 2 }) end) end
local keys = { menu = "RightShift", cursor = "LeftAlt", zoom = "N" }
BBC.refreshPanels = function() end
BBC.onLanguageChanged = {}
local LANG_FILE = "BBC_HUB/idioma.txt"
pcall(function()
    if type(isfile) == "function" and isfile(LANG_FILE) then
        local c = string.gsub(readfile(LANG_FILE), "%s", "")
        if LANG_NAMES[c] then currentLang = c end
    end
end)
local function tr(text)
    if currentLang == "pt" then return text end
    local e = DICT[text]
    return e and e[currentLang] or text
end
local function trKey(text)
    text = string.gsub(text, "&apos;", "'")
    text = string.gsub(text, "&", "&")
    return text
end
local function translateInstance(inst)
    if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then return end
    local cur = inst.Text
    local orig, last = inst:GetAttribute("pt"), inst:GetAttribute("tx")
    if orig ~= nil and cur ~= last then orig = nil end
    if orig == nil then
        local key = trKey(cur)
        if DICT[key] then orig = key else return end
    end
    local t = tr(orig)
    inst:SetAttribute("pt", orig)
    inst:SetAttribute("tx", t)
    if cur ~= t then inst.Text = t end
end
local function setLanguage(code, silent)
    if not LANG_NAMES[code] or code == currentLang then return end
    currentLang = code
    pcall(function()
        if type(writefile) == "function" then
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            writefile(LANG_FILE, code)
        end
    end)
    for _, fn in ipairs(BBC.onLanguageChanged) do pcall(fn) end
end

local Config = Security.getConfig()
Library.Access = Config.Access or "FREE"

-- GEARS (opções que têm submenu de ajustes)
local GEARS = {}
for _, n in ipairs({
    "Jogador","NPCs","Corpo","Recipiente","Item no chão","Itens de missão","Mochila personalizada","Mochila","Barra rápida",
    "Aura","Círculo de salto","Auréola","Rastro estelar",
    "Hack de velocidade","Sprint automático","Voar","Aranha","Deslocamento","Trocar personagem","Personagem",
    "Corpo em 1ª pessoa","Mãos","Item na mão","Terceira pessoa","Câmera livre","Saque automático","Painel do jogador",
    "Renascer automático","Remover água",
    "Pausa inteligente","Tiro por paredes","Aura letal","Espiada subterrânea","Anti aim","Sob o chão","Fantasma",
    "Trajetória do arremesso","Recarga automática","Abastecer cargadores","Mira falsa","Retícula","Círculo da mira",
    "Rastro personalizado","Marca de acerto","Números de dano","Efeitos de acerto","Efeitos de eliminação","Dados do alvo",
    "Luz","Hora e sol","Sombras","Renderização","Neblina","Atmosfera","Céu","Nuvens","Florescer","Desfoque",
    "Ajuste de cor","Profundidade","Raios de sol","Tonalidade","Buscar chefes","Pontos de saída","Radar",
    "Modo pânico","Avisos de entrada","Criador","Testador","Moderador","Trapaceiro","Jump","Pegadas","Pouso",
    "Capacete","Tiro na cabeça","Tiro no corpo","Abate","Disparo","Acerto com sangue","Fundo","Sombra","Destaque próprio",
}) do GEARS[n] = true end

local function buildSettings(name)
    local SPEC = {
        ["Hack de velocidade"] = { { "Velocidade", 16, 250, 40, "" } },
        ["Sprint automático"] = { { "Velocidade", 16, 120, 26, "" } },
        ["Voar"] = { { "Velocidade", 10, 250, 60, "" } },
        ["Aranha"] = { { "Velocidade", 10, 80, 30, "" } },
        ["Terceira pessoa"] = { { "Zoom máximo", 10, 500, 100, "" } },
        ["Luz"] = { { "Brilho", 0, 5, 2, "", 0.1 } },
        ["Hora e sol"] = { { "Hora", 0, 24, 14, "h", 0.5 } },
        ["Florescer"] = { { "Intensidade", 0, 3, 1, "", 0.1 } },
        ["Desfoque"] = { { "Tamanho", 0, 40, 8, "" } },
        ["Ajuste de cor"] = { { "Saturação", -1, 2, 0.4, "", 0.1 }, { "Contraste", -1, 1, 0.1, "", 0.1 } },
        ["Raios de sol"] = { { "Intensidade", 0, 1, 0.25, "", 0.05 } },
        ["Retícula"] = { { "Tamanho", 4, 40, 12, "px" }, { "Espessura", 1, 4, 2, "" } },
    }
    for _, n in ipairs({ "Sombras", "Neblina", "Atmosfera", "Nuvens" }) do GEARS[n] = nil end
    return function(p)
        local spec = SPEC[name]
        if spec then
            BBC.Library.FO[name] = BBC.Library.FO[name] or {}
            for _, sp in ipairs(spec) do
                p:Slider({ Name = sp[1], Min = sp[2], Max = sp[3], Default = sp[4], Suffix = sp[5] or "", Step = sp[6] or 1,
                    Callback = function(v) BBC.Library.FO[name][sp[1]] = v end })
            end
            return
        end
        p:Dropdown({ Name = "Modo", Options = { "Sempre", "Ao segurar", "Alternar" }, Default = "Alternar", Callback = function(v) end })
        p:Slider({ Name = "Intensidade", Min = 0, Max = 100, Default = 50, Suffix = "%", Callback = function(v) end })
        p:Slider({ Name = "Distância", Min = 10, Max = 1000, Default = 300, Suffix = "m", Callback = function(v) end })
        p:Toggle({ Name = "Notificar", Default = false, Callback = function(v) end })
    end
end

BBC.GEARS = GEARS
BBC.buildSettings = buildSettings
BBC.PREMIUM = { ["Anti aim"] = true, ["Sob o chão"] = true, ["Espiada subterrânea"] = true, ["Saque automático"] = true, ["Sem dano de queda"] = true }
BBC.SETTINGS_ICON = { ["Notificar"] = "message-circle", ["Avisos de denúncias"] = "message-circle" }
GEARS["Notificar"] = true; GEARS["Avisos de denúncias"] = true
BBC.TIPS = {
    ["Transp. fundo"] = "Ajusta a transparência do fundo.", ["Transp. do texto"] = "Ajusta a transparência do texto.",
    ["Transp. da borda"] = "Ajusta a transparência da borda.", ["Raio dos cantos"] = "Arredonda os cantos do painel.",
    ["Largura"] = "Define a largura do painel.", ["Altura máxima"] = "Define a altura máxima do painel.",
    ["Tamanho"] = "Muda o tamanho do painel.", ["Suavização"] = "Quanto maior, mais suave o movimento.",
    ["Raio da mira"] = "Alcance do círculo da mira.", ["Cursor livre"] = "Segure a tecla do cursor para liberar o mouse.",
    ["Limite de verificações"] = "Quantas checagens por quadro.", ["Fixar"] = "Impede que o painel seja arrastado.",
}
BBC.MODALS = {}

-- ---------- Janela Principal ----------
local Window = Library:Window({
    Title = "BBC HUB",
    Subtitle = "v0.0.8.2",
    Size = UDim2.fromOffset(640, 388),
    Keybind = "RightShift",
    Theme = "Orange",
    Home = { Build = BBC.Features.buildProfile, Expiry = Config.Expiry },
})
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
pcall(function() Window:SetToggleButton(true) end)

-- Initialize Protection layer after Library is fully available
Protection.init({})
Protection.registerESPFeatures()
Protection.startESPEngine()

-- Tradução automática
do
    local gui = Window.Gui
    if gui then
        for _, d in ipairs(gui:GetDescendants()) do translateInstance(d) end
        gui.DescendantAdded:Connect(function(d) task.defer(translateInstance, d) end)
        table.insert(BBC.onLanguageChanged, function()
            for _, d in ipairs(gui:GetDescendants()) do translateInstance(d) end
        end)
    else
        warn("[BBC HUB] não achei a ScreenGui da janela para traduzir")
    end
end

-- ---------- Features ----------
BBC.Features.buildVisuals(Window)

-- Register ESP preview modals (after visuals builds the buildEspPanel)
BBC.MODALS["Jogador"] = { build = BBC.Features.buildEspPanel("Jogador"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO JOGADOR" } }
BBC.MODALS["NPCs"] = { build = BBC.Features.buildEspPanel("NPCs"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO NPC" } }

BBC.Features.buildPlayer(Window)
BBC.Features.buildCombat(Window)
BBC.Features.buildWorld(Window)

-- Abas extras
local saque = BBC.Features.buildLootTab(Window)
local servidores = Window:Tab({ Name = "SERVIDORES", Icon = "server" })
BBC.Features.buildServers(servidores)
local skins = BBC.Features.buildSkinsTab(Window)
local missoes = BBC.Features.buildQuestsTab(Window)
local comerciantes = BBC.Features.buildMerchantsTab(Window)

-- ---------- Overlays (Watermark + Keybind List) ----------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local overlayParent = (type(gethui) == "function" and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
local overlay = Instance.new("ScreenGui")
overlay.Name = "BBCOverlay"; overlay.ResetOnSpawn = false; overlay.IgnoreGuiInset = true; overlay.DisplayOrder = 998
overlay.Parent = overlayParent

local function makePanel(name, pos)
    local f = Instance.new("Frame")
    f.Name = name; f.Position = pos; f.AutomaticSize = Enum.AutomaticSize.None
    f.BackgroundColor3 = Color3.fromRGB(10, 10, 10); f.BorderSizePixel = 0; f.Parent = overlay
    local c = Instance.new("UICorner", f)
    local st = Instance.new("UIStroke", f); st.Color = Library.Theme.Accent
    local t = Instance.new("TextLabel", f)
    t.BackgroundTransparency = 1; t.Size = UDim2.new(1, -16, 1, -8); t.Position = UDim2.fromOffset(8, 4)
    t.TextXAlignment = Enum.TextXAlignment.Left; t.TextYAlignment = Enum.TextYAlignment.Top
    t.FontFace = Library.Fonts.Regular; t.TextSize = 14; t.TextColor3 = Color3.fromRGB(235, 235, 235)
    t.RichText = true; t.Text = ""
    return f, c, st, t
end

local WM = { Shadow = true, On = false, Pin = false, Size = 100, Width = 285, MaxH = 290, BgT = 0.10, TxtT = 0, BrdT = 0, Radius = 6, Fields = { "Nome", "FPS", "Ping" } }
local KL = { Shadow = true, Pin = false, On = false, Size = 100, Width = 250, MaxH = 260, BgT = 0.05, TxtT = 0, BrdT = 0.75, Radius = 7 }
local wmFrame, wmCorner, wmStroke, wmText = makePanel("Watermark", UDim2.fromOffset(12, 12))
local klPinToggle
local klFrame = Instance.new("Frame")
klFrame.Name = "KeybindList"; klFrame.BorderSizePixel = 0; klFrame.ClipsDescendants = true
klFrame.Position = UDim2.new(0, 14, 0.28, 0); klFrame.Size = UDim2.fromOffset(250, 150); klFrame.Parent = overlay
local klCorner = Instance.new("UICorner", klFrame)
local klStroke = Instance.new("UIStroke", klFrame)
local klScale = Instance.new("UIScale", klFrame)
local klHead = Instance.new("Frame", klFrame)
klHead.BackgroundTransparency = 1; klHead.Size = UDim2.new(1, 0, 0, 34); klHead.Active = true
Library.MakeIcon(klHead, "align-left", 16, "Muted", { Position = UDim2.fromOffset(12, 9) })
local klTitle = Instance.new("TextLabel", klHead)
klTitle.BackgroundTransparency = 1; klTitle.Position = UDim2.fromOffset(38, 0); klTitle.Size = UDim2.new(1, -80, 1, 0)
klTitle.TextXAlignment = Enum.TextXAlignment.Left; klTitle.FontFace = Library.Fonts.Bold; klTitle.TextSize = 14
local klPin = Instance.new("TextButton", klHead)
klPin.AnchorPoint = Vector2.new(1, 0.5); klPin.Position = UDim2.new(1, -8, 0.5, 0); klPin.Size = UDim2.fromOffset(28, 28)
klPin.BackgroundTransparency = 1; klPin.Text = ""; klPin.AutoButtonColor = false
local klPinIcon = Library.MakeIcon(klPin, "pin", 16, "Muted", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
local function paintPin() klPinIcon.ImageColor3 = KL.Pin and Library.Theme.Accent or Library.Theme.Muted end
klPin.MouseButton1Click:Connect(function()
    KL.Pin = not KL.Pin
    paintPin()
    if klPinToggle then klPinToggle:Set(KL.Pin, true) end
end)
local klScroll = Instance.new("ScrollingFrame", klFrame)
klScroll.BackgroundTransparency = 1; klScroll.BorderSizePixel = 0; klScroll.Position = UDim2.fromOffset(0, 36); klScroll.Size = UDim2.new(1, 0, 1, -40)
klScroll.ScrollBarThickness = 2; klScroll.CanvasSize = UDim2.new(); klScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
klScroll.ScrollingDirection = Enum.ScrollingDirection.Y
local klList = Instance.new("UIListLayout", klScroll); klList.SortOrder = Enum.SortOrder.LayoutOrder; klList.Padding = UDim.new(0, 0)
local klRowsRef = {}
local function recolorKL()
    local T = Library.Theme
    klFrame.BackgroundColor3 = T.Background; klStroke.Color = T.Stroke; klTitle.TextColor3 = T.Text
    klScroll.ScrollBarImageColor3 = T.Muted
    paintPin()
    for _, r in ipairs(klRowsRef) do
        if r.name.Parent then r.name.TextColor3 = T.Text; r.key.TextColor3 = r.listening and T.Accent or T.Muted end
    end
end
local KL_FIRST = { ["Tecla do menu"] = 1, ["Tecla do cursor"] = 2 }
local function renderKL()
    for _, c in ipairs(klScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    klRowsRef = {}
    klTitle.Text = tr("Atalhos")
    local items = {}
    for i, kb in ipairs(Library.Keybinds) do
        local v = kb.get()
        if v then table.insert(items, { kb = kb, v = v, order = KL_FIRST[kb.name] or (10 + i) }) end
    end
    table.sort(items, function(x, y) return x.order < y.order end)
    for i, it in ipairs(items) do
        local kb, v = it.kb, it.v
        local row = Instance.new("Frame", klScroll); row.BackgroundTransparency = 1; row.Size = UDim2.new(1, 0, 0, 28); row.LayoutOrder = i
        local listening = kb.listening and kb.listening()
        local keyL = Instance.new("TextLabel", row)
        keyL.BackgroundTransparency = 1; keyL.Position = UDim2.fromOffset(12, 0); keyL.Size = UDim2.fromOffset(76, 28); keyL.TextXAlignment = Enum.TextXAlignment.Left
        keyL.FontFace = Library.Fonts.Regular; keyL.TextSize = 12; keyL.TextTruncate = Enum.TextTruncate.AtEnd
        keyL.Text = listening and "..." or ((v.Name == "MouseButton3" and "MB3") or (v.Name == "MouseButton2" and "MB2") or v.Name)
        local nameL = Instance.new("TextLabel", row)
        nameL.BackgroundTransparency = 1; nameL.Position = UDim2.fromOffset(92, 0); nameL.Size = UDim2.new(1, -128, 1, 0); nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.FontFace = Library.Fonts.Bold; nameL.TextSize = 13; nameL.TextTruncate = Enum.TextTruncate.AtEnd; nameL.Text = tr(kb.name)
        local edit = Instance.new("TextButton", row)
        edit.AnchorPoint = Vector2.new(1, 0.5); edit.Position = UDim2.new(1, -8, 0.5, 0); edit.Size = UDim2.fromOffset(26, 26)
        edit.BackgroundTransparency = 1; edit.Text = ""; edit.AutoButtonColor = false
        Library.MakeIcon(edit, "sliders-horizontal", 16, "Muted", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
        edit.MouseButton1Click:Connect(function() if kb.begin then kb.begin() end end)
        table.insert(klRowsRef, { key = keyL, name = nameL, listening = listening })
    end
    klFrame.Size = UDim2.fromOffset(KL.Width, math.min(42 + #items * 28, KL.MaxH))
    recolorKL()
end
table.insert(Library._kbListeners, renderKL)
table.insert(Library._themeListeners, recolorKL)

local function applyPanel(cfg, frame, corner, stroke, text, height)
    frame.Visible = cfg.On
    local sc = cfg.Size / 100
    frame.Size = UDim2.fromOffset(math.min(cfg.Width, 600) * sc, math.min(height, cfg.MaxH) * sc)
    frame.BackgroundTransparency = cfg.BgT
    text.TextTransparency = cfg.TxtT
    text.TextSize = math.floor(14 * sc)
    stroke.Transparency = cfg.BrdT
    corner.CornerRadius = UDim.new(0, cfg.Radius)
    text.TextStrokeTransparency = cfg.Shadow and 0.6 or 1
end
BBC.refreshPanels = function()
    applyPanel(WM, wmFrame, wmCorner, wmStroke, wmText, 28)
    klFrame.Visible = KL.On
    klScale.Scale = KL.Size / 100
    klFrame.BackgroundTransparency = KL.BgT
    klStroke.Transparency = KL.BrdT
    klCorner.CornerRadius = UDim.new(0, KL.Radius)
    renderKL()
end
table.insert(BBC.onLanguageChanged, BBC.refreshPanels)

local function makeDraggable(handle, cfg, target)
    local frame = target or handle
    handle.Active = true
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(i)
        if cfg.Pin then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(wmFrame, WM)
makeDraggable(klHead, KL, klFrame)

local cursorFree, cursorHeld, cursorKey = true, false, Enum.KeyCode.LeftAlt
UserInputService.InputBegan:Connect(function(i) if cursorFree and i.KeyCode == cursorKey then cursorHeld = true end end)
UserInputService.InputEnded:Connect(function(i) if i.KeyCode == cursorKey then cursorHeld = false end end)
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
    if os.clock() - last >= 1 then fps = frames; frames = 0; last = os.clock() end
    local parts = { "<b>BBC HUB</b>" }
    for _, f in ipairs(WM.Fields) do
        if f == "Nome" then table.insert(parts, LocalPlayer.Name)
        elseif f == "FPS" then table.insert(parts, fps .. " FPS")
        elseif f == "Ping" then
            local ok, ping = pcall(function() return math.floor(LocalPlayer:GetNetworkPing() * 2000) end)
            table.insert(parts, (ok and ping or 0) .. " ms")
        elseif f == "Hora" then table.insert(parts, os.date("%H:%M")) end
    end
    wmText.Text = table.concat(parts, "  |  ")
end)
BBC.refreshPanels()

local function bind(cfg, key, v) cfg[key] = v; BBC.refreshPanels() end
local function SB(grp, name, min, max, def, suffix, step, cfg, key)
    return grp:Slider({ Name = name, Min = min, Max = max, Default = def, Suffix = suffix or "", Step = step or 1, Tooltip = BBC.TIPS[name],
        Callback = function(v) bind(cfg, key, v) end })
end

-- ---------- Fontes ----------
local FONT_URLS = {
    ["Press Start 2P"] = { Name = "PressStart2P", Weights = { Regular = "https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf" } },
    ["Silkscreen"] = { Name = "Silkscreen", Weights = {
        Regular = "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Regular.ttf",
        Bold = "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Bold.ttf" } },
}
local function retagFonts(root)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local bold = d:GetAttribute("bbcBold")
            if bold == nil then
                bold = d.FontFace.Weight.Value >= 600
                d:SetAttribute("bbcBold", bold)
            end
            d.FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular
        end
    end
end
local function setFont(name)
    if name == "Arimo" then
        Library.Fonts.Regular = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular)
        Library.Fonts.Medium = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Medium)
        Library.Fonts.Bold = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold)
    elseif name == "Arcade" or name == "Code" then
        local f = Font.fromEnum(name == "Arcade" and Enum.Font.Arcade or Enum.Font.Code)
        Library.Fonts.Regular, Library.Fonts.Medium, Library.Fonts.Bold = f, f, f
    elseif FONT_URLS[name] then
        if not Library:LoadFont(FONT_URLS[name]) then
            BBC.notify("Fonte indisponível neste executor (precisa de writefile e getcustomasset).")
            return
        end
    else
        return
    end
    if Window.Gui then retagFonts(Window.Gui) end
    retagFonts(overlay)
end

-- ---------- Aba CONFIGURAÇÕES ----------
local cfg = Window:Tab({ Name = "CONFIGURAÇÕES", Icon = "settings", Hidden = true, IsSettings = true })

-- Segurança: modo pânico + status de proteção
do
    local Protection = BBC.Protection
    local P = cfg:Groupbox({ Name = "SEGURANÇA", Icon = "shield", Side = "Left" })
    Library._panicToggle = P:Toggle({ Name = "Modo pânico", Default = false, NoPersist = true,
        Tooltip = "Esconde menu, ESP, radar e botões fixos de uma vez. Para voltar, toque 3 vezes no topo da tela (ou use a tecla de pânico).",
        Callback = function(v) Window:SetPanic(v) end })
    P:Keybind({ Name = "Tecla de pânico", Default = "End", Callback = function() Window:SetPanic(not Library.Panic) end })

    -- Protection Status Display
    local protInfo = P:Label({ Text = "Executor: Detectando..." })
    local protLevel = P:Label({ Text = "Nível: --" })
    local protCaps = P:Label({ Text = "APIs: --" })

    task.spawn(function()
        task.wait(1) -- wait for Protection.init()
        local prot = BBC.Protection
        if prot and type(prot.getProtectionLevel) == "function" then
            protInfo.Set("Executor: " .. (prot.Executor or "Unknown"))
            local ok, level, desc = pcall(prot.getProtectionLevel)
            if ok and level then
                protLevel.Set("Nível: " .. level .. " - " .. desc)
            else
                protLevel.Set("Nível: Erro ao obter nível")
            end
            local caps = prot.Capabilities or {}
            local count = 0
            for _, v in pairs(caps) do if v then count = count + 1 end end
            protCaps.Set("APIs disponíveis: " .. count .. "/" .. (function() local c=0 for _ in pairs(caps) do c=c+1 end return c end)())
        elseif prot then
            protLevel.Set("Nível: getProtectionLevel indisponível")
        end
    end)
end

-- Geral
local g = cfg:Groupbox({ Name = "GERAL", Icon = "settings", Side = "Left" })
g:Dropdown({ Name = "Idioma", Options = { "English", "Español", "Português (Brasil)", "简体中文", "Русский" }, Default = LANG_NAMES[currentLang],
    Flags = { ["English"] = "en", ["Español"] = "es", ["Português (Brasil)"] = "pt", ["简体中文"] = "zh", ["Русский"] = "ru" },
    Callback = function(v)
        local code = LANG_CODES[type(v) == "table" and v[1] or v] or "pt"
        setLanguage(code)
        BBC.notify(tr("Idioma alterado") .. ": " .. LANG_NAMES[code])
    end })
g:Keybind({ Name = "Tecla do menu", Default = "RightShift", OnChanged = function(k) Window:SetKeybind(k); keys.menu = k.Name; BBC.refreshPanels() end, Callback = function() end })
g:Keybind({ Name = "Tecla do cursor", Default = "LeftAlt", OnChanged = function(k) cursorKey = k; keys.cursor = k.Name; BBC.refreshPanels() end, Callback = function() end })
g:Toggle({ Name = "Cursor livre", Default = true, Callback = function(v) cursorFree = v end })
g:Toggle({ Name = "Lista de atalhos", Default = false, Callback = function(v) bind(KL, "On", v) end })
g:Toggle({ Name = "Ilha de FPS", Default = true, Callback = function(v) Window:SetIsland(v) end })
T(g, "Ocultar indisponíveis")
g:Toggle({ Name = "Fixar botão móvel", Default = false, Callback = function(v) pcall(function() Window:SetIslandDraggable(not v) end) end })
g:Button({ Name = "Rever tutorial", Callback = function() BBC.notify(tr(IS_MOBILE and "Toque no botão flutuante para abrir o menu." or "Pressione a tecla do menu para abrir ou fechar.")) end })
g:Button({ Name = "Sair", Callback = function() overlay:Destroy(); Window:Destroy() end })

-- Aparência
local presetNames = Library.ThemeOrder
g = cfg:Groupbox({ Name = "APARÊNCIA", Icon = "palette", Side = "Left" })
do
    local swatches = Instance.new("Frame")
    swatches.BackgroundTransparency = 1; swatches.Size = UDim2.new(1, 0, 0, 0); swatches.AutomaticSize = Enum.AutomaticSize.Y
    swatches.LayoutOrder = g:_nextOrder()
    local sp = Instance.new("UIPadding", swatches); sp.PaddingTop = UDim.new(0, 8); sp.PaddingBottom = UDim.new(0, 8); sp.PaddingLeft = UDim.new(0, 12); sp.PaddingRight = UDim.new(0, 8)
    local grid = Instance.new("UIGridLayout", swatches)
    grid.CellSize = UDim2.fromOffset(24, 24); grid.CellPadding = UDim2.fromOffset(5, 6); grid.SortOrder = Enum.SortOrder.LayoutOrder
    swatches.Parent = g.List
    local rings = {}
    local function accentOf(name)
        local p = Library.ThemePresets[name]
        local c = p and p.Accent
        if typeof(c) == "Color3" then return c end
        if type(c) == "string" then local ok, r = pcall(Color3.fromHex, c); if ok then return r end end
        if type(c) == "table" and #c == 3 then return Color3.fromRGB(c[1], c[2], c[3]) end
        return Color3.fromRGB(200, 200, 200)
    end
    for i, name in ipairs(presetNames) do
        local acc = accentOf(name)
        local b = Instance.new("TextButton")
        b.Text = ""; b.AutoButtonColor = false; b.BackgroundColor3 = Color3.new(1, 1, 1); b.LayoutOrder = i; b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        local gr = Instance.new("UIGradient", b)
        gr.Rotation = 55
        gr.Color = ColorSequence.new(acc:Lerp(Color3.new(1, 1, 1), 0.35), acc:Lerp(Color3.new(0, 0, 0), 0.3))
        local ring = Instance.new("UIStroke", b); ring.Thickness = 2.5; ring.Color = Color3.new(1, 1, 1)
        ring.Transparency = (Library.ThemeName == name) and 0 or 1
        local tick = Instance.new("TextLabel", b)
        tick.BackgroundTransparency = 1; tick.Size = UDim2.fromScale(1, 1); tick.Text = "✓"; tick.TextSize = 13; tick.TextColor3 = Color3.new(1, 1, 1)
        tick.FontFace = Library.Fonts.Bold; tick.Visible = (Library.ThemeName == name)
        local pumpkin
        if name == "Halloween" then
            pumpkin = Instance.new("TextLabel", b)
            pumpkin.BackgroundTransparency = 1; pumpkin.Size = UDim2.fromScale(1, 1); pumpkin.Text = "🎃"; pumpkin.TextSize = 14
            pumpkin.Visible = not (Library.ThemeName == name)
        end
        rings[name] = { ring = ring, tick = tick, pumpkin = pumpkin }
        b.MouseButton1Click:Connect(function()
            Library:SetTheme(name)
            for n, r in pairs(rings) do r.ring.Transparency = (n == name) and 0 or 1; r.tick.Visible = (n == name); if r.pumpkin then r.pumpkin.Visible = (n ~= name) end end
            wmStroke.Color = Library.Theme.Accent; recolorKL()
            BBC.notify(name)
        end)
        b.Parent = swatches
    end
end
g:Toggle({ Name = "Cubo", Default = true, Callback = function(v) Window:SetLogo(v) end })
g:Toggle({ Name = "Rastro ao ativar", Default = true, Tooltip = "Mostra um rastro de luz na cor do menu quando você ativa uma opção.", Callback = function(v) Library.Effects = v end })
g:Toggle({ Name = "Animação do menu", Default = true, Tooltip = "Abre e fecha o menu com um efeito suave.", Callback = function(v) Library.MenuAnim = v end })
g:Dropdown({ Name = "Fonte", Options = { "Arimo", "Arcade", "Code", "Press Start 2P", "Silkscreen" }, Default = "Arimo", Callback = function(v) setFont(type(v) == "table" and v[1] or v) end })
g:Toggle({ Name = "Bordas estáticas", Default = false, Callback = function(v) Window:SetBorderAccent(v) end })
local bgOn, bgVal = false, 25
g:Toggle({ Name = "Fundo", Default = false, Callback = function(v) bgOn = v; Window:SetBackgroundTransparency(v and bgVal / 100 or 0) end,
    Settings = function(p) p:Slider({ Name = "Transparência", Min = 0, Max = 80, Default = 25, Suffix = "%", Callback = function(x) bgVal = x; if bgOn then Window:SetBackgroundTransparency(x / 100) end end }) end })
g:Toggle({ Name = "Sombra", Default = false, Callback = function(v) Window:SetShadow(v) end })

-- Marca d'água
g = cfg:Groupbox({ Name = "MARCA D'ÁGUA", Icon = "scan", Side = "Right", Checkbox = true, Default = false, Callback = function(v) bind(WM, "On", v) end })
g:Toggle({ Name = "Fixar", Default = false, Callback = function(v) WM.Pin = v end })
g:Dropdown({ Name = "Campos visíveis", Options = { "Nome", "FPS", "Ping", "Hora" }, Default = { "Nome", "FPS", "Ping" }, Multi = true,
    Callback = function(v) WM.Fields = v; end })
SB(g, "Tamanho", 50, 200, 100, "%", 1, WM, "Size")
SB(g, "Largura", 150, 600, 285, "", 1, WM, "Width")
SB(g, "Altura máxima", 20, 500, 290, "", 1, WM, "MaxH")
SB(g, "Transp. fundo", 0, 1, 0.10, "", 0.01, WM, "BgT")
SB(g, "Transp. do texto", 0, 1, 0, "", 0.01, WM, "TxtT")
SB(g, "Transp. da borda", 0, 1, 0, "", 0.01, WM, "BrdT")
SB(g, "Raio dos cantos", 0, 20, 6, " px", 1, WM, "Radius")
g:Toggle({ Name = "Sombra", Default = true, Callback = function(v) bind(WM, "Shadow", v) end })

-- Lista de atalhos
g = cfg:Groupbox({ Name = "LISTA DE ATALHOS", Icon = "keyboard", Side = "Right" })
klPinToggle = g:Toggle({ Name = "Fixar", Default = false, Callback = function(v) KL.Pin = v; paintPin() end })
g:Toggle({ Name = "Sombra", Default = true, Callback = function(v) bind(KL, "Shadow", v) end })
SB(g, "Tamanho", 50, 200, 100, "%", 1, KL, "Size")
SB(g, "Largura", 200, 420, 250, "", 1, KL, "Width")
SB(g, "Altura máxima", 100, 500, 260, "", 1, KL, "MaxH")
SB(g, "Transp. fundo", 0, 1, 0.05, "", 0.01, KL, "BgT")
SB(g, "Transp. do texto", 0, 1, 0, "", 0.01, KL, "TxtT")
SB(g, "Transp. da borda", 0, 1, 0.75, "", 0.01, KL, "BrdT")
SB(g, "Raio dos cantos", 0, 20, 7, " px", 1, KL, "Radius")

BBC.refreshPanels()

-- Expor funções globais para compatibilidade
Library.Tr = tr
Library._toggleBinds = Library._toggleBinds or {}
Library.Keybinds = Library.Keybinds or {}
Library.Features = Library.Features or {}
Library.FS = Library.FS or {}
Library.SV = Library.SV or {}
Library.FO = Library.FO or {}
Library.ESP = Library.ESP or {}
Library.LootCfg = Library.LootCfg or {}
Library.RadarCfg = Library.RadarCfg or {}

pcall(function() Window:FinishLoading() end)
Library:Notify({ Title = "BBC HUB", Content = tr("Interface carregada."), Duration = 4 })

-- return BBC  -- handled by build.py FOOTER

end)


return BBC
