-- Preferências somente visuais, lidas antes da intro. Nunca aplicam opções de jogo.
Library.Appearance = { theme = "Orange", color = {1, 130 / 255, 25 / 255}, contrast = false, motion = false, skipIntro = false, writable = true }
do
    local A = Library.Appearance
    local path = "BBC_HUB/appearance.json"
    A.colorListeners = {}
    local function validColor(t)
        if type(t) ~= "table" or #t ~= 3 then return false end
        for k, v in pairs(t) do
            if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > 3 or type(v) ~= "number" or v ~= v or v < 0 or v > 1 then return false end
        end
        return true
    end
    local function valid(data)
        if type(data) ~= "table" then return false end
        local allowed = { theme = true, color = true, contrast = true, motion = true, skipIntro = true, v = true }
        for k in pairs(data) do if not allowed[k] then return false end end
        if data.v ~= 1 or type(data.theme) ~= "string" or (data.theme ~= "Custom" and not Library.ThemePresets[data.theme]) then return false end
        return validColor(data.color) and type(data.contrast) == "boolean" and type(data.motion) == "boolean" and type(data.skipIntro) == "boolean"
    end
    function A:load()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
        local ok, exists = pcall(isfile, path)
        if not ok then self.writable = false; return false end
        if not exists then return false end
        local readOK, raw = pcall(readfile, path)
        local parseOK, data = false, nil
        if readOK and type(raw) == "string" and #raw <= 8192 then parseOK, data = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end) end
        if not parseOK or not valid(data) then
            self.writable = false
            warn("[BBC] Preferências visuais inválidas; arquivo preservado.")
            return false
        end
        self.theme, self.color, self.contrast, self.motion, self.skipIntro = data.theme, data.color, data.contrast, data.motion, data.skipIntro
        return true
    end
    function A:save()
        if not self.writable or type(writefile) ~= "function" or type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
        local data = { v = 1, theme = self.theme, color = self.color, contrast = self.contrast, motion = self.motion, skipIntro = self.skipIntro }
        if not valid(data) then return false end
        local ok, err = pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            if isfile(path) then
                local previous = readfile(path)
                assert(type(previous) == "string" and #previous <= 8192, "preferências visuais inválidas")
                local decoded = game:GetService("HttpService"):JSONDecode(previous)
                assert(valid(decoded), "preferências visuais inválidas")
                writefile(path .. ".bak", previous)
            end
            writefile(path, game:GetService("HttpService"):JSONEncode(data))
        end)
        if not ok then
            warn("[BBC] Falha ao salvar aparência: " .. tostring(err))
            if Library.Diagnostics then Library.Diagnostics:record("aparência", err) end
        end
        return ok
    end
    function A:applyTheme()
        local base = self.theme == "Custom" and Library.MakeTheme(Color3.new(self.color[1], self.color[2], self.color[3]), "neutral") or Library.ThemePresets[self.theme]
        if not base then return false end
        Library.ThemeName = self.theme
        for k, v in pairs(base) do Library.Theme[k] = v end
        if self.contrast then
            Library.Theme.Background = Color3.fromRGB(0, 0, 0)
            Library.Theme.Surface = Color3.fromRGB(15, 15, 15)
            Library.Theme.Surface2 = Color3.fromRGB(30, 30, 30)
            Library.Theme.Surface3 = Color3.fromRGB(46, 46, 46)
            Library.Theme.Stroke = Color3.fromRGB(145, 145, 145)
            Library.Theme.Text = Color3.fromRGB(255, 255, 255)
            Library.Theme.Muted = Color3.fromRGB(210, 210, 210)
        end
        for i = #Library._bindings, 1, -1 do
            local b = Library._bindings[i]
            if b[1] and b[1].Parent then pcall(function() b[1][b[2]] = b[3]() end) else table.remove(Library._bindings, i) end
        end
        for _, fn in ipairs(Library._themeListeners) do pcall(fn) end
        return true
    end
    function Library:SetTheme(name, noSave)
        if type(name) ~= "string" or (name ~= "Custom" and not self.ThemePresets[name]) then return false end
        A.theme = name
        A:applyTheme()
        if not noSave then A:save() end
        return true
    end
    function A:setColor(t, noSave)
        if not validColor(t) then return false end
        self.color = {t[1], t[2], t[3]}
        for _, fn in ipairs(self.colorListeners) do pcall(fn, self.color) end
        if self.theme == "Custom" then self:applyTheme() end
        if not noSave then self:save() end
        return true
    end
    function A:setFlag(key, value, noSave)
        if (key ~= "contrast" and key ~= "motion" and key ~= "skipIntro") or type(value) ~= "boolean" then return false end
        self[key] = value
        Library.ReduceMotion = self.motion
        if key == "contrast" then self:applyTheme() end
        if not noSave then self:save() end
        return true
    end
    A:load()
    Library.ReduceMotion = A.motion
    A:applyTheme()
    -- Chaves estáveis incluem aparência na configuração do menu. O arquivo
    -- separado é apenas o espelho visual para a próxima intro.
    Library.Registry["__appearance/color"] = { name = "Cor personalizada", get = function() return {A.color[1], A.color[2], A.color[3]} end, set = function(v) return A:setColor(v) end, validate = validColor }
    Library.Registry["__appearance/theme"] = { name = "Tema", get = function() return A.theme end, set = function(v) return Library:SetTheme(v) end,
        validate = function(v) return type(v) == "string" and (v == "Custom" or Library.ThemePresets[v] ~= nil) end }
end
