# V2 measurement scripts (Claude, 2026-09-22)

How the Alpine Outpost V2 concept was read into region studs. Python 3 with
numpy and Pillow; run from this folder. None of this is Astra's generator.

- `cam.py`, `fit.py`, `fit2.py` - the V1 camera, and why V2 does not fit it
- `homog.py` - ground homography from the four gate-pier bases
- `measure.py` - pixel -> region studs: homography, piecewise wall/pier x map, pier-panel height ruler
- `annot.py`, `convert.py` - the raw pixel readings and their conversion
- `fitcam.py`, `fitcam2.py`, `refcam.py`, `refcam.json` - the fitted comparison camera (11.75 px RMS)
- `layout.py` - the measured layout that `FrostbitePeaks.luau` was written from (sizes in it predate the delivered kit; the Luau and `../../ALPINE-OUTPOST-V2-SITES.csv` are authoritative)
- `overlay_layout.py`, `plan.py`, `crops.py`, `gridv2.py`, `crop.py` - the reference images in the folder above
- `sbs.py`, `zab.py` - side-by-side and zoomed A/B against the concept

Renders of the build come from `tools/render_region_blender.py`; see
`../../ALPINE-OUTPOST-V2-LAYOUT.md` section 10.
