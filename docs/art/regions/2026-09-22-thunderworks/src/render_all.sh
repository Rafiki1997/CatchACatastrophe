#!/usr/bin/env bash
# Render and finish all five Thunderworks options, their plans, and the
# asset sheets.
#   bash render_all.sh [samples] [res]      (defaults 256, 1.5)
#   ASSETS=0 bash render_all.sh             (skip the asset renders)
# Raw renders and per-option measurements go to ./measurements; finished PNGs
# and the sheets go to the folder above, asset cards to ../assets.
set -euo pipefail
# pwd -W gives C:/... under Git Bash; Python cannot open /c/... paths inside the plan specs
HERE="$(cd "$(dirname "$0")" && (pwd -W 2>/dev/null || pwd))"
OUT="$(dirname "$HERE")"
RAW="$HERE/measurements"
BLENDER="${BLENDER:-C:/Program Files/Blender Foundation/Blender 5.1/blender.exe}"
SAMPLES="${1:-256}"
RES="${2:-1.5}"
mkdir -p "$RAW" "$OUT/assets"
names=("" "TESLA COIL WORKS" "COPPERLINE SUBSTATION" "SPARKLINE SUBSTATION" "STORMCLIFF DYNAMO" "COPPERLINE RAILYARD")
slugs=("" "tesla-coil-works" "copperline-substation" "sparkline-substation" "stormcliff-dynamo" "copperline-railyard")
finals=()
plans=()
cd "$HERE"
for o in 1 2 3 4 5; do
  "$BLENDER" -b --factory-startup -P render_thunderworks.py -- --option "$o" \
    --out "$RAW/option-$o.png" --samples "$SAMPLES" --res "$RES" --stats "$RAW/option-$o.json" \
    | grep -E "RENDERED|Error|Traceback" || true
  f="$OUT/thunderworks-v1-0$o-${slugs[$o]}.png"
  python compose_thunderworks.py "$RAW/option-$o.png" "$f" "0$o" "${names[$o]}"
  finals+=("$f")
  "$BLENDER" -b --factory-startup -P render_thunderworks.py -- --option "$o" --camera top \
    --out "$RAW/plan-$o.png" --samples 96 --res 1.0 | grep -E "RENDERED|Error|Traceback" || true
  plans+=("0$o|${names[$o]}|$RAW/plan-$o.png")
done
python compose_thunderworks.py --sheet "$OUT/thunderworks-v1-overview.png" "${finals[@]}"
python compose_thunderworks.py --plans "$OUT/thunderworks-v1-plans.png" "${plans[@]}"
if [ "${ASSETS:-1}" != "0" ]; then
  "$BLENDER" -b --factory-startup -P render_asset.py -- --out "$RAW/assets" --samples 160 --res 1.0 \
    | grep -E "^ASSET|Error|Traceback" || true
  python compose_assets.py "$RAW/assets" "$OUT/assets"
fi
echo "finished: ${#finals[@]} options + overview + plans in $OUT"
