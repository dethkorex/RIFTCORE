extends RefCounted
## Positions are local to the Rocket Spillway anchor, in metres.

const LENGTH := 2460.0
const GRADE := [
	Vector2(0, 0), Vector2(36, 0), Vector2(104, -13), Vector2(248, -13),
	Vector2(288, -19), Vector2(377, -19), Vector2(425, -10), Vector2(504, -10),
	Vector2(570, -30), Vector2(697, -30), Vector2(747, -23), Vector2(840, -23),
	Vector2(912, -51), Vector2(1002, -51), Vector2(1053, -42), Vector2(1156, -42),
	Vector2(1232, -67), Vector2(1337, -67), Vector2(1388, -58), Vector2(1490, -58),
	Vector2(1565, -85), Vector2(1684, -85), Vector2(1745, -75), Vector2(1849, -75),
	Vector2(1945, -110), Vector2(2060, -110), Vector2(2120, -103), Vector2(2238, -103),
	Vector2(2318, -130), Vector2(LENGTH, -130),
]

const HOP_GAPS := [
	Vector2(154, 165), Vector2(341, 354), Vector2(450, 462), Vector2(591, 605),
	Vector2(779, 793), Vector2(946, 958), Vector2(1098, 1111), Vector2(1290, 1303),
	Vector2(1438, 1453), Vector2(1622, 1634), Vector2(1791, 1805), Vector2(1987, 2001),
	Vector2(2152, 2166), Vector2(2340, 2354),
]
const BOOST_GAPS := [
	Vector2(652, 672), Vector2(858, 879), Vector2(1197, 1219), Vector2(1519, 1541),
	Vector2(1881, 1904), Vector2(2204, 2225), Vector2(2401, 2423),
]
const PAD_OFFSET := 3.0
const OVERHEAD := [
	111.0, 195.0, 307.0, 370.0, 478.0, 539.0, 630.0, 694.0, 811.0,
	923.0, 980.0, 1071.0, 1137.0, 1246.0, 1320.0, 1478.0, 1584.0, 1657.0,
	1836.0, 1926.0, 2024.0, 2179.0, 2249.0, 2376.0, 2438.0,
]
# Vector2 stores centre and width. Wider racks demand a properly timed hop.
const SPIKES := [
	Vector2(78, 3.4), Vector2(218, 2.8), Vector2(279, 3.8), Vector2(408, 4.4),
	Vector2(507, 3.2), Vector2(570, 4.0), Vector2(734, 2.6), Vector2(755, 4.6),
	Vector2(889, 3.5), Vector2(1024, 3.8), Vector2(1165, 4.5), Vector2(1356, 2.8),
	Vector2(1411, 4.8), Vector2(1497, 3.2), Vector2(1708, 3.3), Vector2(1763, 4.5),
	Vector2(1854, 3.1), Vector2(1959, 3.6), Vector2(2075, 4.5), Vector2(2113, 3.1),
	Vector2(2268, 3.6), Vector2(2300, 4.0),
]

static func surface_at(x: float) -> float:
	for index in range(1, GRADE.size()):
		var next: Vector2 = GRADE[index]
		if x <= next.x:
			var previous: Vector2 = GRADE[index - 1]
			var fraction := clampf(inverse_lerp(previous.x, next.x, x), 0.0, 1.0)
			return lerpf(previous.y, next.y, fraction)
	return GRADE[-1].y
