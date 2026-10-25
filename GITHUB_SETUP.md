# Put this build on GitHub → get the `loadstring` link

Your example works like this:

```
https://github.com/USER/REPO/releases/latest/download/out.lua
        └─ GitHub redirects to whichever release is marked "Latest"
                                                    └─ and to the asset named out.lua
```

So 3 requirements: **public repo**, a file named exactly **`out.lua`**, and that file **attached to the
latest release**. That's it.

## Files in your workspace, and where they go

| File | GitHub | Notes |
|---|---|---|
| `out.lua` | repo **+ release asset** ⭐ | the Dex++ build (577 KB, compiles clean) — this is what your loader downloads |
| `ServerDump_Server.lua` | repo **+ release asset** | optional second download; people paste it into their own game |
| `README.md` | repo | project page (already written) |
| `README_FIX.md`, `SERVER_STORAGE_WIRED.md` | repo | docs |
| `deploy.sh`, `.github/workflows/release.yml` | repo | automation (optional) |

> ⚠️ Don't replace `out.lua` with `DexPlusPlus_Fixed.lua`'s old copy — I already synced `out.lua`
> with the newest build (identical bytes, verified).

---

# Method A — website only (no git, ~2 minutes)

### 1. Create the repo
https://github.com/new → name `DexPlusPlus` → **Public** ✅ → **Create repository**

### 2. Upload the files
On the empty repo page click **“uploading an existing file”** (or *Add file → Upload files*), drag in:

```
out.lua
ServerDump_Server.lua
README.md
README_FIX.md
SERVER_STORAGE_WIRED.md
```

→ **Commit changes**

### 3. Create the release (this is the part that makes the link work)
Repo sidebar → **Releases** → **Create a new release** (or `https://github.com/USER/REPO/releases/new`)

- **Tag**: `stable-3.0` → *Create new tag on publish*
- **Title**: `Dex++ Fixed`
- **Set as the latest release** ✅ (NOT pre-release, NOT draft)
- **Attach binaries**: drag in **`out.lua`** and **`ServerDump_Server.lua`**
  ⬅️ the auto-generated `Source code (zip)` files are **not** your asset; you must attach these manually
- **Publish release**

### 4. Test in your browser first
Open `https://github.com/USER/REPO/releases/latest/download/out.lua`
→ you must see Lua code (starting with `--[[` / `Dex++`). If you see a 404 page, the asset name or the
"latest" flag is wrong.

### 5. Your loader
```lua
loadstring(game:HttpGet("https://github.com/USER/REPO/releases/latest/download/out.lua"))()
```

With your example names:
```lua
loadstring(game:HttpGet("https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua"))()
```

Cache-proof (GitHub CDN can serve the old file for a few minutes after an update):
```lua
loadstring(game:HttpGet("https://github.com/USER/REPO/releases/latest/download/out.lua?v=" .. os.time()))()
```

---

# Method B — git + gh CLI (fast to update later)

One time:
```bash
gh auth login                      # or set GH_TOKEN
gh repo create USER/DexPlusPlus --public --source=. --remote=origin --push
#   ...or clone an existing repo instead of creating one
```

Then deploy everything in one command (script is in your workspace, already executable):
```bash
./deploy.sh USER DexPlusPlus stable-3.0
```

It does: sync `out.lua` from `DexPlusPlus_Fixed.lua` → clone → commit the repo files → push →
create the release **or** replace its assets with `--clobber` → print your loader line.

Manual equivalent:
```bash
git add out.lua ServerDump_Server.lua README.md
git commit -m "Dex++ fixed: .rbxm saves + ServerStorage dump"
git push

gh release create stable-3.0 out.lua ServerDump_Server.lua \
  --title "Dex++ Fixed" \
  --notes "Save to File writes .rbxm/.rbxl. Adds Save ServerStorage (.rbxmx)."
```

Update later — **the loader URL never changes**:
```bash
./deploy.sh USER DexPlusPlus stable-3.0        # replaces out.lua on the same release
```

---

# Auto-release on every push (optional, zero manual steps)

`.github/workflows/release.yml` is in your workspace. Copy it into the repo as
`.github/workflows/release.yml`. After that, every push that touches `out.lua`:

1. creates the rolling `latest` release if missing,
2. replaces its `out.lua` asset with the new file.

So editing `out.lua` in the GitHub web editor is enough to update everyone's loader.

> Note: with this workflow the release tag is `latest`, so the link is
> `…/releases/latest/download/out.lua` (works the same) — or use
> `…/releases/download/latest/out.lua` if you prefer an explicit tag.

---

# Common problems

| Symptom | Fix |
|---|---|
| `404` in browser | Asset isn't named exactly `out.lua`, or the release is a **draft/pre-release** → `releases/latest` skips it. Publish it as latest. |
| Worked before, 404 now | You deleted the release, or uploaded `out (1).lua`. Asset name must match the URL exactly, case-sensitive. |
| Private repo | `game:HttpGet` gets 404 — repo must be **public**. |
| Executor still runs the old version | CDN cache — wait ~5 min or add `?v=" .. os.time()`. |
| Only "Source code (zip)" under Assets | You didn't attach the file in *Attach binaries*. Auto-generated archives can't serve as `out.lua`. |
| `loadstring` returns nil | Server returned an HTML error page (404) — check the URL in a browser. Safer loader below. |

Safer loader with a real error message:

```lua
local URL = "https://github.com/USER/REPO/releases/latest/download/out.lua"
local ok, src = pcall(game.HttpGet, game, URL)
if not ok or type(src) ~= "string" or #src < 1000 then
    return warn("[Dex++] download failed: " .. tostring(src))
end
loadstring(src, "Dex++")()
```

## Alternative URLs (same file)

- **Raw** (file committed in repo, updates the instant you push):
  `https://raw.githubusercontent.com/USER/REPO/main/out.lua`
- **jsDelivr mirror** (fast, cache-friendly):
  `https://cdn.jsdelivr.net/gh/USER/REPO@main/out.lua`

Release asset is the most reliable for executors, raw is the fastest to update.

## Heads-up about the second file

`ServerDump_Server.lua` **cannot** be run from the client — it must be pasted into a `Script` in
`ServerScriptService` of the game **you own**. Attaching it to the release just gives people an easy
download link; it doesn't make the ServerStorage dump work in someone else's game (nothing can).
