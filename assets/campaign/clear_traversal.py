"""Apply the authored clearance pass to both campaign generators."""

from pathlib import Path
import re


NODE = re.compile(r"(?m)^\[node [^\n]*\]\n[\s\S]*?(?=^\[|\Z)")
REMOVED = {
    # The hall exit deck already covers this platform.
    "AlcoveCeiling",
    # Dropping from the lift's upper landing directly to the apron is safe.
    "HighReturn",
    # One drop past the shaft wall gives the intended 180-degree turn.
    "ShaftLanding00",
    "TurnbackShaftLanding00",
}
RAISE = {
    "RecessLintel": 0.95,
    "RecessEnd": 0.475,
    "VaultRoof": 0.51,
    "VaultBack": 0.255,
    "ForgeServiceCeiling": 1.04,
    "WardenSideShelf": 0.22,
}


def vector(body, key):
    match = re.search(rf"(?m)^{re.escape(key)} = Vector3\(([^)]+)\)", body)
    return [float(value) for value in match[1].split(",")] if match else None


def replace_vector(body, key, values):
    formatted = ", ".join(f"{value:.4f}".rstrip("0").rstrip(".") for value in values)
    return re.sub(rf"(?m)^{re.escape(key)} = Vector3\([^)]*\)", f"{key} = Vector3({formatted})", body)


def split_node(body):
    header = body.splitlines()[0]
    name = re.search(r'\bname="([^"]+)"', header)[1]
    parent = re.search(r'\bparent="([^"]+)"', header)
    return name, parent[1] if parent else ""


def clear_decks(scene):
    if "metadata/clearance_pass" in scene:
        return scene
    removed_paths = set()

    def rewrite(match):
        body = match[0]
        name, parent = split_node(body)
        path = parent + "/" + name
        if parent in removed_paths:
            removed_paths.add(path)
            return ""
        if not parent or not parent.startswith("TERRAIN"):
            return body
        if name in REMOVED:
            removed_paths.add(path)
            return ""
        at = vector(body, "position")
        if at is None:
            return body
        if name in RAISE:
            amount = RAISE[name]
            at[1] += amount
            body = replace_vector(body, "position", at)
            if name in ("RecessEnd", "VaultBack"):
                scale = vector(body, "scale")
                if scale:
                    # The wall scene is four meters high before scale.
                    scale[1] += amount * 0.5
                    body = replace_vector(body, "scale", scale)
        elif name == "MaintenanceAlcove":
            # The shelf has a second route above it. The exit is its ceiling.
            at[1] -= 0.17
            body = replace_vector(body, "position", at)
        return body

    updated = NODE.sub(rewrite, scene)
    # The authored hall alcove moves as a unit, including the cache and hatch.
    shelves = []
    for node in NODE.findall(updated):
        name, parent = split_node(node)
        if name == "MaintenanceAlcove" and parent.endswith("_Hall"):
            shelves.append((parent, vector(node, "position")))

    def align_alcove(match):
        body = match[0]
        name, parent = split_node(body)
        at = vector(body, "position")
        if at is None:
            return body
        for path, shelf in shelves:
            hall_item = parent == "TERRAIN" and name.startswith("InteriorCache") and abs(at[0] - shelf[0] - 0.5) < 0.08
            if (parent == path and name in ("AlcoveHatch", "AlcoveEnd", "FracturedBarricade")) or hall_item:
                at[1] -= 0.17
                body = replace_vector(body, "position", at)
                if name == "AlcoveHatch":
                    body = re.sub(r"(?m)^climb_height = (\S+)", lambda m: f"climb_height = {float(m[1]) - 0.17:.2f}", body)
                break
        return body

    updated = NODE.sub(align_alcove, updated)
    return updated.replace("metadata/interior_layout = true", "metadata/interior_layout = true\nmetadata/clearance_pass = 1", 1)


def frozen_switchback(scene):
    """Fit the two authored lines between the existing vault and sump."""
    room = "TERRAIN/Room05_Switchback"
    path = "res://assets/campaign/frozen_reactor/kit/coolant_switchback.tscn"
    if path in scene:
        return scene
    replaced = {"Entry00", "ForkApron00", "MiddleStep", "MiddleEast00",
                "VaultExitStep", "VaultSecondStep", "MainDescent"}

    def replace_deck(match):
        name, parent = split_node(match[0])
        parts = (parent + "/" + name).split(room + "/", 1)
        if len(parts) == 2:
            deck = parts[1].split("/", 1)[0]
            if deck == name == "Entry00":
                return (f'[node name="CoolantSwitchback" parent="{room}" instance=ExtResource("CoolantFork")]\n'
                        'position = Vector3(289, 4.35, 0)\n\n')
            if deck in replaced or deck.startswith(("MainToDrop", "MiddleWest")):
                return ""
        return match[0]

    scene = NODE.sub(replace_deck, scene)
    return scene.replace("[ext_resource", f'[ext_resource type="PackedScene" path="{path}" id="CoolantFork"]\n[ext_resource', 1)


def frost_decks(scene):
    def mark(match):
        body = match[0]
        name, parent = split_node(body)
        icy_apron = name == "LeftApron00" and parent.endswith(("_Bridge", "_Lift"))
        if not icy_apron or "ice_deck" in body:
            return body
        header, rest = body.split("\n", 1)
        if "groups=[" in header:
            header = header.replace("groups=[", 'groups=["ice_deck", ', 1)
        else:
            header = header[:-1] + ' groups=["ice_deck"]]'
        return header + "\n" + rest
    return NODE.sub(mark, scene)


if __name__ == "__main__":
    levels = Path(__file__).resolve().parents[2] / "scenes" / "levels"
    for path in levels.glob("*.tscn"):
        original = path.read_text(encoding="utf8")
        if "metadata/interior_layout = true" in original:
            cleaned = clear_decks(original)
            if path.stem in ("frozen_reactor", "frozen_reactor_act_2"):
                cleaned = frost_decks(cleaned)
            if cleaned != original:
                path.write_text(cleaned, encoding="utf8", newline="\n")
