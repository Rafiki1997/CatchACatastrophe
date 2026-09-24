# Kid-friendly UI restyle — design

**Date:** 2026-09-23 · **Status:** approved (approach A) · **Reference:** `docs/art/UIReferences/IconSample.png`

## Goal

Make the whole client UI read as a bright, colourful kids' game, in the style of the
reference sample: chunky glossy icon tiles, candy colours, thick dark outlines, and white
captions with a heavy black text outline. It must stay readable on phones.

## Decisions (from the brainstorm)

| Question | Decision |
|---|---|
| Icon source | **Astra paints them.** This pass ships icon *slots* with glyph fallbacks, plus an exact request for Astra. |
| Scope | **The whole UI, through `Theme` + `Widgets`.** Every panel, the HUD, the sidebar and dialogs. |
| Panel look | **A candy colour per panel**, with the header and sidebar tile in that panel's colour. |
| Readability | **Approach A: cartoon-outline text.** All text stays light with a thick dark outline, so it reads on any candy colour. Panel bodies are saturated, medium-bright colours, not cream. |

Rejected: cream bodies with dark text (it means re-pairing about 430 colour references across ~20 files), and a
palette-only swap (it produces unreadable dark-on-dark and light-on-light text).

## Constraints

- All colours stay in `src/client/UI/Theme.luau`. Panel files add no `Color3.fromRGB`.
  Today only Theme (25) and Widgets (3) contain any.
- Existing Theme colour keys (`bg`, `bgAlt`, `bgDeep`, `ink`, `text`, `textDim`, `accent`, `accentAlt`,
  `success`, `warn`, `danger`, `gold`, `coin`, `stripe`, `circuit`, `overdrive`, `silhouette`,
  `token`, `steal`) and `Theme.elements` stay defined, so no call site breaks. Only their values change.
- The existing `Widgets` public API (function names, parameters, return types) is unchanged. New behaviour is
  additive: new optional props, new Theme tables, and new functions.
- Light text on candy backgrounds is legal *only* because it carries an outline. Every text-bearing
  widget (`label`, `button`, `iconButton`, `badge`, progress label, tab, tooltip) gets an outline by
  default. A label can opt out with `outline = false`, for example text inside a dark inset.
- Base design resolution stays 1280x720, and `W.attachScale` / `W.safeArea` keep working as today.
- Rojo is the only sync path into Studio. Nothing is published.

## Design

### 1. Theme (`Theme.luau`)

- **New palette values.** `bg` becomes a saturated sky blue (the default panel body), `bgAlt` a darker
  shade of it (cards/rows), and `bgDeep` a deep navy (insets, progress-bar troughs, tooltips).
  `ink` stays near-black and `text` near-white. `textDim` becomes a light pastel (not grey), which still
  reads with an outline. The accent, success, danger and other colours become brighter candy versions.
- **`Theme.panels`**, keyed by panel name → `{ body, header, tile }` Color3s. It covers every name passed to
  `W.panel`: Creatures, Atlas, Recipes, Workshop, Supply, Premium, Quests, Cities, Relaunch, Settings,
  Crisis. `Theme.panels.default` is used for anything unlisted.
- **`Theme.icons`**, keyed by sidebar panel name → `{ image: string, glyph: string }`. `image` is an
  `rbxassetid://` string and stays `""` until Astra's art is uploaded. `glyph` is the fallback shown
  meanwhile.
- **Outline tokens:** `Theme.sizes.textOutline` (px, default text) and `textOutlineLarge` (titles,
  captions, HUD numbers).
- **Fonts:** Fredoka stays for titles and numbers and is also used for button captions. Body text stays Gotham.

### 2. Widgets (`Widgets.luau`)

- **Text outline.** A helper adds a `UIStroke` with `ApplyStrokeMode = Contextual` to text objects
  (not `TextStrokeTransparency`, which is thin). It is applied by default in `label`, `button`, `badge`, the
  progress label, `tabs` and tooltips. `LabelProps.outline: boolean?` (default true) opts out.
  The existing `strokeText` prop maps onto the large outline.
- **Gloss.** A helper adds a `UIGradient` running lighter at the top to darker at the bottom, applied to
  buttons, panel headers and sidebar tiles. Hover and press still recolour through `BaseColor`, and the
  gradient multiplies the new colour.
- **Chunkier chrome.** Stroke thickness goes up, and panels and dialogs gain a drop shadow (an offset dark
  frame behind them).
- **`W.panel`** reads `Theme.panels[name]` (or the default) for the body and header colours. Panel files
  are unchanged.
- **`W.iconTile(parent, panelName, caption, onClick, order)`**, a new sidebar tile. It is a square glossy
  button in `Theme.panels[panelName].tile`, with an `ImageLabel` showing `Theme.icons[panelName].image`
  when set, otherwise the big `glyph`. The caption sits in outlined text overlapping the bottom edge, like
  the sample. `W.iconButton` stays as is.

### 3. HUD (`HUD.luau`)

- **Sidebar.** The vertical text list becomes a 2-column `UIGridLayout` of `W.iconTile`s, about 84 px each,
  inside the existing scrolling frame (the same position below the wallet). Gating through
  `HUD.refreshSidebar` is unchanged. The selected panel's tile gets a white outline and a `W.pop`, where
  today it swaps colour.
- **Wallet, forecast chips and pills** pick up the new palette and outlines through Theme and Widgets.
  There is no layout change beyond what the new sizes need.

### 4. Other UI modules

Notifications, CaptureHUD, CaptureReveal, CreaturePicker, TutorialUI, CollectionPadUI, FloatingText and
CircuitEditorUI all use Theme and Widgets, so they restyle automatically. They are adjusted only where
checking shows a readability or overlap problem. Any fix goes through Theme and Widgets, not local colours.

### 5. Astra icon request

`docs/art/UIReferences/ICON-REQUEST.md` holds one entry per sidebar panel (10). Each entry gives the
subject, main colour, and a one-line art direction. It also covers the shared style (a glossy 3D cartoon
object like the sample, a thick dark outline, a slight 3/4 view, no text in the image), the format
(transparent PNG, 512x512, subject filling about 85%), file names (`icon_<panel>.png`), and how the images
land: an upload to Roblox, then IDs pasted into `Theme.icons`.

## Testing

- **Headless:** `tools/verify_theme.luau` (Lune) loads `Theme.luau` and asserts that
  1. every sidebar panel and every `W.panel` name has a `Theme.panels` entry with all three colours;
  2. every sidebar panel has a `Theme.icons` entry with a non-empty `glyph`, and an `image` that is `""`
     or starts with `rbxassetid://`;
  3. `text` against every panel `body`, `header` and `tile`, and against `bg`, `bgAlt` and `bgDeep`, has a
     WCAG contrast ratio ≥ 3.0, the large-text threshold (the outline carries the rest).
- **Static:** `python tools/luau_lint.py src` and `python tools/quote_scan.py src` stay clean.
- **Build:** the Rojo build succeeds.
- **Studio:** with StudioMCP, `[SelfTest]` and `[LiveTest]` show no new failures against a baseline taken before the change (last recorded: 1002/16 and 63/2).
  Open each of the 11 panels plus the HUD at 1280x720 and at a phone-size viewport. Text is
  readable, nothing is clipped, and the sidebar tiles all fit or scroll.

## Out of scope

Painting the icons (Astra), uploading them to Roblox (the user), animated tiles, new panels or
navigation changes, and world-space billboards (region signs, pad prompts).
