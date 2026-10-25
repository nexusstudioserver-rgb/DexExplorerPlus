# Dex++ (fixed build)

A patched build of **Dex++ v3.0** with two fixes/features on top of the original:

1. **`Save to File` writes real Roblox files** — models and assets save as **`.rbxm`** (binary) and a
   whole place saves as **`.rbxl`**, instead of the broken `.txt` the original produced.
2. **ServerStorage / ServerScriptService dump** — a button in the *Save Instance* window that pulls
   your own game's `ServerStorage` as a `.rbxmx` you can open in Studio, with a hardcoded owner lock.

## Load in your executor

```lua
loadstring(game:HttpGet("https://github.com/USER/REPO/releases/latest/download/out.lua"))()
```

Cache-proof version:

```lua
loadstring(game:HttpGet("https://github.com/USER/REPO/releases/latest/download/out.lua?v=" .. os.time()))()
```

## Files

| File | Use |
|---|---|
| `out.lua` | the Dex++ build — execute it in your executor (this is the release asset) |
| `ServerDump_Server.lua` | optional: paste into **your own game's** `ServerScriptService` to enable the ServerStorage dump |
| `docs/RBXM_FIX.md` | what the `.rbxm` fix changed and why |
| `docs/SERVERSTORAGE_SETUP.md` | how the ServerStorage dump works, config, limits |
| `docs/SERVERSTORAGE_EXPLAINED.md` | why ServerStorage can't be read from the client (honest explainer) |
| `docs/GITHUB_SETUP.md` | how to publish this repo + release + loader link |
| `STRUCTURE.md` | where every file goes |

## Save to File → `.rbxm`

Right-click anything in the Explorer → **Save to File** (`Model`, `MeshPart`, `Tool`, `Folder`, …) or
Model Viewer → **Save to File**. The file lands in your executor's workspace folder:

```
Place_<placeId>_Model_<name>_<timestamp>.rbxm
```

`listfiles()` shows it; drag it into Studio or use `File → Insert from File`.

| Saved | Result |
|---|---|
| Model / asset / any instance | `.rbxm` (binary) |
| Whole game (Save Instance app) | `.rbxl` |
| `Binary = false` / name ends `.rbxmx` | `.rbxmx` (XML) |

Accidental `.txt`, `.lua`, `.json` extensions are stripped — a text file for instance saves is now
impossible.

## ServerStorage dump (own games only)

`ServerStorage` and `ServerScriptService` are never replicated to clients, so no client executor can
read them. The legal, working version: run the server half in your own game.

1. In `ServerDump_Server.lua` set `ALLOWED_USER_IDS = { yourUserId }` (everyone else is denied).
2. Paste it into a `Script` in `ServerScriptService` of **your** game.
   Output: `[DexDump] server half ready | targets: ServerStorage, ServerScriptService`
3. In your executor, open Dex → **Save Instance** → `Save ServerStorage (.rbxmx)`.
4. `Dex_ServerDump_ServerStorage_<placeId>_<time>.rbxmx` lands in your workspace folder
   → `File → Insert from File` in Studio → browse the whole ServerStorage tree, script source included.

API form, no UI needed:

```lua
env.ServerDump.Request("ServerStorage", {
    OnStatus = print,
    OnDone   = function(fileName, info) print(fileName, info.instances) end,
    OnError  = warn,
})
```

## Notes

- Credits to **vinskie / Moon's Dex** for the original Dex++ source; this is a patched fork.
- Tested with the Luau compiler plus an end-to-end simulation of the dump (serializer output parses as
  valid Roblox XML).
- Use the dump only on places you own or have permission to dump.
