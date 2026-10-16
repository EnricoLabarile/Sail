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
  `Land` (`Assets/Landscape/world/land.gd`): `Land.is_land(pos)` reads `map_collision.png` (1024², white = land);
  outside the map counts as land, so the map's edge is a wall the boat bumps into.
- **The landscape is a painted map** (Enrico's choice, option 1): `Assets/Landscape/world/map_paint.png` (4096², greys,
  the whole 504 m world, home = the middle) shown by `sea.gdshader` on the sea plane, a fixed 504 × 504 plane at the
  origin (Enrico: no wrap-around, one place per point, for hand-placed things), with the
  wavelets only where `map_collision.png` is black. Both PNGs are imported Lossless, no VRAM compression
  (`detect_3d/compress_to=0`: the web export has no mobile VRAM formats). The template to paint on is in `art_src/map/`
  (`map_paint_base.png`, `map_guide.png` = A1..I9 grid and home as a top layer; `make_map_template.py` makes them from
  the prototype's `DRAWN_LAND`). When her middle or bow (`bow_reach`) would be on land she **bumps** (the prototype's
  `impact()`, in `boat.gd`: `move_and_bounce`, `bump`; knobs `bounce_*`): only moving into the shore at ≥ 0.4 m/s,
  0.6 s cooldown; a push `knock` along `Land.way_to_sea()` of 2 + 0.9 × the hit speed, fading at 3.5/s; speed × 0.25;
  the bow swung off up to 0.3 rad toward the open side. No wobble (Enrico removed it), no damage, sound or buzz yet. In the **shallows** (land within
  `shallows_width` 6 m of her middle, `Land.is_near_land`: 3 rings × 16 points of the mask) the sail's drive is ×
  `shallows_sail` 0.3 (Enrico: less wind by the coast). **The current** (prototype's `CURRENT_DRIFT`): `drift` =
  downwind × `current_speed` 1.8 m/s × `drift_amount` (eases in at the start at `current_ease` 0.8/s), added to her motion; also at
  anchor (the line holds her, see The anchor); pressing her against a shore she just stays (a bump only from her own way). She
  starts at (0, 0, -34), in the sea just north of home.
- **Fog of war** (`Fog` autoload, `Assets/Landscape/world/fog.gd`, as the prototype's): the map in cells of `CELL`
  4.8 m (105 a side); a cell is seen for good once her middle comes within `SIGHT` 22 m of it (`Fog.reveal`, called
  by `boat.gd` every physics frame). Kept in `Fog.image` (L8, 1 px a cell, white = fog), sent to `Fog.texture` only
  when a cell changes; `sea.gd` hands it to `sea.gdshader` (`fog_tex`, linear filter = soft edge), which paints the
  fog solid black. Only the sea plane is fogged (the boat is drawn over it). Nothing is always clear yet. Only in the game: in the editor `fog_tex` is unset and `hint_default_black` makes that no fog, so the whole map shows.
- **The boat's hierarchy** (Enrico's, Oct 2026): `Boat / Model / sm_boat_hull / sm_boat_mast / Rig / sm_boat_sail`
  (+ `Model/Helmsman`, `Boat/Camera3D`). `Model` heels, bobs and rocks (`rock_and_roll`, the prototype's damped springs: roll pulled toward heel + lean out of a turn + the waves' roll, pitch toward the surge + the waves' pitch, `roll_stiffness` 16 / `roll_damping` 3.2, `pitch_stiffness` 22 / `pitch_damping` 4.5, clamped ±0.6 / ±0.3 rad; the lean out of a turn is the measured `turn_speed` / `turn_rate` × speed / `top_speed` × `turn_lean_deg` 22°; the surge is acceleration × `surge_pitch_deg` 3°/(m/s²), at most `surge_pitch_max_deg` 4.5°; the waves `wave_roll_deg` 3°, `wave_pitch_deg` 2°, `wave_period` 3 s and 0.8× that; everything follows), `Rig` (at the mast's foot) turns the
  boom to leeward (half the wind's angle off the bow, 8° to `boom_max_deg` 30° either side: never across her), the sail's shape keys `Inflated_Right` / `Inflated_Left` make its belly. `boat.gd` finds `Rig` and
  `sm_boat_sail` with `find_child` (by name, anywhere inside), so the hierarchy can change as long as the names stay.
- **Turning** (as the prototype): `turn_rate` rad/s at full rudder whatever her speed (no slower with less way),
  × `paddle_turn_mult` 1.5 while the paddle wheels push; none at anchor.
- **The paddle wheels and the crank** (the prototype's `CRANK_DIRECT`): `Assets/Boat/paddle_wheel.tscn` is a stand-in
  model (four boards, two rims, a hub, an axle; its child `Spin` turns), two instances in `boat.tscn` under `Model`
  (`PaddleWheelLeft` / `Right` at x ±1.36, y 0.1, z 0.1). `Assets/UI/crank.tscn` + `crank.gd` (CanvasLayer 95, under
  the dither; 84 px, bottom right, 4 px from the right, 28 from the bottom; drawn in greys in the prototype's 72-unit
  SVG: dotted gear with 16 teeth, hatched plate, three rivets, a ring that fills with `paddle_power`, the arm and knob;
  `_has_point` only its round face, and the wheel's only inside its handles): turned clockwise (a ratchet), its speed
  smoothed, `boat.set_crank(speed / crank_full_rate 5 rad/s)`. In `boat.gd`: `paddle_power` eases to that at
  `crank_ease` 3.75 (0 at anchor), the target speed is max(sail, `paddle_speed` 5.88 m/s × power) and the push bites
  at `crank_bite` 5.25. `spin_paddle_wheels`: rad/s = max(push / `paddle_radius` 0.7, speed / radius × 0.9) ∓ turn ×
  `paddle_half_beam` 1.36 / radius × 0.9 (outside wheel faster). No sound or buzz yet.
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
  and a light rim at anchor). Drag to steer (half a turn = full rudder, springs back to the middle); the hub's grip is
  16.5 sailing / 21 at anchor (× 2.6): held `hub_hold` 0.33 s (a ring fills) it works the anchor and shakes; a finger
  moving 9 off the hub turns the wheel instead; at anchor the wheel doesn't steer (drag and arrow keys). No sound or
  buzz yet.
- **The logbook** (`Assets/UI/logbook/`: `logbook.tscn` + `logbook.gd`, `book_icon.gd`, `book.gd`; in Overworld): as the
  prototype's. The button bottom left (76 px, drawn in greys on a CanvasLayer under the dither, 95, so it's 1-bit) emits
  `pressed`; `logbook.gd` tweens `drop` (the shut book comes down, 0.26 s) then `book.unfold` (the cover swings open on
  the spine while the book re-centres, 0.33 s), the reverse to close. `book.gd` (CanvasLayer 120, crisp) draws the
  leather (a 15 px tile of dots), stitching, metal corners, the pages with the edges beneath, and only spread 0 for
  now (Enrico): the 9×9 map A1..I9 across both pages (the prototype's 100-unit layout), a blinking dot for the boat.
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
