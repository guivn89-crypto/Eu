-- ============ 00_head.luau :: Cabeçalho, biblioteca base (fontes, tema, utilidades, Registry, atalhos) ============
-- ============================================================
--  BBCLib - biblioteca própria do BBC HUB
--  (a AirFlow serviu só de exemplo de estrutura)
--
--  Mapa do arquivo (monolito, na ordem em que aparece):
--   1. Biblioteca base ... fontes, tema, utilidades, Registry, atalhos de tecla
--   2. Elementos de UI ... Toggle, Slider, Dropdown, Button, Keybind, Input, cor
--   3. Layout ............ Window, abas, Groupbox, modais, tooltip, busca
--   4. Menu .............. abas e opções, temas, idiomas, perfis, marca d'água
--   5. Painéis ........... ESP (prévia Chams), radar, busca de saque, servidores
--   6. Motor ............. ESP no jogo, radar, loot, zona do modo pânico
--   7. Entrada ........... intro, FinishLoading, autocontrole, aviso final
-- ============================================================
local Library = (function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Library = {
    Windows = {}, Registry = {}, _themeListeners = {}, _bindings = {},
    ThemeName = "Orange", Theme = {}, Access = "FREE", Keybinds = {}, _kbListeners = {},
    Tr = function(t) return t end, ESPMaster = {},
}
-- Eventos da biblioteca também são desconectados no fechamento e param após
-- erros consecutivos, sem deixar um callback defeituoso repetindo para sempre.
Library._running, Library._uiConnections = true, {}
local function safeConnect(signal, callback)
    local failures, conn = 0, nil
    conn = signal:Connect(function(...)
        if not Library._running then return end
        local ok, err = pcall(callback, ...)
        if ok then failures = 0; return end
        failures += 1
        if failures == 1 then
            warn("[BBC] Evento da interface: " .. tostring(err))
            if Library.Diagnostics then Library.Diagnostics:record("interface", err) end
        end
        if failures >= 5 then
            if conn then pcall(function() conn:Disconnect() end) end
            warn("[BBC] Evento da interface interrompido após erros.")
        end
    end)
    for old in pairs(Library._uiConnections) do if not old.Connected then Library._uiConnections[old] = nil end end
    Library._uiConnections[conn] = true
    return conn
end
function Library:_kbChanged() for _, fn in ipairs(Library._kbListeners) do pcall(fn) end end
-- uma escuta de tecla por vez: começar um atalho cancela o anterior e evita
-- o estado "escutando" ficar travado para sempre
Library._kbOwner, Library._kbCancel = nil, nil
function Library:_kbListen(owner, cancelFn)
    if Library._kbOwner ~= nil and Library._kbOwner ~= owner and Library._kbCancel then pcall(Library._kbCancel) end
    Library._kbOwner, Library._kbCancel = owner, cancelFn
    Library._listening = true
end
function Library:_kbDone()
    Library._kbOwner, Library._kbCancel = nil, nil
    Library._listening = false
    Library._lastBind = os.clock()
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
    if type(opts) ~= "table" then return false end
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[BBC] fontes personalizadas precisam de writefile, isfile e getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    if type(name) ~= "string" or #name > 64 or not name:match("^[%w_%-]+$") then return false end
    local weights = opts.Weights
    if type(weights) ~= "table" then return false end
    local folder = "BBC_HUB_Fontes"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then makefolder(folder) end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local info = FONT_WEIGHTS[weightName]
        if info and type(url) == "string" and #url <= 2048 and url:match("^https://") then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then
                ok = pcall(function()
                    local data = game:HttpGet(url)
                    assert(type(data) == "string" and #data > 0 and #data <= 8 * 1024 * 1024, "fonte inválida ou muito grande")
                    writefile(path, data)
                end)
            end
            if ok then
                local valid, asset = pcall(getcustomasset, path)
                if valid and type(asset) == "string" then table.insert(faces, { name = weightName, weight = info[1], style = "normal", assetId = asset }) end
            end
        end
    end
    if #faces == 0 then return false end
    local familyPath = folder .. "/" .. name .. ".json"
    if not pcall(function() writefile(familyPath, HttpService:JSONEncode({ name = name, faces = faces })) end) then return false end
    local okFamily, family = pcall(getcustomasset, familyPath)
    if not okFamily or type(family) ~= "string" then return false end
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
Library.MakeTheme = preset
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

-- ---------- Utilidades ----------
-- Algumas bibliotecas usam uma API opcional do executor para proteger GUIs
-- antes de inseri-las. A chamada não comprova invisibilidade ou segurança.
Library.GuiProtection = { attempted = 0, succeeded = 0, failed = 0, unavailable = 0, _tracked = setmetatable({}, { __mode = "k" }) }
function Library:ProtectGui(gui)
    local state = self.GuiProtection
    if state._tracked[gui] then return true end
    local protect, unprotect
    if type(protectgui) == "function" then
        protect, unprotect = protectgui, type(unprotectgui) == "function" and unprotectgui or nil
    elseif type(syn) == "table" and type(syn.protect_gui) == "function" then
        protect, unprotect = syn.protect_gui, type(syn.unprotect_gui) == "function" and syn.unprotect_gui or nil
    end
    if not protect then
        state.unavailable += 1
        if not state._warnedUnavailable then
            state._warnedUnavailable = true
            warn("[BBC] Executor sem API de proteção de GUI; interface pode ser detectada.")
        end
        return false
    end
    state.attempted += 1
    local ok, result = pcall(protect, gui)
    if not ok or result == false then
        state.failed += 1
        if not state._warnedFailure then
            state._warnedFailure = true
            warn("[BBC] API de proteção de GUI falhou; interface pode ser detectada.")
        end
        return false
    end
    state.succeeded += 1
    state._tracked[gui] = { unprotect = unprotect }
    -- A notificação é melhor esforço; nem todos os executores expõem Destroying.
    pcall(function() safeConnect(gui.Destroying, function() self:UnprotectGui(gui) end) end)
    return true
end
function Library:UnprotectGui(gui)
    local entry = self.GuiProtection._tracked[gui]
    if not entry then return end
    self.GuiProtection._tracked[gui] = nil
    if entry.unprotect then pcall(entry.unprotect, gui) end
end
function Library:UnprotectAllGuis()
    for gui in pairs(self.GuiProtection._tracked) do self:UnprotectGui(gui) end
end
local function create(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    if class == "ScreenGui" or class == "BillboardGui" then Library:ProtectGui(i) end
    if parent then i.Parent = parent end
    return i
end
local function corner(parent, r) return create("UICorner", { CornerRadius = UDim.new(0, r or 4) }, parent) end
local function stroke(parent, key, transparency, thickness)
    local s = create("UIStroke", { Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
    bind(s, "Color", key or "Stroke")
    return s
end
local function pad(parent, l, r, t, b)
    return create("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0) }, parent)
end
local function listLayout(parent, padding, dir)
    return create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding or 0), FillDirection = dir or Enum.FillDirection.Vertical }, parent)
end
local function tween(inst, props, t, style)
    local tw = TweenService:Create(inst, TweenInfo.new(Library.ReduceMotion and 0 or (t or 0.15), style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[BBC] " .. tostring(err)) end
end
local function label(parent, text, size, key, bold, props)
    local l = create("TextLabel", {
        BackgroundTransparency = 1, Text = text or "", TextSize = size or 13, FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, (size or 13) + 4),
    }, parent)
    bind(l, "TextColor3", key or "Text")
    for k, v in pairs(props or {}) do l[k] = v end
    return l
end

-- ---------- Ícones (Lucide) ----------
local lucide = nil
local iconsGaveUp = true
local allIcons = {}
local GLYPHS = {
    ["eye"] = "◉", ["user"] = "☺", ["crosshair"] = "⌖", ["globe"] = "◍", ["layout-grid"] = "▦", ["package-search"] = "▣",
    ["server"] = "▤", ["palette"] = "✎", ["scroll-text"] = "☰", ["shopping-cart"] = "▲", ["settings"] = "⚙", ["search"] = "⌕",
    ["flame"] = "♨", ["save"] = "▣", ["box"] = "◆", ["sliders-horizontal"] = "≡", ["message-circle"] = "✉", ["lock"] = "⚿", ["snowflake"] = "❄", ["x"] = "✕",
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
    local g = create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = GLYPHS[rec.name] or "•", TextSize = 15, FontFace = Library.Fonts.Bold }, rec.img)
    bind(g, "TextColor3", function() return rec.img.ImageColor3 end)
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
-- Ícones locais: não executa Lua remoto nem cacheado.

local icon
function icon(parent, name, size, key, props)
    local img = create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size or 16, size or 16), ScaleType = Enum.ScaleType.Fit }, parent)
    bind(img, "ImageColor3", key or "Text")
    for k, v in pairs(props or {}) do img[k] = v end
    setIcon(img, name)
    return img
end
Library.MakeIcon = icon

-- ---------- Servidores ----------
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

-- ---------- FPS compartilhado ----------
Library._fps = 60
do
    local frames, last = 0, os.clock()
    safeConnect(RunService.RenderStepped, function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then Library._fps = math.floor(frames / (now - last) + 0.5); frames = 0; last = now end
    end)
end

-- ---------- Raiz da interface ----------
-- Testa a atribuição de Parent, não só a obtenção do serviço: alguns
-- executores retornam CoreGui/gethui mas não permitem inserir objetos nele.
function Library:ParentGui(gui)
    local seen = {}
    local function attempt(getParent, label)
        local ok, parent = pcall(getParent)
        if not ok or not parent then return nil end
        for _, previous in ipairs(seen) do if previous == parent then return nil end end
        table.insert(seen, parent)
        local assigned, same = pcall(function()
            gui.Parent = parent
            return gui.Parent == parent
        end)
        if assigned and same then
            self.GuiProtection.lastParent = label
            return parent
        end
        return nil
    end
    local root = attempt(function() if type(gethui) == "function" then return gethui() end end, "gethui")
        or attempt(function() return game:GetService("CoreGui") end, "CoreGui")
        or attempt(function()
            if not LocalPlayer then return nil end
            return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
        end, "PlayerGui")
    if not root then error("BBC: não foi possível inserir a interface em gethui, CoreGui ou PlayerGui") end
    return root
end
function Library:CreateRootGui(class, props)
    local gui = create(class, props)
    local ok, root = pcall(function() return self:ParentGui(gui) end)
    if not ok then
        self:UnprotectGui(gui)
        pcall(function() gui:Destroy() end)
        error(root)
    end
    return gui
end

-- ---------- Notificações ----------
local notifyGui, notifyHolder
function Library:Notify(opts)
    if not Library._running then return end
    opts = opts or {}
    if Library.Panic then return end   -- no modo pânico nada aparece
    if not notifyGui or not notifyGui.Parent then
        notifyGui = Library:CreateRootGui("ScreenGui", { Name = "BBCNotify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000 })
        notifyHolder = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(250, 400), BackgroundTransparency = 1 }, notifyGui)
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6) }, notifyHolder)
    end
    local active = 0
    for _, child in ipairs(notifyHolder:GetChildren()) do if child:IsA("Frame") then active += 1 end end
    if active >= 8 then return end
    for i = #Library._bindings, 1, -1 do
        if not Library._bindings[i][1].Parent then table.remove(Library._bindings, i) end
    end
    local card = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, BackgroundTransparency = 1 }, notifyHolder)
    bind(card, "BackgroundColor3", "Surface")
    corner(card, 5); stroke(card, "Stroke")
    local bar = create("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 }, card)
    bind(bar, "BackgroundColor3", "Accent"); corner(bar, 2)
    local inner = create("Frame", { Size = UDim2.new(1, -14, 0, 0), Position = UDim2.fromOffset(12, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, card)
    pad(inner, 0, 6, 7, 8); listLayout(inner, 2)
    if opts.Title then label(inner, opts.Title, 13, "Text", true, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 17) }) end
    if opts.Content then
        label(inner, opts.Content, 12, "Muted", false, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 16) })
    end
    card.BackgroundTransparency = 1
    tween(card, { BackgroundTransparency = 0 }, 0.2)
    local duration = tonumber(opts.Duration) or 3
    if duration ~= duration or duration == math.huge or duration == -math.huge then duration = 3 end
    task.delay(math.clamp(duration, 0.2, 30), function()
        if card.Parent then
            tween(card, { BackgroundTransparency = 1 }, 0.25)
            task.wait(0.27)
            card:Destroy()
        end
    end)
end

-- ============================================================
--  Elementos (compartilhados por abas, grupos e submenus)
-- ============================================================
local Container = {}
Container.__index = Container
function Container:_nextOrder()
    self._order = (self._order or 0) + 1
    return self._order
end
local function register(self, name, getter, setter, validate)
    Library.Registry[(self._path or "") .. "/" .. tostring(name)] = { name = tostring(name), get = getter, set = setter, validate = validate }
end
local function separator(parent)
    local s = create("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 1, -1), BorderSizePixel = 0, BackgroundTransparency = 0.5 }, parent)
    bind(s, "BackgroundColor3", "Stroke")
end
local function newOuter(self, name)
    local outer = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self:_nextOrder() }, self.List)
    outer:SetAttribute("SearchName", name or "")
    outer:SetAttribute("SearchTab", string.match(self._path or "", "^[^/]+") or "")
    outer:SetAttribute("SearchPath", self._path or "")
    outer:SetAttribute("SearchKey", (self._path or "") .. "/" .. tostring(name or ""))
    -- a busca usa esta lista em vez de varrer a GUI inteira a cada tecla
    if self.Window then
        local list = self.Window._search or {}
        self.Window._search = list
        list[#list + 1] = outer
    end
    listLayout(outer, 0)
    return outer
end
local function chipBox(parent)
    local c = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 0 }, parent)
    bind(c, "BackgroundColor3", "Surface2")
    corner(c, 4)
    local st = stroke(c, "Stroke", 0)
    return c, st
end

-- bandeiras desenhadas com quadrados (sem depender de imagens)
local function makeFlag(parent, code, props)
    local f = create("Frame", { Size = UDim2.fromOffset(22, 15), BorderSizePixel = 0, ClipsDescendants = true, BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
    for k, v in pairs(props or {}) do f[k] = v end
    corner(f, 2)
    local function rect(x, y, w, h, col, rot)
        return create("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = col, BorderSizePixel = 0, Rotation = rot or 0 }, f)
    end
    if code == "pt" then
        f.BackgroundColor3 = Color3.fromRGB(0, 155, 58)
        rect(6, 2.5, 10, 10, Color3.fromRGB(255, 222, 0), 45)
        local c = rect(7.5, 4.5, 7, 7, Color3.fromRGB(0, 39, 118)); corner(c, 4)
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
        local st = create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(2, -1), Size = UDim2.fromOffset(10, 10), Text = "★", TextSize = 10, TextColor3 = Color3.fromRGB(255, 222, 0), FontFace = Library.Fonts.Bold }, f)
        create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 1), Size = UDim2.fromOffset(6, 6), Text = "★", TextSize = 5, TextColor3 = Color3.fromRGB(255, 222, 0) }, f)
    elseif code == "ru" then
        rect(0, 5, 22, 5, Color3.fromRGB(0, 57, 166)); rect(0, 10, 22, 5, Color3.fromRGB(213, 43, 30))
    end
    return f
end
local function textWidth(text, size)
    local ok, b = pcall(function() return TextService:GetTextSize(tostring(text), size or 12, Enum.Font.Arimo, Vector2.new(1000, 60)) end)
    return ok and b.X or (#tostring(text) * 7)
end
-- segurar (toque) ou parar o mouse sobre uma linha mostra o nome e o que ela faz
-- TIPS é declarado aqui e preenchido mais abaixo, com a descrição de cada opção do menu
local TIPS = {}
local tipFor = nil   -- definido junto com o idioma; devolve a descrição no idioma atual
local function attachTip(self, row, name, tip, stateFn, extras, more)
    if not tip then
        local e = TIPS[name]
        if type(e) == "string" then tip = e elseif e then tip = (tipFor and tipFor(name)) or e.pt end
    end
    if (not tip or tip == "") and not stateFn then return end
    local win = self.Window
    local desc = (tip and tip ~= "") and tip or nil
    local function resolveDesc()
        if type(desc) == "function" then
            local ok, value = pcall(desc)
            return ok and value or nil
        end
        return desc
    end
    local token, hoverCount, shown, startPos = 0, 0, false, nil
    local isTouch = UserInputService.TouchEnabled and not (UserInputService.MouseEnabled or UserInputService.KeyboardEnabled)
    -- a linha e os objetos interativos dela (botão, campo, chip): assim o cartão
    -- abre também quando o mouse/toque está sobre o nome ou sobre o controle
    local targets = { row }
    if more then for _, o in ipairs(more) do if o then targets[#targets + 1] = o end end end
    for _, o in ipairs(targets) do
        safeConnect(o.InputBegan, function(i)
            local t = i.UserInputType
            if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                token += 1
                local my = token
                shown, startPos = false, i.Position
                task.delay(0.45, function()
                    if token == my and row.Parent then
                        shown = true
                        row:SetAttribute("TipHeld", true)   -- o toque de soltar não alterna a opção
                        win:_tip(name, resolveDesc(), row, stateFn, extras)
                    end
                end)
            end
        end)
        safeConnect(o.InputChanged, function(i)
            local t = i.UserInputType
            if startPos and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement) and (i.Position - startPos).Magnitude > 10 then token += 1 end
        end)
        safeConnect(o.InputEnded, function(i)
            local t = i.UserInputType
            if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                token += 1; startPos = nil
                if shown then
                    shown = false
                    win:_hideTip(extras and 4 or 0.9)
                    task.delay(0.25, function() row:SetAttribute("TipHeld", nil) end)
                end
            end
        end)
        safeConnect(o.MouseEnter, function()
            if isTouch then return end
            hoverCount += 1
            task.delay(0.8, function() if hoverCount > 0 and row.Parent then win:_tip(name, resolveDesc(), row, stateFn, extras) end end)
        end)
        safeConnect(o.MouseLeave, function()
            if isTouch then return end
            hoverCount = math.max(0, hoverCount - 1)
            if hoverCount == 0 then win:_hideTip(0.1) end
        end)
    end
end

-- rastro de luz na cor do menu quando uma opção é ativada (some sozinho)
Library.Effects = true
Library.MenuAnim = true
Library.AutoSave = true
Library.Panic = false
Library._panicListeners = {}
Library._panicGuis = {}
Library._toggleBinds = {}
local function activationFx(row, pill)
    if not Library.Effects or Library.ReduceMotion or not row.Parent then return end
    row.ClipsDescendants = true
    -- 1) feixe de luz atravessando a linha
    local beam = create("Frame", { Position = UDim2.new(-0.45, 0, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), BorderSizePixel = 0,
        BackgroundColor3 = Library.Theme.Accent, ZIndex = 2 }, row)
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.62), NumberSequenceKeypoint.new(1, 1) }) }, beam)
    local head = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0,
        BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.2, ZIndex = 2 }, beam)
    tween(beam, { Position = UDim2.new(1, 0, 0, 0) }, 0.7, Enum.EasingStyle.Quad)
    tween(head, { BackgroundTransparency = 1 }, 0.7)
    task.delay(0.8, function() beam:Destroy() end)
    -- 2) cópias do botão que ficam para trás e somem
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
    -- 3) anel de luz em volta do botão
    local ring = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -29, 0.5, 0), Size = UDim2.fromOffset(34, 18), BackgroundTransparency = 1, ZIndex = 2 }, row)
    corner(ring, 9)
    local rs = create("UIStroke", { Thickness = 2, Transparency = 0.15, Color = Library.Theme.Accent }, ring)
    tween(ring, { Size = UDim2.fromOffset(54, 28) }, 0.5, Enum.EasingStyle.Quad)
    tween(rs, { Transparency = 1 }, 0.5)
    task.delay(0.55, function() ring:Destroy() end)
end
local function subPanel(self, parentOuter, order, stableName)
    local panel = create("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false, LayoutOrder = order }, parentOuter)
    bind(panel, "BackgroundColor3", "Surface2")
    panel:SetAttribute("SearchPanel", true)
    corner(panel, 4); stroke(panel, "Stroke", 0.3)
    local inner = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, panel)
    pad(inner, 0, 0, 3, 3); listLayout(inner, 0)
    -- cada submenu precisa de um caminho próprio: antes todos usavam ".../sub" e
    -- as opções de ajustes de opções diferentes colidiam no mesmo registro
    local path
    if stableName then
        path = (self._path or "") .. "/settings/" .. stableName
    else
        local n = (self._subN or 0) + 1
        self._subN = n
        path = (self._path or "") .. "/sub" .. (n > 1 and n or "")
    end
    local sub = setmetatable({ List = inner, _order = 0, Window = self.Window, _path = path, Frame = panel }, Container)
    return sub, panel
end

-- ---------- Toggle ----------
function Container:Toggle(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    outer:SetAttribute("SearchKind", "Toggle")
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    local locked = (opts.Premium and Library.Access ~= "VIP") or opts.Disabled == true
    outer:SetAttribute("Unavailable", locked)
    if self.Window and self.Window._hideUnavailable then self.Window:_filter(self.Window._filterQuery) end
    if self.Window and self.Window._touchTarget then self.Window:_touchTarget(row, 30) end
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
    if state and opts.CanSet then
        local ok, allowed = pcall(opts.CanSet, true)
        if not ok or not allowed then state = false end
    end
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
        if locked then return v ~= true end
        if opts.CanSet then
            local ok, allowed = pcall(opts.CanSet, v == true)
            if not ok or not allowed then return false end
        end
        local previous = state
        state = v == true
        self.Value = state
        paint()
        if not silent and type(opts.Callback) == "function" then
            local ok, err = pcall(opts.Callback, state)
            if not ok then
                warn("[BBC] " .. tostring(opts.Name) .. ": " .. tostring(err))
                state, self.Value = previous, previous
                pcall(opts.Callback, previous)
                paint(true)
                if self._onChange then self._onChange(state) end
                return false
            end
        end
        if self._onChange then self._onChange(state) end
        return true
    end
    function obj:Get() return state end
    safeConnect(row.MouseButton1Click, function()
        if row:GetAttribute("TipHeld") then return end   -- foi um "segurar" para ver a ajuda
        if locked then
            Library:Notify({ Title = "BBC HUB", Content = Library.Tr(opts.Disabled and "Indisponível: implementação pendente." or "Recurso exclusivo VIP."), Duration = 2 })
            return
        end
        obj:Set(not state)
        if state then activationFx(row, pill) end
    end)
    if not (opts.NoSave or opts.NoPersist) then register(self, opts.Name, function() return state end, function(v) return obj:Set(v) end) end
    -- atalho de teclado (PC) e botão fixo na tela (celular); ambos entram no perfil salvo
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
            if obj:Set(not state) then
                Library:Notify({ Title = opts.Name, Content = state and "Ativado" or "Desativado", Duration = 1.2 })
            end
        end })
        table.insert(Library.Keybinds, { name = opts.Name, get = function() return bindKey end, listening = function() return false end,
            begin = function() Library:Notify({ Title = opts.Name, Content = "Segure a opção no menu e toque em Atalho para trocar.", Duration = 3 }) end })
        register(self, opts.Name .. "#tecla", function() return bindKey and bindKey.Name or nil end,
            function(v) bindKey = Library.ParseKey(v); Library:_kbChanged() end,
            function(v) return type(v) == "string" and Library.ParseKey(v) ~= nil end)
        register(self, opts.Name .. "#fixado", function()
            if not pinObj then return nil end
            local pp = pinObj.btn.Position
            return { x = pp.X.Scale, y = pp.Y.Scale }
        end, function(v)
            if type(v) == "table" and type(v.x) == "number" then adopt(win:_setPin(opts.Name, obj, true, v))
            else adopt(win:_setPin(opts.Name, obj, false)) end
        end, function(v) return type(v) == "table" and type(v.x) == "number" and type(v.y) == "number" and v.x >= 0 and v.x <= 1 and v.y >= 0 and v.y <= 1 end)
    end
    local function tipStatus()
        if opts.Disabled then return "pending" end
        if opts.Premium and Library.Access ~= "VIP" then return "vip" end
        local policy = Library.Safety
        if policy and policy.blocked[opts.Name] and (policy.enabled or policy.panic) then return "blocked" end
        return state
    end
    local function tipDescription()
        local tip = opts.Tooltip
        if type(tip) == "function" then local ok, value = pcall(tip); tip = ok and value or nil end
        if not tip then
            local e = TIPS[opts.Name]
            if type(e) == "string" then tip = e elseif e then tip = (tipFor and tipFor(opts.Name)) or e.pt end
        end
        local status = tipStatus()
        local reason = status == "pending" and "Indisponível: implementação pendente." or status == "vip" and "Recurso exclusivo VIP." or status == "blocked" and "Bloqueado pelo modo preventivo." or nil
        return (tip and tostring(tip) or "") .. (reason and ("\n" .. Library.Tr(reason)) or "")
    end
    if Library.Favorites and not opts.NoSave then
        extras = (not locked and extras) or {}
        local key = (self._path or "") .. "/" .. tostring(opts.Name)
        extras.isFavorite = function() return Library.Favorites:contains(key) end
        extras.toggleFavorite = function() return Library.Favorites:toggle(key) end
    elseif locked then extras = nil end
    attachTip(self, row, opts.Name, tipDescription, tipStatus, extras)
    bind(row, "BackgroundColor3", "Accent")
    safeConnect(row.MouseEnter, function() if not locked then tween(row, { BackgroundTransparency = 0.93 }, 0.12) end end)
    safeConnect(row.MouseLeave, function() tween(row, { BackgroundTransparency = 1 }, 0.18) end)

    -- painel grande (abre por cima do conteúdo, com pré-visualização)
    if type(opts.Modal) == "function" then
        local gear = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(12 + 34 + 6), 0.5, 0), Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
        local gi = icon(gear, "sliders-horizontal", 17, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
        local key = (self._path or "") .. "/" .. tostring(opts.Name)
        local hooked = false
        safeConnect(gear.MouseButton1Click, function()
            local m = self.Window:_getModal(key, opts.ModalTitles, opts.Modal)
            if not hooked then
                hooked = true
                safeConnect(m.Overlay:GetPropertyChangedSignal("Visible"), function()
                    gi.ImageColor3 = m.Overlay.Visible and Library.Theme.Accent or Library.Theme.Text
                end)
            end
            m.Overlay.Visible = not m.Overlay.Visible
        end)
        -- monta o painel já no começo: as opções valem (e são salvas) mesmo sem abrir o painel
        if opts.Prebuild then
            local win = self.Window
            win._pendingPrebuild = (win._pendingPrebuild or 0) + 1
            task.defer(function()
                local ok, err = pcall(function()
                    if not win._destroyed then win:_getModal(key, opts.ModalTitles, opts.Modal) end
                end)
                win._pendingPrebuild = math.max(0, (win._pendingPrebuild or 1) - 1)
                if not ok then
                    win._prebuildFailed = true
                    warn("[BBC] Painel: " .. tostring(err))
                    if Library.Diagnostics then Library.Diagnostics:record("painel", err) end
                end
            end)
        end
    end

    -- submenu (ícone de ajustes ao lado do botão)
    if type(opts.Settings) == "function" then
        local gear = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(12 + 34 + 6), 0.5, 0), Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
        local gi = icon(gear, opts.SettingsIcon or "sliders-horizontal", 17, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
        local sub, panel = subPanel(self, outer, 2, opts.SettingsPath)
        local open = false
        local function setOpen(value)
            open = value == true
            local tracked = self.Window._searchPanelState
            local forced = tracked and tracked[panel] ~= nil
            if forced then tracked[panel] = open end
            panel.Visible = forced or open
        end
        self.Window._panelOpeners = self.Window._panelOpeners or {}
        self.Window._panelOpeners[panel] = function() setOpen(true) end
        safeConnect(panel:GetPropertyChangedSignal("Visible"), function()
            gi.ImageColor3 = panel.Visible and Library.Theme.Accent or Library.Theme.Text
        end)
        safeConnect(gear.MouseButton1Click, function() setOpen(not open) end)
        obj.SettingsPanel = sub
        safeCall(opts.Settings, sub)
    end
    if state and type(opts.Callback) == "function" then
        local ok, err = pcall(opts.Callback, true)
        if not ok then
            warn("[BBC] " .. tostring(opts.Name) .. ": " .. tostring(err))
            pcall(opts.Callback, false)
            state, obj.Value = false, false
            paint(true)
        end
    end
    return obj
end

-- ---------- Slider ----------
function Container:Slider(opts)
    opts = opts or {}
    local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
    local min, max = opts.Min or 0, opts.Max or 100
    if not finite(min) or not finite(max) or max < min then min, max = 0, 100 end
    local step = opts.Step or 1
    if not finite(step) or step <= 0 then step = 1 end
    local suffix = opts.Suffix or ""
    local decimals = 0
    if step < 1 then decimals = #(string.match(tostring(step), "%.(%d+)") or "") end
    local value = finite(opts.Default) and math.clamp(opts.Default, min, max) or min
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    local nameL = label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -90, 0, 18) })
    local valueL = label(row, "", 13, "Muted", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4), Size = UDim2.fromOffset(80, 18), TextXAlignment = Enum.TextXAlignment.Right })
    local track = create("Frame", { Position = UDim2.fromOffset(18, 29), Size = UDim2.new(1, -36, 0, 5), BorderSizePixel = 0 }, row)
    bind(track, "BackgroundColor3", "Surface3"); corner(track, 3)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
    bind(fill, "BackgroundColor3", "Accent"); corner(fill, 3)
    local knob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(13, 13), BorderSizePixel = 0, ZIndex = 2 }, track)
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
        v = tonumber(v) or min
        if v ~= v or v == math.huge or v == -math.huge then v = min end
        v = math.clamp(v, min, max)
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
    safeConnect(hit.InputBegan, function(i)
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
    attachTip(self, row, opts.Name, opts.Tooltip, nil, nil, { hit, nameL })
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
    local chip = chipBox(row)
    pad(chip, 7, 6, 0, 0)
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
    local function validChoice(v)
        if multi then
            if type(v) ~= "table" then return false end
            local count = 0
            for k, item in pairs(v) do
                count += 1
                if type(k) ~= "number" or k < 1 or k % 1 ~= 0 or not table.find(options, item) then return false end
            end
            return count == #v
        end
        return v == nil or (type(v) == "string" and table.find(options, v) ~= nil)
    end
    local obj = { Frame = outer }
    local function closeList() list.Visible = false; arrow.Text = "▶" end
    function obj:Set(v, silent)
        if not validChoice(v) then return false end
        setDefault(v)
        paint()
        if not silent then safeCall(opts.Callback, current()) end
    end
    function obj:Get() return current() end
    function obj:SetOptions(newOptions)
        options = newOptions
        for value in pairs(selected) do if not table.find(options, value) then selected[value] = nil end end
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
            safeConnect(b.MouseButton1Click, function()
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
    local function guardedToggle()
        if row:GetAttribute("TipHeld") then return end
        toggleList()
    end
    safeConnect(row.MouseButton1Click, guardedToggle)
    safeConnect(chip.MouseButton1Click, guardedToggle)
    if not opts.NoPersist then register(self, opts.Name, current, function(v) return obj:Set(v) end, validChoice) end
    attachTip(self, row, opts.Name, opts.Tooltip, nil, nil, { chip })
    return obj
end

-- ---------- Keybind ----------
local KEY_SHORT = {
    RightShift = "RShift", LeftShift = "LShift", RightControl = "RCtrl", LeftControl = "LCtrl", RightAlt = "RAlt", LeftAlt = "LAlt",
    MouseButton3 = "MB3", MouseButton2 = "MB2", Backspace = "Bksp", Return = "Enter",
}
local function keyText(v) if not v then return "None" end return KEY_SHORT[v.Name] or v.Name end
local function parseKey(v)
    if typeof(v) == "EnumItem" then return v end
    if type(v) ~= "string" then return nil end
    if v == "MB3" or v == "MouseButton3" then return Enum.UserInputType.MouseButton3 end
    if v == "MB2" or v == "MouseButton2" then return Enum.UserInputType.MouseButton2 end
    local ok, k = pcall(function() return Enum.KeyCode[v] end)
    return ok and k or nil
end
Library.ParseKey = parseKey
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
    local function cancelListen()
        if not listening then return end
        listening = false
        if Library._kbOwner == obj then Library:_kbDone() end
        chipStroke.Color = Library.Theme.Stroke
        show(keyText(value))
        Library:_kbChanged()
    end
    local function beginListen()
        Library:_kbListen(obj, cancelListen)   -- cancela outro atalho que esteja escutando
        listening = true
        chipStroke.Color = Library.Theme.Accent
        show("...")
        Library:_kbChanged()
    end
    table.insert(Library.Keybinds, { name = opts.Name, get = function() return value end, begin = beginListen, listening = function() return listening end })
    safeConnect(chip.MouseButton1Click, function() if row:GetAttribute("TipHeld") then return end; beginListen() end)
    self.Window:_connect(UserInputService.InputBegan, function(input, processed)
        local t = input.UserInputType
        local isMouse = t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3
        if t ~= Enum.UserInputType.Keyboard and not isMouse then return end
        local code = isMouse and t or input.KeyCode
        if listening then
            listening = false
            if Library._kbOwner == obj then Library:_kbDone() end
            chipStroke.Color = Library.Theme.Stroke
            if code == Enum.KeyCode.Escape then show(keyText(value)); Library:_kbChanged() else obj:Set(code) end
            return
        end
        if not processed and value ~= nil and code == value then safeCall(opts.Callback, code) end
    end)
    register(self, opts.Name, function() return value and value.Name or "None" end, function(v) obj:Set(v) end,
        function(v) return v == "None" or (type(v) == "string" and Library.ParseKey(v) ~= nil) end)
    attachTip(self, row, opts.Name, opts.Tooltip, nil, nil, { chip })
    return obj
end

-- ---------- Botão ----------
function Container:Button(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1, BorderSizePixel = 0 }, outer)
    if self.Window and self.Window._touchTarget then self.Window:_touchTarget(row, 30) end
    bind(row, "BackgroundColor3", "Accent")
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    if opts.Arrow then label(row, "▶", 11, "Text", false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 16), TextXAlignment = Enum.TextXAlignment.Right }) end
    safeConnect(row.MouseButton1Click, function()
        if row:GetAttribute("TipHeld") then return end
        row.BackgroundTransparency = 0.8
        tween(row, { BackgroundTransparency = 1 }, 0.25)
        safeCall(opts.Callback)
    end)
    attachTip(self, row, opts.Name, opts.Tooltip)
    return { Frame = outer }
end

-- ---------- Input ----------
function Container:Input(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    if self.Window and self.Window._touchTarget then self.Window:_touchTarget(row, 30) end
    separator(row)
    local nameL = label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -130, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local box = create("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(100, 22), Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "", ClearTextOnFocus = false, TextSize = 12, FontFace = Library.Fonts.Regular, BorderSizePixel = 0, BackgroundTransparency = 0.2 }, row)
    bind(box, "BackgroundColor3", "Background"); bind(box, "TextColor3", "Text"); bind(box, "PlaceholderColor3", "Muted")
    corner(box, 3); stroke(box, "Stroke", 0.1)
    safeConnect(box.FocusLost, function() safeCall(opts.Callback, box.Text) end)
    if not opts.NoPersist then register(self, opts.Name, function() return box.Text end, function(v) box.Text = tostring(v) end) end
    attachTip(self, row, opts.Name, opts.Tooltip, nil, nil, { box, nameL })
    return { Frame = outer, Box = box }
end

-- ---------- Seletor de cor (quadro de saturação, barra de matiz, hex e paleta) ----------
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
    -- quadro S/V
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
    -- barra de matiz
    local hue = create("TextButton", { Position = UDim2.fromOffset(8, 100), Size = UDim2.new(1, -16, 0, 12), Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, panel)
    corner(hue, 6)
    local seq = {}
    for i = 0, 6 do seq[#seq + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1 == 0 and (i == 6 and 0.9999 or 0) or i / 6, 1, 1)) end
    create("UIGradient", { Color = ColorSequence.new(seq) }, hue)
    local hueKnob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 }, hue)
    corner(hueKnob, 3); create("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }, hueKnob)
    -- hex + paleta
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
        safeConnect(b.MouseButton1Click, function() h, s, v = c:ToHSV(); apply() end)
    end
    safeConnect(row.MouseButton1Click, function()
        if row:GetAttribute("TipHeld") then return end
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
    safeConnect(sv.InputBegan, function(i) if isPress(i) then dragSV = true; fromSV(i.Position) end end)
    safeConnect(hue.InputBegan, function(i) if isPress(i) then dragHue = true; fromHue(i.Position) end end)
    self.Window:_connect(UserInputService.InputChanged, function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            if dragSV then fromSV(i.Position) elseif dragHue then fromHue(i.Position) end
        end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(i) if isPress(i) then dragSV, dragHue = false, false end end)
    safeConnect(hex.FocusLost, function()
        local t = string.gsub(hex.Text, "#", "")
        local ok, c = pcall(Color3.fromHex, t)
        if ok and c then h, s, v = c:ToHSV() end
        apply()
    end)
    function obj:Set(c, silent) h, s, v = c:ToHSV(); apply(silent) end
    apply(true)
    if not opts.NoPersist then register(self, opts.Name, function() return { color.R, color.G, color.B } end, function(t) obj:Set(Color3.new(t[1], t[2], t[3])) end,
        function(t)
            if type(t) ~= "table" or #t ~= 3 then return false end
            for k, v in pairs(t) do
                if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > 3 or type(v) ~= "number" or v < 0 or v > 1 then return false end
            end
            return true
        end) end
    attachTip(self, row, opts.Name, opts.Tooltip)
    return obj
end

-- ---------- Seção que abre (▶) ----------
function Container:Foldout(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local arrow = label(row, "▶", 11, "Text", false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 16), TextXAlignment = Enum.TextXAlignment.Right })
    local sub, panel = subPanel(self, outer, 2)
    local open = false
    local function setOpen(v)
        open = v == true
        local tracked = self.Window._searchPanelState
        local forced = tracked and tracked[panel] ~= nil
        if forced then tracked[panel] = open end
        panel.Visible = forced or open
    end
    self.Window._panelOpeners = self.Window._panelOpeners or {}
    self.Window._panelOpeners[panel] = function() setOpen(true) end
    safeConnect(panel:GetPropertyChangedSignal("Visible"), function() arrow.Text = panel.Visible and "▼" or "▶" end)
    safeConnect(row.MouseButton1Click, function() if row:GetAttribute("TipHeld") then return end; setOpen(not open) end)
    safeCall(opts.Build, sub)
    attachTip(self, row, opts.Name, opts.Tooltip)
    return { Frame = outer, Panel = sub, Set = setOpen, IsOpen = function() return open end }
end

-- ---------- Botões lado a lado (ex.: Silencioso / Fixar / Agressivo) ----------
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
            it.btn.BackgroundColor3 = on and Library.Theme.Surface3 or Library.Theme.Surface2
            it.text.TextColor3 = on and Library.Theme.Text or Library.Theme.Muted
            if it.icon then it.icon.ImageColor3 = on and Library.Theme.Accent or Library.Theme.Muted end
        end
    end
    for i, o in ipairs(options) do
        local b = create("TextButton", { Size = UDim2.new(1 / n, -4 * (n - 1) / n, 1, 0), Text = "", AutoButtonColor = false, LayoutOrder = i, BorderSizePixel = 0 }, holder)
        corner(b, 4)
        local st = create("UIStroke", { Thickness = 1 }, b)
        local ic = icons[i] and icon(b, icons[i], 14, "Muted", { Position = UDim2.new(0, 7, 0.5, -7) }) or nil
        local tx = label(b, o, 12, "Muted", false, { Position = UDim2.fromOffset(ic and 24 or 6, 0), Size = UDim2.new(1, ic and -28 or -12, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, TextXAlignment = ic and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center })
        items[o] = { btn = b, stroke = st, text = tx, icon = ic }
        safeConnect(b.MouseButton1Click, function()
            if b:GetAttribute("TipHeld") then return end
            selected = o
            paint()
            safeCall(opts.Callback, o)
        end)
        attachTip(self, b, opts.Name, opts.Tooltip)
    end
    paint()
    table.insert(Library._themeListeners, paint)
    function obj:Set(v, silent)
        if not table.find(options, v) then return false end
        selected = v; paint(); if not silent then safeCall(opts.Callback, v) end
    end
    register(self, opts.Name, function() return selected end, function(v) return obj:Set(v) end,
        function(v) return type(v) == "string" and table.find(options, v) ~= nil end)
    return obj
end

-- ---------- Texto ----------
function Container:Label(opts)
    opts = type(opts) == "table" and opts or { Text = opts }
    local outer = newOuter(self, opts.Text)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, outer)
    local l = label(row, opts.Text, 12, "Muted", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    return { Frame = outer, Label = l, Set = function(_, t) l.Text = t end }
end
function Container:Section(text)
    local outer = newOuter(self, text)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, outer)
    label(row, string.upper(text or ""), 12, "Muted", true, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 18) })
    return { Frame = outer }
end
