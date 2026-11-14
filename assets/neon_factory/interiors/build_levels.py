from pathlib import Path
import re
base=Path(__file__).resolve().parents[3] / "scenes/levels"
kit="res://assets/neon_factory/interiors/"
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
        ("Bridge",kit+"powered_bridge.tscn","PackedScene"),("Shutter",kit+"service_shutter.tscn","PackedScene"),("Relay",kit+"shot_relay.glb","PackedScene"),
        ("Chest",kit+"salvage_chest.glb","PackedScene"),("RelayCode","res://scripts/factory_interior_relay.gd","Script"),
        ("ChestCode","res://scripts/factory_salvage_chest.gd","Script"),("Hazard","res://scripts/factory_interior_trap.gd","Script"),
        ("Pit","res://scripts/spike_pit.gd","Script"),
        ("Biome","res://scripts/biome_zone.gd","Script"),
        ("Font","res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf","FontFile"),
        ("player","res://scenes/actors/riftcore_player.tscn","PackedScene"),
        ("enemy","res://scripts/enemy.gd","Script"),("camera","res://scripts/camera_rig.gd","Script"),
        ("Boss","res://scenes/levels/forge_titan.tscn","PackedScene"),
        ("hall","res://scripts/forge_safe_hall.gd","Script"),("checkpoint","res://scripts/factory_checkpoint.gd","Script"),
        ("Pad","res://assets/neon_factory/deployment_pad.tscn","PackedScene"),
        ("ExitPad","res://assets/neon_factory/extraction_pad.tscn","PackedScene"),
        ("gate","res://assets/neon_factory/boss_gate_door.tscn","PackedScene"),
        ("arch","res://assets/neon_factory/door_frame.tscn","PackedScene"),
        ("beacon","res://assets/neon_factory/checkpoint_beacon.tscn","PackedScene"),
        ("reactor","res://assets/neon_factory/reactor_core.tscn","PackedScene"),
        ("energy","res://assets/pickups/energy_large.tscn","PackedScene"),("repair","res://assets/pickups/health_large.tscn","PackedScene"),
        ("life","res://assets/pickups/extra_life.tscn","PackedScene"),
        ("arena_hatch","res://assets/campaign/neon_factory/terrain/climb_platform_center.tscn","PackedScene"),
    ]:
        header.append(f'[ext_resource type="{typ}" path="{path}" id="{id}"]')
    header.append("""
[sub_resource type="Environment" id="Interior"]
background_mode = 1
background_color = Color(0.025, 0.033, 0.057, 1)
ambient_light_source = 3
ambient_light_color = Color(0.47, 0.61, 0.78, 1)
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
    def label(name,parent,msg,x,y,z=-1.74,tint="0.48, 0.88, 1",pixels=0.0050):
        node(name,parent,"Label3D",(x,y,z),font=e("Font"),text='"'+msg+'"',pixel_size=str(pixels),font_size=56,outline_size=11,modulate=f"Color({tint}, 1)")
    node("NeonFactoryTest" if act==1 else "ForgeTitanSector",None,**{"metadata/interior_layout":"true","metadata/pit_floor_y":-12.8})
    node("WorldEnvironment",typ="WorldEnvironment",environment=s("Interior"))
    node("KeyLight",typ="DirectionalLight3D",rotation=v((-.56,-.30,0)),light_color="Color(0.79, 0.90, 1, 1)",light_energy="1.30",shadow_enabled="true")
    for folder in ["TERRAIN","DECOR","Actors","MARKERS"]: node(folder)
    def deck(name,a,b,y,depth=1):
        span=b-a
        asset(name,"TERRAIN","Floor",(a+b)/2,y,scale=(span/6,1,depth))
    def decks(name,a,b,y):
        i=0
        while a<b:
            end=min(a+6,b)
            deck(name+str(i).zfill(2),a,end,y)
            a=end;i+=1
    def ramp(name,start,end,y,dy):
        import math
        width=end-start
        angle=math.atan2(dy,width)
        h=math.hypot(width,dy)/6
        asset(name,"TERRAIN","Floor",(start+end)/2,y+dy/2,scale=(h,1,1),rotation=v((0,0,angle)))
    def wall(name,x,base,h,z=0):
        asset(name,"TERRAIN","Wall",x,base+h/2,z,scale=(1,h/4,1))
    def shell(end,boss,descent):
        for index,x in enumerate(range(-9,end+6,6)):
            cave=any(a<=x<b for a,b in descent)
            if index%8==0: z=-3.6
            else: z=-3.28
            asset(f"Rear{index:03}","DECOR","Cave" if cave else "Lining",x,-2.35,z)
            asset(f"RearUpper{index:03}","DECOR","Cave" if cave else "Lining",x,5.65 if x<boss else 6.9,z)
            if not cave and (index+act)%7==3:
                asset(f"PressureBank{index:03}","DECOR","PressureBank",x,.1,z+.42)
            for tier, height in enumerate((13.65,21.65) if x<boss else (14.9,22.9)):
                asset(f"HighWall{tier}_{index:03}","DECOR","Cave" if cave else "Lining",x,height,z)
            if x%24==15:
                node(f"BayLight{index}","DECOR","OmniLight3D",(x,4.2,-1.35),light_color=f'Color({ "1, 0.39, 0.17" if cave else "0.19, 0.62, 1"}, 1)',light_energy="1.60",omni_range="9.0")
        for i,x in enumerate(range(-6,end+10,12)):
            asset("BedrockBase"+str(i),"DECOR","Cave",x,-10.35,-2.85,scale=(2,1,1))
        for i,x in enumerate(range(-6,end,12)):
            if x<boss:
                asset("CeilingBeam"+str(i),"DECOR","Lining",x,21.6,-2.65,scale=(2,0.11,1.2))
    def checkpoint(name,x,y):
        node(name,"TERRAIN","Area3D",(x,y,0),script=e("checkpoint"),collision_layer=0)
        path="TERRAIN/"+name
        node("Trigger",path,"CollisionShape3D",(0,.9,0),shape=s("CheckpointShape"))
        asset("Beacon",path,"beacon",0,0,0.75)
        label("Status",path,"CHECKPOINT",0,1.65,-0.95,pixels=.004)
    def chest(name,x,y,index):
        node(name,"TERRAIN","Area3D",(x,y,0),group=["factory_salvage_chest"],script=e("ChestCode"),collision_layer=0,blueprint=f'"bp_01_{index:02}"',bolts=65+index*5,materials=3+index//3)
        path="TERRAIN/"+name
        node("Trigger",path,"CollisionShape3D",(0,.61,0),shape=s("ChestShape"))
        asset("Art",path,"Chest",0,0,0)
        label("Sign",path,"SALVAGE CACHE",0,1.23,-.20,"1, 0.71, 0.23",.0035)
    def hazard(name,x,y,kind,offset=0):
        node(name,"TERRAIN","Area3D",(x,y,0),script=e("Hazard"),collision_layer=0,kind=kind,offset=offset)
    def spikes(name,left,right,height):
        node(name,"TERRAIN","Area3D",((left+right)/2,height,0),
             script=e("Pit"),width=right-left,tint="Color(1, 0.49, 0.19, 1)")
        label(name+"Warning","DECOR","SPIKES  /  JUMP",left-2.1,height+3.7,z=-1.5)

    def relay(trigger,platform,x,y,mx,my,dy,lift=False,art="Bridge",operation=None,dx=0):
        asset(platform,"TERRAIN",art,mx,my)
        node(trigger,"TERRAIN","StaticBody3D",(x,y,0),group=["factory_shot_relay"],script=e("RelayCode"),
            platform_path=f'NodePath("../{platform}")',travel=v((dx,dy,0)),operation=f'"{operation or ("FREIGHT LIFT" if lift else "DROP BRIDGE")}"',lift=str(lift).lower())
        path="TERRAIN/"+trigger
        asset("Art",path,"Relay",0,-.26,0)
        node("Collider",path,"CollisionShape3D",shape=s("RelayShape"))
        node("Lamp",path,"MeshInstance3D",(0,0,.26),mesh=s("LampMesh"))
        label("Status",path,"SHOOT TARGET",0,1.05,-1.38,"1, 0.62, 0.31",.004)
    def switchback(prefix,x,y,index):
        # From the main route, ascend left to a wall-kick shaft, then cross right to the cache.
        decks(prefix+"Approach",x-3,x+2,y+1.85)
        decks(prefix+"Turn",x-10,x-4.6,y+3.65)
        wall(prefix+"WestShaft",x-16,y+2.2,5.5)
        wall(prefix+"EastShaft",x-12.2,y+2.2,3.65)
        deck(prefix+"ShaftEntry",x-15.6,x-12.6,y+2.9)
        deck(prefix+"ShaftTop",x-12,x-6.2,y+6.55)
        deck(prefix+"Midspan",x-2.2,x+1.9,y+7.05)
        decks(prefix+"Vault",x+6,x+15,y+7.35)
        chest(prefix+"Chest",x+12.7,y+7.35,index)
        deck(prefix+"Return",x+16,x+20,y+4.9)
        deck(prefix+"LowerReturn",x+20,x+25,y+2.5)
        label(prefix+"Sign","DECOR","SERVICE VAULT  /  UPPER ROUTE",x+2,y+2.95)
    def lower_loop(prefix,x,index):
        ramp(prefix+"Down",x,x+8,0,-1.85)
        decks(prefix+"Tunnel",x+8,x+32,-1.85)
        ramp(prefix+"Up",x+32,x+40,-1.85,1.85)
        deck(prefix+"OverheadA",x+2,x+13,2.55)
        deck(prefix+"OverheadB",x+16,x+27,2.55)
        deck(prefix+"OverheadC",x+31,x+39,2.55)
        deck(prefix+"CacheStep",x+13,x+15,0.19)
        deck(prefix+"CachePerch",x+19,x+23,0.24)
        chest(prefix+"RecessChest",x+21.35,.24,index)
        label(prefix+"Sign","DECOR","LOWER SERVICE TUNNEL",x+9,0.35)
    def enemies(items, gate):
        for i,(x,y,variant) in enumerate(items):
            node(f"Security{i+1:02}","Actors","CharacterBody3D",(x,y+(.75 if variant!=4 else 2.7),0),group=["level_enemies","damageable_enemies"],script=e("enemy"),variant=variant,patrol_right_limit=gate-12.0)
    def arena(hallx,gx,exitx,start):
        decks("ArmorFloor",hallx-3,exitx+6,0)
        for name,x in [("ForgeHallDoor",hallx),("Gate",gx)]:
            node(name,pos=(x,0,0),**({"script":e("hall")} if name=="ForgeHallDoor" else {}))
            asset("Door",name,"gate",0,0,0,rotation=v((0,1.5708,0)),scale=(.83,1,1))
            asset("PortalFrame",name,"arch",0,0,0,rotation=v((0,1.5708,0)),scale=(.83,1,1))
            node("Blocker",name,"StaticBody3D")
            node("CollisionShape3D",name+"/Blocker","CollisionShape3D",(0,3.2,0),shape=s("GateShape"))
            # The gate cannot be bypassed over or under the enclosed corridor.
            wall(name+"Lintel",x,6.49,8.5)
        node("Shield","ForgeHallDoor","Area3D",(3.6,1.75,0),collision_layer=0)
        node("Shape","ForgeHallDoor/Shield","CollisionShape3D",shape=s("ShieldShape"))
        node("ExitBarrier",typ="StaticBody3D",pos=(exitx,0,0))
        asset("Seal","ExitBarrier","gate",0,0,0,rotation=v((0,-1.5708,0)))
        node("CollisionShape3D","ExitBarrier","CollisionShape3D",(0,3.2,0),shape=s("GateShape"))
        wall("ExtractionEnd",exitx+5,0,14)
        checkpoint("ForgeHallCheckpoint",gx-6.4,0)
        asset("RepairBayHeal","TERRAIN","repair",gx-3.6,.40)
        label("RepairBay","DECOR","REPAIR BAY",gx-6.6,3.35)
        label("ArenaSign","DECOR","DRILL SERGEANT  /  SECURITY VAULT" if act==1 else "FORGE TITAN  /  MELTDOWN CHAMBER",(gx+exitx)/2,7.7)
        for index,x in enumerate([gx+9,gx+22,gx+34]):
            asset("ReactorBank"+str(index),"DECOR","reactor",x,0,-2.1)
        if act == 1:
            deck("SergeantEntryStep",gx+5,gx+9,1.85)
            deck("SergeantSideShelf",gx+10.5,gx+17,3.45)
            deck("SergeantRecoveryIsland",gx+34,gx+41,2.25)
            relay("SergeantLiftRelay","SergeantEvadeLift",gx+24.0,1.05,gx+30.6,.02,3.65,
                  True,operation="EVADE LIFT")
            label("SergeantLiftTip","DECOR","SHOOT TO RISE ABOVE THE DRILL",gx+29,5.35)
        else:
            asset("TitanWestHatch","TERRAIN","arena_hatch",gx+11,4.25,
                  deck_width=6.2,climb_height=4.25)
            deck("TitanHighRun",gx+19,gx+28,6.45)
            deck("TitanEastDrop",gx+38,gx+44,3.95)
            node("TitanVent","TERRAIN","Area3D",(gx+34,1.4,0),script=e("Biome"),
                 kind=6,dimensions=v((5.2,2.8,2.8)),tint="Color(1, 0.62, 0.28, 1)",period=3.8,offset=.8)
            label("TitanVentTip","DECOR","EXHAUST VENT  /  WATCH FOR THE PULSE",gx+34,4.85)
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
        decks(prefix+"LowerEast",edge+width,b-9,low)
        ramp(prefix+"ReturnRamp",b-9,b,low,-low)
        height = 6.25 if three_way else (3.55 if raised else 3.35)
        if three_way:
            deck(prefix+"ServiceStep",a+2,a+6,2.32)
            deck(prefix+"ServiceWest",a+7,a+19,2.95)
            decks(prefix+"ServiceEast",a+24,b-10,2.95)
            deck(prefix+"ServiceExit",b-9,b-4,2.5)
            deck(prefix+"UpperStep",a+12,a+17,5.1)
            deck(prefix+"UpperWest",a+18,a+26,height)
            if act == 1:
                deck(prefix+"UpperSpan",a+30,a+35,height+.35)
                deck(prefix+"UpperDip",a+38,a+42,height-1.0)
                deck(prefix+"UpperReturn",a+44,b-8,height)
                deck(prefix+"UpperEast",b-5,b-1,4.45)
            else:
                decks(prefix+"UpperSpan",a+30,b-13,height)
                deck(prefix+"UpperEast",b-10,b-3,4.95)
            label(prefix+"ServiceSign","DECOR","SERVICE WALKWAY",a+12,4.1)
            asset(prefix+"ServiceSupply","TERRAIN","repair",b-14,3.35)
        else:
            deck(prefix+"UpperStep",a+2,a+6,2.32)
            deck(prefix+"UpperWest",a+7,a+16,3.15)
            decks(prefix+"UpperSpan",a+20,b-15,height)
            deck(prefix+"UpperEast",b-11,b-3,2.7)
        chest(prefix+"UpperCache",b-11 if three_way and act==1 else max(a+31,b-18) if three_way else b-18,height,index)
        label(prefix+"UpperSign","DECOR","UPPER CATWALKS",a+21,height+1.35)
        label(prefix+"LowerSign","DECOR","LOWER TUNNEL",a+15,.05)
        asset(prefix+"LowerSupply","TERRAIN","energy",a+21,low+.40)

    def riser(prefix, a, b, index, base_y=0, height=6.15):
        # Spawn and ground end at the wall. The only forward exit is upstairs.
        left,right=a+13.5,a+17.5
        decks(prefix+"Approach",a,left+.42,base_y)
        wall(prefix+"Left",left,base_y+2.12,6.48,-.02)
        wall(prefix+"Right",right,base_y,height,-.02)
        ramp(prefix+"EntryRamp",left+.42,right-1.42,base_y,1.35)
        deck(prefix+"Sill",right-1.42,right-.40,base_y+1.35)
        decks(prefix+"UpperExit",right+.4,b,base_y+height)
        deck(prefix+"CacheShelf",left-12.5,left-.45,base_y+8.55)
        chest(prefix+"Cache",left-9.8,base_y+8.55,index)
        label(prefix+"Sign","DECOR","WALL KICK UP",left-2,base_y+3.45)

    def basement(prefix, western_end, entry, gate_x, join, cache_index, gap):
        floor, return_y = -8.5, -2.6
        # From the east drop, cross the sump to the west. The relay opens the
        # shutter upstairs. Climb out at the west end and retrace the route one tier up.
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
        decks(prefix+"Return",western_end+7.4,entry-5,return_y)
        deck(prefix+"ReturnTakeoff",entry-5,entry-3,return_y)
        decks(prefix+"ShutterApron",entry+2,gate_x-5,return_y)
        ramp(prefix+"ShutterRamp",gate_x-5,gate_x-1,return_y,-.4-return_y)
        decks(prefix+"Rejoin",gate_x-1,join,-.4)
        ramp(prefix+"RejoinLip",join,join+4,-.4,.4)
        wall(prefix+"RelaySightBaffle",western_end+15,floor-.45,1.95)
        relay(prefix+"LockRelay",prefix+"Lock",western_end+9,floor+1,gate_x,5.7,10.0,
              art="Shutter",operation="RETURN SHUTTER")
        wall(prefix+"GateSill",gate_x,-12.85,12.47)
        wall(prefix+"GateHeader",gate_x,8.3,12.0)
        for index in range(0, int(entry+11-western_end), 6):
            x=western_end+index+3
            asset(prefix+"Backwall"+str(index),"DECOR","Lining",x,-11.65,-2.87)
            if index%12 == 0:
                node(prefix+"Lamp"+str(index),"DECOR","OmniLight3D",(x,-5.7,-1.35),
                     light_color="Color(1, 0.33, 0.17, 1)",light_energy="1.35",omni_range="8.0")
        label(prefix+"Enter","DECOR","DROP TO SUBLEVEL",entry+1,-1.7,z=-1.7)
        label(prefix+"SumpSign","DECOR","<  SHUTTER CONTROL",entry-8,floor+2.6,z=-1.7)
        label(prefix+"TurnSign","DECOR","RETURN LADDER  /  EAST EXIT  >",western_end+6,return_y+1.25,z=-1.7)
        label(prefix+"GateSign","DECOR","SHUTTER  /  OPEN FROM SUBLEVEL",gate_x-3,2.1,z=-1.7)
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
        label("GantryEntry","DECOR","UP  /  COOLING GANTRY",78.2,8.35)
        deck("GantryLaunch",70.9,75.35,13.4)
        deck("GantryColdPipes",61.3,69.0,14.7)
        deck("GantryWestLanding",47.3,52.1,14.45)
        deck("GantrySalvage",38.3,44.0,15.55)
        chest("CoolingOverheadCache",40.3,15.55,8)
        label("GantryCross","DECOR","<  AIR DASH TO THE WEST GANTRY",63.5,16.85)
        deck("GantryTurnWest",31.8,36.15,12.7)
        deck("GantryReturnStart",32.8,40.5,10.15)
        deck("GantryReturnDown",40.5,52.8,10.15)
        ramp("GantryPipeUnderpass",52.8,56.6,10.15,-.8)
        deck("GantryReturnIsland",56.6,61.2,9.35)
        deck("GantryReturnEast",65.0,71.5,8.95)
        # The lower return meets the service deck under the launch side.
        label("GantryReturnSign","DECOR","MAINTENANCE RETURN  >",46.2,11.8)
        hazard("GantryLaser",48.8,14.45,1,1.8)
        for index,(x,y) in enumerate([(80.05,12.1),(64.4,14.7),(49.1,14.45),(40.3,15.55)]):
            overhead_brace("CoolingGantryBrace"+str(index),x,y)

    def refinery_high_route():
        # The lift rises from the forge riser. The eastbound crane level
        # returns west along the lower inspection decks and drops onto slag ramp.
        relay("HighFreightRelay","HighFreightLift",323.7,7.25,331.5,6.15,10.1,
              True,operation="RAISE CRANE LIFT")
        label("HighFreightEntry","DECOR","CRANE LEVEL  /  SHOOT THEN BOARD",329,9.5)
        deck("CraneDisembark",337.7,346.6,16.25)
        deck("CraneEastSpan",354.8,362.4,17.05)
        deck("CraneVault",368.5,377.1,16.95)
        chest("CraneLevelCache",373.5,16.95,4)
        label("CraneTraverse","DECOR","AIR DASH  /  EAST CRANE SPAN  >",342.6,18.35)
        deck("CraneTurnDown",379.15,383.8,14.2)
        deck("CraneInspectionEast",374.0,378.8,11.85)
        deck("CraneInspectionWest",362.8,369.9,10.6)
        deck("CraneExitChute",353.7,360.4,8.45)
        deck("RefineryReturnLanding",350.3,353.3,6.95)
        label("CraneReturnSign","DECOR","<  WEST RETURN TO REFINERY",367.7,12.2)
        hazard("CranePress",358.5,17.05,2,.95)
        for index,(x,y) in enumerate([(341.5,16.25),(359,17.05),(373.6,16.95)]):
            overhead_brace("CraneBrace"+str(index),x,y)

    if act==1:
        hall,gate,exit=419,432,483
        shell(exit,gate,[(39,103),(165,231),(270,324)])
        decks("Intake",-14,14,0)
        decks("IntakeLanding",19,35,0)
        spikes("IntakeSpikes",14,19,-4.0)
        fork("Cooling",35,93,1,three_way=True)
        cooling_gantry()
        decks("Conveyor",93,117,0)
        riser("ConduitShaft",117,158,3)
        decks("ChannelLeft",158,170.5,6.15)
        decks("ChannelRight",176.5,189,6.15)
        decks("MaintenanceCatch",170.5,176.5,3.45)
        deck("CatchStair",174.2,176.5,4.75)
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
        deck("ForgeApproachRamp",403,409,-1.1,1.2)
        deck("ForgeApproachLanding",409,412,1.2)
        ramp("ForgeHallSlope",412,hall-3,1.2,-1.2)
        label("OutgoingGapSign","DECOR","JUMP / AIR DASH ACROSS",379,2.3)
        for i,(x,y,kind) in enumerate([(28,0,0),(66,-2.05,1),(149,6.15,2),(184,-8.5,0),(253,-1.35,1),(300,0,2),(344,6.15,1)]):
            hazard("SafetyHazard"+str(i+1),x,y,kind,i*.37)
        label("SectorTitle","DECOR","NEON FACTORY  /  ACT I",4,3.15)
        label("BridgeSign","DECOR","SERVICE BRIDGE  /  SHOOT THE RED RELAY",163,9.25)
        enemies([(22,0,0),(47,-2.05,1),(59,6.25,4),(101,0,2),(150,6.15,0),(181,6.15,3),(176,-8.5,4),(219,-.4,2),(245,-1.35,1),(273,3.55,3),(291,0,2),(336,6.15,4),(365,1.1,0)],gate)
    else:
        hall,gate,exit=467,480,531
        shell(exit,gate,[(49,110),(196,264),(327,372)])
        decks("SmelterIntake",-14,12,0)
        deck("OverfeedPier",17.3,21,0.6)
        spikes("IntakeFirstSpikes",12,17.3,-4.1)
        spikes("IntakeSecondSpikes",21,26.5,-3.9)
        ramp("OverfeedLanding",26.5,30,0.6,-0.6)
        fork("CoolingDeck",30,83,6,True)
        decks("TransferWalk",83,101,0)
        riser("IntakeRiser",101,141,8)
        decks("HotApron",141,152,6.15)
        deck("HotApronIsland",158,164,5.4)
        ramp("HotApronDown",169.5,191,5.4,-5.4)
        deck("IntakeLip",191,196,0)
        basement("SlagBasement",160,201,234,240,0,(25.4,30.4))
        relay("FreightRelay","FreightLift",210,-1.6,216,-2.6,7.6,True)
        decks("FreightLanding",218,230,5)
        deck("FreightReturn",230.3,234,3.1)
        chest("FreightVaultChest",225,5,9)
        decks("TransferApron",244,248,0)
        checkpoint("MidpointCheckpoint",245,0)
        fork("FuelLine",248,293,10,three_way=True)
        decks("RiserApproach",293,297,0)
        riser("Riser",297,344,11)
        refinery_high_route()
        deck("RightStairA",344,348,4.45)
        deck("RightStairB",348,353,2.65)
        ramp("SlagRamp",353,362,2.65,-2.65)
        fork("Refinery",362,405,5,True)
        decks("SmelterExit",405,418,0)
        decks("SlagBridge",427.4,441,0)
        spikes("SmelterSpikes",418,427.4,-4.25)
        spikes("SlagGapSpikes",441,448.7,-4.15)
        deck("SlagVentIsland",448.7,454,.6)
        deck("SlagFerryApproach",429.6,433.2,1.85)
        deck("SlagFerryAlternateEntry",429.8,434,3.7)
        relay("SlagFerryRelay","SlagFerry",432.2,4.7,437.8,4.1,2.45,True,operation="SEND SLAG FERRY",dx=7.6)
        deck("SlagVaultWestboundLedge",441.9,445.5,6.55)
        deck("SlagVaultReturn",437.4,440,7.15)
        deck("SlagVaultTurn",430.2,434.9,7.55)
        chest("SlagFerryCache",432.6,7.55,3)
        label("SlagFerrySign","DECOR","FERRY TO THE HIGH SALVAGE ROUTE",431.8,5.5)
        ramp("SlagHallRamp",454,hall-3,.6,-.6)
        label("OutgoingGapSign","DECOR","JUMP / AIR DASH ACROSS",415,2.3)
        for i,(x,y,k) in enumerate([(37,-.94,2),(57,-1.35,1),(93,0,0),(135,6.15,2),(177,-8.5,1),(223,-2.6,2),(333,6.15,0),(389,-1.35,1),(401,-.6,2)]):
            hazard("SafetyHazard"+str(i+1),x,y,k,i*.42)
        label("SectorTitle","DECOR","NEON FACTORY  /  ACT II",4,3.15)
        label("LiftSign","DECOR","SHOOT RELAY FOR THE FREIGHT VAULT",211,0.95)
        enemies([(29,.18,0),(46,-1.35,2),(69,3.55,4),(90,0,1),(144,6.15,0),(165,6,4),(202,-8.5,3),(224,5,2),(231,-2.1,3),(260,-1.87,2),(280,6.25,1),(322,6.15,2),(374,-1.35,0),(397,2.4,4)],gate)
    wall("AirlockEnd",-13,0,14)
    arena(hall,gate,exit,0)
    file.write_text('\n'.join(header)+'\n\n'+'\n\n'.join(nodes)+'\n',encoding="utf8")
for act in [1,2]: make(act)
