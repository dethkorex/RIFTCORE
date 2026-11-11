import bpy, math, sys
from pathlib import Path
from mathutils import Vector
root=Path(sys.argv[-1])
dest=root/'assets/enemies'
bpy.ops.wm.read_factory_settings(use_empty=True)
atlas=bpy.data.images.load(str(root/'assets/enemies/security_trim.png'))
def mat(name, color, band=None, emission=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    nt=m.node_tree; bs=nt.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=.38 if band is not None else .25
    bs.inputs['Roughness'].default_value=.38
    if band is not None:
        t=nt.nodes.new('ShaderNodeTexImage'); t.image=atlas
        nt.links.new(t.outputs['Color'],bs.inputs['Base Color'])
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1)
        bs.inputs['Emission Strength'].default_value=emission
    return (m,band)
white=mat('Ceramic',(.8,.8,.8),0)
blue=mat('Cobalt',(.04,.1,.35),1)
steel=mat('Brushed steel',(.2,.2,.2),2)
black=mat('Graphite',(.026,.042,.06))
edge=mat('Machined edges',(.25,.35,.48))
amber=mat('Amber optic',(1,.19,.012),None,1.65)
pink=mat('Magenta optic',(1,.012,.32),None,1.55)
hot=mat('Optic core',(1,.42,.09),None,1.9)
accent_brass=mat('Anodized brass',(.33,.13,.024))
hazard=mat('Service caution',(.28,.19,.04),3)
def v(p): return Vector((p[0],-p[2],p[1]))
parts=[]
gaits=[]
def setup(o,name,m,bevel=0):
    o.name=name; o.data.materials.append(m[0]); parts.append(o)
    if m[1] is not None:
        for uv in o.data.uv_layers.active.data:
            uv.uv[0]=.055+.89*uv.uv[0]
            uv.uv[1]=1-(m[1]+.06+.88*(1-uv.uv[1]))*.25
    if bevel:
        mod=o.modifiers.new('Machined chamfer','BEVEL')
        mod.width=bevel*.72; mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Face normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def plate(n,p,d,m,b=.035,tilt=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=v(p))
    o=bpy.context.object
    o.dimensions=(d[0],d[2],d[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.rotation_euler.y=tilt
    return setup(o,n,m,min(b,min(d)*.38))
def cyl(n,p,r,l,m,axis=(0,0,1),r2=None,verts=12):
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r if r2 is None else r2,depth=l,location=v(p))
    o=bpy.context.object; o.rotation_euler=v(axis).to_track_quat('Z','Y').to_euler()
    return setup(o,n,m,min(.014,l*.23,r*.2))
def joint(p,r=.085):
    cyl('Servo housing',p,r,.115,black,(1,0,0))
    for sign in [-1,1]:
        cyl('Bearing ring',(p[0]+sign*.064,p[1],p[2]),r*.77,.02,edge,(1,0,0))
        cyl('Hub',(p[0]+sign*.077,p[1],p[2]),r*.38,.012,steel,(1,0,0),verts=8)
def optic(p,w,h,c):
    x,y,z=p
    plate('Recessed optic bezel',(x,y,z),(w+.09,h+.072,.11),black,.035)
    plate('Lens',(x,y,z+.061),(w,h,.05),c,.021)
    plate('Bright lens strip',(x,y+h*.18,z+.088),(w*.72,h*.16,.009),hot if c==amber else pink,.004)
def barrel(x,y,z,l=.28,c=amber):
    cyl('Barrel jacket',(x,y,z),.116,l,black,verts=10)
    cyl('Machined brake',(x,y,z+l*.5),.122,.069,edge,verts=8)
    cyl('Muzzle recess',(x,y,z+l*.5+.037),.083,.024,black)
    cyl('Muzzle optic',(x,y,z+l*.5+.05),.052,.01,c)
def limb(x,z,knee,boot,angle=0,c=amber):
    begin=len(parts)
    joint((x,knee,z))
    plate('Drive piston',(x,knee+.09,z-.02),(.135,.25,.13),steel,.028,angle)
    plate('Shin shell',(x,boot+.11,z),(.22,.25,.26),blue,.047,angle)
    plate('Ceramic greave',(x,boot+.135,z+.124),(.173,.18,.082),white,.033,angle)
    plate('Cleated boot',(x,boot,z+.044),(.252,.115,.34),black,.035)
    plate('Toe armor',(x,boot+.038,z+.17),(.215,.075,.15),white,.024)
    plate('Ankle signal',(x,boot+.103,z+.158),(.092,.027,.025),c,.008)
    gaits.append(((x,knee+.14,z),parts[begin:]))
    del parts[begin:]
def hull(y,w,h,d,c,core=False):
    plate('Graphite chassis',(0,y,0),(w,h,d),black,.10)
    plate('Ceramic dorsal shell',(0,y+h*.34,.014),(w*.88,h*.44,d*.92),white,.08)
    plate('Cobalt crown stripe',(0,y+h*.55,.014),(w*.26,.05,d*.72),blue,.016)
    for sign in [-1,1]:
        plate('Cheek armor',(sign*w*.43,y+.014,0),(w*.24,h*.83,d*.89),blue,.055,sign*.12)
        plate('Side vent',(sign*w*.56,y,-.036),(.035,h*.25,d*.53),steel,.012)
        plate('Side ID light',(sign*w*.58,y-.08,.077),(.025,.035,d*.37),c,.008)
        cyl('Front fastener',(sign*w*.35,y+h*.23,d*.47),.025,.035,edge,verts=8)
    if core:
        cyl('Armored reactor bezel',(0,y-.06,d*.51),h*.38,.14,white,verts=8)
        cyl('Reactor recess',(0,y-.06,d*.51+.078),h*.30,.039,black,verts=8)
        cyl('Faceted reactor lens',(0,y-.06,d*.51+.105),h*.24,.049,c,r2=h*.15,verts=8)
    else:
        optic((0,y-.03,d*.49),w*.61,h*.25,c)
def scout():
    hull(.405,.61,.34,.49,amber)
    plate('Torso',(0,.047,0),(.57,.4,.44),black,.075)
    plate('Chest yoke',(0,.10,.21),(.49,.21,.10),white,.047)
    optic((0,.065,.268),.27,.071,amber)
    plate('Pelvic armor',(0,-.19,.065),(.36,.17,.31),blue,.048)
    for side in [-1,1]:
        x=side*.44
        joint((x,.16,0))
        plate('Sloping pauldron',(x,.20,.024),(.237,.21,.29),white,.053,side*.24)
        plate('Forearm shell',(x,-.055,.05),(.18,.218,.22),blue,.042,side*.12)
        if side<0: barrel(x,-.06,.12,.28)
        else: plate('Claw',(x,-.198,.095),(.146,.12,.16),steel,.029)
        limb(side*.19,.005,-.29,-.54,side*.1)
def quad():
    hull(.23,.85,.53,.75,amber)
    plate('Underbody',(0,-.086,0),(.71,.24,.60),steel,.067)
    for side in [-1,1]:
        for z in [-.245,.245]:
            x=side*.42
            joint((x,-.105,z),.107)
            limb(side*.49,z,-.29,-.54,side*.21)
    barrel(0,.10,.39,.18)
def heavy():
    hull(.25,.96,.62,.72,pink,True)
    for side in [-1,1]:
        x=side*.48
        joint((x,.14,0),.13)
        plate('Shoulder shield',(x,.29,.03),(.31,.48,.48),blue,.081,side*.1)
        plate('Shoulder ceramic insert',(x,.38,.242),(.226,.27,.085),white,.038,side*.1)
        for k in range(3):
            plate('Energy vent',(x,.18-k*.046,.275),(.155,.022,.023),pink,.008,side*.28)
        limb(side*.32,.031,-.25,-.54,side*.14,pink)
    plate('Abdominal skid',(0,-.13,.14),(.45,.14,.35),steel,.055)
def turret():
    plate('Anchor plinth',(0,-.47,0),(1.02,.25,.91),blue,.075)
    plate('Ceramic base shield',(0,-.375,.055),(.89,.15,.83),white,.055)
    cyl('Turntable',(0,-.22,0),.29,.23,steel,(0,1,0))
    hull(.14,.79,.50,.66,amber)
    for x in [-.24,.24]:
        barrel(x,.073,.33,.38)
        plate('Anchor light',(x,-.439,.45),(.11,.075,.034),amber,.01)
def flyer():
    hull(.025,.64,.59,.55,pink,True)
    for side in [-1,1]:
        x=side*.44
        plate('Swept nacelle',(x,.009,-.025),(.34,.33,.46),blue,.068,side*.22)
        plate('Nacelle armor',(x,.132,-.025),(.25,.105,.40),white,.037,side*.2)
        for y in [-.075,.005]:
            plate('Thruster stripe',(x,y,.197),(.235,.037,.026),pink,.012,side*.15)
        cyl('Lift jet',(x,-.156,-.025),.115,.095,black,(0,1,0))
        cyl('Lift glow',(x,-.209,-.025),.081,.023,pink,(0,1,0))
    cyl('Vector jet',(0,-.28,0),.16,.069,steel,(0,1,0))
    cyl('Vector glow',(0,-.32,0),.12,.019,pink,(0,1,0))
def add_detail(kind):
    spec={
      'scout':(.405,.61,.34,.49,amber), 'quad':(.23,.85,.53,.75,amber),
      'heavy':(.25,.96,.62,.72,pink), 'turret':(.14,.79,.5,.66,amber),
      'flyer':(.025,.64,.59,.55,pink)
    }
    y,w,h,d,glow=spec[kind]
    front=d*.5
    for side in (-1,1):
        x=side*w*.38
        plate('Angular brow plate',(x,y+h*.24,front+.027),(w*.22,.115,.075),white,.027,side*.20)
        plate('Brow gasket',(x,y+h*.263,front+.066),(w*.13,.028,.008),black,.003)
        for offset in (-.017,.017):
            cyl('Flush brow bolt',(x+offset,y+h*.295,front+.067),.012,.014,edge,verts=7)
        plate('Temple flange',(side*w*.475,y+.019,front*.69),(w*.145,.28,.18),blue,.032,side*.10)
        for j in range(3):
            plate('Inset side louver',(side*w*.557,y+.074-j*.041,.033),(.018,.017,d*.31),black,.003)
        cyl('Cobalt service rivet',(side*w*.56,y+.133,.17),.018,.016,edge,(side,0,0),verts=8)
    for i in range(5):
        plate('Top cooling fin',(0,y+h*.565,-.147+i*.046),(w*.16,.021,.018),edge,.005)
    if kind in ('heavy','flyer'):
        for j in range(8):
            a=j*math.tau/8
            rad=h*.32
            plate('Core locking tab',(math.cos(a)*rad,y-.06+math.sin(a)*rad,front+.126),(.045,.024,.021),edge,.005,a)
        if kind=='heavy':
            for side in (-1,1):
                plate('Shoulder hazard tag',(side*.51,.496,.226),(.145,.072,.018),hazard,.008,side*.14)
    if kind=='scout':
        for side in (-1,1):
            x=side*.439
            for j in range(3):
                cyl('Knuckle servo',(x+(j-1)*.034,-.224,.176),.021,.026,edge,verts=8)
        for x in (-.12,.12):
            cyl('Chest mounting stud',(x,.151,.277),.016,.019,accent_brass,verts=8)
    elif kind=='quad':
        for side in (-1,1):
            cyl('Lower axle hub',(side*.41,-.078,.265),.080,.11,accent_brass,(1,0,0),verts=10)
    elif kind=='turret':
        for x in (-.29,.29):
            plate('Plinth warning strip',(x,-.462,.457),(.19,.062,.023),hazard,.007)
        for x in (-.24,.24):
            for i in range(5):
                a=i*math.tau/5
                cyl('Muzzle collar bolt',(x+.096*math.cos(a),.073+.096*math.sin(a),.566),.013,.02,accent_brass,verts=6)
    elif kind=='flyer':
        for side in (-1,1):
            for j in range(4):
                plate('Thruster side radiator',(side*.52,.11-j*.034,.196),(.083,.014,.019),edge,.005)

for build in [scout,quad,heavy,turret,flyer]:
    parts.clear()
    gaits.clear()
    build()
    add_detail(build.__name__)
    group=bpy.data.objects.new(build.__name__.title(),None)
    bpy.context.collection.objects.link(group)
    def collect(objects,parent):
        grouped={}
        for ob in objects: grouped.setdefault(ob.data.materials[0].name,[]).append(ob)
        bpy.context.view_layer.update()
        for key, bucket in grouped.items():
            bpy.ops.object.select_all(action='DESELECT')
            for ob in bucket: ob.select_set(True)
            bpy.context.view_layer.objects.active=bucket[0]
            bpy.ops.object.join()
            ob=bpy.context.object
            ob.name=key
            ob.parent=parent
            ob.matrix_parent_inverse=parent.matrix_world.inverted()
    collect(parts,group)
    for index,(at,objects) in enumerate(gaits):
        joint_pivot=bpy.data.objects.new(f'Gait_{index}',None)
        bpy.context.collection.objects.link(joint_pivot)
        joint_pivot.parent=group
        joint_pivot.location=v(at)
        collect(objects,joint_pivot)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(dest/f'{build.__name__}_armored.glb'),export_format='GLB',use_selection=True,export_image_format='JPEG',export_jpeg_quality=84)
    for obj in list(group.children_recursive)+[group]:
        bpy.data.objects.remove(obj,do_unlink=True)
