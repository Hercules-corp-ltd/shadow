#!/usr/bin/env bash
# Turn the generated masters into something a landing page can actually serve.
#
# GPT Image 2 returns 2K PNGs — 4 to 8 MB each. Eight of those is over 40 MB of
# images on a page whose entire job is to load fast enough that somebody stays
# to press a download button, so the PNGs are masters kept out of the deploy and
# the site loads WebP derived from them.
#
# Sizes are chosen per role rather than uniformly: the two colonnade plates are
# full-bleed backdrops behind moving type, so they are downscaled hard and lean
# on the fact that they are mostly black; the relief panels sit at ~50% width
# behind a radial mask; the OG card has a fixed 1200x630 slot.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/../img"
mkdir -p "$OUT"

# name:width:quality
JOBS="
colonnade-far:1920:72
colonnade-near:1920:72
relief-phrase:1280:76
relief-masks:1280:76
relief-slots:1280:76
relief-threshold:1280:76
relief-arch:1280:76
og-card:1200:82
"

total=0
for job in $JOBS; do
  name="${job%%:*}"; rest="${job#*:}"
  width="${rest%%:*}"; quality="${rest##*:}"
  src="$DIR/$name.png"
  dst="$OUT/$name.webp"

  if [ ! -s "$src" ]; then
    echo "miss  $name.png — not generated"
    continue
  fi

  ffmpeg -y -loglevel error -i "$src" \
    -vf "scale=${width}:-2:flags=lanczos" \
    -c:v libwebp -quality "$quality" -compression_level 6 -preset picture \
    "$dst" </dev/null || { echo "FAIL  $name"; continue; }

  bytes=$(wc -c < "$dst")
  total=$(( total + bytes ))
  printf 'ok    %-20s %7s KB  (from %s KB)\n' \
    "$name.webp" "$(( bytes / 1024 ))" "$(( $(wc -c < "$src") / 1024 ))"
done

echo "----"
echo "total shipped image weight: $(( total / 1024 )) KB"
