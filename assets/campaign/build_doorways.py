"""Build the sector doorway scenes and update their resource paths in both acts."""
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
DOORS = PROJECT / "assets/campaign/doorways"
DOORS.mkdir(exist_ok=True)

STYLES = {
    "neon_factory": ("foundry", "assets/neon_factory/foundry/deck_Heat-treated steel • albedo.png"),
    "machine_jungle": ("jungle", None),
    "frozen_reactor": ("cryo", "assets/campaign/frozen_reactor/trim.png"),
    "abyssal_plant": ("pressure", "assets/campaign/abyssal_plant/trim.png"),
    "buried_archives": ("archive", "assets/campaign/buried_archives/trim.png"),
    "sky_dock": ("flight", "assets/campaign/sky_dock/trim.png"),
    "biolab": ("lab", "assets/campaign/biolab/trim.png"),
    "orbital_array": ("orbital", "assets/campaign/orbital_array/trim.png"),
    "scrapyard_expanse": ("scrap", "assets/campaign/scrapyard_expanse/trim.png"),
    "riftcore_nexus": ("rift", "assets/campaign/riftcore_nexus/trim.png"),
}


def write_model(style, part, width, height, texture=None):
    lines = ['[gd_scene format=3]', '',
             '[ext_resource type="Script" path="res://scripts/sector_doorway.gd" id="builder"]']
    if texture and (PROJECT / texture).exists():
        lines.append(f'[ext_resource type="Texture2D" path="res://{texture}" id="trim"]')
    lines += ['', f'[node name="{style.title()}{part.title()}" type="Node3D"]',
              'script = ExtResource("builder")', f'style = "{style}"',
              f'width = {width}', f'height = {height}']
    if part == "gate":
        lines.append("sealed = true")
    if len(lines) > 3 and 'id="trim"' in lines[3]:
        lines.append('trim_texture = ExtResource("trim")')
    (DOORS / f"{style}_{part}.tscn").write_text("\n".join(lines)+"\n",encoding="utf8")


def outfit(sector, scene):
    style, _ = STYLES[sector]
    path = f"res://assets/campaign/doorways/{style}"
    # Each existing doorway family retains the native bounds that its act expects.
    scene = scene.replace(f"res://assets/campaign/{sector}/terrain/arch.tscn", path + "_arch.tscn")
    scene = scene.replace(f"res://assets/campaign/{sector}/terrain/gate.tscn", path + "_gate.tscn")
    if sector in ("neon_factory", "machine_jungle"):
        scene = scene.replace("res://assets/neon_factory/boss_gate_door.tscn", path + "_gate.tscn")
        scene = scene.replace("res://assets/neon_factory/door_frame.tscn", path + "_short_arch.tscn")
    if sector == "machine_jungle":
        scene = scene.replace("res://assets/machine_jungle/terrain/root_arch.tscn", path + "_arch.tscn")
    return scene


if __name__ == "__main__":
    for sector, (style, texture) in STYLES.items():
        write_model(style,"arch",3.75,3.0 if sector == "machine_jungle" else 4.22,texture)
        write_model(style,"gate",5.0,3.7,texture)
        if sector in ("neon_factory", "machine_jungle"):
            write_model(style,"short_arch",3.0,3.0,texture)
        for act in ("", "_act_2"):
            suffix = "_test" if not act and sector=="neon_factory" else act
            file = PROJECT / f"scenes/levels/{sector}{suffix}.tscn"
            file.write_text(outfit(sector,file.read_text(encoding="utf8")),encoding="utf8")
