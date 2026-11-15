"""Set back combat encounters from exposed edges and landing zones."""

from dataclasses import dataclass
from math import cos, sin
from pathlib import Path
import re

from clear_traversal import NODE, replace_vector, split_node, vector


@dataclass(frozen=True)
class Surface:
    x: float
    y: float
    half: float
    thickness: float
    slope: float

    def contains(self, x):
        return abs(self.x - x) <= self.half + .025


def get_position(block):
    at = vector(block, "position")
    if at is not None:
        return at
    transform = re.search(r"(?m)^transform = Transform3D\(([^)]+)\)", block)
    return list(map(float, transform[1].split(",")[-3:])) if transform else None


def path_of(block):
    name, parent = split_node(block)
    return f"{parent}/{name}" if parent not in ("", ".") else name


def surfaces(nodes, scene):
    shapes = {
        match[1]: tuple(map(float, match[2].split(",")))
        for match in re.finditer(r'\[sub_resource type="BoxShape3D" id="([^"]+)"\]\s*size = Vector3\(([^)]+)\)', scene)
    }
    result = []
    for path, block in nodes.items():
        if not path.startswith("TERRAIN/"):
            continue
        tag = block.splitlines()[0]
        at = get_position(block)
        if not at or 'type="AnimatableBody3D"' in tag:
            continue
        if 'instance=ExtResource("Floor")' in tag:
            width, height, depth = 6, .84, 4.8
        elif 'type="StaticBody3D"' in tag:
            child = nodes.get(path + "/Collision", "")
            shape = re.search(r'shape = SubResource\("([^"]+)"\)', child)
            if not shape or shape[1] not in shapes:
                continue
            width, height, depth = shapes[shape[1]]
            local = get_position(child) or (0, 0, 0)
            if abs(local[1] + height / 2) > .065:
                continue
        else:
            continue
        sx, sy, sz = vector(block, "scale") or (1, 1, 1)
        h = sy * height
        if abs(at[2]) > depth * sz / 2 - .4 or h > 2.0:
            continue
        angle = (vector(block, "rotation") or (0, 0, 0))[2]
        result.append(Surface(at[0], at[1], cos(angle) * width * sx / 2, h, sin(angle) / cos(angle)))
    return result


def useable_floor(decks, x, y, distance, headroom):
    # Check across seams between adjoining modules as well as within single meshes.
    steps = max(2, round(distance * 4))
    for sample in range(-steps, steps + 1):
        at = x + sample * distance / steps
        local = [(deck.y + (at - deck.x) * deck.slope, deck.thickness) for deck in decks if deck.contains(at)]
        if not any(abs(top - y) <= .18 for top, _ in local):
            return False
        if any(y + .24 < top and top - depth < y + headroom for top, depth in local):
            return False
    return True


def update_encounters(scene):
    if "metadata/encounter_spacing = 1" in scene:
        return scene
    nodes = {path_of(block): block for block in NODE.findall(scene)}
    decks = surfaces(nodes, scene)
    enemies = [
        (path, get_position(block)) for path, block in nodes.items()
        if path.startswith("Actors/") and '"level_enemies"' in block.splitlines()[0]
    ]
    gate = get_position(nodes["ForgeHallDoor"])[0]
    reserved = []
    traps = []
    for path, block in nodes.items():
        name, _ = split_node(block)
        at = get_position(block)
        if not at:
            continue
        if any(part in name for part in ("Checkpoint", "Spawn", "Vines", "Hatch", "Ladder", "Shutter", "Barricade", "Relay", "SupplyDrone", "SlagBoulder", "Door", "Cache")):
            reserved.append((at[0], at[1], 4.0))
        if 'script = ExtResource("Hazard")' in block:
            width = re.search(r"(?m)^nozzle_width = (\S+)", block)
            traps.append((path, at, float(width[1]) * .5 if width else .82, 0, "purge_relay =" not in block))
        elif 'script = ExtResource("RCBiome")' in block:
            kind = re.search(r"(?m)^kind = (\d+)", block)
            dimensions = vector(block, "dimensions")
            if kind and dimensions and int(kind[1]) in (4, 5, 7, 8, 9, 10):
                traps.append((path, at, dimensions[0] * .5, dimensions[1] * .5, True))
        elif 'script = ExtResource("RCLaser")' in block:
            traps.append((path, at, .75, 0, True))

    for path, at, half, offset, move in traps:
        x, y, z = at
        floor = y - offset
        # A damaging fixture needs a clear floor on both sides to read its warning.
        if move and not useable_floor(decks, x, floor, half + 2.0, 2.0):
            choices = sorted(
                (candidate for deck in decks for candidate in (deck.x - 1, deck.x, deck.x + 1)
                 if 18.0 < candidate < gate - 18.0 and abs(candidate - x) <= 9.0 and abs(deck.y - floor) < .15),
                key=lambda candidate: abs(candidate - x),
            )
            for candidate in choices:
                if any(abs(candidate - rx) < half + radius and abs(floor - ry) < 2.5 for rx, ry, radius in reserved):
                    continue
                if useable_floor(decks, candidate, floor, half + 2.0, 2.0):
                    nodes[path] = replace_vector(nodes[path], "position", (candidate, y, z))
                    x = candidate
                    break
        reserved.append((x, floor, half + 3.6))

    # Grounded reinforcements use wide landings between the existing patrols.
    reinforcement_count = round(len(enemies) * .17)
    pool = [
        deck for deck in decks
        if 25.0 < deck.x < gate - 20.0 and abs(deck.slope) < .035 and deck.half > 1.8
        and useable_floor(decks, deck.x, deck.y, 2.6, 3.2)
    ]
    taken = [at for _, at in enemies if at]
    reinforcements = []
    for index in range(reinforcement_count):
        safe = [
            deck for deck in pool
            if all(abs(deck.x - at[0]) >= 9.0 for at in taken)
            and all(abs(deck.x - x) >= radius or abs(deck.y - y) >= 3.1 for x, y, radius in reserved)
        ]
        if not safe:
            raise ValueError(f"No safe reinforcement landing before x={gate:g}")
        spot = max(safe, key=lambda deck: min(abs(deck.x - at[0]) for at in taken))
        taken.append((spot.x, spot.y, 0.0))
        source = nodes[enemies[index % len(enemies)][0]]
        source = re.sub(r'\bname="[^"]+"', f'name="Reinforcement{index + 1:02d}"', source, count=1)
        source = re.sub(r" unique_id=\d+", "", source, count=1)
        source = replace_vector(source, "position", (spot.x, spot.y + .95, 0))
        source = re.sub(r"(?m)^patrol_model = -?\d+", f"patrol_model = {(0, 2, 3)[index % 3]}", source)
        reinforcements.append(source)

    # Keep scene order stable for matching host and guest actor indices.
    last_enemy = enemies[-1][0]
    def rewrite(match):
        key = path_of(match[0])
        if key == last_enemy:
            return nodes[key].rstrip() + "\n\n" + "\n\n".join(block.strip() for block in reinforcements) + "\n\n"
        return nodes[key]

    updated = NODE.sub(rewrite, scene)
    return updated.replace("metadata/interior_layout = true", "metadata/interior_layout = true\nmetadata/encounter_spacing = 1", 1)


if __name__ == "__main__":
    levels = Path(__file__).resolve().parents[2] / "scenes" / "levels"
    for path in sorted(levels.glob("*.tscn")):
        original = path.read_text(encoding="utf8")
        if "metadata/interior_layout = true" in original:
            updated = update_encounters(original)
            if original != updated:
                path.write_text(updated, encoding="utf8", newline="\n")
                print(path.name)
