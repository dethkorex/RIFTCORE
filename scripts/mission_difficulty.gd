extends RefCounted

const NAMES := ["Standard", "Veteran", "Nightmare"]
const COMBAT := [1.0, 1.25, 1.55]
const LOOT := [1.0, 1.5, 2.25]

static func index(value: int) -> int:
	return clampi(value, 0, NAMES.size() - 1)
