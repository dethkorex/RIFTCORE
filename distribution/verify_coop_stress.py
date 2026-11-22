"""Exercise the live relay using isolated native Windows and WSL Linux clients.

This drives real clients without changing system network settings. The Godot
test link delays and drops application packets only inside these test processes.
"""
import argparse
import os
from pathlib import Path
import queue
import re
import subprocess
import threading
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--windows", type=Path, required=True)
    parser.add_argument("--linux", type=Path, required=True)
    parser.add_argument("--platforms", default="windows,linux")
    parser.add_argument("--suite", choices=("network", "campaign", "abyssal", "lava", "foundry", "foundry-escape"), default="network")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--distro", default="RIFTCORE-QA")
    parser.add_argument("--require-continuous", action="store_true", help="Fail a Foundry run if either operator enters connection recovery.")
    args = parser.parse_args()
    if args.require_continuous and not args.suite.startswith("foundry"):
        parser.error("--require-continuous is for Foundry route tests")
    repo = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    platforms = args.platforms.split(",")
    events = queue.Queue()
    processes, readers, logs = [], [], [[] for _ in platforms]

    def linux_path(path):
        path = path.resolve().as_posix()
        return "/mnt/" + path[0].lower() + path[2:]

    # Synchronize QA checkpoints separately from gameplay traffic. A unique directory
    # prevents stale checkpoint files from satisfying a repeat run.
    checkpoints = output / ("checkpoints-" + str(time.time_ns()))
    if args.suite.startswith("foundry"):
        checkpoints.mkdir()

    def launch(index, room=""):
        cli = ["--headless", "--path", str(repo), "--max-fps", "60", "--script", "res://tests/coop_stress.gd",
               "--", "--coop-stress", "host" if index == 0 else "join",
               str(len(platforms)), str(index), args.suite, *([room] if room else [])]
        if args.require_continuous:
            cli.append("--require-continuous")
        if args.suite.startswith("foundry"):
            cli.append("--foundry-sync=" + (str(checkpoints) if platforms[index] == "windows" else linux_path(checkpoints)))
        env = os.environ.copy()
        private = output / ("userdata-" + str(index))
        private.mkdir(exist_ok=True)
        if platforms[index] == "windows":
            env["APPDATA"] = str(private)
            command = [str(args.windows.resolve()), *cli]
        else:
            import shlex
            cli[2] = linux_path(repo)
            script = output / ("client-" + str(index) + ".sh")
            script.write_bytes(("#!/bin/sh\nexport GODOT_SILENCE_ROOT_WARNING=1\n"
                + "export XDG_DATA_HOME=" + shlex.quote(linux_path(private)) + "\nexec "
                + shlex.join([linux_path(args.linux), *cli]) + "\n").encode())
            command = ["wsl.exe", "-d", args.distro, "-u", "root", "-e", "/bin/sh", linux_path(script)]
        process = subprocess.Popen(command, cwd=repo, env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace",
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        processes.append(process)

        def read():
            with (output / ("client-" + str(index) + ".log")).open("w", encoding="utf-8") as file:
                for line in process.stdout:
                    logs[index].append(line)
                    file.write(line)
                    file.flush()
                    events.put((index, line.rstrip()))
        reader = threading.Thread(target=read, daemon=True)
        readers.append(reader)
        reader.start()

    try:
        launch(0)
        joined = False
        deadline = time.monotonic() + (1200 if args.suite == "campaign" else 650)
        while time.monotonic() < deadline:
            try:
                index, line = events.get(timeout=1)
                if "STRESS ROOM " in line and not joined:
                    room = re.search(r"STRESS ROOM (\w+)", line)[1]
                    for guest in range(1, len(platforms)):
                        launch(guest, room)
                    joined = True
                    print("Started " + ", ".join(platforms) + " clients.", flush=True)
                if "STRESS " in line and not any(noise in line for noise in
                    ("ROOM ", "party send", "barrier ", "STRESS POSITION")):
                    print(f"[{index}/{platforms[index]}] {line}", flush=True)
                if "SCRIPT ERROR" in line or "STRESS FAIL" in line:
                    raise RuntimeError(f"Client {index}: {line}")
            except queue.Empty:
                pass
            if all(p.poll() is not None for p in processes):
                for reader in readers:
                    reader.join(2)
                if not joined or any(p.returncode for p in processes) or any(
                    not any("STRESS RESULT" in line and "failures=0" in line for line in log)
                    for log in logs):
                    raise RuntimeError("A client exited without a successful result; see client logs.")
                print("All native clients passed.", flush=True)
                return
        raise TimeoutError("Co-op stress test exceeded its time limit.")
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    main()
