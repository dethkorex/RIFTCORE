from __future__ import annotations

import argparse
import io
import shutil
import urllib.request
import zipfile
from pathlib import Path

VERSION = "4.7.2-stable"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}"
TEMPLATE = f"{BASE}/Godot_v{VERSION}_export_templates.tpz"
FILES = ["windows_release_x86_64.exe", "linux_release.x86_64"]


class RemoteZip(io.RawIOBase):
    def __init__(self, url: str):
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=30) as response:
            self.url = response.geturl()
            self.size = int(response.headers["Content-Length"])
        self.offset = 0

    def seekable(self) -> bool:
        return True

    def readable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.offset

    def seek(self, offset: int, whence: int = 0) -> int:
        value = offset if whence == 0 else (self.offset if whence == 1 else self.size) + offset
        if value < 0:
            raise OSError("Negative seek")
        self.offset = value
        return value

    def read(self, n: int = -1) -> bytes:
        size = self.size - self.offset if n < 0 else min(n, self.size - self.offset)
        if size <= 0:
            return b""
        start = self.offset
        stop = start + size - 1
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{stop}", "Accept-Encoding": "identity"})
        with urllib.request.urlopen(request, timeout=75) as response:
            if response.status != 206 or response.headers.get("Content-Range") != f"bytes {start}-{stop}/{self.size}":
                raise OSError("Server did not honor a template range request")
            data = response.read()
        if len(data) != size:
            raise OSError("Incomplete template response")
        self.offset += size
        return data


def main() -> None:
    cli = argparse.ArgumentParser()
    cli.add_argument("folder", type=Path)
    args = cli.parse_args()
    args.folder.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteZip(TEMPLATE)) as archive:
        for name in FILES:
            dest = args.folder / name
            if dest.is_file() and dest.stat().st_size > 10000000:
                continue
            entry = archive.getinfo("templates/" + name)
            # Fetch each selected entry in one contiguous range to avoid many small requests.
            stream = archive.fp
            stream.seek(entry.header_offset)
            block = stream.read(entry.compress_size + 1024)
            packed = io.BytesIO(block)
            original = archive.fp
            archive.fp = packed
            local = zipfile.ZipInfo(entry.filename)
            for field in ("compress_type", "compress_size", "file_size", "CRC", "flag_bits", "_raw_time", "extract_version"):
                setattr(local, field, getattr(entry, field))
            local.header_offset = 0
            local._end_offset = len(block)
            partial = dest.with_suffix(dest.suffix + ".partial")
            try:
                with archive.open(local) as source, partial.open("wb") as target:
                    shutil.copyfileobj(source, target)
                partial.replace(dest)
            finally:
                archive.fp = original
            print(f"Fetched {name} ({dest.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
