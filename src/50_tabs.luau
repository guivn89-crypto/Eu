-- ============ 50_tabs.luau :: Abas, painel do ESP, radar, busca de saque ============
-- ---------------- VISUAIS ----------------

-- ============================================================
--  Painel do ESP (Jogador / NPCs / Corpo): pré-visualização + lista de ajustes
--  A pré-visualização é um desenho; as opções ficam salvas no menu.
-- ============================================================
local function buildEspPanel(kind)
    return function(m)
        local B = Library.Bind
        local TweenService = game:GetService("TweenService")
        local CVW, CVH, CX, CY = 212, 205, 106, 100
        local corpse = kind == "Corpo"
        local isProp = kind == "Recipiente" or kind == "Item no chão" or kind == "Itens de missão"
        local ORANGE = Color3.fromRGB(255, 120, 30)
        local DARK = Color3.fromRGB(22, 18, 18)
        local GREEN = Color3.fromRGB(70, 220, 90)
        local S = {
            highlight = { on = true, color = ORANGE, alpha = 0.8, outline = 1.5, outlineColor = DARK },
            box = { on = true, color = ORANGE, thick = 1, style = "Completa", corner = 14 },
            name = { on = true, color = Color3.new(1, 1, 1) },
            healthbar = { on = not corpse and not isProp, auto = false, color = GREEN, width = 4, side = "Esquerda" },
            health = { on = false, color = GREEN },
            distance = { on = true, color = Color3.fromRGB(235, 235, 235), unit = "m" },
            tracers = { on = false, color = Color3.fromRGB(255, 255, 255), thick = 1, origin = "Baixo" },
            skeleton = { on = false, color = Color3.fromRGB(255, 255, 255), thick = 1.5 },
            frozen = false, locked = false,
            lod = { on = true, near = 150 }, nearest = { on = false, color = Color3.fromRGB(255, 60, 60) },
            maxDist = 1000, textSize = 11, prevDist = 120, prevHp = (corpse or isProp) and 0 or 100,
        }
        Library.ESP = Library.ESP or {}
        Library.ESP[kind] = S   -- o motor do ESP lê daqui
        local function new(class, props, parent)
            local i = Instance.new(class)
            for k, v in pairs(props or {}) do i[k] = v end
            i.Parent = parent
            return i
        end
        local function T(parent, props)
            props.BackgroundTransparency = 1
            props.FontFace = props.FontFace or Library.Fonts.Bold
            return new("TextLabel", props, parent)
        end
        local L = m.Left
        -- ---------- tela da pré-visualização ----------
        local cv = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(CVW, CVH), BorderSizePixel = 0, ClipsDescendants = true }, L)
        B(cv, "BackgroundColor3", "Background")
        new("UICorner", { CornerRadius = UDim.new(0, 5) }, cv)
        do local st = new("UIStroke", { Transparency = 0.45 }, cv); B(st, "Color", "Stroke") end
        for i = 1, 8 do   -- grade de fundo (efeito de scanner)
            local v = new("Frame", { Position = UDim2.fromOffset(i * 23.5, 0), Size = UDim2.fromOffset(1, CVH), BorderSizePixel = 0, BackgroundTransparency = 0.94 }, cv)
            B(v, "BackgroundColor3", "Text")
        end
        for i = 1, 6 do
            local h = new("Frame", { Position = UDim2.fromOffset(0, i * 29), Size = UDim2.fromOffset(CVW, 1), BorderSizePixel = 0, BackgroundTransparency = 0.94 }, cv)
            B(h, "BackgroundColor3", "Text")
        end
        -- pedestal (plataforma com borda de luz) embaixo do boneco
        local shadow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0 }, cv)
        local pedBase = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(1, 0.8),
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, BorderSizePixel = 0 }, shadow)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, pedBase)
        local pedTop = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1, 0.8), BorderSizePixel = 0 }, shadow)
        B(pedTop, "BackgroundColor3", "Surface2")
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, pedTop)
        local pedStroke = new("UIStroke", { Thickness = 1.5, Transparency = 0.1 }, pedTop); B(pedStroke, "Color", "Accent")
        local pedInner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.6), BackgroundTransparency = 1 }, pedTop)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, pedInner)
        local pedInnerStroke = new("UIStroke", { Thickness = 1, Transparency = 0.5 }, pedInner); B(pedInnerStroke, "Color", "Accent")

        -- boneco em silhueta: blocos separados (cabeça, tronco, braços, pernas e
        -- pés), como um avatar blocudo. O "Corpo" usa a pose caída (deitado).
        local POSE = isProp and {
            w = 96, h = 76,
            parts = {
                { 8, 16, 80, 46, 4 },    -- corpo do recipiente
                { 8, 8, 80, 8, 3 },      -- tampa
                { 42, 16, 12, 12, 2 },   -- fecho
            },
            sk = {},
            skHead = nil,
        } or corpse and {
            w = 150, h = 72,
            parts = {
                { 4, 24, 26, 26, 13 },                          -- cabeça
                { 34, 16, 52, 40, 5 },                          -- tronco
                { 34, 2, 52, 12, 4 }, { 34, 54, 52, 12, 4 },    -- braços
                { 90, 16, 32, 18, 4 }, { 90, 40, 32, 18, 4 },   -- pernas
                { 126, 16, 20, 18, 4 }, { 126, 40, 20, 18, 4 }, -- pés
            },
            sk = {
                { 0.25, 0.50, 0.56, 0.50 }, { 0.25, 0.12, 0.25, 0.88 }, { 0.25, 0.12, 0.60, 0.12 }, { 0.25, 0.88, 0.60, 0.88 },
                { 0.56, 0.30, 0.56, 0.70 }, { 0.56, 0.30, 0.92, 0.30 }, { 0.56, 0.70, 0.92, 0.70 },
            },
            skHead = { 0.09, 0.5 },
        } or {
            w = 96, h = 132,
            parts = {
                { 33, 2, 30, 26, 9 },                              -- cabeça
                { 26, 32, 44, 42, 5 },                             -- tronco
                { 12, 32, 12, 22, 4 }, { 12, 54, 12, 20, 4 }, { 12, 74, 12, 10, 3 },   -- braço esquerdo
                { 72, 32, 12, 22, 4 }, { 72, 54, 12, 20, 4 }, { 72, 74, 12, 10, 3 },   -- braço direito
                { 27, 76, 19, 40, 4 }, { 27, 116, 19, 12, 4 },     -- perna esquerda
                { 50, 76, 19, 40, 4 }, { 50, 116, 19, 12, 4 },     -- perna direita
            },
            sk = {
                { 0.5, 0.27, 0.5, 0.62 }, { 0.22, 0.30, 0.78, 0.30 }, { 0.22, 0.30, 0.12, 0.46 }, { 0.12, 0.46, 0.12, 0.60 },
                { 0.78, 0.30, 0.88, 0.46 }, { 0.88, 0.46, 0.88, 0.60 }, { 0.38, 0.62, 0.62, 0.62 }, { 0.38, 0.62, 0.36, 0.80 },
                { 0.36, 0.80, 0.36, 0.97 }, { 0.62, 0.62, 0.64, 0.80 }, { 0.64, 0.80, 0.64, 0.97 },
            },
            skHead = { 0.5, 0.15 },
        }
        local fg = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(POSE.w, POSE.h), BackgroundTransparency = 1 }, cv)
        local fgScale = new("UIScale", { Scale = 1 }, fg)
        local parts = {}   -- { f = frame, st = stroke } (silhueta preenchida = chams)
        local function part(x, y, w, h, radius)
            local p = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, BorderSizePixel = 0 }, fg)
            new("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, p)
            local st = new("UIStroke", { Thickness = 1, Transparency = 0.3 }, p)
            parts[#parts + 1] = { f = p, st = st }
            return p
        end
        local torso
        for i, p in ipairs(POSE.parts) do
            local f = part(p[1], p[2], p[3], p[4], p[5])
            if i == (isProp and 1 or 2) then torso = f end
        end
        local torsoText = torso and T(torso, { Size = UDim2.fromScale(1, 1), Text = "BBC HUB", TextSize = POSE.w < 120 and 9 or 13, TextColor3 = Color3.new(1, 1, 1), TextWrapped = false }) or nil

        -- esqueleto (linhas ligando as articulações) por cima do boneco
        local skLines = {}
        for i = 1, #POSE.sk do skLines[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, cv) end
        local skHead = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, cv)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, skHead)
        local skHeadStroke = new("UIStroke", { Thickness = 1.5 }, skHead)

        -- caixa (cantos ou completa)
        local brackets = {}
        for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
            for _, horiz in ipairs({ true, false }) do
                brackets[#brackets + 1] = { f = new("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), BorderSizePixel = 0 }, cv), cx = c[1], cy = c[2], horiz = horiz }
            end
        end
        local boxFull = new("Frame", { BackgroundTransparency = 1 }, cv)
        local boxFullStroke = new("UIStroke", { Thickness = 2 }, boxFull)
        local nameL = T(cv, { Size = UDim2.fromOffset(120, 14), Text = kind == "NPCs" and "NPC" or tr(kind) })
        local hbBg = new("Frame", { BackgroundColor3 = Color3.fromRGB(26, 26, 30), BorderSizePixel = 0 }, cv)
        new("UICorner", { CornerRadius = UDim.new(0, 2) }, hbBg)
        local hbFill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, hbBg)
        new("UICorner", { CornerRadius = UDim.new(0, 2) }, hbFill)
        local hpL = T(cv, { Size = UDim2.fromOffset(34, 12), Text = "100" })
        local distL = T(cv, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(90, 12), FontFace = Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Center })
        local tracer = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, cv)
        local farDot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, cv)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, farDot)
        local oorL = T(cv, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY + 4), Size = UDim2.fromOffset(150, 16), Text = tr("Fora do alcance"), TextSize = 12, Visible = false })
        B(oorL, "TextColor3", "Muted")

        -- botões rápidos (espelham a lista da direita; quebram de linha sozinhos)
        local chipDefs = { { "highlight", "Destaque" }, { "box", "Caixa" }, { "name", "Nome" }, { "healthbar", "Barra de vida" }, { "health", "Vida" }, { "distance", "Distância" } }
        table.insert(chipDefs, { "tracers", "Linhas até alvos" }); table.insert(chipDefs, { "skeleton", "Esqueleto" })
        local chipFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 213), Size = UDim2.fromOffset(CVW, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, L)
        new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, chipFrame)
        local chips, toggles = {}, {}
        for i, d in ipairs(chipDefs) do
            local b = new("TextButton", { Text = d[2], TextSize = 10, AutoButtonColor = false, FontFace = Library.Fonts.Bold, BorderSizePixel = 0, LayoutOrder = i,
                Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false }, chipFrame)
            new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, b)
            B(b, "BackgroundColor3", "Surface3"); B(b, "TextColor3", "Text")
            new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
            local st = new("UIStroke", { Thickness = 1 }, b)
            chips[d[1]] = { btn = b, stroke = st }
            Actions.connect(b.MouseButton1Click, function()
                if S.locked then return end
                if toggles[d[1]] then toggles[d[1]]:Set(not S[d[1]].on) end
            end)
        end

        local function hpColor()
            local hp = S.prevHp
            if not S.healthbar.auto then return S.healthbar.color end
            if hp > 60 then return Color3.fromRGB(70, 220, 90) elseif hp > 30 then return Color3.fromRGB(240, 200, 60) end
            return Color3.fromRGB(240, 80, 70)
        end
        local function at(frame, x, y) frame.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5)) end
        local function line(frame, x0, y0, x1, y1, thick)
            local dx, dy = x1 - x0, y1 - y0
            frame.Position = UDim2.fromOffset((x0 + x1) / 2, (y0 + y1) / 2)
            frame.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), thick)
            frame.Rotation = math.deg(math.atan2(dy, dx))
        end

        local function refresh()
            local d, maxd, ts = S.prevDist, S.maxDist, S.textSize
            local inRange = d <= maxd
            local far = S.lod.on and d > S.lod.near
            local details = inRange and not far
            local nearColor = S.nearest.on and S.nearest.color or nil -- a prévia simula um único alvo
            farDot.Visible = inRange and far and (S.box.on or S.highlight.on)
            farDot.BackgroundColor3 = nearColor or S.box.color
            -- o tamanho do boneco muda com a distância simulada
            local sc = math.clamp((80 / math.max(d, 20)) ^ 0.55, 0.28, 1.1)
            if Library.ReduceMotion then fgScale.Scale = sc else TweenService:Create(fgScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = sc }):Play() end
            local bw, bh = POSE.w * sc, POSE.h * sc
            local left, right, top, bottom = CX - bw / 2, CX + bw / 2, CY - bh / 2, CY + bh / 2
            shadow.Size = UDim2.fromOffset(bw * 1.45, math.max(12, 22 * sc)); at(shadow, CX, bottom + 3)
            -- chams: silhueta blocuda preenchida (laranja/vermelho) com contorno escuro fino
            local hl = S.highlight
            for _, p in ipairs(parts) do
                p.f.BackgroundColor3 = nearColor or hl.color
                p.f.BackgroundTransparency = hl.on and (1 - hl.alpha * (inRange and 1 or 0.35)) or 1
                p.st.Color = hl.outlineColor or Library.Theme.Muted
                p.st.Thickness = hl.on and math.max(hl.outline * 0.5, 0.5) or 1
                p.st.Transparency = hl.on and hl.outline > 0 and 0 or 1
            end
            if torsoText then
                torsoText.TextColor3 = hl.on and Color3.new(1, 1, 1) or Library.Theme.Text
                torsoText.TextTransparency = inRange and 0.1 or 0.7
            end
            -- esqueleto
            local sk = S.skeleton
            local showSk = sk.on and details
            for i, seg in ipairs(POSE.sk) do
                local ln = skLines[i]
                ln.Visible = showSk; ln.BackgroundColor3 = sk.color
                line(ln, left + seg[1] * bw, top + seg[2] * bh, left + seg[3] * bw, top + seg[4] * bh, sk.thick)
            end
            if POSE.skHead then
                skHead.Visible = showSk; skHeadStroke.Color = sk.color; skHeadStroke.Thickness = sk.thick
                local skr = math.min(bw, bh) * 0.3
                skHead.Size = UDim2.fromOffset(skr, skr)
                at(skHead, left + POSE.skHead[1] * bw, top + POSE.skHead[2] * bh)
            else
                skHead.Visible = false
            end
            -- caixa
            local th = S.box.thick
            local showBox = S.box.on and details
            local len = math.min(S.box.corner, bw / 2, bh / 2)
            for _, b in ipairs(brackets) do
                b.f.Visible = showBox and S.box.style == "Cantos"
                b.f.BackgroundColor3 = nearColor or S.box.color
                b.f.Size = b.horiz and UDim2.fromOffset(len, th) or UDim2.fromOffset(th, len)
                at(b.f, b.cx == 0 and left or right, b.cy == 0 and top or bottom)
            end
            boxFull.Visible = showBox and S.box.style == "Completa"
            boxFullStroke.Color = nearColor or S.box.color; boxFullStroke.Thickness = th
            boxFull.Size = UDim2.fromOffset(bw, bh); at(boxFull, left, top)
            -- nome
            nameL.Visible = S.name.on and details; nameL.TextColor3 = S.name.color; nameL.TextSize = ts; at(nameL, CX - 60, top - 18)
            -- barra de vida (lado, largura e cor automática pela vida)
            local W = S.healthbar.width
            local barX = S.healthbar.side == "Esquerda" and (left - 7 - W) or (right + 7)
            hbBg.Visible = S.healthbar.on and details
            hbBg.Size = UDim2.fromOffset(W, bh); at(hbBg, barX, top)
            hbFill.Size = UDim2.fromScale(1, math.clamp(S.prevHp / 100, 0, 1)); hbFill.BackgroundColor3 = hpColor()
            hpL.Visible = S.health.on and details; hpL.TextSize = ts
            hpL.Text = tostring(math.floor(S.prevHp)); hpL.TextColor3 = S.healthbar.auto and hpColor() or S.health.color
            if S.healthbar.side == "Esquerda" then
                hpL.AnchorPoint = Vector2.new(1, 0.5); hpL.TextXAlignment = Enum.TextXAlignment.Right; at(hpL, barX - 4, top + bh / 2)
            else
                hpL.AnchorPoint = Vector2.new(0, 0.5); hpL.TextXAlignment = Enum.TextXAlignment.Left; at(hpL, barX + W + 4, top + bh / 2)
            end
            -- distância
            distL.Visible = S.distance.on and inRange; distL.TextColor3 = S.distance.color; distL.TextSize = ts
            distL.Text = S.distance.unit == "m" and (d .. "m") or (math.floor(d / 0.28) .. " st"); at(distL, CX, far and (CY + 6) or (bottom + 3))
            -- linha (tracer) do ponto de origem até a caixa
            tracer.Visible = S.tracers.on and details; tracer.BackgroundColor3 = S.tracers.color
            if S.tracers.origin == "Baixo" then line(tracer, CX, CVH, CX, bottom + 16, S.tracers.thick) else line(tracer, CX, 0, CX, top - 20, S.tracers.thick) end
            oorL.Visible = not inRange
            for key, c in pairs(chips) do c.stroke.Color = S[key].on and Library.Theme.Accent or Library.Theme.Stroke end
        end

        -- ---------- lista da direita ----------
        local R = m.Right
        local fold = R:Foldout({ Name = "Configurações gerais", Build = function(p)
            p:Slider({ Name = "Distância máx.", Min = 100, Max = 3000, Default = 1000, Suffix = "m", Step = 50, Callback = function(v) S.maxDist = v; refresh() end })
            p:Slider({ Name = "Tamanho do texto", Min = 9, Max = 16, Default = 11, Callback = function(v) S.textSize = v; refresh() end })
            p:Slider({ Name = "Distância da prévia", Min = 10, Max = 2000, Default = 120, Suffix = "m", Step = 10, Callback = function(v) S.prevDist = v; refresh() end })
            p:Slider({ Name = "Vida da prévia", Min = 0, Max = 100, Default = 100, Callback = function(v) S.prevHp = v; refresh() end })
            p:Toggle({ Name = "Só detalhes de perto", Default = true, Tooltip = tipText("Longe, mostra só um ponto e a distância. Perto, mostra tudo."), Callback = function(v) S.lod.on = v; refresh() end })
            p:Slider({ Name = "Detalhes até", Min = 20, Max = 1000, Default = 150, Suffix = "m", Step = 10, Callback = function(v) S.lod.near = v; refresh() end })
            p:Toggle({ Name = "Destacar mais próximo", Default = false, Tooltip = tipText("O alvo mais perto de você ganha outra cor."),
                Callback = function(v) S.nearest.on = v; refresh() end,
                Settings = function(q) q:ColorPicker({ Name = "Cor", Default = S.nearest.color, Callback = function(c) S.nearest.color = c; refresh() end }) end })
        end })
        local function add(key, label, extra)
            toggles[key] = R:Toggle({ Name = label, Default = S[key].on, Callback = function(v) S[key].on = v; refresh() end,
                Settings = function(p)
                    p:ColorPicker({ Name = "Cor", Default = S[key].color, Callback = function(c) S[key].color = c; refresh() end })
                    if extra then extra(p) end
                end })
        end
        add("highlight", "Destaque", function(p)
            p:ColorPicker({ Name = "Cor do contorno", Default = S.highlight.outlineColor, Callback = function(c) S.highlight.outlineColor = c; refresh() end })
            p:Slider({ Name = "Preenchimento", Min = 5, Max = 90, Default = 80, Suffix = "%", Callback = function(v) S.highlight.alpha = v / 100; refresh() end })
            p:Toggle({ Name = "Contorno", Default = true, Callback = function(v) S.highlight.outline = v and 1.5 or 0; refresh() end })
        end)
        add("box", "Caixa", function(p)
            p:Dropdown({ Name = "Estilo", Options = { "Cantos", "Completa" }, Default = "Completa", Callback = function(v) S.box.style = v; refresh() end })
            p:Slider({ Name = "Espessura", Min = 1, Max = 5, Default = 1, Callback = function(v) S.box.thick = v; refresh() end })
            p:Slider({ Name = "Tamanho do canto", Min = 6, Max = 30, Default = 14, Callback = function(v) S.box.corner = v; refresh() end })
        end)
        add("name", "Nome")
        add("healthbar", "Barra de vida", function(p)
            p:Toggle({ Name = "Cor automática", Default = false, Callback = function(v) S.healthbar.auto = v; refresh() end })
            p:Dropdown({ Name = "Posição", Options = { "Esquerda", "Direita" }, Default = "Esquerda", Callback = function(v) S.healthbar.side = v; refresh() end })
            p:Slider({ Name = "Largura da barra", Min = 2, Max = 10, Default = 4, Callback = function(v) S.healthbar.width = v; refresh() end })
        end)
        add("health", "Vida")
        add("distance", "Distância", function(p)
            p:Dropdown({ Name = "Unidade", Options = { "m", "studs" }, Default = "m", Callback = function(v) S.distance.unit = v; refresh() end })
        end)
        add("tracers", "Linhas até alvos", function(p)
            p:Dropdown({ Name = "Origem", Options = { "Baixo", "Cima" }, Default = "Baixo", Callback = function(v) S.tracers.origin = v; refresh() end })
            p:Slider({ Name = "Espessura", Min = 1, Max = 4, Default = 1, Callback = function(v) S.tracers.thick = v; refresh() end })
        end)
        add("skeleton", "Esqueleto", function(p)
            p:Slider({ Name = "Espessura", Min = 1, Max = 4, Default = 1.5, Step = 0.5, Callback = function(v) S.skeleton.thick = v; refresh() end })
        end)
        local hint = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.new(1, -16, 0, 34),
            Text = tr("TOQUE: ALTERNAR · SEGURE: O QUE É") .. "\n" .. tr("TOQUE NO ÍCONE: AJUSTES"), TextSize = 10, FontFace = Library.Fonts.Regular, TextWrapped = true }, m.RightBox)
        B(hint, "TextColor3", "Muted")
        refresh()

        -- botões no título da prévia: ajustes gerais, travar e congelar a animação
        local RunService = game:GetService("RunService")
        local function headBtn(iconName, rightOffset)
            local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -rightOffset, 0, 2), Size = UDim2.fromOffset(26, 26),
                BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, m.LeftBox)
            local ic = Library.MakeIcon(b, iconName, 16, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
            return b, ic
        end
        local frozenBtn, frozenIcon = headBtn("snowflake", 6)
        local lockBtn, lockIcon = headBtn("lock", 34)
        local setBtn = headBtn("sliders-horizontal", 62)
        local function paintHead()
            frozenIcon.ImageColor3 = S.frozen and Library.Theme.Accent or Library.Theme.Text
            lockIcon.ImageColor3 = S.locked and Library.Theme.Accent or Library.Theme.Text
        end
        paintHead()
        Actions.connect(frozenBtn.MouseButton1Click, function() S.frozen = not S.frozen; paintHead() end)
        Actions.connect(lockBtn.MouseButton1Click, function() S.locked = not S.locked; paintHead() end)
        Actions.connect(setBtn.MouseButton1Click, function()
            fold.Set(not fold.IsOpen())
            m.RightScroll.CanvasPosition = Vector2.new(0, 0)
        end)

        -- animação leve: linha de varredura (scanner) e pedestal pulsando
        local scan = new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, -14), BorderSizePixel = 0, ZIndex = 2 }, cv)
        B(scan, "BackgroundColor3", "Accent")
        new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.85, 0.9), NumberSequenceKeypoint.new(1, 0.55) }) }, scan)
        local clock, conn = 0, nil
        conn = Actions.connect(RunService.Heartbeat, function(dt)
            if not cv.Parent then conn:Disconnect() return end
            if Library.ReduceMotion or S.frozen or not m.Overlay.Visible then return end
            clock += dt
            scan.Position = UDim2.fromOffset(0, math.floor((clock % 3.2) / 3.2 * (CVH + 14) - 14))
            pedStroke.Transparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(clock * 2.4))
        end)
    end
end
MODALS["Jogador"] = { build = buildEspPanel("Jogador"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO JOGADOR" } }
MODALS["NPCs"] = { build = buildEspPanel("NPCs"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO NPC" } }
MODALS["Corpo"] = { build = buildEspPanel("Corpo"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO CORPO" } }
MODALS["Recipiente"] = { build = buildEspPanel("Recipiente"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO RECIPIENTE" } }
MODALS["Item no chão"] = { build = buildEspPanel("Item no chão"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO ITEM" } }
MODALS["Itens de missão"] = { build = buildEspPanel("Itens de missão"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO ITEM DE MISSÃO" } }

local visuais = Window:Tab({ Name = "VISUAIS", Icon = "eye" })
local g = visuais:Groupbox({ Name = "ESP", Icon = "scan-eye", Side = "Left" })
for _, n in ipairs({ "Jogador", "NPCs", "Corpo", "Recipiente", "Item no chão", "Itens de missão" }) do
    T(g, n, n == "Jogador" or n == "NPCs" or n == "Corpo")
end
g = visuais:Groupbox({ Name = "INTERFACE DO JOGO", Icon = "layout-dashboard", Side = "Right" })
T(g, "Mochila personalizada"); T(g, "Mochila"); T(g, "Barra rápida")
g = visuais:Groupbox({ Name = "LOCAL", Icon = "map-pin", Side = "Right", Checkbox = true, Default = true, Callback = function(v) Actions.applyLocalFxAll(v) end })
for _, n in ipairs({ "Aura", "Círculo de salto", "Auréola", "Rastro estelar" }) do T(g, n) end
Actions.LOCALFX.ready = true

-- ---------------- JOGADOR ----------------
local jogador = Window:Tab({ Name = "JOGADOR", Icon = "user" })
g = jogador:Groupbox({ Name = "MOVIMENTO", Icon = "move", Side = "Left" })
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
S(g, "Campo de visão", 30, 120, 120, "", 1, function(v) Actions.CAM.fov = v; Actions.applyFov() end)
S(g, "Visão com zoom", 5, 120, 5, "", 1, function(v) Actions.CAM.zoom = v; Actions.applyFov() end)
g:Keybind({ Name = "Zoom", Default = "N", OnChanged = function(k) keys.zoom = k.Name; Actions.setZoomKey(k.Name); refreshPanels() end, Callback = function() end })
g = jogador:Groupbox({ Name = "ANIMAÇÕES", Icon = "activity", Side = "Right" })
g:Dropdown({ Name = "Animação", Options = { "Swish", "Padrão" }, Default = "Swish", Callback = function(v) Actions.CHAR.anim = v end })
T(g, "Repetir", false, nil)
S(g, "Velocidade", 0.1, 3, 1, "x", 0.1, function(v) Actions.CHAR.speed = v end)
S(g, "Peso", 0, 100, 100, "%", 1, function(v) Actions.CHAR.weight = v end)
g:Button({ Name = "Reproduzir", Callback = function() Actions.playAnim() end })
g = jogador:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Right" })
T(g, "Painel do jogador"); T(g, "Anti AFK"); T(g, "Renascer automático")
T(g, "Remover água"); T(g, "Não se afogar"); T(g, "Mapa e navegação", true)

-- ---------------- COMBATE ----------------
local combate = Window:Tab({ Name = "COMBATE", Icon = "crosshair" })
g = combate:Groupbox({ Name = "MIRA", Icon = "crosshair", Side = "Left", Checkbox = true, Default = false,
    CanSet = function(v)
        if Library.Safety:allow("MIRA", v) then return true end
        notify("Bloqueado pelo modo preventivo: MIRA")
        return false
    end,
    Callback = function(v) Actions.COMBAT.on = v; Actions.applyAimState() end })
Library.Safety:track("MIRA", g.Checkbox)
g:Dropdown({ Name = "Ativação", Options = { "Ao mirar", "Sempre" }, Default = "Ao mirar", Callback = function(v) Actions.COMBAT.activation = v end })
T(g, "Alvo fixo"); T(g, "Previsão")
S(g, "Suavização", 0, 300, 80, "ms", 1, function(v) Actions.COMBAT.smooth = v / 300; Actions.clampCfg() end)
T(g, "Pausa inteligente"); T(g, "Notificar", true)
g = combate:Groupbox({ Name = "ALVOS", Icon = "target", Side = "Left" })
S(g, "Raio da mira", 10, 500, 70, "", 1, function(v) Actions.COMBAT.radius = v; Actions.clampCfg() end)
T(g, "FOV dinâmico", true)
g:Dropdown({ Name = "Ponto de mira", Options = { "Partes selecionadas", "Mais próximo" }, Default = "Partes selecionadas", Callback = function(v) Actions.COMBAT.aimPoint = v end })
g:Dropdown({ Name = "Partes do corpo", Options = { "Cabeça", "Corpo", "Braços", "Pernas" }, Default = { "Cabeça" }, Multi = true, Callback = function(v)
    Actions.COMBAT.parts = {}
    for _, part in ipairs(type(v) == "table" and v or { v }) do Actions.COMBAT.parts[part] = true end
end })
T(g, "Alternativa visível", true); T(g, "Mirar em NPCs", true); T(g, "Ignorar obstáculos na mira", true)
g:Keybind({ Name = "Adicionar amigo", Default = "MB3", Callback = function()
    local t = Actions.AIM.target and Actions.AIM.target.t
    if t and t.plr then Actions.COMBAT.friends[t.plr] = true; Actions.say("Amigo: " .. t.plr.Name) else Actions.say("Sem alvo no momento.") end
end })
S(g, "Limite de verificações", 1, 20, 7, "", 1, function(v) Actions.COMBAT.maxChecks = v; Actions.clampCfg() end)
g = combate:Groupbox({ Name = "ESPIADA", Icon = "eye", Side = "Left" })
T(g, "Espiada subterrânea")
g = combate:Groupbox({ Name = "CORPO A CORPO", Icon = "swords", Side = "Left" })
T(g, "Aura letal")
g = combate:Groupbox({ Name = "ARMA", Icon = "target", Side = "Right" })
T(g, "Recarga automática"); T(g, "Abastecer cargadores")
g:Button({ Name = "Manuseio da arma", Arrow = true, Callback = function()
    local m = Window:_getModal("combate/manuseio", { Left = "MANUSEIO DA ARMA", Right = "AJUSTES" }, function(mm)
        mm.Right:Slider({ Name = "Recuo", Min = 0, Max = 100, Default = 20, Suffix = "%", Callback = function(v) Actions.WEAPON.recoil = v / 100 end })
        mm.Right:Label({ Text = "Recuo ajusta a mira, não as configurações da arma." })
    end)
    m.Overlay.Visible = true
end })
T(g, "Mira falsa")
g = combate:Groupbox({ Name = "EFEITOS DE COMBATE", Icon = "sparkles", Side = "Right" })
T(g, "Retícula"); T(g, "Círculo da mira", true); T(g, "Rastro personalizado")
T(g, "Rastros do jogo"); T(g, "Marca de acerto", true); T(g, "Números de dano", true)
T(g, "Efeitos de acerto", true); T(g, "Efeitos de eliminação"); T(g, "Dados do alvo", true)
T(g, "Só acertos confirmados", true)
g = combate:Groupbox({ Name = "ANTI AIM", Icon = "shield", Side = "Right" })
T(g, "Anti aim"); T(g, "Sob o chão"); T(g, "Fantasma")
g = combate:Groupbox({ Name = "GRANADAS", Icon = "bomb", Side = "Right" })
T(g, "Trajetória do arremesso"); T(g, "Sem tremor", true)

-- ---------------- MUNDO ----------------
local mundo = Window:Tab({ Name = "MUNDO", Icon = "globe" })
g = mundo:Groupbox({ Name = "MUNDO", Icon = "globe", Side = "Left" })
g:Foldout({ Name = "Cores do terreno", Build = function(p)
        p:ColorPicker({ Name = "Grama", Default = Color3.fromRGB(72, 160, 76), Callback = function(c) Actions.WORLD_COLORS.grama = c; Actions.paintTerrain("grama", c) end })
        p:ColorPicker({ Name = "Areia", Default = Color3.fromRGB(214, 190, 120), Callback = function(c) Actions.WORLD_COLORS.areia = c; Actions.paintTerrain("areia", c) end })
        p:ColorPicker({ Name = "Rocha", Default = Color3.fromRGB(120, 120, 126), Callback = function(c) Actions.WORLD_COLORS.rocha = c; Actions.paintTerrain("rocha", c) end })
        p:ColorPicker({ Name = "Terra", Default = Color3.fromRGB(110, 78, 52), Callback = function(c) Actions.WORLD_COLORS.terra = c; Actions.paintTerrain("terra", c) end })
    end })
g:Foldout({ Name = "Folhas", Build = function(p)
        p:ColorPicker({ Name = "Cor das folhas", Default = Color3.fromRGB(70, 150, 70), Callback = function(c) Actions.WORLD_COLORS.folhas = c; Actions.paintPlants("folhas", c) end })
    end })
g:Foldout({ Name = "Troncos", Build = function(p)
        p:ColorPicker({ Name = "Cor dos troncos", Default = Color3.fromRGB(100, 70, 45), Callback = function(c) Actions.WORLD_COLORS.troncos = c; Actions.paintPlants("troncos", c) end })
    end })
g:ColorPicker({ Name = "Cor da água", Default = Color3.fromRGB(40, 70, 75), Callback = function(c) Actions.WORLD_COLORS.agua = c; Actions.paintTerrain("agua", c) end })
T(g, "Sem grama", true); T(g, "Desativar minas", true)
g = mundo:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Left" })
T(g, "Carregar jogadores"); T(g, "Buscar chefes"); T(g, "Pontos de saída", true)
Library.RadarCfg = { on = false, range = 150, size = 130, npcs = false, pos = { x = 0.88, y = 0.3 } }
g:Toggle({ Name = "Radar", Default = false, Tooltip = tipText("Mini mapa redondo com os jogadores ao redor. Arraste para mover."),
    Callback = function(v) Library.RadarCfg.on = v end,
    Settings = function(p)
        p:Slider({ Name = "Alcance", Min = 50, Max = 500, Default = 150, Suffix = "m", Step = 10, Callback = function(v) Library.RadarCfg.range = v end })
        p:Slider({ Name = "Tamanho", Min = 90, Max = 220, Default = 130, Step = 5, Callback = function(v) Library.RadarCfg.size = v end })
        p:Toggle({ Name = "Mostrar NPCs", Default = false, Callback = function(v) Library.RadarCfg.npcs = v end })
    end })
g = mundo:Groupbox({ Name = "ILUMINAÇÃO", Icon = "lightbulb", Side = "Right", Checkbox = true, Default = true, Callback = function(v) Actions.WORLD.master = v; Actions.applyLighting() end })
for _, n in ipairs({ "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens",
    "Florescer", "Desfoque", "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade" }) do
    T(g, n, n == "Luz" or n == "Hora e sol")
end

-- ---------------- EXTRAS ----------------
local extras = Window:Tab({ Name = "EXTRAS", Icon = "layout-grid" })
g = extras:Groupbox({ Name = "EXTRAS", Icon = "layout-grid", Side = "Left" })
T(g, "Troca rápida"); T(g, "Modo pânico"); g:Button({ Name = "Atravessar porta", Callback = function() if Library.Safety:allow("Atravessar porta", true) then Actions.noclipPulse() else notify("Bloqueado pelo modo preventivo.") end end })
T(g, "Remover efeitos"); T(g, "Avisos de entrada")
g = extras:Groupbox({ Name = "SONS", Icon = "volume-2", Side = "Left" })
g:Input({ Name = "Adicionar ID de som", Placeholder = "ID", Callback = function(v) Actions.setSoundId(v) end })
for _, n in ipairs({ "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue" }) do
    T(g, n, n == "Disparo")
end
g = extras:Groupbox({ Name = "DETECÇÃO", Icon = "radar", Side = "Right" })
T(g, "Criador"); T(g, "Testador"); T(g, "Moderador", true); T(g, "Trapaceiro")
g = extras:Groupbox({ Name = "ORDENAR DEPÓSITO", Icon = "arrow-down-up", Side = "Right" })
g:Button({ Name = "Por valor", Callback = function() Actions.sortBackpack("valor") end })
g:Button({ Name = "Por tipo", Callback = function() Actions.sortBackpack("tipo") end })
g:Button({ Name = "Por nome", Callback = function() Actions.sortBackpack("nome") end })
g = extras:Groupbox({ Name = "VER INVENTÁRIO", Icon = "backpack", Side = "Right" })
g:Keybind({ Name = "Ver inventário", Default = "Backquote", Callback = function() Actions.toggleInv() end })
g:Dropdown({ Name = "Mostrar", Options = { "Jogadores", "NPCs", "Todos" }, Default = "Jogadores", Callback = function(v) Actions.INV.mode = v; if Actions.INV.on then Actions.refreshInv() end end })
T(g, "Sempre mostrar")

-- ---------------- BUSCAR SAQUE / SERVIDORES / SKINS / MISSÕES / COMERCIANTES ----------------
local saque = Window:Tab({ Name = "BUSCAR SAQUE", Icon = "package-search" })
Library.LootCfg = { rarities = { ["Mítico"] = true, ["Lendário"] = true, ["Épico"] = true, ["Raro"] = true }, maxDist = 300, query = "", mark = false, force = true, until_ = 0 }
do
    local LF = Library.LootCfg
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
    fg:Toggle({ Name = "Marcar na tela", Default = false, Tooltip = tipText("Mostra o nome e a distância dos itens encontrados direto no jogo, na cor da raridade."),
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
local overlay = Instance.new("ScreenGui")
Library:ProtectGui(overlay)
overlay.Name = "BBCOverlay"; overlay.ResetOnSpawn = false; overlay.IgnoreGuiInset = true; overlay.DisplayOrder = 998
local overlayParent = Library:ParentGui(overlay)

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
-- cabeçalho: ícone de lista, título e alfinete (fixar)
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
Actions.connect(klPin.MouseButton1Click, function()
    KL.Pin = not KL.Pin
    paintPin()
    if klPinToggle then klPinToggle:Set(KL.Pin, true) end
end)
-- lista com rolagem própria
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
        Actions.connect(edit.MouseButton1Click, function() if kb.begin then kb.begin() end end)
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
refreshPanels = function()
    applyPanel(WM, wmFrame, wmCorner, wmStroke, wmText, 28)
    klFrame.Visible = KL.On
    klScale.Scale = KL.Size / 100
    klFrame.BackgroundTransparency = KL.BgT
    klStroke.Transparency = KL.BrdT
    klCorner.CornerRadius = UDim.new(0, KL.Radius)
    renderKL()
end
table.insert(onLanguageChanged, refreshPanels)

-- arrastar painéis (mouse ou toque), a menos que "Fixar" esteja ligado
local function makeDraggable(handle, cfg, target)
    local frame = target or handle
    handle.Active = true
    local dragging, startPos, startInput
    Actions.connect(handle.InputBegan, function(i)
        if cfg.Pin then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, frame.Position
        end
    end)
    Actions.connect(LangUIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    Actions.connect(LangUIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(wmFrame, WM)
makeDraggable(klHead, KL, klFrame)

-- Cursor livre: segurando a tecla do cursor, o mouse é liberado para clicar no menu
local cursorFree, cursorHeld, cursorKey = true, false, Enum.KeyCode.LeftAlt
Library:OnPanic(function(on)
    if on then
        cursorHeld = false
        Actions.restoreProperty(LangUIS, "MouseBehavior")
        Actions.restoreProperty(LangUIS, "MouseIconEnabled")
    end
end)
Actions.connect(LangUIS.InputBegan, function(i) if cursorFree and i.KeyCode == cursorKey then cursorHeld = true end end)
Actions.connect(LangUIS.InputEnded, function(i) if i.KeyCode == cursorKey then cursorHeld = false end end)
Actions.connect(RunService.RenderStepped, function()
    if cursorHeld and not Library.Panic then
        Actions.setProperty(LangUIS, "MouseBehavior", Enum.MouseBehavior.Default)
        Actions.setProperty(LangUIS, "MouseIconEnabled", true)
    else
        Actions.restoreProperty(LangUIS, "MouseBehavior")
        Actions.restoreProperty(LangUIS, "MouseIconEnabled")
    end
end)
local frames, last = 0, os.clock()
local fps = 60
Actions.connect(RunService.Heartbeat, function()
    frames += 1
    if os.clock() - last >= 1 then fps = frames; frames = 0; last = os.clock() end
    local parts = { "<b>BBC HUB</b>" }
    for _, f in ipairs(WM.Fields) do
        if f == "Nome" then table.insert(parts, Players.LocalPlayer.Name)
        elseif f == "FPS" then table.insert(parts, fps .. " FPS")
        elseif f == "Ping" then
            local ok, ping = pcall(function() return math.floor(Players.LocalPlayer:GetNetworkPing() * 1000) end)
            table.insert(parts, (ok and ping or 0) .. " ms")
        elseif f == "Hora" then table.insert(parts, os.date("%H:%M")) end
    end
    wmText.Text = table.concat(parts, "  |  ")
end)
refreshPanels()

local function bind(cfg, key, v) cfg[key] = v; refreshPanels() end
local function SB(grp, name, min, max, def, suffix, step, cfg, key)
    return grp:Slider({ Name = name, Min = min, Max = max, Default = def, Suffix = suffix or "", Step = step or 1, Tooltip = Library.Internal.tipFor(name),
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

local cfg = Window:Tab({ Name = "CONFIGURAÇÕES", Icon = "settings", Hidden = true, IsSettings = true })

-- Configuração do menu usa o mesmo armazenamento já existente; não apaga perfis.
do
    local box = cfg:Groupbox({ Name = "CONFIGURAÇÃO DO MENU", Icon = "save", Side = "Right" })
    local name = box:Input({ Name = "Nome da configuração", Default = "default", NoPersist = true,
        Tooltip = function() return tr("Escolha um nome para salvar ou carregar os ajustes do menu.") end, Callback = function() end })
    Window._cfgBox = name.Box
    local active = box:Label({ Text = "Ativa: —" })
    local choices = box:Dropdown({ Name = "Configurações disponíveis", Options = {}, NoPersist = true,
        Tooltip = function() return tr("Seleciona um arquivo existente sem carregá-lo.") end,
        Callback = function(value) if type(value) == "string" then name.Box.Text = value end end })
    local function refreshConfigs()
        local names = Window:ListConfigs()
        choices:SetOptions(names)
        if Window._cfgName and table.find(names, Window._cfgName) then choices:Set(Window._cfgName, true) end
        active:Set(tr("Ativa") .. ": " .. (Window._cfgName or "—"))
        if Window._refreshHomeFavorites then Window._refreshHomeFavorites() end
    end
    Window._configChanged = refreshConfigs
    table.insert(onLanguageChanged, refreshConfigs)
    box:Button({ Name = "Atualizar lista", Tooltip = function() return tr("Lista arquivos de configuração disponíveis no executor.") end, Callback = function()
        if type(listfiles) ~= "function" then notify(tr("Listagem indisponível neste executor.")); return end
        refreshConfigs()
    end })
    box:Button({ Name = "Salvar configuração", Tooltip = function() return tr("Salva os ajustes atuais e seleciona este arquivo para iniciar.") end, Callback = function()
        local n = Library.CleanName(name.Box.Text)
        if n == "" then n = "default" end
        local ok, reason = Window:RequestSaveConfig(n)
        if ok then
            name.Box.Text = n
            if not Window:SetAutoload(n) then notify(tr("Salvo, mas não foi possível selecionar o carregamento inicial.")) end
        elseif reason == "confirmar" then
            notify(tr("Toque em Salvar novamente em até 30 segundos para confirmar."))
        elseif reason == "alterado" then
            notify(tr("Arquivo ou ajustes mudaram; confirme novamente."))
        else
            notify(tr("Falha ao salvar; veja o diagnóstico.") .. " " .. tostring(reason))
        end
    end })
    local previewSummary = box:Label({ Text = "" })
    local previewList = Instance.new("ScrollingFrame")
    previewList.Size = UDim2.new(1, -16, 0, 110); previewList.BackgroundTransparency = 1; previewList.BorderSizePixel = 0
    previewList.LayoutOrder = box:_nextOrder(); previewList.ScrollBarThickness = 4; previewList.Visible = false
    previewList.CanvasSize = UDim2.new(); previewList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    previewList.Parent = box.List
    Library.Bind(previewList, "ScrollBarImageColor3", "Accent")
    local previewText = Instance.new("TextLabel")
    previewText.Size = UDim2.new(1, -8, 0, 0); previewText.AutomaticSize = Enum.AutomaticSize.Y
    previewText.BackgroundTransparency = 1; previewText.TextWrapped = true; previewText.TextTruncate = Enum.TextTruncate.None
    previewText.TextXAlignment = Enum.TextXAlignment.Left; previewText.TextYAlignment = Enum.TextYAlignment.Top
    previewText.TextSize = 12; previewText.FontFace = Library.Fonts.Regular; previewText.Text = ""; previewText.Parent = previewList
    Library.Bind(previewText, "TextColor3", "Text")
    local previewReport, previewPage = nil, 1
    local function drawPreviewPage()
        local lines = {}
        if previewReport then
            local first = (previewPage - 1) * 50 + 1
            local last = math.min(#previewReport.changes, first + 49)
            for i = first, last do
                local change = previewReport.changes[i]
                lines[#lines + 1] = change.key .. ": " .. change.before .. " → " .. change.after
            end
        end
        previewText.Text = table.concat(lines, "\n")
        previewList.Visible = #lines > 0
        previewList.CanvasPosition = Vector2.new(0, 0)
        if previewReport then
            local pages = math.max(1, math.ceil(#previewReport.changes / 50))
            previewSummary:Set(tr("Alterações") .. ": " .. #previewReport.changes .. " · " .. tr("Bloqueadas") .. ": " .. previewReport.skipped .. " · " .. tr("Desconhecidas") .. ": " .. previewReport.unknown .. " · " .. previewPage .. "/" .. pages)
        end
    end
    box:Button({ Name = "Página anterior da prévia", Callback = function() if previewReport and previewPage > 1 then previewPage -= 1; drawPreviewPage() end end })
    box:Button({ Name = "Próxima página da prévia", Callback = function()
        if previewReport and previewPage < math.ceil(#previewReport.changes / 50) then previewPage += 1; drawPreviewPage() end
    end })
    box:Button({ Name = "Revisar configuração", Tooltip = function() return tr("Mostra alterações sem aplicá-las; a prévia expira em 60 segundos.") end, Callback = function()
        local report, err = Window:StageConfigPreview(name.Box.Text)
        previewReport, previewPage = report, 1
        previewList.Visible = false; previewText.Text = ""
        if not report then previewSummary:Set(tr("Prévia indisponível") .. ": " .. tostring(err)); return end
        drawPreviewPage()
    end })
    box:Button({ Name = "Confirmar carregamento", Tooltip = function() return tr("Aplica a prévia se o arquivo, os ajustes e a política não mudaram.") end, Callback = function()
        local n = Library.CleanName(name.Box.Text)
        if n == "" then n = "default" end
        local ok, err = Window:ConfirmConfigPreview(n)
        if not ok then notify(tr("Não foi possível confirmar") .. ": " .. tostring(err)); return end
        previewReport = nil; previewSummary:Set(""); previewList.Visible = false; previewText.Text = ""
        name.Box.Text = n
        if not Window:SetAutoload(n) then notify(tr("Carregado, mas não foi possível selecionar o carregamento inicial.")) end
    end })
    box:Button({ Name = "Recuperar backup", Tooltip = function() return tr("Cria uma cópia do backup e a carrega sem alterar os arquivos antigos.") end, Callback = function()
        local ok, result = Window:RestoreConfigBackup(name.Box.Text)
        if not ok then notify(tr("Não foi possível recuperar o backup.") .. " " .. tostring(result)); return end
        name.Box.Text = result
        if not Window:SetAutoload(result) then notify(tr("Carregado, mas não foi possível selecionar o carregamento inicial.")) end
        refreshConfigs()
    end })
    local versionChoice = box:Dropdown({ Name = "Versão do histórico", Options = {}, NoPersist = true, Callback = function() end })
    box:Button({ Name = "Atualizar histórico", Callback = function() versionChoice:SetOptions(Window:ListConfigVersions(name.Box.Text)) end })
    box:Button({ Name = "Criar versão", Callback = function()
        local ok, result = Window:CreateConfigVersion(name.Box.Text)
        notify(ok and (tr("Versão criada") .. ": " .. result) or (tr("Não foi possível criar versão") .. ": " .. tostring(result)))
        versionChoice:SetOptions(Window:ListConfigVersions(name.Box.Text))
    end })
    box:Button({ Name = "Restaurar versão em cópia", Callback = function()
        local version = versionChoice:Get()
        if type(version) == "table" then version = version[1] end
        local ok, result = Window:RestoreConfigVersion(name.Box.Text, version)
        if ok then name.Box.Text = result; refreshConfigs(); notify(tr("Cópia criada; revise antes de carregar") .. ": " .. result)
        else notify(tr("Não foi possível recuperar a versão") .. ": " .. tostring(result)) end
    end })
    box:Label({ Text = "O bloqueio preventivo continua ativo ao iniciar." })
    refreshConfigs()
end

-- Segurança: modo pânico
do
    local P = cfg:Groupbox({ Name = "SEGURANÇA", Icon = "shield", Side = "Left" })
    Library._panicToggle = P:Toggle({ Name = "Modo pânico", Default = false, NoPersist = true,
        Tooltip = tipText("Esconde menu, ESP, radar e botões fixos de uma vez. Para voltar, toque 3 vezes no topo da tela (ou use a tecla de pânico)."),
        Callback = function(v) Window:SetPanic(v) end })
    P:Keybind({ Name = "Tecla de pânico", Default = "End", Callback = function() Window:SetPanic(not Library.Panic) end })
    P:Toggle({ Name = "Bloqueio preventivo", Default = true, NoPersist = true, NoSave = true,
        Tooltip = tipText("Bloqueia uma lista de opções de maior risco, sem detectar o anticheat do jogo. Não garante segurança."),
        Callback = function(v) Library.Safety:setEnabled(v) end })

end

-- Geral
g = cfg:Groupbox({ Name = "GERAL", Icon = "settings", Side = "Left" })
g:Dropdown({ Name = "Idioma", Options = { "English", "Español", "Português (Brasil)", "简体中文", "Русский" }, Default = LANG_NAMES[currentLang],
    Flags = { ["English"] = "en", ["Español"] = "es", ["Português (Brasil)"] = "pt", ["简体中文"] = "zh", ["Русский"] = "ru" },
    Callback = function(v)
        local code = LANG_CODES[type(v) == "table" and v[1] or v] or "pt"
        setLanguage(code)
        notify(tr("Idioma alterado") .. ": " .. LANG_NAMES[code])
    end })
g:Slider({ Name = "Escala do menu", Min = 70, Max = 130, Default = 100, Step = 5, Suffix = "%",
    Tooltip = function() return tr("Ajusta o tamanho do menu, limitado ao espaço disponível na tela.") end,
    Callback = function(v) Window:SetScaleFactor(v / 100) end })
g:Slider({ Name = "Atualizações do ESP", Min = 10, Max = 60, Default = 30, Step = 5, Suffix = " fps",
    Tooltip = function() return tr("Limita a frequência de atualização visual do ESP, radar e busca de saque.") end,
    Callback = function(v) Library.RenderRate = math.clamp(v, 10, 60) end })
g:Keybind({ Name = "Tecla do menu", Default = "RightShift", OnChanged = function(k) Window:SetKeybind(k); keys.menu = k.Name; refreshPanels() end, Callback = function() end })
g:Keybind({ Name = "Tecla do cursor", Default = "LeftAlt", OnChanged = function(k) cursorKey = k; keys.cursor = k.Name; refreshPanels() end, Callback = function() end })
g:Toggle({ Name = "Cursor livre", Default = true, Callback = function(v) cursorFree = v end })
g:Toggle({ Name = "Lista de atalhos", Default = false, Callback = function(v) bind(KL, "On", v) end })
g:Toggle({ Name = "Ilha de FPS", Default = true, Callback = function(v) Window:SetIsland(v) end })
T(g, "Ocultar indisponíveis")
g:Toggle({ Name = "Fixar botão móvel", Default = false, Callback = function(v) pcall(function() Window:SetIslandDraggable(not v) end) end })
g:Button({ Name = "Rever tutorial", Callback = function() notify(tr(IS_MOBILE and "Toque no botão flutuante para abrir o menu." or "Pressione a tecla do menu para abrir ou fechar.")) end })
g:Button({ Name = "Sair", Callback = function()
    if Library._stopEngine then Library._stopEngine() end   -- desliga ESP/radar e suas GUIs
    Window:Destroy()
end })

-- Diagnóstico informa capacidades locais; não testa serviços nem detecta anticheat.
do
    local panel = cfg:Groupbox({ Name = "DIAGNÓSTICO", Icon = "settings", Side = "Right" })
    local files = panel:Label({ Text = "" })
    local controls = panel:Label({ Text = "" })
    local integration = panel:Label({ Text = "" })
    local reload = panel:Label({ Text = "" })
    local prompt = panel:Label({ Text = "" })
    local policy = panel:Label({ Text = "" })
    local engineTiming = panel:Label({ Text = "" })
    local startupState = panel:Label({ Text = "" })
    local storageState = panel:Label({ Text = "" })
    local last = panel:Label({ Text = "" })
    local previous = panel:Label({ Text = "" })
    local older = panel:Label({ Text = "" })
    local pending1 = panel:Label({ Text = "" })
    local pending2 = panel:Label({ Text = "" })
    local pending3 = panel:Label({ Text = "" })
    local pending4 = panel:Label({ Text = "" })
    local pendingGear1 = panel:Label({ Text = "" })
    local pendingGear2 = panel:Label({ Text = "" })
    local function refreshDiagnostics()
        local fs = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"
        files:Set(tr("Arquivos") .. ": " .. tr(fs and "APIs presentes" or "APIs ausentes"))
        controls:Set(tr("Entrada") .. ": " .. (LangUIS.TouchEnabled and "touch " or "") .. (LangUIS.KeyboardEnabled and "teclado " or "") .. (LangUIS.MouseEnabled and "mouse" or ""))
        integration:Set(tr("Saque configurado") .. ": " .. tr(Actions.getLootConfig() and "Sim" or "Não"))
        reload:Set(tr("Recarga configurada") .. ": " .. tr(Actions.getReloadPath() and "Sim" or "Não"))
        prompt:Set(tr("API de prompt") .. ": " .. tr(type(fireproximityprompt) == "function" and "APIs presentes" or "APIs ausentes"))
        policy:Set(tr("Bloqueio preventivo") .. ": " .. tr(Library.Safety.enabled and "Ligado" or "Desligado"))
        startupState:Set(tr("Montagem") .. ": " .. tr(Window._prebuildFailed and "Falhou" or (Window._loaded and "Concluída" or "Pendente")))
        storageState:Set(tr("Salvamento automático") .. ": " .. tr(Window._autoSaveBlocked and "Suspenso" or (Window._ready and "Disponível" or "Pendente")))
        local timing = Library.Diagnostics.engine
        engineTiming:Set(tr("Tempo médio do motor visual") .. ": " .. (timing and string.format("%.2f ms", timing.average) or "—"))
        local recent = Library.Diagnostics.recent
        last:Set(tr("Última falha registrada") .. ": " .. (recent[#recent] or tr("Nenhuma")))
        previous:Set(recent[#recent - 1] or "—")
        older:Set(recent[#recent - 2] or "—")
        pending1:Set(tr("Mochila personalizada") .. ": " .. tr("Não implementado"))
        pending2:Set(tr("Mapa e navegação") .. ": " .. tr("Depende do jogo"))
        pending3:Set(tr("Trocar personagem") .. ": " .. tr("Depende do jogo"))
        pending4:Set(tr("Mira falsa") .. " / " .. tr("Alternativa visível") .. ": " .. tr("Não implementado"))
        pendingGear1:Set(tr("Ajustes pendentes") .. ": " .. tr("Mochila personalizada") .. " / " .. tr("Mochila"))
        pendingGear2:Set(tr("Ajustes pendentes") .. ": " .. tr("Mira falsa") .. " / " .. tr("Trocar personagem"))
    end
    panel:Button({ Name = "Atualizar diagnóstico", Tooltip = function() return tr("Atualiza as capacidades locais e a última falha registrada.") end, Callback = refreshDiagnostics })
    panel:Button({ Name = "Copiar erros recentes", Callback = function()
        local recent = Library.Diagnostics.recent
        if #recent == 0 then notify(tr("Nenhuma falha registrada")); return end
        local copier = type(setclipboard) == "function" and setclipboard or (type(toclipboard) == "function" and toclipboard or nil)
        local ok, result = false, nil
        if copier then ok, result = pcall(copier, table.concat(recent, "\n")) end
        notify(tr(ok and result ~= false and "Erros copiados." or "Cópia indisponível ou falhou."))
    end })
    panel:Label({ Text = "APIs presentes não garantem funcionamento." })
    table.insert(onLanguageChanged, refreshDiagnostics)
    refreshDiagnostics()
end

-- Aparência
local presetNames = Library.ThemeOrder
g = cfg:Groupbox({ Name = "APARÊNCIA", Icon = "palette", Side = "Left" })
do
    -- círculos de cor: tocar aplica o tema na hora
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
    local function repaintSwatches()
        for n, r in pairs(rings) do
            local selected = Library.ThemeName == n
            r.ring.Transparency = selected and 0 or 1; r.tick.Visible = selected
            if r.pumpkin then r.pumpkin.Visible = not selected end
        end
    end
    table.insert(Library._themeListeners, repaintSwatches)
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
        Actions.connect(b.MouseButton1Click, function()
            Library:SetTheme(name)
            for n, r in pairs(rings) do r.ring.Transparency = (n == name) and 0 or 1; r.tick.Visible = (n == name); if r.pumpkin then r.pumpkin.Visible = (n ~= name) end end
            wmStroke.Color = Library.Theme.Accent; recolorKL()
            notify(name)
        end)
        b.Parent = swatches
    end
end
do
    local A = Library.Appearance
    local candidate = Color3.new(A.color[1], A.color[2], A.color[3])
    -- Amostra ilustrativa, sem acionar botões reais nem mudar o tema.
    local sample = Instance.new("Frame")
    sample.Size = UDim2.new(1, -16, 0, 76); sample.BorderSizePixel = 0; sample.LayoutOrder = g:_nextOrder(); sample.Parent = g.List
    Library.Bind(sample, "BackgroundColor3", "Background")
    Instance.new("UICorner", sample).CornerRadius = UDim.new(0, 6)
    local sampleLabel = Instance.new("TextLabel")
    sampleLabel.BackgroundTransparency = 1; sampleLabel.Size = UDim2.new(1, -16, 0, 20); sampleLabel.Position = UDim2.fromOffset(8, 6)
    sampleLabel.Text = tr("Prévia do tema"); sampleLabel.TextXAlignment = Enum.TextXAlignment.Left; sampleLabel.TextSize = 13; sampleLabel.FontFace = Library.Fonts.Bold; sampleLabel.Parent = sample
    Library.Bind(sampleLabel, "TextColor3", "Text")
    local sampleControl = Instance.new("Frame")
    sampleControl.Size = UDim2.new(1, -16, 0, 32); sampleControl.Position = UDim2.fromOffset(8, 34); sampleControl.BorderSizePixel = 0; sampleControl.Parent = sample
    Library.Bind(sampleControl, "BackgroundColor3", "Surface2")
    Instance.new("UICorner", sampleControl).CornerRadius = UDim.new(0, 4)
    local sampleName = Instance.new("TextLabel")
    sampleName.BackgroundTransparency = 1; sampleName.Text = tr("Exemplo"); sampleName.TextSize = 12; sampleName.FontFace = Library.Fonts.Regular
    sampleName.TextXAlignment = Enum.TextXAlignment.Left; sampleName.Position = UDim2.fromOffset(8, 0); sampleName.Size = UDim2.new(1, -50, 1, 0); sampleName.Parent = sampleControl
    Library.Bind(sampleName, "TextColor3", "Text")
    local sampleChip = Instance.new("Frame")
    sampleChip.AnchorPoint = Vector2.new(1, 0.5); sampleChip.Position = UDim2.new(1, -8, 0.5, 0); sampleChip.Size = UDim2.fromOffset(30, 16)
    sampleChip.BorderSizePixel = 0; sampleChip.BackgroundColor3 = candidate; sampleChip.Parent = sampleControl
    Instance.new("UICorner", sampleChip).CornerRadius = UDim.new(1, 0)
    table.insert(onLanguageChanged, function() sampleLabel.Text = tr("Prévia do tema"); sampleName.Text = tr("Exemplo") end)
    local contrastLine = g:Label({ Text = "" })
    local contrastWarning = g:Label({ Text = "" })
    local function updateContrast()
        sampleChip.BackgroundColor3 = candidate
        local surface = Library.UISupport.contrast(candidate, Library.Theme.Surface) or 1
        local white = Library.UISupport.contrast(candidate, Color3.new(1, 1, 1)) or 1
        contrastLine:Set(string.format("%s %.1f:1 · %s %.1f:1", tr("Cor/fundo"), surface, tr("Branco/cor"), white))
        contrastWarning:Set(tr((surface < 4.5 or white < 4.5) and "Contraste baixo em uma combinação." or "Contraste adequado nestas combinações."))
    end
    local picker = g:ColorPicker({ Name = "Prévia da cor", Default = candidate, NoPersist = true, Tooltip = function() return tr("Escolha uma cor na amostra; aplique depois para mudar o menu.") end, Callback = function(c) candidate = c; updateContrast() end })
    table.insert(A.colorListeners, function(c)
        candidate = Color3.new(c[1], c[2], c[3])
        picker:Set(candidate, true); updateContrast()
    end)
    table.insert(Library._themeListeners, updateContrast)
    table.insert(onLanguageChanged, updateContrast)
    updateContrast()
    g:Button({ Name = "Aplicar cor personalizada", Callback = function()
        A:setColor({candidate.R, candidate.G, candidate.B})
        Library:SetTheme("Custom")
        notify(tr("Cor personalizada"))
    end })
    g:Toggle({ Name = "Alto contraste", Default = A.contrast, Tooltip = function() return tr("Aumenta o contraste da superfície e do texto; cores escolhidas podem variar.") end, Callback = function(v) A:setFlag("contrast", v) end })
    g:Toggle({ Name = "Reduzir movimento", Default = A.motion, Tooltip = function() return tr("Reduz transições e animações visuais do menu e da prévia.") end, Callback = function(v) A:setFlag("motion", v) end })
    g:Toggle({ Name = "Pular intro na próxima vez", Default = A.skipIntro, Tooltip = function() return tr("Abre o menu sem o cartão de carregamento na próxima inicialização.") end, Callback = function(v) A:setFlag("skipIntro", v) end })
end
g:Toggle({ Name = "Cubo", Default = true, Callback = function(v) Window:SetLogo(v) end })
g:Toggle({ Name = "Rastro ao ativar", Default = true, Tooltip = tipText("Mostra um rastro de luz na cor do menu quando você ativa uma opção."), Callback = function(v) Library.Effects = v end })
g:Toggle({ Name = "Animação do menu", Default = true, Tooltip = tipText("Abre e fecha o menu com um efeito suave."), Callback = function(v) Library.MenuAnim = v end })
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

refreshPanels()
