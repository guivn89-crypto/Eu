---
name: roblox-avatar-appearance
description: Use when making Roblox avatars/characters look accurate or varied — sourcing and applying clothing (shirts/kits), hair, and faces from the Marketplace catalog, validating them, rendering to hand-pick good ones, and doing nation/identity-weighted skin & hair. Covers the WebFetch catalog-API pipeline that the Studio search_asset tool can't do.
---

# Roblox avatar appearance pipeline

How to give avatars real, varied, accurate clothing/hair/skin — the parts that aren't obvious.

## The core problem
The Studio `search_asset` MCP tool only reaches the **Creator Store** (dev assets: Models/Images/Decals) — NOT the avatar **Marketplace** (clothing/accessories). And soccer/character "jersey" MODELS it finds are 300+-part 3D meshes, useless as wearable clothing. So you must go to the catalog Web API.

## Sourcing assets via the catalog Web API (the breakthrough)
Use `WebFetch` on the catalog search endpoint — it returns asset IDs by keyword within a category/subcategory filter:
```
https://catalog.roblox.com/v1/search/items?category=Clothing&subcategory=ClassicShirts&keyword=<X>&limit=10
```
- **`limit` MUST be 10 or 28.** 6 / 20 return HTTP 400. `category=Accessories` and `creatorTargetId` also 400.
- Subcategories that work: `ClassicShirts`, `ClassicTShirts`, `ClassicPants`. For hair, search `category=Clothing` won't help — search accessories by STYLE keyword (below).
- The endpoint returns only asset IDs; you resolve details next.

## Shirt/Pants: asset id → usable ShirtTemplate id
The catalog gives a Shirt **asset** id, but a `Shirt` object needs the **ShirtTemplate image** id (different number). Resolve each:
1. `InsertService:LoadAsset(assetId)` — **only works in the SERVER datamodel** (client/Edit are blocked).
2. Read the loaded model's child `Shirt.ShirtTemplate` → that's the usable template id (`:match("%d+")`).
3. Apply as a real object: `shirt.ShirtTemplate = "rbxassetid://<templateId>"` (or `http://www.roblox.com/asset/?id=<id>`), `shirt.Parent = model`. Do the same for Pants.

## Hair (and other accessories): validate, then hand-pick
1. **Validate each candidate is a real hair:** set `desc.HairAccessory = tostring(id)` on a `HumanoidDescription`, then `Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)` and count `Accessory` descendants > 0. Many "hair" search results aren't valid HairAccessories.
2. **Keyword matters:** the generic `hair`/`classic hair` keyword returns mostly spiky ANIME UGC. Search by **STYLE**: `buzz cut hair`, `afro hair`, `man bun hair`, `curly fade`, `dreadlocks`, `slicked back hair`, `headband hair` — these return realistic styles. Real classic Roblox hairs appear archived/unsearchable; realistic UGC picks are the practical substitute.

## Rendering to hand-pick (you can't trust ids blind)
- **ViewportFrames render dark** — render candidates on **lit workspace rigs** with numbered BillboardGuis, then `screen_capture` to pick the good/iconic ones by eye.
- A **blank HumanoidDescription → a BLACK body.** Set the color fields (`desc.HeadColor`, `TorsoColor`, `LeftArmColor`, etc.) to a skin tone before generating, or the preview is unusable.
- Weld accessories and anchor parts so the rig holds still for the shot. Clean up the temp rig folder + restore the camera (`CameraType = Custom`, re-enable Freecam) afterward.

## Nation / identity-weighted skin & hair colour
For plausible-per-identity appearance (instead of random), use small weighted-distribution tables keyed by nation (or team/faction), picked by a stable hash of the card/character id:
- `SKIN` = an 8-ish tone palette (light→deep). `NATION_SKIN[nation] = {weighted indices}` (repeats bias the pick). `skinFor(nation, hash) = SKIN[pool[(hash % #pool) + 1]]`, full-range fallback for unknown.
- `HAIR_COLORS` (black→blonde→grey) + `NATION_HAIR[nation] = {weighted indices}` the same way. Tint the hair mesh `Handle.Color` to the picked colour so a small mesh set reads as varied hair.
- Verify live: dark tones for the right nations, Nordic blonde, diverse sides span light→dark.

## Per-card/character signature override
To make a MARQUEE character always recognisable (not a random hash pick), add an override map keyed by id and check it first:
```lua
local CARD_HAIR: { [string]: string } = { ["some-star-id"] = "<hairAssetId>" }
-- in generate(): local hair = CARD_HAIR[id] or HAIR[(hash // k) % #HAIR + 1]
```
Same pattern works for a signature kit/skin.

## ⚠️ IP caveat
Real branded kits/logos carry trademark risk. Prefer spoofed/evocative branding, or only ship real branding with the project owner's explicit OK. Real-player FACES are a likeness impossibility on Roblox — use a small set of generic classic faces for expression variety, not likenesses.
