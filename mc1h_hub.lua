--!nocheck
-- mc1h HUB (Luau, ambiente de executor). Gerado por build.sh a partir de parts/*.lua.
-- Valores especificos do jogo ficam em H.Profile (nil = nao medido, recurso fica bloqueado).
-- Coordenadas: Camera:WorldToViewportPoint devolve pixels de viewport (origem no canto superior esquerdo),
-- o mesmo espaco de UserInputService:GetMouseLocation() e de Drawing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local genv = (getgenv and getgenv()) or _G
if genv.__MC1H_HUB and genv.__MC1H_HUB.Destroy then
	pcall(genv.__MC1H_HUB.Destroy)
end

local H = { Cfg = {}, Def = {}, OnChange = {}, Refresh = {}, Conns = {}, Cleanups = {}, Alive = true, Friends = {} }
genv.__MC1H_HUB = H

H.Cap = {
	Drawing = (Drawing ~= nil and Drawing.new ~= nil),
	Hook = (hookmetamethod ~= nil and getnamecallmethod ~= nil and checkcaller ~= nil),
	CClosure = (newcclosure ~= nil),
	Files = (writefile ~= nil and readfile ~= nil),
}

-- Perfil do jogo. TUDO aqui e nil ate ser medido no jogo; nada e inventado.
-- Match.<categoria> = { names = {"trecho do nome"}, tag = "CollectionService tag" }
-- Staff.<papel>     = { GroupId = numero, MinRank = numero }
H.Profile = {
	Match = {}, -- Container, GroundItem, QuestItem, Body, Extraction, Boss, Mine, Door, Leaf, Trunk
	Staff = {}, -- Tester, Moderator
	Remotes = {}, -- Reload, MeleeHit, Refill ...
}

-- Perfil externo: defina getgenv().MC1H_PROFILE = { Match = {...}, Staff = {...}, Remotes = {...}, ... } antes de carregar o hub.
do
	local ext = genv.MC1H_PROFILE
	if type(ext) == "table" then
		for k, v in pairs(ext) do
			if type(v) == "table" and type(H.Profile[k]) == "table" then
				for k2, v2 in pairs(v) do
					H.Profile[k][k2] = v2
				end
			else
				H.Profile[k] = v
			end
		end
	end
end

----------------------------------------------------------------------
-- Ciclo de vida
----------------------------------------------------------------------
function H.Connect(signal, fn)
	local c = signal:Connect(fn)
	H.Conns[#H.Conns + 1] = c
	return c
end

function H.OnCleanup(fn)
	H.Cleanups[#H.Cleanups + 1] = fn
end

function H.Destroy()
	H.Alive = false
	for i = #H.Cleanups, 1, -1 do
		pcall(H.Cleanups[i])
	end
	for _, c in ipairs(H.Conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(H.Conns)
	if genv.__MC1H_HUB == H then
		genv.__MC1H_HUB = nil
	end
end

----------------------------------------------------------------------
-- Configuracao (chaves planas; so numero, booleano e string vao para o arquivo)
----------------------------------------------------------------------
local FILE = "mc1h_hub_default.json"

function H.Save()
	if not H.Cap.Files then
		return false
	end
	local ok = pcall(function()
		writefile(FILE, HttpService:JSONEncode(H.Cfg))
	end)
	return ok
end

function H.Load()
	if not H.Cap.Files or not isfile then
		return false
	end
	local ok, data = pcall(function()
		if not isfile(FILE) then
			return nil
		end
		return HttpService:JSONDecode(readfile(FILE))
	end)
	if not ok or type(data) ~= "table" then
		return false
	end
	for k, v in pairs(data) do
		local t = type(v)
		if type(k) == "string" and (t == "number" or t == "boolean" or t == "string") then
			H.Cfg[k] = v
		end
	end
	return true
end

function H.Define(key, default)
	if H.Def[key] == nil then
		H.Def[key] = default
	end
	if H.Cfg[key] == nil then
		H.Cfg[key] = default
	end
	return H.Cfg[key]
end

function H.Set(key, value)
	if H.Cfg[key] == value then
		return
	end
	H.Cfg[key] = value
	local refresh = H.Refresh[key]
	if refresh then
		refresh(value)
	end
	local list = H.OnChange[key]
	if list then
		for _, fn in ipairs(list) do
			local ok, err = pcall(fn, value)
			if not ok then
				warn("[mc1h] " .. key .. ": " .. tostring(err))
			end
		end
	end
end

-- Registra callback de mudanca e chama uma vez com o valor atual.
function H.Bind(key, fn)
	local list = H.OnChange[key]
	if not list then
		list = {}
		H.OnChange[key] = list
	end
	list[#list + 1] = fn
	local ok, err = pcall(fn, H.Cfg[key])
	if not ok then
		warn("[mc1h] " .. key .. ": " .. tostring(err))
	end
end

function H.Notify(text)
	print("[mc1h] " .. tostring(text)) -- substituido pela UI
end

local warned = {}
-- Le um valor do perfil do jogo; se for nil avisa uma vez e devolve nil.
function H.Need(path)
	local v = H.Profile
	for part in string.gmatch(path, "[^%.]+") do
		v = (type(v) == "table") and v[part] or nil
	end
	if v == nil and not warned[path] then
		warned[path] = true
		H.Notify("Sem valor no perfil do jogo: " .. path)
	end
	return v
end

function H.Matches(cat, inst)
	local m = H.Profile.Match[cat]
	if not m then
		return false
	end
	if m.tag and CollectionService:HasTag(inst, m.tag) then
		return true
	end
	if m.names then
		local n = string.lower(inst.Name)
		for _, s in ipairs(m.names) do
			if string.find(n, string.lower(s), 1, true) then
				return true
			end
		end
	end
	return false
end

----------------------------------------------------------------------
-- Personagem, camera, entidades
----------------------------------------------------------------------
function H.Char()
	return LocalPlayer.Character
end

function H.Hum()
	local c = LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function H.Root()
	local c = LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function H.Camera()
	return Workspace.CurrentCamera
end

function H.ScreenRef()
	local cam = Workspace.CurrentCamera
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
		return Vector2.new(vp.X / 2, vp.Y / 2)
	end
	return UserInputService:GetMouseLocation()
end

-- Devolve Vector2 (pixels), visivel (na frente da camera e dentro da tela), profundidade.
function H.ToScreen(pos)
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil, false, 0
	end
	local v, on = cam:WorldToViewportPoint(pos)
	return Vector2.new(v.X, v.Y), (on and v.Z > 0), v.Z
end

function H.IsFriend(player)
	return player ~= nil and H.Friends[player.UserId] == true
end

function H.IsEnemy(player)
	if player == LocalPlayer or H.IsFriend(player) then
		return false
	end
	if LocalPlayer.Team == nil or player.Team == nil then
		return true
	end
	return player.Team ~= LocalPlayer.Team
end

-- NPCs: modelos com Humanoid que nao pertencem a um jogador (conjunto mantido por eventos).
local npcSet, npcStarted = {}, false
function H.StartNpcTracking()
	if npcStarted then
		return
	end
	npcStarted = true
	local function consider(d)
		if d:IsA("Humanoid") then
			local m = d.Parent
			if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
				npcSet[m] = true
			end
		end
	end
	H.Connect(Workspace.DescendantAdded, consider)
	task.spawn(function()
		local n = 0
		for _, d in ipairs(Workspace:GetDescendants()) do
			consider(d)
			n += 1
			if n % 1500 == 0 then
				task.wait()
			end
		end
	end)
end

-- Lista de entidades {model, hum, root, player, name, npc}; inclui mortas (filtre por hum.Health).
function H.Entities(withNpc)
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local c = p.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			local root = c and c:FindFirstChild("HumanoidRootPart")
			if hum and root then
				out[#out + 1] = { model = c, hum = hum, root = root, player = p, name = p.DisplayName }
			end
		end
	end
	if withNpc then
		local mine = LocalPlayer.Character
		for m in pairs(npcSet) do
			if m.Parent and m ~= mine and m:IsDescendantOf(Workspace) then
				local hum = m:FindFirstChildOfClass("Humanoid")
				local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
				if hum and root then
					out[#out + 1] = { model = m, hum = hum, root = root, npc = true, name = m.Name }
				end
			else
				npcSet[m] = nil
			end
		end
	end
	return out
end

----------------------------------------------------------------------
-- Eventos internos (fire, hit, kill) emitidos pelos efeitos de combate
----------------------------------------------------------------------
local listeners = {}
function H.OnEvent(name, fn)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end
function H.Emit(name, data)
	local l = listeners[name]
	if l then
		for _, fn in ipairs(l) do
			pcall(fn, data)
		end
	end
end

----------------------------------------------------------------------
-- Drawing com limpeza garantida
----------------------------------------------------------------------
local drawings = {}
function H.NewDrawing(class, props)
	if not H.Cap.Drawing then
		return nil
	end
	local ok, d = pcall(Drawing.new, class)
	if not ok or not d then
		return nil
	end
	for k, v in pairs(props or {}) do
		pcall(function()
			d[k] = v
		end)
	end
	drawings[d] = true
	return d
end

function H.RemoveDrawing(d)
	if d then
		drawings[d] = nil
		pcall(function()
			d:Remove()
		end)
	end
end

H.OnCleanup(function()
	for d in pairs(drawings) do
		pcall(function()
			d:Remove()
		end)
	end
	table.clear(drawings)
end)

function H.WrapC(fn)
	if H.Cap.CClosure then
		return newcclosure(fn)
	end
	return fn
end

H.Load()

----------------------------------------------------------------------
-- Interface (toque primeiro: linhas de 34px, slider por arrasto, janela arrastavel)
-- No Delta nao se usa CoreGui: o pai e gethui() ou PlayerGui.
----------------------------------------------------------------------
do
	local UI = { Tabs = {}, Current = nil }
	H.UI = UI
	local C = {
		bg = Color3.fromRGB(10, 10, 12),
		panel = Color3.fromRGB(20, 20, 24),
		row = Color3.fromRGB(28, 28, 33),
		acc = Color3.fromRGB(255, 150, 30),
		text = Color3.fromRGB(235, 235, 235),
		dim = Color3.fromRGB(150, 150, 158),
		off = Color3.fromRGB(62, 62, 70),
	}
	UI.Colors = C

	local function new(class, props, parent)
		local inst = Instance.new(class)
		for k, v in pairs(props) do
			inst[k] = v
		end
		inst.Parent = parent
		return inst
	end
	UI.New = new

	local function round(inst, r)
		new("UICorner", { CornerRadius = UDim.new(0, r) }, inst)
	end

	local function guiParent()
		if gethui then
			local ok, h = pcall(gethui)
			if ok and h then
				return h
			end
		end
		return LocalPlayer:WaitForChild("PlayerGui")
	end

	local gui = new("ScreenGui", {
		Name = "mc1h_hub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	gui.Parent = guiParent()
	UI.Gui = gui
	H.OnCleanup(function()
		gui:Destroy()
	end)

	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	local function isMove(i)
		return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
	end

	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
	local W = math.clamp(math.floor(vp.X * 0.82), 380, 660)
	local HT = math.clamp(math.floor(vp.Y * 0.8), 240, 380)

	local win = new("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(W, HT),
		Position = UDim2.new(0.5, -W / 2, 0.5, -HT / 2),
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		Active = true,
	}, gui)
	round(win, 8)
	UI.Window = win

	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, win)
	round(header, 8)
	new("TextLabel", {
		Size = UDim2.new(0, 110, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = "mc1h HUB",
		TextColor3 = C.acc,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	local search = new("TextBox", {
		Size = UDim2.new(1, -190, 0, 24),
		Position = UDim2.fromOffset(120, 6),
		BackgroundColor3 = C.row,
		Text = "",
		PlaceholderText = "buscar nesta aba",
		TextColor3 = C.text,
		PlaceholderColor3 = C.dim,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, header)
	round(search, 5)
	local closeBtn = new("TextButton", {
		Size = UDim2.fromOffset(40, 24),
		Position = UDim2.new(1, -48, 0, 6),
		BackgroundColor3 = C.row,
		Text = "X",
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		BorderSizePixel = 0,
	}, header)
	round(closeBtn, 5)

	-- arrastar a janela pelo cabecalho
	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging, dragStart, startPos = true, i.Position, win.Position
		end
	end)
	H.Connect(UserInputService.InputChanged, function(i)
		if dragging and isMove(i) then
			local d = i.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	H.Connect(UserInputService.InputEnded, function(i)
		if isPress(i) then
			dragging = false
		end
	end)

	local side = new("ScrollingFrame", {
		Size = UDim2.new(0, 104, 1, -36),
		Position = UDim2.fromOffset(0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, win)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, side)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 6) }, side)
	local content = new("Frame", {
		Size = UDim2.new(1, -104, 1, -36),
		Position = UDim2.fromOffset(104, 36),
		BackgroundTransparency = 1,
	}, win)

	----------------------------------------------------------------
	-- Abas e controles
	----------------------------------------------------------------
	local Tab = {}
	Tab.__index = Tab

	function UI.AddTab(name)
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = C.panel,
			Text = name,
			TextColor3 = C.dim,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = #UI.Tabs + 1,
		}, side)
		round(btn, 6)
		local page = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
		}, content)
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, page)
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
		}, page)
		local tab = setmetatable({ Name = name, Button = btn, Page = page, Rows = {}, N = 0 }, Tab)
		UI.Tabs[#UI.Tabs + 1] = tab
		btn.Activated:Connect(function()
			UI.Select(tab)
		end)
		if not UI.Current then
			UI.Select(tab)
		end
		return tab
	end

	function UI.Filter(q)
		q = string.lower(q or "")
		local tab = UI.Current
		if not tab then
			return
		end
		for _, r in ipairs(tab.Rows) do
			if q == "" then
				r.frame.Visible = true
			elseif r.section then
				r.frame.Visible = false
			else
				r.frame.Visible = string.find(r.label, q, 1, true) ~= nil
			end
		end
	end

	function UI.Select(tab)
		for _, t in ipairs(UI.Tabs) do
			local on = (t == tab)
			t.Page.Visible = on
			t.Button.TextColor3 = on and C.acc or C.dim
			t.Button.BackgroundColor3 = on and Color3.fromRGB(45, 32, 14) or C.panel
		end
		UI.Current = tab
		UI.Filter(search.Text)
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		UI.Filter(search.Text)
	end)

	function UI.SetVisible(v)
		win.Visible = v
	end
	function UI.Toggle()
		win.Visible = not win.Visible
	end
	closeBtn.Activated:Connect(function()
		UI.SetVisible(false)
	end)

	local launcher = new("TextButton", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(10, 70),
		BackgroundColor3 = C.panel,
		Text = "HUB",
		TextColor3 = C.acc,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		BorderSizePixel = 0,
	}, gui)
	round(launcher, 23)
	launcher.Activated:Connect(UI.Toggle)
	H.Connect(UserInputService.InputBegan, function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode.RightShift then
			UI.Toggle()
		end
	end)

	function Tab:_row(label, height, section)
		self.N += 1
		local r = new("Frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundColor3 = C.row,
			BackgroundTransparency = section and 1 or 0,
			BorderSizePixel = 0,
			LayoutOrder = self.N,
		}, self.Page)
		round(r, 6)
		self.Rows[#self.Rows + 1] = { frame = r, label = string.lower(label), section = section }
		return r
	end

	local function rowLabel(r, label, width)
		return new("TextLabel", {
			Size = UDim2.new(1, -width, 0, 34),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			Text = label,
			TextColor3 = C.text,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, r)
	end

	function Tab:Section(title)
		local r = self:_row(title, 24, true)
		new("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.fromOffset(4, 0),
			BackgroundTransparency = 1,
			Text = string.upper(title),
			TextColor3 = C.acc,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, r)
	end

	function Tab:Info(text)
		local r = self:_row(text, 0)
		r.AutomaticSize = Enum.AutomaticSize.Y
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, r)
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = C.dim,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, r)
	end

	function Tab:Toggle(label, key, default, cb)
		H.Define(key, default and true or false)
		local r = self:_row(label, 34)
		rowLabel(r, label, 64)
		local sw = new("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -50, 0.5, -10), BackgroundColor3 = C.off, BorderSizePixel = 0 }, r)
		round(sw, 10)
		local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, sw)
		round(knob, 8)
		local function paint(v)
			sw.BackgroundColor3 = v and C.acc or C.off
			knob.Position = v and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
		end
		H.Refresh[key] = paint
		paint(H.Cfg[key])
		local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, r)
		hit.Activated:Connect(function()
			H.Set(key, not H.Cfg[key])
		end)
		if cb then
			H.Bind(key, cb)
		end
	end

	function Tab:Slider(label, key, min, max, default, step, fmt, cb)
		H.Define(key, default)
		local r = self:_row(label, 48)
		rowLabel(r, label, 90).Size = UDim2.new(1, -90, 0, 26)
		local val = new("TextLabel", {
			Size = UDim2.fromOffset(80, 26),
			Position = UDim2.new(1, -90, 0, 0),
			BackgroundTransparency = 1,
			TextColor3 = C.acc,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, r)
		local bar = new("Frame", { Size = UDim2.new(1, -20, 0, 8), Position = UDim2.new(0, 10, 0, 32), BackgroundColor3 = C.off, BorderSizePixel = 0 }, r)
		round(bar, 4)
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.acc, BorderSizePixel = 0 }, bar)
		round(fill, 4)
		local function paint(v)
			local a = (v - min) / (max - min)
			fill.Size = UDim2.fromScale(math.clamp(a, 0, 1), 1)
			val.Text = fmt and string.format(fmt, v) or tostring(v)
		end
		H.Refresh[key] = paint
		paint(H.Cfg[key])
		local active = false
		local function fromX(x)
			local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			local v = min + a * (max - min)
			v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
			H.Set(key, v)
		end
		local hit = new("Frame", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -30), BackgroundTransparency = 1, Active = true }, r)
		hit.InputBegan:Connect(function(i)
			if isPress(i) then
				active = true
				self.Page.ScrollingEnabled = false
				fromX(i.Position.X)
			end
		end)
		H.Connect(UserInputService.InputChanged, function(i)
			if active and isMove(i) then
				fromX(i.Position.X)
			end
		end)
		H.Connect(UserInputService.InputEnded, function(i)
			if active and isPress(i) then
				active = false
				self.Page.ScrollingEnabled = true
			end
		end)
		if cb then
			H.Bind(key, cb)
		end
	end

	function Tab:Choice(label, key, options, default, cb)
		H.Define(key, default)
		local r = self:_row(label, 34)
		rowLabel(r, label, 140)
		local val = new("TextLabel", {
			Size = UDim2.fromOffset(130, 34),
			Position = UDim2.new(1, -138, 0, 0),
			BackgroundTransparency = 1,
			TextColor3 = C.acc,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, r)
		local function paint(v)
			val.Text = tostring(v) .. " >"
		end
		H.Refresh[key] = paint
		paint(H.Cfg[key])
		local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, r)
		hit.Activated:Connect(function()
			local idx = 0
			for n, o in ipairs(options) do
				if o == H.Cfg[key] then
					idx = n
				end
			end
			H.Set(key, options[(idx % #options) + 1])
		end)
		if cb then
			H.Bind(key, cb)
		end
	end

	function Tab:Button(label, fn)
		local r = self:_row(label, 34)
		local b = new("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = label,
			TextColor3 = C.text,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
		}, r)
		b.Activated:Connect(function()
			local ok, err = pcall(fn)
			if not ok then
				warn("[mc1h] " .. label .. ": " .. tostring(err))
				H.Notify("Erro em '" .. label .. "' (veja o console)")
			end
		end)
	end

	function Tab:Input(label, key, placeholder, default)
		H.Define(key, default or "")
		local r = self:_row(label, 34)
		rowLabel(r, label, 130)
		local box = new("TextBox", {
			Size = UDim2.fromOffset(112, 24),
			Position = UDim2.new(1, -120, 0.5, -12),
			BackgroundColor3 = C.bg,
			Text = tostring(H.Cfg[key]),
			PlaceholderText = placeholder or "",
			TextColor3 = C.text,
			PlaceholderColor3 = C.dim,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			ClearTextOnFocus = false,
			BorderSizePixel = 0,
		}, r)
		round(box, 5)
		H.Refresh[key] = function(v)
			box.Text = tostring(v)
		end
		box.FocusLost:Connect(function()
			H.Set(key, box.Text)
		end)
	end

	----------------------------------------------------------------
	-- Notificacoes
	----------------------------------------------------------------
	local toasts = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(260, 10),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, gui)
	new("UIListLayout", { Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }, toasts)

	H.Notify = function(text, dur)
		if not H.Alive then
			return
		end
		local kids = toasts:GetChildren()
		local count = 0
		for _, k in ipairs(kids) do
			if k:IsA("TextLabel") then
				count += 1
				if count >= 5 then
					k:Destroy()
				end
			end
		end
		local t = new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.panel,
			BackgroundTransparency = 0.1,
			Text = tostring(text),
			TextColor3 = C.text,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			BorderSizePixel = 0,
			LayoutOrder = math.floor(os.clock() * 100),
		}, toasts)
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, t)
		round(t, 6)
		task.delay(dur or 3.5, function()
			if t.Parent then
				t:Destroy()
			end
		end)
	end

	H.Tabs = {
		Visuais = UI.AddTab("VISUAIS"),
		Jogador = UI.AddTab("JOGADOR"),
		Combate = UI.AddTab("COMBATE"),
		Mundo = UI.AddTab("MUNDO"),
		Extras = UI.AddTab("EXTRAS"),
		Servidores = UI.AddTab("SERVIDORES"),
		Jogo = UI.AddTab("JOGO"),
		Config = UI.AddTab("CONFIG"),
	}
end

----------------------------------------------------------------------
-- VISUAIS: ESP de jogadores/NPCs/corpos e de objetos (objetos dependem de H.Profile.Match)
----------------------------------------------------------------------
do
	local T = H.Tabs.Visuais
	local Cam = H.Camera
	local COL = {
		enemy = Color3.fromRGB(255, 70, 70),
		team = Color3.fromRGB(80, 160, 255),
		friend = Color3.fromRGB(80, 255, 120),
		npc = Color3.fromRGB(255, 210, 60),
		body = Color3.fromRGB(190, 190, 190),
	}

	T:Section("ESP")
	T:Toggle("Jogador", "esp.player", true)
	T:Toggle("NPCs", "esp.npc", false, function(v)
		if v then
			H.StartNpcTracking()
		end
	end)
	T:Toggle("Corpo", "esp.body", false, function(v)
		if v then
			H.StartNpcTracking()
		end
	end)
	T:Toggle("Caixa", "esp.box", true)
	T:Toggle("Nome", "esp.name", true)
	T:Toggle("Vida", "esp.health", true)
	T:Toggle("Distancia", "esp.dist", true)
	T:Toggle("Linhas", "esp.tracer", false)
	T:Toggle("Ocultar time", "esp.hideTeam", false)
	T:Slider("Distancia maxima", "esp.maxDist", 50, 3000, 1500, 50, "%d")

	if not H.Cap.Drawing then
		H.Notify("Drawing indisponivel neste executor: ESP usa Highlight (sem caixa/texto).", 6)
	end

	local pool = {}
	local function newSet()
		return {
			box = H.NewDrawing("Square", { Thickness = 1, Filled = false, Visible = false }),
			name = H.NewDrawing("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
			info = H.NewDrawing("Text", { Size = 12, Center = true, Outline = true, Visible = false }),
			bar = H.NewDrawing("Line", { Thickness = 2, Visible = false }),
			tracer = H.NewDrawing("Line", { Thickness = 1, Visible = false }),
		}
	end
	local function hide(set)
		for k, d in pairs(set) do
			if k == "hl" then
				d.Enabled = false
			else
				d.Visible = false
			end
		end
	end
	local function destroy(model)
		local set = pool[model]
		if not set then
			return
		end
		for k, d in pairs(set) do
			if k == "hl" then
				d:Destroy()
			else
				H.RemoveDrawing(d)
			end
		end
		pool[model] = nil
	end
	H.OnCleanup(function()
		for m in pairs(pool) do
			destroy(m)
		end
	end)

	local function colorFor(e, alive)
		if not alive then
			return COL.body
		end
		if e.npc then
			return COL.npc
		end
		if H.IsFriend(e.player) then
			return COL.friend
		end
		if not H.IsEnemy(e.player) then
			return COL.team
		end
		return COL.enemy
	end

	H.Connect(RunService.RenderStepped, function()
		local cam = Cam()
		local C = H.Cfg
		local wantP, wantN, wantB = C["esp.player"], C["esp.npc"], C["esp.body"]
		if not cam or not (wantP or wantN or wantB) then
			for _, set in pairs(pool) do
				hide(set)
			end
			return
		end
		local camPos = cam.CFrame.Position
		local vp = cam.ViewportSize
		local maxD = C["esp.maxDist"]
		local seen = {}
		for _, e in ipairs(H.Entities(wantN or wantB)) do
			local alive = e.hum.Health > 0
			local want
			if not alive then
				want = wantB
			elseif e.npc then
				want = wantN
			else
				want = wantP and not (C["esp.hideTeam"] and not H.IsEnemy(e.player) and not H.IsFriend(e.player))
			end
			local rp = e.root.Position
			local dist = (camPos - rp).Magnitude
			if want and dist <= maxD then
				local set = pool[e.model]
				if not set then
					set = newSet()
					pool[e.model] = set
				end
				local col = colorFor(e, alive)
				if not H.Cap.Drawing then
					if not set.hl then
						set.hl = Instance.new("Highlight")
						set.hl.FillTransparency = 0.65
						set.hl.Parent = H.UI.Gui
					end
					set.hl.Adornee = e.model
					set.hl.FillColor, set.hl.OutlineColor = col, col
					set.hl.Enabled = true
					seen[e.model] = true
				else
					local top = cam:WorldToViewportPoint(rp + Vector3.new(0, 3, 0))
					local bot = cam:WorldToViewportPoint(rp - Vector3.new(0, 3.5, 0))
					if top.Z > 0 and bot.Z > 0 then
						seen[e.model] = true
						local h = math.abs(bot.Y - top.Y)
						local w = h / 2
						local x = top.X - w / 2
						set.box.Visible = C["esp.box"]
						set.box.Color = col
						set.box.Position = Vector2.new(x, top.Y)
						set.box.Size = Vector2.new(w, h)
						set.name.Visible = C["esp.name"]
						set.name.Color = col
						set.name.Text = alive and e.name or (e.name .. " [corpo]")
						set.name.Position = Vector2.new(top.X, top.Y - 16)
						set.info.Visible = C["esp.dist"]
						set.info.Color = Color3.new(1, 1, 1)
						set.info.Text = string.format("%dm", math.floor(dist + 0.5))
						set.info.Position = Vector2.new(top.X, bot.Y + 2)
						local showBar = C["esp.health"] and alive
						set.bar.Visible = showBar
						if showBar then
							local r = math.clamp(e.hum.Health / math.max(e.hum.MaxHealth, 1), 0, 1)
							set.bar.Color = Color3.fromRGB(255 * (1 - r), 255 * r, 0)
							set.bar.From = Vector2.new(x - 4, bot.Y)
							set.bar.To = Vector2.new(x - 4, bot.Y - h * r)
						end
						set.tracer.Visible = C["esp.tracer"]
						if C["esp.tracer"] then
							set.tracer.Color = col
							set.tracer.From = Vector2.new(vp.X / 2, vp.Y)
							set.tracer.To = Vector2.new(top.X, bot.Y)
						end
					end
				end
			end
		end
		for model, set in pairs(pool) do
			if not seen[model] then
				if model.Parent then
					hide(set)
				else
					destroy(model)
				end
			end
		end
	end)
end

----------------------------------------------------------------------
-- ESP de objetos por categoria (nomes/tags medidos no jogo, em H.Profile.Match)
----------------------------------------------------------------------
do
	local T = H.Tabs.Visuais
	local cats = {
		Container = { label = "Recipiente", color = Color3.fromRGB(80, 220, 255) },
		GroundItem = { label = "Item", color = Color3.fromRGB(255, 255, 255) },
		QuestItem = { label = "Missao", color = Color3.fromRGB(255, 220, 60) },
		Extraction = { label = "Saida", color = Color3.fromRGB(80, 255, 120) },
		Boss = { label = "Chefe", color = Color3.fromRGB(255, 60, 60) },
		Mine = { label = "Mina", color = Color3.fromRGB(255, 140, 0) },
	}
	for _, c in pairs(cats) do
		c.set, c.on, c.scanned, c.draw, c.near = {}, false, false, {}, {}
	end
	local listening = false

	local function consider(cat, d)
		if not (d:IsA("Model") or d:IsA("BasePart")) then
			return
		end
		if not H.Matches(cat, d) then
			return
		end
		if d:IsA("BasePart") and d.Parent and d.Parent:IsA("Model") and H.Matches(cat, d.Parent) then
			return
		end
		cats[cat].set[d] = true
	end

	local function startListening()
		if listening then
			return
		end
		listening = true
		H.Connect(Workspace.DescendantAdded, function(d)
			for name, c in pairs(cats) do
				if c.on then
					consider(name, d)
				end
			end
		end)
	end

	local function scan(name)
		local c = cats[name]
		if c.scanned then
			return
		end
		c.scanned = true
		task.spawn(function()
			local n = 0
			for _, d in ipairs(Workspace:GetDescendants()) do
				consider(name, d)
				n += 1
				if n % 1500 == 0 then
					task.wait()
				end
			end
		end)
	end

	H.Objects = {}
	-- Devolve true se ligou; false se faltam valores no perfil ou nao ha Drawing.
	function H.Objects.Enable(name, on)
		local c = cats[name]
		if not on then
			c.on = false
			return true
		end
		if not H.Cap.Drawing then
			H.Notify("ESP de objetos precisa de Drawing (indisponivel).")
			return false
		end
		if not H.Need("Match." .. name) then
			return false
		end
		c.on = true
		startListening()
		scan(name)
		return true
	end

	local function toggleFor(tab, label, name, key)
		tab:Toggle(label, key, false, function(v)
			if not H.Objects.Enable(name, v and true or false) then
				H.Set(key, false)
			end
		end)
	end
	T:Section("Objetos (precisam do perfil do jogo)")
	toggleFor(T, "Recipiente", "Container", "esp.container")
	toggleFor(T, "Item no chao", "GroundItem", "esp.ground")
	toggleFor(T, "Itens de missao", "QuestItem", "esp.quest")
	T:Slider("Distancia dos objetos", "esp.objDist", 20, 1500, 400, 10, "%d")
	H.ObjToggle = toggleFor -- usado na aba Mundo (saidas, chefes, minas)

	local function pos(inst)
		if inst:IsA("Model") then
			return inst:GetPivot().Position
		end
		return inst.Position
	end

	local lastNear = 0
	H.Connect(RunService.RenderStepped, function()
		local cam = H.Camera()
		if not cam then
			return
		end
		local camPos = cam.CFrame.Position
		local now = os.clock()
		local refresh = (now - lastNear) > 0.4
		if refresh then
			lastNear = now
		end
		local maxD = H.Cfg["esp.objDist"]
		for _, c in pairs(cats) do
			if c.on then
				if refresh then
					local list = {}
					for inst in pairs(c.set) do
						if inst.Parent and inst:IsDescendantOf(Workspace) then
							local d = (pos(inst) - camPos).Magnitude
							if d <= maxD then
								list[#list + 1] = { inst = inst, d = d }
							end
						else
							c.set[inst] = nil
						end
					end
					table.sort(list, function(a, b)
						return a.d < b.d
					end)
					for i = #list, 61, -1 do
						list[i] = nil
					end
					c.near = list
				end
				local used = {}
				for _, it in ipairs(c.near) do
					local inst = it.inst
					if inst.Parent then
						local p = pos(inst)
						local v = cam:WorldToViewportPoint(p)
						local t = c.draw[inst]
						if not t then
							t = H.NewDrawing("Text", { Size = 12, Center = true, Outline = true, Visible = false })
							c.draw[inst] = t
						end
						if t then
							used[inst] = true
							t.Visible = v.Z > 0
							t.Color = c.color
							t.Position = Vector2.new(v.X, v.Y)
							t.Text = string.format("%s %s %dm", c.label, inst.Name, math.floor((p - camPos).Magnitude + 0.5))
						end
					end
				end
				for inst, t in pairs(c.draw) do
					if not used[inst] then
						if t.Visible then
							t.Visible = false
						end
						if not inst.Parent then
							H.RemoveDrawing(t)
							c.draw[inst] = nil
						end
					end
				end
			else
				for inst, t in pairs(c.draw) do
					H.RemoveDrawing(t)
					c.draw[inst] = nil
				end
			end
		end
	end)
end

----------------------------------------------------------------------
-- VISUAIS: efeitos locais (so no seu cliente) e interface de ferramentas
----------------------------------------------------------------------
do
	local T = H.Tabs.Visuais
	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local ACC = Color3.fromRGB(255, 150, 30)
	local NAMES = { "mc1h_aura", "mc1h_halo", "mc1h_trail", "mc1h_trA0", "mc1h_trA1" }

	T:Section("Local (so voce ve)")

	local function clearFx(char)
		for _, n in ipairs(NAMES) do
			local o = char:FindFirstChild(n, true)
			while o do
				o:Destroy()
				o = char:FindFirstChild(n, true)
			end
		end
	end

	local function applyFx()
		local char, root = H.Char(), H.Root()
		if not (char and root) then
			return
		end
		clearFx(char)
		local C = H.Cfg
		if C["local.aura"] then
			local p = Instance.new("ParticleEmitter")
			p.Name = "mc1h_aura"
			p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			p.Rate = 30
			p.Lifetime = NumberRange.new(0.6, 1)
			p.Speed = NumberRange.new(1, 3)
			p.SpreadAngle = Vector2.new(180, 180)
			p.Size = NumberSequence.new(0.5, 0)
			p.LightEmission = 1
			p.Color = ColorSequence.new(ACC)
			p.Parent = root
		end
		if C["local.trail"] then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "mc1h_trA0", "mc1h_trA1"
			a0.Position, a1.Position = Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)
			a0.Parent, a1.Parent = root, root
			local tr = Instance.new("Trail")
			tr.Name = "mc1h_trail"
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Lifetime = 0.6
			tr.LightEmission = 1
			tr.Color = ColorSequence.new(ACC, Color3.fromRGB(80, 160, 255))
			tr.Transparency = NumberSequence.new(0, 1)
			tr.Parent = root
		end
		local head = char:FindFirstChild("Head")
		if C["local.halo"] and head then
			local m = Instance.new("Model")
			m.Name = "mc1h_halo"
			for i = 1, 12 do
				local a = (i / 12) * math.pi * 2
				local b = Instance.new("Part")
				b.Shape = Enum.PartType.Ball
				b.Size = Vector3.new(0.25, 0.25, 0.25)
				b.Material = Enum.Material.Neon
				b.Color = ACC
				b.CanCollide, b.CanQuery, b.CanTouch, b.Massless = false, false, false, true
				b.CFrame = head.CFrame * CFrame.new(math.cos(a) * 1.0, 1.6, math.sin(a) * 1.0)
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = head, b
				w.Parent = b
				b.Parent = m
			end
			m.Parent = char
		end
	end

	T:Toggle("Aura", "local.aura", false, applyFx)
	T:Toggle("Auréola", "local.halo", false, applyFx)
	T:Toggle("Rastro estelar", "local.trail", false, applyFx)
	T:Toggle("Circulo de salto", "local.jump", false)

	local function ring(root, hum)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = ACC
		p.Size = Vector3.new(0.15, 2, 2)
		p.CFrame = CFrame.new(root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		p.Parent = Workspace
		TweenService:Create(p, TweenInfo.new(0.6), { Size = Vector3.new(0.15, 9, 9), Transparency = 1 }):Play()
		Debris:AddItem(p, 0.7)
	end

	local stateConn
	local function hookChar(char)
		task.spawn(function()
			local hum = char:WaitForChild("Humanoid", 10)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not (hum and root and H.Alive) then
				return
			end
			if stateConn then
				stateConn:Disconnect()
			end
			stateConn = hum.StateChanged:Connect(function(_, new)
				if H.Cfg["local.jump"] and new == Enum.HumanoidStateType.Jumping then
					ring(root, hum)
				end
			end)
			applyFx()
		end)
	end
	H.OnCleanup(function()
		if stateConn then
			stateConn:Disconnect()
		end
		local c = H.Char()
		if c then
			clearFx(c)
		end
	end)
	H.Connect(LocalPlayer.CharacterAdded, hookChar)
	if LocalPlayer.Character then
		hookChar(LocalPlayer.Character)
	end

	------------------------------------------------------------------
	-- Interface de ferramentas
	------------------------------------------------------------------
	T:Section("Interface do jogo")

	local function toolList()
		local out = {}
		local ch, bp = LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")
		if ch then
			for _, t in ipairs(ch:GetChildren()) do
				if t:IsA("Tool") then
					out[#out + 1] = { tool = t, equipped = true }
				end
			end
		end
		if bp then
			for _, t in ipairs(bp:GetChildren()) do
				if t:IsA("Tool") then
					out[#out + 1] = { tool = t, equipped = false }
				end
			end
		end
		return out
	end
	local function toggleEquip(entry)
		local hum = H.Hum()
		if not hum then
			return
		end
		if entry.equipped then
			hum:UnequipTools()
		else
			hum:EquipTool(entry.tool)
		end
	end

	local defaultBackpack = true
	pcall(function()
		defaultBackpack = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)
	T:Toggle("Mochila (padrao do Roblox)", "ui.backpack", defaultBackpack, function(v)
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, v and true or false)
		end)
	end)

	-- Barra rapida: botoes de ferramentas na base da tela; Mochila personalizada: lista rolavel.
	local New, Col = H.UI.New, H.UI.Colors
	local bar = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = false,
	}, H.UI.Gui)
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, bar)
	local list = New("ScrollingFrame", {
		Size = UDim2.fromOffset(190, 220),
		Position = UDim2.new(1, -200, 0.5, -110),
		BackgroundColor3 = Col.bg,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, H.UI.Gui)
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, list)

	local function rebuild(container, size)
		for _, c in ipairs(container:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for i, entry in ipairs(toolList()) do
			local b = New("TextButton", {
				Size = size,
				BackgroundColor3 = entry.equipped and Color3.fromRGB(70, 46, 14) or Col.row,
				Text = entry.tool.Name,
				TextColor3 = entry.equipped and Col.acc or Col.text,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextWrapped = true,
				BorderSizePixel = 0,
				LayoutOrder = i,
			}, container)
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
			b.Activated:Connect(function()
				toggleEquip(entry)
			end)
		end
	end

	local acc = 0
	H.Connect(RunService.Heartbeat, function(dt)
		if not (bar.Visible or list.Visible) then
			return
		end
		acc += dt
		if acc < 0.4 then
			return
		end
		acc = 0
		if bar.Visible then
			rebuild(bar, UDim2.fromOffset(64, 44))
		end
		if list.Visible then
			rebuild(list, UDim2.new(1, 0, 0, 32))
		end
	end)

	T:Toggle("Barra rapida", "ui.hotbar", false, function(v)
		bar.Visible = v and true or false
	end)
	T:Toggle("Mochila personalizada", "ui.bplist", false, function(v)
		list.Visible = v and true or false
	end)
end

----------------------------------------------------------------------
-- JOGADOR: movimento (valores de velocidade/voo sao padroes, nao calibrados para nenhum jogo)
----------------------------------------------------------------------
do
	local T = H.Tabs.Jogador
	T:Section("Movimento")
	T:Toggle("Hack de velocidade", "move.speed", false, function(v)
		local hum = H.Hum()
		if v then
			H.MoveOrigSpeed = hum and hum.WalkSpeed or H.MoveOrigSpeed
		elseif hum and H.MoveOrigSpeed then
			hum.WalkSpeed = H.MoveOrigSpeed
		end
	end)
	T:Choice("Modo da velocidade", "move.speedMode", { "WalkSpeed", "CFrame" }, "CFrame")
	T:Slider("Velocidade", "move.speedVal", 16, 200, 32, 1, "%d")
	T:Toggle("Sprint automatico", "move.sprint", false)
	T:Slider("Multiplicador do sprint", "move.sprintMult", 1.1, 3, 1.5, 0.1, "%.1fx")
	T:Toggle("Pulos seguidos", "move.bhop", false)
	T:Toggle("Controle no ar", "move.air", false)
	T:Toggle("Voar", "move.fly", false)
	T:Slider("Velocidade do voo", "move.flySpeed", 10, 200, 60, 5, "%d")
	T:Toggle("Sem dano de queda", "move.nofall", false)
	T:Toggle("Sempre no chao", "move.ground", false)
	T:Toggle("Jesus", "move.jesus", false)
	T:Toggle("Aranha", "move.spider", false)
	T:Slider("Velocidade da aranha", "move.spiderSpeed", 5, 80, 25, 1, "%d")

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local rayWater = RaycastParams.new()
	rayWater.FilterType = Enum.RaycastFilterType.Exclude
	rayWater.IgnoreWater = false

	local bv
	local function stopFly()
		if bv then
			bv:Destroy()
			bv = nil
		end
	end
	H.OnCleanup(function()
		stopFly()
		local hum = H.Hum()
		if hum and H.MoveOrigSpeed and H.Cfg["move.speed"] then
			hum.WalkSpeed = H.MoveOrigSpeed
		end
	end)
	H.Bind("move.fly", function(v)
		if not v then
			stopFly()
		end
	end)

	local platform = Instance.new("Part")
	platform.Name = "mc1h_jesus"
	platform.Anchored = true
	platform.Transparency = 1
	platform.CanCollide = false
	platform.CanQuery = false
	platform.CanTouch = false
	platform.Size = Vector3.new(10, 1, 10)
	platform.Parent = Workspace
	H.OnCleanup(function()
		platform:Destroy()
	end)

	local function worldUp(keyUp, keyDown)
		local up = 0
		if UserInputService:IsKeyDown(keyUp) then
			up += 1
		end
		if UserInputService:IsKeyDown(keyDown) then
			up -= 1
		end
		return up
	end

	H.Connect(RunService.Stepped, function(_, dt)
		local C = H.Cfg
		local char, hum, root = H.Char(), H.Hum(), H.Root()
		if not (char and hum and root) or hum.Health <= 0 then
			platform.CanCollide = false
			return
		end
		local cam = H.Camera()
		rayParams.FilterDescendantsInstances = { char, platform }
		rayWater.FilterDescendantsInstances = { char, platform }
		local md = hum.MoveDirection
		local moving = md.Magnitude > 0.05
		local vel = root.AssemblyLinearVelocity
		local flying = C["move.fly"]

		-- velocidade
		if C["move.speed"] then
			if C["move.speedMode"] == "WalkSpeed" then
				hum.WalkSpeed = C["move.speedVal"]
			elseif moving then
				local extra = math.max(C["move.speedVal"] - hum.WalkSpeed, 0) * dt
				root.CFrame = root.CFrame + md.Unit * extra
			end
		end
		if C["move.sprint"] and moving then
			root.CFrame = root.CFrame + md.Unit * (hum.WalkSpeed * (C["move.sprintMult"] - 1) * dt)
		end

		-- pulos seguidos
		if C["move.bhop"] and moving and not flying and hum.FloorMaterial ~= Enum.Material.Air then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end

		-- controle no ar
		local state = hum:GetState()
		local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		if C["move.air"] and airborne and not flying and moving then
			local s = math.max(hum.WalkSpeed, Vector3.new(vel.X, 0, vel.Z).Magnitude)
			root.AssemblyLinearVelocity = Vector3.new(md.X * s, vel.Y, md.Z * s)
			vel = root.AssemblyLinearVelocity
		end

		-- voo
		if flying and cam then
			if not bv or not bv.Parent then
				stopFly()
				bv = Instance.new("BodyVelocity")
				bv.Name = "mc1h_fly"
				bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
				bv.Velocity = Vector3.zero
				bv.Parent = root
			end
			local localMove = cam.CFrame:VectorToObjectSpace(md)
			local dir = cam.CFrame.LookVector * (-localMove.Z) + cam.CFrame.RightVector * localMove.X
			local up = worldUp(Enum.KeyCode.E, Enum.KeyCode.Q) + worldUp(Enum.KeyCode.Space, Enum.KeyCode.LeftControl)
			if hum.Jump then
				up += 1
			end
			bv.Velocity = (dir + Vector3.new(0, math.clamp(up, -1, 1), 0)) * C["move.flySpeed"]
		end

		-- sem dano de queda: amortece a velocidade vertical perto do chao
		if C["move.nofall"] and not flying and vel.Y < -55 then
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -(math.abs(vel.Y) * 0.12 + 5), 0), rayParams)
			if hit then
				root.AssemblyLinearVelocity = Vector3.new(vel.X, -8, vel.Z)
				vel = root.AssemblyLinearVelocity
			end
		end

		-- sempre no chao
		if C["move.ground"] and not flying and airborne then
			root.AssemblyLinearVelocity = Vector3.new(vel.X, math.min(vel.Y, -60), vel.Z)
			vel = root.AssemblyLinearVelocity
		end

		-- jesus: plataforma invisivel na superficie da agua do Terrain
		if C["move.jesus"] and not flying then
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -14, 0), rayWater)
			if hit and hit.Material == Enum.Material.Water then
				platform.CFrame = CFrame.new(hit.Position - Vector3.new(0, 0.5, 0))
				platform.CanCollide = true
			else
				platform.CanCollide = false
			end
		else
			platform.CanCollide = false
		end

		-- aranha: sobe paredes ao andar contra elas
		if C["move.spider"] and moving and not flying then
			local hit = Workspace:Raycast(root.Position, root.CFrame.LookVector * 2.5, rayParams)
			if hit then
				root.AssemblyLinearVelocity = Vector3.new(vel.X * 0.2, C["move.spiderSpeed"], vel.Z * 0.2)
			end
		end
	end)
end

----------------------------------------------------------------------
-- JOGADOR: primeira pessoa, campo de visao, zoom, terceira pessoa, camera livre
----------------------------------------------------------------------
do
	local T = H.Tabs.Jogador

	T:Section("Corpo e maos (primeira pessoa)")
	T:Toggle("Corpo em 1a pessoa", "fp.body", false)
	T:Toggle("Maos", "fp.hands", false)
	T:Toggle("Item na mao", "fp.item", false)
	local ARMS = {
		LeftHand = true, RightHand = true, LeftLowerArm = true, RightLowerArm = true,
		LeftUpperArm = true, RightUpperArm = true, ["Left Arm"] = true, ["Right Arm"] = true,
	}
	H.Connect(RunService.RenderStepped, function()
		local C = H.Cfg
		if not (C["fp.body"] or C["fp.hands"] or C["fp.item"]) then
			return
		end
		local char = H.Char()
		if not char then
			return
		end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				if d:FindFirstAncestorWhichIsA("Tool") then
					if C["fp.item"] then
						d.LocalTransparencyModifier = 0
					end
				elseif d.Name ~= "Head" and not d:FindFirstAncestorWhichIsA("Accessory") then
					if C["fp.body"] or (C["fp.hands"] and ARMS[d.Name]) then
						d.LocalTransparencyModifier = 0
					end
				end
			end
		end
	end)

	T:Section("Campo de visao")
	T:Toggle("Alterar campo de visao", "cam.fovOn", false)
	T:Slider("Campo de visao", "cam.fov", 30, 120, 90, 1, "%d")
	T:Slider("Visao com zoom", "cam.zoomFov", 5, 60, 20, 1, "%d")
	T:Choice("Tecla do zoom", "cam.zoomKey", { "N", "Z", "X", "C", "V" }, "N")
	local zoomOn = false
	T:Button("Zoom (alternar)", function()
		zoomOn = not zoomOn
	end)
	H.Connect(UserInputService.InputBegan, function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode[H.Cfg["cam.zoomKey"]] then
			zoomOn = true
		end
	end)
	H.Connect(UserInputService.InputEnded, function(i)
		if i.KeyCode == Enum.KeyCode[H.Cfg["cam.zoomKey"]] then
			zoomOn = false
		end
	end)
	local applied, base = false, 70
	RunService:BindToRenderStep("mc1h_fov", Enum.RenderPriority.Camera.Value + 2, function()
		local cam = H.Camera()
		if not cam then
			return
		end
		local C = H.Cfg
		local want = (zoomOn and C["cam.zoomFov"]) or (C["cam.fovOn"] and C["cam.fov"]) or nil
		if want then
			if not applied then
				base, applied = cam.FieldOfView, true
			end
			cam.FieldOfView = want
		elseif applied then
			cam.FieldOfView, applied = base, false
		end
	end)
	H.OnCleanup(function()
		pcall(function()
			RunService:UnbindFromRenderStep("mc1h_fov")
		end)
		local cam = H.Camera()
		if cam and applied then
			cam.FieldOfView = base
		end
	end)

	T:Section("Camera")
	local orig
	local function applyThird()
		if not orig then
			return
		end
		LocalPlayer.CameraMode = Enum.CameraMode.Classic
		LocalPlayer.CameraMaxZoomDistance = math.max(orig.max, 60)
		LocalPlayer.CameraMinZoomDistance = H.Cfg["cam.thirdDist"]
	end
	T:Toggle("Terceira pessoa", "cam.third", false, function(v)
		if v then
			orig = orig or {
				min = LocalPlayer.CameraMinZoomDistance,
				max = LocalPlayer.CameraMaxZoomDistance,
				mode = LocalPlayer.CameraMode,
			}
			applyThird()
		elseif orig then
			LocalPlayer.CameraMinZoomDistance = orig.min
			LocalPlayer.CameraMaxZoomDistance = orig.max
			LocalPlayer.CameraMode = orig.mode
			orig = nil
		end
	end)
	T:Slider("Distancia da camera (3a pessoa)", "cam.thirdDist", 5, 40, 12, 1, "%d", function()
		applyThird()
	end)
	H.OnCleanup(function()
		if orig then
			LocalPlayer.CameraMinZoomDistance = orig.min
			LocalPlayer.CameraMaxZoomDistance = orig.max
			LocalPlayer.CameraMode = orig.mode
		end
	end)

	-- camera livre: o personagem fica parado (WalkSpeed/Jump em 0) e a camera vira Scriptable
	local free
	local function stopFree()
		if not free then
			return
		end
		local cam, hum = H.Camera(), H.Hum()
		if cam then
			cam.CameraType = free.camType
			if hum then
				cam.CameraSubject = hum
			end
		end
		if hum then
			hum.WalkSpeed = free.walk
			pcall(function()
				hum.JumpPower, hum.JumpHeight = free.jp, free.jh
			end)
		end
		free = nil
	end
	T:Toggle("Camera livre", "cam.free", false, function(v)
		local cam, hum = H.Camera(), H.Hum()
		if v and cam and hum and not free then
			local rx, ry = cam.CFrame:ToOrientation()
			free = { camType = cam.CameraType, walk = hum.WalkSpeed, jp = hum.JumpPower, jh = hum.JumpHeight, pos = cam.CFrame.Position, pitch = rx, yaw = ry }
			cam.CameraType = Enum.CameraType.Scriptable
			hum.WalkSpeed = 0
			pcall(function()
				hum.JumpPower, hum.JumpHeight = 0, 0
			end)
		elseif not v then
			stopFree()
		elseif v then
			H.Set("cam.free", false)
		end
	end)
	T:Slider("Velocidade da camera livre", "cam.freeSpeed", 5, 200, 40, 1, "%d")
	H.OnCleanup(stopFree)

	H.Connect(UserInputService.InputChanged, function(i, gp)
		if not free then
			return
		end
		local rotate = false
		if i.UserInputType == Enum.UserInputType.MouseMovement then
			rotate = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		elseif i.UserInputType == Enum.UserInputType.Touch then
			rotate = not gp
		end
		if rotate then
			free.yaw -= i.Delta.X * 0.004
			free.pitch = math.clamp(free.pitch - i.Delta.Y * 0.004, -1.5, 1.5)
		end
	end)
	H.Connect(RunService.RenderStepped, function(dt)
		if not free then
			return
		end
		local cam, hum = H.Camera(), H.Hum()
		if not (cam and hum) then
			return
		end
		local rot = CFrame.fromOrientation(free.pitch, free.yaw, 0)
		local md = rot:VectorToObjectSpace(hum.MoveDirection)
		local up = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			up += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			up -= 1
		end
		local move = rot.LookVector * (-md.Z) + rot.RightVector * md.X + Vector3.new(0, up, 0)
		free.pos += move * H.Cfg["cam.freeSpeed"] * dt
		cam.CFrame = CFrame.new(free.pos) * rot
	end)
end

----------------------------------------------------------------------
-- JOGADOR: personagem (visual local), animacoes, recursos
----------------------------------------------------------------------
do
	local T = H.Tabs.Jogador
	local VirtualUser = game:GetService("VirtualUser")
	local Stats = game:GetService("Stats")

	T:Section("Personagem (visual, so no seu cliente)")
	T:Input("Usuario do Roblox", "char.user", "nome de usuario", "")
	local function applyUser(userId)
		local hum = H.Hum()
		if not hum then
			H.Notify("Sem personagem.")
			return
		end
		local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
		if not ok or not desc then
			H.Notify("Nao consegui ler a aparencia desse usuario.")
			return
		end
		local ok2, err = pcall(function()
			hum:ApplyDescription(desc)
		end)
		if not ok2 then
			H.Notify("ApplyDescription falhou: " .. tostring(err))
		end
	end
	T:Button("Trocar personagem", function()
		local name = tostring(H.Cfg["char.user"])
		if name == "" then
			H.Notify("Digite um usuario.")
			return
		end
		local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
		if not ok or not id then
			H.Notify("Usuario nao encontrado.")
			return
		end
		applyUser(id)
	end)
	T:Button("Restaurar minha aparencia", function()
		applyUser(LocalPlayer.UserId)
	end)

	T:Section("Animacoes")
	T:Input("ID da animacao", "anim.id", "so numeros", "")
	T:Toggle("Repetir", "anim.loop", false)
	T:Slider("Velocidade da animacao", "anim.speed", 0.1, 3, 1, 0.1, "%.1fx")
	T:Slider("Peso da animacao", "anim.weight", 0, 100, 100, 1, "%d%%")
	local track
	local function stopAnim()
		if track then
			pcall(function()
				track:Stop(0.1)
				track:Destroy()
			end)
			track = nil
		end
	end
	T:Button("Reproduzir", function()
		stopAnim()
		local hum = H.Hum()
		local id = tostring(H.Cfg["anim.id"]):gsub("%D", "")
		if not hum or id == "" then
			H.Notify("Precisa de personagem e de um ID numerico.")
			return
		end
		local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 2)
		if not animator then
			H.Notify("Sem Animator no personagem.")
			return
		end
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://" .. id
		local ok, t = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if not ok or not t then
			H.Notify("Nao foi possivel carregar essa animacao.")
			return
		end
		track = t
		t.Looped = H.Cfg["anim.loop"] and true or false
		t:Play(0.1, math.max(H.Cfg["anim.weight"] / 100, 0.01), H.Cfg["anim.speed"])
	end)
	T:Button("Parar animacao", stopAnim)
	H.Bind("anim.speed", function(v)
		if track then
			track:AdjustSpeed(v)
		end
	end)
	H.Bind("anim.weight", function(v)
		if track then
			track:AdjustWeight(math.max(v / 100, 0.01))
		end
	end)
	H.OnCleanup(stopAnim)

	T:Section("Recursos")

	-- painel com dados locais
	local lbl = H.UI.New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 60),
		Size = UDim2.fromOffset(170, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = H.UI.Colors.panel,
		BackgroundTransparency = 0.15,
		TextColor3 = H.UI.Colors.text,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
		Visible = false,
	}, H.UI.Gui)
	H.UI.New("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, lbl)
	T:Toggle("Painel do jogador", "panel.on", false, function(v)
		lbl.Visible = v and true or false
	end)
	local acc, frames = 0, 0
	H.Connect(RunService.RenderStepped, function(dt)
		if not lbl.Visible then
			return
		end
		acc += dt
		frames += 1
		if acc < 0.5 then
			return
		end
		local fps = frames / acc
		acc, frames = 0, 0
		local hum, root = H.Hum(), H.Root()
		local ping = "?"
		pcall(function()
			ping = string.format("%d", math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5))
		end)
		local pos = root and root.Position or Vector3.zero
		local spd = root and root.AssemblyLinearVelocity.Magnitude or 0
		lbl.Text = string.format(
			"FPS   %d\nPing  %s ms\nVida  %d/%d\nVel   %.1f\nPos   %d %d %d\nJog.  %d",
			math.floor(fps + 0.5), ping, math.floor(hum and hum.Health or 0), math.floor(hum and hum.MaxHealth or 0), spd,
			math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z), #Players:GetPlayers()
		)
	end)

	T:Toggle("Anti AFK", "misc.afk", false)
	H.Connect(LocalPlayer.Idled, function()
		if H.Cfg["misc.afk"] then
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end
	end)

	-- renascer automatico: so com o RemoteEvent de respawn do jogo em H.Profile.Remotes.Respawn
	T:Toggle("Renascer automatico", "misc.respawn", false, function(v)
		if v and not H.Need("Remotes.Respawn") then
			H.Set("misc.respawn", false)
		end
	end)
	local function hookDeath(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		hum.Died:Connect(function()
			local r = H.Profile.Remotes.Respawn
			if H.Alive and H.Cfg["misc.respawn"] and r then
				task.delay(1.5, function()
					pcall(function()
						r:FireServer()
					end)
				end)
			end
		end)
	end
	H.Connect(LocalPlayer.CharacterAdded, function(c)
		task.spawn(hookDeath, c)
	end)
	if LocalPlayer.Character then
		task.spawn(hookDeath, LocalPlayer.Character)
	end

	-- agua do Terrain
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local water0
	T:Toggle("Remover agua", "misc.nowater", false, function(v)
		if not terrain then
			return
		end
		if v then
			water0 = water0 or { t = terrain.WaterTransparency, r = terrain.WaterReflectance, w = terrain.WaterWaveSize }
			terrain.WaterTransparency, terrain.WaterReflectance, terrain.WaterWaveSize = 1, 0, 0
		elseif water0 then
			terrain.WaterTransparency, terrain.WaterReflectance, terrain.WaterWaveSize = water0.t, water0.r, water0.w
			water0 = nil
		end
	end)
	H.OnCleanup(function()
		if terrain and water0 then
			terrain.WaterTransparency, terrain.WaterReflectance, terrain.WaterWaveSize = water0.t, water0.r, water0.w
		end
	end)

	-- nao se afogar: desliga o estado Swimming (um sistema de oxigenio proprio do jogo nao e afetado)
	local function applySwim()
		local hum = H.Hum()
		if hum then
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, not H.Cfg["misc.noswim"])
			end)
		end
	end
	T:Toggle("Nao se afogar", "misc.noswim", false, applySwim)
	H.Connect(LocalPlayer.CharacterAdded, function(c)
		c:WaitForChild("Humanoid", 10)
		applySwim()
	end)
	H.OnCleanup(function()
		H.Cfg["misc.noswim"] = false
		applySwim()
	end)
end

----------------------------------------------------------------------
-- COMBATE: mira (Fixar / Agressivo giram a camera; Silencioso redireciona raios e Mouse.Hit do cliente)
-- Unidades: raio em pixels, suavizacao em ms, velocidade do projetil em studs/s (padroes NAO calibrados).
----------------------------------------------------------------------
do
	local T = H.Tabs.Combate
	local A = { Target = nil, Entity = nil, AimPos = nil, SilentPos = nil, SilentPart = nil, Hold = false }
	H.Aim = A

	T:Section("Mira")
	T:Toggle("Mira ativa", "aim.on", false)
	T:Choice("Modo", "aim.mode", { "Silencioso", "Fixar", "Agressivo" }, "Fixar", function(v)
		if v == "Silencioso" and H.InstallSilentHooks then
			H.InstallSilentHooks()
		end
	end)
	T:Choice("Ativacao", "aim.act", { "Ao mirar", "Sempre", "Botao" }, "Ao mirar")
	T:Info("Ao mirar = botao direito do mouse ou o botao AIM na tela. No celular, o modo Silencioso costuma precisar de Ativacao = Sempre ou Botao.")
	T:Toggle("Alvo fixo", "aim.sticky", false)
	T:Toggle("Previsao", "aim.predict", false)
	T:Slider("Velocidade do projetil (nao calibrado)", "aim.projSpeed", 100, 3000, 800, 50, "%d")
	T:Slider("Suavizacao", "aim.smooth", 0, 500, 80, 5, "%dms")
	T:Toggle("Pausa inteligente", "aim.pause", true)
	T:Toggle("Notificar alvo", "aim.notify", false)
	T:Slider("Chance de acerto (silencioso)", "aim.hit", 1, 100, 100, 1, "%d%%")

	T:Section("Alvos")
	T:Slider("Raio da mira", "aim.fov", 10, 400, 70, 5, "%d")
	T:Toggle("FOV dinamico", "aim.dynFov", true)
	T:Choice("Ponto de mira", "aim.point", { "Parte fixa", "Mais perto" }, "Parte fixa")
	T:Choice("Parte do corpo", "aim.part", { "Cabeca", "Torso", "Raiz", "Aleatorio" }, "Cabeca")
	T:Toggle("Alternativa visivel", "aim.fallback", true)
	T:Toggle("Mirar em NPCs", "aim.npc", false, function(v)
		if v then
			H.StartNpcTracking()
		end
	end)
	T:Toggle("Tiro por paredes", "aim.wall", false)
	T:Slider("Limite de verificacoes", "aim.checks", 1, 20, 7, 1, "%d")
	T:Toggle("Silencioso: hook em Raycast/FindPartOnRay", "aim.hookRay", true)
	T:Toggle("Silencioso: hook em Mouse.Hit/Target", "aim.hookMouse", true)
	T:Toggle("Silencioso: hook em ViewportPointToRay", "aim.hookCam", true)

	local PRIMARY = { ["Cabeca"] = { "Head" }, ["Torso"] = { "UpperTorso", "Torso" }, ["Raiz"] = { "HumanoidRootPart" } }
	local ALL = {
		"Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso", "LeftUpperArm", "RightUpperArm",
		"Left Arm", "Right Arm", "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg",
	}
	local function firstPart(model, names)
		for _, n in ipairs(names) do
			local p = model:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				return p
			end
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	pcall(function()
		rayParams.RespectCanCollide = true
	end)
	local visCache = setmetatable({}, { __mode = "k" })
	local budget = 0
	local function visible(cam, part, model)
		if H.Cfg["aim.wall"] then
			return true
		end
		local now = os.clock()
		local c = visCache[part]
		if c and now - c.t < 0.12 then
			return c.v
		end
		if budget <= 0 then
			return c and c.v or false
		end
		budget -= 1
		local ignore = { cam, model }
		if LocalPlayer.Character then
			ignore[#ignore + 1] = LocalPlayer.Character
		end
		rayParams.FilterDescendantsInstances = ignore
		local origin = cam.CFrame.Position
		local v = Workspace:Raycast(origin, part.Position - origin, rayParams) == nil
		visCache[part] = { t = now, v = v }
		return v
	end

	function A.Ref(cam)
		local vp = cam.ViewportSize
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
			return Vector2.new(vp.X / 2, vp.Y / 2)
		end
		return UserInputService:GetMouseLocation()
	end
	function A.Radius(cam)
		local r = H.Cfg["aim.fov"]
		if H.Cfg["aim.dynFov"] then
			r = r * (70 / math.max(cam.FieldOfView, 1))
		end
		return r
	end

	-- melhor parte de uma entidade dentro de maxD pixels da referencia; devolve parte e distancia
	local function pickPart(cam, e, ref, maxD)
		local C = H.Cfg
		local function try(part)
			local sp, on = H.ToScreen(part.Position)
			if not on then
				return nil
			end
			local d = (sp - ref).Magnitude
			if d <= maxD and visible(cam, part, e.model) then
				return d
			end
		end
		local bestPart, bestD
		local function scan(names)
			for _, n in ipairs(names) do
				local p = e.model:FindFirstChild(n)
				if p and p:IsA("BasePart") then
					local d = try(p)
					if d and (not bestD or d < bestD) then
						bestPart, bestD = p, d
					end
				end
			end
		end
		if C["aim.point"] == "Mais perto" then
			scan(ALL)
		else
			local names = PRIMARY[C["aim.part"]]
			if not names then
				names = PRIMARY[({ "Cabeca", "Torso", "Raiz" })[1 + (e.model:GetFullName():len() % 3)]]
			end
			local p = firstPart(e.model, names)
			local d = p and try(p)
			if d then
				return p, d
			end
			if C["aim.fallback"] then
				scan(ALL)
			end
		end
		return bestPart, bestD
	end

	local function validEntity(e)
		return e and e.model.Parent and e.hum.Health > 0
	end

	local function findTarget(cam, ref, radius)
		local C = H.Cfg
		if C["aim.sticky"] and A.Entity and validEntity(A.Entity) then
			local p = pickPart(cam, A.Entity, ref, radius * 1.5)
			if p then
				return A.Entity, p
			end
		end
		local bestE, bestP, bestD = nil, nil, radius
		for _, e in ipairs(H.Entities(C["aim.npc"])) do
			if e.hum.Health > 0 and (e.npc or H.IsEnemy(e.player)) then
				local p, d = pickPart(cam, e, ref, bestD)
				if p and d <= bestD then
					bestE, bestP, bestD = e, p, d
				end
			end
		end
		return bestE, bestP
	end

	local function active()
		local C = H.Cfg
		if not C["aim.on"] then
			return false
		end
		local hum = H.Hum()
		if not hum or hum.Health <= 0 then
			return false
		end
		if C["aim.pause"] and (H.UI.Window.Visible or UserInputService:GetFocusedTextBox()) then
			return false
		end
		local act = C["aim.act"]
		if act == "Sempre" then
			return true
		end
		if act == "Botao" then
			return A.Hold
		end
		return A.Hold or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	end

	local lastNotify = 0
	RunService:BindToRenderStep("mc1h_aim", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = H.Camera()
		A.SilentPos, A.SilentPart = nil, nil
		if not cam or not active() then
			A.Target, A.Entity, A.AimPos = nil, nil, nil
			return
		end
		local C = H.Cfg
		budget = C["aim.checks"]
		local e, part = findTarget(cam, A.Ref(cam), A.Radius(cam))
		if not e then
			A.Target, A.Entity, A.AimPos = nil, nil, nil
			return
		end
		if (not A.Entity or e.model ~= A.Entity.model) and C["aim.notify"] and os.clock() - lastNotify > 1.5 then
			lastNotify = os.clock()
			H.Notify(string.format("Alvo: %s (%dm)", e.name, math.floor((e.root.Position - cam.CFrame.Position).Magnitude + 0.5)))
		end
		local pos = part.Position
		if C["aim.predict"] then
			local dist = (pos - cam.CFrame.Position).Magnitude
			pos = pos + e.root.AssemblyLinearVelocity * (dist / math.max(C["aim.projSpeed"], 1))
		end
		A.Target, A.Entity, A.AimPos = part, e, pos
		if C["aim.mode"] == "Silencioso" then
			A.SilentPos, A.SilentPart = pos, part
		else
			local ms = C["aim.smooth"]
			if C["aim.mode"] == "Agressivo" then
				ms = math.min(ms, 20)
			end
			local alpha = (ms <= 0) and 1 or math.clamp(dt * 1000 / ms, 0, 1)
			cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, pos), alpha)
		end
	end)
	H.OnCleanup(function()
		pcall(function()
			RunService:UnbindFromRenderStep("mc1h_aim")
		end)
		A.SilentPos, A.SilentPart = nil, nil
	end)

	-- botao AIM na tela (segurar)
	local btn = H.UI.New("TextButton", {
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.new(1, -150, 0.5, 40),
		BackgroundColor3 = H.UI.Colors.panel,
		BackgroundTransparency = 0.2,
		Text = "AIM",
		TextColor3 = H.UI.Colors.acc,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Visible = false,
	}, H.UI.Gui)
	H.UI.New("UICorner", { CornerRadius = UDim.new(1, 0) }, btn)
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			A.Hold = true
			btn.BackgroundColor3 = Color3.fromRGB(90, 60, 20)
		end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			A.Hold = false
			btn.BackgroundColor3 = H.UI.Colors.panel
		end
	end)
	H.Connect(RunService.Heartbeat, function()
		btn.Visible = H.Cfg["aim.on"] and (UserInputService.TouchEnabled or H.Cfg["aim.act"] == "Botao")
	end)

	-- amigos (nunca sao alvo): botao do meio do mouse ou botao no menu
	local function toggleFriendNearest()
		local cam = H.Camera()
		if not cam then
			return
		end
		local ref, bestP, bestD = A.Ref(cam), nil, math.huge
		for _, e in ipairs(H.Entities(false)) do
			local sp, on = H.ToScreen(e.root.Position)
			if on and (sp - ref).Magnitude < bestD then
				bestP, bestD = e.player, (sp - ref).Magnitude
			end
		end
		if not bestP then
			H.Notify("Nenhum jogador perto da mira.")
			return
		end
		local now = not H.Friends[bestP.UserId]
		H.Friends[bestP.UserId] = now or nil
		H.Notify((now and "Amigo adicionado: " or "Amigo removido: ") .. bestP.DisplayName)
	end
	T:Button("Adicionar/remover amigo (mais perto da mira)", toggleFriendNearest)
	H.Connect(UserInputService.InputBegan, function(i, gp)
		if not gp and i.UserInputType == Enum.UserInputType.MouseButton3 then
			toggleFriendNearest()
		end
	end)
end

----------------------------------------------------------------------
-- COMBATE: ganchos do modo Silencioso. Redirecionam so chamadas feitas pelo jogo (checkcaller() falso).
-- Instalados apenas quando o modo Silencioso e escolhido; depois de Destroy ficam inertes (repassam tudo).
----------------------------------------------------------------------
do
	local A = H.Aim
	local installed = false
	local RAY = { FindPartOnRay = true, FindPartOnRayWithIgnoreList = true, FindPartOnRayWithWhitelist = true }

	local function roll()
		return math.random(100) <= H.Cfg["aim.hit"]
	end

	function H.InstallSilentHooks()
		if installed then
			return
		end
		if not H.Cap.Hook then
			H.Notify("Modo Silencioso indisponivel: o executor nao tem hookmetamethod/getnamecallmethod/checkcaller. Use Fixar ou Agressivo.", 6)
			return
		end
		installed = true
		local wall = RaycastParams.new()
		wall.FilterType = Enum.RaycastFilterType.Include

		local oldNamecall, oldIndex
		local okN, errN = pcall(function()
			oldNamecall = hookmetamethod(
				game,
				"__namecall",
				H.WrapC(function(self, ...)
					local method = getnamecallmethod()
					local pos = A.SilentPos
					if pos and H.Alive and not checkcaller() then
						local C = H.Cfg
						if self == Workspace and C["aim.hookRay"] then
							if method == "Raycast" then
								local origin, direction, params = ...
								if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" and roll() then
									local to = pos - origin
									if C["aim.wall"] and A.SilentPart then
										wall.FilterDescendantsInstances = { A.SilentPart.Parent }
										return oldNamecall(self, origin, to.Unit * (to.Magnitude + 2), wall)
									end
									return oldNamecall(self, origin, to.Unit * direction.Magnitude, params)
								end
							elseif RAY[method] then
								local args = table.pack(...)
								local ray = args[1]
								if typeof(ray) == "Ray" and roll() then
									local to = pos - ray.Origin
									local len = ray.Direction.Magnitude
									if C["aim.wall"] and A.SilentPart and method == "FindPartOnRayWithWhitelist" then
										args[2] = { A.SilentPart.Parent }
										len = to.Magnitude + 2
									end
									args[1] = Ray.new(ray.Origin, to.Unit * len)
									return oldNamecall(self, table.unpack(args, 1, args.n))
								end
							end
						elseif C["aim.hookCam"] and self == Workspace.CurrentCamera and (method == "ViewportPointToRay" or method == "ScreenPointToRay") and roll() then
							local o = self.CFrame.Position
							return Ray.new(o, (pos - o).Unit)
						end
					end
					return oldNamecall(self, ...)
				end)
			)
		end)
		if not okN then
			warn("[mc1h] hook __namecall falhou: " .. tostring(errN))
		end

		local Mouse = LocalPlayer:GetMouse()
		local okI, errI = pcall(function()
			oldIndex = hookmetamethod(
				game,
				"__index",
				H.WrapC(function(self, key)
					if self == Mouse and (key == "Hit" or key == "Target") and A.SilentPos and H.Alive and H.Cfg["aim.hookMouse"] and not checkcaller() and roll() then
						if key == "Hit" then
							return CFrame.new(A.SilentPos)
						end
						return A.SilentPart
					end
					return oldIndex(self, key)
				end)
			)
		end)
		if not okI then
			warn("[mc1h] hook __index falhou: " .. tostring(errI))
		end
		if okN or okI then
			H.Notify("Modo Silencioso: ganchos instalados (namecall=" .. tostring(okN) .. ", index=" .. tostring(okI) .. ").")
		end
	end

	if H.Cfg["aim.mode"] == "Silencioso" then
		H.InstallSilentHooks()
	end
end

----------------------------------------------------------------------
-- COMBATE: efeitos. "Acerto" = queda de vida de um inimigo perto da mira logo apos um disparo
-- (inferido no cliente; nao e um evento do jogo). Disparo = clique esquerdo ou toque com ferramenta equipada.
----------------------------------------------------------------------
do
	local T = H.Tabs.Combate
	local A = H.Aim
	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local ACC = Color3.fromRGB(255, 150, 30)

	T:Section("Efeitos de combate")
	T:Toggle("Circulo da mira", "fx.circle", true)
	T:Toggle("Mira falsa (cruz no centro)", "fx.crosshair", false)
	T:Toggle("Reticula no alvo", "fx.reticle", true)
	T:Toggle("Dados do alvo", "fx.target", true)
	T:Toggle("Marca de acerto", "fx.hitmarker", true)
	T:Toggle("Numeros de dano", "fx.dmg", true)
	T:Toggle("Efeitos de acerto", "fx.hitfx", true)
	T:Toggle("Efeitos de eliminacao", "fx.killfx", false)
	T:Toggle("So acertos confirmados", "fx.confirmed", true)
	T:Toggle("Rastro personalizado", "fx.tracer", false)

	local circle = H.NewDrawing("Circle", { Thickness = 1, NumSides = 64, Filled = false, Visible = false, Color = Color3.new(1, 1, 1) })
	local reticle = H.NewDrawing("Circle", { Thickness = 2, NumSides = 20, Radius = 6, Filled = false, Visible = false, Color = Color3.fromRGB(255, 70, 70) })
	local info = H.NewDrawing("Text", { Size = 13, Center = true, Outline = true, Visible = false, Color = Color3.new(1, 1, 1) })
	local cross, hm = {}, {}
	for i = 1, 4 do
		cross[i] = H.NewDrawing("Line", { Thickness = 1, Visible = false, Color = Color3.new(1, 1, 1) })
		hm[i] = H.NewDrawing("Line", { Thickness = 2, Visible = false, Color = Color3.fromRGB(255, 255, 255) })
	end
	local nums = {}
	local hmUntil, lastFire = 0, 0

	local function flash(pos, color, s0, s1, t)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.new(s0, s0, s0)
		p.Position = pos
		p.Parent = Workspace
		TweenService:Create(p, TweenInfo.new(t), { Size = Vector3.new(s1, s1, s1), Transparency = 1 }):Play()
		Debris:AddItem(p, t + 0.1)
	end

	local tracerParams = RaycastParams.new()
	tracerParams.FilterType = Enum.RaycastFilterType.Exclude
	local function tracer()
		local char, cam = H.Char(), H.Camera()
		if not (char and cam) then
			return
		end
		local tool = char:FindFirstChildOfClass("Tool")
		local handle = tool and tool:FindFirstChild("Handle")
		local head = char:FindFirstChild("Head")
		local origin = handle and handle.Position or (head and head.Position) or cam.CFrame.Position
		local target = A.SilentPos
		if not target then
			local r = A.Ref(cam)
			local ray = cam:ViewportPointToRay(r.X, r.Y)
			tracerParams.FilterDescendantsInstances = { char }
			local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, tracerParams)
			target = hit and hit.Position or (ray.Origin + ray.Direction * 500)
		end
		local len = (target - origin).Magnitude
		if len < 1 then
			return
		end
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = ACC
		p.Size = Vector3.new(0.08, 0.08, len)
		p.CFrame = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -len / 2)
		p.Parent = Workspace
		TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		Debris:AddItem(p, 0.3)
	end

	local function onFire()
		local now = os.clock()
		if now - lastFire < 0.05 or H.UI.Window.Visible then
			return
		end
		lastFire = now
		local C = H.Cfg
		H.Emit("fire")
		if C["fx.tracer"] then
			tracer()
		end
		if not C["fx.confirmed"] and C["fx.hitmarker"] then
			hmUntil = now + 0.15
		end
	end
	H.Connect(UserInputService.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			onFire()
		elseif i.UserInputType == Enum.UserInputType.Touch then
			local c = H.Char()
			if c and c:FindFirstChildOfClass("Tool") then
				onFire()
			end
		end
	end)

	-- deteccao de acerto por queda de vida
	local hp = setmetatable({}, { __mode = "k" })
	H.Connect(RunService.Heartbeat, function()
		local C = H.Cfg
		if not (C["fx.hitmarker"] or C["fx.dmg"] or C["fx.hitfx"] or C["fx.killfx"]) then
			return
		end
		local cam = H.Camera()
		if not cam then
			return
		end
		local now = os.clock()
		local ref, rad = A.Ref(cam), A.Radius(cam)
		for _, e in ipairs(H.Entities(C["aim.npc"])) do
			if e.npc or H.IsEnemy(e.player) then
				local prev, cur = hp[e.hum], e.hum.Health
				hp[e.hum] = cur
				if prev and cur < prev - 0.01 and (now - lastFire) < 0.5 then
					local sp, on = H.ToScreen(e.root.Position)
					if (A.Entity and A.Entity.model == e.model) or (on and (sp - ref).Magnitude <= rad * 2 + 40) then
						local pos = (A.Entity and A.Entity.model == e.model and A.Target) and A.Target.Position or e.root.Position
						H.Emit("hit", { head = (A.Entity ~= nil and A.Entity.model == e.model and A.Target ~= nil and A.Target.Name == "Head") })
						if cur <= 0 and prev > 0 then
							H.Emit("kill")
						end
						if C["fx.hitmarker"] then
							hmUntil = now + 0.15
						end
						if C["fx.dmg"] and #nums < 10 then
							local t = H.NewDrawing("Text", { Size = 16, Center = true, Outline = true, Visible = false, Color = Color3.fromRGB(255, 220, 60) })
							if t then
								nums[#nums + 1] = { pos = pos, t0 = now, text = t, label = string.format("%d", math.floor(prev - cur + 0.5)) }
							end
						end
						if C["fx.hitfx"] then
							flash(pos, Color3.fromRGB(255, 255, 255), 0.5, 2.2, 0.25)
						end
						if cur <= 0 and prev > 0 and C["fx.killfx"] then
							flash(e.root.Position, Color3.fromRGB(255, 50, 50), 1, 9, 0.5)
						end
					end
				end
			end
		end
	end)

	H.Connect(RunService.RenderStepped, function()
		local cam = H.Camera()
		if not cam then
			return
		end
		local C = H.Cfg
		local vp = cam.ViewportSize
		local center = Vector2.new(vp.X / 2, vp.Y / 2)
		local ref = A.Ref(cam)
		local now = os.clock()
		if circle then
			circle.Visible = C["fx.circle"] and C["aim.on"]
			circle.Position = ref
			circle.Radius = A.Radius(cam)
		end
		local offs = { { 4, 0, 12, 0 }, { -4, 0, -12, 0 }, { 0, 4, 0, 12 }, { 0, -4, 0, -12 } }
		for i = 1, 4 do
			local l = cross[i]
			if l then
				l.Visible = C["fx.crosshair"]
				l.From = center + Vector2.new(offs[i][1], offs[i][2])
				l.To = center + Vector2.new(offs[i][3], offs[i][4])
			end
			local m = hm[i]
			if m then
				local on = now < hmUntil
				m.Visible = on
				if on then
					local sx, sy = (i <= 2) and 1 or -1, (i % 2 == 1) and 1 or -1
					m.From = center + Vector2.new(sx * 4, sy * 4)
					m.To = center + Vector2.new(sx * 11, sy * 11)
				end
			end
		end
		if reticle then
			local show = false
			if C["fx.reticle"] and A.AimPos then
				local sp, on = H.ToScreen(A.AimPos)
				if on then
					show = true
					reticle.Position = sp
				end
			end
			reticle.Visible = show
		end
		if info then
			local e = A.Entity
			if C["fx.target"] and e and e.hum then
				info.Visible = true
				info.Position = Vector2.new(ref.X, ref.Y + A.Radius(cam) + 8)
				info.Text = string.format(
					"%s | %d/%d | %dm", e.name, math.floor(e.hum.Health), math.floor(e.hum.MaxHealth),
					math.floor((e.root.Position - cam.CFrame.Position).Magnitude + 0.5)
				)
			else
				info.Visible = false
			end
		end
		for i = #nums, 1, -1 do
			local n = nums[i]
			local k = (now - n.t0) / 0.8
			if k >= 1 then
				H.RemoveDrawing(n.text)
				table.remove(nums, i)
			else
				local sp, on = H.ToScreen(n.pos + Vector3.new(0, k * 2.5, 0))
				n.text.Visible = on
				n.text.Position = sp or Vector2.zero
				n.text.Text = n.label
				n.text.Transparency = 1 - k
			end
		end
	end)
end

----------------------------------------------------------------------
-- COMBATE: anti mira (local), trajetoria de granada, aura de corpo a corpo e recarga
-- (as tres ultimas dependem de valores do jogo em H.Profile e ficam bloqueadas sem eles)
----------------------------------------------------------------------
do
	local T = H.Tabs.Combate

	T:Section("Anti mira (seu personagem)")
	T:Toggle("Anti aim", "anti.on", false)
	T:Choice("Modo do anti aim", "anti.mode", { "Girar", "Tremer", "Invertido" }, "Girar")
	T:Slider("Velocidade do giro", "anti.speed", 1, 30, 10, 1, "%d")
	T:Toggle("Sob o chao (afunda o corpo)", "anti.under", false)

	local autoRotate0, hip0
	H.Connect(RunService.Stepped, function()
		local C = H.Cfg
		local hum, root, cam = H.Hum(), H.Root(), H.Camera()
		if not (hum and root and cam) then
			return
		end
		if C["anti.on"] then
			if autoRotate0 == nil then
				autoRotate0 = hum.AutoRotate
			end
			hum.AutoRotate = false
			local yaw
			if C["anti.mode"] == "Girar" then
				yaw = os.clock() * C["anti.speed"]
			elseif C["anti.mode"] == "Tremer" then
				yaw = math.random() * math.pi * 2
			else
				local _, camYaw = cam.CFrame:ToOrientation()
				yaw = camYaw + math.pi
			end
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
			root.AssemblyAngularVelocity = Vector3.zero
		elseif autoRotate0 ~= nil then
			hum.AutoRotate = autoRotate0
			autoRotate0 = nil
		end
		if C["anti.under"] then
			if hip0 == nil then
				hip0 = hum.HipHeight
			end
			hum.HipHeight = math.max(hip0 - 1.8, -1)
		elseif hip0 ~= nil then
			hum.HipHeight = hip0
			hip0 = nil
		end
	end)
	H.OnCleanup(function()
		local hum = H.Hum()
		if hum then
			if autoRotate0 ~= nil then
				hum.AutoRotate = autoRotate0
			end
			if hip0 ~= nil then
				hum.HipHeight = hip0
			end
		end
	end)

	T:Section("Depende do jogo (perfil)")

	-- trajetoria: H.Profile.Grenade = { speed = studs/s, gravity = opcional, toolNames = { "trecho" } }
	T:Toggle("Trajetoria do arremesso", "gren.on", false, function(v)
		if v and not (H.Need("Grenade.speed") and H.Cap.Drawing) then
			H.Set("gren.on", false)
		end
	end)
	local lines = {}
	for i = 1, 32 do
		lines[i] = H.NewDrawing("Line", { Thickness = 2, Visible = false, Color = Color3.fromRGB(255, 200, 60) })
	end
	local gp = RaycastParams.new()
	gp.FilterType = Enum.RaycastFilterType.Exclude
	H.Connect(RunService.RenderStepped, function()
		local g = H.Profile.Grenade
		local show = H.Cfg["gren.on"] and g and g.speed and H.Cap.Drawing
		local cam, char = H.Camera(), H.Char()
		if show and g.toolNames then
			local tool = char and char:FindFirstChildOfClass("Tool")
			show = false
			if tool then
				for _, n in ipairs(g.toolNames) do
					if string.find(string.lower(tool.Name), string.lower(n), 1, true) then
						show = true
					end
				end
			end
		end
		if not (show and cam and char) then
			for _, l in ipairs(lines) do
				if l.Visible then
					l.Visible = false
				end
			end
			return
		end
		gp.FilterDescendantsInstances = { char }
		local grav = Vector3.new(0, -(g.gravity or Workspace.Gravity), 0)
		local p = cam.CFrame.Position + cam.CFrame.LookVector
		local v = cam.CFrame.LookVector * g.speed
		local dt = 0.08
		for i = 1, #lines do
			local nv = v + grav * dt
			local np = p + v * dt + grav * (0.5 * dt * dt)
			local hit = Workspace:Raycast(p, np - p, gp)
			if hit then
				np = hit.Position
			end
			local a, aOn = H.ToScreen(p)
			local b, bOn = H.ToScreen(np)
			lines[i].Visible = aOn and bOn
			lines[i].From, lines[i].To = a or Vector2.zero, b or Vector2.zero
			if hit then
				for j = i + 1, #lines do
					lines[j].Visible = false
				end
				break
			end
			p, v = np, nv
		end
	end)

	-- aura de corpo a corpo: H.Profile.Remotes.MeleeHit (RemoteEvent) e H.Profile.MeleeArgs(entidade) -> argumentos
	T:Toggle("Aura letal", "melee.on", false, function(v)
		if v and not (H.Need("Remotes.MeleeHit") and H.Need("MeleeArgs")) then
			H.Set("melee.on", false)
		end
	end)
	T:Slider("Alcance da aura", "melee.range", 3, 25, 8, 1, "%d")
	T:Slider("Golpes por segundo", "melee.cps", 1, 15, 5, 1, "%d")
	local meleeAcc = 0
	H.Connect(RunService.Heartbeat, function(dt)
		if not H.Cfg["melee.on"] then
			return
		end
		meleeAcc += dt
		if meleeAcc < 1 / H.Cfg["melee.cps"] then
			return
		end
		meleeAcc = 0
		local remote, argsFn, root = H.Profile.Remotes.MeleeHit, H.Profile.MeleeArgs, H.Root()
		local hum = H.Hum()
		if not (remote and argsFn and root and hum and hum.Health > 0) then
			return
		end
		local best, bestD = nil, H.Cfg["melee.range"]
		for _, e in ipairs(H.Entities(H.Cfg["aim.npc"])) do
			if e.hum.Health > 0 and (e.npc or H.IsEnemy(e.player)) then
				local d = (e.root.Position - root.Position).Magnitude
				if d <= bestD then
					best, bestD = e, d
				end
			end
		end
		if best then
			local ok, err = pcall(function()
				local args = table.pack(argsFn(best))
				remote:FireServer(table.unpack(args, 1, args.n))
			end)
			if not ok then
				warn("[mc1h] aura letal: " .. tostring(err))
			end
		end
	end)

	-- recarga: H.Profile.GetAmmo() -> atual, maximo ; H.Profile.Remotes.Reload (RemoteEvent)
	T:Toggle("Recarga automatica", "gun.reload", false, function(v)
		if v and not (H.Need("GetAmmo") and H.Need("Remotes.Reload")) then
			H.Set("gun.reload", false)
		end
	end)
	local reloadAcc = 0
	H.Connect(RunService.Heartbeat, function(dt)
		if not H.Cfg["gun.reload"] then
			return
		end
		reloadAcc += dt
		if reloadAcc < 0.3 then
			return
		end
		reloadAcc = 0
		local getAmmo, remote = H.Profile.GetAmmo, H.Profile.Remotes.Reload
		if not (getAmmo and remote) then
			return
		end
		local ok, cur = pcall(getAmmo)
		if ok and cur == 0 then
			pcall(function()
				if H.Profile.ReloadArgs then
					remote:FireServer(H.Profile.ReloadArgs())
				else
					remote:FireServer()
				end
			end)
		end
	end)
end

----------------------------------------------------------------------
-- MUNDO: iluminacao, efeitos de pos-processamento, terreno (tudo local; originais guardados e restaurados)
----------------------------------------------------------------------
do
	local T = H.Tabs.Mundo
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local L0 = {}
	for _, p in ipairs({ "Brightness", "Ambient", "OutdoorAmbient", "ClockTime", "GlobalShadows", "FogEnd", "FogStart", "FogColor" }) do
		L0[p] = Lighting[p]
	end
	local function restore(list)
		for _, p in ipairs(list) do
			Lighting[p] = L0[p]
		end
	end

	T:Section("Iluminacao")
	T:Toggle("Luz (clarear tudo)", "light.on", false, function(v)
		if not v then
			restore({ "Brightness", "Ambient", "OutdoorAmbient" })
		end
	end)
	T:Slider("Brilho", "light.bright", 0, 5, 2, 0.1, "%.1f")
	T:Toggle("Hora e sol", "time.on", false, function(v)
		if not v then
			restore({ "ClockTime" })
		end
	end)
	T:Slider("Hora do dia", "time.clock", 0, 24, 14, 0.25, "%.2f")
	T:Toggle("Sombras desligadas", "shadow.off", false, function(v)
		if not v then
			restore({ "GlobalShadows" })
		end
	end)
	T:Toggle("Neblina personalizada", "fog.on", false, function(v)
		if not v then
			restore({ "FogEnd", "FogStart", "FogColor" })
		end
	end)
	T:Slider("Distancia da neblina", "fog.end", 100, 100000, 100000, 100, "%d")
	H.Connect(RunService.RenderStepped, function()
		local C = H.Cfg
		if C["light.on"] then
			local g = math.clamp(C["light.bright"] * 90, 0, 255)
			Lighting.Brightness = C["light.bright"]
			Lighting.Ambient = Color3.fromRGB(g, g, g)
			Lighting.OutdoorAmbient = Color3.fromRGB(g, g, g)
		end
		if C["time.on"] then
			Lighting.ClockTime = C["time.clock"]
		end
		if C["shadow.off"] then
			Lighting.GlobalShadows = false
		end
		if C["fog.on"] then
			Lighting.FogStart, Lighting.FogEnd = 0, C["fog.end"]
		end
	end)
	H.OnCleanup(function()
		restore({ "Brightness", "Ambient", "OutdoorAmbient", "ClockTime", "GlobalShadows", "FogEnd", "FogStart", "FogColor" })
	end)

	-- renderizacao (nivel de qualidade 1-21)
	local q0
	T:Toggle("Renderizacao (qualidade)", "render.on", false, function(v)
		local ok = pcall(function()
			local r = settings().Rendering
			if v then
				q0 = q0 or r.QualityLevel
				r.QualityLevel = H.Cfg["render.q"]
			elseif q0 then
				r.QualityLevel, q0 = q0, nil
			end
		end)
		if not ok and v then
			H.Notify("settings().Rendering indisponivel neste executor.")
			H.Set("render.on", false)
		end
	end)
	T:Slider("Nivel de qualidade", "render.q", 1, 21, 1, 1, "%d", function(v)
		if H.Cfg["render.on"] then
			pcall(function()
				settings().Rendering.QualityLevel = v
			end)
		end
	end)
	H.OnCleanup(function()
		if q0 then
			pcall(function()
				settings().Rendering.QualityLevel = q0
			end)
		end
	end)

	-- atmosfera, ceu, nuvens (objetos existentes do jogo; valores originais restaurados)
	local atmos0, sky0, cloud0
	T:Toggle("Atmosfera (densidade)", "atmos.on", false, function(v)
		local a = Lighting:FindFirstChildOfClass("Atmosphere")
		if not a then
			return
		end
		if v then
			atmos0 = atmos0 or { a.Density, a.Haze }
			a.Density, a.Haze = H.Cfg["atmos.density"] or 0, 0
		elseif atmos0 then
			a.Density, a.Haze, atmos0 = atmos0[1], atmos0[2], nil
		end
	end)
	T:Slider("Densidade da atmosfera", "atmos.density", 0, 1, 0, 0.05, "%.2f", function(v)
		local a = Lighting:FindFirstChildOfClass("Atmosphere")
		if a and H.Cfg["atmos.on"] then
			a.Density = v
		end
	end)
	T:Toggle("Ceu (sem sol, lua e estrelas)", "sky.on", false, function(v)
		local s = Lighting:FindFirstChildOfClass("Sky")
		if not s then
			return
		end
		if v then
			sky0 = sky0 or { s.CelestialBodiesShown, s.StarCount }
			s.CelestialBodiesShown, s.StarCount = false, 0
		elseif sky0 then
			s.CelestialBodiesShown, s.StarCount, sky0 = sky0[1], sky0[2], nil
		end
	end)
	T:Toggle("Nuvens desligadas", "clouds.off", false, function(v)
		local c = terrain and terrain:FindFirstChildOfClass("Clouds")
		if not c then
			return
		end
		if v then
			cloud0 = c.Enabled
			c.Enabled = false
		elseif cloud0 ~= nil then
			c.Enabled, cloud0 = cloud0, nil
		end
	end)
	H.OnCleanup(function()
		local a, s = Lighting:FindFirstChildOfClass("Atmosphere"), Lighting:FindFirstChildOfClass("Sky")
		local c = terrain and terrain:FindFirstChildOfClass("Clouds")
		if a and atmos0 then
			a.Density, a.Haze = atmos0[1], atmos0[2]
		end
		if s and sky0 then
			s.CelestialBodiesShown, s.StarCount = sky0[1], sky0[2]
		end
		if c and cloud0 ~= nil then
			c.Enabled = cloud0
		end
	end)

	-- efeitos de pos-processamento criados por este script (nome mc1h_*)
	local function ensure(class, name)
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Enabled = false
			e.Parent = Lighting
		end
		return e
	end
	H.OnCleanup(function()
		for _, c in ipairs(Lighting:GetChildren()) do
			if string.sub(c.Name, 1, 5) == "mc1h_" then
				c:Destroy()
			end
		end
	end)
	local TINTS = {
		Laranja = Color3.fromRGB(255, 190, 120), Azul = Color3.fromRGB(150, 190, 255), Verde = Color3.fromRGB(160, 255, 170),
		Roxo = Color3.fromRGB(210, 160, 255), Vermelho = Color3.fromRGB(255, 150, 150),
	}
	local function effect(title, key, class, props, extra)
		local name = "mc1h_" .. key
		local function applyAll(e)
			for _, p in ipairs(props) do
				e[p.prop] = H.Cfg[key .. "." .. p.prop] or p.default
			end
			if extra then
				extra(e)
			end
		end
		T:Toggle(title, key .. ".on", false, function(v)
			if v then
				local e = ensure(class, name)
				applyAll(e)
				e.Enabled = true
			else
				local e = Lighting:FindFirstChild(name)
				if e then
					e.Enabled = false
				end
			end
		end)
		for _, p in ipairs(props) do
			T:Slider(title .. ": " .. p.label, key .. "." .. p.prop, p.min, p.max, p.default, p.step, p.fmt, function(val)
				local e = Lighting:FindFirstChild(name)
				if e then
					e[p.prop] = val
				end
			end)
		end
	end
	effect("Florescer", "bloom", "BloomEffect", {
		{ prop = "Intensity", label = "intensidade", min = 0, max = 3, default = 0.6, step = 0.05, fmt = "%.2f" },
		{ prop = "Size", label = "tamanho", min = 0, max = 56, default = 24, step = 1, fmt = "%d" },
	})
	effect("Desfoque", "blur", "BlurEffect", {
		{ prop = "Size", label = "tamanho", min = 0, max = 56, default = 8, step = 1, fmt = "%d" },
	})
	effect("Ajuste de cor", "cc", "ColorCorrectionEffect", {
		{ prop = "Contrast", label = "contraste", min = -1, max = 1, default = 0.1, step = 0.05, fmt = "%.2f" },
		{ prop = "Saturation", label = "saturacao", min = -1, max = 1, default = 0.2, step = 0.05, fmt = "%.2f" },
		{ prop = "Brightness", label = "brilho", min = -0.5, max = 0.5, default = 0, step = 0.05, fmt = "%.2f" },
	})
	effect("Profundidade de campo", "dof", "DepthOfFieldEffect", {
		{ prop = "FarIntensity", label = "intensidade", min = 0, max = 1, default = 0.3, step = 0.05, fmt = "%.2f" },
		{ prop = "FocusDistance", label = "foco", min = 0, max = 200, default = 40, step = 1, fmt = "%d" },
	})
	effect("Raios de sol", "rays", "SunRaysEffect", {
		{ prop = "Intensity", label = "intensidade", min = 0, max = 1, default = 0.25, step = 0.05, fmt = "%.2f" },
	})
	T:Choice("Cor da tonalidade", "tint.color", { "Laranja", "Azul", "Verde", "Roxo", "Vermelho" }, "Laranja", function(v)
		local e = Lighting:FindFirstChild("mc1h_tint")
		if e then
			e.TintColor = TINTS[v]
		end
	end)
	T:Toggle("Tonalidade", "tint.on", false, function(v)
		if v then
			local e = ensure("ColorCorrectionEffect", "mc1h_tint")
			e.TintColor = TINTS[H.Cfg["tint.color"]] or TINTS.Laranja
			e.Enabled = true
		else
			local e = Lighting:FindFirstChild("mc1h_tint")
			if e then
				e.Enabled = false
			end
		end
	end)

	----------------------------------------------------------------
	-- Terreno
	----------------------------------------------------------------
	T:Section("Terreno e agua")
	local PRESET = {
		Verde = Color3.fromRGB(60, 140, 60), Marrom = Color3.fromRGB(110, 75, 45), Cinza = Color3.fromRGB(120, 120, 125),
		Areia = Color3.fromRGB(215, 190, 130), Preto = Color3.fromRGB(15, 15, 15), Branco = Color3.fromRGB(240, 240, 240),
		Azul = Color3.fromRGB(40, 90, 200), Vermelho = Color3.fromRGB(190, 50, 50),
	}
	local NAMES = { "Verde", "Marrom", "Cinza", "Areia", "Preto", "Branco", "Azul", "Vermelho" }
	local MATS = { "Grass", "Ground", "Sand", "Rock", "Mud", "Snow", "Sandstone", "Slate" }
	local mat0 = {}
	T:Choice("Material do terreno", "terrain.mat", MATS, "Grass")
	T:Choice("Cor do terreno", "terrain.color", NAMES, "Verde")
	T:Button("Aplicar cor ao material", function()
		if not terrain then
			return
		end
		local m = Enum.Material[H.Cfg["terrain.mat"]]
		if mat0[m] == nil then
			mat0[m] = terrain:GetMaterialColor(m)
		end
		terrain:SetMaterialColor(m, PRESET[H.Cfg["terrain.color"]])
	end)
	T:Button("Restaurar cores do terreno", function()
		for m, c in pairs(mat0) do
			terrain:SetMaterialColor(m, c)
		end
		table.clear(mat0)
	end)
	H.OnCleanup(function()
		if terrain then
			for m, c in pairs(mat0) do
				terrain:SetMaterialColor(m, c)
			end
		end
	end)

	local water0
	T:Choice("Cor da agua", "water.color", NAMES, "Azul")
	T:Toggle("Aplicar cor da agua", "water.on", false, function(v)
		if not terrain then
			return
		end
		if v then
			water0 = water0 or terrain.WaterColor
			terrain.WaterColor = PRESET[H.Cfg["water.color"]]
		elseif water0 then
			terrain.WaterColor, water0 = water0, nil
		end
	end)
	H.Bind("water.color", function(v)
		if terrain and H.Cfg["water.on"] then
			terrain.WaterColor = PRESET[v]
		end
	end)
	local grass0
	T:Toggle("Sem grama", "terrain.nograss", false, function(v)
		if not terrain then
			return
		end
		pcall(function()
			if v then
				if grass0 == nil then
					grass0 = terrain.Decoration
				end
				terrain.Decoration = false
			elseif grass0 ~= nil then
				terrain.Decoration, grass0 = grass0, nil
			end
		end)
	end)
	H.OnCleanup(function()
		if terrain and water0 then
			terrain.WaterColor = water0
		end
		if terrain and grass0 ~= nil then
			pcall(function()
				terrain.Decoration = grass0
			end)
		end
	end)
end

----------------------------------------------------------------------
-- MUNDO: folhas, troncos e minas (perfil do jogo), carregar jogadores, radar, ESP de saidas/chefes/minas
----------------------------------------------------------------------
do
	local T = H.Tabs.Mundo
	T:Section("Objetos do mapa (precisam do perfil do jogo)")

	-- aplica fn(part) a toda BasePart de instancias que casam com H.Profile.Match[cat]
	local active = {} -- cat -> { on = fn, off = fn }
	local touched = {} -- cat -> { part = valorOriginal }
	local listening = false

	local function parts(inst)
		if inst:IsA("BasePart") then
			return { inst }
		end
		local out = {}
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				out[#out + 1] = d
			end
		end
		return out
	end
	local function applyTo(cat, inst)
		local a = active[cat]
		if not a or not (inst:IsA("Model") or inst:IsA("BasePart")) or not H.Matches(cat, inst) then
			return
		end
		for _, p in ipairs(parts(inst)) do
			if touched[cat][p] == nil then
				touched[cat][p] = a.get(p)
			end
			a.set(p, a.value)
		end
	end
	local function listen()
		if listening then
			return
		end
		listening = true
		H.Connect(Workspace.DescendantAdded, function(d)
			for cat in pairs(active) do
				applyTo(cat, d)
			end
		end)
	end
	local function enableCat(cat, spec)
		if not H.Need("Match." .. cat) then
			return false
		end
		touched[cat] = touched[cat] or {}
		active[cat] = spec
		listen()
		task.spawn(function()
			local n = 0
			for _, d in ipairs(Workspace:GetDescendants()) do
				if active[cat] ~= spec then
					return
				end
				applyTo(cat, d)
				n += 1
				if n % 1000 == 0 then
					task.wait()
				end
			end
		end)
		return true
	end
	local function disableCat(cat)
		local a = active[cat]
		active[cat] = nil
		if a and touched[cat] then
			for p, orig in pairs(touched[cat]) do
				if p.Parent then
					a.set(p, orig)
				end
			end
			touched[cat] = {}
		end
	end
	H.OnCleanup(function()
		for cat in pairs(active) do
			disableCat(cat)
		end
	end)
	H.Cat = { Enable = enableCat, Disable = disableCat }

	local hideSpec = {
		get = function(p)
			return p.LocalTransparencyModifier
		end,
		set = function(p, v)
			p.LocalTransparencyModifier = v
		end,
		value = 1,
	}
	T:Toggle("Ocultar folhas", "world.leaf", false, function(v)
		if v then
			if not enableCat("Leaf", hideSpec) then
				H.Set("world.leaf", false)
			end
		else
			disableCat("Leaf")
		end
	end)
	T:Toggle("Ocultar troncos", "world.trunk", false, function(v)
		if v then
			if not enableCat("Trunk", hideSpec) then
				H.Set("world.trunk", false)
			end
		else
			disableCat("Trunk")
		end
	end)
	-- Desativar minas: CanTouch=false so no cliente; so ajuda se o jogo detecta a mina no cliente
	local mineSpec = {
		get = function(p)
			return p.CanTouch
		end,
		set = function(p, v)
			p.CanTouch = v
		end,
		value = false,
	}
	T:Toggle("Desativar minas (so no cliente)", "world.mines", false, function(v)
		if v then
			if not enableCat("Mine", mineSpec) then
				H.Set("world.mines", false)
			end
		else
			disableCat("Mine")
		end
	end)

	T:Section("Recursos")
	T:Toggle("Carregar jogadores (streaming)", "world.stream", false)
	local acc = 0
	H.Connect(RunService.Heartbeat, function(dt)
		if not H.Cfg["world.stream"] or not Workspace.StreamingEnabled then
			return
		end
		acc += dt
		if acc < 3 then
			return
		end
		acc = 0
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			local hrp = p ~= LocalPlayer and c and c:FindFirstChild("HumanoidRootPart")
			if hrp then
				task.spawn(function()
					pcall(function()
						LocalPlayer:RequestStreamAroundAsync(hrp.Position, 1)
					end)
				end)
			end
		end
	end)

	if H.ObjToggle then
		H.ObjToggle(T, "Buscar chefes", "Boss", "esp.boss")
		H.ObjToggle(T, "Pontos de saida", "Extraction", "esp.extraction")
		H.ObjToggle(T, "Minas (ESP)", "Mine", "esp.mine")
	end

	-- radar 2D (Drawing): centro no canto inferior esquerdo, gira com a camera
	T:Toggle("Radar", "radar.on", false)
	T:Slider("Alcance do radar", "radar.range", 50, 600, 150, 10, "%d")
	local RADIUS = 70
	local back = H.NewDrawing("Circle", { Thickness = 1, NumSides = 48, Radius = RADIUS, Filled = false, Visible = false, Color = Color3.fromRGB(255, 255, 255) })
	local me = H.NewDrawing("Circle", { NumSides = 12, Radius = 3, Filled = true, Visible = false, Color = Color3.fromRGB(80, 160, 255) })
	local dots = {}
	for i = 1, 40 do
		dots[i] = H.NewDrawing("Circle", { NumSides = 10, Radius = 3, Filled = true, Visible = false })
	end
	H.Connect(RunService.RenderStepped, function()
		local cam = H.Camera()
		local on = H.Cfg["radar.on"] and cam and back
		if not on then
			if back and back.Visible then
				back.Visible, me.Visible = false, false
				for _, d in ipairs(dots) do
					d.Visible = false
				end
			end
			return
		end
		local vp = cam.ViewportSize
		local center = Vector2.new(RADIUS + 20, vp.Y - RADIUS - 20)
		back.Visible, me.Visible = true, true
		back.Position, me.Position = center, center
		local root = H.Root()
		local fwd = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
		fwd = fwd.Magnitude > 0 and fwd.Unit or Vector3.new(0, 0, -1)
		right = right.Magnitude > 0 and right.Unit or Vector3.new(1, 0, 0)
		local range = H.Cfg["radar.range"]
		local n = 0
		if root then
			for _, e in ipairs(H.Entities(H.Cfg["esp.npc"] or H.Cfg["aim.npc"])) do
				if e.hum.Health > 0 and n < #dots then
					local delta = e.root.Position - root.Position
					local px, py = delta:Dot(right) / range * RADIUS, -delta:Dot(fwd) / range * RADIUS
					local v = Vector2.new(px, py)
					if v.Magnitude > RADIUS then
						v = v.Unit * RADIUS
					end
					n += 1
					local d = dots[n]
					d.Visible = true
					d.Position = center + v
					d.Color = e.npc and Color3.fromRGB(255, 210, 60) or (H.IsFriend(e.player) and Color3.fromRGB(80, 255, 120)) or (H.IsEnemy(e.player) and Color3.fromRGB(255, 70, 70)) or Color3.fromRGB(80, 160, 255)
				end
			end
		end
		for i = n + 1, #dots do
			dots[i].Visible = false
		end
	end)
end

----------------------------------------------------------------------
-- EXTRAS: troca rapida, modo panico, atravessar porta, remover efeitos, avisos, deteccao, sons
----------------------------------------------------------------------
do
	local T = H.Tabs.Extras
	local Debris = game:GetService("Debris")
	local GroupService = game:GetService("GroupService")

	T:Section("Extras")

	-- troca rapida: alterna entre as duas ultimas ferramentas equipadas
	T:Toggle("Troca rapida", "extras.quick", false)
	T:Choice("Tecla da troca rapida", "extras.swapKey", { "T", "F", "G", "Q", "H" }, "T")
	local cur, prev
	local function track(char)
		char.ChildAdded:Connect(function(c)
			if c:IsA("Tool") and c ~= cur then
				prev, cur = cur, c
			end
		end)
	end
	H.Connect(LocalPlayer.CharacterAdded, track)
	if LocalPlayer.Character then
		track(LocalPlayer.Character)
	end
	local function swap()
		local hum = H.Hum()
		if hum and prev and prev.Parent then
			hum:EquipTool(prev)
		end
	end
	T:Button("Trocar agora", swap)
	H.Connect(UserInputService.InputBegan, function(i, gp)
		if not gp and H.Cfg["extras.quick"] and i.KeyCode == Enum.KeyCode[H.Cfg["extras.swapKey"]] then
			swap()
		end
	end)

	-- modo panico: desliga tudo e descarrega o hub (nenhum rastro de interface)
	T:Choice("Tecla do modo panico", "panic.key", { "Delete", "End", "Insert", "Home" }, "Delete")
	T:Button("Modo panico (descarregar agora)", function()
		task.defer(H.Destroy)
	end)
	H.Connect(UserInputService.InputBegan, function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode[H.Cfg["panic.key"]] then
			task.defer(H.Destroy)
		end
	end)

	-- atravessar porta: CanCollide=false nas portas do perfil (colisao do seu personagem e local)
	local doorSpec = {
		get = function(p)
			return p.CanCollide
		end,
		set = function(p, v)
			p.CanCollide = v
		end,
		value = false,
	}
	T:Toggle("Atravessar porta (perfil: Match.Door)", "extras.door", false, function(v)
		if v then
			if not (H.Cat and H.Cat.Enable("Door", doorSpec)) then
				H.Set("extras.door", false)
			end
		elseif H.Cat then
			H.Cat.Disable("Door")
		end
	end)

	-- remover efeitos de tela criados pelo jogo (desfoque, cor, etc.)
	local fxOff = {}
	T:Toggle("Remover efeitos de tela", "extras.noeffects", false, function(v)
		if not v then
			for e in pairs(fxOff) do
				if e.Parent then
					e.Enabled = true
				end
			end
			table.clear(fxOff)
		end
	end)
	H.Connect(RunService.Heartbeat, function()
		if not H.Cfg["extras.noeffects"] then
			return
		end
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("PostEffect") and e.Enabled and string.sub(e.Name, 1, 5) ~= "mc1h_" then
				fxOff[e] = true
				e.Enabled = false
			end
		end
	end)
	H.OnCleanup(function()
		for e in pairs(fxOff) do
			if e.Parent then
				e.Enabled = true
			end
		end
	end)

	-- avisos: mensagens que citam voce junto de palavras de denuncia; entrada e saida de jogadores
	T:Toggle("Avisos de denuncias (chat)", "notice.report", false)
	T:Toggle("Avisos de entrada/saida", "notice.join", false)
	local WORDS = { "report", "denunc", "hack", "cheat", "exploit", "aimbot", "ban" }
	local function onChat(name, msg)
		if not H.Cfg["notice.report"] or type(msg) ~= "string" then
			return
		end
		local low = string.lower(msg)
		local me = string.lower(LocalPlayer.Name)
		local me2 = string.lower(LocalPlayer.DisplayName)
		if not (string.find(low, me, 1, true) or string.find(low, me2, 1, true)) then
			return
		end
		for _, w in ipairs(WORDS) do
			if string.find(low, w, 1, true) then
				H.Notify(name .. ": " .. msg, 8)
				return
			end
		end
	end
	local function hookChat(p)
		if p ~= LocalPlayer then
			H.Connect(p.Chatted, function(m)
				onChat(p.DisplayName, m)
			end)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		hookChat(p)
	end
	pcall(function()
		local TCS = game:GetService("TextChatService")
		H.Connect(TCS.MessageReceived, function(m)
			local src = m.TextSource
			local p = src and Players:GetPlayerByUserId(src.UserId)
			if p and p ~= LocalPlayer then
				onChat(p.DisplayName, m.Text)
			end
		end)
	end)

	T:Section("Deteccao de staff e suspeitos")
	T:Toggle("Criador do jogo", "detect.creator", false)
	T:Toggle("Testador (perfil: Staff.Tester)", "detect.tester", false)
	T:Toggle("Moderador (perfil: Staff.Moderator)", "detect.mod", false)
	T:Toggle("Suspeito de trapaca (velocidade)", "detect.cheat", false)
	T:Slider("Limite de velocidade (studs/s)", "detect.speed", 40, 500, 150, 5, "%d")

	local creatorId
	task.spawn(function()
		local ok, id = pcall(function()
			if game.CreatorType == Enum.CreatorType.Group then
				return GroupService:GetGroupInfoAsync(game.CreatorId).Owner.Id
			end
			return game.CreatorId
		end)
		if ok then
			creatorId = id
		end
	end)
	local function inspect(p)
		local C = H.Cfg
		if p == LocalPlayer then
			return
		end
		if C["detect.creator"] and creatorId and p.UserId == creatorId then
			H.Notify("CRIADOR do jogo no servidor: " .. p.DisplayName, 10)
		end
		for _, r in ipairs({ { "Tester", "detect.tester", "Testador" }, { "Moderator", "detect.mod", "Moderador" } }) do
			local spec = H.Profile.Staff[r[1]]
			if C[r[2]] and spec and spec.GroupId then
				task.spawn(function()
					local ok, rank = pcall(p.GetRankInGroup, p, spec.GroupId)
					if ok and rank >= (spec.MinRank or 1) then
						H.Notify(r[3] .. " no servidor: " .. p.DisplayName, 10)
					end
				end)
			end
		end
	end
	local function inspectAll()
		for _, p in ipairs(Players:GetPlayers()) do
			inspect(p)
		end
	end
	for _, key in ipairs({ "detect.creator", "detect.tester", "detect.mod" }) do
		H.Bind(key, function(v)
			if v then
				inspectAll()
			end
		end)
	end
	H.Connect(Players.PlayerAdded, function(p)
		hookChat(p)
		if H.Cfg["notice.join"] then
			H.Notify("Entrou: " .. p.DisplayName .. " (@" .. p.Name .. ")")
		end
		inspect(p)
	end)
	H.Connect(Players.PlayerRemoving, function(p)
		if H.Cfg["notice.join"] then
			H.Notify("Saiu: " .. p.DisplayName)
		end
	end)

	-- suspeito: velocidade horizontal medida acima do limite em duas amostras seguidas
	local samples, strikes, flagged, acc = {}, {}, {}, 0
	H.Connect(RunService.Heartbeat, function(dt)
		if not H.Cfg["detect.cheat"] then
			return
		end
		acc += dt
		if acc < 0.5 then
			return
		end
		local span = acc
		acc = 0
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			local root = p ~= LocalPlayer and c and c:FindFirstChild("HumanoidRootPart")
			if root then
				local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
				local last = samples[p]
				samples[p] = pos
				if last then
					local v = (pos - last).Magnitude / span
					if v > H.Cfg["detect.speed"] and v < 1500 then
						strikes[p] = (strikes[p] or 0) + 1
						if strikes[p] >= 2 and (os.clock() - (flagged[p] or -60)) > 30 then
							flagged[p] = os.clock()
							H.Notify(string.format("Suspeito: %s a %d studs/s", p.DisplayName, math.floor(v)), 8)
						end
					else
						strikes[p] = 0
					end
				end
			end
		end
	end)

	----------------------------------------------------------------
	-- Sons (IDs de audio informados por voce; vazio = desligado)
	----------------------------------------------------------------
	T:Section("Sons (ID de audio do Roblox)")
	T:Slider("Volume dos sons", "snd.vol", 0, 2, 1, 0.1, "%.1f")
	local EVENTS = {
		{ "jump", "Jump" }, { "step", "Pegadas" }, { "land", "Pouso" }, { "fire", "Disparo" },
		{ "head", "Tiro na cabeca" }, { "body", "Tiro no corpo" }, { "blood", "Acerto com sangue" }, { "kill", "Abate" },
	}
	for _, ev in ipairs(EVENTS) do
		T:Input(ev[2], "snd." .. ev[1], "ID", "")
	end
	local function play(ev)
		local id = string.gsub(tostring(H.Cfg["snd." .. ev] or ""), "%D", "")
		if id == "" then
			return
		end
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.Volume = H.Cfg["snd.vol"]
		s.Parent = game:GetService("SoundService")
		s:Play()
		Debris:AddItem(s, 8)
	end
	H.OnEvent("fire", function()
		play("fire")
	end)
	H.OnEvent("hit", function(d)
		play(d and d.head and "head" or "body")
		play("blood")
	end)
	H.OnEvent("kill", function()
		play("kill")
	end)

	local stateConn
	local function hookSounds(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not (hum and H.Alive) then
			return
		end
		if stateConn then
			stateConn:Disconnect()
		end
		stateConn = hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				play("jump")
			elseif new == Enum.HumanoidStateType.Landed then
				play("land")
			end
		end)
	end
	H.Connect(LocalPlayer.CharacterAdded, function(c)
		task.spawn(hookSounds, c)
	end)
	if LocalPlayer.Character then
		task.spawn(hookSounds, LocalPlayer.Character)
	end
	H.OnCleanup(function()
		if stateConn then
			stateConn:Disconnect()
		end
	end)
	local stepAcc = 0
	H.Connect(RunService.Heartbeat, function(dt)
		local hum = H.Hum()
		if not hum or hum.FloorMaterial == Enum.Material.Air or hum.MoveDirection.Magnitude < 0.1 then
			stepAcc = 0
			return
		end
		stepAcc += dt
		if stepAcc >= 0.38 then
			stepAcc = 0
			play("step")
		end
	end)
end

----------------------------------------------------------------------
-- SERVIDORES, JOGO (ferramentas para medir o perfil) e CONFIG; inicializacao
----------------------------------------------------------------------
do
	local TeleportService = game:GetService("TeleportService")
	local S = H.Tabs.Servidores

	S:Section("Servidores")
	S:Info("A lista vem da API publica de servidores do Roblox via game:HttpGet; se o executor bloquear HttpGet, o botao avisa. O teleporte falha em jogos com teleporte restrito.")
	local dyn = {}
	local function clearDyn()
		for _, r in ipairs(dyn) do
			r.frame:Destroy()
			for i, row in ipairs(S.Rows) do
				if row == r then
					table.remove(S.Rows, i)
					break
				end
			end
		end
		table.clear(dyn)
	end
	local function fetch()
		local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
		local ok, body = pcall(function()
			return game:HttpGet(url)
		end)
		if not ok then
			H.Notify("HttpGet indisponivel ou bloqueado: " .. tostring(body), 6)
			return nil
		end
		local ok2, data = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if not ok2 or type(data) ~= "table" or type(data.data) ~= "table" then
			H.Notify("Resposta inesperada da API de servidores.", 6)
			return nil
		end
		local list = {}
		for _, s in ipairs(data.data) do
			if s.id ~= game.JobId and type(s.playing) == "number" and type(s.maxPlayers) == "number" and s.playing < s.maxPlayers then
				list[#list + 1] = s
			end
		end
		return list
	end
	local function join(id)
		local ok, err = pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
		end)
		if not ok then
			H.Notify("Teleporte falhou: " .. tostring(err), 6)
		end
	end
	S:Button("Listar servidores", function()
		local list = fetch()
		if not list then
			return
		end
		clearDyn()
		table.sort(list, function(a, b)
			return a.playing > b.playing
		end)
		for i = 1, math.min(#list, 15) do
			local s = list[i]
			local before = #S.Rows
			S:Button(string.format("Entrar: %d/%d jogadores, ping %s", s.playing, s.maxPlayers, tostring(s.ping or "?")), function()
				join(s.id)
			end)
			if #S.Rows > before then
				dyn[#dyn + 1] = S.Rows[#S.Rows]
			end
		end
		H.Notify(#list .. " servidores com vaga; mostrando ate 15.")
	end)
	S:Button("Servidor com menos jogadores", function()
		local list = fetch()
		if not list or #list == 0 then
			H.Notify("Nenhum servidor disponivel.")
			return
		end
		local best = list[1]
		for _, s in ipairs(list) do
			if s.playing > 0 and s.playing < best.playing then
				best = s
			end
		end
		join(best.id)
	end)
	S:Button("Servidor aleatorio", function()
		local list = fetch()
		if not list or #list == 0 then
			H.Notify("Nenhum servidor disponivel.")
			return
		end
		join(list[math.random(#list)].id)
	end)
	S:Button("Copiar JobId do servidor atual", function()
		if setclipboard then
			setclipboard(game.JobId)
			H.Notify("JobId copiado.")
		else
			H.Notify("JobId: " .. game.JobId, 8)
		end
	end)

	----------------------------------------------------------------
	-- JOGO: o que depende de dados do jogo e como medi-los
	----------------------------------------------------------------
	local J = H.Tabs.Jogo
	J:Section("Ferramentas para preencher H.Profile")
	J:Button("Listar objetos perto (25 studs) no console", function()
		local root = H.Root()
		if not root then
			H.Notify("Sem personagem.")
			return
		end
		local counts, tags = {}, {}
		for _, d in ipairs(Workspace:GetDescendants()) do
			if (d:IsA("Model") or d:IsA("BasePart")) and not d:IsDescendantOf(LocalPlayer.Character or Workspace) then
				local p = d:IsA("Model") and d:GetPivot().Position or d.Position
				if (p - root.Position).Magnitude <= 25 then
					local k = d.ClassName .. " | " .. d.Name
					counts[k] = (counts[k] or 0) + 1
					local t = CollectionService:GetTags(d)
					if #t > 0 then
						tags[k] = table.concat(t, ",")
					end
				end
			end
		end
		local keys = {}
		for k in pairs(counts) do
			keys[#keys + 1] = k
		end
		table.sort(keys)
		print("[mc1h] objetos a 25 studs:")
		for _, k in ipairs(keys) do
			print(string.format("  %s  x%d  tags=%s", k, counts[k], tags[k] or "-"))
		end
		H.Notify(#keys .. " tipos de objeto listados no console (F9 / logs do executor).")
	end)
	J:Button("Listar RemoteEvents/RemoteFunctions no console", function()
		local n = 0
		print("[mc1h] remotes:")
		for _, d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
			if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
				n += 1
				if n <= 300 then
					print("  " .. d.ClassName .. " " .. d:GetFullName())
				end
			end
		end
		H.Notify(n .. " remotes em ReplicatedStorage (ate 300 no console).")
	end)
	J:Button("Detalhar ferramenta equipada no console", function()
		local c = H.Char()
		local tool = c and c:FindFirstChildOfClass("Tool")
		if not tool then
			H.Notify("Nenhuma ferramenta equipada.")
			return
		end
		print("[mc1h] ferramenta: " .. tool:GetFullName())
		for k, v in pairs(tool:GetAttributes()) do
			print("  atributo " .. k .. " = " .. tostring(v))
		end
		for _, d in ipairs(tool:GetDescendants()) do
			print("  " .. d.ClassName .. " " .. d:GetFullName())
		end
		H.Notify("Ferramenta '" .. tool.Name .. "' detalhada no console.")
	end)
	J:Section("Nao implementado: dependem do jogo")
	J:Info("Buscar saque, Saque automatico, Comerciantes, Missoes, Skins, Ordenar deposito e Ver inventario de outros jogadores: exigem os remotes, a UI e os dados de inventario do jogo, que nao foram medidos. Use os botoes acima para achar os RemoteEvents e os nomes dos objetos e me envie a saida.")
	J:Info("Tambem nao implementados: Deslocamento, Manuseio da arma, Abastecer cargadores, Sem tremor, Espiada subterranea, Fantasma, Rastros do jogo, Mapa e navegacao (significado/dados do jogo nao confirmados).")

	----------------------------------------------------------------
	-- CONFIG
	----------------------------------------------------------------
	local C = H.Tabs.Config
	C:Section("Perfil de configuracao")
	C:Button("Salvar configuracao", function()
		H.Notify(H.Save() and "Configuracao salva." or "writefile indisponivel: nao foi possivel salvar.")
	end)
	C:Button("Carregar configuracao", function()
		if not H.Load() then
			H.Notify("Nada para carregar (arquivo ausente ou readfile indisponivel).")
			return
		end
		for k in pairs(H.Cfg) do
			local r = H.Refresh[k]
			if r then
				r(H.Cfg[k])
			end
		end
		H.Notify("Carregado. Alternar cada recurso aplica o valor salvo.")
	end)
	C:Button("Desligar todos os recursos", function()
		for k, v in pairs(H.Cfg) do
			if v == true then
				H.Set(k, false)
			end
		end
	end)
	C:Button("Descarregar o hub", function()
		task.defer(H.Destroy)
	end)
	C:Section("Executor")
	C:Info(string.format("Drawing=%s  Hook(metamethods)=%s  Arquivos=%s  Toque=%s. Abrir/fechar o menu: botao HUB ou RightShift.", tostring(H.Cap.Drawing), tostring(H.Cap.Hook), tostring(H.Cap.Files), tostring(UserInputService.TouchEnabled)))
end

print(string.format("[mc1h] HUB carregado | Drawing=%s Hook=%s Arquivos=%s Toque=%s", tostring(H.Cap.Drawing), tostring(H.Cap.Hook), tostring(H.Cap.Files), tostring(UserInputService.TouchEnabled)))
H.Notify("mc1h HUB carregado. Toque em HUB para abrir.")

