@tool
extends Node3D
## A PIER: something you place in the world where the boat can tie up.
##
## Its scene (pier.tscn) has:
##   - Mesh: what you see (a plain wooden box for now: swap in your own model);
##   - Berth: the boat's "parking spot", a Node3D you move next to the pier. Its blue arrow (-Z, in the
##     editor) is the way her bow will point once tied up: point it out to sea, so she leaves ready to sail.
##     Inside it, Sensor: a cylinder `dock_radius` metres round the berth (an Area3D, like a Trigger Volume).
##
## When the boat sails into the sensor (not at anchor) she ties up: she glides to the berth and turns to face
## the way its arrow points (boat.gd dock_at). To leave, the player presses the anchor button: she casts off
## and can sail away. She ties up again only after she has left the sensor and comes back.
## In the editor a see-through blue disc shows the radius, and an arrow on the berth shows her heading.
## (In Unreal: an actor with a Static Mesh, a Scene Component as the parking spot and a trigger round it.)

## Sent when the boat has tied up here (a store listens, to open its counter: Assets/Landscape/store).
signal docked(boat: Node3D)

## Metres round the berth within which the boat ties up.
@export var dock_radius := 8:
	set(value):
		dock_radius = value
		_fit_sensor()
		_fit_editor_disc()

@onready var berth: Node3D = $Berth


func _ready() -> void:
	_fit_sensor()
	if Engine.is_editor_hint():
		_make_editor_helpers()
		return
	# The physics engine calls this when the boat's sensor comes in (OnBeginOverlap in Unreal).
	$Berth/Sensor.area_entered.connect(_on_sensor_entered)


## The sensor's cylinder is as wide as dock_radius. (Each pier has its own copy of the shape: local to
## scene in pier.tscn, so changing one pier's radius doesn't change the others'.)
func _fit_sensor() -> void:
	var shape := get_node_or_null("Berth/Sensor/Shape") as CollisionShape3D
	if shape and shape.shape:
		shape.shape.radius = dock_radius


## The boat came within dock_radius: if she's under way (not at anchor), she ties up at the berth.
func _on_sensor_entered(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat == null or not boat.is_in_group("player_boat"):
		return
	if boat.anchored:
		return
	boat.dock_at(berth)
	if boat.berth == berth:          # she really tied up here (dock_at says no while she's sinking, say)
		docked.emit(boat)


# ---------- In the editor only: the radius and the berth's heading ----------
# Made in code with no owner, so they aren't saved in the scene and never appear in the game.

var _editor_disc: MeshInstance3D

func _make_editor_helpers() -> void:
	var see_through := StandardMaterial3D.new()
	see_through.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	see_through.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	see_through.albedo_color = Color(0.2, 0.5, 1.0, 0.25)
	see_through.render_priority = 10    # drawn after the sea and everything else, never hidden by it from afar
	see_through.no_depth_test = true    # and on top of the land, so it can be spotted from anywhere
	# 1. The radius: a flat blue disc round the berth, 1 m across, scaled to dock_radius.
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.05
	disc_mesh.material = see_through
	_editor_disc = MeshInstance3D.new()
	_editor_disc.mesh = disc_mesh
	_editor_disc.position.y = 0.1
	berth.add_child(_editor_disc)
	_fit_editor_disc()
	# 2. The heading: a flat triangle on the berth, its tip along -Z (the way her bow will point).
	#    A PrismMesh has its tip up (+Y); turned -90 degrees round X, the tip points to -Z.
	var arrow_material := see_through.duplicate()
	arrow_material.albedo_color = Color(0.2, 0.5, 1.0, 0.8)
	arrow_material.render_priority = 11   # over its own disc
	var arrow_mesh := PrismMesh.new()
	arrow_mesh.size = Vector3(1.5, 3.0, 0.05)
	arrow_mesh.material = arrow_material
	var arrow := MeshInstance3D.new()
	arrow.mesh = arrow_mesh
	arrow.rotation_degrees.x = -90.0
	arrow.position.y = 0.2
	berth.add_child(arrow)


func _fit_editor_disc() -> void:
	if _editor_disc:
		_editor_disc.scale = Vector3(dock_radius, 1.0, dock_radius)
