import importlib.util
import json
from pathlib import Path
import re
import subprocess
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

try:
    from PyQt6.QtCore import QCoreApplication
    from PyQt6.QtQml import QJSEngine
except ImportError:
    QJSEngine = None


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "package/contents/code/duplicatewidget.py"
SPEC = importlib.util.spec_from_file_location("duplicatewidget", SCRIPT)
duplicatewidget = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(duplicatewidget)


def payload():
    return {
        "containmentId": 12, "appletId": 42, "plugin": duplicatewidget.PLUGIN,
        "settings": {
            "apps": '[{"type":"separator","style":"line"},{"name":"Custom \' \\" # $()"}]',
            "iconSize": 64, "zoom": 2.1, "spacing": 16, "bounceCount": 2,
            "vertical": True, "glassTint": 27, "glassBlur": 80,
            "glassSheen": 60, "showLabels": False,
        },
    }


class DuplicateProcessTest(unittest.TestCase):
    def test_configuration_keys_cover_entire_schema(self):
        schema = ET.parse(ROOT / "package/contents/config/main.xml")
        keys = {entry.attrib["name"] for entry in schema.iter()
                if entry.tag.endswith("}entry")}
        self.assertEqual(keys, set(payload()["settings"]))
        qml = (ROOT / "package/contents/ui/WidgetDuplicator.qml").read_text()
        declared = re.search(r"configurationKeys:\s*(\[[^]]+])", qml).group(1)
        self.assertEqual(keys, set(json.loads(declared)))

    def test_invalid_requests(self):
        for key, value in (("containmentId", 0), ("appletId", "42"),
                           ("plugin", "another.plugin"), ("settings", [])):
            data = payload()
            data[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                duplicatewidget.build_script(data)

    @patch.object(duplicatewidget.shutil, "which", return_value="/usr/bin/qdbus6")
    @patch.object(duplicatewidget.subprocess, "run")
    def test_calls_public_dbus_method_without_shell(self, run, which):
        run.return_value = subprocess.CompletedProcess([], 0, 'HUD_DOCK_DUPLICATE:{"id":43}\n', "")
        self.assertEqual(duplicatewidget.duplicate(payload()), {"id": 43})
        args, kwargs = run.call_args
        self.assertEqual(args[0][:4], [
            "/usr/bin/qdbus6", "org.kde.plasmashell", "/PlasmaShell",
            "org.kde.PlasmaShell.evaluateScript",
        ])
        self.assertNotIn("shell", kwargs)
        self.assertEqual(kwargs["timeout"], 30)

    @patch.object(duplicatewidget.shutil, "which", return_value=None)
    def test_missing_dbus_tool_is_reported(self, which):
        with self.assertRaisesRegex(RuntimeError, "qdbus6"):
            duplicatewidget.duplicate(payload())

    @patch.object(duplicatewidget.shutil, "which", return_value="/usr/bin/qdbus6")
    @patch.object(duplicatewidget.subprocess, "run", side_effect=subprocess.TimeoutExpired("qdbus6", 30))
    def test_timeout_is_not_reported_as_success(self, run, which):
        with self.assertRaises(subprocess.TimeoutExpired):
            duplicatewidget.duplicate(payload())

    @patch.object(duplicatewidget.shutil, "which", return_value="/usr/bin/qdbus6")
    @patch.object(duplicatewidget.subprocess, "run")
    def test_errors_are_not_success(self, run, which):
        for code, out, err in [
            (1, "", "Service unavailable"),
            (0, "Syntax error", ""),
            (0, 'HUD_DOCK_DUPLICATE:{"error":"Locked"}\n', ""),
            (0, 'HUD_DOCK_DUPLICATE:{"id":-1}\n', ""),
            (0, 'HUD_DOCK_DUPLICATE:[]\n', ""),
        ]:
            with self.subTest(out=out, code=code):
                run.return_value = subprocess.CompletedProcess([], code, out, err)
                with self.assertRaises((RuntimeError, ValueError)):
                    duplicatewidget.duplicate(payload())


@unittest.skipIf(QJSEngine is None, "Scripting tests require PyQt6")
class DuplicationScriptTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.engine = QJSEngine()
        result = self.engine.evaluate("""
var output = [];
function print(text) { output.push(text); }
var config = {};
var copy = {
    id: 43, currentConfigGroup: [], removed: false,
    get configKeys() { return Object.keys(config); },
    writeConfig: function (key, value) { config[key] = value; },
    readConfig: function (key, fallback) { return config[key]; },
    remove: function () { this.removed = true; }
};
var original = {
    type: "com.aadi.huddock", locked: false, geometry: {x: 100, y: 120, width: 500, height: 200}
};
var container = {
    locked: false, calls: 0, params: null,
    widgetById: function (id) { return id === 42 ? original : null; },
    addWidget: function (plugin, x, y, w, h) {
        this.calls++; this.params = [plugin, x, y, w, h]; return copy;
    }
};
function desktopById(id) { return id === 12 ? container : null; }
function panelById(id) { return null; }
""")
        self.assertFalse(result.isError(), result.toString())

    def evaluate(self, code):
        result = self.engine.evaluate(code)
        self.assertFalse(result.isError(), result.toString())
        return result

    def run_script(self):
        self.evaluate(duplicatewidget.build_script(payload()))
        line = self.evaluate("output[0]").toString()
        self.assertTrue(line.startswith(duplicatewidget.MARKER))
        return json.loads(line[len(duplicatewidget.MARKER):])

    def test_complete_copy_with_safe_serialization(self):
        self.assertEqual(self.run_script(), {"id": 43})
        self.assertEqual(json.loads(self.evaluate("JSON.stringify(config)").toString()), payload()["settings"])
        self.assertEqual(json.loads(self.evaluate("JSON.stringify(container.params)").toString()),
                         [duplicatewidget.PLUGIN, 132, 152, 500, 200])
        self.assertEqual(self.evaluate("copy.currentConfigGroup[0]").toString(), "General")
        self.assertTrue(self.evaluate("copy.globalShortcut === undefined").toBool())

    def test_panel_is_supported(self):
        self.evaluate("desktopById = function () { return null; }; panelById = function () { return container; };")
        self.assertEqual(self.run_script(), {"id": 43})

    def test_locked_or_deleted_sources_are_rejected(self):
        for code in ("container.locked = true", "original.locked = true",
                     "original.type = 'another.plugin'", "original = null"):
            with self.subTest(code=code):
                self.setUp()
                self.evaluate(code)
                self.assertIn("error", self.run_script())
                self.assertEqual(self.evaluate("container.calls").toInt(), 0)

    def test_partial_copy_is_removed(self):
        self.evaluate("copy.writeConfig = function () { throw new Error('Write failed'); };")
        self.assertIn("error", self.run_script())
        self.assertTrue(self.evaluate("copy.removed").toBool())

    def test_failed_creation_is_reported(self):
        self.evaluate("container.addWidget = function () { return null; };")
        self.assertIn("error", self.run_script())


if __name__ == "__main__":
    unittest.main()
