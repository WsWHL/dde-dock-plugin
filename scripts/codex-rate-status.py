#!/usr/bin/env python3
"""Read the Codex account rate limit for the Deepin dock applet."""

import glob
import json
import os
import select
import subprocess
import time


def codex_binary():
    paths = sorted(glob.glob(os.path.expanduser("~/.config/nvm/versions/node/*/bin/codex")), reverse=True)
    return paths[0] if paths else "codex"


def read_rate_limits():
    binary = codex_binary()
    env = os.environ.copy()
    env["PATH"] = os.path.dirname(binary) + os.pathsep + env.get("PATH", "")
    proc = subprocess.Popen([binary, "app-server", "--listen", "stdio://"],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, env=env)
    try:
        for message in (
            {"method": "initialize", "id": 1, "params": {"clientInfo": {"name": "deepin_dock_codex_status", "title": "Deepin Dock Codex Status", "version": "1.0.0"}}},
            {"method": "initialized", "params": {}},
            {"method": "account/rateLimits/read", "id": 2},
        ):
            proc.stdin.write((json.dumps(message) + "\n").encode())
        proc.stdin.flush()
        deadline = time.monotonic() + 15
        pending = b""
        while time.monotonic() < deadline:
            ready, _, _ = select.select([proc.stdout], [], [], deadline - time.monotonic())
            if not ready:
                break
            data = os.read(proc.stdout.fileno(), 65536)
            if not data:
                break
            pending += data
            while b"\n" in pending:
                line, pending = pending.split(b"\n", 1)
                response = json.loads(line)
                if response.get("id") == 2:
                    return response.get("result")
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    return None


def status(result):
    if not isinstance(result, dict):
        return {"remaining": -1}
    buckets = result.get("rateLimitsByLimitId") or {}
    bucket = buckets.get("codex") or result.get("rateLimits") or {}
    windows = [bucket.get(key) for key in ("primary", "secondary")]
    values = [round(max(0, min(100, 100 - window["usedPercent"])))
              for window in windows if isinstance(window, dict) and isinstance(window.get("usedPercent"), (int, float))]
    if not values:
        return {"remaining": -1}
    remaining = min(values)
    return {"remaining": remaining}


if __name__ == "__main__":
    try:
        print(json.dumps(status(read_rate_limits())))
    except (OSError, ValueError, subprocess.SubprocessError):
        print(json.dumps({"state": "unknown", "remaining": -1}))
