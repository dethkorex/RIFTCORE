"""Serve known archives locally and exercise the launcher's real download path."""

import argparse
import functools
import hashlib
import http.server
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from threading import Thread
import zipfile


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("engine", type=Path)
    parser.add_argument("--windowed", type=Path, help="Save the rendered launcher here")
    args = parser.parse_args()
    dist = Path(__file__).resolve().parent
    platform = "windows-x64" if sys.platform == "win32" else "linux-x64"
    executable = "RIFTCORE.exe" if platform == "windows-x64" else "RIFTCORE"
    with tempfile.TemporaryDirectory(prefix="riftcore-launcher-qa-") as work:
        root = Path(work)
        archive = root / f"RIFTCORE-{platform}.zip"
        with zipfile.ZipFile(archive, "w") as package:
            for name in (executable, "RIFTCORE.pck", "GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt"):
                package.writestr(name, "Launcher verification fixture")
        manifest = {"tag": "v6.3.27-preview", "assets": {platform: {
            "file": archive.name, "size": archive.stat().st_size, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        }}, "notes": (dist.parent / "CHANGELOG.md").read_text(encoding="utf-8")}
        (root / "fixture.json").write_text(json.dumps(manifest), encoding="utf-8")
        (root / "updates.cfg").write_text('[updates]\nrepository="dethkorex/RIFTCORE"\npreview_channel=true\n', encoding="utf-8")
        versions = root / "versions"
        versions.mkdir()
        sentinel = root / "linked-sentinel"
        try:
            (versions / "v6.3.20-preview").symlink_to(sentinel, target_is_directory=True)
        except OSError:
            pass  # Windows may require administrator access to create test symlinks.
        else:
            sentinel.mkdir()
            (sentinel / "RIFTCORE.pck").write_text("Do not delete", encoding="utf-8")
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
            thread = Thread(target=server.serve_forever, daemon=True)
            thread.start()
            flags = ["--windowed", "--audio-driver", "Dummy"] if args.windowed else ["--headless"]
            result = subprocess.run([str(args.engine.resolve()), *flags, "--path", str(dist / "launcher"),
                "--script", str(dist / "verify_launcher.gd"), "--", root.as_posix(),
                f"http://127.0.0.1:{server.server_port}"], timeout=60, check=False, capture_output=True, encoding="utf-8", errors="replace")
            print(result.stdout)
            print(result.stderr)
            server.shutdown()
            if result.returncode or "SCRIPT ERROR:" in result.stderr or "FAIL " in result.stdout:
                raise SystemExit(result.returncode or 1)
            if args.windowed:
                args.windowed.write_bytes((root / "launcher.png").read_bytes())


if __name__ == "__main__":
    main()
