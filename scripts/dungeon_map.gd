extends RefCounted

const ROOM_LAYOUT := [
	"1001001",
	"1111111",
	"1111111",
	"1111111",
	"1001001",
]

const EXITS := [Vector2i(0, 0), Vector2i(3, 0), Vector2i(6, 0)]
const SPAWNS := [Vector2i(0, 4), Vector2i(6, 4)]
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func rooms() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(ROOM_LAYOUT.size()):
		for x in range(ROOM_LAYOUT[y].length()):
			if ROOM_LAYOUT[y].substr(x, 1) == "1":
				result.append(Vector2i(x, y))
	return result


static func contains(room: Vector2i) -> bool:
	if room.y < 0 or room.y >= ROOM_LAYOUT.size():
		return false
	if room.x < 0 or room.x >= ROOM_LAYOUT[room.y].length():
		return false
	return ROOM_LAYOUT[room.y].substr(room.x, 1) == "1"


static func neighbors(room: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var next_room: Vector2i = room + direction
		if contains(next_room):
			result.append(next_room)
	return result


static func can_move(from_room: Vector2i, direction: Vector2i) -> bool:
	return neighbors(from_room).has(from_room + direction)


static func next_step(start: Vector2i, destination: Vector2i) -> Vector2i:
	if start == destination or not contains(start) or not contains(destination):
		return start

	var frontier: Array[Vector2i] = [start]
	var parent: Dictionary = {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == destination:
			break
		for next_room in neighbors(current):
			if parent.has(next_room):
				continue
			parent[next_room] = current
			frontier.append(next_room)

	if not parent.has(destination):
		return start

	var step := destination
	while parent[step] != start:
		step = parent[step]
	return step
