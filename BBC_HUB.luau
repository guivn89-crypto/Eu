-- ============================================================
--  BBCLib - biblioteca própria do BBC HUB
--  (a AirFlow serviu só de exemplo de estrutura)
-- ============================================================
local Library = (function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Library = {
    Windows = {}, Registry = {}, _themeListeners = {}, _bindings = {},
    ThemeName = "Orange", Theme = {},
}

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
Library.ThemeOrder = { "Gold", "Purple", "Yellow", "Red", "Blue", "Orange", "Green", "Halloween", "Cyan", "Mono", "Pink" }
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
}
for k, v in pairs(Library.ThemePresets.Orange) do Library.Theme[k] = v end

local function bind(inst, prop, key)
    local fn = type(key) == "function" and key or function() return Library.Theme[key] end
    inst[prop] = fn()
    Library._bindings[#Library._bindings + 1] = { inst, prop, fn }
end
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
local function create(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
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
    local tw = TweenService:Create(inst, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
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
local LUCIDE_URL = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"
local lucide, lucideTried = nil, false
local iconQueue = {}
local function resolveIcon(name)
    if not lucide then return nil end
    local entry = (lucide.Icons and lucide.Icons[name]) or lucide[name]
    if type(entry) ~= "table" then return nil end
    local image = entry.Image
    if type(image) == "number" then image = "rbxassetid://" .. tostring(image) end
    local sheet = (lucide.Spritesheets and lucide.Spritesheets[tostring(image)]) or image
    return sheet, entry.ImageRectPosition, entry.ImageRectSize
end
local function applyIconNow(img, name)
    local sheet, pos, size = resolveIcon(name)
    if sheet then
        img.Image = sheet
        if pos then img.ImageRectOffset = pos end
        if size then img.ImageRectSize = size end
    end
end
local function setIcon(img, name)
    if type(name) == "string" and (name:match("^%d+$") or name:find("^rbxassetid://")) then
        img.Image = name:match("^%d+$") and ("rbxassetid://" .. name) or name
        return
    end
    if lucide then applyIconNow(img, name) else table.insert(iconQueue, { img, name }) end
end
task.spawn(function()
    if lucideTried then return end
    lucideTried = true
    local ok, result = pcall(function() return loadstring(game:HttpGet(LUCIDE_URL))() end)
    if ok and type(result) == "table" then
        lucide = result
        for _, q in ipairs(iconQueue) do if q[1].Parent then applyIconNow(q[1], q[2]) end end
        iconQueue = {}
    else
        warn("[BBC] ícones indisponíveis: " .. tostring(result))
    end
end)
local function icon(parent, name, size, key, props)
    local img = create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size or 16, size or 16), ScaleType = Enum.ScaleType.Fit }, parent)
    bind(img, "ImageColor3", key or "Text")
    for k, v in pairs(props or {}) do img[k] = v end
    setIcon(img, name)
    return img
end

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

-- ---------- Raiz da interface ----------
local function guiParent()
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
function Library:Notify(opts)
    opts = opts or {}
    if not notifyGui or not notifyGui.Parent then
        notifyGui = create("ScreenGui", { Name = "BBCNotify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000 }, guiParent())
        notifyHolder = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(250, 400), BackgroundTransparency = 1 }, notifyGui)
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6) }, notifyHolder)
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
    task.delay(opts.Duration or 3, function()
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
local function chipBox(parent)
    local c = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 0.2 }, parent)
    bind(c, "BackgroundColor3", "Background")
    corner(c, 3); stroke(c, "Stroke", 0.1)
    return c
end
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
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local state = opts.Default == true
    local pill = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(34, 18), BorderSizePixel = 0 }, row)
    corner(pill, 9); stroke(pill, "Stroke", 0.2)
    bind(pill, "BackgroundColor3", function() return state and Library.Theme.Accent or Library.Theme.Surface3 end)
    local knob = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, pill)
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
        state = v == true
        self.Value = state
        paint()
        if not silent then safeCall(opts.Callback, state) end
    end
    function obj:Get() return state end
    row.MouseButton1Click:Connect(function() obj:Set(not state) end)
    register(self, opts.Name, function() return state end, function(v) obj:Set(v) end)

    -- submenu (ícone de ajustes ao lado do botão)
    if type(opts.Settings) == "function" then
        local gear = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(12 + 34 + 6), 0.5, 0), Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
        local gi = icon(gear, "sliders-horizontal", 16, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
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
    local track = create("Frame", { Position = UDim2.fromOffset(12, 29), Size = UDim2.new(1, -24, 0, 5), BorderSizePixel = 0 }, row)
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
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -140, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local chip = chipBox(row)
    pad(chip, 8, 6, 0, 0)
    listLayout(chip, 5, Enum.FillDirection.Horizontal)
    local valueL = label(chip, "", 12, "Text", false, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Center })
    local arrow = label(chip, "▶", 9, "Text", false, { LayoutOrder = 2, Size = UDim2.fromOffset(10, 22), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
    local list = create("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false, LayoutOrder = 2 }, outer)
    bind(list, "BackgroundColor3", "Surface2"); corner(list, 4); stroke(list, "Stroke", 0.3)
    pad(list, 0, 0, 3, 3); listLayout(list, 0)
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
        for o, b in pairs(buttons) do
            local on = selected[o] == true
            b.BackgroundTransparency = on and 0.82 or 1
            b.TextColor3 = on and Library.Theme.Accent or Library.Theme.Text
        end
    end
    local function current()
        if multi then return ordered() end
        return ordered()[1]
    end
    local obj = { Frame = outer }
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
            local b = create("TextButton", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = o, TextSize = 13, FontFace = Library.Fonts.Regular,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = i, BorderSizePixel = 0 }, list)
            bind(b, "BackgroundColor3", "Accent")
            pad(b, 22, 6, 0, 0)
            buttons[o] = b
            b.MouseButton1Click:Connect(function()
                if multi then
                    selected[o] = not selected[o] or nil
                else
                    selected = { [o] = true }
                    list.Visible = false
                    arrow.Text = "▶"
                end
                paint()
                safeCall(opts.Callback, current())
            end)
        end
        paint()
    end
    obj:SetOptions(options)
    row.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        arrow.Text = list.Visible and "▼" or "▶"
    end)
    register(self, opts.Name, current, function(v) obj:Set(v, true) end)
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
    local chip = chipBox(row)
    pad(chip, 8, 8, 0, 0)
    local cl = label(chip, keyText(value), 12, "Text", false, { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Center })
    local listening = false
    local obj = { Frame = outer }
    function obj:Set(v, silent)
        value = parseKey(v)
        self.Value = value
        cl.Text = keyText(value)
        if not silent then safeCall(opts.OnChanged, value) end
    end
    function obj:Get() return value end
    obj.Value = value
    chip.MouseButton1Click:Connect(function()
        listening = true
        Library._listening = true
        cl.Text = "..."
    end)
    self.Window:_connect(UserInputService.InputBegan, function(input, processed)
        local t = input.UserInputType
        local isMouse = t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3
        if t ~= Enum.UserInputType.Keyboard and not isMouse then return end
        local code = isMouse and t or input.KeyCode
        if listening then
            listening = false
            Library._listening = false
            Library._lastBind = os.clock()
            if code == Enum.KeyCode.Escape then cl.Text = keyText(value) else obj:Set(code) end
            return
        end
        if not processed and value ~= nil and code == value then safeCall(opts.Callback, code) end
    end)
    register(self, opts.Name, function() return value and value.Name or "None" end, function(v) obj:Set(v) end)
    return obj
end

-- ---------- Botão ----------
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
    register(self, opts.Name, function() return box.Text end, function(v) box.Text = tostring(v) end)
    return { Frame = outer, Box = box }
end

-- ---------- Seletor de cor ----------
function Container:ColorPicker(opts)
    opts = opts or {}
    local color = opts.Default or Color3.fromRGB(255, 255, 255)
    local h, s, v = color:ToHSV()
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -60, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local sw = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(28, 18), BackgroundColor3 = color, BorderSizePixel = 0 }, row)
    corner(sw, 3); stroke(sw, "Stroke", 0.1)
    local sub, panel = subPanel(self, outer, 2)
    row.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)
    local obj = { Frame = outer }
    local function apply(silent)
        color = Color3.fromHSV(h, s, v)
        sw.BackgroundColor3 = color
        obj.Value = color
        if not silent then safeCall(opts.Callback, color) end
    end
    obj.Value = color
    local hs = sub:Slider({ Name = "H", Min = 0, Max = 100, Default = h * 100, Callback = function(x) h = x / 100; apply() end })
    local ss = sub:Slider({ Name = "S", Min = 0, Max = 100, Default = s * 100, Callback = function(x) s = x / 100; apply() end })
    local vs = sub:Slider({ Name = "V", Min = 0, Max = 100, Default = v * 100, Callback = function(x) v = x / 100; apply() end })
    function obj:Set(c, silent)
        h, s, v = c:ToHSV()
        hs:Set(h * 100, true); ss:Set(s * 100, true); vs:Set(v * 100, true)
        apply(silent)
    end
    register(self, opts.Name, function() return { color.R, color.G, color.B } end, function(t) if type(t) == "table" then obj:Set(Color3.new(t[1], t[2], t[3])) end end)
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

-- ============================================================
--  Aba, grupo e janela
-- ============================================================
local Tab = setmetatable({}, { __index = Container })
Tab.__index = Tab
local Window = {}
Window.__index = Window

function Window:_connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self._conns, c)
    return c
end

-- colunas com rolagem independente (criadas na primeira vez que se usa Groupbox)
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
    label(head, opts.Name, 13, "Muted", false, { Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 8, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local ln = create("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 1, -1), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, head)
    bind(ln, "BackgroundColor3", "Stroke")
    local body = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, box)
    listLayout(body, 0)
    return setmetatable({ List = body, _order = 0, Window = self.Window, _path = self._path .. "/" .. tostring(opts.Name), Frame = box }, Container)
end

local function fmtLeft(sec)
    sec = math.max(math.floor(sec), 0)
    local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
    if d > 0 then return d .. "d " .. h .. "h" end
    return h .. "h " .. m .. "m"
end

function Window:_select(tab)
    if not tab then return end
    for _, t in ipairs(self.Tabs) do
        t.Page.Visible = (t == tab)
        if t.Button then
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
        self.HomeTab = tab
        table.insert(self.Tabs, tab)
        return tab
    end
    local btn = create("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = #self.Tabs + 1 }, self._tabList)
    tab.Button = btn
    tab.Sel = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1 }, btn)
    bind(tab.Sel, "BackgroundColor3", "Accent"); corner(tab.Sel, 4)
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }) }, tab.Sel)
    tab.IconImg = icon(btn, opts.Icon or "circle", 16, "Muted", { Position = UDim2.fromOffset(12, 8) })
    tab.Text = label(btn, string.upper(opts.Name or ""), 13, "Muted", false, { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    table.insert(self.Tabs, tab)
    btn.MouseButton1Click:Connect(function() self:_select(tab) end)
    if not self.Current or self.Current == self.HomeTab then self:_select(tab) end
    return tab
end

-- ---------- Configurações salvas ----------
local CFG_FOLDER = "BBC_HUB/configs"
local function canFS() return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" end
function Window:SaveConfig(name)
    if not canFS() then Library:Notify({ Title = "BBC HUB", Content = "Salvar precisa de writefile no executor." }); return false end
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            if not isfolder(CFG_FOLDER) then makefolder(CFG_FOLDER) end
        end
    end)
    local data = {}
    for key, r in pairs(Library.Registry) do
        local ok, val = pcall(r.get)
        if ok and val ~= nil then data[key] = val end
    end
    local ok = pcall(function() writefile(CFG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(data)) end)
    Library:Notify({ Title = "BBC HUB", Content = ok and ("Configuração salva: " .. name) or "Falha ao salvar." })
    return ok
end
function Window:LoadConfig(name)
    if not canFS() then return false end
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, data = pcall(function() if isfile(path) then return HttpService:JSONDecode(readfile(path)) end end)
    if not ok or type(data) ~= "table" then return false end
    for key, val in pairs(data) do
        local r = Library.Registry[key]
        if r then pcall(r.set, val) end
    end
    Library:Notify({ Title = "BBC HUB", Content = "Configuração carregada: " .. name })
    return true
end

-- ---------- Identidade ----------
function Window:SetHideName(h) self._hideName = h == true; self:_renderIdentity() end
function Window:SetHideAvatar(h) self._hideAvatar = h == true; self:_renderIdentity() end
function Window:_renderIdentity()
    if not self._pName then return end
    self._pName.Text = self._hideName and "••••••" or LocalPlayer.DisplayName
    self._pAvatar.Image = self._hideAvatar and "" or (self._thumb or "")
end

-- ---------- Visibilidade e botão flutuante ----------
function Window:SetVisible(v) self._main.Visible = v end
function Window:Toggle() self._main.Visible = not self._main.Visible end
function Window:SetKeybind(k) self._key = parseKey(k) end
function Window:SetIslandDraggable(enabled) self._btnDraggable = enabled == true end
function Window:SetToggleButton(enabled)
    if not enabled then
        if self._toggleBtn then self._toggleBtn:Destroy(); self._toggleBtn = nil end
        return
    end
    if self._toggleBtn then return end
    local b = create("TextButton", { Name = "BBCToggle", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 14, 0.38, 0), Text = "BBC", TextSize = 15,
        FontFace = Library.Fonts.Bold, AutoButtonColor = false, BorderSizePixel = 0 }, self.Gui)
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

-- ---------- Janela ----------
function Library:Window(opts)
    opts = opts or {}
    if opts.Theme and Library.ThemePresets[opts.Theme] then Library:SetTheme(opts.Theme) end
    local self = setmetatable({ Tabs = {}, _conns = {}, _hideName = false, _hideAvatar = false, _btnDraggable = true }, Window)
    local W = (opts.Size and opts.Size.X.Offset > 0) and opts.Size.X.Offset or 640
    local H = (opts.Size and opts.Size.Y.Offset > 0) and opts.Size.Y.Offset or 360
    local gui = create("ScreenGui", { Name = "BBCHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, guiParent())
    self.Gui = gui
    local main = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BorderSizePixel = 0 }, gui)
    bind(main, "BackgroundColor3", "Background"); corner(main, 6); stroke(main, "Stroke", 0)
    self._main = main
    local scale = create("UIScale", {}, main)
    local function fit()
        local vp = gui.AbsoluteSize
        if vp.X <= 0 or vp.Y <= 0 then return end
        scale.Scale = math.clamp(math.min(vp.X * 0.8 / W, vp.Y * 0.92 / H), 0.45, 1.3)
    end
    fit()
    self:_connect(gui:GetPropertyChangedSignal("AbsoluteSize"), fit)
    self._key = parseKey(opts.Keybind or "RightShift")
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if processed or Library._listening or os.clock() - (Library._lastBind or 0) < 0.25 then return end
        local t = input.UserInputType
        local code = t == Enum.UserInputType.Keyboard and input.KeyCode or t
        if self._key and code == self._key then self:Toggle() end
    end)

    -- cabeçalho
    local header = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, main)
    icon(header, "box", 30, "Accent", { Position = UDim2.fromOffset(12, 11) })
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

    -- barra de configuração ("default" + salvar)
    local cfgName = "default"
    local cfgBar = create("Frame", { Position = UDim2.fromOffset(130, 11), Size = UDim2.new(1, -330, 0, 30), BorderSizePixel = 0 }, header)
    bind(cfgBar, "BackgroundColor3", "Surface2"); corner(cfgBar, 3); stroke(cfgBar, "Stroke", 0.1)
    local saveBtn = create("TextButton", { Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, cfgBar)
    icon(saveBtn, "save", 18, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    local cfgBox = create("TextBox", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -38, 1, 0), BackgroundTransparency = 1, Text = cfgName, TextSize = 14,
        FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, PlaceholderText = "default" }, cfgBar)
    bind(cfgBox, "TextColor3", "Text"); bind(cfgBox, "PlaceholderColor3", "Muted")
    saveBtn.MouseButton1Click:Connect(function() cfgName = (cfgBox.Text ~= "" and cfgBox.Text) or "default"; self:SaveConfig(cfgName) end)
    cfgBox.FocusLost:Connect(function(enter)
        if enter and cfgBox.Text ~= "" then cfgName = cfgBox.Text; if not self:LoadConfig(cfgName) then cfgBox.Text = cfgName end end
    end)
    -- busca
    local searchBox = create("TextBox", { Position = UDim2.fromOffset(130, 11), Size = UDim2.new(1, -330, 0, 30), Text = "", PlaceholderText = "Search", TextSize = 14,
        FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, Visible = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, header)
    bind(searchBox, "BackgroundColor3", "Surface2"); bind(searchBox, "TextColor3", "Text"); bind(searchBox, "PlaceholderColor3", "Muted")
    corner(searchBox, 3); stroke(searchBox, "Accent", 0.2); pad(searchBox, 10, 8, 0, 0)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function() self:_filter(searchBox.Text) end)
    -- botões do canto
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

    -- barra lateral
    local side = create("Frame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(0, 152, 1, -52), BackgroundTransparency = 1 }, main)
    self._tabList = create("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -58), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y }, side)
    pad(self._tabList, 6, 4, 2, 2); listLayout(self._tabList, 2)
    local div = create("Frame", { Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, -6), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, side)
    bind(div, "BackgroundColor3", "Stroke")
    -- cartão do jogador
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

    -- conteúdo
    self._content = create("Frame", { Position = UDim2.fromOffset(160, 54), Size = UDim2.new(1, -168, 1, -62), BackgroundTransparency = 1, ClipsDescendants = true }, main)

    -- página inicial (perfil), escondida da barra lateral
    if opts.Home ~= false then
        local homeTab = self:Tab({ Name = "Home", Hidden = true })
        if type(home.Build) == "function" then safeCall(home.Build, self, homeTab, homeTab.List) end
    end
    table.insert(Library.Windows, self)
    table.insert(Library._themeListeners, function()
        if gui.Parent and self.Current then self:_select(self.Current) end
    end)
    self:_renderIdentity()
    return self
end

return Library
end)()


getgenv().BBCLib = Library


-- ============================================================
--  BBC HUB - interface (somente visual, callbacks vazios)
-- ============================================================

-- ============================================================
--  PAINEL DE PERFIL (dados reais do aparelho, da conta e do jogo)
-- ============================================================

-- ============================================================
--  IDIOMAS (English / Español / Português / 简体中文 / Русский)
-- ============================================================
local LangUIS = game:GetService("UserInputService")
local LANG_CODES = { ["English"] = "en", ["Español"] = "es", ["Português (Brasil)"] = "pt", ["简体中文"] = "zh", ["Русский"] = "ru" }
local LANG_NAMES = { en = "English", es = "Español", pt = "Português (Brasil)", zh = "简体中文", ru = "Русский" }
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
local refreshPanels = function() end
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
    text = string.gsub(text, "&amp;", "&")
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
local onLanguageChanged = {}
local function setLanguage(code, silent)
    if not LANG_NAMES[code] or code == currentLang then return end
    currentLang = code
    pcall(function()
        if type(writefile) == "function" then
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            writefile(LANG_FILE, code)
        end
    end)
    for _, fn in ipairs(onLanguageChanged) do pcall(fn) end
end

local Config = (getgenv and getgenv().BBC_CONFIG) or {}
-- Opcional, antes de carregar:  getgenv().BBC_CONFIG = { Access = "VIP", Expiry = os.time() + 12*3600, Version = "0.0.8.2" }
local buildProfile
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local StatsService = game:GetService("Stats")
    local LP = Players.LocalPlayer
    local VERSION = Config.Version or "0.0.8.2"
    local ACCESS = Config.Access or "FREE"

    -- ---------- Persistência (executor com writefile) ----------
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

    -- ---------- Rastreamento real ----------
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

    -- Abates por tag "creator" (jogos que usam essa convenção)
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

    -- ---------- Leituras ----------
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
        if UserInputService.TouchEnabled and not kb then return tr("Celular") end
        if UserInputService.GamepadEnabled and not kb then return tr("Console") end
        return "PC"
    end
    local frames, fps = 0, 0
    RunService.RenderStepped:Connect(function() frames += 1 end)

    -- ---------- UI ----------
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

    buildProfile = function(win, page, list)
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

        -- Valores estáticos (reais)
        vUid.Text = tostring(LP.UserId)
        vAge.Text = LP.AccountAge .. " " .. tr("dias")
        vAccess.Text = ACCESS
        vVer.Text = VERSION
        vDev.Text = getDevice()
        table.insert(onLanguageChanged, function() vDev.Text = getDevice(); vAge.Text = LP.AccountAge .. " " .. tr("dias") end)
        vMap.Text = tostring(game.PlaceId)
        vMapVer.Text = tostring(game.PlaceVersion)
        vJob.Text = (game.JobId ~= "" and game.JobId) or tr("Servidor local")
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
                vLeft.Text = left > 0 and fmtDuration(left) or tr("Expirado")
            else
                vLeft.Text = tr("Ilimitado")
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
end


-- ============================================================
--  SERVIDORES (lista real da API pública do Roblox)
-- ============================================================
local buildServers
do
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

    buildServers = function(tab)
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
        local cName = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.46, 0, 1, 0), Position = UDim2.fromOffset(10, 0) })
        local cPing = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.18, 0, 1, 0), Position = UDim2.new(0.5, 0, 0, 0) })
        local cPl = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.18, 0, 1, 0), Position = UDim2.new(0.68, 0, 0, 0) })
        local cFps = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.14, 0, 1, 0), Position = UDim2.new(0.86, 0, 0, 0) })

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

        local function renderDetails()
            local sv = state.selected
            if not sv then
                detName.Text = mapName
                detSub.Text = tr("Pronto para entrar")
                return
            end
            detName.Text = mapName .. (sv.id == game.JobId and ("  •  " .. tr("Seu servidor")) or "")
            detSub.Text = tr("Pronto para entrar") .. "  ·  " .. string.sub(sv.id or "", 1, 22)
        end

        local render
        local function selectServer(sv) state.selected = sv; renderDetails(); render() end

        render = function()
            for _, c in ipairs(scroller:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
            for i = #themed, 1, -1 do if not themed[i][1].Parent then table.remove(themed, i) end end
            local items = visibleList()
            local total = #state.all
            title.Text = string.upper(tr("Servidor")) .. "   " .. #items .. " / " .. total .. " " .. tr("servidores")
            cName.Text = tr("Servidor"); cPing.Text = "Ping"; cPl.Text = tr("Jogadores"); cFps.Text = "FPS"
            sortBtn.Text = tr("Ordenar") .. ": " .. (state.sort == "players" and tr("Jogadores") or (state.sort == "ping" and "Ping" or "FPS"))
            dirBtn.Text = state.desc and "↓" or "↑"
            box.PlaceholderText = tr("Buscar mapa, nome ou ID do servidor")
            bRefresh.Text = tr("Atualizar"); bHistory.Text = tr("Histórico"); bFilters.Text = tr("Filtros")
            bDetails.Text = tr("Detalhes"); bJoin.Text = tr("Entrar")
            if state.loading then
                txt(scroller, tr("Carregando servidores..."), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
            elseif state.failed and not state.showHistory then
                txt(scroller, tr("Falha ao carregar a lista"), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
            elseif #items == 0 then
                txt(scroller, tr(state.showHistory and "Histórico vazio" or "Nenhum servidor encontrado"), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
            end
            for i, sv in ipairs(items) do
                if i > 150 then break end
                local row = mk("TextButton", { Size = UDim2.new(1, 0, 0, 44), Text = "", AutoButtonColor = false, LayoutOrder = i }, scroller)
                decorate(row, "Surface2", 6)
                local selected = state.selected and state.selected.id == sv.id
                if selected then th(row:FindFirstChildOfClass("UIStroke"), "Color", "Accent") end
                txt(row, mapName, 14, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.46, -10, 0, 18) })
                txt(row, (sv.id == game.JobId and (tr("Seu servidor") .. " · ") or "") .. shortId(sv.id), 11, "Muted", false, { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(0.46, -10, 0, 16) })
                local ping = tonumber(sv.ping)
                txt(row, ping and (math.floor(ping) .. " ms") or "—", 13, "Text", false, { Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.new(0.18, 0, 0, 18) })
                txt(row, (sv.playing or 0) .. "/" .. (sv.maxPlayers or 0), 13, "Text", false, { Position = UDim2.new(0.68, 0, 0, 12), Size = UDim2.new(0.18, 0, 0, 18) })
                local fps = tonumber(sv.fps)
                txt(row, fps and tostring(math.floor(fps)) or "—", 13, "Text", false, { Position = UDim2.new(0.86, 0, 0, 12), Size = UDim2.new(0.14, 0, 0, 18) })
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
            if not pcall(function() setclipboard(sv.id) end) then notify(info) else notify(tr("Copiar ID") .. ": " .. string.sub(sv.id, 1, 13)) end
        end, 1)
        bJoin = btn(detBtns, "", 80, function()
            local sv = state.selected
            if not sv then return end
            table.insert(history, 1, { id = sv.id, playing = sv.playing, maxPlayers = sv.maxPlayers, ping = sv.ping, fps = sv.fps, when = os.time() })
            while #history > 30 do table.remove(history) end
            saveHistory()
            notify(tr("Entrando no servidor..."))
            Library:JoinServer(sv.id)
        end, 2)

        -- Filtros
        filtersFrame = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, LayoutOrder = 3 }, root)
        decorate(filtersFrame, "Surface2", 6)
        mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, filtersFrame)
        mk("UIListLayout", { Padding = UDim.new(0, 6), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, filtersFrame)
        local function filterToggle(key, label, order)
            local b = mk("TextButton", { Size = UDim2.fromOffset(150, 26), TextSize = 13, AutoButtonColor = false, FontFace = Library.Fonts.Regular, LayoutOrder = order, Text = "" }, filtersFrame)
            decorate(b, "Surface3", 6); th(b, "TextColor3", "Text")
            local function paint() b.Text = (state[key] and "● " or "○ ") .. tr(label) end
            paint()
            b.MouseButton1Click:Connect(function() state[key] = not state[key]; paint(); render() end)
            table.insert(onLanguageChanged, paint)
        end
        filterToggle("hideFull", "Ocultar cheios", 1)
        filterToggle("hideMine", "Ocultar meu servidor", 2)

        box:GetPropertyChangedSignal("Text"):Connect(function() state.query = box.Text; render() end)
        sortBtn.MouseButton1Click:Connect(function()
            state.sort = state.sort == "players" and "ping" or (state.sort == "ping" and "fps" or "players")
            render()
        end)
        dirBtn.MouseButton1Click:Connect(function() state.desc = not state.desc; render() end)
        table.insert(onLanguageChanged, function() renderDetails(); render() end)
        renderDetails()
        load()
    end
end

local Window = Library:Window({
    Title = "BBC HUB",
    Subtitle = "v0.0.8.2",
    Size = UDim2.fromOffset(640, 360),
    Keybind = "RightShift",
    Theme = "Orange",
    Home = { Build = buildProfile, Expiry = Config.Expiry },
})
local IS_MOBILE = LangUIS.TouchEnabled and not LangUIS.KeyboardEnabled
pcall(function() Window:SetToggleButton(true) end) -- botão flutuante para abrir/fechar (celular)

-- tradução automática de tudo que aparece na janela
do
    local gui = Window.Gui or Window.ScreenGui or Window.Root
    if gui then
        for _, d in ipairs(gui:GetDescendants()) do translateInstance(d) end
        gui.DescendantAdded:Connect(function(d) task.defer(translateInstance, d) end)
        table.insert(onLanguageChanged, function()
            for _, d in ipairs(gui:GetDescendants()) do translateInstance(d) end
        end)
    else
        warn("[BBC HUB] não achei a ScreenGui da janela para traduzir")
    end
end

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

local function notify(text)
    pcall(function() Library:Notify({ Title = "BBC HUB", Content = text, Duration = 2 }) end)
end

-- Submenu padrão (ícone de ajustes ao lado do toggle)
local function buildSettings(name)
    return function(p)
        p:Dropdown({ Name = "Modo", Options = { "Sempre", "Ao segurar", "Alternar" }, Default = "Alternar", Callback = function(v) end })
        p:Slider({ Name = "Intensidade", Min = 0, Max = 100, Default = 50, Suffix = "%", Callback = function(v) end })
        p:Slider({ Name = "Distância", Min = 10, Max = 1000, Default = 300, Suffix = "m", Callback = function(v) end })
        p:Toggle({ Name = "Notificar", Default = false, Callback = function(v) end })
    end
end

local function T(tab, name, default, tip)
    local o = { Name = name, Default = default or false, Tooltip = tip, Callback = function(v) end }
    if GEARS[name] then o.Settings = buildSettings(name) end
    return tab:Toggle(o)
end
local function S(tab, name, min, max, default, suffix, step)
    return tab:Slider({ Name = name, Min = min, Max = max, Default = default, Suffix = suffix or "", Step = step or 1, Callback = function(v) end })
end

-- ---------------- VISUAIS ----------------
local visuais = Window:Tab({ Name = "VISUAIS", Icon = "eye" })
local g = visuais:Groupbox({ Name = "ESP", Icon = "scan-eye", Side = "Left" })
for _, n in ipairs({ "Jogador", "NPCs", "Corpo", "Recipiente", "Item no chão", "Itens de missão" }) do
    T(g, n, n == "Jogador" or n == "NPCs" or n == "Corpo")
end
g = visuais:Groupbox({ Name = "INTERFACE DO JOGO", Icon = "layout-dashboard", Side = "Right" })
T(g, "Mochila personalizada"); T(g, "Mochila"); T(g, "Barra rápida", true)
g = visuais:Groupbox({ Name = "LOCAL", Icon = "map-pin", Side = "Right" })
for _, n in ipairs({ "Aura", "Círculo de salto", "Auréola", "Rastro estelar" }) do T(g, n) end

-- ---------------- JOGADOR ----------------
local jogador = Window:Tab({ Name = "JOGADOR", Icon = "user" })
g = jogador:Groupbox({ Name = "MOVIMENTO", Icon = "move", Side = "Left" })
T(g, "Hack de velocidade"); T(g, "Sprint automático", true); T(g, "Pulos seguidos")
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
g:Keybind({ Name = "Zoom", Default = "N", OnChanged = function(k) keys.zoom = k.Name; refreshPanels() end, Callback = function() end })
g = jogador:Groupbox({ Name = "ANIMAÇÕES", Icon = "activity", Side = "Right" })
g:Dropdown({ Name = "Animação", Options = { "Swish", "Padrão" }, Default = "Swish", Callback = function(v) end })
T(g, "Repetir")
S(g, "Velocidade", 0.1, 3, 1, "x", 0.1)
S(g, "Peso", 0, 100, 100, "%")
g:Button({ Name = "Reproduzir", Callback = function() notify("Reproduzir") end })
g = jogador:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Right" })
T(g, "Painel do jogador"); T(g, "Anti AFK"); T(g, "Renascer automático")
T(g, "Remover água"); T(g, "Não se afogar"); T(g, "Mapa e navegação", true)

-- ---------------- COMBATE ----------------
local combate = Window:Tab({ Name = "COMBATE", Icon = "crosshair" })
g = combate:Groupbox({ Name = "MIRA", Icon = "crosshair", Side = "Left" })
g:Dropdown({ Name = "Modo", Options = { "Silencioso", "Fixar", "Agressivo" }, Default = "Fixar", Callback = function(v) end })
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
g:Button({ Name = "Manuseio da arma", Arrow = true, Callback = function() notify("Manuseio da arma") end })
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

-- ---------------- MUNDO ----------------
local mundo = Window:Tab({ Name = "MUNDO", Icon = "globe" })
g = mundo:Groupbox({ Name = "MUNDO", Icon = "globe", Side = "Left" })
g:Button({ Name = "Cores do terreno", Arrow = true, Callback = function() notify("Cores do terreno") end })
g:Button({ Name = "Folhas", Arrow = true, Callback = function() notify("Folhas") end })
g:Button({ Name = "Troncos", Arrow = true, Callback = function() notify("Troncos") end })
g:ColorPicker({ Name = "Cor da água", Default = Color3.fromRGB(40, 70, 75), Callback = function(c) end })
T(g, "Sem grama", true); T(g, "Desativar minas", true)
g = mundo:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Left" })
T(g, "Carregar jogadores"); T(g, "Buscar chefes"); T(g, "Pontos de saída", true); T(g, "Radar")
g = mundo:Groupbox({ Name = "ILUMINAÇÃO", Icon = "lightbulb", Side = "Right" })
for _, n in ipairs({ "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens",
    "Florescer", "Desfoque", "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade" }) do
    T(g, n, n == "Luz" or n == "Hora e sol")
end

-- ---------------- EXTRAS ----------------
local extras = Window:Tab({ Name = "EXTRAS", Icon = "layout-grid" })
g = extras:Groupbox({ Name = "EXTRAS", Icon = "layout-grid", Side = "Left" })
T(g, "Troca rápida"); T(g, "Modo pânico"); g:Button({ Name = "Atravessar porta", Callback = function() notify("Atravessar porta") end })
T(g, "Remover efeitos"); T(g, "Avisos de denúncias", true); T(g, "Avisos de entrada")
g = extras:Groupbox({ Name = "SONS", Icon = "volume-2", Side = "Left" })
g:Input({ Name = "Adicionar ID de som", Placeholder = "ID", Callback = function(v) end })
for _, n in ipairs({ "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue" }) do
    T(g, n, n == "Disparo")
end
g = extras:Groupbox({ Name = "DETECÇÃO", Icon = "radar", Side = "Right" })
T(g, "Criador"); T(g, "Testador"); T(g, "Moderador", true); T(g, "Trapaceiro")
g = extras:Groupbox({ Name = "ORDENAR DEPÓSITO", Icon = "arrow-down-up", Side = "Right" })
g:Button({ Name = "Por valor", Callback = function() notify("Por valor") end })
g:Button({ Name = "Por tipo", Callback = function() notify("Por tipo") end })
g:Button({ Name = "Por nome", Callback = function() notify("Por nome") end })
g = extras:Groupbox({ Name = "VER INVENTÁRIO", Icon = "backpack", Side = "Right" })
g:Keybind({ Name = "Ver inventário", Default = "Backquote", Callback = function() end })
g:Dropdown({ Name = "Mostrar", Options = { "Jogadores", "NPCs", "Todos" }, Default = "Jogadores", Callback = function(v) end })
T(g, "Sempre mostrar")

-- ---------------- BUSCAR SAQUE / SERVIDORES / SKINS / MISSÕES / COMERCIANTES ----------------
local saque = Window:Tab({ Name = "BUSCAR SAQUE", Icon = "package-search" })
saque:Section("BUSCAR SAQUE")
saque:Label({ Text = "Resultados da busca aparecerão aqui." })
local servidores = Window:Tab({ Name = "SERVIDORES", Icon = "server" })
buildServers(servidores)
local skins = Window:Tab({ Name = "SKINS", Icon = "palette" })
skins:Section("SKINS")
local missoes = Window:Tab({ Name = "MISSÕES", Icon = "scroll-text" })
missoes:Section("MISSÕES")
local comerciantes = Window:Tab({ Name = "COMERCIANTES", Icon = "shopping-cart" })
comerciantes:Section("COMERCIANTES")

-- ---------------- CONFIGURAÇÕES ----------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local overlayParent = (type(gethui) == "function" and gethui()) or Players.LocalPlayer:WaitForChild("PlayerGui")
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

local WM = { Shadow = true, On = true, Pin = false, Size = 100, Width = 285, MaxH = 290, BgT = 0.10, TxtT = 0, BrdT = 0, Radius = 6, Fields = { "Nome", "FPS", "Ping" } }
local KL = { Shadow = true, Pin = false, On = true, Size = 100, Width = 335, MaxH = 300, BgT = 0.10, TxtT = 0, BrdT = 0, Radius = 6 }
local wmFrame, wmCorner, wmStroke, wmText = makePanel("Watermark", UDim2.fromOffset(12, 12))
local klFrame, klCorner, klStroke, klText = makePanel("KeybindList", UDim2.new(1, -360, 0, 120))

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
refreshPanels = function()
    applyPanel(WM, wmFrame, wmCorner, wmStroke, wmText, 28)
    applyPanel(KL, klFrame, klCorner, klStroke, klText, 90)
    klText.Text = "<b>" .. tr("LISTA DE ATALHOS") .. "</b>\n" .. tr("Menu") .. "  [" .. keys.menu .. "]\n"
        .. tr("Cursor") .. "  [" .. keys.cursor .. "]\nZoom  [" .. keys.zoom .. "]"
end
table.insert(onLanguageChanged, refreshPanels)

-- arrastar painéis (mouse ou toque), a menos que "Fixar" esteja ligado
local function makeDraggable(frame, cfg)
    frame.Active = true
    local dragging, startPos, startInput
    frame.InputBegan:Connect(function(i)
        if cfg.Pin then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, frame.Position
        end
    end)
    LangUIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    LangUIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(wmFrame, WM)
makeDraggable(klFrame, KL)

-- Cursor livre: segurando a tecla do cursor, o mouse é liberado para clicar no menu
local cursorFree, cursorHeld, cursorKey = true, false, Enum.KeyCode.LeftAlt
LangUIS.InputBegan:Connect(function(i) if cursorFree and i.KeyCode == cursorKey then cursorHeld = true end end)
LangUIS.InputEnded:Connect(function(i) if i.KeyCode == cursorKey then cursorHeld = false end end)
RunService.RenderStepped:Connect(function()
    if cursorHeld then
        LangUIS.MouseBehavior = Enum.MouseBehavior.Default
        LangUIS.MouseIconEnabled = true
    end
end)
local frames, last = 0, os.clock()
local fps = 60
RunService.Heartbeat:Connect(function()
    frames += 1
    if os.clock() - last >= 1 then fps = frames; frames = 0; last = os.clock() end
    local parts = { "<b>BBC HUB</b>" }
    for _, f in ipairs(WM.Fields) do
        if f == "Nome" then table.insert(parts, Players.LocalPlayer.Name)
        elseif f == "FPS" then table.insert(parts, fps .. " FPS")
        elseif f == "Ping" then
            local ok, ping = pcall(function() return math.floor(Players.LocalPlayer:GetNetworkPing() * 2000) end)
            table.insert(parts, (ok and ping or 0) .. " ms")
        elseif f == "Hora" then table.insert(parts, os.date("%H:%M")) end
    end
    wmText.Text = table.concat(parts, "  |  ")
end)
refreshPanels()

local function bind(cfg, key, v) cfg[key] = v; refreshPanels() end
local function SB(grp, name, min, max, def, suffix, step, cfg, key)
    return grp:Slider({ Name = name, Min = min, Max = max, Default = def, Suffix = suffix or "", Step = step or 1,
        Callback = function(v) bind(cfg, key, v) end })
end


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
            notify("Fonte indisponível neste executor (precisa de writefile e getcustomasset).")
            return
        end
    else
        return
    end
    if Window.Gui then retagFonts(Window.Gui) end
    retagFonts(overlay)
end

local cfg = Window:Tab({ Name = "CONFIGURAÇÕES", Icon = "settings" })

-- Geral
g = cfg:Groupbox({ Name = "GERAL", Icon = "settings", Side = "Left" })
g:Dropdown({ Name = "Idioma", Options = { "English", "Español", "Português (Brasil)", "简体中文", "Русский" }, Default = LANG_NAMES[currentLang], Callback = function(v) setLanguage(LANG_CODES[type(v) == "table" and v[1] or v] or "pt") end })
g:Keybind({ Name = "Tecla do menu", Default = "RightShift", OnChanged = function(k) Window:SetKeybind(k); keys.menu = k.Name; refreshPanels() end, Callback = function() end })
g:Keybind({ Name = "Tecla do cursor", Default = "LeftAlt", OnChanged = function(k) cursorKey = k; keys.cursor = k.Name; refreshPanels() end, Callback = function() end })
g:Toggle({ Name = "Cursor livre", Default = true, Callback = function(v) cursorFree = v end })
T(g, "Ocultar indisponíveis")
g:Toggle({ Name = "Fixar botão móvel", Default = false, Callback = function(v) pcall(function() Window:SetIslandDraggable(not v) end) end })
g:Button({ Name = "Rever tutorial", Callback = function() notify(tr(IS_MOBILE and "Toque no botão flutuante para abrir o menu." or "Pressione a tecla do menu para abrir ou fechar.")) end })
g:Button({ Name = "Sair", Callback = function() overlay:Destroy(); Window:Destroy() end })

-- Aparência
local presetNames = Library.ThemeOrder
g = cfg:Groupbox({ Name = "APARÊNCIA", Icon = "palette", Side = "Left" })
do
    -- círculos de cor: tocar aplica o tema na hora
    local swatches = Instance.new("Frame")
    swatches.BackgroundTransparency = 1; swatches.Size = UDim2.new(1, 0, 0, 0); swatches.AutomaticSize = Enum.AutomaticSize.Y
    swatches.LayoutOrder = g:_nextOrder()
    local sp = Instance.new("UIPadding", swatches); sp.PaddingTop = UDim.new(0, 8); sp.PaddingBottom = UDim.new(0, 8); sp.PaddingLeft = UDim.new(0, 12)
    local grid = Instance.new("UIGridLayout", swatches)
    grid.CellSize = UDim2.fromOffset(30, 30); grid.CellPadding = UDim2.fromOffset(10, 10); grid.SortOrder = Enum.SortOrder.LayoutOrder
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
        local b = Instance.new("TextButton")
        b.Text = ""; b.AutoButtonColor = false; b.BackgroundColor3 = accentOf(name); b.LayoutOrder = i; b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        local ring = Instance.new("UIStroke", b); ring.Thickness = 2; ring.Color = Color3.new(1, 1, 1)
        ring.Transparency = (Library.ThemeName == name) and 0 or 1
        rings[name] = ring
        b.MouseButton1Click:Connect(function()
            Library:SetTheme(name)
            for n, r in pairs(rings) do r.Transparency = (n == name) and 0 or 1 end
            wmStroke.Color = Library.Theme.Accent; klStroke.Color = Library.Theme.Accent
        end)
        b.Parent = swatches
    end
end
T(g, "Cubo", true)
g:Dropdown({ Name = "Fonte", Options = { "Arimo", "Arcade", "Code", "Press Start 2P", "Silkscreen" }, Default = "Arimo", Callback = function(v) setFont(type(v) == "table" and v[1] or v) end })
T(g, "Bordas estáticas"); T(g, "Fundo"); T(g, "Sombra")

-- Marca d'água
g = cfg:Groupbox({ Name = "MARCA D'ÁGUA", Icon = "scan", Side = "Right" })
g:Toggle({ Name = "Ativar", Default = true, Callback = function(v) bind(WM, "On", v) end })
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
g:Toggle({ Name = "Ativar", Default = true, Callback = function(v) bind(KL, "On", v) end })
g:Dropdown({ Name = "Exibir", Options = { "Mostrar tudo", "Ocultar" }, Default = "Mostrar tudo",
    Callback = function(v) v = type(v) == "table" and v[1] or v; bind(KL, "On", v ~= "Ocultar") end })
g:Toggle({ Name = "Fixar", Default = false, Callback = function(v) KL.Pin = v end })
g:Toggle({ Name = "Sombra", Default = true, Callback = function(v) bind(KL, "Shadow", v) end })
SB(g, "Tamanho", 50, 200, 100, "%", 1, KL, "Size")
SB(g, "Largura", 150, 600, 335, "", 1, KL, "Width")
SB(g, "Altura máxima", 20, 500, 300, "", 1, KL, "MaxH")
SB(g, "Transp. fundo", 0, 1, 0.10, "", 0.01, KL, "BgT")
SB(g, "Transp. do texto", 0, 1, 0, "", 0.01, KL, "TxtT")
SB(g, "Transp. da borda", 0, 1, 0, "", 0.01, KL, "BrdT")
SB(g, "Raio dos cantos", 0, 20, 6, " px", 1, KL, "Radius")

refreshPanels()
Window:Notify({ Title = "BBC HUB", Content = tr("Interface carregada."), Duration = 4 })
