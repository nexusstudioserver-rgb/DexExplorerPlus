# Where does every file go?

Two different "structures" matter here: **the GitHub repo** (what you upload) and **the runtime
placement** (where each file has to be for it to work).

---

## 1. GitHub repo structure (exactly how to upload it)

```
DexPlusPlus/                        ← repo root (the folder you upload)
│
├── out.lua                         ⭐ MAIN FILE — the Dex++ build, also the release asset
├── ServerDump_Server.lua           ⭐ second download — paste into your own game (optional feature)
│
├── README.md                       repo front page (already written)
├── STRUCTURE.md                    this file
│
├── docs/
│   ├── GITHUB_SETUP.md             how to create the release + loader link, troubleshooting
│   ├── RBXM_FIX.md                 what the .rbxm/.rbxl fix changed and why
│   ├── SERVERSTORAGE_SETUP.md      ServerStorage dump: config, usage, tests, limits
│   └── SERVERSTORAGE_EXPLAINED.md  why a client can never read ServerStorage (honest explainer)
│
├── deploy.sh                       one-command publish (git + gh CLI), optional
└── .github/
    └── workflows/
        └── release.yml             auto-updates the out.lua release asset on every push, optional
```

That's it — `out.lua` and `ServerDump_Server.lua` are the only files that actually run.

### Uploading it (website, no git)

1. https://github.com/new → name `DexPlusPlus` → **Public** → Create.
2. On the empty repo: **Add file → Upload files**.
3. Drag **the contents of the `DexPlusPlus` folder** in (not the folder itself): `out.lua`,
   `ServerDump_Server.lua`, `README.md`, `STRUCTURE.md`, `deploy.sh`, plus the `docs/` folder and the
   `.github/` folder if you want the extras. GitHub keeps the folder structure when you drag folders.
4. Commit changes.
5. **Releases → Create a new release**:
   - Tag `stable-3.0`, **Set as the latest release** ✅
   - **Attach binaries**: `out.lua` and `ServerDump_Server.lua` (must be attached — the auto
     "Source code (zip)" is not your asset)
   - Publish
6. Check in a browser: `https://github.com/USER/REPO/releases/latest/download/out.lua` → Lua code.

### Uploading it (git, one command)

```bash
cd DexPlusPlus            # the unzipped folder (it already contains .github/ and docs/)
git init
git add -A
git commit -m "Dex++ fixed: .rbxm saves + ServerStorage dump"
git branch -M main
git remote add origin https://github.com/USER/REPO.git
git push -u origin main

# release (needs gh: https://cli.github.com)
gh release create stable-3.0 out.lua ServerDump_Server.lua \
  --title "Dex++ Fixed" --notes "Save to File writes .rbxm/.rbxl. Adds Save ServerStorage (.rbxmx)."
```

Or just run `./deploy.sh USER REPO stable-3.0` — it syncs, pushes and publishes in one go.

---

## 2. Runtime placement (where the files live while you use them)

```
YOUR EXECUTOR                          YOUR ROBLOX GAME (only if you want ServerStorage)
─────────────                          ────────────────────────────────────────────────
execute out.lua                        ServerScriptService
   │                                        └── Script  ← paste ServerDump_Server.lua here
   └─ Dex++ window                              (set ALLOWED_USER_IDS = { yourUserId } first)
        ├─ Explorer → right-click → Save to File → .rbxm
        └─ Save Instance window
             ├─ [ Save ServerStorage (.rbxmx) ]      ← asks the server half
             └─ [ Save ServerScriptService (.rbxmx) ]

Saved files appear in your executor's WORKSPACE FOLDER (listfiles()):
   Place_<placeId>_Model_<name>_<time>.rbxm
   Dex_ServerDump_ServerStorage_<placeId>_<time>.rbxmx

Then in Roblox Studio:  File → Insert from File → pick the .rbxm / .rbxmx
```

**Minimum setup:** execute `out.lua` only. You get the `.rbxm`/`.rbxl` saving fix.
**Full setup:** also paste `ServerDump_Server.lua` into `ServerScriptService` of a game you own, to
get the ServerStorage / ServerScriptService dump buttons working.

---

## Quick checklist

| # | Task | Where |
|---|---|---|
| 1 | Create public repo | github.com/new |
| 2 | Upload `out.lua` + `ServerDump_Server.lua` (+ docs) | repo → Upload files |
| 3 | Create release, attach `out.lua` as asset, mark latest | repo → Releases |
| 4 | Use loader `loadstring(game:HttpGet("…/releases/latest/download/out.lua"))()` | your executor |
| 5 | (Optional) paste `ServerDump_Server.lua` into a `Script` in ServerScriptService | your own game |
| 6 | (Optional) `ALLOWED_USER_IDS = { yourUserId }` so only you can dump | top of that script |

---

## Notes

- `out.lua` must keep that exact name — the release URL ends with `/out.lua`.
- Keep the repo **public**; private repos return 404 to `game:HttpGet`.
- `.github/workflows/release.yml` only runs if you commit it under exactly
  `.github/workflows/release.yml` (leading dot matters); it then replaces the `out.lua` asset on the
  rolling `latest` release whenever `out.lua` changes.
- The `.rbxm`/`.rbxmx` files are for **Roblox Studio**, not for GitHub — don't commit your dumps.
