from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy

root = Path(sys.argv[-1])
kit = root / "assets/machine_jungle"
base = root / "assets/enemies/build_factory_armor.py"
shared = base.read_text(encoding="utf-8").split("for build in [scout,quad,heavy,turret,flyer]:")[0]
shared = shared.replace("assets/enemies/security_trim.png", "assets/machine_jungle/jungle_trim.png")
exec(compile(shared, str(base), "exec"))

leaf = mat("Jade power rail", (0.06, 0.98, 0.36), None, 1.65)
acid = mat("Toxic reactor", (0.59, 0.018, 1.0), None, 1.55)
acid_core = mat("Spore core", (0.92, 0.30, 1.0), None, 2.1)
brass = mat("Weathered brass", (0.31, 0.21, 0.06))
root_mat = mat("Polymer bark", (0.05, 0.09, 0.035))
poison = mat("Containment trim", (0.35, 0.09, 0.25), 3)


def link(name, a, b, radius, material, segments=9):
    center = tuple((x + y) * .5 for x, y in zip(a, b))
    direction = tuple(y - x for x, y in zip(a, b))
    return cyl(name, center, radius, math.sqrt(sum(n*n for n in direction)), material, direction, verts=segments)


def guard(n, p, d, color=blue, tilt=0):
    return plate(n, p, d, color, .049, tilt)


def spore_lens(x, y, z, radius, tone=acid):
    cyl("Ceramic reactor collar", (x,y,z), radius * 1.20, .084, white, verts=8)
    cyl("Seal rim", (x,y,z+.048), radius, .034, black, verts=10)
    cyl("Spore lens", (x,y,z+.072), radius*.75, .041, tone, r2=radius*.57, verts=12)
    cyl("Spore nucleus", (x,y,z+.095), radius*.35, .012, acid_core if tone == acid else leaf, verts=10)


def rootrunner():
    guard("Rootrunner torso", (0,.046,0), (.52,.43,.43), black)
    guard("Bioceramic chest yoke", (0,.105,.224), (.43,.25,.14), white)
    guard("Emerald cuirass", (0,.025,.257), (.38,.12,.104))
    optic((0,.068,.299), .22,.056,leaf)
    guard("Spine armor", (0,-.13,.025), (.36,.19,.35))
    guard("Hood shell", (0,.406,.018), (.51,.30,.43), blue)
    guard("Ceramic helm guard", (0,.542,.044), (.45,.15,.40), white)
    guard("Black face gasket", (0,.426,.216), (.40,.132,.083), black)
    for s in (-1,1):
        optic((s*.095,.432,.27), .15,.051,leaf)
        guard("Hood cheek", (s*.20,.351,.209), (.111,.17,.094), white, s*.32)
        joint((s*.39,.179,0),.077)
        guard("Leaf pauldron", (s*.405,.195,.015), (.245,.18,.28), blue,s*.35)
        guard("Forearm armor", (s*.416,-.034,.069), (.16,.22,.21), white,s*.12)
        limb(s*.18,.018,-.28,-.54,s*.11,leaf)
    for i in range(3):
        link("Vine blade tine", (-.418+(i-1)*.048,-.09,.15),(-.418+(i-1)*.071,.035,.49),.034,steel)
    guard("Vine power strip", (-.417,-.008,.266), (.085,.032,.195), leaf)
    for y in [-.02,.025,.07]:
        guard("Torso vent", (.224,y,.078), (.022,.019,.17), steel)


def thorn_weaver():
    guard("Weaver abdomen", (0,.19,-.079), (.76,.45,.80), root_mat)
    for i in range(4):
        guard("Segmented seed shell", (0,.35,-.30+i*.16), (.66-.036*i,.17,.20), blue)
    guard("Head clasp", (0,.173,.329), (.51,.30,.27), white)
    spore_lens(0,.178,.464,.129)
    for s in (-1,1):
        for z in [-.235,.245]:
            joint((s*.355,.035,z),.092)
            link("Telescoping thorn femur",(s*.33,.035,z),(s*.48,-.17,z),.065,brass)
            limb(s*.485,z,-.28,-.54,s*.26,acid)
        cyl("Abdomen valve",(s*.344,.244,-.23),.073,.102,black,(s,0,0),verts=8)
        cyl("Abdomen valve light",(s*.4,.244,-.23),.036,.022,acid,(s,0,0))
    for n in [-.185,0,.185]:
        cyl("Seed barb",(n,.392,-.215),.055,.22,white,(0,1,-.38),r2=.0,verts=5)


def bark_bulwark():
    guard("Beetle chassis",(0,.18,.015),(1.03,.58,.69),black)
    guard("Ceramic central brow",(0,.482,.22),(.61,.23,.42),white)
    guard("Bark breastplate",(0,.177,.345),(.65,.43,.23),blue)
    spore_lens(0,.178,.46,.19,leaf)
    for s in (-1,1):
        joint((s*.49,.175,.035),.12)
        for i in range(3):
            guard("Layered bark shield",(s*(.505+i*.018),.456-i*.132,.18+i*.055),(.28,.2,.48),blue if i!=1 else white,s*.17)
        guard("Shield marking",(s*.58,.248,.426),(.147,.10,.022),poison,s*.27)
        guard("Arm shield",(s*.54,-.041,.08),(.225,.27,.44),root_mat,s*.13)
        limb(s*.305,.018,-.245,-.54,s*.13,leaf)
    for x in [-.2,-.10,0,.10,.2]:
        guard("Cooling rib",(x,-.09,.442),(.055,.032,.051),steel)


def spore_sentry():
    cyl("Seed anchor plinth",(0,-.44,0),.48,.27,blue,(0,1,0),r2=.39,verts=8)
    cyl("Root collar",(0,-.292,0),.29,.13,steel,(0,1,0),verts=12)
    guard("Turret cradle",(0,-.15,.02),(.49,.31,.53),root_mat)
    guard("Canister crown",(0,.267,.017),(.81,.29,.66),white)
    guard("Main stem shield",(0,.15,.079),(.56,.42,.51),blue)
    for angle in [-1.1,0,1.1]:
        x=math.sin(angle)*.245
        y=.12+math.cos(angle)*.135
        cyl("Spore barrel jacket",(x,y,.322),.109,.29,steel,verts=10)
        spore_lens(x,y,.482,.072,acid)
    for s in (-1,1):
        link("Root anchor brace",(s*.17,-.23,.055),(s*.48,-.50,.16),.068,root_mat,7)
        guard("Anchor warning rib",(s*.27,-.435,.407),(.13,.067,.03),poison)


def canopy_wasp():
    guard("Hover hull",(0,.035,0),(.56,.45,.73),blue)
    guard("Crown plate",(0,.245,.047),(.44,.12,.65),white)
    optic((0,.099,.36),.34,.075,leaf)
    spore_lens(0,-.07,.385,.119)
    for s in (-1,1):
        guard("Swept leaf vane",(s*.414,.145,-.055),(.47,.072,.59),blue,s*.21)
        guard("Machined leading edge",(s*.464,.162,.21),(.33,.055,.073),white,s*.12)
        guard("Biolume vane edge",(s*.488,.124,.240),(.29,.026,.041),acid,s*.14)
        cyl("Hover turbine",(s*.31,-.092,-.104),.123,.111,black,(0,1,0))
        cyl("Hover turbine core",(s*.31,-.154,-.104),.083,.021,acid,(0,1,0))
    cyl("Stinger tail",(0,-.074,-.485),.137,.30,steel,(0,-.18,-1),r2=.004,verts=9)
    cyl("Poison stinger filament",(0,-.085,-.51),.104,.175,acid,(0,-.18,-1),r2=.006,verts=8)


def group_surfaces(objects, pivot):
    by_material = {}
    for ob in objects:
        by_material.setdefault(ob.data.materials[0].name, []).append(ob)
    bpy.context.view_layer.update()
    for name, objects in by_material.items():
        bpy.ops.object.select_all(action="DESELECT")
        for ob in objects:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        ob = bpy.context.object
        ob.name = name
        ob.parent = pivot
        ob.matrix_parent_inverse = pivot.matrix_world.inverted()


for build in [rootrunner, thorn_weaver, bark_bulwark, spore_sentry, canopy_wasp]:
    parts.clear()
    gaits.clear()
    build()
    group = bpy.data.objects.new(build.__name__.title(), None)
    bpy.context.collection.objects.link(group)
    group_surfaces(parts, group)
    for index, (at, geometry) in enumerate(gaits):
        pivot = bpy.data.objects.new(f"Gait_{index}", None)
        bpy.context.collection.objects.link(pivot)
        pivot.parent = group
        pivot.location = v(at)
        group_surfaces(geometry, pivot)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(kit / "enemies" / f"{build.__name__}.glb"), export_format="GLB",
                             use_selection=True, export_image_format="JPEG", export_jpeg_quality=85)
    for ob in list(group.children_recursive) + [group]:
        bpy.data.objects.remove(ob, do_unlink=True)
