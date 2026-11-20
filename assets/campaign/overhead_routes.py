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
        OverheadRoute("CROSSWIND TRUSS", "NAVIGATION SPINE", 77, "lift", -1, 16.5, "UPDRAFT", (5.9,5.65), (3.15,7.75)),
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
        ("ROOT GUARD LOFT", ((.20,4,2.45),(.39,5,4.15),(.69,8,5.75)), "vine", .39),
        ("COLOSSUS CANOPY", ((.14,5,3.6),(.33,7,5.4),(.68,10,5.95),(.87,3.8,3.35)), "vine", .68),
    ),
    "frozen_reactor": (
        ("CRYO DETOUR", ((.18,6.8,2.5),(.40,4,4.05),(.78,8.8,2.85)), "cover", .59),
        ("DEFROST RING", ((.15,5.6,3.65),(.38,8,5.7),(.68,4,4.55),(.85,5,2.55)), "lift", .51),
    ),
    "abyssal_plant": (
        ("PUMP DECK", ((.21,5,2.5),(.42,8,4.4),(.79,5,3.0)), "current", .62),
        ("KRAKEN DRY LOCK", ((.21,7,4.2),(.48,6,6.0),(.76,5,3.35)), "lift", .33),
    ),
    "buried_archives": (
        ("INDEX DODGE", ((.16,4.8,2.5),(.35,5.6,4.35),(.75,10,3.15)), "phase", .55),
        ("CIPHER CROSSING", ((.17,6,4.15),(.37,5,6.35),(.63,5,5.35),(.82,4,3.15)), "phase", .49),
    ),
    "sky_dock": (
        ("HANGAR UPDRAFT", ((.16,6,2.55),(.49,8,6.15),(.75,3.8,4.2),(.89,3.5,2.55)), "vent", .34),
        ("AEROWYRM FLIGHT DECK", ((.19,8,4.5),(.39,4.4,6.6),(.78,10,5.15)), "vent", .58),
    ),
    "biolab": (
        ("CLEAN ROOM RAMPART", ((.22,8.2,2.5),(.42,4,4.25),(.85,5,2.8)), "cover", .63),
        ("CHIMERA OBSERVATION", ((.15,5,3.6),(.34,5.6,5.45),(.56,5,7.2),(.83,7.8,3.5)), "vent", .67),
    ),
    "orbital_array": (
        ("GRAVITY HOP", ((.17,4.8,2.55),(.47,5.4,6.3),(.76,9,4.1)), "gravity", .34),
        ("ECLIPSE RING", ((.15,5,3.7),(.32,5,5.65),(.52,6,7.65),(.79,7.2,6.2)), "gravity", .62),
    ),
    "scrapyard_expanse": (
        ("CRANE COVER", ((.19,6,2.55),(.38,5,4.3),(.73,10.8,3.45)), "cover", .55),
        ("REVENANT FOUNDRY", ((.13,4.5,3.8),(.29,4,5.55),(.63,9.8,5.75),(.86,4.5,3.8)), "lift", .47),
    ),
    "riftcore_nexus": (
        ("ECHO STRAFE", ((.16,4.6,2.5),(.36,4.8,4.25),(.70,6,5.4),(.87,4,3.25)), "phase", .525),
        ("ARCHITECT NULL CHAMBER", ((.15,5,3.65),(.36,6,5.55),(.60,4.5,7.55),(.85,7.4,4.85)), "gravity", .47),
    ),
}
