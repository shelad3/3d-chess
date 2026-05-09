extends Control

var elapsed := 0.0
var started := false

func _ready():
	$"..".get_window().size = Vector2(800, 700)

	var bg = ColorRect.new()
	bg.color = Color("#1a1a2e")
	bg.size = get_viewport_rect().size
	bg.name = "BG"
	add_child(bg)

	var title = Label.new()
	title.text = "♚ CHESS ♔"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("#e0e0e0"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size = Vector2(600, 120)
	title.position = Vector2((get_viewport_rect().size.x - 600) / 2, 200)
	title.name = "Title"
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "3D Chess"
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color("#8888aa"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(400, 50)
	subtitle.position = Vector2((get_viewport_rect().size.x - 400) / 2, 320)
	subtitle.name = "Subtitle"
	add_child(subtitle)

	var prompt = Label.new()
	prompt.text = "Click anywhere to start"
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color("#666688"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.size = Vector2(400, 40)
	prompt.position = Vector2((get_viewport_rect().size.x - 400) / 2, 450)
	prompt.name = "Prompt"
	add_child(prompt)

	modulate = Color(1, 1, 1, 0)

func _process(delta):
	elapsed += delta
	if not started and elapsed < 1.0:
		modulate = Color(1, 1, 1, elapsed)
	elif not started:
		modulate = Color(1, 1, 1, 1)
		var prompt = get_node_or_null("Prompt")
		if prompt:
			prompt.modulate = Color(1, 1, 1, 0.5 + sin(elapsed * 3) * 0.5)

func _input(event):
	if event is InputEventMouseButton and event.pressed and not started:
		started = true
		create_tween().tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5).finished.connect(_go_menu)

func _go_menu():
	get_tree().change_scene_to_file("res://menu.tscn")
