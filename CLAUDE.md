# Vento e Vele (Godot) — notes for Claude Code

- **Reply to Enrico in Italian.** All text inside the game stays in English.
- **Do only what Enrico asks.** No extra features, effects or animations he didn't request, even if the prototype
  has them or they seem nice: he decides what goes in. If something extra seems worth it, suggest it in one line
  and wait for his yes.
- Enrico comes from **Unreal Engine**: explain Godot things through their Unreal equivalents (scene ≈ Blueprint/level, node ≈ component/actor, instancing a scene ≈ placing a Blueprint, CanvasLayer + shader ≈ a post-process material, GDScript ≈ Blueprint graph logic, autoload ≈ GameInstance subsystem).
- **Enrico is learning GDScript**: keep code simple and easy to read (plain names, short functions, no clever
  one-liners), comment it generously (what each block does and why, in plain words), and when I add or change code,
  explain it to him step by step in my reply: what each part does, how it connects to the scene, where to change it.
- The remake in Godot 4.7 (Standard, GDScript, Compatibility renderer) of the HTML prototype in
  `EnricoLabarile/Sail---Prototype` (its `index.html` and `CLAUDE.md` describe the game; its `docs/godot-plan.md`
  is the plan: 2D world with a few simple 3D models like the boat, phone held upright, phases 0–10).
- Enrico works in the editor on Windows and commits with GitHub Desktop: if he says he changed something, pull first.
  Commit after every working change, short messages in English, and push to `main`.
- **Every push to `main` builds the web export and publishes it** on https://enricolabarile.github.io/Sail/
  (`.github/workflows/web.yml`, preset "Web" in `export_presets.cfg`, no threads so it runs on Pages; Godot and the
  templates' version in `GODOT_VERSION` must match the editor). That's how Enrico plays it on his Android phone.
- Phone layout: viewport 360×800, stretch `canvas_items` / `expand`, portrait, Nearest texture filter, touch
  emulated from the mouse. Leave a gap at the bottom of the screen for the navigation bar.
- Check a change without the editor: `godot --headless --path . --import` then `--quit-after 30` for script errors.

## Keeping the project folder clean (Enrico's rules)
- **The layout now (Enrico chose it, Oct 2026)**: everything under `Assets/`, by part: `Assets/Boat/` (`boat/boat.tscn`,
  `boat.gd`; `boat_test.tscn`, the test scene), `Assets/Landscape/world/` (the sea), `Assets/Post_Process/dither/`,
  `Assets/UI/` (`helm.tscn`, the wheel), `Assets/Scenes/` (`Overworld.tscn`, the main scene, which `run/main_scene`
  points at by uid; `main.tscn`), plus `Dangers/`, `SFX/` when they get files. Follow this layout for new files; it
  replaces the lower-case `boat/ world/ ui/ shared/` plan below (the other rules still hold, and since the folders now
  have capitals, spell every `res://` path exactly as on disk: the web export is case-sensitive).
- **Autoloads** (project.godot): `PhoneFrame` (`Assets/Scenes/phone_frame.gd`, a phone-shaped frame on wide screens) and
  `Wind` (`Assets/Landscape/world/wind.gd`, the prototype's wind: random start, holds, shifts 30–90° over 3–5 s,
  constant strength (Enrico: only the direction changes); the boat and the wind vane read `Wind.from_deg`).
  `Sfx` (`Assets/SFX/sfx.tscn` + `sfx.gd`, the sounds, see Sound below).
  `Land` (`Assets/Landscape/world/land.gd`): `Land.is_land(pos)` shoots a physics ray straight down (y 100 → -20,
  `intersect_ray`): anything solid hit = land; outside the 504 m map counts as land, so the map's edge is a wall.
- **The landscape: a plain sea plane and 3D coast meshes** (Enrico, Oct 2026; the painted map, its mask and the templates
  in `art_src/map/` are gone). `sea.tscn`: a fixed
  504 × 504 PlaneMesh at the origin, `sea.gdshader`: Enrico's texture `sea_tex` (`sea_tex.png`, 128², a 4 × 4 test flipbook of numbers; set in `sea.tscn`'s material; `sea_color` also
  tints it; nearest, repeating) tiled in world space every `tile_size` 8 m, animated as a flipbook (`frames_x` ×
  `frames_y` cells in one image, `fps`) and/or scrolled (`scroll` m/s), turned to follow the wind (`sea.gd` `_process`: `texture_angle` eases toward `Wind.from_deg` + `texture_turn_deg` 90 with `lerp_angle` over `follow_time` 1 s; Enrico's drawing points right = the way the wind blows, so a wind blowing east (from 270°) leaves it unturned; it turns round the boat, `texture_offset` keeping the water under her still; uniforms `wind_angle`, `wind_offset`): one texture read a pixel, the cheapest (the wavelets are
  gone, Enrico); the boat's stencil. (Import the PNG Lossless, no VRAM compression.) Enrico chose the flipbook. Later (Enrico): a wave on the shore, somehow (not started). Enrico places the coasts as 3D meshes under the `Coast` node in `Overworld.tscn`; each needs
  a collision (a StaticBody3D with a CollisionShape3D: in the editor select the mesh, Mesh menu → Create Trimesh
  Static Body, or name it with the `-col` suffix in Blender), which is what `Land` hits. When her middle or bow (`bow_reach`) would be on land she **bumps** (the prototype's
  `impact()`, in `boat.gd`: `move_and_bounce`, `bump`; knobs `bounce_*`): only moving into the shore at ≥ 0.4 m/s,
  0.6 s cooldown; a push `knock` along `Land.way_to_sea()` of 2 + 0.9 × the hit speed, fading at 3.5/s; speed × 0.25;
  the bow swung off up to 0.3 rad toward the open side. No wobble (Enrico removed it), no damage, sound or buzz yet. In the **shallows** (land within
  `shallows_width` 6 m of her middle, `Land.is_near_land`: 3 rings × 16 rays) the sail's drive is ×
  `shallows_sail` 0.3 (Enrico: less wind by the coast). **The current** (prototype's `CURRENT_DRIFT`): `drift` =
  downwind × `current_speed` 1.8 m/s × `drift_amount` (eases in at the start at `current_ease` 0.8/s), added to her motion; also at
  anchor (the line holds her, see The anchor); pressing her against a shore she just stays (a bump only from her own way). She
  starts at (0, 0, -34), in the sea just north of home.
- **Clouds** (`Assets/Landscape/clouds/`: `clouds.tscn` + `clouds.gd`, instanced as `Clouds` in Overworld): flat image
  planes (PlaneMesh facing up, `StandardMaterial3D` unshaded, alpha from the PNG, both faces, render_priority 2, render layer 2)
  `height` 15 m up; `cloud_count` 12 made at start from `cloud_textures` (in turn; stand-ins `cloud_1..3.png`, soft
  white blobs, to be replaced by Enrico's; imported Lossless, no VRAM compression), random place, size
  `size_min`–`size_max` 20–40 m and turn; every frame moved downwind (`-Wind.from_vector()` × `speed` 2 m/s) and
  wrapped round the 504 m map. Static pictures for now (flipbooks later, maybe). **Shadows** (they darken sea, land and boat alike):
  a **cloud map**, a `SubViewport` (`shadow_resolution` 256², transparent background, redrawn every frame) whose
  orthographic camera looks straight down on the clouds alone (`cull_mask` = `CLOUD_LAYER` 2), `shadow_area` 160 m a
  side, kept over the boat in steps of one map pixel (`follow_boat`, so it doesn't shimmer); and a **screen effect**,
  `cloud_shadow.gdshader` on a QuadMesh stretched over the screen (render_priority 1: after the sea, before the clouds
  and the fog): per pixel the world point from the depth (solid things) or the line of sight down to the water, then
  up toward the "sun" to the clouds' height (`sun_shift` = `shadow_offset` (4, 0, 4) / `height`), the map's alpha there ×
  `shadow_opacity` 0.35 in ink. `shadows_on`. (Decals don't exist in the Compatibility renderer; the scene is unshaded,
  so real light shadows wouldn't show.)
- **Fog of war** (`Fog` autoload, `Assets/Landscape/world/fog.gd`, as the prototype's): the map in cells of `CELL`
  4.8 m (105 a side); a cell is seen for good once her middle comes within `SIGHT` 22 m of it (`Fog.reveal`, called
  by `boat.gd` every physics frame). Kept in `Fog.image` (L8, 1 px a cell, white = fog), sent to `Fog.texture` only
  when a cell changes. Drawn as a **screen effect** (Enrico: it must cover 3D objects too):
  `Assets/Landscape/world/fog.gdshader` on a QuadMesh that `sea.gd` makes at start (child of Sea, huge
  `extra_cull_margin`, render_priority 3, after the sea, the outline, the cloud shadows and the clouds), stretched over the screen in the vertex
  shader; per pixel it follows the line of sight (two points unprojected with `INV_PROJECTION_MATRIX` /
  `INV_VIEW_MATRIX`) down to the water (y 0) and reads `fog_tex` there (linear: soft edge), painting `fog_color`
  black with that alpha; `falloff` (metres, `sea.gd` `fog_falloff`, 0 = as it comes, about a cell) averages 8 more
  reads on a ring that far round, for a wider, softer edge. Tall objects are fogged as the water just behind them. The boat is drawn under it but she's
  always in seen water. Made in code, so the editor shows the whole map. Nothing is always clear yet.
- **The boat's hierarchy** (Enrico's, Oct 2026): `Boat / Model / sm_boat_hull / sm_boat_mast / Rig / sm_boat_sail`
  (+ `Boat/Camera3D`). `Model` heels, bobs and rocks (`rock_and_roll`, the prototype's damped springs: roll pulled toward heel + lean out of a turn + the waves' roll, pitch toward the surge + the waves' pitch, `roll_stiffness` 16 / `roll_damping` 3.2, `pitch_stiffness` 22 / `pitch_damping` 4.5, clamped ±0.6 / ±0.3 rad; the lean out of a turn is the measured `turn_speed` / `turn_rate` × speed / `top_speed` × `turn_lean_deg` 22°; the surge is acceleration × `surge_pitch_deg` 3°/(m/s²), at most `surge_pitch_max_deg` 4.5°; the waves `wave_roll_deg` 3°, `wave_pitch_deg` 2°, `wave_period` 3 s and 0.8× that; everything follows), `Rig` (at the mast's foot) turns the
  boom to leeward (half the wind's angle off the bow, 8° to `boom_max_deg` 30° either side: never across her), the sail's shape keys `Inflated_Right` / `Inflated_Left` make its belly. `boat.gd` finds `Rig` and
  `sm_boat_sail` with `find_child` (by name, anywhere inside), so the hierarchy can change as long as the names stay.
- **Fake light** (no lights in the scene, Enrico removed the `Sun`): the boat's materials are unshaded and shade
  themselves, `Assets/Boat/fake_light.gdshaderinc` (a shared include, like a Material Function): `fake_light(NORMAL,
  INV_VIEW_MATRIX)` = `ambient` (0.45) + (1 − ambient) × max(0, N·sun) in world space. The sun is the **global shader
  parameter `sun_direction`** (Project Settings > Shader Globals, like a Material Parameter Collection; default
  (-0.25, 0.94, -0.25)), set by `clouds.gd` `set_sun_direction()` from `shadow_offset` / `height`, so the boat is lit
  from where the clouds' shadows come (north-west, high). `toon_shade.gdshader` (`base_color` × the light) is used by
  `m_hull.tres` (hooked to `sm_boat_hull.fbx`'s `boat_hull` material in its import, `use_external`) and `m_mast.tres`;
  `Sail.gdshader` uses the same light, its normal turned round on the back face (`FRONT_FACING`).
- **She sits in the water; only her inside is never cut** (a stencil): `boat.gd` `add_water_mask()` puts
  `Assets/Boat/boat_mask.gdshader` (invisible, `stencil_mode write, compare_always, 1`, render_priority -1) as
  `material_overlay` only on meshes inside `Model` with `inner` in their name or their parent's (Enrico: the hull's
  inside as its own object, `sm_boat_hull_inner`); `sea.gdshader` reads it (`stencil_mode read, compare_not_equal, 1`)
  and writes `ALPHA = 1.0`, which puts it in the transparent pass, drawn after the boat: it skips those pixels, so the
  floor of the boat (below y 0) shows. The outside of the hull, mast and sail have no mask: the sea covers what's
  below the water. Until the inner mesh exists, nothing is masked (the sea shows over her floor). How deep she sits
  is `Model`'s y in `boat.tscn` (Enrico places it; −0.4 now): `boat.gd` reads it at start (`model_height`) and bobs round it.
- **Wake and bow spray** (as the prototype's wake dots and `bowSpray`): two `CPUParticles3D` children of `Boat` in
  `boat.tscn` (`Wake`, `BowSpray`; their look is set in the Inspector), `local_coords` off so what they leave stays on
  the water, flat 8-sided discs (a CylinderMesh with no height), unshaded, vertex colour + alpha, render_priority 1.
  `Wake`: at the stern (z +1.7), two points ±0.55 m pushed outward 1.2 m/s, 28 dots, life 1.2 s (short), ink, alpha
  0.8 → 0, growing 0.28 → 0.9 m. `BowSpray`: points along both sides of the bow, flung outward 1–3 m/s, 30 bits, life
  0.45 s ± half, white, fading in the second half, growing. `boat.gd` `update_water_fx()`: on only above 6% of
  `top_speed` and not at anchor; `speed_scale` = her share of top speed (at least 0.35), so slower = fewer dots, still
  the same distance apart (CPUParticles3D has no `amount_ratio`).
- **The outline** (`Assets/Boat/boat_outline.gdshader`, made by `boat.gd` `add_outline()`: a QuadMesh child of the
  camera, stretched over the screen in the vertex shader, render_priority 1, after the sea): reads the depth buffer
  (`hint_depth_texture`; only the solid things are in it, i.e. the boat, since the sea is in the transparent pass;
  0.0 = nothing), and paints ink on pixels with no boat but boat within `outline_width` (boat.gd export, 1.5 phone
  points) in 8 directions; boat pixels below `water_level` (0) don't count (their height is worked out from the depth
  with `INV_PROJECTION_MATRIX` / `INV_VIEW_MATRIX`), so the line follows the water line, not the hidden hull. Made in code so it doesn't cover the editor's view. Any future solid 3D object gets it too.
- **The camera** (`Boat/Camera3D`, orthographic, `size` 40, `far` 200): placed by `boat.gd` `_process` from the south,
  tilted `camera_tilt_deg` 45, `camera_distance` 100 m back along the way it looks (in ortho the distance doesn't
  change the picture; at 40 the clouds low on the screen fell behind the near plane and were cut).
- **Sound** (`Sfx` autoload, `Assets/SFX/`): `.ogg` files made from the prototype's own Web Audio code by
  `art_src/audio/bake.py` (Playwright opens `bake.html`, which holds the prototype's `colouredNoise`, `chainLink` and
  `anchor` verbatim and its `ambient()` written out as a timeline, renders each sound in an `OfflineAudioContext`;
  loops are 48 s with the extra second cross-faded onto the start; one gain for all keeps the prototype's balance;
  ffmpeg → Vorbis; `CHROMIUM=/opt/pw-browsers/chromium python art_src/audio/bake.py`). `sea.ogg` (two swells of
  brown noise panned apart, always on), `wind.ogg` (new, the prototype had none: pink noise ~600 Hz in slow gusts,
  always on), `rush.ogg` (water along the hull: loudness × (speed/top_speed)^1.5, pitch 0.55..1), `anchor_down.ogg`
  / `anchor_up.ogg` (`Sfx.anchor(down)`, called by `boat.gd` `toggle_anchor`). The players are nodes in `sfx.tscn`
  (their Volume dB = the level; the loops fade in over `fade_in_time` 2 s); nothing plays while the game is paused.
  (Headless `--quit-after` prints "resources still in use at exit" for the playing loops: harmless.)
- **The dither** (`Assets/Post_Process/dither/`: `dither.tscn`, a CanvasLayer 100 with a ColorRect, `dither.gdshader`):
  Bayer 4×4 to paper/ink, one dot per pixel of the game view (below; the shader still works out a scale from its
  screen, which is 1 there).
- **The game view** (`Assets/Post_Process/game_view.gd`, node `GameView` in Overworld; Enrico asked for performance):
  at start (deferred, after every node is ready) it moves `Sea`, `Coast`, `Clouds`, `Boat`, `Dither`, `Helm` and the
  logbook's `IconLayer` into a `SubViewport` drawn at the game's resolution, and shows its picture on a full-screen
  `TextureRect` (CanvasLayer 1, nearest filter: sharp dots). Size: real pixels of the game area
  (`get_visible_rect().size × get_final_transform().get_scale()`) / `dot_scale`, `dot_scale` = round(real width /
  360), ≥ 1 (phone 1080 wide → 360×655, ×3; the PC's 360×800 window → ×1; a wide PC screen in the phone frame
  405×900 → ×1). So the world, the shadows, the dither and the wheel are drawn ~9× smaller on the phone; what stays
  crisp at full resolution on top: the wind vane (110), the open book (120), the start screen (130). Taps and drags
  on the picture are passed into the view (`_pass_input`: `push_input`, scaled to its pixels). In the editor the
  scene looks as always. (Before: the 3D at 1/3 with `scaling_3d_scale`, the dither at full resolution; `dither.gd`
  is gone.) The 3D world is shared (the SubViewport uses the root's World3D: `Land`'s rays still work).
- **Turning** (as the prototype): `turn_rate` 2.25 rad/s (Enrico: between the old 1.5 and the doubled 3) at full rudder whatever her speed (no slower with less way);
  none at anchor. (Paddle wheels and the crank were added, then removed for now by Enrico.)
- **The anchor** (as the prototype's `anchorPt`, `ANCHOR_RODE`): dropped, it lies off her bow (`anchor_point`,
  `bow_point()` = middle + `bow_reach` forward) and stays there; the current now carries her at anchor too; once the
  bow is `anchor_rode` 3 m from it, `hold_at_anchor` holds the bow there and the hull trails from it, so she swings
  round it, bow to the anchor (carried > 4 × the rode off, it drags and bites again). At anchor the sail is gathered
  onto the boom (`update_furl`: `sm_boat_sail` scale.y → `furled_height` 0.06 at `furl_rate` 2.2, spread again at
  `unfurl_rate` 3.5). No line drawn yet.
- **The wheel** (`Assets/UI/helm.gd`, `helm.tscn`: CanvasLayer 95, under the dither, 221 × 242 px, 30 px off the
  bottom), as the prototype's `drawWheel`: drawn in greys in its units (×`WHEEL_SCALE` 1.3): a dark backing, eight
  turned spokes and handles (king spoke whipped), rim with grain and brass caps, the boss; over it the big hub
  (×2: brass bezel lit top left, four rivets, light face with an ink anchor sailing, dark face with a paper anchor
  and a light rim at anchor), **drawn once into pictures** (`_make_picture`: a SubViewport with a painter Control,
  rendered `UPDATE_ONCE`, again only on resize): the wheel at angle 0 (drawn every frame turned by `wheel_angle`, linear
  filter), the hub sailing and the hub at anchor; only the rim's fixed shade, the hub's shake and its hold ring are
  drawn live (draw calls ~290 → ~45: the wheel's discs of 40 triangles each were most of them). Drag to steer (half a turn = full rudder, springs back to the middle); the hub's grip is
  16.5 sailing / 21 at anchor (× 2.6): held `hub_hold` 0.33 s (a ring fills) it works the anchor and shakes; a finger
  moving 9 off the hub turns the wheel instead; at anchor the wheel doesn't steer (drag and arrow keys). No sound or
  buzz yet.
- **The logbook** (`Assets/UI/logbook/`: `logbook.tscn` + `logbook.gd`, `book_icon.gd`, `book.gd`; in Overworld): as the
  prototype's. The button bottom left (76 px, drawn in greys on a CanvasLayer under the dither, 95, so it's 1-bit) emits
  `pressed`; `logbook.gd` tweens `drop` (the shut book comes down, 0.26 s) then `book.unfold` (the cover swings open on
  the spine while the book re-centres, 0.33 s), the reverse to close. `book.gd` (CanvasLayer 120, crisp) draws the
  leather (a 15 px tile of dots), stitching, metal corners, the pages with the edges beneath, and only spread 0 for
  now (Enrico): the 9×9 map A1..I9 across both pages (the prototype's 100-unit layout), the square she's in shaded
  (ink 0.3; no dot any more, Enrico); a tiny faint frame-rate counter in the right page's bottom right corner, over it
  the game view's size and dot scale, then fps, ms a frame and draw calls ("360x655  x3" / "60 fps  16.7 ms  45 dc"): a `Label` child of the book
  (`_make_fps_label`), filled every frame by `_process` while the book is fully open (Enrico), hidden otherwise.
  **The book itself is not redrawn every frame** (Enrico): `logbook.gd` calls `book.refresh()` on opening, which reads
  the square once; after that it's drawn again only while the cover turns (`unfold`'s setter).
- **The start screen** (`Assets/UI/start_screen.tscn` + `.gd`, CanvasLayer 130, in Overworld): a card with the title, "Build
  N" and the build's start time, and "Set sail"; the game is paused until it's pressed. The numbers come from
  `Assets/UI/build_info.gd` ("local" in the repo); `web.yml` rewrites it before exporting with `github.run_number`
  and the time (Europe/Rome). Only identification for now (Enrico): no settings or knobs on it.
- **Folders by feature, not by file type**: each part of the game keeps its scene, script, model and textures together.
  ```
  res://
  ├─ boat/      boat.tscn, boat.gd, boat.glb, the boat's textures
  ├─ world/     overworld.tscn, the sea, the land, the islands
  ├─ ui/        HUD, logbook, wheel, crank
  ├─ shared/    things used by several parts: the 1-bit shader, fonts, themes
  ├─ audio/     sounds and music
  └─ sandbox/   test scenes and experiments
  ```
  The root holds only project files: `project.godot`, `icon.svg`, `export_presets.cfg`, `CLAUDE.md`, `.github/`,
  `.gitignore`, `.gitattributes`. Nothing else goes there.
- **Files and folders: lower case, words joined by `_`** (`overworld.tscn`, `boat_sail.png`), no spaces, no capitals.
  Windows doesn't tell `Boat` from `boat` but the web export does, so a name spelt two ways works on the PC and breaks
  online. **Nodes** inside scenes are PascalCase (`Boat`, `MainCamera`), as Godot does.
- **A script has its scene's name and sits next to it**: `boat.tscn` → `boat.gd`.
- **Art sources (.blend, .kra, .psd) stay out of the game folders**; only exports (.glb, .png) go in. If kept in the
  repo, they go in `art_src/` with a `.gdignore` inside, so Godot doesn't import them.
- **Move and rename only from Godot's FileSystem dock**, never from Explorer: Godot updates the references in the
  scenes. (When I move files in the repo, I also fix every `res://` path and keep the `uid` in place, and Enrico must
  have pulled and closed the editor first.)
- Git doesn't keep empty folders: a new folder shows up on GitHub only once a file is in it (or a `.gitkeep`).
