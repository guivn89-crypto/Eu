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