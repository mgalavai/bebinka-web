#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

FRAMER_ORIGIN="${FRAMER_ORIGIN:-https://exciting-support-013821.framer.app}"
SITEMAP_URL="${SITEMAP_URL:-$FRAMER_ORIGIN/sitemap.xml}"

TMP_PATHS="$(mktemp)"
trap 'rm -f "$TMP_PATHS"' EXIT

curl -fsSL "$SITEMAP_URL" \
  | grep -oE '<loc>[^<]+' \
  | sed 's#<loc>##' \
  | sed -E 's#https?://[^/]+##' \
  | awk 'NF' \
  | sort -u > "$TMP_PATHS"

if ! grep -qx '/' "$TMP_PATHS"; then
  echo "/" >> "$TMP_PATHS"
  sort -u "$TMP_PATHS" -o "$TMP_PATHS"
fi

while IFS= read -r route; do
  if [[ "$route" == "/" ]]; then
    output="index.html"
  else
    output="${route#/}/index.html"
  fi

  mkdir -p "$(dirname "$output")"
  curl -fsSL "${FRAMER_ORIGIN}${route}" -o "$output"

  # Normalize internal links to root-absolute paths for stable navigation on GitHub Pages.
  perl -0pi -e 's/href="\.\/"/href="\/"/g; s/href="\.\/([^"]+)"/href="\/$1"/g;' "$output"
done < "$TMP_PATHS"

# Keep a styled 404 page from Framer (can return HTTP 404 by design).
curl -sSL "${FRAMER_ORIGIN}/404" -o 404.html
perl -0pi -e 's/href="\.\/"/href="\/"/g; s/href="\.\/([^"]+)"/href="\/$1"/g;' 404.html

echo "Synced routes:"
cat "$TMP_PATHS"
