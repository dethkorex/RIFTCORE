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


static func boss_health_scale(sector: int, mode: int, act: int) -> float:
	var scale := combat_scale(sector, mode)
	return scale * (1.16 + 0.04 * index(mode)) if act == 1 else scale

static func boss_recovery_scale(mode: int, miniboss := false) -> float:
	return [0.88, 0.72, 0.58][index(mode)] if miniboss else [1.0, 0.86, 0.72][index(mode)]

static func windup_time(base: float, mode: int, minimum: float = 0.42) -> float:
	return maxf(minimum, base * [1.0, 0.94, 0.84][index(mode)])

static func boss_pursuit_scale(mode: int, miniboss := false) -> float:
	return [1.14, 1.24, 1.35][index(mode)] if miniboss else [1.0, 1.09, 1.17][index(mode)]
