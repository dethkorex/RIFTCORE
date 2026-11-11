"""Bake the 40 sector enemy meshes and eight original boss assemblies into editable GLBs."""
import json,sys,math,bpy
from pathlib import Path
root=Path(sys.argv[-1])
source=root/'assets/enemies/build_security_redesign.py'
exec(compile(source.read_text(encoding='utf-8-sig').split("for name,build in [('scout',sentinel)")[0],str(source),'exec'))
campaign=root/'assets/campaign'
catalog=json.loads((campaign/'sector_plan.json').read_text())
POINT=[(-.48,.35),(-.20,.54),(.29,.44),(.51,.12),(.21,-.24),(0,-.62),(-.26,-.28)]
boss_colors={
3:(.12,.76,1),4:(1,.78,.08),5:(1,.53,.10),6:(.19,1,.61),
7:(.96,.12,.49),8:(.58,.28,1),9:(1,.38,.08),10:(1,.07,.40)}
cores={}
def lens(y,z,r,c):
    cyl('Machined reactor collar',(0,y,z),r*1.15,.135,white,verts=16)
    ring('Reactor retainer',(0,y,z+.079),r*.95,r*.11,edge)
    cyl('Reactor well',(0,y,z+.11),r*.83,.035,black,verts=20)
    cyl('Energy nucleus',(0,y,z+.145),r*.69,.052,c,r2=r*.51,verts=16)
    for i in range(12):
        a=math.tau*i/12
        cyl('Reactor collar bolt',(r*math.cos(a),y+r*math.sin(a),z+.122),r*.058,.045,accent_brass,verts=8)
def segment_chain(points,scale,light):
    for i,(a,b) in enumerate(zip(points,points[1:])):
        rod('Articulated hydraulic link',a,b,scale*.50,black)
        p=tuple((x+y)*.5 for x,y in zip(a,b))
        panel('Overlapping segment carapace',p,scale*1.9,scale*2.08,scale*1.35,white if i%2 else blue,angle=.18 if i%2 else -.16)
        cyl('Segment rotating hub',(b[0],b[1],b[2]+scale*.27),scale*.59,scale*.41,edge,verts=10)
        ring('Joint power collar',(b[0],b[1],b[2]+scale*.49),scale*.42,scale*.065,light)
def limb_slot(name,at):
    gaits.append((name,at,parts[:]))
    parts.clear()
def boss_leg(side,light,width=.52):
    x=side*.51
    for j in (-1,1):
        rod('Exposed thigh piston',(x+j*.11,1.47,-.04),(x+j*.11,.66,.025),.076,accent_brass)
    cyl('Gait pivot',(x,.75,.15),.235,.37,black)
    panel('Knee impact armor',(x,.81,.38),width,.48,.20,white,side*.18)
    panel('Shin carapace',(x,.42,.14),width*1.05,.68,.48,blue,-side*.1)
    for i in range(4):
        plate('Shin heat channel',(x,.28+i*.075,.405),(.24,.033,.021),light,.009)
    panel('Crampon foot',(x,.15,.19),width*1.22,.80,.23,black,plane='xz')
    for i in range(3):
        panel('Toe claw',(x+(i-1)*width*.34,.17,.55),width*.32,.32,.13,white,plane='xz')
    limb_slot('LegLeft' if side<0 else 'LegRight',(x,1.44,0))
def humanoid_boss(n,c):
    core_y=2.12 if n<10 else 2.38
    panel('Angular main chassis',(0,core_y,0),1.42,1.11,.78,black)
    panel('Collar armor',(0,core_y+.48,.36),1.26,.32,.21,white)
    lens(core_y,.43,.30 if n<10 else .34,c)
    helmet(core_y+.81,.60,c)
    for side in (-1,1):
        rod('Reactor conduit',(side*.42,core_y-.38,.39),(side*.58,core_y+.44,.29),.063,accent_brass)
        for j in range(4):
            plate('Flank radiator',(side*.54,core_y-.15+j*.083,.453),(.19,.033,.021),c,.007)
        if n==10:
            for i in range(3):
                panel('Integrated Nexus wing',(side*(1.1+i*.24),2.33-i*.34,-.32),.52,1.82,.22,white if i%2 else blue,side*(-.44-i*.16),outline=POINT)
                plate('Wing energy conduit',(side*(1.12+i*.22),2.20-i*.34,-.189),(.061,.89,.016),c,.008,-side*.54)
        elif n==3:
            cyl('Coolant pressure vessel',(side*.55,2.83,-.37),.24,.86,c,(0,1,0),verts=16)
            for dy in (-.41,.41):
                cyl('Pressure vessel end cap',(side*.55,2.83+dy,-.37),.28,.16,blue,(0,1,0),verts=10)
        else:
            ring('Scrap recovery coil',(side*.43,2.71,-.29),.25,.063,c)
            panel('Overlapped salvage shell',(side*.63,2.2,-.25),.48,.86,.22,white,side*.17)
    limb_slot('Body',(0,0,0))
    for side in (-1,1):
        boss_leg(side,c,.47 if n==10 else (.64 if n==9 else .54))
        x=side*1.02
        cyl('Shoulder pivot',(x,core_y+.39,0),.32,.54,black,(1,0,0),verts=12)
        for i in range(3):
            panel('Scalloped shoulder armor',(x+side*.07*i,core_y+.63-i*.13,.24),.69,.57,.53,white if i==0 else blue,side*.24)
        rod('Forearm piston',(x,core_y+.26,.06),(x+side*.18,core_y-.62,.14),.14,steel)
        if n==3 and side>0:
            panel('Cryogenic shield frame',(x+.27,1.57,.41),.82,1.69,.28,white,.13,outline=POINT)
            panel('Shield armored inner',(x+.27,1.62,.59),.63,1.27,.10,blue,.13,outline=POINT)
            for i in range(5):
                plate('Shield coolant radiator',(x+.27,1.28+i*.15,.66),(.34,.055,.018),c,.008)
        elif side<0:
            end=(x-.31,core_y-.78,.72)
            rod('Signature weapon sleeve',(x-.16,core_y-.31,.14),end,.25,blue)
            for j in range(3):
                cyl('Emitter barrel collar',(end[0],end[1],.23+j*.21),.255,.07,edge,verts=12)
            cyl('Focal lance',end,.19,.78,c,axis=(0,-.55,1),r2=.018,verts=8)
        else:
            for i in range(3):
                cyl('Repair clamp tooth',(x+.07+i*.15,core_y-.8,.39),.104,.52,white,(0,-1,.42),r2=.01)
        limb_slot('ArmLeft' if side<0 else 'ArmRight',(x,core_y+.40,0))
def kraken(c):
    cyl('Submersible mantle',(0,1.91,0),.91,.94,black,(0,1,0),r2=.65,verts=14)
    lens(1.94,.76,.36,c)
    for j in range(3):
        panel('Pressure crown',(0,2.54+j*.17,-.18),1.30-j*.34,.30,.66,blue if j%2 else white,outline=POINT)
    for side in (-1,1):
        cyl('Pressurized coolant canister',(side*.73,2.50,-.34),.18,.78,c,(0,1,0),verts=10)
        panel('Mantle armored cheek',(side*.63,1.92,.38),.55,.85,.42,blue,side*.23)
    limb_slot('Body',(0,0,0))
    for side in (-1,1):
        segment_chain([(side*.70,1.82,0),(side*1.12,1.51,.09),(side*1.49,1.72,.18),(side*1.72,2.19,.24),(side*2.04,2.42,.31)],.27,c)
        for i in (-1,1):
            cyl('Coil claw tip',(side*2.08+i*.16,2.20,.34),.12,.48,white,(i*.44,-1,0),r2=.006)
        limb_slot('ArmLeft' if side<0 else 'ArmRight',(side*.73,1.82,0))
        for z in (-.38,.46):
            segment_chain([(side*.64,1.56,z),(side*1.12,1.15,z),(side*1.47,.73,z),(side*1.66,.25,z)],.23,c)
            panel('Pressure foot',(side*1.67,.14,z),.52,.55,.25,white,plane='xz')
        limb_slot('LegLeft' if side<0 else 'LegRight',(side*.63,1.56,0))
def cipher(c):
    cyl('Antigravity plinth',(0,.41,0),.78,.33,black,(0,1,0),r2=.98,verts=12)
    ring('Hover thrust ring',(0,.27,0),.66,.075,c,(0,1,0))
    panel('Archive guardian chassis',(0,1.75,0),1.28,1.56,.62,black)
    lens(1.83,.37,.26,c)
    helmet(2.78,.63,c)
    for side in (-1,1):
        for i in range(4):
            panel('Layered sandstone cloak',(side*(.50+i*.17),1.94-i*.27,.11-i*.043),.66,1.18,.18,white if i%2==0 else blue,side*.30,outline=POINT)
            plate('Inlaid glyph rail',(side*(.51+i*.17),1.83-i*.27,.25-i*.04),(.19,.040,.018),c,.007)
    limb_slot('Body',(0,0,0))
    for side in (-1,1):
        segment_chain([(side*.72,2.36,0),(side*1.05,2.21,.12),(side*1.28,1.86,.22),(side*1.54,1.57,.35)],.22,c)
        panel('Cipher lance blade',(side*1.61,1.25,.45),.35,.87,.12,c,side*.38,outline=POINT)
        limb_slot('ArmLeft' if side<0 else 'ArmRight',(side*.72,2.36,0))
def wyrm(c):
    points=[(-1.50,.55,-.4),(-.9,.64,-.35),(-.35,.88,-.27),(.06,1.22,-.12),(.29,1.64,.04),(.25,2.04,.20),(.02,2.45,.40),(-.24,2.69,.57)]
    segment_chain(points,.26,c)
    panel('Aerodynamic dragon head',(-.28,2.73,.61),.69,.50,.56,white,outline=POINT)
    visor((-.28,2.71,.94),.50,.085,c)
    for side in (-1,1):
        panel('Raked brow fin',(-.28+side*.29,2.94,.59),.21,.49,.16,blue,side*.39,outline=POINT)
    limb_slot('Body',(0,0,0))
    for side in (-1,1):
        x=side*.93
        rod('Wing mounting strut',(0,2.1,.21),(x,2.22,.14),.14,steel)
        ring('Ducted fan shell',(x,2.22,.13),.33,.10,white)
        ring('Ducted fan light',(x,2.22,.229),.30,.033,c)
        for i in range(7):
            a=i*math.tau/7
            plate('Impeller',(x+math.cos(a)*.18,2.22+math.sin(a)*.18,.16),(.23,.067,.05),blue,.012,a)
        panel('Swept foil',(side*1.36,2.33,-.03),1.04,.47,.21,blue,-side*.21,outline=POINT)
        limb_slot('ArmLeft' if side<0 else 'ArmRight',(side*.30,2.10,.19))
def chimera(c):
    panel('Chimera dorsal frame',(0,1.37,-.14),1.65,1.63,.73,black,plane='xz')
    panel('Wedge beast skull',(0,1.64,.64),1.05,.61,.65,white,outline=POINT)
    visor((0,1.64,1.00),.71,.115,c)
    for x in (-.52,0,.52):
        cyl('Mutation reservoir',(x,2.05,-.42),.23,.69,c,(0,1,0),verts=12)
        for dy in (-.34,.34):
            cyl('Reservoir clamp',(x,2.05+dy,-.42),.27,.135,blue,(0,1,0),verts=10)
    limb_slot('Body',(0,0,0))
    for side in (-1,1):
        for z in (-.51,.53):
            segment_chain([(side*.60,1.40,z),(side*.93,1.05,z),(side*1.23,.48,z+.19),(side*1.31,.18,z+.28)],.26,c)
            for j in (-1,0,1):
                cyl('Armored claw',(side*1.31+j*.15,.19,z+.46),.105,.39,white,(0,-.48,1),r2=.006)
        limb_slot('LegLeft' if side<0 else 'LegRight',(side*.60,1.40,0))
        segment_chain([(side*.54,1.65,-.40),(side*1.12,2.04,-.29),(side*1.44,2.23,.18)],.22,c)
        cyl('Mutation barrel',(side*1.44,2.22,.37),.22,.48,blue)
        ring('Mutation aperture',(side*1.44,2.22,.65),.163,.035,c)
        limb_slot('ArmLeft' if side<0 else 'ArmRight',(side*.55,1.65,-.40))
def nova(c):
    lens(1.76,.42,.32,c)
    for r,z in [(1.18,-.05),(.84,.15),(.55,.28)]:
        ring('Armored orbital ring',(0,1.76,z),r,.10 if r>1 else .061,blue)
        ring('Inner orbital conductor',(0,1.76,z+.075),r*.96,.023,c)
        for i in range(8):
            a=i*math.tau/8
            panel('Solar gimbal guard',(r*math.cos(a),1.76+r*math.sin(a),z+.12),.36,.22,.20,white,a+math.pi/2)
    for i in range(6):
        a=i*math.tau/6
        x,y=math.cos(a),math.sin(a)
        rod('Solar arm',(x*1.03,1.76+y*1.03,-.02),(x*1.62,1.76+y*1.62,-.07),.059,steel)
        panel('Solar leaf',(x*1.55,1.76+y*1.55,-.074),.54,.27,.10,blue,a,outline=POINT)
    limb_slot('Rotor',(0,1.76,0))
def export(name,folder,boss=False):
    top=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(top)
    collect(parts,top)
    for index,record in enumerate(gaits):
        if boss:
            label,at,objects=record
        else:
            at,objects=record
            label=f'Gait_{index}'
        pivot=bpy.data.objects.new(label,None);bpy.context.collection.objects.link(pivot)
        pivot.parent=top;pivot.location=v(at);collect(objects,pivot)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in [top]+list(top.children_recursive):ob.select_set(True)
    folder.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(folder/f'{name}.glb'),export_format='GLB',use_selection=True,export_image_format='JPEG',export_jpeg_quality=88)
    for ob in list(top.children_recursive)+[top]:bpy.data.objects.remove(ob,do_unlink=True)
for info in catalog[2:]:
    n=info['number']; folder=campaign/info['id']; atlas_new=bpy.data.images.load(str(folder/'trim.png'),check_existing=True)
    for material in [white,blue,steel,hazard]:
        for node in material[0].node_tree.nodes:
            if node.type=='TEX_IMAGE':node.image=atlas_new
    tint=boss_colors[n]; light=mat(info['boss']+' energy',tint,None,1.6)
    for lamp in [amber,pink,hot]:
        bs=lamp[0].node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value=(*tint,1);bs.inputs['Emission Color'].default_value=(*tint,1)
    for index,(role,model) in enumerate([('scout',sentinel),('quad',crawler),('heavy',bulwark),('turret',emplacement),('flyer',interceptor)]):
        parts.clear();gaits.clear();model()
        y=[.24,.27,.31,.32,.16][index]
        for side in (-1,1):
            at=(side*(.28+index*.025),y,-.26)
            if n in [3,4,7]:
                cyl('Biome pressure capsule',at,.077,.27 if n!=7 else .39,light,(0,1,0),verts=10)
                cyl('Pressure capsule retainer',(at[0],at[1]+.15,at[2]),.093,.055,steel,(0,1,0),verts=8)
            elif n in [6,8,10]:
                panel('Biome swept fin',(at[0],at[1]+.12,at[2]),.22,.41,.094,blue,side*.40,outline=POINT)
                plate('Fin light strip',(at[0],at[1]+.17,at[2]+.057),(.035,.13,.018),light,.004,side*.34)
            else:
                panel('Biome overlapped shell',(at[0],at[1]-.02,at[2]+.07),.24,.29,.13,white,side*.23,outline=POINT)
                ring('Reinforced actuator coil',(at[0],at[1],at[2]+.103),.075,.015,light)
        export(role,folder/'enemies')
    parts.clear();gaits.clear()
    if n in [3,9,10]:humanoid_boss(n,light)
    else:{4:kraken,5:cipher,6:wyrm,7:chimera,8:nova}[n](light)
    export(info['boss_slug'],folder/'enemies',True)
    print('SECTOR_ASSETS_OK',info['id'])
