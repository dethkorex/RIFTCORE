"""Authored room order for each sector. Widths are in Godot metres."""
# Every tuple is (room type, width, in-world sign). Slopes and shafts change the
# elevation of the main route. Loops, galleries and lifts branch off that route.
ROUTES = {
    "machine_jungle": [
        [("gallery",42,"ROOT NURSERY"),("loop",42,"ROOT CELLAR"),("shaft",45,"CANOPY RISER"),("gallery",48,"SPORE TERRACES"),("fall",33,"DRAIN ROOTS"),("lift",34,"SEED HOIST"),("branch",41,"VELVET GROVE"),("hall",30,"GROVE ACCESS")],
        [("loop",39,"FLOODED SEED BANK"),("gallery",43,"VINE VIADUCT"),("fall",32,"HOLLOW TRUNK"),("shaft",47,"POLLEN SHAFT"),("loop",49,"UNDERGROWTH"),("bridge",36,"ROOT FERRY"),("gallery",37,"GUARDIAN NURSERY"),("hall",33,"GROVE ANTECHAMBER")],
    ],
    "frozen_reactor": [
        [("slope",38,"ICE INTAKE"),("shaft",42,"COOLANT RISER"),("branch",42,"CONDENSER VAULT"),("fall",39,"FROST STEP DOWN"),("loop",54,"COOLANT RETURN"),("bridge",35,"HEAT EXCHANGER"),("slope",36,"GLACIER TUNNEL"),("hall",36,"REACTOR ACCESS")],
        [("bridge",44,"FROZEN LOCK"),("loop",43,"UNDER-ICE BYPASS"),("slope",39,"COMPRESSOR RAMP"),("lift",39,"COOLANT HOIST"),("fall",36,"THERMAL SINK"),("shaft",43,"REACTOR CHIMNEY"),("gallery",46,"HEAT RESERVE"),("hall",36,"CORE APPROACH")],
    ],
    "abyssal_plant": [
        [("fall",41,"FLOODGATE DESCENT"),("loop",55,"PRESSURE MANIFOLD"),("bridge",39,"SLUICE CROSSING"),("gallery",41,"PUMP SERVICE DECK"),("shaft",39,"BILGE STACK"),("branch",35,"PRESSURE VAULT"),("lift",42,"BALLAST LIFT"),("hall",33,"DRY AIRLOCK")],
        [("loop",51,"RESERVOIR BYPASS"),("lift",36,"BALLAST FERRY"),("gallery",46,"BUS BAR BALCONY"),("bridge",35,"ELECTRODE BAY"),("fall",34,"DRAINAGE SPILLWAY"),("branch",45,"FLOOD CONTROL"),("shaft",43,"PRESSURE RELEASE"),("hall",39,"KRAKEN LOCK")],
    ],
    "buried_archives": [
        [("branch",40,"WITNESS STACKS"),("fall",42,"BURIED STACKS"),("loop",47,"DEAD LETTER ROUTE"),("gallery",38,"INDEX BALCONY"),("shaft",44,"GLYPH SHAFT"),("bridge",39,"BRIDGE OF RECORDS"),("branch",44,"RECORD VAULT"),("hall",31,"CIPHER GATE")],
        [("shaft",41,"ARCHIVE SERVICE CORE"),("gallery",45,"REDACTION FLOOR"),("bridge",42,"PHASE TRANSFER"),("loop",56,"SUB-ARCHIVE"),("fall",35,"FORGOTTEN STACKS"),("lift",36,"MANUSCRIPT HOIST"),("branch",40,"BLACKOUT RECORD"),("hall",34,"CIPHER CHAMBER")],
    ],
    "sky_dock": [
        [("lift",43,"FREIGHT APRON"),("gallery",48,"HANGAR MEZZANINE"),("slope",34,"FLIGHT DECK RAMP"),("bridge",43,"TRANSFER TRUSS"),("fall",31,"VENT DROP"),("branch",42,"CARGO HOLD"),("shaft",42,"CONTROL TOWER"),("hall",33,"INNER HANGAR")],
        [("gallery",55,"FLIGHT DECK"),("shaft",45,"CONTROL RISER"),("fall",39,"SHUTTLE BAY"),("lift",37,"CARGO ELEVATOR"),("bridge",42,"CROSSWIND TRUSS"),("branch",45,"SEALED MANIFESTS"),("slope",38,"FLIGHT CONTROL"),("hall",35,"AEROWYRM HANGAR")],
    ],
    "biolab": [
        [("loop",43,"CULTURE TRENCH"),("branch",36,"QUARANTINE STORAGE"),("gallery",48,"OBSERVATION WALK"),("lift",37,"SPECIMEN ELEVATOR"),("shaft",44,"STERILIZATION STACK"),("fall",34,"WASTE CHUTE"),("bridge",45,"CONTAINMENT SPAN"),("hall",34,"CLEAN ROOM")],
        [("fall",35,"SPORE DRAIN"),("bridge",38,"ISOLATION CHAMBER"),("loop",55,"QUARANTINE LOOP"),("shaft",40,"VENT RISER"),("gallery",49,"THAW LAB"),("branch",42,"PATIENT VAULT"),("lift",36,"SPECIMEN TRANSFER"),("hall",38,"CHIMERA OBSERVATION")],
    ],
    "orbital_array": [
        [("bridge",38,"ARRAY TRUSS"),("gallery",43,"GRAVITY WALK"),("shaft",47,"ANTENNA RISER"),("loop",46,"SHIELDED TUNNEL"),("slope",39,"SOLAR RAMP"),("lift",42,"CALIBRATION LIFT"),("branch",35,"SIGNAL VAULT"),("hall",36,"RELAY LOCK")],
        [("lift",37,"MAINTENANCE TRANSFER"),("fall",32,"SPIN CHAMBER"),("bridge",42,"ECLIPSE SPAN"),("branch",43,"SHADOW STORAGE"),("loop",49,"SHIELDED CIRCUIT"),("gallery",54,"DISH HOUSING"),("shaft",40,"UPLINK SHAFT"),("hall",38,"ARRAY CONTROL")],
    ],
    "scrapyard_expanse": [
        [("slope",40,"SCRAP RAMPS"),("branch",38,"MAGNETIC SALVAGE"),("bridge",40,"CRUSHER TRANSFER"),("fall",35,"DISASSEMBLY DROP"),("loop",49,"RECOVERY TRENCH"),("shaft",39,"COMPACTOR SHAFT"),("lift",41,"JUNK HOIST"),("hall",37,"RECLAMATION DOOR")],
        [("branch",42,"RECLAIMED CORES"),("lift",44,"SORTING CRANE"),("loop",52,"SCRAP BYPASS"),("bridge",36,"PRESS TRANSFER"),("gallery",43,"FURNACE WALK"),("fall",35,"SLAG DRIFT"),("shaft",47,"REVENANT RISER"),("hall",34,"SCRAP FOUNDRY")],
    ],
    "riftcore_nexus": [
        [("shaft",38,"NULL RISER"),("branch",43,"FRACTURED CACHE"),("loop",48,"PHASE SUBLEVEL"),("bridge",39,"CORRUPTION SPAN"),("fall",39,"RIFT SINK"),("gallery",51,"ECHO BALCONY"),("lift",44,"CORE ELEVATOR"),("hall",31,"NULL THRESHOLD")],
        [("bridge",42,"SEVERED LINK"),("shaft",47,"PHASE RISER"),("fall",34,"NULL DESCENT"),("gallery",52,"BEFORE THE FRACTURE"),("lift",39,"CORE TRANSFER"),("loop",49,"WITNESS BYPASS"),("branch",46,"FINAL MEMORY VAULT"),("hall",40,"ARCHITECT ACCESS")],
    ],
}
