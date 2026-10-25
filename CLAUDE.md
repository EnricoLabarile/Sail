# Vento e Vele (Godot) — notes for Claude Code

- **Reply to Enrico in Italian.** All text inside the game stays in English.
- **Do only what Enrico asks.** No extra features, effects or animations he didn't request, even if the prototype
  has them or they seem nice: he decides what goes in. If something extra seems worth it, suggest it in one line
  and wait for his yes.
- **No camera-facing (billboard) shaders or nodes** (Enrico's rule, Oct 2026): pictures in the world are plain
  planes/quads that keep the node's own rotation; Enrico decides himself whether and how to tilt an element to the
  camera's angle. (Already made before the rule: `stone.gdshader`, used by the bomb and the fireball, and
  `sea_imp.gdshader`; the map marker's billboard is editor-only.)
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

## Game design rules (Enrico's; keep every change in line with them)
1. The game is about sailing a boat in a tiny world.
2. The player talks to NPCs; they ask favours and hint at places that can benefit the player.
3. The player is only ever on the boat: there is no walking around.
4. The map is a tool the player needs to use to find the way.
5. Keep the number of new tools the player must learn to the minimum.
6. Fun, engaging traversal is the core of the game: flowing movement, all about keeping momentum (like The Pathless).

## The story so far (Enrico's synopsis, Oct 2026: a frame for choices; parts may go)
You are a **monster hunter**. Reach the town (one of the islands) and gather information. A **smith** offers a boat
upgrade (a metal reinforcement with a **ram**), dear. He offers work for a friend of his: he marks the friend's place on
the map and asks you to deliver a **parcel**, paying a little for the trouble. On the way you can fish and, off the
beaten track, find treasure; the area is still fenced in (several routes to the goal, not the whole world yet). The boat
has **no weapons** yet; weak enemies on the way leave you alone, eventually. The friend thanks you, invites you to dinner
and gives you a **trap** (in the inventory; selected, it's laid the next time you drop anchor; a monster that enters its
area is caught; sailing over it puts the monster in the hold, to sell or bring to a goal). He asks you to **catch a
monster** that plagues the area: it can't be beaten, only lured into the trap; bringing it back pays well, a little less
than the upgrade costs, so the player explores for fishing spots. Meanwhile townsfolk hint where the **kraken** is, the
terror of the local seas: met before the upgrade it can't be beaten. It shows as pieces breaking the water (head,
tentacles): dodge the lashing tentacles, place traps tactically to hurt it and make it vulnerable, then ram it at full
speed. (Alternative to ram and traps: a **bomb**, dropped (now off the bow) with its own button, timed to blow up on the enemy.)
For now (Enrico): bombs AND traps both in, to see which plays better; **the slingshot is gone**.

## Keeping the project folder clean (Enrico's rules)
- **The layout now (Enrico chose it, Oct 2026)**: everything under `Assets/`, by part: `Assets/Boat/` (`boat/boat.tscn`,
  `boat.gd`; `boat_test.tscn`, the test scene), `Assets/Landscape/world/` (the sea), `Assets/Post_Process/dither/`,
  `Assets/UI/` (`helm.tscn`, the wheel), `Assets/Scenes/` (`Overworld.tscn`, the main scene, which `run/main_scene`
  points at by uid; `main.tscn`), plus `Dangers/`, `SFX/` when they get files. Follow this layout for new files; it
  replaces the lower-case `boat/ world/ ui/ shared/` plan below (the other rules still hold, and since the folders now
  have capitals, spell every `res://` path exactly as on disk: the web export is case-sensitive).
- **Autoloads** (project.godot): `PhoneFrame` (`Assets/Scenes/phone_frame.gd`, a phone-shaped frame on wide screens) and
  `Wind` (`Assets/Landscape/world/wind.gd`, the prototype's wind, but on **8 fixed directions** (Enrico: N, NE, E, SE, S, SW, W, NW, `DIRECTIONS` 8): a random one at the start, holds, then shifts 1–2 steps (`SHIFT_STEPS`, 45° or 90°) left or right, smoothly over 3–5 s, landing exactly on a direction,
  constant strength (Enrico: only the direction changes); the boat and the wind vane read `Wind.from_deg`). **The current
  lives here too** (Enrico: a force on many things): `CURRENT_SPEED` 1.5 m/s, `Wind.current()` = downwind × it, read
  by the boat (eased in with her `drift_amount`), a burning bomb and a dead imp.
  `Sfx` (`Assets/SFX/sfx.tscn` + `sfx.gd`, the sounds, see Sound below). `Inventory` (`Assets/Inventory/inventory.gd`, the hold, see The inventory).
  `Land` (`Assets/Landscape/world/land.gd`): `Land.is_land(pos)` shoots a physics ray straight down (y 100 → -20,
  `intersect_ray`): anything solid hit = land; outside the map counts as land, so the map's edge is a wall. **`Land.WORLD_SIZE`** (1008 m a side; Enrico doubled it from 504,
  the prototype's 5040 px) is the one number for the world's size: `fog.gd`, `clouds.gd`, `book.gd` and `sea.gd` (the
  fog shader's `world_size`) read it; only the sea plane's size in `sea.tscn` must be set to match by hand. The
  logbook's 9×9 squares now cover 112 m each.
- **The landscape: a plain sea plane and 3D coast meshes** (Enrico, Oct 2026; the painted map, its mask and the templates
  in `art_src/map/` are gone). `sea.tscn`: a fixed
  1008 × 1008 PlaneMesh at the origin, `sea.gdshader`: Enrico's texture `sea_tex` (`sea_tex.png`, 128², a 4 × 4 test flipbook of numbers; set in `sea.tscn`'s material; `sea_color` also
  tints it; nearest, repeating) tiled in world space every `tile_size` 8 m, animated as a flipbook (`frames_x` ×
  `frames_y` cells in one image, `fps`) and/or scrolled (`scroll` m/s), turned to follow the wind (`sea.gd` `_process`: `texture_angle` eases toward `Wind.from_deg` + `texture_turn_deg` 90 with `lerp_angle` over `follow_time` 1 s; Enrico's drawing points right = the way the wind blows, so a wind blowing east (from 270°) leaves it unturned; it turns round the boat, `texture_offset` keeping the water under her still; uniforms `wind_angle`, `wind_offset`): one texture read a pixel, the cheapest (the wavelets are
  gone, Enrico); the boat's stencil. (Import the PNG Lossless, no VRAM compression.) Enrico chose the flipbook. **Shore waves** (Enrico, distance field): `sea.gdshader` `shore_foam()` reads `shore_tex`
  (`Assets/Landscape/shore/shore_distance.png`, 1008², L8, imported lossless with `detect_3d/compress_to=0`: black = on
  the coast, white = `shore_max_distance` 32 m or more; set in `sea.tscn`), and within `shore_width` 10 m of a coast draws
  lines of foam every `wave_spacing` 3.5 m rolling in at `wave_speed` 1.2 m/s, `wave_line` 0.5 m thick near the shore and
  thinner out, `wave_wobble` 1 m of value noise, plus steady foam `foam_width` 0.8 m along the coast; `shore_color` white
  at `shore_opacity` 0.9 (one texture read a pixel). **Baked in the editor** by `ShoreBaker` (a Node3D in Overworld,
  `Assets/Landscape/shore/shore_baker.gd`, `@tool`, `@export_tool_button` "Bake shore"; ~1 s): every MeshInstance3D
  under `land_roots` (`../Islands`, `../Coast`) copied white into an own World3D, an orthographic camera 200 m up
  looking down with its far plane at the sea's level (only what's above the water), the alpha = land; a two-sweep
  chamfer distance (1 / 1.41) in pixels × `metres_per_pixel` 1; saved as the PNG (`MAX_DISTANCE` 32 must match the
  shader's `shore_max_distance`). **Bake again after changing the coasts.** Enrico places the coasts as 3D meshes under the `Coast` node in `Overworld.tscn`; each needs
  a collision (a StaticBody3D with a CollisionShape3D: in the editor select the mesh, Mesh menu → Create Trimesh
  Static Body, or name it with the `-col` suffix in Blender), which is what `Land` hits. When her middle or bow (`bow_reach`) would be on land she **bumps** (the prototype's
  `impact()`, in `boat.gd`: `move_and_bounce`, `bump`; knobs `bounce_*`): only moving into the shore at ≥ 0.4 m/s,
  0.6 s cooldown; a push `knock` along `Land.way_to_sea()` of 2 + 0.9 × the hit speed, fading at 3.5/s; speed × 0.25;
  the bow swung off up to 0.3 rad toward the open side; the hull loses `hit_damage` (half a heart, see Health). No wobble (Enrico removed it), no sound or buzz yet. In the **shallows** (land within
  `shallows_width` 6 m of her middle, `Land.is_near_land`: 3 rings × 16 rays, looked again only every `shallows_check_time`
  0.2 s, `in_shallows`) the sail's drive is ×
  `shallows_sail` 0.3 (Enrico: less wind by the coast). **The current** (prototype's `CURRENT_DRIFT`): `drift` =
  `Wind.current()` (downwind × `Wind.CURRENT_SPEED` 1.5 m/s) × `drift_amount` (eases in at the start at `current_ease` 0.8/s), added to her motion; also at
  anchor (the line holds her, see The anchor); pressing her against a shore she just stays (a bump only from her own way). She
  starts at (0, 0, -34), in the sea just north of home.
- **The grid on the sea** (Enrico, as the prototype's room seams `drawRoomSeams`): `sea.gdshader`'s `seam()`
  draws dashed lines along the borders between the logbook's 9 × 9 squares, every `cell_size` (Land.WORLD_SIZE / 9 =
  112 m, sent by `sea.gd` with `world_size`) from the map's edge: `seam_width` 0.3 m, `seam_dash` 0.6 / `seam_gap`
  0.9 m, mixed in at `seam_opacity` 0.8 of `seam_color` white (ink, as the prototype's, hardly showed on this darker
  sea). No extra draw call: it's in the sea's own shader (so it's under the islands, the boat and the fog).
- **Islands** (Enrico: 2D drawings, not 3D models; `Assets/Landscape/islands/`: `island.tscn` + `island.gd` (`@tool`),
  `island.gdshader`, `island_test.png`; instanced under `Coast`, for now one `TestIsland` at (6, 0, −80), north of the
  start): the island drawn slightly from the side (3/4 view: the front shore along the bottom edge, hills rising up
  the picture, see-through round it) on a QuadMesh `Card` that faces the camera (leaned back by 90° − `camera_tilt_deg`
  45, so it shows on screen as drawn), its bottom edge on the water at the node's place (`center_offset`); size =
  the picture's pixels / `pixels_per_metre` 9 (= the game's 9 px a metre, so a texture pixel is a screen pixel).
  The shader is unshaded, nearest, alpha-scissored at `alpha_cut` 0.5 (a solid pixel or nothing): the solid pixels
  write depth, so the boat behind the island is hidden by it (anything north of its front edge is behind the whole
  card) and the ink outline (`boat_outline.gdshader`, from the depth) is drawn round it at no extra cost. Collision:
  only the footprint, `Body/Footprint` (a CollisionPolygon3D lying flat, rotated −90° on x so its local +y is north,
  `depth` 4 round the water line), which Enrico shapes in the editor, smaller than the drawing so the peaks aren't
  solid (`Land` hits it). A point h m up the picture is h / cos(tilt) (1.41 h) m north on the water. `island_test.png`
  (270 × 200, 30 × 22 m) is a stand-in. Known: the fog is worked out on the water behind tall things, so a hill's
  top can stay fogged a little longer than its shore.
- **Land drawings' material** (`Assets/Landscape/land/`, Enrico's faraglioni: `faraglione_01_a.tscn` + `.png`):
  `land_unlit.gdshader` (unshaded, both faces, `picture` nearest, alpha-scissored at `alpha_cut` 0.5, `tint`),
  used by `island_master.tres` (a ShaderMaterial now, same uid; a StandardMaterial3D came out black: there are no
  lights). **No ink outline** (Enrico): it doesn't write depth (`depth_draw_never`) and sets `ALPHA = 1.0`, so it's
  drawn with the see-through things after the boat (material render_priority 2: after the sea, wake and wind lines,
  before the fog); its depth test still keeps the boat in front of it in front and hides her behind it. The PNG
  imported Lossless. (Enrico removed `island.gdshader` and `island_test.png`: `island.tscn` still points at them.)
- **Clouds** (`Assets/Landscape/clouds/`: `clouds.tscn` + `clouds.gd`, instanced as `Clouds` in Overworld): flat image
  planes (PlaneMesh facing up, `StandardMaterial3D` unshaded, alpha from the PNG, both faces, render_priority 4: drawn over the fog of war (Enrico), render layer 2)
  `height` 35 m up (Enrico); `cloud_count` 256 made at start (64 on the half-size map: same density) from `cloud_textures` (in turn; stand-ins `cloud_1..3.png`, soft
  white blobs, to be replaced by Enrico's; imported Lossless, no VRAM compression), random place, size
  `size_min`–`size_max` 30–50 m and turn; every frame moved downwind (`-Wind.from_vector()` × `speed` 2 m/s) and
  wrapped round the map. Static pictures for now (flipbooks later, maybe). **Shadows** (they darken sea, land and boat alike):
  a **cloud map**, a `SubViewport` (`shadow_resolution` 256², transparent background, drawn again `shadow_updates_per_second`
  10 times a second with `UPDATE_ONCE`, the camera moved over the boat at the same moment: not every frame) whose
  orthographic camera looks straight down on the clouds alone (`cull_mask` = `CLOUD_LAYER` 2), `shadow_area` 160 m a
  side, kept over the boat in steps of one map pixel (`follow_boat`, so it doesn't shimmer); and a **screen effect**,
  `cloud_shadow.gdshader` on a QuadMesh stretched over the screen (render_priority 1: after the sea, before the fog
  and the clouds): per pixel the world point from the depth (solid things) or the line of sight down to the water, then
  up toward the "sun" to the clouds' height (`sun_shift` = `shadow_offset` (4, 0, 4) / `height`), the map's alpha there ×
  `shadow_opacity` 0.35 in ink. `shadows_on`. (Decals don't exist in the Compatibility renderer; the scene is unshaded,
  so real light shadows wouldn't show.)
- **Wind lines** (`Assets/Landscape/wind_lines/`: `wind_lines.tscn` + `wind_lines.gd`, `wind_line.gdshader`; node
  `WindLines` in Overworld, moved into the game view like the others; as the prototype's wind streaks): a pool of
  `line_count` 8 flat rectangles (PlaneMesh `line_length` 6 m × 0.8, each its own ShaderMaterial, render_priority 1)
  used again and again. About `lines_per_second` 0.6 appear, `spawn_radius_min`–`spawn_radius` 4–25 m from the boat,
  0.05 m above the water, laid along the wind (`-Wind.from_vector()`, ±0.15 rad) and drifting with it at `drift_speed`
  1.5 m/s; each lasts `line_life` 2.2 s. The shader draws a wavy ink line (`line_width` 0.22 m, about two dots;
  `line_alpha` 1, since under 1 the dither breaks it up; a bend of 0.15–0.3 m every 8–12 m plus a slight moving
  ripple, `seed` per line): with `progress` 0→1 the head runs out downwind, then the tail catches up, with a quick
  fade at both ends.
- **Gulls** (`Assets/Landscape/gulls/`: `gulls.tscn` + `gulls.gd`, `gull.gdshader`, `gull.png`; node `Gulls` in
  Overworld, moved into the game view; the prototype's behaviour, Enrico, but flat planes with a flipbook): the
  first flock after `first_flock_after` 6–10 s, then every `flock_every` 15–22 s, 1–3 gulls in a loose V (each
  2.2–3.4 m further back and 1.2–2 m × its place out to one side then the other) start `spawn_distance` 70 m upwind
  of the boat (±15 m to the side), `height` 12 m up, and fly roughly downwind (−`Wind.from_vector()` ±0.7 rad) at
  `speed` 7.2–9.5 m/s (each ×0.95–1.05), weaving `weave` 0.6 m/s side to side (cos, 0.9 rad/s), until they've flown
  2 × `spawn_distance` + 20 m (then freed). Each is a PlaneMesh `gull_size` 2.2 m lying level, turned so the
  picture's top (the head) points the way it flies, with its own ShaderMaterial (render_priority 2): a 4 × 4
  flipbook looped at `fps` 12 from its own random frame (`phase`); `gull.png` is a stand-in (frames 64 × 64, head to
  the top) for Enrico to redraw. No sound (Enrico: only the anchor and the wheel). On the clouds' render layer (2),
  so the clouds' shadow map sees them and they cast a shadow like the clouds (refreshed 10 times a second; it falls
  as if they were at the clouds' height, and thin strokes vanish in the map's 0.6 m pixels).
- **Fog of war** (`Fog` autoload, `Assets/Landscape/world/fog.gd`, as the prototype's): the map in cells of `CELL`
  4.8 m (210 a side); a cell is seen for good once her middle comes within `SIGHT` 22 m of it (`Fog.reveal`, called
  by `boat.gd` every physics frame; it does its sums only once she has moved 1 m since the last time, `last_pos`). Kept in `Fog.image` (L8, 1 px a cell, white = fog), sent to `Fog.texture` only
  when a cell changes. Drawn as a **screen effect** (Enrico: it must cover 3D objects too):
  `Assets/Landscape/world/fog.gdshader` on a QuadMesh that `sea.gd` makes at start (child of Sea, huge
  `extra_cull_margin`, render_priority 3, after the sea, the outline, the cloud shadows, gulls and stones; the clouds (4) come after it, over it), stretched over the screen in the vertex
  shader; per pixel it follows the line of sight (two points unprojected with `INV_PROJECTION_MATRIX` /
  `INV_VIEW_MATRIX`) down to the water (y 0) and reads `fog_tex` there (linear: soft edge), painting `fog_color`
  black with that alpha; `falloff` (metres, `sea.gd` `fog_falloff`, 0 = as it comes, about a cell) averages 8 more
  reads on a ring that far round, for a wider, softer edge. Tall objects are fogged as the water just behind them. The boat is drawn under it but she's
  always in seen water. Made in code, so the editor shows the whole map. Nothing is always clear yet.
- **The boat's hierarchy** (Enrico's, Oct 2026): `Boat / Model / sm_boat_hull / sm_boat_mast / Rig / sm_boat_sail`
  (+ `Boat/Camera3D`). `Model` heels, bobs and rocks (`rock_and_roll`, the prototype's damped springs: roll pulled toward heel + lean out of a turn + the waves' roll, pitch toward the speed's bow lift + the waves' pitch, `roll_stiffness` 16 / `roll_damping` 3.2, `pitch_stiffness` 22 / `pitch_damping` 4.5, clamped ±0.6 / ±0.3 rad; the lean out of a turn is the measured `turn_speed` / `turn_rate` × speed / `top_speed` × `turn_lean_deg` 22°; **speed lifts the bow and it stays up** (Enrico, like a motorboat; it replaced the prototype's surge): pitch target = (speed / `top_speed`)^`bow_lift_curve` (2) × `bow_lift_deg` (8°), the pitch clamp's top raised to fit; the waves `wave_roll_deg` 3°, `wave_pitch_deg` 2°, `wave_period` 3 s and 0.8× that; everything follows), `Rig` (at the mast's foot) turns the
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
- **Wake and bow wave**: the wake (as the prototype's wake dots) is a `CPUParticles3D` child of `Boat` in `boat.tscn`
  (`Wake`, its look set in the Inspector), `local_coords` off so what it leaves stays on the water, flat 8-sided discs
  (a CylinderMesh with no height), unshaded, vertex colour + alpha, render_priority 1: at the stern (z +1.7), two
  points ±0.55 m pushed outward 1.2 m/s, 28 dots, life 1.2 s, ink, alpha 0.8 → 0, growing 0.28 → 0.9 m; on only above
  6% of `top_speed` and not at anchor; `speed_scale` = her share of top speed (at least 0.35). **The bow wave**
  (Enrico, like Wind Waker's; it replaced the `BowSpray` particles): two flat "wings" of water, `BowWaveRight` /
  `BowWaveLeft` (MeshInstance3D, one QuadMesh 2.6 × 0.9 m with `center_offset` so its origin is its front bottom
  corner), at the stem at the waterline (±0.08, 0.02, −2.95), running back 50° out from her line and leaning 35°
  outward; material `m_bow_wave.tres` (`bow_wave.gdshader`: unshaded, both faces, render_priority 1, a **4 × 4
  flipbook** of `bow_wave.png`, frames 128 × 48, bow end on the left, crest at the top; the picture is a stand-in
  for Enrico to redraw; uniforms `frames_x/y`, `frame`, `strength`). `boat.gd` `update_bow_wave()`: `strength` eases
  (×4/s) to her share of top speed (0 at anchor or slow), the wings grow from `bow_wave_min_size` 0.4 to full with it
  and hide below 0.02; the frame counts up at `bow_wave_fps` 12 × that share (at least 0.3).
  **The sail's trail** (Enrico: the boom's end skimming the water in a hard turn): `SailTip` (a Marker3D in `Rig` at
  the boom's end, (0, 0.12, 4.7); move it in boat.tscn) and `SailTrail` (CPUParticles3D, child of Boat, the wake's disc
  mesh and colour ramp, 24 dots, life 1 s, no velocity, local_coords off, size curve 0.4 → 1 × 0.7); `update_sail_trail()`
  (from `update_water_fx`) puts the emitter at the tip's x/z at y 0.05 and turns it on while |`turn_speed`| / `turn_rate` ×
  speed / `top_speed` > `sail_trail_threshold` (0.4), not at anchor or sinking (a condition, not real contact).
- **The slingshot: removed** (Enrico, Oct 2026; in git history: `Assets/UI/slingshot/`, `Assets/Boat/projectile/stone.*`).
  `Assets/Boat/projectile/stone.gdshader` stays: the camera-facing flipbook used by the fireball and the bomb. It keeps the node's scale (it once dropped it), so scaling `Picture` in `bomb.tscn` / `fireball.tscn` makes the picture bigger. Its
  sounds are gone too (bake.html can still make them).
- **The outline** (`Assets/Boat/boat_outline.gdshader`, made by `boat_camera.gd` `add_outline()`: a QuadMesh child of the
  camera, stretched over the screen in the vertex shader, render_priority 1, after the sea): reads the depth buffer
  (`hint_depth_texture`; only the solid things are in it, i.e. the boat, since the sea is in the transparent pass;
  0.0 = nothing), and paints ink on pixels with no boat but boat within `outline_width` (boat_camera.gd export, 1.5 phone
  points) in 8 directions; boat pixels below `water_level` (0) don't count (their height is worked out from the depth
  with `INV_PROJECTION_MATRIX` / `INV_VIEW_MATRIX`), so the line follows the water line, not the hidden hull. Made in code so it doesn't cover the editor's view. Any future solid 3D object gets it too.
- **The camera** (`Boat/Camera3D` with its own script, **`Assets/Boat/boat_camera.gd`**: everything about the camera
  lives there, not in boat.gd; **perspective** (Enrico: not orthographic), `fov` 20, keep width, `far` 200): `top_level`,
  placed every frame from the south, tilted `tilt_deg` 20, `distance` m back along the way it looks; **the distance
  eases** (Enrico; `update_zoom`, lerp at `zoom_speed` 1.5) to `distance_sailing` 130 under way / `distance_anchored` 90
  at anchor or tied up (`boat.anchored`), so the view is further out while sailing. It looks at `focus`, which trails after her
  with a **dead zone** (`follow`: while she's within `dead_zone` 6 m it stays still; past it, it lerps toward the spot
  that puts her back on the edge at `follow_speed` 3). **Screen shake** (Enrico, whenever she takes damage): boat.gd
  `take_damage` calls `camera.shake()`; `update_shake` sets `h_offset` / `v_offset` to random ± `shake_strength` 0.5 m ×
  what's left of `shake_time` 0.3 s. It also makes the ink outline (`add_outline`, `outline_width`). The boat calls only
  `camera.shake()` and `camera.jump_to_boat()` (respawn); nothing else reads it now.
- **Sound** (`Sfx` autoload, `Assets/SFX/`): `.ogg` files made from the prototype's own Web Audio code by
  `art_src/audio/bake.py` (Playwright opens `bake.html`, which holds the prototype's `colouredNoise`, `chainLink`,
  `anchor` and `thunk` verbatim, renders each sound in an `OfflineAudioContext`; loops get an extra second
  cross-faded onto the start; one gain for all keeps the prototype's balance; ffmpeg → Vorbis;
  `CHROMIUM=/opt/pw-browsers/chromium-1194/chrome-linux/chrome python art_src/audio/bake.py`). **Only the anchor and the
  wheel now** (Enrico removed the sea, the wind and the water along the hull; bake.html still has them, bake.py's
  `NAMES` leaves them out): `anchor_down.ogg` / `anchor_up.ogg` (`Sfx.anchor(down)`, called by `boat.gd`
  `toggle_anchor`); `wheel_rub.ogg` (a 6 s loop of the prototype's rub: low-passed noise at 520 Hz through its wheel
  bus, × `WHEEL_VOL` 2; `Sfx.wheel(spin, dt)` every frame from `helm.gd`: loudness = min(1, spin / 7 rad/s), silent
  under 0.05, eased over 0.08 s, pitch 0.8..1 for the prototype's filter 320..520 Hz) and `wheel_thunk.ogg` (the thud at
  full lock, `thunk(WHEEL_VOL)`; `Sfx.wheel_stop(strength)` when the wheel reaches full lock turning faster than 0.3
  rad/s, strength min(1, 0.5 + spin / 10)). The spokes' knocks stay off, as in the prototype (`WHEEL_KNOCKS` false).
  The players are nodes in `sfx.tscn` (their Volume dB = the level); nothing plays while the game is paused.
- **The dither** (`Assets/Post_Process/dither/`: `dither.tscn`, a CanvasLayer 100 with a ColorRect, `dither.gdshader`):
  Bayer 4×4 to paper/ink, one dot per pixel of the game view (below; `pixel_size` > 1 only makes the grain coarser).
  Its handles (the ColorRect's material in `dither.tscn`): `brightness`, `contrast`, then **levels** (Enrico):
  `black_point` (greys at or below → solid ink), `white_point` (at or above → solid paper), `gamma` (the middle greys:
  > 1 lighter); `paper_color`, `ink_color`. Tone is set here, not with a WorldEnvironment (that would touch only the 3D).
- **The game view** (`Assets/Post_Process/game_view.gd`, node `GameView` in Overworld; Enrico asked for performance):
  at start (deferred, after every node is ready) it moves `Sea`, `Coast`, `Clouds`, `WindLines`, `Gulls`, `Boat`, `Dither`, `Helm`, `BombButton` and the
  logbook's `IconLayer` into a `SubViewport` drawn at the game's resolution, and shows its picture on a full-screen
  `TextureRect` (CanvasLayer 1, nearest filter: sharp dots). Size: real pixels of the game area
  (`get_visible_rect().size × get_final_transform().get_scale()`) / `dot_scale`, `dot_scale` = round(real width /
  `dots_across`), ≥ 1 (**`dots_across`**, an export on `GameView`, 360 = the grain as it was; 540 = 2 × 2 real pixels a
  dot on a 1080 phone, ~2.25× the work; 1080 = 1 × 1, 9×). The controls inside keep their size whatever it is:
  `size_2d_override` = real pixels / round(real width / 360), `size_2d_override_stretch` on. With 360: (phone 1080 wide → 360×655, ×3; the PC's 360×800 window → ×1; a wide PC screen in the phone frame
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
  moving 9 off the hub turns the wheel instead; at anchor the wheel doesn't steer (drag and arrow keys), and **it fades
  away, only the hub stays** (Enrico, as the prototype; `wheel_shown` 1 → 0 over `wheel_fade_time` 0.3 s, also tied up;
  `_has_point` then only takes the hub). **The hub's glyph** (`_draw_hub(..., glyph)`: "anchor", "question" over a
  fishing spot, "talk" a speech bubble, `_draw_speech_bubble`; talk comes first; six pictures): the speech bubble while
  she's in an NPC's radius or someone talks (Enrico: dropping anchor there starts the talk), from the boat's
  `talk_hint_changed` (`set_near_npc`, `npcs_near`, `talking`'s setter, `talk_hint()`). Its sounds:
  see Sound (the rub and the thud at full lock). No buzz yet.
- **The wind vane** (`Assets/UI/wind_vane.tscn` + `wind_vane.gd`, `@tool`; CanvasLayer 110, crisp, top right, 68 px;
  group `hidden_while_talking`): **as Valheim's** (Enrico): it turns with the boat, not the map. A leaf-shaped ink
  boat in the middle always bow up; a thin ink ring round her, **thick ink where the wind is bad** (where the sail gives
  less than `poor_drive` 0.5 of its best, read from the boat's own `POLAR` via `BOAT_SCRIPT`, so it follows the curve:
  `_thick_arc` per stretch); the **wind badge** on the ring where the wind comes from seen from her (`wind_on_ring` =
  `Wind.from_deg` − her compass heading; 0 = on the bow), a paper disc with an ink arrow pointing in, **flipped (ink disc, paper arrow) while the wind is in the bad zone**
  (Enrico). Redrawn only
  when the badge moves by 0.5° or more.
- **The logbook** (`Assets/UI/logbook/`: `logbook.tscn` + `logbook.gd`, `book_icon.gd`, `book.gd`; in Overworld): as the
  prototype's. The button bottom left (76 px, drawn in greys on a CanvasLayer under the dither, 95, so it's 1-bit) emits
  `pressed`; `logbook.gd` tweens `drop` (the shut book comes down, 0.26 s) then `book.unfold` (the cover swings open on
  the spine while the book re-centres, 0.33 s), the reverse to close. `book.gd` (CanvasLayer 120, crisp) draws the
  leather (a 15 px tile of dots), stitching, metal corners, the pages with the edges beneath, and only spread 0 for
  now (Enrico): the two pages meet with no gap and no line down the middle (one sheet: no more pages for now). Top half:
  the hold (see The inventory), "Cargo" and "n/9" over a 3-across grid of slots (`SLOT_MAX` 40 px), each thing in a solid
  frame with its icon at its own pixel size (a pile with its number bottom right; the equipped one with a second, thick
  frame inside), empty slots dashed and faint. **A tap on a bomb's or trap's slot equips it** (`_gui_input`, touch, only
  fully open; `_slot_rects` kept by `_draw_hold`; `Inventory.toggle_equip`); it refreshes on `equipped_changed` too. Bottom half: the 9×9 map A1..I9 (the
  prototype's 100-unit layout), a square as big as fits, its middle on the spine, labels at least `LABEL_MIN_SIZE` 8 px,
  the square she's in shaded (ink 0.3). Everything on the pages is laid out flat and drawn twice by `_draw_half`, the
  right page as it is and the left squeezed toward the spine with `draw_set_transform` while the cover turns; the
  `_half_*` helpers cut lines, rects and pictures at the spine (words are drawn only on a page that holds all of them).
  (The frame-rate counter is gone, Enrico.) It refreshes on opening and on `Inventory.changed`.
  **The book itself is not redrawn every frame** (Enrico): `logbook.gd` calls `book.refresh()` on opening, which reads
  the square once; after that it's drawn again only while the cover turns (`unfold`'s setter).
- **The inventory** (`Inventory` autoload, `Assets/Inventory/inventory.gd`, data only; the logbook draws it; icons in
  `Assets/Inventory/icons/`: `fish.png`, `bomb.png`, `trap.png`, `imp.png`, stand-ins): `SLOTS` 9; an item is its name;
  `items` one entry per thing; `STACKABLE` (`bomb`, `trap`) pile up in ONE slot; `slots()` gives the slots as
  `{item, count}`; `add(item, count)` (as many as fit: a stackable already aboard needs no slot), `remove`, `count`,
  `is_full`; signal `changed`. **Equipping** (Enrico): `EQUIPPABLE` (`bomb`, `trap`), one at a time, `equipped` ("" =
  none), `toggle_equip(item)` (tap again = unequip; the last one spent unequips), signal `equipped_changed`.
  `START_ITEMS` {bomb: 9, trap: 9} (Enrico, to try them). A captured imp is `"imp"` (one slot).
- **Health** (Enrico, the prototype's hull as Zelda's hearts): on the boat (`boat.gd`): `max_hearts` 3, `health` in hearts
  (0.5 = half), `hit_damage` 0.5 a bump (in `bump()`, after its cooldown and minimum speed), `take_damage(hearts)`,
  `add_heart_container()` (one more heart and the hull whole), signal `health_changed(hurt)`. **At 0 she sinks** (Enrico): `start_sinking()` (no sailing, anchor or bumps; the water mask off so the sea covers her inside; no wake or bow wave), `update_sinking` takes `Model` down `sink_depth` 2.5 m and over `sink_lean_deg` 25° in `sink_time` 2 s (eased in), then signal `sank`; `respawn()` puts her back home (`home_position` / `home_turn`, where she was placed in Overworld) at anchor, hull whole, keeping the hold and heart containers. **The game over card** (`Assets/UI/game_over.tscn` + `.gd`, made like the start screen: CanvasLayer 130, process_mode Always, hidden): on `sank` it pauses the game and shows "Shipwrecked", "The hull gave way. Back home to mend it." and "Set sail again", which calls `respawn()` and unpauses.
  Shown top left by `Assets/UI/health/` (`health.tscn`: CanvasLayer 110, crisp; Control `Hearts` 12, 12; `health.gd`,
  `@tool`): a paper panel, 2 px ink border, a hard 3 px ink shadow, "Hull" and a 17 px heart a heart (the prototype's SVG
  path as Béziers), full, half (its left half) or empty; drawn again only on `health_changed`; hurt, the panel is ink
  for `HURT_FLASH` 0.35 s.
- **Fishing spots** (Enrico; `Assets/Landscape/fishing_spots/`: `fishing_spot.tscn` + `fishing_spot.gd` (`@tool`),
  `fishing_spot.gdshader`, `fishing_spot.png`; instanced by hand under `FishingSpots` in Overworld, for now `FishSpot`
  (−12, 0, −50) and `HeartSpot` (20, 0, −62)): the prototype's drawSpot (a dark soft patch, rings welling up), a
  4 × 4 flipbook (frames 64², a stand-in for Enrico to redraw) on a 1 m PlaneMesh `Picture` 0.05 m up, scaled to
  `radius` 3.3 m × 2 (scaled, as the mesh is shared); unshaded, render_priority 1, the sea's stencil read (not over the
  boat's inside), material local to scene (`phase` random, `fade`). Inspector: `loot` (FISH or HEART_CONTAINER),
  `fish_count`, `reach` 4.5 m (the anchor must fall that close to the middle: a bit more than the patch), `fishing_time`
  3 s, `fade_time` 1.8 s. `boat.gd` `toggle_anchor` calls `try_fishing(boat)` on every spot (group `fishing_spots`) when
  the anchor goes down; still at anchor after `fishing_time`, the haul: fish into the Inventory (hold full: nothing, the
  spot stays) or `add_heart_container()`; then it fades and is freed. Weighed before: nothing, it stays. No net,
  popup or sound yet. **The wheel's hub shows a question mark** (Enrico, the prototype's `bankHint` glyph) instead of the anchor
  while she's over a spot, **event-driven** (Enrico: no checks every frame): each spot has `Sensor` (Area3D, a
  `CylinderShape3D` of radius `reach`, local to scene, height 4; mask = physics layer 4 "sensors", not monitorable) and
  the boat `SpotSensor` (Area3D, a 0.3 m sphere on layer 4, not monitoring); `area_entered` / `area_exited` →
  `_update_boat_here()`: over = not fished out and (inside or fishing there), told only when it changes through
  `boat.set_over_fishing_spot(spot, here)`; the boat keeps `fishing_spots_under` and emits
  `over_fishing_spot_changed(over)` when it goes empty/non-empty; `helm.gd` connects to it once (`_listen_to_boat`,
  deferred) and swaps the hub picture (`over_spot`; `_hub_picture_sailing_spot` / `_anchored_spot`, `_draw_hub(...,
  question)`, `_draw_question_mark`). After the haul, the anchor again. (Land's rays don't hit areas.)
- **Sea imps** (Enrico's **mimic**; `Assets/Dangers/sea_imp/`: `sea_imp_zone.tscn` + `.gd` (`@tool`), `sea_imp.gdshader`,
  `sea_imp.png`, `fireball.tscn` + `.gd`, `fireball.png`; placed by Enrico under `SeaImps` in Overworld, for now one
  `SeaImpZone` at (−156, 0, −91)). Nodes: `Imp` (a 4 m camera-facing picture, its bottom middle on the water;
  `sea_imp.gdshader` discards what's under the water line; alpha-scissored, nearest, render_priority 2; `frames_x/y`,
  `frame` ready for Enrico's sheet; a stand-in) and `Patch` (the fishing spot's flipbook shader and picture,
  render_priority 1, a 1 m plane scaled to `lurk_size` 10.8 m: Enrico, 3 times the first 3.6). `State`: **LURKING** at
  its own place (only the patch, like a fishing spot) → the boat within `wake_radius` 10 m → **EMERGING** (`emerge_time`
  1.5 s: only the patch, where it will come up: the warning) → **UP** (the imp; `idle_before_spit` 1 s, spits,
  `idle_after_spit` 1 s) → **UNDER** (the imp invisible, out of reach; **its patch swims**, Enrico: `swim()`, from where it
  dived straight to the next spot at a steady `swim_speed` 6 m/s, `move_toward`; the spot, `swim_target`, is chosen the
  first frame under, retried each frame until one fits) → EMERGING at that spot
  (`find_spot_in_view`: a random point of the screen within `screen_margin` 0.12 of the edges, followed down the boat
  camera's line of sight to the water, `spawn_distance_min/max` 6–18 m from her, **downwind of her** while
  `downwind_only` (on; off = anywhere on the screen, Enrico, to compare) (Enrico: the line
  through her across the wind splits the screen, it only comes up on the side the wind blows toward, so a bomb drifts
  to it; `is_downwind`, dot with −`Wind.from_vector()` > 0), not land; 20 tries a frame). The first
  time it comes up where it lurked. Back to LURKING (at its place) when she's more than `radius` 40 m from it, or sinks.
  **The fireball** (`fireball.gd`): from `spit_height` 1.5 m, level, toward where she'll be in `aim_ahead` 0.5 s,
  `fireball_speed` 7.5 m/s; within `fireball_hit_radius` 1.3 m of her middle `boat.take_damage(fireball_damage)` (1
  heart, Enrico); gone on land or after `fireball_life` 3 s; `stone.gdshader`'s billboard flipbook (a stand-in).
  **Health**: `max_hearts` 3; bombs and traps call `hit_imp_at(point, reach, damage)` on every imp (group `sea_imps`):
  only while EMERGING or UP and within `reach`: −`damage` hearts and **it blinks black** (Enrico: feedback; `hurt_time`
  0.5 s at `hurt_blinks_per_second` 12, `update_flash` sets `sea_imp.gdshader`'s `flash`, its material duplicated per
  imp); left > 0 → **HURT** (up, harmless, blinking; hit while emerging it shows itself) then UNDER; 0 → **DEFEATED** (up,
  harmless, after the same blinking **solid black** for good, dead (Enrico; a different picture later), and **carried by
  the current** (`drift_with_current`: `Wind.current()` × dt, no step onto land, so it washes up on a shore)); the boat's middle within `collect_radius` 2.5 m → `Inventory.add("imp")` (room needed) →
  CAPTURED, gone for good. Lost hearts stay lost. In the editor a red disc shows `radius`. No ripples, sounds, popups
  or buzz (not asked).
- **Big waves** (Enrico, the prototype's rollers, zones placed by hand; `Assets/Dangers/big_waves/`: `wave_zone.tscn` +
  `.gd` (`@tool`), `big_wave.tscn` + `.gd`, `big_wave.gdshader`, `big_wave.png`; under `BigWaves` in Overworld, for now
  one `WaveZone` at (0, 0, −200), `radius` 60): no sounds, no buzz, no darker sea (Enrico). The zone: a circle (green disc
  in the editor), `Sensor` (Area3D on layer 4) sets `boat_inside`; while she's in (not sinking, not tied up), every
  `spawn_every_min/max` 1.5–3 s a wave (at most `max_waves` 10) rises upwind of her (`spawn_back_min/max` 6–36 m,
  ±`spawn_side` 26 m), in the zone, on water, with 12 m of water ahead; running downwind (wind ≥ `downwind_deg` 120° from
  her bow, speed > 0.6) each second a `surf_wave_chance` 0.3 of her own wave `surf_wave_back` 10 m astern
  (±`surf_wave_side` 4.5 m), already at her pace + `catch_up` 2.5 (capped `max_pace` 12), living 5.5–6.5 s; one at a time.
  A wave (group `big_waves`): travels downwind (its −Z), crest `length` 4.5–7.5 m bowed 0.625 m forward in the middle,
  `pace` 2.5–3 m/s, `life` 4–6 s; `strength()` builds over 30%, full, fades over the last 30%; dies down (jumps to 75% of
  its life) 4 m before land or the zone's edge. The quiet hand (`adjust_pace`): a wave just behind her (≤ 22 m, crest
  in line) while she runs its way (cos > 0.4) hurries to her real pace (her way + the current, `boat.drift`) + catch_up
  and lives 40% longer; one about to hit her badly slows to `spare` 0.55. The crest reaching her (strength ≥ 0.55,
  |u| < 1, within thickness × 0.6 × √(1−u²) + 0.3 of the bowed crest), once: her way (cos > 0.4) → `boat.surf_wave()`
  (`surf_time` 2.6 s of + `surf_boost` 3.2 m/s, fading over its last 0.8 s, gathered at rate 3); else
  `boat.hit_by_wave(dir, strength, badly, damage)`: `damage` 0.5 hearts, `knock` += dir × `wave_push` 4.5 × strength,
  speed × `wave_slowdown` 0.4, bow slewed ± `wave_slew_deg` 14° × badly. Picture: a 1 m PlaneMesh scaled to length × 3 m,
  0.06 m up, render_priority 1, the sea's stencil read, a 4 × 4 flipbook (frames 128 × 48, travel = up, the crest on the
  middle row, bowed up) played once over its life (a stand-in: builds, breaks into foam, fades).
- **Piers** (Enrico; `Assets/Landscape/pier/`: `pier.tscn` + `pier.gd` (`@tool`); instanced under `Piers` in Overworld,
  for now one at (−10, 0, −20), a test): `Mesh` (a placeholder wooden BoxMesh 2 × 0.6 × 10 m, toon_shade; not solid),
  `Berth` (Node3D, the boat's parking spot: her bow points along its −Z) with `Sensor` (Area3D, a `CylinderShape3D`
  of radius `dock_radius` 8, local to scene; mask layer 4 "sensors", the boat's `SpotSensor`). In the editor a blue
  disc (the radius) and an arrow on the berth (her heading), made in code with no owner. `area_entered` with the boat
  not at anchor → `boat.dock_at(berth)`: `berth` set, `anchored` true (sail gathered, no steering, hub dark), speed 0;
  every physics frame `glide_to_berth` (instead of steering / current / bumps / the anchor line) moves her x/z and
  `rotation.y` (`lerp_angle`) toward the berth by 1 − exp(−`dock_speed` 3 × dt). The anchor button (`toggle_anchor`)
  while tied up → `cast_off()`: `berth` null, `anchored` false (no sound); **then a calm and a push** (Enrico: so the
  wind can't trap her on land): for `cast_off_calm_time` 3 s (`calm_left`) the sail's drive is 0 and there's no current
  (`drift_amount` back to 0, so it eases in again after), and her speed is set to `cast_off_push` 5 m/s forward (it
  fades at `accel`, ~7.5 m in the 3 s); she can steer meanwhile. She ties up again only after leaving the
  sensor and coming back (it's `area_entered`). `respawn()` clears `berth`.
- **Bombs** (Enrico; `Assets/Items/bomb/`: `bomb.tscn` + `bomb.gd`, `bomb.png` a 2 × 1 sheet (dark, fuse lit), stand-in;
  the button `Assets/UI/bomb_button/`: `bomb_button.tscn` (CanvasLayer 95, in `DITHERED`; Control `Button` bottom right,
  80 px, where the slingshot was) + `bomb_button.gd` (`@tool`)): the button shows only while a bomb is equipped; a tap
  (touch) takes one bomb out of the hold and drops it `bow_offset` 2.2 m ahead of her middle (Enrico: off the bow), on the water, into the
  world. The bomb: a 1.6 m camera-facing picture (`stone.gdshader`, render_priority 2) whose spark blinks quicker and
  quicker (2 → 8 a second) and **pulses** (Enrico: shrinks and swells, `pulse_time` 1 s a cycle, ±`pulse_amount` 0.15
  round the `Picture`'s own scale from bomb.tscn, `pulse()`), **carried by the current** while the fuse burns (Enrico; `drift_with_current`, as the dead
  imp: `Wind.current()` × dt, no step onto land); after `fuse_time` 2 s it blows: `Blast`, a flat disc growing to `blast_radius` 4 m and fading
  over `blast_time` 0.4 s; every zone's `hit_imp_at(pos, blast_radius, damage 1)`, and the boat too
  (`take_damage(1)`) if her middle is within the radius; then a **powerful screen shake** wherever she is (Enrico:
  `boat.camera.shake_hard(shake_strength 1.5, shake_time 0.6)`, the bomb's exports; `boat_camera.gd` `shake_hard`: a
  weaker shake never cuts a stronger one short; `shake()` = `shake_hard(shake_strength 0.5, shake_time 0.3)`). No sound (not asked).
- **Traps** (Enrico; `Assets/Items/trap/`: `trap.tscn` + `trap.gd`, `trap.png` (a stand-in, seen from above),
  `trap_setter.gd` on `Boat/TrapSetter` in boat.tscn): boat.gd sends `anchor_dropped` when the anchor goes down
  (`toggle_anchor`, not at a pier); with a trap equipped (and one aboard) TrapSetter lays one where she is (a 2.4 m
  PlaneMesh 0.04 m up, StandardMaterial3D unshaded, alpha, render_priority 1). ARMING, faint (alpha 0.4): she must stay
  at anchor `arm_time` 1.5 s, or it's taken back (nothing spent); then ACTIVE, solid, one trap out of the hold; it stays
  when she sails away; an imp coming up within `radius` 2 m (`hit_imp_at`) loses `damage` 1 heart and the trap is
  used up.
- **NPCs** (Enrico; `Assets/NPCs/npc/`: `npc.tscn` + `npc.gd` (`@tool`, `@icon` `npc_icon.svg`, a speech bubble),
  `bubble.png` (a stand-in); instanced under `NPCs` in Overworld, for now `TestNPC` at (14, 0, −34), an "Old
  Fisherman" with three test pages): no look yet, the node is the pivot. Inspector: `speaker_name`, `portrait`
  (Texture2D, Enrico paints it), `lines` (`@export_multiline Array[String]`: an entry = a page, new lines inside it),
  `talk_radius` 8 m (a yellow disc in the editor), `bob_height` 0.4, `bob_speed` 1.5, `fade_time` 0.3. `Sensor` (Area3D,
  mask layer 4, the boat's `SpotSensor`: event-driven) sets `boat_near` and tells the boat (`set_near_npc`: the hub
  shows a speech bubble); `Bubble` (a flat PlaneMesh 5 × 3.75 m lying
  level 5 m up, StandardMaterial3D unshaded, alpha, render_priority 2, duplicated per NPC; Enrico tilts it if he wants:
  no billboards) fades in while she's near and not talking and bobs up and down, fades out when she leaves. On the
  boat's `anchor_dropped` with her near: `talk_box.open(speaker_name, portrait, lines, _on_talk_finished)`; it starts
  again from the top each time she anchors there.
- **The talk box** (`Assets/UI/talk_box/`: `talk_box.tscn` (CanvasLayer 115, crisp, not in `DITHERED`; Control `Box`
  at the top, full width less 12 px, y 92–222) + `talk_box.gd`; in Overworld as `TalkBox`, group `talk_box`): a paper
  panel, 2 px ink border, 3 px ink shadow (as the hearts'); on the left `Portrait` (TextureRect 86 px, a double ink
  frame), on the right `Name` (14) and `Text` (13, autowrap), ink. Each page typed out at `letters_per_second` 30
  (`visible_characters`). **A quick tap on the wheel's hub** (`helm.gd` signal `hub_tapped`: let go before `hub_hold`;
  helm in group `helm`): while typing → the whole page; then the next page; after the last → closes and calls the
  NPC back. While open `boat.talking` is true: `toggle_anchor` does nothing (hub hold, Space) and the hub's ring
  doesn't fill. **While open, every node in the group `hidden_while_talking` is hidden** (Enrico: the
  `WindVane` and `Health` CanvasLayers, group set in their .tscn; `_show_hud`); add a node to it to hide it too.
- **Map markers** (Enrico; `Assets/Quests/map_marker/`: `map_marker.tscn` + `map_marker.gd` (`@tool`, `@icon`),
  `map_marker_icon.svg`; instanced under `MapMarkers` in Overworld, for now one at (60, 0, −150), F4, `active` on to
  try it): an invisible Node3D; in the editor a red X in a circle (the scene-tree icon, and in the 3D view a Sprite3D
  billboard, `fixed_size`, `no_depth_test`, made in code with no owner, so not in the game). `active` (export),
  `activate()` / `deactivate()` (for future quests: an NPC will call them), `square()` = its 9 × 9 square (as the
  boat's). Group `map_markers`: `book.gd` `refresh()` (on opening) reads the squares of the active ones into
  `_marked_squares`; `_draw_map` draws an ink X (arms 0.3 of a square, width 2) in the middle of each.
- **The UI is drawn in the editor too** (Enrico: to place and arrange it himself): `helm.gd`, `wind_vane.gd`,
  `book_icon.gd`, `book.gd`, `health.gd` and `bomb_button.gd` are `@tool`; in the editor (`Engine.is_editor_hint()`) `_gui_input`
  and `_process` return at once (no touches, keys, boat, wind or sounds), so they only draw: the wheel with the
  sailing hub (redrawn each editor frame, its pictures being ready a frame late), the vane with the wind from the
  north, the shut logbook icon, the open book (`unfold` = 1, the hold empty), three full hearts, the bomb button (always shown there). Their places and sizes
  are the Controls' in their .tscn (anchors and offsets), except the open book's, which `logbook.gd` works out
  every frame (`BOOK_MAX`, `TOP_GAP`, centred).
- **The start screen** (`Assets/UI/start_screen.tscn` + `.gd`, CanvasLayer 130, in Overworld): a card with the title, "Build
  N" and the build's start time, and the line "Hold the anchor to set sail". **No button and no pause** (Enrico): she
  starts at anchor and **weighing the anchor** (the hub held, as always) starts the game: the boat's signal
  `anchor_weighed` (sent by `toggle_anchor` when it comes up; connected `CONNECT_ONE_SHOT`) hides the card. Until
  then everything in the group `hidden_at_start` is hidden (`WindVane`, `Health`, the logbook's `IconLayer`,
  `BombButton`; groups set in their .tscn), so only the hub shows (the wheel is faded away at anchor). The numbers
  come from `Assets/UI/build_info.gd` ("local" in the repo); `web.yml` rewrites it before exporting with
  `github.run_number` and the time (Europe/Rome). No settings or knobs on it.
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
