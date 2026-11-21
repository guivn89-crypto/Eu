-- Favoritos são apenas atalhos de navegação; nunca ativam controles por si.
Library.Favorites = { items = {}, listeners = {}, MAX = 12 }
do
    local F = Library.Favorites
    local function validate(list)
        if type(list) ~= "table" or #list > F.MAX then return false end
        local seen, count = {}, 0
        for k, v in pairs(list) do
            if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > #list then return false end
            if type(v) ~= "string" or #v == 0 or #v > 512 or seen[v] then return false end
            count += 1; seen[v] = true
        end
        return count == #list
    end
    function F:get()
        local result = {}; for i, v in ipairs(self.items) do result[i] = v end; return result
    end
    function F:set(list)
        if not validate(list) then return false end
        self.items = {}; for i, v in ipairs(list) do self.items[i] = v end
        for _, f in ipairs(self.listeners) do pcall(f) end
        return true
    end
    function F:contains(key) return table.find(self.items, key) ~= nil end
    function F:toggle(key)
        local items = self:get()
        local i = table.find(items, key)
        if i then table.remove(items, i) else
            if #items >= self.MAX then return false end
            items[#items + 1] = key
        end
        return self:set(items)
    end
    Library.Registry["__favorites/list"] = { name = "Favoritos", get = function() return F:get() end,
        set = function(v) return F:set(v) end, validate = validate }
end

-- Histórico local à sessão de navegações pela busca/favoritos, sem ativar opções.
Library.RecentNavigation = {items = {}, listeners = {}, MAX = 5}
function Library.RecentNavigation:add(key)
    if type(key) ~= "string" or #key == 0 or #key > 512 then return end
    local i = table.find(self.items, key)
    if i then table.remove(self.items, i) end
    table.insert(self.items, 1, key)
    if #self.items > self.MAX then table.remove(self.items) end
    for _, f in ipairs(self.listeners) do pcall(f) end
end
function Library.RecentNavigation:get()
    local result = {}; for i, key in ipairs(self.items) do result[i] = key end; return result
end
