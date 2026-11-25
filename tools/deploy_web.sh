#!/usr/bin/env bash
# Web export alır ve build/web içeriğini gh-pages dalına push eder.
# main dalına build klasörü girmez (.gitignore: build/).
# Kullanım: tools/deploy_web.sh "commit mesajı"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MSG="${1:-Web build}"
cd "$ROOT"
rm -rf build/web && mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
test -f build/web/index.wasm
touch build/web/.nojekyll
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -r build/web/. "$TMP/"
cd "$TMP"
git init -q -b gh-pages
git config user.name "$(git -C "$ROOT" config user.name || echo bayterek-bot)"
git config user.email "$(git -C "$ROOT" config user.email || echo bot@localhost)"
git add -A
git commit -q -m "$MSG"
REMOTE="$(git -C "$ROOT" remote get-url origin)"
for i in 1 2 3 4; do
  if git push -f "$REMOTE" gh-pages:gh-pages; then exit 0; fi
  sleep $((2 ** i))
done
exit 1
