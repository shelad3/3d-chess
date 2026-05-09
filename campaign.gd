extends RefCounted

const SAVE_PATH = "user://campaign_data.json"

static var levels = [
	{ "id": 1,  "name": "First Blood",       "desc": "Win your first game against a novice AI",       "ai_depth": 2, "objective": "win" },
	{ "id": 2,  "name": "Rook's Pride",       "desc": "Win without losing more than 3 pieces",         "ai_depth": 2, "objective": "win_with_loss_limit", "loss_limit": 3 },
	{ "id": 3,  "name": "Knight's Gambit",    "desc": "Defeat a stronger AI opponent",                 "ai_depth": 3, "objective": "win" },
	{ "id": 4,  "name": "Queen's Hunt",       "desc": "Capture the enemy queen and win the game",      "ai_depth": 3, "objective": "capture_queen_and_win" },
	{ "id": 5,  "name": "Bishop's Siege",     "desc": "Win against a hard AI",                        "ai_depth": 4, "objective": "win" },
	{ "id": 6,  "name": "Speed Chess",        "desc": "Win within 30 moves",                          "ai_depth": 3, "objective": "win_in_moves", "move_limit": 30 },
	{ "id": 7,  "name": "Material Master",    "desc": "Win with a 5-point material advantage",        "ai_depth": 3, "objective": "win_with_material_lead", "material_lead": 500 },
	{ "id": 8,  "name": "King's Challenge",   "desc": "Defeat an expert AI (depth 5)",                "ai_depth": 5, "objective": "win" },
	{ "id": 9,  "name": "Grandmaster",        "desc": "Win without losing a single piece",            "ai_depth": 4, "objective": "win_with_loss_limit", "loss_limit": 0 },
	{ "id": 10, "name": "Chess Champion",     "desc": "Win 3 games in a row against expert AI",       "ai_depth": 5, "objective": "win_streak", "streak": 3 },
]

static func get_level_data() -> Dictionary:
	var data = {
		"completed": {},
		"stars": {},
		"current_level": 1,
		"streak": 0,
		"total_wins": 0,
		"total_losses": 0,
	}
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				data = json.data
			file.close()
	if not data.has("completed"): data.completed = {}
	if not data.has("stars"): data.stars = {}
	if not data.has("current_level"): data.current_level = 1
	if not data.has("streak"): data.streak = 0
	if not data.has("total_wins"): data.total_wins = 0
	if not data.has("total_losses"): data.total_losses = 0
	return data

static func save_level_data(data: Dictionary):
	var dir_str = SAVE_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_str)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.new().stringify(data))
		file.close()

static func is_level_unlocked(level_id: int) -> bool:
	if level_id == 1: return true
	var data = get_level_data()
	return data.completed.has(str(level_id - 1))

static func get_stars_for_level(level_id: int, move_count: int, pieces_lost: int, captured_queen: bool, material_diff: int) -> int:
	var level = null
	for l in levels:
		if l.id == level_id: level = l; break
	if level == null: return 1
	var stars = 1
	if level.objective == "win":
		stars = 2
	elif level.objective == "win_with_loss_limit":
		stars = 2
	elif level.objective == "capture_queen_and_win":
		stars = 2
	elif level.objective == "win_with_material_lead":
		stars = 2
	elif level.objective == "win_in_moves":
		stars = 2

	if move_count <= 20: stars += 1
	if level.objective == "win_with_loss_limit":
		if pieces_lost <= level.get("loss_limit", 99): stars = max(stars, 2)
		if pieces_lost == 0: stars = max(stars, 3)
	if level.objective == "capture_queen_and_win" and captured_queen:
		stars = max(stars, 2)
	if level.objective == "win_with_material_lead" and material_diff >= level.get("material_lead", 500):
		stars = max(stars, 2)
	if level.objective == "win_in_moves" and move_count <= level.get("move_limit", 30):
		stars = max(stars, 2)

	return clampi(stars, 1, 3)

static func complete_level(level_id: int, stars: int, move_count: int):
	var data = get_level_data()
	data.completed[str(level_id)] = true
	if not data.stars.has(str(level_id)) or data.stars[str(level_id)] < stars:
		data.stars[str(level_id)] = stars
	if level_id < len(levels) and not data.completed.has(str(level_id + 1)):
		data.current_level = level_id + 1
	data.total_wins += 1
	data.streak += 1
	save_level_data(data)

static func record_loss():
	var data = get_level_data()
	data.total_losses += 1
	data.streak = 0
	save_level_data(data)

static func get_total_completed() -> int:
	var data = get_level_data()
	var count = 0
	for l in levels:
		if data.completed.has(str(l.id)): count += 1
	return count

static func get_total_stars() -> int:
	var data = get_level_data()
	var total = 0
	for l in levels:
		total += data.stars.get(str(l.id), 0)
	return total

static func reset_progress():
	var data = {
		"completed": {},
		"stars": {},
		"current_level": 1,
		"streak": 0,
		"total_wins": 0,
		"total_losses": 0,
	}
	save_level_data(data)
