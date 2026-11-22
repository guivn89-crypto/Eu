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
