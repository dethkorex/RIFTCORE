"""Act-specific junctions. Room order and the rest of each act live in interior_routes."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Junction:
    room: str
    span: int
    depth: float
    gap: float
    upper_route: str
    lower_field: str
    merge_field: str
    lanes: tuple[str, str, str]


# A negative depth adds a compulsory westbound crossing below the first split.
# Upper routes either open early, branch from the middle, or turn back to a cache.
JUNCTIONS = {
    "machine_jungle": (
        (Junction("ROOT CELLAR", 71, -8.4, 4.9, "vine", "ROOT POOL", "SPORE POD",
                  ("ROOT TUNNEL", "NURSERY WALK", "VINE CANOPY")),
         Junction("SPORE TERRACES", 61, 0, 5.0, "early", "SPORE POD", "ROOT POOL",
                  ("SPORE FLOOR", "DRAIN WALK", "CROWN LEDGES"))),
        (Junction("FLOODED SEED BANK", 66, 0, 5.4, "vine", "ROOT POOL", "SPORE POD",
                  ("FLOODED ROOTS", "SEED WALK", "VINE CANOPY")),
         Junction("UNDERGROWTH", 82, -9.1, 5.8, "late", "SPORE POD", "ROOT POOL",
                  ("HOLLOW TRUNK", "ROOT BRIDGES", "POLLEN LEDGES"))),
    ),
    "frozen_reactor": (
        (Junction("CONDENSER VAULT", 60, 0, 5.8, "late", "ICE", "COOLANT",
                  ("ICED FLOOR", "CONDENSER WALK", "HEAT PIPES")),
         Junction("COOLANT RETURN", 85, -9.4, 5.6, "reverse", "ICE", "COOLANT",
                  ("CHILLER SUMP", "SERVICE TRUSS", "CONDENSER WALK"))),
        (Junction("FROZEN LOCK", 74, -8.6, 5.2, "lift", "COOLANT", "ICE",
                  ("COOLANT TRENCH", "INSULATED WALK", "HOIST BALCONY")),
         Junction("HEAT RESERVE", 64, 0, 5.5, "early", "COOLANT", "ICE",
                  ("PURGE RUN", "RESERVE DECK", "WARM CATWALK"))),
    ),
    "abyssal_plant": (
        (Junction("PRESSURE MANIFOLD", 87, -8.9, 6.2, "lift", "CURRENT", "ELECTRODES",
                  ("INTAKE CHANNEL", "PIPE WALK", "BALLAST BALCONY")),
         Junction("PUMP SERVICE DECK", 62, 0, 5.2, "late", "ELECTRODES", "CURRENT",
                  ("PUMP FLOOR", "PRESSURE WALK", "DRY PIPES"))),
        (Junction("RESERVOIR BYPASS", 65, 0, 5.6, "early", "CURRENT", "ELECTRODES",
                  ("RESERVOIR", "SPILLWAY WALK", "SEALED BALCONY")),
         Junction("FLOOD CONTROL", 80, -9.7, 5.0, "reverse", "ELECTRODES", "CURRENT",
                  ("DRAINAGE BASIN", "BUS BAR WALK", "DRY CONTROL ROOM"))),
    ),
    "buried_archives": (
        (Junction("WITNESS STACKS", 77, -8.6, 5.5, "phase", "CORRUPTION", "PHASE",
                  ("STACK BASEMENT", "INDEX WALK", "PHASE LEDGES")),
         Junction("INDEX BALCONY", 63, 0, 5.1, "reverse", "CORRUPTION", "PHASE",
                  ("INDEX FLOOR", "WITNESS WALK", "RETURN VAULT"))),
        (Junction("PHASE TRANSFER", 65, 0, 5.9, "phase", "CORRUPTION", "PHASE",
                  ("REDACTION BELT", "TRANSFER WALK", "PHASE LEDGES")),
         Junction("SUB-ARCHIVE", 85, -9.4, 6.0, "late", "CORRUPTION", "PHASE",
                  ("SEALED STACKS", "DATA TRUSS", "MANUSCRIPT VAULT"))),
    ),
    "sky_dock": (
        (Junction("HANGAR MEZZANINE", 66, 0, 6.2, "boost", "WIND", "UPDRAFT",
                  ("WIND TUNNEL", "HANGAR WALK", "VENT BALCONY")),
         Junction("TRANSFER TRUSS", 88, -8.6, 5.7, "lift", "WIND", "UPDRAFT",
                  ("SERVICE HANGAR", "TRANSFER WALK", "CRANE BALCONY"))),
        (Junction("FLIGHT DECK", 83, -9.2, 6.1, "boost", "WIND", "UPDRAFT",
                  ("EXHAUST DUCT", "FLIGHT TRUSS", "LIFT VENT")),
         Junction("SEALED MANIFESTS", 63, 0, 5.4, "reverse", "UPDRAFT", "WIND",
                  ("CARGO DRAFT", "MANIFEST WALK", "FORMER CONTROL"))),
    ),
    "biolab": (
        (Junction("CULTURE TRENCH", 76, -8.8, 5.1, "late", "MUTATION", "VENT",
                  ("CULTURE SUMP", "STERILE WALK", "CULTURE VAULT")),
         Junction("OBSERVATION WALK", 63, 0, 5.9, "early", "VENT", "MUTATION",
                  ("HOT SIDE", "OBSERVATION WALK", "SPECIMEN SHELVES"))),
        (Junction("ISOLATION CHAMBER", 66, 0, 5.4, "lift", "VENT", "MUTATION",
                  ("ISOLATION FLOOR", "GLASS WALK", "SPECIMEN HOIST")),
         Junction("PATIENT VAULT", 82, -9.6, 5.7, "reverse", "MUTATION", "VENT",
                  ("WASTE SUMP", "QUARANTINE WALK", "PATIENT VAULT"))),
    ),
    "orbital_array": (
        (Junction("GRAVITY WALK", 64, 0, 6.4, "early", "GRAVITY", "SOLAR",
                  ("GRAVITY WELL", "ARRAY WALK", "ANTENNA LEDGES")),
         Junction("SHIELDED TUNNEL", 85, -9.4, 6.2, "phase", "GRAVITY", "SOLAR",
                  ("SHIELDED CELLAR", "SERVICE RING", "RELAY LEDGES"))),
        (Junction("MAINTENANCE TRANSFER", 81, -9.0, 6.4, "lift", "SOLAR", "GRAVITY",
                  ("MAINTENANCE WELL", "SHADOW WALK", "CALIBRATION LIFT")),
         Junction("DISH HOUSING", 64, 0, 5.7, "late", "SOLAR", "GRAVITY",
                  ("EXPOSED RIM", "DISH WALK", "RECEIVER LEDGES"))),
    ),
    "scrapyard_expanse": (
        (Junction("CRUSHER TRANSFER", 64, 0, 5.4, "late", "PRESS", "MAGNET",
                  ("CRUSHER FLOOR", "SCRAP WALK", "SORTING LEDGES")),
         Junction("RECOVERY TRENCH", 84, -9.1, 5.6, "lift", "MAGNET", "PRESS",
                  ("SCRAP TRENCH", "RECOVERY WALK", "JUNK HOIST"))),
        (Junction("RECLAIMED CORES", 80, -9.7, 6.0, "reverse", "PRESS", "MAGNET",
                  ("RECLAMATION SUMP", "MAGNET WALK", "RECLAIMED CORES")),
         Junction("FURNACE WALK", 66, 0, 5.8, "boost", "MAGNET", "PRESS",
                  ("SORTING FLOOR", "FURNACE WALK", "EXHAUST LEDGES"))),
    ),
    "riftcore_nexus": (
        (Junction("PHASE SUBLEVEL", 80, -8.9, 6.1, "phase", "GRAVITY", "CORRUPTION",
                  ("GRAVITY SINK", "ECHO WALK", "PHASE SHELVES")),
         Junction("ECHO BALCONY", 67, 0, 5.7, "reverse", "CORRUPTION", "PHASE",
                  ("RIFT FLOOR", "BALCONY WALK", "ECHO VAULT"))),
        (Junction("SEVERED LINK", 65, 0, 5.8, "phase", "LASER", "GRAVITY",
                  ("LASER CHANNEL", "SEVERED WALK", "GHOST SPAN")),
         Junction("WITNESS BYPASS", 88, -9.8, 6.2, "late", "CORRUPTION", "LASER",
                  ("NULL BASEMENT", "WITNESS WALK", "CORE VAULT"))),
    ),
}



# Each pair describes the first and second junction in travel order.
# "echo" sends players between levels to reconnect. "switch" opens a return
# descent. "ferry" crosses a shaft diagonally. "slalom" alternates shelves.
ROUTE_BEATS = {
    "machine_jungle": (("echo", "slalom"), ("slalom", "switch")),
    "frozen_reactor": (("switch", "echo"), ("ferry", "slalom")),
    "abyssal_plant": (("ferry", "echo"), ("slalom", "switch")),
    "buried_archives": (("echo", "switch"), ("slalom", "echo")),
    "sky_dock": (("slalom", "ferry"), ("echo", "switch")),
    "biolab": (("echo", "slalom"), ("ferry", "switch")),
    "orbital_array": (("slalom", "echo"), ("ferry", "switch")),
    "scrapyard_expanse": (("switch", "ferry"), ("echo", "slalom")),
    "riftcore_nexus": (("echo", "switch"), ("slalom", "echo")),
}
