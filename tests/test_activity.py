import importlib.util
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "scripts" / "codex-activity.py"
spec = importlib.util.spec_from_file_location("codex_activity", SOURCE)
activity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(activity)


class ActivityTests(unittest.TestCase):
    def test_counts_only_unfinished_recent_tasks(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            database = sqlite3.connect(home / "state_5.sqlite")
            database.execute("CREATE TABLE threads (rollout_path TEXT, archived INTEGER, updated_at INTEGER)")
            now = int(__import__("time").time())
            for index, events in enumerate((
                ["task_started"],
                ["task_started", "task_complete"],
                ["task_started"],
                ["task_started", "turn_aborted"],
            )):
                path = home / f"task-{index}.jsonl"
                path.write_text("".join(json.dumps({"type": "event_msg", "payload": {"type": event}}) + "\n" for event in events))
                database.execute("INSERT INTO threads VALUES (?, 0, ?)", (str(path), now))
            database.commit()
            self.assertEqual(activity.active_count(home, now), 2)
            database.close()

    def test_start_event_before_large_output(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "long-task.jsonl"
            with path.open("w") as handle:
                handle.write(json.dumps({"type": "event_msg", "payload": {"type": "task_started"}}) + "\n")
                handle.write(json.dumps({"type": "response_item", "payload": {"output": "x" * 300000}}) + "\n")
            self.assertIs(activity.latest_task_event(path), True)

    def test_missing_database_is_unknown(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(activity.active_count(directory), -1)


if __name__ == "__main__":
    unittest.main()
