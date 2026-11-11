"""Build the Verdant Colossus GLB with articulated attack and locomotion pivots."""
from pathlib import Path
import sys
import bmesh

kit_source = Path(sys.argv[-1]) / "assets/machine_jungle/build_machine_jungle.py"
exec(compile(kit_source.read_text(encoding="utf-8").split("for build in [rootrunner, thorn_weaver")[0], str(kit_source), "exec"))

rig = bpy.data.objects.new("VerdantColossusRig", None)
bpy.context.collection.objects.link(rig)

def leaf_plate(name, center, width, height, material, angle=0):
    outline = [(-.50,-.20),(-.30,.34),(0,.56),(.34,.38),(.50,-.13),(.18,-.39),(0,-.56),(-.23,-.36)]
    verts = []
    for depth in [-.06,.075]:
        for x,y in outline:
            dx,dy=x*width,y*height
            verts.append(v((center[0]+dx*math.cos(angle)-dy*math.sin(angle),
                            center[1]+dx*math.sin(angle)+dy*math.cos(angle),center[2]+depth)))
    faces = [tuple(range(7,-1,-1)),tuple(range(8,16))]
    faces += [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project()
    bpy.ops.object.mode_set(mode="OBJECT")
    setup(ob,name,material,.018)
    ob.select_set(False)

def pack(name, at=(0, 0, 0)):
    pivot = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(pivot)
    pivot.parent = rig
    pivot.location = v(at)
    group_surfaces(parts, pivot)
    parts.clear()

guard("Reactor chassis", (0,2.25,0), (1.55,1.05,.86), black)
guard("Pelvis", (0,1.43,0), (1.21,.49,.67), blue)
spore_lens(0,2.23,.47,.39)
for side in (-1,1):
    guard("Angled chest carapace", (side*.53,2.48,.42), (.58,.51,.25), blue, side*.27)
    guard("Ceramic reactor clamp", (side*.41,2.08,.49), (.24,.39,.16), white, -side*.43)
    for i in range(3):
        link("Root winding", (side*(.2+i*.08),1.5,.36), (side*(.64+i*.08),2.4,.52), .037, root_mat)
    for i in range(4):
        cyl("Rib bolt", (side*(.47+i*.09),2.57,.55), .037,.035, brass)
    leaf_plate("Vented chest petal", (side*.49,2.53,.60), .65,.58,blue,-side*.32)
    for i in range(4):
        guard("Chest radiator slot", (side*(.35+i*.09),2.52,.70), (.041,.16,.025), black, -side*.26)
    leaf_plate("Hip carapace", (side*.65,1.46,.40),.58,.69,white,-side*.26)
    for i in range(3):
        guard("Pelvis service grate",(side*(.13+i*.11),1.56,.39),(.06,.13,.055),edge)
pack("Core")
guard("Helmet", (0,2.99,.14), (.75,.48,.6), black)
guard("Jade brow", (0,3.1,.43), (.62,.22,.18), blue)
for side in (-1,1):
    guard("Optic slit", (side*.17,2.99,.455), (.22,.048,.075), leaf, side*.22)
    link("Horn foundation", (side*.28,3.10,.13),(side*.50,3.38,.27), .136, blue)
    cyl("Curved ivory horn tip", (side*.54,3.49,.28), .085,.29, white, (side*.19,1,.14), r2=.006)
    guard("Mandible", (side*.22,2.84,.38), (.19,.27,.22), white, side*.26)
pack("Head", (0,2.94,.12))

for side, name in [(-1,"LegLeft"),(1,"LegRight")]:
    x = side*.59
    guard("Thigh housing", (x,1.17,0), (.61,.73,.69), black)
    guard("Thigh shell", (x,1.32,.34), (.59,.37,.24), blue, -side*.2)
    cyl("Knee motor", (x,.84,.32), .24,.25, brass)
    guard("Knee shield", (x,.78,.53), (.53,.36,.22), white)
    leaf_plate("Knee overlapping scale",(x,.83,.67),.52,.43,blue,side*.19)
    leaf_plate("Shin overlapping scale",(x,.48,.54),.54,.45,white,-side*.10)
    guard("Armored boot", (x,.22,.16), (.78,.43,1.01), black)
    guard("Boot shell", (x,.27,.52), (.66,.32,.48), blue)
    for i in (-1,0,1):
        guard("Ivory toe", (x+i*.21,.18,.72), (.18,.23,.25), white)
        link("Shin piston", (x+i*.18,.33,.37), (x+i*.18,.74,.45), .039, brass)
    pack(name, (x,1.43,0))

for side, name in [(-1,"SporeBank"),(1,"VineArm")]:
    x = side*1.17
    guard("Shoulder chassis", (x,2.54,0), (.92,.79,.90), black)
    guard("Ivory pauldron", (x,2.80,.25), (.94,.48,.68), white, side*.20)
    guard("Jade shoulder lip", (x+side*.32,2.58,.32), (.43,.52,.50), blue, side*.34)
    guard("Forearm body", (x+side*.21,1.79,.11), (.69,.80,.74), black)
    guard("Forearm scales", (x+side*.21,1.8,.47), (.62,.47,.24), blue)
    for i in range(3):
        leaf_plate("Layered shoulder petal", (x+side*(i-.9)*.25,2.70-i*.09,.64+i*.015),.48,.62,blue if i==2 else white,side*(.25+i*.13))
        cyl("Shoulder plate rivet",(x+side*(i-.9)*.25,2.78-i*.09,.75+i*.015),.032,.024,brass,verts=6)
    leaf_plate("Forearm petal", (x+side*.22,1.82,.64),.66,.68,white,side*.12)
    for i in range(3):
        guard("Arm ventilator", (x+side*.22,1.68+i*.1,.75),(.34,.031,.035),black)
    for i in range(3):
        link("Forearm hydraulic", (x+side*(.05+i*.15),1.8,.35),(x+side*(.05+i*.15),2.34,.39), .047, brass)
    if side < 0:
        for dx,dy in [(-.25,0),(.25,0),(0,.41)]:
            spore_lens(x+dx,2.86+dy,.62,.21)
        for i in range(3):
            cyl("Claw", (x+(i-1)*.16,1.26,.27), .085,.37,white,(0,-1,.48),r2=.009)
    else:
        points = [(x+.21,1.44,.19),(x+.55,1.22,.27),(x+.88,1.45,.35),(x+1.08,1.83,.39),(x+1.30,1.96,.42),(x+1.53,1.78,.44)]
        for a,b in zip(points,points[1:]):
            link("Vine spine", a,b,.11,root_mat)
            cyl("Vine joint", b,.16,.15,black,verts=9)
            guard("Overlapping vine scale", b,(.25,.23,.20),blue,.32)
        cyl("Venom lance", points[-1],.14,.48,acid,(.48,-1,.2),r2=.006)
    pack(name, (x,2.54,0))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.wm.save_as_mainfile(filepath=str(root.parent / "verdant-colossus.blend"))
bpy.ops.export_scene.gltf(filepath=str(kit / "enemies/verdant_colossus.glb"), export_format="GLB",
                         use_selection=True, export_image_format="JPEG", export_jpeg_quality=88)
