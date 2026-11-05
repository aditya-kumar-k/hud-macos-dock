import os
from pathlib import Path
import tempfile
import time
import unittest

try:
    from PyQt6.QtCore import QUrl
    from PyQt6.QtGui import QGuiApplication
    from PyQt6.QtQml import QJSValue, QQmlComponent, QQmlEngine
    from PyQt6.QtTest import QTest
except ImportError:
    QQmlEngine = None


@unittest.skipIf(QQmlEngine is None, "Desktop synchronization tests require PyQt6 and KDE QML modules")
class DesktopSyncTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        cls.app = QGuiApplication.instance() or QGuiApplication([])

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "app ' # %.desktop"
        self.write_desktop("Original", "original")
        self.engine = QQmlEngine()
        harness = Path(__file__).parent / "fixtures/SyncHarness.qml"
        self.component = QQmlComponent(self.engine, QUrl.fromLocalFile(str(harness)))
        self.assertEqual(self.component.status(), QQmlComponent.Status.Ready,
                         "\n".join(error.toString() for error in self.component.errors()))
        self.root = self.component.create()
        self.assertIsNotNone(self.root)
        self.root.setProperty("items", [self.item()])

    def tearDown(self):
        self.root.deleteLater()
        self.component.deleteLater()
        self.engine.deleteLater()
        self.app.processEvents()

    def write_desktop(self, name, icon):
        self.path.write_text(
            f"[Desktop Entry]\nType=Application\nName={name}\nIcon={icon}\nExec=true\n",
            encoding="utf-8",
        )

    def item(self, **overrides):
        return {
            "id": self.path.name, "path": str(self.path), "name": "Original",
            "icon": "original", "desktopName": "Original", "desktopIcon": "original",
            "customName": False, "customIcon": False, **overrides,
        }

    def items(self):
        value = self.root.property("items")
        return value.toVariant() if isinstance(value, QJSValue) else value

    def wait_until(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.app.processEvents()
            if predicate():
                return
            QTest.qWait(10)
        self.fail(f"Timed out waiting for synchronization; error: {self.root.property('errorMessage')}")

    def test_external_change_is_detected_and_stable(self):
        self.write_desktop("Updated", "new-icon")
        self.wait_until(lambda: self.items()[0]["name"] == "Updated")
        self.assertEqual(self.items()[0]["icon"], "new-icon")
        updates = self.root.property("updates")
        QTest.qWait(400)
        self.assertEqual(self.root.property("updates"), updates)

    def test_atomic_replacement_is_detected(self):
        replacement = self.path.with_suffix(".temporary")
        replacement.write_text(
            "[Desktop Entry]\nType=Application\nName=Replaced\nIcon=replaced\nExec=true\n",
            encoding="utf-8",
        )
        replacement.replace(self.path)
        self.wait_until(lambda: self.items()[0]["name"] == "Replaced")
        self.assertEqual(self.items()[0]["icon"], "replaced")

    def test_custom_values_are_preserved(self):
        self.root.setProperty("items", [
            self.item(name="My name", customName=True),
            {"type": "separator", "style": "line"},
        ])
        self.write_desktop("External name", "external-icon")
        self.wait_until(lambda: self.items()[0]["desktopName"] == "External name")
        self.assertEqual(self.items()[0]["name"], "My name")
        self.assertEqual(self.items()[0]["icon"], "external-icon")
        self.assertEqual(self.items()[1], {"type": "separator", "style": "line"})
        self.root.setProperty("items", [self.item(icon="custom-icon", customIcon=True)])
        self.wait_until(lambda: self.items()[0]["name"] == "External name")
        self.assertEqual(self.items()[0]["icon"], "custom-icon")

    def test_missing_file_keeps_values_and_recovers(self):
        original = self.items()
        self.path.unlink()
        self.wait_until(lambda: bool(self.root.property("errorMessage")))
        self.assertEqual(self.items(), original)
        failures = self.root.property("failures")
        QTest.qWait(300)
        self.assertEqual(self.root.property("failures"), failures)
        self.write_desktop("Recovered", "recovered")
        self.wait_until(lambda: self.items()[0]["name"] == "Recovered")
        self.wait_until(lambda: self.root.property("errorMessage") == "")

    def test_invalid_file_keeps_values_and_recovers(self):
        self.path.write_text("invalid desktop file\n")
        self.wait_until(lambda: bool(self.root.property("errorMessage")))
        self.assertEqual(self.items()[0]["name"], "Original")
        self.write_desktop("Fixed", "fixed")
        self.wait_until(lambda: self.items()[0]["name"] == "Fixed")
        self.wait_until(lambda: self.root.property("errorMessage") == "")

    def test_paused_editor_does_not_change_items(self):
        self.root.setProperty("paused", True)
        self.write_desktop("Updated", "updated")
        QTest.qWait(400)
        self.assertEqual(self.items()[0]["name"], "Original")
        self.root.setProperty("paused", False)
        self.wait_until(lambda: self.items()[0]["name"] == "Updated")

    def test_removed_item_is_not_resurrected_by_pending_response(self):
        self.write_desktop("Updated", "updated")
        self.root.refresh()
        self.assertTrue(self.root.property("busy"))
        self.root.setProperty("items", [{"type": "separator", "style": "spacer"}])
        self.wait_until(lambda: not self.root.property("busy"))
        self.assertEqual(self.items(), [{"type": "separator", "style": "spacer"}])

    def test_customization_during_request_is_preserved(self):
        self.write_desktop("Updated", "updated")
        self.root.refresh()
        self.root.setProperty("items", [self.item(name="During request", customName=True)])
        self.wait_until(lambda: not self.root.property("busy"))
        self.assertEqual(self.items()[0]["name"], "During request")
        self.assertEqual(self.items()[0]["icon"], "updated")


if __name__ == "__main__":
    unittest.main()
