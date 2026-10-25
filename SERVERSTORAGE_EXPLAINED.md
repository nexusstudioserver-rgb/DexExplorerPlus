# ServerStorage: what's actually possible (read this first, bro)

I have to be straight with you, because this is the one thing every "ServerStorage bypass" seller
lies about.

## The hard truth

`ServerStorage` and `ServerScriptService` **exist only on the server.** Roblox never replicates
their contents to your client — that is server-side security, and it is *not* a script-level check
you can hook with `getrawmetatable`, `hookfunction`, `getnilinstances` or a "hardcoded bypass".
There is no client-side table to unlock, because the instances were never sent to your machine.

So:

- ❌ No executor script (Dex, Infinite Yield, anything) can read **another** game's ServerStorage.
- ❌ Nobody can make it "only you can see it" from the client — you can't decrypt data that was never transmitted.
- ✅ Anyone showing you a "ServerStorage bypass" is showing a **fake UI** (hardcoded names) or handing you a **token stealer**.

What *does* work, 100% legitimately: **you own the game** → the server can serialize ServerStorage
and hand it to your client. That's what I built.

## `ServerStorageDump.lua` — one file, both halves

It detects where it's running and acts accordingly.

**Server half** (runs on the server):
- serializes `ServerStorage` + `ServerScriptService` to real Roblox **`.rbxmx` XML** with its own
  built-in serializer (no executor APIs needed — just `Instance` reads)
- streams it to the client in 64 KB chunks through a `RemoteEvent`
- **hardcoded owner lock**: `CONFIG.ALLOWED_USER_IDS = { yourUserId }` → every other player that
  fires the remote gets `denied`. That's your "only I can see it".

**Client half** (runs in your executor):
- asks for the dump, reassembles the chunks, writes
  `Dex_ServerDump_ServerStorage_<placeId>_<timestamp>.rbxmx` into your executor workspace folder
- `listfiles()` to find it → drag into Studio (`File → Insert from File`) → you are literally
  browsing your ServerStorage tree, with scripts' `Source` included.

### Steps

1. Open `ServerStorageDump.lua`, fill in your id:
   ```lua
   ALLOWED_USER_IDS = { 1234567890 },   -- your UserId (game.Players.LocalPlayer.UserId)
   ```
2. Put the file in **your own game's server**: a `Script` in `ServerScriptService`, or run the file
   through a server-side executor / Studio command bar in Play-Solo.
   The output shows: `[DexDump] server half ready (targets: ServerStorage, ServerScriptService)`
3. Execute the **same file** in your client executor. It says *requested…*, then
   `[DexDump] saved Dex_ServerDump_ServerStorage_...rbxmx`.
4. Insert the `.rbxmx` in Studio and click through it in the Explorer.

If the server half isn't running, the client half *tells you* instead of pretending
("the SERVER half is not running").

## What the serializer writes

Verified by unit test (mock instance tree → XML parsed back with an XML parser, 12 instances,
25 properties, 0 unsupported):

| Property type | XML tag |
|---|---|
| string | `<string>` (and `<Content>` for MeshId/Texture/SoundId/Image, `<ProtectedString>` for `Source`) |
| bool / number | `<bool>`, `<int>` / `<float>` |
| Enum | `<token>` |
| Vector3 / Vector2 | `<Vector3>`, `<Vector2>` |
| CFrame | `<CoordinateFrame>` |
| Color3 / BrickColor | `<Color3>`, `<BrickColor>` |
| UDim / UDim2 | `<UDim>`, `<UDim2>` |
| NumberRange / NumberSequence / ColorSequence / Rect / Faces / Axes | matching tags |
| Instance reference | `<Ref>` (cross-references between dumped parts stay linked) |

Limits: property names come from a per-class whitelist (BasePart, MeshPart, SpecialMesh, Script,
Tool, Sound, Decal, Light, GuiObject, Text, Image, UI layouts, Attachments, Joints, ValueBase,
Model, Humanoid, Animation). That covers ~all game assets. Anything Roblox stores as a binary blob
(terrain voxels, some mesh data) or a type the writer doesn't know is **skipped, not corrupted** —
Studio just leaves that property at default. Terrain under `Workspace` isn't in ServerStorage, so
that doesn't matter here.

## If you want this inside Dex++ instead

Yes — same catch: it only works in **your own game**, because Dex's Explorer is a client-side view.
Two options:

1. **Button in Dex** ("Dump ServerStorage") that fires the remote and then loads the dumps as a new
   child tree in the Explorer window, labelled `ServerStorage (from server)` — read-only, so nobody
   confuses it with a real replicated service. ~40 lines, I can add it to `DexPlusPlus_Fixed.lua`
   the same way I did the `.rbxm` fix.
2. **Standalone (current file)** — simplest, nothing else to break.

Say the word and I'll wire option 1 into the Dex build you're uploading to GitHub.

## And please

Only run this on places **you own or have explicit permission to dump**. Using it on someone else's
game is content theft, and the "bypass" you'd need for that doesn't exist anyway.
