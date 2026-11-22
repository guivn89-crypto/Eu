--[[
    BBC HUB - Security
    Camada de proteção e utilitários seguros.

    Responsabilidades:
      * chamadas protegidas (pcall) para callbacks e código de terceiros;
      * detecção de capacidades do executor (filesystem / config);
      * leitura e escrita segura de arquivos JSON;
      * validação de acesso (FREE / VIP) e expiração de licença;
      * checagem básica do ambiente de execução.
]]

local Security = {}
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local function log(message)
    warn("[BBC][security] " .. tostring(message))
end

-- Executa um callback sem deixar o erro derrubar o hub.
function Security.safeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        log(err)
    end
    return ok, err
end

-- Executa e devolve o resultado, ou nil em caso de falha.
function Security.safeInvoke(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        log(result)
        return nil
    end
    return result
end

function Security.canFS()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

function Security.ensureFolder(path)
    if type(path) ~= "string" or path == "" then
        return false
    end
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return false
    end
    local ok = pcall(function()
        if not isfolder(path) then
            makefolder(path)
        end
    end)
    return ok
end

function Security.readJSON(path)
    if not Security.canFS() or type(path) ~= "string" then
        return nil
    end
    local ok, data = pcall(function()
        if isfile(path) then
            return HttpService:JSONDecode(readfile(path))
        end
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

function Security.writeJSON(path, data)
    if not Security.canFS() or type(path) ~= "string" then
        return false
    end
    local ok = pcall(function()
        writefile(path, HttpService:JSONEncode(data or {}))
    end)
    return ok
end

-- Configuração injetada pelo executor antes do load:
--   getgenv().BBC_CONFIG = { Access = "VIP", Expiry = os.time() + 3600, Version = "x.y.z" }
function Security.getConfig()
    local env = type(getgenv) == "function" and getgenv() or nil
    local cfg = env and env.BBC_CONFIG
    if type(cfg) ~= "table" then
        return {}
    end
    return cfg
end

function Security.isVIP()
    local library = BBC.Library
    return library ~= nil and library.Access == "VIP"
end

function Security.resolveExpiry(expiry)
    if type(expiry) == "function" then
        local ok, value = pcall(expiry)
        expiry = ok and value or nil
    end
    if type(expiry) == "number" then
        return expiry
    end
    return nil
end

function Security.remaining(expiry)
    local at = Security.resolveExpiry(expiry)
    if not at then
        return nil
    end
    return math.max(at - os.time(), 0)
end

function Security.isExpired(expiry)
    local left = Security.remaining(expiry)
    return left ~= nil and left <= 0
end

-- Retorna true quando o recurso pode ser usado.
function Security.hasAccess(opts)
    opts = opts or {}
    if opts.Premium and not Security.isVIP() then
        return false
    end
    if Security.isExpired(BBC.State and BBC.State.Config and BBC.State.Config.Expiry) then
        return false
    end
    return true
end

function Security.checkEnvironment()
    local problems = {}
    if typeof(game) ~= "Instance" then
        problems[#problems + 1] = "game indisponível"
    end
    if not Players.LocalPlayer then
        problems[#problems + 1] = "LocalPlayer indisponível"
    end
    if type(getgenv) ~= "function" then
        problems[#problems + 1] = "getgenv ausente"
    end
    if #problems > 0 then
        log(table.concat(problems, ", "))
        return false
    end
    return true
end

-- Marca a sessão como protegida e congela a tabela de config.
function Security.init()
    Security.checkEnvironment()
    pcall(function()
        local env = getgenv()
        env.BBC_HUB_SECURE = true
        env.BBC_HUB_VERSION = "0.0.8.2"
        if type(env.BBC_CONFIG) == "table" then
            table.freeze(env.BBC_CONFIG)
        end
    end)
    return true
end

BBC.Security = Security
return Security