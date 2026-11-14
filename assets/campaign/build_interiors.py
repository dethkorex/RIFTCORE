"""Author native Godot terrain and relocate the encounters from the original scenes."""
import argparse
import math
import re
from pathlib import Path

from branch_junctions import JUNCTIONS, ROUTE_BEATS
from exterior_routes import EXTERIORS
from interior_routes import ROUTES
from overhead_routes import ARENAS, OVERHEAD

PROJECT = Path(__file__).resolve().parents[2]
LEVELS = PROJECT / "scenes/levels"
FACTORY = "res://assets/neon_factory/interiors/"
ACCENTS = ["87dc3d", "57ceff", "34ebe0", "ffab51", "43f9c5", "ff62b6", "aa87ff", "ff7d36", "ff497b"]
HAZARDS = [
    ((1, "ROOT FLOOD"), (4, "BURN THE SPORE POD")),
    ((0, "ICE / BRAKE EARLY"), (4, "COOLANT PURGE")),
    ((1, "CURRENT / HIGH ROUTE ABOVE"), (5, "LIVE ELECTRODES")),
    ((10, "CORRUPTED SCANS"), (10, "RECORD PURGE")),
    ((2, "CROSSWIND"), (6, "UPDRAFT / JUMP BOOST")),
    ((7, "QUARANTINE GAS"), (4, "STERILIZATION VENT")),
    ((3, "LOW GRAVITY"), (8, "SOLAR FLARE")),
    ((2, "MAGNETIC PULL"), (9, "SCRAP CRUSHER")),
    ((3, "RIFT GRAVITY"), (10, "CORRUPTION SURGE")),
]
# Each sector sets its own rhythm and force for the existing terrain devices.
HAZARD_TIMING = [5.3, 4.7, 4.2, 5.4, 3.5, 5.5, 4.0, 4.9, 3.7]
FIELD_STRENGTH = [0.68, 1.22, 1.40, 1.0, 1.25, 1.0, 1.18, 1.34, 0.78]
PIT_Y = -22.0
# RX-07, stock gear, 60 Hz: 7.65 m running jump, 2.895 m apex,
# 12.27 m with a late air dash; 11.07 m onto a 1 m higher landing.
RUN_REACH = 7.65
DASH_REACH = 12.27
SAFE_RUN_GAP = round(RUN_REACH * .69, 2)
SAFE_DASH_GAP = round(DASH_REACH * .76, 2)
MIDDLE_RISE = 3.35
UPPER_RISE = 4.85
ROOF_CLEARANCE = 12.0
JUNCTION_FIELDS = {
    "ICE": (0, "ICE / EARLY BRAKE"), "ROOT POOL": (1, "ROOT POOL / CURRENT"),
    "CURRENT": (1, "CURRENT"), "WIND": (2, "CROSSWIND"),
    "MAGNET": (2, "MAGNETIC PULL"), "GRAVITY": (3, "LOW GRAVITY"),
    "SPORE POD": (4, "BURNABLE SPORE POD"), "COOLANT": (4, "COOLANT PURGE"),
    "VENT": (4, "STERILIZER"), "ELECTRODES": (5, "LIVE ELECTRODES"),
    "UPDRAFT": (6, "UPDRAFT / JUMP BOOST"), "MUTATION": (7, "MUTATION GAS"),
    "SOLAR": (8, "SOLAR FLARE"), "PRESS": (9, "CRUSHER"),
    "CORRUPTION": (10, "CORRUPTION"), "LASER": (-1, "LASER"), "PHASE": (-2, "PHASE CYCLE"),
}
DEVICE_NAMES = [
    ("ROOT FERRY", "SEED HOIST"), ("THAW BRIDGE", "COOLANT LIFT"),
    ("SLUICE BRIDGE", "BALLAST LIFT"), ("RECORD TRANSFER", "STACK HOIST"),
    ("TRUSS BRIDGE", "CARGO ELEVATOR"), ("CONTAINMENT SPAN", "SPECIMEN HOIST"),
    ("ALIGN ARRAY", "CALIBRATION LIFT"), ("SCRAP TRANSFER", "MAGNETIC CRANE"),
    ("RIFT BRIDGE", "CORE ELEVATOR"),
]


def vec(*values):
    return "Vector3(" + ", ".join(f"{value:.5g}" for value in values) + ")"


def ext(name):
    return f'ExtResource("{name}")'


def sub(name):
    return f'SubResource("{name}")'


def coordinates(block):
    for line in block.splitlines()[1:]:
        if line.startswith(("position = ", "transform = ")):
            numbers = line.split("(", 1)[1].split(")", 1)[0].split(",")
            return tuple(float(value) for value in numbers[-3:])
    return 0, 0, 0


def relocate(block, x, y, z):
    lines = block.strip().splitlines()
    for i, line in enumerate(lines):
        if line.startswith("transform ="):
            values = line.split("(", 1)[1].strip(")").split(",")
            values[-3:] = [f" {value:.5g}" for value in (x, y, z)]
            lines[i] = "transform = Transform3D(" + ",".join(values) + ")"
            return "\n".join(lines)
        if line.startswith("position ="):
            lines[i] = "position = " + vec(x, y, z)
            return "\n".join(lines)
    lines.insert(1, "position = " + vec(x, y, z))
    return "\n".join(lines)


class Scene:
    def __init__(self, sector, number, act):
        self.sector = sector
        self.number = number
        self.act = act
        self.nodes = []
        self.assets = dict(Deck="deck", Wall="wall", Room="room", Fixture="fixture")
        self.spawns = []
        self.rooms = []
        self.cache_count = 0
        self.cave_entrance = None
        self.exterior = EXTERIORS[sector][act-1]
        self.accent = ACCENTS[number - 2]
        self.chamber = ""

    def header(self, old_header):
        assets = [(f"RC{kind}", f"res://assets/campaign/{self.sector}/interior/{self.sector}_{stem}.glb", "PackedScene")
                  for kind, stem in self.assets.items()]
        assets += [("RCDoorRelay", FACTORY + "shot_relay.glb", "PackedScene"),
                   ("RCCache", FACTORY + "salvage_chest.glb", "PackedScene"),
                   ("RCRelayScript", "res://scripts/factory_interior_relay.gd", "Script"),
                   ("RCCacheScript", "res://scripts/factory_salvage_chest.gd", "Script"),
                   ("RCBiome", "res://scripts/biome_zone.gd", "Script"),
                   ("RCShutter", FACTORY + "service_shutter.tscn", "PackedScene"),
                   ("RCPhase", f"res://assets/campaign/{self.sector}/terrain/phase.tscn", "PackedScene"),
                   ("RCHatch", f"res://assets/campaign/{self.sector}/terrain/climb_platform_center.tscn", "PackedScene"),
                   ("RCPit", "res://scripts/spike_pit.gd", "Script"),
                   ("RCLaser", "res://scripts/factory_interior_trap.gd", "Script"),
                   ("RCFont", "res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.ttf", "FontFile")]
        panorama = ("res://assets/machine_jungle/jungle_panorama.png" if self.sector == "machine_jungle"
                    else f"res://assets/campaign/{self.sector}/panorama.png")
        arch = ("res://assets/machine_jungle/terrain/root_arch.tscn" if self.sector == "machine_jungle"
                else f"res://assets/campaign/{self.sector}/terrain/arch.tscn")
        assets.extend([("RCSky", "res://scripts/jungle_backdrop.gd", "Script"),
                       ("RCPanorama", panorama, "Texture2D"),
                       ("RCExteriorFrame", arch, "PackedScene")])
        if self.sector == "machine_jungle":
            assets.extend([
                ("RCJungleBank", "res://assets/campaign/machine_jungle/interior/jungle_root_bank.glb", "PackedScene"),
                ("RCJungleMouth", "res://assets/campaign/machine_jungle/interior/jungle_cave_mouth.glb", "PackedScene"),
            ])
            for hatch in ("left", "right"):
                path = f"res://assets/campaign/machine_jungle/terrain/climb_platform_{hatch}.tscn"
                assets.append(("RCVine" + hatch.title(), path, "PackedScene"))
        new_ext = "\n".join(f'[ext_resource type="{kind}" path="{path}" id="{key}"]' for key, path, kind in assets)
        header = old_header.rstrip()
        idx = header.find("[sub_resource")
        header = header[:idx] + new_ext + "\n\n" + header[idx:]
        header = re.sub(r" load_steps=\d+", "", header, count=1)
        return header + """

[sub_resource type="BoxShape3D" id="RCRelayShape"]
size = Vector3(0.86, 0.84, 0.7)

[sub_resource type="SphereMesh" id="RCRelayLamp"]
radius = 0.21
height = 0.42

[sub_resource type="BoxShape3D" id="RCCacheShape"]
size = Vector3(1.52, 1.25, 1.5)"""

    def node(self, name, *, parent=None, kind="Node3D", art=None, pos=None, group=None, **properties):
        parent = parent or self.chamber
        tag = f'[node name="{name}"'
        if art is None:
            tag += f' type="{kind}"'
        tag += f' parent="{parent}"'
        if group:
            tag += f' groups=["{group}"]'
        if art:
            tag += f" instance={ext(art)}"
        lines = [tag + "]"]
        if pos is not None:
            lines.append("position = " + vec(*pos))
        lines.extend(f"{key} = {value}" for key, value in properties.items())
        self.nodes.append("\n".join(lines))
        return f"{parent}/{name}" if parent != "." else name

    def solid(self, name, art, pos, dimensions, art_scale, offset=0, angle=0, moving=False, layer=1):
        body = self.node(name, pos=pos, kind="AnimatableBody3D" if moving else "StaticBody3D",
                         rotation=vec(0, 0, angle), collision_layer=layer)
        self.node("Art", parent=body, art="RC" + art, scale=vec(*art_scale))
        shape = f"BoxShape3D_{len(self.nodes):04d}"
        self.shapes.append(f'[sub_resource type="BoxShape3D" id="{shape}"]\nsize = {vec(*dimensions)}')
        self.node("Collision", parent=body, kind="CollisionShape3D", pos=(0, offset, 0), shape=sub(shape))

    def deck(self, name, a, b, low, high=None, thin=False, moving=False):
        high = low if high is None else high
        length = math.hypot(b-a, high-low)
        height = .46 if thin else .84
        self.solid(name, "Deck", ((a+b)/2, (low+high)/2, 0), (length+.006, height, 4.8),
                   (length/6, height/.84, 1), -height/2, math.atan2(high-low,b-a), moving)

    def stretch(self, name, a, b, y, thin=False):
        n = max(1, math.ceil((b-a)/7.5))
        for i in range(n):
            self.deck(f"{name}{i:02d}", a+(b-a)*i/n, a+(b-a)*(i+1)/n, y, thin=thin)

    def spike_pit(self, name, a, b, y):
        self.node(name,kind="Area3D",script=ext("RCPit"),pos=((a+b)/2,y,0),
                  width=b-a,tint=self.color())
        self.label(name+"Sign","SPIKES  /  JUMP",a-2.0,y+3.7,z=-1.65,pixels=.0042)

    def wall(self, name, x, bottom, top):
        height = top-bottom
        self.solid(name, "Wall", (x, bottom+height/2, 0), (.79, height, 4.0), (1,height/4.25,1))

    def color(self, shade=None):
        shade = shade or self.accent
        return "Color(" + ", ".join(str(round(int(shade[i:i+2], 16)/255, 4)) for i in (0,2,4)) + ", 1)"

    def label(self, name, message, x, y, z=-2.15, parent=None, pixels=.0046):
        self.node(name, parent=parent, kind="Label3D", pos=(x,y,z), text=f'"{message}"',
                  font=ext("RCFont"), font_size=54, outline_size=10, pixel_size=pixels, modulate=self.color())

    def jungle_opening(self, b, floor):
        if b != self.cave_entrance:
            return
        parent = self.node("OpenCanopy")
        self.node("CaveMouth", parent=parent, art="RCJungleMouth",
                  pos=(b,floor,-.12), rotation=vec(0,-math.pi/2,0))
        self.label("CaveMouthSign","ROOT CAVES",b-3.4,floor+3.1,z=-1.45,
                   parent=parent,pixels=.0052)
        if self.act == 1:
            self.solid("RootCellarCanopy","Deck",(b+3.1,floor+4.55,0),
                       (7.4,.84,4.8),(7.4/6.0,1,1),-.42)

    def jungle_bank(self, name, a, b, from_y, to_y):
        span = math.hypot(b-a,to_y-from_y)
        self.node(name,art="RCJungleBank",pos=((a+b)*.5,(from_y+to_y)*.5,0),
                  scale=vec(span/6.0,1,1),rotation=vec(0,0,math.atan2(to_y-from_y,b-a)))

    def jungle_traverse(self, a, p, q, floor):
        if self.act == 1:
            gap = p+7.0
            self.stretch("NurseryBank",p,gap,floor)
            self.spike_pit("NurseryThorns",gap,gap+4.45,floor-3.25)
            self.deck("NurseryStep",gap+4.45,gap+9.0,floor+.80)
            self.deck("NurseryRamp",gap+9.0,q-3,floor+.80,floor+2.10)
            self.deck("NurseryTop",q-3,q,floor+2.10)
            self.jungle_bank("NurseryBedrock",a,gap,floor,floor)
            self.jungle_bank("NurseryFarBedrock",gap+4.45,gap+9.0,floor+.80,floor+.80)
            self.jungle_bank("NurseryRisingBedrock",gap+9.0,q-3,floor+.80,floor+2.10)
            self.deck("CanopyCacheDeck",gap-10.0,gap-5.1,floor+2.15,thin=True)
            self.cache(gap-7.6,floor+2.15)
            self.spawns.append((q-2,floor+2.10))
            return floor+2.10
        gap = p+6.4
        self.stretch("ViaductBank",p,gap,floor)
        self.spike_pit("ViaductThorns",gap,gap+6.05,floor-3.25)
        self.deck("ViaductLanding",gap+6.05,gap+11.8,floor+.6)
        self.deck("ViaductSecondLanding",gap+15.1,gap+20.7,floor-.58)
        self.spike_pit("ViaductUnderpassThorns",gap+11.8,gap+15.1,floor-3.7)
        self.deck("ViaductDescent",gap+20.7,q,floor-.58,floor-1.60)
        self.jungle_bank("ViaductBedrock",a,gap,floor,floor)
        self.jungle_bank("ViaductIslandBedrock",gap+6.05,gap+11.8,floor+.6,floor+.6)
        self.jungle_bank("ViaductFarBedrock",gap+15.1,gap+20.7,floor-.58,floor-.58)
        self.jungle_bank("ViaductDescendingBedrock",gap+20.7,q,floor-.58,floor-1.60)
        self.spawns.append((q-2,floor-1.60))
        self.label("ViaductDashSign","JUMP / AIR DASH",gap-2.8,floor+1.25,z=-1.6)
        return floor-1.60

    def exposed_shell(self, start, end, entry_y, exit_y, *, end_frame=True):
        parent = self.node("ExteriorView", **{"metadata/begin": start, "metadata/end": end})
        span = end-start
        # A low rear retaining wall leaves the panorama visible behind each landing.
        blocks = math.ceil(span/8.4)
        for index in range(blocks):
            offset = (index+.5)/blocks
            y = entry_y + (exit_y-entry_y)*offset
            self.node(f"RearSkirt{index}", parent=parent, art="RCRoom",
                      pos=(start+span*offset,y-7.52,-4.35),
                      scale=vec(span/blocks/6,.71,1.0))
            if index%3==1:
                self.node(f"Pier{index}",parent=parent,art="RCWall",
                          pos=(start+span*offset,y-5.5,-3.12),
                          scale=vec(1.6,1.45,.66))
        if end_frame:
            self.node("ReturnFrame", parent=parent, art="RCExteriorFrame",
                      pos=(end-.72,exit_y,0), rotation=vec(0,-math.pi/2,0),
                      scale=vec(1.43,1.36,1.10))
            self.label("ReturnSign", self.exterior.exit_sign, end-2.1,exit_y+3.86,z=-2.15,
                       parent=parent,pixels=.0041)

    def exterior_traverse(self, p, q, floor):
        route = self.exterior
        width = q-p
        gap_left = p + width * (.40 if route.style == "ridge" else .29)
        gap_right = gap_left + route.gap
        shelf = floor+route.shelf_rise
        high = floor+route.exit_rise
        depart = floor
        if route.style == "ridge":
            self.stretch("EaveApproach",p,gap_left-4.5,floor)
            self.deck("EaveRidge",gap_left-4.5,gap_left-1.8,floor,floor+.32)
            depart = floor+.32
            self.deck("EaveTakeoff",gap_left-1.8,gap_left,depart)
        else:
            self.stretch("EaveApproach",p,gap_left,depart)
        spike_y = min(depart,shelf)-3.4
        self.spike_pit("ExteriorSpikes",gap_left,gap_right,spike_y)
        self.label("ExteriorJumpSign","AIR DASH" if route.gap>6.4 else "JUMP",
                   gap_left-1.9,depart+1.33,z=-1.65)
        if route.style == "stepped":
            second = min(q-4.0,gap_right+6.0)
            self.deck("EaveStep",gap_right,second,shelf)
            self.deck("EaveLowerStep",second+1.4,q,high)
        else:
            grade = min(q-2.4,gap_right+4.25)
            self.deck("EaveLanding",gap_right,grade,shelf)
            self.deck("EaveReturn",grade,q-1.5,shelf,high)
            self.deck("EaveEnd",q-1.5,q,high)
        self.spawns.append((q+1.75,high))
        if route.style == "ledge" and width >= 25:
            self.deck("EaveLookout",p+.8,p+5.5,floor+2.15,thin=True)
            self.cache(p+3.5,floor+2.15,blueprint=False)
        return high

    def shell(self, a, b, floor, roof, variation, cave_lip_floor=None):
        if self.cave_entrance is not None and a < self.cave_entrance:
            opening_end = min(b,self.cave_entrance)
            self.jungle_opening(opening_end,cave_lip_floor if cave_lip_floor is not None else floor)
            if opening_end >= b:
                return
            a = opening_end
        parent = self.node(f"InteriorCladding_{variation}")
        roof += ROOF_CLEARANCE
        length = b-a
        n = math.ceil(length/7.0)
        panel = length/n
        for i in range(n):
            x = a+(i+.5)*panel
            recess = .60 if (i+variation)%3==1 else 0
            self.node(f"Bulkhead{i}", parent=parent, art="RCRoom", pos=(x,floor-1.1,-3.4-recess),
                      scale=vec(panel/6, (roof-floor+1.1)/8, 1))
            if (i+variation)%5 == 2:
                self.node(f"SectorFixture{i}", parent=parent, art="RCFixture",
                          pos=(x,floor+.75,-2.67-recess))
            if (i+variation)%3 == 0:
                self.node(f"BayLight{i}", parent=parent, kind="OmniLight3D", pos=(x,roof-1.9,-1.85),
                          light_color=self.color(), light_energy=.8, omni_range=8.5)
        # Ceiling and lower skirt extend off the gameplay plane.
        for i in range(math.ceil(length/13)):
            x = a+(i+.5)*length/math.ceil(length/13)
            self.node(f"Ceiling{i}", parent=parent, art="RCDeck", pos=(x,roof,-1.25),
                      scale=vec(length/math.ceil(length/13)/6,1.6,1.9))
            self.node(f"Foundation{i}", parent=parent, art="RCRoom", pos=(x,floor-9,-2.2),
                      scale=vec(length/math.ceil(length/13)/6,1,1))

    def relay(self, x, y, name, dy, lift, operation=None, dx=0):
        target = self.node(f"{name}Relay", kind="StaticBody3D", pos=(x,y+1,0), group="factory_shot_relay",
                           script=ext("RCRelayScript"), collision_layer=16, collision_mask=0,
                           platform_path=f'NodePath("../{name}")', travel=vec(dx,dy,0),
                           operation=f'"{operation or DEVICE_NAMES[self.number-2][int(lift)]}"', lift=str(lift).lower(),
                           repeat_hold=5.2 if self.number in (6,9) else 6.5)
        self.node("Casing", parent=target, art="RCDoorRelay", pos=(0,-.26,0))
        self.node("Collision", parent=target, kind="CollisionShape3D", shape=sub("RCRelayShape"))
        self.node("Lamp", parent=target, kind="MeshInstance3D", pos=(0,0,.26), mesh=sub("RCRelayLamp"))
        self.label("Status", "SHOOT TARGET", 0, 1.2, -1.35, parent=target)

    def cache(self, x, y, blueprint=True):
        # Keep the name unique within the sector's checkpoint state.
        self.cache_count += 1
        part = (self.act-1)*6+self.cache_count-1
        if self.cache_count > 6:
            blueprint = False
        self.node(f"InteriorCache{self.cache_count:02d}", parent="TERRAIN", kind="Area3D", pos=(x,y,0),
                  group="factory_salvage_chest", script=ext("RCCacheScript"), sector=self.number,
                  blueprint=f'"bp_{self.number:02d}_{part:02d}"' if blueprint else '""',
                  bolts=60+self.number*13+self.act*22, materials=3+self.act, experience=25+self.number*4,
                  collision_layer=0, collision_mask=1)
        path = f"TERRAIN/InteriorCache{self.cache_count:02d}"
        self.node("Casing", parent=path, art="RCCache")
        self.node("Collision", parent=path, kind="CollisionShape3D", pos=(0,.56,0), shape=sub("RCCacheShape"))
        self.label("Sign", "SALVAGE CACHE", 0, 1.22, -.25, parent=path, pixels=.0033)

    def hazard(self, x, y, exposed):
        kind, label = HAZARDS[self.number-2][int(exposed)]
        if exposed and self.number == 10 and self.act == 2:
            kind = -1
        self.field("Hazard", x, y, kind, label)

    def field(self, name, x, y, kind, label, direction=1.0, width=0.0, field_height=0.0):
        if kind == -1:
            self.node(name, pos=(x,y,0), script=ext("RCLaser"), kind="Area3D",
                      group="factory_interior_trap", collision_layer=0, collision_mask=1)
            self.nodes[-1] += "\nkind = 1"
            return
        if kind == -2:
            self.node(name, art="RCPhase", pos=(x,y+2.3,0), period=4.4 if self.act==1 else 3.6,
                      phase_offset=0.65 if self.act==1 else 1.15)
        else:
            pod = self.sector == "machine_jungle" and kind == 4
            width = width or (3.6 if kind >= 4 else 8.2)
            height = field_height or (2.35 if pod else 2.6)
            self.node(name, kind="Area3D", pos=(x,y+height/2,0), script=ext("RCBiome"),
                      dimensions=vec(width,height,2.65), tint=self.color(),
                      offset=1.3 if self.act == 1 else 2.15,
                      period=HAZARD_TIMING[self.number-2] - (0.54 if self.act == 2 else 0),
                      terrain_strength=FIELD_STRENGTH[self.number-2],
                      power=13+self.number+(self.act-1)*3, direction=direction,
                      burnable_spore_pod=str(pod).lower())
            self.nodes[-1] += f"\nkind = {kind}"
        self.label(name+"Sign", label, x, y+2.8, z=-1.60)

    def junction(self, spec, p, q, floor, beat):
        """Build parallel lanes above a lower crossing and rejoin at the right apron."""
        end = q-12
        mid = floor+MIDDLE_RISE
        high = mid+UPPER_RISE
        mid_gap = SAFE_DASH_GAP if self.act == 2 else SAFE_RUN_GAP
        gap_center = (p+end)*.5 + (2.2 if self.act==2 else -1.5)
        start_step = p+17 if spec.upper_route in ("late","reverse","lift") else p+7
        upper_start = start_step+7
        self.stretch("ForkApron",p,p+5,floor)
        self.deck("MiddleStep",p+1.0,p+4.5,floor+1.45,thin=True)
        self.deck("MiddleUpperStep",p+5,p+8.5,floor+2.2,thin=True)

        if spec.upper_route == "lift":
            self.stretch("MiddleWest",p+9.2,upper_start-5.6,mid,thin=True)
            self.stretch("MiddleAfterHoist",upper_start-1.2,gap_center-mid_gap*.5,mid,thin=True)
        else:
            self.stretch("MiddleWest",p+9.2,gap_center-mid_gap*.5,mid,thin=True)
        middle_landing = gap_center+mid_gap*.5
        self.stretch("MiddleEast",middle_landing,middle_landing+5.8,mid,thin=True)
        self.route_crossovers(spec, beat, middle_landing+5.8, end, mid, high)
        if not spec.depth:
            self.deck("MiddleMerge",end,end+3.25,mid,floor+1.08,thin=True)
        else:
            self.label("MiddleDropSign","DROP TO THE BASEMENT",end-9.0,mid+1.2,z=-1.7)
        self.label("MiddleRouteSign",spec.lanes[1]+"  >",p+9,mid+1.72,z=-1.7)
        self.label("LowRouteSign",spec.lanes[0]+"  >",p+8,floor+1.25,z=-1.7)
        self.label("MiddleGapSign", "AIR DASH ACROSS" if self.act == 2 else "RUNNING JUMP",
                   gap_center-mid_gap*.5-2.8, mid+1.1, z=-1.55)
        self.label("HighRouteSign",spec.lanes[2],upper_start+4,high+1.75,z=-1.7)

        if spec.upper_route == "reverse":
            left_end = gap_center-6
            self.stretch("UpperWestVault",p+10,left_end,high,thin=True)
            self.deck("UpperWestTurn",left_end+2.7,left_end+5.4,high-.15,thin=True)
            self.deck("UpperEastTurn",gap_center+13.6,gap_center+17.5,mid+1.6,thin=True)
            self.deck("UpperReturnLow",gap_center+9.1,gap_center+12.5,high-1.74,thin=True)
            self.deck("UpperReturnTurn",gap_center+4.9,gap_center+8.25,high-.65,thin=True)
            self.deck("UpperReturnWest",gap_center+.5,gap_center+3.6,high-.06,thin=True)
            self.label("UpperWestSign","<  SALVAGE VAULT",left_end-2,high+1.3,z=-1.65)
            self.deck("VaultExitStep",p+6.3,p+9.1,mid+1.45,thin=True)
            self.deck("VaultSecondStep",p+7.9,p+9.9,mid+3.0,thin=True)
            self.cache(left_end-1.6,high,blueprint=False)
            self.cache(p+12,high)
        elif spec.upper_route == "lift":
            x = upper_start-3.4
            self.deck("BalconyHoist",x-2.2,x+2.2,mid,thin=True,moving=True)
            self.relay(x-3.0,mid,"BalconyHoist",high-mid,True)
            self.stretch("UpperBalcony",upper_start,end-3,high,thin=True)
            self.deck("BalconyExit",end-1,end+4,mid+1.55,thin=True)
            self.cache(end-5,high)
        else:
            if spec.upper_route == "vine":
                self.node("CanopyHatch",art="RCHatch",pos=(upper_start,high,0),deck_width=4.0,climb_height=high-mid)
                upper_start += 2
            else:
                if spec.upper_route == "late":
                    # Reach the upper route after crossing the middle; then traverse it west.
                    east_step = gap_center + mid_gap*.5 + 7.5
                    self.deck("LateUpperStep",east_step,east_step+4,mid+1.45,thin=True)
                    self.deck("LateUpperSecond",east_step-3.2,east_step-.55,mid+3.13,thin=True)
                    upper_start = p+11
                    self.label("LateAccessSign","<  UPPER SALVAGE",east_step,mid+2.75,z=-1.65)
                else:
                    self.deck("UpperEntryStep",start_step,start_step+4.0,mid+1.45,thin=True)
                    self.deck("UpperSecondStep",start_step+4.5,start_step+7,mid+3.13,thin=True)
            if spec.upper_route == "boost":
                self.field("BoostVent",start_step+.8,mid,6,"VENT TO UPPER DECK",width=2.65)
            if spec.upper_route == "phase":
                self.stretch("UpperBeforePhase",upper_start,gap_center-3.4,high,thin=True)
                self.node("PhaseSpan",art="RCPhase",pos=(gap_center,high,0),period=3.9,
                          phase_offset=1.38 if self.act==2 else .44)
                self.stretch("UpperAfterPhase",gap_center+3.4,end-3,high,thin=True)
            else:
                self.stretch("UpperWalk",upper_start,end-3,high,thin=True)
            self.deck("BalconyExit",end-1,end+4,mid+1.55,thin=True)
            self.cache(upper_start+3 if spec.upper_route == "late" else end-5,high)

        lower_kind, lower_label = JUNCTION_FIELDS[spec.lower_field]
        if spec.depth:
            bottom = self.switchback(spec,p,q,floor,end,lower_kind,lower_label)
        else:
            low = floor-1.6
            bottom = low-1.0
            self.deck("LowerDown",p+5,p+11,floor,low)
            # The lower route remains a running jump even when the middle calls for a dash.
            lower_gap = min(spec.gap, SAFE_RUN_GAP)
            self.stretch("LowerWest",p+11,gap_center-lower_gap*.5,low)
            self.stretch("LowerEast",gap_center+lower_gap*.5,end-2,low)
            self.spike_pit("LowerRouteSpikes",gap_center-lower_gap*.5,gap_center+lower_gap*.5,low-2.9)
            self.deck("LowerUp",end-2,end+4,low,floor)
            self.field("LowerField",gap_center-lower_gap*.5-5.5,low,lower_kind,lower_label,
                       direction=-1 if self.act==2 else 1)
        merge_kind, merge_label = JUNCTION_FIELDS[spec.merge_field]
        self.stretch("MergeApron",end+4,q,floor)
        self.field("MergeField",q-0.8,floor,merge_kind,merge_label, direction=-1 if self.act==2 else 1, width=3.2)
        self.spawns.extend(((p+13,mid),(middle_landing+1.5,mid),(q+4,floor)))
        return bottom

    def route_crossovers(self, spec, beat, start, end, middle, upper):
        """After the measured approach jump, change levels again to reach the merge."""
        space = end-start
        # Late and westbound vaults need a reliable place to start their return.
        if spec.upper_route in ("reverse", "late"):
            self.stretch("VaultApproach",start,start+5.0,middle,thin=True)
            start += 5.0
            space -= 5.0
        if space < 15.0 or spec.depth:
            # Stop before the compulsory drop bulkhead. A crossover past it
            # could strand a player above the basement return.
            if spec.depth:
                end -= 7.1
                space = end-start
                if space < 2.0:
                    return
            # A compact transfer still crosses between heights. Put its first
            # rise well beyond the takeoff of the measured middle jump.
            split = start+space*.40
            link_end = start+space*.77
            y = middle - (.95 if beat in ("echo","ferry") else .62)
            self.deck("CompactApproach",start,split,middle,thin=True)
            self.deck("CompactTransfer",split,link_end,middle,y,thin=True)
            self.deck("CompactMerge",link_end,end,y,middle,thin=True)
            return

        if beat == "echo":
            # The lane bends down and back above the sump, then climbs on staggered shelves.
            # The upper track stays available as an easier line back from the vault.
            self.stretch("EchoTakeoff",start,start+3.4,middle,thin=True)
            self.deck("EchoDown",start+4.8,start+8.6,middle-1.37,thin=True)
            if spec.upper_route == "reverse":
                self.deck("EchoReturn",start+8.60,start+14.0,middle-1.37,thin=True)
            else:
                self.deck("EchoReturn",start+8.95,start+14.0,middle-1.33,thin=True)
            if space >= 18:
                self.stretch("EchoRejoin",end-2.7,end,middle,thin=True)
                landing_end = end-2.9
                if landing_end > start+17.9:
                    self.stretch("EchoLanding",start+17.3,landing_end,middle-.5,thin=True)
            else:
                self.stretch("EchoRejoin",start+14.35,end,middle,thin=True)
            self.label("EchoSign","DOWN TO THE LOWER SPAN",start+5,middle+.72,z=-1.66)
        elif beat == "switch":
            # A target lowers a balcony shortcut. The bottom shelf is an
            # independent crossing, so a missed shot costs time, not a reset.
            self.stretch("SwitchTakeoff",start,start+3.6,middle,thin=True)
            self.deck("SwitchCrossing",start+3.9,start+9.4,upper-.45,thin=True,moving=True)
            self.relay(start+.6,middle-.36,"SwitchCrossing",middle-upper+.45,False,"DROP SHORTCUT")
            self.deck("SwitchLowerLanding",start+4.3,start+7.3,middle-1.32,thin=True)
            self.deck("SwitchLowerExit",start+8.7,start+12.0,middle-.92,thin=True)
            self.stretch("SwitchMerge",start+12.4,end,middle,thin=True)
            self.label("SwitchRouteSign","SHOOT TO DROP THE SHORTCUT",start+2,middle+2.6,z=-1.55)
        elif beat == "ferry":
            # The lift travels across as well as up. The exposed staggered
            # ledges are an alternate route for players who skip the switch.
            self.deck("FerryDock",start,start+3.4,middle,thin=True)
            self.deck("DiagonalFerry",start+3.6,start+6.7,middle-.72,thin=True,moving=True)
            self.relay(start+1.8,middle,"DiagonalFerry",1.74,True,"SEND FERRY",dx=7.2)
            self.deck("FerryFallback",start+7.25,start+10.1,middle-1.1,thin=True)
            self.deck("FerryLanding",start+9.95,start+14.4,middle-1.1,thin=True)
            if end > start+14.4:
                self.stretch("FerryMerge",start+14.4,end,middle,thin=True)
        else:
            # Two different heights and a timed utility field change when to
            # commit. A fast player can drop out through the gaps to the floor.
            rising = self.act == 1
            first_y = middle+1.18 if rising else middle-1.23
            second_y = middle-.48 if rising else middle+.35
            self.deck("SlalomEntry",start,start+2.8,middle,thin=True)
            self.deck("SlalomFirst",start+4.6,start+7.8,first_y,thin=True)
            self.deck("SlalomSecond",start+9.25,start+12.8,second_y,thin=True)
            self.stretch("SlalomRejoin",start+13.65,end,middle,thin=True)
            field_kind, field_label = JUNCTION_FIELDS[spec.merge_field]
            if field_kind in (0,1,2,3,6):
                self.field("SlalomField",start+6.15,first_y,field_kind,field_label,
                           direction=1 if rising else -1,width=2.45)

    def switchback(self, spec, p, q, floor, end, lower_kind, lower_label):
        low = floor + spec.depth - 2.5
        return_y = floor-2.25
        west = p+5.4
        drop = end-9.0
        shaft = west+3.0
        gate_x = end+4
        gap_a = west+(drop-west)*(.43 if self.act==1 else .59)
        gap_b = gap_a + min(spec.gap, 4.65 if lower_kind == 4 and self.sector == "frozen_reactor" else 5.2)
        ceiling = floor-5.85
        self.deck("MainDescent",p+5,p+11,floor,floor-1.3)
        self.stretch("MainToDrop",p+11,drop-6.2,floor-1.3)
        # An overhead baffle forces the approach to fall west of the sealed return wing.
        self.wall("DropBulkhead",drop+2.65,return_y+4.50,floor+MIDDLE_RISE+UPPER_RISE+3.0)
        self.stretch("SumpWest",west,gap_a,low)
        if self.act==2 and lower_kind not in (1,3):
            self.deck("SumpIsland",gap_b,gap_b+3.3,low+.46)
            self.stretch("SumpEast",gap_b+6.5,drop+2.4,low)
        else:
            self.stretch("SumpEast",gap_b,drop+2.4,low)
        self.spike_pit("SumpSpikes",gap_a,gap_b,low-2.65)
        self.wall("SumpWestWall",west-.38,low-.45,return_y-.25)
        self.wall("SumpEastWall",drop+2.4,low-.45,return_y)
        self.deck("LadderWestLanding",west,shaft-2.1,ceiling)
        self.node("ReturnHatch",art="RCHatch",pos=(shaft,ceiling,0),deck_width=4.2,climb_height=ceiling-low)
        self.stretch("ReturnUnderMain",shaft+2.1,drop-8.9,ceiling)
        self.deck("ReturnRamp",drop-8.9,drop-4.5,ceiling,return_y)
        self.deck("ReturnTakeoff",drop-4.5,drop-1.63,return_y)
        self.stretch("ReturnEast",drop+2.85,gate_x-4.9,return_y)
        self.deck("GateRamp",gate_x-4.9,gate_x-0.95,return_y,floor)
        self.deck("GateThreshold",gate_x-.95,gate_x,floor)
        # The sill and header close the boundary above and below the moving shutter.
        self.node("SumpShutter",art="RCShutter",pos=(gate_x,floor+6.1,0))
        self.wall("ShutterSill",gate_x,PIT_Y-.3,floor-.015)
        self.wall("ShutterHeader",gate_x,floor+8.76,floor+22.2)
        self.relay(west+6.5,low,"SumpShutter",11.0,False,"RETURN SHUTTER")
        self.wall("RelaySightBaffle",west+14.0,low-.45,low+2.05)
        self.label("DropNavigation","DROP TO SUBLEVEL  v",drop-3.8,floor+.25,z=-1.65)
        self.label("SumpNavigation","<  JUMP THE BAFFLE TO REACH THE SHUTTER CONTROL",drop-5.0,low+2.0,z=-1.65)
        self.label("TurnNavigation","RETURN HATCH   /   CROSS EAST  >",shaft+2.7,ceiling+.95,z=-1.65)
        self.field("SumpField", min(gap_b+10.5,drop-1.8), low, lower_kind, lower_label,
                   direction=-1, width=3.2 if lower_kind>=4 else 5.2)
        self.cache(west+1.8,low,blueprint=False)
        self.spawns.append((drop-1.6,low))
        return low-1.0

    def overhead(self, spec, a, floor):
        """A second traversal loop above a continuous, accessible main deck."""
        b = a+spec.width
        self.chamber = self.node("OverheadLoop",parent="TERRAIN",
                                 **{"metadata/left": a, "metadata/right": b, "metadata/floor": floor,
                                    "metadata/direction": spec.direction, "metadata/title": f'"{spec.title}"'})
        # The far landing changes sides between eastbound and westbound loops.
        direction = spec.direction
        origin = a+14 if direction==1 else b-14
        def x(local):
            return origin+direction*local
        def span(name, start, end, height, other=None, moving=False):
            left,right = sorted((x(start),x(end)))
            low,high = (height,other) if direction==1 or other is None else (other,height)
            self.deck(name,left,right,floor+low,None if high is None else floor+high,thin=True,moving=moving)
        lift_level = spec.rise-1.15
        dock = 5.1 if spec.mechanism=="lift" else 4.0
        # Two breaks under the high loop. Offset the second jump and its
        # raised landing between acts to vary the rhythm across sectors.
        left_gap = a + (37 if self.act==1 else 39)
        first_width = 4.55 + .14 * ((self.number+self.act)%4)
        far_gap = b - (17 if self.act==1 else 20)
        far_width = 5.18 if self.act==1 else 8.65
        step = .55 if self.act==1 else .22
        self.stretch("MainWest",a,left_gap,floor)
        self.spike_pit("LoftSpikesWest",left_gap,left_gap+first_width,floor-3.35)
        self.stretch("MainBetween",left_gap+first_width,far_gap,floor)
        self.spike_pit("LoftSpikesEast",far_gap,far_gap+far_width,floor-3.8)
        self.deck("MainRaisedLanding",far_gap+far_width,far_gap+far_width+3.8,floor+step)
        self.deck("MainLandingRamp",far_gap+far_width+3.8,far_gap+far_width+7.4,floor+step,floor)
        self.stretch("MainEast",far_gap+far_width+7.4,b,floor)
        self.label("LoftEastWarning","AIR DASH" if self.act==2 else "RUNNING JUMP",far_gap-2.6,floor+2.65,z=-1.5)
        span("EntrySide", -9,-5,1.4)
        span("EntryTurn",-4.4,-.6,2.75)
        span("EntryDock",.2,4.6,dock)
        self.label("OverheadEntry",spec.title+"  /  UP",x(0),floor+7.4,z=-1.63)
        if spec.mechanism == "lift":
            # A platform carries the operator the whole way from the dock.
            span("HighHoist",5.05,10.15,dock,moving=True)
            self.relay(x(2.7),floor+dock,"HighHoist",lift_level-dock,True,"RAISE GANTRY")
            span("LiftExit",10.45,14.0,lift_level)
        elif spec.mechanism == "kick":
            # Mirror the proven Neon Factory shaft rather than the controller.
            entrance, exit_wall = x(8), x(12)
            span("GripApproach",4.6,7.6,dock)
            span("GripEntryRamp",8.42,10.58,dock,dock+1.35)
            span("OverheadKickSill",10.58,11.60,dock+1.35)
            self.wall("OverheadEntranceGrip",entrance,floor+dock+2.12,floor+dock+8.6)
            self.wall("OverheadExitGrip",exit_wall,floor+dock,floor+dock+6.15)
            span("GripLanding",12.4,19.6,dock+6.15)
            self.node("OverheadLedgeHatch",art="RCHatch",pos=(x(17.70),floor+lift_level,0),
                      deck_width=3.55,climb_height=lift_level-dock-6.15)
        else:
            hatch_x = x(6.5)
            first_y = 9.4 if spec.mechanism in ("buoyant","gravity") else 9.7
            span("DockLip",4.6,7.7,dock)
            self.node("OverheadLowerHatch",art="RCHatch",pos=(hatch_x,floor+first_y,0),
                      deck_width=3.6,climb_height=first_y-dock)
            span("TransferDeck",8.3,16.15,first_y)
            self.node("OverheadLedgeHatch",art="RCHatch",pos=(x(14.45),floor+lift_level,0),
                      deck_width=3.6,climb_height=lift_level-first_y)
            # Updrafts offer a quick line onto the transfer deck, with the
            # hatch available when the vent is between cycles.
            if spec.mechanism=="vent":
                self.field("OverheadBoost",x(3.7),floor+dock,6,"BOOST TO TRANSFER",width=2.5)
            if spec.mechanism in ("gravity","buoyant"):
                kind = 3 if spec.mechanism=="gravity" else 1
                self.field("OverheadAccessField",x(9.9),floor+first_y,kind,
                           "FLOAT TO THE HATCH",direction=direction,width=4.0)
        launch_start = {"kick": 19.475, "lift": 14.0}.get(spec.mechanism, 16.25)
        launch_end = 23.0
        middle_start = launch_end+spec.gaps[0]
        middle_end = middle_start+8.1
        vault_start = middle_end+spec.gaps[1]
        vault_end = min(vault_start+7.3,spec.width-7)
        middle_height = spec.rise+.40 if self.act==1 else spec.rise-.55
        span("HighLaunch",launch_start,launch_end,lift_level)
        span("HighSpan",middle_start,middle_end,middle_height)
        span("HighVault",vault_start,vault_end,spec.rise)
        self.cache(x((vault_start+vault_end)*.5),floor+spec.rise,blueprint=False)
        kind,label = JUNCTION_FIELDS[spec.obstacle]
        midpoint = (middle_start+middle_end)*.5
        if kind == -2:
            self.node("OverheadPhaseStep",art="RCPhase",
                      pos=(x(launch_end+spec.gaps[0]*.5),floor+spec.rise-.45,0),
                      period=3.8 if self.act==2 else 4.55,phase_offset=.45)
            self.label("OverheadPhaseSign","CROSS ON THE PHASE PULSE",x(midpoint),floor+middle_height+2.3,z=-1.6)
        else:
            self.field("OverheadGimmick",x(midpoint),floor+middle_height,kind,label,
                       direction=direction,width=3.2)
        self.label("OverheadJumpSign","AIR DASH TO SALVAGE",x(launch_end-2.4),floor+lift_level+1.18,z=-1.60)

        # Drop beyond the vault side and turn back below the high decks.
        turn_tip = min(vault_end+7.2,spec.width+8.8)
        first_return = spec.rise-spec.drops[0]
        second_return = spec.rise-spec.drops[1]
        span("Turnaround",vault_end+1.85,turn_tip,first_return)
        span("ReturnOuter",vault_end-2.1,turn_tip-2.45,second_return)
        span("ReturnCross",vault_start-3.8,vault_end-3.2,second_return-1.75)
        span("ReturnDrop",vault_start-10.1,vault_start-4.8,max(2.1,second_return-4.2))
        self.label("OverheadReturnSign", "RETURN TO MAIN DECK",x(vault_start-2.5),
                   floor+second_return+1.2,z=-1.60)
        for index,at in enumerate((launch_end-3,midpoint,vault_end-2)):
            support_height = 24.0 - spec.rise
            self.node(f"OverheadBrace{index}",art="RCWall",
                      pos=(x(at),floor+spec.rise+support_height*.5,-3.15),
                      scale=vec(.66,support_height/4.25,.72))
            self.node(f"OverheadLight{index}",kind="OmniLight3D",
                      pos=(x(at),floor+spec.rise+1.3,-1.8),
                      light_color=self.color(),light_energy=1.8,omni_range=7.0)
        self.shell(a,b,floor-1.0,floor+11.8,8+self.act)
        self.spawns.extend(((a+8,floor),(b-8,floor),(x(midpoint),floor+middle_height)))
        return b

    def arena_layout(self, gate, escape, floor):
        title,decks,mechanic,location = ARENAS[self.sector][self.act-1]
        width = escape-gate
        at = gate+width*location
        self.label("ArenaTactics",title,gate+width*.5,floor+8.4,z=-1.5)
        for index,(fraction,length,height) in enumerate(decks):
            x = gate+width*fraction
            if mechanic=="vine" and fraction==location:
                self.node("ArenaVineHatch",art="RCHatch",pos=(x,floor+height,0),
                          deck_width=length,climb_height=height)
            else:
                self.deck(f"TacticalDeck{index}",x-length/2,x+length/2,floor+height,thin=True)
            self.node(f"TacticalLight{index}",kind="OmniLight3D",
                      pos=(x,floor+height+1.1,-1.6),
                      light_color=self.color(),light_energy=1.55,omni_range=5.6)
        if mechanic=="lift":
            self.deck("ArenaElevator",at-1.65,at+1.65,floor+.01,thin=True,moving=True)
            nearby = min(decks,key=lambda deck:abs(deck[0]-location))
            destination = nearby[2] + .80
            # Tall lift destinations clear the neighbouring gallery; the
            # player can step or jump off either side during the dwell.
            self.relay(at-2.9,floor,"ArenaElevator",destination,True,"DODGE LIFT")
        elif mechanic=="cover":
            self.solid("ProjectileShield","Wall",(at,floor+1.42,0),(.76,2.85,2.5),(1,2.85/4.25,.62),layer=128)
            self.label("ArenaCoverSign","PROJECTILE COVER",at,floor+3.25,z=-1.45)
        elif mechanic=="phase":
            self.node("ArenaPhaseDeck",art="RCPhase",pos=(at,floor+3.2,0),
                      period=4.35 if self.act==1 else 3.65,phase_offset=1.2)
            self.label("ArenaPhaseSign","PHASE LEDGE",at,floor+4.35,z=-1.45)
        elif mechanic!="vine":
            effect = {"current": 1, "gravity": 3, "vent": 6}[mechanic]
            sign = {"current": "CURRENT / JUMP CLEAR", "gravity": "FLOAT FIELD", "vent": "VENT / QUICK ESCAPE"}[mechanic]
            # Make the gravity/vent recovery influence large enough to reach
            # the next deck, while leaving the boss's floor continuous.
            self.field("ArenaMovementField",at,floor,effect,sign,direction=-1 if self.act==2 else 1,width=5.8,field_height=7.6 if mechanic=="gravity" else 2.6)

    def build_rooms(self, act_routes, floor, gate_y):
        self.shapes = []
        a = -7
        self.node("SectorPanorama",parent="DECOR",script=ext("RCSky"),panorama_texture=ext("RCPanorama"))
        if self.sector == "machine_jungle":
            # Act I enters the caves at the nursery lip. Act II returns to the
            # canopy, crosses a viaduct, then descends through the hollow trunk.
            self.cave_entrance = 37.5 if self.act == 1 else 116.0
            self.node("CanopyKey",parent="DECOR",kind="DirectionalLight3D",
                      rotation=vec(-.62,-.45,0),light_color="Color(0.83, 1, 0.88, 1)",
                      light_energy=.60,shadow_enabled="true")
        checkpoint = None
        overhead = OVERHEAD[self.sector][self.act-1]
        junctions = {spec.room: spec for spec in JUNCTIONS[self.sector][self.act-1]}
        beats = iter(ROUTE_BEATS[self.sector][self.act-1])
        for i, (kind,width,title) in enumerate(act_routes):
            entry_floor = floor
            spec = junctions.get(title)
            if spec:
                width = round(spec.span * (1.27 if spec.depth else 1.22))
                kind = "switchback" if spec.depth else "junction"
            if not spec and kind != "hall":
                width += 6 if self.act == 1 else 8
            if title == self.exterior.room:
                width = max(width, 48)
            b = a + width
            self.chamber = self.node(f"Room{i+1:02d}_{kind.title()}", parent="TERRAIN", pos=(0,0,0), **{"metadata/entry_x": a, "metadata/entry_y": floor})
            shift = 1 + (self.number + i + self.act) % 4
            # A level approach keeps the deployment and checkpoint landing clear.
            p = a + (13 if i==0 else 7)
            q = b - 8
            high = floor
            self.label("RoomSign", title, p-2, floor+3.45)
            if i==2:
                edge = a+2.15
                self.deck("EntryTakeoff",a,edge,floor)
                self.spike_pit("EntrySpikes",edge,p-.45,floor-2.85)
                self.deck("EntryLanding",p-.45,p,floor)
            else:
                self.stretch("Entry",a,p,floor)
                self.spawns.append((p-2,floor))
            if i == 4:
                checkpoint = (a+2,floor,0)
            bottom = floor
            if spec:
                if spec.depth and floor > 7.0:
                    # Leave enough headroom above the return deck without a 12 m ladder.
                    self.deck("ApproachDescent",p,p+8,floor,7.0)
                    floor = high = 7.0
                    p += 8
                bottom = self.junction(spec,p,q,floor,next(beats))
            elif self.sector == "machine_jungle" and ((self.act == 1 and i == 0) or (self.act == 2 and i == 1)):
                high = self.jungle_traverse(a,p,q,floor)
            elif title == self.exterior.room:
                high = self.exterior_traverse(p,q,floor)
            elif kind == "shaft" or kind == "branch":
                right = p + 9 + shift
                span = 4.0
                left = right-span
                high = floor + 6.15
                self.stretch("Approach",p,left+.42,floor)
                self.deck("ShaftEntryRamp",left+.42,right-1.42,floor,floor+1.35,thin=True)
                self.deck("ShaftFoot",right-1.42,right-.395,floor+1.35,thin=True)
                self.wall("WestGrip",left,floor+2.12,floor+8.6)
                self.wall("EastGrip",right,floor,high)
                self.stretch("ExitLanding",right+.40,q,high)
                self.label("WallJumpSign","WALL JUMP UP THE SHAFT", left-2, floor+3.45)
                if kind == "branch":
                    self.deck("UpperVault",left-11.7,left-.45,high+2.4,thin=True)
                    self.cache(left-7.8,high+2.4)
                    self.label("BacktrackSign","UPPER SALVAGE ROUTE",left-5,high+3.65)
                    self.spawns.append((q-3,high))
            elif kind == "loop":
                low=max(-2.05,floor-1.55-shift*.18)
                self.deck("DescendingRamp",p,p+6,floor,low)
                self.stretch("LowerPassage",p+6,q-6,low)
                self.deck("AscendingRamp",q-6,q,low,floor)
                self.deck("UpperEntry",p+1,p+8,floor+2.35,thin=True)
                self.stretch("Bypass",p+12,q-4,floor+2.6+shift*.13,thin=True)
                self.deck("UpperReturn",q-2,q+3,floor+2.25,thin=True)
                self.cache(q-6,floor+2.6+shift*.13)
                self.spawns.append((p+10,low))
                self.hazard(p+13,low,exposed=False)
            elif kind in ("bridge","lift"):
                gap = 6.15 + (shift*.25 if self.act==1 else shift*.40)
                edge=(p+q-gap)*.5
                far=edge+gap
                low=max(-2.05,floor-1.7)
                self.stretch("LeftApron",p,edge,floor)
                self.stretch("CatchFloor",edge,far,low)
                self.stretch("RightApron",far,q,floor)
                if kind=="bridge":
                    self.deck("PoweredBridge",edge+.05,far-.05,floor+3.15,thin=True,moving=True)
                    self.relay(edge-2.2,floor,"PoweredBridge",-3.15,False)
                    self.deck("Overlook",far+1,far+6,floor+2.6,thin=True)
                    self.cache(far+3,floor+2.6)
                else:
                    self.deck("ServiceLift",edge+.55,far-.55,low+.48,thin=True,moving=True)
                    self.relay(edge-2.2,floor,"ServiceLift",floor+4.3-low-.48,True)
                    self.deck("HighLanding",far-.48,far+5.8,floor+4.3,thin=True)
                    self.deck("HighReturn",far+6.8,far+12,floor+2.3,thin=True)
                    self.cache(far+3,floor+4.3)
                self.spawns.append((q+3,floor))
                if self.number in (3,6,8,9):
                    self.hazard(edge-6,floor,exposed=False)
            elif kind in ("slope","fall","hall"):
                high = gate_y if kind=="hall" else min(5.9,floor+1.6+shift*.17) if kind=="slope" else max(-2.05,floor-2.1-shift*.27)
                self.stretch("Approach",p,p+4,floor)
                if self.sector == "machine_jungle" and self.act == 2 and i == 2:
                    high = floor-4.6
                    # Stepped descent gives each landing a visible takeoff and
                    # keeps the route clear of the reserve ledge above it.
                    self.deck("HollowUpperShelf",p+4,p+8,floor)
                    self.deck("HollowMiddleShelf",p+10.9,p+16,floor-2.20)
                    self.deck("HollowLowerShelf",p+19.25,q-2,high)
                    self.spike_pit("HollowFirstSpikes",p+8,p+10.9,floor-5.9)
                    self.spike_pit("HollowSecondSpikes",p+16,p+19.25,floor-8.3)
                else:
                    self.deck("Incline",p+4,q-2,floor,high)
                self.deck("Transition",q-2,q,high)
                if kind != "hall":
                    if self.sector == "machine_jungle" and self.act == 2 and i == 2:
                        self.label("CaveDescentSign","HOLLOW TRUNK / DOWN",p+4.5,floor+2.05,z=-1.55)
                    self.deck("PatrolShelf",p+1,p+7,max(floor,high)+2.8,thin=True)
                    self.spawns.append((q+3,high))
            else:
                self.stretch("Ground",p,q,floor)
                turn = p + 4 + shift
                if self.sector == "machine_jungle":
                    hatch = "RCVineLeft" if self.act == 1 else "RCVineRight"
                    self.node("CanopyVines", art=hatch, pos=(p+4.5,floor+2.5,0),
                              deck_width=7.0, climb_height=2.5)
                else:
                    self.deck("WestWalk",p+1,p+8,floor+2.5,thin=True)
                self.deck("HighWalk",turn+5,q-3,floor+3.85+shift*.20,thin=True)
                self.deck("EastWalk",q-2,q+3,floor+2.25,thin=True)
                self.spawns.append((q-5,floor+3.85+shift*.20))
                if self.cache_count < 4:
                    self.cache(turn+6,floor+3.85+shift*.20)
                self.spawns.append((q-2,floor))
                self.hazard(p+8.3,floor,exposed=True)
            self.stretch("Exit",q,b,high)
            shell_floor = min(bottom,high)-(1.4 if kind=="loop" else 0)
            shell_roof = max(floor,high)+(13.1 if spec else 10.8 if kind=="shaft" else 8.7)
            if title == self.exterior.room:
                self.exposed_shell(a,b,entry_floor,high)
            elif title == self.exterior.view_room:
                # Short openings in a larger room keep its mechanics and boss route intact.
                view_start = a + min(18,(b-a)*.32)
                view_end = b - min(11,(b-a)*.23)
                self.shell(a,view_start,shell_floor,shell_roof,i+self.number)
                self.exposed_shell(view_start,view_end,entry_floor,high,end_frame=False)
                self.shell(view_end,b,shell_floor,shell_roof,i+self.number+2)
            else:
                self.shell(a,b,shell_floor,shell_roof,i+self.number,
                           cave_lip_floor=high if kind=="gallery" else entry_floor)
            self.rooms.append((a,b,kind,high))
            floor = high
            a = b
            if title == overhead.after:
                a = self.overhead(overhead,a,floor)
        return a, checkpoint

    def align_portals(self, entries, header):
        for door_name, visual_name in (("ForgeHallDoor","Door"),("Gate","Door"),("ExitBarrier","Seal")):
            blocker_path = (door_name if visual_name == "Seal" else door_name+"/Blocker")+"/CollisionShape3D"
            blocker = entries[blocker_path]
            shape_id = re.search(r'SubResource\("([^"]+)"\)',blocker)[1]
            shape = re.search(r'id="'+re.escape(shape_id)+r'"\]\s+size = Vector3\(([^)]+)\)',header)[1]
            _, height, depth = (float(value.strip()) for value in shape.split(","))
            # Assets are authored across local X. An exact quarter turn spans world Z.
            # Fit the panels to their blocker and place jambs just outside its edges.
            visual = door_name+"/"+visual_name
            tag = entries[visual].splitlines()[0]
            entries[visual] = f"{tag}\nrotation = {vec(0,-math.pi/2,0)}\nscale = {vec(depth/5.0,height/3.7,1)}"
            frame = door_name+"/PortalFrame"
            if frame not in entries:
                continue
            tag = entries[frame].splitlines()[0]
            legacy_frame = 'ExtResource("door_frame")' in tag
            root_frame = self.sector == "machine_jungle" and not legacy_frame
            native_width = 3.0 if legacy_frame else 3.75
            native_height = 3.0 if legacy_frame or root_frame else 4.22
            frame_depth = depth + (1.20 if root_frame else .88)
            # Show the complete frame beside the moving panel.
            approach = -.25
            entries[frame] = (f"{tag}\nposition = {vec(approach,0,0)}"
                              f"\nrotation = {vec(0,-math.pi/2,0)}"
                              f"\nscale = {vec(frame_depth/native_width,(height+.2)/native_height,1.12)}")

    def convert(self, legacy):
        header,*blocks = re.split(r'(?=^\[node )',legacy,flags=re.M)
        entries = {}
        for block in blocks:
            tag = block.splitlines()[0]
            name = re.search(r'name="([^"]+)"',tag)[1]
            match = re.search(r'parent="([^"]+)"',tag)
            parent = match[1] if match else ""
            key = f"{parent}/{name}" if parent not in (".","") else name
            entries[key] = block.strip()
        self.align_portals(entries,header)
        gate_x, gate_y, _ = coordinates(entries["Gate"])
        floor = coordinates(entries["MARKERS/PlayerSpawn"])[1]-.905
        end, checkpoint = self.build_rooms(ROUTES[self.sector][self.act-1],floor,gate_y)
        new_gate = end + 10.0
        shift = new_gate - gate_x
        exit_x = coordinates(entries["MARKERS/RoomExit"])[0] + shift
        self.chamber = self.node("BossWing", parent="TERRAIN")
        self.stretch("Antechamber",end,new_gate,gate_y)
        # The existing arena collider remains continuous across the entire fight.
        for i in range(math.ceil((exit_x-new_gate+6)/6)):
            self.node(f"ArenaDeck{i}", art="RCDeck", pos=(new_gate+3+i*6,gate_y,0))
        self.shell(end,exit_x+6,gate_y,gate_y+10,3)
        self.arena_layout(new_gate,exit_x,gate_y)
        self.wall("SealedAirlock", -6.55, floor-1.0, floor+10)
        for door_name in ("ForgeHallDoor", "Gate", "ExitBarrier"):
            door_x, door_y, _ = coordinates(entries[door_name])
            self.wall(door_name+"Header",door_x+shift,door_y+6.48,door_y+10.3)
        self.spawns = sorted((x,y) for x,y in self.spawns if 19 < x < end-30)
        actors = [key for key,block in entries.items() if 'groups=["level_enemies"]' in block.splitlines()[0]]
        for i,key in enumerate(actors):
            slot = i*len(self.spawns)//len(actors)
            x,y = self.spawns[slot]
            if i > 0 and slot == (i-1)*len(self.spawns)//len(actors):
                x += 2.4
            flying = any(word in entries[key].splitlines()[0] for word in ("flyer", "canopy_wasp"))
            block = re.sub(r"(?m)^patrol_right_limit = .*\n?", "", entries[key])
            entries[key] = relocate(block,x,y+(3 if flying else .95),0) + f"\npatrol_right_limit = {end-3:.3f}"
        result = []
        for key, block in entries.items():
            name = key.rsplit("/",1)[-1]
            x,y,z = coordinates(block)
            if not "/" in key and name not in ("WorldEnvironment","KeyLight","TERRAIN","DECOR","MARKERS",
                                               "Actors","CameraRig","Gate","ExitBarrier","ForgeHallDoor","ArenaUnifiedFloor"):
                if ' parent=' not in block.splitlines()[0]:
                    result.append(block + f"\nmetadata/interior_layout = true\nmetadata/pit_floor_y = {PIT_Y}")
                continue
            if key.startswith("TERRAIN/ArenaPerch") or key.startswith("DECOR/ArenaName"):
                continue
            if key == "MARKERS/CameraBounds":
                block = re.sub(r"metadata/max_x = .*","metadata/max_x = " + str(exit_x),block)
            elif key == "TERRAIN/MidpointCheckpoint":
                block = relocate(block,*checkpoint)
            elif key == "CameraRig":
                block += f"\nminimum_follow_y = {PIT_Y + 2.0}"
            elif key == "Actors/RiftcoreMecha":
                block += f"\npit_floor_y = {PIT_Y}"
            elif key in ("TERRAIN","DECOR","MARKERS","Actors","KeyLight","WorldEnvironment"):
                pass
            elif key.startswith("Actors/") and key not in actors and name != "RiftcoreMecha":
                block = relocate(block,x+shift,y,z)
            elif name == "RoomExit" or key in ("Gate","ExitBarrier","ForgeHallDoor","ArenaUnifiedFloor") or (
                    "/" in key and "/" not in key.split("/",1)[1] and
                    (name.startswith(("Arena","ForgeHallCheckpoint","Hall","Boss")) and
                     not name.startswith("ArenaTread"))):
                block = relocate(block,x+shift,y,z)
            elif not (key in actors or key.startswith(("Actors/","MARKERS/","Gate/","ExitBarrier/",
                                                       "ForgeHallDoor/","ArenaUnifiedFloor/")) or
                      key.startswith(("TERRAIN/MidpointCheckpoint/","TERRAIN/ForgeHallCheckpoint/"))):
                continue
            result.append(block)
        used_ext = set(re.findall(r'ExtResource\("([^"]+)"\)',"\n".join(result+self.nodes)))
        header = self.header(header)
        header = re.sub(r'^\[ext_resource [^\n]+id="([^"]+)"\]\n',
                        lambda m:m[0] if m[1] in used_ext else "",header,flags=re.M)
        # Drop stale resources after preserving legacy actor and door dependencies.
        pieces = re.split(r"(?=^\[sub_resource )",header,flags=re.M)
        keep = set(re.findall(r'SubResource\("([^"]+)"\)',"\n".join(result+self.nodes)))
        for piece in reversed(pieces[1:]):
            identifier = re.search(r'id="([^"]+)"',piece)[1]
            if identifier in keep:
                keep.update(re.findall(r'SubResource\("([^"]+)"\)',piece))
        header = pieces[0] + "".join(piece for piece in pieces[1:]
                                    if re.search(r'id="([^"]+)"',piece)[1] in keep)
        header = re.sub(r"\n{3,}", "\n\n", header.strip())
        return "\n\n".join([header,*self.shapes,*result,*self.nodes]) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--legacy-source", type=Path, default=LEVELS)
    args = parser.parse_args()
    for sector_number,sector in enumerate(ROUTES,2):
        for act in (1,2):
            name = sector + ("_act_2" if act==2 else "") + ".tscn"
            file = LEVELS / name
            old = (args.legacy_source / name).read_text(encoding="utf8")
            if "metadata/interior_layout" in old:
                print(f"Already converted {name}")
                continue
            scene = Scene(sector,sector_number,act)
            new = scene.convert(old)
            file.write_text(new, encoding="utf8", newline="\n")
            print(f"{name}: {scene.rooms[-1][1]:.0f} m before the arena, {scene.cache_count} salvage routes")


if __name__ == "__main__":
    main()
