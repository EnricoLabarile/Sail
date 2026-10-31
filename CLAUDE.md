# Vento e Vele (Godot) — notes for Claude Code

- **Reply to Enrico in Italian.** All text inside the game stays in English.
- **Do only what Enrico asks.** No extra features, effects or animations he didn't request, even if the prototype
  has them or they seem nice: he decides what goes in. If something extra seems worth it, suggest it in one line
  and wait for his yes.
- **Editor-only helpers must be visible from afar** (Enrico's rule): every debug disc, arrow or icon made for the
  editor gets `render_priority` 10 or more (after the sea, which is a see-through pass and would otherwise cover it
  when it's further away than the sea's middle) and `no_depth_test = true` (over the land). Done for the sea imp,
  wave zone, pier, NPC and map marker helpers.
- **A sensor's size lives in the script, never only in the shape** (Enrico's rule): every Area3D sensor is sized by
  an export on its script (`reach`, `radius`, `talk_radius`, `size`…) with a setter that calls `_fit_sensor()` (also
  from `_ready`, before the editor return; the script is `@tool`, the shape `resource_local_to_scene`), so changing the
  export resizes the shape at once, in the editor too, and the value stored on the shape in the .tscn never matters.
  Done for pickups, barrels, fishing spots, piers, NPCs, wave zones, wind zones and the floating shop's greet area.
- **Every new enemy can be hurt by the bomb** (Enrico's rule, Oct 2026): give it health (`max_hearts`, 3 unless
  told otherwise), put it in the group `bomb_targets` and give it `blast_at(bomb)` (hit if `bomb.in_blast(its place,
  its size)`: −`bomb.damage`, a black blink; at 0 it dies). `bomb.gd` `explode()` calls `blast_at` on that group.
- **Running into any enemy hurts and bounces the boat** (Enrico's rule, Oct 2026, for every monster): the enemy checks
  each frame whether the boat's middle is within its `touch_radius` (only while it's out of the water / solid) and
  calls `boat.bump_into_enemy(its place)`: she's knocked back away from it (`bounce_kick` + `bounce_extra` × her
  speed, into `knock`), her speed × `bounce_slowdown`, `take_damage(enemy_touch_damage 0.5)` (its sound: `Sfx.boat_hurt`); then
  `enemy_touch_cooldown` 1 s (`enemy_wait`) before it can happen again. Done for the urchin (3 m) and the imp (2 m, up or hurt).
- **Every enemy, when killed, makes the death sound and drops something** (Enrico's rule, Oct 2026): `Sfx.enemy_death()`
  (`imp_death.ogg`, `enemy_death_delay` 0.25 s after, so the bomb's bang doesn't cover it) and `Pickup.drop_loot(parent,
  item, place, chance, min, max, spread)` (a static function in `pickup.gd`: with `chance` 0..1 it leaves `min`–`max`
  pickups of `item` on water within `spread` m, `loot_spot`); each enemy has the exports `drop_item` (default
  `bomb.tres`; empty = nothing), `drop_chance` (1 = always), `drop_min` 1, `drop_max` 2, `drop_spread` 3 m.
- **No camera-facing (billboard) shaders or nodes** (Enrico's rule, Oct 2026): pictures in the world are plain
  planes/quads that keep the node's own rotation; Enrico decides himself whether and how to tilt an element to the
  camera's angle. (Already made before the rule: `stone.gdshader`, used by the bomb and the fireball, and
  `sea_imp.gdshader`; the map marker's billboard is editor-only.)
- **Guides for code Enrico writes himself** (when he says "lo voglio fare io" / "guide me"): steps in the file's own
  order, **top to bottom** (declarations first, so nothing is used before it exists), one file at a time, each step
  with the **line number** it goes at (worked out with the earlier steps already added), and the line's text to check.
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
- **Before creating any new file, show Enrico where it will go and wait for his ok** (Enrico's rule, Oct 2026): list
  each new file with its full `res://` path (and any new folder) first, so he can check the folder structure; create
  them only after his yes. (Files outside the game, e.g. `art_src/` scripts, too.)
- **The layout now (Enrico chose it, Oct 2026)**: everything under `Assets/`, by part: `Assets/Boat/` (`boat/boat.tscn`,
  `boat.gd`; `boat_test.tscn`, the test scene), `Assets/Landscape/world/` (the sea), `Assets/Post_Process/dither/`,
  `Assets/UI/` (`helm.tscn`, the wheel), `Assets/Scenes/` (`Overworld.tscn`, the main scene, which `run/main_scene`
  points at by uid; `main.tscn`), plus `Dangers/`, `SFX/` when they get files. Follow this layout for new files; it
  replaces the lower-case `boat/ world/ ui/ shared/` plan below (the other rules still hold, and since the folders now
  have capitals, spell every `res://` path exactly as on disk: the web export is case-sensitive).
- **Autoloads** (project.godot): `PhoneFrame` (`Assets/Scenes/phone_frame.gd`, a phone-shaped frame on wide screens, **PC only**: on a phone (`is_phone()`: `mobile` / `web_android` / `web_ios` feature tags or a touch screen) it's always `EXPAND`, never the frame (Enrico: after turning the phone sideways and back the game stayed squeezed between black bars, the frame's `KEEP`); in the browser `listen_for_turns` adds a little JavaScript (`window.vvAskSizeAgain`, on `orientationchange`, `screen.orientation` change, trusted `resize`, `visibilitychange`, and on focus in) that re-sends `resize` 0.1, 0.5 and 1 s later (Godot polls `innerWidth/innerHeight` every frame, `library_godot_display.js` `updateSize`); `lock_upright` asks `screen.orientation.lock('portrait')`, which browsers allow only in full screen / home-screen apps, so in a normal tab the page still turns) and
  `Wind` (`Assets/Landscape/world/wind.gd`): **no random wind any more** (Enrico): every level starts blowing **north** (`START_FROM_DEG` 180 = from the south; `reset()` on `scene_changed`), constant strength, and it changes only when the boat crosses a **wind zone** (below): `Wind.turn_to(from_deg, seconds)`, the short way round, smoothstep, `_process` only while turning; the boat and the wind vane read `Wind.from_deg`. Signal `direction_changed` whenever `from_deg` changes (its setter): the gusts listen. **Wind zones** (`Assets/Landscape/wind_zone/`: `wind_zone.tscn` + `wind_zone.gd` (`@tool`, `@icon` `wind_zone_icon.svg`); under `Gameplay/WindZones` in Overworld, for now `WindZoneEast` at z −45 and `WindZoneRandom` at z −90, 40 × 6 m, tests): an invisible box (`Sensor`, Area3D mask layer 4, a BoxShape3D local to scene, `size` width × length in m, turned with the node); Inspector `mode` SPECIFIC (blows TOWARD `blow_toward_deg`, 0 = north, 90 = east) or RANDOM (any angle, picked on crossing), `turn_time` 4 s; works **once** (`used`, then disconnected). In the editor only: the icon (Sprite3D, fixed size, on top), a see-through blue rectangle and an arrow (top_level, pointing where it will blow) or a "?" in RANDOM mode (render_priority 10–12, no depth test, no owner). **The current
  lives here too** (Enrico: a force on many things): `CURRENT_SPEED` 1.5 m/s, `Wind.current()` = downwind × it, read
  by the boat (eased in with her `drift_amount`), a burning bomb and a dead imp.
  `Sfx` (`Assets/SFX/sfx.tscn` + `sfx.gd`, the sounds, see Sound below). `Inventory` (`Assets/Inventory/inventory.gd`, the hold, see The inventory).
  **`Hud`** (`Assets/UI/hud.gd`): whether the icons (the groups `hidden_at_start`: wind vane, hearts, logbook button,
  bomb button; `hidden_while_talking`: vane and hearts) show. Each wish to hide them is a **reason**
  (`Hud.set_hidden(reason, groups, hidden)`): "start" (until Set sail), **"anchor"** (Enrico: **at anchor or tied up only
  the hub shows**: `boat.gd`'s `anchored` setter, and in its `_ready`), "talk" (talk box), "store" (the counter); an icon
  shows only when no reason hides it, so a talk or trade ending at anchor doesn't bring them back. Nothing else should set
  those nodes' `visible`.
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
  at `shore_opacity` 0.9 (one texture read a pixel). **Deep water** (Enrico): the same picture darkens the sea away from the coasts (`distance_from_coast()`,
  read once a pixel for both): `smoothstep(deep_from, deep_to 30, metres)`, `deep_from` = the boat's `shallows_width` (sent by `sea.gd` `match_deep_water_to_shallows`, deferred; Enrico: the darkening starts where the slow water ends; 3 in the shader for the editor) × `deep_opacity` 0.3 toward `deep_color`
  (ink), before the grid and the foam; no picture = all deep. `show_shore_waves` off now only hides the waves
  (`shore_waves_on` uniform), the deep water stays. **Baked in the editor** by `ShoreBaker` (a Node3D in Overworld,
  `Assets/Landscape/shore/shore_baker.gd`, `@tool`, `@export_tool_button` "Bake shore"; ~1 s): every MeshInstance3D
  under `land_roots` (`../Islands`, `../Coast`; a path that leads nowhere is looked for by its last name anywhere in the level) copied white into an own World3D, an orthographic camera 200 m up
  looking down with its far plane at the sea's level (only what's above the water), the alpha = land; a two-sweep
  chamfer distance (1 / 1.41) in pixels × `metres_per_pixel` 1; saved as the PNG (`MAX_DISTANCE` 32 must match the
  shader's `shore_max_distance`). **Bake again after changing the coasts.** **One picture per level** (Enrico makes gyms
  to test mechanics): the baker saves to its `save_path` export (`@export_file`, which the Inspector may store as "uid://…": `bake()`
  turns it back into the res:// path with `ResourceUID`; Enrico's files: `ShoreMask_Overworld.png`, `ShoreMask_Gym_SeaImp.png`;
  after saving, `use_new_picture` reimports it and gives it to the level's `Sea` (`shore_texture`), marking the scene unsaved), and each level's `Sea` picks its file in `shore_texture` (sea.gd; set in sea.tscn to the Overworld's):
  at start it sends it to the material's `shore_tex` and to `Land.set_shore_picture()`, which `distance_to_shore`
  reads. `sea.gd` is `@tool`: in the editor it only does that (no fog, no turning), so each level shows its own waves there
  too; it draws with its own copy of sea.tscn's material (`sea_material`, worn as `material_override`, made once in
  `use_shore_picture`, also called by `shore_texture`'s setter), taken off on `NOTIFICATION_EDITOR_PRE_SAVE` and put
  back on `_POST_SAVE`, so it's never written into the level's file. **`show_shore_waves`** (Inspector tick on the `Sea`, Enrico: handy
  while placing islands): off = `shore_tex` null (the shader's default white: no waves); only the look, `Land` keeps the picture. Enrico places the coasts as 3D meshes under the `Coast` node in `Overworld.tscn`; each needs
  a collision (a StaticBody3D with a CollisionShape3D: in the editor select the mesh, Mesh menu → Create Trimesh
  Static Body, or name it with the `-col` suffix in Blender), which is what `Land` hits. When her middle or bow (`bow_reach`) would be on land she **bumps** (the prototype's
  `impact()`, in `boat.gd`: `move_and_bounce`, `bump`; knobs `bounce_*`): only moving into the shore at ≥ 0.4 m/s,
  0.6 s cooldown; a push `knock` along `Land.way_to_sea()` of 2 + 0.9 × the hit speed, fading at 3.5/s; speed × 0.25;
  the bow swung off up to 0.3 rad toward the open side; the hull loses `hit_damage` (**0 now**, Enrico: no damage from bumps, the screen shake stays; was half a heart, see Health) and the hull knocks (`Sfx.hull_bump`, see Sound). No wobble (Enrico removed it), no buzz yet. In the **shallows** (land within
  `shallows_width` 6 m of her middle, `Land.is_near_land`: 3 rings × 16 rays, looked again only every `shallows_check_time`
  0.2 s, `in_shallows`) the sail's drive is ×
  `shallows_sail` 0.3 (Enrico: less wind by the coast). **The current** (prototype's `CURRENT_DRIFT`): `drift` =
  `Wind.current()` (downwind × `Wind.CURRENT_SPEED` 1.5 m/s) × `drift_amount` (eases in at the start at `current_ease` 0.8/s), added to her motion; also at
  anchor (the line holds her, see The anchor); pressing her against a shore she just stays (a bump only from her own way). She
  starts at (0, 0, -34), in the sea just north of home.
- **Sea zones: boiling water and strong currents** (Enrico, Oct 2026; `Assets/Landscape/sea_zones/`): **`sea_zone.tscn`**
  + `sea_zone.gd` (`@tool`, `class_name SeaZone`): **the zone IS a `Path3D`** (Enrico: each placed zone its own shape, as a
  Blueprint's spline in Unreal; it was a Node3D with a shared `Outline` child): select it and edit the points with the
  Path tools; `sea_zone.tscn` has no curve, `_ready` (editor) gives a new zone its own 20 × 20 m square
  (`default_square`), saved in the level with it (not while sea_zone.tscn itself is open); straight sides (handles ignored), `kind` BOILING / CURRENT, `strength` 4 (CURRENT:
  × `Wind.CURRENT_SPEED`, so 6 m/s), `edge_softness` 4 m (it fades in from the edge); a current flows the way the node
  points (its −Z, `flow_direction`; turn the node). Editor helper: the outline (red / blue) and, for a current, a 10 m
  arrow (ImmediateMesh lines, no owner, render_priority 10, no depth test). Nothing runs in the game: **`SeaZoneBaker`**
  (`sea_zone_baker.gd`, `@tool`, a Node3D under `Core` next to the ShoreBaker; button "Bake sea zones", `save_path`
  `SeaZones_<Level>.png`, `metres_per_pixel` 1) paints every SeaZone of the level (CPU: pixels in its box inside the
  polygon, `Geometry2D.is_point_in_polygon`, share = distance to the edge / `edge_softness`) into one RGB8 picture of the
  map: **R** = boiling 0..1 (max of zones), **G / B** = the current's push east / south in m/s as `128 + push /
  SeaZone.MAX_PUSH (20) × 127` (zones add up); it writes a `.import` (lossless, no mipmaps, no 3D detection) the first
  time, reimports and gives it to the level's `Sea` (`zones_texture`). **Bake again after changing a zone.**
  `sea.gd` `zones_texture` → `Land.set_zones_picture` and the material (`zones_tex`, `zones_on`, `max_push`,
  `usual_current`); `Land.boil_at(pos)` (R) and `Land.current_at(pos)` (the push, Vector3). **The boat**: `update_boiling`
  (every physics frame not tied up): in boil ≥ `boil_threshold` 0.5, `take_damage(boil_damage 0.5)` every `boil_every`
  1 s (the first after 1 s; out of it the count restarts); `update_current`: flow = `Wind.current()` × (1 − share) +
  zone push, share = |push| / `Wind.CURRENT_SPEED` (clamped), so inside a zone only the zone's push, at its edge mixed;
  still × `drift_amount` (no current near shores, at NPCs, just after casting off). **The look** (`sea.gdshader`): where
  the picture says so, the sea texture gives way to `boil_tex` (`boiling.png`, × boil) and `current_tex`
  (`strong_current.png`, × share, turned so its TOP points along the flow, `atan(push.x, -push.z)`, sliding along it
  at `current_scroll` 2 m/s), both 4 × 4 flipbooks (`zone_frames_x/y`, `boil_tile` 6 m / `boil_fps` 10, `current_tile`
  8 m / `current_fps` 12), stand-ins made by `art_src/items/make_sea_zone_textures.py` (bubbles welling and popping;
  streaks and "^" chevrons sliding up), set in `sea.tscn`. Test zones in Overworld: `Gameplay/SeaZones/BoilingTest`
  (−30, 0, 40) and `CurrentTest` (−30, 0, 68), flowing east. Gym_SeaImp has its baker (`SeaZones_Gym_SeaImp.png` once baked) and no zones yet.
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
- **Island pieces' import** (Enrico's modular island meshes, `.fbx` from Blender, in `Assets/Landscape/islands/` with
  their shared material `island.tres`): `island_import.gd` (`EditorScenePostImport`, set as the scene importer's default
  Import Script in project.godot `[importer_defaults]`, so every NEW model gets it) sets `island.tres` on every surface
  and adds `StaticBody3D` → `CollisionShape3D` (trimesh, `create_trimesh_shape`) under every mesh that has no body yet;
  models from other folders are left untouched (`get_source_file()` checked). Files imported before keep their own
  `.import` settings (to use it: set Import Script in the Import dock, several at once, and Reimport).
- **Island grid** (Enrico: an absolute grid snap for the modular pieces; `Assets/Landscape/islands/island_grid.gd`,
  `@tool`, on the `Islands` node in Overworld): in the editor, each selected piece under it (its direct children) is put
  on the nearest point of a fixed grid, `grid_size` 8 m (the pieces' own step), counted from `grid_offset` (0, 0,
  0.888885 in Overworld: where the first 365 pieces already sat), and turned to the nearest quarter turn
  (`snap_rotation`); `snap_on` to place one freely; button **"Snap all pieces"** (`snap_all`). Godot's own snap is
  relative (how far you move), this one is absolute (where it ends up). Nothing in the game.
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
  wrapped round the map (moved together inside `Drift`, wrapped once a second: see Nothing runs every frame). Static pictures for now (flipbooks later, maybe). **Shadows** (they darken sea, land and boat alike):
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
- **The sail is its own item and script** (Enrico, Oct 2026: as much of the sail's code as possible on the sail itself):
  **`Assets/Boat/sail.gd`** on the `Rig` node of boat.tscn (an Actor Component in Unreal terms) holds the curve (`POLAR`,
  `polar`), the wind's push `drive()` (0..1 of top speed; 0 when not set or at anchor; × `shallows_sail` 0.5 when
  `boat.in_shallows`), and the look `update_look(dt, push)`: boom to leeward (`boom_max_deg`), belly
  (`sail_fill_rate`, shape keys), gathered up at anchor (`furl_rate`, `unfurl_rate`, `furled_height`), the boom's trail
  (`sail_trail_threshold`, `SailTip`, `SailTrail`); `stop_trail`, `gather_up`. boat.gd only does `sail.drive()` (× top
  speed; still 0 during `calm_left`) and `sail.update_look`; the heel follows the drive. **Item `sail.tres`**
  (`toggle_on_tap`, not equippable, buy/sell 0: the counter won't buy it, it stays aboard; icon `icons/sail.png`, a
  stand-in by `art_src/items/make_sail_icon.py`), one slot, aboard and set at the start (`Inventory.START_ITEMS`,
  `START_ON`). **A tap on its slot in the logbook sets or strikes it** (`Inventory.tap_equip` → `toggle`; `is_on`,
  `switched_on`, signal `toggled(item, on)`; the slot has the thick frame, no A/B letter). **Struck**: the mast and
  everything on it hidden (`sm_boat_mast.visible`, Enrico), no wind push (gusts' boost × 0 too), the current still
  carries her; set again it comes back gathered up and spreads.
- **The paddles** (Enrico, Oct 2026: the paddle wheels and the crank back, as an item like the sail; their code on
  themselves): **`Assets/Boat/paddles.gd`** on `Model/Paddles` in boat.tscn, holding `PaddleWheelLeft` / `Right`
  (`Assets/Boat/paddle_wheel.tscn`, the old stand-in from git with `toon_shade` materials, x ±1.75, y 0.1, z 0.1; `Spin`
  turns). Item `paddles.tres` (`toggle_on_tap`, buy/sell 0, icon `icons/paddles.png` by
  `art_src/items/make_paddles_icon.py`), aboard from the start but **off** (`START_ITEMS`, not in `START_ON`); a tap on
  its logbook slot switches it; off = no wheels, no crank, no push. **The wound spring**: one FULL clockwise turn of
  the crank → `wound()`: `push_left` = `push_time` 4 s at `paddle_speed` 5.88 m/s forward whichever way she points
  (counted down only under way; none at anchor); `power` eases at `take_up_rate` 3.75; the boat's target speed =
  max(sail, `push_speed()`) picked up at `bite` 5.25; turning × `turn_mult` 1.5 while they push (`turn_factor`); the
  current still carries her. **Locked while it pushes, except the last `recharge_window` 2 s** (Enrico: keep it going
  without stopping): `can_wind()`; a full turn then refills to `push_time` (not added). Wheels: pushed or freewheeling
  with her speed, outside wheel faster in a turn (`half_beam`, `paddle_radius`). `stop()` on respawn.
  **The crank** (`Assets/UI/crank/`: `crank.tscn` CanvasLayer 95, group `hidden_at_start`, in game_view `DITHERED`, in
  all 4 levels; Control `Button` 120 px, bottom-left anchored, offsets 6 / −392 / 126 / −272: up and left of the wheel,
  bigger than A/B; `crank.gd`, `@tool`): shown only while the paddles are on; the old drawing (gear, hatched plate,
  rivets, arm and knob, 72-unit box scaled); a finger turning it clockwise winds `wound_so_far`; at TAU →
  `paddles.wound()` and the arm back up; let go before → springs back at `spring_back_speed` 12 rad/s; locked = pale
  (0.35) and no touch; the ring = `push_left / push_time`; every touch flashes it black and clicks.
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
  The players are nodes in `sfx.tscn` (their Volume dB = the level); nothing plays while the game is paused. **The wheel's sounds quieter** (Enrico): `WheelRub` and `WheelThunk` at −14 dB in sfx.tscn. **In the background** (Enrico: the browser in the background still played the game): `sfx.gd` `_notification` on `NOTIFICATION_APPLICATION_FOCUS_OUT` / `_PAUSED` → `go_to_background()`: the Master bus muted and the game paused (remembering if it already was, `paused_before_background`); on `_FOCUS_IN` / `_RESUMED` → `come_back()` puts both back. On the PC it also happens when another window is clicked.
  **Enrico's sound pass** (Oct 2026): **"came aboard"** (`pickup.ogg`, player `Pickup`, `Sfx.came_aboard()`): played
  by the BOAT for anything going into the hold (Enrico: an item or an imp's body, it's all something brought aboard):
  `Inventory.add` sends `came_aboard(item, count)` (not for the start items, added before the boat listens),
  `boat.gd` `_on_came_aboard` plays it: pickups, a caught imp, a fishing haul, a buy at the counter. **Imp killed**
  (`imp_death.ogg`, `ImpDeath`, `Sfx.enemy_death()`, now **every enemy's** death sound: `sea_imp_zone.gd` `defeat()`, `sea_urchin.gd` `blast_at`): a low buzzy growl falling
  110 → 38 Hz with a wobble, a bubbling gurgle of low noise, soft overdrive, 1.1 s. **Bomb** (`bomb_blast.ogg`,
  `BombBlast`, `Sfx.bomb_blast()`, from `bomb.gd` `explode()`): a short crack, a boom falling 80 → 28 Hz, a low
  rumble, overdriven, 1.6 s; played less intense (Enrico): `BombBlast` Pitch Scale 1.5 (higher, ~1.1 s) and Volume
  −6 dB (half) in sfx.tscn. An enemy's death plays `enemy_death_delay` 0.25 s late (an export on sfx.gd), as it's
  usually killed by a bomb, whose blast covered it. Both made by `art_src/audio/make_danger_sounds.py` (numpy, scipy, ffmpeg); both keep
  overtones above 200 Hz on purpose, as a phone's speaker can't play their deep part.
  **The logbook** (Enrico: a page turning, opening and closing): `book_open.ogg` / `book_close.ogg` (players `BookOpen` / `BookClose` −8 dB, `Sfx.book(opening)`, from `logbook.gd` `set_open`: opening as the cover starts to swing, after the drop; closing at once): a paper flutter (noise band-passed 1.5–4.5 kHz and a lower rustle, flickering under a rise-and-fall swell), 0.35 s; closing 0.3 s of it and then the cover's soft thump (110 → 70 Hz and low-passed noise) at 0.3 s; made by `art_src/audio/make_page_turn.py`.
  **The boat hurt** (Enrico: one sound for every kind of damage): `boat_hurt.ogg` (player `BoatHurt` −6 dB,
  `Sfx.boat_hurt()`), played by `boat.gd` `take_damage` whenever she loses hearts (> 0; not while sinking or coming
  up), so fireballs, spikes, bombs, boiling water, maelstroms, waves and enemies all make it with nothing of their own; a
  splintering crack (4 bursts of noise 1.5–5 kHz in 50 ms) on a heavy thud 110 → 55 Hz and a short creak sliding
  900 → 400 Hz, 0.42 s, made by `art_src/audio/make_boat_hurt.py`. Running into an enemy plays only this (not the hull bump).
  **Hull bump** (Enrico: when she bounces off a surface; `hull_bump.ogg`, player `HullBump`, `Sfx.hull_bump(strength)`,
  from `boat.gd` `bump()`, so shores and barrels alike, only for a real bump, after its cooldown and minimum speed):
  a dull thud 150 → 75 Hz with overtones (Enrico: keep this pitch), a woody knock (noise round 700 Hz) and a scrape, all
  from the first instant (the first version's scrape peaked 80 ms in), 0.55 s,
  made by `art_src/audio/make_bump.py`; `HullBump` Volume −8 dB (Enrico: quieter); loudness 0.4 + 0.6 × hit speed / `top_speed`.
- **The dither** (`Assets/Post_Process/dither/`: `dither.tscn`, a CanvasLayer 100 with a ColorRect, `dither.gdshader`):
  Bayer 4×4 to paper/ink, one dot per pixel of the game view (below; `pixel_size` > 1 only makes the grain coarser).
  Its handles (the ColorRect's material in `dither.tscn`): `brightness`, `contrast`, then **levels** (Enrico):
  `black_point` (greys at or below → solid ink), `white_point` (at or above → solid paper), `gamma` (the middle greys:
  > 1 lighter); `paper_color`, `ink_color`. Tone is set here, not with a WorldEnvironment (that would touch only the 3D).
- **The game view** (`Assets/Post_Process/game_view.gd`, node `GameView` in Overworld; Enrico asked for performance):
  at start (deferred, after every node is ready) it moves `Sea`, `Coast`, `Clouds`, `WindLines`, `Gulls`, `Boat`, `Dither`, `Helm`, `BombButton` and the
  logbook's `IconLayer` (found by name anywhere in the level, `owner.find_child`: Enrico groups the Overworld into
  "folder" nodes, Core / Dangers / Decorative / Gameplay / UI and PostProcess) into a `SubViewport` drawn at the game's resolution, and shows its picture on a full-screen
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
- **Smooth movement: physics interpolation** (Enrico: choppy on the phone; Project Settings > Physics > Common >
  Physics Interpolation, on): she moves in `_physics_process` (60 Hz) but the phone draws at its own uneven pace, so
  her drawn position jumped 0 or 2 ticks a frame (measured with real frame times: 2.5–4.5 m/s on screen for a steady
  3.5). Now Godot draws her between ticks. Only the boat is interpolated: `boat.gd` `_ready` sets the tree's root
  `physics_interpolation_mode` OFF and hers ON (everything else moves itself in `_process` and must not be smoothed);
  the camera is OFF too and follows `boat_position()` = `get_global_transform_interpolated()`; `respawn()` calls
  `reset_physics_interpolation()` (a jump, not a glide). Anything new moved in `_physics_process` that must look
  smooth: set its mode ON (or put it inside the boat).
- **Nothing runs every frame without a reason** (Enrico's optimisation pass, Oct 2026; measured: the scripts' own cost
  was tiny, the choppiness was the above): `set_process(false)` while idle, switched on by events: NPCs (sensor in/out,
  talk end; off once the bubble has faded), fishing spots (`try_fishing`; off when nobody fishes), wave zones (while she's
  inside), the logbook (while the book shows; `_hide_book`), the talk box (open / close), the floating shop (greet area,
  `say`; off when she's gone and he's quiet), the hearts (only during the hurt flash). The clouds move as one node
  (`clouds.gd` `drift`, all 256 inside it) and are wrapped round the map once a second (`wrap_clouds`), not each cloud
  every frame. `sea.gd` sends the texture's angle only while it turns to a new wind (steady wind: nothing; it lands on
  the target within 0.001 rad), keeps the boat once found, and sends `fog_falloff` from its setter.
- **Shader warm-up** (Enrico: frame drops while sailing round; `Assets/Post_Process/shader_warmup.gd`,
  `class_name ShaderWarmup`, added by `game_view.gd` at the level's start, so every level has it): the first time a
  material is drawn its shader compiles, and on WebGL that stops a frame (measured sailing round the Overworld, real
  frame times under xvfb: 6–9 hitches of 80–320 ms on a first lap, where an island, the fishing spot or the first
  fireball first came into view; on a second lap only where something new showed; with the warm-up 1, unrelated to
  anything). At start it collects every 3D material in the tree (hidden ones too: the imp, the NPC's bubble; islands
  out of view) plus those of the scenes in `LATER` (fireball with its debug ring, bomb and blast, trap, pickup, big
  wave: made once, hidden and disabled, to read their materials), skips the full-screen effects (shader code with
  `POSITION =`: fog, outline, cloud shadows), and draws each once on a 1 cm square 2 m in front of the camera, plus a
  tiny-dotted copy of each CPUParticles3D, for `FRAMES` 3 frames; then it all goes (59 materials, 2 emitters in the
  Overworld). Something new made later in code with a new kind of material: add its scene to `LATER`.
- **Top speed** (`boat.gd` `top_speed`): **3.5 m/s** (Enrico: halved from 7, so the gusts' boosts matter). **Turning** (as the prototype): `turn_rate` 2.25 rad/s (Enrico: between the old 1.5 and the doubled 3) at full rudder whatever her speed (no slower with less way);
  none at anchor; × the paddles' `turn_mult` while they push (see The paddles).
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
  16.5 sailing / 21 at anchor (× 2.6): held `hub_hold` 0.33 s (Enrico: halved to 0.165, then back once the press flash showed the press; a ring fills) it works the anchor and shakes; a finger
  moving 9 off the hub turns the wheel instead; at anchor the wheel doesn't steer (drag and arrow keys), and **it fades
  away, only the hub stays** (Enrico, as the prototype; `wheel_shown` 1 → 0 over `wheel_fade_time` 0.3 s, also tied up;
  `_has_point` then only takes the hub). **Every press on the hub** (Enrico, a rule for every button: also the bomb and jar buttons, their own `press_flash` 0.12 s, the whole disc ink; in a talk, to drop or
  weigh the anchor) **flashes black and clicks**: its picture tinted black while the finger is down and for at least
  `press_flash` 0.12 s (`press_flash_left`), and `Sfx.button_press()` (`button_press.ogg`, player `ButtonPress` −6 dB: a
  soft low tock, 70 ms, 170 → 130 Hz with a muffled tick, made by `art_src/audio/make_button_press.py`). **The hub's glyph** (`_draw_hub(..., glyph)`: "anchor", "question" over a
  fishing spot, "talk" a speech bubble, `_draw_speech_bubble`; talk comes first; six pictures): the speech bubble while
  she's in an NPC's radius or someone talks (Enrico: dropping anchor there starts the talk), from the boat's
  `talk_hint_changed` (`set_near_npc`, `npcs_near`, `talking`'s setter, `talk_hint()`). Its sounds:
  see Sound (the rub and the thud at full lock). No buzz yet.
- **The wind vane** (`Assets/UI/wind_vane.tscn` + `wind_vane.gd`, `@tool`; CanvasLayer 110, crisp, top right, 68 px;
  **hidden for now** (Enrico): Visible off in wind_vane.tscn and out of the Hud groups (it was in `hidden_while_talking`, `hidden_at_start`; put it back in them to show it again), `_process` does nothing while hidden): **just an arrow** (Enrico, simple; it was Valheim's dial with the
  boat and the bad-wind ring): ink with a paper edge (`edge_width` 2 px), pointing the way the wind BLOWS on the screen
  (`blows_to` = `Wind.from_deg` + 180; the camera looks north, so up = north). Redrawn only when it turns by 0.5° or more.
- **The logbook** (`Assets/UI/logbook/`: `logbook.tscn` + `logbook.gd`, `book_icon.gd`, `book.gd`; in Overworld): as the
  prototype's. The button bottom left (76 px, drawn in greys on a CanvasLayer under the dither, 95, so it's 1-bit) emits
  `pressed`; `logbook.gd` tweens `drop` (the shut book comes down, 0.26 s) then `book.unfold` (the cover swings open on
  the spine while the book re-centres, 0.33 s), the reverse to close. `book.gd` (CanvasLayer 120, crisp) draws the
  leather (a 15 px tile of dots), stitching, metal corners, the pages with the edges beneath, and only spread 0 for
  now (Enrico): the two pages meet with no gap and no line down the middle (one sheet); a second spread, the marked places, see Map markers. Top half:
  the hold (see The inventory), "Cargo" and "n/9" over a 3-across grid of slots (`SLOT_MAX` 40 px), each thing in a solid
  frame with its icon at its own pixel size (a pile with its number bottom right; the equipped one with a second, thick
  frame inside), empty slots dashed and faint. **A tap on a bomb's or trap's slot equips it** (`_gui_input`, touch, only
  fully open; `_slot_rects` kept by `_draw_hold`; `Inventory.tap_equip`: into A, A → B, B → A; **held** `HOLD_TIME` 0.5 s still (≤ `HOLD_SLOP` 10 px) it's taken off, `_wait_for_hold`, Enrico; the equipped slot shows its letter A or B top left); it refreshes on `equipped_changed` too. Bottom half: the 9×9 map A1..I9 (the
  prototype's 100-unit layout), a square as big as fits, its middle on the spine, labels at least `LABEL_MIN_SIZE` 8 px,
  the square she's in shaded (ink 0.3). Everything on the pages is laid out flat and drawn twice by `_draw_half`, the
  right page as it is and the left squeezed toward the spine with `draw_set_transform` while the cover turns; the
  `_half_*` helpers cut lines, rects and pictures at the spine (words are drawn only on a page that holds all of them).
  (The frame-rate counter is gone, Enrico.) It refreshes on opening and on `Inventory.changed`.
  **The book itself is not redrawn every frame** (Enrico): `logbook.gd` calls `book.refresh()` on opening, which reads
  the square once; after that it's drawn again only while the cover turns (`unfold`'s setter).
- **The inventory** (`Inventory` autoload, `Assets/Inventory/inventory.gd`, data only; the logbook draws it; icons in
  `Assets/Inventory/icons/`: `fish.png`, `bomb.png`, `trap.png`, `imp.png`, stand-ins): `SLOTS` 9; an item is its name
  (its ItemData, see Items); `items` one entry per thing; stackable ones (`bomb`, `trap`) pile up in ONE slot; `slots()` gives the slots as
  `{item, count}`; `add(item, count)` (as many as fit: a stackable already aboard needs no slot), `remove`, `count`,
  `is_full`; signal `changed`. **Equipping** (Enrico): equippable ones (`bomb`, `trap`), one at a time, `equipped` ("" =
  none), `tap_equip(item)`, `equip(item, slot)`, `unequip(item)`, `slot_with(item)` (the last one spent unequips), signal `equipped_changed`.
  `START_ITEMS` {trap: 9, sail: 1, paddles: 1} (Enrico: no bombs and no jars at the start, she finds them; the sail, see The sail); **two equip slots, A and B** (Enrico, like Zelda's item buttons; `equipped_a`, `equipped_b`; `ItemData.equip_slot` is gone): ANY equippable thing (bomb, trap, jar, harpoon) in either; a tap in the logbook puts it in A, again moves it to B, again back to A; moving onto the other one's slot swaps them, a new one replaces what was there; a hold takes it off. Each item button sits in its slot's place (`Hud.ITEM_BUTTON_TOP` {a: −252 above, b: −162 below}, `Hud.place_item_button`); the trap has no button (laid at anchor while equipped in either). Things with `ItemData.equip_on_pickup` (bomb, jar, harpoon) **are equipped at once when they come aboard** in the first empty slot (A, then B; both taken: not equipped) (in `add`). A captured imp is `"imp"` (one slot).
- **Health** (Enrico, the prototype's hull as Zelda's hearts): on the boat (`boat.gd`): `max_hearts` 3, `health` in hearts
  (0.5 = half), `hit_damage` 0 a bump (Enrico; was 0.5; in `bump()`, after its cooldown and minimum speed), `take_damage(hearts)`,
  `add_heart_container()` (one more heart and the hull whole), signal `health_changed(hurt)`. **At 0 she sinks** (Enrico): `start_sinking()` (no sailing, anchor or bumps; the water mask off so the sea covers her inside; no wake or bow wave), `update_sinking` takes `Model` down `sink_depth` 2.5 m and over `sink_lean_deg` 25° in `sink_time` 2 s (eased in), then signal `sank`; `respawn()` puts her back home (`home_position` / `home_turn`, where she was placed in Overworld) at anchor, hull whole, keeping the hold and heart containers. **She spawns by coming up out of the water** (Enrico: the sinking played backwards): `start_emerging()` at the level's start (`emerge_on_start`, on) and at the end of `respawn()`; `update_emerging` raises `Model` from `sink_depth` under and `sink_lean_deg` over to its place in `sink_time` ((1 − share)², quick at first, slowing at the surface), the water mask off till she's up; while `emerging` no sailing or damage, but the fog clears round her, and **the anchor can already be weighed** (Enrico: one press after "Set sail"; she sets off once she's up). **The game over card** (`Assets/UI/game_over.tscn` + `.gd`, made like the start screen: CanvasLayer 130, process_mode Always, hidden): on `sank` it pauses the game and shows "Shipwrecked", "The hull gave way. Back home to mend it." and "Set sail again", which calls `respawn()` and unpauses.
  Shown top left by `Assets/UI/health/` (`health.tscn`: CanvasLayer 110, crisp; Control `Hearts` 12, 20; `health.gd`,
  `@tool`): a paper panel, 2 px ink border, a hard 3 px ink shadow, "Hull" and a 17 px heart a heart (the prototype's SVG
  path as Béziers), full, half (its left half) or empty; drawn again only on `health_changed`; hurt, the panel is ink
  for `HURT_FLASH` 0.35 s (`_process` runs only then). **As big as the wind arrow** (Enrico): drawn at that small size
  and scaled up (`draw_set_transform`) so it's `panel_height` 60 px tall, its top at 20 like the arrow's tip; "Hull" is
  drawn at the real big font size (scaled up it was blurry). With 4+ hearts it reaches the arrow. **FPS counter** under
  it (`Fps`, a Label in health.tscn, `fps_counter.gd`: "n fps" from `Engine.get_frames_per_second()`, refreshed by its
  own Timer every `update_every` 0.5 s, not every frame); the floating shop's purse moved below it (top 124).
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
  time it comes up where it lurked. Back to LURKING (at its place) when she sinks, or (Enrico) when she's more than
  `radius` from it **and** it's off her screen (`is_seen`: the imp, or its patch while emerging / under water, inside
  `boat.camera.is_position_in_frustum`; underwater counts as on screen too, Enrico): on screen it keeps chasing her past
  the radius, and gives up once she leaves it off screen (its patch swims at 6 m/s, she sails faster).
  **The fireball** (`fireball.gd`): from `spit_height` 1.5 m, level, toward where she'll be in `aim_ahead` 0.5 s,
  `fireball_speed` 7.5 m/s; within `fireball_hit_radius` 1.3 m of her middle (the zone's value, passed in `launch`: it replaces the ball's own `hit_radius`; **debug**: `show_fireball_hit_radius` on the zone, on, draws an ink ring of that radius on the water under each ball (`make_hit_disc`, a TorusMesh 0.15 m thick, black, render_priority 10, no depth test; a red disc vanished in the dither, same grey as the sea)) `boat.take_damage(fireball_damage)` (1
  heart, Enrico); gone on land or after `fireball_life` 3 s; `stone.gdshader`'s billboard flipbook (a stand-in).
  **Health**: `max_hearts` 3; bombs and traps call `hit_imp_at(point, reach, damage)` on every imp (group `sea_imps`):
  only while EMERGING or UP and within `reach`: −`damage` hearts and **it blinks black** (Enrico: feedback; `hurt_time`
  0.5 s at `hurt_blinks_per_second` 12, `update_flash` sets `sea_imp.gdshader`'s `flash`, its material duplicated per
  imp); left > 0 → **HURT** (up, harmless, blinking; hit while emerging it shows itself) then UNDER; 0 → **DEFEATED** (up,
  harmless, after the same blinking **solid black** for good, dead (Enrico; a different picture later), and **carried by
  the current** (`drift_with_current`: `Wind.current()` × dt, no step onto land, so it washes up on a shore)); the boat's middle within `collect_radius` 2.5 m → `Inventory.add("imp")` (room needed) →
  CAPTURED, gone for good. Lost hearts stay lost. **Running into it** while UP or HURT (boat's middle within
  `touch_radius` 2 m) → `boat.bump_into_enemy` (bounce, half a heart). In the editor a red disc shows `radius`. No ripples, sounds, popups
  or buzz (not asked).
- **Sea urchins** (Enrico: an enemy less aggressive than the imp, it never aims at the boat; `Assets/Dangers/sea_urchin/`:
  `sea_urchin.tscn` + `sea_urchin.gd` (`@tool`), `sea_urchin.png`, `spike.tscn` + `spike.gd`, `spike.png`, stand-ins made
  by `art_src/items/make_sea_urchin.py`; a test one `Dangers/SeaUrchinTest` at (−60, 0, 100) in Overworld): the node is
  the middle of its area, a circle of `area_radius` 20 m (red editor disc, render_priority 10, no depth test); the child
  `Urchin` (a 5 m PlaneMesh `Picture` lying on the water, StandardMaterial3D unshaded, alpha-scissor, nearest,
  render_priority 2; not a billboard) moves. `State` **WALKING** for `walk_time` 4 s at `walk_speed` 2 m/s toward a
  random point of the area on water (`random_point_in_area`, 20 tries; a new one on arrival or when the next step would be
  land), then **ATTACKING** for `attack_time` 2 s standing still: `shot_count` 3 rounds spread evenly over it (round n at
  n × attack_time / shot_count), each `shoot_round` = 8 spikes N, NE, E… from its middle, 0.3 m up; then WALKING again.
  A spike (`spike.gd`, `launch`): flies straight at `spike_speed` 8 m/s, its 1.2 × 2.4 m picture turned so its top points
  the way it flies, for `spike_range` 15 m; within `spike_hit_radius` 1.2 m of her middle `take_damage(spike_damage 0.5)`
  and gone; gone on land. All numbers are the urchin's exports. **Bombs kill it** (Enrico): group `bomb_targets`,
  `blast_at(bomb)`: within `bomb.in_blast(urchin, body_radius 1.5)` it loses `bomb.damage` of `max_hearts` 3 and blinks
  black (`hurt_time` 0.5 s at `hurt_blinks_per_second` 12: its own copy of the picture's material, `albedo_color` black /
  white); at 0 → `State.DEAD`: `Sfx.enemy_death()`, `Pickup.drop_loot` (its `drop_item` bomb, `drop_chance` 1, 1–2 within
  3 m), it stops, blinks, and is freed. Traps don't touch it. **Running into it**: `check_touch`,
  the boat's middle within `touch_radius` 3 m → `boat.bump_into_enemy` (bounce, half a heart). No sounds. `spike.tscn` is in the shader warm-up's `LATER`.
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
- **Maelstroms** (Enrico wrote stages 1–2 himself from my guides; `Assets/Dangers/maelstrom/`: `maelstrom.tscn` +
  `maelstrom.gd` (`@tool`), `maelstrom_outer.png`, `maelstrom_core.png` stand-ins; instanced in Overworld as
  `Maelstrom`): `Whirl` (moves) holds `Outer` / `Core`, 1 m PlaneMeshes scaled to `outer_radius` / `core_radius` × 2
  (`fit_pictures`, setters: the editor follows too), both turning (`spin_speed`, the core twice as fast). It wanders
  in its zone (`zone_radius`, red editor disc; `random_point_in_zone`, `wander_speed`), shows `shown_time`, hides
  `hidden_time`, fading in and out over `fade_time` (`fade`, materials duplicated per maelstrom, `set_fade`).
  **Inert while fading** (Enrico): `is_active()` = showing and fully faded in. Active: `pull_boat()` adds to
  `boat.whirl_pull` (0 at the ring's edge → `pull_strength` at the core's; the boat adds it to her motion and
  zeroes it every frame); `try_catch()`: her middle in the core → `boat.catch(whirl, hold_spin)` (boat.gd
  `caught_eye`: she glides into the eye and spins, no helm, no anchor, `update_caught`) for `hold_time` 1.5 s, then
  `hold_boat` → `boat.release(bow direction, fling_speed 12, fling_time 1.2)` (`fling_velocity` / `fling_left`, fading
  over its last 0.4 s: thrown ~ speed × time metres), `take_damage(core_damage 2)`, and it fades out (`disappear`).
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
- **Items** (`Assets/Inventory/item_data.gd`, `class_name ItemData`, a Resource = a Data Asset): one `.tres` per kind
  in `Assets/Inventory/items/` (`fish`, `bomb`, `trap`, `imp`): `id` (the name the code uses), `display_name`, `icon`,
  `buy_price` (what a merchant asks; fish 4, bomb 5, trap 6, imp 0 = not sold), `sell_price` (what a merchant pays;
  fish 2, bomb 2, trap 3, imp 15; 0 = not bought), `stackable`, `equippable`. The `Inventory` reads the folder at start
  (`load_catalogue`, `ResourceLoader.list_directory`) into `catalogue`; `data(id)`, `icon_of`, `is_stackable`,
  `is_equippable` replace the old ICONS / STACKABLE / EQUIPPABLE lists. A new kind of item = a new `.tres`. **The purse**:
  `Inventory.coins` (`START_COINS` 10 for now, `add_coins`; no slot), shown in the logbook's Cargo heading ("n coins  2/9";
  0 in the editor, where the Inventory doesn't run). `slots_of(list)` works out the slots of any list (a trade's result).
- **Stores** (Enrico; `Assets/Landscape/store/`: `store.tscn` + `store.gd`, `store_counter.tscn` + `.gd`; for now one in
  `Gym_Store`, a copy of Gym_SeaImp without imps, at (−9.5, 0, 108) north of the boat): `Pier` (an instance of
  `pier.tscn`, its docking as any pier; its `Berth` turned 180° in store.tscn so she ties up bow out to sea, away from the building; `pier.gd` now sends `docked(boat)` once she's tied up), `Building` (a
  placeholder box), `StoreCounter`. Inspector: `merchant_name`, `for_sale` (`Array[ItemData]`: drag in .tres files),
  `stock` (−1 = no limit, else how many of each; `sold` counts). Docked → the counter **opens by itself** (Enrico) after `open_delay` 1.5 s (Enrico: see her glide alongside first; a
  `create_timer` await, and only if she's still tied up there).
  **The counter** (CanvasLayer 115, crisp; a card 340 × 460 like the start screen's): "Your hold" (piles, `x3 2c` =
  three, 2 coins each; greyed if `sell_price` 0) and "For sale" (`goods_left`), a tap moves one to "You give" /
  "You take" under them, a tap there puts it back; the purse; the balance (given × sell − taken × buy: "You get n
  coins" / "You pay n coins" / "Even trade") or why not ("Tap things…", "Not enough coins", "No room in the hold":
  `hold_after()` through `slots_of`); **Quit** / **Trade** (moves the items, settles the purse, `sold_one`), both
  close it and leave her tied up (she leaves with the anchor as at any pier; it opens again only on docking again).
  While open: the groups `hidden_while_talking` and `hidden_at_start` and the helm hidden, `boat.talking` true (no anchor).
- **The floating shop** (Enrico's alternative store, to try a physical, UI-less shop; `Assets/Landscape/store_alternative/`:
  `store_alternative.tscn` + `.gd` (`@tool`), `merchant.png` stand-in; its goods are ordinary **pickups**, see below; one in `Gym_StoreAlt`
  (a copy of Gym_Store) at (−9.5, 0, 92)): no pier, no stopping. `Merchant` (a `Raft` box and a `Picture` quad 3 × 4 m
  facing south, not a billboard: Enrico tilts it), `Slot1..3` (Marker3D pivots), `GreetArea` (Area3D, mask layer 4,
  `greet_radius` 20; a green editor disc). Inspector: `for_sale` (up to 3 ItemData, one per slot in order),
  `welcome_line`, `no_money_line`, `hold_full_line`, `greet_radius` (30, Enrico), `pickup_radius` 5 (the script's value; the .tscn's 2.4 override was removed), `bounce_push` 12 (Enrico: more), `line_time` 3.
  **Buy feedback** (Enrico; the shake made by the pickup, the sound by the boat for anything coming aboard): `Sfx.came_aboard()` (`Assets/SFX/pickup.ogg`, a snappy two-note blip made by
  `art_src/audio/make_pickup.py`, numpy + ffmpeg; player `Pickup` in sfx.tscn), `camera.shake_hard(take_shake_strength 0.25,
  take_shake_time 0.18)` (the pickup's exports), and **the purse on screen** (`Talk/Purse`, a paper label "Coins  n" top left under the hearts,
  only while she's in the greet area) counting down to what's left: a Tween of `coins_shown` over `coin_count_time` 0.6 s.
  The bubble is kept 8 px inside the screen's sides.
  **In the greet area the camera comes in as at anchor** (Enrico): `boat_camera.gd` `ask_close_up(on)` counts
  `close_up_requests`, `target_distance()` = `distance_anchored` while > 0. Items drawn **twice as big** (Enrico: disc
  r 1.8, rim 2, icon plane 2.6 m). `Talk` is switched on in `_ready` (game only), so a scene saved in the editor can't keep it hidden.
  On each slot a pickup (`price` = its `buy_price`, `reach` = `pickup_radius`, `auto_take` off, its `touched`
  connected to `try_buy`): `why_not()` "" → `take()` (into the hold, coins out, blip and shake, gone for good) and the
  purse counts down; "hold_full" / "no_money" → `bounce`: `boat.push_away(point, bounce_push)` (boat.gd: speed 0 and
  a `knock` away from it, no damage) and the merchant's line. **Speech bubble** and **price tags** ("5c") are crisp
  Controls on `Talk` (CanvasLayer 112) pinned each frame to the merchant's head / 2.6 m in front of each thing
  (`on_screen`: `camera.unproject_position` in the game view, as a share of it, times the screen); the bubble shows
  `line_time` s on entering the greet area (each time) and on a bounce; the tags only while she's in the greet area.
  For now `Inventory.START_COINS` is 10 (Enrico: to try it; buying a bomb leaves 5, a trap at 6 bounces).
- **Pickups** (Enrico: every collectable is a thing on its own; `Assets/Items/pickup/`: `pickup.tscn` + `pickup.gd`
  (`@tool`)): an item floating on the water, the old shop item's look (`Float`, which bobs: a paper `Disc` r 1.8 with an
  ink `Rim` r 2, the icon on a 2.6 m plane made in code with no owner, so it shows in the editor and is never saved),
  `Sensor` (Area3D, mask layer 4, a cylinder of `reach`, local to scene). Inspector: `item` (ItemData), `count` 1,
  `price` 0 (coins; 0 = free), `reach` 6 (**the magnet**, Enrico: about twice the boat; was 5, 3.5, 2.4), `auto_take` (on),
  `pull_speed` 3 m/s, `pull_accel` 25 m/s², `collect_distance` 0.8 m, `bob_height` / `bob_speed`, `take_shake_strength` /
  `take_shake_time`. Her SpotSensor entering → signal `touched(pickup, boat)`; with `auto_take`, `why_not()` ("" /
  "hold_full" / "no_money") "" → **magnetised** (`pulled_by` = the boat): `fly_to_boat` moves it straight to her middle,
  speeding up (`pull_speed` + `pull_accel` × t; ~0.4 s from 5 m), and within `collect_distance` → `take(boat)` (no room
  by then: it stops where it got to). The floating shop's goods (`auto_take` off) aren't pulled. `take(boat)`: `Inventory.add(id, count)`, coins out if priced, `Sfx.pickup()`, the shake,
  signal `taken`, freed; no room: it stays. (Its sound is the boat's "came aboard", see Sound.) Placed by hand anywhere, made by the floating shop, and **dropped by a killed
  enemy** (`Pickup.drop_loot`, see the rule at the top: the imp's `defeat()`, the urchin's death; `drop_chance`,
  `drop_min`–`drop_max` 1–2 pickups of `drop_item` (bomb.tres) within `drop_spread` 3 m, on water, added next to the
  enemy so they stay put).
- **Barrels** (Enrico, like Zelda's pots; `Assets/Items/barrel/`: `barrel.tscn` + `barrel.gd` (`@tool`),
  `barrel.gdshader`, `barrel.png` a 4 × 4 flipbook (frames 64², a big barrel lying on its side, rocking, a foam ring;
  a stand-in for Enrico to redraw, made by `art_src/items/make_barrel.py`); under `Gameplay/Barrels` in Overworld, for
  now one at (−4, 0, −56) holding 2 bombs): `Picture` a 4 m PlaneMesh lying 0.1 m up, the shader unshaded, nearest,
  alpha-cut, no depth (no outline), render_priority 2, its own `phase`. Inspector: **`contents`** (ItemData: what's
  inside, Enrico picks it; empty = nothing), `count`, `radius` (its size as a collider; Enrico set 5 m).
  **Solid**: `Sensor` (Area3D, mask layer 4, sized in `_ready` to `radius` + `SENSOR_MARGIN` 3 m) switches `_physics_process` on while the boat's SpotSensor is in
  it; her middle closer than `radius` is put back on its edge (`keep_boat_out`), and if her own way took her into it,
  `boat.bump(out, into)` (her push back, lost way, half a heart, as a shore); **the barrel never moves** (Enrico). **Broken only by a bomb**: `bomb.gd` `explode()`
  calls `blast_at(point, blast_radius)` on the group `barrels`; with an arm of the blast touching it (`in_blast` + its `radius`) it breaks (`break_open`): an
  ordinary **pickup** (`pickup.tscn`, `item` = `contents`, `count`) left where it was, the barrel gone. No sound or
  break animation yet (not asked).
- **Bombs** (Enrico; `Assets/Items/bomb/`: `bomb.tscn` + `bomb.gd`, `bomb.png` a 2 × 1 sheet (dark, fuse lit), stand-in;
  the button `Assets/UI/bomb_button/`: `bomb_button.tscn` (CanvasLayer 95, in `DITHERED`; Control `Button` bottom right,
  80 px, where the slingshot was) + `bomb_button.gd` (`@tool`)): the button shows only while a bomb is equipped **and at least one is aboard** (Enrico: 0 bombs = hidden, so no taps; `_update_shown` on `equipped_changed` and `Inventory.changed`); **when a bomb gets equipped**
  (`_on_equipped_changed`, `was_equipped`) two rings pulse out round it (`_draw_equip_rings`, ink over paper, `equip_anim_time` 0.6 s,
  `equip_ring_grow` 22 px) and `Sfx.equip_bomb()` plays (`equip_bomb.ogg`, player `EquipBomb` −4 dB: two dry metallic clicks 70 ms
  apart, like a gun being loaded, made by `art_src/audio/make_equip.py`); a tap
  (touch) takes one bomb out of the hold (then the button rests `cooldown` 2 s, Enrico: taps do nothing, a see-through ink pie of the wait still left shrinking clockwise from the top, `cooldown_left`, `_draw_pie`) and drops it `bow_offset` 2.2 m ahead of her middle (Enrico: off the bow), on the water, into the
  world. The bomb: a 1.6 m camera-facing picture (`stone.gdshader`, render_priority 2) whose spark blinks quicker and
  quicker (2 → 8 a second) and **pulses** (Enrico: shrinks and swells, `pulse_time` 1 s a cycle, ±`pulse_amount` 0.15
  round the `Picture`'s own scale from bomb.tscn, `pulse()`), **carried by the current** while the fuse burns (Enrico; `drift_with_current`, as the dead
  imp: `Wind.current()` × dt, no step onto land), leaving a **white trail** on the water (Enrico: shows which way it drifts; `Trail`, a
  CPUParticles3D in bomb.tscn, local_coords off, 30 white discs r 0.4 m, life 1.5 s, shrinking to 0.3 and fading; off at the blast); after `fuse_time` 2 s it blows. **The blast runs along lines, like Bomberman** (Enrico, Oct 2026; no
  longer only a circle): **a tight circle plus a long cross** (Enrico): the circle `blast_radius` 3 m round the bomb, and
  `pattern` CROSS (4 arms N/E/S/W, the basic bomb) or DOUBLE_CROSS (8, the diagonals too, the advanced one), each
  `arm_length` 16 m long and `arm_width` 2 m wide (`arm_directions`, `in_blast(point, extra)`: in the circle or on an
  arm). The circle is the `Blast` disc (1 m, scaled to `blast_radius` by `show_circle(size, opacity)`): faint while the
  fuse burns, at the blast it grows from 60% to full and fades with the arms. The arms are white strips on the water made in code (`make_arms`, `set_arms`: PlaneMesh, unshaded,
  render_priority 2): faint (`warning_opacity` 0.25) while the fuse burns, so she sees where it will hit; at the blast
  they shoot out (first third of `blast_time` 0.4 s) and fade. Hit: an imp
  on an arm (`hit_imp_at(imp's place, 0.1, damage 1)`), every node of the group `bomb_targets` (`blast_at(bomb)`: the
  sea urchins), a barrel an arm touches (`blast_at(bomb)` → `in_blast(its
  place, radius)`), the boat (`take_damage(1)`) if her middle is in the circle or on an arm; between two arms, outside the circle, she's safe; then a **powerful screen shake** wherever she is (Enrico:
  `boat.camera.shake_hard(shake_strength 1.5, shake_time 0.6)`, the bomb's exports; `boat_camera.gd` `shake_hard`: a
  weaker shake never cuts a stronger one short; `shake()` = `shake_hard(shake_strength 0.5, shake_time 0.3)`). No sound (not asked).
- **The Aeolus Jar** (Enrico; item `aeolus_jar.tres`: stackable, equippable, `equip_on_pickup`, buy 8 / sell 3; icon `Assets/Inventory/icons/aeolus_jar.png`, an amphora with a wind swirl, a stand-in made by `art_src/items/make_aeolus_jar.py`; a test pickup `Gameplay/Pickups/AeolusJarPickup` at (−8, 0, −28) in Overworld): a consumable. Its button `Assets/UI/jar_button/` (`jar_button.tscn`, CanvasLayer 95, group `hidden_at_start`, in `DITHERED`; Control `Button` bottom right, 80 px, **in the place of its A/B slot** (`Hud.place_item_button`); `jar_button.gd`, `@tool`, the bomb button's look and pie): shown only while a jar is equipped and one is aboard; a tap (`uncork_jar`) takes one out of the hold and turns the wind to blow **from right astern**, the way her bow points (`Wind.turn_to(bow + 180, turn_time 1.5 s)`), where it stays until another jar or a wind zone; then `cooldown` 30 s (the ink pie). Instanced in every level next to `BombButton`.
- **The harpoon** (Enrico, like Zelda's hookshot; `Assets/Items/harpoon/`: `harpoon.tscn` + `harpoon.gd`, `harpoon.png`
  the head seen from above, point at the top; item `harpoon.tres`: stackable, equippable (A or B), `equip_on_pickup`, buy 4 / sell 2; icon `icons/harpoon.png`; stand-ins
  by `art_src/items/make_harpoon.py`; a test pickup `Gameplay/Pickups/HarpoonPickup` (10, 0, 30), 9 of them). The button
  `Assets/UI/harpoon_button/` (`harpoon_button.tscn` + `.gd`, `@tool`, the jar button's copy, in its A/B slot's place,
  CanvasLayer 95, in game_view `DITHERED`, instanced in all 4 levels): shown while a harpoon is equipped and one is aboard;
  a tap spends one (Enrico: consumed, bought again) and shoots it (`shoot_harpoon`; one out at a time, then `cooldown`
  1 s, the pie). The harpoon (exports on its root, Enrico's knobs): the head flies straight from the bow (the way she
  pointed when shot) at `shoot_speed` 30 m/s, `head_height` 0.3 m up, the rope (an ink strip `rope_width` 0.12 m) from
  her bow (wherever it is now) to it; it hooks the first thing of the group **`hookable`** within `hook_radius` 1 m +
  that thing's `hook_size()`; nothing within `max_length` 20 m (or land) → back at `return_speed` 40 and gone. Hooked →
  pulled toward her bow at `pull_speed` 12 m/s until `stop_distance` 2 m from it (or land ahead), then let go.
  **Enemies**: `damage` 0.5 hearts (blinking black) and stunned (harmless: no moving, shooting or bumping) while pulled
  and `stun_time` 2 s after; **0 turns either off**. **The hookable interface** (a rule for new things that can be
  pulled): `can_be_hooked()`, `hook_point()`, `hook_size()`, `hooked(harpoon)`, `still_hooked()`, `pulled_to(point)`,
  `unhooked(harpoon)` (see harpoon.gd's notes). Now: **pickups** (free ones with `auto_take`, until the magnet takes
  them), **the sea urchin** (`on_hook`, `stun_left`, `lose_hearts`, `update_stun`: then it wanders again), **the sea
  imp** (only out of the water: UP, HURT, STUNNED, DEFEATED; new state `STUNNED`, then it goes under; a bomb hits it
  stunned too; dead, its body is pulled in to be taken aboard). In the shader warm-up's `LATER`.
- **Wind gusts** (Enrico; `Assets/Landscape/gust/`: `gust.tscn` + `gust.gd` (`@tool`), `gust.gdshader`, `gust.png` a 4 × 4 flipbook of 128² frames (three paper-and-ink gusts curling into spirals, whirling round a dashed ring; a stand-in made by `art_src/items/make_gust.py`)): `Picture` a 1 m PlaneMesh 0.08 m up scaled to `radius` × 2, unshaded, nearest, alpha-cut, no depth, render_priority 2, the sea's stencil read, its own `phase`; `Sensor` (Area3D mask layer 4, sized by `radius` 3 m, `_fit_sensor`). Her SpotSensor entering (not at anchor, tied up or sinking; again every time she comes back in) → `boat.boost(speed_multiplier 2, boost_time 1 s, boost_accel 4)` (boat.gd `boost_left`, `boost_multiplier`, `boost_accel`: her speed target × the multiplier whichever way she heads, gathered at that rate; cleared on respawn), `camera.shake_hard(shake_strength 0.2, shake_time 0.15)` and `Sfx.gust_whoosh()` (`gust_whoosh.ogg`, player `GustWhoosh` −12 dB: a very mild band-passed noise sweep, 0.6 s, made by `art_src/audio/make_whoosh.py`). **The picture turns with the wind**: its top points the way the wind blows (`face_the_wind`, `picture_turn_deg`), at start and on `Wind.direction_changed`. **They travel with the wind** (Enrico, Oct 2026: no longer placed on the map): `travel_speed` m/s downwind (`_process`, read from `Wind.from_vector()` every frame, so they turn with the wind; 0 = stays put, for one placed by hand). **The gust spawner** (`gust_spawner.gd`, a plain Node3D in every level: `Gameplay/Gusts/GustSpawner` in Overworld, at the root in the gyms; the old scatter is gone): once the boat has kept `full_speed_share` 0.95 of `top_speed` (not anchored or sinking) for `full_speed_time` 3 s in a row (`full_speed_for`; any slowing starts it again), a gust every `spawn_every_min/max` 0.8–1.6 s while fewer than `max_gusts` 3 are out (`gusts`): placed at a random point across the wind (`spread` 0.8 of the screen's half-width there, measured by `distance_to_screen_edge`: steps of 2 m until `camera.is_position_in_frustum` is false) and then pushed upwind to just past the screen's edge (+4 m), given `travel_speed` 9 m/s (she does 7 at top speed); freed once downwind of her and out of view, or 300 m away (`forget_finished_gusts`).
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
  shows a speech bubble, and **her top speed is capped at `npc_speed_limit` 0.2 of `top_speed`** while `npcs_near` isn't
  empty, Enrico; she eases down to it at `accel`; and **no current** there either, `update_current` target 0, Enrico); while she's in the
  radius and not talking the hub's speech bubble **shimmers** (Enrico: to catch the eye; `helm.gd` `shimmer_on`,
  `_draw_shimmer`: a slanted paper band with thin ink edges, cut to the hub's circle with `Geometry2D.intersect_polygons`,
  sweeps left to right in `shimmer_time` 0.5 s every `shimmer_every` 1.6 s; redrawn every frame only then); `Bubble` (a flat PlaneMesh 5 × 3.75 m lying
  level 5 m up, StandardMaterial3D unshaded, alpha, render_priority 2, duplicated per NPC; Enrico tilts it if he wants:
  no billboards) fades in while she's near and not talking and bobs up and down, fades out when she leaves. **The talk starts by itself** (Enrico): on entering the radius (`_start_talk_on_arrival`, deferred; not tied up, sinking, or already talked to) the anchor drops by itself (`boat.toggle_anchor()`, its sound too), or if she's already anchored the talk just opens. On the
  boat's `anchor_dropped` with her near: `talk_box.open(speaker_name, portrait, lines, _on_talk_finished)`. **When the talk ends**
  (Enrico) the NPC calls `boat.done_talking_with(self)`: the boat keeps `npcs_talked_to`, and until she leaves its radius
  (`set_near_npc(…, false)` drops it) that NPC no longer counts for `talk_hint()` (= talking or `npcs_waiting()`): the hub shows
  the anchor again (so it's clear she can sail on), no shimmer, its 3D bubble fades out, and anchoring there again doesn't
  restart the talk (`has_talked_to`); out and back in, it's as new. While the hub shows the speech bubble **the wheel is drawn
  darker** (`helm.gd` `talk_wheel_shade` 0.6, a modulate on the wheel's picture).
- **The talk box** (`Assets/UI/talk_box/`: `talk_box.tscn` (CanvasLayer 115, crisp, not in `DITHERED`; Control `Box`
  at the top, full width less 12 px, y 92–222) + `talk_box.gd`; in Overworld as `TalkBox`, group `talk_box`): a paper
  panel, 2 px ink border, 3 px ink shadow (as the hearts'); on the left `Portrait` (TextureRect 86 px, a double ink
  frame), on the right `Name` (14) and `Text` (13, autowrap), ink. Each page typed out at `letters_per_second` 30
  (`visible_characters`). **Its voice** (Enrico, like Animal Crossing): every `letters_per_blip` 2 spoken letters (letters and digits; `_is_spoken`, the first of a page at once) `Sfx.talk_blip()`: `talk_blip.ogg` (player `TalkBlip` −8 dB, polyphony 3; second version, Enrico: the first was whiny: a plain 50 ms dot of sound, 240 Hz holding its pitch, a touch of 2nd/3rd harmonics, made by `art_src/audio/make_talk_blip.py`) at a random pitch `talk_pitch_min/max` 0.96–1.04 (only a little change) (sfx.gd exports). **A quick tap on the wheel's hub** (`helm.gd` signal `hub_tapped`: let go before `hub_hold`;
  helm in group `helm`; see the wheel for its press flash and click): while typing → the whole page; then the next page; after the last → closes and calls the
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
  **Printed maps** (Enrico: an editor tool, not something done while playing): `picture` (Texture2D export) is the
  marker's page in the logbook; **"Print map"** (`@export_tool_button`, group "Print map" in the Inspector,
  `print_map`) makes it, like the shore baker: a SubViewport with its own World3D (see-through background) holding plain white
  unshaded copies (`_copy_mesh`) of only the meshes under `land_roots` (`../../Islands`, `../../Coast`, found
  by name if the path fails), an orthographic Camera3D `area_size` 120 m across, straight above the marker looking down (`CAMERA_HEIGHT` 200 m, a constant: in orthographic the height changes nothing, it only has to be above everything; Enrico: a map is always printed from above, no tilt), one render of
  `picture_size` 140²; in **two colours, no shading** (Enrico: easy to read; `to_two_colours`): land
  (not see-through) = paper, sea = ink; the camera's far plane is at the sea's level, so only what's above the water counts; saved to `print_path` (empty = `Assets/Quests/map_marker/prints/<level>_<marker>.png`), then
  reimported and put in `picture` (`use_new_picture`, the scene marked unsaved: save it). Print again after changing
  the coasts. Nothing of it runs in the game. The Overworld's two markers have theirs (`Overworld_MapMarker*.png`).
  **The logbook's pages** (`book.gd`, `PAGE_COUNT` 2): `page` 0 = the hold and the map; page 1 = **"Marked places"**
  (Enrico: one spread, not a page per marker): `PLACE_SLOTS` 9 square slots in a 3 × 3 grid (`PLACE_COLUMNS`,
  `PLACE_GAP` 8) as big as fit, centred on the spine, title and "n/9" above (`_draw_places`); the active markers with a
  `picture` fill them in turn (`_places`, read in `refresh`, at most 9): the picture stretched to the slot, an ink
  frame and an X (paper under ink) in the middle, no square's name (Enrico: the player finds it from the land) (`_draw_place`);
  empty slots dashed and faint, as the hold's. Page dots at the bottom (`_draw_page_dots`, `DOTS_HEIGHT`).
  **Swipe** to turn (`_gui_input`: where the finger came down is kept; lifted ≥ `SWIPE` 40 px sideways → `turn_page`,
  left = next; less = a tap, which on page 0 equips a bomb or trap slot as before). It remembers its page.
- **The UI is drawn in the editor too** (Enrico: to place and arrange it himself): `helm.gd`, `wind_vane.gd`,
  `book_icon.gd`, `book.gd`, `health.gd` and `bomb_button.gd` are `@tool`; in the editor (`Engine.is_editor_hint()`) `_gui_input`
  and `_process` return at once (no touches, keys, boat, wind or sounds), so they only draw: the wheel with the
  sailing hub (redrawn each editor frame, its pictures being ready a frame late), the vane with the wind from the
  north, the shut logbook icon, the open book (`unfold` = 1, the hold empty), three full hearts, the bomb button (always shown there). Their places and sizes
  are the Controls' in their .tscn (anchors and offsets), except the open book's, which `logbook.gd` works out
  every frame (`BOOK_MAX`, `TOP_GAP`, centred).
- **The start screen** (`Assets/UI/start_screen.tscn` + `.gd`, CanvasLayer 130, process_mode Always, in every level): a card
  with the title, "Build N" and the build's start time, the **level list** and a **"Set sail"** button (inked, shorter than the level buttons: 130 px, centred, Enrico: so it doesn't look like the selected level).
  **Black until "Set sail"** (Enrico): a black ColorRect in its own CanvasLayer `CURTAIN_LAYER` 129 (over the whole
  game, under the card) from the first frame, and the game **paused** (`get_tree().paused`: the boat, wind and imps
  wait; her coming up out of the water plays only after). "Set sail" (`_on_start`): the card hides, the controls come
  back, unpause, the black fades over `curtain_fade` 0.3 s (`lift_curtain`). **She starts at anchor** (Enrico: the
  start and the anchor are separate again): the hub weighs it as always. Until then everything in the group
  `hidden_at_start` is hidden (`WindVane`, `Health`, the logbook's `IconLayer`, `BombButton`; groups set in their
  .tscn). The numbers come from `Assets/UI/build_info.gd` ("local" in the repo); `web.yml` rewrites it before
  exporting with `github.run_number` and the time (Europe/Rome). **Level list** (Enrico): under "Levels", a button per
  `.tscn` in `LEVELS_FOLDER` `res://Assets/Scenes` (`level_names()`: `ResourceLoader.list_directory`, which also works
  in the web export; `Overworld` first, the rest A–Z, `_` shown as spaces), the picked one inked; **a tap only picks it** (Enrico: the menu stays quick; `pick_level`, `picked_level`); "Set sail" (`_on_set_sail`) on the loaded level just starts, on another one `load_level`: "Loading…" on the button (two frames awaited so it's drawn), then
  `change_scene_to_file` behind the black, and the new level **starts by itself** with no second card (`static var start_right_away`, read in its `_ready`) (autoloads carry over: hold, fog, wind). A new level saved there gets its
  button by itself.
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
