extends Node

enum Type { EMPTY, PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

var game

var PIECE_VALUES = {
	Type.PAWN: 100,
	Type.KNIGHT: 320,
	Type.BISHOP: 330,
	Type.ROOK: 500,
	Type.QUEEN: 900,
	Type.KING: 20000,
}

const PAWN_TABLE = [
	[ 0,  0,  0,  0,  0,  0,  0,  0],
	[50, 50, 50, 50, 50, 50, 50, 50],
	[10, 10, 20, 30, 30, 20, 10, 10],
	[ 5,  5, 10, 25, 25, 10,  5,  5],
	[ 0,  0,  0, 20, 20,  0,  0,  0],
	[ 5, -5,-10,  0,  0,-10, -5,  5],
	[ 5, 10, 10,-20,-20, 10, 10,  5],
	[ 0,  0,  0,  0,  0,  0,  0,  0],
]

const KNIGHT_TABLE = [
	[-50,-40,-30,-30,-30,-30,-40,-50],
	[-40,-20,  0,  0,  0,  0,-20,-40],
	[-30,  0, 10, 15, 15, 10,  0,-30],
	[-30,  5, 15, 20, 20, 15,  5,-30],
	[-30,  0, 15, 20, 20, 15,  0,-30],
	[-30,  5, 10, 15, 15, 10,  5,-30],
	[-40,-20,  0,  5,  5,  0,-20,-40],
	[-50,-40,-30,-30,-30,-30,-40,-50],
]

const BISHOP_TABLE = [
	[-20,-10,-10,-10,-10,-10,-10,-20],
	[-10,  0,  0,  0,  0,  0,  0,-10],
	[-10,  0, 10, 10, 10, 10,  0,-10],
	[-10,  5,  5, 10, 10,  5,  5,-10],
	[-10,  0,  5, 10, 10,  5,  0,-10],
	[-10, 10, 10, 10, 10, 10, 10,-10],
	[-10,  5,  0,  0,  0,  0,  5,-10],
	[-20,-10,-10,-10,-10,-10,-10,-20],
]

const ROOK_TABLE = [
	[ 0,  0,  0,  0,  0,  0,  0,  0],
	[ 5, 10, 10, 10, 10, 10, 10,  5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[ 0,  0,  0,  5,  5,  0,  0,  0],
]

const QUEEN_TABLE = [
	[-20,-10,-10, -5, -5,-10,-10,-20],
	[-10,  0,  0,  0,  0,  0,  0,-10],
	[-10,  0,  5,  5,  5,  5,  0,-10],
	[ -5,  0,  5,  5,  5,  5,  0, -5],
	[  0,  0,  5,  5,  5,  5,  0, -5],
	[-10,  5,  5,  5,  5,  5,  0,-10],
	[-10,  0,  5,  0,  0,  0,  0,-10],
	[-20,-10,-10, -5, -5,-10,-10,-20],
]

const KING_TABLE = [
	[-30,-40,-40,-50,-50,-40,-40,-30],
	[-30,-40,-40,-50,-50,-40,-40,-30],
	[-30,-40,-40,-50,-50,-40,-40,-30],
	[-30,-40,-40,-50,-50,-40,-40,-30],
	[-20,-30,-30,-40,-40,-30,-30,-20],
	[-10,-20,-20,-20,-20,-20,-20,-10],
	[ 20, 20,  0,  0,  0,  0, 20, 20],
	[ 20, 30, 10,  0,  0, 10, 30, 20],
]

const KING_ENDGAME_TABLE = [
	[-50,-40,-30,-20,-20,-30,-40,-50],
	[-30,-20,-10,  0,  0,-10,-20,-30],
	[-30,-10, 20, 30, 30, 20,-10,-30],
	[-30,-10, 30, 40, 40, 30,-10,-30],
	[-30,-10, 30, 40, 40, 30,-10,-30],
	[-30,-10, 20, 30, 30, 20,-10,-30],
	[-30,-30,  0,  0,  0,  0,-30,-30],
	[-50,-30,-30,-30,-30,-30,-30,-50],
]

func get_best_move(color, depth: int) -> Dictionary:
	var moves = get_all_legal_moves(color)
	if moves.is_empty():
		return { from = Vector2i(-1, -1), to = Vector2i(-1, -1) }

	moves.sort_custom(func(a, b): return _move_score(a) > _move_score(b))

	var best_score = -INF
	var best_moves = []

	for mv in moves:
		var real_board = game.board
		var sim = _simulate(mv.from, mv.to, color)
		game.board = sim.board

		var score
		if game.is_in_check(opp(color)):
			score = -_minimax(sim.board, depth - 1, -INF, INF, false, opp(color), depth)
		else:
			score = -_minimax(sim.board, depth - 1, -INF, INF, false, opp(color), depth)

		game.board = real_board

		if score > best_score:
			best_score = score
			best_moves = [mv]
		elif score == best_score:
			best_moves.append(mv)

	best_moves.sort_custom(func(a, b): return _move_score(a) > _move_score(b))
	return best_moves[0]

func _minimax(bd: Array, depth: int, alpha: float, beta: float, is_max: bool, color, max_depth: int) -> float:
	if depth == 0:
		return _evaluate(bd, color)

	var moves = _get_all_legal_moves_from(bd, color)
	if moves.is_empty():
		var kp = _find_king_in(bd, color)
		if _is_square_attacked_in(bd, kp, opp(color)):
			return -99999.0 * (max_depth - depth + 1)
		return 0.0

	moves.sort_custom(func(a, b): return _move_score_from(bd, a) > _move_score_from(bd, b))

	var best = -INF if is_max else INF
	for mv in moves:
		var sim = _simulate_from(bd, mv.from, mv.to, color)
		var score = _minimax(sim.board, depth - 1, alpha, beta, not is_max, opp(color), max_depth)

		if is_max:
			best = max(best, score)
			alpha = max(alpha, score)
		else:
			best = min(best, score)
			beta = min(beta, score)

		if beta <= alpha:
			break

	return best

func _evaluate(bd: Array, color) -> float:
	var score = 0
	var w_material = 0.0
	var b_material = 0.0

	for y in 8:
		for x in 8:
			var p = bd[y][x]
			if p == null:
				continue
			var val = PIECE_VALUES[p.type]
			var pos_bonus = _position_bonus(p.type, x, y, p.color == PieceColor.WHITE)

			if p.color == PieceColor.WHITE:
				w_material += val + pos_bonus
			else:
				b_material += val + pos_bonus

	var total_pieces = 0
	for y in 8:
		for x in 8:
			if bd[y][x] != null:
				total_pieces += 1

	score = w_material - b_material

	if color == PieceColor.BLACK:
		score = -score

	var kp = _find_king_in(bd, color)
	if kp != Vector2i(-1, -1):
		if total_pieces < 8:
			var eg = KING_ENDGAME_TABLE[kp.y][kp.x]
			score += eg * 0.1

	var okp = _find_king_in(bd, opp(color))
	if okp != Vector2i(-1, -1):
		if total_pieces < 8:
			var eg = KING_ENDGAME_TABLE[okp.y][okp.x]
			score -= eg * 0.1

	return score

func _position_bonus(type, x: int, y: int, is_white: bool) -> float:
	var row = y if is_white else 7 - y
	var col = x

	match type:
		Type.PAWN:
			return PAWN_TABLE[row][col]
		Type.KNIGHT:
			return KNIGHT_TABLE[row][col]
		Type.BISHOP:
			return BISHOP_TABLE[row][col]
		Type.ROOK:
			return ROOK_TABLE[row][col]
		Type.QUEEN:
			return QUEEN_TABLE[row][col]
		Type.KING:
			return KING_TABLE[row][col]
	return 0

func _move_score(mv) -> float:
	return _move_score_from(game.board, mv)

func _move_score_from(bd, mv) -> float:
	var target = bd[mv.to.y][mv.to.x]
	if target != null:
		return PIECE_VALUES.get(target.type, 0) + 10
	return 0.001

func get_all_legal_moves(color):
	return _get_all_legal_moves_from(game.board, color)

func _get_all_legal_moves_from(bd: Array, color):
	var moves = []
	for y in 8:
		for x in 8:
			var p = bd[y][x]
			if p == null or p.color != color:
				continue
			var raw = _get_raw_moves_from(bd, Vector2i(x, y))
			for mv in raw:
				var sim = _simulate_from(bd, Vector2i(x, y), mv, color)
				var kp = _find_king_in(sim.board, color)
				if not _is_square_attacked_in(sim.board, kp, opp(color)):
					moves.append({ from = Vector2i(x, y), to = mv })
	return moves

func _get_raw_moves_from(bd: Array, pos: Vector2i) -> Array:
	var p = bd[pos.y][pos.x]
	if p == null:
		return []
	var moves = []
	var c = p.color
	var dir = -1 if c == PieceColor.WHITE else 1

	match p.type:
		Type.PAWN:
			var fwd = Vector2i(pos.x, pos.y + dir)
			if _is_in_bounds(fwd) and bd[fwd.y][fwd.x] == null:
				moves.append(fwd)
				var start = 6 if c == PieceColor.WHITE else 1
				if pos.y == start:
					var f2 = Vector2i(pos.x, pos.y + 2 * dir)
					if bd[f2.y][f2.x] == null:
						moves.append(f2)
			for dx in [-1, 1]:
				var d = Vector2i(pos.x + dx, pos.y + dir)
				if _is_in_bounds(d) and bd[d.y][d.x] != null and bd[d.y][d.x].color != c:
					moves.append(d)
		Type.ROOK:
			for dd in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]:
				var t = pos + dd
				while _is_in_bounds(t):
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
				if _is_in_bounds(t) and (bd[t.y][t.x] == null or bd[t.y][t.x].color != c):
					moves.append(t)
		Type.BISHOP:
			for dd in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
				var t = pos + dd
				while _is_in_bounds(t):
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
				while _is_in_bounds(t):
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
				if _is_in_bounds(t) and (bd[t.y][t.x] == null or bd[t.y][t.x].color != c):
					moves.append(t)
	return moves

func _simulate(from: Vector2i, to: Vector2i, color):
	return _simulate_from(game.board, from, to, color)

func _simulate_from(bd: Array, from: Vector2i, to: Vector2i, color):
	var new_board = []
	for y in 8:
		var row = []
		for x in 8:
			row.append(bd[y][x])
		new_board.append(row)

	new_board[to.y][to.x] = new_board[from.y][from.x]
	new_board[from.y][from.x] = null
	return { board = new_board }

func _find_king_in(bd: Array, color) -> Vector2i:
	for y in 8:
		for x in 8:
			var p = bd[y][x]
			if p != null and p.type == Type.KING and p.color == color:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _is_square_attacked_in(bd: Array, pos: Vector2i, by_color) -> bool:
	if pos == Vector2i(-1, -1):
		return false
	for y in 8:
		for x in 8:
			var p = bd[y][x]
			if p == null or p.color != by_color:
				continue
			var f = Vector2i(x, y)
			if p.type == Type.PAWN:
				var dir = -1 if p.color == PieceColor.WHITE else 1
				for dx in [-1, 1]:
					if f + Vector2i(dx, dir) == pos:
						return true
			elif p.type == Type.KNIGHT:
				for dd in [Vector2i(1,2),Vector2i(2,1),Vector2i(-1,2),Vector2i(-2,1),Vector2i(1,-2),Vector2i(2,-1),Vector2i(-1,-2),Vector2i(-2,-1)]:
					if f + dd == pos:
						return true
			elif p.type in [Type.ROOK, Type.QUEEN]:
				for dd in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]:
					var t = f + dd
					while _is_in_bounds(t):
						if t == pos:
							return true
						if bd[t.y][t.x] != null:
							break
						t += dd
			elif p.type in [Type.BISHOP, Type.QUEEN]:
				for dd in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
					var t = f + dd
					while _is_in_bounds(t):
						if t == pos:
							return true
						if bd[t.y][t.x] != null:
							break
						t += dd
			elif p.type == Type.KING:
				for dd in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
					if f + dd == pos:
						return true
	return false

func _is_in_bounds(v: Vector2i) -> bool:
	return v.x >= 0 and v.x < 8 and v.y >= 0 and v.y < 8

func opp(color):
	return PieceColor.BLACK if color == PieceColor.WHITE else PieceColor.WHITE
