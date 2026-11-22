--!strict
-- The Robux price this player is really charged for a ProductConfig.Products item. Passes use Roblox's
-- regional Managed Pricing, so the price can be lower than the default in poorer regions;
-- MarketplaceService:GetProductInfoAsync called from the CLIENT returns this player's price. Until it
-- answers (or if it fails) the default `robux` from ProductConfig is used. Results are cached per session.
--   RobuxPrice.get(key) -> number           cached / default price, never yields
--   RobuxPrice.text(key) -> string          "R$ <price>"
--   RobuxPrice.watch(key, fn(text))         calls fn now with the default, again once the real price is in

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)

local RobuxPrice = {}

local cache: { [string]: number } = {}
local loading: { [string]: { (string) -> () } } = {}

function RobuxPrice.get(key: string): number
	local product = ProductConfig.Products[key]
	return cache[key] or (if product then product.robux else 0)
end

function RobuxPrice.text(key: string): string
	return `R$ {RobuxPrice.get(key)}`
end

local function load(key: string)
	local product = ProductConfig.Products[key]
	if not product or product.id <= 0 then
		return
	end
	local infoType = if product.kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
	for attempt = 1, 3 do
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, product.id, infoType)
		if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
			cache[key] = info.PriceInRobux
			break
		end
		task.wait(attempt * 2)
	end
	local waiting = loading[key]
	loading[key] = nil
	for _, fn in waiting or {} do
		task.spawn(fn, RobuxPrice.text(key))
	end
end

function RobuxPrice.watch(key: string, fn: (string) -> ())
	fn(RobuxPrice.text(key))
	if cache[key] then
		return
	end
	local waiting = loading[key]
	if waiting then
		table.insert(waiting, fn)
		return
	end
	loading[key] = { fn }
	task.spawn(load, key)
end

return RobuxPrice
