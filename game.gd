extends Node3D

const Campaign = preload("res://campaign.gd")
const PIECE_VALUES = { 1: 100, 2: 320, 3: 330, 4: 500, 5: 900 }
const BOARD_SIZE := 8
const SQ_SIZE := 0.9
const HALF := BOARD_SIZE * SQ_SIZE / 2.0

enum Type { EMPTY, PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

var board: Array = []
var selected: Vector2i = Vector2i(-1, -1)
var turn: PieceColor = PieceColor.WHITE
var valid_moves: Array = []
var game_over := false
var en_passant_target: Vector2i = Vector2i(-1, -1)
var castling_rights = { PieceColor.WHITE: { "K": true, "Q": true }, PieceColor.BLACK: { "K": true, "Q": true } }
var move_log: Array = []
var ai_enabled := false
var ai_color: PieceColor = PieceColor.BLACK
var ai_depth := 3
var ai_thinking := false
var captured_white: Array = []
var captured_black: Array = []
var promotion_pos: Vector2i
var promotion_color: PieceColor

var board_mesh_instances: Array = []
var piece_nodes_3d: Array = []
var highlight_nodes_3d: Array = []
var ui_layer: Control
var status_label: Label
var move_label: Label
var captured_label_white: Label
var captured_label_black: Label
var promotion_panel: Control
var promo_buttons: Array = []
var camera_node: Camera3D
var camera_tween: Tween
var camera_white_pos := Vector3(0, 7, 7)
var camera_white_look := Vector3(0, 0.2, 0)
var camera_black_pos := Vector3(0, 7, -7)
var camera_black_look := Vector3(0, 0.2, 0)
var human_color: PieceColor = PieceColor.WHITE
var move_history: Array = []
var saved_games_dir: String
var campaign_mode := false
var campaign_level_id := 0
var move_count := 0
var pieces_lost := 0
var captured_enemy_queen := false
var current_material_diff := 0


const PIECE_SYMBOLS_2D = {
	PieceColor.WHITE: { Type.KING: "♔", Type.QUEEN: "♕", Type.ROOK: "♖", Type.BISHOP: "♗", Type.KNIGHT: "♘", Type.PAWN: "♙" },
	PieceColor.BLACK: { Type.KING: "♚", Type.QUEEN: "♛", Type.ROOK: "♜", Type.BISHOP: "♝", Type.KNIGHT: "♞", Type.PAWN: "♟" },
}

func configure(ai: bool, depth: int):
	ai_enabled = ai
	ai_depth = depth

func _ready():
	saved_games_dir = "user://saves"
	DirAccess.make_dir_recursive_absolute(saved_games_dir)
	setup_3d()

	var should_load := ""
	if Engine.has_meta("game_config"):
		var config = Engine.get_meta("game_config")
		ai_enabled = config.ai
		ai_depth = config.depth
		if config.has("human_color"):
			human_color = config.human_color
		if config.has("load_slot"):
			should_load = config.load_slot
		if config.has("campaign"):
			campaign_mode = true
			campaign_level_id = config.campaign_level
		Engine.remove_meta("game_config")

	if should_load != "":
		load_game(should_load)
	else:
		setup_board()
		render_board()
		_set_camera_for_turn(false)
		if ai_enabled and turn == ai_color:
			make_ai_move()

func setup_3d():
	get_window().size = Vector2(900, 780)

	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1a1a2e")
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment.ambient_light_color = Color("#1e2b3c")
	env.environment.ambient_light_energy = 0.4
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ssao_enabled = true
	env.environment.ssao_radius = 2.0
	env.environment.ssao_intensity = 0.6
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.25
	env.environment.glow_hdr_threshold = 1.2
	add_child(env)

	var sun = DirectionalLight3D.new()
	sun.position = Vector3(8, 14, 6)
	sun.light_color = Color("#ffe4c4")
	sun.light_energy = 1.8
	sun.light_indirect_energy = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.05
	sun.directional_shadow_max_distance = 25
	sun.directional_shadow_blend_splits = 4
	add_child(sun)
	sun.look_at(Vector3(0, 0, 0))

	var sky = DirectionalLight3D.new()
	sky.position = Vector3(-6, 10, -4)
	sky.light_color = Color("#87ceeb")
	sky.light_energy = 0.7
	sky.light_indirect_energy = 0.3
	add_child(sky)
	sky.look_at(Vector3(0, 0, 0))

	var bounce = DirectionalLight3D.new()
	bounce.position = Vector3(0, -2, 0)
	bounce.light_color = Color("#c8a96e")
	bounce.light_energy = 0.15
	add_child(bounce)
	bounce.look_at(Vector3(4, 0, 4))

	camera_white_pos = Vector3(0, 7, 7)
	camera_white_look = Vector3(0, 0.0, 0)
	camera_black_pos = Vector3(0, 7, -7)
	camera_black_look = Vector3(0, 0.0, 0)
	camera_node = Camera3D.new()
	camera_node.position = camera_white_pos
	add_child(camera_node)
	camera_node.current = true
	camera_node.look_at(camera_white_look)

	var table_mat = StandardMaterial3D.new()
	table_mat.albedo_color = Color("#5c3a1e")
	table_mat.metallic = 0.1
	table_mat.roughness = 0.8
	var table = MeshInstance3D.new()
	table.mesh = BoxMesh.new()
	table.mesh.size = Vector3(BOARD_SIZE * SQ_SIZE + 1.6, 0.15, BOARD_SIZE * SQ_SIZE + 1.6)
	table.position = Vector3(0, -0.12, 0)
	table.material_override = table_mat
	add_child(table)

	var table_leg_mat = StandardMaterial3D.new()
	table_leg_mat.albedo_color = Color("#3d2210")
	table_leg_mat.metallic = 0.2
	table_leg_mat.roughness = 0.7
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var leg = MeshInstance3D.new()
		leg.mesh = CylinderMesh.new()
		leg.mesh.top_radius = 0.06
		leg.mesh.bottom_radius = 0.075
		leg.mesh.height = 0.4
		var board_hw = BOARD_SIZE * SQ_SIZE / 2.0
		leg.position = Vector3(corner.x * (board_hw + 0.5), -0.35, corner.z * (board_hw + 0.5))
		leg.material_override = table_leg_mat
		add_child(leg)

	ui_layer = Control.new()
	ui_layer.size = get_window().size
	ui_layer.anchors_preset = Control.PRESET_FULL_RECT
	add_child(ui_layer)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color("#d0d0e0"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.size = Vector2(400, 30)
	status_label.position = Vector2((ui_layer.size.x - 400) / 2, 10)
	ui_layer.add_child(status_label)

	move_label = Label.new()
	move_label.add_theme_font_size_override("font_size", 14)
	move_label.add_theme_color_override("font_color", Color("#8888aa"))
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_label.size = Vector2(800, 20)
	move_label.position = Vector2(50, 720)
	move_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_layer.add_child(move_label)

	captured_label_black = Label.new()
	captured_label_black.add_theme_font_size_override("font_size", 16)
	captured_label_black.add_theme_color_override("font_color", Color("#cccccc"))
	captured_label_black.size = Vector2(400, 30)
	captured_label_black.position = Vector2(10, 50)
	ui_layer.add_child(captured_label_black)

	captured_label_white = Label.new()
	captured_label_white.add_theme_font_size_override("font_size", 16)
	captured_label_white.add_theme_color_override("font_color", Color("#dddddd"))
	captured_label_white.size = Vector2(400, 30)
	captured_label_white.position = Vector2(480, 50)
	ui_layer.add_child(captured_label_white)

	var restart_btn = ColorRect.new()
	restart_btn.color = Color("#16213e")
	restart_btn.size = Vector2(120, 36)
	restart_btn.position = Vector2((ui_layer.size.x - 120) / 2, 675)
	restart_btn.name = "RestartBtn"
	ui_layer.add_child(restart_btn)

	var rlbl = Label.new()
	rlbl.text = "Restart"
	rlbl.add_theme_font_size_override("font_size", 16)
	rlbl.add_theme_color_override("font_color", Color("#c0c0e0"))
	rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rlbl.size = Vector2(120, 36)
	rlbl.position = restart_btn.position
	ui_layer.add_child(rlbl)

	var menu_btn = ColorRect.new()
	menu_btn.color = Color("#16213e")
	menu_btn.size = Vector2(120, 36)
	menu_btn.position = Vector2((ui_layer.size.x - 120) / 2, 635)
	menu_btn.name = "MenuBtn"
	ui_layer.add_child(menu_btn)

	var mlbl = Label.new()
	mlbl.text = "Main Menu"
	mlbl.add_theme_font_size_override("font_size", 16)
	mlbl.add_theme_color_override("font_color", Color("#c0c0e0"))
	mlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mlbl.size = Vector2(120, 36)
	mlbl.position = menu_btn.position
	ui_layer.add_child(mlbl)

func board_pos(col: int, row: int) -> Vector3:
	return Vector3((col - 3.5) * SQ_SIZE, 0, (row - 3.5) * SQ_SIZE)

func board_col_row(pos: Vector3) -> Vector2i:
	var col = roundi(pos.x / SQ_SIZE + 3.5)
	var row = roundi(pos.z / SQ_SIZE + 3.5)
	if col < 0 or col >= BOARD_SIZE or row < 0 or row >= BOARD_SIZE:
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func clear_3d():
	for n in board_mesh_instances:
		if is_instance_valid(n): n.queue_free()
	board_mesh_instances.clear()
	clear_pieces()
	clear_highlights()

func clear_pieces():
	for row in piece_nodes_3d:
		for n in row:
			if n != null and is_instance_valid(n):
				n.queue_free()
	piece_nodes_3d = []

func clear_highlights():
	for n in highlight_nodes_3d:
		if is_instance_valid(n): n.queue_free()
	highlight_nodes_3d.clear()

func render_board():
	clear_3d()
	draw_board_3d()
	draw_pieces_3d()
	draw_highlights_3d()
	update_ui()

func draw_board_3d():
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var is_light = (x + y) % 2 == 0

			var body = StaticBody3D.new()
			body.position = board_pos(x, y) + Vector3(0, -0.04, 0)
			body.name = "Square_" + str(x) + "_" + str(y)
			add_child(body)

			var col = CollisionShape3D.new()
			col.shape = BoxShape3D.new()
			col.shape.size = Vector3(SQ_SIZE, 0.08, SQ_SIZE)
			body.add_child(col)

			var mesh = MeshInstance3D.new()
			mesh.mesh = BoxMesh.new()
			mesh.mesh.size = Vector3(SQ_SIZE, 0.08, SQ_SIZE)
			mesh.material_override = StandardMaterial3D.new()
			mesh.material_override.albedo_color = Color("#f0d9b5") if is_light else Color("#b58863")
			body.add_child(mesh)

			board_mesh_instances.append(mesh)

	var floor_body = StaticBody3D.new()
	floor_body.position = Vector3(0, -0.06, 0)
	add_child(floor_body)

	var floor_col = CollisionShape3D.new()
	floor_col.shape = BoxShape3D.new()
	floor_col.shape.size = Vector3(BOARD_SIZE * SQ_SIZE + 0.4, 0.04, BOARD_SIZE * SQ_SIZE + 0.4)
	floor_body.add_child(floor_col)

	var floor_mesh = MeshInstance3D.new()
	floor_mesh.mesh = BoxMesh.new()
	floor_mesh.mesh.size = Vector3(BOARD_SIZE * SQ_SIZE + 0.4, 0.04, BOARD_SIZE * SQ_SIZE + 0.4)
	floor_mesh.material_override = StandardMaterial3D.new()
	floor_mesh.material_override.albedo_color = Color("#3d2b1f")
	floor_body.add_child(floor_mesh)
	board_mesh_instances.append(floor_mesh)

func draw_pieces_3d():
	piece_nodes_3d = []
	for y in BOARD_SIZE:
		var row_nodes = []
		for x in BOARD_SIZE:
			row_nodes.append(null)
		piece_nodes_3d.append(row_nodes)

	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null:
				var pnode = create_piece_mesh(p.type, p.color)
				pnode.position = board_pos(x, y) + Vector3(0, 0.04, 0)
				add_child(pnode)
				piece_nodes_3d[y][x] = pnode

func get_piece_scene_path(type: Type) -> String:
	match type:
		Type.PAWN: return "res://assets/pawn/scene.gltf"
		Type.ROOK: return "res://assets/rook/scene.gltf"
		Type.KNIGHT: return "res://assets/knight/scene.gltf"
		Type.BISHOP: return "res://assets/bishop/scene.gltf"
		Type.QUEEN: return "res://assets/queen/scene.gltf"
		Type.KING: return "res://assets/king/scene.gltf"
	return ""

func get_piece_gltf_height_estimate(type: Type) -> float:
	match type:
		Type.PAWN: return 11.2
		Type.ROOK: return 30.2
		Type.KNIGHT: return 15.0
		Type.BISHOP: return 8.4
		Type.QUEEN: return 20.0
		Type.KING: return 25.0
	return 10.0

func recolor_piece(node: Node, color: PieceColor):
	if color == PieceColor.WHITE:
		return
	for c in node.get_children():
		if c is MeshInstance3D and c.material_override != null:
			var mat = c.material_override.duplicate()
			mat.albedo_color = Color("#1a1a1a")
			mat.metallic = 0.5
			mat.roughness = 0.4
			c.material_override = mat
		elif c is MeshInstance3D and c.mesh != null and c.material_override == null:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color("#1a1a1a")
			mat.metallic = 0.5
			mat.roughness = 0.4
			c.material_override = mat
		recolor_piece(c, color)

func create_piece_mesh(type: Type, color: PieceColor) -> Node3D:
	var path = get_piece_scene_path(type)
	var scene = null
	if path != "":
		scene = load(path)
	if scene == null:
		return _create_placeholder_mesh(type, color)

	var root = scene.instantiate()

	var height = get_piece_gltf_height_estimate(type)
	var desired = 0.28 if type == Type.PAWN else 0.35 if type == Type.KING else 0.3
	var sc = desired / height
	root.scale = Vector3(sc, sc, sc)

	for c in root.get_children():
		if c is MeshInstance3D:
			var aabb = c.mesh.get_aabb()
			var bottom = aabb.position.y
			root.position.y = -bottom * sc + 0.02
			break

	recolor_piece(root, color)
	return root

func _create_placeholder_mesh(type: Type, color: PieceColor) -> Node3D:
	var root = Node3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#f5f5f0") if color == PieceColor.WHITE else Color("#1a1a1a")
	mat.metallic = 0.6
	mat.roughness = 0.3

	var mat2 = StandardMaterial3D.new()
	mat2.albedo_color = Color("#e8e8e0") if color == PieceColor.WHITE else Color("#2a2a2a")
	mat2.metallic = 0.5
	mat2.roughness = 0.4

	var S = 0.18

	match type:
		Type.PAWN:
			var body = MeshInstance3D.new()
			body.mesh = CylinderMesh.new()
			body.mesh.top_radius = S * 0.7
			body.mesh.bottom_radius = S * 0.85
			body.mesh.height = S * 1.2
			body.position.y = S * 0.6
			body.material_override = mat
			root.add_child(body)

			var head = MeshInstance3D.new()
			head.mesh = SphereMesh.new()
			head.mesh.radius = S * 0.35
			head.mesh.height = S * 0.7
			head.position.y = S * 1.4
			head.material_override = mat2
			root.add_child(head)

		Type.ROOK:
			var body = MeshInstance3D.new()
			body.mesh = CylinderMesh.new()
			body.mesh.top_radius = S * 0.7
			body.mesh.bottom_radius = S * 0.8
			body.mesh.height = S * 1.6
			body.position.y = S * 0.8
			body.material_override = mat
			root.add_child(body)

			var rim = MeshInstance3D.new()
			rim.mesh = CylinderMesh.new()
			rim.mesh.top_radius = S * 0.75
			rim.mesh.bottom_radius = S * 0.8
			rim.mesh.height = S * 0.1
			rim.position.y = S * 1.65
			rim.material_override = mat2
			root.add_child(rim)

		Type.KNIGHT:
			var body = MeshInstance3D.new()
			body.mesh = CylinderMesh.new()
			body.mesh.top_radius = S * 0.65
			body.mesh.bottom_radius = S * 0.75
			body.mesh.height = S * 1.3
			body.position.y = S * 0.65
			body.material_override = mat
			root.add_child(body)

			var head = MeshInstance3D.new()
			head.mesh = BoxMesh.new()
			head.mesh.size = Vector3(S * 0.6, S * 0.5, S * 0.4)
			head.position = Vector3(S * 0.25, S * 1.4, 0)
			head.rotation.z = 0.3
			head.material_override = mat2
			root.add_child(head)

		Type.BISHOP:
			var body = MeshInstance3D.new()
			body.mesh = CylinderMesh.new()
			body.mesh.top_radius = S * 0.6
			body.mesh.bottom_radius = S * 0.75
			body.mesh.height = S * 1.2
			body.position.y = S * 0.6
			body.material_override = mat
			root.add_child(body)

			var hat = MeshInstance3D.new()
			hat.mesh = CylinderMesh.new()
			hat.mesh.top_radius = 0.005
			hat.mesh.bottom_radius = S * 0.45
			hat.mesh.height = S * 0.7
			hat.position.y = S * 1.55
			hat.material_override = mat2
			root.add_child(hat)

		Type.QUEEN:
			var body = MeshInstance3D.new()
			body.mesh = CylinderMesh.new()
			body.mesh.top_radius = S * 0.7
			body.mesh.bottom_radius = S * 0.85
			body.mesh.height = S * 1.3
			body.position.y = S * 0.65
			body.material_override = mat
			root.add_child(body)

			var crown = MeshInstance3D.new()
			crown.mesh = CylinderMesh.new()
			crown.mesh.top_radius = S * 0.5
			crown.mesh.bottom_radius = S * 0.65
			crown.mesh.height = S * 0.4
			crown.position.y = S * 1.5
			crown.material_override = mat2
			root.add_child(crown)

			var top = MeshInstance3D.new()
			top.mesh = SphereMesh.new()
			top.mesh.radius = S * 0.25
			top.mesh.height = S * 0.5
			top.position.y = S * 1.9
			top.material_override = mat2
			root.add_child(top)

		Type.KING:
			var body = MeshInstance3D.new()
			body.mesh = CylinderMesh.new()
			body.mesh.top_radius = S * 0.75
			body.mesh.bottom_radius = S * 0.9
			body.mesh.height = S * 1.5
			body.position.y = S * 0.75
			body.material_override = mat
			root.add_child(body)

			var collar = MeshInstance3D.new()
			collar.mesh = CylinderMesh.new()
			collar.mesh.top_radius = S * 0.55
			collar.mesh.bottom_radius = S * 0.65
			collar.mesh.height = S * 0.2
			collar.position.y = S * 1.6
			collar.material_override = mat2
			root.add_child(collar)

			var head = MeshInstance3D.new()
			head.mesh = SphereMesh.new()
			head.mesh.radius = S * 0.35
			head.mesh.height = S * 0.7
			head.position.y = S * 2.0
			head.material_override = mat2
			root.add_child(head)

			var cross_v = MeshInstance3D.new()
			cross_v.mesh = BoxMesh.new()
			cross_v.mesh.size = Vector3(S * 0.08, S * 0.5, S * 0.08)
			cross_v.position.y = S * 2.5
			cross_v.material_override = mat
			root.add_child(cross_v)

			var cross_h = MeshInstance3D.new()
			cross_h.mesh = BoxMesh.new()
			cross_h.mesh.size = Vector3(S * 0.35, S * 0.08, S * 0.08)
			cross_h.position.y = S * 2.35
			cross_h.material_override = mat
			root.add_child(cross_h)

	return root

func draw_highlights_3d():
	for mv in valid_moves:
		var is_cap = board[mv.y][mv.x] != null
		var hl = MeshInstance3D.new()
		hl.mesh = BoxMesh.new()
		if is_cap:
			hl.mesh.size = Vector3(SQ_SIZE, 0.02, SQ_SIZE)
			hl.material_override = StandardMaterial3D.new()
			hl.material_override.albedo_color = Color(0.8, 0.2, 0.15, 0.5)
			hl.position = board_pos(mv.x, mv.y) + Vector3(0, 0.02, 0)
		else:
			hl.mesh.size = Vector3(SQ_SIZE * 0.3, 0.02, SQ_SIZE * 0.3)
			hl.material_override = StandardMaterial3D.new()
			hl.material_override.albedo_color = Color(0.2, 0.8, 0.2, 0.4)
			hl.position = board_pos(mv.x, mv.y) + Vector3(0, 0.02, 0)
		add_child(hl)
		highlight_nodes_3d.append(hl)

	if selected != Vector2i(-1, -1):
		var hl = MeshInstance3D.new()
		hl.mesh = BoxMesh.new()
		hl.mesh.size = Vector3(SQ_SIZE, 0.02, SQ_SIZE)
		hl.material_override = StandardMaterial3D.new()
		hl.material_override.albedo_color = Color("#829769")
		hl.position = board_pos(selected.x, selected.y) + Vector3(0, 0.02, 0)
		add_child(hl)
		highlight_nodes_3d.append(hl)

func update_ui():
	if status_label:
		if game_over:
			status_label.text = "Game Over"
		elif ai_thinking:
			status_label.text = "AI thinking..."
		else:
			status_label.text = piece_color_str(turn) + "'s turn"

	if move_label:
		var lines = []
		for i in range(0, move_log.size(), 2):
			var n = i / 2 + 1
			var w = format_move(move_log[i])
			var b = ""
			if i + 1 < move_log.size():
				b = format_move(move_log[i + 1])
			lines.append(str(n) + ". " + w + "  " + b)
		move_label.text = "  ".join(lines)

	if captured_label_white:
		var text = ""
		for p in captured_white:
			text += PIECE_SYMBOLS_2D[PieceColor.BLACK][p.type]
		captured_label_white.text = "Captured: " + text

	if captured_label_black:
		var text = ""
		for p in captured_black:
			text += PIECE_SYMBOLS_2D[PieceColor.WHITE][p.type]
		captured_label_black.text = "Captured: " + text

func _set_camera_for_turn(animate: bool = true):
	if ai_enabled:
		var target = camera_white_pos if human_color == PieceColor.WHITE else camera_black_pos
		var look = camera_white_look if human_color == PieceColor.WHITE else camera_black_look
		_move_camera(target, look, animate)
	else:
		if turn == PieceColor.WHITE:
			_move_camera(camera_white_pos, camera_white_look, animate)
		else:
			_move_camera(camera_black_pos, camera_black_look, animate)

func _move_camera(pos: Vector3, look: Vector3, animate: bool = true):
	if not animate:
		camera_node.position = pos
		camera_node.look_at(look)
		return
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	camera_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_parallel(true)
	camera_tween.tween_property(camera_node, "position", pos, 0.6)
	camera_tween.tween_method(_camera_look_at.bind(look), 0.0, 1.0, 0.6)

func _camera_look_at(_val: float, look: Vector3):
	camera_node.look_at(look)

func format_move(entry) -> String:
	var cols = "abcdefgh"
	var from_str = cols[entry.from.x] + str(8 - entry.from.y)
	var to_str = cols[entry.to.x] + str(8 - entry.to.y)
	var pname = { Type.PAWN: "", Type.ROOK: "R", Type.KNIGHT: "N", Type.BISHOP: "B", Type.QUEEN: "Q", Type.KING: "K" }
	var captured_str = "x" if entry.captured != null else ""
	var flags_str = entry.get("flags", "")
	return pname[entry.piece.type] + from_str + captured_str + to_str + flags_str

func piece_color_str(c: PieceColor) -> String:
	return "White" if c == PieceColor.WHITE else "Black"

func opp(c: PieceColor) -> PieceColor:
	return PieceColor.BLACK if c == PieceColor.WHITE else PieceColor.WHITE

func is_in_bounds(v: Vector2i) -> bool:
	return v.x >= 0 and v.x < BOARD_SIZE and v.y >= 0 and v.y < BOARD_SIZE

func get_piece_at(v: Vector2i):
	if not is_in_bounds(v): return null
	return board[v.y][v.x]

func is_empty(v: Vector2i) -> bool:
	return get_piece_at(v) == null

func enemy_at(v: Vector2i, c: PieceColor) -> bool:
	var p = get_piece_at(v)
	return p != null and p.color != c

func _setup_board():
	board = []
	for y in BOARD_SIZE:
		var row = []
		for x in BOARD_SIZE:
			row.append(null)
		board.append(row)
	for x in BOARD_SIZE:
		board[1][x] = { type = Type.PAWN, color = PieceColor.BLACK }
		board[6][x] = { type = Type.PAWN, color = PieceColor.WHITE }
	var back = [Type.ROOK, Type.KNIGHT, Type.BISHOP, Type.QUEEN, Type.KING, Type.BISHOP, Type.KNIGHT, Type.ROOK]
	for x in BOARD_SIZE:
		board[0][x] = { type = back[x], color = PieceColor.BLACK }
		board[7][x] = { type = back[x], color = PieceColor.WHITE }

func setup_board():
	_setup_board()

func get_raw_moves(pos: Vector2i) -> Array:
	return _get_raw_moves_from(board, pos)

func _get_raw_moves_from(bd: Array, pos: Vector2i) -> Array:
	var p = bd[pos.y][pos.x]
	if p == null: return []
	var moves: Array = []
	var c = p.color
	var dir = -1 if c == PieceColor.WHITE else 1

	match p.type:
		Type.PAWN:
			var fwd = Vector2i(pos.x, pos.y + dir)
			if is_in_bounds(fwd) and bd[fwd.y][fwd.x] == null:
				moves.append(fwd)
				var start = 6 if c == PieceColor.WHITE else 1
				if pos.y == start:
					var f2 = Vector2i(pos.x, pos.y + 2 * dir)
					if bd[f2.y][f2.x] == null:
						moves.append(f2)
			for dx in [-1, 1]:
				var d = Vector2i(pos.x + dx, pos.y + dir)
				if is_in_bounds(d) and bd[d.y][d.x] != null and bd[d.y][d.x].color != c:
					moves.append(d)
				if d == en_passant_target:
					moves.append(d)
		Type.ROOK:
			for dd in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]:
				var t = pos + dd
				while is_in_bounds(t):
					if bd[t.y][t.x] == null:
						moves.append(t)
					else:
						if bd[t.y][t.x].color != c:
							moves.append(t)
						break
					t += dd
		Type.KNIGHT:
			for dd in [Vector2i(1,2),Vector2i(2,1),Vector2i(-1,2),Vector2i(-2,1),Vector2i(1,-2),Vector2i(2,-1),Vector2i(-1,-2),Vector2i(-2,-1)]:
				var t = pos + dd
				if is_in_bounds(t) and (bd[t.y][t.x] == null or bd[t.y][t.x].color != c):
					moves.append(t)
		Type.BISHOP:
			for dd in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
				var t = pos + dd
				while is_in_bounds(t):
					if bd[t.y][t.x] == null:
						moves.append(t)
					else:
						if bd[t.y][t.x].color != c:
							moves.append(t)
						break
					t += dd
		Type.QUEEN:
			for dd in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
				var t = pos + dd
				while is_in_bounds(t):
					if bd[t.y][t.x] == null:
						moves.append(t)
					else:
						if bd[t.y][t.x].color != c:
							moves.append(t)
						break
					t += dd
		Type.KING:
			for dd in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
				var t = pos + dd
				if is_in_bounds(t) and (bd[t.y][t.x] == null or bd[t.y][t.x].color != c):
					moves.append(t)
			var row = 7 if c == PieceColor.WHITE else 0
			if pos == Vector2i(4, row):
				if castling_rights[c]["K"] and bd[row][5] == null and bd[row][6] == null:
					var rp = bd[row][7]
					if rp != null and rp.type == Type.ROOK and rp.color == c:
						if not _is_square_attacked_in(board, pos, opp(c)) and not _is_square_attacked_in(board, Vector2i(5,row), opp(c)) and not _is_square_attacked_in(board, Vector2i(6,row), opp(c)):
							moves.append(Vector2i(6,row))
				if castling_rights[c]["Q"] and bd[row][1] == null and bd[row][2] == null and bd[row][3] == null:
					var rp = bd[row][0]
					if rp != null and rp.type == Type.ROOK and rp.color == c:
						if not _is_square_attacked_in(board, pos, opp(c)) and not _is_square_attacked_in(board, Vector2i(3,row), opp(c)) and not _is_square_attacked_in(board, Vector2i(2,row), opp(c)):
							moves.append(Vector2i(2,row))
	return moves

func find_king(c: PieceColor) -> Vector2i:
	return _find_king_in(board, c)

func _find_king_in(bd: Array, c: PieceColor) -> Vector2i:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = bd[y][x]
			if p != null and p.type == Type.KING and p.color == c:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func is_square_attacked(pos: Vector2i, by_color: PieceColor) -> bool:
	return _is_square_attacked_in(board, pos, by_color)

func _is_square_attacked_in(bd: Array, pos: Vector2i, by_color: PieceColor) -> bool:
	if pos == Vector2i(-1, -1): return false
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = bd[y][x]
			if p == null or p.color != by_color: continue
			var f = Vector2i(x, y)
			if p.type == Type.PAWN:
				var dir = -1 if p.color == PieceColor.WHITE else 1
				for dx in [-1, 1]:
					if f + Vector2i(dx, dir) == pos: return true
			elif p.type == Type.KNIGHT:
				for dd in [Vector2i(1,2),Vector2i(2,1),Vector2i(-1,2),Vector2i(-2,1),Vector2i(1,-2),Vector2i(2,-1),Vector2i(-1,-2),Vector2i(-2,-1)]:
					if f + dd == pos: return true
			elif p.type in [Type.ROOK, Type.QUEEN]:
				for dd in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]:
					var t = f + dd
					while is_in_bounds(t):
						if t == pos: return true
						if bd[t.y][t.x] != null: break
						t += dd
			elif p.type in [Type.BISHOP, Type.QUEEN]:
				for dd in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
					var t = f + dd
					while is_in_bounds(t):
						if t == pos: return true
						if bd[t.y][t.x] != null: break
						t += dd
			elif p.type == Type.KING:
				for dd in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
					if f + dd == pos: return true
	return false

func is_in_check(c: PieceColor) -> bool:
	var kp = find_king(c)
	return _is_square_attacked_in(board, kp, opp(c))

func simulate_move(from: Vector2i, to: Vector2i) -> Array:
	var new_board = []
	for y in BOARD_SIZE:
		var row = []
		for x in BOARD_SIZE:
			row.append(board[y][x])
		new_board.append(row)
	var temp = board
	board = new_board
	var captured = board[to.y][to.x]
	board[to.y][to.x] = board[from.y][from.x]
	board[from.y][from.x] = null
	var result = [board, captured]
	board = temp
	return result

func get_legal_moves(pos: Vector2i) -> Array:
	var p = board[pos.y][pos.x]
	if p == null: return []
	var raw = _get_raw_moves_from(board, pos)
	var legal: Array = []
	for mv in raw:
		var sim = simulate_move(pos, mv)
		var real_board = board
		board = sim[0]
		if not is_in_check(p.color):
			legal.append(mv)
		board = real_board
	return legal

func has_legal_moves(c: PieceColor) -> bool:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.color == c:
				if get_legal_moves(Vector2i(x, y)).size() > 0: return true
	return false

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S and event.ctrl_pressed:
			save_game("quicksave")
			return
		if event.keycode == KEY_L and event.ctrl_pressed:
			var saves = get_saved_games()
			if "quicksave" in saves:
				load_game("quicksave")
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_over or ai_thinking:
			return
		var gp = event.position
		if _handle_ui_click(gp):
			return
		_handle_board_click(gp)

func _handle_ui_click(gp: Vector2) -> bool:
	var restart = ui_layer.get_node_or_null("RestartBtn")
	if restart and Rect2(restart.position, restart.size).has_point(gp):
		restart_game()
		return true
	var menu = ui_layer.get_node_or_null("MenuBtn")
	if menu and Rect2(menu.position, menu.size).has_point(gp):
		get_tree().change_scene_to_file("res://menu.tscn")
		return true
	if promotion_panel and promotion_panel.visible:
		return _handle_promotion_click(gp)
	return false

func _handle_board_click(gp: Vector2):
	var space = get_world_3d().direct_space_state
	if space == null: return

	var from = camera_node.project_ray_origin(gp)
	var dir = camera_node.project_ray_normal(gp)
	var ray = PhysicsRayQueryParameters3D.new()
	ray.from = from
	ray.to = from + dir * 50

	var result = space.intersect_ray(ray)
	if result.is_empty():
		selected = Vector2i(-1, -1)
		valid_moves = []
		render_board()
		return

	var hit_pos = result.position
	var br = board_col_row(hit_pos)
	if br == Vector2i(-1, -1):
		selected = Vector2i(-1, -1)
		valid_moves = []
		render_board()
		return

	if selected == Vector2i(-1, -1):
		var p = board[br.y][br.x]
		if p != null and p.color == turn:
			selected = br
			valid_moves = get_legal_moves(br)
			render_board()
	else:
		if valid_moves.has(br):
			execute_move(selected, br)
			selected = Vector2i(-1, -1)
			valid_moves = []
			render_board()
			check_game_state()
			if not game_over and ai_enabled and turn == ai_color:
				make_ai_move()
		else:
			var p = board[br.y][br.x]
			if p != null and p.color == turn:
				selected = br
				valid_moves = get_legal_moves(br)
				render_board()
			else:
				selected = Vector2i(-1, -1)
				valid_moves = []
				render_board()

func execute_move(from: Vector2i, to: Vector2i):
	var p = board[from.y][from.x]
	if p == null: return
	var captured = board[to.y][to.x]
	var flags := ""

	if p.type == Type.PAWN and to == en_passant_target:
		var ep = Vector2i(to.x, from.y)
		captured = board[ep.y][ep.x]
		board[ep.y][ep.x] = null
		flags = "ep"
	elif p.type == Type.PAWN and abs(to.y - from.y) == 2:
		en_passant_target = Vector2i(from.x, from.y + (to.y - from.y) / 2)
	else:
		en_passant_target = Vector2i(-1, -1)

	if p.type == Type.KING and abs(to.x - from.x) == 2:
		if to.x == 6:
			board[from.y][5] = board[from.y][7]
			board[from.y][7] = null
			flags = "O-O"
		elif to.x == 2:
			board[from.y][3] = board[from.y][0]
			board[from.y][0] = null
			flags = "O-O-O"

	if p.type == Type.KING:
		castling_rights[p.color]["K"] = false
		castling_rights[p.color]["Q"] = false
	if p.type == Type.ROOK:
		var row = 7 if p.color == PieceColor.WHITE else 0
		if from == Vector2i(7, row): castling_rights[p.color]["K"] = false
		if from == Vector2i(0, row): castling_rights[p.color]["Q"] = false

	if captured != null:
		if captured.color == PieceColor.WHITE:
			captured_white.append(captured)
		else:
			captured_black.append(captured)

	board[to.y][to.x] = p
	board[from.y][from.x] = null

	if p.type == Type.PAWN and (to.y == 0 or to.y == 7):
		promote_pawn(to, p.color)
		return

	move_log.append({ from = from, to = to, piece = p, captured = captured, flags = flags })
	_update_campaign_stats()
	turn = opp(turn)
	_set_camera_for_turn()
	render_board()

func promote_pawn(pos: Vector2i, color: PieceColor):
	show_promotion_dialog(pos, color)

func show_promotion_dialog(pos: Vector2i, color: PieceColor):
	promotion_pos = pos
	promotion_color = color
	promotion_panel = Control.new()
	promotion_panel.size = get_window().size
	promotion_panel.name = "PromotionPanel"
	ui_layer.add_child(promotion_panel)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = promotion_panel.size
	promotion_panel.add_child(bg)

	var panel = ColorRect.new()
	panel.color = Color("#2d2d2d")
	panel.size = Vector2(SQ_SIZE * 100 + 40, SQ_SIZE * 30 + 40)
	panel.position = Vector2((promotion_panel.size.x - panel.size.x) / 2, (promotion_panel.size.y - panel.size.y) / 2)
	promotion_panel.add_child(panel)

	var types = [Type.QUEEN, Type.ROOK, Type.BISHOP, Type.KNIGHT]
	promo_buttons = []
	for i in 4:
		var btn = ColorRect.new()
		btn.color = Color("#16213e")
		btn.size = Vector2(SQ_SIZE * 25, SQ_SIZE * 30)
		btn.position = Vector2(panel.position.x + 10 + i * (SQ_SIZE * 25 + 10), panel.position.y + 10)
		btn.name = "PromoBtn" + str(i)
		promotion_panel.add_child(btn)
		promo_buttons.append(btn)

		var lbl = Label.new()
		lbl.text = PIECE_SYMBOLS_2D[color][types[i]]
		lbl.add_theme_font_size_override("font_size", 48)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = btn.size
		lbl.position = btn.position
		promotion_panel.add_child(lbl)

	promotion_panel.visible = true

func _handle_promotion_click(gp: Vector2) -> bool:
	for i in promo_buttons.size():
		if Rect2(promo_buttons[i].position, promo_buttons[i].size).has_point(gp):
			var types = [Type.QUEEN, Type.ROOK, Type.BISHOP, Type.KNIGHT]
			_execute_promotion(types[i])
			return true
	return false

func _execute_promotion(ptype: Type):
	var p = board[promotion_pos.y][promotion_pos.x]
	if p == null: return
	var captured = null
	board[promotion_pos.y][promotion_pos.x] = { type = ptype, color = promotion_color }
	move_log.append({ from = promotion_pos, to = promotion_pos, piece = board[promotion_pos.y][promotion_pos.x], captured = captured, flags = "=Q" })

	promotion_panel.queue_free()
	promotion_panel = null
	promo_buttons = []

	turn = opp(turn)
	_set_camera_for_turn()
	render_board()
	check_game_state()
	if not game_over and ai_enabled and turn == ai_color:
		make_ai_move()

func check_game_state():
	var c = turn
	if is_in_check(c):
		if not has_legal_moves(c):
			game_over = true
			var winner_color = opp(c)
			var winner = piece_color_str(winner_color)
			show_game_over(winner + " wins by checkmate!", winner_color)
		else:
			show_message(piece_color_str(c) + " is in check!")
	elif not has_legal_moves(c):
		game_over = true
		show_game_over("Stalemate - Draw!")
	update_ui()

func _check_campaign_complete(winner):
	if not campaign_mode or not game_over: return
	if winner == null or winner != human_color:
		if winner != null:
			Campaign.record_loss()
		return

	var level_data = Campaign.get_level_data()
	var stars = Campaign.get_stars_for_level(campaign_level_id, move_count, pieces_lost, captured_enemy_queen, current_material_diff)
	Campaign.complete_level(campaign_level_id, stars, move_count)

	if status_label:
		status_label.text = "LEVEL COMPLETE! Stars: " + str(stars) + "/3"

func show_message(msg: String):
	get_node_or_null("StatusLabel")
	if status_label:
		status_label.text = msg

func show_game_over(msg: String, winner = null):
	if status_label:
		status_label.text = msg

	if campaign_mode:
		_check_campaign_complete(winner)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.size = get_window().size
	overlay.name = "GameOverOverlay"
	ui_layer.add_child(overlay)

	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color("#f0d0d0"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(500, 80)
	lbl.position = Vector2((ui_layer.size.x - 500) / 2, ui_layer.size.y / 2 - 60)
	ui_layer.add_child(lbl)

	var rlbl = Label.new()
	rlbl.text = "Click anywhere to " + ("return to menu" if campaign_mode else "restart")
	rlbl.add_theme_font_size_override("font_size", 20)
	rlbl.add_theme_color_override("font_color", Color("#c0c0c0"))
	rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rlbl.size = Vector2(400, 40)
	rlbl.position = Vector2((ui_layer.size.x - 400) / 2, ui_layer.size.y / 2 + 20)
	ui_layer.add_child(rlbl)

	var overlay_obj = overlay
	await get_tree().create_timer(0.1).timeout
	var ov = ui_layer.get_node_or_null("GameOverOverlay")
	if ov:
		ov.mouse_filter = Control.MOUSE_FILTER_STOP
		ov.gui_input.connect(_on_overlay_click)

func _on_overlay_click(event):
	if event is InputEventMouseButton and event.pressed:
		if campaign_mode:
			get_tree().change_scene_to_file("res://menu.tscn")
		else:
			restart_game()

func restart_game():
	var overlay = ui_layer.get_node_or_null("GameOverOverlay")
	if overlay: overlay.queue_free()
	if promotion_panel:
		promotion_panel.queue_free()
		promotion_panel = null
		promo_buttons = []
	board = []
	selected = Vector2i(-1, -1)
	turn = PieceColor.WHITE
	valid_moves = []
	game_over = false
	en_passant_target = Vector2i(-1, -1)
	castling_rights = { PieceColor.WHITE: { "K": true, "Q": true }, PieceColor.BLACK: { "K": true, "Q": true } }
	move_log = []
	captured_white = []
	captured_black = []
	_setup_board()
	render_board()
	if ai_enabled and turn == ai_color:
		make_ai_move()

func serialize_board() -> Array:
	var data = []
	for y in BOARD_SIZE:
		var row = []
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p == null:
				row.append(null)
			else:
				row.append({ "t": p.type, "c": p.color })
		data.append(row)
	return data

func deserialize_board(data: Array):
	board = []
	for y in BOARD_SIZE:
		var row = []
		for x in BOARD_SIZE:
			var entry = data[y][x]
			if entry == null:
				row.append(null)
			else:
				row.append({ type = entry.t, color = entry.c })
		board.append(row)

func save_game(slot: String):
	if game_over: return
	var data = {
		"board": serialize_board(),
		"turn": turn,
		"castling": { "WK": castling_rights[PieceColor.WHITE]["K"], "WQ": castling_rights[PieceColor.WHITE]["Q"],
					  "BK": castling_rights[PieceColor.BLACK]["K"], "BQ": castling_rights[PieceColor.BLACK]["Q"] },
		"ep": [en_passant_target.x, en_passant_target.y],
		"moves": move_log,
		"cap_w": captured_white,
		"cap_b": captured_black,
		"ai": ai_enabled,
		"ai_depth": ai_depth,
		"human_color": human_color,
	}
	var path = saved_games_dir.path_join(slot + ".save")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.new().stringify(data))
		file.close()
		show_message("Game saved: " + slot)

func get_saved_games() -> Array:
	var dir = DirAccess.open(saved_games_dir)
	if dir == null: return []
	var list = []
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".save"):
			list.append(f.trim_suffix(".save"))
		f = dir.get_next()
	return list

func load_game(slot: String):
	var path = saved_games_dir.path_join(slot + ".save")
	if not FileAccess.file_exists(path): return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK: return
	var data = json.data
	file.close()

	deserialize_board(data.board)
	turn = data.turn
	castling_rights[PieceColor.WHITE]["K"] = data.castling.WK
	castling_rights[PieceColor.WHITE]["Q"] = data.castling.WQ
	castling_rights[PieceColor.BLACK]["K"] = data.castling.BK
	castling_rights[PieceColor.BLACK]["Q"] = data.castling.BQ
	en_passant_target = Vector2i(data.ep[0], data.ep[1])
	move_log = data.moves
	captured_white = data.cap_w
	captured_black = data.cap_b
	ai_enabled = data.ai
	ai_depth = data.ai_depth
	human_color = data.human_color
	selected = Vector2i(-1, -1)
	valid_moves = []
	game_over = false
	render_board()
	_set_camera_for_turn(false)
	show_message("Loaded: " + slot)
	update_ui()

func _update_campaign_stats():
	if not campaign_mode: return
	if turn == human_color:
		move_count += 1
	var last_move = move_log.back() if move_log.size() > 0 else null
	if last_move and last_move.captured != null:
		if last_move.captured.color == human_color:
			pieces_lost += 1
		if last_move.captured.type == Type.QUEEN and last_move.captured.color != human_color:
			captured_enemy_queen = true
	current_material_diff = calculate_material()
	if human_color == PieceColor.BLACK:
		current_material_diff = -current_material_diff

func calculate_material() -> int:
	var white_total = 0
	var black_total = 0
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p == null: continue
			var val = PIECE_VALUES.get(p.type, 0)
			if p.color == PieceColor.WHITE:
				white_total += val
			else:
				black_total += val
	return white_total - black_total

func make_ai_move():
	if game_over: return
	ai_thinking = true
	update_ui()

	var ai = preload("res://ai.gd").new()
	ai.game = self
	var best = ai.get_best_move(ai_color, ai_depth)
	ai.free()

	ai_thinking = false

	if best.from != Vector2i(-1, -1):
		execute_move(best.from, best.to)
		render_board()
		check_game_state()
		if not game_over and ai_enabled and turn == ai_color:
			make_ai_move()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
