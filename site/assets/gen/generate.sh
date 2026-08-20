#!/usr/bin/env bash
# Asset generation for the Shadow download site.
#
# Everything here is generated rather than sourced, and every prompt is written
# to the same brief so the set reads as one hand: dark grey marble, one warm
# low-angle light, deep black everywhere else, no lettering of any kind (AI
# lettering is always wrong and every panel here sits under real type anyway).
#
# Two things this script learned the hard way:
#
#  1. The response carries BOTH `min_result_url` (a small .webp preview) and
#     `result_url` (the full-resolution PNG), and the preview comes first in the
#     JSON. Grepping for the first URL therefore silently downloads a thumbnail
#     and saves it under a .png name — the file is a RIFF/WEBP with the wrong
#     extension and a quarter of the pixels. Parse the JSON and take
#     `result_url` by name.
#  2. The API drops requests intermittently for no stated reason, so every call
#     retries with a backoff. A failure is not a content refusal.
set -u
OUT="$(cd "$(dirname "$0")" && pwd)"

# Pull result_url out of the response, ignoring the min_result_url preview.
extract_url() {
  node -e '
    let raw = "";
    process.stdin.on("data", d => raw += d);
    process.stdin.on("end", () => {
      const i = raw.indexOf("[");
      const j = raw.lastIndexOf("]");
      if (i < 0 || j < i) return;
      let arr;
      try { arr = JSON.parse(raw.slice(i, j + 1)); } catch (e) { return; }
      for (const job of [].concat(arr)) {
        if (job && job.status === "completed" && job.result_url) {
          process.stdout.write(job.result_url);
          return;
        }
      }
    });
  '
}

gen() {
  local name="$1" aspect="$2" prompt="$3"
  if [ -s "$OUT/$name.png" ] && [ "$(head -c 4 "$OUT/$name.png")" = "$(printf '\x89PNG')" ]; then
    echo "skip  $name (already a real png)"; return 0
  fi
  for attempt in 1 2 3 4 5 6; do
    echo "gen   $name (attempt $attempt)"
    url=$(higgsfield generate create gpt_image_2 \
            --aspect_ratio "$aspect" --quality high \
            --prompt "$prompt" --wait --json 2>/dev/null | extract_url)
    if [ -n "${url:-}" ] && curl -sSfL -o "$OUT/$name.png" "$url"; then
      if [ "$(head -c 4 "$OUT/$name.png")" = "$(printf '\x89PNG')" ]; then
        echo "ok    $name -> $(wc -c < "$OUT/$name.png") bytes"
        return 0
      fi
      echo "      (not a png, retrying)"
    fi
    sleep $(( attempt * 5 ))
  done
  echo "FAIL  $name"
  return 1
}

STYLE="Carved from dark grey Pentelic marble, shallow bas-relief, visible chisel
texture and age. Lit by a single warm amber light low and to the left; every
other surface falls into deep black. No lettering, no text, no numerals, no
signage of any kind. No modern objects. Museum photography against a near-black
background, extreme contrast, fine film grain."

gen "colonnade-far" "16:9" \
"A vast ancient Greek colonnade receding into darkness, photographed head-on
straight down the central aisle. Fluted Doric columns of dark grey marble march
away in perfect symmetry and dissolve into pitch black at the vanishing point.
One warm amber light sits low and far to the left, raking across the stone so it
catches only the left edge of each column as a thin bright rim; everything else
is deep black. Faint volumetric haze between the columns. No people, no text, no
lettering, no signage, no modern objects. About ninety percent of the frame is
near-black. Cinematic anamorphic photography, fine film grain, a wide empty dark
corridor through the centre of the frame."

gen "colonnade-near" "16:9" \
"Two enormous fluted marble columns standing close to camera at the extreme left
and right edges of the frame, cropped by the frame edges, seen in near silhouette.
Between them, nothing but black depth. One warm amber light low to the left picks
out the fluting on the left column only. The centre two thirds of the image is
pure black and completely empty. No people, no text, no lettering, no signage.
Cinematic, extreme contrast, fine film grain."

gen "relief-phrase" "4:3" \
"$STYLE A shallow relief panel showing twelve small blank rectangular tablets
arranged in a neat three-by-four grid, each one plain and unmarked, with a single
carved keystone set above them and faint carved rays descending from the keystone
to touch every tablet."

gen "relief-masks" "4:3" \
"$STYLE A shallow relief panel showing a wall of nine classical theatre masks
hung in rows, each face subtly different from the others, all of them turned very
slightly away from the viewer. One mask at the centre catches the light fully."

gen "relief-slots" "4:3" \
"$STYLE A shallow relief panel showing a wall of small square openings in neat
rows, like an ancient dovecote carved in stone. Most openings are dark and empty.
One opening at the centre is half covered by a carved stone shutter, and a thin
carved curl of vapour rises from it."

gen "relief-threshold" "4:3" \
"$STYLE A shallow relief panel showing a single tall arched doorway in a plain
wall, seen straight on. A carved standing figure in a simple draped chiton stands
beside the arch with one arm held out level across the opening. Long carved
shadows stretch toward the arch from the foreground and stop at the step, not
passing through."

gen "relief-arch" "4:3" \
"$STYLE A shallow relief panel showing one tall narrow arch cut clean through a
marble wall, seen straight on and perfectly centred, its top a smooth half
ellipse. Through the opening there is only warm light and haze, no detail at all.
The wall around the arch is plain and unornamented."

gen "og-card" "16:9" \
"A single crescent-shaped sliver of warm amber light on a pure black field,
positioned slightly left of centre, as if one edge of a marble sphere is catching
a low sun. Faint volumetric haze around it. Vast empty black space to the right.
No text, no lettering, no logo. Cinematic, extreme contrast, fine film grain."

echo "done"
