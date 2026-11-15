extends RefCounted

const NAMES := ["Normal", "Hard", "Expert"]
const NORMAL := 0
const HARD := 1
const NIGHTMARE := 2
const PLAYER_LEVEL_CAP := 50
const COMBAT := [1.10, 1.68, 3.0]
const ENEMY_SPEED := [1.08, 1.14, 1.21]
const LOOT := [1.0, 1.65, 3.2]
const SECTOR_LEVELS := [1, 4, 7, 10, 14, 18, 22, 27, 33, 40]
const LEVEL_OFFSET := [0, 4, 12]

static func index(value: int) -> int:
	return clampi(value, 0, NAMES.size() - 1)

static func recommended_level(sector: int, mode: int) -> int:
	return SECTOR_LEVELS[clampi(sector, 1, SECTOR_LEVELS.size()) - 1] + LEVEL_OFFSET[index(mode)]

static func combat_scale(sector: int, mode: int) -> float:
	var level := recommended_level(sector, mode)
	return COMBAT[index(mode)] * (1.0 + (level - 1) * 0.020)

static func enemy_speed_scale(sector: int, mode: int) -> float:
	return ENEMY_SPEED[index(mode)] + minf(0.08, (recommended_level(sector, mode) - 1) * 0.002)
