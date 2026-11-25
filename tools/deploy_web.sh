#!/usr/bin/env bash
# Web export alır ve build/web içeriğini gh-pages dalına push eder.
# main dalına build klasörü girmez (.gitignore: build/).
#
# Önbellek kırma: her build benzersiz adla dışa aktarılır (bayterek-<sha>-<zaman>.pck/.wasm/.js),
# index.html bu adları yükler → tarayıcı eski oyun dosyasını önbellekten getiremez.
# Sürüm kimliği data/build_info.txt'ye yazılır; menünün altında görünür (hangi build açık?).
# Kullanım: tools/deploy_web.sh "commit mesajı"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MSG="${1:-Web build}"
cd "$ROOT"
SHA="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"
STAMP="$(date -u +%Y%m%d-%H%M)"
BUILD_ID="${SHA}-${STAMP}"
echo "$BUILD_ID" > data/build_info.txt
trap 'rm -f "$ROOT/data/build_info.txt"' EXIT
rm -rf build/web && mkdir -p build/web
NAME="bayterek-${BUILD_ID}"
godot --headless --path . --export-release "Web" "build/web/${NAME}.html"
test -f "build/web/${NAME}.wasm"
mv "build/web/${NAME}.html" build/web/index.html
touch build/web/.nojekyll
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; rm -f "$ROOT/data/build_info.txt"' EXIT
cp -r build/web/. "$TMP/"
cd "$TMP"
git init -q -b gh-pages
git config user.name "$(git -C "$ROOT" config user.name || echo bayterek-bot)"
git config user.email "$(git -C "$ROOT" config user.email || echo bot@localhost)"
git add -A
git commit -q -m "$MSG ($BUILD_ID)"
REMOTE="$(git -C "$ROOT" remote get-url origin)"
for i in 1 2 3 4; do
  if git push -f "$REMOTE" gh-pages:gh-pages; then echo "BUILD_ID=$BUILD_ID"; exit 0; fi
  sleep $((2 ** i))
done
exit 1
