extends RefCounted

const NAMES := ["Normal", "Hard", "Expert"]
const NORMAL := 0
const HARD := 1
const NIGHTMARE := 2
const PLAYER_LEVEL_CAP := 50
const EXTRACTION_SHARD_PERCENT := 125
const ENEMY_HEALTH := [1.0, 1.24, 1.55]
const BOSS_HEALTH := [1.0, 1.28, 1.62]
const INCOMING_DAMAGE := [1.0, 1.28, 1.58]
const MINIBOSS_HEALTH_BY_SECTOR := [575, 1140, 1600, 1800, 2030, 2310, 2600, 2900, 3240, 3650]
const BOSS_HEALTH_BY_SECTOR := [1720, 3100, 4100, 4580, 5120, 5720, 6360, 7120, 8000, 9000]
const MINIBOSS_ATTACK_SCALE := 1.10
const BOSS_ATTACK_SCALE := 1.15
const ENEMY_SPEED := [1.08, 1.14, 1.21]
const LOOT := [1.0, 1.65, 3.2]
const SECTOR_LEVELS := [1, 4, 7, 10, 14, 18, 22, 27, 33, 40]
const LEVEL_OFFSET := [0, 4, 12]

static func index(value: int) -> int:
	return clampi(value, 0, NAMES.size() - 1)

static func recommended_level(sector: int, mode: int) -> int:
	return SECTOR_LEVELS[clampi(sector, 1, SECTOR_LEVELS.size()) - 1] + LEVEL_OFFSET[index(mode)]

static func enemy_health_scale(sector: int, mode: int, act: int, party_size := 1) -> float:
	var steps := clampi(sector, 1, SECTOR_LEVELS.size()) - 1
	var progression := 1.0 + .27 * steps + .012 * steps * steps
	return progression * ENEMY_HEALTH[index(mode)] * (1.18 if act == 2 else 1.0) * party_health_scale(party_size)

static func incoming_damage_scale(sector: int, mode: int) -> float:
	var progress := float(clampi(sector, 1, SECTOR_LEVELS.size()) - 1) / (SECTOR_LEVELS.size() - 1)
	return lerpf(1.03, 2.85, progress) * INCOMING_DAMAGE[index(mode)]

static func party_health_scale(party_size: int, boss := false) -> float:
	return 1.0 + (clampi(party_size, 1, 4) - 1) * (.45 if boss else .30)

static func enemy_speed_scale(sector: int, mode: int) -> float:
	return ENEMY_SPEED[index(mode)] + minf(0.08, (recommended_level(sector, mode) - 1) * 0.002)


static func boss_health(sector: int, mode: int, act: int, party_size := 1) -> float:
	var baseline := MINIBOSS_HEALTH_BY_SECTOR if act == 1 else BOSS_HEALTH_BY_SECTOR
	return baseline[clampi(sector, 1, baseline.size()) - 1] * BOSS_HEALTH[index(mode)] * party_health_scale(party_size, true)

static func jungle_boss_damage_scale(mode: int) -> float:
	return boss_damage_scale(mode)

static func boss_damage_scale(mode: int) -> float:
	return [1.0, 1.18, 1.38][index(mode)]

static func jungle_boss_damage_taken(mode: int, miniboss: bool) -> float:
	return ([0.80, 0.74, 0.68] if miniboss else [0.75, 0.68, 0.62])[index(mode)]

static func boss_recovery_scale(mode: int, miniboss := false) -> float:
	return [0.88, 0.72, 0.58][index(mode)] if miniboss else [1.0, 0.86, 0.72][index(mode)]

static func windup_time(base: float, mode: int, minimum: float = 0.42) -> float:
	return maxf(minimum, base * [1.0, 0.94, 0.84][index(mode)])

static func boss_pursuit_scale(mode: int, miniboss := false) -> float:
	return [1.14, 1.24, 1.35][index(mode)] if miniboss else [1.0, 1.09, 1.17][index(mode)]

static func extraction_shards(sector: int, mode: int) -> int:
	var base := 2 + (sector - 1) / 4 + index(mode)
	return roundi(base * EXTRACTION_SHARD_PERCENT / 100.0)
