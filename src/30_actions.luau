-- ============ 30_actions.luau :: Lógica de movimento, mundo, extras, combate e servidores ============
local buildProfile
local Actions = {}
-- Inicialização isolada da função principal: o compilador do loadstring não
-- precisa manter os locais dos módulos anteriores no mesmo quadro de registros.
local function initializeActions()
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local StatsService = game:GetService("Stats")
    local LP = Players.LocalPlayer
    local VERSION = Config.Version or "0.0.8.2"
    local ACCESS = Config.Access or "FREE"

    -- limpeza: o "Sair" e o stopEngine chamam estas funções
    local CLEANUPS = {}
    Actions.alive = true
    Actions.connections = {}
    Actions.tracked = {}
    function Actions.trackConn(conn)
        if not Actions.alive then pcall(function() conn:Disconnect() end)
        else
            if Actions.tracked[conn] then return conn end
            for old in pairs(Actions.tracked) do if not old.Connected then Actions.tracked[old] = nil end end
            Actions.tracked[conn] = true
        end
        return conn
    end
    function Actions.connect(signal, callback)
        local conn = Library.Guards.connect(signal, callback,
            function() return Actions.alive end,
            function(stage, err)
                warn("[BBC] Evento " .. stage .. ": " .. err)
                if Library.Diagnostics then Library.Diagnostics:record("evento " .. stage, err) end
                if stage == "interrompido" then
                    pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = "Evento interrompido após erros; veja o console.", Duration = 5 }) end)
                end
            end)
        return Actions.trackConn(conn)
    end
    function Actions.guardStep(name, state, callback, stop)
        return Library.Guards.step(state, callback, function(stage, err)
            warn("[BBC] " .. name .. " " .. stage .. ": " .. err)
            if Library.Diagnostics then Library.Diagnostics:record(name .. " " .. stage, err) end
            if stage == "interrompido" then
                if stop then pcall(stop) end
                Library.Safety:disable(name)
                pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = name .. " interrompido após erros; veja o console.", Duration = 5 }) end)
            end
        end)
    end
    Actions.originals = setmetatable({}, { __mode = "k" })
    function Actions.setProperty(obj, prop, value)
        if not obj then return false end
        local saved = Actions.originals[obj]
        if not saved then saved = {}; Actions.originals[obj] = saved end
        local entry = saved[prop]
        if not entry then
            local ok, old = pcall(function() return obj[prop] end)
            if not ok then return false end
            entry = { value = old }
            saved[prop] = entry
        end
        local ok = pcall(function() obj[prop] = value end)
        if ok then entry.last, entry.applied = value, true end
        return ok
    end
    function Actions.restoreProperty(obj, prop)
        local saved = obj and Actions.originals[obj]
        local entry = saved and saved[prop]
        if not entry then return end
        -- Não sobrescrever uma alteração mais recente do próprio jogo.
        pcall(function()
            if entry.applied and obj[prop] == entry.last then obj[prop] = entry.value end
        end)
        saved[prop] = nil
    end
    local function onCleanup(fn) CLEANUPS[#CLEANUPS + 1] = fn end

    -- Ajustes limitados também quando aplicados por perfil, não apenas pelo slider.
    Actions.adjustments = {
        speed = {2.2, 1, 4}, sprint = {1.6, 1, 4}, fly = {60, 10, 120}, climb = {40, 5, 80}, cameraDistance = {12, 3, 40},
        brightness = {5, 0, 10}, clockTime = {14, 0, 24}, shadowSoftness = {0.5, 0, 1}, fogDensity = {0.6, 0, 1}, haze = {0.4, 0, 10},
        cloudCover = {0.5, 0, 1}, bloom = {0.8, 0, 5}, blur = {12, 0, 56}, saturation = {0.25, -1, 1}, contrast = {0.1, -1, 1},
        focus = {60, 0, 500}, farIntensity = {0.4, 0, 1}, rays = {0.25, 0, 1}, raysSpread = {0.6, 0, 1},
        swapInterval = {0.35, 0.2, 5}, peekDepth = {4, 0, 10}, ghostTransparency = {0.5, 0, 1},
        throwRange = {60, 10, 100}, hitDuration = {0.12, 0.05, 1}, hotbarSlots = {8, 1, 8},
        reticleSize = {5, 2, 30}, ringThickness = {1.5, 0.5, 5}, trailLifetime = {0.5, 0.1, 3},
        thirdZoom = {300, 10, 500}, offsetDistance = {3, 0, 10}, undergroundHeight = {-6, -10, 0}, spinDegrees = {6, 0, 15},
        lootDistance = {14, 1, 14}, lootInterval = {2, 2, 10}, reloadInterval = {5, 5, 30},
        refillValue = {999, 0, 999}, respawnDelay = {0.5, 0.5, 10}, auraRange = {12, 1, 12},
        bossOpacity = {60, 0, 100}, exitOpacity = {60, 0, 100}, skyStars = {3000, 0, 5000},
        shadowGearSoftness = {0.5, 0, 1}, toneWarmth = {100, 0, 100}, waterTransparency = {1, 0, 1},
        panelTextSize = {11, 8, 24}, panelInterval = {0.8, 0.5, 5}, charTransparency = {0, 0, 1}, handTransparency = {0, 0, 1}, heldTransparency = {0, 0, 1},
        firstPersonTransparency = {0, 0, 1}, ignoreObstacleDistance = {10000, 0, 10000}, panicTapWindow = {1.2, 0.8, 3}, panicZoneWidth = {140, 100, 300}, pauseResume = {0, 0, 1}, hitFxDuration = {0.3, 0.1, 1}, hitFxTransparency = {0.4, 0, 1},
        roleCriador = {4, 1, 10}, roleTestador = {4, 1, 10}, roleModerador = {4, 1, 10}, roleTrapaceiro = {4, 1, 10},
        joinDuration = {3, 1, 10}, targetDuration = {1.2, 1, 10}, killDuration = {2, 1, 10}, targetTextSize = {11, 8, 24}, damageTextSize = {14, 8, 30},
    }
    function Actions.setAdjustment(key, value)
        local entry = Actions.adjustments[key]
        if not entry or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
        value = math.clamp(value, entry[2], entry[3])
        entry[1] = (key == "hotbarSlots" or key == "refillValue" or key == "skyStars") and math.floor(value) or value
        if Actions.refreshAdjustment then Actions.refreshAdjustment(key) end
        return true
    end
    function Actions.getAdjustment(key)
        local entry = Actions.adjustments[key]
        return entry and entry[1]
    end

    -- ---------- Movimento / jogador: lógica de verdade para os botões ----------
    local MV = {
        speed = false, sprint = false, jumps = false, air = false, fly = false,
        noFall = false, ground = false, spider = false, jesus = false,
        third = false, camFree = false, antiAfk = false, respawn = false, noDrown = false,
    }
    local baseWalk, baseJump = 16, 50
    local flyLV, afkOn = nil, false
    local lastJump, preFallHealth = 0, nil
    local freeYaw, freePitch = 0, 0.3

    function Actions.restoreWalk()
        local hum, original, lastApplied = Actions.walkHum, Actions.walkOriginal, Actions.walkApplied
        if hum and original ~= nil and lastApplied ~= nil then
            pcall(function() if hum.Parent and hum.WalkSpeed == lastApplied then hum.WalkSpeed = original end end)
        end
        Actions.walkHum, Actions.walkOriginal, Actions.walkApplied = nil, nil, nil
    end
    function Actions.restoreSwim()
        local hum, original = Actions.swimHum, Actions.swimOriginal
        if hum and original ~= nil then
            pcall(function()
                if hum.Parent and not hum:GetStateEnabled(Enum.HumanoidStateType.Swimming) then
                    hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, original)
                end
            end)
        end
        Actions.swimHum, Actions.swimOriginal = nil, nil
    end
    local function mvHum()
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        return ch, hum, hrp
    end
    local function stopFly()
        if flyLV then pcall(function() flyLV:Destroy() end); flyLV = nil end
        if Actions.flyAttachment then pcall(function() Actions.flyAttachment:Destroy() end); Actions.flyAttachment = nil end
    end
    local function startFly()
        stopFly()
        local ch, hum, hrp = mvHum()
        if not (hum and hrp) then return end
        local ok, lv = pcall(function()
            local att = Instance.new("Attachment")
            Actions.flyAttachment = att
            att.Name = "BBCFlyAtt"; att.Parent = hrp
            local o = Instance.new("LinearVelocity")
            o.Name = "BBCFly"; o.Attachment0 = att; o.MaxForce = math.huge; o.VectorVelocity = Vector3.zero
            o.Parent = hrp
            return o
        end)
        flyLV = ok and lv or nil
        if not ok then stopFly() end
    end
    local function applyCamera()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        pcall(function()
            if MV.third then Actions.setProperty(LP, "CameraMaxZoomDistance", Actions.getAdjustment("thirdZoom"))
            else Actions.restoreProperty(LP, "CameraMaxZoomDistance") end
            if MV.camFree then Actions.setProperty(cam, "CameraType", Enum.CameraType.Scriptable)
            else Actions.restoreProperty(cam, "CameraType") end
        end)
    end
    local VirtualUser = nil
    pcall(function() VirtualUser = game:GetService("VirtualUser") end)
    local function afkLoop()
        if not MV.antiAfk or afkOn or not VirtualUser or not Library.Safety:allow("Anti AFK", true) then return end
        afkOn = true
        task.spawn(function()
            pcall(function() VirtualUser:CaptureController() end)
            while Actions.alive and MV.antiAfk and Library.Safety:allow("Anti AFK", true) do
                pcall(function()
                    VirtualUser:Button2Down(Vector2.new(), Workspace.CurrentCamera)
                    task.wait(0.2)
                    VirtualUser:Button2Up(Vector2.new(), Workspace.CurrentCamera)
                end)
                task.wait(60)
            end
            afkOn = false
        end)
    end

    Actions.connections.movement = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
        local ok, err = pcall(function()
            local ch, hum, hrp = mvHum()
            if not (ch and hum and hrp) then
                Actions.restoreWalk(); Actions.restoreSwim(); stopFly()
                return
            end
            local st = hum:GetState()

            -- velocidade / sprint
            if MV.speed or MV.sprint then
                if Actions.walkHum ~= hum then
                    Actions.restoreWalk()
                    Actions.walkHum, Actions.walkOriginal = hum, hum.WalkSpeed
                end
                local original = Actions.walkOriginal
                local ws = original
                if MV.speed then ws = original * Actions.getAdjustment("speed") end
                if MV.sprint then ws = math.max(ws, original * Actions.getAdjustment("sprint")) end
                if hum.WalkSpeed ~= ws then hum.WalkSpeed = ws end
                Actions.walkApplied = ws
            elseif Actions.walkHum then
                Actions.restoreWalk()
            end

            -- pulo duplo (pulos seguidos)
            if MV.jumps and st == Enum.HumanoidStateType.Freefall and os.clock() - lastJump > 0.25 then
                lastJump = os.clock()
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + baseJump, v.Z)
            end
            -- controle no ar: mantém o movimento horizontal
            if MV.air and st == Enum.HumanoidStateType.Freefall then
                local dir = hum.MoveDirection
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * hum.WalkSpeed, v.Y, dir.Z * hum.WalkSpeed)
            end
            -- aranha: segura a subida encostado na parede
            if MV.spider and st == Enum.HumanoidStateType.Freefall and hum.MoveDirection.Magnitude > 0.1 then
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(v.X, Actions.getAdjustment("climb"), v.Z)
            end
            -- jesus: não nada, fica em cima da água
            if MV.jesus and st == Enum.HumanoidStateType.Swimming then
                hum:ChangeState(Enum.HumanoidStateType.Landed)
            end
            -- voar
            if MV.fly then
                if flyLV and flyLV.Parent ~= hrp then stopFly() end
                if not flyLV then startFly() end
                if flyLV then
                    local dir = hum.MoveDirection
                    local v = Vector3.new(dir.X, 0, dir.Z) * Actions.getAdjustment("fly")
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v += Vector3.new(0, Actions.getAdjustment("fly"), 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v += Vector3.new(0, -Actions.getAdjustment("fly"), 0) end
                    flyLV.VectorVelocity = v
                end
                if st ~= Enum.HumanoidStateType.Flying then hum:ChangeState(Enum.HumanoidStateType.Flying) end
            else
                stopFly()
            end
            -- sempre no chão
            if MV.ground and st == Enum.HumanoidStateType.Freefall then
                hum:ChangeState(Enum.HumanoidStateType.Landed)
            end
            -- sem dano de queda (guarda a vida antes de cair)
            if MV.noFall then
                if st == Enum.HumanoidStateType.Freefall then
                    if preFallHealth == nil then preFallHealth = hum.Health end
                elseif st == Enum.HumanoidStateType.Landed and preFallHealth ~= nil then
                    if hum.Health < preFallHealth then hum.Health = preFallHealth end
                    preFallHealth = nil
                end
            else
                preFallHealth = nil
            end
            -- não se afogar
            if MV.noDrown then
                if Actions.swimHum ~= hum then
                    Actions.restoreSwim()
                    Actions.swimHum, Actions.swimOriginal = hum, hum:GetStateEnabled(Enum.HumanoidStateType.Swimming)
                end
                hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
            elseif Actions.swimHum then
                Actions.restoreSwim()
            end
            -- câmera livre (mouse gira em volta do personagem)
            if MV.camFree then
                local md = UserInputService:GetMouseDelta()
                freeYaw += md.X * 0.02
                freePitch = math.clamp(freePitch + md.Y * 0.02, -1.2, 1.2)
                local head = hrp.Position + Vector3.new(0, 2, 0)
                local off = Vector3.new(math.sin(freeYaw) * math.cos(freePitch), math.sin(freePitch), math.cos(freeYaw) * math.cos(freePitch)) * Actions.getAdjustment("cameraDistance")
                Workspace.CurrentCamera.CFrame = CFrame.new(head + off, head)
            end
        end)
        if ok then
            Actions.movementErrors = 0
        else
            Actions.movementErrors = (Actions.movementErrors or 0) + 1
            if Actions.movementErrors == 1 then warn("[BBC] Movimento: " .. tostring(err)) end
            if Actions.movementErrors >= 5 then
                Actions.connections.movement:Disconnect()
                stopFly()
                Actions.restoreWalk(); Actions.restoreSwim()
                Library.Safety:disableTracked()
                pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = "Movimento interrompido após erros; veja o console.", Duration = 5 }) end)
            end
        end
    end))

    local PLAYER_ACTIONS = {
        ["Hack de velocidade"] = function(v) MV.speed = v; if not MV.speed and not MV.sprint then Actions.restoreWalk() end end,
        ["Sprint automático"] = function(v) MV.sprint = v; if not MV.speed and not MV.sprint then Actions.restoreWalk() end end,
        ["Pulos seguidos"] = function(v) MV.jumps = v end,
        ["Controle no ar"] = function(v) MV.air = v end,
        ["Voar"] = function(v) MV.fly = v; if not v then stopFly() end end,
        ["Sem dano de queda"] = function(v) MV.noFall = v end,
        ["Sempre no chão"] = function(v) MV.ground = v end,
        ["Jesus"] = function(v) MV.jesus = v end,
        ["Aranha"] = function(v) MV.spider = v end,
        ["Terceira pessoa"] = function(v) MV.third = v; applyCamera() end,
        ["Câmera livre"] = function(v) MV.camFree = v; applyCamera() end,
        ["Anti AFK"] = function(v) MV.antiAfk = v; afkLoop() end,
        ["Renascer automático"] = function(v) MV.respawn = v end,
        ["Não se afogar"] = function(v) MV.noDrown = v; if not v then Actions.restoreSwim() end end,
    }

    -- ---------- Mundo / iluminação: lógica de verdade para os botões ----------
    local Lighting = game:GetService("Lighting")
    local Terrain = Workspace.Terrain
    local WORLD = {
        grama = false, minas = false, jogadores = false, chefes = false, saida = false,
        luz = false, sol = false, sombras = false, render = false, neblina = false,
        atmosfera = false, ceu = false, nuvens = false, florescer = false, desfoque = false,
        cor = false, profundidade = false, raios = false, tonalidade = false, master = true,
    }
    local WORLD_COLORS = {
        grama = Color3.fromRGB(72, 160, 76), areia = Color3.fromRGB(214, 190, 120),
        rocha = Color3.fromRGB(120, 120, 126), terra = Color3.fromRGB(110, 78, 52),
        agua = Color3.fromRGB(40, 70, 75), folhas = Color3.fromRGB(70, 150, 70),
        troncos = Color3.fromRGB(100, 70, 45),
    }
    local FX = {}
    local function mkFx(class, name, parent, disabled)
        local instance
        local ok, o = pcall(function()
            instance = Instance.new(class)
            instance.Name = name
            -- Clouds e os efeitos começam desligados antes de serem associados:
            -- evita uma ativação transitória e conflito na criação da interface.
            if disabled then instance.Enabled = false end
            instance.Parent = parent
            return instance
        end)
        if not ok and instance then pcall(function() instance:Destroy() end) end
        FX[name] = ok and o or nil
        return FX[name]
    end
    mkFx("BloomEffect", "BBC_Bloom", Lighting, true)
    mkFx("BlurEffect", "BBC_Blur", Lighting, true)
    mkFx("ColorCorrectionEffect", "BBC_CorAjuste", Lighting, true)
    mkFx("ColorCorrectionEffect", "BBC_CorTon", Lighting, true)
    mkFx("DepthOfFieldEffect", "BBC_Profundidade", Lighting, true)
    mkFx("SunRaysEffect", "BBC_Raios", Lighting, true)
    -- Atmosphere e Sky não possuem Enabled: ficam fora da árvore até o uso.
    mkFx("Atmosphere", "BBC_Atmosfera", nil)
    mkFx("Sky", "BBC_Ceu", nil)

    -- Reutiliza as nuvens do jogo, se existirem, para não disputar com uma
    -- segunda instância. Apenas a instância criada pelo hub é destruída.
    local cloudTarget
    local function applyClouds(enabled, cover)
        if cloudTarget and (not enabled or cloudTarget.Parent ~= Terrain) then
            Actions.restoreProperty(cloudTarget, "Cover")
            Actions.restoreProperty(cloudTarget, "Enabled")
            if cloudTarget == FX.BBC_Nuvens then
                pcall(function() cloudTarget:Destroy() end)
                FX.BBC_Nuvens = nil
            end
            cloudTarget = nil
        end
        if not enabled then return end
        if not cloudTarget then
            local ok, children = pcall(function() return Terrain:GetChildren() end)
            if not ok then return end -- não criar uma duplicata se não pudermos verificar
            local first
            for _, child in ipairs(children) do
                if child:IsA("Clouds") then
                    first = first or child
                    if child.Enabled then cloudTarget = child; break end
                end
            end
            cloudTarget = cloudTarget or first
            if not cloudTarget then
                cloudTarget = mkFx("Clouds", "BBC_Nuvens", nil, true)
                if not cloudTarget then return end
                local parented = pcall(function() cloudTarget.Parent = Terrain end)
                if not parented then
                    pcall(function() cloudTarget:Destroy() end)
                    FX.BBC_Nuvens, cloudTarget = nil, nil
                    return
                end
            end
        end
        Actions.setProperty(cloudTarget, "Cover", cover)
        Actions.setProperty(cloudTarget, "Enabled", true)
    end

    local function applyLighting()
        pcall(function()
            local m = WORLD.master
            local function override(prop, enabled, value)
                if enabled then Actions.setProperty(Lighting, prop, value)
                else Actions.restoreProperty(Lighting, prop) end
            end
            override("Brightness", m and WORLD.luz, Actions.getAdjustment("brightness"))
            override("Ambient", m and WORLD.luz, Color3.fromRGB(110, 110, 110))
            override("OutdoorAmbient", m and WORLD.luz, Color3.fromRGB(110, 110, 110))
            override("ClockTime", m and WORLD.sol, Actions.getAdjustment("clockTime"))
            override("GeographicLatitude", m and WORLD.sol, 0)
            override("GlobalShadows", m and WORLD.sombras, true)
            override("ShadowSoftness", m and (WORLD.render or WORLD.sombras), Actions.getAdjustment(WORLD.sombras and "shadowGearSoftness" or "shadowSoftness"))

            local atmo = FX.BBC_Atmosfera
            if atmo then
                atmo.Parent = (m and (WORLD.atmosfera or WORLD.neblina)) and Lighting or nil
                atmo.Density = (m and WORLD.neblina) and Actions.getAdjustment("fogDensity") or 0.35
                atmo.Color = Color3.fromRGB(188, 200, 220)
                atmo.Decay = Color3.fromRGB(90, 110, 140)
                atmo.Glare = 0.2
                atmo.Haze = Actions.getAdjustment("haze")
            end
            if FX.BBC_Ceu then
                FX.BBC_Ceu.StarCount = Actions.getAdjustment("skyStars")
                FX.BBC_Ceu.Parent = (m and WORLD.ceu) and Lighting or nil
            end
            applyClouds(m and WORLD.nuvens, Actions.getAdjustment("cloudCover"))
            if FX.BBC_Bloom then
                FX.BBC_Bloom.Enabled = m and WORLD.florescer
                FX.BBC_Bloom.Intensity = Actions.getAdjustment("bloom")
                FX.BBC_Bloom.Size = 24
                FX.BBC_Bloom.Threshold = 2
            end
            if FX.BBC_Blur then
                FX.BBC_Blur.Enabled = m and WORLD.desfoque
                FX.BBC_Blur.Size = Actions.getAdjustment("blur")
            end
            if FX.BBC_CorAjuste then
                FX.BBC_CorAjuste.Enabled = m and WORLD.cor
                FX.BBC_CorAjuste.Saturation = Actions.getAdjustment("saturation")
                FX.BBC_CorAjuste.Contrast = Actions.getAdjustment("contrast")
            end
            if FX.BBC_CorTon then
                FX.BBC_CorTon.Enabled = m and WORLD.tonalidade
                local warmth = Actions.getAdjustment("toneWarmth") / 100
                FX.BBC_CorTon.TintColor = Color3.new(1, 1 - (20 / 255) * warmth, 1 - (45 / 255) * warmth)
            end
            if FX.BBC_Profundidade then
                FX.BBC_Profundidade.Enabled = m and WORLD.profundidade
                FX.BBC_Profundidade.FarIntensity = Actions.getAdjustment("farIntensity")
                FX.BBC_Profundidade.FocusDistance = Actions.getAdjustment("focus")
                FX.BBC_Profundidade.InFocusRadius = 40
            end
            if FX.BBC_Raios then
                FX.BBC_Raios.Enabled = m and WORLD.raios
                FX.BBC_Raios.Intensity = Actions.getAdjustment("rays")
                FX.BBC_Raios.Spread = Actions.getAdjustment("raysSpread")
            end
        end)
    end

    -- terreno: cores de material de verdade
    local TERRAIN_MATS = {
        grama = Enum.Material.Grass, areia = Enum.Material.Sand,
        rocha = Enum.Material.Rock, terra = Enum.Material.Ground,
    }
    local function paintTerrain(key, c)
        pcall(function()
            if key == "agua" then
                Actions.setProperty(Terrain, "WaterColor", c)
            else
                local mat = TERRAIN_MATS[key]
                if mat then
                    Actions.terrainColors = Actions.terrainColors or {}
                    if Actions.terrainColors[mat] == nil then Actions.terrainColors[mat] = Terrain:GetMaterialColor(mat) end
                    Terrain:SetMaterialColor(mat, c)
                end
            end
        end)
    end

    -- folhas / troncos: pinta as partes com o material correspondente
    local plantLeaf, plantTrunk = {}, {}
    local function scanPlants()
        plantLeaf, plantTrunk = {}, {}
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local m = d.Material
                if m == Enum.Material.LeafyGrass or m == Enum.Material.Grass then
                    plantLeaf[#plantLeaf + 1] = d
                elseif m == Enum.Material.Wood or m == Enum.Material.WoodPlanks then
                    plantTrunk[#plantTrunk + 1] = d
                end
            end
        end
    end
    local function paintPlants(key, c)
        local list = key == "folhas" and plantLeaf or plantTrunk
        if #list == 0 then scanPlants(); list = key == "folhas" and plantLeaf or plantTrunk end
        for _, d in ipairs(list) do Actions.setProperty(d, "Color", c) end
    end

    -- Guardar objetos locais em vez de destruí-los, para poder restaurá-los.
    Actions.hidden = { grass = {}, mines = {} }
    function Actions.hideNamed(kind, d, patterns)
        if not (d:IsA("BasePart") or d:IsA("Model")) or not d.Parent or not d:IsDescendantOf(Workspace) then return end
        if LP.Character and d:IsDescendantOf(LP.Character) then return end
        local low = string.lower(d.Name)
        for _, pattern in ipairs(patterns) do
            if string.find(low, pattern, 1, true) then
                Actions.hidden[kind][d] = d.Parent
                d.Parent = nil
                return
            end
        end
    end
    function Actions.restoreHidden(kind)
        for obj, parent in pairs(Actions.hidden[kind]) do
            pcall(function() if obj.Parent == nil and parent.Parent then obj.Parent = parent end end)
        end
        table.clear(Actions.hidden[kind])
    end
    -- Evento primeiro, varredura incremental depois: cancelar invalida tanto
    -- callbacks pendentes quanto o restante da caminhada antes de restaurar.
    Actions.hiddenTokens, Actions.hiddenConns = {}, {}
    function Actions.setHiddenScan(kind, enabled, patterns)
        local token = (Actions.hiddenTokens[kind] or 0) + 1
        Actions.hiddenTokens[kind] = token
        local previous = Actions.hiddenConns[kind]
        if previous then previous:Disconnect(); Actions.hiddenConns[kind] = nil end
        if not enabled then Actions.restoreHidden(kind); return end
        local function active()
            return Actions.alive and not Library.Panic and Actions.hiddenTokens[kind] == token
        end
        local function visit(d)
            if active() then Actions.hideNamed(kind, d, patterns) end
        end
        Actions.hiddenConns[kind] = Actions.connect(Workspace.DescendantAdded, visit)
        Library.StreamScan.start(Workspace, active, visit)
    end
    local function applyGrama(v)
        Actions.setHiddenScan("grass", v, { "grass", "grama" })
    end
    local function applyMinas(v)
        Actions.setHiddenScan("mines", v, { "mine", "mina", "landmine", "tnt", "explosive" })
    end
    local function applyJogadores(v)
        if not v then return end
        pcall(function() Players.CharacterAutoLoads = true end)
        pcall(function() if LP.Character then LP:LoadCharacter() end end)
        Library:Notify({ Title = "MUNDO", Content = "Personagem recarregado (" .. #Players:GetPlayers() .. " jogadores).", Duration = 4 })
    end

    local bossHigh, exitHigh = {}, {}
    local function clearHigh(list)
        for _, h in ipairs(list) do pcall(function() h:Destroy() end) end
        for i = 1, #list do list[i] = nil end
    end
    local function markHigh(list, found, color, transparency)
        for _, d in ipairs(found) do
            pcall(function()
                local h = Instance.new("Highlight")
                h.Name = "BBC_HL"
                h.FillColor = color
                h.FillTransparency = transparency
                h.OutlineColor = Color3.fromRGB(22, 18, 18)
                h.OutlineTransparency = 0.1
                h.Enabled = not Library.Panic
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent = d
                list[#list + 1] = h
            end)
        end
    end
    function Actions.scanNamedMarks(v, list, patterns, color, adjustment, tokenKey, title)
        Actions[tokenKey] = (Actions[tokenKey] or 0) + 1
        local token = Actions[tokenKey]
        clearHigh(list)
        if not v then return end
        task.spawn(function()
            Library.StreamScan.run(Workspace, function()
                return Actions.alive and Actions[tokenKey] == token
            end, function(d)
                if #list >= 100 or not d:IsDescendantOf(Workspace) or not (d:IsA("Model") or d:IsA("BasePart")) then return end
                local low = string.lower(d.Name)
                for _, pattern in ipairs(patterns) do
                    if string.find(low, pattern, 1, true) then
                        markHigh(list, {d}, color, Actions.getAdjustment(adjustment) / 100)
                        break
                    end
                end
            end)
            if Actions.alive and Actions[tokenKey] == token and not Library.Panic then
                Library:Notify({ Title = "MUNDO", Content = #list .. " " .. title .. (#list >= 100 and " (limite)" or "") .. ".", Duration = 5 })
            end
        end)
    end
    local function applyChefes(v)
        Actions.scanNamedMarks(v, bossHigh, { "boss", "chefe", "chefao", "champion" }, Color3.fromRGB(255, 120, 30), "bossOpacity", "bossToken", "chefes marcados")
    end
    local function applySaida(v)
        Actions.scanNamedMarks(v, exitHigh, { "exit", "saida", "portal" }, Color3.fromRGB(70, 220, 90), "exitOpacity", "exitToken", "saídas marcadas")
    end

    local WORLD_ACTIONS = {
        ["Sem grama"] = function(v) WORLD.grama = v; applyGrama(v) end,
        ["Desativar minas"] = function(v) WORLD.minas = v; applyMinas(v) end,
        ["Carregar jogadores"] = function(v) WORLD.jogadores = v; applyJogadores(v) end,
        ["Buscar chefes"] = function(v) WORLD.chefes = v; applyChefes(v) end,
        ["Pontos de saída"] = function(v) WORLD.saida = v; applySaida(v) end,
        ["Luz"] = function(v) WORLD.luz = v; applyLighting() end,
        ["Hora e sol"] = function(v) WORLD.sol = v; applyLighting() end,
        ["Sombras"] = function(v) WORLD.sombras = v; applyLighting() end,
        ["Renderização"] = function(v) WORLD.render = v; applyLighting() end,
        ["Neblina"] = function(v) WORLD.neblina = v; applyLighting() end,
        ["Atmosfera"] = function(v) WORLD.atmosfera = v; applyLighting() end,
        ["Céu"] = function(v) WORLD.ceu = v; applyLighting() end,
        ["Nuvens"] = function(v) WORLD.nuvens = v; applyLighting() end,
        ["Florescer"] = function(v) WORLD.florescer = v; applyLighting() end,
        ["Desfoque"] = function(v) WORLD.desfoque = v; applyLighting() end,
        ["Ajuste de cor"] = function(v) WORLD.cor = v; applyLighting() end,
        ["Profundidade"] = function(v) WORLD.profundidade = v; applyLighting() end,
        ["Raios de sol"] = function(v) WORLD.raios = v; applyLighting() end,
        ["Tonalidade"] = function(v) WORLD.tonalidade = v; applyLighting() end,
        ["Remover água"] = function(v)
            WORLD.aguaOff = v
            pcall(function()
                if v then
                    Actions.setProperty(Terrain, "WaterTransparency", Actions.getAdjustment("waterTransparency"))
                    Actions.setProperty(Terrain, "WaterWaveSize", 0)
                    Actions.setProperty(Terrain, "WaterWaveSpeed", 0)
                else
                    for _, prop in ipairs({ "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed" }) do
                        Actions.restoreProperty(Terrain, prop)
                    end
                end
            end)
        end,
    }

    -- ---------- Extras: lógica de verdade para os botões ----------
    local StarterGui = game:GetService("StarterGui")
    local SoundService = game:GetService("SoundService")
    local EXTRA = { swap = false, effects = false, joinConn = nil, panicFn = nil }
    local function say(text)
        pcall(function() Library:Notify({ Title = "BBC HUB", Content = text, Duration = 3 }) end)
    end

    -- ===== sons (IDs definidos na aba SONS) =====
    local SOUND_TOGGLES = { Jump = false, Pegadas = false, Pouso = false, Capacete = false,
        ["Tiro na cabeça"] = false, ["Tiro no corpo"] = false, Abate = false, Disparo = false, ["Acerto com sangue"] = false }
    local SOUND_IDS, soundObjs, soundVolumes = {}, {}, {}
    function Actions.setSoundVolume(name, value)
        if SOUND_TOGGLES[name] == nil or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
        soundVolumes[name] = math.clamp(value, 0, 100) / 100
        local sound = soundObjs[name]
        if sound then pcall(function() sound.Volume = soundVolumes[name] end) end
        return true
    end
    local SOUND_NAMES = { "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue" }
    local function getSound(name)
        local id = SOUND_IDS[name]
        if not id then return nil end
        local s = soundObjs[name]
        if not s then
            local ok, o = pcall(function()
                local i = Instance.new("Sound")
                i.Name = "BBC_SND"
                i.SoundId = "rbxassetid://" .. tostring(id)
                i.Volume = soundVolumes[name] or 0.6
                i.Parent = SoundService
                return i
            end)
            s = ok and o or nil
            soundObjs[name] = s
        end
        return s
    end
    local function playSound(name)
        if not SOUND_TOGGLES[name] then return end
        local s = getSound(name)
        if s then pcall(function() s:Play() end) end
    end
    local function setSoundId(text)
        local name, id = string.match(tostring(text or ""), "^%s*(.-)%s+([0-9]+)%s*$")
        if not id then id = string.match(tostring(text or ""), "^%s*([0-9]+)%s*$") end
        if not id then say("Use: Nome ID  ou  ID"); return end
        if name and name ~= "" then SOUND_IDS[name] = id else for _, n in ipairs(SOUND_NAMES) do SOUND_IDS[n] = id end end
        for _, sound in pairs(soundObjs) do pcall(function() sound:Destroy() end) end
        soundObjs = {}
        say("Som definido: " .. ((name and name ~= "") and name or "todos"))
    end
    local function hookCharSounds(char)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
        if not Actions.alive or LP.Character ~= char or not hum or not hum:IsA("Humanoid") then return end
        if Actions.charSoundConn then Actions.charSoundConn:Disconnect() end
        Actions.charSoundConn = Actions.connect(hum.StateChanged, function(_, new)
            if new == Enum.HumanoidStateType.Jumping then playSound("Jump")
            elseif new == Enum.HumanoidStateType.Landed then playSound("Pouso") end
        end)
        task.spawn(function()
            while Actions.alive and LP.Character == char and char.Parent and hum.Parent do
                if SOUND_TOGGLES["Pegadas"] and hum.MoveDirection.Magnitude > 0.1 and hum:GetState() == Enum.HumanoidStateType.Running then
                    playSound("Pegadas")
                    task.wait(math.clamp(30 / math.max(hum.WalkSpeed, 1), 0.15, 0.8))
                else
                    task.wait(0.2)
                end
            end
        end)
    end
    Actions.soundToolConns = setmetatable({}, { __mode = "k" })
    local function hookTool(tool)
        if not tool:IsA("Tool") or Actions.soundToolConns[tool] then return end
        local conns = {}
        Actions.soundToolConns[tool] = conns
        conns[#conns + 1] = Actions.connect(tool.Activated, function()
            if tool.Parent == LP.Character then playSound("Disparo") end
        end)
        conns[#conns + 1] = Actions.connect(tool.Equipped, function()
            local low = string.lower(tool.Name)
            if string.find(low, "helmet", 1, true) or string.find(low, "capacete", 1, true) or string.find(low, "hat", 1, true) then
                playSound("Capacete")
            end
        end)
        local function unhook()
            for _, conn in ipairs(conns) do conn:Disconnect() end
            Actions.soundToolConns[tool] = nil
        end
        conns[#conns + 1] = Actions.connect(tool.Destroying, unhook)
        conns[#conns + 1] = Actions.connect(tool.AncestryChanged, function()
            task.defer(function()
                if not Actions.alive or Actions.soundToolConns[tool] ~= conns then return end
                if tool.Parent ~= LP.Character and tool.Parent ~= LP:FindFirstChildOfClass("Backpack") then unhook() end
            end)
        end)
    end
    local function hookCharTools(char)
        if not Actions.alive or LP.Character ~= char then return end
        if Actions.soundCharConn then Actions.soundCharConn:Disconnect(); Actions.soundCharConn = nil end
        if Actions.soundBackpackConn then Actions.soundBackpackConn:Disconnect(); Actions.soundBackpackConn = nil end
        local function scan(parent)
            if not parent then return end
            for _, t in ipairs(parent:GetChildren()) do if t:IsA("Tool") then hookTool(t) end end
        end
        scan(char); scan(LP:FindFirstChild("Backpack"))
        Actions.soundCharConn = Actions.connect(char.ChildAdded, function(c) if c:IsA("Tool") then hookTool(c) end end)
        local bp = LP:FindFirstChild("Backpack")
        if bp then Actions.soundBackpackConn = Actions.connect(bp.ChildAdded, function(c) if c:IsA("Tool") then hookTool(c) end end) end
    end
    local function hookCharExtra(char)
        hookCharSounds(char)
        hookCharTools(char)
    end
    if LP.Character then task.spawn(hookCharExtra, LP.Character) end
    Actions.trackConn(Actions.connect(LP.CharacterAdded, hookCharExtra))
    Actions.connect(LP.ChildAdded, function(child)
        if child:IsA("Backpack") and LP.Character then hookCharTools(LP.Character) end
    end)
    local function hookVictimSounds(plr)
        local charConn, addedConn, removingConn, ancestryConn
        local function disconnectCharacter()
            if charConn then charConn:Disconnect(); charConn = nil end
        end
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if not Actions.alive or plr.Parent ~= Players or plr.Character ~= char or not hum then return end
            disconnectCharacter()
            charConn = Actions.connect(hum.HealthChanged,  function(h)
                local tag = hum:FindFirstChild("creator")
                if not (tag and tag.Value == LP) then return end
                if h <= 0 then playSound("Abate"); return end
                playSound("Acerto com sangue")
                local cam = Workspace.CurrentCamera
                local hit
                if cam then
                    local ok, res = pcall(function() return Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 1000) end)
                    if ok and res and res.Instance then hit = res.Instance end
                end
                if hit and hit:IsDescendantOf(char) then
                    playSound(string.find(string.lower(hit.Name), "head", 1, true) and "Tiro na cabeça" or "Tiro no corpo")
                end
            end)
        end
        if plr.Character then task.spawn(onChar, plr.Character) end
        addedConn = Actions.connect(plr.CharacterAdded, onChar)
        removingConn = Actions.connect(plr.CharacterRemoving, disconnectCharacter)
        ancestryConn = Actions.connect(plr.AncestryChanged, function(_, parent)
            if parent then return end
            disconnectCharacter()
            if addedConn then addedConn:Disconnect() end
            if removingConn then removingConn:Disconnect() end
            if ancestryConn then ancestryConn:Disconnect() end
        end)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookVictimSounds(p) end
    Actions.trackConn(Actions.connect(Players.PlayerAdded, hookVictimSounds))

    -- ===== troca rápida: equipa a próxima ferramenta em loop =====
    local swapOn = false
    local function applySwap(v)
        swapOn = v == true
        Actions.swapToken = (Actions.swapToken or 0) + 1
        local token = Actions.swapToken
        if not v then return end
        task.spawn(function()
            local guard = {}
            while Actions.alive and swapOn and Actions.swapToken == token do
                if not Actions.guardStep("Troca rápida", guard, function()
                local ch, hum = LP.Character, LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if ch and hum then
                    local tools = {}
                    local bp = LP:FindFirstChild("Backpack")
                    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then tools[#tools + 1] = t end end end
                    local equipped = ch:FindFirstChildOfClass("Tool")
                    if #tools > 0 then
                        local idx = 1
                        for i, t in ipairs(tools) do if t == equipped then idx = i; break end end
                        local nxt = tools[(idx % #tools) + 1]
                        if nxt and nxt ~= equipped then hum:EquipTool(nxt) end
                    end
                end
                end, function() swapOn = false end) then break end
                task.wait(Actions.getAdjustment("swapInterval"))
            end
        end)
    end

    -- ===== atravessar porta: alguns segundos sem colisão =====
    local noclipParts = {}
    local function stopNoclip()
        Actions.noclipToken = (Actions.noclipToken or 0) + 1
        for d, v in pairs(noclipParts) do pcall(function() if d.Parent and d.CanCollide == false then d.CanCollide = v end end) end
        table.clear(noclipParts)
    end
    Library.Safety:trackStopper(stopNoclip)
    local function noclipPulse()
        if not Actions.alive or not Library.Safety:allow("Atravessar porta", true) then return false end
        local ch = LP.Character
        if not ch then return end
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BasePart") then
                if noclipParts[d] == nil then noclipParts[d] = d.CanCollide end
                pcall(function() d.CanCollide = false end)
            end
        end
        Actions.noclipToken = (Actions.noclipToken or 0) + 1
        local token = Actions.noclipToken
        say("Atravessando por 3s.")
        task.delay(3, function()
            if token ~= Actions.noclipToken then return end
            stopNoclip()
        end)
    end

    -- ===== remover efeitos =====
    local EFFECT_CLASSES = { "ParticleEmitter", "Trail", "Beam", "PointLight", "SpotLight", "SurfaceLight", "Fire", "Smoke", "Sparkles" }
    Actions.effects = setmetatable({}, { __mode = "k" })
    local function removeEffects(v)
        EXTRA.effects = v == true
        Actions.effectsToken = (Actions.effectsToken or 0) + 1
        local token = Actions.effectsToken
        if not v then
            for obj, enabled in pairs(Actions.effects) do
                pcall(function() if obj.Enabled == false then obj.Enabled = enabled end end)
            end
            table.clear(Actions.effects)
            return
        end
        task.spawn(function()
            local n = 0
            local function active() return Actions.alive and EXTRA.effects and not Library.Panic and Actions.effectsToken == token end
            Library.StreamScan.run(Workspace, active, function(d)
                if not active() or not d:IsDescendantOf(Workspace) then return end
                for _, class in ipairs(EFFECT_CLASSES) do
                    if d:IsA(class) then
                        local ok = pcall(function()
                            if Actions.effects[d] == nil then Actions.effects[d] = d.Enabled end
                            d.Enabled = false
                        end)
                        if ok then n += 1 end
                        break
                    end
                end
            end)
            if active() then say(n .. " efeitos desativados localmente.") end
        end)
    end

    -- ===== avisos de entrada =====
    local function applyJoinAlerts(v)
        if v and not EXTRA.joinConn then
            EXTRA.joinConn = Actions.trackConn(Actions.connect(Players.PlayerAdded, function(pl)
                pcall(function() Library:Notify({ Title = "EXTRAS", Content = pl.Name .. " entrou.", Duration = Actions.getAdjustment("joinDuration") }) end)
            end))
        elseif not v and EXTRA.joinConn then
            EXTRA.joinConn:Disconnect(); EXTRA.joinConn = nil
        end
    end
    -- ===== detecção de cargos =====
    local ROLE_KW = {
        Criador = { "creator", "criador", "owner", "dono", "founder", "fundador" },
        Testador = { "tester", "testador", "beta", "trial" },
        Moderador = { "mod", "moderador", "admin", "administrador", "staff" },
        Trapaceiro = { "cheat", "trapace", "banned", "banido", "suspect" },
    }
    local roleConns = {}
    local function roleTexts(pl)
        local texts = {}
        for _, a in ipairs({ "Role", "Cargo", "GroupRole", "Rank", "Title", "Tag" }) do
            local v = pl:GetAttribute(a)
            if v ~= nil then texts[#texts + 1] = string.lower(tostring(v)) end
        end
        local gid = pl:GetAttribute("GroupId") or pl:GetAttribute("Group")
        if gid then
            local ok, role = pcall(function() return pl:GetRoleInGroup(tonumber(gid)) end)
            if ok and role then texts[#texts + 1] = string.lower(role) end
        end
        texts[#texts + 1] = string.lower(pl.Name)
        texts[#texts + 1] = string.lower(pl.DisplayName)
        return texts
    end
    local function checkRole(pl, role)
        local texts = roleTexts(pl)
        for _, kw in ipairs(ROLE_KW[role] or {}) do
            for _, t in ipairs(texts) do if string.find(t, kw, 1, true) then return true end end
        end
        return false
    end
    local function applyRole(role, v)
        if v and not roleConns[role] then
            local function scan()
                if not Actions.alive or Library.Panic then return end
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LP and checkRole(pl, role) then
                        pcall(function() Library:Notify({ Title = "DETECÇÃO", Content = role .. ": " .. pl.Name, Duration = Actions.getAdjustment("role" .. role) }) end)
                    end
                end
            end
            scan()
            roleConns[role] = {
                Actions.trackConn(Actions.connect(Players.PlayerAdded, function()
                    task.delay(1, function() if Actions.alive and roleConns[role] then scan() end end)
                end)),
                Actions.trackConn(Actions.connect(Players.PlayerRemoving, scan)),
            }
        elseif not v and roleConns[role] then
            for _, c in ipairs(roleConns[role]) do c:Disconnect() end
            roleConns[role] = nil
        end
    end

    -- ===== ordenar depósito (mochila) =====
    local function sortBackpack(mode)
        local bp = LP:FindFirstChild("Backpack")
        if not bp then say("Sem mochila."); return end
        local items = {}
        for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") or t:IsA("HopperBin") then items[#items + 1] = t end end
        local function val(t)
            local v = t:GetAttribute("Value") or t:GetAttribute("Price") or t:GetAttribute("Rarity")
            return tonumber(v) or 0
        end
        if mode == "valor" then table.sort(items, function(a, b) return val(a) > val(b) end)
        elseif mode == "tipo" then table.sort(items, function(a, b) return a.ClassName < b.ClassName end)
        else table.sort(items, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end) end
        for _, t in ipairs(items) do pcall(function() t.Parent = nil end); pcall(function() t.Parent = bp end) end
        say(#items .. " itens ordenados (" .. mode .. ").")
    end

    -- ===== ver inventário =====
    local INV = { on = false, mode = "Jogadores", always = false }
    local invGui, invLabel
    local function ensureInvGui()
        if invGui and invGui.Parent then return end
        invGui = Library:CreateRootGui("ScreenGui", { Name = "BBCInv", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900, Enabled = false })
        local f = Library.Internal.create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(280, 220), BorderSizePixel = 0 }, invGui)
        Library.Internal.bind(f, "BackgroundColor3", "Surface"); Library.Internal.corner(f, 5); Library.Internal.stroke(f, "Stroke", 0.3)
        local title = Library.Internal.create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 4), Text = "INVENTÁRIO", TextSize = 12, FontFace = Library.Fonts.Bold }, f)
        Library.Internal.bind(title, "TextColor3", "Text")
        invLabel = Library.Internal.create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 1, -30), Text = "", TextSize = Actions.getAdjustment("panelTextSize"), FontFace = Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, f)
        Library.Internal.bind(invLabel, "TextColor3", "Text")
    end
    local function nearestNpc()
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local my = hrp and hrp.Position or Workspace.CurrentCamera.CFrame.Position
        local best, bd = nil, math.huge
        for _, m in ipairs(Workspace:GetDescendants()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(m) and m ~= ch then
                local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
                if p and p:IsA("BasePart") then
                    local d = (p.Position - my).Magnitude
                    if d < bd then bd = d; best = m end
                end
            end
        end
        return best
    end
    local function toolLines(pl)
        local lines = {}
        local function add(parent)
            if not parent then return end
            for _, t in ipairs(parent:GetChildren()) do if t:IsA("Tool") then lines[#lines + 1] = t.Name end end
        end
        add(pl:FindFirstChild("Backpack"))
        if pl.Character then add(pl.Character) end
        return lines
    end
    local function refreshInv()
        if not INV.on then if invGui then invGui.Enabled = false end; return end
        ensureInvGui()
        invGui.Enabled = true
        local lines = {}
        if INV.mode == "Jogadores" then
            lines[#lines + 1] = "Você:"
            for _, l in ipairs(toolLines(LP)) do lines[#lines + 1] = "  " .. l end
        elseif INV.mode == "NPCs" then
            local n = nearestNpc()
            lines[#lines + 1] = n and ("NPC: " .. n.Name) or "Nenhum NPC por perto."
            if n then for _, t in ipairs(n:GetChildren()) do if t:IsA("Tool") then lines[#lines + 1] = "  " .. t.Name end end end
        else
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ls = toolLines(pl)
                    if #ls > 0 then lines[#lines + 1] = pl.Name .. ":"; for _, l in ipairs(ls) do lines[#lines + 1] = "  " .. l end end
                end
            end
        end
        invLabel.Text = table.concat(lines, "\n")
    end
    task.spawn(function()
        local guard = {}
        while Actions.alive do
            if INV.on and not Library.Panic then
                Actions.guardStep("Ver inventário", guard, refreshInv, function()
                    INV.on = false
                    if invGui then invGui.Enabled = false end
                end)
            else
                guard = {}
            end
            task.wait(0.8)
        end
    end)
    local function setBackpackEnabled(v)
        pcall(function()
            if Actions.backpackOriginal == nil then
                Actions.backpackOriginal = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
            end
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, v)
        end)
    end
    -- Barra local genérica para Tools; não representa inventários próprios do jogo.
    local hotbar = { on = false, slots = {}, tools = {}, sources = {} }
    local function hotbarRefresh()
        if not hotbar.gui or not Actions.alive then return end
        local tools, seen = {}, {}
        for _, parent in pairs({ LP.Character, LP:FindFirstChildOfClass("Backpack") }) do
            if parent then
                for _, item in ipairs(parent:GetChildren()) do
                    if item:IsA("Tool") and not seen[item] then seen[item] = true; tools[#tools + 1] = item end
                end
            end
        end
        table.sort(tools, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)
        hotbar.tools = tools
        for i, button in ipairs(hotbar.slots) do
            local tool = tools[i]
            button.Visible = tool ~= nil and i <= Actions.getAdjustment("hotbarSlots")
            button.Text = tool and (tostring(i) .. "  " .. tool.Name) or ""
            button.BackgroundColor3 = tool and tool.Parent == LP.Character and Color3.fromRGB(130, 65, 20) or Color3.fromRGB(35, 35, 35)
        end
    end
    local function hotbarSources()
        for _, conn in ipairs(hotbar.sources) do conn:Disconnect() end
        table.clear(hotbar.sources)
        local function watch(parent)
            if parent then
                for _, sig in ipairs({ parent.ChildAdded, parent.ChildRemoved }) do
                    hotbar.sources[#hotbar.sources + 1] = Actions.connect(sig, function() task.defer(hotbarRefresh) end)
                end
            end
        end
        watch(LP.Character); watch(LP:FindFirstChildOfClass("Backpack"))
        hotbarRefresh()
    end
    local function applyHotbar(value)
        hotbar.on = value == true
        if hotbar.on and not hotbar.gui then
            hotbar.gui = Library:CreateRootGui("ScreenGui", { Name = "BBC_Hotbar", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900 })
            local bar = Instance.new("ScrollingFrame")
            bar.AnchorPoint = Vector2.new(0.5, 1); bar.Position = UDim2.new(0.5, 0, 1, -12)
            bar.Size = UDim2.new(0.8, 0, 0, 48); bar.BackgroundTransparency = 1; bar.BorderSizePixel = 0
            bar.ScrollingDirection = Enum.ScrollingDirection.X; bar.ScrollBarThickness = 3
            bar.CanvasSize = UDim2.fromOffset(8 * 78, 0); bar.Parent = hotbar.gui
            local layout = Instance.new("UIListLayout"); layout.FillDirection = Enum.FillDirection.Horizontal
            layout.Padding = UDim.new(0, 4); layout.Parent = bar
            for i = 1, 8 do
                local button = Instance.new("TextButton")
                button.LayoutOrder = i; button.Size = UDim2.fromOffset(74, 42); button.TextSize = 11
                button.TextColor3 = Color3.new(1, 1, 1); button.TextWrapped = true; button.Parent = bar
                hotbar.slots[i] = button
                Actions.connect(button.MouseButton1Click, function()
                    local tool = hotbar.tools[i]
                    local character = LP.Character
                    local hum = character and character:FindFirstChildOfClass("Humanoid")
                    local bp = LP:FindFirstChildOfClass("Backpack")
                    if not hotbar.on or Library.Panic or not hum or not tool then return end
                    if tool.Parent == character then hum:UnequipTools()
                    elseif tool.Parent == bp then hum:EquipTool(tool) end
                end)
            end
            Actions.connect(LP.CharacterAdded, function() task.defer(hotbarSources) end)
            Actions.connect(LP.ChildAdded, function(child) if child:IsA("Backpack") then task.defer(hotbarSources) end end)
            Actions.connect(LP.ChildRemoved, function(child) if child:IsA("Backpack") then task.defer(hotbarSources) end end)
            hotbarSources()
        end
        if hotbar.gui then hotbar.gui.Enabled = hotbar.on and not Library.Panic; hotbarRefresh() end
    end
    onCleanup(function()
        for _, conn in ipairs(hotbar.sources) do pcall(function() conn:Disconnect() end) end
        if hotbar.gui then pcall(function() hotbar.gui:Destroy() end) end
    end)
    local function toggleInv()
        INV.on = not INV.on
        if INV.on then refreshInv() else if invGui then invGui.Enabled = false end; setBackpackEnabled(INV.always) end
        say(INV.on and ("Inventário: " .. INV.mode) or "Inventário fechado.")
    end

    -- Saque só usa caminhos de prompt explícitos e autorizados para este PlaceId.
    local autoLoot = false
    function Actions.getLootConfig()
        local ok, id, paths = pcall(function()
            local env = type(getgenv) == "function" and getgenv() or nil
            local cfg = type(env) == "table" and env.BBC_CONFIG or nil
            if type(cfg) ~= "table" then return nil, nil end
            return cfg.LootPlaceId, cfg.LootPromptPaths
        end)
        if ok and Library.OperationGuard:validLootConfig(id, paths, game.PlaceId) then return paths end
        return nil
    end
    local function applyAutoLoot(v)
        if v and (not Actions.alive or not Library.Safety:allow("Saque automático", true)) then return false end
        if v and type(fireproximityprompt) ~= "function" then
            error("Saque automático requer suporte a fireproximityprompt no executor.")
        end
        if v and not Actions.getLootConfig() then
            error("Saque automático exige LootPlaceId e LootPromptPaths autorizados; consulte o README.")
        end
        autoLoot = v == true
        Actions.lootToken = (Actions.lootToken or 0) + 1
        local token = Actions.lootToken
        if not v then return end
        task.spawn(function()
            local guard = {}
            while Actions.alive and autoLoot and Actions.lootToken == token do
                if not Actions.guardStep("Saque automático", guard, function()
                    local paths = Actions.getLootConfig()
                    if not paths then error("configuração de saque inválida ou alterada") end
                    local ch = LP.Character
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local best, bestPart, bd = nil, nil, Actions.getAdjustment("lootDistance")
                    for _, path in ipairs(paths) do
                        local prompt = Library.OperationGuard:resolvePrompt(Workspace, path)
                        if prompt and prompt.Enabled then
                            local part = prompt.Parent
                            if part and part:IsA("Attachment") then part = part.Parent end
                            if part and part:IsA("Model") then part = part.PrimaryPart end
                            if part and part:IsA("BasePart") then
                                local dist = (part.Position - hrp.Position).Magnitude
                                if dist < bd and dist <= prompt.MaxActivationDistance then bd = dist; best, bestPart = prompt, part end
                            end
                        end
                    end
                    if best and best.Parent and best.Enabled and bestPart and bestPart.Parent
                        and (bestPart.Position - hrp.Position).Magnitude <= best.MaxActivationDistance
                        and Actions.alive and autoLoot and Actions.lootToken == token and Library.Safety:allow("Saque automático", true)
                        and Library.OperationGuard:take("loot", os.clock()) then
                        local ok, err = pcall(fireproximityprompt, best)
                        if not ok then
                            autoLoot = false
                            Library.Safety:disable("Saque automático")
                            warn("[BBC] Saque automático interrompido: " .. tostring(err))
                            say(tr("Ação interrompida após falha; veja o console."))
                        end
                    end
                end, function() autoLoot = false end) then break end
                task.wait(Actions.getAdjustment("lootInterval"))
            end
        end)
    end

    -- ===== campo de visão / zoom =====
    local CAM = { fov = 120, zoom = 5, zoomHeld = false }
    local zoomKeyName = "N"
    local function applyFov()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        Actions.setProperty(cam, "FieldOfView", CAM.zoomHeld and CAM.zoom or CAM.fov)
    end
    Actions.connections.zoom = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
        local kc = Enum.KeyCode[zoomKeyName]
        if not kc then return end
        local down = UserInputService:IsKeyDown(kc)
        if down ~= CAM.zoomHeld then CAM.zoomHeld = down; applyFov() end
    end))

    -- ===== painel do jogador =====
    local PANEL = { on = false }
    local panelGui, panelLabel
    local function ensurePanelGui()
        if panelGui and panelGui.Parent then return end
        panelGui = Library:CreateRootGui("ScreenGui", { Name = "BBCPlayers", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900, Enabled = false })
        local f = Library.Internal.create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(260, 200), BorderSizePixel = 0 }, panelGui)
        Library.Internal.bind(f, "BackgroundColor3", "Surface"); Library.Internal.corner(f, 5); Library.Internal.stroke(f, "Stroke", 0.3)
        local title = Library.Internal.create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 4), Text = "JOGADORES", TextSize = 12, FontFace = Library.Fonts.Bold }, f)
        Library.Internal.bind(title, "TextColor3", "Text")
        panelLabel = Library.Internal.create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 1, -30), Text = "", TextSize = Actions.getAdjustment("panelTextSize"), FontFace = Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, f)
        Library.Internal.bind(panelLabel, "TextColor3", "Text")
    end
    local function refreshPanel()
        if not PANEL.on then if panelGui then panelGui.Enabled = false end; return end
        ensurePanelGui()
        panelGui.Enabled = true
        local cam = Workspace.CurrentCamera
        local lines = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local d = hrp and math.floor((hrp.Position - cam.CFrame.Position).Magnitude * 0.28) or 0
                lines[#lines + 1] = pl.Name .. "  " .. d .. "m"
            end
        end
        panelLabel.Text = table.concat(lines, "\n")
    end
    task.spawn(function()
        local guard = {}
        while Actions.alive do
            if PANEL.on and not Library.Panic then
                Actions.guardStep("Painel do jogador", guard, refreshPanel, function()
                    PANEL.on = false
                    if panelGui then panelGui.Enabled = false end
                end)
            else
                guard = {}
            end
            task.wait(Actions.getAdjustment("panelInterval"))
        end
    end)

    local EXTRA_ACTIONS = {
        ["Troca rápida"] = function(v) applySwap(v) end,
        ["Modo pânico"] = function(v) if EXTRA.panicFn then EXTRA.panicFn(v) else Library.Panic = (v == true) end end,
        ["Remover efeitos"] = function(v) removeEffects(v) end,
        ["Avisos de entrada"] = function(v) applyJoinAlerts(v) end,
        ["Criador"] = function(v) applyRole("Criador", v) end,
        ["Testador"] = function(v) applyRole("Testador", v) end,
        ["Moderador"] = function(v) applyRole("Moderador", v) end,
        ["Trapaceiro"] = function(v) applyRole("Trapaceiro", v) end,
        ["Jump"] = function(v) SOUND_TOGGLES["Jump"] = v end,
        ["Pegadas"] = function(v) SOUND_TOGGLES["Pegadas"] = v end,
        ["Pouso"] = function(v) SOUND_TOGGLES["Pouso"] = v end,
        ["Capacete"] = function(v) SOUND_TOGGLES["Capacete"] = v end,
        ["Tiro na cabeça"] = function(v) SOUND_TOGGLES["Tiro na cabeça"] = v end,
        ["Tiro no corpo"] = function(v) SOUND_TOGGLES["Tiro no corpo"] = v end,
        ["Abate"] = function(v) SOUND_TOGGLES["Abate"] = v end,
        ["Disparo"] = function(v) SOUND_TOGGLES["Disparo"] = v end,
        ["Acerto com sangue"] = function(v) SOUND_TOGGLES["Acerto com sangue"] = v end,
        ["Saque automático"] = function(v) applyAutoLoot(v) end,
        ["Painel do jogador"] = function(v) PANEL.on = v == true; if not v and panelGui then panelGui.Enabled = false end end,
        ["Sempre mostrar"] = function(v) INV.always = v == true; if v then setBackpackEnabled(true) end end,
        ["Mochila"] = function(v) setBackpackEnabled(v) end,
        ["Barra rápida"] = function(v) applyHotbar(v) end,
    }

    -- ===== aparência do personagem (MÃOS E ARMA) =====
    local CHAR = { offset = nil, first = false, anim = "Swish", charVisible = false, handsVisible = false, heldVisible = false }
    local function charParts(char, filter)
        local t = {}
        if not char then return t end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and (not filter or filter(d)) then t[#t + 1] = d end
        end
        return t
    end
    local function applyCharVisible(v)
        CHAR.charVisible = v == true
        for _, d in ipairs(charParts(LP.Character, function(d) return d.Name ~= "HumanoidRootPart" end)) do
            pcall(function() Actions.setProperty(d, "Transparency", v and Actions.getAdjustment("charTransparency") or 1) end)
        end
    end
    local function applyHands(v)
        CHAR.handsVisible = v == true
        for _, d in ipairs(charParts(LP.Character, function(d)
            local n = string.lower(d.Name)
            return string.find(n, "arm", 1, true) or string.find(n, "hand", 1, true) or string.find(n, "bra", 1, true)
        end)) do
            pcall(function() Actions.setProperty(d, "Transparency", v and Actions.getAdjustment("handTransparency") or 1) end)
        end
    end
    local function applyHeld(v)
        CHAR.heldVisible = v == true
        local ch = LP.Character
        local tool = ch and ch:FindFirstChildOfClass("Tool")
        if not tool then return end
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("BasePart") then pcall(function() Actions.setProperty(d, "Transparency", v and Actions.getAdjustment("heldTransparency") or 1) end) end
        end
    end
    local function stopOffset()
        if CHAR.offset then pcall(function() CHAR.offset:Destroy() end); CHAR.offset = nil end
    end
    local function applyOffset(v)
        stopOffset()
        if not v then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local ok, bp = pcall(function()
            local o = Instance.new("BodyPosition")
            o.Name = "BBC_Offset"
            o.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            o.P = 10000; o.D = 500
            o.Parent = hrp
            return o
        end)
        CHAR.offset = ok and bp or nil
        if CHAR.offset then
            local current = CHAR.offset
            task.spawn(function()
                local guard = {}
                while Actions.alive and CHAR.offset == current and current.Parent do
                    if not Actions.guardStep("Deslocamento", guard, function()
                        local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                        if h then current.Position = h.Position + h.CFrame.LookVector * Actions.getAdjustment("offsetDistance") end
                    end, stopOffset) then break end
                    task.wait()
                end
            end)
        end
    end
    -- Mostra somente partes corporais reconhecidas no cliente. Não interfere
    -- com cabeça, HumanoidRootPart, acessórios ou ferramentas.
    local function applyFirst(v)
        CHAR.first = v == true
        for _, conn in ipairs(CHAR.firstConns or {}) do pcall(function() conn:Disconnect() end) end
        CHAR.firstConns = {}
        if CHAR.firstDescConn then CHAR.firstDescConn:Disconnect(); CHAR.firstDescConn = nil end
        for part in pairs(CHAR.firstParts or {}) do Actions.restoreProperty(part, "LocalTransparencyModifier") end
        CHAR.firstParts = {}
        pcall(function()
            if CHAR.first then Actions.setProperty(LP, "CameraMode", Enum.CameraMode.LockFirstPerson)
            else Actions.restoreProperty(LP, "CameraMode") end
        end)
        if not CHAR.first or not Actions.alive then return end
        local names = { Torso = true, UpperTorso = true, LowerTorso = true,
            ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
            LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
            LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true }
        local function attach(char)
            if not Actions.alive or not CHAR.first or LP.Character ~= char then return end
            if CHAR.firstDescConn then CHAR.firstDescConn:Disconnect(); CHAR.firstDescConn = nil end
            for part in pairs(CHAR.firstParts) do Actions.restoreProperty(part, "LocalTransparencyModifier") end
            CHAR.firstParts = {}
            local function add(part)
                if part.Parent == char and part:IsA("BasePart") and names[part.Name] then CHAR.firstParts[part] = true end
            end
            CHAR.firstDescConn = Actions.connect(char.ChildAdded, add)
            for _, part in ipairs(char:GetChildren()) do add(part) end
        end
        if LP.Character then attach(LP.Character) end
        CHAR.firstConns[#CHAR.firstConns + 1] = Actions.connect(LP.CharacterAdded, attach)
        CHAR.firstConns[#CHAR.firstConns + 1] = Actions.connect(RunService.RenderStepped, function()
            if not CHAR.first or Library.Panic then return end
            for part in pairs(CHAR.firstParts) do
                if part.Parent ~= LP.Character then
                    Actions.restoreProperty(part, "LocalTransparencyModifier")
                    CHAR.firstParts[part] = nil
                else
                    Actions.setProperty(part, "LocalTransparencyModifier", Actions.getAdjustment("firstPersonTransparency"))
                end
            end
        end)
    end
    local function playAnim()
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum then say("Sem personagem."); return end
        local anim
        local animate = ch:FindFirstChild("Animate")
        local idle = animate and animate:FindFirstChild("idle")
        local searchRoot = CHAR.anim == "Padrão" and idle or ch
        if searchRoot then
            for _, item in ipairs(searchRoot:GetDescendants()) do
                if item:IsA("Animation") and item.AnimationId ~= "" and
                    (CHAR.anim == "Padrão" or string.lower(item.Name) == "swish") then
                    anim = item; break
                end
            end
        end
        if not anim then say("Animação selecionada não encontrada no personagem."); return end
        if CHAR.track then pcall(function() CHAR.track:Stop() end) end
        local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
        if not ok or not track then say("Não foi possível reproduzir."); return end
        local played = pcall(function() track:Play(0.1, CHAR.weight / 100, CHAR.speed) end)
        if not played then say("Não foi possível reproduzir a animação."); return end
        CHAR.track = track
        if CHAR.repeating then
            pcall(function()
                Actions.trackConn(Actions.connect(track.Ended, function()
                    if CHAR.repeating and CHAR.track == track then playAnim() end
                end))
            end)
        end
    end
    local CHAR_ACTIONS = {
        ["Personagem"] = function(v) applyCharVisible(v) end,
        ["Mãos"] = function(v) applyHands(v) end,
        ["Item na mão"] = function(v) applyHeld(v) end,
        ["Corpo em 1ª pessoa"] = function(v) applyFirst(v) end,
        ["Deslocamento"] = function(v) applyOffset(v) end,
        ["Reproduzir"] = function() playAnim() end,
        ["Repetir"] = function(v) CHAR.repeating = v == true end,
    }
    CHAR.speed, CHAR.weight, CHAR.repeating = 1, 100, false

    -- ===== COMBATE (mira, alvos, efeitos, anti-aim, granadas) =====
    -- Cada lógica tem sua trava: valores limitados, pcall em tudo que toca o
    -- jogo, verificação de pânico e desconexão ao desligar.
    local WEAPON = { recoil = 0.2 }
    local COMBAT = {
        on = false, activation = "Ao mirar", lock = false, predict = false,
        smooth = 0.08, smartPause = false, notify = true,
        radius = 70, fovDyn = true, aimPoint = "Partes selecionadas", parts = { ["Cabeça"] = true },
        npcs = true, throughWalls = true, maxChecks = 7, friends = {},
        reticle = false, circle = true, trail = false, gameTrails = false,
        hitMark = true, hitFx = true, dmgNumbers = true, killFx = false, targetData = true, confirmedOnly = true,
        antiAim = false, underGround = false, ghost = false,
        throwLine = false, noShake = true, reload = false, refill = false,
        peek = false, aura = false,
    }
    local AIM = { conn = nil, target = nil, lastKey = nil, sg = nil, ring = nil, mark = nil, label = nil, dmg = {} }
    local function clampCfg()
        COMBAT.radius = math.clamp(tonumber(COMBAT.radius) or 70, 10, 500)
        COMBAT.maxChecks = math.clamp(tonumber(COMBAT.maxChecks) or 7, 1, 20)
        COMBAT.smooth = math.clamp(tonumber(COMBAT.smooth) or 0.08, 0, 1)
    end
    clampCfg()

    local function ensureAimGui()
        if AIM.sg and AIM.sg.Parent then return end
        AIM.sg = Library:CreateRootGui("ScreenGui", { Name = "BBC_Aim", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 950, Enabled = true })
        local c = Library.Internal.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(Actions.getAdjustment("reticleSize"), Actions.getAdjustment("reticleSize")), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, AIM.sg)
        Library.Internal.corner(c, 3)
        AIM.dot = c
        AIM.ring = Library.Internal.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(140, 140), BackgroundTransparency = 1, Visible = false }, AIM.sg)
        Library.Internal.create("UICorner", { CornerRadius = UDim.new(1, 0) }, AIM.ring)
        AIM.ringStroke = Library.Internal.create("UIStroke", { Thickness = Actions.getAdjustment("ringThickness"), Transparency = 0.2, Color = Color3.fromRGB(255, 120, 30) }, AIM.ring)
        AIM.label = Library.Internal.create("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 110), Size = UDim2.fromOffset(220, 30), BackgroundTransparency = 1, Text = "", TextSize = Actions.getAdjustment("targetTextSize"), FontFace = Library.Fonts.Bold }, AIM.sg)
        Library.Internal.bind(AIM.label, "TextColor3", "Text")
        AIM.mark = Library.Internal.create("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Text = "✕", TextSize = 26, Visible = false, FontFace = Library.Fonts.Bold }, AIM.sg)
        Library.Internal.bind(AIM.mark, "TextColor3", "Accent")
    end

    local aimNpcs, aimNpcScan = {}, false
    local function aimNpcAdd(h)
        if Actions.alive and h:IsA("Humanoid") and h:IsDescendantOf(Workspace) then
            local m = h.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and m ~= LP.Character then aimNpcs[m] = h end
        end
    end
    local function startAimNpcScan()
        if aimNpcScan then return end
        aimNpcScan = true
        Actions.trackConn(Actions.connect(Workspace.DescendantAdded, function(d) if d:IsA("Humanoid") then task.defer(aimNpcAdd, d) end end))
        Actions.trackConn(Actions.connect(Workspace.DescendantRemoving, function(d)
            aimNpcs[d] = nil
            if d:IsA("Humanoid") and d.Parent then aimNpcs[d.Parent] = nil end
        end))
        Library.StreamScan.start(Workspace, function() return Actions.alive end, aimNpcAdd)
    end
    local function aimTargets(cam, vp)
        local out = {}
        local n = 0
        local function add(m, hum, hrp, name, plr)
            if n >= COMBAT.maxChecks then return end
            if not (m and hum and hrp) then return end
            if hum.Health <= 0 then return end
            if plr and COMBAT.friends[plr] then return end
            n += 1
            out[#out + 1] = { m = m, hum = hum, hrp = hrp, name = name, plr = plr }
        end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                add(pl.Character, hum, hrp, (pl.DisplayName ~= "" and pl.DisplayName) or pl.Name, pl)
            end
            if n >= COMBAT.maxChecks then break end
        end
        if COMBAT.npcs then
            startAimNpcScan()
            for m, hum in pairs(aimNpcs) do
                if n >= COMBAT.maxChecks then break end
                if m.Parent and hum.Health > 0 and m ~= LP.Character then
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    add(m, hum, hrp, m.Name, nil)
                end
            end
        end
        return out
    end
    local function partPosition(t)
        local m = t.m
        local function find(...)
            for _, n in ipairs({ ... }) do
                local p = m:FindFirstChild(n)
                if p and p:IsA("BasePart") then return p end
            end
            return nil
        end
        local p
        if COMBAT.aimPoint == "Mais próximo" then
            local best, bd = nil, math.huge
            local camPos = Workspace.CurrentCamera.CFrame.Position
            for _, d in ipairs(m:GetDescendants()) do
                if d:IsA("BasePart") and not d.Name:lower():find("root") then
                    local dist = (d.Position - camPos).Magnitude
                    if dist < bd then bd = dist; best = d end
                end
            end
            p = best
        else
            if COMBAT.parts["Cabeça"] then p = find("Head", "head") end
            if not p and COMBAT.parts["Corpo"] then p = find("UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart") end
            if not p and COMBAT.parts["Braços"] then p = find("LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm") end
            if not p and COMBAT.parts["Pernas"] then p = find("LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg") end
            if not p then p = find("HumanoidRootPart", "UpperTorso", "Torso", "Head") end
        end
        return p
    end
    local function isVisible(from, to, target)
        if COMBAT.throughWalls and (to - from).Magnitude <= Actions.getAdjustment("ignoreObstacleDistance") then return true end
        local ok, res = pcall(function()
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = { LP.Character }
            return Workspace:Raycast(from, to - from, rp)
        end)
        if not ok then
            if not Actions.raycastWarned then
                Actions.raycastWarned = true
                warn("[BBC] Verificação de obstáculos falhou; mira pausada enquanto estiver indisponível.")
            end
            return false
        end
        Actions.raycastWarned = false
        if not res then return true end
        return res.Instance ~= nil and res.Instance:IsDescendantOf(target.m)
    end
    -- Escala em pixels para manter aproximadamente o mesmo ângulo ao alterar o FOV.
    local function aimRadius(cam)
        if not COMBAT.fovDyn then return COMBAT.radius end
        local fov = math.clamp(tonumber(cam.FieldOfView) or 70, 1, 120)
        return math.clamp(COMBAT.radius * math.tan(math.rad(70 / 2)) / math.tan(math.rad(fov / 2)), 1, 2000)
    end
    local function pickTarget(cam, vp)
        local list = aimTargets(cam, vp)
        local cx, cy = vp.X / 2, vp.Y / 2
        local best, bestScore = nil, math.huge
        for _, t in ipairs(list) do
            local p = partPosition(t)
            if p then
                local sp = cam:WorldToViewportPoint(p.Position)
                if sp.Z > 0 then
                    local d = math.sqrt((sp.X - cx) ^ 2 + (sp.Y - cy) ^ 2)
                    local score = d
                    if d <= aimRadius(cam) and score < bestScore then
                        if COMBAT.smartPause and not isVisible(cam.CFrame.Position, p.Position, t) then continue end
                        bestScore = score; best = { t = t, pos = p.Position, dist = d }
                    end
                end
            end
        end
        return best
    end
    local function active()
        if not COMBAT.on or Library.Panic or not Actions.alive or not Library.Safety:allow("MIRA", true) then return false end
        if COMBAT.activation == "Ao mirar" then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
        end
        return true
    end
    local function aimStep(dt)
        local camera = Workspace.CurrentCamera
        if AIM.ring and camera then
            local diameter = aimRadius(camera) * 2
            AIM.ring.Size = UDim2.fromOffset(diameter, diameter)
        end
        if not active() then
            AIM.visibleSince, AIM.visibleTarget = nil, nil
            AIM.target = nil
            if AIM.label then AIM.label.Text = "" end
            return
        end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local cur = AIM.target
        if COMBAT.lock and cur and cur.t.hum.Health > 0 and cur.t.m.Parent then
            local p = partPosition(cur.t)
            if p then cur.pos = p.Position end
        else
            cur = pickTarget(cam, vp)
            local key = cur and cur.t.m or nil
            if COMBAT.notify and cur and key ~= AIM.lastKey then
                AIM.lastKey = key
                pcall(function() Library:Notify({ Title = "MIRA", Content = cur.t.name, Duration = Actions.getAdjustment("targetDuration") }) end)
            end
            AIM.target = cur
        end
        if not cur then AIM.visibleSince, AIM.visibleTarget = nil, nil; return end
        local p = partPosition(cur.t)
        if not p then return end
        local pos = p.Position
        if COMBAT.predict then
            local vel = cur.t.hrp.AssemblyLinearVelocity
            pos = pos + vel * math.clamp((pos - cam.CFrame.Position).Magnitude / 800, 0, 0.25)
        end
        -- compensação de recuo: mira um pouco acima conforme o ajuste
        if WEAPON.recoil > 0 then
            pos = pos + Vector3.new(0, WEAPON.recoil * math.clamp((pos - cam.CFrame.Position).Magnitude * 0.01, 0, 1.5), 0)
        end
        if COMBAT.smartPause then
            if not isVisible(cam.CFrame.Position, pos, cur.t) then AIM.visibleSince, AIM.visibleTarget = nil, nil; return end
            if AIM.visibleTarget ~= cur.t.m then AIM.visibleTarget = cur.t.m; AIM.visibleSince = os.clock() end
            if os.clock() - (AIM.visibleSince or os.clock()) < Actions.getAdjustment("pauseResume") then return end
        else
            AIM.visibleSince, AIM.visibleTarget = nil, nil
        end
        local look = (pos - cam.CFrame.Position).Unit
        local now = cam.CFrame.LookVector
        local alpha = math.clamp((1 - COMBAT.smooth) * (dt * 60), 0.01, 0.3)
        local newLook = now:Lerp(look, alpha).Unit
        pcall(function()
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + newLook)
        end)
        if AIM.label then
            AIM.label.Text = COMBAT.targetData and (cur.t.name .. "  " .. math.floor((pos - cam.CFrame.Position).Magnitude * 0.28) .. "m") or ""
        end
    end
    local function applyAimState()
        if AIM.conn then AIM.conn:Disconnect(); AIM.conn = nil end
        if not COMBAT.on or not Actions.alive or not Library.Safety:allow("MIRA", true) then
            COMBAT.on = false
            if AIM.dot then AIM.dot.Visible = false end
            if AIM.ring then AIM.ring.Visible = false end
            if AIM.label then AIM.label.Text = "" end
            return
        end
        ensureAimGui()
        if AIM.dot then AIM.dot.Visible = COMBAT.reticle end
        if AIM.ring then AIM.ring.Visible = COMBAT.circle end
        Actions.aimErrors = 0
        AIM.conn = Actions.trackConn(Actions.connect(RunService.RenderStepped, function(dt)
            local ok, err = pcall(aimStep, math.min(dt, 0.05))
            if ok then Actions.aimErrors = 0; return end
            Actions.aimErrors += 1
            if Actions.aimErrors == 1 then
                warn("[BBC] Mira: " .. tostring(err))
                if Library.Diagnostics then Library.Diagnostics:record("mira", err) end
            end
            if Actions.aimErrors >= 5 then
                Library.Safety:disableTracked()
                pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = "Mira interrompida após erros; veja o console.", Duration = 5 }) end)
            end
        end))
    end

    -- efeitos de combate na tela
    local function flashMark()
        if not Actions.alive or Library.Panic or not COMBAT.hitMark then return end
        ensureAimGui()
        AIM.markToken = (AIM.markToken or 0) + 1
        local token = AIM.markToken
        AIM.mark.Visible = true
        task.delay(Actions.getAdjustment("hitDuration"), function()
            if AIM.mark and AIM.markToken == token then AIM.mark.Visible = false end
        end)
    end
    local function spawnDmg(part, amount)
        if not COMBAT.dmgNumbers or not part then return end
        pcall(function()
            local item = table.remove(AIM.dmg)
            if not item then
                local gui = Instance.new("BillboardGui")
                Library:ProtectGui(gui)
                gui.Size = UDim2.fromOffset(90, 28)
                gui.StudsOffset = Vector3.new(0, 2, 0)
                gui.AlwaysOnTop = true
                gui.LightInfluence = 0
                local l = Instance.new("TextLabel")
                l.BackgroundTransparency = 1
                l.Size = UDim2.fromScale(1, 1)
                l.FontFace = Library.Fonts.Bold
                l.TextSize = Actions.getAdjustment("damageTextSize")
                l.TextColor3 = Color3.fromRGB(255, 80, 60)
                l.TextStrokeTransparency = 0.4
                l.Parent = gui
                item = { gui = gui, label = l }
            end
            item.label.Text = "-" .. tostring(math.floor(amount))
            item.label.TextTransparency = 0
            item.label.TextStrokeTransparency = 0.4
            item.gui.Adornee = part
            item.gui.Enabled = true
            Library:ParentGui(item.gui)
            game:GetService("TweenService"):Create(item.label, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
            task.delay(0.75, function()
                pcall(function() item.gui:Destroy() end)
            end)
        end)
    end

    -- Realce local temporário; não afirma que o servidor confirmou um acerto.
    Actions.hitFxObjects = {}
    function Actions.clearHitEffects()
        for object in pairs(Actions.hitFxObjects) do pcall(function() object:Destroy() end) end
        table.clear(Actions.hitFxObjects)
    end
    local function showHitEffect(character)
        if not Actions.alive or Library.Panic or not COMBAT.hitFx or not character or not character.Parent then return end
        local count = 0
        for _ in pairs(Actions.hitFxObjects) do count += 1 end
        if count >= 8 then return end
        local ok, object = pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "BBC_HitEffect"
            h.FillColor = Color3.fromRGB(255, 120, 30)
            h.FillTransparency = Actions.getAdjustment("hitFxTransparency")
            h.OutlineTransparency = 1
            h.DepthMode = Enum.HighlightDepthMode.Occluded
            h.Parent = character
            return h
        end)
        if not ok or not object then return end
        Actions.hitFxObjects[object] = true
        task.delay(Actions.getAdjustment("hitFxDuration"), function()
            Actions.hitFxObjects[object] = nil
            pcall(function() object:Destroy() end)
        end)
    end

    -- acerto/eliminação: marca, efeito e número de dano
    local dmgLast = setmetatable({}, { __mode = "k" })
    local function hookCombatFx(plr)
        local charConn, addedConn, removingConn, ancestryConn
        local function disconnectCharacter()
            if charConn then charConn:Disconnect(); charConn = nil end
        end
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if not Actions.alive or plr.Parent ~= Players or plr.Character ~= char or not hum then return end
            dmgLast[hum] = hum.Health
            disconnectCharacter()
            charConn = Actions.connect(hum.HealthChanged,  function(h)
                local tag = hum:FindFirstChild("creator")
                if COMBAT.confirmedOnly and not (tag and tag.Value == LP) then dmgLast[hum] = h; return end
                if h >= (dmgLast[hum] or h) then dmgLast[hum] = h; return end
                if Library.Panic then dmgLast[hum] = h; return end
                showHitEffect(char)
                if h <= 0 then
                    if COMBAT.killFx then pcall(function() Library:Notify({ Title = "COMBATE", Content = "Eliminação: " .. plr.Name, Duration = Actions.getAdjustment("killDuration") }) end) end
                    dmgLast[hum] = h
                    return
                end
                local dmg = math.max((dmgLast[hum] or h) - h, 0)
                dmgLast[hum] = h
                if COMBAT.hitMark then flashMark() end
                local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                spawnDmg(part, dmg)
            end)
        end
        if plr.Character then task.spawn(onChar, plr.Character) end
        addedConn = Actions.connect(plr.CharacterAdded, onChar)
        removingConn = Actions.connect(plr.CharacterRemoving, disconnectCharacter)
        ancestryConn = Actions.connect(plr.AncestryChanged, function(_, parent)
            if parent then return end
            disconnectCharacter()
            if addedConn then addedConn:Disconnect() end
            if removingConn then removingConn:Disconnect() end
            if ancestryConn then ancestryConn:Disconnect() end
        end)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookCombatFx(p) end
    Actions.trackConn(Actions.connect(Players.PlayerAdded, hookCombatFx))

    -- aura letal
    local auraConn = nil
    local function auraStep()
        if not Actions.alive or not Library.Safety:allow("Aura letal", true) then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character and not COMBAT.friends[pl] then
                local h = pl.Character:FindFirstChildOfClass("Humanoid")
                local p = pl.Character:FindFirstChild("HumanoidRootPart")
                if h and p and h.Health > 0 then
                    local d = (p.Position - hrp.Position).Magnitude
                    if d <= Actions.getAdjustment("auraRange") then pcall(function() h:TakeDamage(4) end) end
                end
            end
        end
    end
    local function applyAura(v)
        Actions.auraToken = (Actions.auraToken or 0) + 1
        local token = Actions.auraToken
        if not v then COMBAT.aura = false; return end
        auraConn = task.spawn(function()
            local guard = {}
            while Actions.alive and COMBAT.aura and Actions.auraToken == token do
                if not Library.Panic and not Actions.guardStep("Aura letal", guard, auraStep, function() COMBAT.aura = false end) then break end
                task.wait(0.5)
            end
        end)
    end

    -- espiada subterrânea / anti-aim / sob o chão / fantasma / sem tremor
    local camConn, charConn = nil, nil
    local function applyPeek(v)
        COMBAT.peek = v == true
        if COMBAT.peek then
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.setProperty(hum, "CameraOffset", Vector3.new(0, -Actions.getAdjustment("peekDepth"), 0)) end
            end)
        else
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.restoreProperty(hum, "CameraOffset") end
            end)
        end
    end
    local function applyGhost(v)
        COMBAT.ghost = v == true
        local ch = LP.Character
        if not ch then return end
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                if COMBAT.ghost then Actions.setProperty(d, "Transparency", Actions.getAdjustment("ghostTransparency"))
                else Actions.restoreProperty(d, "Transparency") end
            end
        end
    end
    local function applyAntiAim(v)
        COMBAT.antiAim = v == true
        if camConn then camConn:Disconnect(); camConn = nil end
        if not v then return end
        camConn = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
            if not COMBAT.antiAim or Library.Panic then return end
            pcall(function()
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(Actions.getAdjustment("spinDegrees"))) end
            end)
        end))
    end
    local function applyUnderGround(v)
        COMBAT.underGround = v == true
        if charConn then charConn:Disconnect(); charConn = nil end
        if not v then
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.restoreProperty(hum, "HipHeight") end
            end)
            return
        end
        charConn = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
            if not COMBAT.underGround or Library.Panic then return end
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.setProperty(hum, "HipHeight", Actions.getAdjustment("undergroundHeight")) end
            end)
        end))
    end
    local function applyNoShake(v)
        COMBAT.noShake = v == true
        if COMBAT.noShake then
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.setProperty(hum, "CameraOffset", Vector3.zero) end
            end)
        end
    end

    -- recarga / cargadores
    local function equippedTool()
        local ch = LP.Character
        return ch and ch:FindFirstChildOfClass("Tool")
    end
    -- Apenas um caminho exato configurado para este jogo pode ser usado; nomes
    -- parecidos podem apontar para remotes não relacionados ou iscas.
    function Actions.getReloadPath()
        local ok, path = pcall(function()
            local env = type(getgenv) == "function" and getgenv() or nil
            local cfg = type(env) == "table" and env.BBC_CONFIG or nil
            return type(cfg) == "table" and cfg.ReloadRemotePath or nil
        end)
        if ok and Library.OperationGuard:validPath(path) then return path end
        return nil
    end
    local function doReload()
        if not Actions.alive or not Library.Safety:allow("Recarga automática", true) then return false end
        local tool = equippedTool()
        if not tool then return false end
        local remote = Library.OperationGuard:resolveRemote(tool, Actions.getReloadPath())
        if not remote then
            if not Actions.reloadPathWarned then
                Actions.reloadPathWarned = true
                say(tr("Recarga: caminho do RemoteEvent não encontrado na ferramenta."))
            end
            return false
        end
        Actions.reloadPathWarned = false
        if not Library.OperationGuard:take("reload", os.clock()) then return false end
        local ok, err = pcall(function() remote:FireServer() end)
        if not ok then
            COMBAT.reload = false
            Library.Safety:disable("Recarga automática")
            warn("[BBC] Recarga automática interrompida: " .. tostring(err))
            say(tr("Ação interrompida após falha; veja o console."))
        end
        return ok
    end
    local function doRefill()
        if not Actions.alive or not Library.Safety:allow("Abastecer cargadores", true) then return 0 end
        local n = 0
        local ch = LP.Character
        local bp = LP:FindFirstChild("Backpack")
        local function scan(parent)
            if not parent then return end
            for _, d in ipairs(parent:GetDescendants()) do
                if d:IsA("IntValue") or d:IsA("NumberValue") then
                    local low = string.lower(d.Name)
                    if string.find(low, "ammo", 1, true) or string.find(low, "mag", 1, true) or string.find(low, "clip", 1, true) then
                        pcall(function() d.Value = Actions.getAdjustment("refillValue") end); n += 1
                    end
                end
            end
        end
        scan(ch); scan(bp)
        return n
    end
    task.spawn(function()
        local guard = {}
        while Actions.alive do
            if COMBAT.reload and not Library.Panic then
                Actions.guardStep("Recarga automática", guard, doReload, function() COMBAT.reload = false end)
            else
                guard = {}
            end
            task.wait(Actions.getAdjustment("reloadInterval"))
        end
    end)

    -- trajetória do arremesso: linha de blocos à frente
    local throwParts = {}
    local function applyThrowLine(v)
        COMBAT.throwLine = v == true
        Actions.throwToken = (Actions.throwToken or 0) + 1
        local token = Actions.throwToken
        if not v then
            for _, p in ipairs(throwParts) do pcall(function() p:Destroy() end) end
            for i = 1, #throwParts do throwParts[i] = nil end
            return
        end
        task.spawn(function()
            local guard = {}
            while Actions.alive and COMBAT.throwLine and Actions.throwToken == token do
                if not Actions.guardStep("Trajetória do arremesso", guard, function()
                    for _, p in ipairs(throwParts) do pcall(function() p:Destroy() end) end
                    for i = 1, #throwParts do throwParts[i] = nil end
                    local ch = LP.Character
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dir = hrp.CFrame.LookVector
                        for i = 1, 10 do
                            local p = Instance.new("Part")
                            throwParts[#throwParts + 1] = p
                            p.Name = "BBC_Throw"
                            p.Anchored = true; p.CanCollide = false; p.CanQuery = false
                            p.Size = Vector3.new(0.3, 0.3, 0.3)
                            p.Material = Enum.Material.Neon
                            p.Color = Color3.fromRGB(255, 200, 90)
                            p.Transparency = 0.4
                            local t = i / 10
                            p.Position = hrp.Position + dir * (i * Actions.getAdjustment("throwRange") / 10) + Vector3.new(0, 2 - 6 * t * t, 0)
                            p.Parent = Workspace
                        end
                    end
                end, function() COMBAT.throwLine = false end) then break end
                task.wait(0.2)
            end
        end)
    end

    -- rastros do jogo: esconde trilhas/feixes do mundo
    local trailFx = { built = false, a0 = nil, a1 = nil, t = nil }
    local function applyTrail(v)
        COMBAT.trail = v == true
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not (ch and hrp) then return end
        if not trailFx.built then
            trailFx.built = true
            trailFx.a0 = Instance.new("Attachment"); trailFx.a1 = Instance.new("Attachment")
            trailFx.a0.Position = Vector3.new(0, 1.5, 0); trailFx.a1.Position = Vector3.new(0, -1.5, 0)
            trailFx.t = Instance.new("Trail")
            trailFx.t.Lifetime = Actions.getAdjustment("trailLifetime")
            trailFx.t.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
            trailFx.t.WidthScale = NumberSequence.new(1)
            Actions.trackConn(Actions.connect(LP.CharacterAdded, function()
                task.defer(function()
                    local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if h then trailFx.a0.Parent = h; trailFx.a1.Parent = h; trailFx.t.Parent = h end
                end)
            end))
        end
        trailFx.a0.Parent = hrp; trailFx.a1.Parent = hrp; trailFx.t.Parent = hrp
        trailFx.t.Enabled = COMBAT.trail
    end
    local savedTrails = {}
    local function applyGameTrails(v)
        COMBAT.gameTrails = v == true
        pcall(function()
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("Trail") or d:IsA("Beam") then
                    if v then
                        if savedTrails[d] == nil then savedTrails[d] = d.Enabled end
                        d.Enabled = false
                    elseif savedTrails[d] ~= nil then
                        d.Enabled = savedTrails[d]
                    end
                end
            end
        end)
    end

    local COMBAT_ACTIONS = {
        ["Alvo fixo"] = function(v) COMBAT.lock = v end,
        ["Previsão"] = function(v) COMBAT.predict = v end,
        ["Pausa inteligente"] = function(v) COMBAT.smartPause = v end,
        ["Notificar"] = function(v) COMBAT.notify = v end,
        ["FOV dinâmico"] = function(v) COMBAT.fovDyn = v end,
        ["Mirar em NPCs"] = function(v) COMBAT.npcs = v end,
        ["Ignorar obstáculos na mira"] = function(v) COMBAT.throughWalls = v end,
        ["Espiada subterrânea"] = function(v) applyPeek(v) end,
        ["Aura letal"] = function(v) COMBAT.aura = v; applyAura(v) end,
        ["Recarga automática"] = function(v)
            if v and not Actions.getReloadPath() then
                say(tr("Recarga bloqueada: configure um caminho de RemoteEvent conhecido."))
                error("Recarga automática requer BBC_CONFIG.ReloadRemotePath; verifique o README.")
            end
            COMBAT.reload = v
        end,
        ["Abastecer cargadores"] = function(v) COMBAT.refill = v; if v then local n = doRefill(); say("Cargadores: " .. n) end end,
        ["Retícula"] = function(v) COMBAT.reticle = v; if AIM.dot then AIM.dot.Visible = v end end,
        ["Círculo da mira"] = function(v) COMBAT.circle = v; if AIM.ring then AIM.ring.Visible = v end end,
        ["Rastro personalizado"] = function(v) applyTrail(v) end,
        ["Rastros do jogo"] = function(v) applyGameTrails(v) end,
        ["Marca de acerto"] = function(v)
            COMBAT.hitMark = v
            if not v then AIM.markToken = (AIM.markToken or 0) + 1; if AIM.mark then AIM.mark.Visible = false end end
        end,
        ["Números de dano"] = function(v) COMBAT.dmgNumbers = v end,
        ["Efeitos de acerto"] = function(v) COMBAT.hitFx = v == true; if not v then Actions.clearHitEffects() end end,
        ["Efeitos de eliminação"] = function(v) COMBAT.killFx = v end,
        ["Dados do alvo"] = function(v) COMBAT.targetData = v end,
        ["Só acertos confirmados"] = function(v) COMBAT.confirmedOnly = v end,
        ["Anti aim"] = function(v) applyAntiAim(v) end,
        ["Sob o chão"] = function(v) applyUnderGround(v) end,
        ["Fantasma"] = function(v) applyGhost(v) end,
        ["Trajetória do arremesso"] = function(v) applyThrowLine(v) end,
        ["Sem tremor"] = function(v) applyNoShake(v) end,
    }

    -- limpeza total: chamada pelo "Sair" (stopEngine)
    onCleanup(function()
        Actions.clearHitEffects()
        applyFirst(false)
        COMBAT.on = false
        CHAR.repeating = false
        if CHAR.track then pcall(function() CHAR.track:Stop() end) end
        stopOffset()
        COMBAT.reload = false
        COMBAT.aura = false
        COMBAT.antiAim = false
        COMBAT.underGround = false
        COMBAT.throwLine = false
        COMBAT.peek = false
        COMBAT.trail = false
        if AIM.conn then pcall(function() AIM.conn:Disconnect() end); AIM.conn = nil end
        if AIM.sg then pcall(function() AIM.sg:Destroy() end); AIM.sg = nil end
        if camConn then pcall(function() camConn:Disconnect() end); camConn = nil end
        if charConn then pcall(function() charConn:Disconnect() end); charConn = nil end
        for _, item in pairs(trailFx) do if typeof(item) == "Instance" then pcall(function() item:Destroy() end) end end
        for _, p in ipairs(throwParts) do pcall(function() p:Destroy() end) end
        for i = 1, #throwParts do throwParts[i] = nil end
        INV.on = false
        PANEL.on = false
        if invGui then pcall(function() invGui:Destroy() end); invGui = nil end
        if panelGui then pcall(function() panelGui:Destroy() end); panelGui = nil end
        stopFly()
    end)

    -- ===== efeitos locais (aba VISUAIS > LOCAL) =====
    local LOCALFX = { aura = false, circle = false, halo = false, trail = false, master = true, ready = false, intensity = { aura = 50, circle = 50, halo = 50, trail = 50 } }
    local fx = { built = false }
    local function attachLocalFx()
        if not Actions.alive then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local head = ch and ch:FindFirstChild("Head")
        if not (ch and hrp) then return end
        if fx.aura then fx.aura.Parent = hrp; fx.aura.Enabled = LOCALFX.master and LOCALFX.aura and not Library.Panic end
        if fx.halo then fx.halo.Parent = head or hrp; fx.halo.Enabled = LOCALFX.master and LOCALFX.halo and not Library.Panic end
        if fx.trail then fx.trailA0.Parent = hrp; fx.trailA1.Parent = hrp; fx.trail.Parent = hrp; fx.trail.Enabled = LOCALFX.master and LOCALFX.trail and not Library.Panic end
    end
    function Actions.setLocalFxIntensity(key, value)
        if LOCALFX.intensity[key] == nil or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
        value = math.clamp(value, 0, 100)
        LOCALFX.intensity[key] = value
        if key == "aura" and fx.aura then fx.aura.Brightness = 4 * value / 100 end
        if key == "halo" and fx.halo then fx.halo.Brightness = 3 * value / 100 end
        if key == "trail" and fx.trail then fx.trail.Lifetime = 0.1 + value / 100 end
        return true
    end
    local function ensureLocalFx()
        if fx.built then attachLocalFx(); return end
        fx.built = true
        fx.aura = Instance.new("PointLight")
        fx.aura.Color = Color3.fromRGB(255, 150, 60); fx.aura.Range = 14; fx.aura.Brightness = 2
        fx.halo = Instance.new("PointLight")
        fx.halo.Color = Color3.fromRGB(255, 220, 120); fx.halo.Range = 8; fx.halo.Brightness = 1.5
        fx.circle = Instance.new("Part")
        fx.circle.Name = "BBC_Circle"; fx.circle.Anchored = true; fx.circle.CanCollide = false; fx.circle.CanQuery = false
        fx.circle.Shape = Enum.PartType.Cylinder
        fx.circle.Size = Vector3.new(0.2, 10, 10); fx.circle.Material = Enum.Material.Neon
        fx.circle.Color = Color3.fromRGB(255, 170, 60); fx.circle.Transparency = 1
        fx.circle.Parent = Workspace
        fx.trailA0 = Instance.new("Attachment"); fx.trailA0.Position = Vector3.new(0, 1, 0)
        fx.trailA1 = Instance.new("Attachment"); fx.trailA1.Position = Vector3.new(0, -1, 0)
        fx.trail = Instance.new("Trail")
        fx.trail.Attachment0 = fx.trailA0; fx.trail.Attachment1 = fx.trailA1
        fx.trail.Lifetime = 0.6; fx.trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
        fx.trail.WidthScale = NumberSequence.new(1)
        for key, intensity in pairs(LOCALFX.intensity) do Actions.setLocalFxIntensity(key, intensity) end
        attachLocalFx()
        local function watchJump(ch)
            if Actions.fxJumpConn then pcall(function() Actions.fxJumpConn:Disconnect() end); Actions.fxJumpConn = nil end
            task.spawn(function()
                local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", 5)
                if not Actions.alive or LP.Character ~= ch or not hum or not hum:IsA("Humanoid") then return end
                Actions.fxJumpConn = Actions.connect(hum.StateChanged, function(_, newState)
                    if newState == Enum.HumanoidStateType.Jumping and LOCALFX.master and LOCALFX.circle and not Library.Panic then
                        LOCALFX.jumpUntil = os.clock() + 0.65
                    end
                end)
            end)
        end
        if LP.Character then watchJump(LP.Character) end
        Actions.trackConn(Actions.connect(LP.CharacterAdded, function(ch) task.defer(attachLocalFx); watchJump(ch) end))
    end
    local function applyLocalFx(name, v)
        LOCALFX[name] = v == true
        ensureLocalFx()
        attachLocalFx()
    end
    Actions.connections.localFx = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
        if not fx.circle then return end
        if LOCALFX.master and LOCALFX.circle and not Library.Panic and os.clock() < (LOCALFX.jumpUntil or 0) then
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                fx.circle.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
                fx.circle.Transparency = math.clamp(1 - 0.011 * LOCALFX.intensity.circle, 0, 1)
            else
                fx.circle.Transparency = 1
            end
        else
            fx.circle.Transparency = 1
        end
    end))
    local LOCALFX_ACTIONS = {
        ["Aura"] = function(v) applyLocalFx("aura", v) end,
        ["Círculo de salto"] = function(v) applyLocalFx("circle", v) end,
        ["Auréola"] = function(v) applyLocalFx("halo", v) end,
        ["Rastro estelar"] = function(v) applyLocalFx("trail", v) end,
    }
    local function applyLocalFxAll(v)
        LOCALFX.master = v == true
        if not LOCALFX.ready then return end   -- ainda não havia as opções criadas
        if fx.built then attachLocalFx() end
    end

    -- A Home conserva seu estado em closures próprias, sem ocupar os registros
    -- usados pelo restante da inicialização das ações.
    local function initializeProfile()
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
            if not Actions.alive or LP.Character ~= char or not hum then return end
            local last = hum.Health
            Actions.trackConn(Actions.connect(hum.HealthChanged, function(h)
                if h < last then data.damage += last - h end
                last = h
            end))
            Actions.trackConn(Actions.connect(hum.Died, function()
                data.deaths += 1
                if MV.respawn then task.delay(Actions.getAdjustment("respawnDelay"), function() if Actions.alive and MV.respawn and not Library.Panic and LP.Character == char and hum.Health <= 0 then pcall(function() LP:LoadCharacter() end) end end) end
            end))
        end
        if LP.Character then task.spawn(hookCharacter, LP.Character) end
        Actions.trackConn(Actions.connect(LP.CharacterAdded, hookCharacter))

        -- Abates por tag "creator" (jogos que usam essa convenção)
        local function hookVictim(plr)
            if plr == LP then return end
            local charConn, addedConn, removingConn, ancestryConn
            local function disconnectCharacter()
                if charConn then charConn:Disconnect(); charConn = nil end
            end
            local function onChar(char)
                local hum = char:WaitForChild("Humanoid", 10)
                if not Actions.alive or plr.Parent ~= Players or plr.Character ~= char or not hum then return end
                disconnectCharacter()
                charConn = Actions.connect(hum.Died,  function()
                    local tag = hum:FindFirstChild("creator")
                    if tag and tag.Value == LP then data.kills += 1 end
                end)
            end
            if plr.Character then task.spawn(onChar, plr.Character) end
            addedConn = Actions.connect(plr.CharacterAdded, onChar)
            removingConn = Actions.connect(plr.CharacterRemoving, disconnectCharacter)
            ancestryConn = Actions.connect(plr.AncestryChanged, function(_, parent)
                if parent then return end
                disconnectCharacter()
                if addedConn then addedConn:Disconnect() end
                if removingConn then removingConn:Disconnect() end
                if ancestryConn then ancestryConn:Disconnect() end
            end)
        end
        for _, p in ipairs(Players:GetPlayers()) do hookVictim(p) end
        Actions.trackConn(Actions.connect(Players.PlayerAdded, hookVictim))

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
            local ok2, p = pcall(function() return LP:GetNetworkPing() * 1000 end)
            return ok2 and math.floor(p) or 0
        end
        local function getDevice()
            local kb = UserInputService.KeyboardEnabled
            if UserInputService.TouchEnabled and not kb then return tr("Celular") end
            if UserInputService.GamepadEnabled and not kb then return tr("Console") end
            return "PC"
        end
        local frames, fps = 0, 0
        Actions.trackConn(Actions.connect(RunService.RenderStepped, function() frames += 1 end))

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
            local titleLabel = txt(f, string.upper(title), 12, "Muted", false, { LayoutOrder = 0 })
            return f, titleLabel
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
                if ok and Actions.alive and avatar.Parent then thumb = img; avatar.Image = img end
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
            Actions.trackConn(Actions.connect(nameL:GetPropertyChangedSignal("TextBounds"), placeBadge)); placeBadge()
            local hidden = false
            local spy = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(44, 44), Text = "OCULTAR", TextSize = 9, AutoButtonColor = false, FontFace = Library.Fonts.Bold }, idc)
            decorate(spy, "Background", 6); th(spy, "TextColor3", "Text")
            Actions.trackConn(Actions.connect(spy.MouseButton1Click, function()
                hidden = not hidden
                pcall(function() win:SetHideName(hidden); win:SetHideAvatar(hidden) end)
                nameL.Text = hidden and "••••••" or LP.DisplayName
                userL.Text = hidden and "@••••••" or ("@" .. LP.Name)
                avatar.Image = hidden and "" or (thumb or "")
                th(spy, "TextColor3", hidden and "Accent" or "Text")
            end))

            -- Estatísticas
            local st = box(root, "Estatísticas", 2)
            local sg = grid(st, 6, 1)
            local vKills = cell(sg, "Abates", 1, 15)
            local vDeaths = cell(sg, "Mortes", 2, 15)
            local vKD = cell(sg, "Proporção K/D", 3, 15)
            local vRep = cell(sg, "Denúncias", 4, 15)
            local vPlayed = cell(sg, "Tempo jogado", 5, 15)
            local vDmg = cell(sg, "Dano recebido", 6, 15)
            th(vKD, "TextColor3", "Accent"); vRep.Text = "—"

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

            -- Acesso rápido é apenas navegação: não ativa uma função ao abrir.
            do
                local favorites = box(root, "Favoritos", 5)
                local description = txt(favorites, tr("Segure uma opção e toque em Favoritar."), 12, "Muted", false, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20) })
                local current = txt(favorites, "", 12, "Muted", false, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 20) })
                local slots = {}
                for i = 1, Library.Favorites.MAX do
                    local b = mk("TextButton", { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i + 2, Visible = false,
                        Text = "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                        AutoButtonColor = false, FontFace = Library.Fonts.Regular }, favorites)
                    decorate(b, "Background", 4); th(b, "TextColor3", "Text")
                    local padding = mk("UIPadding", {}, b); padding.PaddingLeft = UDim.new(0, 8); padding.PaddingRight = UDim.new(0, 8)
                    local slot = { button = b }; slots[i] = slot
                    Actions.connect(b.MouseButton1Click, function() if slot.key then win:OpenFavorite(slot.key) end end)
                end
                local function renderFavorites()
                    if not root.Parent then return end
                    local items = Library.Favorites:get()
                    description.Visible = #items == 0
                    description.Text = tr("Segure uma opção e toque em Favoritar.")
                    current.Text = tr("Configuração ativa") .. ": " .. (win._cfgName or "—")
                    for i, slot in ipairs(slots) do
                        local key = items[i]
                        slot.key, slot.button.Visible = key, key ~= nil
                        if key then
                            local labelText = key
                            for _, d in ipairs(win._search or {}) do
                                if d.Parent and d:GetAttribute("SearchKey") == key and d:GetAttribute("SearchKind") == "Toggle" then
                                    labelText = tr(d:GetAttribute("SearchTab") or "") .. " · " .. tr(d:GetAttribute("SearchName") or "")
                                    break
                                end
                            end
                            slot.button.Text = labelText
                        end
                    end
                end
                win._refreshHomeFavorites = renderFavorites
                table.insert(Library.Favorites.listeners, renderFavorites)
                table.insert(onLanguageChanged, renderFavorites)
                renderFavorites()
            end
            do
                local recent, title = box(root, tr("Recentes nesta sessão"), 6)
                local empty = txt(recent, tr("Navegue pela busca ou favoritos para ver opções recentes."), 12, "Muted", false,
                    { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20) })
                local slots = {}
                for i = 1, Library.RecentNavigation.MAX do
                    local b = mk("TextButton", { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i + 1, Visible = false,
                        Text = "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                        AutoButtonColor = false, FontFace = Library.Fonts.Regular }, recent)
                    decorate(b, "Background", 4); th(b, "TextColor3", "Text")
                    local padding = mk("UIPadding", {}, b); padding.PaddingLeft = UDim.new(0, 8); padding.PaddingRight = UDim.new(0, 8)
                    local slot = { button = b }; slots[i] = slot
                    Actions.connect(b.MouseButton1Click, function() if slot.key then win:OpenFavorite(slot.key) end end)
                end
                local function renderRecent()
                    if not root.Parent then return end
                    local items = Library.RecentNavigation:get()
                    title.Text = string.upper(tr("Recentes nesta sessão"))
                    empty.Visible = #items == 0
                    empty.Text = tr("Navegue pela busca ou favoritos para ver opções recentes.")
                    for i, slot in ipairs(slots) do
                        local key = items[i]
                        slot.key, slot.button.Visible = key, key ~= nil
                        if key then
                            local text = key
                            for _, d in ipairs(win._search or {}) do
                                if d.Parent and d:GetAttribute("SearchKey") == key and d:GetAttribute("SearchKind") == "Toggle" then
                                    text = tr(d:GetAttribute("SearchTab") or "") .. " · " .. tr(d:GetAttribute("SearchName") or ""); break
                                end
                            end
                            slot.button.Text = text
                        end
                    end
                end
                table.insert(Library.RecentNavigation.listeners, renderRecent)
                table.insert(onLanguageChanged, renderRecent)
                renderRecent()
            end

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
                while Actions.alive and list.Parent do
                    task.wait(1)
                    if Actions.alive and list.Parent then pcall(refresh) end
                end
            end)
            Actions.trackConn(Actions.connect(Players.PlayerRemoving, function(p) if p == LP then save() end end))
        end
    end
    initializeProfile()

    -- Expor somente as referências utilizadas pelos módulos seguintes; os locais
    -- acima pertencem ao bloco e não ficam disponíveis fora dele automaticamente.
    -- Fallback independente dos toggles: se um callback de UI falhar ao
    -- desligar, ainda tentamos interromper estados, tarefas e efeitos locais.
    function Actions.stopRiskyWork()
        MV.speed, MV.sprint, MV.jumps, MV.air, MV.fly = false, false, false, false, false
        MV.noFall, MV.ground, MV.jesus, MV.spider = false, false, false, false
        MV.noDrown, MV.antiAfk, MV.respawn = false, false, false
        preFallHealth = nil
        swapOn, autoLoot = false, false
        Actions.swapToken = (Actions.swapToken or 0) + 1
        Actions.lootToken = (Actions.lootToken or 0) + 1
        COMBAT.on, COMBAT.reload, COMBAT.refill, COMBAT.aura = false, false, false, false
        COMBAT.antiAim, COMBAT.underGround, COMBAT.peek, COMBAT.throwLine = false, false, false, false
        WORLD.grama, WORLD.minas, WORLD.jogadores = false, false, false
        pcall(stopFly)
        pcall(Actions.restoreWalk)
        pcall(Actions.restoreSwim)
        pcall(stopOffset)
        pcall(applyAimState)
        pcall(applyAntiAim, false)
        pcall(applyUnderGround, false)
        pcall(applyPeek, false)
        pcall(applyThrowLine, false)
        pcall(applyGrama, false)
        pcall(applyMinas, false)
        pcall(removeEffects, false)
    end
    Library.Safety:trackStopper(Actions.stopRiskyWork)
    Actions.connect(LP.CharacterRemoving, function()
        if Actions.charSoundConn then Actions.charSoundConn:Disconnect(); Actions.charSoundConn = nil end
        Library.Safety:disableTracked()
    end)
    Actions.isAlive = function() return Actions.alive end
    Library.Safety:guardActions(PLAYER_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(WORLD_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(EXTRA_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(CHAR_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(LOCALFX_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(COMBAT_ACTIONS, Actions.isAlive)
    Actions.player, Actions.world, Actions.extra = PLAYER_ACTIONS, WORLD_ACTIONS, EXTRA_ACTIONS
    Actions.character, Actions.localfx, Actions.combat = CHAR_ACTIONS, LOCALFX_ACTIONS, COMBAT_ACTIONS
    Actions.EXTRA, Actions.LOCALFX, Actions.CAM, Actions.CHAR = EXTRA, LOCALFX, CAM, CHAR
    Actions.COMBAT, Actions.WEAPON, Actions.AIM, Actions.INV = COMBAT, WEAPON, AIM, INV
    Actions.WORLD, Actions.WORLD_COLORS = WORLD, WORLD_COLORS
    Actions.applyLocalFxAll, Actions.applyFov, Actions.playAnim = applyLocalFxAll, applyFov, playAnim
    Actions.applyAimState, Actions.clampCfg, Actions.say = applyAimState, clampCfg, say
    Actions.refreshAdjustment = function(key)
        if not Actions.alive then return end
        if key == "hotbarSlots" then hotbarRefresh() end
        if key == "panicZoneWidth" and Library._panicZone then Library._panicZone.Size = UDim2.fromOffset(Actions.getAdjustment(key), 56) end
        if key == "panelTextSize" and panelLabel then panelLabel.TextSize = Actions.getAdjustment(key) end
        if key == "bossOpacity" then for _, h in ipairs(bossHigh) do pcall(function() h.FillTransparency = Actions.getAdjustment(key) / 100 end) end end
        if key == "exitOpacity" then for _, h in ipairs(exitHigh) do pcall(function() h.FillTransparency = Actions.getAdjustment(key) / 100 end) end end
        if key == "waterTransparency" and WORLD.aguaOff then Actions.setProperty(Terrain, "WaterTransparency", Actions.getAdjustment(key)) end
        if key == "charTransparency" and CHAR.charVisible then applyCharVisible(true) end
        if key == "handTransparency" and CHAR.handsVisible then applyHands(true) end
        if key == "heldTransparency" and CHAR.heldVisible then applyHeld(true) end
        if key == "thirdZoom" and MV.third then applyCamera() end
        if key == "targetTextSize" and AIM.label then AIM.label.TextSize = Actions.getAdjustment(key) end
        if key == "reticleSize" and AIM.dot then
            local size = Actions.getAdjustment(key); AIM.dot.Size = UDim2.fromOffset(size, size)
        end
        if key == "ringThickness" and AIM.ringStroke then AIM.ringStroke.Thickness = Actions.getAdjustment(key) end
        if key == "trailLifetime" and trailFx.t then trailFx.t.Lifetime = Actions.getAdjustment(key) end
        if key == "ghostTransparency" and COMBAT.ghost then applyGhost(true) end
        if key == "peekDepth" and COMBAT.peek then applyPeek(true) end
        if key == "brightness" or key == "clockTime" or key == "shadowSoftness" or key == "fogDensity" or key == "haze"
            or key == "cloudCover" or key == "bloom" or key == "blur" or key == "saturation" or key == "contrast"
            or key == "focus" or key == "farIntensity" or key == "rays" or key == "raysSpread" or key == "shadowGearSoftness" or key == "skyStars" or key == "toneWarmth" then applyLighting() end
    end
    Actions.paintTerrain, Actions.paintPlants, Actions.applyLighting = paintTerrain, paintPlants, applyLighting
    Actions.setPanicVisuals = function(on)
        for _, h in ipairs(bossHigh) do pcall(function() h.Enabled = not on end) end
        for _, h in ipairs(exitHigh) do pcall(function() h.Enabled = not on end) end
        if on then
            AIM.markToken = (AIM.markToken or 0) + 1
            if AIM.mark then AIM.mark.Visible = false end
            Actions.clearHitEffects()
            for part in pairs(CHAR.firstParts or {}) do Actions.restoreProperty(part, "LocalTransparencyModifier") end
        end
        if invGui then invGui.Enabled = not on and INV.on end
        if panelGui then panelGui.Enabled = not on and PANEL.on end
        if hotbar.gui then hotbar.gui.Enabled = not on and hotbar.on end
        if trailFx.t then trailFx.t.Enabled = not on and COMBAT.trail end
        if fx.built then attachLocalFx() end
        if on and fx.circle then fx.circle.Transparency = 1 end
    end
    Actions.toggleInv, Actions.refreshInv, Actions.cleanups = toggleInv, refreshInv, CLEANUPS
    Actions.noclipPulse, Actions.setSoundId, Actions.sortBackpack = noclipPulse, setSoundId, sortBackpack
    Actions.setZoomKey = function(name) if type(name) == "string" and Enum.KeyCode[name] then zoomKeyName = name end end
    onCleanup(function()
        Actions.alive = false
        for conn in pairs(Actions.tracked) do pcall(function() conn:Disconnect() end) end
        table.clear(Actions.tracked)
        MV.antiAfk = false
        swapOn, autoLoot = false, false
        for _, conn in pairs(Actions.connections) do pcall(function() conn:Disconnect() end) end
        pcall(applyGameTrails, false)
        pcall(applyGrama, false)
        pcall(applyMinas, false)
        pcall(removeEffects, false)
        clearHigh(bossHigh); clearHigh(exitHigh)
        stopNoclip()
        if Actions.backpackOriginal ~= nil then
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, Actions.backpackOriginal) end)
        end
        for _, sound in pairs(soundObjs) do pcall(function() sound:Destroy() end) end
        for _, obj in pairs(FX) do pcall(function() obj:Destroy() end) end
        for mat, color in pairs(Actions.terrainColors or {}) do pcall(function() Terrain:SetMaterialColor(mat, color) end) end
        for obj, saved in pairs(Actions.originals) do
            for prop in pairs(saved) do Actions.restoreProperty(obj, prop) end
        end
        for _, obj in pairs(fx) do
            if typeof(obj) == "Instance" then pcall(function() obj:Destroy() end) end
        end
        Actions.restoreWalk(); Actions.restoreSwim()
    end)
end
initializeActions()


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
        Actions.connect(b.MouseButton1Click, onClick)
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
        local cName = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.34, 0, 1, 0), Position = UDim2.fromOffset(10, 0) })
        local cPing = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.15, 0, 1, 0), Position = UDim2.new(0.37, 0, 0, 0) })
        local cPl = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.17, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0) })
        local cFps = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.12, 0, 1, 0), Position = UDim2.new(0.69, 0, 0, 0) })

        -- Lista com rolagem própria
        local scroller = mk("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
            CanvasSize = UDim2.new(), LayoutOrder = 5, ScrollingDirection = Enum.ScrollingDirection.Y }, root)
        th(scroller, "ScrollBarImageColor3", "Accent")
        local rowLayout = mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, scroller)
        mk("UIPadding", { PaddingRight = UDim.new(0, 8) }, scroller)
        Actions.connect(rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
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

        local function joinServer(sv)
            if not sv then return end
            table.insert(history, 1, { id = sv.id, playing = sv.playing, maxPlayers = sv.maxPlayers, ping = sv.ping, fps = sv.fps, when = os.time() })
            while #history > 30 do table.remove(history) end
            saveHistory()
            notify(tr("Entrando no servidor..."))
            Library:JoinServer(sv.id)
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
                txt(row, mapName, 14, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.34, -10, 0, 18) })
                txt(row, (sv.id == game.JobId and (tr("Seu servidor") .. " · ") or "") .. shortId(sv.id), 11, "Muted", false, { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(0.34, -10, 0, 16) })
                local ping = tonumber(sv.ping)
                txt(row, ping and (math.floor(ping) .. " ms") or "—", 13, "Text", false, { Position = UDim2.new(0.37, 0, 0, 12), Size = UDim2.new(0.15, 0, 0, 18) })
                txt(row, (sv.playing or 0) .. "/" .. (sv.maxPlayers or 0), 13, "Text", false, { Position = UDim2.new(0.52, 0, 0, 12), Size = UDim2.new(0.17, 0, 0, 18) })
                local fps = tonumber(sv.fps)
                txt(row, fps and tostring(math.floor(fps)) or "—", 13, "Text", false, { Position = UDim2.new(0.69, 0, 0, 12), Size = UDim2.new(0.12, 0, 0, 18) })
                local full = (sv.playing or 0) >= (sv.maxPlayers or 0) and (sv.maxPlayers or 0) > 0
                local joinB = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(62, 28), Text = tr("Entrar"), TextSize = 13,
                    AutoButtonColor = false, FontFace = Library.Fonts.Bold, BorderSizePixel = 0, ZIndex = 3 }, row)
                th(joinB, "BackgroundColor3", full and "Surface3" or "Accent")
                th(joinB, "TextColor3", "Text")
                mk("UICorner", { CornerRadius = UDim.new(0, 5) }, joinB)
                Actions.connect(joinB.MouseButton1Click, function() state.selected = sv; renderDetails(); joinServer(sv) end)
                Actions.connect(row.MouseButton1Click, function() selectServer(sv) end)
            end
        end

        local function load()
            if state.loading then return end
            state.loading, state.failed = true, false
            render()
            task.spawn(function()
                local all, cursor = {}, nil
                for _ = 1, 3 do
                    if not Actions.alive then return end
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
                if not Actions.alive then return end
                state.all, state.loading = all, false
                pcall(render)
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
        bJoin = btn(detBtns, "", 80, function() joinServer(state.selected) end, 2)

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
            Actions.connect(b.MouseButton1Click, function() state[key] = not state[key]; paint(); render() end)
            table.insert(onLanguageChanged, paint)
        end
        filterToggle("hideFull", "Ocultar cheios", 1)
        filterToggle("hideMine", "Ocultar meu servidor", 2)

        Actions.connect(box:GetPropertyChangedSignal("Text"), function() state.query = box.Text; render() end)
        Actions.connect(sortBtn.MouseButton1Click, function()
            state.sort = state.sort == "players" and "ping" or (state.sort == "ping" and "fps" or "players")
            render()
        end)
        Actions.connect(dirBtn.MouseButton1Click, function() state.desc = not state.desc; render() end)
        table.insert(onLanguageChanged, function() renderDetails(); render() end)
        renderDetails()
        load()
    end
end
