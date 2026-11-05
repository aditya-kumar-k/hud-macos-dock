import os
from pathlib import Path
import unittest

try:
    from PyQt6.QtCore import QCoreApplication, QMimeData, QPoint, QPointF, Qt, QUrl
    from PyQt6.QtGui import QDragEnterEvent, QDragLeaveEvent, QDropEvent, QGuiApplication
    from PyQt6.QtQuick import QQuickView
except ImportError:
    QQuickView = None


@unittest.skipIf(QQuickView is None, "Native drag-event tests require PyQt6")
class DesktopDropTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        cls.app = QGuiApplication.instance() or QGuiApplication([])

    def setUp(self):
        self.view = QQuickView()
        self.view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
        path = Path(__file__).resolve().parents[1] / "package/contents/ui/DesktopDropArea.qml"
        self.view.setSource(QUrl.fromLocalFile(str(path)))
        self.assertEqual(self.view.status(), QQuickView.Status.Ready)
        self.view.resize(200, 200)
        self.view.show()
        self.app.processEvents()
        self.area = self.view.rootObject()
        self.received = []
        self.area.filesDropped.connect(self.received.append)
        self.addCleanup(self.view.close)
        self.mime = QMimeData()

    def enter(self, urls, actions=Qt.DropAction.CopyAction | Qt.DropAction.MoveAction):
        self.mime.setUrls([QUrl(url) for url in urls])
        event = QDragEnterEvent(
            QPoint(100, 100), actions, self.mime,
            Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier,
        )
        QCoreApplication.sendEvent(self.view, event)
        return event

    def drop(self):
        event = QDropEvent(
            QPointF(100, 100), Qt.DropAction.CopyAction | Qt.DropAction.MoveAction,
            self.mime, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier,
        )
        event.setDropAction(Qt.DropAction.MoveAction)
        QCoreApplication.sendEvent(self.view, event)
        return event

    def test_native_file_drop_is_accepted_as_copy(self):
        urls = ["file:///tmp/first.desktop", "file:///tmp/second%20app.desktop"]
        event = self.enter(urls)
        self.assertTrue(event.isAccepted())
        self.assertTrue(self.area.property("containsDrag"))
        drop = self.drop()
        self.assertTrue(drop.isAccepted())
        self.assertEqual(drop.dropAction(), Qt.DropAction.CopyAction)
        self.assertEqual(len(self.received), 1)
        self.assertEqual([url.toString() for url in self.received[0]],
                         ["file:///tmp/first.desktop", "file:///tmp/second app.desktop"])
        self.assertFalse(self.area.property("containsDrag"))

    def test_unsupported_drops_are_rejected(self):
        for urls, actions in [
            (["file:///tmp/document.txt"], Qt.DropAction.CopyAction),
            (["https://example.com/app.desktop"], Qt.DropAction.CopyAction),
            (["file:///tmp/app.desktop"], Qt.DropAction.MoveAction),
            (["file:///tmp/app.desktop", "file:///tmp/document.txt"], Qt.DropAction.CopyAction),
        ]:
            with self.subTest(urls=urls, actions=actions):
                event = self.enter(urls, actions)
                self.assertFalse(event.isAccepted())
                self.assertFalse(self.area.property("containsDrag"))
                self.assertEqual(self.received, [])

    def test_leaving_does_not_import(self):
        self.assertTrue(self.enter(["file:///tmp/app.desktop"]).isAccepted())
        QCoreApplication.sendEvent(self.view, QDragLeaveEvent())
        self.assertFalse(self.area.property("containsDrag"))
        self.assertEqual(self.received, [])


if __name__ == "__main__":
    unittest.main()
