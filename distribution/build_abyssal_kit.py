"""Blender source for the Abyssal Plant pressure machinery (metres, Godot Y-up).

Run blender -b --python distribution/build_abyssal_kit.py -- PROJECT PIPES_GLTF.
The imported pipe meshes/textures are CC0 Poly Haven; see kit/SOURCES.md.
All other geometry is authored here, with beveled edges and separate moving parts.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector

root, source = map(Path, sys.argv[sys.argv.index('--') + 1:])
out = root / 'assets/campaign/abyssal_plant/kit'
out.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat(name, rgb, metal=.6, rough=.35, emission=0):
    m = bpy.data.materials.new(name); m.diffuse_color = (*rgb, 1); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Metallic'].default_value = metal; p.inputs['Roughness'].default_value = rough
    p.inputs['Emission Color'].default_value = (*rgb, 1)
    p.inputs['Emission Strength'].default_value = emission
    return m

steel = mat('Pressure gunmetal', (.012,.025,.04),.8)
paint = mat('Ocean enamel', (.025,.075,.09),.48,.3)
alloy = mat('Machined titanium', (.22,.30,.34),.83,.25)
rubber = mat('Nonconductive ceramic', (.035,.055,.065),.05,.78)
amber = mat('Hazard enamel', (.95,.49,.055),.25)
cyan = mat('Status cyan', (.10,.65,.74),.25,.24,.65)
red = mat('Pressure release red', (.65,.055,.025),.35)

def cv(p): return (p[0], -p[2], p[1])
def finish(o, m, bevel=0):
    o.data.materials.append(m)
    if bevel:
        mod=o.modifiers.new('Manufactured edge radii','BEVEL');mod.width=bevel;mod.segments=3
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons: p.use_smooth=True
    return o
def box(name,p,s,m,bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.name=name
    o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,m,min(bevel,min(s)*.28))
def cyl(name,p,r,h,m,axis='y',vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=cv(p))
    o=bpy.context.object;o.name=name
    if axis=='z':o.rotation_euler.x=math.pi/2
    if axis=='x':o.rotation_euler.y=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,m,.015)
def ring(name,p,r,t,m):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=t,major_segments=48,minor_segments=10,location=cv(p),rotation=(math.pi/2,0,0))
    o=bpy.context.object;o.name=name;return finish(o,m)
def bolt(p):return cyl('Hex fastener',p,.055,.055,alloy,'z',6)
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def export(name):
    # Join by material: retain detail without hundreds of runtime draw calls.
    groups={}
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH':groups.setdefault(o.data.materials[0].name if o.data.materials else 'none',[]).append(o)
    for objects in groups.values():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',export_yup=True,export_animations=False)
    clear()

for width in [4,8]:
    box('Reinforced deck',(0,-.28,0),(width,.56,3.2),steel,.1)
    box('Raised grip surface',(0,-.045,0),(width-.10,.09,3.05),rubber)
    for x in [-width/2+.16,width/2-.16]:
        box('Side casting',(x,-.23,0),(.30,.46,3.25),paint)
        for z in [-1.1,1.1]:bolt((x,-.18,z))
    for x in range(int(width/.25)):
        box('Anti slip tread',(-width/2+.125+x*.25,.012,0),(.08,.025,2.75),alloy,.006)
    for x in range(width):
        box('Front warning stripe',(-width/2+.3+x,-.2,1.625),(.38,.22,.035),amber,.006)
        box('Front lamp',(-width/2+.7+x,-.39,1.64),(.20,.06,.025),cyan,.006)
    for x in [-width/2+.35,width/2-.35]:
        box('Rear stanchion',(x,.55,-1.53),(.10,1.1,.1),alloy)
        bracket=box('Cantilever gusset',(x,-.73,-.85),(.20,1.0,.22),paint)
        bracket.rotation_euler.x=-.65
    box('Rear safety rail',(0,1.08,-1.53),(width,.12,.12),paint)
    export('catwalk_%dm'%width)

box('Insulator core',(0,-.3,0),(4,.6,3.2),steel,.12)
box('Ceramic landing',(0,-.055,0),(3.8,.11,3.1),rubber,.03)
for x in [-1.85,1.85]:
    box('Amber isolation edge',(x,.015,0),(.09,.035,3),amber)
for i in range(6):box('Ceramic ribs',((i-2.5)*.56,.018,0),(.42,.04,2.8),alloy)
box('Grounded status',(0,-.25,1.65),(2.8,.07,.04),cyan)
export('insulated_refuge')

box('Valve pedestal',(0,.4,-.65),(.9,.8,.9),steel,.1)
cyl('Valve main barrel',(0,1.08,-.65),.39,1.0,paint,'z')
for x in [-.32,.32]:bolt((x,.5,-.17))
box('Pressure gauge housing',(.57,1.43,-.6),(.40,.51,.20),steel)
cyl('Pressure gauge face',(.57,1.47,-.47),.14,.035,alloy,'z')
box('Needle',(.58,1.51,-.44),(.028,.17,.018),red,.003)
box('Status strip',(0,.58,-.12),(.45,.07,.04),cyan)
export('pressure_valve')
ring('Hand wheel',(0,0,0),.46,.07,red)
for a in range(6):
    a=a*math.tau/6
    o=box('Wheel spoke',(.23*math.sin(a),.23*math.cos(a),0),(.045,.48,.06),alloy)
    o.rotation_euler.y=-a
cyl('Wheel spindle',(0,0,0),.14,.18,alloy,'z')
export('pressure_wheel')

for x in [-2.2,2.2]:
    box('Pressure lock jamb',(x,3,0),(.75,6.5,1.3),steel,.13)
    box('Reinforced gasket',(x*.88,3,.17),(.16,6,.18),rubber)
    for y in [1,3,5]:
        box('Lock lug',(x,y,.82),(.55,.38,.25),alloy)
        bolt((x,y,.98))
box('Pressure lock lintel',(0,6.1,0),(5.2,.8,1.3),paint,.15)
box('Warning header',(0,6.1,.7),(2.2,.16,.06),amber)
export('pressure_lock_frame')
box('Lock moving slab',(0,2.8,0),(3.65,5.6,.45),paint,.1)
for x in [-1.25,0,1.25]:box('Lock reinforcing ribs',(x,2.8,.29),(.13,5.2,.16),alloy)
ring('Seal wheel',(0,2.8,.42),.68,.09,steel)
box('Lock status',(0,4.7,.27),(1.3,.12,.06),cyan)
export('pressure_lock_slab')

ring('Turbine shroud',(0,0,0),2.6,.28,paint)
ring('Front guard ring',(0,0,.28),2.36,.09,alloy)
ring('Warning rim',(0,0,.34),2.7,.065,amber)
for i in range(12):
    a=i*math.tau/12
    bolt((2.6*math.cos(a),2.6*math.sin(a),.30))
    box('Housing mounting',(2.85*math.cos(a),2.85*math.sin(a),-.22),(.3,.3,.4),steel)
export('turbine_shroud')
cyl('Drive hub',(0,0,0),.42,.7,steel,'z')
cyl('Drive face',(0,0,.38),.29,.09,alloy,'z')
for i in range(3):
    a=i*math.tau/3
    o=box('Swept turbine blade',(1.42*math.cos(a),1.42*math.sin(a),0),(2.08,.53,.20),alloy,.08)
    o.rotation_euler.y=-a-.20
    o=box('Blade tip marker',(2.25*math.cos(a),2.25*math.sin(a),.11),(.33,.44,.05),amber)
    o.rotation_euler.y=-a
export('turbine_rotor')

for x in [-3.4,3.4]:
    box('Window pressure mullion',(x,3.3,0),(.35,7.0,.5),steel,.08)
    for y in [.3,2.3,4.3,6.3]:bolt((x,y,.29))
for y in [0,6.6]:box('Observation window sill',(0,y,0),(7.1,.35,.65),paint,.09)
box('Window service light',(0,6.2,.12),(4.0,.09,.06),cyan)
export('observation_frame')

cyl('Insulated coil base',(0,.25,0),.44,.5,steel)
for y in [.55,.77,.99,1.21]:cyl('Ceramic coil',(0,y,0),.30,.14,alloy)
cyl('Electrode tip',(0,1.52,0),.13,.5,cyan)
box('Floor bolts',(0,.05,0),(1,.1,1),paint)
export('arc_electrode')

# Opaque pressure hull between observation windows; UV-mapped PBR panel detail.
hull=mat('Weathered pressure hull',(.08,.17,.20),.58,.5)
nodes=hull.node_tree.nodes
image=nodes.new('ShaderNodeTexImage')
image.image=bpy.data.images.load(str(root/'assets/campaign/abyssal_plant/surfaces/sector_wall.jpg'))
hull.node_tree.links.new(image.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
box('Pressure hull',(0,3.3,-.12),(7,6.6,.40),hull,.08)
for x in [-3.35,3.35]:
    box('Hull frame',(x,3.3,.16),(.30,6.8,.4),steel)
    for y in [.35,2.25,4.4,6.25]:bolt((x,y,.39))
for y in [0,6.6]:box('Hull transverse frame',(0,y,.16),(7,.30,.45),paint)
box('Recessed hatch',(0,3.2,.14),(4.8,4.6,.20),steel,.15)
for x in [-1.15,1.15]:box('Hatch inset',(x,3.2,.29),(2.10,4.10,.10),paint,.09)
for i in range(12):box('Vent louver',((i-5.5)*.18,1.45,.41),(.08,.5,.07),alloy)
box('Cable tray',(0,5.6,.4),(5.8,.4,.25),steel)
for x in [-2.5,-1.5,-.5,.5,1.5,2.5]:box('Cable tray bracket',(x,5.6,.56),(.07,.47,.10),alloy)
box('Service lamp',(0,5.25,.35),(1.6,.065,.04),cyan)
export('bulkhead_panel')

# Retain the actual scan-authored pipe kit, rebased into individual modular pieces.
bpy.ops.import_scene.gltf(filepath=str(source))
for image in bpy.data.images:
    if image.size[0]>512:
        image.scale(512,512)
        image.pack()
bpy.ops.export_scene.gltf(filepath=str(out/'industrial_pipes.glb'),export_format='GLB',export_yup=True,export_animations=False,export_image_format='JPEG',export_jpeg_quality=88)
print('ABYSSAL_KIT_COMPLETE',out)
