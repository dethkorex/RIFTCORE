"""Build the two Operations Hub standing platforms with Blender 4.4 in background mode."""
from math import cos, pi, sin, tau
from pathlib import Path

import bmesh
import bpy

OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "hub"
guides = []
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def finish(name, rgb, metal, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


iron = finish("Undercarriage", (.016, .023, .032), .42, .53)
paint = finish("Midnight ceramic", (.047, .080, .115), .46, .40)
alloy = finish("Armor steel", (.20, .27, .32), .68, .37)
trim = finish("Edge milling", (.43, .49, .52), .68, .32)
tread = finish("Non-slip deck", (.056, .072, .082), .14, .72)
brass = finish("Safety ochre", (.49, .25, .055), .38, .48)
emitter = finish("Light guides", (.10, .72, .89), .18, .26)


def block(name, outline, low, high, mat, bevel=0.006):
    n = len(outline)
    vertices = [(x, y, z) for z in (low, high) for x,y in outline]
    faces = [list(reversed(range(n))), list(range(n, 2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return solid(name, vertices, faces, mat, bevel)


def solid(name, vertices, faces, mat, bevel):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    if bevel:
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new("Milled edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.harden_normals = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if mat == emitter:
        guides.append(obj)
    return obj


def disc(radius, low, high, mat, sides=48):
    return block("Drum", [(radius*cos(i*tau/sides), radius*sin(i*tau/sides))
                          for i in range(sides)], low, high, mat)


def segment(start, stop, section, mat, divisions=6, bevel=.002):
    # The radial cross section describes actual lips, sloping plate and fascia.
    n = len(section)
    points = []
    for i in range(divisions+1):
        angle = start + (stop-start)*i/divisions
        points += [(r*cos(angle),r*sin(angle),h) for r,h in section]
    faces = [list(range(n)), list(reversed(range(divisions*n,(divisions+1)*n)))]
    for i in range(divisions):
        for j in range(n):
            a=i*n+j
            b=i*n+(j+1)%n
            faces.append((a,b,b+n,a+n))
    return solid("Radial casting", points, faces, mat, bevel)


def strip(a,b,r1,r2,z,mat,divisions=6):
    segment(a,b,[(r1,z-.009),(r2,z-.009),(r2,z),(r1,z)],mat,divisions)


def fastener(x,y,z):
    for radius,height,mat in [(0.039,.010,iron),(.026,.015,trim)]:
        block("Captive bolt", [(x+radius*cos(i*pi/3),y+radius*sin(i*pi/3)) for i in range(6)],
              z-.005,z+height,mat,.001)


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    objects[0].name=name
    return objects[0]


def platform(deploy):
    outer = 1.64 if deploy else 1.28
    h = .246 if deploy else .151
    count = 12 if deploy else 8
    disc(outer*.94,.012,h*.45,iron,count*2)
    disc(outer*.90,h*.39,h*.64,alloy,count*2)
    disc(outer*.87,h*.60,h*.83,iron)
    disc(.84,.052,h-.012,paint)
    disc(.713,h-.012,h+.001,tread)
    for i in range(count):
        center = -pi/2 + tau*i/count
        half = pi/count-.018
        a,b = center-half,center+half
        segment(a,b,[(outer*.69,h*.42),(outer*.96,h*.30),(outer,h*.52),
                     (outer*.99,h*.74),(outer*.90,h),(outer*.73,h)],alloy)
        strip(a+.025,b-.025,outer*.745,outer*.865,h+.007,paint)
        strip(a+.045,b-.045,outer*.87,outer*.89,h+.007,trim)
        # Visible from a low side camera: a recessed black bezel with a colored lens.
        segment(a+.055,b-.055,[(outer*.985,h*.48),(outer*1.001,h*.48),
                    (outer*1.001,h*.68),(outer*.985,h*.68)],iron)
        segment(center-half*.54,center+half*.54,[(outer,h*.525),(outer*1.004,h*.525),
                    (outer*1.004,h*.63),(outer,h*.63)],emitter)
        for angle in (a+.065,b-.065):
            fastener(outer*.81*cos(angle),outer*.81*sin(angle),h+.009)
        if i%2==0:
            for j in [-1,0,1]:
                angle=center+j*.048
                strip(angle,angle+.020,outer*.756,outer*.833,h+.016,brass,1)
        else:
            strip(center-half*.55,center+half*.55,outer*.785,outer*.814,h+.012,emitter)
    for side in [-1,1]:
        for row in [-2,-1,0,1,2]:
            y=row*.133
            poly=[(.22,y),(.44,y+.045),(.48,y+.080),(.26,y+.038)]
            block("Grip rib",[(side*x,v) for x,v in poly],h+.001,h+.010,alloy,.002)
    if deploy:
        # Connector pods and a recessed plaque identify the central deployment pad.
        for sign in [-1,1]:
            outline=[(.79,-.94),(1.14,-.82),(1.25,-.96),(1.03,-1.23),(.78,-1.16)]
            block("Coupling",[(x*sign,y) for x,y in outline],.021,.162,paint,.018)
            block("Coupling lamp",[(x*sign,y) for x,y in
                  [(.88,-1.07),(1.12,-.90),(1.14,-.95),(.90,-1.14)]],.162,.178,emitter)
        block("Deploy plaque",[(-.42,-1.48),(.42,-1.48),(.38,-1.65),(-.38,-1.65)],
              .045,.215,iron,.018)
    root=bpy.data.objects.new("Platform",None)
    bpy.context.collection.objects.link(root)
    lights=set(guides)
    chassis=join([obj for obj in bpy.context.scene.objects if obj.type=="MESH" and obj not in lights],"Chassis")
    lens=join(list(guides),"LightGuides")
    guides.clear()
    chassis.parent=root
    lens.parent=root
    name="deployment_platform" if deploy else "station_platform"
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(name+".glb")),export_format="GLB",
                              export_animations=False,export_yup=True,export_texcoords=False)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


platform(False)
platform(True)
