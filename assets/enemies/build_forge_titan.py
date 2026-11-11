import sys, math
from pathlib import Path
import bpy
from mathutils import Vector
r=Path(sys.argv[-1])
source=r/'assets/enemies/build_factory_armor.py'
# Share construction primitives and UV layout with the five factory units.
base=source.read_text().split('for build in [scout,quad,heavy,turret,flyer]:')[0]
base=base.replace("assets/enemies/security_trim.png","assets/enemies/forge_titan_trim.png")
exec(compile(base,str(source),'exec'))
hazard=mat('Safety stripes',(.4,.2,.01),3)
burnt=mat('Heat-treated steel',(.19,.07,.029),2)
orange=mat('Molten reactor',(1,.17,.008),None,3.3)
yellow=mat('Hot filament',(1,.52,.05),None,4.0)
bronze=mat('Anodized bronze',(.37,.16,.035))
root_pivot=bpy.data.objects.new('ForgeTitanRig',None)
bpy.context.collection.objects.link(root_pivot)
def pivot(n,p=(0,0,0),parent=root_pivot):
    o=bpy.data.objects.new(n,None); bpy.context.collection.objects.link(o)
    o.parent=parent; o.location=v(p)
    return o
def pack(parent):
    grouped={}
    for ob in parts: grouped.setdefault(ob.data.materials[0].name,[]).append(ob)
    for key, objects in grouped.items():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects: ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        ob=bpy.context.object; ob.name=key; ob.parent=parent
    parts.clear()
def gbox(n,x,y,z,w,h,d,m,bevel=.045,tilt=0):
    return plate(n,(x,y,z),(w,h,d),m,bevel,tilt)
def ribbed_panel(x,y,z,w,h,count=4):
    gbox('Vent face',x,y,z,w+.07,h+.063,.08,black,.024)
    for i in range(count):
        gbox('Reactor grille',x,y+h*(i/(count-1)-.5),z+.041,w,.023,.024,orange,.008)
def bolt(x,y,z,r=.028):
    cyl('Hardened bolt',(x,y,z),r,.026,edge,verts=8)
def shaft(p,q,r,m):
    axis=tuple(q[i]-p[i] for i in range(3))
    c=tuple((p[i]+q[i])*.5 for i in range(3))
    return cyl('Hydraulic assembly',c,r,Vector(axis).length,m,axis,verts=12)
hull_pivot=pivot('HullPivot')
gbox('Torso subframe',0,.31,0,1.69,1.00,.93,black,.14)
gbox('Abdomen block',0,-.22,.03,1.09,.48,.71,blue,.115)
gbox('Waist shell',0,-.38,.34,.72,.28,.28,white,.085)
for side in [-1,1]:
    x=side*.61
    gbox('Breastplate',x,.39,.373,.59,.58,.33,blue,.105,side*.16)
    gbox('Ceramic clavicle',x,.66,.378,.53,.19,.32,white,.07,side*.21)
    ribbed_panel(x,.35,.566,.29,.117,3)
    shaft((side*.25,.05,.46),(side*.75,-.03,.43),.061,bronze)
    shaft((side*.7,-.04,.43),(side*.88,.16,.34),.072,steel)
    x=side*1.04
    gbox('Pauldron subframe',x,.67,-.012,.85,.58,.87,blue,.11,side*.15)
    gbox('Winged shoulder mantle',x,.95,.008,.94,.27,.95,white,.092,side*.24)
    gbox('Ceramic upper crown',x+side*.13,1.12,-.12,.37,.23,.61,white,.078,side*.36)
    ribbed_panel(x,.61,.45,.41,.14,3)
    bolt(x-side*.24,.855,.43,.033)
    bolt(x+side*.26,.855,.43,.033)
    gbox('Hip shield',side*.55,-.29,.27,.39,.36,.47,blue,.08,side*.24)
    bolt(side*.56,-.29,.52)
cyl('Reactor rim',(0,.35,.584),.37,.23,black,verts=16)
cyl('Reactor orange collar',(0,.35,.715),.321,.057,bronze,verts=12)
cyl('Reactor heat shield',(0,.35,.748),.265,.04,burnt,verts=16)
cyl('Plasma window',(0,.35,.77),.188,.038,orange,r2=.15,verts=16)
cyl('White hot core',(0,.35,.798),.092,.028,yellow,r2=.066,verts=14)
for i in range(12):
    a=i*math.tau/12
    x=.303*math.cos(a); y=.35+.303*math.sin(a)
    gbox('Reactor radial clamp',x,y,.757,.074,.054,.066,edge,.015,a)
gbox('Helmet frame',0,1.095,.137,.62,.48,.53,black,.095)
gbox('Helmet dome',0,1.296,.10,.62,.22,.55,white,.078)
gbox('Central dorsal crest',0,1.434,.094,.19,.13,.49,blue,.045)
for side in [-1,1]:
    gbox('Optic cheek plate',side*.26,1.073,.33,.13,.27,.22,white,.048,side*.22)
    gbox('Angled optic',side*.11,1.142,.432,.24,.074,.026,orange,.013,side*.18)
    cyl('Helmet ear housing',(side*.335,1.13,.12),.124,.096,black,(1,0,0),verts=10)
    cyl('Helmet ear bearing',(side*.39,1.13,.12),.063,.019,bronze,(1,0,0),verts=10)
gbox('Helmet jaw',0,1.026,.376,.35,.17,.18,blue,.044)
pack(hull_pivot)
for side in [-1,1]:
    leg=pivot('LegLeft' if side<0 else 'LegRight',(side*.515,-.40,.01))
    gbox('Hip clevis',0,-.07,0,.46,.30,.46,black,.075)
    for sx in [-.105,.105]:
        shaft((sx,-.02,.19),(sx,-.30,.19),.062,steel)
        shaft((sx,-.08,.21),(sx,-.34,.23),.033,bronze)
    joint((0,-.32,0),.152)
    gbox('Shin chassis',0,-.58,0,.58,.58,.63,blue,.09,side*.07)
    gbox('Ceramic greave',0,-.52,.29,.48,.43,.26,white,.091,side*.05)
    gbox('Knee armor',0,-.32,.413,.23,.148,.074,bronze,.028)
    ribbed_panel(side*.22,-.63,.344,.105,.124,3)
    bolt(-.14,-.44,.434)
    bolt(.14,-.44,.434)
    gbox('Track foot',0,-.91,.14,.68,.25,.91,black,.069)
    gbox('Foot cap',0,-.79,.222,.61,.25,.69,blue,.092)
    gbox('Hazard toe',0,-.803,.588,.48,.106,.034,hazard,.009)
    for n in [-.21,0,.21]:
        gbox('Toe tread',n,-.924,.592,.16,.11,.145,edge,.031)
    pack(leg)
drill_module=pivot('DrillModule',(-1.19,.46,.21))
gbox('Drill drive link',0,-.04,0,.52,.32,.52,blue,.092)
cyl('Ceramic drill arm housing',(0,-.31,0),.356,.44,white,(0,-1,0),r2=.379,verts=12)
cyl('Drill locking collar',(0,-.566,0),.362,.12,steel,(0,-1,0),r2=.331,verts=16)
for i in range(12):
    a=i*math.tau/12
    gbox('Collar key',.349*math.cos(a),-.58,.349*math.sin(a),.073,.075,.073,black,.016)
ribbed_panel(0,-.32,.371,.22,.105,3)
pack(drill_module)
rotor=pivot('DrillRotor',(0,-.62,0),drill_module)
cyl('Tapered carbide bit',(0,-.48,0),.323,.97,burnt,(0,-1,0),r2=.004,verts=28)
def helix(radius_offset,m,tube,angle_offset=0):
    points=[]; faces=[]
    n=140
    ring=7
    for i in range(n+1):
        t=i/n; a=angle_offset+t*math.tau*3.25
        rad=.32*(1-t)+radius_offset
        for j in range(ring):
            b=math.tau*j/ring
            rr=rad+tube*math.cos(b)
            points.append(v((rr*math.cos(a),-.031-t*.925+tube*math.sin(b),rr*math.sin(a))))
        if i:
            for j in range(ring):
                k=(j+1)%ring
                faces.append(((i-1)*ring+j,(i-1)*ring+k,i*ring+k,i*ring+j))
    data=bpy.data.meshes.new('Machined spiral'); data.from_pydata(points,[],faces); data.update()
    ob=bpy.data.objects.new('Machined spiral',data); bpy.context.collection.objects.link(ob)
    setup(ob,ob.name,m)
helix(-.003,edge,.034)
helix(.018,orange,.014)
pack(rotor)
fist_module=pivot('FistModule',(1.18,.44,.16))
joint((0,-.11,0),.153)
gbox('Fist servo chassis',0,-.25,0,.49,.49,.54,black,.092)
gbox('Ceramic knuckle shield',0,-.29,.25,.62,.37,.21,white,.074)
ribbed_panel(0,-.31,.365,.25,.109,3)
for i in [-1,0,1]:
    x=i*.175
    cyl('Finger joint',(x,-.46,.08),.086,.127,steel,(1,0,0),verts=9)
    shaft((x,-.48,.16),(x,-.72,.24),.091,edge)
    shaft((x,-.67,.24),(x,-.83,.35),.061,black)
    gbox('Claw heat strip',x,-.64,.322,.06,.17,.044,orange,.013,i*.17)
pack(fist_module)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(r/'assets/enemies/forge_titan_armored.glb'),export_format='GLB',use_selection=True,export_image_format='JPEG',export_jpeg_quality=88)
