"""Transfer the established RX-07 bind pose and clips to the supplied fire armor mesh."""
import bpy,sys,json
from pathlib import Path
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]
root=Path(args[0])
input_file=Path(args[1]) if len(args)>1 else Path('C:/Users/krayz/Downloads/Fire upgrade.glb')
asset_name=args[2] if len(args)>2 else 'RiftcoreFireRigged'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'assets/models/mecha_main/RiftcoreMechaUAL.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
source=next(o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
hero_root=rig
while hero_root.parent:hero_root=hero_root.parent
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(input_file))
added=set(bpy.data.objects)-before
target=max((o for o in added if o.type=='MESH'), key=lambda o:len(o.data.vertices))
# Both meshes have the same full T-pose proportions; match the established 1.8 m silhouette.
src_pts=[source.matrix_world@v.co for v in source.data.vertices]
new_pts=[target.matrix_world@v.co for v in target.data.vertices]
src_lo=min(p.z for p in src_pts);src_hi=max(p.z for p in src_pts)
lo=min(p.z for p in new_pts);hi=max(p.z for p in new_pts)
scale=(src_hi-src_lo)/(hi-lo)
for vertex,at in zip(target.data.vertices,new_pts):
    vertex.co=Vector((at.x*scale,at.y*scale,(at.z-lo)*scale+src_lo))
target.parent=None
target.matrix_world.identity()
for modifier in list(target.modifiers):
    if modifier.type=='ARMATURE':target.modifiers.remove(modifier)
target.vertex_groups.clear()
for group in source.vertex_groups:target.vertex_groups.new(name=group.name)
bpy.ops.object.select_all(action='DESELECT')
target.select_set(True);bpy.context.view_layer.objects.active=target
rig.data.pose_position='REST'
bpy.context.view_layer.update()
transfer=target.modifiers.new('RX07 exact existing rig weights','DATA_TRANSFER')
transfer.object=source
transfer.use_vert_data=True
transfer.data_types_verts={'VGROUP_WEIGHTS'}
transfer.vert_mapping='POLYINTERP_NEAREST'
transfer.layers_vgroup_select_src='ALL'
transfer.layers_vgroup_select_dst='NAME'
bpy.ops.object.modifier_apply(modifier=transfer.name)
# Keep the buster shell rigid rather than allowing wrist/finger deformation.
cannon=target.vertex_groups.get('mixamorig:RightForeArm')
rigid=0
for vertex in target.data.vertices:
    if vertex.co.x < -.56 and vertex.co.z > 1.14:
        for g in target.vertex_groups:g.remove([vertex.index])
        cannon.add([vertex.index],1.0,'REPLACE');rigid+=1
# Normalize exactly four influences for deterministic Godot skinning.
for vertex in target.data.vertices:
    weights=sorted([(g.group,g.weight) for g in vertex.groups if g.weight>.00001],key=lambda pair:pair[1],reverse=True)[:4]
    total=sum(weight for _,weight in weights)
    for group in target.vertex_groups:group.remove([vertex.index])
    for index,weight in weights:target.vertex_groups[index].add([vertex.index],weight/total,'REPLACE')
rig.data.pose_position='POSE'
unweighted=0
for vertex in target.data.vertices:
    weights=[g.weight for g in vertex.groups]
    if sum(weights)<.00001:unweighted+=1
assert unweighted==0, f'Unweighted vertices: {unweighted}'
world=target.matrix_world.copy()
target.parent=rig
target.matrix_world=world
deform=target.modifiers.new('RX07 original skeleton','ARMATURE')
deform.object=rig
target.name='NatureSuitArmor' if 'Nature' in asset_name else 'FireSuitArmor'
for ob in added:
    if ob!=target and ob.type!='MESH':bpy.data.objects.remove(ob,do_unlink=True)
bpy.data.objects.remove(source,do_unlink=True)
for image in bpy.data.images:
    if image.source=='FILE':
        try:image.pack()
        except RuntimeError:pass
bpy.ops.object.select_all(action='DESELECT')
for ob in [hero_root]+list(hero_root.children_recursive):ob.select_set(True)
out=root/'assets/models/mecha_main'/f'{asset_name}.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='NLA_TRACKS',
                         export_image_format='AUTO',export_skins=True)
print('RIG_REPORT',json.dumps({'vertices':len(target.data.vertices),'unweighted':unweighted,'rigid_cannon_vertices':rigid,'scale':scale,
                             'bones':len(rig.data.bones),'nla_tracks':[track.name for track in rig.animation_data.nla_tracks]}))
bpy.ops.wm.save_as_mainfile(filepath=str(root.parent/f'{asset_name}.blend'))
