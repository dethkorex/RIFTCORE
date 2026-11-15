"""Export Ember Foundry terrain and mechanical enemies from Blender."""
import math
import sys
from pathlib import Path

import bpy

project = Path(__file__).resolve().parents[3]
terrain_source = Path(__file__).with_name("build_kit.py")
scope = {"__file__": str(terrain_source)}
exec(compile(terrain_source.read_text().split('for name, builder in [("deck", floor)')[0], str(terrain_source), "exec"), scope)
material, box, bake = (scope[key] for key in ("material", "box", "bake"))
alloy = scope["textured_alloy"]
output = project / "assets/neon_factory/foundry"
output.mkdir(exist_ok=True)
scope["ROOT"] = output
for key, name, tint, seed in [
    ("steel", "Heat-treated steel", (.105, .072, .061), 22),
    ("edge", "Burnished nickel", (.29, .185, .126), 34),
    ("dark", "Cast iron", (.047, .032, .027), 65),
    ("rock", "Volcanic basalt", (.09, .055, .051), 70),
]:
    scope[key] = material(name, tint, .55 if key != "rock" else .12)
    alloy(scope[key], .26, .55, seed)
scope["cyan"] = material("Molten amber", (1, .27, .04), .12, 2.4)
scope["amber"] = material("Firebrick indicator", (1, .075, .012), .1, 1.85)
scope["gold"] = material("Safety enamel", (.92, .46, .077), .24)

def nozzle():
    for height, radius, depth, surface in [
        (.035, .65, .15, "dark"), (.105, .56, .11, "edge"),
        (.149, .43, .05, "steel"), (.165, .33, .04, "amber"),
        (.187, .248, .034, "dark"),
    ]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth, location=(0, 0, height))
        bpy.context.object.data.materials.append(scope[surface])
    for i in range(6):
        angle = math.tau * i / 6
        x, y = math.cos(angle), math.sin(angle)
        box("Nozzle retaining bolt", (.50*x, .50*y, .18), (.095, .095, .09), scope["edge"], .016)
        box("Refractory tooth", (.31*x, .31*y, .218), (.071, .071, .10), scope["steel"], .024)
    for side in (-1, 1):
        box("Safety block", (.60*side, 0, .117), (.15, .45, .19), scope["edge"], .036)
        for y in (-.13, .0, .13):
            box("Safety stripe", (.60*side, y, .22), (.10, .035, .018), scope["gold"], .006)

def basalt_wall():
    box("Continuous basalt shell", (0, .30, 3.99), (6.04, .56, 8.03), scope["rock"], .06)
    # Broad, inclined fault faces keep the wall solid across kit seams.
    for i, (x,z,w,h,tilt) in enumerate([
        (-2.0,1.50,2.2,3.47,.14),(.02,1.58,2.65,3.85,-.25),(2.14,1.09,1.93,2.90,.10),
        (-2.37,3.8,1.62,2.8,-.22),(-.9,4.1,2.47,3.55,.37),(1.47,4.03,2.71,3.8,.19),
        (-2.0,6.56,2.27,3.0,.22),(.38,6.89,2.88,2.79,-.19),(2.43,6.28,1.77,3.92,.35),
    ]):
        facet = box("Split basalt face", (x,-.21-(i%3)*.11,z),(w,.78,h),scope["rock"],.34,tilt)
        facet.rotation_euler.z = .31 * ((i%3)-1)
    for x,z,tilt in [(-1.6,2.6,.84),(1.68,4.9,-.62),(-.18,6.76,.88)]:
        box("Mineral inclusion", (x,-.74,z), (1.15,.12,.22), scope["edge"], .05,tilt)

def threshold():
    box("Station changeover lintel", (0,0,5.65), (1.88,5.27,1.46), scope["steel"], .15)
    box("Rear jamb", (0,1.69,2.87), (1.81,1.04,5.88), scope["steel"], .14)
    box("Back wall return", (0,2.67,2.15), (2.23,.91,5.85), scope["dark"], .15)
    box("Front lintel guard", (0,-2.52,5.64), (1.93,.23,1.0), scope["edge"], .07)
    for x in (-.84,.84):
        box("Jamb trim", (x,1.05,2.80), (.15,.19,5.56), scope["edge"], .035)
        box("Jamb warm light", (x,.95,2.90), (.055,.12,3.40), scope["cyan"], .018)
    for y in (-1.75,-.69,.39,1.47):
        box("Ceiling inset", (0,y,4.94), (1.10,.30,.059), scope["edge"], .019)
    for z in (1.1,1.45,1.8):
        box("Frame heatsink", (0,1.07,z), (1.21,.16,.105), scope["dark"], .03)

for name, builder in [
    ("deck", "floor"), ("bulkhead", "lining"),
    ("shaft_wall", "column"), ("transfer_bridge", "bridge"),
    ("salvage_chest", "cache"), ("pressure_bank", "pressure_bank"),
]:
    bake(name, scope[builder])
bake("flame_nozzle", nozzle)
bake("bedrock", basalt_wall)
bake("zone_threshold", threshold)
for index, collection in enumerate(c for c in bpy.data.collections if c.name.endswith(" source")):
    collection.hide_viewport = False
    collection.hide_render = False
    for obj in collection.objects:
        obj.location.x += index * 8.5
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(output / "foundry_terrain.blend"))

# The existing kit provides chassis dimensions and named animation pivots.
sys.argv.append(str(project))
rig_source = project / "assets/enemies/build_security_redesign.py"
exec(compile(rig_source.read_text().split("for name,build in [('scout',sentinel)")[0], str(rig_source), "exec"))
for key, name, tint, seed in [
    ("white", "Firebrick ceramic", (.39, .105, .055), 111),
    ("blue", "Oxidized armor", (.116, .079, .069), 127),
    ("steel", "Nickel steel", (.36, .24, .16), 136),
]:
    globals()[key] = mat(name, tint)
    alloy(globals()[key][0], .3, .47, seed)
pink = mat("Burner optic", (1, .125, .015), None, 2.4)
edge = mat("Tungsten faceplate", (.38, .34, .29))
accent_brass = mat("Copper hardware", (.42, .15, .054))
hazard = mat("Foundry safety enamel", (.67, .32, .038))

def stack(at, radius, length):
    x, y, z = at
    cyl("Exhaust header", at, radius, length, black, (0, 1, 0), verts=16)
    for d in (-.42, .30, .50):
        ring("Reinforced exhaust collar", (x, y + d*length, z), radius, radius*.15, edge, (0, 1, 0))
    cyl("Hot exhaust interior", (x, y + length*.47, z), radius*.70, .025, amber, (0, 1, 0))

def trim_enemy(variant):
    if variant == 0:
        stack((-.27, .36, -.24), .092, .42)
        rod("External charge pipe", (-.27,.26,-.24), (-.42,.02,.23), .024, accent_brass)
    elif variant == 1:
        for x in (-.29, .29):
            stack((x, .26, -.29), .092, .26)
    elif variant == 2:
        for x in (-.37, .37):
            stack((x, .37, -.25), .105, .46)
            rod("Shoulder coolant return", (x,.35,-.24),(x,.13,.34),.037,accent_brass)
    elif variant == 3:
        stack((0, .37, -.26), .10, .32)
    else:
        for x in (-.35, .35):
            stack((x,.31,-.21),.068,.16)
    for x in (-.13, .13):
        plate("Enamel heat marker", (x,.15,.31), (.08,.034,.032), hazard, .008, -.31)

def pivot(name, at, parent):
    ob = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(ob)
    ob.parent = parent
    ob.location = v(at)
    return ob

def section(name, at, builder, parent):
    start = len(parts)
    builder()
    joint = pivot(name, at, parent)
    collect(parts[start:], joint)
    del parts[start:]
    return joint

def chassis(warden):
    if warden:
        panel("Kiln casing", (0,.18,0), 1.99,1.42,1.50,black)
        for x in (-.72,.72):
            stack((x, .87, -.36), .23, .89)
            panel("Kiln top refractory", (x,.65,.26),.79,.67,.44,white)
        cyl("Firebox housing",(0,.15,.79),.62,.31,edge,verts=14)
        cyl("Firebox mouth",(0,.15,.978),.48,.16,black,verts=14)
        cyl("Fire bed",(0,.15,1.018),.38,.07,hot,verts=14)
        for y in (-.087,.06,.21,.36):
            plate("Kiln grate", (0,y,1.09),(.74,.043,.084),edge)
    else:
        panel("Forged chest",(0,.33,.0),2.22,1.48,1.29,black)
        panel("Cervical armor",(0,1.14,.16),.73,.65,.73,edge)
        optic((0,1.14,.53),.43,.13,amber)
        for x in (-.82,.82):
            stack((x,.87,-.37),.22,.80)
            panel("Layered refractory pauldron",(x,.74,.32),.83,.52,.90,white)
            panel("Shoulder gusset",(x,.45,.57),.68,.34,.22,edge)
        cyl("Armored furnace bearing",(0,.32,.65),.62,.31,edge,verts=20)
        cyl("Furnace recess",(0,.32,.84),.49,.13,black,verts=20)
        ring("Copper current collector",(0,.32,.95),.368,.054,accent_brass)
        cyl("Core window",(0,.32,.95),.308,.12,hot,verts=16)
        for i in range(10):
            a = math.tau*i/10
            plate("Reactor perimeter latch",(.50*math.cos(a),.32+.50*math.sin(a),.94),(.12,.14,.135),white,.025,a)

def boss_leg(x, z, warden):
    y = -.32
    rod("Servo radius rod",(x,y,z),(x*1.25,-1.12,z+.10),.13,steel)
    cyl("Travel bearing",(x,-.73,z+.1),.24,.25,accent_brass,(1,0,0),verts=12)
    panel("Load-bearing shin",(x*1.16,-.99,z+.10),.61,.61,.54,white)
    plate("Steel tread",(x*1.19,-1.34,z+.20),(.64,.19,.69),black,.08)
    for i in range(4):
        plate("Cleat",(x*1.19,-1.39,z+.45-i*.17),(.65,.09,.09),edge,.022)

def drill_housing():
    x,y,z = -.99,.28,.15
    cyl("Drill sleeve",(x,y,z+.35),.40,.87,black,verts=16)
    for yoff in (-.28,.28):
        plate("Drill sideguard",(x,y+yoff,z+.38),(.66,.24,.67),white,.055)
    ring("Drive collar",(x,y,z+.82),.33,.065,amber)

def drill_cone():
    x,y,z = -.99,.28,.15
    cyl("Forged tapered auger",(x,y,z+1.34),.345,1.02,edge,r2=.045,verts=24)
    for i in range(54):
        t = i/55
        a = i*math.tau/17
        r = .34 - .27*t
        plate("Helical cutting edge",(x+math.cos(a)*r,y+math.sin(a)*r,z+.87+t*.96),(.155,.08,.105),black,.017, a)
        if i%2 == 0:
            plate("Heated helical flute",(x+math.cos(a)*r,y+math.sin(a)*r,z+.91+t*.96),(.127,.057,.10),amber,.014,a)

def gauntlet():
    panel("Pressure hammer",(1.12,-.16,.45),.82,.64,.85,white)
    for i in range(3):
        x = .88 + i*.23
        plate("Forge finger",(x,-.36,.75),(.19,.55,.29),edge,.05)
        plate("Hot knuckle",(x,-.51,.86),(.13,.14,.11),amber,.024)
    rod("Hammer return line",(1.31,-.17,0),(1.31,.43,0),.105,accent_brass)

def burner(x):
    barrel(x,.36,.58,.62,hot)
    ring("Heat baffle",(x,.36,.87),.235,.045,accent_brass)
    cyl("Burner burner bell",(x,.37,.71),.216,.27,white,verts=16)
    ring("Burner ignition ring",(x,.37,.902),.15,.029,amber)

def shutter(side):
    panel("Armored core door",(side*.21,.32,1.05),.46,.69,.16,white)
    for y in (.17,.33,.49):
        plate("Core door cooling rib",(side*.21,y,1.143),(.31,.065,.048),edge,.015)

def export(name, root_node, index):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(root_node.children_recursive) + [root_node]:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output / (name+".glb")), export_format="GLB",
        use_selection=True)
    root_node.location.x = index * 4.5

for index, (name, build) in enumerate([
    ("scorch_scout",sentinel), ("slag_crawler",crawler), ("crucible_guard",bulwark),
    ("flue_sentry",emplacement), ("ember_drone",interceptor),
]):
    parts.clear()
    gaits.clear()
    build()
    trim_enemy(index)
    rig = pivot(name, (0,0,0), None)
    collect(parts, rig)
    for gait_index, (at, geometry) in enumerate(gaits):
        collect(geometry, pivot(f"{name}_Gait_{gait_index}", at, rig))
    export(name,rig,index)

for index, (name, warden) in enumerate([("kiln_warden",True), ("forge_titan",False)], 5):
    parts.clear()
    rig = pivot(name,(0,0,0),None)
    chassis(warden)
    collect(parts,rig)
    parts.clear()
    for side, suffix in [(-1,"Left"),(1,"Right")]:
        x = .61 * side
        section(("WardenLeg" if warden else "TitanLeg")+suffix,(x,-.32,.02),lambda: boss_leg(x,.02,warden),rig)
        if warden:
            section("Rear"+suffix,(x,-.32,-.65),lambda: boss_leg(x,-.65,warden),rig)
            section("Burner"+suffix,(side*.89,.36,.33),lambda: burner(side*.89),rig)
        else:
            section("Shutter"+suffix,(side*.21,.32,1.05),lambda: shutter(side),rig)
    if not warden:
        drill_module = section("DrillModule",(-.99,.28,.15),drill_housing,rig)
        section("DrillRotor",(0,0,.82),drill_cone,drill_module)
        section("FistModule",(1.05,.44,.04),gauntlet,rig)
    export(name,rig,index)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(output / "foundry_robots.blend"))
