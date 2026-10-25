#!/usr/bin/env bash
# Deploy this Dex++ build to GitHub and publish the release assets.
#
#   ./deploy.sh USER REPO [TAG]
#   ./deploy.sh AZYsGithub DexPlusPlus stable-3.0
#
# Needs: git, gh (https://cli.github.com) and `gh auth login` once.
set -euo pipefail

USER="${1:?usage: ./deploy.sh USER REPO [TAG]}"
REPO="${2:?usage: ./deploy.sh USER REPO [TAG]}"
TAG="${3:-stable-3.0}"

# files that go into the repo + get attached to the release
REPO_FILES=(out.lua ServerDump_Server.lua README.md README_FIX.md SERVER_STORAGE_WIRED.md)
ASSETS=(out.lua ServerDump_Server.lua)

[ -f out.lua ] || { echo "!! out.lua missing (run me from the workspace root)"; exit 1; }
[ -f ServerDump_Server.lua ] || { echo "!! ServerDump_Server.lua missing"; exit 1; }
command -v gh >/dev/null || { echo "!! gh CLI missing: https://cli.github.com"; exit 1; }

# keep out.lua in sync with the fixed build
if [ -f DexPlusPlus_Fixed.lua ]; then cp DexPlusPlus_Fixed.lua out.lua; fi

WORK="$(mktemp -d)"
git clone "https://github.com/$USER/$REPO.git" "$WORK/repo" 2>/dev/null || {
  echo "!! clone failed. If the repo is empty/new, create it on github.com first, or run:"
  echo "   gh repo create $USER/$REPO --public --source=. --remote=origin --push"
  exit 1
}

for f in "${REPO_FILES[@]}"; do
  [ -f "$f" ] && cp "$f" "$WORK/repo/$f"
done

(
  cd "$WORK/repo"
  git add -A
  if git diff --cached --quiet; then
    echo "== no changes to commit"
  else
    git commit -m "Dex++ fixed: save as .rbxm/.rbxl + ServerStorage dump button"
    git push
  fi
)

if gh release view "$TAG" --repo "$USER/$REPO" >/dev/null 2>&1; then
  echo "== release $TAG exists -> replacing assets"
  gh release upload "$TAG" "${ASSETS[@]}" --repo "$USER/$REPO" --clobber
else
  gh release create "$TAG" "${ASSETS[@]}" --repo "$USER/$REPO" \
    --title "Dex++ Fixed ($TAG)" \
    --notes "Save to File now writes .rbxm/.rbxl (no more .txt). Adds Save ServerStorage (.rbxmx) using ServerDump_Server.lua in your own game."
fi

rm -rf "$WORK"
echo
echo "done. loader:"
echo "loadstring(game:HttpGet(\"https://github.com/$USER/$REPO/releases/latest/download/out.lua\"))()"
