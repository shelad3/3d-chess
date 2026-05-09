extends Control

const Campaign = preload("res://campaign.gd")
enum Screen { MAIN, NEW_GAME, LOAD, SETTINGS, CAMPAIGN, CREDITS }
var current_screen = Screen.MAIN
var particles: Array = []
var time := 0.0
var music_playing := false
var music_bus: int

func _ready():
	$"..".get_window().size = Vector2(900, 780)
	music_bus = AudioServer.get_bus_index("Master")

	var bg = ColorRect.new()
	bg.color = Color("#0d0d1a")
	bg.size = get_viewport_rect().size
	add_child(bg)

	for i in 30:
		var p = ColorRect.new()
		p.color = Color(1, 1, 1, randf_range(0.1, 0.4))
		var sz = randf_range(2, 6)
		p.size = Vector2(sz, sz)
		p.position = Vector2(randf_range(0, get_viewport_rect().size.x), randf_range(0, get_viewport_rect().size.y))
		p.name = "Particle" + str(i)
		add_child(p)
		particles.append({ node = p, speed = randf_range(5, 20), dir = randf_range(-0.5, 0.5) })

	var title = Label.new()
	title.text = "♚ CHESS ♔"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("#e0d8c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(500, 100)
	title.position = Vector2((get_viewport_rect().size.x - 500) / 2, 80)
	title.name = "Title"
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "3D Chess"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("#8888aa"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(300, 40)
	subtitle.position = Vector2((get_viewport_rect().size.x - 300) / 2, 175)
	subtitle.name = "Subtitle"
	add_child(subtitle)

	show_main_menu()
	_setup_music()

func _setup_music():
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.5

	var player = AudioStreamPlayer2D.new()
	player.stream = gen
	player.volume_db = -20
	player.name = "MusicPlayer"
	add_child(player)

	await get_tree().process_frame
	player.play()

	var playback = player.get_stream_playback()
	if playback:
		music_playing = true

func _process(delta):
	time += delta
	for p in particles:
		p.node.position.y -= p.speed * delta
		p.node.position.x += sin(time * 0.5 + p.dir * 10) * delta * 3
		if p.node.position.y < -10:
			p.node.position.y = get_viewport_rect().size.y + 10
			p.node.position.x = randf_range(0, get_viewport_rect().size.x)

	if music_playing:
		var player = get_node_or_null("MusicPlayer")
		if player and player.stream is AudioStreamGenerator:
			var playback = player.get_stream_playback()
			if playback and playback.get_frames_available() >= 512:
				_generate_audio_chunk(playback)

func _generate_audio_chunk(playback: AudioStreamGeneratorPlayback):
	var frames = 512
	var buf = PackedVector2Array()
	var dt = 1.0 / 22050.0
	for i in frames:
		var t = time + i * dt
		var chord = sin(t * 55.0 * 2.0 * PI) * 0.06
		chord += sin(t * 65.41 * 2.0 * PI) * 0.05
		chord += sin(t * 82.41 * 2.0 * PI) * 0.04
		chord += sin(t * 110.0 * 2.0 * PI) * 0.02
		var mod = 0.5 + 0.5 * sin(t * 0.15)
		var sample = chord * mod * 0.3
		sample = clamp(sample, -0.5, 0.5)
		buf.append(Vector2(sample, sample))
	if buf.size() == frames:
		playback.push_buffer(buf)

func clear_screen():
	for c in get_children():
		if c.name.begins_with("Btn") or c.name.begins_with("Lbl") or c.name.begins_with("Panel") or c.name.begins_with("Overlay") or c.name.begins_with("Slider") or c.name.begins_with("Save") or c.name.begins_with("Cell") or c.name.begins_with("CellBorder") or c.name.begins_with("Bar") or c.name.begins_with("Detail"):
			c.queue_free()
	for c in get_children():
		if c is Label and c.name not in ["Title", "Subtitle"]:
			if c.name != "Title" and c.name != "Subtitle":
				c.queue_free()

func make_btn(x: float, y: float, w: float, h: float, text: String, idx: int) -> ColorRect:
	var btn = ColorRect.new()
	btn.color = Color("#16213e")
	btn.size = Vector2(w, h)
	btn.position = Vector2(x, y)
	btn.name = "Btn" + str(idx)
	add_child(btn)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color("#c0c0e0"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(w, h)
	lbl.position = Vector2(x, y)
	lbl.name = "Lbl" + str(idx)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	btn.mouse_entered.connect(func(): btn.color = Color("#0f3460"))
	btn.mouse_exited.connect(func(): btn.color = Color("#16213e"))
	return btn

func make_panel(x: float, y: float, w: float, h: float) -> ColorRect:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.size = get_viewport_rect().size
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var panel = ColorRect.new()
	panel.color = Color("#1a1a2e")
	panel.size = Vector2(w, h)
	panel.position = Vector2(x, y)
	panel.name = "Panel"
	add_child(panel)
	return panel

func show_main_menu():
	clear_screen()
	current_screen = Screen.MAIN
	var cx = get_viewport_rect().size.x / 2.0
	var bw = 260.0
	var bh = 44.0
	var start_y = 225.0
	var gap = 52.0

	make_btn(cx - bw / 2, start_y, bw, bh, "Campaign", 0)
	make_btn(cx - bw / 2, start_y + gap, bw, bh, "New Game", 1)
	make_btn(cx - bw / 2, start_y + gap * 2, bw, bh, "Load Game", 2)
	make_btn(cx - bw / 2, start_y + gap * 3, bw, bh, "Settings", 3)
	make_btn(cx - bw / 2, start_y + gap * 4, bw, bh, "Credits", 4)
	make_btn(cx - bw / 2, start_y + gap * 5, bw, bh, "Quit", 5)

func show_new_game():
	clear_screen()
	current_screen = Screen.NEW_GAME
	var cx = get_viewport_rect().size.x / 2.0
	var cy = get_viewport_rect().size.y / 2.0
	var pw = 360.0
	var ph = 380.0
	make_panel(cx - pw / 2, cy - ph / 2 - 20, pw, ph)

	var title = Label.new()
	title.text = "New Game"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#e0d8c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(pw, 40)
	title.position = Vector2(cx - pw / 2, cy - ph / 2 + 15)
	title.name = "PanelTitle"
	add_child(title)

	var options = [
		{ text = "Human vs Human", ai = false, depth = 0 },
		{ text = "Human vs AI (Novice)", ai = true, depth = 2 },
		{ text = "Human vs AI (Easy)", ai = true, depth = 3 },
		{ text = "Human vs AI (Hard)", ai = true, depth = 4 },
		{ text = "Human vs AI (Expert)", ai = true, depth = 5 },
	]
	for i in options.size():
		var opt = options[i]
		var btn = make_btn(cx - 130, cy - 80 + i * 52, 260, 44, opt.text, 10 + i)
		var ai_val = opt.ai
		var depth_val = opt.depth
		btn.connect("gui_input", func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				start_game(ai_val, depth_val))

	var back_btn = make_btn(cx - 80, cy + 140, 160, 40, "Back", 99)
	back_btn.connect("gui_input", func(event):
		if event is InputEventMouseButton and event.pressed:
			show_main_menu())

func show_load():
	clear_screen()
	current_screen = Screen.LOAD
	var cx = get_viewport_rect().size.x / 2.0
	var cy = get_viewport_rect().size.y / 2.0
	var pw = 400.0
	var ph = 350.0
	make_panel(cx - pw / 2, cy - ph / 2, pw, ph)

	var title = Label.new()
	title.text = "Load Game"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#e0d8c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(pw, 40)
	title.position = Vector2(cx - pw / 2, cy - ph / 2 + 15)
	title.name = "PanelTitle"
	add_child(title)

	var saves = []
	var dir = DirAccess.open("user://saves")
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f.ends_with(".save"):
				saves.append(f.trim_suffix(".save"))
			f = dir.get_next()

	if saves.is_empty():
		var lbl = Label.new()
		lbl.text = "No saved games found"
		lbl.add_theme_color_override("font_color", Color("#8888aa"))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(pw - 40, 40)
		lbl.position = Vector2(cx - pw / 2 + 20, cy - 30)
		add_child(lbl)
	else:
		var start_y = cy - ph / 2 + 65
		for i in saves.size():
			if i >= 6: break
			var btn = make_btn(cx - 150, start_y + i * 42, 260, 34, saves[i], 20 + i)
			var sname = saves[i]
			btn.connect("gui_input", func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_load_and_start(sname))

	var back_btn = make_btn(cx - 80, cy + ph / 2 - 50, 160, 40, "Back", 99)
	back_btn.connect("gui_input", func(event):
		if event is InputEventMouseButton and event.pressed:
			show_main_menu())

func _load_and_start(slot: String):
	Engine.set_meta("game_config", { ai = false, depth = 0, load_slot = slot })
	get_tree().change_scene_to_file("res://game.tscn")

func show_settings():
	clear_screen()
	current_screen = Screen.SETTINGS
	var cx = get_viewport_rect().size.x / 2.0
	var cy = get_viewport_rect().size.y / 2.0
	var pw = 400.0
	var ph = 280.0
	make_panel(cx - pw / 2, cy - ph / 2, pw, ph)

	var title = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#e0d8c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(pw, 40)
	title.position = Vector2(cx - pw / 2, cy - ph / 2 + 15)
	title.name = "PanelTitle"
	add_child(title)

	var vlbl = Label.new()
	vlbl.text = "Music Volume"
	vlbl.add_theme_font_size_override("font_size", 16)
	vlbl.add_theme_color_override("font_color", Color("#a0a0c0"))
	vlbl.size = Vector2(200, 30)
	vlbl.position = Vector2(cx - 100, cy - 40)
	add_child(vlbl)

	var slider = HSlider.new()
	slider.size = Vector2(260, 30)
	slider.position = Vector2(cx - 130, cy - 10)
	slider.min_value = -40
	slider.max_value = 0
	slider.value = -20
	slider.step = 1
	slider.name = "SliderVol"
	slider.value_changed.connect(func(val):
		var player = get_node_or_null("MusicPlayer")
		if player: player.volume_db = val)
	add_child(slider)

	var lbl2 = Label.new()
	lbl2.text = "AI Search Speed"
	lbl2.add_theme_font_size_override("font_size", 16)
	lbl2.add_theme_color_override("font_color", Color("#a0a0c0"))
	lbl2.size = Vector2(200, 30)
	lbl2.position = Vector2(cx - 100, cy + 40)
	add_child(lbl2)

	var slider2 = HSlider.new()
	slider2.size = Vector2(260, 30)
	slider2.position = Vector2(cx - 130, cy + 70)
	slider2.min_value = 2
	slider2.max_value = 5
	slider2.value = 3
	slider2.step = 1
	slider2.name = "SliderAI"
	add_child(slider2)

	Engine.set_meta("settings_ai_depth", slider2)

	var back_btn = make_btn(cx - 80, cy + 110, 160, 40, "Back", 99)
	back_btn.connect("gui_input", func(event):
		if event is InputEventMouseButton and event.pressed:
			var sd = get_node_or_null("SliderAI")
			if sd: Engine.set_meta("settings_ai_depth", sd.value)
			show_main_menu())

func show_campaign():
	clear_screen()
	current_screen = Screen.CAMPAIGN
	var cx = get_viewport_rect().size.x / 2.0
	var cy = get_viewport_rect().size.y / 2.0
	var pw = 580.0
	var ph = 600.0
	make_panel(cx - pw / 2, cy - ph / 2 - 20, pw, ph)
	var data = Campaign.get_level_data()

	var title = Label.new()
	title.text = "Campaign"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#e0d8c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(pw, 40)
	title.position = Vector2(cx - pw / 2, cy - ph / 2 + 15)
	title.name = "PanelTitle"
	add_child(title)

	var completed_count = Campaign.get_total_completed()
	var total_stars = Campaign.get_total_stars()
	var max_stars = len(Campaign.levels) * 3

	var stats = Label.new()
	var streak_str = ""
	if data.streak > 0: streak_str = "  Streak: " + str(data.streak)
	stats.text = "Progress: " + str(completed_count) + "/" + str(len(Campaign.levels)) + "  Stars: " + str(total_stars) + "/" + str(max_stars) + "  Wins: " + str(data.total_wins) + "  Losses: " + str(data.total_losses) + streak_str
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color("#8888aa"))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.size = Vector2(pw - 40, 20)
	stats.position = Vector2(cx - pw / 2 + 20, cy - ph / 2 + 52)
	add_child(stats)

	var bar_bg = ColorRect.new()
	bar_bg.color = Color("#0a0a15")
	bar_bg.size = Vector2(pw - 40, 14)
	bar_bg.position = Vector2(cx - pw / 2 + 20, cy - ph / 2 + 74)
	add_child(bar_bg)

	var bar_fill = ColorRect.new()
	bar_fill.color = Color("#2ecc71")
	var pct = float(completed_count) / float(len(Campaign.levels))
	bar_fill.size = Vector2(max(1, (pw - 40) * pct), 14)
	bar_fill.position = Vector2(cx - pw / 2 + 20, cy - ph / 2 + 74)
	bar_fill.name = "BarFill"
	add_child(bar_fill)

	var bar_lbl = Label.new()
	bar_lbl.text = str(completed_count) + " / " + str(len(Campaign.levels))
	bar_lbl.add_theme_font_size_override("font_size", 10)
	bar_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_lbl.size = Vector2(pw - 40, 14)
	bar_lbl.position = Vector2(cx - pw / 2 + 20, cy - ph / 2 + 74)
	add_child(bar_lbl)

	var cols = 2
	var cell_w = 250
	var cell_h = 78
	var grid_w = cols * cell_w + (cols - 1) * 12
	var grid_x = cx - grid_w / 2
	var grid_y = cy - ph / 2 + 100

	for level in Campaign.levels:
		var idx = level.id - 1
		var col = idx % cols
		var row = idx / cols
		var lx = grid_x + col * (cell_w + 12)
		var ly = grid_y + row * (cell_h + 8)
		var unlocked = Campaign.is_level_unlocked(level.id)
		var completed = data.completed.has(str(level.id)) and data.completed[str(level.id)]
		var stars = data.stars.get(str(level.id), 0)
		var is_current = data.current_level == level.id and not completed

		var border_color = Color("#2ecc71") if completed else (Color("#f1c40f") if is_current else (Color("#0f3460") if unlocked else Color("#1a1a2e")))
		var bg_color = Color("#0d1b2a") if unlocked else Color("#0a0a15")

		var cell_border = ColorRect.new()
		cell_border.color = border_color
		cell_border.size = Vector2(cell_w, cell_h)
		cell_border.position = Vector2(lx, ly)
		cell_border.name = "CellBorder" + str(level.id)
		add_child(cell_border)

		var cell = ColorRect.new()
		cell.color = bg_color
		cell.size = Vector2(cell_w - 4, cell_h - 4)
		cell.position = Vector2(lx + 2, ly + 2)
		cell.name = "Cell" + str(level.id)
		add_child(cell)

		var star_str = ""
		if completed:
			for s in range(stars): star_str += "★"
			for s in range(stars, 3): star_str += "☆"
		else:
			star_str = "☆☆☆"

		var lock_str = ""
		if not unlocked: lock_str = "  🔒"

		var lbl = Label.new()
		lbl.text = "Lv." + str(level.id) + " " + level.name + lock_str + "\n" + level.desc + "\n" + star_str
		lbl.add_theme_font_size_override("font_size", 11)
		if unlocked:
			lbl.add_theme_color_override("font_color", Color("#e0d8c8") if not completed else Color("#a0d8a0"))
		else:
			lbl.add_theme_color_override("font_color", Color("#444444"))
		lbl.size = Vector2(cell_w - 14, cell_h - 12)
		lbl.position = Vector2(lx + 7, ly + 6)
		lbl.name = "LblCell" + str(level.id)
		add_child(lbl)

		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if unlocked:
			var lid = level.id
			cell.mouse_entered.connect(func():
				if is_instance_valid(cell): cell.color = Color("#1a2744"))
			cell.mouse_exited.connect(func():
				if is_instance_valid(cell): cell.color = bg_color)
			cell.connect("gui_input", func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					show_campaign_level_detail(lid))

	var reset_btn = make_btn(cx - 140, cy + ph / 2 - 40, 110, 30, "Reset", 98)
	reset_btn.color = Color("#4a1a1a")
	reset_btn.mouse_entered.connect(func(): if is_instance_valid(reset_btn): reset_btn.color = Color("#6a2020"))
	reset_btn.mouse_exited.connect(func(): if is_instance_valid(reset_btn): reset_btn.color = Color("#4a1a1a"))
	reset_btn.connect("gui_input", func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Campaign.reset_progress()
			show_campaign())

	var back_btn = make_btn(cx + 30, cy + ph / 2 - 40, 110, 30, "Back", 99)
	back_btn.connect("gui_input", func(event):
		if event is InputEventMouseButton and event.pressed:
			show_main_menu())

func show_campaign_level_detail(level_id: int):
	clear_screen()
	current_screen = Screen.CAMPAIGN
	var cx = get_viewport_rect().size.x / 2.0
	var cy = get_viewport_rect().size.y / 2.0
	var pw = 420.0
	var ph = 400.0
	make_panel(cx - pw / 2, cy - ph / 2 - 20, pw, ph)
	var data = Campaign.get_level_data()

	var level = null
	for l in Campaign.levels:
		if l.id == level_id: level = l; break
	if level == null: return

	var completed = data.completed.has(str(level_id)) and data.completed[str(level_id)]
	var stars = data.stars.get(str(level_id), 0)

	var title = Label.new()
	title.text = "Level " + str(level.id) + ": " + level.name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#e0d8c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(pw, 36)
	title.position = Vector2(cx - pw / 2, cy - ph / 2 + 18)
	title.name = "DetailTitle"
	add_child(title)

	var star_lbl = Label.new()
	var star_txt = ""
	for s in range(3):
		if s < stars: star_txt += "★"
		else: star_txt += "☆"
	if not completed: star_txt = "☆☆☆"
	star_lbl.text = star_txt
	star_lbl.add_theme_font_size_override("font_size", 24)
	star_lbl.add_theme_color_override("font_color", Color("#f1c40f"))
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.size = Vector2(pw, 30)
	star_lbl.position = Vector2(cx - pw / 2, cy - ph / 2 + 55)
	add_child(star_lbl)

	var details = [
		{ label = "Objective", value = level.desc },
		{ label = "AI Difficulty", value = _ai_depth_name(level.ai_depth) + " (depth " + str(level.ai_depth) + ")" },
		{ label = "Status", value = "✓ Completed" if completed else (_get_objective_detail(level)) },
	]
	if completed and stars > 0:
		details.append({ label = "Record", value = "Moves: " + str(data.stars.get(str(level_id) + "_moves", "?")) })

	var start_y = cy - ph / 2 + 100
	for i in details.size():
		var d = details[i]
		var dlbl = Label.new()
		dlbl.text = d.label + ":"
		dlbl.add_theme_font_size_override("font_size", 13)
		dlbl.add_theme_color_override("font_color", Color("#8888cc"))
		dlbl.size = Vector2(140, 24)
		dlbl.position = Vector2(cx - 190, start_y + i * 28)
		add_child(dlbl)

		var vlbl = Label.new()
		vlbl.text = d.value
		vlbl.add_theme_font_size_override("font_size", 13)
		vlbl.add_theme_color_override("font_color", Color("#c0c0e0"))
		vlbl.size = Vector2(240, 24)
		vlbl.position = Vector2(cx - 50, start_y + i * 28)
		vlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(vlbl)

	if completed:
		var back_btn = make_btn(cx - 50, cy + ph / 2 - 50, 100, 36, "Back", 99)
		back_btn.connect("gui_input", func(event):
			if event is InputEventMouseButton and event.pressed:
				show_campaign())
	else:
		var play_btn = make_btn(cx - 110, cy + ph / 2 - 50, 100, 36, "Play", 97)
		play_btn.color = Color("#1a6b1a")
		play_btn.mouse_entered.connect(func(): if is_instance_valid(play_btn): play_btn.color = Color("#228b22"))
		play_btn.mouse_exited.connect(func(): if is_instance_valid(play_btn): play_btn.color = Color("#1a6b1a"))
		play_btn.connect("gui_input", func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				start_campaign_game(level.id, level.ai_depth))

		var back_btn = make_btn(cx + 10, cy + ph / 2 - 50, 100, 36, "Back", 99)
		back_btn.connect("gui_input", func(event):
			if event is InputEventMouseButton and event.pressed:
				show_campaign())

func _ai_depth_name(depth: int) -> String:
	match depth:
		2: return "Novice"
		3: return "Easy"
		4: return "Hard"
		5: return "Expert"
	return "Unknown"

func _get_objective_detail(level: Dictionary) -> String:
	match level.objective:
		"win": return "Win the game"
		"win_with_loss_limit": return "Lose ≤ " + str(level.get("loss_limit", 0)) + " pieces"
		"capture_queen_and_win": return "Capture queen & win"
		"win_with_material_lead": return "Lead by " + str(level.get("material_lead", 0) / 100) + " points"
		"win_in_moves": return "Win in ≤ " + str(level.get("move_limit", 0)) + " moves"
		"win_streak": return "Win " + str(level.get("streak", 0)) + " in a row"
	return ""

func start_campaign_game(level_id: int, depth: int):
	Engine.set_meta("game_config", { ai = true, depth = depth, campaign = true, campaign_level = level_id })
	get_tree().change_scene_to_file("res://game.tscn")

func show_credits():
	clear_screen()
	current_screen = Screen.CREDITS
	var cx = get_viewport_rect().size.x / 2.0
	var cy = get_viewport_rect().size.y / 2.0
	var pw = 420.0
	var ph = 440.0
	make_panel(cx - pw / 2, cy - ph / 2 - 20, pw, ph)

	var title = Label.new()
	title.text = "Credits"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#e0d8c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(pw, 40)
	title.position = Vector2(cx - pw / 2, cy - ph / 2 + 15)
	title.name = "PanelTitle"
	add_child(title)

	var credits = [
		{ role = "Developer", name = "Sheldon Ramu" },
		{ role = "Company", name = "NativeCodex" },
		{ role = "Company Description", name = "A Solo Developer Company" },
		{ role = "Operating System", name = "Linux Mint" },
		{ role = "Game Engine", name = "Godot Engine" },
		{ role = "AI Coding Assistant", name = "OpenCode" },
		{ role = "AI Model", name = "Big Pickle" },
		{ role = "3D Assets", name = "Poly Pizza / CC0" },
		{ role = "Font", name = "System Font" },
	]

	var start_y = cy - ph / 2 + 70
	for i in credits.size():
		var c = credits[i]
		var role_lbl = Label.new()
		role_lbl.text = c.role
		role_lbl.add_theme_font_size_override("font_size", 14)
		role_lbl.add_theme_color_override("font_color", Color("#8888cc"))
		role_lbl.size = Vector2(180, 28)
		role_lbl.position = Vector2(cx - 190, start_y + i * 34)
		add_child(role_lbl)

		var name_lbl = Label.new()
		name_lbl.text = c.name
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color("#e0d8c8"))
		name_lbl.size = Vector2(200, 28)
		name_lbl.position = Vector2(cx - 10, start_y + i * 34)
		add_child(name_lbl)

	var back_btn = make_btn(cx - 60, cy + ph / 2 - 50, 120, 36, "Back", 99)
	back_btn.connect("gui_input", func(event):
		if event is InputEventMouseButton and event.pressed:
			show_main_menu())

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if current_screen == Screen.MAIN:
			var gp = event.position
			var cx = get_viewport_rect().size.x / 2.0
			var bw = 260.0
			var bh = 44.0
			var start_y = 225.0
			var gap = 52.0
			var btn_rects = [
				Rect2(cx - bw / 2, start_y, bw, bh),
				Rect2(cx - bw / 2, start_y + gap, bw, bh),
				Rect2(cx - bw / 2, start_y + gap * 2, bw, bh),
				Rect2(cx - bw / 2, start_y + gap * 3, bw, bh),
				Rect2(cx - bw / 2, start_y + gap * 4, bw, bh),
				Rect2(cx - bw / 2, start_y + gap * 5, bw, bh),
			]
			if btn_rects[0].has_point(gp): show_campaign()
			elif btn_rects[1].has_point(gp): show_new_game()
			elif btn_rects[2].has_point(gp): show_load()
			elif btn_rects[3].has_point(gp): show_settings()
			elif btn_rects[4].has_point(gp): show_credits()
			elif btn_rects[5].has_point(gp): get_tree().quit()

		elif current_screen == Screen.SETTINGS:
			var gp = event.position
			var cx = get_viewport_rect().size.x / 2.0
			var cy = get_viewport_rect().size.y / 2.0
			var pw = 400.0
			var ph = 280.0
			var back_rect = Rect2(cx - 80, cy + 110, 160, 40)
			if back_rect.has_point(gp):
				var sd = get_node_or_null("SliderAI")
				if sd: Engine.set_meta("settings_ai_depth", sd.value)
				show_main_menu()

func start_game(ai: bool, depth: int):
	var ad = depth
	if ai and Engine.has_meta("settings_ai_depth"):
		var sd = Engine.get_meta("settings_ai_depth")
		ad = int(sd.value)
	Engine.set_meta("game_config", { ai = ai, depth = ad })
	get_tree().change_scene_to_file("res://game.tscn")
