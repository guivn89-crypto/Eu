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