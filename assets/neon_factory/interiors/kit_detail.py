"""Shared modeling and surface details for the modular sector kits."""
from math import cos, pi, sin
import random
import bpy


def textured_alloy(material, grain, wear, seed):
    """Build a tileable alloy finish with color and roughness baked into the GLB."""
    size = 128
    randomizer = random.Random(seed)
    shader = material.node_tree.nodes.get("Principled BSDF")
    base = list(shader.inputs["Base Color"].default_value[:3])
    roughness = shader.inputs["Roughness"].default_value
    chips = [(randomizer.randrange(size), randomizer.randrange(size),
              randomizer.randint(2, 11), randomizer.uniform(.11, .33))
             for _ in range(72)]
    texture = [0.0] * (size * size)
    for x, y, length, amount in chips:
        for step in range(length):
            texture[((y + (step // 7)) % size) * size + (x + step) % size] += amount * (1 - step / length)
    color_pixels, rough_pixels = [], []
    for y in range(size):
        for x in range(size):
            u, v = 2*pi*x/size, 2*pi*y/size
            grain_signal = sin(31*v+sin(3*u))*0.19 + sin(51*v+sin(2*u))*0.12
            hammered = sin(5*u+sin(8*v))*sin(4*v+sin(7*u))
            mottling = .49*sin(2*u)*cos(3*v)+.28*cos(7*u+v)*sin(4*v)
            score = grain * grain_signal + wear * (hammered*.14+mottling*.18)
            scratch = texture[y * size + x] * wear
            abrasion = randomizer.uniform(-.018, .018)
            color_pixels.extend([max(0, min(1, value*(1+score+abrasion)+scratch*.28)) for value in base]+[1.0])
            rough_pixels.extend([max(.12, min(.91, roughness + score*.2 + scratch*.45))]*3+[1.0])
    for label, pixels in [("albedo", color_pixels), ("roughness", rough_pixels)]:
        image = bpy.data.images.new(f"{material.name} • {label}", width=size, height=size, alpha=False)
        if label == "roughness":
            image.colorspace_settings.name = "Non-Color"
        image.pixels.foreach_set(pixels)
        image.pack()
        node = material.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        material.node_tree.links.new(node.outputs["Color"], shader.inputs["Base Color" if label == "albedo" else "Roughness"])


def machined_deck(box, dark, panel, trim, glow, motif):
    for tile in [-2, 0, 2]:
        box("Keel inset", (tile,-2.456,-.61),(1.82,.086,.11),dark,.023)
        for ix in range(5):
            x = tile + (ix-2)*.20
            if motif in ("pressure","ice","lab"):
                box("Heat exchanger fins", (x,-2.512,-.44),(.07,.07,.19),trim,.011,-.20)
            elif motif in ("roots","rift"):
                box("Inlaid crystal ribs", (x,-2.51,-.42),(.11,.07,.16),trim if ix%2 else glow,.02,.32)
            else:
                box("Machined vent louvres", (x,-2.512,-.44),(.12,.075,.14),trim,.016,.26)
        for shoulder in [-.82,.82]:
            x = tile+shoulder
            box("Corner armor cleat", (x,-2.446,-.26),(.17,.19,.32),panel,.032)
            box("Recessed bolt head", (x,-2.551,-.25),(.057,.035,.064),trim,.009,.22)
        for y in [-1.92,1.92]:
            for ix in [-1,0,1]:
                x = tile + ix*.34
                box("Non-slip traction strips", (x,y,-.012),(.22,.26,.019),panel,.015,.00)
    for x in [-2.83,2.83]:
        box("Deck end marker", (x,-2.513,-.155),(.22,.072,.051),glow,.015)
    box("Box section underframe", (0,-2.32,-.778),(5.88,.235,.104),panel,.035)


def faceplate(box, dark, panel, trim, glow, x, y, z, width, height):
    box("Flush access panel", (x,y,z), (width,.14,height),dark,.074)
    box("Machined cover", (x,y-.084,z), (width-.12,.078,height-.12),panel,.061)
    for offset in [-1,1]:
        box("Recessed fasteners", (x+offset*(width*.5-.16),y-.136,z+height*.25),(.079,.032,.081),trim,.012,.24)
    box("Access panel light", (x,y-.144,z-height*.33),(width*.32,.034,.043),glow,.012)


def sector_feature(box, tube, dark, panel, trim, glow, motif):
    """Model a dedicated powered fixture for each biome at the wall plane."""
    box("Isolated mounting frame", (0,.12,1.46),(3.13,.32,2.92),dark,.15)
    for x in [-1.40,1.40]:
        box("Shock mounts", (x,-.10,1.43),(.33,.40,2.74),trim,.073)
        for z in [.39,2.48]:
            box("Retention lock", (x,-.34,z),(.23,.11,.19),panel,.042)
    if motif in ("roots","rift"):
        for i in range(7):
            x=(i-3)*.36
            box("Organic mineral growth", (x,-.35,.95+abs(x)*.26),(.43,.44,1.3+(i%3)*.42),
                trim if i%3 else panel,.13,x*.37)
            box("Charged filament", (x,-.61,1.18),(.12,.14,.90+(i%3)*.42),glow,.04,x*.37)
    elif motif in ("pressure","ice","lab","factory"):
        for i in range(3):
            z=.64+.77*i
            tube("Process cylinder", (0,-.42,z),.265,2.66,panel)
            for x in [-1.07,1.07]:
                tube("Compression collar", (x,-.42,z),.34,.18,trim)
            tube("Active pressure window", (0,-.42,z),.274,.75,glow)
    else:
        for i in range(3):
            x=(i-1)*.83
            faceplate(box,dark,panel,trim,glow,x,-.40,1.39,.76,2.13)
            for j in range(3):
                box("Cassette grille", (x,-.585,.91+j*.23),(.58,.12,.102),trim,.022)

    if motif == "roots":
        for x in [-.91,.90]:
            box("Spore pod housing", (x,-.37,2.27),(.63,.45,.74),panel,.19,x*.28)
            box("Spore pod core", (x,-.58,2.33),(.30,.14,.44),glow,.09,x*.28)
    elif motif == "rift":
        box("Rift containment spine", (0,-.63,1.48),(.31,.28,2.73),dark,.073,.38)
        for i in range(5):
            box("Rift charge contact", ((i-2)*.17,-.80,.76+i*.38),(.25,.13,.16),glow,.043,-.25)
    elif motif == "ice":
        for i in range(6):
            x=(i-2.5)*.42
            box("Frost shroud", (x,-.61,2.61),(.26,.32,.82-(i%3)*.18),trim,.10,(i-2.5)*.14)
    elif motif == "pressure":
        for x in [-.78,.78]:
            tube("Pressure gauge housing", (x,-.72,2.35),.22,.45,trim)
            box("Gauge display", (x,-.95,2.34),(.23,.052,.083),glow,.017)
    elif motif == "lab":
        for x in [-.68,.68]:
            box("Culture sample cassette", (x,-.80,1.05),(.38,.32,1.30),dark,.075)
            box("Culture window", (x,-.976,1.06),(.19,.041,.80),glow,.039)
    elif motif == "archive":
        for z in [.61,1.44,2.25]:
            box("Optical data tray", (0,-.65,z),(2.08,.17,.20),dark,.04)
            box("Reader trace", (.21,-.746,z),(.54,.047,.041),glow,.011)
    elif motif in ("hangar","array"):
        for i in range(5):
            x = (i-2)*.39
            box("Navigation panel" if motif=="hangar" else "Photovoltaic fin",
                (x,-.61,2.08-abs(i-2)*.13),(.24,.29,1.16),panel,.045,-.29 if motif=="hangar" else .28)
    elif motif == "scrap":
        for x in [-.95,.95]:
            box("Sorter gripper", (x,-.72,1.83),(.48,.43,1.44),trim,.11,x*.30)
    box("Lower frame lamp", (0,-.421,.24),(2.49,.062,.067),glow,.018)
