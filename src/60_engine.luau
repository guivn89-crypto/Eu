-- ============ 60_engine.luau :: Motor do ESP, radar, loot, zona do pânico e encerramento ============
-- ============================================================
--  Motor: ESP no jogo (usa as opções dos painéis), radar, buscar saque
--  e a zona de retorno do modo pânico.
-- ============================================================
do
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")
    local LP = Players.LocalPlayer
    local espGui = Instance.new("ScreenGui")
    Library:ProtectGui(espGui)
    espGui.Name = "BBCESP"; espGui.ResetOnSpawn = false; espGui.IgnoreGuiInset = true; espGui.DisplayOrder = 990
    Library:ParentGui(espGui)
    local holder = Instance.new("Folder")
    holder.Name = "BBCMarks"; Library:ParentGui(holder)
    table.insert(Library._panicGuis, overlay)
    table.insert(Library._panicGuis, espGui)

    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        if class == "ScreenGui" or class == "BillboardGui" then Library:ProtectGui(i) end
        if class == "ScreenGui" then Library:ParentGui(i) else i.Parent = parent end
        return i
    end
    local FONT = Library.Fonts.Bold
    -- o "Sair" usa isso para desligar o motor (laços, conexões e GUIs do ESP/radar)
    local engineConns, engineGuis = {}, { espGui, holder, overlay }
    local engineClosed = false
    local function conn(sig, fn)
        local c = Library.Guards.connect(sig, fn, function() return not engineClosed end,
            function(stage, err)
                warn("[BBC] Motor " .. stage .. ": " .. err)
                if Library.Diagnostics then Library.Diagnostics:record("motor " .. stage, err) end
                if stage == "interrompido" then
                    pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = "Evento do motor interrompido; veja o console.", Duration = 5 }) end)
                end
            end)
        engineConns[#engineConns + 1] = c
        return c
    end

    -- ---------- zona de retorno do modo pânico: 3 toques no topo da tela ----------
    do
        local zoneGui = mk("ScreenGui", { Name = "BBCZone", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1001 }, overlayParent)
        engineGuis[#engineGuis + 1] = zoneGui
        local zone = mk("TextButton", { BackgroundTransparency = 1, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromOffset(Actions.getAdjustment("panicZoneWidth"), 56), Visible = false }, zoneGui)
        local taps = {}
        conn(zone.MouseButton1Click, function()
            local now = os.clock()
            table.insert(taps, now)
            for i = #taps, 1, -1 do if now - taps[i] > Actions.getAdjustment("panicTapWindow") then table.remove(taps, i) end end
            if #taps >= 3 then taps = {}; Window:SetPanic(false) end
        end)
        Library._panicZone = zone
    end

    -- ---------- NPCs (modelos com Humanoid que não são jogadores) ----------
    local npcs, npcScan = {}, false
    local function addHum(h)
        if not engineClosed and h:IsA("Humanoid") and h:IsDescendantOf(Workspace) then
            local m = h.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then npcs[m] = h end
        end
    end
    local function startNpcScan()
        if npcScan then return end
        npcScan = true
        conn(Workspace.DescendantAdded, function(d) if d:IsA("Humanoid") then task.defer(addHum, d) end end)
        conn(Workspace.DescendantRemoving, function(d)
            npcs[d] = nil
            if d:IsA("Humanoid") and d.Parent then npcs[d.Parent] = nil end
        end)
        Library.StreamScan.start(Workspace, function() return not engineClosed end, addHum)
    end

    -- ---------- Itens / recipientes (varredura com cache) ----------
    local CONT_KW = { "chest", "bau", "baú", "box", "crate", "container", "depot", "stash", "safe", "locker", "fridge", "register", "dumpster", "sack", "mochila" }
    local MISSION_KW = { "quest", "mission", "missão", "misso", "key", "chave", "document", "documento", "briefcase", "notebook", "laptop", "drive", "pendrive", "usb", "note", "nota", "maca" }
    local ITEM_KW = { "item", "loot", "ammo", "muni", "weapon", "arma", "tool", "ferramenta", "medkit", "kit", "potion", "poção", "pocao",
        "coin", "moeda", "gem", "diamond", "drop", "pickup", "supply", "suprimento", "cell", "celula" }
    local itemCands = { Recipiente = {}, ["Item no chão"] = {}, ["Itens de missão"] = {} }
    local itemScan = false
    local itemCounts = { Recipiente = 0, ["Item no chão"] = 0, ["Itens de missão"] = 0 }
    local function addItemCandidate(kind, inst)
        local set = itemCands[kind]
        if not set[inst] and itemCounts[kind] < 2048 then set[inst] = true; itemCounts[kind] += 1 end
    end
    local function removeItemCandidate(kind, inst)
        local set = itemCands[kind]
        if set[inst] then set[inst] = nil; itemCounts[kind] -= 1 end
    end
    local function hasChild(inst, class)
        return inst:FindFirstChildOfClass(class) ~= nil
    end
    local function classifyItem(inst)
        if engineClosed or not inst:IsDescendantOf(Workspace) then return end
        if not (inst:IsA("BasePart") or inst:IsA("Model")) then return end
        if LP.Character and inst:IsDescendantOf(LP.Character) then return end
        if Players:GetPlayerFromCharacter(inst) then return end
        local par = inst.Parent
        if par and par:IsA("Model") and par:FindFirstChildOfClass("Humanoid") then return end
        local low = string.lower(inst.Name)
        if low == "" then return end
        local cont, miss = false, false
        for _, k in ipairs(CONT_KW) do if string.find(low, k, 1, true) then cont = true; break end end
        for _, k in ipairs(MISSION_KW) do if string.find(low, k, 1, true) then miss = true; break end end
        if cont then addItemCandidate("Recipiente", inst) end
        if miss then addItemCandidate("Itens de missão", inst) end
        if cont or miss then return end
        local item = false
        for _, k in ipairs(ITEM_KW) do if string.find(low, k, 1, true) then item = true; break end end
        if not item and (hasChild(inst, "ProximityPrompt") or hasChild(inst, "ClickDetector")) then item = true end
        local attr = inst:GetAttribute("Rarity") or inst:GetAttribute("Tier") or inst:GetAttribute("Value")
        if attr ~= nil then item = true end
        if item then addItemCandidate("Item no chão", inst) end
    end
    local function startItemScan()
        if itemScan then return end
        itemScan = true
        conn(Workspace.DescendantAdded, classifyItem)
        conn(Workspace.DescendantRemoving, function(inst)
            for kind in pairs(itemCands) do removeItemCandidate(kind, inst) end
        end)
        Library.StreamScan.start(Workspace, function() return not engineClosed end, classifyItem)
    end

    -- ---------- ESP ----------
    local R15 = { { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" }, { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" },
        { "LeftLowerLeg", "LeftFoot" }, { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" } }
    local R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
    local KEYS = { "highlight", "box", "name", "healthbar", "health", "distance", "tracers", "arrows", "skeleton" }
    local function anyOn(S)
        if not S then return false end
        for _, k in ipairs(KEYS) do if S[k] and S[k].on then return true end end
        return false
    end
    local function hpColor(S, ratio)
        if not S.healthbar.auto then return S.healthbar.color end
        if ratio > 0.6 then return Color3.fromRGB(70, 220, 90) elseif ratio > 0.3 then return Color3.fromRGB(240, 200, 60) end
        return Color3.fromRGB(240, 80, 70)
    end
    local function txt(parent, anchor)
        return mk("TextLabel", { BackgroundTransparency = 1, FontFace = FONT, TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), AnchorPoint = anchor,
            Size = UDim2.fromOffset(120, 14), Visible = false, TextColor3 = Color3.new(1, 1, 1) }, parent)
    end
    local function lineF(f, x0, y0, x1, y1, th, col)
        local dx, dy = x1 - x0, y1 - y0
        f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), th)
        f.Position = UDim2.fromOffset((x0 + x1) / 2, (y0 + y1) / 2)
        f.Rotation = math.deg(math.atan2(dy, dx))
        f.BackgroundColor3 = col
        f.Visible = true
    end
    local pool = { Jogador = {}, NPCs = {}, Corpo = {}, Recipiente = {}, ["Item no chão"] = {}, ["Itens de missão"] = {} }
    local function newDraw()
        local d = { skel = {}, skelOn = false }
        local r = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, espGui)
        d.root = r
        d.boxFull = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, r)
        d.boxStroke = mk("UIStroke", { Thickness = 2 }, d.boxFull)
        d.corners = {}
        for i = 1, 8 do d.corners[i] = mk("Frame", { BorderSizePixel = 0, Visible = false }, r) end
        d.hbBg = mk("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false }, r)
        d.hbFill = mk("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, d.hbBg)
        d.name = txt(r, Vector2.new(0.5, 1)); d.hp = txt(r, Vector2.new(1, 0)); d.dist = txt(r, Vector2.new(0.5, 0))
        d.tracer = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, r)
        d.arrow = Library.MakeIcon(r, "navigation-2", 18, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
        d.dot = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Visible = false }, r)
        mk("UICorner", { CornerRadius = UDim.new(1, 0) }, d.dot)
        d.hl = mk("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, holder)
        return d
    end
    local function hideDraw(d)
        d.root.Visible = false
        d.hl.Enabled = false
    end
    -- Alturas estáveis em relação à raiz, sem depender de poses/acessórios.
    local function characterOffsets(t)
        local function partHeight(name)
            local part = t.model:FindFirstChild(name)
            return part and part:IsA("BasePart") and part.Size.Y or nil
        end
        local rootHalf = t.hrp.Size.Y / 2
        local above, below
        local torso = partHeight("Torso")
        if torso then
            above = torso / 2 + (partHeight("Head") or 1)
            below = rootHalf + (partHeight("Left Leg") or partHeight("Right Leg") or 2)
        else
            local upper, lower = partHeight("UpperTorso"), partHeight("LowerTorso")
            above = (lower or t.hrp.Size.Y) / 2 + (upper or 1) + (partHeight("Head") or 1)
            below = rootHalf + math.max(0, t.hum.HipHeight)
        end
        return math.max(above, 1.5), math.max(below, 1.5)
    end
    local function projectBounds(c, center, above, below)
        -- Os extremos ficam no plano da tela e à mesma profundidade da raiz.
        local up = c.CFrame.UpVector
        return c:WorldToViewportPoint(center + up * above), c:WorldToViewportPoint(center - up * below)
    end
    local function drawTarget(d, t, S, c, vp, isNearest)
        local near = isNearest and S.nearest.on
        local ncol = S.nearest.color
        local center, above, below
        if t.hum and t.hum.Health > 0 then
            center = t.hrp.Position
            above, below = characterOffsets(t)
        else
            local sz = t.model:IsA("Model") and t.model:GetExtentsSize() or t.model.Size
            center, above, below = t.model:GetPivot().Position, sz.Y / 2, sz.Y / 2
        end
        local topV, botV = projectBounds(c, center, above, below)
        d.root.Visible = true
        -- esconde tudo; só reaparece o que estiver ligado
        d.boxFull.Visible = false
        for i = 1, 8 do d.corners[i].Visible = false end
        d.hbBg.Visible = false; d.name.Visible = false; d.hp.Visible = false; d.dist.Visible = false
        d.tracer.Visible = false; d.dot.Visible = false; d.arrow.Visible = false
        if d.skelOn then for _, f in ipairs(d.skel) do f.Visible = false end; d.skelOn = false end
        local onScreen = topV.Z > 0 and botV.Z > 0 and topV.X > -60 and topV.X < vp.X + 60 and topV.Y > -120 and botV.Y < vp.Y + 120
        if not onScreen then
            d.hl.Enabled = false
            if S.arrows and S.arrows.on then
                local projected = c:WorldToViewportPoint(center)
                local x, y = projected.X - vp.X / 2, projected.Y - vp.Y / 2
                if projected.Z < 0 then x, y = -x, -y end
                local length = math.sqrt(x * x + y * y)
                if length < 0.001 then x, y, length = 0, -1, 1 end
                x, y = x / length, y / length
                local margin = S.arrows.size + 8
                local rx, ry = math.max(1, vp.X / 2 - margin), math.max(1, vp.Y / 2 - margin)
                local scale = math.min(rx / math.max(math.abs(x), 0.0001), ry / math.max(math.abs(y), 0.0001))
                d.arrow.Position = UDim2.fromOffset(vp.X / 2 + x * scale, vp.Y / 2 + y * scale)
                d.arrow.Rotation = math.deg(math.atan2(y, x)) + 90
                d.arrow.Size = UDim2.fromOffset(S.arrows.size, S.arrows.size)
                d.arrow.ImageColor3 = near and ncol or S.arrows.color
                d.arrow.Visible = true
            end
            return
        end
        local top, bottom = topV.Y, botV.Y
        local hgt = math.max(bottom - top, 8)
        local wid = hgt * 0.55
        local cx = topV.X
        local left = cx - wid / 2
        local ts = S.textSize
        local far = S.lod.on and t.m > S.lod.near
        local boxCol = near and ncol or S.box.color
        local hl = S.highlight
        if d.hl.Adornee ~= t.model then d.hl.Adornee = t.model end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = hl.outlineColor or (near and ncol or hl.color):Lerp(Color3.new(1, 1, 1), 0.35)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0
        local distText = (S.distance.unit == "studs") and (math.floor(t.studs) .. " st") or (math.floor(t.m) .. "m")
        if far then
            -- longe: só um ponto + distância
            if S.box.on or hl.on then
                d.dot.Visible = true; d.dot.BackgroundColor3 = boxCol; d.dot.Position = UDim2.fromOffset(cx, (top + bottom) / 2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = ts; d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, (top + bottom) / 2 + 6)
            end
        else
            if S.box.on then
                local th = S.box.thick
                if S.box.style == "Completa" then
                    d.boxFull.Visible = true
                    d.boxFull.Position = UDim2.fromOffset(left, top); d.boxFull.Size = UDim2.fromOffset(wid, hgt)
                    d.boxStroke.Color = boxCol; d.boxStroke.Thickness = th
                else
                    local len = math.min(S.box.corner, wid / 2, hgt / 2)
                    local L = { { left, top, len, th }, { left, top, th, len }, { left + wid - len, top, len, th }, { left + wid - th, top, th, len },
                        { left, top + hgt - th, len, th }, { left, top + hgt - len, th, len }, { left + wid - len, top + hgt - th, len, th }, { left + wid - th, top + hgt - len, th, len } }
                    for i = 1, 8 do
                        local f, v = d.corners[i], L[i]
                        f.Visible = true; f.BackgroundColor3 = boxCol
                        f.Position = UDim2.fromOffset(v[1], v[2]); f.Size = UDim2.fromOffset(v[3], v[4])
                    end
                end
            end
            local ratio = t.hum and math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1) or 1
            if S.healthbar.on and t.hum then
                local bw = S.healthbar.width
                local bx = S.healthbar.side == "Direita" and (left + wid + 3) or (left - 3 - bw)
                d.hbBg.Visible = true; d.hbBg.Position = UDim2.fromOffset(bx, top); d.hbBg.Size = UDim2.fromOffset(bw, hgt)
                d.hbFill.Size = UDim2.fromScale(1, ratio); d.hbFill.BackgroundColor3 = hpColor(S, ratio)
            end
            if S.health.on and t.hum then
                d.hp.Visible = true; d.hp.Text = tostring(math.floor(t.hum.Health)); d.hp.TextSize = ts
                d.hp.TextColor3 = S.healthbar.auto and hpColor(S, ratio) or S.health.color
                if S.healthbar.side == "Direita" then
                    d.hp.AnchorPoint = Vector2.new(0, 0.5); d.hp.TextXAlignment = Enum.TextXAlignment.Left
                    d.hp.Position = UDim2.fromOffset(left + wid + 7 + (S.healthbar.on and S.healthbar.width or 0), top + hgt / 2)
                else
                    d.hp.AnchorPoint = Vector2.new(1, 0.5); d.hp.TextXAlignment = Enum.TextXAlignment.Right
                    d.hp.Position = UDim2.fromOffset(left - 7 - (S.healthbar.on and S.healthbar.width or 0), top + hgt / 2)
                end
            end
            if S.name.on then
                d.name.Visible = true; d.name.Text = t.name; d.name.TextSize = ts; d.name.TextColor3 = S.name.color
                d.name.Position = UDim2.fromOffset(cx, top - 2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = ts; d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, bottom + 2)
            end
            if S.skeleton.on then
                local list = t.model:FindFirstChild("UpperTorso") and R15 or R6
                d.skelOn = true
                for i, pr in ipairs(list) do
                    local f = d.skel[i]
                    if not f then f = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, d.root); d.skel[i] = f end
                    local a, b = t.model:FindFirstChild(pr[1]), t.model:FindFirstChild(pr[2])
                    if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                        local va, vb = c:WorldToViewportPoint(a.Position), c:WorldToViewportPoint(b.Position)
                        if va.Z > 0 and vb.Z > 0 then lineF(f, va.X, va.Y, vb.X, vb.Y, S.skeleton.thick, near and ncol or S.skeleton.color) else f.Visible = false end
                    else
                        f.Visible = false
                    end
                end
                for i = #list + 1, #d.skel do d.skel[i].Visible = false end
            end
        end
        if S.tracers.on then
            local fromBottom = S.tracers.origin == "Baixo"
            lineF(d.tracer, vp.X / 2, fromBottom and vp.Y or 0, cx, fromBottom and bottom or top, S.tracers.thick, near and ncol or S.tracers.color)
        end
    end
    local function gather(kind, out)
        if kind == "Jogador" then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ch = pl.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then
                        out[#out + 1] = { model = ch, hum = hum, hrp = hrp, name = (pl.DisplayName ~= "" and pl.DisplayName) or pl.Name }
                    end
                end
            end
        elseif kind == "Corpo" then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ch = pl.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health <= 0 then
                        out[#out + 1] = { model = ch, hum = hum, hrp = hrp, name = (pl.DisplayName ~= "" and pl.DisplayName) or pl.Name }
                    end
                end
            end
        elseif kind == "Recipiente" or kind == "Item no chão" or kind == "Itens de missão" then
            startItemScan()
            local arr = itemCands[kind]
            for inst in pairs(arr) do
                if not inst.Parent or not inst:IsDescendantOf(Workspace) then
                    removeItemCandidate(kind, inst)
                else
                    local hrp = inst:IsA("Model") and (inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart) or inst
                    if hrp and hrp:IsA("BasePart") then
                        out[#out + 1] = { model = inst, hum = nil, hrp = hrp, name = inst.Name }
                    end
                end
            end
        else
            startNpcScan()
            for m, hum in pairs(npcs) do
                if not m.Parent or not m:IsDescendantOf(Workspace) then
                    npcs[m] = nil
                else
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if hrp and hrp:IsA("BasePart") and hum.Parent and hum.Health > 0 and m ~= LP.Character then
                        out[#out + 1] = { model = m, hum = hum, hrp = hrp, name = m.Name }
                    end
                end
            end
        end
    end
    local selectedTargets, vis = {}, {}
    local function processKind(kind, S, c, vp, slowTick)
        local P = pool[kind]
        local active = S and not Library.Panic and Library.ESPMaster[kind] ~= false and anyOn(S)
        local selected = selectedTargets[kind]
        local camPos = c.CFrame.Position
        if not active then
            selectedTargets[kind] = nil
            selected = {}
        elseif slowTick or not selected then
            local candidates = {}
            gather(kind, candidates)
            table.clear(vis)
            for _, t in ipairs(candidates) do
                if t.model.Parent and t.hrp.Parent and (not t.hum or t.hum.Parent) then
                    t.studs = (t.hrp.Position - camPos).Magnitude
                    t.m = t.studs * 0.28
                    if t.m <= S.maxDist then vis[#vis + 1] = t end
                end
            end
            table.sort(vis, function(a, b) return a.studs < b.studs end)
            selected = {}
            for i = 1, math.min(#vis, 24) do selected[i] = vis[i] end
            selectedTargets[kind] = selected
        end
        local seen = {}
        for i, t in ipairs(selected) do
            if t.model.Parent and t.hrp.Parent and (not t.hum or t.hum.Parent) then
                t.studs = (t.hrp.Position - camPos).Magnitude
                t.m = t.studs * 0.28
                if t.m <= S.maxDist then
                    seen[t.model] = true
                    local d = P[t.model]
                    if not d then d = newDraw(); P[t.model] = d end
                    drawTarget(d, t, S, c, vp, i == 1)
                end
            end
        end
        for model, d in pairs(P) do
            if not seen[model] then
                hideDraw(d)
                if not model.Parent then d.root:Destroy(); d.hl:Destroy(); P[model] = nil end
            end
        end
    end

    -- ---------- radar ----------
    local RC = Library.RadarCfg
    local radar = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(10, 12, 14), BackgroundTransparency = 0.25, BorderSizePixel = 0,
        Visible = false, Active = true }, espGui)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, radar)
    local radarStroke = mk("UIStroke", { Thickness = 2, Color = Library.Theme.Accent }, radar)
    local ring = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, radar)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
    mk("UIStroke", { Thickness = 1, Transparency = 0.65, Color = Color3.new(1, 1, 1) }, ring)
    mk("Frame", { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0 }, radar)
    mk("Frame", { Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0 }, radar)
    mk("TextLabel", { BackgroundTransparency = 1, Text = "▲", TextSize = 14, FontFace = FONT, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16) }, radar)
    local radarDots = {}
    local radarDrag, rStart, rPos = false, nil, nil
    conn(radar.InputBegan, function(i)
        local t = i.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then radarDrag = true; rStart = i.Position; rPos = radar.Position end
    end)
    conn(UserInputService.InputChanged, function(i)
        if not radarDrag then return end
        local t = i.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement then
            local d = i.Position - rStart
            radar.Position = UDim2.new(rPos.X.Scale, rPos.X.Offset + d.X, rPos.Y.Scale, rPos.Y.Offset + d.Y)
        end
    end)
    conn(UserInputService.InputEnded, function(i)
        local t = i.UserInputType
        if radarDrag and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1) then
            radarDrag = false
            local vp = espGui.AbsoluteSize
            local cpos = radar.AbsolutePosition + radar.AbsoluteSize / 2
            RC.pos = { x = math.clamp(cpos.X / vp.X, 0.05, 0.95), y = math.clamp(cpos.Y / vp.Y, 0.08, 0.92) }
            radar.Position = UDim2.fromScale(RC.pos.x, RC.pos.y)
        end
    end)
    Library.Registry["radar/pos"] = { get = function() return { x = RC.pos.x, y = RC.pos.y } end,
        set = function(v) RC.pos = { x = v.x, y = v.y } end,
        validate = function(v) return type(v) == "table" and type(v.x) == "number" and type(v.y) == "number" and v.x >= 0 and v.x <= 1 and v.y >= 0 and v.y <= 1 end }
    local function updateRadar(c)
        if not RC.on or Library.Panic then radar.Visible = false; return end
        radar.Visible = true
        local size = RC.size
        radar.Size = UDim2.fromOffset(size, size)
        if not radarDrag then radar.Position = UDim2.fromScale(RC.pos.x, RC.pos.y) end
        radarStroke.Color = Library.Theme.Accent
        local look = c.CFrame.LookVector
        local fx, fz = look.X, look.Z
        local mag = math.sqrt(fx * fx + fz * fz)
        if mag < 0.001 then fx, fz = 0, -1 else fx, fz = fx / mag, fz / mag end
        local ch = LP.Character
        local myHrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local myPos = myHrp and myHrp.Position or c.CFrame.Position
        local radius = size / 2 - 5
        local range = RC.range / 0.28
        local n = 0
        local function dot(pos, col)
            if n >= 60 then return end
            n += 1
            local f = radarDots[n]
            if not f then
                f = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, radar)
                mk("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
                radarDots[n] = f
            end
            local rel = pos - myPos
            local x, y = (rel.X * (-fz) + rel.Z * fx) / range, -(rel.X * fx + rel.Z * fz) / range
            local m = math.sqrt(x * x + y * y)
            local out = m > 1
            if out then x, y = x / m, y / m end
            f.Position = UDim2.new(0.5, x * radius, 0.5, y * radius)
            f.BackgroundColor3 = col
            f.BackgroundTransparency = out and 0.6 or 0
            f.Visible = true
        end
        local pcol = (Library.ESP and Library.ESP.Jogador and Library.ESP.Jogador.name.color) or Color3.fromRGB(255, 90, 110)
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then dot(hrp.Position, pcol) end
            end
        end
        if RC.npcs then
            startNpcScan()
            for m, hum in pairs(npcs) do
                local hrp = m.Parent and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
                if hrp and hrp:IsA("BasePart") and hum.Health > 0 and m ~= ch then dot(hrp.Position, Color3.fromRGB(255, 170, 60)) end
            end
        end
        for i = n + 1, #radarDots do radarDots[i].Visible = false end
    end

    -- ---------- buscar saque (filtra por raridade) ----------
    local LF = Library.LootCfg
    local RAR = { { "Mítico", { "mythic", "mítico", "mitico" } }, { "Lendário", { "legendary", "lendário", "lendario" } }, { "Épico", { "epic", "épico", "epico" } },
        { "Raro", { "rare", "raro" } }, { "Incomum", { "uncommon", "incomum" } }, { "Comum", { "common", "comum" } } }
    local RCOL = { ["Mítico"] = Color3.fromRGB(255, 70, 110), ["Lendário"] = Color3.fromRGB(255, 170, 40), ["Épico"] = Color3.fromRGB(180, 90, 255),
        ["Raro"] = Color3.fromRGB(60, 150, 255), ["Incomum"] = Color3.fromRGB(80, 210, 110), ["Comum"] = Color3.fromRGB(205, 205, 205), ["Outros"] = Color3.fromRGB(150, 150, 150) }
    local cands, lootScan, candCount = {}, false, 0
    local function rarityOf(inst, prompt)
        local texts = {}
        for _, a in ipairs({ "Rarity", "Raridade", "Tier", "Quality", "Rank" }) do
            local v = inst:GetAttribute(a)
            if v ~= nil then texts[#texts + 1] = string.lower(tostring(v)) end
        end
        texts[#texts + 1] = string.lower(inst.Name)
        if prompt and prompt.ObjectText ~= "" then texts[#texts + 1] = string.lower(prompt.ObjectText) end
        local par = inst.Parent
        for _ = 1, 2 do
            if par and par ~= Workspace then texts[#texts + 1] = string.lower(par.Name); par = par.Parent end
        end
        for _, r in ipairs(RAR) do
            for _, kw in ipairs(r[2]) do
                for _, tx in ipairs(texts) do
                    if string.find(tx, kw, 1, true) then return r[1] end
                end
            end
        end
        return "Outros"
    end
    local function addCand(obj)
        if engineClosed or not obj:IsDescendantOf(Workspace) then return end
        if obj:IsA("ProximityPrompt") then
            local it = obj.Parent
            if it and it:IsA("Attachment") then it = it.Parent end
            if not it then return end
            local root = (it:IsA("BasePart") and it:FindFirstAncestorOfClass("Model")) or it
            if root:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(root) then return end
            local nm = (obj.ObjectText ~= "" and obj.ObjectText) or root.Name
            if not cands[root] and candCount < 2048 then cands[root] = { name = nm, prompt = obj }; candCount += 1 end
        elseif obj:IsA("Tool") then
            local mdl = obj:FindFirstAncestorOfClass("Model")
            if mdl and mdl:FindFirstChildOfClass("Humanoid") then return end
            if not cands[obj] and candCount < 2048 then cands[obj] = { name = obj.Name }; candCount += 1 end
        end
    end
    local function startLootScan()
        if lootScan then return end
        lootScan = true
        conn(Workspace.DescendantAdded, function(d) if d:IsA("ProximityPrompt") or d:IsA("Tool") then task.defer(function() if not engineClosed and d:IsDescendantOf(Workspace) then addCand(d) end end) end end)
        conn(Workspace.DescendantRemoving, function(d)
            if cands[d] then cands[d] = nil; candCount -= 1 end
            if d:IsA("ProximityPrompt") then
                for root, info in pairs(cands) do
                    if info.prompt == d then cands[root] = nil; candCount -= 1 end
                end
            end
        end)
        Library.StreamScan.start(Workspace, function() return not engineClosed end, addCand)
    end
    local function itemPart(it)
        if it:IsA("BasePart") then return it end
        if it:IsA("Model") then return it.PrimaryPart or it:FindFirstChildWhichIsA("BasePart", true) end
        return it:FindFirstChild("Handle") or it:FindFirstChildWhichIsA("BasePart", true)
    end
    local marks = {}
    local function mark(i)
        local b = marks[i]
        if b then return b end
        local gui = mk("BillboardGui", { Size = UDim2.fromOffset(150, 26), StudsOffset = Vector3.new(0, 2, 0), AlwaysOnTop = true, Enabled = false }, holder)
        b = { gui = gui, label = mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = FONT, TextSize = 13, TextStrokeTransparency = 0.35, TextColor3 = Color3.new(1, 1, 1) }, gui) }
        marks[i] = b
        return b
    end
    local lootClock, shown = 0, 0
    local function lootRefresh(c)
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local origin = hrp and hrp.Position or c.CFrame.Position
        local out = {}
        for it, info in pairs(cands) do
            if not it.Parent or not it:IsDescendantOf(Workspace) then
                cands[it] = nil; candCount -= 1
            else
                local part = itemPart(it)
                if part then
                    local m = (part.Position - origin).Magnitude * 0.28
                    if m <= LF.maxDist then
                        info.rar = info.rar or rarityOf(it, info.prompt)
                        if LF.rarities[info.rar] and (LF.query == "" or string.find(string.lower(info.name), LF.query, 1, true)) then
                            out[#out + 1] = { name = info.name, rar = info.rar, m = m, part = part }
                        end
                    end
                end
            end
        end
        table.sort(out, function(a, b) return a.m < b.m end)
        -- lista na aba
        if LF.rows then
            LF.status:Set(#out == 0 and "Nenhum item com esses filtros por perto." or (#out .. " item(ns) encontrado(s), do mais perto para o mais longe."))
            for i = 1, #LF.rows do
                local it = out[i]
                local row = LF.rows[i]
                if it then
                    local nm = string.gsub(string.gsub(string.gsub(it.name, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
                    row.Label.Text = string.format('<font color="#%s">●</font> %s  <font color="#9a9a9a">%dm · %s</font>', RCOL[it.rar]:ToHex(), nm, math.floor(it.m), it.rar)
                    row.Frame.Visible = true
                else
                    row.Frame.Visible = false
                end
            end
        end
        -- marcações no jogo
        for i = 1, 40 do
            local it = out[i]
            if it and LF.mark and not Library.Panic then
                local b = mark(i)
                b.gui.Adornee = it.part
                b.label.TextColor3 = RCOL[it.rar]
                b.label.Text = it.name .. " · " .. math.floor(it.m) .. "m"
                b.gui.Enabled = true
            elseif marks[i] then
                marks[i].gui.Enabled = false
            end
        end
        shown = #out
    end
    local function updateLoot(dt, c)
        local active = LF.mark or os.clock() < LF.until_
        if not active then
            if shown > 0 then for _, b in pairs(marks) do b.gui.Enabled = false end; shown = 0 end
            return
        end
        startLootScan()
        lootClock += dt
        if LF.force or lootClock >= 1 then
            LF.force = false
            lootClock = 0
            lootRefresh(c)
        end
    end
    Library:OnPanic(function(on) if on then for _, b in pairs(marks) do b.gui.Enabled = false end end end)

    -- ---------- laço principal ----------
    local errCount, stopped, elapsed = 0, false, 0
    Library.RenderRate = Library.RenderRate or 30
    local function renderEngine(dt)
        if stopped or engineClosed then return end
        elapsed += dt
        local slowTick = elapsed >= 1 / math.clamp(Library.RenderRate or 30, 10, 60)
        local slowDt = elapsed
        if slowTick then elapsed = 0 end
        local started = os.clock()
        local ok, err = pcall(function()
            local c = Workspace.CurrentCamera
            if not c then return end
            local vp = c.ViewportSize
            for kind in pairs(pool) do processKind(kind, Library.ESP and Library.ESP[kind], c, vp, slowTick) end
            if slowTick then
                updateRadar(c)
                updateLoot(slowDt, c)
            end
        end)
        if Library.Diagnostics then Library.Diagnostics:sampleEngine(os.clock() - started) end
        if not ok then
            errCount += 1
            warn("[BBC] ESP: " .. tostring(err))
            if errCount == 1 and Library.Diagnostics then Library.Diagnostics:record("ESP", err) end
            if errCount >= 5 then
                stopped = true
                for _, P in pairs(pool) do for _, d in pairs(P) do hideDraw(d) end end
                Library:Notify({ Title = "BBC HUB", Content = "O ESP parou por causa de um erro (veja o console).", Duration = 5 })
            end
        else
            errCount = 0
        end
    end
    local renderName = "BBC_ESP_" .. tostring({})
    local bound = pcall(function() RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, renderEngine) end)
    if not bound then conn(RunService.RenderStepped, renderEngine) end

    -- desliga o motor de vez: laço, conexões, GUIs do ESP/radar e registros do radar
    local function stopEngine()
        if engineClosed then return end
        engineClosed = true
        Actions.alive = false
        stopped = true
        if bound then pcall(function() RunService:UnbindFromRenderStep(renderName) end) end
        for _, c in ipairs(engineConns) do pcall(function() c:Disconnect() end) end
        for _, g in ipairs(engineGuis) do pcall(function() g:Destroy() end) end
        for _, P in pairs(pool) do for _, d in pairs(P) do pcall(hideDraw, d) end end
        for k in pairs(pool) do pool[k] = nil end
        Library.Registry["radar/pos"] = nil
        table.clear(Library._panicGuis)
        Library._panicZone = nil
        for _, fn in ipairs(Actions.cleanups or {}) do pcall(fn) end
    end
    Library._stopEngine = stopEngine
end

Library.Tr = tr
pcall(function() Window:FinishLoading() end)   -- fecha a intro: o cartão vira o menu
Library:Notify({ Title = "BBC HUB", Content = tr("Interface carregada."), Duration = 4 })
if Library.GuiProtection.unavailable > 0 or Library.GuiProtection.failed > 0 then
    Library:Notify({ Title = "BBC HUB", Content = tr("Proteção de interface indisponível ou falhou; o menu pode ser detectado."), Duration = 8 })
end
