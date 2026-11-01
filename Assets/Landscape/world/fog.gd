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
##
## The soft edge (Enrico, Nov 2026, for speed): with a `falloff` (sea.gd's fog_falloff, metres), the picture sent
## to the graphics card is a blurred copy, `soft`, worked out here only round the cells that just changed. The fog
## shader then reads it once a pixel; before, it averaged 9 reads a pixel, every frame, over the whole screen.

const CELL := 4.8              # metres a cell, a side (the prototype's 48 px)
const SIGHT := 35.0            # metres of fog cleared round the boat (the prototype's 220 px)

var cells := int(round(Land.WORLD_SIZE / CELL))   # cells a side: 210
var image: Image               # one pixel a cell
var texture: ImageTexture      # the same picture, handed to the sea's shader
var last_pos := Vector3(INF, 0.0, INF)   # where reveal() last did its sums (far away at first, so the first call does)
var falloff := 0.0             # metres of soft edge (set by sea.gd with set_falloff); 0 = the picture as it is
var seen := PackedByteArray()  # the truth, a byte a cell (row after row): 255 = fog, 0 = seen
var soft := PackedByteArray()  # the blurred copy that goes to the graphics card (the same as seen with no falloff)
var seen_box := Rect2i()       # every cell seen so far lies in this box (empty = none): only it needs blurring
# The blur's recipe (make_kernel), one entry per neighbouring cell: its column and row offset and its share.
var kernel_di := PackedInt32Array([0])
var kernel_dj := PackedInt32Array([0])
var kernel_share := PackedFloat32Array([1.0])
var kernel_reach := 0          # how many cells the recipe reaches out, any way


## Called once, when the game starts: the whole map starts in fog (every pixel white).
func _ready() -> void:
	seen.resize(cells * cells)
	seen.fill(255)
	soft = seen.duplicate()
	image = Image.create_from_data(cells, cells, false, Image.FORMAT_L8, soft)   # L8 = one grey value a pixel
	texture = ImageTexture.create_from_image(image)


## How soft the fog's edge is, in metres (sea.gd sends its fog_falloff at start and when it changes).
## The recipe of the blur (`kernel`) and the whole blurred copy are worked out again (only now, not while sailing).
func set_falloff(metres: float) -> void:
	falloff = metres
	make_kernel()
	# Only round what's been seen can the blur change anything (the rest is all fog, and stays 255).
	soft = seen.duplicate()
	if seen_box.has_area():
		var margin := kernel_reach            # as far as the blur reaches
		soften(seen_box.position.x - margin, seen_box.end.x + margin, seen_box.position.y - margin, seen_box.end.y + margin)
	send_picture()


## The blur's recipe, as the fog shader did it: a cell's soft value is the average of the fog at its middle and at
## 8 points round it, `falloff` metres away (45° apart), each read smoothly between the 4 cells round it. That always
## comes down to the same share of each neighbouring cell, so the shares are added up once here:
## kernel_di / kernel_dj / kernel_share list them. (In Unreal terms: a blur kernel, baked once.)
func make_kernel() -> void:
	var shares := {}                        # Vector2i offset -> share
	var reach := falloff / CELL             # the ring's size, in cells
	var points := [Vector2.ZERO]            # the middle, then the 8 points of the ring
	if reach > 0.0:
		for k in 8:
			var a := k * PI / 4.0
			points.append(Vector2(cos(a), sin(a)) * reach)
	for p: Vector2 in points:
		# The 4 cells round this point and how much each counts (smooth "linear" reading).
		var i0 := int(floor(p.x))
		var j0 := int(floor(p.y))
		var fx: float = p.x - i0
		var fy: float = p.y - j0
		var corners := [[0, 0, (1.0 - fx) * (1.0 - fy)], [1, 0, fx * (1.0 - fy)], [0, 1, (1.0 - fx) * fy], [1, 1, fx * fy]]
		for c in corners:
			if c[2] <= 0.0:
				continue
			var key := Vector2i(i0 + c[0], j0 + c[1])
			shares[key] = shares.get(key, 0.0) + c[2] / points.size()
	kernel_di.clear()
	kernel_dj.clear()
	kernel_share.clear()
	kernel_reach = 0
	for key: Vector2i in shares:
		kernel_di.append(key.x)
		kernel_dj.append(key.y)
		kernel_share.append(shares[key])
		kernel_reach = maxi(kernel_reach, maxi(absi(key.x), absi(key.y)))


## Sends the blurred copy to the graphics card.
func send_picture() -> void:
	image.set_data(cells, cells, false, Image.FORMAT_L8, soft)
	texture.update(image)


## Works out the blurred copy for the cells from column i_min to i_max and row j_min to j_max, with the kernel.
## Off the map a neighbour counts as the nearest cell on the edge.
func soften(i_min: int, i_max: int, j_min: int, j_max: int) -> void:
	var count := kernel_share.size()
	for j in range(maxi(j_min, 0), mini(j_max, cells - 1) + 1):
		for i in range(maxi(i_min, 0), mini(i_max, cells - 1) + 1):
			var total := 0.0
			var inside := i >= kernel_reach and j >= kernel_reach and i < cells - kernel_reach and j < cells - kernel_reach
			for k in count:
				var ii := i + kernel_di[k]
				var jj := j + kernel_dj[k]
				if not inside:                  # near the map's edge: keep to the map
					ii = clampi(ii, 0, cells - 1)
					jj = clampi(jj, 0, cells - 1)
				total += seen[jj * cells + ii] * kernel_share[k]
			soft[j * cells + i] = int(round(total))


## Clears the fog round this point of the world. Only x and z count.
func reveal(pos: Vector3) -> void:
	# 0. Moved less than a metre since the last time: nothing new can be in sight, skip the sums.
	#    (The boat calls this 60 times a second; the cells are 4.8 m wide.)
	if Vector2(pos.x - last_pos.x, pos.z - last_pos.z).length() < 1.0:
		return
	last_pos = pos
	var changed := false
	var box := Rect2i()                     # the cells that just changed (for the blur)
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
			if seen[j * cells + i] == 0:
				continue
			# 3. The cell's middle, in metres. Within SIGHT of the boat: now it's seen (black).
			var middle := Vector2((i + 0.5) * CELL - half, (j + 0.5) * CELL - half)
			if middle.distance_to(Vector2(pos.x, pos.z)) <= SIGHT:
				seen[j * cells + i] = 0
				box = Rect2i(i, j, 1, 1) if not changed else box.merge(Rect2i(i, j, 1, 1))
				seen_box = Rect2i(i, j, 1, 1) if not seen_box.has_area() else seen_box.merge(Rect2i(i, j, 1, 1))
				changed = true
	# 4. Only when something new was seen: blur again the cells that changed and the ones round them (as far as
	#    the ring reaches), then send the picture to the graphics card.
	if changed:
		var margin := kernel_reach            # as far as the blur reaches
		soften(box.position.x - margin, box.end.x + margin, box.position.y - margin, box.end.y + margin)
		send_picture()
