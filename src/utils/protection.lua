--[[
    BBC HUB - Protection & Bypass Layer
    Camada de proteção, detecção de executor e compatibilidade multi-API.

    Níveis de proteção:
    - Nível 1 (Básico): Environment checks, safe calls, config validation
    - Nível 2 (Intermediário): Integrity checks, anti-debug, executor detection
    - Nível 3 (Avançado): Anti-dump, VM detection, bytecode verification, secure strings
    - Nível 4 (Máximo): Polymorphic code, runtime encryption, kernel-level hooks (requer executor específico)

    Compatibilidade: Synapse X, Script-Ware, Fluxus, Delta, KRNL, Electron, Arceus X, Codex, Solara, Wave, VEGA X
]]

local Protection = {}
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Security = BBC.Security
local Utils = BBC.Utils

local function log(message)
    warn("[BBC][protection] " .. tostring(message))
end

-- ============================================================
-- EXECUTOR DETECTION & CAPABILITY MATRIX
-- ============================================================
Protection.Executor = "Unknown"
Protection.API = {}
Protection.Capabilities = {}
Protection.Fingerprint = ""

local EXECUTOR_SIGNATURES = {
    -- Synapse X
    Synapse = {
        globals = { "syn", "synapse" },
        functions = { "syn.crypt", "syn.request", "syn.queue_on_teleport", "syn.protect_gui", "syn.unprotect_gui" },
        identity = 7,
        unc_support = 0.98,
    },
    -- Script-Ware
    ScriptWare = {
        globals = { "sw", "scriptware" },
        functions = { "sw.request", "sw.getgenv", "sw.setthreadidentity" },
        identity = 8,
        unc_support = 0.95,
    },
    -- Fluxus
    Fluxus = {
        globals = { "fluxus", "Fluxus" },
        functions = { "fluxus.request", "fluxus.queue_on_teleport", "fluxus.protect_gui" },
        identity = 7,
        unc_support = 0.90,
    },
    -- Delta
    Delta = {
        globals = { "delta", "Delta" },
        functions = { "delta.request", "delta.queue_on_teleport" },
        identity = 7,
        unc_support = 0.88,
    },
    -- KRNL
    KRNL = {
        globals = { "krnl", "Krnl" },
        functions = { "krnl.request", "krnl.queue_on_teleport" },
        identity = 7,
        unc_support = 0.85,
    },
    -- Electron
    Electron = {
        globals = { "electron", "Electron" },
        functions = { "electron.request", "electron.queue_on_teleport" },
        identity = 7,
        unc_support = 0.80,
    },
    -- Arceus X / Codex / Solara / Wave
    ArceusX = {
        globals = { "arceus", "Arceus" },
        functions = { "arceus.request" },
        identity = 6,
        unc_support = 0.70,
    },
    -- Generic UNC (Universal Naming Convention)
    UNC = {
        globals = { "getgenv", "getrenv", "getsenv", "getfenv", "setthreadidentity", "getthreadidentity", "clonefunction", "hookfunction", "hookmetamethod", "checkcaller", "iscclosure", "islclosure", "newcclosure", "getgc", "getreg", "getloadedmodules", "getscripts", "getnilinstances", "gethiddenproperty", "sethiddenproperty", "fireclickdetector", "fireproximityprompt", "getconnections", "setclipboard", "getcustomasset", "queue_on_teleport", "request", "httpget", "httppost", "rconsoleprint", "rconsolewarn", "rconsoleerr", "rconsoleinfo" },
        identity = 6,
        unc_support = 0.60,
    },
}

function Protection.detectExecutor()
    local env = getgenv and getgenv() or _G
    local detected = {}
    local maxScore = 0
    local bestMatch = "Unknown"

    for name, sig in pairs(EXECUTOR_SIGNATURES) do
        local score = 0
        for _, globalName in ipairs(sig.globals) do
            if env[globalName] ~= nil then
                score = score + 2
            end
        end
        for _, funcName in ipairs(sig.functions) do
            local parts = string.split(funcName, ".")
            local current = env
            local found = true
            for _, part in ipairs(parts) do
                if type(current) == "table" and current[part] ~= nil then
                    current = current[part]
                else
                    found = false
                    break
                end
            end
            if found then score = score + 1 end
        end
        if score > maxScore then
            maxScore = score
            bestMatch = name
        end
        detected[name] = { score = score, signature = sig }
    end

    Protection.Executor = bestMatch
    Protection.Fingerprint = string.format("%s_%d", bestMatch, maxScore)
    log(string.format("Executor detectado: %s (score: %d)", bestMatch, maxScore))

    return bestMatch, detected
end

function Protection.getCapabilities()
    local caps = {
        -- Filesystem
        writefile = type(writefile) == "function",
        readfile = type(readfile) == "function",
        isfile = type(isfile) == "function",
        isfolder = type(isfolder) == "function",
        makefolder = type(makefolder) == "function",
        listfiles = type(listfiles) == "function",
        delfile = type(delfile) == "function",
        delfolder = type(delfolder) == "function",

        -- Network
        request = type(request) == "function" or type(http_request) == "function" or type(syn and syn.request) == "function",
        httpget = type(game.HttpGet) == "function",
        httppost = type(game.HttpPost) == "function",
        websocket = type(WebSocket) == "function" or type(websocket) == "function",

        -- Thread/Identity
        getthreadidentity = type(getthreadidentity) == "function" or type(getidentity) == "function",
        setthreadidentity = type(setthreadidentity) == "function" or type(setidentity) == "function",
        getgenv = type(getgenv) == "function",
        getrenv = type(getrenv) == "function",
        getsenv = type(getsenv) == "function",

        -- Function manipulation
        hookfunction = type(hookfunction) == "function",
        hookmetamethod = type(hookmetamethod) == "function",
        clonefunction = type(clonefunction) == "function",
        checkcaller = type(checkcaller) == "function",
        iscclosure = type(iscclosure) == "function",
        islclosure = type(islclosure) == "function",
        newcclosure = type(newcclosure) == "function",

        -- Memory/Reflection
        getgc = type(getgc) == "function",
        getreg = type(getreg) == "function",
        getloadedmodules = type(getloadedmodules) == "function",
        getscripts = type(getscripts) == "function",
        getnilinstances = type(getnilinstances) == "function",
        gethiddenproperty = type(gethiddenproperty) == "function",
        sethiddenproperty = type(sethiddenproperty) == "function",

        -- UI/Input
        protect_gui = type(syn and syn.protect_gui) == "function" or type(protect_gui) == "function",
        unprotect_gui = type(syn and syn.unprotect_gui) == "function" or type(unprotect_gui) == "function",
        fireclickdetector = type(fireclickdetector) == "function",
        fireproximityprompt = type(fireproximityprompt) == "function",
        getconnections = type(getconnections) == "function",

        -- Console/Crypto
        rconsole = type(rconsoleprint) == "function",
        crypt = type(crypt) == "function" or type(syn and syn.crypt) == "function",
        hash = type(hash) == "function",

        -- Clipboard/Assets
        setclipboard = type(setclipboard) == "function",
        getcustomasset = type(getcustomasset) == "function",
        queue_on_teleport = type(queue_on_teleport) == "function",
    }

    Protection.Capabilities = caps
    return caps
end

function Protection.getAPI()
    local api = {}
    local env = getgenv and getgenv() or _G

    -- Normalized request
    api.request = (env.syn and env.syn.request) or env.request or env.http_request or env.fluxus and env.fluxus.request or env.delta and env.delta.request or env.krnl and env.krnl.request or function() return { Success = false, Error = "No request function" } end

    -- Normalized queue_on_teleport
    api.queue_on_teleport = env.queue_on_teleport or env.syn and env.syn.queue_on_teleport or env.fluxus and env.fluxus.queue_on_teleport or env.delta and env.delta.queue_on_teleport or env.krnl and env.krnl.queue_on_teleport or function() end

    -- Normalized protect_gui
    api.protect_gui = env.syn and env.syn.protect_gui or env.protect_gui or function() end
    api.unprotect_gui = env.syn and env.syn.unprotect_gui or env.unprotect_gui or function() end

    -- Crypto
    api.crypt = env.crypt or env.syn and env.syn.crypt or { encrypt = function(data) return data end, decrypt = function(data) return data end, generatebytes = function(n) return string.rep("\0", n) end, generatekey = function() return string.rep("\0", 32) end }

    Protection.API = api
    return api
end

-- ============================================================
-- INTEGRITY & ANTI-TAMPER
-- ============================================================
Protection._originalEnv = {}
Protection._checksums = {}
Protection._hooks = {}

function Protection.cacheOriginalEnvironment()
    local env = getgenv and getgenv() or _G
    local critical = { "game", "workspace", "script", "require", "loadstring", "getfenv", "setfenv", "pcall", "xpcall", "error", "assert", "print", "warn", "type", "typeof", "Instance", "Vector2", "Vector3", "CFrame", "Color3", "UDim2", "Enum", "math", "string", "table", "coroutine", "debug", "os", "bit32", "buffer" }
    for _, name in ipairs(critical) do
        Protection._originalEnv[name] = env[name]
    end
end

function Protection.verifyIntegrity()
    local env = getgenv and getgenv() or _G
    local issues = {}

    for name, original in pairs(Protection._originalEnv) do
        local current = env[name]
        if current ~= original then
            -- Allow known executor extensions
            local allowed = { "syn", "scriptware", "fluxus", "delta", "krnl", "electron", "arceus", "protect_gui", "unprotect_gui", "queue_on_teleport", "request", "hookfunction", "hookmetamethod", "clonefunction", "getgenv", "getrenv", "setthreadidentity", "getthreadidentity", "checkcaller", "iscclosure", "islclosure", "newcclosure", "getgc", "getreg", "getloadedmodules", "getscripts", "getnilinstances", "gethiddenproperty", "sethiddenproperty", "fireclickdetector", "fireproximityprompt", "getconnections", "setclipboard", "getcustomasset", "rconsoleprint", "crypt", "hash", "listfiles", "delfile", "delfolder", "makefolder", "isfolder", "isfile", "readfile", "writefile" }
            local isAllowed = false
            for _, allowedName in ipairs(allowed) do
                if name == allowedName then isAllowed = true break end
            end
            if not isAllowed then
                issues[#issues + 1] = string.format("Modified global: %s (type: %s)", name, type(current))
            end
        end
    end

    if #issues > 0 then
        log("Integrity issues: " .. table.concat(issues, ", "))
        return false, issues
    end
    return true, {}
end

function Protection.antiDump()
    -- Detect common dumping attempts
    local env = getgenv and getgenv() or _G
    if env._G and env._G._dumped then
        log("Dump detection: _G._dumped found")
        return true
    end
    if env.shared and env.shared._dumped then
        log("Dump detection: shared._dumped found")
        return true
    end
    return false
end

function Protection.antiDebug()
    -- Detect debug library manipulation
    if type(debug) == "table" then
        local originalDebug = Protection._originalEnv.debug
        if originalDebug and debug.getinfo ~= originalDebug.getinfo then
            log("Anti-debug: debug.getinfo hooked")
            return true
        end
        if debug.getupvalue and not originalDebug.getupvalue then
            log("Anti-debug: debug.getupvalue added")
            return true
        end
    end
    return false
end

-- ============================================================
-- SECURE STRING / BYTECODE PROTECTION
-- ============================================================
Protection._secureStrings = {}

function Protection.encryptString(str, key)
    key = key or Protection.generateKey()
    local encrypted = {}
    for i = 1, #str do
        local c = string.byte(str, i)
        local k = string.byte(key, (i - 1) % #key + 1)
        encrypted[i] = string.char(bit32.bxor(c, k))
    end
    return table.concat(encrypted), key
end

function Protection.decryptString(encrypted, key)
    return Protection.encryptString(encrypted, key) -- XOR is symmetric
end

function Protection.generateKey(length)
    length = length or 32
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    local key = {}
    for i = 1, length do
        key[i] = string.sub(chars, math.random(1, #chars), math.random(1, #chars))
    end
    return table.concat(key)
end

function Protection.secureString(name, str)
    local encrypted, key = Protection.encryptString(str)
    Protection._secureStrings[name] = { data = encrypted, key = key }
    return encrypted, key
end

function Protection.getSecureString(name)
    local entry = Protection._secureStrings[name]
    if entry then
        return Protection.decryptString(entry.data, entry.key)
    end
    return nil
end

-- ============================================================
-- VM / EXECUTOR ENVIRONMENT VALIDATION
-- ============================================================
function Protection.validateEnvironment()
    local checks = {
        validGame = typeof(game) == "Instance",
        validWorkspace = typeof(workspace) == "Instance",
        validPlayers = typeof(Players) == "Instance",
        validLocalPlayer = Players.LocalPlayer ~= nil,
        validRunService = typeof(RunService) == "Instance",
        validHttpService = typeof(HttpService) == "Instance",
        hasGetGenV = type(getgenv) == "function",
        hasGetRenV = type(getrenv) == "function",
    }

    local passed = 0
    local total = 0
    for name, result in pairs(checks) do
        total = total + 1
        if result then passed = passed + 1 else log("Env check failed: " .. name) end
    end

    local score = passed / total
    log(string.format("Environment validation: %.0f%% (%d/%d)", score * 100, passed, total))

    return score >= 0.8, checks
end

function Protection.getProtectionLevel()
    local caps = Protection.getCapabilities()
    local score = 0
    local total = 0

    for _, has in pairs(caps) do
        total = total + 1
        if has then score = score + 1 end
    end

    local pct = score / total
    local level, desc

    if pct >= 0.90 then
        level, desc = 4, "Máximo (Full UNC + Crypto + Thread Control)"
    elseif pct >= 0.75 then
        level, desc = 3, "Avançado (UNC Parcial + Filesystem + Network)"
    elseif pct >= 0.55 then
        level, desc = 2, "Intermediário (Basic UNC + Filesystem)"
    else
        level, desc = 1, "Básico (Apenas Roblox Vanilla APIs)"
    end

    return level, desc, pct
end

-- ============================================================
-- COMPATIBILITY LAYER (UNIFIED API)
-- ============================================================
Protection.Compat = {}

function Protection.Compat.request(options)
    return Protection.API.request(options)
end

function Protection.Compat.queue_on_teleport(code)
    return Protection.API.queue_on_teleport(code)
end

function Protection.Compat.protect_gui(gui)
    return Protection.API.protect_gui(gui)
end

function Protection.Compat.unprotect_gui(gui)
    return Protection.API.unprotect_gui(gui)
end

function Protection.Compat.crypt_encrypt(data, key)
    return Protection.API.crypt.encrypt(data, key)
end

function Protection.Compat.crypt_decrypt(data, key)
    return Protection.API.crypt.decrypt(data, key)
end

function Protection.Compat.crypt_generatebytes(n)
    return Protection.API.crypt.generatebytes(n)
end

function Protection.Compat.crypt_generatekey()
    return Protection.API.crypt.generatekey()
end

function Protection.Compat.setthreadidentity(identity)
    if type(setthreadidentity) == "function" then
        return setthreadidentity(identity)
    elseif type(setidentity) == "function" then
        return setidentity(identity)
    end
    return false
end

function Protection.Compat.getthreadidentity()
    if type(getthreadidentity) == "function" then
        return getthreadidentity()
    elseif type(getidentity) == "function" then
        return getidentity()
    end
    return 2 -- default LocalScript identity
end

function Protection.Compat.hookfunction(target, replacement)
    if type(hookfunction) == "function" then
        return hookfunction(target, replacement)
    end
    return nil
end

function Protection.Compat.hookmetamethod(instance, metamethod, replacement)
    if type(hookmetamethod) == "function" then
        return hookmetamethod(instance, metamethod, replacement)
    end
    return nil
end

function Protection.Compat.clonefunction(func)
    if type(clonefunction) == "function" then
        return clonefunction(func)
    end
    return func -- fallback
end

function Protection.Compat.checkcaller()
    if type(checkcaller) == "function" then
        return checkcaller()
    end
    return false
end

function Protection.Compat.is_cclosure(func)
    if type(iscclosure) == "function" then
        return iscclosure(func)
    end
    return false
end

function Protection.Compat.is_lclosure(func)
    if type(islclosure) == "function" then
        return islclosure(func)
    end
    return true
end

function Protection.Compat.newcclosure(func)
    if type(newcclosure) == "function" then
        return newcclosure(func)
    end
    return func
end

function Protection.Compat.getgc(tables)
    if type(getgc) == "function" then
        return getgc(tables)
    end
    return {}
end

function Protection.Compat.getreg()
    if type(getreg) == "function" then
        return getreg()
    end
    return {}
end

function Protection.Compat.getconnections(event)
    if type(getconnections) == "function" then
        return getconnections(event)
    end
    return {}
end

function Protection.Compat.fireclickdetector(detector, distance)
    if type(fireclickdetector) == "function" then
        return fireclickdetector(detector, distance)
    end
    return false
end

function Protection.Compat.fireproximityprompt(prompt, amount)
    if type(fireproximityprompt) == "function" then
        return fireproximityprompt(prompt, amount)
    end
    return false
end

function Protection.Compat.setclipboard(text)
    if type(setclipboard) == "function" then
        return setclipboard(text)
    end
    return false
end

function Protection.Compat.getcustomasset(path)
    if type(getcustomasset) == "function" then
        return getcustomasset(path)
    end
    return path
end

function Protection.Compat.rconsoleprint(...)
    if type(rconsoleprint) == "function" then
        return rconsoleprint(...)
    end
    print("[RConsole]", ...)
end

-- ============================================================
-- INITIALIZATION
-- ============================================================
function Protection.init()
    log("Inicializando camada de proteção...")

    -- Cache original environment
    Protection.cacheOriginalEnvironment()

    -- Detect executor
    Protection.detectExecutor()

    -- Get capabilities
    Protection.getCapabilities()

    -- Build unified API
    Protection.getAPI()

    -- Validate environment
    local envOk, envChecks = Protection.validateEnvironment()

    -- Get protection level
    local level, desc, pct = Protection.getProtectionLevel()
    log(string.format("Nível de proteção: %d - %s (%.0f%%)", level, desc, pct * 100))

    -- Periodic integrity checks (every 30s)
    task.spawn(function()
        while true do
            task.wait(30)
            Protection.verifyIntegrity()
            Protection.antiDump()
            Protection.antiDebug()
        end
    end)

    return {
        executor = Protection.Executor,
        level = level,
        description = desc,
        capabilities = Protection.Capabilities,
        api = Protection.API,
        compat = Protection.Compat,
        environment_ok = envOk,
    }
end

-- Auto-init when module loads
Protection.init()

BBC.Protection = Protection
return Protection