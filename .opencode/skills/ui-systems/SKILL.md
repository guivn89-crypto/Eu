---
name: ui-systems
description: >
  Roblox UI systems knowledge for building responsive, performant 2D and 3D-attached interfaces.
  Covers ScreenGui, layout objects (UIListLayout, UIGridLayout, UIFlexItem), UDim2 positioning,
  AnchorPoint, common elements (TextLabel, TextButton, ImageLabel, Frame, ScrollingFrame),
  BillboardGui/SurfaceGui, TweenService animations, StyleQuery responsive styling, UIShadow,
  per-corner UICorner, and best practices for organization, performance, and cleanup.
  Pair with `roblox-ui` for Fusion/reactive patterns or `game-ui-ux` for engine-neutral design rules.
---

# Roblox UI Systems

Expert knowledge for building Roblox game UI — ScreenGui layout, common elements, 3D-attached UI, animations, responsive design, and modern styling features (StyleQuery, UIShadow, per-corner UICorner).

## When to Use

- Building or debugging HUDs, menus, shops, inventories, or any 2D/3D UI in Roblox
- Fixing UI that breaks on different resolutions or devices
- Implementing responsive layouts with Scale/Offset and AnchorPoint
- Adding native drop shadows (UIShadow) or per-corner rounding
- Using StyleQuery for device/container-responsive conditional styling
- Animating UI with TweenService
- Attaching UI to 3D objects (BillboardGui, SurfaceGui)
- Optimizing UI performance (CanvasGroup, object pooling, avoiding TextScaled)

## Core Concepts

### ScreenGui Basics
- Root container for 2D UI; place under `StarterGui` (cloned to each player's `PlayerGui`)
- Key properties: `DisplayOrder` (layering), `ResetOnSpawn` (persistent UI), `IgnoreGuiInset` (full-screen overlays)

### Positioning & Sizing — UDim2
- `UDim2.new(xScale, xOffset, yScale, yOffset)` — Scale (0–1) = fraction of parent; Offset = fixed pixels
- **Rule:** Prefer Scale for responsive layout; use Offset for fixed-pixel elements (icons, padding)
- `AnchorPoint` (0–1 per axis) shifts origin — center with `Vector2.new(0.5, 0.5)`

### Layout Objects
| Object | Purpose |
|--------|---------|
| `UIListLayout` | Vertical/horizontal auto-arrange with `Padding`, `SortOrder` |
| `UIGridLayout` | Grid cells with `CellSize`, `CellPadding` |
| `UIFlexItem` | Flexbox-like grow/shrink/fill within UIListLayout parent |
| `UISizeConstraint` | Clamp min/max pixel size |
| `UITextSizeConstraint` | Clamp min/max text size |
| `UIAspectRatioConstraint` | Lock width:height ratio |
| `UIPadding` | Internal container padding |
| `UICorner` | Round corners (supports per-corner radii) |
| `UIStroke` | Outline/border |
| `UIScale` | Uniform subtree scaling |

### Common UI Elements
- **TextLabel/TextButton/TextBox** — `Font`, `TextSize`, `TextColor3`, `BackgroundTransparency`
- **ImageLabel/ImageButton** — `Image`, `ScaleType` (Fit, Slice, Crop), `SliceCenter` for 9-slice
- **Frame** — Generic container
- **ScrollingFrame** — Scrollable container; use `AutomaticCanvasSize = Enum.AutomaticSize.Y` + `UIListLayout`

### 3D-Attached UI
- **BillboardGui** — Always faces camera; `Adornee` + `StudsOffset`; parent to 3D part
- **SurfaceGui** — Renders on a Part face; `Face`, `PixelsPerStud`

### UI Animations with TweenService
- `TweenInfo.new(duration, EasingStyle, EasingDirection)` — Quad/Out is standard
- Tweenable: `Position`, `Size`, `BackgroundTransparency`, `BackgroundColor3`, `TextTransparency`, `ImageTransparency`, `Rotation`, `GroupTransparency` (CanvasGroup)
- **Note:** `Spring` and `Bezier` easing styles exist in API but error at runtime; use `Elastic` or `Back`

### Responsive Design
- Use `UDim2.fromScale()` + `UIAspectRatioConstraint`
- Detect device: `UserInputService.TouchEnabled` + `KeyboardEnabled`
- Listen to `Camera:GetPropertyChangedSignal("ViewportSize")` for orientation changes

### StarterGui & LocalScript Interaction
- UI code runs on client in `LocalScripts` under `StarterGui` or `StarterPlayerScripts`
- Use `PlayerGui:WaitForChild()` for safe access
- ModuleScripts for UI logic; keep LocalScripts thin

### ProximityPrompt
- Auto-rendered interaction UI near Parts
- Custom styling: `Style = Enum.ProximityPromptStyle.Custom` + `ProximityPromptService.PromptShown/Hidden`

## Modern Features (2026)

### StyleQuery — Responsive Style Queries
CSS-like conditional styling activated by device/container/accessibility conditions:
- Conditions: `MinSize`, `MaxSize`, `AspectRatioRange`, `ViewportDisplaySize`, `PreferredInput`, `PreferredTextSize`, `ReducedMotionEnabled`
- Parent `StyleQuery` under `StyleSheet`; `StyleRule` with `Selector = "@QueryName"` activates when conditions match
- Built-in selectors: `@PreferredTextSizeLarge`, `@WideContainer`

### UIShadow — Native Drop Shadows
Replace 9-slice image shadows with native `UIShadow` child:
- Properties: `Color`, `Transparency`, `BlurRadius`, `Offset`, `Spread`, `ZIndex` (negative), `Enabled`
- Auto-respects `UICorner` rounding; rotates with parent
- **Upgraded UIShadows (beta):** `Mode` (Shape/Text), `Inset`, `ShowBehindParent`, `UIGradient` coloring — do not rely in published games until beta releases

### Per-Corner UICorner Rounding
Individual corner radii: `TopLeftRadius`, `TopRightRadius`, `BottomRightRadius`, `BottomLeftRadius`
- Fully released 2026-06-23 (beta flag removed)
- Shorthand `CornerRadius` overwrites all four

### Color3 Contrast Methods (WCAG 2.1)
- `Color3:GetLuminance()`, `GetContrastRatio(other)`, `GetContrastingColor(...)`
- Use for readable text on any background:
```luau
local MIN_CONTRAST = 4.5
local function readableTextColor(bg: Color3, preferred: Color3?): Color3
    if preferred and preferred:GetContrastRatio(bg) >= MIN_CONTRAST then return preferred end
    return bg:GetContrastingColor()
end
```

## Best Practices

### Organization
- One `ScreenGui` per logical feature (HUD, Shop, Settings); layer with `DisplayOrder`
- Descriptive names: `HealthBarFrame`, not `Frame`
- ModuleScripts for UI logic; thin LocalScripts

### Performance
- Avoid creating/destroying UI every frame — toggle `Visible` or object pool
- Use `CanvasGroup` to batch-render complex subtrees
- Minimize `TextScaled` on many labels — prefer explicit `TextSize`
- Set `Parent` last when building UI trees in code

### Cleanup
```luau
local connections: { RBXScriptConnection } = {}
table.insert(connections, button.Activated:Connect(onActivated))
table.insert(connections, RunService.Heartbeat:Connect(onHeartbeat))
-- On cleanup:
for _, conn in connections do conn:Disconnect() end
```
- `ResetOnSpawn = true` (default) destroys and re-clones ScreenGui — references break

## Related Skills
- `roblox-ui` — Fusion 0.3 reactive framework, component patterns
- `game-ui-ux` — Engine-neutral HUD/menu design rules (anchors, scaling, safe areas, gamepad focus)
- `roblox-dev-skill` — Parent skill with full Roblox/Luau reference