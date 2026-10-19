extends Node
## FOG OF WAR: remembers which parts of the map the boat has seen.
##
## This script is an Autoload (Project Settings → Globals → Autoload, name "Fog"), like `Land` and `Wind`.
## (In Unreal: a World Subsystem that keeps the explored map.)
##
## As in the prototype, the map is cut into square cells of CELL metres. A cell is "explored" once the
## boat has come within SIGHT metres of its middle; explored cells stay clear for good.
## The boat calls `Fog.reveal(position)` every frame (boat.gd).
##
## The cells are kept in a tiny picture, `image`: one pixel a cell, white = still in fog, black = seen.
## `texture` is that picture as a texture: the sea's shader (sea.gdshader) reads it, stretched smoothly
## over the whole map, and paints the fogged parts black. (In Unreal: a render target the material reads.)

const CELL := 4.8              # metres a cell, a side (the prototype's 48 px)
const SIGHT := 22.0            # metres of fog cleared round the boat (the prototype's 220 px)

var cells := int(round(Land.WORLD_SIZE / CELL))   # cells a side: 210
var image: Image               # one pixel a cell
var texture: ImageTexture      # the same picture, handed to the sea's shader
var last_pos := Vector3(INF, 0.0, INF)   # where reveal() last did its sums (far away at first, so the first call does)


## Called once, when the game starts: the whole map starts in fog (every pixel white).
func _ready() -> void:
	image = Image.create(cells, cells, false, Image.FORMAT_L8)   # L8 = one grey value a pixel
	image.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(image)


## Clears the fog round this point of the world. Only x and z count.
func reveal(pos: Vector3) -> void:
	# 0. Moved less than a metre since the last time: nothing new can be in sight, skip the sums.
	#    (The boat calls this 60 times a second; the cells are 4.8 m wide.)
	if Vector2(pos.x - last_pos.x, pos.z - last_pos.z).length() < 1.0:
		return
	last_pos = pos
	var changed := false
	# 1. Which cells could be in sight: the ones in the square round the boat, SIGHT metres each way.
	#    Cell (i, j) covers x from -half + i * CELL (home, 0, is the middle of the map).
	var half := Land.WORLD_SIZE / 2.0
	var i_min := int(floor((pos.x - SIGHT + half) / CELL))
	var i_max := int(floor((pos.x + SIGHT + half) / CELL))
	var j_min := int(floor((pos.z - SIGHT + half) / CELL))
	var j_max := int(floor((pos.z + SIGHT + half) / CELL))
	for j in range(j_min, j_max + 1):
		for i in range(i_min, i_max + 1):
			# 2. Skip cells off the map, and the ones already seen.
			if i < 0 or j < 0 or i >= cells or j >= cells:
				continue
			if image.get_pixel(i, j).r < 0.5:
				continue
			# 3. The cell's middle, in metres. Within SIGHT of the boat: now it's seen (black).
			var middle := Vector2((i + 0.5) * CELL - half, (j + 0.5) * CELL - half)
			if middle.distance_to(Vector2(pos.x, pos.z)) <= SIGHT:
				image.set_pixel(i, j, Color.BLACK)
				changed = true
	# 4. Only when something new was seen, send the picture to the graphics card again.
	if changed:
		texture.update(image)
