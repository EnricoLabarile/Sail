extends Node3D
## THE ANCHOR, SEEN (Enrico, Nov 2026: "when the anchor is dropped I cannot really tell"): while she's at anchor a
## CHAIN runs from her bow down to the water where the anchor went in (boat.gd `anchor_point`), and little RINGS keep
## spreading on the water there, as if from the anchor below. Weighed, it all goes.
## (In Unreal terms: an Actor Component of the boat that spawns and moves a few small meshes.)
##
## It lives on the node `AnchorChain` inside boat.tscn. Everything is made in code (no pictures): the chain is a row of
## small oval rings (TorusMesh "links"), each turned a quarter round the chain from the one before, like a real chain
## (seen from above: a ring, a bar, a ring, a bar…); the ripples are flat thin rings that grow and fade.
## It's `top_level`: it doesn't turn with the boat, it's placed in the world every frame (from where she is drawn,
## her interpolated place, so the chain stays on her bow while she glides between physics steps).
##
## Nothing runs while the anchor is up: `_process` is switched on when it's dropped (the boat's `anchor_dropped`),
## at the start if she's at anchor, and after she comes back home (respawn); it switches itself off when the anchor is
## weighed, she ties up at a pier (no anchor there) or she sinks.

const INK := Color("1b1a17")
const PAPER := Color("ebe7dc")
const MAX_LINKS := 60                 # the most links ever drawn (the chain can't get longer than this × link_step)
const MAX_RIPPLES := 4                # rings on the water at the same time, at most

@export var bow_height := 0.4         # metres above the water where the chain leaves her bow
@export var sag := 0.15               # metres the chain hangs down in its middle (0 = straight)
@export var link_step := 0.26         # metres from one link to the next
@export var link_size := 0.13         # a link's half length (its ring's outer radius), metres
@export var link_thickness := 0.045   # how thick the metal of a link is, metres
@export var ripple_every := 0.9       # seconds between two new rings on the water
@export var ripple_time := 1.6        # seconds a ring takes to spread out and fade
@export var ripple_start := 0.3       # metres: a ring's radius when it appears
@export var ripple_size := 1.6        # metres: its radius at the end
@export var ripple_height := 0.03     # metres above the water (just over it, so the sea doesn't cover it)

var boat: Node3D                      # the boat (this node's parent)
var links: Array[MeshInstance3D] = []
var ripples: Array[MeshInstance3D] = []
var ripple_ages: Array[float] = []    # seconds since each ring appeared (below 0 = not in use)
var next_ripple_in := 0.0             # seconds to the next ring


func _ready() -> void:
	boat = get_parent() as Node3D
	top_level = true                  # placed in the world by hand, not moved or turned with the boat
	global_transform = Transform3D.IDENTITY
	make_links()
	make_ripples()
	show_all(false)
	set_process(false)
	boat.anchor_dropped.connect(start)        # the anchor goes down: show it
	boat.health_changed.connect(_on_health_changed)
	start.call_deferred()                     # she starts at anchor: show it once everything is ready


## The anchor is down (or may be): show the chain and start the rings, if she really is at anchor.
func start() -> void:
	if not is_at_anchor():
		return
	next_ripple_in = 0.0                      # a first ring at once, where it went in
	set_process(true)


## After respawn (she's home again, at anchor) the boat says health_changed: show the anchor again.
func _on_health_changed(_hurt: bool) -> void:
	if not is_processing():
		start()


## Really at anchor: anchored, not tied up at a pier (that's `anchored` too, but no anchor), not going down.
func is_at_anchor() -> bool:
	return boat.anchored and boat.berth == null and not boat.sinking


func _process(dt: float) -> void:
	if not is_at_anchor():
		show_all(false)                       # weighed, tied up or sinking: all gone
		set_process(false)
		return
	# Where her bow is now, as drawn (the interpolated place, so the chain doesn't shake as she glides).
	var drawn := boat.get_global_transform_interpolated()
	var forward := -drawn.basis.z
	var bow: Vector3 = drawn.origin + forward * boat.bow_reach
	bow.y = bow_height
	var anchor: Vector3 = boat.anchor_point
	anchor.y = 0.0
	place_links(bow, anchor)
	update_ripples(dt, anchor)


# ---- the chain ----

## Makes the pool of links once: small rings, the same mesh and material for all.
func make_links() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = link_size - link_thickness
	mesh.outer_radius = link_size
	mesh.rings = 10
	mesh.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = INK
	mesh.material = material
	for i in MAX_LINKS:
		var link := MeshInstance3D.new()
		link.mesh = mesh
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(link)
		links.append(link)


## Puts the links along the chain from the bow down to where the anchor went in. The chain is a straight line that
## hangs down a little in the middle (`sag`, a half sine: 0 at both ends, most in the middle), never below the water
## (the sea would cover it there anyway).
func place_links(bow: Vector3, anchor: Vector3) -> void:
	var length := bow.distance_to(anchor)
	# Which way the chain runs (from the bow to the water); bow right over the anchor: straight down.
	var along := (anchor - bow).normalized()
	if length < 0.01:
		along = Vector3.DOWN
	var count := clampi(int(length / link_step) + 1, 2, MAX_LINKS)
	for i in MAX_LINKS:
		var link := links[i]
		if i >= count:
			link.visible = false
			continue
		link.visible = true
		var share := float(i) / float(count - 1)                 # 0 at the bow, 1 at the water
		var point := bow.lerp(anchor, share)
		point.y = maxf(point.y - sin(share * PI) * sag, 0.0)
		link.global_transform = Transform3D(link_basis(along, i % 2 == 1), point)


## A link's turn: its ring's long side along the chain (stretched 1.6 times that way, so it's an oval), lying flat
## (seen from above: a ring) or, every other link, standing on edge (seen from above: a bar).
func link_basis(along: Vector3, on_edge: bool) -> Basis:
	# Two directions square to the chain: "side" (level) and "up" (as near to up as square to the chain allows).
	var side := along.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT                                     # chain straight down: any level side will do
	side = side.normalized()
	var up := side.cross(along).normalized()
	# The torus's own axis is its y: the ring lies across x and z. Flat link: its axis is "up"; on edge: "side".
	# (The third direction is chosen so the three make a right-handed set, or the ring would be drawn inside out.)
	var axis := side if on_edge else up
	var across := -up if on_edge else side
	return Basis(along * 1.6, axis, across)


# ---- the rings on the water ----

## Makes the pool of rings once: a thin flat ring of radius 1 m, scaled to the size it has grown to.
func make_ripples() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.9
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 4
	for i in MAX_RIPPLES:
		var ring := MeshInstance3D.new()
		ring.mesh = mesh
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Each ring its own material, so each fades on its own.
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = PAPER
		material.render_priority = 1                             # after the sea (like the wake)
		ring.material_override = material
		add_child(ring)
		ripples.append(ring)
		ripple_ages.append(-1.0)


## Every `ripple_every` seconds a new ring appears where the anchor went in; each grows from ripple_start to
## ripple_size over ripple_time, quick at first then slowing (ease out), and fades over its second half.
func update_ripples(dt: float, anchor: Vector3) -> void:
	next_ripple_in -= dt
	if next_ripple_in <= 0.0:
		next_ripple_in = ripple_every
		var free_one := ripple_ages.find(-1.0)
		if free_one == -1:
			free_one = 0                                         # all in use: the oldest-placed one starts again
		ripple_ages[free_one] = 0.0
	for i in MAX_RIPPLES:
		var ring := ripples[i]
		if ripple_ages[i] < 0.0:
			ring.visible = false
			continue
		ripple_ages[i] += dt
		var share := ripple_ages[i] / ripple_time
		if share >= 1.0:
			ripple_ages[i] = -1.0                                # done: free for the next one
			ring.visible = false
			continue
		ring.visible = true
		var eased := 1.0 - pow(1.0 - share, 2.0)
		var radius := lerpf(ripple_start, ripple_size, eased)
		ring.global_transform = Transform3D(Basis().scaled(Vector3(radius, 0.05, radius)),
				Vector3(anchor.x, ripple_height, anchor.z))
		var alpha := clampf((1.0 - share) * 2.0, 0.0, 1.0)       # full for the first half, then fading
		(ring.material_override as StandardMaterial3D).albedo_color = Color(PAPER, alpha)


## Hides (or shows) every link and ring at once.
func show_all(on: bool) -> void:
	for link in links:
		link.visible = on
	for i in MAX_RIPPLES:
		ripples[i].visible = on
		ripple_ages[i] = -1.0
