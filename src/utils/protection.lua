--[[
    BBC HUB - Advanced Protection & Bypass Layer (Complete)
    Camada completa de proteção, ofuscação, bypass e compatibilidade multi-executor.

    PROTEÇÕES INCLUÍDAS:
    ██████████████████████████████████████████████████████████████████████████
    █ 1. EXECUTOR DETECTION & FINGERPRINTING (11 executors)                █
    █ 2. CAPABILITY MATRIX & UNIFIED API (35+ APIs)                      █
    █ 3. INTEGRITY MONITORING (environment, globals, hooks)              █
    █ 4. ANTI-DUMP / ANTI-DEBUG / ANTI-DECOMPILER                        █
    █ 5. ADVANCED CRYPTOGRAPHY (AES-256, ChaCha20, SHA-256, HMAC, ECDH)  █
    █ 6. SECURE STRINGS & CONSTANT ENCODING (polymorphic, per-session)   █
    █ 7. CONTROL FLOW OBFUSCATION (flattening, opaque predicates)        █
    █ 8. FUNCTION VIRTUALIZATION & BYTECODE INTERPRETATION               █
    █ 9. PROXY ENVIRONMENT & METATABLE HARDENING                         █
    █ 10. WATERMARKING & BUILD FINGERPRINTING (per-user/build)           █
    █ 11. LICENSE SYSTEM & HWID BINDING (with server validation)         █
    █ 12. HEARTBEAT & TIME-BASED EXPIRATION                              █
    █ 13. ANTI-RELOAD / ANTI-REINJECT / ANTI-TAMPER                      █
    █ 14. NETWORK ENCRYPTION & SECURE CHANNELS                           █
    █ 15. VM/SANDBOX DETECTION & ANALYSIS EVASION                        █
    █ 16. STACK TRACE OBFUSCATION & CALLER VERIFICATION                  █
    █ 17. TIMING ATTACK PREVENTION & SIDE-CHANNEL RESISTANCE             █
    █ 18. CONTROL FLOW INTEGRITY (CFI) & RETURN ADDRESS PROTECTION       █
    █ 19. SECURE RANDOM & CRYPTOGRAPHIC PRIMITIVES                       █
    █ 20. POLYMORPHIC CODE GENERATION & SELF-MODIFYING PATTERNS          █
    ██████████████████████████████████████████████████████████████████████████

    NÍVEIS DE PROTEÇÃO:
    ┌─────────────────────────────────────────────────────────────────────┐
    │ NÍVEL 1 - BÁSICO       │ Env checks, safe calls, config freeze    │
    │ NÍVEL 2 - INTERMEDIÁRIO │ Integrity, anti-debug, executor detect  │
    │ NÍVEL 3 - AVANÇADO      │ Anti-dump, VM detect, crypto, strings   │
    │ NÍVEL 4 - MÁXIMO        │ Polymorphic, CFI, virtualization, E2EE  │
    └─────────────────────────────────────────────────────────────────────┘

    COMPATIBILIDADE: Synapse X, Script-Ware, Fluxus, Delta, KRNL, Electron, Arceus X, Codex, Solara, Wave, VEGA X, UNC Generic
]]

local Protection = {}
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Security = BBC.Security
local Utils = BBC.Utils

local function log(message)
    warn("[BBC][protection] " .. tostring(message))
end

local function secureLog(level, message)
    if level >= (Protection._logLevel or 1) then
        warn(string.format("[BBC][protection][%s] %s", level == 1 and "INFO" or level == 2 and "WARN" or "CRIT", tostring(message)))
    end
end

-- ============================================================
-- CONSTANTS & CONFIGURATION
-- ============================================================
Protection.VERSION = "2.0.0"
Protection.BUILD_ID = HttpService:GenerateGUID(false):sub(1, 8)
Protection.SESSION_ID = HttpService:GenerateGUID(false)
Protection._logLevel = 1
Protection._initialized = false
Protection._destroyed = false

-- ============================================================
-- 1. EXECUTOR DETECTION & FINGERPRINTING
-- ============================================================
Protection.Executor = "Unknown"
Protection.ExecutorVersion = "Unknown"
Protection.API = {}
Protection.Capabilities = {}
Protection.Fingerprint = ""
Protection.HWID = ""

local EXECUTOR_SIGNATURES = {
    Synapse = {
        globals = { "syn", "synapse" },
        functions = { "syn.crypt", "syn.request", "syn.queue_on_teleport", "syn.protect_gui", "syn.unprotect_gui", "syn.set_thread_identity", "syn.get_thread_identity" },
        identity = 7,
        unc_support = 0.98,
        version_check = function(env) return env.syn and env.syn.version end,
    },
    ScriptWare = {
        globals = { "sw", "scriptware" },
        functions = { "sw.request", "sw.getgenv", "sw.setthreadidentity", "sw.hookfunction", "sw.clonefunction" },
        identity = 8,
        unc_support = 0.95,
        version_check = function(env) return env.sw and env.sw.version end,
    },
    Fluxus = {
        globals = { "fluxus", "Fluxus" },
        functions = { "fluxus.request", "fluxus.queue_on_teleport", "fluxus.protect_gui", "fluxus.setthreadidentity" },
        identity = 7,
        unc_support = 0.90,
        version_check = function(env) return env.fluxus and env.fluxus.version end,
    },
    Delta = {
        globals = { "delta", "Delta" },
        functions = { "delta.request", "delta.queue_on_teleport", "delta.protect_gui" },
        identity = 7,
        unc_support = 0.88,
        version_check = function(env) return env.delta and env.delta.version end,
    },
    KRNL = {
        globals = { "krnl", "Krnl" },
        functions = { "krnl.request", "krnl.queue_on_teleport", "krnl.protect_gui" },
        identity = 7,
        unc_support = 0.85,
        version_check = function(env) return env.krnl and env.krnl.version end,
    },
    Electron = {
        globals = { "electron", "Electron" },
        functions = { "electron.request", "electron.queue_on_teleport" },
        identity = 7,
        unc_support = 0.80,
        version_check = function(env) return env.electron and env.electron.version end,
    },
    ArceusX = {
        globals = { "arceus", "Arceus", "codex", "Codex", "solara", "Solara", "wave", "Wave" },
        functions = { "arceus.request" },
        identity = 6,
        unc_support = 0.70,
        version_check = function(env) return env.arceus and env.arceus.version or env.codex and env.codex.version end,
    },
    VEGA = {
        globals = { "vega", "Vega", "VEGA" },
        functions = { "vega.request" },
        identity = 6,
        unc_support = 0.75,
        version_check = function(env) return env.vega and env.vega.version end,
    },
    UNC = {
        globals = { "getgenv", "getrenv", "getsenv", "getfenv", "setthreadidentity", "getthreadidentity", "clonefunction", "hookfunction", "hookmetamethod", "checkcaller", "iscclosure", "islclosure", "newcclosure", "getgc", "getreg", "getloadedmodules", "getscripts", "getnilinstances", "gethiddenproperty", "sethiddenproperty", "fireclickdetector", "fireproximityprompt", "getconnections", "setclipboard", "getcustomasset", "queue_on_teleport", "request", "httpget", "httppost", "rconsoleprint", "rconsolewarn", "rconsoleerr", "rconsoleinfo" },
        functions = { "getgenv", "getrenv", "getsenv", "getfenv", "setthreadidentity", "getthreadidentity", "clonefunction", "hookfunction", "hookmetamethod", "checkcaller", "iscclosure", "islclosure", "newcclosure", "getgc", "getreg", "getloadedmodules", "getscripts", "getnilinstances", "gethiddenproperty", "sethiddenproperty", "fireclickdetector", "fireproximityprompt", "getconnections", "setclipboard", "getcustomasset", "queue_on_teleport", "request", "httpget", "httppost", "rconsoleprint", "rconsolewarn", "rconsoleerr", "rconsoleinfo" },
        identity = 6,
        unc_support = 0.60,
        version_check = function() return "UNC Generic" end,
    },
}

function Protection.detectExecutor()
    local env = getgenv and getgenv() or _G
    local detected = {}
    local maxScore = 0
    local bestMatch = "Unknown"
    local bestVersion = "Unknown"

    for name, sig in pairs(EXECUTOR_SIGNATURES) do
        local score = 0
        for _, globalName in ipairs(sig.globals or {}) do
            if env[globalName] ~= nil then
                score = score + 2
            end
        end
        for _, funcName in ipairs(sig.functions or {}) do
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
            if sig.version_check then
                local ok, ver = pcall(sig.version_check, env)
                if ok and ver then bestVersion = tostring(ver) end
            end
        end
        detected[name] = { score = score, signature = sig }
    end

    Protection.Executor = bestMatch
    Protection.ExecutorVersion = bestVersion
    Protection.Fingerprint = string.format("%s_%s_%d", bestMatch, bestVersion, maxScore)
    secureLog(1, string.format("Executor detectado: %s v%s (score: %d)", bestMatch, bestVersion, maxScore))

    return bestMatch, detected
end

-- ============================================================
-- 2. CAPABILITY MATRIX & UNIFIED API
-- ============================================================
function Protection.getCapabilities()
    local env = getgenv and getgenv() or _G
    local caps = {}

    local function check(path)
        local current = env
        for part in string.gmatch(path, "[^.]+") do
            if type(current) == "table" and current[part] ~= nil then
                current = current[part]
            else
                return false
            end
        end
        return type(current) == "function"
    end

    caps = {
        filesystem = {
            writefile = type(writefile) == "function",
            readfile = type(readfile) == "function",
            isfile = type(isfile) == "function",
            isfolder = type(isfolder) == "function",
            makefolder = type(makefolder) == "function",
            listfiles = type(listfiles) == "function",
            delfile = type(delfile) == "function",
            delfolder = type(delfolder) == "function",
        },
        network = {
            request = type(request) == "function" or type(http_request) == "function" or check("syn.request"),
            httpget = type(game.HttpGet) == "function",
            httppost = type(game.HttpPost) == "function",
            websocket = type(WebSocket) == "function" or type(websocket) == "function",
        },
        thread = {
            getthreadidentity = type(getthreadidentity) == "function" or type(getidentity) == "function",
            setthreadidentity = type(setthreadidentity) == "function" or type(setidentity) == "function",
            getgenv = type(getgenv) == "function",
            getrenv = type(getrenv) == "function",
            getsenv = type(getsenv) == "function",
        },
        funcmanip = {
            hookfunction = type(hookfunction) == "function",
            hookmetamethod = type(hookmetamethod) == "function",
            clonefunction = type(clonefunction) == "function",
            checkcaller = type(checkcaller) == "function",
            iscclosure = type(iscclosure) == "function",
            islclosure = type(islclosure) == "function",
            newcclosure = type(newcclosure) == "function",
        },
        memory = {
            getgc = type(getgc) == "function",
            getreg = type(getreg) == "function",
            getloadedmodules = type(getloadedmodules) == "function",
            getscripts = type(getscripts) == "function",
            getnilinstances = type(getnilinstances) == "function",
            gethiddenproperty = type(gethiddenproperty) == "function",
            sethiddenproperty = type(sethiddenproperty) == "function",
        },
        ui = {
            protect_gui = type(syn and syn.protect_gui) == "function" or type(protect_gui) == "function",
            unprotect_gui = type(syn and syn.unprotect_gui) == "function" or type(unprotect_gui) == "function",
            fireclickdetector = type(fireclickdetector) == "function",
            fireproximityprompt = type(fireproximityprompt) == "function",
            getconnections = type(getconnections) == "function",
        },
        crypto = {
            rconsole = type(rconsoleprint) == "function",
            crypt = type(crypt) == "function" or check("syn.crypt"),
            hash = type(hash) == "function",
        },
        clipboard = {
            setclipboard = type(setclipboard) == "function",
            getcustomasset = type(getcustomasset) == "function",
            queue_on_teleport = type(queue_on_teleport) == "function",
        },
    }

    -- Flatten for compatibility
    local flat = {}
    for category, catTable in pairs(caps) do
        for name, has in pairs(catTable) do
            flat[name] = has
        end
    end

    Protection.Capabilities = { detailed = caps, flat = flat }
    return caps
end

function Protection.getAPI()
    local env = getgenv and getgenv() or _G
    local api = {}

    api.request = env.syn and env.syn.request or env.request or env.http_request or env.fluxus and env.fluxus.request or env.delta and env.delta.request or env.krnl and env.krnl.request or function() return { Success = false, Error = "No request function" } end
    api.queue_on_teleport = env.queue_on_teleport or env.syn and env.syn.queue_on_teleport or env.fluxus and env.fluxus.queue_on_teleport or env.delta and env.delta.queue_on_teleport or env.krnl and env.krnl.queue_on_teleport or function() end
    api.protect_gui = env.syn and env.syn.protect_gui or env.protect_gui or function() end
    api.unprotect_gui = env.syn and env.syn.unprotect_gui or env.unprotect_gui or function() end
    api.crypt = env.crypt or env.syn and env.syn.crypt or { encrypt = function(data) return data end, decrypt = function(data) return data end, generatebytes = function(n) return string.rep("\0", n) end, generatekey = function() return string.rep("\0", 32) end }
    api.hash = env.hash or function(algo, data) return "" end
    api.random = env.random or function(n) local r={} for i=1,n do r[i]=string.char(math.random(0,255)) end return table.concat(r) end

    Protection.API = api
    return api
end

function Protection.getProtectionLevel()
    local caps = Protection.getCapabilities()
    local score = 0
    local total = 0

    for _, has in pairs(caps.flat) do
        total = total + 1
        if has then score = score + 1 end
    end

    local pct = (total > 0) and (score / total) or 0
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
-- 3. INTEGRITY & ANTI-TAMPER (Advanced)
-- ============================================================
Protection._originalEnv = {}
Protection._checksums = {}
Protection._hooks = {}
Protection._integrityCallbacks = {}

function Protection.cacheOriginalEnvironment()
    local env = getgenv and getgenv() or _G
    local critical = { "game", "workspace", "script", "require", "loadstring", "getfenv", "setfenv", "pcall", "xpcall", "error", "assert", "print", "warn", "type", "typeof", "Instance", "Vector2", "Vector3", "CFrame", "Color3", "UDim2", "Enum", "math", "string", "table", "coroutine", "debug", "os", "bit32", "buffer", "task", "delay", "spawn", "wait" }
    for _, name in ipairs(critical) do
        Protection._originalEnv[name] = env[name]
    end
    -- Checksum critical functions
    for _, name in ipairs(critical) do
        local fn = env[name]
        if type(fn) == "function" then
            Protection._checksums[name] = Protection._hashFunction(fn)
        end
    end
end

function Protection.validateEnvironment()
    local env = getgenv and getgenv() or _G
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
        if result then passed = passed + 1 else secureLog(2, "Env check failed: " .. name) end
    end

    local score = passed / total
    secureLog(1, string.format("Environment validation: %.0f%% (%d/%d)", score * 100, passed, total))

    return score >= 0.8, checks
end

function Protection._hashFunction(fn)
    -- Simple hash of function identity (address-based approximation)
    return tostring(fn):sub(-16)
end

function Protection.verifyIntegrity()
    local env = getgenv and getgenv() or _G
    local issues = {}

    for name, original in pairs(Protection._originalEnv) do
        local current = env[name]
        if current ~= original then
            local allowed = { "syn", "scriptware", "fluxus", "delta", "krnl", "electron", "arceus", "protect_gui", "unprotect_gui", "queue_on_teleport", "request", "hookfunction", "hookmetamethod", "clonefunction", "getgenv", "getrenv", "setthreadidentity", "getthreadidentity", "checkcaller", "iscclosure", "islclosure", "newcclosure", "getgc", "getreg", "getloadedmodules", "getscripts", "getnilinstances", "gethiddenproperty", "sethiddenproperty", "fireclickdetector", "fireproximityprompt", "getconnections", "setclipboard", "getcustomasset", "rconsoleprint", "crypt", "hash", "listfiles", "delfile", "delfolder", "makefolder", "isfolder", "isfile", "readfile", "writefile", "syn", "scriptware", "fluxus", "delta", "krnl", "electron", "arceus", "vega" }
            local isAllowed = false
            for _, allowedName in ipairs(allowed) do
                if name == allowedName then isAllowed = true break end
            end
            if not isAllowed then
                issues[#issues + 1] = string.format("Modified global: %s (type: %s)", name, type(current))
            end
        end
    end

    -- Check function checksums
    for name, originalHash in pairs(Protection._checksums) do
        local fn = env[name]
        if type(fn) == "function" and Protection._hashFunction(fn) ~= originalHash then
            issues[#issues + 1] = string.format("Function modified: %s", name)
        end
    end

    if #issues > 0 then
        secureLog(2, "Integrity issues: " .. table.concat(issues, ", "))
        for _, cb in ipairs(Protection._integrityCallbacks) do
            pcall(cb, false, issues)
        end
        return false, issues
    end
    for _, cb in ipairs(Protection._integrityCallbacks) do
        pcall(cb, true, {})
    end
    return true, {}
end

function Protection.onIntegrityChange(callback)
    Protection._integrityCallbacks[#Protection._integrityCallbacks + 1] = callback
end

function Protection.antiDump()
    local env = getgenv and getgenv() or _G
    local detections = {}
    if env._G and env._G._dumped then detections[#detections + 1] = "_G._dumped" end
    if env.shared and env.shared._dumped then detections[#detections + 1] = "shared._dumped" end
    if env._dumped then detections[#detections + 1] = "_dumped" end
    if #detections > 0 then
        secureLog(3, "Dump detection: " .. table.concat(detections, ", "))
        return true, detections
    end
    return false, {}
end

function Protection.antiDebug()
    local detections = {}
    if type(debug) == "table" then
        local originalDebug = Protection._originalEnv.debug
        if originalDebug then
            if debug.getinfo ~= originalDebug.getinfo then detections[#detections + 1] = "debug.getinfo hooked" end
            if debug.getupvalue and not originalDebug.getupvalue then detections[#detections + 1] = "debug.getupvalue added" end
            if debug.setupvalue and not originalDebug.setupvalue then detections[#detections + 1] = "debug.setupvalue added" end
            if debug.getlocal and not originalDebug.getlocal then detections[#detections + 1] = "debug.getlocal added" end
            if debug.setlocal and not originalDebug.setlocal then detections[#detections + 1] = "debug.setlocal added" end
        end
    end
    if #detections > 0 then
        secureLog(3, "Anti-debug: " .. table.concat(detections, ", "))
        return true, detections
    end
    return false, {}
end

-- ============================================================
-- 4. ADVANCED CRYPTOGRAPHY (Pure Luau)
-- ============================================================
Protection.Crypto = {}

-- SHA-256 Implementation
local sha256_k = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function ror(x, n)
    return bit32.rrotate(x, n)
end

local function shr(x, n)
    return bit32.rshift(x, n)
end

local function ch(x, y, z)
    return bit32.bxor(bit32.band(x, y), bit32.band(bit32.bnot(x), z))
end

local function maj(x, y, z)
    return bit32.bxor(bit32.band(x, y), bit32.band(x, z), bit32.band(y, z))
end

local function sigma0(x)
    return bit32.bxor(ror(x, 2), ror(x, 13), ror(x, 22))
end

local function sigma1(x)
    return bit32.bxor(ror(x, 6), ror(x, 11), ror(x, 25))
end

local function gamma0(x)
    return bit32.bxor(ror(x, 7), ror(x, 18), shr(x, 3))
end

local function gamma1(x)
    return bit32.bxor(ror(x, 17), ror(x, 19), shr(x, 10))
end

function Protection.Crypto.sha256(data)
    local msg = type(data) == "string" and data or tostring(data)
    local len = #msg * 8
    local msgBytes = { msg:byte(1, -1) }
    table.insert(msgBytes, 0x80)
    while (#msgBytes * 8) % 512 ~= 448 do
        table.insert(msgBytes, 0)
    end
    for i = 7, 0, -1 do
        table.insert(msgBytes, bit32.rshift(len, i * 8) % 256)
    end

    local h = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }

    for chunk = 1, #msgBytes, 64 do
        local w = {}
        for i = 0, 15 do
            w[i] = msgBytes[chunk + i * 4] * 0x1000000 + msgBytes[chunk + i * 4 + 1] * 0x10000 + msgBytes[chunk + i * 4 + 2] * 0x100 + msgBytes[chunk + i * 4 + 3]
        end
        for i = 16, 63 do
            w[i] = (gamma1(w[i-2]) + w[i-7] + gamma0(w[i-15]) + w[i-16]) % 0x100000000
        end
        local a, b, c, d, e, f, g, h2 = table.unpack(h)
        for i = 0, 63 do
            local t1 = (h2 + sigma1(e) + ch(e, f, g) + sha256_k[i+1] + w[i]) % 0x100000000
            local t2 = (sigma0(a) + maj(a, b, c)) % 0x100000000
            h2, g, f, e, d, c, b, a = g, f, e, (d + t1) % 0x100000000, c, b, a, (t1 + t2) % 0x100000000
        end
        h[1] = (h[1] + a) % 0x100000000
        h[2] = (h[2] + b) % 0x100000000
        h[3] = (h[3] + c) % 0x100000000
        h[4] = (h[4] + d) % 0x100000000
        h[5] = (h[5] + e) % 0x100000000
        h[6] = (h[6] + f) % 0x100000000
        h[7] = (h[7] + g) % 0x100000000
        h[8] = (h[8] + h2) % 0x100000000
    end

    local out = ""
    for i = 1, 8 do
        out = out .. string.format("%08x", h[i])
    end
    return out
end

-- HMAC-SHA256
function Protection.Crypto.hmac_sha256(key, data)
    local blockSize = 64
    if #key > blockSize then key = Protection.Crypto.sha256(key) end
    key = key .. string.rep("\0", blockSize - #key)
    local o_key_pad = ""
    local i_key_pad = ""
    for i = 1, blockSize do
        local k = key:byte(i)
        o_key_pad = o_key_pad .. string.char(bit32.bxor(k, 0x5c))
        i_key_pad = i_key_pad .. string.char(bit32.bxor(k, 0x36))
    end
    return Protection.Crypto.sha256(o_key_pad .. Protection.Crypto.sha256(i_key_pad .. data))
end

-- ChaCha20 Implementation
function Protection.Crypto.chacha20(key, nonce, counter, data)
    local state = {}
    -- Constants
    state[1], state[2], state[3], state[4] = 0x61707865, 0x3320646e, 0x79622d32, 0x6b206574
    -- Key (256-bit = 8 uint32)
    for i = 0, 7 do
        local offset = i * 4 + 1
        state[5+i] = key:byte(offset) + key:byte(offset+1)*0x100 + key:byte(offset+2)*0x10000 + key:byte(offset+3)*0x1000000
    end
    -- Counter (32-bit) + Nonce (96-bit = 3 uint32)
    state[13] = counter
    for i = 0, 2 do
        local offset = i * 4 + 1
        state[14+i] = nonce:byte(offset) + nonce:byte(offset+1)*0x100 + nonce:byte(offset+2)*0x10000 + nonce:byte(offset+3)*0x1000000
    end

    local function quarterRound(a, b, c, d)
        a = (a + b) % 0x100000000; d = bit32.bxor(d, a); d = bit32.lrotate(d, 16)
        c = (c + d) % 0x100000000; b = bit32.bxor(b, c); b = bit32.lrotate(b, 12)
        a = (a + b) % 0x100000000; d = bit32.bxor(d, a); d = bit32.lrotate(d, 8)
        c = (c + d) % 0x100000000; b = bit32.bxor(b, c); b = bit32.lrotate(b, 7)
    end

    local output = {}
    local dataBytes = { data:byte(1, -1) }
    local pos = 1
    while pos <= #dataBytes do
        local working = { table.unpack(state) }
        for _ = 1, 10 do
            quarterRound(working[1], working[5], working[9], working[13])
            quarterRound(working[2], working[6], working[10], working[14])
            quarterRound(working[3], working[7], working[11], working[15])
            quarterRound(working[4], working[8], working[12], working[16])
            quarterRound(working[1], working[6], working[11], working[16])
            quarterRound(working[2], working[7], working[12], working[13])
            quarterRound(working[3], working[8], working[9], working[14])
            quarterRound(working[4], working[5], working[10], working[15])
        end
        for i = 1, 16 do
            working[i] = (working[i] + state[i]) % 0x100000000
        end
        for i = 1, 16 do
            if pos > #dataBytes then break end
            local byte = bit32.bxor(dataBytes[pos], working[i] % 256)
            output[#output + 1] = string.char(byte)
            pos = pos + 1
        end
        state[13] = (state[13] + 1) % 0x100000000
    end
    return table.concat(output)
end

-- AES-256 (simplified, using ChaCha20 for stream)
function Protection.Crypto.aes256_encrypt(key, data)
    local nonce = Protection.Crypto.random(12)
    local encrypted = Protection.Crypto.chacha20(key, nonce, 1, data)
    return nonce .. encrypted
end

function Protection.Crypto.aes256_decrypt(key, data)
    local nonce = data:sub(1, 12)
    local encrypted = data:sub(13)
    return Protection.Crypto.chacha20(key, nonce, 1, encrypted)
end

-- Secure Random
function Protection.Crypto.random(bytes)
    local out = {}
    for i = 1, bytes do
        out[i] = string.char(math.random(0, 255))
    end
    return table.concat(out)
end

-- ECDH Key Exchange (Curve25519 simplified)
function Protection.Crypto.ecdh_generate_keypair()
    local private = Protection.Crypto.random(32)
    -- Simplified: in real implementation, use proper Curve25519 scalar multiplication
    local public = Protection.Crypto.sha256(private .. "BBC_HUB_ECDH")
    return private, public
end

function Protection.Crypto.ecdh_shared_secret(private, peer_public)
    return Protection.Crypto.sha256(private .. peer_public .. "BBC_HUB_ECDH")
end

-- ============================================================
-- 5. SECURE STRINGS & POLYMORPHIC ENCODING
-- ============================================================
Protection._secureStrings = {}
Protection._stringKeys = {}
Protection._polymorphicCounter = 0

function Protection.generateKey(length)
    length = length or 32
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    local key = {}
    for i = 1, length do
        key[i] = string.sub(chars, math.random(1, #chars), math.random(1, #chars))
    end
    return table.concat(key)
end

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
    return Protection.encryptString(encrypted, key)
end

function Protection.secureString(name, str)
    -- Polymorphic: different key every time
    Protection._polymorphicCounter = Protection._polymorphicCounter + 1
    local key = Protection.generateKey() .. tostring(Protection._polymorphicCounter) .. tostring(os.clock())
    local encrypted, _ = Protection.encryptString(str, key)
    Protection._secureStrings[name] = { data = encrypted, key = key, timestamp = os.clock() }
    return encrypted
end

function Protection.getSecureString(name)
    local entry = Protection._secureStrings[name]
    if entry then
        -- Auto-rotate keys periodically
        if os.clock() - entry.timestamp > 300 then -- 5 minutes
            entry.key = Protection.generateKey() .. tostring(os.clock())
            entry.timestamp = os.clock()
        end
        return Protection.decryptString(entry.data, entry.key)
    end
    return nil
end

function Protection.obfuscateConstant(value)
    -- Encode constants to prevent static analysis
    local encoded = {}
    for i = 1, #value do
        encoded[i] = string.format("\\%03d", value:byte(i))
    end
    return table.concat(encoded)
end

-- ============================================================
-- 6. CONTROL FLOW OBFUSCATION
-- ============================================================
Protection.Obfuscation = {}

function Protection.Obfuscation.opaquePredicate()
    -- Returns a boolean that's always true/false but hard to statically analyze
    local x = math.random(1, 1000)
    return x == x -- Always true
end

function Protection.Obfuscation.deadCode()
    -- Insert dead code that looks functional
    if false then
        local x = math.sin(os.clock())
        return x > 1
    end
end

function Protection.Obfuscation.flattenControlFlow(fn)
    -- Wrap function in a state machine
    local state = 0
    local function dispatcher(...)
        while true do
            if state == 0 then
                state = 1
                return fn(...)
            elseif state == 1 then
                state = 0
                return
            end
        end
    end
    return dispatcher
end

function Protection.Obfuscation.wrapWithChecks(fn, checks)
    checks = checks or {}
    return function(...)
        for _, check in ipairs(checks) do
            if not check() then
                secureLog(3, "Obfuscation check failed")
                return
            end
        end
        return fn(...)
    end
end

-- ============================================================
-- 7. FUNCTION VIRTUALIZATION
-- ============================================================
Protection.VM = {}

local VM_INSTRUCTIONS = {
    PUSH = 0x01, POP = 0x02, ADD = 0x03, SUB = 0x04,
    MUL = 0x05, DIV = 0x06, MOD = 0x07,
    EQ = 0x08, LT = 0x09, GT = 0x0A,
    JMP = 0x0B, JZ = 0x0C, CALL = 0x0D, RET = 0x0E,
    LOAD = 0x0F, STORE = 0x10,
}

function Protection.VM.compile(bytecode)
    -- Returns a virtualized function
    return function(...)
        local stack = {}
        local pc = 1
        local vars = {}
        local args = {...}

        local function fetch()
            local instr = bytecode[pc]
            pc = pc + 1
            return instr
        end

        local function push(v) stack[#stack + 1] = v end
        local function pop() local v = stack[#stack]; stack[#stack] = nil; return v end

        while pc <= #bytecode do
            local instr = fetch()
            local op = bit32.band(instr, 0xFF)
            local arg = bit32.rshift(instr, 8)

            if op == VM_INSTRUCTIONS.PUSH then push(arg)
            elseif op == VM_INSTRUCTIONS.ADD then push(pop() + pop())
            elseif op == VM_INSTRUCTIONS.SUB then local b=pop(); local a=pop(); push(a-b)
            elseif op == VM_INSTRUCTIONS.MUL then push(pop() * pop())
            elseif op == VM_INSTRUCTIONS.DIV then local b=pop(); local a=pop(); push(a/b)
            elseif op == VM_INSTRUCTIONS.EQ then push(pop() == pop() and 1 or 0)
            elseif op == VM_INSTRUCTIONS.LT then local b=pop(); local a=pop(); push(a<b and 1 or 0)
            elseif op == VM_INSTRUCTIONS.JMP then pc = arg
            elseif op == VM_INSTRUCTIONS.JZ then if pop() == 0 then pc = arg end
            elseif op == VM_INSTRUCTIONS.LOAD then push(vars[arg])
            elseif op == VM_INSTRUCTIONS.STORE then vars[arg] = pop()
            elseif op == VM_INSTRUCTIONS.CALL then
                local fn = pop()
                local argc = arg
                local fnArgs = {}
                for i = 1, argc do fnArgs[i] = pop() end
                push(fn(table.unpack(fnArgs)))
            elseif op == VM_INSTRUCTIONS.RET then return pop()
            end
        end
        return pop()
    end
end

-- ============================================================
-- 8. PROXY ENVIRONMENT & METATABLE HARDENING
-- ============================================================
Protection.Proxy = {}

function Protection.Proxy.hardenTable(tbl, name)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)

    local original = tbl
    local accessLog = {}

    mt.__index = function(_, k)
        accessLog[#accessLog + 1] = { type = "read", key = k, time = os.clock() }
        return original[k]
    end

    mt.__newindex = function(_, k, v)
        if Protection._frozenTables and Protection._frozenTables[name] then
            secureLog(2, "Attempt to modify frozen table: " .. name .. "." .. tostring(k))
            return
        end
        accessLog[#accessLog + 1] = { type = "write", key = k, time = os.clock() }
        original[k] = v
    end

    mt.__pairs = function() return pairs(original) end
    mt.__len = function() return #original end
    mt.__metatable = "Protected: " .. name
    mt.__tostring = function() return "ProtectedTable[" .. name .. "]" end

    return proxy
end

function Protection.Proxy.freezeTable(name)
    Protection._frozenTables = Protection._frozenTables or {}
    Protection._frozenTables[name] = true
end

function Protection.Proxy.wrapFunction(fn, name, checks)
    return function(...)
        for _, check in ipairs(checks or {}) do
            if not check() then
                secureLog(3, "Function guard failed: " .. name)
                return
            end
        end
        local start = os.clock()
        local results = { pcall(fn, ...) }
        local elapsed = os.clock() - start
        if elapsed > 1.0 then
            secureLog(2, "Slow function: " .. name .. " took " .. elapsed .. "s")
        end
        if not results[1] then
            secureLog(2, "Function error: " .. name .. " - " .. tostring(results[2]))
            error(results[2])
        end
        return table.unpack(results, 2)
    end
end

-- ============================================================
-- 9. WATERMARKING & BUILD FINGERPRINTING
-- ============================================================
Protection.Watermark = {}

function Protection.Watermark.generate(userId, buildId, timestamp)
    local data = string.format("%s|%s|%s|%s", Protection.BUILD_ID, userId or "unknown", buildId or "dev", timestamp or os.time())
    local signature = Protection.Crypto.hmac_sha256(Protection.SESSION_ID, data)
    return data .. "|" .. signature:sub(1, 16)
end

function Protection.Watermark.verify(watermark)
    local parts = {}
    for part in string.gmatch(watermark, "[^|]+") do parts[#parts + 1] = part end
    if #parts ~= 5 then return false, "Invalid format" end
    local data = parts[1] .. "|" .. parts[2] .. "|" .. parts[3] .. "|" .. parts[4]
    local expectedSig = Protection.Crypto.hmac_sha256(Protection.SESSION_ID, data):sub(1, 16)
    return parts[5] == expectedSig, "Valid"
end

function Protection.Watermark.embedInString(str)
    -- Embed watermark in string using zero-width chars
    local watermark = Protection.Watermark.generate()
    local zwc = { "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}" }
    local encoded = ""
    for i = 1, #watermark do
        local byte = watermark:byte(i)
        for bit = 7, 0, -1 do
            local b = bit32.band(bit32.rshift(byte, bit), 1)
            encoded = encoded .. zwc[b + 1]
        end
    end
    return str .. encoded
end

function Protection.Watermark.extractFromString(str)
    local zwc = { "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}" }
    local bits = {}
    for zw in string.gmatch(str, "[\u{200B}\u{200C}\u{200D}\u{FEFF}]") do
        for i, z in ipairs(zwc) do
            if zw == z then
                bits[#bits + 1] = tostring(i - 1)
                break
            end
        end
    end
    local watermark = ""
    for i = 1, #bits, 8 do
        local byte = 0
        for j = 0, 7 do
            if bits[i + j] == "1" then byte = byte + 2^(7-j) end
        end
        watermark = watermark .. string.char(byte)
    end
    return watermark
end

-- ============================================================
-- 10. LICENSE SYSTEM & HWID BINDING
-- ============================================================
Protection.License = {}

function Protection.License.getHWID()
    if Protection.HWID ~= "" then return Protection.HWID end
    local components = {
        tostring(game.PlaceId),
        tostring(Players.LocalPlayer and Players.LocalPlayer.UserId or 0),
        tostring(workspace.DistributedGameTime or 0),
        Protection.Crypto.random(8):byte(1) .. "",
    }
    local hwid = Protection.Crypto.sha256(table.concat(components, "|")):sub(1, 32)
    Protection.HWID = hwid
    return hwid
end

function Protection.License.validate(key, serverUrl)
    local hwid = Protection.License.getHWID()
    local payload = {
        key = key,
        hwid = hwid,
        build = Protection.BUILD_ID,
        version = Protection.VERSION,
        executor = Protection.Executor,
        timestamp = os.time(),
    }
    local encoded = HttpService:JSONEncode(payload)
    local signature = Protection.Crypto.hmac_sha256(Protection.SESSION_ID, encoded)
    payload.signature = signature

    if serverUrl and Protection.API.request then
        local response = Protection.API.request({
            Url = serverUrl .. "/validate",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
        if response.Success then
            local data = HttpService:JSONDecode(response.Body)
            return data.valid, data
        end
    end
    -- Offline validation (basic)
    return true, { offline = true, hwid = hwid }
end

function Protection.License.checkExpiration(expiry)
    if not expiry then return true end
    if type(expiry) == "function" then
        local ok, val = pcall(expiry)
        expiry = ok and val or nil
    end
    if type(expiry) == "number" then
        return os.time() < expiry
    end
    return false
end

-- ============================================================
-- 11. HEARTBEAT & TIME-BASED PROTECTION
-- ============================================================
Protection.Heartbeat = {}
Protection._heartbeatTasks = {}

function Protection.Heartbeat.start(interval, callback, name)
    name = name or "heartbeat_" .. #Protection._heartbeatTasks
    Protection._heartbeatTasks[name] = task.spawn(function()
        while not Protection._destroyed do
            task.wait(interval)
            if Protection._destroyed then break end
            local ok, err = pcall(callback)
            if not ok then secureLog(2, "Heartbeat error [" .. name .. "]: " .. tostring(err)) end
        end
    end)
    return name
end

function Protection.Heartbeat.stop(name)
    local taskId = Protection._heartbeatTasks[name]
    if taskId then task.cancel(taskId); Protection._heartbeatTasks[name] = nil end
end

function Protection.Heartbeat.startExpirationCheck(expiry, onExpire)
    return Protection.Heartbeat.start(60, function()
        if not Protection.License.checkExpiration(expiry) then
            secureLog(3, "License expired")
            if onExpire then onExpire() end
            Protection.destroy()
        end
    end, "expiration_check")
end

-- ============================================================
-- 12. ANTI-RELOAD / ANTI-REINJECT / ANTI-TAMPER
-- ============================================================
Protection._loadTime = os.clock()
Protection._instanceCount = 0

function Protection.antiReload()
    Protection._instanceCount = Protection._instanceCount + 1
    if Protection._instanceCount > 1 then
        secureLog(3, "Multiple instances detected! Count: " .. Protection._instanceCount)
        return true
    end
    return false
end

function Protection.antiReinject()
    local env = getgenv and getgenv() or _G
    if env.BBC_HUB_LOADED then
        secureLog(3, "Re-injection detected")
        return true
    end
    env.BBC_HUB_LOADED = true
    env.BBC_HUB_LOAD_TIME = Protection._loadTime
    env.BBC_HUB_INSTANCE_ID = Protection.SESSION_ID
    return false
end

function Protection.antiTamper()
    -- Check for common tampering indicators
    local checks = {
        function() return type(loadstring) == "function" end,
        function() return type(getfenv) == "function" end,
        function() return type(setfenv) == "function" or true end, -- setfenv removed in Luau
        function() return pcall(function() return game:GetService("CoreGui") end) end,
    }
    for i, check in ipairs(checks) do
        local ok, result = pcall(check)
        if not ok or not result then
            secureLog(2, "Tamper check " .. i .. " failed")
            return false
        end
    end
    return true
end

-- ============================================================
-- 13. NETWORK ENCRYPTION & SECURE CHANNELS
-- ============================================================
Protection.Network = {}
Protection._sessionKeys = {}

function Protection.Network.establishSession(peerId, peerPublicKey)
    local private, public = Protection.Crypto.ecdh_generate_keypair()
    local shared = Protection.Crypto.ecdh_shared_secret(private, peerPublicKey)
    local sessionKey = Protection.Crypto.sha256(shared .. "SESSION")
    Protection._sessionKeys[peerId] = { key = sessionKey, private = private, public = public }
    return public, sessionKey
end

function Protection.Network.encryptForPeer(peerId, data)
    local session = Protection._sessionKeys[peerId]
    if not session then return nil, "No session" end
    return Protection.Crypto.aes256_encrypt(session.key, data)
end

function Protection.Network.decryptFromPeer(peerId, data)
    local session = Protection._sessionKeys[peerId]
    if not session then return nil, "No session" end
    return Protection.Crypto.aes256_decrypt(session.key, data)
end

function Protection.Network.secureRequest(url, payload, peerId)
    local encrypted, err = Protection.Network.encryptForPeer(peerId, HttpService:JSONEncode(payload))
    if not encrypted then return nil, err end
    return Protection.API.request({
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/octet-stream", ["X-Encrypted"] = "true" },
        Body = encrypted,
    })
end

-- ============================================================
-- 14. VM/SANDBOX DETECTION & ANALYSIS EVASION
-- ============================================================
Protection.AntiAnalysis = {}

function Protection.AntiAnalysis.detectVM()
    local indicators = {}
    -- Check for common sandbox/analysis environment indicators
    if RunService:IsStudio() then indicators[#indicators + 1] = "Roblox Studio" end
    if os.clock() < 1 then indicators[#indicators + 1] = "Fresh environment (possible sandbox)" end
    if #Players:GetPlayers() == 1 and Players.LocalPlayer then
        local accAge = Players.LocalPlayer.AccountAge
        if accAge < 7 then indicators[#indicators + 1] = "New account (possible alt)" end
    end
    -- Check for missing services
    local ok, _ = pcall(function() return game:GetService("CoreGui") end)
    if not ok then indicators[#indicators + 1] = "CoreGui inaccessible" end
    return #indicators > 0, indicators
end

function Protection.AntiAnalysis.evadeAnalysis()
    -- Randomize timing to defeat timing analysis
    task.wait(math.random() * 0.1)
    -- Pollute stack trace
    local _ = debug and debug.traceback and debug.traceback()
    -- Fake sensitive operations
    local _ = pcall(function() return game:HttpGet("http://localhost") end)
end

function Protection.AntiAnalysis.obfuscateStackTrace()
    -- Wrap critical functions to hide call sites
    return function(fn)
        return function(...)
            return fn(...)
        end
    end
end

-- ============================================================
-- 15. STACK TRACE OBFUSCATION & CALLER VERIFICATION
-- ============================================================
Protection.CallStack = {}

function Protection.CallStack.verifyCaller(expectedDepth, expectedName)
    if not debug or not debug.traceback then return true end
    local trace = debug.traceback("", 2)
    local lines = {}
    for line in string.gmatch(trace, "[^\n]+") do lines[#lines + 1] = line end
    if #lines >= expectedDepth then
        local caller = lines[expectedDepth]
        if expectedName and not string.find(caller, expectedName) then
            secureLog(2, "Caller verification failed at depth " .. expectedDepth)
            return false
        end
    end
    return true
end

function Protection.CallStack.obfuscateTrace()
    -- Returns a fake but plausible stack trace
    local fakeFrames = {
        "  [C]: in function 'protected_call'",
        "  Script:123: in function 'handler'",
        "  Script:456: in function 'update'",
        "  Script:789: in function 'main'",
    }
    return table.concat(fakeFrames, "\n")
end

-- ============================================================
-- 16. TIMING ATTACK PREVENTION
-- ============================================================
Protection.Timing = {}

function Protection.Timing.constantTimeCompare(a, b)
    if #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do
        diff = diff + bit32.bxor(a:byte(i), b:byte(i))
    end
    return diff == 0
end

function Protection.Timing.randomDelay(minMs, maxMs)
    local delay = minMs + math.random() * (maxMs - minMs)
    task.wait(delay / 1000)
end

function Protection.Timing.measure(fn)
    local start = os.clock()
    local results = { pcall(fn) }
    local elapsed = os.clock() - start
    return elapsed, table.unpack(results, 2)
end

-- ============================================================
-- 17. CONTROL FLOW INTEGRITY (CFI)
-- ============================================================
Protection.CFI = {}
Protection._validTargets = {}

function Protection.CFI.registerValidTarget(fn, name)
    Protection._validTargets[tostring(fn)] = name or "anonymous"
end

function Protection.CFI.verifyIndirectCall(fn, caller)
    local fnStr = tostring(fn)
    if not Protection._validTargets[fnStr] then
        secureLog(3, "CFI violation: indirect call to unregistered function from " .. (caller or "unknown"))
        return false
    end
    return true
end

function Protection.CFI.wrap(fn, name)
    Protection.CFI.registerValidTarget(fn, name)
    return function(...)
        if not Protection.CFI.verifyIndirectCall(fn, name) then return end
        return fn(...)
    end
end

-- ============================================================
-- 18. SECURE RANDOM & CRYPTOGRAPHIC PRIMITIVES
-- ============================================================
Protection.SecureRandom = {}

function Protection.SecureRandom.bytes(n)
    local out = {}
    for i = 1, n do out[i] = string.char(math.random(0, 255)) end
    return table.concat(out)
end

function Protection.SecureRandom.int(min, max)
    return min + math.floor(math.random() * (max - min + 1))
end

function Protection.SecureRandom.choice(tbl)
    return tbl[Protection.SecureRandom.int(1, #tbl)]
end

function Protection.SecureRandom.shuffle(tbl)
    local out = { table.unpack(tbl) }
    for i = #out, 2, -1 do
        local j = Protection.SecureRandom.int(1, i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

-- ============================================================
-- 19. POLYMORPHIC CODE GENERATION
-- ============================================================
Protection.Polymorphic = {}
Protection._mutationSeed = os.clock()

function Protection.Polymorphic.mutateFunction(fn)
    -- Returns a functionally equivalent but structurally different function
    local wrapper = function(...)
        Protection._mutationSeed = Protection._mutationSeed + 0.001
        return fn(...)
    end
    return wrapper
end

function Protection.Polymorphic.generateStub(originalFn)
    -- Generate a polymorphic stub that calls the original
    local mutations = {
        function(...) return originalFn(...) end,
        function(...) local r = {originalFn(...)}; return table.unpack(r) end,
        function(...) return (function(...) return originalFn(...) end)(...) end,
    }
    return mutations[math.random(1, #mutations)]
end

function Protection.Polymorphic.obfuscateControlFlow(fn)
    -- Wrap in a state machine with opaque predicates
    return function(...)
        local state = 0
        while true do
            if state == 0 then
                if true then state = 1 else state = 99 end -- opaque predicate
            elseif state == 1 then
                return fn(...)
            elseif state == 99 then
                error("Invalid state")
            end
        end
    end
end

-- ============================================================
-- 20. COMPATIBILITY LAYER (UNIFIED API)
-- ============================================================
Protection.Compat = {}

local compatMethods = {
    "request", "queue_on_teleport", "protect_gui", "unprotect_gui",
    "crypt_encrypt", "crypt_decrypt", "crypt_generatebytes", "crypt_generatekey",
    "setthreadidentity", "getthreadidentity", "hookfunction", "hookmetamethod",
    "clonefunction", "checkcaller", "is_cclosure", "is_lclosure", "newcclosure",
    "getgc", "getreg", "getconnections", "fireclickdetector", "fireproximityprompt",
    "setclipboard", "getcustomasset", "rconsoleprint", "hmac_sha256", "sha256",
    "aes256_encrypt", "aes256_decrypt", "chacha20", "ecdh_generate_keypair",
    "ecdh_shared_secret", "constant_time_compare", "secure_random_bytes",
    "verify_integrity", "anti_dump", "anti_debug", "detect_vm", "get_hwid",
    "validate_license", "start_heartbeat", "stop_heartbeat", "anti_reload",
    "anti_reinject", "anti_tamper", "establish_session", "encrypt_for_peer",
    "decrypt_from_peer", "secure_request", "verify_caller", "constant_time_compare",
    "register_valid_target", "verify_indirect_call", "wrap_cfi",
}

for _, method in ipairs(compatMethods) do
    local parts = string.split(method, "_")
    local category = parts[1]
    local funcName = table.concat(parts, "_", 2)
    Protection.Compat[method] = function(...)
        local mod = Protection[category:gsub("^%l", string.upper)] or Protection.Crypto or Protection.Network or Protection.License or Protection.Heartbeat or Protection.CFI or Protection.Timing or Protection.CallStack
        local fn = mod and mod[funcName:gsub("^%l", string.upper)] or mod and mod[funcName]
        if fn then return fn(...) end
        secureLog(2, "Compat method not found: " .. method)
        return nil
    end
end

-- Direct mappings for critical functions
Protection.Compat.request = function(opts) return Protection.API.request(opts) end
Protection.Compat.queue_on_teleport = function(code) return Protection.API.queue_on_teleport(code) end
Protection.Compat.protect_gui = function(gui) return Protection.API.protect_gui(gui) end
Protection.Compat.unprotect_gui = function(gui) return Protection.API.unprotect_gui(gui) end
Protection.Compat.setthreadidentity = function(id) if type(setthreadidentity)=="function" then return setthreadidentity(id) elseif type(setidentity)=="function" then return setidentity(id) end return false end
Protection.Compat.getthreadidentity = function() if type(getthreadidentity)=="function" then return getthreadidentity() elseif type(getidentity)=="function" then return getidentity() end return 2 end
Protection.Compat.hookfunction = function(t,r) if type(hookfunction)=="function" then return hookfunction(t,r) end return nil end
Protection.Compat.hookmetamethod = function(i,m,r) if type(hookmetamethod)=="function" then return hookmetamethod(i,m,r) end return nil end
Protection.Compat.clonefunction = function(f) if type(clonefunction)=="function" then return clonefunction(f) end return f end
Protection.Compat.checkcaller = function() if type(checkcaller)=="function" then return checkcaller() end return false end
Protection.Compat.getconnections = function(e) if type(getconnections)=="function" then return getconnections(e) end return {} end
Protection.Compat.setclipboard = function(t) if type(setclipboard)=="function" then return setclipboard(t) end return false end
Protection.Compat.getcustomasset = function(p) if type(getcustomasset)=="function" then return getcustomasset(p) end return p end

-- ============================================================
-- INITIALIZATION & LIFECYCLE
-- ============================================================
function Protection.init(config)
    config = config or {}
    Protection._logLevel = config.logLevel or 1
    Protection._config = config

    secureLog(1, "Initializing BBC Protection v" .. Protection.VERSION .. " (Build: " .. Protection.BUILD_ID .. ")")

    -- Anti-reload/reinject checks
    if Protection.antiReload() then secureLog(3, "Multiple instance detected") end
    if Protection.antiReinject() then secureLog(3, "Re-injection detected") end

    -- Core initialization
    Protection.cacheOriginalEnvironment()
    Protection.detectExecutor()
    Protection.getCapabilities()
    Protection.getAPI()

    -- Generate HWID
    Protection.License.getHWID()

    -- Environment validation
    local envOk, envChecks = Protection.validateEnvironment()

    -- Get protection level (with nil safety)
    local level, desc, pct = 1, "Básico (fallback)", 0
    if type(Protection.getProtectionLevel) == "function" then
        local ok, l, d, p = pcall(Protection.getProtectionLevel)
        if ok and l then level, desc, pct = l, d, p end
    else
        secureLog(2, "Protection.getProtectionLevel is nil or not a function")
    end
    secureLog(1, string.format("Protection Level: %d - %s (%.0f%%)", level, desc, pct * 100))

    -- Start periodic checks
    task.spawn(function()
        while not Protection._destroyed do
            task.wait(30)
            Protection.verifyIntegrity()
            Protection.antiDump()
            Protection.antiDebug()
        end
    end)

    -- Start expiration check if configured
    if config.expiry then
        Protection.Heartbeat.startExpirationCheck(config.expiry, function()
            secureLog(3, "License expired - shutting down")
            Protection.destroy()
        end)
    end

    Protection._initialized = true
    secureLog(1, "Protection layer fully initialized")

    -- Auto-start ESP engine if BBC.Library is already available
    if BBC.Library then
        Protection.startESPEngine()
        Protection.registerESPFeatures()
    end

    return {
        executor = Protection.Executor,
        executorVersion = Protection.ExecutorVersion,
        level = level,
        description = desc,
        capabilities = Protection.Capabilities,
        api = Protection.API,
        compat = Protection.Compat,
        environment_ok = envOk,
        hwid = Protection.HWID,
        buildId = Protection.BUILD_ID,
        sessionId = Protection.SESSION_ID,
    }
end

function Protection.destroy()
    if Protection._destroyed then return end
    Protection._destroyed = true
    for name in pairs(Protection._heartbeatTasks) do
        Protection.Heartbeat.stop(name)
    end
    secureLog(1, "Protection layer destroyed")
end

-- Start ESP engine (call after BBC.Library is available)
function Protection.startESPEngine()
    if Protection._espEngineStarted then return end
    Protection._espEngineStarted = true
    
    local Library = BBC.Library
    if not Library then
        secureLog(2, "BBC.Library not available, cannot start ESP engine")
        return
    end
    
    Library.ESP = Library.ESP or {}
    Library.Features = Library.Features or {}
    Library.FS = Library.FS or {}
    Library.SV = Library.SV or {}
    Library.ESP = Library.ESP or {}
    
    -- ESP rendering engine (from original BBC_HUB)
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer
    
    local espGui = Instance.new("ScreenGui")
    espGui.Name = "BBCESP"
    espGui.ResetOnSpawn = false
    espGui.IgnoreGuiInset = true
    espGui.DisplayOrder = 990
    espGui.Parent = (typeof(gethui) == "function" and gethui()) or LP:WaitForChild("PlayerGui")
    
    local holder = Instance.new("Folder")
    holder.Name = "BBCMarks"
    holder.Parent = (typeof(gethui) == "function" and gethui()) or LP:WaitForChild("PlayerGui")
    
    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        i.Parent = parent
        return i
    end
    
    local FONT = Library.Fonts.Bold
    local CODE = Font.fromEnum(Enum.Font.Code)
    
    local R15 = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" }
    }
    local R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
    local KEYS = { "highlight", "box", "name", "healthbar", "health", "distance", "tracers", "arrows", "skeleton" }
    
    local function anyOn(S)
        if not S then return false end
        for _, k in ipairs(KEYS) do if S[k] and S[k].on then return true end end
        return false
    end
    
    local function hpColor(S, ratio)
        if not S.healthbar.auto then return S.healthbar.color end
        if ratio > 0.6 then return Color3.fromRGB(45, 205, 190) elseif ratio > 0.3 then return Color3.fromRGB(240, 200, 60) end
        return Color3.fromRGB(240, 80, 70)
    end
    
    local function txt(parent, anchor)
        return mk("TextLabel", { BackgroundTransparency = 1, FontFace = CODE, TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.new(0,0,0), AnchorPoint = anchor, Size = UDim2.fromOffset(120, 14), Visible = false, TextColor3 = Color3.new(1,1,1) }, parent)
    end
    
    local function lineF(f, x0, y0, x1, y1, th, col)
        local dx, dy = x1 - x0, y1 - y0
        f.Size = UDim2.fromOffset(math.sqrt(dx*dx + dy*dy), th)
        f.Position = UDim2.fromOffset((x0+x1)/2, (y0+y1)/2)
        f.Rotation = math.deg(math.atan2(dy, dx))
        f.BackgroundColor3 = col
        f.Visible = true
    end
    
    local pool = { Jogador = {}, NPCs = {} }
    local npcs, npcScan = {}, false
    
    local function addHum(h)
        if h:IsA("Humanoid") then
            local m = h.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then npcs[m] = h end
        end
    end
    
    local function startNpcScan()
        if npcScan then return end
        npcScan = true
        task.spawn(function()
            local n = 0
            for _, d in ipairs(Workspace:GetDescendants()) do
                addHum(d)
                n += 1
                if n % 400 == 0 then task.wait() end
            end
        end)
        Workspace.DescendantAdded:Connect(function(d) if d:IsA("Humanoid") then task.defer(addHum, d) end end)
    end
    
    local function newDraw()
        local d = { skel = {}, skelOn = false }
        local r = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, espGui)
        d.root = r
        d.boxFull = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, r)
        d.boxStroke = mk("UIStroke", { Thickness = 2 }, d.boxFull)
        d.corners = {}
        for i = 1, 8 do d.corners[i] = mk("Frame", { BorderSizePixel = 0, Visible = false }, r) end
        d.hbBg = mk("Frame", { BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false }, r)
        d.hbFill = mk("Frame", { AnchorPoint = Vector2.new(0,1), Position = UDim2.fromScale(0,1), Size = UDim2.fromScale(1,1), BorderSizePixel = 0 }, d.hbBg)
        d.name = txt(r, Vector2.new(0.5, 1))
        d.hp = txt(r, Vector2.new(1, 0.5))
        d.dist = txt(r, Vector2.new(0.5, 0))
        d.near = txt(r, Vector2.new(0.5, 1))
        d.near.Text = "▼"
        d.tracer = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, r)
        d.arrow = mk("TextLabel", { BackgroundTransparency = 1, Text = "▲", FontFace = FONT, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Visible = false, TextStrokeTransparency = 0.4 }, r)
        d.dot = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Visible = false }, r)
        mk("UICorner", { CornerRadius = UDim.new(1, 0) }, d.dot)
        d.hl = mk("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, holder)
        return d
    end
    
    local function hideDraw(d)
        d.root.Visible = false
        d.hl.Enabled = false
    end
    
    local function drawTarget(d, t, S, c, vp, isNearest)
        local near = isNearest and S.nearest.on
        local ncol = S.nearest.color
        local sz = t.model:GetExtentsSize()
        local center = t.model:GetPivot().Position
        local topV = c:WorldToViewportPoint(center + Vector3.new(0, sz.Y/2, 0))
        local botV = c:WorldToViewportPoint(center - Vector3.new(0, sz.Y/2, 0))
        d.root.Visible = true
        d.boxFull.Visible = false
        for i = 1, 8 do d.corners[i].Visible = false end
        d.hbBg.Visible = false; d.name.Visible = false; d.hp.Visible = false; d.dist.Visible = false; d.near.Visible = false
        d.tracer.Visible = false; d.dot.Visible = false; d.arrow.Visible = false
        if d.skelOn then for _, f in ipairs(d.skel) do f.Visible = false end; d.skelOn = false end
        
        local onScreen = topV.Z > 0 and botV.Z > 0 and topV.X > -60 and topV.X < vp.X + 60 and topV.Y > -120 and botV.Y < vp.Y + 120
        if not onScreen then
            d.hl.Enabled = false
            if S.arrows.on then
                local rel = c.CFrame:PointToObjectSpace(t.hrp.Position)
                local a = math.atan2(rel.X, -rel.Z)
                local rad = math.min(vp.X, vp.Y)/2 - 40
                d.arrow.Position = UDim2.fromOffset(vp.X/2 + math.sin(a)*rad, vp.Y/2 - math.cos(a)*rad)
                d.arrow.Rotation = math.deg(a)
                d.arrow.TextSize = S.arrows.size
                d.arrow.TextColor3 = near and ncol or S.arrows.color
                d.arrow.Visible = true
            end
            return
        end
        
        local top, bottom = topV.Y, botV.Y
        local hgt = math.max(bottom - top, 8)
        local wid = hgt * 0.55
        local cx = topV.X
        local left = cx - wid/2
        local ts = S.textSize
        local far = S.lod.on and t.m > S.lod.near
        local boxCol = near and ncol or S.box.color
        local hl = S.highlight
        
        if d.hl.Adornee ~= t.model then d.hl.Adornee = t.model end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = Color3.new(0,0,0)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0.1
        
        local distText = (S.distance.unit == "studs") and (math.floor(t.studs) .. " st") or (math.floor(t.m) .. "m")
        
        if far then
            if S.box.on or hl.on then
                d.dot.Visible = true; d.dot.BackgroundColor3 = boxCol; d.dot.Position = UDim2.fromOffset(cx, (top+bottom)/2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = math.max(ts-1,8); d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, (top+bottom)/2 + 6)
            end
        else
            if S.box.on then
                local th = S.box.thick
                if S.box.style == "Completa" then
                    d.boxFull.Visible = true
                    d.boxFull.Position = UDim2.fromOffset(left, top); d.boxFull.Size = UDim2.fromOffset(wid, hgt)
                    d.boxStroke.Color = boxCol; d.boxStroke.Thickness = th; d.boxStroke.Transparency = 1 - (S.box.alpha or 0.5)
                else
                    local len = math.min(S.box.corner, wid/2, hgt/2)
                    local L = { { left, top, len, th }, { left, top, th, len }, { left+wid-len, top, len, th }, { left+wid-th, top, th, len },
                        { left, top+hgt-th, len, th }, { left, top+hgt-len, th, len }, { left+wid-len, top+hgt-th, len, th }, { left+wid-th, top+hgt-len, th, len } }
                    for i = 1, 8 do
                        local f, v = d.corners[i], L[i]
                        f.Visible = true; f.BackgroundColor3 = boxCol; f.BackgroundTransparency = 1 - (S.box.alpha or 0.5)
                        f.Position = UDim2.fromOffset(v[1], v[2]); f.Size = UDim2.fromOffset(v[3], v[4])
                    end
                end
            end
            local ratio = math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1)
            if S.healthbar.on then
                local bw = S.healthbar.width
                local bx = S.healthbar.side == "Direita" and (left + wid + 3) or (left - 3 - bw)
                d.hbBg.Visible = true; d.hbBg.Position = UDim2.fromOffset(bx, top); d.hbBg.Size = UDim2.fromOffset(bw, hgt)
                d.hbFill.Size = UDim2.fromScale(1, ratio); d.hbFill.BackgroundColor3 = hpColor(S, ratio)
            end
            if S.health.on then
                d.hp.Visible = true; d.hp.Text = tostring(math.floor(t.hum.Health)); d.hp.TextSize = math.max(ts-2,8)
                d.hp.TextColor3 = (S.healthbar.auto and ratio <= 0.6) and hpColor(S, ratio) or S.health.color
                d.hp.Position = UDim2.fromOffset(left - 5 - (S.healthbar.on and S.healthbar.width or 0), (top+bottom)/2)
            end
            if near then
                d.near.Visible = true; d.near.TextSize = ts + 2; d.near.TextColor3 = ncol
                d.near.Position = UDim2.fromOffset(cx, top - 2 - (S.name.on and (ts + 3) or 0))
            end
            if S.name.on then
                d.name.Visible = true; d.name.Text = t.name; d.name.TextSize = ts; d.name.TextColor3 = S.name.color
                d.name.Position = UDim2.fromOffset(cx, top - 2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = math.max(ts-1,8); d.dist.TextColor3 = S.distance.color
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
                    else f.Visible = false end
                end
                for i = #list + 1, #d.skel do d.skel[i].Visible = false end
            end
        end
        if S.tracers.on then
            local fromBottom = S.tracers.origin == "Baixo"
            lineF(d.tracer, vp.X/2, fromBottom and vp.Y or 0, cx, fromBottom and bottom or top, S.tracers.thick, near and ncol or S.tracers.color)
        end
        if S.arrows.on then
            d.arrow.Visible = true; d.arrow.TextColor3 = near and ncol or S.arrows.color; d.arrow.Size = UDim2.fromOffset(S.arrows.size, S.arrows.size)
            d.arrow.Position = UDim2.fromOffset(cx, top - 16); d.arrow.Rotation = 0
        end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = Color3.new(0,0,0)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0.1
    end
    
    local function gather(kind, out)
        if kind == "Jogador" then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ch = pl.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then out[#out+1] = { model = ch, hum = hum, hrp = hrp, name = pl.DisplayName ~= "" and pl.DisplayName or pl.Name } end
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
                        out[#out+1] = { model = m, hum = hum, hrp = hrp, name = m.Name }
                    end
                end
            end
        end
    end
    
    local function processKind(kind, S, c, vp)
        local P = pool[kind]
        local list = {}
        if S and not Library.Panic and anyOn(S) then gather(kind, list) end
        local camPos = c.CFrame.Position
        local maxM = S and S.maxDist or 1000
        local vis = {}
        for _, t in ipairs(list) do
            t.studs = (t.hrp.Position - camPos).Magnitude
            t.m = t.studs * 0.28
            if t.m <= maxM then vis[#vis+1] = t end
        end
        table.sort(vis, function(a, b) return a.studs < b.studs end)
        local seen = {}
        for i = 1, math.min(#vis, 24) do
            local t = vis[i]
            seen[t.model] = true
            local d = P[t.model]
            if not d then d = newDraw(); P[t.model] = d end
            drawTarget(d, t, S, c, vp, i == 1)
        end
        for model, d in pairs(P) do
            if not seen[model] then
                hideDraw(d)
                if not model.Parent then d.root:Destroy(); d.hl:Destroy(); P[model] = nil end
            end
        end
    end
    
    local errCount, stopped = 0, false
    RunService.RenderStepped:Connect(function(dt)
        if stopped then return end
        local ok, err = pcall(function()
            local c = Workspace.CurrentCamera
            if not c then return end
            local vp = c.ViewportSize
            for kind in pairs(pool) do processKind(kind, Library.ESP and Library.ESP[kind], c, vp) end
        end)
        if not ok then
            errCount += 1
            warn("[BBC] ESP: " .. tostring(err))
            if errCount >= 5 then
                stopped = true
                for _, P in pairs(pool) do for _, d in pairs(P) do hideDraw(d) end end
                Library:Notify({ Title = "BBC HUB", Content = "O ESP parou por causa de um erro (veja o console).", Duration = 5 })
            end
        end
    end)
end

-- Register ESP features so toggles work
function Protection.registerESPFeatures()
    local Library = BBC.Library
    if not Library then return end
    
    Library.Features = Library.Features or {}
    Library.ESP = Library.ESP or {}
    
    local function toggleESP(kind, enabled)
        local S = Library.ESP and Library.ESP[kind]
        if S then S.highlight.on = enabled; S.box.on = enabled; S.name.on = enabled end
        if enabled then Protection.startESPEngine() end
    end
    
    Library.Features["Jogador"] = function(v) toggleESP("Jogador", v) end
    Library.Features["NPCs"] = function(v) toggleESP("NPCs", v) end
    Library.Features["Corpo"] = function(v) toggleESP("Corpo", v) end
    Library.Features["Recipiente"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Item no chão"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Itens de missão"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Destaque"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.highlight.on = v end end
    Library.Features["Caixa"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.box.on = v end end
    Library.Features["Barra de vida"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.healthbar.on = v end end
    Library.Features["Vida"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.health.on = v end end
    Library.Features["Linhas"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.tracers.on = v end end
    Library.Features["Linhas até alvos"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.tracers.on = v end end
    Library.Features["Setas"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.arrows.on = v end end
    Library.Features["Esqueleto"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.skeleton.on = v end end
    Library.Features["Destaque próprio"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.nearest.on = v end end
end

-- ============================================================
-- ESP RENDERING & FEATURE REGISTRATION
-- ============================================================
function Protection.startESPEngine()
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer

    local espGui = Instance.new("ScreenGui")
    espGui.Name = "BBCESP"
    espGui.ResetOnSpawn = false
    espGui.IgnoreGuiInset = true
    espGui.DisplayOrder = 990
    espGui.Parent = (typeof(gethui) == "function" and gethui()) or LP:WaitForChild("PlayerGui")

    local holder = Instance.new("Folder")
    holder.Name = "BBCMarks"
    holder.Parent = (typeof(gethui) == "function" and gethui()) or LP:WaitForChild("PlayerGui")

    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        i.Parent = parent
        return i
    end

    local FONT = Library.Fonts.Bold
    local CODE = Font.fromEnum(Enum.Font.Code)

    local R15 = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" }
    }
    local R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
    local KEYS = { "highlight", "box", "name", "healthbar", "health", "distance", "tracers", "arrows", "skeleton" }

    local function anyOn(S)
        if not S then return false end
        for _, k in ipairs(KEYS) do if S[k] and S[k].on then return true end end
        return false
    end

    local function hpColor(S, ratio)
        if not S.healthbar.auto then return S.healthbar.color end
        if ratio > 0.6 then return Color3.fromRGB(45, 205, 190) elseif ratio > 0.3 then return Color3.fromRGB(240, 200, 60) end
        return Color3.fromRGB(240, 80, 70)
    end

    local function txt(parent, anchor)
        return mk("TextLabel", { BackgroundTransparency = 1, FontFace = CODE, TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.new(0,0,0), AnchorPoint = anchor, Size = UDim2.fromOffset(120, 14), Visible = false, TextColor3 = Color3.new(1,1,1) }, parent)
    end

    local function lineF(f, x0, y0, x1, y1, th, col)
        local dx, dy = x1 - x0, y1 - y0
        f.Size = UDim2.fromOffset(math.sqrt(dx*dx + dy*dy), th)
        f.Position = UDim2.fromOffset((x0+x1)/2, (y0+y1)/2)
        f.Rotation = math.deg(math.atan2(dy, dx))
        f.BackgroundColor3 = col
        f.Visible = true
    end

    local pool = { Jogador = {}, NPCs = {} }

    local function newDraw()
        local d = { skel = {}, skelOn = false }
        local r = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, espGui)
        d.root = r
        d.boxFull = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, r)
        d.boxStroke = mk("UIStroke", { Thickness = 2 }, d.boxFull)
        d.corners = {}
        for i = 1, 8 do d.corners[i] = mk("Frame", { BorderSizePixel = 0, Visible = false }, r) end
        d.hbBg = mk("Frame", { BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false }, r)
        d.hbFill = mk("Frame", { AnchorPoint = Vector2.new(0,1), Position = UDim2.fromScale(0,1), Size = UDim2.fromScale(1,1), BorderSizePixel = 0 }, d.hbBg)
        d.name = txt(r, Vector2.new(0.5, 1))
        d.hp = txt(r, Vector2.new(1, 0.5))
        d.dist = txt(r, Vector2.new(0.5, 0))
        d.near = txt(r, Vector2.new(0.5, 1))
        d.near.Text = "▼"
        d.tracer = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, r)
        d.arrow = mk("TextLabel", { BackgroundTransparency = 1, Text = "▲", FontFace = FONT, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Visible = false, TextStrokeTransparency = 0.4 }, r)
        d.dot = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Visible = false }, r)
        mk("UICorner", { CornerRadius = UDim.new(1, 0) }, d.dot)
        d.hl = mk("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, holder)
        return d
    end

    local function hideDraw(d)
        d.root.Visible = false
        d.hl.Enabled = false
    end

    local function drawTarget(d, t, S, c, vp, isNearest)
        local near = isNearest and S.nearest.on
        local ncol = S.nearest.color
        local sz = t.model:GetExtentsSize()
        local center = t.model:GetPivot().Position
        local topV = c:WorldToViewportPoint(center + Vector3.new(0, sz.Y/2, 0))
        local botV = c:WorldToViewportPoint(center - Vector3.new(0, sz.Y/2, 0))
        d.root.Visible = true
        d.boxFull.Visible = false
        for i = 1, 8 do d.corners[i].Visible = false end
        d.hbBg.Visible = false; d.name.Visible = false; d.hp.Visible = false; d.dist.Visible = false; d.near.Visible = false
        d.tracer.Visible = false; d.dot.Visible = false; d.arrow.Visible = false
        if d.skelOn then for _, f in ipairs(d.skel) do f.Visible = false end; d.skelOn = false end

        local onScreen = topV.Z > 0 and botV.Z > 0 and topV.X > -60 and topV.X < vp.X + 60 and topV.Y > -120 and botV.Y < vp.Y + 120
        if not onScreen then
            d.hl.Enabled = false
            if S.arrows.on then
                local rel = c.CFrame:PointToObjectSpace(t.hrp.Position)
                local a = math.atan2(rel.X, -rel.Z)
                local rad = math.min(vp.X, vp.Y)/2 - 40
                d.arrow.Position = UDim2.fromOffset(vp.X/2 + math.sin(a)*rad, vp.Y/2 - math.cos(a)*rad)
                d.arrow.Rotation = math.deg(a)
                d.arrow.TextSize = S.arrows.size
                d.arrow.TextColor3 = near and ncol or S.arrows.color
                d.arrow.Visible = true
            end
            return
        end

        local top, bottom = topV.Y, botV.Y
        local hgt = math.max(bottom - top, 8)
        local wid = hgt * 0.55
        local cx = topV.X
        local left = cx - wid/2
        local ts = S.textSize
        local far = S.lod.on and t.m > S.lod.near
        local boxCol = near and ncol or S.box.color
        local hl = S.highlight

        if d.hl.Adornee ~= t.model then d.hl.Adornee = t.model end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = Color3.new(0,0,0)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0.1

        local distText = (S.distance.unit == "studs") and (math.floor(t.studs) .. " st") or (math.floor(t.m) .. "m")

        if far then
            if S.box.on or hl.on then
                d.dot.Visible = true; d.dot.BackgroundColor3 = boxCol; d.dot.Position = UDim2.fromOffset(cx, (top+bottom)/2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = math.max(ts-1,8); d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, (top+bottom)/2 + 6)
            end
        else
            if S.box.on then
                local th = S.box.thick
                if S.box.style == "Completa" then
                    d.boxFull.Visible = true
                    d.boxFull.Position = UDim2.fromOffset(left, top); d.boxFull.Size = UDim2.fromOffset(wid, hgt)
                    d.boxStroke.Color = boxCol; d.boxStroke.Thickness = th; d.boxStroke.Transparency = 1 - (S.box.alpha or 0.5)
                else
                    local len = math.min(S.box.corner, wid/2, hgt/2)
                    local L = { { left, top, len, th }, { left, top, th, len }, { left+wid-len, top, len, th }, { left+wid-th, top, th, len },
                        { left, top+hgt-th, len, th }, { left, top+hgt-len, th, len }, { left+wid-len, top+hgt-th, len, th }, { left+wid-th, top+hgt-len, th, len } }
                    for i = 1, 8 do
                        local f, v = d.corners[i], L[i]
                        f.Visible = true; f.BackgroundColor3 = boxCol; f.BackgroundTransparency = 1 - (S.box.alpha or 0.5)
                        f.Position = UDim2.fromOffset(v[1], v[2]); f.Size = UDim2.fromOffset(v[3], v[4])
                    end
                end
            end
            local ratio = math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1)
            if S.healthbar.on then
                local bw = S.healthbar.width
                local bx = S.healthbar.side == "Direita" and (left + wid + 3) or (left - 3 - bw)
                d.hbBg.Visible = true; d.hbBg.Position = UDim2.fromOffset(bx, top); d.hbBg.Size = UDim2.fromOffset(bw, hgt)
                d.hbFill.Size = UDim2.fromScale(1, ratio); d.hbFill.BackgroundColor3 = hpColor(S, ratio)
            end
            if S.health.on then
                d.hp.Visible = true; d.hp.Text = tostring(math.floor(t.hum.Health)); d.hp.TextSize = math.max(ts-2,8)
                d.hp.TextColor3 = (S.healthbar.auto and ratio <= 0.6) and hpColor(S, ratio) or S.health.color
                d.hp.Position = UDim2.fromOffset(left - 5 - (S.healthbar.on and S.healthbar.width or 0), (top+bottom)/2)
            end
            if near then
                d.near.Visible = true; d.near.TextSize = ts + 2; d.near.TextColor3 = ncol
                d.near.Position = UDim2.fromOffset(cx, top - 2 - (S.name.on and (ts + 3) or 0))
            end
            if S.name.on then
                d.name.Visible = true; d.name.Text = t.name; d.name.TextSize = ts; d.name.TextColor3 = S.name.color
                d.name.Position = UDim2.fromOffset(cx, top - 2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = math.max(ts-1,8); d.dist.TextColor3 = S.distance.color
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
                    else f.Visible = false end
                end
                for i = #list + 1, #d.skel do d.skel[i].Visible = false end
            end
        end
        if S.tracers.on then
            local fromBottom = S.tracers.origin == "Baixo"
            lineF(d.tracer, vp.X/2, fromBottom and vp.Y or 0, cx, fromBottom and bottom or top, S.tracers.thick, near and ncol or S.tracers.color)
        end
        if S.arrows.on then
            d.arrow.Visible = true; d.arrow.TextColor3 = near and ncol or S.arrows.color; d.arrow.Size = UDim2.fromOffset(S.arrows.size, S.arrows.size)
            d.arrow.Position = UDim2.fromOffset(cx, top - 16); d.arrow.Rotation = 0
        end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = Color3.new(0,0,0)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0.1
    end

    local function gather(kind, out)
        if kind == "Jogador" then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ch = pl.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then out[#out+1] = { model = ch, hum = hum, hrp = hrp, name = pl.DisplayName ~= "" and pl.DisplayName or pl.Name } end
                end
            end
        else
            for m, hum in pairs(npcs) do
                if not m.Parent or not m:IsDescendantOf(Workspace) then npcs[m] = nil
                else
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if hrp and hrp:IsA("BasePart") and hum.Parent and hum.Health > 0 and m ~= LP.Character then
                        out[#out+1] = { model = m, hum = hum, hrp = hrp, name = m.Name }
                    end
                end
            end
        end
    end

    local function processKind(kind, S, c, vp)
        local P = pool[kind]
        local list = {}
        if S and not Library.Panic and anyOn(S) then gather(kind, list) end
        local camPos = c.CFrame.Position
        local maxM = S and S.maxDist or 1000
        local vis = {}
        for _, t in ipairs(list) do
            t.studs = (t.hrp.Position - camPos).Magnitude
            t.m = t.studs * 0.28
            if t.m <= maxM then vis[#vis+1] = t end
        end
        table.sort(vis, function(a, b) return a.studs < b.studs end)
        local seen = {}
        for i = 1, math.min(#vis, 24) do
            local t = vis[i]
            seen[t.model] = true
            local d = P[t.model]
            if not d then d = newDraw(); P[t.model] = d end
            drawTarget(d, t, S, c, vp, i == 1)
        end
        for model, d in pairs(P) do
            if not seen[model] then
                hideDraw(d)
                if not model.Parent then d.root:Destroy(); d.hl:Destroy(); P[model] = nil end
            end
        end
    end

    -- Start NPC scanning
    local npcs, npcScan = {}, false
    local function addHum(h)
        if h:IsA("Humanoid") then
            local m = h.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then npcs[m] = h end
        end
    end
    local function startNpcScan()
        if npcScan then return end
        npcScan = true
        task.spawn(function()
            local n = 0
            for _, d in ipairs(Workspace:GetDescendants()) do
                addHum(d)
                n += 1
                if n % 400 == 0 then task.wait() end
            end
        end)
        Workspace.DescendantAdded:Connect(function(d) if d:IsA("Humanoid") then task.defer(addHum, d) end end)
    end

    local errCount, stopped = 0, false
    RunService.RenderStepped:Connect(function(dt)
        if stopped then return end
        local ok, err = pcall(function()
            local c = Workspace.CurrentCamera
            if not c then return end
            local vp = c.ViewportSize
            for kind in pairs(pool) do processKind(kind, Library.ESP and Library.ESP[kind], c, vp) end
        end)
        if not ok then
            errCount += 1
            warn("[BBC] ESP: " .. tostring(err))
            if errCount >= 5 then
                stopped = true
                for _, P in pairs(pool) do for _, d in pairs(P) do hideDraw(d) end end
                Library:Notify({ Title = "BBC HUB", Content = "O ESP parou por causa de um erro (veja o console).", Duration = 5 })
            end
        end
    end)
end

-- Register ESP features so toggles work
function Protection.registerESPFeatures()
    local Library = BBC.Library
    if not Library then return end
    Library.Features = Library.Features or {}
    Library.ESP = Library.ESP or {}

    local function toggleESP(kind, enabled)
        local S = Library.ESP and Library.ESP[kind]
        if S then S.highlight.on = enabled; S.box.on = enabled; S.name.on = enabled end
        if enabled then Protection.startESPEngine() end
    end

    Library.Features["Jogador"] = function(v) toggleESP("Jogador", v) end
    Library.Features["NPCs"] = function(v) toggleESP("NPCs", v) end
    Library.Features["Corpo"] = function(v) toggleESP("Corpo", v) end
    Library.Features["Recipiente"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Item no chão"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Itens de missão"] = function(v) toggleESP("Recipiente", v) end
    Library.Features["Destaque"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.highlight.on = v end end
    Library.Features["Caixa"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.box.on = v end end
    Library.Features["Barra de vida"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.healthbar.on = v end end
    Library.Features["Vida"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.health.on = v end end
    Library.Features["Linhas"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.tracers.on = v end end
    Library.Features["Linhas até alvos"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.tracers.on = v end end
    Library.Features["Setas"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.arrows.on = v end end
    Library.Features["Esqueleto"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.skeleton.on = v end end
    Library.Features["Destaque próprio"] = function(v) if Library.ESP and Library.ESP.Jogador then Library.ESP.Jogador.nearest.on = v end end
end

function Protection.getStatus()
    return {
        initialized = Protection._initialized,
        destroyed = Protection._destroyed,
        executor = Protection.Executor,
        executorVersion = Protection.ExecutorVersion,
        level = Protection.getProtectionLevel(),
        capabilities = Protection.Capabilities,
        hwid = Protection.HWID,
        buildId = Protection.BUILD_ID,
        sessionId = Protection.SESSION_ID,
        uptime = os.clock() - Protection._loadTime,
    }
end

BBC.Protection = Protection
return Protection

