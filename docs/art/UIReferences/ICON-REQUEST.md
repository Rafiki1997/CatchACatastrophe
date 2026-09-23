# Sidebar icon request (for Astra)

**Reference:** `IconSample.png` in this folder. Match its style exactly: glossy, chunky 3D cartoon
objects with soft highlights, a thick dark outline and saturated candy colours, in a slight 3/4 view,
reading clearly at 60 px.

## Format (every icon)

- Transparent PNG, **512x512**, with the subject filling about 85% of the canvas and centred.
- **No text, letters or numbers** in the image (the game draws the caption).
- No background tile or frame: the game draws the coloured tile behind the icon.
- File name `icon_<panel>.png` (lower case), delivered to `docs/art/UIReferences/icons/`.

## Icons

| File | Panel (caption) | Subject | Main colour (tile colour behind it) |
|---|---|---|---|
| `icon_creatures.png` | Creatures | A friendly round little storm creature with big eyes, peeking out of a glass capture jar | Purple tile (128, 54, 200): creature in teal/yellow |
| `icon_atlas.png` | Atlas | A cartoon globe on a small stand with a red map pin | Teal tile (0, 128, 138): globe blue/green |
| `icon_recipes.png` | Recipes | An open recipe book with a sparkle and a bookmark ribbon | Orange tile (202, 86, 12): book cream/red |
| `icon_workshop.png` | Workshop | A crossed wrench and hammer | Blue tile (42, 84, 204): steel silver, orange handle |
| `icon_supply.png` | Supply | A wooden supply crate with a lid ajar and a coin poking out | Green tile (32, 136, 54): crate warm brown |
| `icon_premium.png` | Premium | A red shopping basket like the sample's "Store" icon, with a gold star | Red tile (200, 36, 54): basket bright red |
| `icon_quests.png` | Quests | A clipboard checklist with a gold star sticker and two green ticks | Pink tile (194, 42, 136): clipboard cream/brown |
| `icon_cities.png` | Cities | Three chunky toy city buildings (one tall, two short) with lit windows | Sky tile (20, 122, 198): buildings warm colours |
| `icon_relaunch.png` | Relaunch | A cartoon rocket lifting off with a puff of smoke | Orange-red tile (210, 60, 34): rocket white/red |
| `icon_settings.png` | Settings | A glossy blue-and-white gear, like the sample's "Setting" icon | Indigo tile (70, 80, 178): gear light blue |

## How they land in the game

1. Upload each PNG to Roblox as a Decal or Image (Studio's Asset Manager, or Open Cloud).
2. Paste each asset id into `src/client/UI/Theme.luau` → `Theme.icons.<Panel>.image = "rbxassetid://<id>"`.
3. Run `lune run tools/verify_theme.luau`; the tile switches from the glyph to the image automatically.
