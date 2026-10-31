#!/usr/bin/env bash
# Builds the CrazyGames upload bundle: build/crazygames/ and
# build/slide-merge-crazygames.zip. See docs/crazygames.md.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/build/crazygames"
ZIP="$ROOT/build/slide-merge-crazygames.zip"
SDK_URL="https://sdk.crazygames.com/crazygames-sdk-v3.js"

rm -rf "$OUT" "$ZIP"
flutter build web --release \
  --base-href / \
  --no-web-resources-cdn \
  --dart-define=CRAZYGAMES=true \
  --output "$OUT"

INDEX="$OUT/index.html"
# CrazyGames serves the bundle from an unknown sub path: use a relative base.
perl -pi -e 's#<base href="/">#<base href="./">#' "$INDEX"
# Portal builds must not link out: drop the Bon-on hub nav bar and the space
# reserved for it (see feature-game-hub-navigation).
perl -0pi -e 's#\s*<nav class="games-nav-bar".*?</nav>##s' "$INDEX"
perl -pi -e 's#--games-nav-height: calc\([^;]*\);#--games-nav-height: 0px;#' "$INDEX"
# The SDK must be loaded before the Flutter loader script (which runs main()).
# This shell boots Flutter from an inline loader instead of flutter_bootstrap.js,
# so the SDK goes right after the game host element that precedes that loader.
perl -pi -e "s#^(\\s*)(<div id=\"game-host\"></div>)#\$1\$2\n\$1<script src=\"$SDK_URL\"></script>#" "$INDEX"

grep -q '<base href="./">' "$INDEX" || { echo "error: relative base href missing" >&2; exit 1; }
sdk_line=$(grep -n -m1 -F "$SDK_URL" "$INDEX" | cut -d: -f1 || true)
boot_line=$(grep -n -m1 -F "hostElement: document.getElementById('game-host')" "$INDEX" | cut -d: -f1 || true)
if [[ -z "$sdk_line" || -z "$boot_line" || "$sdk_line" -ge "$boot_line" ]]; then
  echo "error: SDK script must precede the Flutter loader" >&2
  exit 1
fi
if (( $(grep -c -F "$SDK_URL" "$INDEX") != 1 )); then
  echo "error: SDK script must appear exactly once" >&2
  exit 1
fi

if grep -q -e 'games-nav-bar"' -e 'bon-on.github.io' "$INDEX"; then
  echo "error: hub navigation link still present in index.html" >&2
  exit 1
fi
if ! grep -q -e '--games-nav-height: 0px;' "$INDEX"; then
  echo "error: hub navigation height was not reset" >&2
  exit 1
fi

# Debug symbol files are not needed at runtime.
find "$OUT" -name '*.symbols' -delete

file_count=$(find "$OUT" -type f | wc -l | tr -d ' ')
total_kb=$(du -sk "$OUT" | cut -f1)
if (( file_count > 1500 )); then
  echo "error: $file_count files exceeds the CrazyGames limit of 1500" >&2
  exit 1
fi
if (( total_kb > 50 * 1024 )); then
  echo "error: bundle is ${total_kb}KB, above the 50MB limit" >&2
  exit 1
fi

(cd "$OUT" && zip -qr "$ZIP" .)
echo "CrazyGames bundle: $OUT ($file_count files, ${total_kb}KB)"
echo "Upload zip: $ZIP"
