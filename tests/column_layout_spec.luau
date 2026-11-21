local left, right = {}, {}
local a, b = {Parent=left}, {Parent=right}
local tab = setmetatable({_cols={Left=left, Right=right}, _groupBoxes={{box=a, side="Left"},{box=b, side="Right"}},
    Window={Gui={AbsoluteSize={X=390,Y=844}}}}, {__index=Tab})
tab:_layoutColumns()
assert(a.Parent == left and b.Parent == left and right.Visible == false and left.Size.mode == "scale")
tab.Window.Gui.AbsoluteSize = {X=1024,Y=600}
tab:_layoutColumns()
assert(a.Parent == left and b.Parent == right and right.Visible and left.Size.mode == "new")
UserInputService.TouchEnabled = false
tab.Window.Gui.AbsoluteSize = {X=390,Y=844}; tab:_layoutColumns()
assert(b.Parent == right and right.Visible)
print("column reflow restores original parents OK")
