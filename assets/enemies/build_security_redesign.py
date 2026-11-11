"""Sculpted faceted armor, piston limbs and turbine geometry for the security redesign."""
import bpy,math,sys,bmesh
from pathlib import Path
root=Path(sys.argv[-1])
base=root/'assets/enemies/build_factory_armor.py'
exec(compile(base.read_text().split('for build in [scout,quad,heavy,turret,flyer]:')[0],str(base),'exec'))
dest=root/'assets/enemies/redesign_v3'
def panel(name,at,w,h,d,m=white,angle=0,plane='xy',outline=None):
    outline=outline or [(-.50,-.22),(-.37,.36),(-.10,.5),(.34,.38),(.5,.02),(.23,-.34),(0,-.5),(-.28,-.37)]
    vertices=[]
    for z in (-d*.5,d*.5):
        for x,y in outline:
            a,b=x*w,y*h
            a,b=a*math.cos(angle)-b*math.sin(angle),a*math.sin(angle)+b*math.cos(angle)
            vertices.append(v((at[0]+a,at[1]+(b if plane=='xy' else z),at[2]+(z if plane=='xy' else b))))
    n=len(outline)
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT')
    return setup(o,name,m,.014)
def rod(name,a,b,r,m=steel):
    return cyl(name,tuple((x+y)/2 for x,y in zip(a,b)),r,math.dist(a,b),m,tuple(y-x for x,y in zip(a,b)),verts=12)
def ring(name,p,major,minor,m,axis=(0,0,1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=24,minor_segments=8,location=v(p))
    o=bpy.context.object;o.rotation_euler=v(axis).to_track_quat('Z','Y').to_euler()
    return setup(o,name,m)
def vents(at,w,h,count=4):
    for i in range(count):
        plate('Recessed heat exchanger',(at[0],at[1]+(i-(count-1)*.5)*h/count,at[2]),(w,h/count*.34,.017),black,.003)
def visor(at,w,h,c):
    outline=[(-.5,.33),(-.23,.18),(0,-.5),(.24,.18),(.5,.33),(.35,-.12),(0,-.7),(-.35,-.12)]
    panel('Visor dark inset',at,w*1.16,h*1.3,.038,black,outline=outline)
    panel('Recessed V optic',(at[0],at[1],at[2]+.025),w,h,.018,c,outline=outline)
def helmet(y,w,c):
    panel('Separate angular helmet',(0,y,0),w,.31,.31,white)
    panel('Navy crown',(0,y+.10,-.025),w*.65,.22,.33,blue)
    visor((0,y-.01,.174),w*.79,.078,c)
    panel('Face guard',(0,y-.105,.18),w*.43,.14,.07,steel)
    for side in (-1,1):
        panel('Helmet crest',(side*w*.35,y+.20,-.036),w*.26,.27,.10,blue,-side*.25)
        cyl('Ear bearing',(side*w*.5,y-.005,.012),.067,.047,steel,(1,0,0),verts=12)
def leg(side,hip=.18,large=False):
    begin=len(parts)
    x=side*hip;k=side*(hip+.025)
    joint((x,-.19,-.02),.078 if not large else .10)
    rod('Titanium thigh piston',(x,-.15,-.035),(k,-.345,.01),.053 if not large else .072)
    panel('Tapered thigh shield',(x,-.215,.09),.19 if not large else .25,.25,.09,blue,side*.1)
    joint((k,-.355,.025),.081 if not large else .10)
    for z in (-.05,.035):
        rod('Calf piston',(k+side*.055,-.36,z),(k+side*.07,-.55,z+.025),.022,accent_brass)
    panel('Greave armor',(k,-.46,.10),.205 if not large else .29,.31,.13,white,side*.12)
    plate('Greave energy inset',(k,-.49,.182),(.085 if not large else .15,.038,.018),pink if large else amber,.008)
    panel('Cleated armored foot',(k,-.60,.086),.28 if not large else .34,.39,.12,black,plane='xz',outline=[(-.5,-.4),(-.36,.42),(.34,.5),(.5,.3),(.5,-.36)])
    panel('Sloped toe',(k,-.555,.19),.25 if not large else .31,.22,.064,white,plane='xz')
    gaits.append(((x,-.13,0),parts[begin:]));del parts[begin:]
def rifle(x,y,z,c=amber):
    cyl('Barrel heat sleeve',(x,y,z),.119,.34,black,verts=16)
    for dz in (-.12,0,.13):
        ring('Machined barrel collar',(x,y,z+dz),.117,.018,edge)
    for side in (-1,1):
        panel('Barrel armor petal',(x+side*.08,y+.048,z),.13,.18,.32,blue,side*.18)
    cyl('Muzzle well',(x,y,z+.185),.105,.035,black,verts=16)
    ring('Muzzle lens ring',(x,y,z+.21),.064,.014,c)
    cyl('Bore',(x,y,z+.214),.046,.014,black,verts=16)
def sentinel():
    panel('Angular scout torso',(0,.12,0),.51,.42,.36,black)
    panel('Cuirass yoke',(0,.24,.20),.48,.22,.09,white)
    visor((0,.18,.255),.30,.055,amber)
    plate('Neck actuator',(0,.375,0),(.16,.12,.15),steel,.025)
    helmet(.53,.37,amber)
    panel('Pelvis armor',(0,-.115,.04),.34,.22,.29,blue)
    for side in (-1,1):
        x=side*.36
        joint((x,.25,0),.084)
        for i in range(2):
            panel('Overlapping swept shoulder',(x+side*i*.065,.32-i*.052,.015),.33,.24,.29,white if i==0 else blue,side*.33)
        rod('Arm actuator',(x,.20,0),(x+side*.05,.015,.025),.045)
        panel('Forearm guard',(x+side*.04,.005,.075),.20,.27,.20,blue,side*.12)
        if side<0:rifle(x+side*.04,-.045,.22)
        else:
            for f in range(3):
                rod('Articulated gripper',(x+(f-1)*.043,-.095,.08),(x+(f-1)*.043,-.205,.13),.020,steel)
        leg(side)
def crawler():
    panel('Sloped crawler body',(0,.09,0),.84,.94,.40,black,plane='xz')
    for side in (-1,1):
        panel('Layered beetle carapace',(side*.16,.28,-.025),.52,.83,.11,white,side*.16,plane='xz')
        panel('Swept cobalt shell',(side*.26,.20,-.10),.25,.65,.10,blue,side*.18,plane='xz')
        plate('Crawler eye',(side*.22,.14,.40),(.24,.046,.027),amber,.012,-side*.20)
        for z in (-.27,.25):
            begin=len(parts)
            a=(side*.35,-.04,z);b=(side*.55,-.25,z-.04);c=(side*.61,-.55,z+.10)
            joint(a,.086);joint(b,.078)
            rod('Crawler upper strut',a,b,.051,steel)
            rod('Crawler piston',(a[0],a[1]-.025,a[2]+.045),(b[0],b[1]+.025,b[2]+.045),.025,accent_brass)
            rod('Crawler lower strut',b,c,.040,black)
            panel('Swept crawler greave',(side*.59,-.39,z+.08),.16,.31,.16,white,side*.31)
            panel('Crawler cleat',(side*.61,-.59,z+.13),.25,.31,.085,black,plane='xz')
            plate('Crawler ankle light',(side*.61,-.55,z+.28),(.10,.022,.018),amber,.005)
            gaits.append((a,parts[begin:]));del parts[begin:]
    vents((0,.025,.473),.35,.10)
    panel('Nose wedge',(0,.10,.465),.25,.16,.055,blue)
def bulwark():
    panel('Reinforced heavy torso',(0,.16,0),.81,.60,.49,black)
    panel('Upper chest plating',(0,.38,.27),.65,.20,.10,white)
    cyl('Armored reactor bezel',(0,.15,.28),.22,.09,white,verts=12)
    ring('Reactor concentric ring',(0,.15,.34),.176,.027,edge)
    cyl('Reactor dark recess',(0,.15,.352),.145,.022,black,verts=16)
    cyl('Reactor lens',(0,.15,.371),.124,.022,pink,verts=16)
    for i in range(10):
        a=math.tau*i/10
        cyl('Reactor lock',(math.cos(a)*.197,.15+math.sin(a)*.197,.349),.015,.022,accent_brass,verts=6)
    helmet(.65,.34,pink)
    panel('Heavy pelvis',(0,-.15,.015),.46,.24,.35,steel)
    for side in (-1,1):
        x=side*.46
        joint((x,.26,-.02),.13)
        for i in range(3):
            panel('Heavy layered shoulder shield',(x+side*i*.056,.35-i*.10,.09),.37,.42,.37,white if i==0 else blue,side*.20)
        vents((x,.28,.31),.19,.13)
        rod('Heavy arm piston',(x,.20,0),(x+side*.025,-.04,.045),.067,steel)
        panel('Heavy fist housing',(x,-.105,.12),.25,.27,.25,blue)
        for i in range(3):
            cyl('Fist knuckle',(x+(i-1)*.064,-.20,.25),.028,.039,steel,verts=10)
        leg(side,.265,True)
def emplacement():
    panel('Turret hex anchor',(0,-.48,0),1.00,.82,.19,blue,plane='xz')
    for side in (-1,1):
        for z in (-.29,.29):
            a=(side*.25,-.35,z*.66);b=(side*.43,-.58,z)
            rod('Anchoring hydraulic',a,b,.040,accent_brass)
            panel('Splayed planted foot',(side*.43,-.59,z),.25,.25,.10,white,plane='xz')
    cyl('Rotating actuator',(0,-.235,0),.255,.26,steel,(0,1,0),verts=20)
    for i in range(3):ring('Turntable bearing',(0,-.315+i*.07,0),.25,.023,edge,(0,1,0))
    panel('Sloped rotating gun mantle',(0,.12,0),.83,.74,.42,black,plane='xz')
    for side in (-1,1):
        panel('Mantle armor petal',(side*.225,.31,-.015),.48,.66,.12,white,-side*.10,plane='xz')
        panel('Mantle side shield',(side*.38,.15,-.02),.12,.36,.55,blue)
        rifle(side*.22,.07,.40)
        plate('Mantle amber running light',(side*.438,.07,-.03),(.018,.057,.27),amber,.009)
    vents((0,.32,-.08),.18,.22)
def interceptor():
    panel('Pointed interceptor chassis',(0,.0,.09),.60,1.14,.31,black,plane='xz',outline=[(-.45,-.48),(.45,-.48),(.5,-.05),(.22,.36),(0,.61),(-.22,.36),(-.5,-.05)])
    for side in (-1,1):
        panel('Split arrow nose',(side*.12,.16,.18),.28,1.00,.08,white,-side*.09,plane='xz')
        panel('Swept dorsal vane',(side*.40,.28,-.24),.20,.40,.08,blue,-side*.35)
        x=side*.49
        cyl('Ducted fan housing',(x,.025,-.04),.238,.23,blue,verts=24)
        cyl('Fan inner darkness',(x,.025,.085),.199,.018,black,verts=24)
        ring('Intake lip',(x,.025,.106),.218,.026,white)
        ring('Turbine running light',(x,.025,.121),.192,.010,pink)
        for i in range(7):
            a=i*math.tau/7
            plate('Turbine impeller blade',(x+math.cos(a)*.115,.025+math.sin(a)*.115,.115),(.136,.039,.035),steel,.008,a+.42)
        cyl('Turbine hub',(x,.025,.14),.052,.049,edge,verts=12)
        cyl('Turbine hub lamp',(x,.025,.166),.023,.008,pink,verts=12)
        rod('Nacelle brace',(side*.20,.00,-.13),(x,.00,-.07),.042,steel)
    panel('Nose energy inset',(0,-.015,.595),.072,.18,.035,pink)
def collect(objects,parent):
    grouped={}
    for ob in objects:grouped.setdefault(ob.data.materials[0].name,[]).append(ob)
    bpy.context.view_layer.update()
    for bucket in grouped.values():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in bucket:ob.select_set(True)
        bpy.context.view_layer.objects.active=bucket[0]
        bpy.ops.object.join()
        ob=bpy.context.object;ob.parent=parent;ob.matrix_parent_inverse=parent.matrix_world.inverted()
for name,build in [('scout',sentinel),('quad',crawler),('heavy',bulwark),('turret',emplacement),('flyer',interceptor)]:
    parts.clear();gaits.clear();build()
    group=bpy.data.objects.new('Security_'+name,None);bpy.context.collection.objects.link(group)
    collect(parts,group)
    for index,(at,geometry) in enumerate(gaits):
        pivot=bpy.data.objects.new(f'Gait_{index}',None);bpy.context.collection.objects.link(pivot)
        pivot.parent=group;pivot.location=v(at)
        collect(geometry,pivot)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(dest/f'{name}.glb'),export_format='GLB',use_selection=True,export_image_format='JPEG',export_jpeg_quality=90)
    for ob in list(group.children_recursive)+[group]:bpy.data.objects.remove(ob,do_unlink=True)
