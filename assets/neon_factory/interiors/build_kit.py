"""Build the Neon Factory modular kit. Run with Blender in background mode."""
import math
import sys
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from kit_detail import faceplate, machined_deck, sector_feature, textured_alloy

def material(name, rgb, metallic=0.55, glow=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*rgb, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = 0.43
    if glow:
        shader.inputs["Emission Color"].default_value = (*rgb, 1)
        shader.inputs["Emission Strength"].default_value = glow
    return result

def box(name, xyz, size, mat, edge=0.045, turn=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.y = turn
    obj.data.materials.append(mat)
    if edge:
        bevel = obj.modifiers.new("Machined edges", "BEVEL")
        bevel.width = edge
        bevel.segments = 1
        obj.modifiers.new("Face normals", "WEIGHTED_NORMAL")
    return obj

def tube(name, xyz, radius, length, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=length, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler.y = math.pi / 2
    obj.data.materials.append(mat)

def map_surface_texture(obj):
    """Use consistent texture density on large panels and small fasteners."""
    mat = obj.data.materials[0]
    if not any(node.type == "TEX_IMAGE" for node in mat.node_tree.nodes):
        return
    mesh = obj.data
    uv = mesh.uv_layers.active or mesh.uv_layers.new()
    for face in mesh.polygons:
        normal = obj.matrix_world.to_3x3() @ face.normal
        direction = max(range(3), key=lambda axis: abs(normal[axis]))
        horizontal, vertical = [(1, 2), (0, 2), (0, 1)][direction]
        for index in face.loop_indices:
            vertex = obj.matrix_world @ mesh.vertices[mesh.loops[index].vertex_index].co
            uv.data[index].uv = (vertex[horizontal]/1.75, vertex[vertical]/1.75)


def bake(name, builder):
    bpy.ops.object.select_all(action="DESELECT")
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    before = set(bpy.data.objects)
    builder()
    pieces = sorted(set(bpy.data.objects) - before, key=lambda obj: obj.name)
    for obj in pieces:
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        collection.objects.link(obj)
        obj.select_set(True)
    source = bpy.data.collections.new(name + " source")
    bpy.context.scene.collection.children.link(source)
    for obj in pieces:
        original = obj.copy()
        original.data = obj.data.copy()
        source.objects.link(original)
    source.hide_viewport = True
    source.hide_render = True
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.convert(target="MESH")
    by_material = {}
    for obj in sorted(bpy.context.selected_objects, key=lambda obj: obj.name):
        map_surface_texture(obj)
        by_material.setdefault(obj.data.materials[0].name, []).append(obj)
    bpy.ops.object.select_all(action="DESELECT")
    merged = []
    for mat, group in by_material.items():
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        group[0].name = name + " - " + mat
        group[0].select_set(False)
        merged.append(group[0])
    for obj in merged:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT / (name + ".glb")), export_format="GLB", use_selection=True)
    collection.hide_viewport = True
    collection.hide_render = True

bpy.ops.wm.read_factory_settings(use_empty=True)
steel = material("Blue steel", (.065, .105, .17))
edge = material("Brushed gunmetal", (.16, .23, .30))
dark = material("Recessed iron", (.024, .036, .057))
gold = material("Safety enamel", (.76, .27, .038), .24)
cyan = material("Cool perimeter LEDs", (.025, .65, 1), .15, 2.2)
amber = material("Hot service LEDs", (1, .22, .033), .16, 2.2)
rock = material("Basalt", (.095, .088, .10), 0)
for surface, grain, wear, seed in [(steel,.28,.48,41),(edge,.32,.58,82),(dark,.18,.39,20),(rock,.06,.84,72)]:
    textured_alloy(surface,grain,wear,seed)

def floor():
    box("Load bearing slab", (0, 0, -.47), (5.99, 4.8, .74), steel, .08)
    for x in [-2., 0., 2.]:
        box("Tread plate", (x, 0, -.055), (1.96, 4.69, .11), edge, .035)
        box("Recessed fascia", (x, -2.402, -.43), (1.68, .054, .35), dark)
        box("Guide lamp", (x, -2.438, -.40), (.68, .037, .06), cyan, .015)
        for offset in [-.74, .74]:
            box("Rivet", (x+offset, -2.443, -.41), (.08, .05, .08), edge)
    box("Bottom rail", (0, -2.42, -.75), (5.89, .069, .11), edge)
    machined_deck(box,dark,steel,edge,cyan,"factory")

def lining():
    box("Interior backing", (0, 0, 4), (6.01, .42, 8), dark, 0)
    for y in [.95, 3., 5.05, 7.03]:
        box("Recessed armor", (0, -.24, y), (5.77, .21, 1.92), steel, .11)
        box("Panel bevel", (0, -.367, y+.73), (5.42, .052, .085), edge)
    for x in [-2.78, 2.78]:
        box("Vertical ribs", (x, -.43, 4), (.33, .31, 7.97), edge, .06)
    tube("Service pipe", (0, -.51, 5.49), .16, 5.87, dark)
    for x in [-2.62,-.6,1.55]:
        tube("Pipe coupling", (x, -.51, 5.49), .22, .18, edge)
    box("Utility light", (0, -.64, 6.46), (1.87, .08, .115), cyan)
    faceplate(box,dark,steel,edge,cyan,-1.52,-.41,3.35,1.70,1.14)
    faceplate(box,dark,steel,edge,amber,1.19,-.41,1.02,2.24,.80)
    for x in [-2.06,-1.77,-1.48,-1.19,-.9]:
        box("Bulkhead louvre", (x,-.56,3.39),(.095,.09,.44),edge,.018,.30)

def cave():
    box("Bedrock backing", (0, .29, 3.96), (6.02, .50, 8.), dark, 0)
    for i in range(9):
        x = (i % 3 - 1) * 2.02
        y = (i // 3) * 2.54 + 1.18
        obj = box("Split basalt", (x, -.20-(i % 4)*.09, y), (1.97, .96, 2.39), rock, .26, .08*((i % 4)-1))
        obj.rotation_euler.z = .10*((i % 3)-1)
    for i in range(8):
        x = (i%4-1.5)*1.31
        height = 1.14+(i%3)*.31
        box("Angular basalt seam", (x,-.79,2.32+(i//4)*3.1),(.42,.23,height),
            rock if i%3 else steel,.115,x*.34)
    box("Conduit rail", (0,-.90,1.18), (5.96,.28,.33), edge)
    tube("Hot pipe", (0,-1.13,1.20), .08, 5.93, amber)

def machinery():
    box("Transformer housing", (0,.08,1.61), (5.90,1.2,3.22), steel,.15)
    box("Armored face", (0,-.60,1.63), (5.62,.19,2.92), edge,.11)
    for x in [-1.7,0,1.7]:
        box("Conduit channel", (x,-.73,1.65), (1.34,.10,2.42), dark,.05)
        for z in [.81,1.34,1.87,2.40]:
            box("Cooling grille", (x,-.82,z), (1.10,.16,.18), steel,.04)
        box("Power readout", (x,-.91,2.68), (.56,.09,.10), amber,.02)
    tube("Feeder pipe", (0,-.72,3.36), .19,5.67, dark)
    for x in [-2.5,0,2.5]:
        tube("Feeder coupling", (x,-.72,3.36),.27,.21,edge)

def ceiling():
    box("Overhead chassis", (0,0,.45), (5.98,5.51,.90), dark,.07)
    for x in [-2.45,0,2.45]:
        box("Crossbeam", (x,0,.04), (.38,5.51,.31), steel,.04)
    box("Lighting track", (0,-1.35,-.14), (5.79,.42,.17), edge,.053)
    box("Lighting tube", (0,-1.37,-.25), (3.14,.18,.10), cyan,.03)

def column():
    box("Wall jump chassis", (0,0,0), (.79,4.25,4.01), steel)
    for y in [-1.57,-.52,.53,1.60]:
        box("Ladder plate", (0,-2.14,y), (.77,.12,.87), edge)
        for x in [-.37,.37]:
            box("Wall guide", (x,-2.24,y), (.063,.09,.46), amber, .013)

def pressure_bank():
    sector_feature(box,tube,dark,steel,edge,amber,"factory")


def bridge():
    floor()
    for x in [-2.35,-1.7,1.7,2.35]:
        box("Bridge band", (x,-2.46,-.23), (.33,.06,.14), gold, .02, math.radians(-24))

def relay():
    box("Switch mount", (0,0,-.39), (.64,.39,.92), dark)
    box("Armored sensor", (0,-.07,.24), (1.04,.48,.80), edge, .12)
    box("Sensor window", (0,-.34,.24), (.68,.08,.49), dark, .09)
    for x in [-.41,.41]:
        box("Power lane", (x,-.41,.23), (.055,.09,.42), cyan)

def cache():
    box("Lockbox", (0,0,.39), (1.28,.89,.68), steel, .09)
    box("Lid", (0,0,.75), (1.31,.94,.23), edge, .06)
    for x in [-.49,.49]:
        box("Reinforcing band", (x,-.449,.52), (.11,.10,.72), gold)
    box("Latch", (0,-.484,.57), (.39,.11,.19), amber)

def hazard_base(width):
    box("Recessed trap housing", (0,0,.055), (width,1.68,.11), dark, .04)
    box("Service hatch", (0,0,.089), (width*.76,1.46,.09), steel, .03)
    for x in [-width*.405,width*.405]:
        box("Caution band", (x,0,.14), (.13,1.53,.08), gold, .015)
    for x in [-width*.33,width*.33]:
        for y in [-.58,.58]:
            box("Bolt", (x,y,.14), (.06,.075,.045), edge, .015)

def drill_trap():
    hazard_base(1.56)
    box("Drill aperture", (0,0,.134), (.67,.86,.04), dark, .02)

def laser_trap():
    hazard_base(.84)
    for x in [-.42,.42]:
        box("Laser upright", (x,.85,1.35), (.23,.25,2.7), steel, .05)
        box("Emitter guard", (x,.74,1.27), (.33,.20,.42), edge, .04)
        box("Emitter lane", (x,.62,1.65), (.09,.06,1.53), amber, .02)

def press_trap():
    hazard_base(2.96)
    for x in [-1.33,1.33]:
        box("Piston guide", (x,.84,1.55), (.22,.26,2.85), edge, .055)
    box("Ram motor", (0,0,3.28), (2.95,1.85,.60), steel,.10)
    for x in [-.72,.72]:
        box("Ram motor vents", (x,-.96,3.26), (.85,.12,.22), dark,.04)
        box("Ram status", (x,-1.034,3.25), (.49,.06,.055), amber,.013)

for name, builder in [("deck", floor), ("bulkhead", lining), ("bedrock", cave), ("shaft_wall", column),
                      ("transfer_bridge", bridge), ("shot_relay", relay), ("salvage_chest", cache), ("transformer", machinery), ("ceiling", ceiling),
                      ("pressure_bank", pressure_bank), ("drill_trap", drill_trap), ("laser_trap", laser_trap), ("press_trap", press_trap)]:
    bake(name,builder)
for i, collection in enumerate(item for item in bpy.data.collections if not item.name.endswith(" source")):
    source = bpy.data.collections[collection.name + " source"]
    source.hide_viewport = False
    source.hide_render = False
    for obj in source.objects:
        obj.location.x += i * 8.5
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "neon_factory_interiors.blend"))
