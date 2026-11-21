local function element(name, unavailable)
    local e = {Parent = true, attrs = {SearchName = name, Unavailable = unavailable}}
    function e:GetAttribute(k) return self.attrs[k] end
    return e
end
local a, b, c = element("Comum", false), element("Premium", true), element("Premium Livre", false)
local w = setmetatable({_search = {a, b, c}}, {__index = Window})
w:_filter(""); assert(a.Visible and b.Visible and c.Visible)
w:SetHideUnavailable(true); assert(a.Visible and not b.Visible and c.Visible)
w:_filter("premium"); assert(not a.Visible and not b.Visible and c.Visible)
w:SetHideUnavailable(false); assert(not a.Visible and b.Visible and c.Visible)
w:SetHideUnavailable(true); w:_filter(""); assert(a.Visible and not b.Visible and c.Visible)
print("UI unavailable filter OK")

-- A busca encontra a tradução e abre temporariamente pais/submenus.
Library.Tr = function(s) return s == "Comum" and "Common" or s end
w:SetHideUnavailable(false); w:_filter("common"); assert(a.Visible and not b.Visible)
local parent = element("Pai", false)
local panel = {Parent = parent, Visible = false, attrs = {SearchPanel = true}}
function panel:GetAttribute(k) return self.attrs[k] end
local child = element("Ajuste", false); child.Parent = panel
w._search = {parent, child}
w:_filter("ajuste"); assert(child.Visible and parent.Visible and panel.Visible)
w:_filter(""); assert(not panel.Visible)
parent.attrs.Unavailable = true
w:SetHideUnavailable(true); w:_filter("ajuste"); assert(not child.Visible and not parent.Visible and not panel.Visible)

local tabButton = {attrs = {}}
function tabButton:SetAttribute(k, v) self.attrs[k] = v end
w._search = {a, b}; a.attrs.SearchTab = "Visuais"; b.attrs.SearchTab = "Outro"
w.Tabs = {{Name = "Visuais", TabBtn = tabButton, _searchCount = {}}}
w:SetHideUnavailable(false); w:_filter("common")
assert(tabButton.attrs.SearchMatches == 1 and w.Tabs[1]._searchCount.Text == "1")
w:_filter(""); assert(tabButton.attrs.SearchMatches == 0 and w.Tabs[1]._searchCount.Text == "")

Library.Tr = function(s) return s == "Comum" and "ПРИВЕТ" or s end
w._search = {a}; w:_filter("привет"); assert(a.Visible)
Library.Tr = function(s) return s == "Comum" and "简体中文" or s end
w:_filter("中文"); assert(a.Visible)

-- Mudança manual durante a busca torna-se o estado restaurado.
Library.Tr = function(s) return s end
parent.attrs.Unavailable = false; panel.Visible = false
w._search = {parent, child}; w:_filter("ajuste"); assert(panel.Visible)
w._searchPanelState[panel] = true
w:_filter(""); assert(panel.Visible)
