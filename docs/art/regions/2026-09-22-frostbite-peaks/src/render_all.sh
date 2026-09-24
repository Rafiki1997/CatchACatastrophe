#!/usr/bin/env bash
# Render and finish all five Frostbite Peaks options.
#   bash render_all.sh [samples] [res]      (defaults 256, 1.5)
# Raw renders (deleted after finishing is fine) and per-option measurements go to
# ./measurements; finished PNGs and the overview sheet go to the folder above.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(dirname "$HERE")"
RAW="$HERE/measurements"
BLENDER="${BLENDER:-C:/Program Files/Blender Foundation/Blender 5.1/blender.exe}"
SAMPLES="${1:-256}"
RES="${2:-1.5}"
mkdir -p "$RAW"
names=("" "IGLOO HOLLOW" "ALPINE OUTPOST" "GLACIER FALLS" "CRYSTAL GROTTO" "COLDSNOUT'S CROWN")
slugs=("" "igloo-hollow" "alpine-outpost" "glacier-falls" "crystal-grotto" "coldsnouts-crown")
finals=()
cd "$HERE"
for o in 1 2 3 4 5; do
  "$BLENDER" -b --factory-startup -P render_frostbite.py -- --option "$o" \
    --out "$RAW/option-$o.png" --samples "$SAMPLES" --res "$RES" --stats "$RAW/option-$o.json" \
    | grep -E "RENDERED|Error|Traceback" || true
  f="$OUT/frostbite-peaks-v1-0$o-${slugs[$o]}.png"
  python compose_frostbite.py "$RAW/option-$o.png" "$f" "0$o" "${names[$o]}"
  finals+=("$f")
done
python compose_frostbite.py --sheet "$OUT/frostbite-peaks-v1-overview.png" "${finals[@]}"
echo "finished: ${#finals[@]} options + overview in $OUT"
