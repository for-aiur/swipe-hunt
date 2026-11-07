extends RefCounted

const HUNTER := [
	".....HH.......",
	"....HGGH......",
	"....HGGH......",
	".....HH.......",
	"..BBBBBB......",
	"..BTTBBR......",
	"..BBBBBB......",
	"...BBBB.......",
	"...B..B.......",
	"...K..K.......",
	"...K..K.......",
	"..KK..KK......",
	"..KK..KK......",
	"...SSSS.......",
	"...SSSS.......",
]

const CREATURE := [
	"...HH..HH...",
	"..HBB..BBH..",
	".HBBBBBBBBH.",
	"HBBRRBBRRBBH",
	"HBBBBBBBBBBH",
	".HBBBBBBBBH.",
	"..HBBBBBBH..",
	"...HBBBBH...",
	"..HBBSSBBH..",
	".HBBSSSSBBH.",
	"HBBSSSSSSBBH",
	".HBBSSSSBBH.",
	"..HH....HH..",
	".HH......HH.",
]

const HUNTER_PALETTE := {
	"H": Color("9a8c77"),
	"G": Color("dec4a0"),
	"B": Color("302834"),
	"T": Color("c59758"),
	"R": Color("a44943"),
	"K": Color("171519"),
	"S": Color("0c0a0d"),
}

const CREATURE_PALETTE := {
	"H": Color("a68d69"),
	"B": Color("3a252b"),
	"R": Color("f07750"),
	"S": Color("171015"),
}

static func draw_sprite(canvas: CanvasItem, sprite: Array, center: Vector2, pixel_size: float, direction: Vector2, palette: Dictionary) -> void:
	var facing_angle := Vector2.UP.angle_to(direction.normalized())
	var width: int = sprite[0].length()
	var height := sprite.size()
	for y in range(height):
		var row: String = sprite[y]
		for x in range(width):
			var code := row.substr(x, 1)
			if not palette.has(code):
				continue
			var local := Vector2((float(x) - float(width - 1) * 0.5) * pixel_size, (float(y) - float(height - 1) * 0.5) * pixel_size)
			var top_left := _snap(center + local.rotated(facing_angle) - Vector2.ONE * pixel_size * 0.5, pixel_size)
			canvas.draw_rect(Rect2(top_left, Vector2.ONE * pixel_size), palette[code], true)


static func draw_pixel_line(canvas: CanvasItem, start: Vector2, end: Vector2, pixel_size: float, color: Color, thickness: int = 1) -> void:
	var distance := start.distance_to(end)
	var steps := maxi(1, int(ceil(distance / pixel_size)))
	for index in range(steps + 1):
		var position := start.lerp(end, float(index) / float(steps))
		var top_left := _snap(position, pixel_size)
		for offset in range(thickness):
			canvas.draw_rect(Rect2(top_left + Vector2(offset, offset) * pixel_size, Vector2.ONE * pixel_size), color, true)


static func _snap(position: Vector2, pixel_size: float) -> Vector2:
	return Vector2(round(position.x / pixel_size), round(position.y / pixel_size)) * pixel_size
