"""Hand-authored crossings for the main route, in metres.

Profiles describe how connected masses shape a room. Gap length and the
landing rise are constrained by a measured stock RX-07 jump.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class Room:
    name: str
    design: str
    turn: float
    pit: float
    ledge: float
    rise: float


ROOMS = {
    "machine_jungle": (
        Room("DRAIN ROOTS", "terraces", .29, 4.2, -2.25, -3.6),
        Room("GUARDIAN NURSERY", "low_branch", .46, 4.7, -1.45, -.55),
    ),
    "frozen_reactor": (
        Room("FROST STEP DOWN", "terraces", .34, 4.8, -1.35, -3.25),
        Room("REACTOR CHIMNEY", "climb", .36, 0, -2.1, 4.35),
    ),
    "abyssal_plant": (
        Room("BILGE STACK", "climb", .50, 0, -1.5, 4.55),
        Room("BUS BAR BALCONY", "low_branch", .35, 5.1, -2.0, .85),
    ),
    "buried_archives": (
        Room("GLYPH SHAFT", "climb", .39, 0, -2.55, 4.50),
        Room("BLACKOUT RECORD", "low_branch", .49, 4.9, -1.95, -.32),
    ),
    "sky_dock": (
        Room("VENT DROP", "terraces", .41, 5.15, -1.65, -2.0),
        Room("CARGO ELEVATOR", "climb", .54, 0, -1.25, 4.4),
    ),
    "biolab": (
        Room("STERILIZATION STACK", "climb", .38, 0, -1.25, 4.6),
        Room("PATIENT VAULT", "low_branch", .41, 4.4, -2.2, -1.35),
    ),
    "orbital_array": (
        Room("CALIBRATION LIFT", "terraces", .54, 5.3, .62, 1.15),
        Room("UPLINK SHAFT", "climb", .46, 0, -2.45, 4.65),
    ),
    "scrapyard_expanse": (
        Room("RECOVERY TRENCH", "low_branch", .39, 4.3, -2.4, -.65),
        Room("RECLAIMED CORES", "terraces", .48, 4.85, -1.2, -.65),
    ),
    "riftcore_nexus": (
        Room("NULL RISER", "climb", .50, 0, -1.55, 4.7),
        Room("FINAL MEMORY VAULT", "terraces", .58, 5.35, -.82, 1.25),
    ),
}
