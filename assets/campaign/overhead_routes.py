"""Overhead loop and arena layouts, in sector / act order.

Loop entries use local metres. Sign/entry type determines how the player
reaches the high deck, direction determines the far turnaround.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class OverheadRoute:
    after: str
    title: str
    width: float
    mechanism: str
    direction: int
    rise: float
    obstacle: str
    gaps: tuple[float, float]
    drops: tuple[float, float]


OVERHEAD = {
    "machine_jungle": (
        OverheadRoute("CANOPY RISER", "CROWN OF ROOTS", 76, "vine", -1, 15.0, "SPORE POD", (3.8,5.2), (2.8,5.2)),
        OverheadRoute("VINE VIADUCT", "POLLEN UPLINK", 84, "vent", 1, 16.3, "ROOT POOL", (6.5,4.2), (3.65,7.0)),
    ),
    "frozen_reactor": (
        OverheadRoute("CONDENSER VAULT", "GLACIER GANTRY", 82, "kick", 1, 16.1, "ICE", (4.4,5.8), (3.1,6.9)),
        OverheadRoute("THERMAL SINK", "DEFROST HOIST", 72, "lift", -1, 14.9, "COOLANT", (7.1,3.6), (3.25,6.05)),
    ),
    "abyssal_plant": (
        OverheadRoute("SLUICE CROSSING", "DRY HEADER", 83, "lift", 1, 16.7, "ELECTRODES", (4.2,7.7), (3.2,5.9)),
        OverheadRoute("DRAINAGE SPILLWAY", "FLOOD CROWN", 77, "buoyant", -1, 15.3, "CURRENT", (5.1,6.4), (4.15,7.05)),
    ),
    "buried_archives": (
        OverheadRoute("DEAD LETTER ROUTE", "WITNESS CAROUSEL", 78, "hatch", -1, 15.2, "PHASE", (6.9,4.0), (3.0,7.0)),
        OverheadRoute("SUB-ARCHIVE", "GHOST INDEX", 86, "kick", 1, 17.1, "CORRUPTION", (4.9,7.3), (3.25,5.15)),
    ),
    "sky_dock": (
        OverheadRoute("FLIGHT DECK RAMP", "CRANE RAIL", 87, "vent", 1, 17.2, "WIND", (7.4,4.5), (3.6,6.35)),
        OverheadRoute("CROSSWIND TRUSS", "NAVIGATION SPINE", 77, "lift", -1, 16.5, "UPDRAFT", (5.9,7.0), (3.15,7.75)),
    ),
    "biolab": (
        OverheadRoute("OBSERVATION WALK", "STERILE OVERLOOK", 79, "hatch", 1, 15.9, "MUTATION", (4.2,7.5), (3.1,5.55)),
        OverheadRoute("VENT RISER", "EXHAUST BYPASS", 83, "vent", -1, 16.7, "VENT", (5.8,4.6), (4.1,7.1)),
    ),
    "orbital_array": (
        OverheadRoute("ANTENNA RISER", "UPLINK ARMS", 87, "gravity", -1, 17.6, "SOLAR", (7.1,6.1), (4.2,7.65)),
        OverheadRoute("DISH HOUSING", "ECLIPSE RING", 78, "lift", 1, 15.7, "GRAVITY", (4.6,5.6), (2.8,6.1)),
    ),
    "scrapyard_expanse": (
        OverheadRoute("DISASSEMBLY DROP", "MAGNET BRIDGE", 86, "lift", -1, 16.0, "MAGNET", (5.4,7.5), (3.05,5.95)),
        OverheadRoute("SORTING CRANE", "SORTER WALK", 80, "kick", 1, 16.9, "PRESS", (4.9,7.1), (4.05,7.6)),
    ),
    "riftcore_nexus": (
        OverheadRoute("FRACTURED CACHE", "ECHO STRUTS", 87, "gravity", 1, 17.5, "PHASE", (7.8,6.5), (3.5,7.1)),
        OverheadRoute("CORE TRANSFER", "NULL CROWN", 91, "kick", -1, 17.9, "LASER", (7.2,8.0), (3.55,8.25)),
    ),
}

# Fractions of arena width followed by deck width and world height over floor.
# The device is placed at a local fraction of the same width.
ARENAS = {
    "machine_jungle": (
        ("ROOT GUARD LOFT", ((.23,5,2.3),(.38,5,4.15),(.71,6,3.3)), "vine", .38),
        ("COLOSSUS CANOPY", ((.17,8,3.65),(.61,7,6.05),(.81,5,4.5)), "vine", .81),
    ),
    "frozen_reactor": (
        ("CRYO DETOUR", ((.22,5,2.0),(.36,6,3.85),(.82,5,4.0)), "cover", .55),
        ("DEFROST RING", ((.24,6,4.25),(.53,5,6),(.76,8,4.1)), "lift", .38),
    ),
    "abyssal_plant": (
        ("PUMP DECK", ((.21,5,2.2),(.42,8,4.4),(.79,5,3.0)), "current", .62),
        ("KRAKEN DRY LOCK", ((.21,7,4.2),(.48,6,6.0),(.76,5,3.35)), "lift", .33),
    ),
    "buried_archives": (
        ("INDEX DODGE", ((.25,5,3.0),(.53,6,4.6),(.83,4,2.8)), "phase", .40),
        ("CIPHER CROSSING", ((.19,6,4.0),(.43,5,5.65),(.72,7,5.45)), "phase", .58),
    ),
    "sky_dock": (
        ("HANGAR UPDRAFT", ((.20,5,2.3),(.48,6,4.3),(.79,6,3.6)), "vent", .35),
        ("AEROWYRM FLIGHT DECK", ((.16,7,4.6),(.38,5,7.05),(.74,8,5.1)), "vent", .63),
    ),
    "biolab": (
        ("CLEAN ROOM RAMPART", ((.24,7,2.6),(.36,5,4.4),(.79,4,3.2)), "cover", .6),
        ("CHIMERA OBSERVATION", ((.20,6,4.8),(.57,7,6.2),(.79,7,3.9)), "vent", .32),
    ),
    "orbital_array": (
        ("GRAVITY HOP", ((.24,5,3.0),(.46,4,5.4),(.74,8,4.15)), "gravity", .38),
        ("ECLIPSE RING", ((.17,7,3.9),(.43,6,6.5),(.73,6,7.4)), "gravity", .51),
    ),
    "scrapyard_expanse": (
        ("CRANE COVER", ((.19,7,2.4),(.62,6,4.7),(.79,5,3.35)), "cover", .45),
        ("REVENANT FOUNDRY", ((.21,6,4.1),(.51,6,6.3),(.81,8,4.6)), "lift", .64),
    ),
    "riftcore_nexus": (
        ("ECHO STRAFE", ((.18,7,2.3),(.49,6,4.7),(.81,5,3.15)), "phase", .36),
        ("ARCHITECT NULL CHAMBER", ((.21,5,3.7),(.47,5,7.2),(.75,7,5.75)), "gravity", .45),
    ),
}
