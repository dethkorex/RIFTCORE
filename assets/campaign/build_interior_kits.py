"""Generate the campaign interior modules and their editable Blender source."""
import random
from pathlib import Path

CAMPAIGN = Path(__file__).resolve().parent
KIT = CAMPAIGN.parent / "neon_factory" / "interiors" / "build_kit.py"
definitions = KIT.read_text(encoding="utf8").split("for name, builder in [", 1)[0]
__file__ = str(KIT)
exec(compile(definitions, str(KIT), "exec"))
__file__ = str(CAMPAIGN / "build_interior_kits.py")
SECTORS = [
    ("machine_jungle", (.12,.21,.11), (.63,.93,.19), "roots"),
    ("frozen_reactor", (.13,.24,.34), (.27,.82,1), "ice"),
    ("abyssal_plant", (.08,.18,.18), (.14,.88,.83), "pressure"),
    ("buried_archives", (.31,.20,.13), (1,.55,.16), "archive"),
    ("sky_dock", (.15,.22,.31), (.17,.91,.65), "hangar"),
    ("biolab", (.25,.12,.22), (1,.19,.66), "lab"),
    ("orbital_array", (.16,.15,.28), (.52,.37,1), "array"),
    ("scrapyard_expanse", (.28,.15,.10), (1,.34,.085), "scrap"),
    ("riftcore_nexus", (.16,.085,.22), (1,.15,.44), "rift"),
]

def ribs(count, material, front=-.46):
    for index in range(count):
        x = 5.2 * ((index + .5) / count - .5)
        box("Wall brace", (x, front, 3.5), (.20, .25, 7), material, .055)

def room(motif, panel, secondary, glow):
    box("Room backing", (0,.10,3.9), (6.01,.32,8), dark, 0)
    box("Foundation", (0,-.22,.40), (5.99,.86,.80), panel)
    box("Head beam", (0,-.32,7.52), (5.99,1.0,.83), panel)
    if motif in ("roots", "ice", "rift", "scrap"):
        randomizer = random.Random(motif)
        for i in range(11):
            x = 1.42 * (i%4-1.5)
            z = (i//4)*2.25+1.32
            block = box(motif + " strata", (x,-.22-randomizer.random()*.22,z),
                        (1.48,.80,2.36), panel if i%3 else secondary, .22,
                        randomizer.uniform(-.24,.24))
            block.rotation_euler.z = randomizer.uniform(-.19,.19)
        if motif == "roots":
            for x in [-1.7,1.8]:
                box("Branch", (x,-.72,3.6), (.72,.72,6.7), secondary, .22, x*.18)
                box("Living strip", (x,-1.11,3.55), (.14,.10,2.23), glow, .035,x*.18)
        elif motif in ("ice","rift"):
            for i in range(6):
                x = .96*(i-2.5)
                box("Faceted crystal", (x,-.81,2.10 + i*.62), (.21,.23,1.2+(i%3)*.42),
                    glow if i%2==0 else secondary,.09,x*.25)
        else:
            for z in [1.1,4.3,6.4]:
                tube("Reclaimed conduit", (0,-.83,z), .16, 5.94, secondary)
    elif motif == "pressure":
        ribs(3,secondary)
        for z in [1.55,2.85,4.7,6.15]:
            tube("Pressure header", (0,-.62,z), .21 if z<4 else .29, 5.98,panel)
            for x in [-2.3,.10,2.25]:
                tube("Flange", (x,-.62,z), .34, .20,secondary)
        box("Pressure status", (.9,-.99,4.68), (.43,.10,.09), glow)
    elif motif == "archive":
        ribs(2,secondary)
        for x in [-1.9,0,1.9]:
            box("Archive cabinet", (x,-.38,3.65), (1.68,.57,5.85),panel,.12)
            for z in range(2,7):
                box("Data drawer", (x,-.71,z), (1.43,.19,.71),secondary,.06)
                box("Drawer status", (x+.37,-.83,z), (.30,.05,.059),glow)
    elif motif in ("hangar","array"):
        ribs(3 if motif=="hangar" else 5,secondary)
        box("Recessed observation glass", (0,-.26,4.28), (5.31,.12,4.7),panel,.17)
        for x in [-2.4,2.4]:
            box("Window brace", (x,-.44,4.16),(.32,.38,5.5),secondary,.06,x*.18)
        for z in [2.1,5.8,6.8]:
            box("Window guide", (0,-.53,z),(2.71,.07,.085),glow,.02)
    else:
        for x in [-1.66,1.66]:
            box("Containment vessel", (x,-.45,3.6),(2.62,.67,5.28),panel,.19)
            box("Observation screen", (x,-.84,3.6),(1.8,.14,3.25),secondary,.11)
            for z in [2.32,3.42,4.52]:
                box("Culture trace", (x,-.93,z), (1.32,.07,.09),glow)
    box("Room light", (0,-.86,7.15),(2.35,.11,.12),glow)
    if motif in ("roots","ice","rift","scrap"):
        for i in range(5):
            x=(i-2)*1.12
            box("Angular strata seam", (x,-.78,2.30+i*.69),(.46,.27,1.25),secondary if i%2 else panel,.14,x*.28)
    else:
        faceplate(box,dark,panel,secondary,glow,-1.65,-.99,1.36,1.33,.62)
        faceplate(box,dark,panel,secondary,glow,1.65,-.99,6.45,1.33,.62)

def decking(panel, secondary, glow, motif):
    box("Structural floor", (0,0,-.43),(5.99,4.8,.81),panel,.065)
    for i,x in enumerate([-2,0,2]):
        box("Tread tile", (x,0,-.043),(1.96,4.72,.076),secondary,.028)
        box("Recessed fascia", (x,-2.414,-.41),(1.63,.11,.32),dark)
        for dx in [-.44,0,.44]:
            box("Deck markers", (x+dx,-2.478,-.41),(.26,.051,.08),glow,.02,.18 if motif in ("scrap","hangar") else 0)
    box("Keel", (0,-2.418,-.70), (5.95,.08,.14),secondary)
    machined_deck(box,dark,panel,secondary,glow,motif)

def shaft(panel, secondary, glow):
    box("Climb wall", (0,0,0),(.79,4.25,4.0),panel,.048)
    for z in [-1.60,-.51,.53,1.56]:
        box("Grip plate", (0,-2.14,z),(.77,.14,.82),secondary,.053)
        box("Grip lamp", (0,-2.23,z),(.42,.063,.07),glow,.018)
        for x in [-.28,.28]:
            box("Socket bolt", (x,-2.239,z+.19),(.074,.05,.066),dark,.014)
        box("Ribbed climbing insert", (0,-2.235,z-.19),(.51,.045,.095),panel,.016)

def jungle_mouth(panel, secondary, glow):
    """Passable root-and-rock lintel with irregular stone sides."""
    rng = random.Random(712)
    for side in (-1,1):
        for tier in range(5):
            x = side * (2.55 - .09*tier)
            z = .43 + 1.01*tier
            box("Grounded root column", (x,.18,z),(1.17,1.9,1.30),panel if tier%2 else secondary,
                .24,side*.14+rng.uniform(-.17,.17))
            if tier%2==1:
                box("Bioluminescent seam", (x,-.86,z),(.44,.18,.09),glow,.035,side*.26)
        box("Cave shoulder", (side*1.72,.36,5.15),(1.85,2.45,1.28),secondary,.28,side*.36)
    for i in range(4):
        x = (i-1.5)*1.13
        box("Binding crown rock", (x,.57,5.65+rng.uniform(-.2,.2)),(1.43,2.61,1.41),
            panel if i%3 else secondary,.29,rng.uniform(-.30,.30))
        if i%2==0:
            box("Hanging root tip", (x,-.72,4.80),(.22,.40,.83),secondary,.08,.22)


def jungle_bank(panel, secondary):
    rng = random.Random(783)
    box("Continuous earth core", (0,.05,-1.34),(5.94,3.85,1.47),panel,.19)
    for i in range(7):
        x = (i-3)*.82
        z = -1.55 - rng.uniform(-.04,.18)
        box("Exposed root and bedrock", (x,-1.73,z),(.88,1.11,rng.uniform(1.20,1.9)),
            secondary if i%3==0 else panel,.22,rng.uniform(-.36,.36))
        if i%2:
            box("Hanging roots", (x,-1.8,-2.77),(.18,.32,rng.uniform(1.05,1.70)),dark,.07,x*.11)
    for i in range(5):
        x = (i-2)*1.20
        box("Moss edge", (x,-1.89,-.64),(1.11,.38,.25),secondary,.082,rng.uniform(-.14,.14))


for sector, rgb, accent, motif in SECTORS:
    ROOT = CAMPAIGN / sector / "interior"
    ROOT.mkdir(exist_ok=True)
    panel = material(sector+" panels",rgb,.35)
    secondary = material(sector+" trim",tuple(min(1,v*1.25+.07) for v in rgb), .48)
    glow = material(sector+" accents",accent,.12,1.65)
    grain = .14 if motif in ("roots","ice","rift") else .34
    wear = .70 if motif in ("archive","scrap","rift","roots") else .41
    textured_alloy(panel,grain,wear,sector)
    textured_alloy(secondary,grain*.8,wear*.77,sector + " trim")
    for name, build in [("deck",lambda: decking(panel,secondary,glow,motif)),
                        ("wall",lambda: shaft(panel,secondary,glow)),
                        ("room",lambda: room(motif,panel,secondary,glow)),
                        ("fixture",lambda: sector_feature(box,tube,dark,panel,secondary,glow,motif))]:
        bake(sector+"_"+name,build)
    if motif == "roots":
        bake("jungle_cave_mouth",lambda: jungle_mouth(panel,secondary,glow))
        bake("jungle_root_bank",lambda: jungle_bank(panel,secondary))
ROOT = CAMPAIGN
bpy.context.preferences.filepaths.save_version = 0
for i, collection in enumerate(c for c in bpy.data.collections if c.name.endswith(" source")):
    collection.hide_viewport = False
    collection.hide_render = False
    for obj in collection.objects:
        obj.location.x += (i%9)*9
        obj.location.y += (i//9)*10
bpy.ops.wm.save_as_mainfile(filepath=str(CAMPAIGN / "campaign_interiors.blend"))
