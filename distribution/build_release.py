from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "distribution"
ENGINE_ASSETS = {"windows-x64": ("Windows x64", "RIFTCORE.exe", "windows_release_x86_64.exe"),
                 "linux-x64": ("Linux x64", "RIFTCORE", "linux_release.x86_64")}
LICENSES = ["GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt"]


@contextlib.contextmanager
def local_templates(config: Path, templates: Path):
    original = config.read_bytes()
    try:
        data = original.decode("utf-8")
        names = [x[2] for x in ENGINE_ASSETS.values()]
        for i, match in enumerate(reversed(list(re.finditer(r'custom_template/release=""', data)))):
            start, end = match.span()
            filename = (templates / names[len(names) - 1 - i]).as_posix()
            data = data[:start] + f'custom_template/release="{filename}"' + data[end:]
        config.write_text(data, encoding="utf-8", newline="\n")
        yield
    finally:
        config.write_bytes(original)


def godot(engine: Path, project: Path, log: Path, *flags: str) -> None:
    command = [str(engine), "--headless", "--path", str(project), "--log-file", str(log), *flags]
    proc = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240)
    output = log.read_text(encoding="utf-8", errors="replace") if log.exists() else proc.stdout + proc.stderr
    if proc.returncode or "SCRIPT ERROR:" in output or "Export failed" in output:
        print(output[-11000:])
        raise RuntimeError(f"Godot failed: {flags} ({proc.returncode})")


def export(engine: Path, project: Path, preset: str, destination: Path, log: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    godot(engine, project, log, "--export-release", preset, str(destination))
    if not destination.is_file() or destination.stat().st_size < 1000000:
        raise RuntimeError(f"Export did not produce {destination}")


def linux_installer(payload: Path, out: Path) -> None:
    script = (DIST / "linux-installer.sh").read_bytes().replace(b"\r\n", b"\n")
    with out.open("wb") as dst:
        dst.write(script.rstrip(b"\n") + b"\n")
        with tarfile.open(fileobj=dst, mode="w:gz", compresslevel=6) as tar:
            for child in sorted(payload.rglob("*")):
                if not child.is_file():
                    continue
                info = tar.gettarinfo(str(child), arcname=child.relative_to(payload).as_posix())
                info.uid = info.gid = 0
                info.uname = info.gname = ""
                info.mode = 0o755 if child.name == "RIFTCORE" else 0o644
                with child.open("rb") as src:
                    tar.addfile(info, src)
    out.chmod(0o755)


def windows_installer(payload: Path, out: Path, nsis: Path) -> None:
    if not nsis.exists():
        raise RuntimeError("Windows installer compiler not found")
    switch = "/D" if sys.platform == "win32" else "-D"
    subprocess.run([str(nsis), switch + "PAYLOAD=" + str(payload), switch + "OUTPUT=" + str(out),
                    switch + "BRAND_ICO=" + str(payload / "riftcore.ico"),
                    str(DIST / "windows-installer.nsi")], check=True, timeout=240)
    if not out.is_file():
        raise RuntimeError("NSIS did not produce an installer")


def main() -> None:
    cli = argparse.ArgumentParser()
    cli.add_argument("--engine", type=Path, required=True)
    cli.add_argument("--templates", type=Path, required=True)
    cli.add_argument("--licenses", type=Path, required=True)
    cli.add_argument("--nsis", type=Path, required=True)
    cli.add_argument("--skip-windows-installer", action="store_true")
    cli.add_argument("--work", type=Path, required=True)
    cli.add_argument("--out", type=Path, required=True)
    cli.add_argument("--tag", default="v0.1.0")
    cli.add_argument("--repo", default="")
    a = cli.parse_args()
    if not re.fullmatch(r"v[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}", a.tag):
        cli.error("tag must be vMAJOR.MINOR.PATCH")
    if a.repo and not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9_.-]{1,90}", a.repo):
        cli.error("repo must be owner/name")
    engine, templates, nsis, work, out, license_path = map(Path.resolve,
        (a.engine, a.templates, a.nsis, a.work, a.out, a.licenses))
    work.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)
    launcher = DIST / "launcher"
    icon = launcher / "branding" / "riftcore-icon.svg"
    icon_cache = work / "riftcore.ico"
    godot(engine, launcher, work / "branding.log", "--script", str(DIST / "make_brand_icon.gd"), "--", str(icon), str(icon_cache))
    godot(engine, ROOT, work / "game-import.log", "--editor", "--import")
    godot(engine, launcher, work / "launcher-import.log", "--editor", "--import")
    notes = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8-sig").strip()
    if len(notes.encode("utf-8")) > 14000:
        raise ValueError("Release notes exceed the launcher manifest budget")
    manifest = {"tag": a.tag, "assets": {}, "notes": notes}
    (out / "PATCH_NOTES.md").write_text(notes + "\n", encoding="utf-8")
    with local_templates(ROOT / "export_presets.cfg", templates), local_templates(launcher / "export_presets.cfg", templates):
        for platform, (preset, binary, _) in ENGINE_ASSETS.items():
            payload = work / platform / "install"
            version = payload / "versions" / a.tag
            export(engine, ROOT, preset, version / binary, work / f"{platform}-game.log")
            export(engine, launcher, preset, payload / binary, work / f"{platform}-launcher.log")
            if platform == "windows-x64":
                shutil.copy2(icon_cache, payload / "riftcore.ico")
            else:
                shutil.copy2(icon, payload / "riftcore-icon.svg")
            if platform == "linux-x64":
                (version / binary).chmod(0o755)
                (payload / binary).chmod(0o755)
            for file in LICENSES:
                shutil.copy2(license_path / file, version / file)
            (payload / "updates.cfg").write_text(
                f'[updates]\nrepository="{a.repo}"\nbundled_notes_tag="{a.tag}"\n', encoding="utf-8", newline="\n"
            )
            shutil.copy2(out / "PATCH_NOTES.md", payload / "PATCH_NOTES.md")
            game_zip = out / f"RIFTCORE-{platform}.zip"
            with zipfile.ZipFile(game_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=5) as archive:
                for name in [binary, "RIFTCORE.pck", *LICENSES]:
                    archive.write(version / name, arcname=name)
            with game_zip.open("rb") as handle:
                checksum = hashlib.file_digest(handle, "sha256").hexdigest()
            manifest["assets"][platform] = {"file": game_zip.name, "size": game_zip.stat().st_size, "sha256": checksum}
            print(f"Packaged {platform}: {game_zip.name}", flush=True)
            if platform == "windows-x64":
                if not a.skip_windows_installer:
                    windows_installer(payload, out / "RIFTCORE-Windows-x64-Setup.exe", nsis)
            else:
                linux_installer(payload, out / "RIFTCORE-Linux-x64-Setup.run")
    (out / "update.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
