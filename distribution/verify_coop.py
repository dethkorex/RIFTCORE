"""Run the packaged co-op mission through the live relay with two clients."""

import os
import queue
import re
import subprocess
import sys
import threading
import time
from pathlib import Path


def verify(executable: Path, sector: str = "") -> None:
    encoding = "utf-8" if os.name != "nt" else None
    def launch(*arguments: str) -> subprocess.Popen:
        return subprocess.Popen(
            [str(executable), "--headless", "--", "--verify-relay", *arguments, "mission",
             *(["jungle"] if sector == "jungle" else [])],
            cwd=executable.parent,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding=encoding,
            errors="replace",
        )

    host = launch("host")
    guest = None
    lines: list[str] = []
    events: queue.Queue[str] = queue.Queue()

    def read_host() -> None:
        for line in host.stdout:
            lines.append(line)
            events.put(line)
        events.put("")

    reader = threading.Thread(target=read_host, daemon=True)
    reader.start()
    try:
        deadline = time.monotonic() + 40
        while guest is None:
            try:
                line = events.get(timeout=max(0.1, deadline - time.monotonic()))
            except queue.Empty as error:
                raise RuntimeError("Timed out waiting for the packaged host to create a room.") from error
            if not line or "RELAY CHECK FAIL" in line:
                raise RuntimeError("Host could not start a co-op room.")
            match = re.fullmatch(r"RELAY ROOM CODE ([A-Z0-9]{10})", line.strip())
            if match:
                guest = launch("join", match[1])
        output, _ = guest.communicate(timeout=115 if sector == "jungle" else 80)
        host.wait(timeout=20)
        reader.join(timeout=2)
        if guest.returncode or host.returncode or any(
            "RELAY CHECK PASS" not in result for result in (output, "".join(lines))
        ):
            print(output)
            raise RuntimeError("Co-op mission did not pass on both clients.")
        if sector == "jungle":
            for result in (output, "".join(lines)):
                if result.count("JUNGLE CROSSING") != 2 or " false" in "\n".join(
                    line for line in result.splitlines() if line.startswith("JUNGLE CROSSING")
                ):
                    raise RuntimeError("A client did not cross both Jungle jumps.")
            print("Both live clients crossed the Jungle jumps and completed both acts.")
        else:
            print("Live party join, names, independent cameras and controls, shared rewards and return passed.")
    finally:
        for process in (host, guest):
            if process is not None and process.poll() is None:
                process.kill()
                process.wait()
        for line in lines:
            if not line.startswith("RELAY ROOM CODE"):
                print(line.rstrip())


if __name__ == "__main__":
    verify(Path(sys.argv[1]).resolve(), sys.argv[2] if len(sys.argv) > 2 else "")
