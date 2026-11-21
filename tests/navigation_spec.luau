local tab = {Name = "VISUAIS"}
local overlay = {Parent = nil, attrs = {SearchModal = "VISUAIS/ESP"}}
function overlay:GetAttribute(k) return self.attrs[k] end
function overlay:IsA() return false end
local scroll = {Parent = overlay, attrs = {}, CanvasPosition = {X=0,Y=0}, AbsolutePosition = {Y=20}, AbsoluteSize = {Y=100}, AbsoluteCanvasSize = {Y=400}}
function scroll:GetAttribute(k) return self.attrs[k] end
function scroll:IsA(kind) return kind == "ScrollingFrame" end
local target = {Parent = scroll, attrs = {SearchTab = "VISUAIS"}, AbsolutePosition = {Y=250}}
function target:GetAttribute(k) return self.attrs[k] end
local w = setmetatable({Tabs={tab}, _modals={["VISUAIS/ESP"]={Overlay=overlay}}, _searchPopup={Visible=true}}, {__index = Window})
function w:_select(t) self.selected = t end
w:_openSearchResult(target)
assert(w.selected == tab and overlay.Visible and not w._searchPopup.Visible)
assert(scroll.CanvasPosition.Y == 222)
target.Parent = nil
w.selected = nil; w:_openSearchResult(target); assert(w.selected == nil)
print("search result navigation OK")

target.Parent = scroll; target.attrs.SearchKey = "VISUAIS/ESP/Jogador"; target.attrs.SearchKind = "Toggle"
w._search = {target}; local groupOpened = false
w._groupOpeners = {[scroll] = function() groupOpened = true end}
assert(w:OpenFavorite("VISUAIS/ESP/Jogador") and groupOpened and w.selected == tab)
w._hideUnavailable = true; scroll.attrs.Unavailable = true; w.selected = nil
assert(not w:OpenFavorite("VISUAIS/ESP/Jogador") and not w.selected)
assert(not w:OpenFavorite("inexistente"))

local seen = {}
Library.RecentNavigation = {add = function(_, key) table.insert(seen, key) end}
scroll.attrs.Unavailable = nil; w._hideUnavailable = false
assert(w:OpenFavorite("VISUAIS/ESP/Jogador") and #seen == 1 and seen[1] == "VISUAIS/ESP/Jogador")
w._hideUnavailable = true; scroll.attrs.Unavailable = true
assert(not w:OpenFavorite("VISUAIS/ESP/Jogador") and #seen == 1)
