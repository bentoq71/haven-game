extends Node2D
## BOUNCE BACK - game manager. Builds the world in code, runs progression, puzzles,
## the Watcher encounter, audio, UI and the ending.
##
## Map (x ranges, left to right):  Ballroom 0-1400 | Gallery 1400-3000 |
##                                 Corridor 3000-4600 | Forgotten Room 4600-6000

const FLOOR_Y := 560.0
const SCREEN := Vector2(1152, 648)

enum State { TITLE, PLAYING, ENDING }

const AREA_NAMES := ["THE BALLROOM", "THE GALLERY", "THE CORRIDOR", "THE FORGOTTEN ROOM"]
const AREA_MOD := [Color(0.95, 0.88, 0.82), Color(0.62, 0.70, 0.72), Color(0.40, 0.36, 0.52), Color(0.14, 0.12, 0.19)]
const AREA_LIGHT_SCALE := [3.2, 2.8, 2.4, 1.9]
const AREA_LIGHT_ENERGY := [0.15, 0.3, 0.55, 0.9]
const AREA_MELODY_DB := [-14.0, -20.0, -24.0, -80.0]
const AREA_MELODY_PITCH := [1.0, 0.92, 0.82, 0.7]
const SEQ_ORDER := ["musicbox", "chair", "clock"]

var state: int = State.TITLE

# world
var player: Player
var camera: Camera2D
var backdrop: Backdrop
var canvas_mod: CanvasModulate
var ambient: Watcher
var scripted: Watcher

# progression
var current_area := 0
var max_area := 0
var cp_x := -1.0
var checkpoint_pos := Vector2(100, FLOOR_Y - 2)
var checkpoints: Array = []
var hints: Array = []
var respawning := false
var fragment_collected := false
var memory_complete := false
var seq_progress: Array = []
var door1: Interactable
var wall1: Solid

# horror
var encounter_state := 0
var encounter_timer := 0.0
var blackout := 0.0
var silence_timer := 0.0
var shake := 0.0
var watcher_timer := 20.0
var tick_timer := 1.0

# ending
var ending_music := false
var end_ready := false

# UI
var ui: CanvasLayer
var msg_label: Label
var prompt_label: Label
var hud_label: Label
var title_panel: ColorRect
var fade_rect: ColorRect
var end_label: Label
var msg_timer := 0.0

# audio
var drone: AudioStreamPlayer
var melody: AudioStreamPlayer
var sfx := {}


func _ready() -> void:
	_setup_input()
	_build_world()
	_build_ui()
	_build_audio()
	title_panel.visible = true


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_bind("interact", [KEY_E])
	_bind("echo", [KEY_Q])
	_bind("recollect", [KEY_R])
	_bind("start", [KEY_ENTER, KEY_KP_ENTER])


func _build_world() -> void:
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = AREA_MOD[0]
	add_child(canvas_mod)

	backdrop = Backdrop.new()
	add_child(backdrop)

	_build_level()

	ambient = Watcher.new()
	scripted = Watcher.new()
	scripted.mode = "scripted"
	add_child(ambient)
	add_child(scripted)

	player = Player.new()
	player.position = checkpoint_pos
	player.controls_enabled = false
	add_child(player)
	ambient.player = player
	scripted.player = player
	player.echo_cast.connect(_on_echo_cast)
	player.recollect_cast.connect(_on_recollect_cast)
	player.footstep.connect(_on_footstep)
	player.landed.connect(_on_landed)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = 6000
	camera.limit_top = 0
	camera.limit_bottom = int(SCREEN.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.position = Vector2(0, -100)
	player.add_child(camera)
	camera.reset_smoothing()


func _floor(x0: float, x1: float) -> void:
	add_child(Solid.new().setup(Rect2(x0, FLOOR_Y, x1 - x0, 120.0)))


func _wall_block(x: float, w: float, col: Color, show_wall: bool = true) -> Solid:
	var s := Solid.new().setup(Rect2(x, 120.0, w, FLOOR_Y - 120.0), Solid.Mode.NORMAL, col, col.lightened(0.15))
	s.visible = show_wall
	add_child(s)
	return s


## A blocked doorway: an invisible wall plus a door the player opens. Returns [door, wall].
func _make_door(x: float, prompt: String, start_hidden: bool = false) -> Array:
	var wall := _wall_block(x - 12.0, 24.0, Palette.INK, false)
	var door := Interactable.new().setup("door", Vector2(x, FLOOR_Y), prompt, start_hidden)
	add_child(door)
	return [door, wall]


func _build_level() -> void:
	# World boundaries
	_wall_block(-40.0, 40.0, Palette.INK, false)
	_wall_block(6000.0, 40.0, Palette.INK, false)

	# ---------------- Area I: The Ballroom ----------------
	_floor(0.0, 1400.0)
	var frag := Interactable.new().setup("fragment", Vector2(650, FLOOR_Y), "Wind the music box")
	add_child(frag)
	var d1 := _make_door(1312.0, "Open the door")
	door1 = d1[0]
	wall1 = d1[1]
	door1.locked = true
	frag.on_use = func():
		frag.used = true
		fragment_collected = true
		door1.locked = false
		_sfx("chime")
		_show_text("A music box. The melody is almost familiar. Somewhere, a lock gives way.", 5.0)
	door1.on_use = func():
		if not fragment_collected:
			_show_text("Locked. Something is missing... a memory, maybe.", 4.0)
			return
		door1.opened = true
		wall1.set_enabled(false)
		_sfx("chime")
		_show_text("The door opens onto somewhere that shouldn't exist.", 4.0)

	# ---------------- Area II: The Gallery ----------------
	_floor(1400.0, 2000.0)
	_floor(2500.0, 3000.0)
	var orb_e := Interactable.new().setup("orb_echo", Vector2(1700, FLOOR_Y), "Take the glowing echo")
	orb_e.color = Palette.ECHO
	add_child(orb_e)
	orb_e.on_use = func():
		orb_e.used = true
		player.has_echo = true
		_sfx("chime")
		_show_text("ECHO.  Press Q to send out a pulse. Remember what was forgotten.", 6.0)
	# Hidden stepping stones across the pit (revealed by Echo)
	for r in [Rect2(2040, 500, 90, 20), Rect2(2190, 460, 90, 20), Rect2(2340, 500, 90, 20)]:
		add_child(Solid.new().setup(r, Solid.Mode.HIDDEN, Palette.ECHO, Palette.ECHO))
	# Hidden doorway out of the Gallery
	var d2 := _make_door(2902.0, "Step through the hidden door", true)
	var door2: Interactable = d2[0]
	var wall2: Solid = d2[1]
	door2.on_use = func():
		door2.opened = true
		wall2.set_enabled(false)
		_sfx("chime")
		_show_text("A door that was always there. You just forgot it.", 4.0)

	# ---------------- Area III: The Corridor ----------------
	_floor(3000.0, 3500.0)
	_floor(3950.0, 4600.0)
	var orb_r := Interactable.new().setup("orb_recollect", Vector2(3200, FLOOR_Y), "Take the amber memory")
	orb_r.color = Palette.RECOLLECT
	add_child(orb_r)
	orb_r.on_use = func():
		orb_r.used = true
		player.has_recollection = true
		_sfx("chime")
		_show_text("RECOLLECTION.  Press R to restore what was broken. It will not last.", 6.0)
	# Broken bridge (restored by Recollection)
	for i in 5:
		add_child(Solid.new().setup(Rect2(3500.0 + i * 90.0, FLOOR_Y, 90.0, 16.0), Solid.Mode.BROKEN, Palette.PLANK, Palette.PLANK))
	# The one door that is different (red knob)
	var d3 := _make_door(4572.0, "Open the different door")
	var door3: Interactable = d3[0]
	var wall3: Solid = d3[1]
	door3.knob = Palette.PLAYER_SCARF
	door3.on_use = func():
		door3.opened = true
		wall3.set_enabled(false)
		_sfx("chime")
		_show_text("It leads somewhere you have been avoiding.", 4.0)

	# ---------------- Area IV: The Forgotten Room ----------------
	_floor(4600.0, 6000.0)
	# Three objects. Echo reveals dots above each: touch them in that order.
	var defs := [["chair", 5000.0, 2], ["clock", 5180.0, 3], ["musicbox", 5360.0, 1]]
	for d in defs:
		var shape_name: String = d[0]
		var label := "music box" if shape_name == "musicbox" else shape_name
		var o := Interactable.new().setup("object", Vector2(d[1], FLOOR_Y), "Touch the " + label)
		o.shape = shape_name
		o.symbol_count = d[2]
		o.on_use = func(): _on_object_used(shape_name, o)
		add_child(o)
	# Broken stairs up to the exit (restored by Recollection)
	for r in [Rect2(5640, 500, 80, 60), Rect2(5720, 440, 80, 120), Rect2(5800, 380, 80, 180), Rect2(5880, 320, 120, 240)]:
		add_child(Solid.new().setup(r, Solid.Mode.BROKEN, Palette.STONE, Palette.STONE))
	# Hidden exit (revealed by Echo)
	var exit_door := Interactable.new().setup("exit", Vector2(5950, 320), "Go through", true)
	exit_door.on_use = func():
		if not memory_complete:
			_show_text("Not yet. The memory is still scattered.", 3.5)
			return
		_run_ending()
	add_child(exit_door)

	checkpoints = [
		[0.0, Vector2(100, FLOOR_Y - 2)],
		[1380.0, Vector2(1450, FLOOR_Y - 2)],
		[1900.0, Vector2(1900, FLOOR_Y - 2)],
		[2520.0, Vector2(2570, FLOOR_Y - 2)],
		[3010.0, Vector2(3060, FLOOR_Y - 2)],
		[3440.0, Vector2(3440, FLOOR_Y - 2)],
		[3960.0, Vector2(3990, FLOOR_Y - 2)],
		[4610.0, Vector2(4650, FLOOR_Y - 2)],
	]

	hints = [
		{"x": 160.0, "text": "Familiar. Warm. Empty.", "shown": false},
		{"x": 1500.0, "text": "The colours have been drained from everything in here.", "shown": false},
		{"x": 1960.0, "text": "The floor ahead is gone. Perhaps it is only forgotten. [Q]", "shown": false},
		{"x": 2700.0, "text": "A doorway is hiding somewhere near the far wall. [Q]", "shown": false},
		{"x": 3350.0, "text": "The bridge is in pieces. What was whole can be whole again. [R]", "shown": false},
		{"x": 4100.0, "text": "Every door looks the same. Except one.", "shown": false},
		{"x": 4950.0, "text": "These things want to be touched in the right order. [Q]", "shown": false},
		{"x": 5500.0, "text": "The way up is broken. The way out is hidden. [R] [Q]", "shown": false},
	]


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	# vignette
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.8)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.25, 0.5)
	tex.width = 256
	tex.height = 256
	var vig := TextureRect.new()
	vig.texture = tex
	vig.size = SCREEN
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vig)

	hud_label = _make_label(Vector2(20, 14), Vector2(500, 90), 18, HORIZONTAL_ALIGNMENT_LEFT)
	ui.add_child(hud_label)

	msg_label = _make_label(Vector2(96, 470), Vector2(960, 80), 24)
	msg_label.modulate.a = 0.0
	ui.add_child(msg_label)

	prompt_label = _make_label(Vector2(96, 585), Vector2(960, 40), 20)
	ui.add_child(prompt_label)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.size = SCREEN
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade_rect)

	end_label = _make_label(Vector2(150, 90), Vector2(852, 480), 26)
	end_label.visible = false
	ui.add_child(end_label)

	title_panel = ColorRect.new()
	title_panel.color = Color(0, 0, 0, 0.88)
	title_panel.size = SCREEN
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := _make_label(Vector2(0, 140), Vector2(1152, 100), 76)
	t1.text = "BOUNCE BACK"
	var t2 := _make_label(Vector2(0, 245), Vector2(1152, 40), 24)
	t2.text = "a fractured memory"
	var t3 := _make_label(Vector2(0, 340), Vector2(1152, 200), 20)
	t3.text = "A / D  move        Space  jump        E  interact\nQ  Echo        R  Recollection        (once you find them)\n\nPress ENTER to begin"
	title_panel.add_child(t1)
	title_panel.add_child(t2)
	title_panel.add_child(t3)
	ui.add_child(title_panel)


func _make_label(pos: Vector2, sz: Vector2, font_size: int, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("efe6d6"))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _make_player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p


func _build_audio() -> void:
	drone = _make_player(Sounds.drone(), -17.0)
	melody = _make_player(Sounds.melody(), -80.0)
	sfx["tick"] = _make_player(Sounds.tick(), -20.0)
	sfx["step"] = _make_player(Sounds.step(), -22.0)
	sfx["chime"] = _make_player(Sounds.chime(), -8.0)
	sfx["echo"] = _make_player(Sounds.echo(), -8.0)
	sfx["recollect"] = _make_player(Sounds.recollect(), -8.0)
	sfx["stinger"] = _make_player(Sounds.stinger(), -4.0)


func _sfx(sound: String) -> void:
	if sfx.has(sound):
		sfx[sound].play()


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	match state:
		State.TITLE:
			if Input.is_action_just_pressed("start"):
				_start_game()
		State.PLAYING:
			_update_playing(delta)
		State.ENDING:
			if end_ready and Input.is_action_just_pressed("start"):
				get_tree().reload_current_scene()
	_update_visuals(delta)


func _start_game() -> void:
	state = State.PLAYING
	title_panel.visible = false
	player.controls_enabled = true
	drone.play()
	melody.play()
	_show_text("Where... am I?", 4.0)


func _update_playing(delta: float) -> void:
	var px := player.global_position.x

	var area := _area_for_x(px)
	if area != current_area:
		_change_area(area)

	for cp in checkpoints:
		if cp[0] > cp_x and px >= cp[0]:
			cp_x = cp[0]
			checkpoint_pos = cp[1]

	for h in hints:
		if not h["shown"] and px >= h["x"]:
			h["shown"] = true
			_show_text(h["text"], 4.5)

	if player.global_position.y > 800.0:
		_respawn()

	var it := player.get_nearest_interactable()
	prompt_label.text = ("[E]  " + it.prompt) if it != null else ""
	if it != null and Input.is_action_just_pressed("interact") and it.on_use.is_valid():
		it.on_use.call()

	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = 1.0
		if silence_timer <= 0.0:
			_sfx("tick")

	_update_encounter(delta)
	_update_ambient_watcher(delta)


func _area_for_x(x: float) -> int:
	for i in 4:
		if x < Util.AREA_X[i + 1]:
			return i
	return 3


func _change_area(a: int) -> void:
	var prev := current_area
	current_area = a
	if a > max_area:
		max_area = a
		backdrop.anomaly[a - 1] += 1   # the room you just left changes behind you
		watcher_timer = 5.0
		match a:
			1:
				_show_text("THE GALLERY", 3.0)
			2:
				_show_text("THE CORRIDOR\nYou feel like you have walked this hall before.", 4.0)
			3:
				_show_text("THE FORGOTTEN ROOM", 3.0)
	elif a < prev:
		backdrop.anomaly[a] += 1       # coming back: something is different
		watcher_timer = 3.0


func _respawn() -> void:
	if respawning:
		return
	respawning = true
	_show_text("Bounce back.", 2.5)
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.25)
	tw.tween_callback(func():
		player.global_position = checkpoint_pos
		player.velocity = Vector2.ZERO)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.4)
	tw.tween_callback(func(): respawning = false)


# ---------------------------------------------------------------------------
# Puzzle: the forgotten sequence
# ---------------------------------------------------------------------------

func _on_object_used(shape_name: String, item: Interactable) -> void:
	item.lit_time = 1.0
	_sfx("chime")
	if memory_complete:
		return
	seq_progress.append(shape_name)
	var i := seq_progress.size() - 1
	if seq_progress[i] != SEQ_ORDER[i]:
		seq_progress.clear()
		blackout = 0.8
		_sfx("stinger")
		_show_text("That is not how it happened.", 3.0)
		return
	if seq_progress.size() == SEQ_ORDER.size():
		_complete_memory()


func _complete_memory() -> void:
	memory_complete = true
	var lines := [
		"The music box played. You sat and waited.",
		"The clock kept going. Nobody came back through the door.",
		"So you ran. And the world cracked behind you.",
		"The pieces are still here. Put the way back together.",
	]
	for line in lines:
		if state != State.PLAYING:
			return
		_show_text(line, 3.6)
		await get_tree().create_timer(3.8).timeout


# ---------------------------------------------------------------------------
# Horror
# ---------------------------------------------------------------------------

func _in_pit(x: float) -> bool:
	return (x > 1990.0 and x < 2510.0) or (x > 3490.0 and x < 3960.0)


func _update_ambient_watcher(delta: float) -> void:
	if encounter_state != 0 or current_area >= 3:
		return
	watcher_timer -= delta
	if watcher_timer > 0.0 or ambient.is_active():
		return
	watcher_timer = randf_range(16.0, 30.0)
	var px := player.global_position.x
	for attempt in 4:
		var dir: float = player.facing
		if max_area > 0 and randf() < 0.6:
			dir = -player.facing
		if attempt >= 2:
			dir = -dir
		var x := px + dir * randf_range(430.0, 560.0)
		if x < 60.0 or x > 4540.0 or _in_pit(x):
			continue
		ambient.appear(x, FLOOR_Y, -dir, 14.0)
		return


## The scripted Watcher encounter in the Forgotten Room.
func _update_encounter(delta: float) -> void:
	var px := player.global_position.x
	match encounter_state:
		0:
			if px > 4800.0:
				encounter_state = 1
				encounter_timer = 0.0
				blackout = 1.8
				silence_timer = 4.5
				shake = 0.3
				ambient.vanish(true)
				_show_text("...", 2.0)
		1:
			encounter_timer += delta
			if encounter_timer > 2.2:
				scripted.appear(5560.0, FLOOR_Y, -1.0)
				encounter_state = 2
				encounter_timer = 0.0
				_show_text("Someone is standing at the far end of the room.", 4.0)
		2:
			encounter_timer += delta
			if absf(px - scripted.position.x) < 320.0 or encounter_timer > 16.0:
				scripted.vanish(true)
				encounter_state = 3
				encounter_timer = 0.0
		3:
			encounter_timer += delta
			if encounter_timer > 1.0:
				var behind := clampf(px - player.facing * 230.0, 4640.0, 5960.0)
				scripted.appear(behind, FLOOR_Y, 1.0)
				blackout = 0.5
				shake = 1.0
				_sfx("stinger")
				_show_text("Don't look away.", 3.0)
				encounter_state = 4
				encounter_timer = 0.0
		4:
			encounter_timer += delta
			if encounter_timer > 3.2 or absf(px - scripted.position.x) < 120.0:
				scripted.vanish(true)
				silence_timer = 0.0
				encounter_state = 5


# ---------------------------------------------------------------------------
# Visuals, messages and audio mixing
# ---------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	var target_mod: Color = AREA_MOD[current_area]
	var target_scale: float = AREA_LIGHT_SCALE[current_area]
	var target_energy: float = AREA_LIGHT_ENERGY[current_area]

	if blackout > 0.0:
		blackout -= delta
		var on := randf() < 0.35
		canvas_mod.color = target_mod if on else Color(0.02, 0.02, 0.03)
		player.glow.energy = target_energy if on else 0.0
	else:
		canvas_mod.color = canvas_mod.color.lerp(target_mod, clampf(delta * 3.0, 0.0, 1.0))
		player.glow.energy = lerpf(player.glow.energy, target_energy, clampf(delta * 3.0, 0.0, 1.0))
	player.glow.texture_scale = lerpf(player.glow.texture_scale, target_scale, clampf(delta * 2.0, 0.0, 1.0))

	backdrop.view_x = player.global_position.x

	# on-screen message
	if msg_timer > 0.0:
		msg_timer -= delta
		msg_label.modulate.a = clampf(msg_timer / 0.6, 0.0, 1.0)
	else:
		msg_label.modulate.a = 0.0

	# HUD
	var lines := PackedStringArray()
	if player.has_echo:
		lines.append("Q   Echo")
	if player.has_recollection:
		lines.append("R   Recollection")
	hud_label.text = "\n".join(lines)

	# camera shake
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 1.5)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 10.0
	else:
		camera.offset = Vector2.ZERO

	# audio mix
	var silent := silence_timer > 0.0
	if silent:
		silence_timer -= delta
	var drone_target := -17.0
	var mel_db: float = AREA_MELODY_DB[current_area]
	var mel_pitch: float = AREA_MELODY_PITCH[current_area]
	if silent:
		drone_target = -80.0
		mel_db = -80.0
	if ending_music:
		drone_target = -80.0
		mel_db = -10.0
		mel_pitch = 1.0
	drone.volume_db = lerpf(drone.volume_db, drone_target, clampf(delta * 6.0, 0.0, 1.0))
	melody.volume_db = lerpf(melody.volume_db, mel_db, clampf(delta * 2.0, 0.0, 1.0))
	melody.pitch_scale = lerpf(melody.pitch_scale, mel_pitch, clampf(delta * 0.8, 0.0, 1.0))


func _show_text(text: String, duration: float = 4.0) -> void:
	msg_label.text = text
	msg_timer = duration
	msg_label.modulate.a = 1.0


func _spawn_pulse(origin: Vector2, col: Color, radius: float) -> void:
	var p := Pulse.new().setup(col, radius)
	p.position = origin
	add_child(p)


func _on_echo_cast(origin: Vector2) -> void:
	_spawn_pulse(origin, Palette.ECHO, Player.ECHO_RADIUS)
	_sfx("echo")


func _on_recollect_cast(origin: Vector2) -> void:
	_spawn_pulse(origin, Palette.RECOLLECT, Player.RECOLLECT_RADIUS)
	_sfx("recollect")


func _on_footstep() -> void:
	if sfx.has("step"):
		sfx["step"].pitch_scale = randf_range(0.85, 1.1)
		sfx["step"].play()


func _on_landed() -> void:
	_sfx("step")


# ---------------------------------------------------------------------------
# Ending
# ---------------------------------------------------------------------------

func _run_ending() -> void:
	state = State.ENDING
	player.controls_enabled = false
	ending_music = true
	prompt_label.text = ""
	msg_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 3.0)
	await tw.finished
	end_label.visible = true
	var lines := [
		"You remember now.",
		"The door never opened. Waiting hurt too much, so you ran, and the world cracked around you.",
		"But you came back through every broken room.",
		"You fell. You stood up. You bounced back.",
		"THE END",
	]
	for line in lines:
		end_label.text += line + "\n\n"
		await get_tree().create_timer(3.2).timeout
	end_label.text += "[ENTER]  play again"
	end_ready = true
