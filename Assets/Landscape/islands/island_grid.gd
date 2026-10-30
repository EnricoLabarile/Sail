@tool
extends Node
## THE ISLAND GRID (Enrico): an ABSOLUTE grid snap for the island pieces, in the editor. Put on the `Islands` node:
## every piece under it that you move (or drop in from the FileSystem) jumps to the nearest point of a fixed grid,
## every `grid_size` metres, and its turn to the nearest quarter turn. Godot's own snap (the magnet, Y) only snaps
## HOW FAR you move, so a piece that starts off the grid stays off it; this one snaps WHERE it ends up.
## (In Unreal: like the level's grid snap, but absolute, done by an Editor Utility on this one folder of actors.)
##
## Only the selected pieces are looked at (a few each frame, not all of them), and only in the editor: in the game
## this does nothing. Its numbers are in the Inspector when you select `Islands`.
## "Snap all pieces" puts every piece under it on the grid at once (the ones already there don't move).

## The grid's step in metres. 8 = the island pieces' own step (their edges and pivots fall on multiples of 8).
@export var grid_size := 8.0
## Where the grid starts: a point of the grid. The pieces placed so far sit 0.889 m off a plain 8 m grid on z, so the
## level sets that here and nothing already placed moves.
@export var grid_offset := Vector3.ZERO
## Also snap the turn round the vertical to quarter turns (0, 90, 180, 270 degrees).
@export var snap_rotation := true
## Untick to place a piece freely for a moment.
@export var snap_on := true
## The button in the Inspector: every piece under this node on the grid at once.
@export_tool_button("Snap all pieces", "SnapGrid") var snap_all_button := snap_all

const TOLERANCE := 0.001   # closer than this to the grid counts as on it (so tiny float leftovers aren't "moved")


func _process(_dt: float) -> void:
	if not Engine.is_editor_hint() or not snap_on:
		return
	# The nodes selected in the editor right now (the Scene dock's selection).
	var editor = Engine.get_singleton("EditorInterface")
	for node in editor.get_selection().get_selected_nodes():
		if node is Node3D and node.get_parent() == self:
			snap_piece(node)


## Every piece under this node on the grid (the button).
func snap_all() -> void:
	var moved := 0
	for child in get_children():
		if child is Node3D and snap_piece(child):
			moved += 1
	print("Island grid: %d of %d pieces moved onto the grid" % [moved, get_child_count()])


## Puts one piece on the grid (and its turn on a quarter turn). Gives back true if it had to move.
func snap_piece(piece: Node3D) -> bool:
	var moved := false
	# 1. Where it is: x and z to the nearest grid point (counted from grid_offset); its height stays.
	var here := piece.position
	var on_grid := here
	on_grid.x = snappedf(here.x - grid_offset.x, grid_size) + grid_offset.x
	on_grid.z = snappedf(here.z - grid_offset.z, grid_size) + grid_offset.z
	if absf(on_grid.x - here.x) > TOLERANCE or absf(on_grid.z - here.z) > TOLERANCE:
		piece.position = on_grid
		moved = true
	# 2. Its turn round the vertical to the nearest quarter turn (no tilt; its scale stays).
	if snap_rotation:
		var turn := piece.rotation.y
		var quarter := snappedf(turn, PI / 2.0)
		var tilted := absf(piece.rotation.x) > TOLERANCE or absf(piece.rotation.z) > TOLERANCE
		if absf(angle_difference(turn, quarter)) > TOLERANCE or tilted:
			var size := piece.scale
			piece.rotation = Vector3(0.0, quarter, 0.0)
			piece.scale = size
			moved = true
	return moved
