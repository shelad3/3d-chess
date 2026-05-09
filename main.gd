extends Control

const BOARD_SIZE := 8
const SQ_SIZE := 64
const MARGIN := 20

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
var promotion_pending := false
var promotion_pos: Vector2i
var promotion_color: PieceColor

const PIECE_SYMBOLS = {
	PieceColor.WHITE: { Type.KING: "♔", Type.QUEEN: "♕", Type.ROOK: "♖", Type.BISHOP: "♗", Type.KNIGHT: "♘", Type.PAWN: "♙" },
	PieceColor.BLACK: { Type.KING: "♚", Type.QUEEN: "♛", Type.ROOK: "♜", Type.BISHOP: "♝", Type.KNIGHT: "♞", Type.PAWN: "♟" },
}

static func side_str(c: PieceColor) -> String:
	return "White" if c == PieceColor.WHITE else "Black"

static func opp(c: PieceColor) -> PieceColor:
	return PieceColor.BLACK if c == PieceColor.WHITE else PieceColor.WHITE

func _ready():
	setup_board()
	draw_board()

func setup_board():
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

func is_in_bounds(v: Vector2i) -> bool:
	return v.x >= 0 and v.x < BOARD_SIZE and v.y >= 0 and v.y < BOARD_SIZE

func get_piece_at(v: Vector2i):
	if not is_in_bounds(v):
		return null
	return board[v.y][v.x]

func is_empty(v: Vector2i) -> bool:
	return get_piece_at(v) == null

func enemy_at(v: Vector2i, c: PieceColor) -> bool:
	var p = get_piece_at(v)
	return p != null and p.color != c

func get_raw_moves(pos: Vector2i) -> Array:
	var p = get_piece_at(pos)
	if p == null:
		return []
	var moves: Array = []
	var t = p.type
	var c = p.color
	var dir = -1 if c == PieceColor.WHITE else 1
	match t:
		Type.PAWN:
			var fwd = Vector2i(pos.x, pos.y + dir)
			if is_in_bounds(fwd) and is_empty(fwd):
				moves.append(fwd)
				var start_row = 6 if c == PieceColor.WHITE else 1
				if pos.y == start_row:
					var fwd2 = Vector2i(pos.x, pos.y + 2 * dir)
					if is_empty(fwd2):
						moves.append(fwd2)
			for dx in [-1, 1]:
				var diag = Vector2i(pos.x + dx, pos.y + dir)
				if is_in_bounds(diag) and enemy_at(diag, c):
					moves.append(diag)
				if diag == en_passant_target:
					moves.append(diag)
		Type.ROOK:
			moves = slide_moves(pos, [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)])
		Type.KNIGHT:
			for d in [Vector2i(1,2),Vector2i(2,1),Vector2i(-1,2),Vector2i(-2,1),Vector2i(1,-2),Vector2i(2,-1),Vector2i(-1,-2),Vector2i(-2,-1)]:
				var tgt = pos + d
				if is_in_bounds(tgt) and (is_empty(tgt) or enemy_at(tgt, c)):
					moves.append(tgt)
		Type.BISHOP:
			moves = slide_moves(pos, [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)])
		Type.QUEEN:
			moves = slide_moves(pos, [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)])
		Type.KING:
			for d in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
				var tgt = pos + d
				if is_in_bounds(tgt) and (is_empty(tgt) or enemy_at(tgt, c)):
					moves.append(tgt)
			var row = 7 if c == PieceColor.WHITE else 0
			if pos == Vector2i(4, row):
				if castling_rights[c]["K"] and is_empty(Vector2i(5,row)) and is_empty(Vector2i(6,row)):
					var rp = get_piece_at(Vector2i(7,row))
					if rp != null and rp.type == Type.ROOK and rp.color == c:
						if not is_square_attacked(pos, opp(c)) and not is_square_attacked(Vector2i(5,row), opp(c)) and not is_square_attacked(Vector2i(6,row), opp(c)):
							moves.append(Vector2i(6,row))
				if castling_rights[c]["Q"] and is_empty(Vector2i(3,row)) and is_empty(Vector2i(2,row)) and is_empty(Vector2i(1,row)):
					var rp = get_piece_at(Vector2i(0,row))
					if rp != null and rp.type == Type.ROOK and rp.color == c:
						if not is_square_attacked(pos, opp(c)) and not is_square_attacked(Vector2i(3,row), opp(c)) and not is_square_attacked(Vector2i(2,row), opp(c)):
							moves.append(Vector2i(2,row))
	return moves

func slide_moves(pos: Vector2i, dirs: Array) -> Array:
	var moves: Array = []
	var p = get_piece_at(pos)
	if p == null:
		return moves
	for d in dirs:
		var tgt = pos + d
		while is_in_bounds(tgt):
			if is_empty(tgt):
				moves.append(tgt)
			else:
				if enemy_at(tgt, p.color):
					moves.append(tgt)
				break
			tgt += d
	return moves

func find_king(c: PieceColor) -> Vector2i:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.type == Type.KING and p.color == c:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func is_square_attacked(pos: Vector2i, by_color: PieceColor) -> bool:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p == null or p.color != by_color:
				continue
			var from = Vector2i(x, y)
			if p.type == Type.PAWN:
				var dir = -1 if p.color == PieceColor.WHITE else 1
				for dx in [-1, 1]:
					if from + Vector2i(dx, dir) == pos:
						return true
			elif p.type == Type.KNIGHT:
				for d in [Vector2i(1,2),Vector2i(2,1),Vector2i(-1,2),Vector2i(-2,1),Vector2i(1,-2),Vector2i(2,-1),Vector2i(-1,-2),Vector2i(-2,-1)]:
					if from + d == pos:
						return true
			elif p.type in [Type.ROOK, Type.QUEEN]:
				for d in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]:
					var tgt = from + d
					while is_in_bounds(tgt):
						if tgt == pos:
							return true
						if not is_empty(tgt):
							break
						tgt += d
			elif p.type in [Type.BISHOP, Type.QUEEN]:
				for d in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
					var tgt = from + d
					while is_in_bounds(tgt):
						if tgt == pos:
							return true
						if not is_empty(tgt):
							break
						tgt += d
			elif p.type == Type.KING:
				for d in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
					if from + d == pos:
						return true
	return false

func is_in_check(c: PieceColor) -> bool:
	var king_pos = find_king(c)
	if king_pos == Vector2i(-1, -1):
		return false
	return is_square_attacked(king_pos, opp(c))

func simulate_move(from: Vector2i, to: Vector2i) -> Array:
	var new_board = []
	for y in BOARD_SIZE:
		var row = []
		for x in BOARD_SIZE:
			row.append(board[y][x])
		new_board.append(row)
	var temp_board = board
	board = new_board

	var captured = board[to.y][to.x]
	board[to.y][to.x] = board[from.y][from.x]
	board[from.y][from.x] = null

	var result = [board, captured]
	board = temp_board
	return result

func get_legal_moves(pos: Vector2i) -> Array:
	var p = get_piece_at(pos)
	if p == null:
		return []
	var raw = get_raw_moves(pos)
	var legal: Array = []
	for mv in raw:
		var sim = simulate_move(pos, mv)
		var sim_board = sim[0]
		var real_board = board
		board = sim_board
		if not is_in_check(p.color):
			legal.append(mv)
		board = real_board
	return legal

func has_legal_moves(c: PieceColor) -> bool:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.color == c:
				if get_legal_moves(Vector2i(x, y)).size() > 0:
					return true
	return false

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_over:
			restart_game()
			return
		if promotion_pending:
			var gp = event.position
			var panel_x = MARGIN + 10
			var panel_y = MARGIN + 3 * SQ_SIZE + 10
			var px = int((gp.x - panel_x) / (SQ_SIZE + 4))
			var py = int((gp.y - panel_y) / SQ_SIZE)
			if px >= 0 and px <= 3 and py == 0:
				var types = [Type.QUEEN, Type.ROOK, Type.BISHOP, Type.KNIGHT]
				_on_promotion_selected(types[px])
				return
			return

		var gp = event.position
		var bx = int((gp.x - MARGIN) / SQ_SIZE)
		var by = int((gp.y - MARGIN) / SQ_SIZE)
		if bx < 0 or bx >= BOARD_SIZE or by < 0 or by >= BOARD_SIZE:
			selected = Vector2i(-1, -1)
			valid_moves = []
			draw_board()
			return
		var clicked = Vector2i(bx, by)
		if selected == Vector2i(-1, -1):
			var p = get_piece_at(clicked)
			if p != null and p.color == turn:
				selected = clicked
				valid_moves = get_legal_moves(clicked)
				draw_board()
		else:
			if valid_moves.has(clicked):
				execute_move(selected, clicked)
				selected = Vector2i(-1, -1)
				valid_moves = []
				draw_board()
				check_game_state()
			else:
				var p = get_piece_at(clicked)
				if p != null and p.color == turn:
					selected = clicked
					valid_moves = get_legal_moves(clicked)
					draw_board()
				else:
					selected = Vector2i(-1, -1)
					valid_moves = []
					draw_board()

func execute_move(from: Vector2i, to: Vector2i):
	var p = board[from.y][from.x]
	if p == null:
		return
	var captured = board[to.y][to.x]
	var flags := ""

	if p.type == Type.PAWN and to == en_passant_target:
		var ep_cap = Vector2i(to.x, from.y)
		captured = board[ep_cap.y][ep_cap.x]
		board[ep_cap.y][ep_cap.x] = null
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
		if from == Vector2i(7, row):
			castling_rights[p.color]["K"] = false
		if from == Vector2i(0, row):
			castling_rights[p.color]["Q"] = false

	board[to.y][to.x] = p
	board[from.y][from.x] = null

	if p.type == Type.PAWN and (to.y == 0 or to.y == 7):
		promotion_pending = true
		promotion_pos = to
		promotion_color = p.color
		show_promotion_dialog()
		return

	move_log.append({ from = from, to = to, piece = p, captured = captured, flags = flags })
	turn = opp(turn)

func show_promotion_dialog():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.size = get_viewport_rect().size
	overlay.name = "PromotionOverlay"
	add_child(overlay)

	var panel = ColorRect.new()
	panel.color = Color("#2d2d2d")
	panel.size = Vector2(SQ_SIZE * 4 + 20, SQ_SIZE + 20)
	panel.position = Vector2(MARGIN, MARGIN + 3 * SQ_SIZE)
	panel.name = "PromotionPanel"
	add_child(panel)

	var types = [Type.QUEEN, Type.ROOK, Type.BISHOP, Type.KNIGHT]
	for i in 4:
		var lbl = Label.new()
		lbl.text = PIECE_SYMBOLS[promotion_color][types[i]]
		lbl.add_theme_font_size_override("font_size", 48)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(SQ_SIZE, SQ_SIZE)
		lbl.position = Vector2(panel.position.x + 10 + i * (SQ_SIZE + 4), panel.position.y + 10)
		lbl.name = "PromoBtn" + str(i)
		add_child(lbl)

func _on_promotion_selected(ptype: Type):
	var overlay = get_node_or_null("PromotionOverlay")
	if overlay: overlay.queue_free()
	var panel = get_node_or_null("PromotionPanel")
	if panel: panel.queue_free()
	for i in 4:
		var btn = get_node_or_null("PromoBtn" + str(i))
		if btn: btn.queue_free()

	board[promotion_pos.y][promotion_pos.x] = { type = ptype, color = promotion_color }
	promotion_pending = false
	move_log[-1].piece = board[promotion_pos.y][promotion_pos.x]
	turn = opp(turn)
	draw_board()
	check_game_state()

func check_game_state():
	var c = turn
	if is_in_check(c):
		if not has_legal_moves(c):
			game_over = true
			show_game_over(side_str(opp(c)) + " wins by checkmate!")
			return
		else:
			show_message(side_str(c) + " is in check!")
	elif not has_legal_moves(c):
		game_over = true
		show_game_over("Stalemate - Draw!")
		return

func show_message(msg: String):
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(600, 30)
	lbl.position = Vector2(0, MARGIN + BOARD_SIZE * SQ_SIZE + 40)
	lbl.name = "StatusLabel"
	var old = get_node_or_null("StatusLabel")
	if old:
		old.queue_free()
	add_child(lbl)

func show_game_over(msg: String):
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = get_viewport_rect().size
	overlay.name = "GameOverOverlay"
	add_child(overlay)

	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(500, 80)
	lbl.position = Vector2((get_viewport_rect().size.x - 500) / 2, get_viewport_rect().size.y / 2 - 60)
	add_child(lbl)

	var restart = Label.new()
	restart.text = "Click to restart"
	restart.add_theme_font_size_override("font_size", 20)
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	restart.size = Vector2(500, 40)
	restart.position = Vector2((get_viewport_rect().size.x - 500) / 2, get_viewport_rect().size.y / 2 + 20)
	add_child(restart)

func restart_game():
	for c in get_children():
		c.queue_free()
	board = []
	selected = Vector2i(-1, -1)
	turn = PieceColor.WHITE
	valid_moves = []
	game_over = false
	en_passant_target = Vector2i(-1, -1)
	castling_rights = { PieceColor.WHITE: { "K": true, "Q": true }, PieceColor.BLACK: { "K": true, "Q": true } }
	move_log = []
	promotion_pending = false
	setup_board()
	draw_board()

func draw_board():
	for c in get_children():
		if c.name in ["StatusLabel", "GameOverOverlay", "PromotionOverlay", "PromotionPanel"]:
			continue
		if c.name.begins_with("PromoBtn"):
			continue
		c.queue_free()

	var window_size = Vector2(MARGIN * 2 + BOARD_SIZE * SQ_SIZE, MARGIN * 2 + BOARD_SIZE * SQ_SIZE + 80)
	get_window().size = window_size

	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var is_light = (x + y) % 2 == 0
			var rect = ColorRect.new()
			rect.color = Color("#f0d9b5") if is_light else Color("#b58863")
			rect.size = Vector2(SQ_SIZE, SQ_SIZE)
			rect.position = Vector2(MARGIN + x * SQ_SIZE, MARGIN + y * SQ_SIZE)
			add_child(rect)

			if selected == Vector2i(x, y):
				rect.color = Color("#829769")

			if valid_moves.has(Vector2i(x, y)):
				var is_capture = get_piece_at(Vector2i(x, y)) != null
				var hl = ColorRect.new()
				if is_capture:
					hl.color = Color(0.8, 0.3, 0.2, 0.6)
					hl.size = Vector2(SQ_SIZE, SQ_SIZE)
				else:
					hl.color = Color(0.3, 0.8, 0.3, 0.3)
					hl.size = Vector2(SQ_SIZE * 0.3, SQ_SIZE * 0.3)
					hl.position += Vector2(SQ_SIZE * 0.35, SQ_SIZE * 0.35)
				hl.position += Vector2(MARGIN + x * SQ_SIZE, MARGIN + y * SQ_SIZE)
				add_child(hl)

			var piece = board[y][x]
			if piece != null:
				var lbl = Label.new()
				lbl.text = PIECE_SYMBOLS[piece.color][piece.type]
				lbl.add_theme_font_size_override("font_size", 44)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.size = Vector2(SQ_SIZE, SQ_SIZE)
				lbl.position = Vector2(MARGIN + x * SQ_SIZE, MARGIN + y * SQ_SIZE)
				add_child(lbl)

	var tl = Label.new()
	tl.text = side_str(turn) + "'s turn"
	tl.add_theme_font_size_override("font_size", 18)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tl.size = Vector2(300, 30)
	tl.position = Vector2(MARGIN, MARGIN + BOARD_SIZE * SQ_SIZE + 10)
	add_child(tl)
