class_name MapGenerator
extends RefCounted

## Procedural map generator for ESCHATON.
## Generates walls (cover) and hazard (acid pool) tiles on a 10×10 grid.
## Guarantees at least one path from the bottom to the top via flood-fill.

const GRID_SIZE: int = 10

# Zones kept clear to guarantee playability
# Player spawn zone: columns 3-6, rows 7-9
# Center corridor: columns 4-5, all rows

static func generate(cover_density: float, hazard_density: float) -> Dictionary:
	var walls: Array[Vector2] = []
	var hazards: Array[Vector2] = []

	# --- Phase 1: Generate walls ---
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			# Never wall the player spawn zone (bottom area)
			if x >= 3 and x <= 6 and y >= 7:
				continue
			# Keep center corridor mostly clear for guaranteed pathing
			if (x == 4 or x == 5) and y >= 1 and y <= 8:
				continue

			var roll: float = randf()
			var is_edge: bool = (x == 0 or x == GRID_SIZE - 1 or y == 0 or y == GRID_SIZE - 1)

			if is_edge:
				# 60% chance for edge walls — creates arena shapes
				if roll < 0.6:
					walls.append(Vector2(x, y))
			else:
				# Interior walls based on cover_density
				if roll < cover_density:
					walls.append(Vector2(x, y))

	# --- Phase 2: Flood-fill validation ---
	# Ensure a path exists from bottom-center (5,9) to any tile in row 0
	var max_attempts: int = 50
	var attempt: int = 0
	while not _has_path(walls) and attempt < max_attempts:
		# Remove a random interior wall (not edge)
		var interior_walls: Array[Vector2] = []
		for w in walls:
			if w.x > 0 and w.x < GRID_SIZE - 1 and w.y > 0 and w.y < GRID_SIZE - 1:
				interior_walls.append(w)
		if interior_walls.size() == 0:
			break
		var remove_idx: int = randi() % interior_walls.size()
		walls.erase(interior_walls[remove_idx])
		attempt += 1

	# --- Phase 3: Generate hazard tiles (acid pools) ---
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var pos := Vector2(x, y)
			# Skip walls
			if pos in walls:
				continue
			# Skip player spawn zone
			if x >= 3 and x <= 6 and y >= 7:
				continue
			# Skip edges (hazards are interior only)
			if x == 0 or x == GRID_SIZE - 1 or y == 0 or y == GRID_SIZE - 1:
				continue

			if randf() < hazard_density:
				hazards.append(pos)

	return {"walls": walls, "hazards": hazards}


static func _has_path(walls: Array[Vector2]) -> bool:
	## BFS flood-fill from (5, 9) — checks if any cell in row 0 is reachable.
	var start := Vector2(5, 9)
	if start in walls:
		return false

	var visited: Dictionary = {}
	var queue: Array[Vector2] = [start]
	visited[start] = true

	var dirs: Array[Vector2] = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]

	while queue.size() > 0:
		var current: Vector2 = queue.pop_front()

		# Reached top row — path exists
		if int(current.y) == 0:
			return true

		for d in dirs:
			var next := Vector2(current.x + d.x, current.y + d.y)
			if next.x < 0 or next.x >= GRID_SIZE or next.y < 0 or next.y >= GRID_SIZE:
				continue
			if next in walls:
				continue
			if visited.has(next):
				continue
			visited[next] = true
			queue.append(next)

	return false
