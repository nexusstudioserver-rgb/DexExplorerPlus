# Dex++ — "Save to File" now saves `.rbxm` instead of `.txt`

File to run in your executor: **`DexPlusPlus_Fixed.lua`**

## What was wrong

In Dex++, "Save to File" (Explorer right-click → *Save to File*, Model Viewer → *Save to File*,
and the Save Instance app) passed a **callback** into `Lib.SaveAsPrompt`, and that callback branch
fell back to a **`.txt`** extension whenever the name had no extension:

```lua
-- old code (the bug)
currentextension = ext or filename:match("%.([^%.]+)$") or "txt"
filename = filename:gsub("%.[^.]+$", "") .. "." .. currentextension
...
local s, msg = pcall(codeToSave, filename)
```

The name Dex builds (`Place_123_Model_Cool_Model_1699`) has no dot, so you got
`Place_123_Model_Cool_Model_1699.txt` sitting in your executor workspace folder — a text file
that Roblox Studio can't open. The `saveinstance` wrapper also blindly trusted whatever name it
was given, so nothing ever corrected it.

## What the fix does

1. **Callback saves never fall back to `.txt`.** `Lib.SaveAsPrompt` now asks for a real Roblox
   extension, so the Save As box already shows `.rbxm`.

2. **One single place decides the extension** (`env.saveinstance` → `env.FixSavePath`):

   | What you save | File you get |
   |---|---|
   | Model / MeshPart / Tool / Folder / any asset / instance | `Something.rbxm` (binary) |
   | The whole game / DataModel (Save Instance app) | `Place_<id>_<name>_<time>.rbxl` |
   | You pass `Binary = false` or type `.rbxmx` / `.rbxlx` | `Something.rbxmx` (XML) |

   `.txt`, `.lua`, `.json`, `.dat`, `.xml` typed by accident are stripped and replaced with the
   correct extension — a text file is now impossible for instance saves.

3. **Works with or without a built-in executor `saveinstance`.** It first tries the executor's own
   `saveinstance(obj, path, options)`; if that errors it falls back to SynSaveInstance (what Dex
   already used), with `IsModel` / `Binary` / `FilePath` set correctly so SynSaveInstance never
   appends its own `.rbxmx`/`.rbxl` or a `(1)` suffix.

4. **Folders are created** if you save into a subfolder (`dex_saves/CoolModel` → `dex_saves/` is
   auto-`makefolder`d).

5. **Console confirmation** every save so you can see the real path:
   `[Dex++] Saved instance -> Place_123_Model_Cool_Model_1699.rbxm`

New helper API on the Dex environment (handy for your own scripts):

```lua
env.RbxmExtension(obj, { IsModel = true, Binary = true }) -- "rbxm" / "rbxmx" / "rbxl" / "rbxlx"
env.FixSavePath("cool_model.txt", obj)                    -- "cool_model.rbxm"
env.saveinstance(obj, "cool_model", { Decompile = true }) -- writes cool_model.rbxm
```

## How to use

1. Open `DexPlusPlus_Fixed.lua` in your executor and execute it (same as before).
2. Right-click a model/asset in the Explorer → **Save to File** → name it → Save.
3. Check your executor's **workspace folder** (`listfiles()`), e.g.
   `workspace/Place_123_Model_Cool_Model_1699.rbxm`.
4. Drag the `.rbxm` into Roblox Studio (or `File → Insert from File`) to open it.

## Notes / troubleshooting

- Executors only write inside their workspace folder — call `listfiles()` to see exactly where the
  file landed.
- If your executor's `writefile`/`appendfile` corrupts binary data, SynSaveInstance detects it and
  switches to XML. Pass `Binary = false` in that case to get a proper `.rbxmx` name:
  `env.saveinstance(model, "cool_model", { Binary = false })`.
- Decompiled **script source** still saves as `.txt`/`.lua` — that is intentional, those are code
  files, not instances.
- The `.rbxl` (whole place) save is meant for Studio: `File → Open` the `.rbxl`, or use
  `File → Insert from File` for a `.rbxm`.
- Syntax-checked against the original file (Luau compiler, exit 0) and the extension logic was unit
  tested: model → `.rbxm`, game → `.rbxl`, accidental `.txt` → `.rbxm`, `.rbxmx` respected,
  paths with dots/subfolders preserved.
