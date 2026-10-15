#!/usr/bin/env python3
"""Count locally running Codex turns from the user's session journal."""

import json
import os
import sqlite3
import time
from pathlib import Path

MAX_AGE_SECONDS = 600
CHUNK_BYTES = 65536
MAX_THREADS = 100
FINISH_EVENTS = {"task_complete", "turn_aborted"}


def latest_task_event(path):
    """Read backward until the latest task start or finish event is found."""
    try:
        with open(path, "rb") as handle:
            position = handle.seek(0, os.SEEK_END)
            remainder = b""
            while position:
                count = min(CHUNK_BYTES, position)
                position -= count
                handle.seek(position)
                lines = (handle.read(count) + remainder).split(b"\n")
                remainder = lines.pop(0) if position else b""
                for raw in reversed(lines):
                    if not any(event.encode() in raw for event in ("task_started", *FINISH_EVENTS)):
                        continue
                    try:
                        record = json.loads(raw)
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        continue
                    if record.get("type") != "event_msg":
                        continue
                    event = (record.get("payload") or {}).get("type")
                    if event == "task_started":
                        return True
                    if event in FINISH_EVENTS:
                        return False
    except OSError:
        return None
    return None


def active_count(codex_home=None, now=None):
    home = Path(codex_home or os.environ.get("CODEX_HOME") or Path.home() / ".codex")
    database = home / "state_5.sqlite"
    now = now or time.time()
    if not database.exists():
        return -1
    uri = f"file:{database}?mode=ro"
    try:
        with sqlite3.connect(uri, uri=True, timeout=1) as connection:
            rows = connection.execute(
                "SELECT rollout_path FROM threads WHERE archived = 0 AND updated_at >= ? "
                "ORDER BY updated_at DESC LIMIT ?",
                (int(now - MAX_AGE_SECONDS), MAX_THREADS),
            ).fetchall()
    except sqlite3.Error:
        return -1

    count = 0
    for (path,) in rows:
        if not path:
            continue
        try:
            if now - os.path.getmtime(path) > MAX_AGE_SECONDS:
                continue
        except OSError:
            continue
        if latest_task_event(path) is True:
            count += 1
    return count


if __name__ == "__main__":
    print(json.dumps({"active": active_count()}))
