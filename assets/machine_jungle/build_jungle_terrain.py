from __future__ import annotations

from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE = "res://assets/machine_jungle"


def vec(v):
    return "Vector3(" + ", ".join(str(round(x, 5)) for x in v) + ")"


class Module:
    def __init__(self, label, body="Node3D", one_way=False):
        self.label = label
        self.body = body
        self.one_way = one_way
        self.resources = []
        self.nodes = []
        self.counter = 0

    def mesh(self, at, size, material, rotation=(0, 0, 0)):
        key = f"M{self.counter}"
        self.counter += 1
        self.resources.append(f'[sub_resource type="BoxMesh" id="{key}"]\nmaterial = ExtResource("{material}")\nsize = {vec(size)}\n')
        self.nodes.append(f'[node name="Panel{key}" type="MeshInstance3D" parent="."]\nposition = {vec(at)}\nrotation = {vec(rotation)}\nmesh = SubResource("{key}")\n')

    def rod(self, at, radius, length, material, tilt=0.0):
        key = f"M{self.counter}"
        self.counter += 1
        self.resources.append(f'[sub_resource type="CylinderMesh" id="{key}"]\nmaterial = ExtResource("{material}")\ntop_radius = {radius * .83}\nbottom_radius = {radius}\nheight = {length}\nradial_segments = 7\n')
        self.nodes.append(f'[node name="Root{key}" type="MeshInstance3D" parent="."]\nposition = {vec(at)}\nrotation = {vec((0,0,tilt))}\nmesh = SubResource("{key}")\n')

    def collider(self, at, size):
        self.resources.append(f'[sub_resource type="BoxShape3D" id="collision"]\nsize = {vec(size)}\n')
        self.nodes.append(f'[node name="Collider" type="CollisionShape3D" parent="."]\nposition = {vec(at)}\nshape = SubResource("collision")\n')

    def save(self, name):
        lines = ["[gd_scene format=3]"]
        for material in ("stone","fern","tread","poison","jade"):
            lines.append(f'[ext_resource type="Material" path="{BASE}/{material}.tres" id="{material}"]')
        lines.extend(self.resources)
        group = ' groups=["factory_one_way"]' if self.one_way else ''
        lines.append(f'[node name="{self.label}" type="{self.body}"{group}]')
        lines.extend(self.nodes)
        (HERE/"terrain"/f"{name}.tscn").write_text("\n\n".join(lines)+"\n", encoding="utf-8")


for name, tint, band in [("stone",(.39,.50,.43),0),("fern",(.10,.36,.25),1),("tread",(.055,.13,.11),2),("poison",(.30,.15,.41),3)]:
    (HERE/f"{name}.tres").write_text(f'''[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://assets/neon_factory/platform_finish.gdshader" id="shader"]
[ext_resource type="Texture2D" path="{BASE}/jungle_trim.png" id="trim"]

[resource]
shader = ExtResource("shader")
shader_parameter/atlas = ExtResource("trim")
shader_parameter/tint = Color({tint[0]}, {tint[1]}, {tint[2]}, 1)
shader_parameter/band = {band}.0
shader_parameter/texture_mix = 0.8
''',encoding="utf-8")
(HERE/"jade.tres").write_text('''[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(0.14, 0.87, 0.49, 1)
emission_enabled = true
emission = Color(0.09, 0.75, 0.37, 1)
emission_energy_multiplier = 1.12
roughness = 0.44
''',encoding="utf-8")

m = Module("RootRibFloor", "StaticBody3D")
m.collider((0,-.18,0),(8,.36,2.1))
m.mesh((0,-.19,0),(7.99,.34,2.08),"tread")
for x in (-3,-1,1,3):
    m.mesh((x,-.035,0),(1.95,.073,1.79),"fern")
    m.mesh((x,-.155,1.054),(1.29,.073,.028),"jade")
    m.rod((x-.67,-.30,1.02),.12,.62,"tread",-.50)
    m.mesh((x+.58,-.202,1.064),(.28,.14,.035),"stone",(0,0,.12))
m.save("root_rib_floor")

m = Module("CanopyCatwalk", "StaticBody3D", True)
m.collider((0,-.11,0),(4.4,.22,1.82))
for z in (-.88,.88):
    m.mesh((0,-.10,z),(4.39,.21,.145),"stone")
for i in range(14):
    x=-2.08+i*.32
    m.mesh((x,-.043,0),(.17,.072,1.67),"fern",(0,.09,0))
for x in (-1.38,0,1.38):
    m.mesh((x,-.115,.958),(.63,.042,.038),"jade")
m.save("canopy_catwalk")

m = Module("VineWall", "StaticBody3D")
m.collider((0,0,0),(.48,3.65,1.9))
m.mesh((0,0,0),(.46,3.63,1.88),"tread")
for y in (-1.47,-.58,.26,1.16):
    m.mesh((0,y,.936),(.48,.66,.075),"fern",(0,0,.045))
    m.rod((-.11,y,.985),.056,.45,"jade",.26)
for y in (-1.71,1.71):
    m.mesh((0,y,0),(.51,.19,1.91),"stone")
m.save("vine_wall")

m = Module("JungleRootArch")
for s in (-1,1):
    m.rod((s*1.62,1.19,-.34),.31,2.51,"tread",s*.24)
    m.rod((s*1.17,2.11,-.34),.24,1.52,"fern",s*.80)
    m.mesh((s*1.60,.32,-.30),(.54,.27,.61),"stone",(0,0,s*.11))
    m.rod((s*.82,2.39,-.30),.066,1.03,"jade",s*1.18)
m.mesh((0,2.77,-.34),(1.17,.24,.69),"poison")
m.save("root_arch")

m = Module("SporeReservoir")
m.rod((0,.65,0),.54,1.08,"fern")
m.rod((0,.09,0),.64,.23,"tread")
m.rod((0,1.20,0),.46,.20,"stone")
for x in (-.28,0,.28):
    m.mesh((x,.69,.48),(.082,.63,.041),"jade")
m.save("spore_reservoir")

for key, label, kind, phase in [("thorn_bed","ThornBed",0,0.0),("spore_pod","SporePod",1,1.3),("snap_vine","SnapVine",2,2.7)]:
    (HERE/"traps"/f"{key}.tscn").write_text(f'''[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/machine_jungle_trap.gd" id="trap"]

[node name="{label}" type="Area3D"]
script = ExtResource("trap")
kind = {kind}
phase_offset = {phase}
''',encoding="utf-8")

for name, label, variant in [("rootrunner","Rootrunner",0),("thorn_weaver","ThornWeaver",1),("bark_bulwark","BarkBulwark",2),("spore_sentry","SporeSentry",3),("canopy_wasp","CanopyWasp",4)]:
    (HERE/"enemies"/f"{name}.tscn").write_text(f'''[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/enemy.gd" id="enemy"]
[ext_resource type="PackedScene" path="{BASE}/enemies/{name}.glb" id="model"]

[node name="{label}" type="CharacterBody3D" groups=["damageable_enemies", "jungle_enemies"]]
script = ExtResource("enemy")
variant = {variant}
model_override = ExtResource("model")
fire_weakness = 1.5
''',encoding="utf-8")
