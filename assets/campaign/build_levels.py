"""Build the editable sectors 03-10 from authored routes and modular biome kits."""
from pathlib import Path
import json,math,re,sys
ROOT=Path(sys.argv[-1])
CAM=ROOT/'assets/campaign'
catalog=json.loads((CAM/'sector_plan.json').read_text())
module_source=ROOT/'assets/machine_jungle/build_jungle_terrain.py'
env={"__file__":str(module_source)}
exec(compile(module_source.read_text().split("for name, tint, band in")[0],str(module_source),'exec'),env)
Module=env['Module']
# Center x : deck top : width : optional p=phase / m=moving / c=one way.
ROUTES={
3:"0:0:8 8:0:8 17:.55:8 27:1.3:6 37:2.15:8 47:1.85:6 57:2.6:7 67:3.9:5 77:4.75:7 87:3.55:7 96:2.75:4:m 105:4.9:7 115:4.4:8 125:3.4:6 136:2:8 146:2.8:6 155:4.15:6 166:5.25:8 176:4.4:6 186:3.2:8 196:1.65:7 205:1.25:7 215:.5:8 225:.5:8",
4:"0:0:8 8:0:8 17:.45:7 27:1.1:7 36:.7:8 45:0:8 54:-1.35:8 66:-1.70:8 78:-1.4:8 90:-1.55:8 102:-1.15:8 111:.2:6 119:1.15:7 129:2.55:7 139:3.35:6 150:2.25:8 161:1.55:7 171:.25:8 180:.25:6 190:1.65:8 201:2.55:7 212:1.30:8 222:.6:8 232:.6:8",
5:"0:0:8 8:0:8 18:1.05:7 29:2.15:8 39:2.85:7 48:3.6:5 57:3.85:4:p 65:4.65:4:p 73:3.2:7 83:1.65:8 93:.6:7 102:.6:8 112:1.25:8 122:2.7:6 131:3.4:4:m 141:4.75:6 150:5.65:8 160:4.15:5:p 170:3.25:7 182:2.15:8 192:2.85:6 202:1.55:8 213:.75:8 223:.75:8",
6:"0:1:8 8:1:8 18:1.8:7 29:2.6:8 41:3.3:7 51:5.1:6 63:6.55:7 74:5.6:6 87:4.95:8 99:4.05:8 109:3.4:4:m 120:5.45:8 131:6.1:7 143:7.65:8 154:6.8:6 166:5.4:8 177:4.15:7 187:4.9:5:c 198:3.7:8 208:2.6:7 218:1.5:8 228:1.5:8",
7:"0:0:8 8:0:8 18:.85:8 29:1.75:8 38:2.85:6 49:3.65:7 60:2.55:8 70:1.25:8 79:1.25:6 89:2.6:7 100:4.1:7 111:5.35:8 121:4.35:6 132:3.45:8 142:2.55:7 153:1.35:8 164:1.35:7 174:2.75:8 185:4.0:7 195:3.15:6 206:2.45:8 217:1.25:8 227:.75:8 237:.75:8",
8:"0:0:8 8:0:8 18:1:7 30:2.6:8 44:4.4:6 58:5.65:6 72:6.3:7 84:5.5:7 96:4.2:8 107:3.2:7 117:2.45:8 128:3.45:6 141:5.25:7 155:6.8:7 170:6.4:8 184:5.1:7 195:3.75:7 207:2.4:8 218:1.1:8 229:1.1:8",
9:"0:0:8 8:0:8 17:.5:8 27:1.3:8 37:2.2:7 47:2.2:8 57:3.2:7 67:4.45:7 77:5.25:8 88:4.55:6 99:3.25:8 109:2.4:8 120:1.25:8 130:1.25:7 140:2.45:8 150:3.55:6 160:4.4:7 171:5.15:8 182:4.2:7 194:3.1:8 204:1.9:8 215:1.1:7 225:.55:8 235:.55:8",
10:"0:0:8 8:0:8 19:.95:8 31:2.25:8 42:3.6:7 52:4.45:6 63:5.15:7 74:5.45:6:p 84:4.4:8 95:3.45:7 107:2.5:8 118:1.45:8 129:1.45:7 140:2.8:7 151:4.1:7 162:5.25:8 174:6.2:7 185:5.0:6:p 195:4.0:8 206:2.55:8 217:3.25:7 228:2.10:8 238:1.15:8 248:.5:8 258:.5:8",
}
# kind, center x, lower y, width, height, flow; second half offsets stagger the hazards.
ZONES={
3:[(0,17,.54,6,1.6,0),(0,37,2.14,6,1.7,0),(4,58,2.6,2.0,1.25,0),(0,79,4.74,4.4,1.65,0),(4,137,2,2.3,1.43,0),(0,168,5.24,4.8,1.4,0),(4,204,1.25,2.3,1.41,0)],
4:[(1,77,-2.8,67,7.0,1),(5,66,-1.7,2.5,1.9,0),(5,103,-1.15,2.35,1.6,0),(1,142,-.5,29,5.8,-1),(5,171,.25,2.1,1.2,0),(5,190,1.65,3.1,1.4,0),(5,212,1.3,2.25,1.3,0)],
5:[(6,47,3.6,2.1,2.1,1),(6,113,1.25,2.0,2.3,1),(2,137,1.8,14,5.8,-1),(6,152,5.65,1.6,2.3,1),(5,183,2.15,2.3,1.4,0),(6,202,1.55,2,2.4,1)],
6:[(2,34,1.35,27,7,1),(6,41,3.3,2.1,3.1,1),(2,68,3.1,31,6.2,1),(6,100,4.05,2.2,3.0,1),(2,140,3.9,31,6.5,-1),(6,176,4.15,2.3,2.5,1),(2,191,2.2,25,7.0,1)],
7:[(7,20,.85,2.4,1.9,0),(6,49,3.65,2.3,2.5,1),(7,71,1.25,2.8,1.4,0),(6,90,2.60,2.2,2.8,1),(7,131,3.45,2.4,2.1,0),(7,164,1.35,3.0,2.2,0),(6,185,4.0,2.2,2.5,1),(7,217,1.25,2.5,1.8,0)],
8:[(3,56,-2.4,71,14.4,0),(8,44,4.4,2.25,4.0,0),(8,83,5.5,2.5,4.5,0),(3,152,-1.9,75,16.0,0),(8,143,5.25,2.4,4.2,0),(8,171,6.4,2.25,4.6,0),(8,207,2.4,2.9,3.9,0)],
9:[(2,31,-.1,26,6.2,-1),(9,46,2.2,2.5,2.2,0),(9,76,5.25,2.6,2.4,0),(2,94,1.8,32,7.5,1),(9,130,1.25,2.2,2.4,0),(9,160,4.4,2.7,2.5,0),(2,186,.8,28,7.4,-1),(9,214,1.1,2.6,2.4,0)],
10:[(10,20,.95,2.5,2.3,0),(10,43,3.6,3.1,2.5,0),(2,70,3.15,22,6.8,-1),(10,86,4.4,2.6,2.0,0),(10,108,2.5,2.3,2.3,0),(3,149,0,35,11,0),(10,152,4.1,2.5,2.5,0),(10,194,4,2.5,2.2,0),(9,216,3.25,2.7,2.5,0),(10,238,1.15,3.0,2.4,0)],
}
ARENAS={
3:[(7,2.65,5),(21,5.1,5),(34,2.75,5)],
4:[(8,4.25,6),(20,3.10,4),(35,4.75,6)],
5:[(8,2.75,5),(19,4.65,4),(29,3.80,4),(40,2.65,5)],
6:[(7,3.6,4),(16,5.15,5),(27,6.5,5),(39,4.1,5)],
7:[(8,2.45,6),(24,4.75,6),(39,3.15,5)],
8:[(7,4.2,5),(20,2.75,4),(31,5.2,5),(41,3.4,5)],
9:[(6,2.8,6),(23,4.45,5),(38,3.55,6)],
10:[(7,3.05,5),(18,4.3,4),(29,6.0,5),(42,3.15,6)],
}
def v(*p):return "Vector3("+", ".join(f"{x:.6g}" for x in p)+")"
def tint(hex):
    return tuple(int(hex[i:i+2],16)/255 for i in (0,2,4))
def rgb(c,alpha=1):return 'Color('+', '.join(f'{x:.4f}' for x in (*c,alpha))+')'
def make_kit(info):
    kit=CAM/info['id']; n=info['number']
    folder=kit/'terrain'; folder.mkdir(parents=True,exist_ok=True)
    env['BASE']=f"res://assets/campaign/{info['id']}";env['HERE']=kit
    c=tint(info['color'])
    for j,(name,col) in enumerate([('stone',(.48,.53,.60)),('fern',tuple(a*.26 for a in c)),('tread',(.075,.09,.135)),('poison',c)]):
        (kit/(name+'.tres')).write_text(f'''[gd_resource type="ShaderMaterial" format=3]
[ext_resource type="Shader" path="res://assets/neon_factory/platform_finish.gdshader" id="shader"]
[ext_resource type="Texture2D" path="{env['BASE']}/trim.png" id="trim"]
[resource]
shader = ExtResource("shader")
shader_parameter/atlas = ExtResource("trim")
shader_parameter/tint = {rgb(col)}
shader_parameter/band = {j}.0
shader_parameter/texture_mix = 0.78
''')
    (kit/'jade.tres').write_text(f'''[gd_resource type="StandardMaterial3D" format=3]
[resource]
albedo_color = {rgb(c)}
emission_enabled = true
emission = {rgb(c)}
emission_energy_multiplier = 1.45
roughness = 0.38
''')
    for id,w,h,depth,one in [('deck',8,.38,2.15,False),('perch',4,.24,1.88,True),('wall',.48,3.5,1.86,False)]:
        m=Module(info['boss_node']+id.capitalize(),"StaticBody3D",one)
        if id=='wall':
            m.collider((0,0,0),(w,h,depth))
            m.mesh((0,0,0),(w*.95,h,depth*.98),'tread')
            for y in [-1.25,-.43,.43,1.25]:
                m.mesh((0,y,.94),(.51,.63,.071),'fern')
                m.mesh((0,y,.99),(.10,.33,.021),'jade')
            for y in [-1.66,1.66]:m.mesh((0,y,0),(.52,.18,1.93),'stone')
        else:
            m.collider((0,-h/2,0),(w,h,depth))
            m.mesh((0,-h/2,0),(w-.008,h-.008,depth-.012),'tread')
            for k in range(4 if w>5 else 2):
                x=(k+.5)/(4 if w>5 else 2)*w-w/2
                m.mesh((x,-.037,0),(w/(4 if w>5 else 2)-.035,.074,depth*.89),'fern')
                m.mesh((x,-h*.53,depth/2+.028),(w*.154,.067,.042),'jade')
                m.mesh((x,-h*.57,depth/2+.015),(w*.207,.141,.033),'stone')
            for side in [-1,1]:
                m.mesh((side*(w/2-.12),-h/2,0),(.22,h,depth),'stone')
        m.save(id)
    for name,fromid,body,extra in [('lift','perch','AnimatableBody3D','script = ExtResource("motion")\ntravel = 2.3\nhorizontal_travel = 0.65\nseconds_per_leg = 2.4'),('phase','perch','StaticBody3D','script = ExtResource("motion")')]:
        s=(folder/(fromid+'.tscn')).read_text()
        script='factory_lift' if name=='lift' else 'phase_platform'
        s=s.replace('[sub_resource type="',f'[ext_resource type="Script" path="res://scripts/{script}.gd" id="motion"]\n\n[sub_resource type="',1)
        s=re.sub(r'\[node name="[^"]+" type="StaticBody3D"[^\n]*\]',f'[node name="{name.capitalize()}" type="{body}"'+(' groups=["factory_one_way"]' if name=='phase' else '')+']\n'+extra,s,count=1)
        (folder/(name+'.tscn')).write_text(s.rstrip()+'\n')
    for name in ['relay','gate','arch']:
        m=Module(info['boss_node']+name.capitalize())
        if name=='relay':
            m.mesh((0,.25,0),(1.15,.5,1.04),'tread')
            m.rod((0,1.55,0),.40,2.25,'fern')
            m.rod((0,2.38,0),.43,.26,'stone')
            m.rod((0,1.55,.28),.13,1.35,'jade')
            for side in (-1,1):m.rod((side*.46,1.12,.01),.12,1.76,'stone',side*.22)
        elif name=='gate':
            m.mesh((0,1.86,0),(3.10,3.72,.47),'fern')
            m.mesh((0,.29,.26),(2.90,.37,.08),'poison')
            for side in (-1,1):m.mesh((side*.93,1.98,.27),(.09,2.19,.03),'jade')
            m.mesh((0,2.94,.27),(1.26,.21,.045),'stone')
        else:
            for side in (-1,1):
                m.mesh((side*1.64,2,0),(.49,4,.68),'tread')
                m.mesh((side*1.64,1.93,.36),(.095,2.91,.038),'jade')
            m.mesh((0,3.99,0),(3.77,.50,.69),'stone')
            m.mesh((0,3.86,.39),(2.76,.09,.051),'jade')
        m.save(name)
    for p in folder.glob('*.tscn'):
        s=p.read_text()
        s=s.replace('[sub_resource type="','[ext_resource type="Script" path="res://scripts/biome_mesh_finish.gd" id="finish"]\n\n[sub_resource type="',1)
        if 'id="finish"' not in s:s=s.replace('[node name=', '[ext_resource type="Script" path="res://scripts/biome_mesh_finish.gd" id="finish"]\n\n[node name=',1)
        s=s.rstrip()+'''\n\n[node name="BevelFinish" type="Node3D" parent="."]
script = ExtResource("finish")
'''
        p.write_text(s)
    for i,role in enumerate(['scout','quad','heavy','turret','flyer']):
        (kit/'enemies'/f'{role}.tscn').write_text(f'''[gd_scene format=3]
[ext_resource type="Script" path="res://scripts/enemy.gd" id="enemy"]
[ext_resource type="PackedScene" path="{env['BASE']}/enemies/{role}.glb" id="model"]
[node name="{info['enemies'][i].replace(' ','')}" type="CharacterBody3D" groups=["damageable_enemies"]]
script = ExtResource("enemy")
variant = {i}
model_override = ExtResource("model")
fire_weakness = {1.4 if n==3 else 1.0}
weakness_weapon = "{info['weak']}"
weapon_weakness = 1.4
''')
    (ROOT/'scenes/levels'/f"{info['boss_slug']}.tscn").write_text(f'''[gd_scene format=3]
[ext_resource type="Script" path="res://scripts/campaign_boss.gd" id="boss"]
[ext_resource type="PackedScene" path="{env['BASE']}/enemies/{info['boss_slug']}.glb" id="model"]
[ext_resource type="PackedScene" path="{env['BASE']}/enemies/flyer.tscn" id="minion"]
[sub_resource type="BoxShape3D" id="Hull"]
size = Vector3({2.4 if n in [4,7,8] else 2.12}, 3.10, 1.25)
[node name="{info['boss_node']}" type="CharacterBody3D" groups=["damageable_enemies"]]
script = ExtResource("boss")
sector_number = {n}
accent = {rgb(c)}
max_health = {float(info['health'])}
minion_scene = ExtResource("minion")
fire_weakness = {1.55 if n==3 else 1.0}
weakness_weapon = "{info['weak']}"
weapon_weakness = 1.48
[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("Hull")
[node name="Armor" type="Node3D" parent="."]
position = Vector3(0, -1.55, 0)
rotation = Vector3(0, -1.04, 0)
[node name="Model" parent="Armor" instance=ExtResource("model")]
''')
def make_level(info):
    n=info['number'];id=info['id'];prefix=f'assets/campaign/{id}';c=tint(info['color'])
    route=[]
    for row in ROUTES[n].split():
        x,y,w,*kind=row.split(':'); route.append((float(x),float(y),float(w),{'p':'phase','m':'lift','c':'perch'}.get(kind[0],'deck') if kind else 'deck'))
    x0,y0,w0,_=route[-1]
    hall=x0+w0/2; fy=y0; gate=hall+8.2; arena=46.0 if n<8 else 50.0; end=gate+arena
    refs={}
    def ext(key,path,typ='PackedScene'):refs[key]=(path,typ)
    for key in ['deck','perch','wall','lift','phase','relay','gate','arch']:ext(key,f'{prefix}/terrain/{key}.tscn')
    for key in ['scout','quad','heavy','turret','flyer']:ext(key,f'{prefix}/enemies/{key}.tscn')
    for key in ['health_large','energy_large','energy_small','xp_orb','extra_life']:ext(key,'assets/pickups/'+key+'.tscn')
    for key in ['checkpoint_beacon','deployment_pad','extraction_pad']:ext(key,'assets/neon_factory/'+key+'.tscn')
    for key in ['camera_rig','jungle_backdrop','factory_checkpoint','factory_ladder','forge_safe_hall','biome_zone']:ext(key,'scripts/'+key+'.gd','Script')
    ext('panorama',prefix+'/panorama.png','Texture2D')
    ext('player','scenes/actors/riftcore_player.tscn')
    ext('boss',f"scenes/levels/{info['boss_slug']}.tscn")
    out=['[gd_scene format=3]']
    out.extend(f'[ext_resource type="{ty}" path="res://{path}" id="{key}"]' for key,(path,ty) in refs.items())
    for key,size in [('Checkpoint',(2.1,1.9,1.8)),('GateBlocker',(.66,6.7,3.2)),('HallShield',(5.7,4.2,2.8)),('ArenaFloor',(end+2.3-hall,.38,2.15))]:
        out.append(f'[sub_resource type="BoxShape3D" id="{key}"]\nsize = {v(*size)}')
    bg=tuple(a*.06 for a in c)
    out.append(f'''[sub_resource type="Environment" id="Backdrop"]
background_mode = 1
background_color = {rgb(bg)}
ambient_light_source = 3
ambient_light_color = {rgb(tuple(.64+a*.26 for a in c))}
ambient_light_energy = 0.91
tonemap_mode = 2
[node name="{info['boss_node']}Sector" type="Node3D"]''')
    def node(name,type,parent='.',props='',group=''):
        g=f' groups=["{group}"]' if group else ''
        out.append(f'[node name="{name}" type="{type}" parent="{parent}"{g}]\n'+props)
    def instance(name,key,xyz,parent='TERRAIN',props='',group=''):
        g=f' groups=["{group}"]' if group else ''
        out.append(f'[node name="{name}" parent="{parent}"{g} instance=ExtResource("{key}")]\nposition = {v(*xyz)}\n'+props)
    def label(name,text,x,y):
        node(name,'Label3D','DECOR',f'position = {v(x,y,-1.42)}\ntext = "{text}"\npixel_size = 0.0041\nfont_size = 45\nmodulate = {rgb(c)}')
    def checkpoint(name,x,y):
        node(name,'Area3D','TERRAIN',f'position = {v(x,y,0)}\ncollision_layer = 0\nscript = ExtResource("factory_checkpoint")')
        parent='TERRAIN/'+name
        node('Trigger','CollisionShape3D',parent,'position = Vector3(0, 0.95, 0)\nshape = SubResource("Checkpoint")')
        instance('Beacon','checkpoint_beacon',(0,0,-.72),parent)
        node('Status','Label3D',parent,f'position = {v(0,1.46,-.64)}\npixel_size = 0.0044\nfont_size = 43\nmodulate = {rgb(c)}\ntext = "CHECKPOINT"')
    def zone(name,kind,x,y,w,h,direction):
        node(name,'Area3D','TERRAIN',f'position = {v(x,y+h/2,0)}\nscript = ExtResource("biome_zone")\nkind = {kind}\ndimensions = {v(w,h,2.18)}\ntint = {rgb(c)}\ndirection = {float(direction)}\noffset = {(x*.19)%4:.4f}\npower = {17+n*1.35:.4f}')
    node('WorldEnvironment','WorldEnvironment',props='environment = SubResource("Backdrop")')
    node('KeyLight','DirectionalLight3D',props=f'rotation = {v(-.77,-.65,0)}\nlight_energy = 1.55\nlight_color = {rgb(tuple(.76+a*.24 for a in c))}\nshadow_enabled = true')
    node('Parallax','Node3D',props='script = ExtResource("jungle_backdrop")\npanorama_texture = ExtResource("panorama")')
    node('TERRAIN','Node3D');node('DECOR','Node3D')
    for i,(x,y,w,kind) in enumerate(route):
        props='scale = '+v(w/(8 if kind=='deck' else 4),1,1)
        if kind=='phase':props+=f'\nphase_offset = {float(i%3)*.78}'
        instance(f'RouteDeck{i:02}',kind,(x,y,0),props=props)
        if i%3==1:instance(f'MidgroundRelay{i}','relay',(x+1,y,-2.95),'DECOR',props='scale = '+v(1.05,1.4+(i%4)*.28,1.05))
        if i%6==2:instance(f'MidgroundFrame{i}','arch',(x,y,-4.4),'DECOR',props='scale = '+v(1.43,1.55,1.4))
    checkpoint_index=min(range(2,len(route)-3), key=lambda i:abs(route[i][0]-hall*.51)+(25 if route[i][3]!='deck' or any(abs(route[i][0]-z[1])<3 and z[0]>=4 for z in ZONES[n]) else 0))
    mid=route[checkpoint_index];checkpoint('MidpointCheckpoint',mid[0],mid[1])
    checkpoint('ForgeHallCheckpoint',hall+6.1,fy)
    instance('HallFullHeal','health_large',(hall+3.8,fy+.45,0),props='full_heal = true')
    for i,(kind,x,y,w,h,direction) in enumerate(ZONES[n]):zone(f'BiomeGimmick{i:02}',kind,x,y,w,h,direction)
    for i in [2,7,checkpoint_index+2,len(route)-3]:
        x,y,w,k=route[i]
        if k in ['phase','lift']:continue
        instance(f'Reserve{i}','energy_large',(x-1.05,y+.38,0))
    for i in [4,checkpoint_index+4,len(route)-5]:
        x,y,w,k=route[i]
        instance(f'CacheLedge{i}','perch',(x+1.4,y+1.85,0))
        instance('InspectionExtraLife' if i==checkpoint_index+4 else f'XPReserve{i}','extra_life' if i==checkpoint_index+4 else 'xp_orb',(x+1.4,y+2.26,0),props='' if i==checkpoint_index+4 else 'large = true\nxp_amount = 60')
    if n in [5,10]:
        for i,(x,y,w,k) in enumerate(route):
            if k=='phase':instance(f'PhaseSafetyShelf{i}','perch',(x,y-2.1,0),props='scale = '+v(1.16,1,1))
    if n==4:
        for i in [6,7,8,9]:
            x,y,w,k=route[i]
            instance(f'AirPocket{i}','perch',(x+1.4,1.8+(i%3)*.37,0))
    if n==6:
        for i in [5,8,15]:
            x,y,w,k=route[i]
            instance(f'WindRest{i}','perch',(x+2.5,y-1.65,0))
    for i,(px,py,pw) in enumerate(ARENAS[n]):
        instance(f'ArenaPerch{i}','perch',(gate+px,fy+py,0),props='scale = '+v(pw/4,1,1))
        if i in [0,1,2]:
            node(f'ArenaClimb{i}','Node3D','TERRAIN',f'position = {v(gate+px,fy,0)}\nscript = ExtResource("factory_ladder")\nrise = {py}','factory_ladder')
    p=hall
    i=0
    while p<end+2.3-.01:
        width=min(8,end+2.3-p)
        instance(f'DuelFloor{i}','deck',(p+width/2,fy,0),props='collision_layer = 0\nscale = '+v(width/8,1,1))
        i+=1;p+=width
    node('ArenaUnifiedFloor','StaticBody3D',props=f'position = {v((hall+end+2.3)/2,fy-.19,0)}')
    node('Collider','CollisionShape3D','ArenaUnifiedFloor','shape = SubResource("ArenaFloor")')
    for parent,x in [('ForgeHallDoor',hall+.35),('Gate',gate)]:
        props=f'position = {v(x,fy,0)}'
        if parent=='ForgeHallDoor':props+='\nscript = ExtResource("forge_safe_hall")'
        node(parent,'Node3D',props=props)
        instance('Door','gate',(0,0,0),parent,props='rotation = Vector3(0, 1.5707963, 0)\nscale = Vector3(0.79, 1, 1)')
        instance('PortalFrame','arch',(0,0,0),parent,props='rotation = Vector3(0, 1.5707963, 0)\nscale = Vector3(0.84, 1, 1)')
        node('Blocker','StaticBody3D',parent)
        node('CollisionShape3D','CollisionShape3D',parent+'/Blocker','position = Vector3(0, 3.2, 0)\nshape = SubResource("GateBlocker")')
    node('Shield','Area3D','ForgeHallDoor','position = Vector3(3.56, 1.75, 0)\ncollision_layer = 0')
    node('Shape','CollisionShape3D','ForgeHallDoor/Shield','shape = SubResource("HallShield")')
    node('ExitBarrier','StaticBody3D',props='position = '+v(end,fy,0))
    instance('Seal','gate',(0,0,0),'ExitBarrier',props='rotation = Vector3(0, -1.5707963, 0)\nscale = Vector3(0.82, 1, 1)')
    node('CollisionShape3D','CollisionShape3D','ExitBarrier','position = Vector3(0, 3.2, 0)\nshape = SubResource("GateBlocker")')
    for j in range(3):instance(f'ArenaMachine{j}','relay',(gate+7+j*15,fy,-3.0),'DECOR',props='scale = '+v(1.6,2.15+j*.16,1.4))
    label('SectorSign',f'{n:02d}  /  {info["title"].upper()}',3,2.65)
    label('GimmickHint',info['gimmick'].upper(),17,3.9)
    label('RepairBay','REPAIR BAY  /  CHECKPOINT',hall+5,fy+3.05)
    label('ArenaName',info['boss'].upper(),gate+arena*.50,fy+7.85)
    node('MARKERS','Node3D')
    node('PlayerSpawn','Marker3D','MARKERS','position = '+v(0,route[0][1]+.905,0))
    node('RoomExit','Marker3D','MARKERS','position = '+v(end+1.04,fy+.85,0))
    node('CameraBounds','Node3D','MARKERS',f'metadata/min_x = 0.0\nmetadata/max_x = {end:.6f}')
    instance('DeploymentPad','deployment_pad',(0,-.905,0),'MARKERS/PlayerSpawn')
    instance('ExtractionPad','extraction_pad',(0,-.85,0),'MARKERS/RoomExit')
    node('Actors','Node3D')
    instance('RiftcoreMecha','player',(0,route[0][1]+.905,0),'Actors')
    instance(info['boss_node'],'boss',(gate+arena*.53,fy+1.55,0),'Actors')
    roster=['scout','quad','heavy','turret','flyer'];placed=0
    for i,(x,y,w,k) in enumerate(route):
        if i<2 or i==checkpoint_index or i>=len(route)-1 or k!='deck' or w<6.0 or i%5==4:continue
        role=placed%5
        instance(f'{info["enemies"][role].replace(" ","")}{placed:02}',roster[role],(x+.7,y+(1.05 if role==4 else .71),0),'Actors',group='level_enemies')
        placed+=1
    node('CameraRig','Node3D',props='position = Vector3(0, 1.35, 0)\nscript = ExtResource("camera_rig")')
    (ROOT/'scenes/levels'/f'{id}.tscn').write_text('\n\n'.join(out).rstrip()+'\n')
    print(n,info['title'],f'{end+6.3:.0f}m',placed,'enemies',len(ZONES[n]),'hazard zones')
for info in catalog[2:]:
    make_kit(info)
    make_level(info)
