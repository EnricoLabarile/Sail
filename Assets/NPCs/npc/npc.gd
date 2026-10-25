@tool
@icon("res://Assets/NPCs/npc/npc_icon.svg")
extends Node3D
## AN NPC you can talk to. Not drawn yet (Enrico: the look comes later): this node is its place, its pivot.
##
## How it works:
##   1. the boat comes within `talk_radius`: a speech bubble fades in above it and bobs up and down, to catch
##      the eye; she sails away without stopping: it fades out and nothing happens;
##   2. she drops anchor inside the radius: the talk starts. The talk box at the top of the screen
##      (Assets/UI/talk_box) shows `portrait`, `speaker_name` and the `lines`, one page at a time, typed out
##      letter by letter; a quick tap on the wheel's hub (the anchor button) goes on to the next page;
##   3. after the last page a tap closes it. Dropping anchor here again starts it again from the top.
## It's a monologue: the player only reads and taps, no choices.
##
## To place one: instance npc.tscn under NPCs in Overworld (like placing a Blueprint), move it, and fill in
## the Inspector: its name, its portrait and its lines (each entry of `lines` is one page; inside a page you can
## go to a new line as often as you like). In the editor a disc shows `talk_radius`.
## (In Unreal: an actor with a sphere trigger and a widget popping up over it, plus the dialogue data on it.)

## The name shown in the talk box.
@export var speaker_name := "Stranger"
## The picture in the talk box's frame, on the left (paint your own; any size, it's fitted into the frame).
@export var portrait: Texture2D
## What it says: each entry is one page, shown one after the other (a tap on the hub for the next).
@export_multiline var lines: Array[String] = ["Hello, sailor."]
## How close the boat must come, in metres, for the bubble to show and for the anchor to start the talk.
@export var talk_radius := 8.0:
	set(value):
		talk_radius = value
		_fit_radius()

@export var bob_height := 0.4      # metres the bubble goes up and down
@export var bob_speed := 1.5       # bobs a second
@export var fade_time := 0.3       # seconds to fade in or out

var boat_near := false             # is the boat inside talk_radius now?
var talking := false               # is the talk box showing this NPC's lines now?
var bubble_alpha := 0.0            # 0 = bubble hidden, 1 = fully shown
var bubble_rest_y := 0.0           # the bubble's height as placed in npc.tscn (it bobs round it)
var time := 0.0

@onready var bubble: MeshInstance3D = $Bubble
@onready var sensor: Area3D = $Sensor


func _ready() -> void:
	_fit_radius()
	bubble_rest_y = bubble.position.y
	if Engine.is_editor_hint():
		_make_editor_disc()
		return
	bubble.material_override = bubble.material_override.duplicate()   # its own copy: each NPC fades on its own
	_set_bubble_alpha(0.0)
	# The boat's SpotSensor (a small Area3D on the "sensors" layer) entering or leaving the radius tells us,
	# as with the fishing spots: no checks every frame.
	sensor.area_entered.connect(_on_sensor_entered)
	sensor.area_exited.connect(_on_sensor_exited)
	# When the anchor goes down (boat.gd sends anchor_dropped), see if it was inside our radius.
	_listen_to_boat.call_deferred()


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	# The bubble shows while the boat is near and no talk is going on; it fades in and out.
	var want := 1.0 if (boat_near and not talking) else 0.0
	bubble_alpha = move_toward(bubble_alpha, want, dt / fade_time)
	if bubble_alpha <= 0.0:
		bubble.visible = false
		return
	bubble.visible = true
	_set_bubble_alpha(bubble_alpha)
	# Bob up and down: sin goes smoothly from -1 to 1 and back, bob_speed times a second.
	time += dt
	bubble.position.y = bubble_rest_y + sin(time * bob_speed * TAU) * bob_height


# ---- the boat ----

func _listen_to_boat() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat:
		boat.anchor_dropped.connect(_on_anchor_dropped)


func _on_sensor_entered(area: Area3D) -> void:
	var boat := area.get_parent()
	if boat != null and boat.is_in_group("player_boat"):
		boat_near = true
		boat.set_near_npc(self, true)     # the wheel's hub shows the speech bubble


func _on_sensor_exited(area: Area3D) -> void:
	var boat := area.get_parent()
	if boat != null and boat.is_in_group("player_boat"):
		boat_near = false
		boat.set_near_npc(self, false)


## The anchor went down somewhere: if it was inside our radius, start talking.
func _on_anchor_dropped() -> void:
	if not boat_near or talking or lines.is_empty():
		return
	var talk_box := get_tree().get_first_node_in_group("talk_box")
	if talk_box == null:
		return
	talking = true
	talk_box.open(speaker_name, portrait, lines, _on_talk_finished)


## The talk box was closed after the last page: the bubble may show again.
func _on_talk_finished() -> void:
	talking = false


# ---- helpers ----

func _set_bubble_alpha(alpha: float) -> void:
	var material: StandardMaterial3D = bubble.material_override
	material.albedo_color.a = alpha


## The sensor's cylinder (and the editor's disc) follow talk_radius.
func _fit_radius() -> void:
	var shape_node := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape_node and shape_node.shape is CylinderShape3D:
		shape_node.shape.radius = talk_radius
	if _editor_disc:
		_editor_disc.scale = Vector3(talk_radius, 1.0, talk_radius)


# ---------- In the editor only: talk_radius drawn as a disc on the water ----------

var _editor_disc: MeshInstance3D

func _make_editor_disc() -> void:
	# A flat yellow cylinder, see-through, 1 m across, scaled to the radius. Made in code with no owner, so it's
	# not saved in the scene and never appears in the game.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.82, 0.4, 0.3)
	material.render_priority = 10       # drawn after the sea and everything else, never hidden by it from afar
	material.no_depth_test = true       # and on top of the land, so it can be spotted from anywhere
	mesh.material = material
	_editor_disc = MeshInstance3D.new()
	_editor_disc.mesh = mesh
	_editor_disc.position.y = 0.1
	add_child(_editor_disc)
	_fit_radius()
