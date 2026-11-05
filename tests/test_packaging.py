import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile


SCRIPT = Path(__file__).resolve().parents[1] / "make-package.sh"


class PackagingTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copy2(SCRIPT, self.root / SCRIPT.name)
        self.package = self.root / "package"
        self.package.mkdir()
        self.metadata = self.package / "metadata.json"
        self.output = self.root / "dist/com.example.dock.plasmoid"
        (self.package / "contents").mkdir()
        (self.package / "contents/main.qml").write_text("import QtQuick\nItem {}\n")
        (self.package / "contents/__pycache__").mkdir()
        (self.package / "contents/__pycache__/cached.pyc").write_bytes(b"cache")
        (self.package / "contents/cached.pyc").write_bytes(b"cache")
        self.set_version("1.1.0")

    def set_version(self, version):
        self.metadata.write_text(json.dumps({
            "KPlugin": {"Id": "com.example.dock", "Version": version, "Name": "Dock"},
            "KPackageStructure": "Plasma/Applet",
        }) + "\n", encoding="utf-8")

    def build(self):
        return subprocess.run(
            ["bash", str(self.root / SCRIPT.name)],
            cwd=self.root.parent, capture_output=True, text=True,
        )

    def assert_version(self, expected):
        self.assertEqual(json.loads(self.metadata.read_text())["KPlugin"]["Version"], expected)
        with zipfile.ZipFile(self.output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(json.loads(archive.read("metadata.json"))["KPlugin"]["Version"], expected)
            self.assertEqual(sorted(archive.namelist()), ["contents/main.qml", "metadata.json"])

    def test_increments_each_build_and_packages_matching_version(self):
        for version in ("1.1.0+1", "1.1.0+2"):
            result = self.build()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(version, result.stdout)
            self.assert_version(version)

    def test_preserves_release_and_prerelease(self):
        self.set_version("2.3.4-rc.1+9")
        result = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_version("2.3.4-rc.1+10")

    def test_new_release_restarts_counter(self):
        self.assertEqual(self.build().returncode, 0)
        self.set_version("1.2.0")
        self.assertEqual(self.build().returncode, 0)
        self.assert_version("1.2.0+1")

    def test_invalid_version_preserves_metadata_and_previous_package(self):
        self.assertEqual(self.build().returncode, 0)
        previous_archive = self.output.read_bytes()
        for version in ("1.1", "01.1.0", "1.1.0+abc", "1.1.0+01", "1.1.0-01"):
            with self.subTest(version=version):
                self.set_version(version)
                previous_metadata = self.metadata.read_bytes()
                result = self.build()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Invalid version", result.stderr)
                self.assertEqual(self.metadata.read_bytes(), previous_metadata)
                self.assertEqual(self.output.read_bytes(), previous_archive)

    def test_build_failure_does_not_increment(self):
        (self.root / "dist").write_text("not a directory")
        before = self.metadata.read_bytes()
        result = self.build()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.metadata.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
