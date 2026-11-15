"""Main-route descents organized as three connected rooms on different floors."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Fold:
    width: float
    west_end: float
    first_drop: float
    second_drop: float
    pit: float
    crossing: str
    stepped: bool = False


# Widths and landings are authored per act. Pit placement and the drop shape
# vary independently so each route asks for a different move after the turn.
FOLDS = {
    "neon_factory": (Fold(32, 6.0, 5.65, 5.4, 4.8, "west"), Fold(38, 7.0, 5.2, 5.5, 5.1, "lower", True)),
    "machine_jungle": (Fold(33, 5.2, 5.0, 5.6, 4.5, "lower", True), Fold(43, 7.4, 5.6, 6.2, 5.0, "west")),
    "frozen_reactor": (Fold(37, 6.2, 5.8, 5.2, 4.75, "west", True), Fold(41, 6.8, 6.6, 5.3, 5.3, "lower")),
    "abyssal_plant": (Fold(40, 6.4, 5.1, 5.0, 4.5, "lower"), Fold(45, 8.6, 5.8, 6.6, 5.2, "west", True)),
    "buried_archives": (Fold(34, 6.6, 5.65, 6.7, 4.8, "west"), Fold(42, 9.2, 5.65, 5.6, 5.4, "west", True)),
    "sky_dock": (Fold(44, 11.0, 5.5, 5.7, 5.3, "west", True), Fold(46, 6.4, 7.0, 6.0, 6.05, "lower")),
    "biolab": (Fold(34, 5.5, 4.9, 5.3, 4.6, "lower", True), Fold(40, 8.2, 6.2, 5.6, 5.1, "west")),
    "orbital_array": (Fold(41, 8.4, 6.5, 6.1, 5.0, "lower"), Fold(45, 7.8, 7.1, 6.3, 5.05, "west", True)),
    "scrapyard_expanse": (Fold(38, 5.1, 5.6, 6.3, 5.3, "west"), Fold(44, 9.5, 5.2, 6.5, 6.25, "lower", True)),
    "riftcore_nexus": (Fold(40, 9.0, 6.25, 6.5, 5.2, "west", True), Fold(47, 7.1, 6.8, 7.2, 6.6, "lower")),
}


# The larger encounter budgets leave space for a fourth obstacle.
FOLD_TIMED_FIXTURE = {
    ("neon_factory", 2), ("machine_jungle", 2), ("frozen_reactor", 2),
    ("sky_dock", 1), ("biolab", 2), ("scrapyard_expanse", 2),
}


def folded_route(spec, a, y, exit_y, deck, wall, pit, fixture, *, passage_hazard=None, bottom_limit=-16.0):
    east = a + spec.width
    west = a + spec.west_end
    lip = east - (5.15 if spec.stepped else 4.30)
    turn = west + 4.6
    middle = max(y - spec.first_drop, bottom_limit + 4.7)
    bottom = max(middle - spec.second_drop, bottom_limit)
    ceiling = y + 7.2
    opening = bottom + 3.55
    ramp = east + 5.8
    end = ramp + max(7.0, abs(exit_y - bottom) * 1.85)

    # A low step separates the preceding runway from the drop. The long
    # landing beyond it leaves room to set up the descent.
    sill = a + (7.2 if spec.stepped else 5.6)
    rise = .88 if spec.crossing == "west" else 1.02
    deck("Ingress", a, sill, y, y)
    deck("IngressStep", sill, sill + 2.6, y + rise, y + rise)
    deck("IngressStepRamp", sill + 2.6, sill + 5.1, y + rise, y)
    deck("IngressLane", sill + 5.1, lip, y, y)
    # The upper two floors end at the partition. Its only exit is at the
    # bottom, past the west-facing gallery and the second drop.
    wall("LowerExitHeader", east + 0.38, opening, ceiling + 0.1)
    deck("Ceiling", a, east + 0.8, ceiling, ceiling)
    wall("CeilingButtress", east + 0.38, ceiling, ceiling + 7.4)
    wall("WestShaftWall", west - 0.39, bottom - 0.4, middle + 0.60)
    if spec.stepped:
        deck("ShaftLanding", east - 1.8, east, y - 2.22, y - 2.22)
    if spec.crossing == "west":
        gap_at = turn + (east - turn) * 0.44
        deck("WestGallery", turn, gap_at, middle, middle)
        pit("GalleryPit", gap_at, gap_at + spec.pit, middle - 2.85)
        deck("EastGallery", gap_at + spec.pit, east + 0.04, middle, middle)
        if fixture:
            fixture(east - 6.4, bottom)
    else:
        deck("ReturnGallery", turn, east + 0.04, middle, middle)
        if fixture:
            fixture(turn + (east - turn) * 0.38, middle)
        elif passage_hazard and east - turn >= 28.5:
            passage_hazard("ReturnGalleryHazard", (turn + east) * .5, middle)
    if spec.crossing == "lower":
        gap_at = west + (east - west) * 0.51
        deck("BasementLanding", west, gap_at, bottom, bottom)
        pit("BasementPit", gap_at, gap_at + spec.pit, bottom - 2.85)
        deck("BasementExit", gap_at + spec.pit, ramp, bottom, bottom)
    else:
        deck("Basement", west, ramp, bottom, bottom)
        if passage_hazard and ramp - west >= 27.5:
            passage_hazard("BasementHazard", west + (ramp - west) * .46, bottom)
    deck("DrainRise", ramp, end, bottom, exit_y)
    return end, bottom
