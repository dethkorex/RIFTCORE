from pathlib import Path
import math
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "campaign"))
from interior_rhythm import break_up_walk
from folded_rooms import FOLDS, FOLD_TIMED_FIXTURE, folded_route
from build_doorways import outfit
from clear_traversal import clear_decks
from encounter_spacing import update_encounters

base=Path(__file__).resolve().parents[3] / "scenes/levels"
kit="res://assets/neon_factory/foundry/"
def make(act):
    file=base/("neon_factory_test.tscn" if act==1 else "neon_factory_act_2.tscn")
    old=file.read_text(encoding="utf8")
    uid=old.splitlines()[0]
    header=[uid,""]
    nodes=[]
    for id,path,typ in [
        ("Floor",kit+"interior_deck.tscn","PackedScene"),("Wall",kit+"shaft_column.tscn","PackedScene"),
        ("Lining",kit+"interior_bulkhead.tscn","PackedScene"),("Cave",kit+"cave_lining.tscn","PackedScene"),
        ("PressureBank",kit+"pressure_bank.glb","PackedScene"),
        ("Threshold",kit+"zone_threshold.glb","PackedScene"),
        ("LowThreshold",kit+"zone_threshold_low.tscn","PackedScene"),
        ("FactorySky","res://scripts/jungle_backdrop.gd","Script"),
        ("FactoryPanorama","res://assets/neon_factory/foundry/foundry_panorama.jpg","Texture2D"),
        ("Bridge",kit+"powered_bridge.tscn","PackedScene"),("ArenaLift",kit+"warden_lift.tscn","PackedScene"),("Shutter","res://assets/neon_factory/interiors/service_shutter.tscn","PackedScene"),("Relay","res://assets/neon_factory/foundry/power_coupler.tscn","PackedScene"),
        ("Supply","res://scripts/cargo_carrier.gd","Script"),("Chest","res://assets/campaign/neon_factory/salvage_cache.glb","PackedScene"),("RelayCode","res://scripts/factory_interior_relay.gd","Script"),
        ("ChestCode","res://scripts/factory_salvage_chest.gd","Script"),("Hazard","res://scripts/foundry_vent.gd","Script"),("Boulder","res://scripts/foundry_boulder.gd","Script"),
        ("Pit","res://scripts/spike_pit.gd","Script"),
        ("player","res://scenes/actors/riftcore_player.tscn","PackedScene"),
        ("enemy","res://scripts/enemy.gd","Script"),("camera","res://scripts/camera_rig.gd","Script"),
        ("Boss","res://scenes/levels/forge_titan.tscn","PackedScene"),
        ("hall","res://scripts/forge_safe_hall.gd","Script"),("checkpoint","res://scripts/factory_checkpoint.gd","Script"),
        ("Pad","res://assets/neon_factory/deployment_pad.tscn","PackedScene"),
        ("ExitPad","res://assets/neon_factory/extraction_pad.tscn","PackedScene"),
        ("gate","res://assets/neon_factory/boss_gate_door.tscn","PackedScene"),
        ("arch","res://assets/neon_factory/door_frame.tscn","PackedScene"),
        ("beacon","res://assets/neon_factory/checkpoint_beacon.tscn","PackedScene"),
        ("energy","res://assets/pickups/energy_large.tscn","PackedScene"),("repair","res://assets/pickups/health_large.tscn","PackedScene"),
        ("life","res://assets/pickups/extra_life.tscn","PackedScene"),
        ("Barricade","res://scripts/breakable_barricade.gd","Script"),
        ("arena_hatch",kit+"climb_platform_center.tscn","PackedScene"),
    ]:
        header.append(f'[ext_resource type="{typ}" path="{path}" id="{id}"]')
    header.append("""
[sub_resource type="Environment" id="Interior"]
background_mode = 1
background_color = Color(0.043, 0.021, 0.016, 1)
ambient_light_source = 3
ambient_light_color = Color(0.79, 0.59, 0.48, 1)
ambient_light_energy = 0.82

[sub_resource type="BoxShape3D" id="GateShape"]
size = Vector3(0.65, 6.6, 4.65)
[sub_resource type="BoxShape3D" id="ShieldShape"]
size = Vector3(5.7, 4.2, 2.8)
[sub_resource type="BoxShape3D" id="CheckpointShape"]
size = Vector3(2.5, 2.2, 2.3)
[sub_resource type="BoxShape3D" id="RelayShape"]
size = Vector3(0.85, 0.85, 0.8)
[sub_resource type="BoxShape3D" id="ChestShape"]
size = Vector3(1.48, 1.22, 1.22)
[sub_resource type="SphereMesh" id="LampMesh"]
radius = 0.22
height = 0.44
""")
    def v(xyz): return f"Vector3({xyz[0]:.4f}, {xyz[1]:.4f}, {xyz[2]:.4f})"
    def e(id): return f'ExtResource("{id}")'
    def s(id): return f'SubResource("{id}")'
    def node(name, parent=".", typ="Node3D", pos=None, inst=None, group=None, **props):
        tag=f'[node name="{name}"'
        if not inst: tag+=f' type="{typ}"'
        if parent is not None: tag+=f' parent="{parent}"'
        if inst: tag+=f' instance={e(inst)}'
        if group: tag+=' groups=['+', '.join(f'"{g}"' for g in group)+']'
        lines=[tag+']']
        if pos is not None: lines.append('position = '+v(pos))
        lines.extend(f'{key} = {value}' for key,value in props.items())
        nodes.append('\n'.join(lines))
    def asset(name, parent, scene, x, y, z=0, scale=None, **props):
        if scale: props['scale']=v(scale)
        node(name,parent,inst=scene,pos=(x,y,z),**props)
    node("NeonFactoryTest" if act==1 else "ForgeTitanSector",None,**{"metadata/interior_layout":"true","metadata/pit_floor_y":-12.8})
    node("WorldEnvironment",typ="WorldEnvironment",environment=s("Interior"))
    node("KeyLight",typ="DirectionalLight3D",rotation=v((-.56,-.30,0)),light_color="Color(1, 0.80, 0.61, 1)",light_energy="1.30",shadow_enabled="true")
    for folder in ["TERRAIN","DECOR","Actors","MARKERS"]: node(folder)
    def deck(name,a,b,y,depth=1,drop=False,thickness=1):
        span=b-a
        asset(name,"TERRAIN","Floor",(a+b)/2,y,scale=(span/6,thickness,depth),
              group=["factory_drop_through"] if drop else None)
    def decks(name,a,b,y,drop=False):
        i=0
        while a<b:
            end=min(a+6,b)
            deck(name+str(i).zfill(2),a,end,y,drop=drop)
            a=end;i+=1
    def travel(name,a,b,y,drop=False,low_ceiling=False):
        break_up_walk(name,a,b,y,act+len(name),
            lambda key,left,right,top: decks(key,left,right,top,drop),
            lambda key,left,right,low,high: ramp(key,left,right,low,high-low,drop),
            low_ceiling=low_ceiling)
    def ramp(name,start,end,y,dy,drop=False):
        import math
        width=end-start
        angle=math.atan2(dy,width)
        h=math.hypot(width,dy)/6
        asset(name,"TERRAIN","Floor",(start+end)/2,y+dy/2,scale=(h,1,1),rotation=v((0,0,angle)),
              group=["factory_drop_through"] if drop else None)
    def wall(name,x,base,h,z=0):
        asset(name,"TERRAIN","Wall",x,base+h/2,z,scale=(1,h/4,1))
    def shell(end,boss,descent):
        exterior = [(-12,30,0.0,"COOLING INTAKE"),(96,150,6.15,"MAINTENANCE SHAFT"),
                    (366,411,1.2,"FORGE ACCESS")] if act==1 else [
                        (132,186,1.42,"FREIGHT WORKS"),(396,462,.16,"SMELTER ACCESS")]
        node("SectorPanorama","DECOR",script=e("FactorySky"),panorama_texture=e("FactoryPanorama"),
             shadow_tint="Vector3(0.056, 0.019, 0.014)", panorama_filter="Vector3(0.70, 0.70, 0.71)")
        for i,(a,b,y,_) in enumerate(exterior):
            asset(f"EntryThreshold{i}","DECOR","Threshold",b+1.15,y+.04,-.63)
            # Bend the rear wall around the entry, leaving the play lane clear.
            asset(f"EntryReturnWall{i}","DECOR","Lining",b+4.2,y-1.45,-2.60)
            for n in range(a+5,b,15):
                asset(f"IndustrialButtress{i}_{n}","DECOR","Wall",n,y-5.2,-3.25,scale=(2.75,1.4,.79))
        for i,(mouth,_,floor) in enumerate(descent):
            if act == 1 and i == 2:
                # Set the lintel below the upper Bedrock walk and use its existing rock wall.
                asset("CaveThreshold2","TERRAIN","LowThreshold",mouth+1.35,-2.0,-.48)
                continue
            asset(f"CaveThreshold{i}","DECOR","Threshold",mouth+1.35,floor,-.48)
            asset(f"CaveReturnWall{i}","DECOR","Cave",mouth+3.3,floor-2.15,-2.57)
        for index,x in enumerate(range(-9,end+6,6)):
            if any(a<=x<b for a,b,_,_ in exterior):
                continue
            cave=any(a<=x<b for a,b,_ in descent)
            if index%8==0: z=-3.6
            else: z=-3.28
            asset(f"Rear{index:03}","DECOR","Cave" if cave else "Lining",x,-2.35,z)
            asset(f"RearUpper{index:03}","DECOR","Cave" if cave else "Lining",x,5.65 if x<boss else 6.9,z)
            if not cave and (index+act)%7==3:
                asset(f"PressureBank{index:03}","DECOR","PressureBank",x,.1,z+.42)
            for tier, height in enumerate((13.65,21.65) if x<boss else (14.9,22.9)):
                asset(f"HighWall{tier}_{index:03}","DECOR","Cave" if cave else "Lining",x,height,z)
            if x%24==15:
                node(f"BayLight{index}","DECOR","OmniLight3D",(x,4.2,-1.35),light_color=f'Color({ "1, 0.39, 0.17" if cave else "1, 0.55, 0.24"}, 1)',light_energy="1.60",omni_range="9.0")
        for i,x in enumerate(range(-6,end+10,12)):
            asset("BedrockBase"+str(i),"DECOR","Cave",x,-10.35,-2.85,scale=(2,1,1))
        for i,x in enumerate(range(-6,end,12)):
            if x<boss and not any(a<=x<b for a,b,_,_ in exterior):
                asset("CeilingBeam"+str(i),"DECOR","Lining",x,21.6,-2.65,scale=(2,0.11,1.2))
    def checkpoint(name,x,y):
        node(name,"TERRAIN","Area3D",(x,y,0),script=e("checkpoint"),collision_layer=0)
        path="TERRAIN/"+name
        node("Trigger",path,"CollisionShape3D",(0,.9,0),shape=s("CheckpointShape"))
        asset("Beacon",path,"beacon",0,0,0.75)
    def chest(name,x,y,index):
        node(name,"TERRAIN","Area3D",(x,y,0),group=["factory_salvage_chest"],script=e("ChestCode"),collision_layer=0,materials=3+index//3)
        path="TERRAIN/"+name
        node("Trigger",path,"CollisionShape3D",(0,.61,0),shape=s("ChestShape"))
        asset("Art",path,"Chest",0,0,0)
    def sealed_cache(name, x, floor, index):
        shelf = floor + 2.67
        deck(name+"Alcove",x,x+7.4,shelf)
        deck(name+"Ceiling",x+1.7,x+7.4,shelf+2.68)
        wall(name+"End",x+7.05,shelf,2.15)
        node(name+"Barricade","TERRAIN","StaticBody3D",(x+2.25,shelf,0),script=e("Barricade"))
        chest(name+"Cache",x+5.4,shelf,index)

    def hazard(name,x,y,kind,offset=0,tighter=False,purge=None):
        node(name,"TERRAIN","Area3D",(x,y,0),script=e("Hazard"),collision_layer=0,
             flame_height=(2.22,3.0,3.55)[kind], nozzle_width=(1.52,1.74,1.90)[kind], damage=(17.0,23.0,28.0)[kind],
             period=(3.23 if tighter else 3.8), offset=offset,
             **({"purge_relay":f'NodePath("../{purge}")'} if purge else {}))
    def spikes(name,left,right,height):
        node(name,"TERRAIN","Area3D",((left+right)/2,height,0),
             script=e("Pit"),width=right-left,tint="Color(1, 0.49, 0.19, 1)")

    def supply(name,x,y,reward):
        node(name,"TERRAIN","CharacterBody3D",(x,y,0),script=e("Supply"),
             group=["factory_supply_carrier"],supplies_only="true",reward=e(reward))

    def relay(trigger,platform,x,y,mx,my,dy,lift=False,art="Bridge",operation=None,dx=0,projectile_only=True,delay=None,pressure_plate=False):
        if delay is None: delay = 1.15 if lift else 0.0
        asset(platform,"TERRAIN",art,mx,my)
        node(trigger,"TERRAIN","StaticBody3D",(x,y,0),group=["factory_shot_relay"],script=e("RelayCode"),
            collision_layer=0 if pressure_plate else 2 if projectile_only else 1, collision_mask=0,
            **({"departure_delay": delay} if delay else {}),
            floating=str(not pressure_plate).lower(),pressure_plate=str(pressure_plate).lower(),
            platform_path=f'NodePath("../{platform}")',travel=v((dx,dy,0)),operation=f'"{operation or ("FREIGHT LIFT" if lift else "DROP BRIDGE")}"',lift=str(lift).lower())
        path="TERRAIN/"+trigger
        if pressure_plate:
            asset("Art",path,"Relay",0,-.08,0,scale=(2,.25,2))
            node("Lamp",path,"MeshInstance3D",(0,-.08,0),mesh=s("LampMesh"),scale=v((2,.30,2)))
        else:
            asset("Art",path,"Relay",0,0,0)
            node("Collider",path,"CollisionShape3D",shape=s("RelayShape"))
            node("Lamp",path,"MeshInstance3D",(0,0,0),mesh=s("LampMesh"))
    def lower_loop(prefix,x,index):
        ramp(prefix+"Down",x,x+8,0,-1.85)
        decks(prefix+"Tunnel",x+8,x+32,-1.85)
        ramp(prefix+"Up",x+32,x+40,-1.85,1.85)
        deck(prefix+"OverheadA",x+2,x+13,2.55,drop=True)
        deck(prefix+"OverheadB",x+16,x+27,2.55,drop=True)
        deck(prefix+"OverheadC",x+31,x+39,2.55,drop=True)
        deck(prefix+"CacheStep",x+13,x+15,0.19)
        deck(prefix+"CachePerch",x+19,x+23,0.24)
        chest(prefix+"RecessChest",x+21.35,.24,index)
    def enemies(items, gate):
        for i,(x,y,variant) in enumerate(items):
            common = (i-4+act-1)%6 if 4<=i<10 else -1
            if i < 4:
                variant = (0,2,3,4)[i]
            elif common < 0 and variant==1:
                variant = 0
            flying = variant==4 if common<0 else common>=4
            node(f"Security{i+1:02}","Actors","CharacterBody3D",(x,y+(2.85 if flying else .91),0),
                 group=["level_enemies","damageable_enemies"],script=e("enemy"),variant=variant,
                 detachment_sector=1,patrol_model=common,patrol_right_limit=gate-12.0)

    def basement_approach(start, floor):
        fold = FOLDS["neon_factory"][act-1]
        fixture = (lambda x,y: hazard("TurnbackFlare",x,y,2,1.15,tighter=True)) if ("neon_factory",act) in FOLD_TIMED_FIXTURE else None
        def fold_deck(name,a,b,y,high):
            if y != high:
                ramp("Turnback"+name,a,b,y,high-y)
            elif name == "IngressLane":
                travel("Turnback"+name,a,b,y)
            else:
                decks("Turnback"+name,a,b,y)
        end, bottom = folded_route(fold,start,floor,0.0,
            fold_deck,
            lambda name,x,y,top: wall("Turnback"+name,x,y,top),
            lambda name,a,b,y: spikes("Turnback"+name,a,b,y),
            fixture,
            passage_hazard=lambda name,x,y: hazard("Turnback"+name,x,y,0 if act==1 else 2,.85,tighter=act==2),
            bottom_limit=-10.1)
        for index,x in enumerate(range(int(start),int(end),6)):
            asset(f"TurnbackCladding{index}","DECOR","Cave",x,bottom-1.4,-3.18,scale=(1.0,1.25,1.0))
        hall = math.ceil(end) + 9
        decks("HallRecovery",end,hall-3,0)
        return hall,hall+13,hall+64

    def arena(hallx,gx,exitx,start):
        decks("ArmorFloor",hallx-3,exitx+6,0)
        for name,x in [("ForgeHallDoor",hallx),("Gate",gx)]:
            node(name,pos=(x,0,0),**({"script":e("hall")} if name=="ForgeHallDoor" else {}))
            asset("Door",name,"gate",0,0,0,rotation=v((0,-1.5708,0)),scale=(.93,6.6/3.7,1))
            asset("PortalFrame",name,"arch",-.25,0,0,rotation=v((0,-1.5708,0)),scale=(5.53/3.0,6.8/3.0,1.12))
            node("Blocker",name,"StaticBody3D")
            node("CollisionShape3D",name+"/Blocker","CollisionShape3D",(0,3.2,0),shape=s("GateShape"))
            # The gate cannot be bypassed over or under the enclosed corridor.
            wall(name+"Lintel",x,6.49,8.5)
        node("Shield","ForgeHallDoor","Area3D",(3.6,1.75,0),collision_layer=0)
        node("Shape","ForgeHallDoor/Shield","CollisionShape3D",shape=s("ShieldShape"))
        node("ExitBarrier",typ="StaticBody3D",pos=(exitx,0,0))
        asset("Seal","ExitBarrier","gate",0,0,0,rotation=v((0,-1.5708,0)),scale=(.93,6.6/3.7,1))
        node("CollisionShape3D","ExitBarrier","CollisionShape3D",(0,3.2,0),shape=s("GateShape"))
        wall("ExtractionEnd",exitx+5,0,14)
        checkpoint("ForgeHallCheckpoint",gx-6.4,0)
        asset("RepairBayHeal","TERRAIN","repair",gx-3.6,.40)
        for index,x in enumerate([gx+9,gx+22,gx+34]):
            asset("FurnaceBackplate"+str(index),"DECOR","PressureBank",x,0,-2.65,scale=(1.1,1.15,.9))
        if act == 1:
            deck("WardenEntryStep",gx+5,gx+9,2.72,drop=True,thickness=.6)
            deck("WardenSideShelf",gx+10.5,gx+17,3.45,drop=True)
            deck("WardenRecoveryIsland",gx+34,gx+41,2.75,drop=True,thickness=.6)
            relay("WardenLiftRelay","WardenEvadeLift",gx+24.0,1.27,gx+30.6,.14,4.81,
                  True,art="ArenaLift",operation="EVADE LIFT",projectile_only=True)
        else:
            asset("TitanWestHatch","TERRAIN","arena_hatch",gx+11,4.25,
                  deck_width=6.2,climb_height=4.25)
            deck("TitanHighRun",gx+19,gx+28,6.45,drop=True)
            deck("TitanEastDrop",gx+38,gx+44,3.95,drop=True)
        node("PlayerSpawn","MARKERS","Marker3D",(start,.87,0))
        asset("SpawnPad","MARKERS/PlayerSpawn","Pad",0,-.87)
        node("RoomExit","MARKERS","Marker3D",(exitx+1.4,.87,0))
        asset("ExtractionPad","MARKERS/RoomExit","ExitPad",0,-.87)
        node("CameraBounds","MARKERS",**{"metadata/min_x":-7.0,"metadata/max_x":exitx+2.0})
        asset("RiftcoreMecha","Actors","player",start,.87,pit_floor_y=-12.8)
        asset("ForgeTitan","Actors","Boss",gx+25,1.45)
        node("CameraRig",pos=(start,1.23,0),script=e("camera"),minimum_follow_y=-7.8)
    def fork(prefix, a, b, index, raised=False, three_way=False):
        # The floor ramps into a genuine lower passage. The other fork jumps
        # up to overhead walkways with gaps and a different reward.
        low = -2.05 if not raised else -1.35
        ramp(prefix+"LowerRamp",a,a+10,0,low)
        edge=a+(27 if act==1 else 21 if three_way else 19)
        width=4.2 if act==1 else 4.25
        decks(prefix+"LowerWest",a+10,edge,low)
        spikes(prefix+"TunnelSpikes",edge,edge+width,low-3.05)
        travel(prefix+"LowerEast",edge+width,b-9,low,low_ceiling=True)
        ramp(prefix+"ReturnRamp",b-9,b,low,-low)
        height = 6.25 if three_way else (3.55 if raised else 3.35)
        if three_way:
            deck(prefix+"ServiceStep",a+2,a+6,2.32,drop=True)
            deck(prefix+"ServiceWest",a+7,a+18,2.95,drop=True)
            if act == 2:
                deck(prefix+"ServiceEast",a+24,b-10,2.95,drop=True)
                deck(prefix+"ServiceExit",b-9,b-4,2.5,drop=True)
            deck(prefix+"UpperStep",a+12,a+17,5.73,drop=True)
            deck(prefix+"UpperWest",a+18,a+26,height,drop=True)
            if act == 1:
                deck(prefix+"UpperSpan",a+30,a+35,height+.35,drop=True)
                deck(prefix+"UpperDip",a+38,a+42,height-.54,drop=True)
                deck(prefix+"UpperReturn",a+44,b-8,height,drop=True)
                deck(prefix+"UpperEast",b-3.8,b-1,4.75,drop=True)
            else:
                decks(prefix+"UpperSpan",a+30,b-13,height,drop=True)
                deck(prefix+"UpperEast",b-10,b-3,5.24,drop=True)
            asset(prefix+"ServiceSupply","TERRAIN","repair",b-14,3.35 if act==2 else height+.4)
        else:
            deck(prefix+"UpperStep",a+2,a+6,2.32,drop=True)
            deck(prefix+"UpperWest",a+7,a+16,3.15,drop=True)
            travel(prefix+"UpperSpan",a+20,b-15,height,drop=True)
            deck(prefix+"UpperEast",b-11,b-3,2.7,drop=True)
        chest(prefix+"UpperCache",b-11 if three_way and act==1 else max(a+31,b-18) if three_way else b-18,height,index)
        asset(prefix+"LowerSupply","TERRAIN","energy",a+21,low+.40)

    def riser(prefix, a, b, index, base_y=0, height=6.15):
        # Spawn and ground end at the wall. The only forward exit is upstairs.
        left,right=a+13.5,a+17.5
        decks(prefix+"Approach",a,left+.42,base_y)
        wall(prefix+"Left",left,base_y+2.12,6.48,-.02)
        wall(prefix+"Right",right,base_y,height,-.02)
        ramp(prefix+"EntryRamp",left+.42,right-1.42,base_y,1.35)
        deck(prefix+"Sill",right-1.42,right-.40,base_y+1.35)
        decks(prefix+"UpperExit",right+.4,b,base_y+height,drop=True)
        deck(prefix+"CacheShelf",left-12.5,left-.45,base_y+8.55,drop=True)
        chest(prefix+"Cache",left-9.8,base_y+8.55,index)

    def basement(prefix, western_end, entry, gate_x, join, cache_index, gap):
        floor, return_y = -8.5, -2.6
        # Act I's sump uses a floor interlock. Act II's upper lock is a fractured wall.
        decks(prefix+"WestSump",western_end,western_end+gap[0],floor)
        if act == 1:
            decks(prefix+"EastSump",western_end+gap[1],entry+4,floor)
        else:
            deck(prefix+"SumpIsland",western_end+gap[1],entry-5.3,floor+.7)
            decks(prefix+"EastSump",entry-1.2,entry+4,floor)
        wall(prefix+"SumpEnd",western_end-.39,floor-.84,7.1)
        wall(prefix+"EntryStop",entry+4.39,floor-.84,7.1)
        deck(prefix+"HatchWest",western_end,western_end+3.4,return_y)
        wall(prefix+"UnderpassShield",western_end-.39,return_y,3.2)
        asset(prefix+"LadderHatch","TERRAIN","arena_hatch",western_end+5.4,return_y,
              deck_width=4.0,climb_height=return_y-floor)
        travel(prefix+"Return",western_end+7.4,entry-5,return_y,low_ceiling=True)
        deck(prefix+"ReturnTakeoff",entry-5,entry-3,return_y)
        decks(prefix+"ShutterApron",entry+2,gate_x-5,return_y)
        ramp(prefix+"ShutterRamp",gate_x-5,gate_x-1,return_y,-.4-return_y)
        decks(prefix+"Rejoin",gate_x-1,join,-.4)
        ramp(prefix+"RejoinLip",join,join+4,-.4,.4)
        if act==1:
            relay(prefix+"LockRelay",prefix+"Lock",western_end+2.25,floor+.15,gate_x,5.7,10.0,
                  art="Shutter",operation="RETURN SHUTTER",pressure_plate=True)
        else:
            node(prefix+"FracturedBulkhead","TERRAIN","StaticBody3D",(gate_x,-.39,0),
                 script=e("Barricade"),scale=v((1,4.18,1)),accent="Color(1, 0.47, 0.17, 1)")
        wall(prefix+"GateSill",gate_x,-12.85,12.47)
        wall(prefix+"GateHeader",gate_x,8.3,12.0)
        for index in range(0, int(entry+11-western_end), 6):
            x=western_end+index+3
            asset(prefix+"Backwall"+str(index),"DECOR","Lining",x,-11.65,-2.87)
            if index%12 == 0:
                node(prefix+"Lamp"+str(index),"DECOR","OmniLight3D",(x,-5.7,-1.35),
                     light_color="Color(1, 0.33, 0.17, 1)",light_energy="1.35",omni_range="8.0")
        chest(prefix+"ServiceCache",western_end+2.1,floor,cache_index)

    def overhead_brace(name, x, y, roof_y=21.6):
        # Visible behind the play lane and outside player collision.
        asset(name,"DECOR","Wall",x,(y+roof_y)/2,-4.3,
              scale=(.65,(roof_y-y)/4,.52))

    def cooling_gantry():
        # Climb on the east, cross west above the original catwalks, then
        # descend and turn east on a separate maintenance deck.
        asset("GantryAccessHatch","TERRAIN","arena_hatch",77.55,12.05,
              deck_width=4.4,climb_height=5.8)
        deck("GantryLaunch",70.9,75.35,13.4,drop=True)
        deck("GantryColdPipes",61.3,69.0,14.7,drop=True)
        deck("GantryWestLanding",47.3,52.1,14.45,drop=True)
        deck("GantrySalvage",38.3,44.0,15.55,drop=True)
        chest("CoolingOverheadCache",40.3,15.55,8)
        # The gantry returns through a west-side drop instead of duplicating
        # the route underneath. Two staggered shelves guide the descent.
        deck("GantryTurnWest",31.75,36.05,11.75,drop=True)
        deck("GantryDescentShelf",28.85,33.5,6.05,drop=True)
        hazard("GantryFlare",48.8,14.45,1,1.8)
        for index,(x,y) in enumerate([(80.05,12.1),(64.4,14.7),(49.1,14.45),(40.3,15.55)]):
            overhead_brace("CoolingGantryBrace"+str(index),x,y)

    def refinery_high_route():
        # The lift rises from the forge riser. The eastbound crane level
        # returns west along the lower inspection decks and drops onto slag ramp.
        relay("HighFreightRelay","HighFreightLift",323.7,7.25,331.5,8.86,7.39,
              True,operation="RAISE CRANE LIFT")
        deck("CraneDisembark",337.7,346.6,16.25,drop=True)
        deck("CraneEastSpan",354.8,362.4,17.05,drop=True)
        deck("CraneVault",368.5,377.1,16.95,drop=True)
        chest("CraneLevelCache",373.5,16.95,4)
        deck("CraneTurnDown",379.15,383.8,14.2,drop=True)
        deck("CraneInspectionWest",364.65,369.9,11.15,drop=True)
        deck("CraneExitChute",353.7,360.4,8.45,drop=True)
        deck("RefineryReturnLanding",350.3,353.3,6.95)
        hazard("CraneFlare",358.5,17.05,2,.95,purge="HighFreightRelay")
        for index,(x,y) in enumerate([(341.5,16.25),(359,17.05),(373.6,16.95)]):
            overhead_brace("CraneBrace"+str(index),x,y)

    if act==1:
        hall,gate,exit=basement_approach(412,1.2)
        shell(exit,gate,[(39,103,-.82),(165,231,6.15),(270,324,-1.35)])
        decks("Intake",-14,3.4,0)
        ramp("IntakeDrain",3.4,7.5,0,-.64)
        ramp("IntakeDrainReturn",7.5,10.8,-.64,.64)
        deck("IntakeLip",10.8,14,0)
        decks("IntakeLanding",20,35,0)
        spikes("IntakeSpikes",14,20,-4.0)
        fork("Cooling",35,93,1,three_way=True)
        cooling_gantry()
        # Freight viaduct. Thick ramps carry the apron, with a deliberate
        # running gap between structure-tied landings.
        ramp("FreightViaductRamp",93,99.1,0,1.28)
        deck("FreightViaductLip",99.1,101.9,1.28)
        spikes("FreightViaductSpikes",101.9,106.45,-2.55)
        deck("FreightViaductLanding",106.45,110.2,.72)
        ramp("FreightViaductReturn",110.2,117,.72,-.72)
        asset("FreightViaductSupport","DECOR","Wall",108.25,-2,-2.55,scale=(1.3,1.25,.77))
        riser("ConduitShaft",117,158,3)
        decks("ChannelLeft",158,170.5,6.15)
        decks("ChannelRight",176.5,189,6.15)
        deck("MaintenanceCatch",170.5,172.6,3.45)
        ramp("CatchStair",172.6,176.5,3.45,1.30)
        relay("DropBridgeRelay","DropBridge",166.5,7.15,173.5,9.3,-3.15)
        # The bridge gives a straight crossing. The service passage bypasses it below.
        deck("DropLip",189,191,6.15)
        basement("PumpBasement",145,194,211,220,2,(18,23.1))
        decks("MidwayLanding",224,227,0)
        checkpoint("MidpointCheckpoint",224.8,0)
        fork("Bedrock",227,292,4,True)
        decks("FoundryAccess",292,298,0)
        deck("FoundryLanding",304.2,309,0)
        spikes("FoundrySpikes",298,304.2,-4.2)
        riser("FoundryShaft",309,350,7)
        deck("FoundryStep",350,354,4.4)
        deck("FoundryLowerStep",354,359,2.7)
        ramp("FoundryRamp",359,369,2.7,-2.7)
        decks("ForgeApron",369,383,0)
        deck("OutboundCatwalkA",392.2,397.6,0)
        spikes("ForgeApronSpikes",383,392.2,-4.3)
        deck("CatwalkDippedLanding",399.4,403,-1.1)
        ramp("ForgeApproachRamp",403,409,-1.1,2.3)
        node("ForgeFracturedBulkhead","TERRAIN","StaticBody3D",(410.4,1.2,0),
             script=e("Barricade"),scale=v((1,2.2,1)),accent="Color(1, 0.47, 0.17, 1)")
        deck("ForgeBulkheadLintel",409.7,411.1,6.53)
        wall("ForgeBulkheadCrown",410.4,6.52,12.7)
        deck("ForgeApproachLanding",409,412,1.2)
        sealed_cache("ForgeService",371.5,0,13)
        for i,(x,y,kind) in enumerate([(28,0,0),(69.5,-2.05,1),(149,6.15,2),(197,-8.5,0),(253,-1.35,1),(295.0,0,2),(344,6.15,1)]):
            hazard("FoundryFlare"+str(i+1),x,y,kind,i*.37,tighter=i in (0,2))
        for name,x,y,reward in [
            ("IntakeSupplyDrone",26.0,1.63,"repair"),("ConduitSupplyDrone",155.1,7.80,"energy"),
            ("FoundrySupplyDrone",315.7,1.61,"repair"),
        ]: supply(name,x,y,reward)
        enemies([(22,0,0),(47,-2.05,1),(59,6.25,4),(107.4,.72,2),(150,6.15,0),(181,6.15,3),(176,-8.5,4),(219,-.4,2),(245,-1.35,1),(273,3.55,3),(291,0,2),(336,6.15,4),(423.5,1.2,0)],gate)
    else:
        hall,gate,exit=basement_approach(454,.6)
        shell(exit,gate,[(49,110,-1.35),(196,264,0),(327,372,6.15)])
        decks("SmelterIntake",-14,2.4,0)
        ramp("SmelterManifold",2.4,5.4,0,1.03)
        ramp("SmelterManifoldReturn",5.4,8.15,1.03,-1.03)
        deck("SmelterIntakeLip",8.15,12,0)
        deck("OverfeedPier",18.25,22,0.6)
        spikes("IntakeFirstSpikes",12,18.25,-4.1)
        spikes("IntakeSecondSpikes",22,27.5,-3.9)
        ramp("OverfeedLanding",27.5,30,0.6,-0.6)
        fork("CoolingDeck",30,83,6,True)
        # The smelter route drops under the intake baffle, then opens into a
        # different jump from the bridge approach in Act I.
        ramp("KilnDuctDescent",83,89,0,-1.85)
        deck("KilnDuctFloor",89,92.1,-1.85)
        spikes("KilnDrainSpikes",92.1,96.25,-5.2)
        deck("KilnDuctLanding",96.25,98.35,-.90)
        ramp("KilnDuctRim",98.35,101,-.90,.90)
        riser("IntakeRiser",101,141,8)
        decks("HotApron",141,152,6.15)
        deck("HotApronIsland",158,164,5.4)
        ramp("HotApronDown",169.5,191,5.4,-5.4)
        deck("IntakeLip",191,196,0)
        basement("SlagBasement",160,201,234,240,0,(25.4,30.4))
        relay("FreightRelay","FreightLift",210,-1.6,215.3,.11,4.89,True)
        decks("FreightLanding",218.5,230,5)
        deck("FreightReturn",230.3,234,3.1)
        chest("FreightVaultChest",225,5,9)
        decks("TransferApron",244,248,0)
        checkpoint("MidpointCheckpoint",245,0)
        fork("FuelLine",248,293,10,three_way=True)
        decks("FuelRiserLanding",293,297,0)
        riser("Riser",297,344,11)
        refinery_high_route()
        deck("RightStairA",345.1,349,4.45)
        ramp("SlagRamp",352,362,2.9,-2.9)
        fork("Refinery",362,405,5,True)
        decks("SmelterExit",405,418,0)
        # The etched chute is its own encounter. The inlet stays open for retreat.
        deck("BoulderChuteCanopy",406,418,4.08)
        asset("BoulderStartCollar","DECOR","Threshold",416.1,0,-.2,scale=(1.1,1.12,1.2))
        for x in (406,410,414):
            asset("BoulderBaffle"+str(x),"DECOR","PressureBank",x,1.2,-2.54,scale=(.85,1.15,.9))
            node("BoulderLamp"+str(x),"DECOR","OmniLight3D",(x,2.86,-1.43),light_color="Color(1, 0.19, 0.052, 1)",light_energy="1.65",omni_range="4.8")
        node("SlagBoulder","TERRAIN","AnimatableBody3D",(416.4,1.4,0),
             script=e("Boulder"),group=["foundry_boulder"],runway_length=10.6)
        hazard("CastingLineReliefVent",450.85,.6,1,1.35,purge="CastingBridgeCoupler")
        deck("SlagBridgeLanding",427.4,431.4,0)
        ramp("SlagBridgeRiser",431.4,435.2,0,.92)
        ramp("SlagBridgeReturn",435.2,441,.92,-.92)
        spikes("SmelterSpikes",418,427.4,-4.25)
        spikes("SlagGapSpikes",441,448.7,-4.15)
        deck("SlagVentIsland",448.7,454,.6)
        relay("CastingBridgeCoupler","CastingServiceBridge",437.2,4.65,450.25,3.42,0,False,
              operation="EXTEND CASTING BRIDGE",dx=-6.55,projectile_only=True,delay=.46)
        deck("SlagVaultWestboundLedge",441.8,444.25,8.32,drop=True)
        deck("SlagVaultTurn",429.1,435.87,9.25,drop=True)
        chest("CastingLoftCache",431.7,9.25,3)
        for i,(x,y,k) in enumerate([(37,-.94,2),(57,-1.35,1),(99.45,-.52,0),(135,6.15,2),(177,-8.5,1),(223,-2.6,2),(333,6.15,0),(391.0,-1.35,1),(401,-.6,2)]):
            hazard("FoundryFlare"+str(i+1),x,y,k,i*.42)
        for name,x,y,reward in [
            ("ManifoldSupplyDrone",35.4,1.18,"energy"),("ApronSupplyDrone",149.0,7.78,"repair"),
            ("RiserSupplyDrone",294.7,1.62,"energy"),
        ]: supply(name,x,y,reward)
        enemies([(29,.18,0),(46,-1.35,2),(76,2.7,4),(87.2,-1.25,1),(144,6.15,0),(161,5.4,4),(202,-8.5,3),(224,5,2),(231,-2.1,3),(260,-1.87,2),(286,5.24,1),(322,6.15,2),(374,-1.35,0),(466.1,.6,4)],gate)
    wall("AirlockEnd",-13,0,14)
    arena(hall,gate,exit,0)
    file.write_text(update_encounters(clear_decks(outfit("neon_factory", '\n'.join(header)+'\n\n'+'\n\n'.join(nodes)+'\n'))),encoding="utf8")
for act in [1,2]: make(act)
