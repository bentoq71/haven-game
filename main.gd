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
const AREA_MOD := [Color(0.95, 0.88, 0.82), Color(0.66, 0.74, 0.76), Color(0.60, 0.54, 0.74), Color(0.28, 0.24, 0.36)]
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
var hud_echo: Control
var hud_rec: Control
var msg_panel: NinePatchRect
var type_pos := 0.0
var title_panel: ColorRect
var fade_rect: ColorRect
var end_label: Label
var msg_timer := 0.0

 # audio
var music: AudioStreamPlayer
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
	var s := Solid.new().setup(Rect2(x, 120.0, w, FLOOR_Y - 120.0), Solid.Mode.NORMAL, "wall")
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
	var frag := Interactable.new().setup(
	"fragment",
	Vector2(675, 340),
    "wind the music box"
)
	add_child(frag)
	var d1 := _make_door(1312.0, "open the door")
	door1 = d1[0]
	wall1 = d1[1]
	door1.locked = true
	frag.on_use = func():
		frag.used = true
		fragment_collected = true
		door1.locked = false
		_sfx("chime")
		_show_text("a music box. i know this song. i just can't remember who played it for me.\nsomething clicked, over by the door.", 5.0)
	door1.on_use = func():
		if not fragment_collected:
			_show_text("locked. there has to be something in here that opens it.", 4.0)
			return
		door1.opened = true
		wall1.set_enabled(false)
		_sfx("chime")
		_show_text("that wasn't a hallway before.", 4.0)

# Ballroom bounce puzzle
	_add_bounce_platform(Vector2(510, 540), 750.0)

# Elevated ledge that cannot be reached by normal jumping
	add_child(
		Solid.new().setup(
			Rect2(585, 340, 190, 16)
	)
)

	# ---------------- Area II: The Gallery ----------------
	_floor(1400.0, 2000.0)
	_floor(2500.0, 3000.0)
	var orb_e := Interactable.new().setup("orb_echo", Vector2(1700, FLOOR_Y), "take the glowing thing")
	orb_e.color = Palette.ECHO
	add_child(orb_e)
	orb_e.on_use = func():
		orb_e.used = true
		player.has_echo = true
		_sfx("chime")
		_show_text("oh. the room answers when i call out to it. [Q] to listen.", 6.0)
	# Hidden stepping stones across the pit (revealed by Echo)
	for r in [Rect2(2040, 500, 90, 20), Rect2(2190, 460, 90, 20), Rect2(2340, 500, 90, 20)]:
		add_child(Solid.new().setup(r, Solid.Mode.HIDDEN, "slab"))
	# Hidden doorway out of the Gallery
	var d2 := _make_door(2902.0, "open the hidden door", true)
	var door2: Interactable = d2[0]
	var wall2: Solid = d2[1]
	door2.on_use = func():
		door2.opened = true
		wall2.set_enabled(false)
		_sfx("chime")
		_show_text("it was here the whole time. i just wasn't looking.", 4.0)

	# ---------------- Area III: The Corridor ----------------
	_floor(3000.0, 3500.0)
	_floor(3950.0, 4600.0)
	var orb_r := Interactable.new().setup("orb_recollect", Vector2(3200, FLOOR_Y), "take the warm light")
	orb_r.color = Palette.RECOLLECT
	add_child(orb_r)
	orb_r.on_use = func():
		orb_r.used = true
		player.has_recollection = true
		_sfx("chime")
		_show_text("warm. like remembering the end of a song. [R] puts broken things back, but never for long.", 6.0)
	# Broken bridge (restored by Recollection)
	for i in 5:
		add_child(Solid.new().setup(Rect2(3500.0 + i * 90.0, FLOOR_Y, 90.0, 16.0), Solid.Mode.BROKEN, "plank"))
	# The one door that is different (red handle)
	var d3 := _make_door(4572.0, "open the red-handled door")
	var door3: Interactable = d3[0]
	var wall3: Solid = d3[1]
	door3.odd = true
	door3.on_use = func():
		door3.opened = true
		wall3.set_enabled(false)
		_sfx("chime")
		_show_text("i don't want to go in there. ...i'm going in.", 4.0)

	# ---------------- Area IV: The Forgotten Room ----------------
	_floor(4600.0, 6000.0)
	# Three objects. Echo reveals dots above each: touch them in that order.
	var defs := [["chair", 5000.0, 2], ["clock", 5180.0, 3], ["musicbox", 5360.0, 1]]
	for d in defs:
		var shape_name: String = d[0]
		var label := "music box" if shape_name == "musicbox" else shape_name
		var o := Interactable.new().setup("object", Vector2(d[1], FLOOR_Y), "touch the " + label)
		o.shape = shape_name
		o.symbol_count = d[2]
		o.on_use = func(): _on_object_used(shape_name, o)
		add_child(o)
	# Broken stairs up to the exit (restored by Recollection)
	for r in [Rect2(5640, 500, 80, 60), Rect2(5720, 440, 80, 120), Rect2(5800, 380, 80, 180), Rect2(5880, 320, 120, 240)]:
		add_child(Solid.new().setup(r, Solid.Mode.BROKEN, "stairs"))
	# Hidden exit (revealed by Echo)
	var exit_door := Interactable.new().setup("exit", Vector2(5950, 320), "go through", true)
	exit_door.on_use = func():
		if not memory_complete:
			_show_text("not yet. i still don't remember all of it.", 3.5)
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
		{"x": 160.0, "text": "it's so quiet. someone should be dancing.", "shown": false},
		{"x": 1500.0, "text": "the paintings are watching me. ...they're paintings. it's fine.", "shown": false},
		{"x": 1960.0, "text": "the floor just stops. maybe it's not gone, maybe i just forgot it. try [Q].", "shown": false},
		{"x": 2700.0, "text": "there's a door in here somewhere. i can feel it. [Q] again?", "shown": false},
		{"x": 3350.0, "text": "the bridge is in bits. if i can remember how it went together... [R]", "shown": false},
		{"x": 4100.0, "text": "every door looks the same. except one.", "shown": false},
		{"x": 4950.0, "text": "those three things want to be touched in the right order. [Q] might show me.", "shown": false},
		{"x": 5500.0, "text": "the way up is broken and the way out is hidden. [R] then [Q], i think.", "shown": false},
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

	hud_echo = _make_hud_item("icon_echo", "q", Vector2(20, 16))
	hud_rec = _make_hud_item("icon_recollect", "r", Vector2(20, 60))
	ui.add_child(hud_echo)
	ui.add_child(hud_rec)

	msg_panel = NinePatchRect.new()
	msg_panel.texture = Util.tex("panel")
	msg_panel.patch_margin_left = 12
	msg_panel.patch_margin_top = 12
	msg_panel.patch_margin_right = 12
	msg_panel.patch_margin_bottom = 12
	# Smaller dialogue box near the top of the screen
	msg_panel.position = Vector2(96, 24)
	msg_panel.size = Vector2(960, 88)
	msg_panel.modulate.a = 0.0
	msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(msg_panel)
	# Dialogue text
	msg_label = _make_label(
		Vector2(28, 8),
		Vector2(904, 72),
		18,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.visible_characters = 0
	msg_panel.add_child(msg_label)

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
	t3.text = "a / d  move        space  jump        e  interact\nq  echo        r  recollection        (once you find them)\n\npress ENTER to begin"
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
	Util.style_label(l, font_size >= 40)
	l.add_theme_color_override("font_color", Color("efe6d6"))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _make_hud_item(icon_name: String, key: String, pos: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.visible = false
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = Util.tex(icon_name)
	tr.size = Vector2(30, 30)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tr)
	var l := _make_label(Vector2(42, 4), Vector2(60, 24), 18, HORIZONTAL_ALIGNMENT_LEFT)
	l.text = key
	c.add_child(l)
	return c


func _make_player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p



func _build_audio() -> void:
	# Background music
	music = AudioStreamPlayer.new()
	music.name = "BackgroundMusic"
	add_child(music)

	var track_path = "res://audio/music/The_Caretaker_-_Libet_s_Delay_(mp3.pm).mp3"
	var track = load("res://audio/music/The_Caretaker_-_Libet_s_Delay_(mp3.pm).mp3") as AudioStreamMP3

	if track:
		track.loop = true
		music.stream = track
		music.volume_db = -12.0

	# Sound effects
	var sound_streams = {
		"tick": Sounds.tick(),
		"step": Sounds.step(),
		"chime": Sounds.chime(),
		"echo": Sounds.echo(),
		"recollect": Sounds.recollect(),
		"stinger": Sounds.stinger(),
		"blip": Sounds.blip()
	}

	for sound_name in sound_streams:
		var player := AudioStreamPlayer.new()
		player.name = sound_name
		player.stream = sound_streams[sound_name]
		player.volume_db = -80.0
		add_child(player)
		sfx[sound_name] = player



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
	music.play()
	_show_text("huh. i know this room. why do i know this room?", 4.0)


func _update_playing(delta: float) -> void:
	var px := player.global_position.x

	var area := _area_for_x(px)
	if area != current_area:
		_change_area(area)

	for cp in checkpoints:
		if cp[0] > cp_x and px >= cp[0]:
			cp_x = cp[0]
			checkpoint_pos = cp[1]

	# Hints wait for the current line to finish, and expire if you've already walked well past them.
	for h in hints:
		if h["shown"] or px < h["x"]:
			continue
		if px > h["x"] + 500.0:
			h["shown"] = true
		elif _text_idle():
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
				_show_text("the colours are all wrong in here. like someone washed them out.", 4.0)
			2:
				_show_text("wait. haven't i walked this hall already?", 4.0)
			3:
				_show_text("it's so quiet in here.", 3.0)
	elif a < prev:
		backdrop.anomaly[a] += 1       # coming back: something is different
		watcher_timer = 3.0


func _respawn() -> void:
	if respawning:
		return
	respawning = true
	_show_text("ow. okay. bounce back.", 2.5)
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
		_show_text("no. that's not how it went.", 3.0)
		return
	if seq_progress.size() == SEQ_ORDER.size():
		_complete_memory()


func _complete_memory() -> void:
	memory_complete = true
	var lines := [
		"the music box was playing. i sat there and waited.",
		"the clock kept going. nobody came back through the door.",
		"so i ran. and everything cracked behind me.",
		"...the pieces are still here. i can put it back together.",
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
				_show_text("someone's standing at the far end of the room. they're not moving.", 4.0)
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
				_show_text("it's behind me. don't turn around.", 3.0)
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
	var total := msg_label.text.length()
	if msg_label.visible_characters < total:
		var before := msg_label.visible_characters
		type_pos += delta * 42.0
		msg_label.visible_characters = mini(int(type_pos), total)
		var now := msg_label.visible_characters
		if now != before and now > 0 and now % 2 == 0 and msg_label.text[now - 1] != " ":
			sfx["blip"].pitch_scale = randf_range(0.9, 1.2)
			sfx["blip"].play()
		msg_panel.modulate.a = 1.0
	elif msg_timer > 0.0:
		msg_timer -= delta
		msg_panel.modulate.a = clampf(msg_timer / 0.6, 0.0, 1.0)
	else:
		msg_panel.modulate.a = 0.0

	# HUD
	hud_echo.visible = player.has_echo
	hud_rec.visible = player.has_recollection

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

func _text_idle() -> bool:
	return msg_label.visible_characters >= msg_label.text.length() and msg_timer <= 0.0


func _show_text(text: String, duration: float = 4.0) -> void:
	msg_label.text = text
	msg_label.visible_characters = 0
	type_pos = 0.0
	msg_timer = duration
	msg_panel.modulate.a = 1.0


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
	msg_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 3.0)
	await tw.finished
	end_label.visible = true
	var lines := [
		"i remember now.",
		"the door never opened. waiting hurt too much, so i ran, and the whole world cracked.",
		"but i came back through every broken room.",
		"i fell. i got up. i bounced back.",
		"THE END",
	]
	for line in lines:
		end_label.text += line + "\n\n"
		await get_tree().create_timer(3.2).timeout
	end_label.text += "[ENTER]  play again"
	end_ready = true
	
func _add_bounce_platform(pos: Vector2, strength: float) -> void:
	var platform := BouncePlatform.new()
	platform.position = pos
	platform.bounce_strength = strength
	add_child(platform)
