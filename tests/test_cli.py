"""Проверки поведения через настоящий интерфейс командной строки."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CliTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.file = Path(self.directory.name) / "nested" / "tasks.json"

    def run_cli(self, *args):
        return subprocess.run([sys.executable, "-m", "src.main", "--file", str(self.file), *args],
                              cwd=ROOT, capture_output=True, text=True)

    def test_task_lifecycle(self):
        self.assertIn("Задач пока нет", self.run_cli("list").stdout)
        for title in ("Изучить Git", "Подготовить отчёт"):
            self.assertEqual(self.run_cli("add", title).returncode, 0)
        self.assertEqual(self.run_cli("done", "1").returncode, 0)
        listing = self.run_cli("list")
        self.assertEqual(listing.returncode, 0)
        self.assertIn("[x] #1 Изучить Git", listing.stdout)
        self.assertIn("[ ] #2 Подготовить отчёт", listing.stdout)

    def test_invalid_input_does_not_modify_file(self):
        self.assertEqual(self.run_cli("add", "Задача").returncode, 0)
        before = self.file.read_bytes()
        for args in (("add", "  "), ("done", "999")):
            self.assertNotEqual(self.run_cli(*args).returncode, 0)
            self.assertEqual(self.file.read_bytes(), before)

    def test_corrupt_storage_is_not_overwritten(self):
        self.file.parent.mkdir(parents=True)
        for content in ("{invalid", json.dumps({"unexpected": True}), '[{"id": 1}]'):
            self.file.write_text(content, encoding="utf-8")
            result = self.run_cli("add", "Новая задача")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Ошибка:", result.stderr)
            self.assertEqual(self.file.read_text(encoding="utf-8"), content)


if __name__ == "__main__":
    unittest.main()
