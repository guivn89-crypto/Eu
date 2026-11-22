--[[
    BBC HUB - Window
    Abas, grupos, janela principal, persistência de configuração,
    ilha de FPS e overlays (watermark / lista de atalhos).
]]

local Library = BBC.Library
local Utils = BBC.Utils
local Security = BBC.Security

-- Defensive: Ensure Library.Fonts exists before any UI code accesses it
local InitUtils = BBC.Modules["utils.init"]
if InitUtils and InitUtils.ensureFonts then
    InitUtils.ensureFonts(Library)
end

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