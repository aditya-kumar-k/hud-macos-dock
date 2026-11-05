import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "package/contents/code/listapps.py"
SPEC = importlib.util.spec_from_file_location("listapps", SCRIPT)
listapps = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(listapps)


class DesktopFilesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)

    def desktop(self, name="example.desktop", contents=None):
        path = self.directory / name
        path.write_text(
            contents if contents is not None else
            "[Desktop Entry]\nType=Application\nName=Example\nIcon=example\nExec=example %U\n",
            encoding="utf-8",
        )
        return path

    def test_import_metadata_and_encoded_filename(self):
        path = self.desktop("ação ' $() # %.desktop")
        result = listapps.dropped_apps([path.as_uri()])
        self.assertEqual(result, {
            "apps": [{"id": path.name, "name": "Example", "icon": "example", "path": str(path)}],
            "errors": [],
        })

    def test_localhost_url(self):
        path = self.desktop()
        result = listapps.dropped_apps([path.as_uri().replace("file:///", "file://localhost/")])
        self.assertEqual(result["apps"][0]["path"], str(path))
        self.assertEqual(result["errors"], [])

    def test_partial_batch_preserves_order_and_reports_errors(self):
        first = self.desktop("first.desktop")
        last = self.desktop("last.desktop")
        result = listapps.dropped_apps([
            first.as_uri(), (self.directory / "missing.desktop").as_uri(), last.as_uri(),
        ])
        self.assertEqual([app["id"] for app in result["apps"]], [first.name, last.name])
        self.assertEqual(len(result["errors"]), 1)
        self.assertIn("missing.desktop", result["errors"][0])

    def test_rejects_non_local_or_non_desktop_urls(self):
        path = self.desktop()
        for url in [
            "https://example.com/example.desktop", "file://remote/tmp/example.desktop",
            "file:relative.desktop", path.as_uri() + "?query", path.as_uri() + "#fragment",
            (self.directory / "file.txt").as_uri(), "file:///tmp/bad%00.desktop",
        ]:
            with self.subTest(url=url):
                result = listapps.dropped_apps([url])
                self.assertEqual(result["apps"], [])
                self.assertEqual(len(result["errors"]), 1)

    def test_rejects_invalid_desktop_entries(self):
        for contents in [
            "not a desktop entry", "[Other]\nName=Other\n",
            "[Desktop Entry]\nType=Link\nName=Link\nURL=https://example.com\n",
            "[Desktop Entry]\nType=Application\nExec=example\n",
            "[Desktop Entry]\nType=Application\nName= \nExec=example\n",
            "[Desktop Entry]\nType=Application\nName=Example\n",
            "[Desktop Entry]\nType=Application\nName=Example\nExec=example\nHidden=true\n",
        ]:
            with self.subTest(contents=contents):
                result = listapps.dropped_apps([self.desktop(contents=contents).as_uri()])
                self.assertEqual(result["apps"], [])
                self.assertEqual(len(result["errors"]), 1)

    def test_bad_encoding_and_directory_are_reported(self):
        path = self.desktop()
        path.write_bytes(b"\xff")
        directory = self.directory / "folder.desktop"
        directory.mkdir()
        result = listapps.dropped_apps([path.as_uri(), directory.as_uri()])
        self.assertEqual(result["apps"], [])
        self.assertEqual(len(result["errors"]), 2)

    def test_nodisplay_and_dbus_launchers_can_be_dropped(self):
        path = self.desktop(contents=(
            "[Desktop Entry]\nType=Application\nName=Background\n"
            "NoDisplay=true\nDBusActivatable=true\n"
        ))
        self.assertEqual(listapps.dropped_apps([path.as_uri()])["apps"][0]["name"], "Background")
        with self.assertRaises(ValueError):
            listapps.read_app(path)

    def test_missing_icon_uses_fallback_and_drop_does_not_execute(self):
        marker = self.directory / "executed"
        path = self.desktop(contents=(
            f"[Desktop Entry]\nType=Application\nName=Example\nExec=touch {marker}\n"
        ))
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--desktop-files", path.as_uri()],
            check=True, capture_output=True, text=True,
        )
        self.assertEqual(json.loads(result.stdout)["apps"][0]["icon"], "application-x-executable")
        self.assertFalse(marker.exists())

    def test_installed_apps_keep_filtering_sorting_and_overrides(self):
        system = self.directory / "system"
        user = self.directory / "user"
        system.mkdir()
        user.mkdir()
        original = self.desktop("same.desktop")
        override = user / original.name
        override.write_text("[Desktop Entry]\nType=Application\nName=Zebra\n", encoding="utf-8")
        alpha = self.desktop("alpha.desktop", "[Desktop Entry]\nType=Application\nName=Alpha\n")
        hidden = self.desktop("hidden.desktop", "[Desktop Entry]\nType=Application\nName=Hidden\nHidden=true\n")
        excluded = self.desktop("excluded.desktop", "[Desktop Entry]\nType=Application\nName=Excluded\nNoDisplay=true\n")
        with patch.dict(os.environ, {"XDG_DATA_DIRS": f"{system}:{user}"}), patch.object(
            listapps.glob, "glob",
            side_effect=lambda pattern: (
                [str(original), str(alpha), str(hidden), str(excluded)]
                if pattern.startswith(str(system)) else
                [str(override)] if pattern.startswith(str(user)) else []
            ),
        ):
            apps = listapps.installed_apps()
        self.assertEqual([app["name"] for app in apps], ["Alpha", "Zebra"])
        self.assertEqual(apps[1]["path"], str(override))


if __name__ == "__main__":
    unittest.main()
