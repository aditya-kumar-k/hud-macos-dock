import QtQuick
import QtTest
import "../package/contents/ui" as Dock
import "../package/contents/code/DockItems.js" as DockItems

TestCase {
    id: testCase
    name: "DockView"
    width: 900
    height: 900
    visible: true
    when: windowShown

    function i18n(text) { return text }

    readonly property var first: ({ id: "a.desktop", path: "/apps/a.desktop", name: "A", icon: "a" })
    readonly property var last: ({ id: "b.desktop", path: "/apps/b.desktop", name: "B", icon: "b" })
    readonly property var spacer: ({ type: "separator", style: "spacer" })
    readonly property var line: ({ type: "separator", style: "line" })
    property var view
    property var host

    Component {
        id: hostComponent
        QtObject {
            property var apps: []
            property bool vertical: false
            property int iconSize: 52
            property real zoom: 1.7
            property int gap: 10
            property real pad: 15
            property real mainLen: 500
            property real crossLen: 200
            property bool showLabels: true
            property int bounceCount: 0
            property real glassTint: 0.15
            property real glassBlur: 0
            property real glassSheen: 1
            property string dropError: ""
            property int launches: 0
            property string saved: ""

            function iconSource(icon) { return icon }
            function launchApplication(app) { launches++ }
            function reorderItems(from, to) {
                apps = DockItems.move(apps, from, to)
                saved = JSON.stringify(apps)
            }
        }
    }

    Component {
        id: dockComponent
        Dock.DockView {}
    }

    function init() {
        host = createTemporaryObject(hostComponent, testCase, { apps: [first, spacer, line, last] })
        view = createTemporaryObject(dockComponent, testCase, { host: host })
        verify(view !== null)
    }

    function test_drag_data() {
        return [
            { tag: "horizontal", vertical: false, overlay: false, from: 0, to: 3 },
            { tag: "vertical", vertical: true, overlay: false, from: 3, to: 0 },
            { tag: "popup", vertical: false, overlay: true, from: 0, to: 2 },
            { tag: "vertical popup separator", vertical: true, overlay: true, from: 2, to: 0 },
            { tag: "spacer", vertical: false, overlay: false, from: 1, to: 3 }
        ]
    }

    function test_drag(data) {
        host.vertical = data.vertical
        view.overlay = data.overlay
        waitForRendering(view)
        var source = findChild(view, "dockTile" + data.from)
        var target = findChild(view, "dockTile" + data.to)
        var destination = source.mapFromItem(target, target.width / 2, target.height / 2)
        mouseDrag(source, source.width / 2, source.height / 2,
            destination.x - source.width / 2, destination.y - source.height / 2, Qt.LeftButton)
        compare(host.apps, DockItems.move([first, spacer, line, last], data.from, data.to))
        compare(JSON.parse(host.saved), host.apps)
        compare(host.launches, 0)
    }

    function test_clickStillLaunches() {
        waitForRendering(view)
        var tile = findChild(view, "dockTile0")
        mouseClick(tile)
        compare(host.launches, 1)
        compare(host.apps, [first, spacer, line, last])
    }

    function test_separatorClickDoesNotLaunch() {
        waitForRendering(view)
        mouseClick(findChild(view, "dockTile2"))
        compare(host.launches, 0)
        compare(host.saved, "")
    }

    function test_dropOutsideCancels() {
        waitForRendering(view)
        var source = findChild(view, "dockTile0")
        mouseDrag(source, source.width / 2, source.height / 2, -200, -250, Qt.LeftButton)
        compare(host.apps, [first, spacer, line, last])
        compare(host.launches, 0)
        compare(host.saved, "")
    }

    function test_changedItemsCancelDrop() {
        waitForRendering(view)
        var content = view.contentItem
        var source = findChild(view, "dockTile0")
        var target = findChild(view, "dockTile3")
        var start = content.mapFromItem(source, source.width / 2, source.height / 2)
        var end = content.mapFromItem(target, target.width / 2, target.height / 2)
        mousePress(content, start.x, start.y)
        mouseMove(content, start.x + 30, start.y, 30)
        mouseMove(content, end.x, end.y, 30)
        host.apps = [first, spacer, line]
        mouseRelease(content, end.x, end.y)
        compare(host.apps, [first, spacer, line])
        compare(host.saved, "")
        compare(host.launches, 0)
    }

    function test_canceledGestureDoesNotSave() {
        waitForRendering(view)
        var content = view.contentItem
        var source = findChild(view, "dockTile0")
        var target = findChild(view, "dockTile3")
        var start = content.mapFromItem(source, source.width / 2, source.height / 2)
        var end = content.mapFromItem(target, target.width / 2, target.height / 2)
        mousePress(content, start.x, start.y)
        mouseMove(content, start.x + 30, start.y, 30)
        mouseMove(content, end.x, end.y, 30)
        verify(view.reordering)
        findChild(view, "dockReorder").enabled = false
        mouseRelease(content, end.x, end.y)
        compare(host.apps, [first, spacer, line, last])
        compare(host.saved, "")
        compare(host.launches, 0)
    }

    function test_feedback_data() {
        return [
            { tag: "horizontal", vertical: false, overlay: false },
            { tag: "vertical", vertical: true, overlay: false },
            { tag: "popup", vertical: false, overlay: true }
        ]
    }

    function test_feedback(data) {
        host.vertical = data.vertical
        view.overlay = data.overlay
        waitForRendering(view)
        var drag = findChild(view, "dockReorder")
        var source = findChild(view, "dockTile0")
        var target = findChild(view, "dockTile3")
        var start = drag.mapFromItem(source, source.width / 2, source.height / 2)
        var end = drag.mapFromItem(target, target.width / 2, target.height / 2)
        var oldTargetAxis = host.vertical ? target.y : target.x
        mousePress(drag, start.x, start.y)
        mouseMove(drag, start.x + (host.vertical ? 0 : 25), start.y + (host.vertical ? 25 : 0), 30)
        mouseMove(drag, end.x, end.y, 30)
        verify(view.reordering)
        var preview = findChild(view, "dockDragPreview")
        verify(preview.visible)
        verify(preview.accepted)
        compare(preview.app.id, first.id)
        fuzzyCompare(preview.x + preview.width / 2, end.x, 1)
        wait(220)
        verify((host.vertical ? target.y : target.x) < oldTargetAxis)
        compare(host.apps, [first, spacer, line, last])
        mouseMove(drag, -20, -20, 30)
        verify(!preview.accepted)
        mouseRelease(drag, -20, -20)
        compare(host.saved, "")
        verify(!preview.visible)
        tryVerify(function () {
            return Math.abs((host.vertical ? target.y : target.x) - oldTargetAxis) < 1
        })
    }
}
