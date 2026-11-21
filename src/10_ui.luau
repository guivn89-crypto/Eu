-- ============ 10_ui.luau :: Elementos de UI: Toggle, Slider, Dropdown, Button, Keybind, Input, cor, Foldout, Segmented ============
-- ============================================================
--  Aba, grupo e janela
-- ============================================================
local Tab = setmetatable({}, { __index = Container })
Tab.__index = Tab
local Window = {}
Window.__index = Window

function Window:_connect(signal, fn)
    local c = safeConnect(signal, fn)
    table.insert(self._conns, c)
    return c
end

function Window:_touchTarget(row, baseline)
    self._touchRows = self._touchRows or {}
    self._touchRows[#self._touchRows + 1] = { row = row, baseline = baseline }
    local vp = self.Gui.AbsoluteSize
    local compact = Library.UISupport.compact(vp.X, vp.Y, UserInputService.TouchEnabled)
    row.Size = UDim2.new(1, 0, 0, compact and math.max(40, baseline) or baseline)
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

-- Em toque/portrait, mantém os mesmos objetos e troca duas colunas por uma.
function Tab:_layoutColumns()
    if not self._cols then return end
    local vp = self.Window.Gui.AbsoluteSize
    local compact = Library.UISupport.compact(vp.X, vp.Y, UserInputService.TouchEnabled)
    local left, right = self._cols.Left, self._cols.Right
    left.Size = compact and UDim2.fromScale(1, 1) or UDim2.new(0.5, -4, 1, 0)
    right.Visible = not compact
    for _, item in ipairs(self._groupBoxes or {}) do
        local dest = compact and left or self._cols[item.side]
        if item.box.Parent ~= dest then item.box.Parent = dest end
    end
end

function Tab:Groupbox(opts)
    opts = opts or {}
    local col = self:_column(opts.Side)
    self._groupBoxes = self._groupBoxes or {}
    local originalSide = col == self._cols.Right and "Right" or "Left"
    local box = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = #self._groupBoxes + 1 }, col)
    table.insert(self._groupBoxes, { box = box, side = originalSide })
    self:_layoutColumns()
    bind(box, "BackgroundColor3", "Surface"); corner(box, 4)
    local bs = create("UIStroke", { Thickness = 1, Transparency = 0.2 }, box); bind(bs, "Color", "Accent")
    listLayout(box, 0)
    local head = create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, box)
    local x = 10
    if opts.Icon then icon(head, opts.Icon, 15, "Text", { Position = UDim2.fromOffset(10, 6.5) }); x = 31 end
    label(head, opts.Name, 13, "Muted", false, { Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - (opts.Checkbox and 62 or 34), 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local cbObj
    if opts.Checkbox then
        local on = opts.Default ~= false
        if on and opts.CanSet then
            local ok, allowed = pcall(opts.CanSet, true)
            if not ok or not allowed then on = false end
        end
        local cb = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(24, 24), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, head)
        corner(cb, 4); stroke(cb, "Accent", 0.1)
        bind(cb, "BackgroundColor3", function() return on and Library.Theme.Accent or Library.Theme.Surface3 end)
        local mark = label(cb, "✓", 13, "Text", true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Visible = on })
        cbObj = {}
        function cbObj:Set(v, silent)
            if opts.CanSet then
                local ok, allowed = pcall(opts.CanSet, v == true)
                if not ok or not allowed then return false end
            end
            local previous = on
            on = v == true
            if not silent and type(opts.Callback) == "function" then
                local ok, err = pcall(opts.Callback, on)
                if not ok then
                    warn("[BBC] " .. tostring(opts.Name) .. ": " .. tostring(err))
                    on = previous
                    pcall(opts.Callback, previous)
                    cb.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface3
                    mark.Visible = on
                    return false
                end
            end
            cb.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface3
            mark.Visible = on
            return true
        end
        function cbObj:Get() return on end
        safeConnect(cb.MouseButton1Click, function() cbObj:Set(not on) end)
        register(self, tostring(opts.Name) .. "#ativo", function() return on end, function(v) return cbObj:Set(v) end)
        if on then safeCall(opts.Callback, true) end
    end
    local ln = create("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 1, -1), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, head)
    bind(ln, "BackgroundColor3", "Stroke")
    local body = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, box)
    listLayout(body, 0)
    local fold = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, opts.Checkbox and -36 or -6, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Text = "▼", TextSize = 14, AutoButtonColor = false }, head)
    bind(fold, "TextColor3", "Text")
    local expanded = true
    local function showGroup() body.Visible = expanded or (self.Window._filterQuery or "") ~= ""; fold.Text = body.Visible and "▼" or "▶" end
    safeConnect(fold.MouseButton1Click, function() expanded = not expanded; showGroup() end)
    self.Window._groupOpeners = self.Window._groupOpeners or {}
    self.Window._groupOpeners[body] = function() expanded = true; showGroup() end
    self.Window._groups = self.Window._groups or {}
    table.insert(self.Window._groups, showGroup)
    return setmetatable({ List = body, _order = 0, Window = self.Window, _path = self._path .. "/" .. tostring(opts.Name), Frame = box, Checkbox = cbObj }, Container)
end

local function fmtLeft(sec)
    sec = math.max(math.floor(sec), 0)
    local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
    if d > 0 then return d .. "d " .. h .. "h" end
    return h .. "h " .. m .. "m"
end

function Window:_getModal(key, titles, build)
    self._modals = self._modals or {}
    local m = self._modals[key]
    if m then return m end
    local overlay = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 20 }, self._content)
    overlay:SetAttribute("SearchModal", key)
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
    safeConnect(close.MouseButton1Click, function() overlay.Visible = false end)
    local lbody = create("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1 }, lb)
    local rs = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, rb)
    bind(rs, "ScrollBarImageColor3", "Accent")
    listLayout(rs, 0); pad(rs, 4, 6, 0, 4)
    m = { Overlay = overlay, Left = lbody, LeftBox = lb, RightBox = rb, RightScroll = rs, Close = function() overlay.Visible = false end }
    m.Right = setmetatable({ List = rs, _order = 0, Window = self, _path = key .. "/painel" }, Container)
    self._modals[key] = m
    if type(build) == "function" then
        local ok, err = pcall(build, m)
        if not ok then
            self._modals[key] = nil
            overlay:Destroy()
            error(err)
        end
    end
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
    if switching and tab.Page and not Library.ReduceMotion then
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
    tab._searchCount = label(btn, "", 11, "Text", true, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(24, 18), TextXAlignment = Enum.TextXAlignment.Right })
    tab.Sel = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1 }, btn)
    bind(tab.Sel, "BackgroundColor3", "Accent"); corner(tab.Sel, 4)
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }) }, tab.Sel)
    tab.IconImg = icon(btn, opts.Icon or "circle", 16, "Muted", { Position = UDim2.fromOffset(12, 5.5) })
    tab.Text = label(btn, string.upper(opts.Name or ""), 13, "Muted", false, { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -66, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    table.insert(self.Tabs, tab)
    safeConnect(btn.MouseButton1Click, function() self:_select(tab) end)
    if not self.Current or self.Current == self.HomeTab then self:_select(tab) end
    -- a barra da intro avança a cada aba montada (e cede um quadro para ela desenhar)
    if self._introProgress then
        self._tabCount = (self._tabCount or 0) + 1
        self._introProgress(2 / 3, Library.Tr("Montando o menu") .. " · " .. string.upper(Library.Tr(tostring(opts.Name or ""))))
        task.wait()
    end
    return tab
end

-- ---------- Configurações salvas (perfis) ----------
local CFG_FOLDER = "BBC_HUB/configs"
local AUTOLOAD_FILE = "BBC_HUB/autoload.txt"
local function canFS() return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" end
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
-- texto estável (chaves em ordem) só para saber se algo mudou
local function stable(v)
    local kind = type(v)
    if kind ~= "table" then
        local text = tostring(v)
        return kind .. ":" .. #text .. ":" .. text
    end
    local items = {}
    for k, x in pairs(v) do items[#items + 1] = { stable(k), x } end
    table.sort(items, function(a, b) return a[1] < b[1] end)
    for i, it in ipairs(items) do items[i] = it[1] .. stable(it[2]) end
    return "table:" .. #items .. ":{" .. table.concat(items) .. "}"
end
local function endsWith(key, tail) return string.sub(key, -#tail) == tail end

function Window:_snapshot()
    local data = {}
    for key, r in pairs(Library.Registry) do
        local ok, val = pcall(r.get)
        if ok and val ~= nil then data[key] = val end
    end
    return data
end
function Window:_applyData(decoded)
    local policy = Library.Safety
    local blocked = (policy and (policy.enabled or policy.panic)) and policy.blocked or {}
    local operations, err, skipped, unknown = Library.ProfileGuard:prepare(decoded, Library.Registry, blocked)
    if not operations then return false, err end
    local ok, key = Library.ProfileGuard:apply(operations)
    if not ok then return false, "falha ao aplicar: " .. tostring(key) end
    return true, nil, skipped, unknown
end
local function decodeProfile(text)
    if type(text) ~= "string" or #text > Library.ProfileGuard.MAX_BYTES then return nil end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(text) end)
    if not ok or type(decoded) ~= "table" then return nil end
    return decoded
end
-- Backup somente de um arquivo decodificável. A escrita não é atômica em
-- executores genéricos; se o backup falhar, não sobrescrevemos o original.
local function writeConfigWithBackup(path, json)
    local ok, err = pcall(function()
        if isfile(path) then
            local previous = readfile(path)
            local decoded = decodeProfile(previous)
            assert(decoded and Library.ProfileGuard:validateTree(decoded), "arquivo anterior inválido; não será sobrescrito")
            assert(writefile(path .. ".bak", previous) ~= false, "falha ao gravar backup")
        end
        assert(writefile(path, json) ~= false, "falha ao gravar perfil")
    end)
    return ok, err
end
function Window:SaveConfig(name, quiet)
    name = cleanName(name)
    if name == "" then name = "default" end
    if not canFS() then Library:Notify({ Title = "BBC HUB", Content = "Salvar precisa de writefile no executor." }); return false end
    ensureFolders()
    local snap = self:_snapshot()
    if not Library.ProfileGuard:validateTree(snap) then return false end
    local ok, failure = pcall(function()
        local json = HttpService:JSONEncode({ v = 2, name = name, data = snap })
        assert(#json <= Library.ProfileGuard.MAX_BYTES, "perfil grande demais")
        local written, err = writeConfigWithBackup(CFG_FOLDER .. "/" .. name .. ".json", json)
        assert(written, err)
    end)
    if ok then
        self._cfgName = name
        self._autoSaveBlocked = false
        self._lastState = stable(snap)
        if self._cfgBox then self._cfgBox.Text = name end
        if self._configChanged then pcall(self._configChanged) end
    end
    if not ok then
        warn("[BBC] Falha ao salvar configuração: " .. tostring(failure))
        if Library.Diagnostics then Library.Diagnostics:record("configuração", failure) end
    end
    if not quiet then Library:Notify({ Title = "BBC HUB", Content = ok and ("Configuração salva: " .. name) or "Falha ao salvar; veja o console." }) end
    return ok
end
-- Confirmação apenas para o botão manual; a API e o autosave permanecem separados.
function Window:RequestSaveConfig(name)
    name = cleanName(name)
    if name == "" then name = "default" end
    if not canFS() then return false, "arquivos indisponíveis" end
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, exists, raw = pcall(function()
        local present = isfile(path)
        return present, present and readfile(path) or nil
    end)
    if not ok then return false, "não foi possível verificar o arquivo" end
    if not exists then
        local staged = self._savePreview
        self._savePreview = nil
        if staged and staged.name == name then return false, "alterado" end
        return self:SaveConfig(name), "salvo"
    end
    local decoded = decodeProfile(raw)
    if not decoded or not Library.ProfileGuard:validateTree(decoded) then self._savePreview = nil; return false, "arquivo anterior inválido; preservado" end
    local snapshot = self:_snapshot()
    if not Library.ProfileGuard:validateTree(snapshot) then return false, "ajustes inválidos" end
    local signature = stable(snapshot)
    local staged = self._savePreview
    if not staged or staged.name ~= name or os.clock() > staged.expires then
        self._savePreview = { name = name, raw = raw, signature = signature, expires = os.clock() + 30 }
        return false, "confirmar"
    end
    self._savePreview = nil
    if staged.raw ~= raw or staged.signature ~= signature then return false, "alterado" end
    local versionOK = self:CreateConfigVersion(name)
    if not versionOK then Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Histórico não criado; backup normal continua disponível.") }) end
    return self:SaveConfig(name), "salvo"
end
function Window:LoadConfig(name, quiet)
    if not canFS() then
        if not quiet then Library:Notify({ Title = "BBC HUB", Content = "Carregar precisa de acesso a arquivos no executor." }) end
        return false
    end
    name = cleanName(name)
    if name == "" then name = "default" end
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, raw = pcall(function() if isfile(path) then return readfile(path) end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded then
        if Library.Diagnostics then Library.Diagnostics:record("carregamento", "arquivo ausente, inválido ou grande demais") end
        if not quiet then Library:Notify({ Title = "BBC HUB", Content = "Perfil inválido ou grande demais." }) end
        return false
    end
    local applied, err, skipped, unknown = self:_applyData(decoded)
    if not applied then
        if Library.Diagnostics then Library.Diagnostics:record("carregamento", err) end
        if not quiet then Library:Notify({ Title = "BBC HUB", Content = "Perfil rejeitado: " .. tostring(err) }) end
        return false
    end
    self._cfgName = name
    self._autoSaveBlocked = false
    self._lastState = stable(self:_snapshot())
    if self._cfgBox then self._cfgBox.Text = name end
    if skipped > 0 or unknown > 0 or not quiet then
        Library:Notify({ Title = "BBC HUB", Content = "Configuração carregada: " .. name .. (skipped > 0 and (" · " .. skipped .. " opções bloqueadas") or "") .. (unknown > 0 and (" · " .. unknown .. " ajustes desconhecidos ignorados") or "") })
    end
    if self._configChanged then pcall(self._configChanged) end
    return true
end
-- A prévia só lê e valida; não chama setters. A confirmação relê o arquivo
-- e invalida a prévia se o conteúdo, os valores atuais ou a política mudarem.
function Window:PreviewConfig(name)
    if not canFS() then return nil, "acesso a arquivos indisponível" end
    name = cleanName(name)
    if name == "" then name = "default" end
    local ok, raw = pcall(function() if isfile(CFG_FOLDER .. "/" .. name .. ".json") then return readfile(CFG_FOLDER .. "/" .. name .. ".json") end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded then return nil, "perfil ausente, inválido ou grande demais" end
    local policy = Library.Safety
    local blocked = (policy and (policy.enabled or policy.panic)) and policy.blocked or {}
    local operations, err, skipped, unknown = Library.ProfileGuard:prepare(decoded, Library.Registry, blocked)
    if not operations then return nil, err end
    local changes, fingerprint = {}, { skipped = skipped, unknown = unknown, enabled = policy and policy.enabled == true, panic = policy and policy.panic == true, blocked = blocked, operations = {} }
    local function display(v)
        if v == nil then return "—" end
        if type(v) == "table" then
            local pieces, n = {}, 0
            for k, value in pairs(v) do
                n += 1
                if n <= 6 then pieces[#pieces + 1] = string.sub(tostring(k), 1, 16) .. "=" .. string.sub(type(value) == "table" and "{…}" or tostring(value), 1, 24) end
            end
            table.sort(pieces)
            return "{" .. table.concat(pieces, ", ") .. (n > 6 and ", …" or "") .. "}"
        end
        return string.sub(tostring(v), 1, 60)
    end
    for _, op in ipairs(operations) do
        fingerprint.operations[op.key] = { before = op.old, after = op.value }
        if stable(op.old) ~= stable(op.value) then
            changes[#changes + 1] = { key = op.key, before = display(op.old), after = display(op.value) }
        end
    end
    return { name = name, raw = raw, signature = stable(fingerprint), changes = changes, skipped = skipped, unknown = unknown, operations = operations }
end
function Window:StageConfigPreview(name)
    self._configPreview = nil
    local preview, err = self:PreviewConfig(name)
    if not preview then return nil, err end
    preview.expires = os.clock() + 60
    self._configPreview = preview
    return preview
end
function Window:ConfirmConfigPreview(name)
    local staged = self._configPreview
    self._configPreview = nil
    name = cleanName(name)
    if name == "" then name = "default" end
    if not staged or staged.name ~= name or os.clock() > staged.expires then return false, "prévia ausente ou expirada" end
    local current, err = self:PreviewConfig(name)
    if not current then return false, err end
    if current.raw ~= staged.raw or current.signature ~= staged.signature then return false, "perfil, ajustes ou política mudaram; revise novamente" end
    local applied, key = Library.ProfileGuard:apply(current.operations)
    if not applied then
        if Library.Diagnostics then Library.Diagnostics:record("carregamento", key) end
        return false, "falha ao aplicar: " .. tostring(key)
    end
    self._cfgName, self._autoSaveBlocked = name, false
    self._lastState = stable(self:_snapshot())
    if self._cfgBox then self._cfgBox.Text = name end
    if self._configChanged then pcall(self._configChanged) end
    Library:Notify({ Title = "BBC HUB", Content = "Configuração carregada: " .. name .. (current.skipped > 0 and (" · opções bloqueadas: " .. current.skipped) or "") .. (current.unknown > 0 and (" · ajustes desconhecidos: " .. current.unknown) or "") })
    return true
end
-- Recupera em outro arquivo: nunca modifica o original ou o backup.
function Window:RestoreConfigBackup(name)
    name = cleanName(name)
    if name == "" then name = "default" end
    if not canFS() then return false, "acesso a arquivos indisponível" end
    local source = CFG_FOLDER .. "/" .. name .. ".json.bak"
    local ok, raw = pcall(function() if isfile(source) then return readfile(source) end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded then return false, "backup ausente ou inválido" end
    local policy = Library.Safety
    local blocked = (policy and (policy.enabled or policy.panic)) and policy.blocked or {}
    local operations, err = Library.ProfileGuard:prepare(decoded, Library.Registry, blocked)
    if not operations then return false, err end
    local recovery
    for i = 1, 99 do
        local suffix = "-rec" .. i
        local candidate = string.sub(name, 1, 24 - #suffix) .. suffix
        local existsOK, exists = pcall(isfile, CFG_FOLDER .. "/" .. candidate .. ".json")
        if not existsOK then return false, "não foi possível verificar o arquivo de destino" end
        if not exists then recovery = candidate; break end
    end
    if not recovery then return false, "sem nome disponível para recuperação" end
    ensureFolders()
    local written, writeErr = pcall(writefile, CFG_FOLDER .. "/" .. recovery .. ".json", raw)
    if not written then return false, "não foi possível criar cópia: " .. tostring(writeErr) end
    if not self:LoadConfig(recovery) then return false, "cópia criada, mas não pôde ser carregada: " .. recovery end
    return true, recovery
end
-- Até três cópias independentes, sem rotação destrutiva nem sobrescrita.
function Window:ListConfigVersions(name)
    name = cleanName(name); if name == "" then name = "default" end
    local out = {}
    if not canFS() then return out end
    for i = 1, 3 do
        local ok, exists = pcall(isfile, CFG_FOLDER .. "/" .. name .. ".json.version" .. i)
        if ok and exists then out[#out + 1] = tostring(i) end
    end
    return out
end
function Window:CreateConfigVersion(name)
    name = cleanName(name); if name == "" then name = "default" end
    if not canFS() then return false, "arquivos indisponíveis" end
    local source = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, raw = pcall(function() if isfile(source) then return readfile(source) end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded or not Library.ProfileGuard:validateTree(decoded) then return false, "perfil inválido ou ausente" end
    for i = 1, 3 do
        local dest = source .. ".version" .. i
        local checked, exists = pcall(isfile, dest)
        if not checked then return false, "não foi possível verificar o destino" end
        if not exists then
            local written, result = pcall(writefile, dest, raw)
            if not written or result == false then return false, "falha ao gravar versão" end
            return true, tostring(i)
        end
    end
    return false, "limite de versões atingido"
end
function Window:RestoreConfigVersion(name, version)
    name = cleanName(name); if name == "" then name = "default" end
    local n = tonumber(version)
    if not canFS() or not n or n % 1 ~= 0 or n < 1 or n > 3 then return false, "versão indisponível" end
    local path = CFG_FOLDER .. "/" .. name .. ".json.version" .. n
    local ok, raw = pcall(function() if isfile(path) then return readfile(path) end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded then return false, "versão inválida ou ausente" end
    local policy = Library.Safety
    local blocked = (policy and (policy.enabled or policy.panic)) and policy.blocked or {}
    local operations, err = Library.ProfileGuard:prepare(decoded, Library.Registry, blocked)
    if not operations then return false, err end
    for i = 1, 99 do
        local suffix = "-hist" .. i
        local candidate = string.sub(name, 1, 24 - #suffix) .. suffix
        local dest = CFG_FOLDER .. "/" .. candidate .. ".json"
        local checked, exists = pcall(isfile, dest)
        if not checked then return false, "não foi possível verificar o destino" end
        if not exists then
            local written, result = pcall(writefile, dest, raw)
            if not written or result == false then return false, "falha ao criar cópia" end
            return true, candidate
        end
    end
    return false, "sem nome disponível para recuperação"
end
function Window:ListConfigs()
    local out = {}
    if type(listfiles) ~= "function" then return out end
    pcall(function()
        for _, path in ipairs(listfiles(CFG_FOLDER)) do
            local n = string.match(path, "([^/\\]+)%.json$")
            if n and n ~= "" and cleanName(n) == n then table.insert(out, n) end
        end
    end)
    table.sort(out, function(a, b) return string.lower(a) < string.lower(b) end)
    while #out > 100 do table.remove(out) end
    return out
end
function Window:DeleteConfig(name)
    name = cleanName(name)
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    if type(delfile) ~= "function" or not canFS() or not isfile(path) then
        Library:Notify({ Title = "BBC HUB", Content = "Não foi possível apagar este perfil." }); return false
    end
    local ok = pcall(delfile, path)
    if ok and self:GetAutoload() == name then self:SetAutoload(false) end
    Library:Notify({ Title = "BBC HUB", Content = ok and ("Perfil apagado: " .. name) or "Falha ao apagar." })
    return ok
end
-- perfil carregado ao iniciar: nome, "none" (desligado) ou, sem arquivo, o perfil "default" se existir
function Window:GetAutoload()
    if not canFS() then return nil end
    local _, raw = pcall(function() if isfile(AUTOLOAD_FILE) then return readfile(AUTOLOAD_FILE) end end)
    local n = type(raw) == "string" and cleanName(raw) or ""
    if n == "none" then return nil end
    if n == "" then n = "default" end
    local ok, exists = pcall(isfile, CFG_FOLDER .. "/" .. n .. ".json")
    if ok and exists then return n end
    return nil
end
function Window:SetAutoload(name)
    if not canFS() then return end
    ensureFolders()
    local value = name and cleanName(name) or "none"
    if name and (value == "" or value == "none") then return false end
    local ok = pcall(writefile, AUTOLOAD_FILE, value)
    return ok
end
function Window:ExportConfig()
    local ok, json = pcall(function()
        local snap = self:_snapshot()
        assert(Library.ProfileGuard:validateTree(snap), "perfil inválido")
        local encoded = HttpService:JSONEncode({ v = 2, data = snap })
        assert(#encoded <= Library.ProfileGuard.MAX_BYTES, "perfil grande demais")
        return encoded
    end)
    local copy = setclipboard or toclipboard
    if ok and type(copy) == "function" and pcall(copy, json) then
        Library:Notify({ Title = "BBC HUB", Content = "Código do perfil copiado." })
    else
        Library:Notify({ Title = "BBC HUB", Content = "Seu executor não permite copiar para a área de transferência." })
    end
end
function Window:ImportConfig(text, saveAs)
    local decoded = decodeProfile(text)
    if not decoded then Library:Notify({ Title = "BBC HUB", Content = "Código inválido ou grande demais." }); return false end
    local applied, err, skipped = self:_applyData(decoded)
    if not applied then Library:Notify({ Title = "BBC HUB", Content = "Perfil rejeitado: " .. tostring(err) }); return false end
    -- senão o autocontrole acha que nada mudou e o perfil importado nunca é gravado
    self._lastState = stable(self:_snapshot())
    if self._cfgBox then self._cfgBox.Text = self._cfgName or "" end
    Library:Notify({ Title = "BBC HUB", Content = "Perfil importado." .. (skipped > 0 and (" Opções bloqueadas: " .. skipped) or "") })
    if saveAs and not self:SaveConfig(saveAs, true) then
        Library:Notify({ Title = "BBC HUB", Content = "Importado, mas não foi possível salvar." })
        return false
    end
    return true
end
-- guarda os valores iniciais para o "Resetar tudo"
function Window:CaptureDefaults()
    for _, r in pairs(Library.Registry) do
        local ok, v = pcall(r.get)
        r.has = ok and v ~= nil
        if r.has then r.default = v end
    end
end
function Window:ResetConfig()
    for key, r in pairs(Library.Registry) do
        if r.has then pcall(r.set, r.default)
        elseif endsWith(key, "#tecla") or endsWith(key, "#fixado") then pcall(r.set, nil) end
    end
    Library:Notify({ Title = "BBC HUB", Content = "Tudo voltou ao padrão." })
end
-- salva sozinho o que você ligou/mexeu no menu (e carrega na próxima vez que executar)
function Window:_autoSaveNow()
    if not canFS() or self._introActive or not self._ready or self._autoSaveBlocked then return end
    local snap = self:_snapshot()
    if not Library.ProfileGuard:validateTree(snap) then return end
    local state = stable(snap)
    if state == self._lastState then return end
    ensureFolders()
    local name = self._cfgName or "default"
    local ok, failure = pcall(function()
        local json = HttpService:JSONEncode({ v = 2, name = name, data = snap })
        assert(#json <= Library.ProfileGuard.MAX_BYTES, "perfil grande demais")
        local written, err = writeConfigWithBackup(CFG_FOLDER .. "/" .. name .. ".json", json)
        assert(written, err)
    end)
    if ok then
        local firstConfig = self._cfgName == nil
        self._cfgName = name
        self._lastState = state
        self._autoSaveWarned = false
        if firstConfig and self._configChanged then pcall(self._configChanged) end
    elseif not self._autoSaveWarned then
        self._autoSaveWarned = true
        warn("[BBC] Salvamento automático falhou: " .. tostring(failure))
        if Library.Diagnostics then Library.Diagnostics:record("salvamento automático", failure) end
        Library:Notify({ Title = "BBC HUB", Content = "Falha no salvamento automático; tentando novamente. Veja o console." })
    end
end
function Window:StartAutoSave()
    if self._autoSaveOn then return end
    self._autoSaveOn = true
    if self._lastState == nil then self._lastState = stable(self:_snapshot()) end
    task.spawn(function()
        while self.Gui and self.Gui.Parent do
            task.wait(3)
            if self.Gui and self.Gui.Parent then safeCall(function() self:_autoSaveNow() end) end
        end
    end)
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
function Window:_updateIsland()
    if self._island then self._island.Visible = (self._islandOn ~= false) and not self._main.Visible and not self._introActive end
    self:_updatePins()
end

-- botões fixos na tela (aparecem com o menu fechado): toque liga/desliga, arraste move, segure remove
-- modo pânico: esconde menu, ESP, radar e botões fixos de uma vez; o menu volta como estava
function Library:OnPanic(fn) table.insert(Library._panicListeners, fn) end
function Window:SetPanic(on)
    on = on == true
    if Library.Panic == on then return end
    Library.Panic = on
    if self.Gui then self.Gui.Enabled = not on end
    if notifyGui then notifyGui.Enabled = not on end
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
    safeConnect(btn.InputBegan, function(i)
        local t = i.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        dragging, moved, startIn, startPos = true, false, i.Position, btn.Position
        tok += 1
        local my = tok
        task.delay(0.8, function()   -- segurar parado remove o botão
            if tok == my and dragging and not moved and btn.Parent then
                self._pins[name] = nil
                if pin.OnRemoved then pin.OnRemoved() end
                pin.Destroy()
                Library:Notify({ Title = tostring(name), Content = "Botão removido da tela.", Duration = 1.5 })
            end
        end)
    end)
    c1 = safeConnect(UserInputService.InputChanged, function(i)
        if not dragging then return end
        local t = i.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseMovement then return end
        local d = i.Position - startIn
        if d.Magnitude > 8 then moved = true end
        if moved then btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
    end)
    c2 = safeConnect(UserInputService.InputEnded, function(i)
        local t = i.UserInputType
        if not dragging or (t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1) then return end
        dragging = false
        tok += 1
        if moved then
            local vp = self.Gui.AbsoluteSize
            local c = btn.AbsolutePosition + btn.AbsoluteSize / 2
            if vp.X > 0 and vp.Y > 0 then
                local hx, hy = math.min(0.5, 23 / vp.X), math.min(0.5, 23 / vp.Y)
                btn.Position = UDim2.fromScale(math.clamp(c.X / vp.X, hx, 1 - hx), math.clamp(c.Y / vp.Y, hy, 1 - hy))
            end
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
    if self._fit then self._fit() end
    btn.Visible = not self._main.Visible and not self._introActive
    return pin
end
function Window:SetIsland(on)
    self._islandOn = on == true
    self:_updateIsland()
end
-- abrir/fechar com um "pop" (escala), sem precisar de transparência nos filhos
function Window:_setOpen(v)
    if self._introActive or Library.Panic then return end
    local main, scale = self._main, self._scale
    local was = self._wantOpen ~= false
    self._wantOpen = v
    if v == was and main.Visible == v then return end
    self._animToken = (self._animToken or 0) + 1
    local my = self._animToken
    if not (Library.MenuAnim and scale) or Library.ReduceMotion then
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
    if self._fit then self._fit() end
    local dragging, moved, startPos, startInput = false, false, nil, nil
    safeConnect(b.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved, startInput, startPos = true, false, i.Position, b.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(i)
        if dragging and self._btnDraggable ~= false and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            if d.Magnitude > 6 then moved = true end
            if moved then
                local vp, size = self.Gui.AbsoluteSize, b.AbsoluteSize
                local x = startPos.X.Scale * vp.X + startPos.X.Offset + d.X
                local y = startPos.Y.Scale * vp.Y + startPos.Y.Offset + d.Y
                b.Position = UDim2.fromOffset(math.clamp(x, 0, math.max(0, vp.X - size.X)), math.clamp(y, 0, math.max(0, vp.Y - size.Y)))
            end
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
    if Library._kbOwner == "tip" and Library._kbCancel then pcall(Library._kbCancel) end
    local f = self._tipFrame
    if not f then return end
    task.delay(delay or 0, function()
        if self._tipFrame ~= f or self._tipHover then return end
        self._tipFrame = nil
        tween(f, { GroupTransparency = 1 }, 0.15)
        task.delay(0.2, function() f:Destroy() end)
    end)
end

-- cartão de ajuda: nome, estado (ATIVO/INATIVO) e o que a opção faz, perto da linha
function Window:_tip(title, text, row, stateFn, extras)
    if Library._kbOwner == "tip" and Library._kbCancel then pcall(Library._kbCancel) end
    if self._tipFrame then self._tipFrame:Destroy(); self._tipFrame = nil end
    self._tipHover = false
    local main = self._main
    local sc = (self._scale and self._scale.Scale) or 1
    local f = create("CanvasGroup", { Size = UDim2.fromOffset(236, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 50, GroupTransparency = 1 }, main)
    bind(f, "BackgroundColor3", "Surface3"); corner(f, 7); stroke(f, "Accent", 0.1)
    pad(f, 11, 11, 8, 9); listLayout(f, 3)
    local head = create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1 }, f)
    label(head, Library.Tr(tostring(title)), 13, "Accent", true, { Size = UDim2.new(1, -62, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 51 })
    if stateFn then
        local state = stateFn()
        local on = state == true
        local chip = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(56, 16), BorderSizePixel = 0, ZIndex = 51 }, head)
        corner(chip, 8)
        chip.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface
        local txt = label(chip, Library.Tr(state == "pending" and "PENDENTE" or state == "vip" and "VIP" or state == "blocked" and "BLOQUEADO" or (on and "ATIVO" or "INATIVO")), 10, "Text", true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 52 })
        if not on then txt.TextColor3 = Library.Theme.Muted end
    end
    label(f, text and tostring(text) or "Toque para ativar ou desativar.", 12, text and "Text" or "Muted", false, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 16), ZIndex = 51 })
    if extras then
        local actions = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3 }, f)
        local al = listLayout(actions, 6, Enum.FillDirection.Horizontal)
        -- Versões antigas podem não expor Wraps; empilhar evita cortar ações.
        if not pcall(function() al.Wraps = true end) then al.FillDirection = Enum.FillDirection.Vertical end
        al.VerticalAlignment = Enum.VerticalAlignment.Center
        local function chipBtn(text, order)
            local b = create("TextButton", { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 11, FontFace = Library.Fonts.Bold,
                AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 51 }, actions)
            bind(b, "BackgroundColor3", "Surface"); bind(b, "TextColor3", "Text")
            corner(b, 5); stroke(b, "Stroke", 0.2); pad(b, 8, 8, 0, 0)
            return b
        end
        local function keep() self._tipToken = (self._tipToken or 0) + 1; self._tipHover = false; self:_hideTip(2.5) end
        if UserInputService.KeyboardEnabled and extras.getKey then
            local function keyLabel() local k = extras.getKey(); return "Atalho: " .. (k and keyText(k) or "—") end
            local kb = chipBtn(keyLabel(), 1)
            safeConnect(kb.MouseButton1Click, function()
                local c
                local function cancel()
                    if c then c:Disconnect(); c = nil end
                    kb.Text = keyLabel()
                    Library:_kbDone()
                    keep()
                end
                Library:_kbListen("tip", cancel)
                kb.Text = "Pressione uma tecla…"
                c = safeConnect(UserInputService.InputBegan, function(input)
                    local t = input.UserInputType
                    local isMouse = t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3
                    if t ~= Enum.UserInputType.Keyboard and not isMouse then return end
                    local code = isMouse and t or input.KeyCode
                    c:Disconnect(); c = nil
                    Library:_kbDone()
                    if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then extras.setKey(nil) else extras.setKey(code) end
                    kb.Text = keyLabel()
                    keep()
                end)
            end)
        end
        if extras.isPinned then
            local pb = chipBtn(extras.isPinned() and "Desafixar" or "Fixar na tela", 2)
            safeConnect(pb.MouseButton1Click, function()
                local v = not extras.isPinned()
                extras.setPinned(v)
                pb.Text = v and "Desafixar" or "Fixar na tela"
                keep()
            end)
        end
        if extras.isFavorite then
            local fb = chipBtn(Library.Tr(extras.isFavorite() and "Remover favorito" or "Favoritar"), 3)
            safeConnect(fb.MouseButton1Click, function()
                if not extras.toggleFavorite() then Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Limite de favoritos atingido.") }) end
                fb.Text = Library.Tr(extras.isFavorite() and "Remover favorito" or "Favoritar")
                keep()
            end)
        end
    end
    self._tipFrame = f
    safeConnect(f.MouseEnter, function() self._tipHover = true end)
    safeConnect(f.MouseLeave, function() self._tipHover = false; self:_hideTip(0.3) end)
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
    q = Library.UISupport.normalize(q or "")
    self._filterQuery = q
    local matched, counts = {}, {}
    -- Restaura a abertura anterior dos submenus antes de calcular o novo filtro.
    for panel, wasVisible in pairs(self._searchPanelState or {}) do
        if panel.Parent then panel.Visible = wasVisible end
    end
    self._searchPanelState = {}
    for _, d in ipairs(self._search or {}) do
        if d.Parent then
            local n = d:GetAttribute("SearchName") or ""
            local translated = Library.Tr and Library.Tr(n) or n
            local hit = q == "" or string.find(Library.UISupport.normalize(n), q, 1, true) ~= nil or string.find(Library.UISupport.normalize(translated), q, 1, true) ~= nil
            local blocked = self._hideUnavailable and d:GetAttribute("Unavailable")
            local parent = d.Parent
            while not blocked and parent and type(parent) ~= "boolean" do
                if self._hideUnavailable and parent:GetAttribute("Unavailable") then blocked = true end
                parent = parent.Parent
            end
            d.Visible = not blocked and hit
            if q ~= "" and d.Visible then
                matched[#matched + 1] = d
                local tab = d:GetAttribute("SearchTab") or ""
                counts[tab] = (counts[tab] or 0) + 1
            end
        end
    end
    for _, d in ipairs(matched) do
        local parent = d.Parent
        while parent and type(parent) ~= "boolean" do
            if parent:GetAttribute("SearchName") ~= nil then parent.Visible = true end
            if parent:GetAttribute("SearchPanel") then
                if self._searchPanelState[parent] == nil then self._searchPanelState[parent] = parent.Visible end
                parent.Visible = true
            end
            parent = parent.Parent
        end
    end
    self._searchMatches = matched
    if self._renderSearchResults then self:_renderSearchResults() end
    for _, show in ipairs(self._groups or {}) do show() end
    for _, tab in ipairs(self.Tabs or {}) do
        if tab.TabBtn then
            local count = counts[tab.Name] or 0
            tab.TabBtn:SetAttribute("SearchMatches", count)
            if tab._searchCount then tab._searchCount.Text = count > 0 and tostring(count) or "" end
        end
    end
end
function Window:_openSearchResult(target)
    if not target or not target.Parent then return end
    local node = target.Parent
    while node do
        local openGroup = self._groupOpeners and self._groupOpeners[node]
        local openPanel = self._panelOpeners and self._panelOpeners[node]
        if openGroup then openGroup() end
        if openPanel then openPanel() end
        node = node.Parent
    end
    local tabName = target:GetAttribute("SearchTab")
    for _, tab in ipairs(self.Tabs) do if tab.Name == tabName then self:_select(tab); break end end
    local parent, modal = target.Parent, nil
    while parent do
        local key = parent:GetAttribute("SearchModal")
        if key then modal = self._modals and self._modals[key]; break end
        parent = parent.Parent
    end
    if modal then modal.Overlay.Visible = true end
    if self._searchPopup then self._searchPopup.Visible = false end
    if Library.RecentNavigation and target:GetAttribute("SearchKind") == "Toggle" then
        Library.RecentNavigation:add(target:GetAttribute("SearchKey"))
    end
    task.defer(function()
        task.wait() -- aguarda o layout dos grupos que a busca abriu
        if self._destroyed or not target.Parent then return end
        local scrolls, node = {}, target.Parent
        while node do
            if node:IsA("ScrollingFrame") then scrolls[#scrolls + 1] = node end
            node = node.Parent
        end
        for i = #scrolls, 1, -1 do
            local scroll = scrolls[i]
            local y = scroll.CanvasPosition.Y + target.AbsolutePosition.Y - scroll.AbsolutePosition.Y - 8
            local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y)
            scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.clamp(y, 0, maxY))
        end
    end)
end
function Window:OpenFavorite(key)
    if self._searchBox and self._searchBox.Text ~= "" then self._searchBox.Text = "" end
    for _, d in ipairs(self._search or {}) do
        if d.Parent and d:GetAttribute("SearchKey") == key and d:GetAttribute("SearchKind") == "Toggle" then
            if self._hideUnavailable then
                local current = d
                while current do
                    if current:GetAttribute("Unavailable") then
                        Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Opção oculta por indisponibilidade.") }); return false
                    end
                    current = current.Parent
                end
            end
            self:_openSearchResult(d); return true
        end
    end
    Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Favorito não encontrado nesta sessão.") })
    return false
end
function Window:SetHideUnavailable(value)
    self._hideUnavailable = value == true
    self:_filter(self._filterQuery)
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self._animToken = (self._animToken or 0) + 1
    local isHub = self == Library._hubWindow
    if isHub then
        if Library._stopEngine then pcall(Library._stopEngine) end
        Library:UnprotectAllGuis()
        Library._running = false
        for conn in pairs(Library._uiConnections) do pcall(function() conn:Disconnect() end) end
        table.clear(Library._uiConnections)
        if notifyGui then pcall(function() notifyGui:Destroy() end); notifyGui = nil end
        Library._hubWindow = nil
    end
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    self._groupOpeners, self._panelOpeners, self._groups = {}, {}, {}
    self._search, self._searchMatches, self._searchPanelState, self._touchRows = {}, {}, {}, {}
    self._refreshHomeFavorites = nil
    if self.Gui then pcall(function() self.Gui:Destroy() end) end
    for i, w in ipairs(Library.Windows) do if w == self then table.remove(Library.Windows, i) break end end
    -- sem a janela, o registro de opções e os atalhos não servem para nada
    if isHub then
        for k in pairs(Library.Registry) do Library.Registry[k] = nil end
        table.clear(Library.Keybinds)
        table.clear(Library._toggleBinds)
        table.clear(Library._kbListeners)
        table.clear(Library._themeListeners)
        table.clear(Library._bindings)
        if Library.Appearance then table.clear(Library.Appearance.colorListeners) end
        if Library.Favorites then table.clear(Library.Favorites.listeners) end
        if Library.RecentNavigation then table.clear(Library.RecentNavigation.listeners); table.clear(Library.RecentNavigation.items) end
        table.clear(Library._panicListeners)
        Library._panicZone = nil
    end
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
    safeConnect(island.MouseEnter, function()
        if UserInputService.TouchEnabled and not (UserInputService.MouseEnabled or UserInputService.KeyboardEnabled) then return end
        setExpanded(true)
    end)
    safeConnect(island.MouseLeave, function() setExpanded(false) end)
    safeConnect(island.InputBegan, function(i)
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
    safeConnect(island.MouseButton1Click, function()
        if longPressed then longPressed = false return end
        self:SetVisible(true)
    end)
    task.spawn(function()
        while gui.Parent do
            task.wait(0.5)
            if gui.Parent and island.Visible then safeCall(update) end
        end
    end)
    self._island = island
    self:_updateIsland()
end

-- ---------- Janela ----------
-- ---------- Logo: cubo 3D girando (ViewportFrame) ----------
local CUBE_GLYPH = {
    B = { "1111.", "1...1", "1...1", "1111.", "1...1", "1...1", "1111." },
    C = { ".111.", "1...1", "1....", "1....", "1....", "1...1", ".111." },
}
local CUBE_FACES = {   -- direção da face, "para cima" da face, letra
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
        for _, b in ipairs({ -1, 1 }) do   -- as 12 arestas brilhando na cor do tema
            part(Vector3.new(2.1, E, E), CFrame.new(0, a, b), Library.Theme.Accent, Enum.Material.Neon, true)
            part(Vector3.new(E, 2.1, E), CFrame.new(a, 0, b), Library.Theme.Accent, Enum.Material.Neon, true)
            part(Vector3.new(E, E, 2.1), CFrame.new(a, b, 0), Library.Theme.Accent, Enum.Material.Neon, true)
        end
    end
    local cell = 0.25
    for _, face in ipairs(CUBE_FACES) do   -- letras B / C feitas de pequenos blocos em cada face
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
    conn = safeConnect(RunService.RenderStepped, function(dt)
        if not vp.Parent then conn:Disconnect() return end
        if active and not active() then return end
        if Library.ReduceMotion then return end
        t += dt
        model:PivotTo(CFrame.Angles(math.rad(-22), 0, math.rad(8)) * CFrame.Angles(0, t * 0.9, 0))
    end)
    return vp
end

-- ---------- Intro: cartão de carregamento que vira a janela ----------
-- Aparece assim que o loadstring roda: logo, passos com check, barra de progresso
-- e no final o cartão "se abre" e vira o menu. Window:FinishLoading() avisa que
-- o script terminou de montar as abas (sem isso ele espera no máx. 12s).
function Window:FinishLoading()
    task.spawn(function()
        local waitStart = os.clock()
        while not self._destroyed and (self._pendingPrebuild or 0) > 0 and os.clock() - waitStart < 8 do task.wait(0.05) end
        if self._destroyed then return end
        if self._prebuildFailed or (self._pendingPrebuild or 0) > 0 then
            self._autoSaveBlocked = true
            if Library.Diagnostics then Library.Diagnostics:record("inicialização", "painel incompleto; autoload e autosave suspensos") end
            Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Painel incompleto; carregamento automático suspenso."), Duration = 8 })
            return
        end
        self._loaded = true
        local t0 = os.clock()
        while self._introActive and os.clock() - t0 < 20 do task.wait(0.1) end
        self:CaptureDefaults()
        local auto = self:GetAutoload()
        if auto and not self:LoadConfig(auto, true) then
            Library:Notify({ Title = "BBC HUB", Content = "Não foi possível carregar a configuração inicial; arquivo preservado." })
            -- Não permitir que o autosave substitua um arquivo que falhou ao carregar.
            self._autoSaveBlocked = true
        elseif not auto and canFS() then
            local ok, exists = pcall(isfile, CFG_FOLDER .. "/default.json")
            if not ok or exists then
                self._autoSaveBlocked = true
                Library:Notify({ Title = "BBC HUB", Content = "Configuração existente preservada; carregue ou salve uma configuração para ativar o salvamento automático." })
            end
        end
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

    -- logo (respira enquanto carrega) + título + status + porcentagem
    local logoHolder = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(PAD + 15, PAD + 15), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1 }, content)
    local logoScale = create("UIScale", { Scale = 1 }, logoHolder)
    icon(logoHolder, "box", 30, "Accent", { Size = UDim2.fromScale(1, 1) })
    if not Library.ReduceMotion then TweenService:Create(logoScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.14 }):Play() end
    local TEXT_X = PAD + 42
    label(content, opts.Title or "BBC HUB", 15, "Text", true, { Position = UDim2.fromOffset(TEXT_X, PAD - 2), Size = UDim2.new(1, -(TEXT_X + 70), 0, 18) })
    local statusLabel = label(content, "Iniciando", 12, "Muted", false, { Position = UDim2.fromOffset(TEXT_X, PAD + 17), Size = UDim2.new(1, -(TEXT_X + 70), 0, 15) })
    local percentLabel = label(content, "0%", 13, "Muted", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -PAD, 0, PAD + 6),
        Size = UDim2.fromOffset(56, 16), TextXAlignment = Enum.TextXAlignment.Right })
    local hair = create("Frame", { Position = UDim2.fromOffset(PAD, listTop - 14), Size = UDim2.new(1, -PAD * 2, 0, 1), BorderSizePixel = 0 }, content)
    bind(hair, "BackgroundColor3", "Stroke")

    -- cada passo: ponto apagado (espera) -> arco girando (rodando) -> ✓ (feito)
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
        task.delay(0.15 + index * 0.06, function()   -- os passos entram um atrás do outro
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

    -- barra fina de progresso na borda de baixo
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
    stepConn = safeConnect(RunService.RenderStepped, function(dt)
        if not loader.Parent then stepConn:Disconnect() return end
        percentLabel.Text = math.floor(fill.Size.X.Scale * 100 + 0.5) .. "%"
        for _, row in ipairs(rows) do
            if row.State == "active" then row.Spinner.Rotation = (row.Spinner.Rotation + dt * 360) % 360 end
        end
    end)

    -- entrada do cartão
    tween(loader, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.45, Enum.EasingStyle.Quint)
    tween(loaderScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Quint)

    local function cleanup()
        if not self._introActive or self._destroyed then return end
        pcall(function() stepConn:Disconnect() end)
        if loader.Parent then loader:Destroy() end
        main.Visible = true
        self._introActive = false
        self._introProgress = nil
        self._wantOpen = true
        if self._toggleBtn then self._toggleBtn.Visible = true end
        self:_updateIsland()
    end

    local skip = create("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -5), Size = UDim2.fromOffset(76, 24), BackgroundTransparency = 1, Text = Library.Tr("Pular intro"), TextSize = 12, FontFace = Library.Fonts.Bold, AutoButtonColor = false, ZIndex = 63 }, content)
    bind(skip, "TextColor3", "Text")
    safeConnect(skip.MouseButton1Click, cleanup)

    -- final: o cartão cresce até o tamanho do menu, o menu aparece e o cartão some
    local function finish()
        if not self._introActive or self._destroyed then return end
        for i, r in ipairs(rows) do if r.State ~= "warn" then setStep(i, "done") end end
        progress(1, 0.25)
        statusLabel.Text = Library.Tr("Menu montado")
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
            setStep(1, "active"); progress(0, 0)
            task.wait(Library.ReduceMotion and 0 or 0.15)
            if not self._introActive then return end
            setStep(1, "done")
            setStep(2, "active"); progress(1 / 3, 0.3)
            -- Os símbolos locais estão prontos; não há download remoto de ícones.
            rows[2].Label.Text = Library.Tr("Símbolos locais prontos")
            setStep(2, "done")
            setStep(3, "active"); progress(2 / 3, 0.3)
            local t2 = os.clock()
            while self._introActive and not self._loaded and os.clock() - t2 < 12 do task.wait(0.05) end
            if not self._introActive then return end
            if not self._loaded then
                rows[3].Label.Text = Library.Tr("Montagem ainda em andamento")
                setStep(3, "warn")
                statusLabel.Text = Library.Tr("Montagem ainda em andamento")
                task.wait(1)
                cleanup()
                Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Montagem ainda em andamento"), Duration = 5 })
                return
            end
            task.wait(Library.ReduceMotion and 0 or 0.2)
            finish()
        end)
        if not ok then
            warn("[BBC] intro: " .. tostring(err))
            cleanup()   -- se algo falhar, abre o menu direto
        end
    end)
end

function Window:SetScaleFactor(factor)
    if type(factor) ~= "number" or factor ~= factor or factor == math.huge or factor == -math.huge then return false end
    self._scaleFactor = math.clamp(factor, 0.7, 1.3)
    if self._fit then self._fit() end
    return true
end

function Library:Window(opts)
    opts = opts or {}
    if opts.Theme and Library.ThemePresets[opts.Theme] and not Library.Appearance then Library:SetTheme(opts.Theme) end
    local self = setmetatable({ Tabs = {}, _conns = {}, _hideName = false, _hideAvatar = false, _btnDraggable = true }, Window)
    local W = (opts.Size and opts.Size.X.Offset > 0) and opts.Size.X.Offset or 640
    local H = (opts.Size and opts.Size.Y.Offset > 0) and opts.Size.Y.Offset or 360
    local intro = opts.Intro ~= false and not (Library.Appearance and Library.Appearance.skipIntro)
    local gui = Library:CreateRootGui("ScreenGui", { Name = "BBCHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
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
        scale.Scale = Library.fitScale(vp.X, vp.Y, W, H, self._scaleFactor or 1)
        self._fitScale = scale.Scale
        local halfX, halfY = W * scale.Scale / 2, H * scale.Scale / 2
        local x = main.Position.X.Scale * vp.X + main.Position.X.Offset
        local y = main.Position.Y.Scale * vp.Y + main.Position.Y.Offset
        main.Position = UDim2.fromOffset(math.clamp(x, halfX, math.max(halfX, vp.X - halfX)), math.clamp(y, halfY, math.max(halfY, vp.Y - halfY)))
        if self._toggleBtn then
            local b = self._toggleBtn
            local bx = b.Position.X.Scale * vp.X + b.Position.X.Offset
            local by = b.Position.Y.Scale * vp.Y + b.Position.Y.Offset
            b.Position = UDim2.fromOffset(math.clamp(bx, 0, math.max(0, vp.X - 46)), math.clamp(by, 0, math.max(0, vp.Y - 46)))
        end
        for _, tab in ipairs(self.Tabs) do tab:_layoutColumns() end
        local compact = Library.UISupport.compact(vp.X, vp.Y, UserInputService.TouchEnabled)
        for i = #(self._touchRows or {}), 1, -1 do
            local entry = self._touchRows[i]
            if entry.row.Parent then entry.row.Size = UDim2.new(1, 0, 0, compact and math.max(40, entry.baseline) or entry.baseline)
            else table.remove(self._touchRows, i) end
        end
        for _, pin in pairs(self._pins or {}) do
            local b = pin.btn
            local px = (b.Position.X.Scale * vp.X + b.Position.X.Offset) / vp.X
            local py = (b.Position.Y.Scale * vp.Y + b.Position.Y.Offset) / vp.Y
            local hx, hy = math.min(0.5, 23 / vp.X), math.min(0.5, 23 / vp.Y)
            b.Position = UDim2.fromScale(math.clamp(px, hx, 1 - hx), math.clamp(py, hy, 1 - hy))
        end
    end
    self._fit = fit
    fit()
    self:_connect(gui:GetPropertyChangedSignal("AbsoluteSize"), fit)
    -- intro de carregamento (aparece na hora em que o loadstring executa)
    if intro then self:_startIntro(opts, W, H) end
    -- espera os ícones carregarem (até 25s) para a janela já nascer completa
    local t0 = os.clock()
    while not lucide and not iconsGaveUp and os.clock() - t0 < 25 do task.wait(0.1) end
    if not lucide then
        iconsGaveUp = true -- símbolos de texto por enquanto; se o download terminar depois, os ícones reais entram sozinhos
        for _, rec in ipairs(allIcons) do showGlyph(rec) end
    end
    self._key = parseKey(opts.Keybind or "RightShift")
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if processed or Library._listening or os.clock() - (Library._lastBind or 0) < 0.25 then return end
        local t = input.UserInputType
        local code = t == Enum.UserInputType.Keyboard and input.KeyCode or t
        if self._key and code == self._key then self:Toggle() end
        for _, b in ipairs(Library._toggleBinds) do
            local k = b.key()
            if k and code == k then task.spawn(function() safeCall(b.fire) end) end
        end
    end)

    -- cabeçalho
    local header = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, main)
    do
        local okc, vp = pcall(buildCubeLogo, header, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(44, 44) }, function() return main.Visible end)
        self._logo = (okc and vp) or icon(header, "box", 30, "Accent", { Position = UDim2.fromOffset(12, 11) })
    end
    label(header, "BBC", 17, "Accent", true, { Position = UDim2.fromOffset(50, 6), Size = UDim2.fromOffset(70, 20) })
    label(header, "HUB", 17, "Text", true, { Position = UDim2.fromOffset(50, 25), Size = UDim2.fromOffset(70, 20) })
    local dragging, dragStart, startPos = false, nil, nil
    safeConnect(header.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            local vp = gui.AbsoluteSize
            local half = main.AbsoluteSize / 2
            local x = startPos.X.Scale * vp.X + startPos.X.Offset + d.X
            local y = startPos.Y.Scale * vp.Y + startPos.Y.Offset + d.Y
            main.Position = UDim2.fromOffset(math.clamp(x, half.X, math.max(half.X, vp.X - half.X)), math.clamp(y, half.Y, math.max(half.Y, vp.Y - half.Y)))
        end
    end)
    self:_connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)

    -- busca
    local searchBox = create("TextBox", { Position = UDim2.fromOffset(130, 11), Size = UDim2.new(1, -330, 0, 30), Text = "", PlaceholderText = Library.Tr("Buscar por nome"), TextSize = 14,
        FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, Visible = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, header)
    bind(searchBox, "BackgroundColor3", "Surface2"); bind(searchBox, "TextColor3", "Text"); bind(searchBox, "PlaceholderColor3", "Muted")
    corner(searchBox, 3); stroke(searchBox, "Accent", 0.2); pad(searchBox, 10, 8, 0, 0)
    self._searchBox = searchBox
    self._refreshSearchLanguage = function() searchBox.PlaceholderText = Library.Tr("Buscar por nome") end
    safeConnect(searchBox:GetPropertyChangedSignal("Text"), function() self:_filter(searchBox.Text) end)
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
    safeConnect(searchBtn.MouseButton1Click, function()
        local on = not searchBox.Visible
        searchBox.Visible = on
        if on then searchBox:CaptureFocus() else searchBox.Text = ""; if self._searchPopup then self._searchPopup.Visible = false end end
    end)
    -- Atalho convencional, apenas com menu visível e sem outro campo em foco.
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard or Library._listening or self._introActive or Library.Panic or not main.Visible then return end
        local focus = UserInputService:GetFocusedTextBox()
        if input.KeyCode == Enum.KeyCode.Escape and focus == searchBox then
            searchBox:ReleaseFocus(); searchBox.Visible = false; searchBox.Text = ""
            if self._searchPopup then self._searchPopup.Visible = false end
        elseif not processed and not focus and input.KeyCode == Enum.KeyCode.F and
            (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            searchBox.Visible = true; searchBox:CaptureFocus()
        end
    end)
    safeConnect(flameBtn.MouseButton1Click, function() self:_select(self.HomeTab) end)
    safeConnect(gearBtn.MouseButton1Click, function()
        for _, t in ipairs(self.Tabs) do if t.IsSettings then self:_select(t) break end end
    end)

    -- barra lateral
    local side = create("Frame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(0, 152, 1, -52), BackgroundTransparency = 1 }, main)
    self._tabList = create("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -54), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
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
        if ok and Library._running and self.Gui and self.Gui.Parent then
            self._thumb = img
            safeCall(function() self:_renderIdentity() end)
        end
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
    task.spawn(function() while gui.Parent do task.wait(20); if gui.Parent then safeCall(function() pSub.Text = subText() end) end end end)
    safeConnect(card.MouseButton1Click, function() self:_select(self.HomeTab) end)

    -- conteúdo
    self._content = create("Frame", { Position = UDim2.fromOffset(160, 54), Size = UDim2.new(1, -168, 1, -62), BackgroundTransparency = 1, ClipsDescendants = true }, main)

    -- Lista de resultados: os botões são reutilizados, sem criar conexões a cada tecla.
    do
        local popup = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 30 }, self._content)
        bind(popup, "BackgroundColor3", "Surface"); corner(popup, 4); stroke(popup, "Accent", 0.2)
        local summary = label(popup, "", 12, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), ZIndex = 31 })
        local results = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 31 }, popup)
        bind(results, "ScrollBarImageColor3", "Accent"); pad(results, 6, 8, 0, 6); listLayout(results, 3)
        local slots = {}
        for i = 1, 40 do
            local b = create("TextButton", { Size = UDim2.new(1, 0, 0, 36), BorderSizePixel = 0, Text = "", TextSize = 12,
                FontFace = Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                AutoButtonColor = false, LayoutOrder = i, Visible = false, ZIndex = 32 }, results)
            bind(b, "BackgroundColor3", "Surface2"); bind(b, "TextColor3", "Text"); corner(b, 4); pad(b, 8, 8, 0, 0)
            local slot = { button = b }
            slots[i] = slot
            safeConnect(b.MouseButton1Click, function() self:_openSearchResult(slot.target) end)
        end
        self._searchPopup = popup
        function self:_renderSearchResults()
            local query, hits = self._filterQuery or "", self._searchMatches or {}
            popup.Visible = searchBox.Visible and query ~= ""
            if not popup.Visible then return end
            summary.Text = #hits == 0 and Library.Tr("Nenhum resultado") or (Library.Tr("Resultados") .. ": " .. #hits .. (#hits > #slots and " · 40" or ""))
            results.CanvasPosition = Vector2.new(0, 0)
            for i, slot in ipairs(slots) do
                local d = hits[i]
                slot.target, slot.button.Visible = d, d ~= nil
                if d then
                    local path, pieces = d:GetAttribute("SearchPath") or "", {}
                    for part in string.gmatch(path, "[^/]+") do pieces[#pieces + 1] = Library.Tr(part) end
                    slot.button.Text = table.concat(pieces, " › ") .. " · " .. Library.Tr(d:GetAttribute("SearchName") or "")
                end
            end
        end
        safeConnect(searchBox.FocusLost, function(enter)
            if enter and popup.Visible and slots[1].target then self:_openSearchResult(slots[1].target) end
        end)
    end

    -- página inicial (perfil), escondida da barra lateral
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

-- Utilitários necessários ao código do hub fora desta biblioteca.
Library.Internal = { create = create, bind = bind, corner = corner, stroke = stroke, tips = TIPS, setTipResolver = function(fn) tipFor = fn end }
return Library
end)()
