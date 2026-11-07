extends Node2D

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const PixelArt := preload("res://scripts/pixel_art.gd")

const BACKGROUND := Color("0b090c")
const FLOOR_DARK := Color("21191b")
const FLOOR_A := Color("302426")
const FLOOR_B := Color("39292a")
const WALL := Color("171316")
const WALL_HIGHLIGHT := Color("493638")
const BRASS := Color("d7a457")
const BLOOD := Color("b74640")
const PALE := Color("e7d2ad")
const ROUND_SETUP := [
	{"spawn": Vector2i(0, 4), "goal": Vector2i(6, 0), "player": Vector2i(3, 2), "exits": [Vector2i(0, 0), Vector2i(6, 0)]},
	{"spawn": Vector2i(6, 4), "goal": Vector2i(0, 0), "player": Vector2i(3, 2), "exits": [Vector2i(0, 0), Vector2i(6, 0)]},
	{"spawn": Vector2i(0, 4), "goal": Vector2i(6, 0), "player": Vector2i(3, 3), "exits": [Vector2i(0, 0), Vector2i(6, 0)]},
	{"spawn": Vector2i(6, 4), "goal": Vector2i(0, 0), "player": Vector2i(3, 1), "exits": [Vector2i(0, 0), Vector2i(6, 0)]},
]
const CREATURE_STEP_SECONDS := 3.1
const BREADCRUMB_SECONDS := 9.0
const COUNTDOWN_SECONDS := 2.5

enum RunState { READY, COUNTDOWN, PLAYING, CAUGHT, ESCAPED }

var run_state := RunState.READY
var player_room := Vector2i(3, 2)
var creature_room := Vector2i.ZERO
var creature_goal := Vector2i.ZERO
var round_exits: Array = []
var breadcrumb_age: Dictionary = {}
var breadcrumb_direction: Dictionary = {}
var last_setup_index := -1
var rng := RandomNumberGenerator.new()
var touch_start := Vector2.ZERO
var touch_active := false
var player_facing := Vector2.UP
var impact_direction := Vector2.ZERO
var stun_remaining := 0.0
var attack_remaining := 0.0
var pending_catch := false
var creature_flash_remaining := 0.0
var countdown_remaining := 0.0
var creature_step_remaining := CREATURE_STEP_SECONDS
var round_elapsed := 0.0
var round_number := 0
var player_steps := 0
var animation_clock := 0.0
var last_feedback := "TAP TO BEGIN THE HUNT"
var last_feedback_color := PALE


func _ready() -> void:
	rng.randomize()
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _process(delta: float) -> void:
	var changed := false
	animation_clock += delta
	if stun_remaining > 0.0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
		if stun_remaining == 0.0:
			last_feedback = "YOU FIND YOUR FEET"
			last_feedback_color = PALE
		changed = true
	if attack_remaining > 0.0:
		attack_remaining = maxf(0.0, attack_remaining - delta)
		changed = true
		if attack_remaining == 0.0 and pending_catch:
			pending_catch = false
			_finish_round(RunState.CAUGHT)
	if creature_flash_remaining > 0.0:
		creature_flash_remaining = maxf(0.0, creature_flash_remaining - delta)
		changed = true
	if run_state == RunState.COUNTDOWN:
		countdown_remaining -= delta
		if countdown_remaining <= 0.0:
			run_state = RunState.PLAYING
			creature_step_remaining = CREATURE_STEP_SECONDS
			last_feedback = "THE RUNNER IS LOOSE"
			last_feedback_color = BLOOD
		changed = true
	elif run_state == RunState.PLAYING:
		var prior_second := int(round_elapsed)
		round_elapsed += delta
		if int(round_elapsed) != prior_second:
			changed = true
		if not pending_catch:
			creature_step_remaining -= delta
			if creature_step_remaining <= 0.0:
				creature_step_remaining += CREATURE_STEP_SECONDS
				_move_creature()
	for room in breadcrumb_age.keys():
		breadcrumb_age[room] = float(breadcrumb_age[room]) - delta
		if breadcrumb_age[room] <= 0.0:
			breadcrumb_age.erase(room)
			breadcrumb_direction.erase(room)
			changed = true
	if animation_clock >= 0.18:
		animation_clock = 0.0
		changed = true
	if changed:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			touch_active = true
		elif touch_active:
			_finish_pointer_gesture(event.position)
			touch_active = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_start = event.position
			touch_active = true
		elif touch_active:
			_finish_pointer_gesture(event.position)
			touch_active = false
	elif event is InputEventKey and event.pressed and not event.echo:
		if run_state != RunState.PLAYING:
			if run_state != RunState.COUNTDOWN and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_R):
				_start_round()
			return
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			_move_player(Vector2i.UP)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_move_player(Vector2i.RIGHT)
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_move_player(Vector2i.DOWN)
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_move_player(Vector2i.LEFT)
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_attack()


func _finish_pointer_gesture(end_position: Vector2) -> void:
	var delta := end_position - touch_start
	if run_state == RunState.READY or run_state == RunState.CAUGHT or run_state == RunState.ESCAPED:
		if delta.length() < 32.0:
			_start_round()
		return
	if run_state != RunState.PLAYING:
		return
	var usable := _usable_rect()
	var threshold := maxf(28.0, minf(usable.size.x, usable.size.y) * 0.07)
	if delta.length() < threshold:
		_attack()
	elif absf(delta.x) > absf(delta.y):
		_move_player(Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT)
	else:
		_move_player(Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP)


func _start_round() -> void:
	var setup_index := rng.randi_range(0, ROUND_SETUP.size() - 1)
	if ROUND_SETUP.size() > 1 and setup_index == last_setup_index:
		setup_index = (setup_index + 1 + rng.randi_range(0, ROUND_SETUP.size() - 2)) % ROUND_SETUP.size()
	last_setup_index = setup_index
	var setup: Dictionary = ROUND_SETUP[setup_index]
	round_number += 1
	player_room = setup["player"]
	creature_room = setup["spawn"]
	creature_goal = setup["goal"]
	round_exits = setup["exits"]
	player_facing = Vector2.UP
	player_steps = 0
	round_elapsed = 0.0
	creature_step_remaining = CREATURE_STEP_SECONDS
	countdown_remaining = COUNTDOWN_SECONDS
	stun_remaining = 0.0
	attack_remaining = 0.0
	pending_catch = false
	creature_flash_remaining = 0.0
	impact_direction = Vector2.ZERO
	breadcrumb_age.clear()
	breadcrumb_direction.clear()
	last_feedback = "THE RUNNER HAS A HEAD START"
	last_feedback_color = BLOOD
	run_state = RunState.COUNTDOWN
	queue_redraw()


func _move_player(direction: Vector2i) -> void:
	if run_state != RunState.PLAYING or stun_remaining > 0.0 or pending_catch:
		return
	player_facing = Vector2(direction)
	if DungeonMap.can_move(player_room, direction):
		player_room += direction
		player_steps += 1
		impact_direction = Vector2.ZERO
		if player_room == creature_room:
			last_feedback = "THE RUNNER IS HERE · TAP TO STRIKE"
			last_feedback_color = BRASS
		else:
			last_feedback = "FOLLOW THE FRESH PRINTS"
			last_feedback_color = PALE
	else:
		impact_direction = Vector2(direction)
		stun_remaining = 0.55
		last_feedback = "STONE REJECTS YOU"
		last_feedback_color = BLOOD
	queue_redraw()


func _attack() -> void:
	if run_state != RunState.PLAYING or stun_remaining > 0.0 or attack_remaining > 0.0:
		return
	attack_remaining = 0.42
	if player_room == creature_room:
		pending_catch = true
		creature_flash_remaining = 0.42
		last_feedback = "A CLEAN STRIKE"
		last_feedback_color = BRASS
	else:
		last_feedback = "NO TARGET · READ THE PRINTS"
		last_feedback_color = PALE
	queue_redraw()


func _move_creature() -> void:
	if run_state != RunState.PLAYING:
		return
	var next_room: Vector2i = DungeonMap.next_step(creature_room, creature_goal)
	if next_room == creature_room:
		_finish_round(RunState.ESCAPED)
		return
	var direction := next_room - creature_room
	breadcrumb_age[creature_room] = BREADCRUMB_SECONDS
	breadcrumb_direction[creature_room] = direction
	creature_room = next_room
	if creature_room == player_room:
		last_feedback = "IT'S IN THIS CHAMBER · STRIKE"
		last_feedback_color = BRASS
	elif round_exits.has(creature_room):
		_finish_round(RunState.ESCAPED)
		return
	queue_redraw()


func _finish_round(result: int) -> void:
	run_state = result
	if result == RunState.CAUGHT:
		last_feedback = "THE RUNNER IS CAUGHT"
		last_feedback_color = BRASS
	else:
		last_feedback = "THE RUNNER ESCAPED"
		last_feedback_color = BLOOD
	queue_redraw()


func _usable_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return viewport_rect
	var window_position := DisplayServer.window_get_position()
	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return viewport_rect
	var safe_window := Rect2i(window_position, window_size).intersection(safe_area)
	if safe_window.size.x <= 0 or safe_window.size.y <= 0:
		return viewport_rect
	var viewport_scale := Vector2(viewport_rect.size) / Vector2(window_size)
	var offset := Vector2(safe_window.position - window_position) * viewport_scale
	var size := Vector2(safe_window.size) * viewport_scale
	return Rect2(viewport_rect.position + offset, size)


func _draw() -> void:
	var viewport := get_viewport_rect()
	draw_rect(viewport, BACKGROUND, true)
	var usable := _usable_rect()
	var margin := clampf(minf(usable.size.x, usable.size.y) * 0.04, 12.0, 28.0)
	var room := usable.grow(-margin)
	var pixel_size := maxf(2.0, floorf(minf(room.size.x, room.size.y) / 96.0))
	_draw_pixel_room(room, pixel_size)
	_draw_doors(room, pixel_size)
	_draw_breadcrumb(room, pixel_size)
	_draw_exit_warning(room, pixel_size)
	_draw_hud(usable, pixel_size)
	_draw_hunter(room, pixel_size)
	_draw_creature(room, pixel_size)
	_draw_sword_swing(room, pixel_size)
	_draw_wall_impact(room, pixel_size)
	_draw_round_overlay(usable, pixel_size)


func _draw_pixel_room(room: Rect2, pixel_size: float) -> void:
	var cell_size := pixel_size * 5.0
	var columns := int(floor(room.size.x / cell_size))
	var rows := int(floor(room.size.y / cell_size))
	var floor_size := Vector2(columns, rows) * cell_size
	var origin := Vector2(floor((room.get_center().x - floor_size.x * 0.5) / pixel_size), floor((room.get_center().y - floor_size.y * 0.5) / pixel_size)) * pixel_size
	for row in range(rows):
		var corner_cut := 2 - mini(row, rows - 1 - row)
		draw_rect(Rect2(origin + Vector2(corner_cut * cell_size, row * cell_size), Vector2((columns - corner_cut * 2) * cell_size, cell_size)), WALL, true)
		for column in range(columns):
			if (row < 2 or row >= rows - 2) and (column < corner_cut or column >= columns - corner_cut):
				continue
			var tile_position := origin + Vector2(column, row) * cell_size
			var edge := row == 0 or row == rows - 1 or column == 0 or column == columns - 1
			var variation := posmod(column * 5 + row * 3 + player_room.x * 2 + player_room.y, 3)
			var tile_color := WALL_HIGHLIGHT if edge else FLOOR_DARK
			if not edge and variation == 1:
				tile_color = FLOOR_A
			elif not edge and variation == 2:
				tile_color = FLOOR_B
			draw_rect(Rect2(tile_position + Vector2.ONE * pixel_size, Vector2.ONE * (cell_size - pixel_size * 1.5)), tile_color, true)
			if edge:
				draw_rect(Rect2(tile_position + Vector2.ONE * pixel_size, Vector2(cell_size - pixel_size, pixel_size)), Color("685047"), true)
			elif variation == 0:
				var chip := tile_position + Vector2(cell_size * 0.62, cell_size * 0.58)
				draw_rect(Rect2(chip, Vector2.ONE * pixel_size), Color("493638"), true)
	_draw_floor_seal(room, pixel_size)
	_draw_pixel_torches(room, pixel_size)


func _draw_floor_seal(room: Rect2, pixel_size: float) -> void:
	var center := room.get_center()
	for offset in range(5, 0, -1):
		var radius := pixel_size * float(offset) * 4.0
		for step in range(8):
			var point := center + Vector2(cos(TAU * float(step) / 8.0), sin(TAU * float(step) / 8.0)) * radius
			draw_rect(Rect2(_snap_pixel(point, pixel_size), Vector2.ONE * pixel_size), Color("70513a", 0.35), true)
	for point in [Vector2(-2, 0), Vector2(-1, -1), Vector2(0, -2), Vector2(1, -1), Vector2(2, 0), Vector2(1, 1), Vector2(0, 2), Vector2(-1, 1)]:
		draw_rect(Rect2(_snap_pixel(center + point * pixel_size * 2.0, pixel_size), Vector2.ONE * pixel_size), Color("936a43"), true)


func _draw_pixel_torches(room: Rect2, pixel_size: float) -> void:
	var positions := [
		Vector2(room.position.x + room.size.x * 0.12, room.position.y + room.size.y * 0.12),
		Vector2(room.end.x - room.size.x * 0.12, room.position.y + room.size.y * 0.12),
		Vector2(room.position.x + room.size.x * 0.12, room.end.y - room.size.y * 0.12),
		Vector2(room.end.x - room.size.x * 0.12, room.end.y - room.size.y * 0.12),
	]
	var flicker := int(animation_clock * 10.0) % 2
	for position in positions:
		var snapped := _snap_pixel(position, pixel_size)
		for glow_step in range(3, 0, -1):
			draw_rect(Rect2(snapped + Vector2(-glow_step, -glow_step) * pixel_size, Vector2.ONE * pixel_size * float(glow_step * 2 + 1)), Color(BRASS, 0.025 * float(4 - glow_step)), true)
		draw_rect(Rect2(snapped, Vector2.ONE * pixel_size * 2.0), Color("33231c"), true)
		draw_rect(Rect2(snapped + Vector2(0, -pixel_size * float(2 + flicker)), Vector2.ONE * pixel_size), Color("f2bf69"), true)
		draw_rect(Rect2(snapped + Vector2(pixel_size, -pixel_size * float(1 + flicker)), Vector2.ONE * pixel_size), Color("fff0b4"), true)


func _draw_doors(room: Rect2, pixel_size: float) -> void:
	var cell_size := pixel_size * 5.0
	var center := room.get_center()
	for direction_index in range(DungeonMap.DIRECTIONS.size()):
		var direction: Vector2i = DungeonMap.DIRECTIONS[direction_index]
		var neighbor: Vector2i = player_room + direction
		var is_path := DungeonMap.contains(neighbor)
		var is_exit := round_exits.has(player_room + direction) and is_path
		var is_exit_room: bool = round_exits.has(player_room) and direction == Vector2i.UP
		if is_exit_room:
			is_path = true
			is_exit = true
		var gap_half := cell_size * 1.35
		var wall_depth := cell_size * 2.0
		var marker_color := BRASS if is_exit else (Color("b58554") if is_path else Color("554346"))
		if direction == Vector2i.UP or direction == Vector2i.DOWN:
			var y := room.position.y if direction == Vector2i.UP else room.end.y - wall_depth
			var opening := Rect2(Vector2(center.x - gap_half, y), Vector2(gap_half * 2.0, wall_depth))
			if is_path:
				draw_rect(opening, BACKGROUND, true)
				for side in [-1.0, 1.0]:
					var post := Vector2(center.x + side * gap_half, y)
					draw_rect(Rect2(post, Vector2(pixel_size * 2.0, wall_depth)), marker_color, true)
				_draw_passage_chevron(Vector2(center.x, y + (wall_depth * 0.66 if direction == Vector2i.UP else wall_depth * 0.32)), direction, pixel_size, marker_color)
			else:
				draw_rect(Rect2(Vector2(center.x - gap_half, y), Vector2(gap_half * 2.0, pixel_size)), Color("49363a"), true)
		else:
			var x := room.position.x if direction == Vector2i.LEFT else room.end.x - wall_depth
			var opening := Rect2(Vector2(x, center.y - gap_half), Vector2(wall_depth, gap_half * 2.0))
			if is_path:
				draw_rect(opening, BACKGROUND, true)
				for side in [-1.0, 1.0]:
					var post := Vector2(x, center.y + side * gap_half)
					draw_rect(Rect2(post, Vector2(wall_depth, pixel_size * 2.0)), marker_color, true)
				_draw_passage_chevron(Vector2(x + (wall_depth * 0.66 if direction == Vector2i.LEFT else wall_depth * 0.32), center.y), direction, pixel_size, marker_color)
			else:
				draw_rect(Rect2(Vector2(x, center.y - gap_half), Vector2(pixel_size, gap_half * 2.0)), Color("49363a"), true)
		if is_exit:
			var badge := center + Vector2(direction) * cell_size * 3.7
			_draw_pixel_text("EXIT", badge - Vector2(pixel_size * 6.0, -pixel_size * 2.0), pixel_size, BRASS)


func _draw_passage_chevron(position: Vector2, direction: Vector2i, pixel_size: float, color: Color) -> void:
	var forward := Vector2(direction)
	var side := Vector2(-forward.y, forward.x)
	for layer in range(3):
		var point := _snap_pixel(position + forward * pixel_size * float(layer), pixel_size)
		for wing in [-1.0, 1.0]:
			var pixel: Vector2 = point + side * wing * pixel_size * float(layer + 1)
			draw_rect(Rect2(pixel, Vector2.ONE * pixel_size), Color(color, 0.9 - float(layer) * 0.2), true)


func _draw_breadcrumb(room: Rect2, pixel_size: float) -> void:
	if not breadcrumb_age.has(player_room):
		return
	var direction: Vector2i = breadcrumb_direction.get(player_room, Vector2i.UP)
	var center := room.get_center() + Vector2(direction) * pixel_size * 10.0
	var age_ratio := clampf(float(breadcrumb_age[player_room]) / BREADCRUMB_SECONDS, 0.2, 1.0)
	var mark_color := Color(BLOOD, age_ratio)
	for offset in [Vector2(-2, -1), Vector2(-1, -1), Vector2(-2, 0), Vector2(1, 1), Vector2(2, 1), Vector2(2, 2)]:
		draw_rect(Rect2(_snap_pixel(center + offset * pixel_size, pixel_size), Vector2.ONE * pixel_size), mark_color, true)
	draw_rect(Rect2(_snap_pixel(center + Vector2(direction) * pixel_size * 2.0, pixel_size), Vector2.ONE * pixel_size), Color("e27a51", age_ratio), true)


func _draw_exit_warning(room: Rect2, pixel_size: float) -> void:
	if not round_exits.has(player_room):
		return
	var sign_position := Vector2(room.get_center().x, room.position.y + pixel_size * 11.0)
	_draw_pixel_text("ESCAPE GATE", sign_position - Vector2(pixel_size * 19.0, 0.0), pixel_size, BRASS)


func _draw_hud(usable: Rect2, pixel_size: float) -> void:
	var panel_width := usable.size.x * 0.88
	var panel_left := usable.position.x + usable.size.x * 0.06
	var panel_top := usable.position.y + usable.size.y * 0.035
	var hud_height := pixel_size * 16.0
	draw_rect(Rect2(Vector2(panel_left, panel_top), Vector2(panel_width, hud_height)), Color("100d11", 0.92), true)
	draw_rect(Rect2(Vector2(panel_left, panel_top), Vector2(panel_width, pixel_size)), Color("785444"), true)
	_draw_pixel_text("ASHEN DEPTHS", Vector2(panel_left + pixel_size * 3.0, panel_top + pixel_size * 3.0), pixel_size, PALE)
	var time_text := "%02d:%02d" % [int(round_elapsed) / 60, int(round_elapsed) % 60]
	_draw_pixel_text("HUNT %02d" % round_number, Vector2(panel_left + pixel_size * 3.0, panel_top + pixel_size * 9.0), pixel_size, Color("b69e89"))
	_draw_pixel_text("%s" % time_text, Vector2(panel_left + panel_width - pixel_size * 22.0, panel_top + pixel_size * 9.0), pixel_size, BRASS)
	var state_text := "MOVE / WASD  ·  STRIKE / TAP"
	var state_color := Color("9c8180")
	if run_state == RunState.PLAYING:
		state_text = last_feedback
		state_color = last_feedback_color
	_draw_pixel_text(state_text, Vector2(panel_left + pixel_size * 3.0, panel_top + pixel_size * 14.0), pixel_size, state_color)


func _draw_hunter(room: Rect2, pixel_size: float) -> void:
	var center := room.get_center()
	var direction := player_facing.normalized()
	var offset := Vector2.ZERO
	if creature_room == player_room and run_state == RunState.PLAYING:
		offset = -direction * pixel_size * 13.0
	if stun_remaining > 0.0:
		offset += Vector2(0.0, sin(animation_clock * 70.0) * pixel_size * 2.0)
	var hunter_center := _snap_pixel(center + offset, pixel_size)
	draw_rect(Rect2(hunter_center + Vector2(-pixel_size * 8.0, pixel_size * 8.0), Vector2(pixel_size * 16.0, pixel_size * 3.0)), Color("070609", 0.75), true)
	PixelArt.draw_sprite(self, PixelArt.HUNTER, hunter_center, pixel_size, direction, PixelArt.HUNTER_PALETTE)
	var perpendicular := Vector2(-direction.y, direction.x)
	var grip := hunter_center + perpendicular * pixel_size * 3.0 + direction * pixel_size
	var tip := hunter_center + perpendicular * pixel_size * 5.0 - direction * pixel_size * 4.0
	PixelArt.draw_pixel_line(self, grip, tip, pixel_size, Color("bda77d"), 1)
	PixelArt.draw_pixel_line(self, grip - perpendicular * pixel_size * 2.0, grip + perpendicular * pixel_size * 2.0, pixel_size, Color("754d3b"), 1)
	if stun_remaining > 0.0 and int(animation_clock * 18.0) % 2 == 0:
		for spark in [Vector2(-7, -4), Vector2(6, -6), Vector2(7, 3)]:
			draw_rect(Rect2(hunter_center + spark * pixel_size, Vector2.ONE * pixel_size), BLOOD, true)


func _draw_creature(room: Rect2, pixel_size: float) -> void:
	if run_state != RunState.PLAYING and run_state != RunState.CAUGHT:
		return
	if creature_room != player_room:
		return
	var direction_to_goal := DungeonMap.next_step(creature_room, creature_goal) - creature_room
	if direction_to_goal == Vector2i.ZERO:
		direction_to_goal = Vector2i.UP
	var center := room.get_center() + Vector2(player_facing) * pixel_size * 13.0
	center += Vector2(0.0, float(int(animation_clock * 8.0) % 2) * pixel_size)
	draw_rect(Rect2(center + Vector2(-pixel_size * 8.0, pixel_size * 7.0), Vector2(pixel_size * 16.0, pixel_size * 3.0)), Color("070609", 0.78), true)
	var palette: Dictionary = PixelArt.CREATURE_PALETTE
	if creature_flash_remaining > 0.0 and int(animation_clock * 18.0) % 2 == 0:
		palette = {"H": Color("fff0c1"), "B": Color("fff0c1"), "R": Color("fff0c1"), "S": Color("6b4541")}
	PixelArt.draw_sprite(self, PixelArt.CREATURE, center, pixel_size, Vector2(direction_to_goal), palette)


func _draw_sword_swing(room: Rect2, pixel_size: float) -> void:
	if attack_remaining <= 0.0:
		return
	var frame := clampi(int((1.0 - attack_remaining / 0.42) * 4.0), 0, 3)
	var local_pixels: Array = [
		[Vector2i(3, -5), Vector2i(4, -4), Vector2i(5, -3)],
		[Vector2i(2, -6), Vector2i(3, -5), Vector2i(4, -4), Vector2i(5, -2)],
		[Vector2i(0, -6), Vector2i(2, -5), Vector2i(4, -3), Vector2i(6, -1), Vector2i(7, 1)],
		[Vector2i(-1, -5), Vector2i(1, -3), Vector2i(3, -1), Vector2i(5, 1)],
	]
	var center := room.get_center()
	if creature_room == player_room:
		center -= player_facing * pixel_size * 13.0
	var facing_angle := Vector2.UP.angle_to(player_facing.normalized())
	var blade_color := Color("fff0c4") if pending_catch else Color("e3b365")
	for local_point in local_pixels[frame]:
		var offset := Vector2(local_point) * pixel_size
		var point := _snap_pixel(center + offset.rotated(facing_angle), pixel_size)
		draw_rect(Rect2(point, Vector2.ONE * pixel_size), blade_color, true)
	if pending_catch:
		for point in [Vector2(-4, -7), Vector2(5, -6), Vector2(7, 3), Vector2(-6, 4)]:
			draw_rect(Rect2(_snap_pixel(center + point * pixel_size, pixel_size), Vector2.ONE * pixel_size), BRASS, true)


func _draw_wall_impact(room: Rect2, pixel_size: float) -> void:
	if stun_remaining <= 0.0 or impact_direction == Vector2.ZERO:
		return
	var edge := room.get_center() + impact_direction * minf(room.size.x, room.size.y) * 0.46
	var side := Vector2(-impact_direction.y, impact_direction.x)
	for index in range(5):
		var position := _snap_pixel(edge + side * float(index - 2) * pixel_size * 3.0, pixel_size)
		var color := BRASS if index % 2 == 0 else BLOOD
		draw_rect(Rect2(position, Vector2.ONE * pixel_size * 2.0), color, true)
		draw_rect(Rect2(position - impact_direction * pixel_size * float(2 + index % 2), Vector2.ONE * pixel_size), Color(color, 0.75), true)


func _draw_round_overlay(usable: Rect2, pixel_size: float) -> void:
	var overlay_text := ""
	var subtitle := ""
	var color := PALE
	if run_state == RunState.READY:
		overlay_text = "THE RUNNER IS LOOSE"
		subtitle = "TAP TO HUNT  ·  WASD TO MOVE"
	elif run_state == RunState.COUNTDOWN:
		overlay_text = "THE RUNNER FLEES"
		subtitle = "CHASE IN %d" % (int(ceil(countdown_remaining)))
		color = BLOOD
	elif run_state == RunState.CAUGHT:
		overlay_text = "RUNNER CAUGHT"
		subtitle = "%.1f SEC  ·  %d STEPS  ·  TAP TO HUNT AGAIN" % [round_elapsed, player_steps]
		color = BRASS
	elif run_state == RunState.ESCAPED:
		overlay_text = "THE RUNNER ESCAPED"
		subtitle = "%.1f SEC  ·  %d STEPS  ·  TAP TO RETRY" % [round_elapsed, player_steps]
		color = BLOOD
	if overlay_text.is_empty():
		return
	var panel_size := Vector2(usable.size.x * 0.84, pixel_size * 29.0)
	var panel_position := usable.get_center() - panel_size * 0.5
	var panel := Rect2(panel_position, panel_size)
	draw_rect(panel, Color("0d0a0e", 0.96), true)
	for edge in range(2):
		var border_color := Color(color, 0.85 - float(edge) * 0.4)
		var inset := float(edge) * pixel_size * 2.0
		draw_rect(Rect2(panel.position + Vector2(inset, inset), panel.size - Vector2.ONE * inset * 2.0), border_color, false, pixel_size)
	var title_position := Vector2(panel.get_center().x - _pixel_text_width(overlay_text, pixel_size) * 0.5, panel.position.y + pixel_size * 12.0)
	var subtitle_pixel := pixel_size * 0.75
	var subtitle_position := Vector2(panel.get_center().x - _pixel_text_width(subtitle, subtitle_pixel) * 0.5, panel.position.y + pixel_size * 22.0)
	_draw_pixel_text(overlay_text, title_position, pixel_size, color)
	_draw_pixel_text(subtitle, subtitle_position, subtitle_pixel, Color("bca99a"))


func _draw_pixel_text(value: String, position: Vector2, pixel_size: float, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var size := int(clampf(pixel_size * 2.8, 10.0, 20.0))
	draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _pixel_text_width(value: String, pixel_size: float) -> float:
	var font_size := int(clampf(pixel_size * 2.8, 10.0, 20.0))
	return ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _snap_pixel(position: Vector2, pixel_size: float) -> Vector2:
	return Vector2(round(position.x / pixel_size), round(position.y / pixel_size)) * pixel_size
