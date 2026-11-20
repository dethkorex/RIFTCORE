"""Authored outbound switchback lines. Coordinates are fractions of the room's existing run.
The sheltered sump, reverse gallery, vault and relay keep their original geometry.
Each pair gives bank limits and deck elevations in metres above the old floor.
"""

# name, left fraction, right fraction, left height, right height
LINES = {
    (2, 1): [("RootToe",0,.29,0,.65),("HollowRoot",.42,.63,-.80,-.8),("NurseryBank",.76,1,.65,0)],
    (2, 2): [("OrchidLip",0,.18,0,.7),("PollenShelf",.30,.48,-1,-.6),("VineCradle",.64,.85,.65,.95),("ReturnBough",.93,1,0,0)],
    (3, 2): [("FrostShelf",0,.31,0,.9),("BrakePocket",.50,.68,-.8,-.8),("CompressorLip",.83,1,.6,0)],
    (5, 1): [("IndexRamp",0,.30,0,-.55),("FallenStack",.48,.65,.9,.9),("ShelfFoot",.75,1,-.7,0)],
    (5, 2): [("Scriptorium",0,.25,0,.85),("SunkenIndex",.39,.56,-1,-1),("OrreryReturn",.74,1,.65,0)],
    (6, 1): [("MooringRamp",0,.24,0,.65),("CargoSling",.36,.47,-.8,-.8),("DockArm",.64,.83,.5,.85),("GantryToe",.92,1,0,0)],
    (6, 2): [("FreightApron",0,.38,0,-.7),("BallastCar",.58,.70,.6,.6),("TugDock",.85,1,-.55,0)],
    (7, 1): [("SpecimenBay",0,.31,0,-.8),("IsolationPlinth",.44,.64,.8,.8),("SterileDrain",.76,1,-.5,0)],
    (7, 2): [("IntakeGrille",0,.20,0,.65),("FilterBed",.32,.57,-.95,-.65),("PurgeBridge",.72,.87,.85,.65),("ExhaustLip",.94,1,0,0)],
    (8, 1): [("HeavyWalk",0,.31,0,-.55),("Receiver",.48,.65,.9,.9),("ArraySkirt",.79,1,-.75,0)],
    (8, 2): [("DishRim",0,.22,0,.75),("Counterweight",.37,.48,-.85,-.85),("CalibrationTable",.65,.82,.7,.45),("AzimuthWalk",.91,1,0,0)],
    (9, 1): [("HopperLip",0,.24,0,.7),("PressBed",.38,.58,-.9,-.9),("ScrapBale",.74,1,.75,0)],
    (9, 2): [("SortingChute",0,.38,0,-.8),("MagnetLoad",.55,.70,.75,.75),("RejectBin",.80,1,-.5,0)],
    (10, 1): [("EchoSill",0,.24,0,.55),("FractureShelf",.38,.66,-.85,-.45),("PhaseBank",.82,1,.8,0)],
    (10, 2): [("SplitLip",0,.19,0,-.7),("CoreIsland",.33,.44,.65,.65),("InvertedWalk",.55,.77,-.9,-.75),("NullShoulder",.92,1,.9,0)],
}

# Ports on stable landings activate an existing lift, cross-current, phase step or hoist.
# Keep timed damage obstacles out of the landing zone. Existing sump traps stay underneath.
DEVICES = {
    (2,1): ("field",1,.20), (2,2): ("hatch",0,.82), (3,2): ("ice",0,.12),
    (5,1): ("lift",0,.56), (5,2): ("phase",0,.51),
    (6,1): ("lift",0,.415), (6,2): ("field",2,.27),
    (7,1): ("hatch",0,.58), (7,2): ("field",6,.50),
    (8,1): ("field",3,.27), (8,2): ("lift",0,.415),
    (9,1): ("hatch",0,.45), (9,2): ("lift",0,.625),
    (10,1): ("phase",0,.57), (10,2): ("field",3,.685),
}

def outbound(scene, start, end, y):
    key = scene.number, scene.act
    banks = LINES[key]
    length = end - start
    device, kind, site = DEVICES[key]
    x = start + length*site
    for name, a, b, lo, hi in banks:
        left, right = start + length*a, start + length*b
        moving = device == "lift" and a < site < b
        scene.deck(name, left, right, y+lo, y+hi, moving=moving, icy=device == "ice" and a < site < b)
        if a < site < b:
            at_y = y + lo + (hi-lo)*(site-a)/(b-a)
            if moving:
                scene.relay(right-1.2, at_y, name, 2.05, True, hold=3.5, delay=.8)
            elif device == "field":
                scene.field(name+"Current", x, at_y, kind, "", width=3.2, field_height=4.2)
            elif device == "hatch":
                scene.node(name+"Climb", art="RCHatch", pos=(x,at_y+2.65,0),deck_width=2.3,climb_height=2.65)
            elif device == "phase":
                scene.node(name+"Phase", art="RCPhase", pos=(x,at_y+2.7,0),period=4.4,phase_offset=.8)
