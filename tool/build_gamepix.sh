#!/usr/bin/env bash
# Builds the GamePix upload bundle: build/gamepix/ and build/slide-merge-gamepix.zip.
# SDK-free: no third-party scripts, no external links, no network access.
# See docs/gamepix.md.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/build/gamepix"
ZIP="$ROOT/build/slide-merge-gamepix.zip"

rm -rf "$OUT" "$ZIP"
flutter build web --release \
  --base-href / \
  --no-web-resources-cdn \
  --dart-define=GAMEPIX=true \
  --output "$OUT"

INDEX="$OUT/index.html"
# GamePix serves the bundle from an unknown sub path: use a relative base.
perl -pi -e 's#<base href="/">#<base href="./">#' "$INDEX"
# Portal builds must not link out: drop the Bon-on hub nav bar and the space
# reserved for it (see feature-game-hub-navigation).
perl -0pi -e 's#\s*<nav class="games-nav-bar".*?</nav>##s' "$INDEX"
# Drop the template's documentation comment (it contains an external URL).
perl -0pi -e 's#\s*<!--\s*If you are serving.*?-->##s' "$INDEX"
perl -pi -e 's#--games-nav-height: calc\([^;]*\);#--games-nav-height: 0px;#' "$INDEX"

grep -q '<base href="./">' "$INDEX" || { echo "error: relative base href missing" >&2; exit 1; }
if grep -q -i -e 'crazygames' -e 'bon-on.github.io' -e 'games-nav-bar"' "$INDEX"; then
  echo "error: portal SDK or hub navigation still present in index.html" >&2
  exit 1
fi
if grep -q -E '<script[^>]+src=' "$INDEX"; then
  echo "error: index.html must not load external scripts" >&2
  exit 1
fi
if grep -q -E '(href|src|action)="(https?:)?//' "$INDEX"; then
  echo "error: index.html links to an outbound URL" >&2
  exit 1
fi
if ! grep -q -e '--games-nav-height: 0px;' "$INDEX"; then
  echo "error: hub navigation height was not reset" >&2
  exit 1
fi
if ! grep -q '"family":"Roboto"' "$OUT/assets/FontManifest.json"; then
  echo "error: Roboto is not bundled (FontManifest.json)" >&2
  exit 1
fi
if grep -rq -i 'crazygames-sdk' "$OUT" --include='*.html' --include='*.js'; then
  echo "error: CrazyGames SDK reference found in the bundle" >&2
  exit 1
fi

# Debug symbol files are not needed at runtime.
find "$OUT" -name '*.symbols' -delete
rm -f "$OUT/.last_build_id"

file_count=$(find "$OUT" -type f | wc -l | tr -d ' ')
total_kb=$(du -sk "$OUT" | cut -f1)

# Zip with files at the archive root (index.html must not be in a sub folder).
(cd "$OUT" && zip -qr "$ZIP" .)
if ! unzip -l "$ZIP" | awk '{print $4}' | grep -qx 'index.html'; then
  echo "error: index.html is not at the zip root" >&2
  exit 1
fi
cg_count=$({ grep -o -i 'crazygames' "$OUT/main.dart.js" || true; } | wc -l | tr -d ' ')
zip_kb=$(du -k "$ZIP" | cut -f1)
echo "GamePix bundle: $OUT ($file_count files, ${total_kb}KB)"
echo "Upload zip: $ZIP (${zip_kb}KB)"
echo "crazygames strings in main.dart.js: $cg_count"
