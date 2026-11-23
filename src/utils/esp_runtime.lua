--!strict
--[[
    BBC HUB - Pure ESP runtime registry
    Owns one drawing record and at most one Highlight per character model.
]]

local ESPRuntime = {}
ESPRuntime.__index = ESPRuntime

function ESPRuntime.new()
    return setmetatable({
        records = {},
        highlights = {},
    }, ESPRuntime)
end

function ESPRuntime:register(model, kind, drawing)
    if model == nil or drawing == nil then
        return nil, false
    end

    local existing = self.records[model]
    if existing ~= nil then
        -- A model can be reclassified from NPC to player between scans.
        existing.kind = kind
        return existing.drawing, false
    end

    self.records[model] = { kind = kind, drawing = drawing }
    return drawing, true
end

function ESPRuntime:getDrawing(model)
    local record = self.records[model]
    return record and record.drawing or nil
end

function ESPRuntime:ensureHighlight(model, factory)
    if model == nil then
        return nil
    end

    local existing = self.highlights[model]
    if existing ~= nil then
        return existing
    end

    local highlight = factory()
    if highlight ~= nil then
        self.highlights[model] = highlight
    end
    return highlight
end

function ESPRuntime:hideKind(kind)
    for _, record in pairs(self.records) do
        if record.kind == kind and type(record.drawing.hideAll) == "function" then
            record.drawing:hideAll()
        end
    end
end

function ESPRuntime:hideFeature(kind, feature)
    for _, record in pairs(self.records) do
        if record.kind == kind and type(record.drawing.hideFeature) == "function" then
            record.drawing:hideFeature(feature)
        end
    end
end

function ESPRuntime:forEachKind(kind, callback)
    for _, record in pairs(self.records) do
        if record.kind == kind then
            callback(record.drawing)
        end
    end
end

function ESPRuntime:release(model)
    local record = self.records[model]
    if record ~= nil then
        if type(record.drawing.destroy) == "function" then
            record.drawing:destroy()
        end
        self.records[model] = nil
    end

    local highlight = self.highlights[model]
    if highlight ~= nil then
        if type(highlight.Destroy) == "function" then
            highlight:Destroy()
        elseif type(highlight.destroy) == "function" then
            highlight:destroy()
        end
        self.highlights[model] = nil
    end
end

function ESPRuntime:releaseKind(kind)
    local models = {}
    for model, record in pairs(self.records) do
        if record.kind == kind then
            models[#models + 1] = model
        end
    end
    for _, model in ipairs(models) do
        self:release(model)
    end
end

function ESPRuntime:destroyAll()
    local models = {}
    for model in pairs(self.records) do
        models[#models + 1] = model
    end
    for _, model in ipairs(models) do
        self:release(model)
    end

    local highlighted = {}
    for model in pairs(self.highlights) do
        highlighted[#highlighted + 1] = model
    end
    for _, model in ipairs(highlighted) do
        self:release(model)
    end
end

function ESPRuntime:count()
    local count = 0
    for _ in pairs(self.records) do
        count = count + 1
    end
    return count
end

function ESPRuntime:highlightCount()
    local count = 0
    for _ in pairs(self.highlights) do
        count = count + 1
    end
    return count
end

return ESPRuntime
