"""Build beveled, textured enemy kits for each sector and shared patrols.

Run Blender in background mode with --python and pass the Godot project root.
Meshes are combined by material and articulated group for inexpensive updates.
"""
import json
import math
from pathlib import Path
import sys

import bpy

root = Path(sys.argv[-1]).resolve()
source = root / "assets/enemies/build_security_redesign.py"
support = source.read_text(encoding="utf-8-sig").split("for name,build in [('scout',sentinel)")[0]
exec(compile(support, str(source), "exec"))
catalog = json.loads((root / "assets/campaign/sector_plan.json").read_text(encoding="utf-8"))
output = root / "assets/enemies/detachments"
output.mkdir(exist_ok=True)

palette = [
    (1.0, .31, .06), (.32, .93, .17), (.12, .74, 1.0), (.08, 1.0, .86),
    (.87, .48, .10), (.19, .44, 1.0), (.99, .12, .46), (.62, .24, 1.0),
    (1.0, .29, .09), (1.0, .11, .58),
]
silhouettes = [sentinel, crawler, bulwark, emplacement, interceptor]
roles = [0, 2, 3, 4]
signals = [mat("Sector optic %d" % (i + 1), value, emission=2.2) for i, value in enumerate(palette)]
shared_signal = mat("Security network optic", (.20, .83, .96), emission=1.7)

def shape_details(sector, role, glow):
    """Sector hardware is visible in silhouette from the side-scrolling camera."""
    y = [.28, .20, .35, .19, .03][role]
    z = [.31, .41, .38, .42, .37][role]
    for side in (-1, 1):
        x = side * (.46 if role in (2, 4) else .34)
        if sector == 1:
            rod("Hydraulic stanchion", (x, y-.20, -.24), (x, y+.21, .09), .071, steel)
            for i in range(3):
                plate("Warning gate", (x*1.1, y+.18-i*.075, z+.025), (.14,.045,.043), hazard, .008, side*.22)
        elif sector == 2:
            for i in range(3):
                panel("Root-carapace leaf", (x+side*i*.042,y-.05+i*.06,-.16), .26,.43,.16, blue, side*(.45+i*.13))
                rod("Luminous sap channel", (x,y-.14,-.08), (x+side*i*.095,y+.2+i*.05,.04), .014, glow)
        elif sector == 3:
            for i in range(2):
                cyl("Insulated cryogenic cartridge", (x+side*i*.1,y+.04,-.20), .062,.49, white,(0,1,0),verts=16)
                ring("Coolant collar", (x+side*i*.1,y+.23,-.20), .069,.011,glow,(0,1,0))
        elif sector == 4:
            cyl("Water intake collar", (x,y,-.32), .17,.31, steel, (0,0,1),verts=24)
            ring("Pressure seal", (x,y,-.48),.142,.018,glow)
            for i in range(4):
                plate("Impeller shutter", (x,y-.08+i*.053,-.487),(.205,.016,.026),black,.004)
        elif sector == 5:
            for i in range(3):
                panel("Archive memory plate",(x,y+.19+i*.065,-.2-i*.029),.21,.12,.43,blue,side*.12,plane="xz")
                plate("Memory terminal contacts",(x,y+.21+i*.065,.02-i*.029),(.13,.023,.036),glow,.005)
        elif sector == 6:
            panel("Swept aviation fin",(x+side*.17,y+.2,-.14),.32,.51,.11,blue,side*.54)
            panel("Leading edge",(x+side*.21,y+.33,-.12),.22,.24,.09,white,side*.55)
            rod("Navigation light", (x+side*.16,y+.10,-.09), (x+side*.24,y+.33,-.06),.022,glow)
        elif sector == 7:
            cyl("Sterile culture reservoir",(x,y,-.25),.09,.43,glow,(0,1,0),verts=20)
            for j in (-1,1):
                cyl("Culture pressure cap",(x,y+j*.20,-.25),.104,.103,blue,(0,1,0),verts=16)
            for j in (-1,1):
                rod("Reservoir cage",(x+j*.093,y-.17,-.25),(x+j*.093,y+.17,-.25),.014,steel)
        elif sector == 8:
            ring("Orbital relay coil",(x,y+.20,-.19),.164,.031,white,(side*.35,0,1))
            ring("Induction inner ring",(x,y+.20,-.16),.121,.017,glow,(side*.35,0,1))
        elif sector == 9:
            for i in range(3):
                panel("Salvaged armor patch",(x+side*.05*i,y-.11+i*.13,.11),.24,.21,.16,white if i%2 else hazard,side*(.08+i*.19))
            cyl("Magnetic grabber",(x*1.24,y-.19,.16),.115,.18,steel,(0,0,1),verts=14)
        elif sector == 10:
            for i in range(3):
                panel("Rift field blade",(x+side*.10*i,y+.03+i*.16,-.20),.17,.41,.08,blue,side*.31)
                rod("Rift filament",(x+side*.10*i,y+.03+i*.16,-.142),(x+side*(.08+.10*i),y+.2+i*.16,-.103),.018,glow)
        else:
            ring("Patrol halo",(x,y+.24,-.10),.092,.018,glow)
            for i in range(4):
                plate("Patrol cooling vent",(x,y-.13+i*.060,z),(.14,.023,.046),steel,.005)
        for i in range(3):
            cyl("Inset chassis bolt",(x+side*.04,y-.12+i*.094,z-.025),.016,.022,steel,verts=8)
    plate("Emitter inset",(0,y,z+.14),(.21,.071,.063),black,.017)
    for i in range(3):
        plate("Emitter status segment",((i-1)*.054,y,z+.18),(.035,.028,.009),glow,.004)

def relay_drone():
    hull(.12,.63,.42,.66,shared_signal,True)
    for side in (-1,1):
        x=side*.42
        plate("Sensor wing housing",(x,.13,-.09),(.34,.11,.51),blue,.047,side*.28)
        cyl("Vector exhaust",(x,-.06,-.24),.118,.25,steel,(0,0,1),verts=20)
        ring("Wake ionizer",(x,-.06,-.38),.092,.016,shared_signal)
    cyl("Downlink receiver",(0,.34,-.11),.16,.15,black,(0,1,0),verts=20)
    ring("Detection dish",(0,.44,-.11),.20,.029,white,(0,1,0))
    sphere_strip = ((-.13,.42,-.17), (0,.54,-.12), (.13,.42,-.17))
    for point in (sphere_strip[0], sphere_strip[-1]):
        rod("Dish support",point,sphere_strip[1],.013,steel)

def export_vehicle(filename):
    group=bpy.data.objects.new(filename.stem,None)
    bpy.context.collection.objects.link(group)
    collect(parts,group)
    for index,(at,geometry) in enumerate(gaits):
        pivot=bpy.data.objects.new(f"Gait_{index}",None)
        bpy.context.collection.objects.link(pivot)
        pivot.parent=group
        pivot.location=v(at)
        collect(geometry,pivot)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(filename),export_format="GLB",use_selection=True,
                             export_image_format="JPEG",export_jpeg_quality=91)
    for obj in list(group.children_recursive)+[group]:
        bpy.data.objects.remove(obj,do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if not mesh.users:
            bpy.data.meshes.remove(mesh)

def use_atlas(image):
    for material in [white,blue,steel,hazard]:
        for node in material[0].node_tree.nodes:
            if node.type == "TEX_IMAGE":
                node.image = image

def bake(name, sector, role, model, glow):
    parts.clear()
    gaits.clear()
    model()
    shape_details(sector, role, glow)
    export_vehicle(output / (name + ".glb"))

for i,(role,model) in enumerate(enumerate(silhouettes)):
    bake("patrol_%d" % i, 0, role, model, shared_signal)
bake("patrol_5",0,4,relay_drone,shared_signal)

for info in catalog:
    sector = info["number"]
    folder = root / "assets/campaign" / info["id"]
    texture = folder / "trim.png"
    use_atlas(bpy.data.images.load(str(texture), check_existing=True) if texture.is_file() else atlas)
    for role in roles:
        bake("sector_%02d_%d" % (sector,role),sector,role,silhouettes[role],signals[sector-1])
