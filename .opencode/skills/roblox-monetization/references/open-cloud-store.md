# Open Cloud: creating and syncing passes and developer products

A script-driven store, so prices, names, descriptions and icons live in the repo, not only in the Creator Hub.

## Files
- `tools/store/items.py`: `UNIVERSE = <universe id>` and `ITEMS = [dict(key, kind="pass"|"product", name, description, price, icon, ...)]`. `key` matches the game's product config.
- `tools/store/make_icons.py`: 512x512 PNG per item in `tools/store/icons/<key>.png` (game UI icon on a gradient badge).
- `tools/store/create.py`: dry run / `--create` / `--sync`, writes `tools/store/ids.json` (key → id).

## API key
- The user's Open Cloud key, stored in the macOS Keychain (`security find-generic-password -s <name> -w`), never in the repo or chat.
- Scopes on that universe: `game-pass:read`, `game-pass:write`, `developer-product:read`, `developer-product:write`.
- Header: `x-api-key: <key>`.

## Endpoints (base `https://apis.roblox.com`)
| What | Method + path |
|---|---|
| List passes | `GET /game-passes/v1/universes/{u}/game-passes/creator?pageSize=50&pageToken=` → `gamePasses[] {name, gamePassId}`, `nextPageToken` |
| List products | `GET /developer-products/v2/universes/{u}/developer-products/creator?pageSize=50` → `developerProducts[] {name, productId}` |
| Create pass | `POST /game-passes/v1/universes/{u}/game-passes` (multipart) → `gamePassId` |
| Create product | `POST /developer-products/v2/universes/{u}/developer-products` (multipart) → `productId` |
| Update pass | `PATCH /game-passes/v1/universes/{u}/game-passes/{id}` (multipart) |
| Update product | `PATCH /developer-products/v2/universes/{u}/developer-products/{id}` (multipart) |

Multipart fields: `name`, `description`, `price`, `isForSale` ("true"), `isManagedPricingEnabled` ("true" for passes, "false" for products), file field `imageFile` (PNG).

## Script rules
- Page through the lists first. An item whose **name** already exists is reused, never made twice, so the script is safe to re-run.
- Write `ids.json` after every create (a failure halfway keeps what was made).
- Default run is a dry run that prints `exists` / `missing`. `--create` publishes items **for sale**: run it only when the user asks.
- `--sync` PATCHes `price` + `isManagedPricingEnabled` on existing items. On `InvalidManagedPricing` (terms not accepted in the Creator Hub), retry with the price alone and print that the user must accept Managed Pricing, then sync again.
- After creating, copy ids from `ids.json` into the shared product config (one list for every place in the universe).
- Keep `items.py` prices and the config's default `robux` numbers in step. GUIs still show the live price (see RobuxPrice).
