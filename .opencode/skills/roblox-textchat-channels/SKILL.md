---
name: roblox-textchat-channels
description: Use when building custom chat for a Roblox game — multiple named chat channels shown as switchable TABS (e.g. "Local"/"Global"), cross-server chat or a cross-server event feed, or piping game events (big pulls, kills, announcements) into chat. Covers modern TextChatService + ChannelTabsConfiguration + MessagingService.
---

# Roblox custom chat: channels, tabs, cross-server

Modern games use **TextChatService** (`ChatVersion = TextChatService`). Here's how to get real, switchable channel tabs and cross-server delivery — the non-obvious parts.

## Two channels shown as TABS (the key that's OFF by default)
The modern default chat merges everything into one window UNLESS you enable channel tabs. Two settings, best set as **place properties in Edit mode** (setting them at runtime is too late — the chat server boots first — and can break the default wiring):
- `TextChatService.CreateDefaultTextChannels = false` — drop the default RBXGeneral/System tabs so you get EXACTLY your channels.
- `TextChatService.ChannelTabsConfiguration.Enabled = true` — **this is the switch that makes channels appear as tabs.** `ChannelTabsConfiguration` is an auto-created child of TextChatService. Once on, **each custom `TextChannel` auto-becomes a tab labelled by its `Name`** — no per-channel config needed.

⚠️ Both are **place properties** → they need a **place SAVE** to persist across sessions. Also set them in `ChatService.start()` at runtime as a fallback, but the Edit-mode/place value is what reliably takes effect on boot.

## Creating the channels (server)
With `CreateDefaultTextChannels = false`, the `TextChannels` container is NOT auto-created. So:
```lua
local container = TextChatService:FindFirstChild("TextChannels")
if not container then
    local f = Instance.new("Folder"); f.Name = "TextChannels"; f.Parent = TextChatService; container = f
end
-- Tab order = CREATION order (there is NO reorder API — it's an open devforum feature request).
-- Create the channel you want leftmost FIRST.
local here   = Instance.new("TextChannel"); here.Name   = "Here";   here.Parent   = container
local global = Instance.new("TextChannel"); global.Name = "Global"; global.Parent = container
```
Add every player to each channel on join so they can read + type: `channel:AddUserAsync(player.UserId)` (creates their TextSource; pcall-guard it; it yields, so calls run in order).

## Displaying messages into a channel (client)
`textChannel:DisplaySystemMessage(richText)` shows a message **on the calling client only**, in that channel's tab. Use it to render a game-event feed (pulls, announcements) into a specific tab. RichText works — but **escape user-supplied text** first (`s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")`) or players can inject `</font>` tags.

## Cross-server (chat or an event feed) via MessagingService
`DisplaySystemMessage` is local-only, and normal channel delivery is per-server. To go cross-server:
- **Event feed (e.g. broadcast a rare drop to all servers):** on the event, `MessagingService:PublishAsync(TOPIC, payload)` with `payload.j = game.JobId`. `SubscribeAsync(TOPIC, ...)` on every server; when `data.j ~= game.JobId` (another server), fire a RemoteEvent to local clients → they `DisplaySystemMessage` it. Fire the LOCAL copy instantly via `FireAllClients` and skip your own JobId in the subscriber to avoid a double.
- **Cross-server player chat:** set the channel's `ShouldDeliverCallback` (runs on the SERVER per recipient) — relay the message once (dedupe by `message.MessageId`) via `MessagingService:PublishAsync`, and `return true` to still deliver locally. Other servers receive it and `DisplaySystemMessage` it for their clients (local = native message, remote = system message; acceptable).
- **Always `pcall`-guard MessagingService** — it errors when API access is off (Studio) or rate-limited (~150 + 60×players msgs/min per topic). Then the feature degrades to in-server only instead of crashing.

## Testing caveats
- **Cross-server can't be tested in solo Studio** (one server) — MessagingService round-trips to self only. Verify the in-server path (channels exist, player is a member, DisplaySystemMessage renders) and wire the cross-server path carefully.
- Fire a fake event via `Net.event("X"):FireAllClients(payload)` from the **Server** datamodel, then `screen_capture` the chat (the window pops on a new message) to confirm formatting + which tab it lands in.

## Lesson
Before declaring "the platform can't do X" for chat/UI, **check create.roblox.com/docs and the devforum** — the modern chat is more capable than it first looks (channel tabs, gradients, configs all exist). Docs: create.roblox.com/docs/chat/chat-window ; devforum "Channel Tabs & UI Gradient Now Available in TextChatService".
