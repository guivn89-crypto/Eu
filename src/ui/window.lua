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
