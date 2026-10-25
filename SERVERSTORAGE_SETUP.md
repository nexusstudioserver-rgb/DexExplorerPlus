# Dump ServerStorage — wired into Dex++ and tested ✅

Two files, that's all:

| File | Where it goes | Why |
|---|---|---|
| **`ServerDump_Server.lua`** | **your game** → `ServerScriptService` → a `Script` (paste it in) | ServerStorage only exists on the server, so the server has to send it |
| **`DexPlusPlus_Fixed.lua`** (or `out.lua`) | your **executor** (same as always) | has the new buttons + the receiver that writes the file |

## What you do

1. **Fill in your UserId** at the top of `ServerDump_Server.lua`:
   ```lua
   local ALLOWED_USER_IDS = {
       1234567890,   -- your UserId  (game.Players.LocalPlayer.UserId)
   }
   ```
   Empty list = everybody can request it. Filled = **only you**, everyone else gets `denied`
   and the server logs them.

2. Put that file in **your own game**: `ServerScriptService` → new `Script` → paste everything.
   The output window shows:
   ```
   [DexDump] server half ready  |  targets: ServerStorage, ServerScriptService
   ```

3. Execute Dex in your executor → open **Save Instance** window. You'll now see at the bottom:

   ```
   Server dump: server half detected - ready
   [ Save ServerStorage (.rbxmx) ]   [ Save ServerScriptService (.rbxmx) ]
   ```

   Click one. Status goes `requesting… → receiving… x KB → saved <file>.rbxmx`.

4. File lands in your executor workspace folder:
   `Dex_ServerDump_ServerStorage_<placeId>_<timestamp>.rbxmx`
   → `listfiles()` to find it → Studio: **File → Insert from File** → you're browsing the whole
   ServerStorage tree (models, tools, folders, **script source included**).

If the server half isn't running, the label reads
`Server dump: no server half (ServerStorage is server-only)` and clicking explains it instead of
hanging. It re-checks every 3 seconds, so you can start the server script after Dex is already open.

## Also available as a plain API (no UI needed)

```lua
env.ServerDump.IsAvailable()            --> true / false
env.ServerDump.Request("ServerStorage", {
    OnStatus = function(text) print(text) end,
    OnDone   = function(fileName, info) print(fileName, info.instances, info.bytes) end,
    OnError  = function(text) warn(text) end,
})
-- also: getgenv().DexServerDump
```

## Proof it works (tests I ran)

* whole Dex file compiles with the Luau compiler → exit 0 (also after every patch)
* **end-to-end simulation**: fake RemoteEvent → fake ServerStorage tree (Folder/Tool/Part/
  SpecialMesh/Script/ScreenGui) → Dex `env.ServerDump.Request` → chunked chunks reassembled →
  `writefile` called → produced file parsed back with a real XML parser:

  ```
  - ServerStorage 'ServerStorage'
    - Folder 'Hidden'
      - Tool 'AdminSword'  [CanBeDropped, RequiresHandle]
        - Part 'Handle'    [Anchored, CanCollide, Size, CFrame, Transparency]
        - SpecialMesh 'Mesh' [MeshId]
      - Script 'GiveTools' [Source, Disabled]      ← source text preserved & XML-escaped
  ```
* error paths verified: no server half → `false` + clear message; `denied` → owner-lock message and
  the running flag is cleared; exactly one file written per request (no double-saves).

## Notes

* Chunks are streamed 64 KB at a time (`CHUNK_SIZE` in the server file) and `task.wait()`ed, so
  big ServerStorages don't blow Roblox's remote limits or the executor's queue.
* Big services can take a few seconds — that's normal; the status label updates while it streams.
* The dump is written as **`.rbxmx`** (XML) because a client-side binary `.rbxm` writer doesn't
  exist. Studio opens both identically; if you want a `.rbxm`, insert the `.rbxmx` in Studio and
  re-save as `.rbxm`.
* What is skipped: property types my writer doesn't know, and non-creatable internal data
  (e.g. terrain voxels — not in ServerStorage anyway). Instances/classes/structure are always kept;
  a skipped property just stays at its default in Studio. Nothing gets corrupted.
* Still only for **places you own / have permission to dump**. In other people's games there is no
  server half and ServerStorage is simply never sent to you — that part is Roblox security, not a
  bug to fix.
