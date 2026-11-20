"""Model NOVA's orbital-station drone with Blender in background mode."""
from math import cos, pi, sin, tau
from pathlib import Path

import bmesh
import bpy
from mathutils import Quaternion, Vector

OUT = Path(__file__).resolve().parents[1] / "assets" / "hub" / "nova_drone.glb"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, rgb, metal, roughness, glow=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    for key, value in {"Base Color": (*rgb, 1), "Metallic": metal, "Roughness": roughness,
                       "Emission Color": (*rgb, 1), "Emission Strength": glow}.items():
        shader.inputs[key].default_value = value
    return mat


ceramic = material("Pearl ceramic", (.63, .68, .80), .38, .27)
joint = material("Recessed midnight alloy", (.026, .032, .073), .38, .37)
steel = material("Edge alloy", (.24, .30, .45), .72, .34)
fin = material("Ink blue nacelle", (.085, .103, .23), .55, .31)
cyan = material("Cyan optics", (.026, .62, .92), .23, .20, 1.35)
ink = material("Optical black", (.014, .037, .074), .14, .15)
lilac = material("Lilac indicator", (.43, .12, .75), .12, .35, .88)
white = material("Lens highlight", (.65, .83, .94), .14, .22, .85)


def setup(obj, name, finish):
    obj.name = name
    obj.data.materials.append(finish)
    return obj


def sphere(name, at, size, finish):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=at)
    obj = bpy.context.object
    obj.scale = size
    for face in obj.data.polygons:
        face.use_smooth = True
    return setup(obj, name, finish)


def torus(name, at, radius, cross_section, finish, face_forward=True):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=10,
                                     major_radius=radius, minor_radius=cross_section, location=at,
                                     rotation=(pi / 2, 0, 0) if face_forward else (0, 0, 0))
    obj = bpy.context.object
    for face in obj.data.polygons:
        face.use_smooth = True
    return setup(obj, name, finish)


def capsule_panel(name, polar_low, polar_high, theta_low, theta_high, finish, lift=0):
    verts = []
    phi_count, theta_count = 8, 12
    for j in range(phi_count + 1):
        phi = polar_low + (polar_high - polar_low) * j / phi_count
        for i in range(theta_count + 1):
            theta = theta_low + (theta_high - theta_low) * i / theta_count
            verts.append(((.333 + lift) * sin(phi) * cos(theta),
                          -(.293 + lift) * cos(phi),
                          (.312 + lift) * sin(phi) * sin(theta)))
    faces = []
    for j in range(phi_count):
        for i in range(theta_count):
            p = j * (theta_count + 1) + i
            faces.append((p, p + 1, p + theta_count + 2, p + theta_count + 1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if mesh.polygons[0].normal.dot(mesh.polygons[0].center) < 0:
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
    for face in mesh.polygons:
        face.use_smooth = True
    shell = obj.modifiers.new("Ceramic wall", "SOLIDIFY")
    shell.thickness = .018
    bevel = obj.modifiers.new("Rounded edge", "BEVEL")
    bevel.width = .005
    bevel.segments = 2
    return setup(obj, name, finish)


def bar(name, at, size, finish, tilt=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Rounded cap", "BEVEL")
    bevel.width = min(size) * .40
    bevel.segments = 3
    obj.rotation_euler.y = tilt
    return setup(obj, name, finish)


sphere("Core under shell", (0, 0, 0), (.321, .283, .301), joint)
# Segments wrap around the eye and leave a dark seam between the ceramic pieces.
for index in range(8):
    a = (index + .06) * tau / 8
    b = (index + .94) * tau / 8
    capsule_panel("Face armor", .713, 1.36, a, b, ceramic, .012)
    capsule_panel("Rear armor", 1.42, 2.81, a, b, ceramic)
    if index % 2 == 0:
        capsule_panel("Status line", 1.356, 1.413, a + .07, b - .07, lilac, .007)
capsule_panel("Optical brow", .639, .86, .19, pi - .19, ceramic, .024)
sphere("Back cap", (0, .225, 0), (.128, .074, .11), fin)
for side in [-1, 1]:
    sphere("Gimbal", (side*.341, 0, -.025), (.104,.091,.082), steel)
    sphere("Lift nacelle", (side*.421, .024,-.028), (.102,.128,.191), fin).rotation_euler.y = side*.25
    bar("Thruster status", (side*.443,-.099,-.068), (.049,.014,.026), cyan, side*.24)
    torus("Lift emitter", (side*.410,.026,-.17), .053,.009,lilac,False)
    for row in range(3):
        bar("Cooling grille", (side*(.228 + row*.023),-.216,-.129-row*.019),
            (.008,.014,.031), steel, side*.4)
torus("Eye gasket", (0,-.248,0), .201,.023,joint)
torus("Machined lens seat", (0,-.265,0), .184,.011,steel)
sphere("Optics seat", (0,-.267,0), (.177,.028,.173),ink)
iris = bpy.data.objects.new("Iris", None)
bpy.context.collection.objects.link(iris)
iris.location = (0,-.296,0)
bpy.context.view_layer.update()
for obj in [
        sphere("Cyan iris", (0,-.301,0), (.157,.034,.152),cyan),
        sphere("Pupil", (.009,-.327,.008), (.090,.018,.093),ink),
        sphere("Catchlight", (-.040,-.344,.045), (.026,.007,.019),white)]:
    bpy.context.view_layer.update()
    original = obj.matrix_world.copy()
    obj.parent = iris
    obj.matrix_world = original

bpy.ops.object.select_all(action="DESELECT")
shell_parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.parent != iris]
for part in shell_parts:
    bpy.context.view_layer.objects.active = part
    for modifier in list(part.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    part.select_set(True)
bpy.context.view_layer.objects.active = shell_parts[0]
bpy.ops.object.join()
bpy.context.object.name = "DroneBody"

bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB",
                          export_yup=True, export_animations=False)
