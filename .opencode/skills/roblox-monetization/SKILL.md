---
name: roblox-monetization
description: Use when building or auditing Roblox monetization — Developer Products (Robux purchases via ProcessReceipt), Gamepasses, gem/currency bundles, limited-stock offers, Robux price labels, store items created via Open Cloud, or anything touching real Robux. Covers the idempotency + rollback pattern that prevents "charged but got nothing" and duplication bugs, one product list per universe, live per-player (regional) prices, Open Cloud creation/sync of passes and products, cross-server stock, pass attributes, test hooks and purchase analytics.
---

# Roblox monetization: safe receipts, passes, prices and offers

Real Robux is unforgiving. A subtle bug means players get charged and receive nothing, or get free stuff forever. These are the patterns that kept a shipped two-place game correct.

## One product list per universe
- Keep **every** pass and developer product in ONE shared config module (e.g. `ProductConfig.Products = { Key = { kind = "Product"|"Pass", id, robux, grant?, amount? } }`).
- Passes, products and DataStores belong to the **universe**, so a lobby place and a game place share the same ids. Map the one module into every place's Rojo project (see roblox-studio-workflow, multi-place) instead of copying ids around.
- Each place's config reads its ids from that list, never its own copy.
- `id == 0` = **not made yet**: the Buy button toasts "Coming soon!" instead of prompting, and receipt routing skips it. The shop is then safe before the ids exist.

## Never print the config price
- The `robux` number in config is the Creator Hub **default** price only. With **Managed (regional) Pricing** on passes, many players are charged less. The purchase prompt is always right, but your label drifts.
- GUIs show prices through one small client module (template: `templates/RobuxPrice.luau`):
  - `RobuxPrice.watch(key, fn(text))` calls `fn` at once with the default, then again when the real price is in.
  - It uses `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.GamePass | Product)` **from the client**, which returns THIS player's price (`PriceInRobux`), with retries and a per-session cache.
  - `RobuxPrice.text(key)` / `.get(key)` never yield.
- Rule: no GUI string ever holds a Robux number directly. Grep for `robux` uses in client code during audits.
- **Managed Pricing now covers developer products too** (regional prices + Roblox's price optimization). It needs the "no trading or gifting" attestation. The config
  `robux` is only the base price: anything computed from prices ("SAVE 34%", "x5 VALUE", a struck "was" price) must
  use each item's live price for this player, or it lies in most countries.
- Revenue logged from your own events (value = the default price) is approximate under Managed Pricing; the Creator
  Hub revenue page is the truth.

## Create and update store items from a script (Open Cloud)
Clicking passes together in the Creator Hub doesn't scale and drifts from code. Use a script instead; reference: `references/open-cloud-store.md`.
- `items.py` (or similar) lists each item: `key` (matches the config), `kind`, `name`, `description`, `price`, icon.
- `create.py` modes:
  - dry run (default): lists what exists and what is missing.
  - `--create`: makes the missing items with their icons. **This publishes for sale**, so it runs only on the user's request.
  - `--sync`: PATCHes prices plus `isManagedPricingEnabled` (true for every item) onto existing items. It matches by
    name, so a rename is a one-off PATCH.
- Idempotent by **name**: list the universe's existing passes/products first and reuse their ids. Write `ids.json` after every create, so a failure halfway loses nothing. Copy the ids into the shared config.
- API key: the user's own key, read from the OS keychain, never from the repo. Scopes: `game-pass:read/write` and `developer-product:read/write` on that universe. Keys are ~960 characters and the interactive `security add-generic-password -w` prompt stores only 128 (Roblox answers "Invalid API Key"): save with `-w "$(pbpaste)"` (**roblox-live-ops**).
- **Create new items without asking** (the user's standing preference): add to `items.py`, run create, wire the id,
  and report the price chosen so they can change it.
- An `InvalidManagedPricing` error means the Managed Pricing terms aren't accepted on the Creator Hub yet. Set the price alone and tell the user to accept the terms.
- Icons: draw 512x512 badges from the game's own UI icons (PIL script), so store art matches in-game art.

## Developer Products: `MarketplaceService.ProcessReceipt`
- **Exactly one `ProcessReceipt` per place**, in one Receipts module. Never assign it twice: the last one wins silently.
- Roblox delivers a receipt to whichever server the player is in, in any place of the universe. Route by product:
  - A product this place can't grant (a run-only item while in the lobby): return `NotProcessedYet`. It is re-delivered when the player is in the right place.
  - Player not in this server, or profile not loaded: `NotProcessedYet`.
- It MUST be **idempotent** (Roblox re-delivers until you return `PurchaseGranted`) and **atomic**: the grant and the PurchaseId are recorded in the SAME durable write.

**Commit-and-rollback shape (session profile you save yourself):**
```lua
local key = tostring(receipt.PurchaseId)
if data.Receipts[key] then return Enum.ProductPurchaseDecision.PurchaseGranted end -- already granted
if busy[key] then return Enum.ProductPurchaseDecision.NotProcessedYet end          -- mid-grant
if not Profile.canSave(player) then return Enum.ProductPurchaseDecision.NotProcessedYet end -- load failed: never grant unsaved
busy[key] = true
data.Gems += amount
data.Receipts[key] = os.time()            -- timestamp, so old ids can be trimmed (keep ~100)
if not Profile.saveNow(player) then       -- durable save failed → undo both
	data.Gems -= amount
	data.Receipts[key] = nil
	busy[key] = nil
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
busy[key] = nil
return Enum.ProductPurchaseDecision.PurchaseGranted
```

**When another place owns the profile** (the game place grants a Revive into the lobby's profile store), use one `UpdateAsync` that checks and writes both:
```lua
store:UpdateAsync(profileKey, function(saved)
	local data = if typeof(saved) == "table" then saved else {}
	data.Receipts = data.Receipts or {}
	if data.Receipts[purchaseId] then result = "already"; return nil end -- nil cancels the write
	data.Receipts[purchaseId] = os.time()
	data.Revives = (data.Revives or 0) + 1
	return data
end)
```
Both places then share the profile's `Receipts` field, so a receipt is never granted twice even when it lands in the other place.

**In-session items** (consumables that aren't saved): grant, then record the PurchaseId in a `Receipts_v1` DataStore. If the record write fails, call the handler's `undo` and return `NotProcessedYet`. A record read that errors means "unknown": return `NotProcessedYet`, never grant.

**Rules that prevent the classic bugs:**
- **Only grant fungible things inside ProcessReceipt** (currency, counts, an owned flag). Don't roll a random reward inside it: a rollback plus re-delivery re-rolls. Grant a token and let the client redeem it.
- **Never use a config table as a table key.** `inventory[def] = ...` can't be serialized, so the save throws, the grant rolls back and the receipt re-delivers forever. The player is charged and gets nothing. Extract the string id.
- Resets (admin "reset progress") never touch `Receipts` or owned limited items.
- Minor known window: `receipts[key]` is set before `save()` yields. The `busy` set covers concurrent re-invocations in the same server.

## Gamepasses
- Publish ownership as a **Player attribute** `Pass_<key>` on the server. Every check (server and client GUIs) reads the attribute.
- On join: `UserOwnsGamePassAsync` per pass (pcall).
- Also **set the attribute again on `PromptGamePassPurchaseFinished`** (when `bought`). `UserOwnsGamePassAsync` is cached and can say false right after a purchase, so the perk must work at once without a rejoin.
- An "all passes" bundle: a saved flag that re-applies every pass on each join, so passes added later unlock too.
- A pass bought in one place works in the others of the same universe. Each place runs its own pass check.

## Limited-stock offers ("only 100 will ever be sold")
- Make them **developer products, not passes**: a pass can't be stopped at N sales, but your server can refuse to prompt.
- Config: `{ key, stock, endsAt = <unix UTC>, ... }`. The owned flag is saved in the profile (`Limited[key]`) and published as a Player attribute.
- **Buy flow**: the client invokes a `BuyLimited(key)` RemoteFunction. The server checks per-player cooldown, already owned, `os.time() < endsAt`, does a **fresh stock read**, then calls `PromptProductPurchase` itself. The client never prompts directly.
- **Shared count**: DataStore `LimitedStock_v1` (key → units sold).
  - Each server reads it every ~45 s.
  - After a sale, `UpdateAsync(+1)` with retries, then `MessagingService:PublishAsync("LimitedSold", {key, sold})`; subscribers update at once.
  - Counts only ever go up locally, so a stale read never gives stock back.
  - Publish `ReplicatedStorage` attribute `LimitedLeft_<key>` for the card's "N / 100 LEFT" bar and the SOLD OUT / ENDED states.
- `recordSale` runs in the Receipts module **after** the grant is saved. Two buyers racing for the last unit can both get it: a paid receipt is always honoured.

## Time-boxed offers: preview and switch-over
- Offers with `endsAt` switch by themselves on running servers (the shop re-reads on open, a HUD tile re-picks every
  few seconds); queue the next offer with its start = the old one's end, and check the switch in a playtest with the
  end moved to "now" on server and client.
- An admin **Offer Clock** previews any moment (see roblox-game-architecture, admin tools); purchase checks always
  use the real time on live servers.

## Admin gifts go through the receipt path
Give a product to a player through the same handler as a purchase, with a made-up receipt (`PurchaseId =
"admin-<guid>"`, a `Gift` flag): it is granted exactly like a sale, recorded the same, and skips limited stock and
sales stats. A pass is given through the same owned flag a gem purchase sets. Never write a second grant path.

## Offer slots
Sell a pass where it's useful: a greyed, locked slot after the owned hotbar slots shows the next tool pass the player lacks, with its live price. Tapping it prompts the pass. It hides once that attribute (or something better) is owned. Same idea for in-minigame offer cards ("2x faster scoop").

## Analytics
Log a funnel step right before every `Prompt...Purchase` (e.g. `Funnel.prompt(player, key, "where")`), and the purchase on `Prompt*PurchaseFinished`. Then Creator Hub funnels show prompt → buy rates per placement. A new prompt call without the log is a review finding.

## Testing (Studio can't really buy)
Studio test purchases need the real product and often have no DataStore access. Build hooks in from the start:
- `Receipts.process = processReceipt`: run a **fake receipt table** (`{PlayerId, ProductId, PurchaseId}`) through the real path from `eval_server_runtime`. Run it twice with the same PurchaseId to check it grants once.
- `Profile.failSaves = true` / `LobbyData.failWrites` / `Receipts.failRecords`: force the durable write to fail and check the grant is undone and `NotProcessedYet` comes back.
- Admin toggle **"No Passes"** (a saved per-admin setting): every pass check says not owned and `Pass_*` attributes clear. Then the developer, who owns everything, can see the shop and locked slots as a normal player. Every new pass check must ask it.
- In Studio without API access, dedupe receipts in memory and say so in a warning.

## Launch checklist (the user does these)
- Run `create.py --create` (or make items in the Creator Hub), copy the ids, accept Managed Pricing terms, `--sync`.
- Turn on Studio API access for DataStore testing.
- Publish every place (Claude can't publish).

## Persistence of purchase fields
Every purchase field (`Receipts`, currency, owned flags, tokens) needs full save/load/reset parity. A field loaded but not saved, or the reverse, means re-claimable gifts or lost purchases. General checklist: **roblox-studio-workflow**. Store design (UpdateAsync, MessagingService, quotas): **roblox-data**. Open Cloud details: **roblox-cloud**.
