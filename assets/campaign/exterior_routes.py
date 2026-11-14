"""Playable outdoor traverses and secondary views for the authored campaign."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Exterior:
    room: str
    view_room: str
    exit_sign: str
    gap: float
    shelf_rise: float
    exit_rise: float
    style: str


# These rooms use the normal campaign checkpoints and connect back into the
# existing junctions. The second opening is a view on a different route beat.
EXTERIORS = {
    "machine_jungle": (
        Exterior("", "VELVET GROVE", "GROVE ACCESS", 0, 0, 0, "roots"),
        Exterior("", "GUARDIAN NURSERY", "GROVE ANTECHAMBER", 0, 0, 0, "roots"),
    ),
    "frozen_reactor": (
        Exterior("ICE INTAKE", "GLACIER TUNNEL", "COOLANT LOCK", 4.65, .70, 1.45, "ridge"),
        Exterior("COMPRESSOR RAMP", "HEAT RESERVE", "COMPRESSOR INTAKE", 6.75, -.70, .25, "ledge"),
    ),
    "abyssal_plant": (
        Exterior("FLOODGATE DESCENT", "PUMP SERVICE DECK", "SUBMERGED PUMP GALLERY", 5.10, -1.10, -1.80, "stepped"),
        Exterior("DRAINAGE SPILLWAY", "BUS BAR BALCONY", "LOWER FLOOD CONTROL", 6.2, -.95, -1.45, "ledge"),
    ),
    "buried_archives": (
        Exterior("BURIED STACKS", "BRIDGE OF RECORDS", "ENTER THE INDEX VAULT", 4.35, -.90, -1.75, "stepped"),
        Exterior("REDACTION FLOOR", "FORGOTTEN STACKS", "ARCHIVE SERVICE AIRLOCK", 5.35, .65, 1.35, "ridge"),
    ),
    "sky_dock": (
        Exterior("FLIGHT DECK RAMP", "HANGAR MEZZANINE", "ENTER THE FREIGHT HANGAR", 5.95, .33, -.50, "ledge"),
        Exterior("SHUTTLE BAY", "FLIGHT DECK", "FLIGHT CONTROL AIRLOCK", 7.90, -.40, .35, "stepped"),
    ),
    "biolab": (
        Exterior("WASTE CHUTE", "OBSERVATION WALK", "STERILE SPECIMEN GALLERY", 4.75, .60, .20, "ledge"),
        Exterior("SPORE DRAIN", "THAW LAB", "QUARANTINE ACCESS", 4.20, -.90, -1.65, "stepped"),
    ),
    "orbital_array": (
        Exterior("SOLAR RAMP", "GRAVITY WALK", "SHIELDED TRANSFER", 7.20, -.32, .50, "ridge"),
        Exterior("ECLIPSE SPAN", "DISH HOUSING", "UPLINK ACCESS HATCH", 8.0, -.45, -.90, "ledge"),
    ),
    "scrapyard_expanse": (
        Exterior("SCRAP RAMPS", "DISASSEMBLY DROP", "ENTER THE SORTER", 5.25, .78, 1.80, "ridge"),
        Exterior("SLAG DRIFT", "FURNACE WALK", "FURNACE VENTILATION LOCK", 6.40, -.65, -1.45, "stepped"),
    ),
    "riftcore_nexus": (
        Exterior("RIFT SINK", "ECHO BALCONY", "ENTER THE CORE", 6.50, -1.15, -1.9, "stepped"),
        Exterior("BEFORE THE FRACTURE", "NULL DESCENT", "FRACTURE CONTAINMENT", 7.55, .35, 1.25, "ridge"),
    ),
}
