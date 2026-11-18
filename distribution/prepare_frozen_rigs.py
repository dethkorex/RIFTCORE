"""Blender: rebuild mechanical joints and rigid skin groups on the Frozen Reactor mechs.

Usage: blender -b --python prepare_frozen_rigs.py -- rime|cryo INPUT.glb OUTPUT.glb
The generated Tripo textures and geometry are preserved; no image edits or paid calls.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

kind, source, destination = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(source).resolve()))
mesh = max((obj for obj in bpy.data.objects if obj.type == "MESH"), key=lambda obj: len(obj.data.vertices))
# Freeze the original T-pose geometry, remove the auto-rig and its display helpers.
world = mesh.matrix_world.copy()
mesh.parent = None
mesh.matrix_world = Matrix.Identity(4)
for vertex in mesh.data.vertices:
    vertex.co = world @ vertex.co
mesh.modifiers.clear()
mesh.vertex_groups.clear()
for obj in list(bpy.data.objects):
    if obj != mesh:
        bpy.data.objects.remove(obj, do_unlink=True)
mesh.name = "MechanicalArmor"

armature = bpy.data.armatures.new("FrozenMechanism")
rig = bpy.data.objects.new("FrozenSkeleton", armature)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
rime = kind == "rime"
hip_height = .245 if rime else .295
knee_height = .145 if rime else .190
foot_height = .047 if rime else .052
arm_height = .415 if rime else .389

def joint(name, head, tail, parent=None):
    bone = armature.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    if parent:
        bone.parent = armature.edit_bones[parent]

joint("Hips", (.025, 0, hip_height), (.025, 0, hip_height + .04))
joint("Spine", (.025, 0, hip_height + .025), (.025, 0, .46 if rime else .41), "Hips")
joint("Head", (.02, 0, .51 if rime else .44), (.02, 0, .59 if rime else .48), "Spine")
for direction, side in [(1, "Left"), (-1, "Right")]:
    leg_y = .095 if rime else .079
    joint(side+"Thigh", (.025,direction*leg_y,hip_height), (.04,direction*leg_y,knee_height), "Hips")
    joint(side+"Calf", (.04,direction*leg_y,knee_height), (.025,direction*leg_y,foot_height), side+"Thigh")
    joint(side+"Foot", (.025,direction*leg_y,foot_height), (.115,direction*leg_y,.025), side+"Calf")
    joint(side+"UpperArm", (.02,direction*.225,arm_height), (.03,direction*.285,arm_height-.012), "Spine")
    joint(side+"Forearm", (.03,direction*.285,arm_height-.012), (.035,direction*.43,arm_height-.02), side+"UpperArm")
bpy.ops.object.mode_set(mode="OBJECT")

groups = {bone.name: mesh.vertex_groups.new(name=bone.name) for bone in armature.bones}
for vertex in mesh.data.vertices:
    x, y, z = vertex.co
    lateral = abs(y)
    side = "Left" if y > 0 else "Right"
    # Complete gauntlets, cannon and shield follow one rigid joint each.
    arm = lateral > .25 and (z < (.49 if rime else .455) or lateral > .31)
    if rime and x < -.065 and lateral < .33 and z > .42:
        arm = False
    if arm:
        name = side + ("Forearm" if lateral > .282 else "UpperArm")
    elif z < hip_height and lateral > .026:
        name = side + ("Foot" if z < (.087 if rime else .09) else "Calf" if z < knee_height else "Thigh")
    elif lateral < (.085 if rime else .065) and z > (.493 if rime else .435):
        name = "Head"
    elif z < hip_height + .022:
        name = "Hips"
    else:
        # Broad shoulder shells, chest and coolant tanks stay on the rigid torso.
        name = "Spine"
    groups[name].add([vertex.index], 1.0, "REPLACE")

mesh.parent = rig
modifier = mesh.modifiers.new("MechanicalSkin", "ARMATURE")
modifier.object = rig
mesh.select_set(True)
rig.select_set(True)
bpy.context.view_layer.update()
Path(destination).parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(Path(destination).resolve()), export_format="GLB",
                          use_selection=True, export_animations=False, export_skins=True,
                          export_yup=True, export_apply=False)
print("FROZEN MECHANICAL RIG", kind, len(mesh.data.vertices), "vertices", len(armature.bones), "joints")
