import QtQuick
import QtTest
import "../package/contents/code/DockItems.js" as DockItems
import "../package/contents/code/DesktopFiles.js" as DesktopFiles

TestCase {
    name: "DockItems"

    readonly property var app: { "id": "a.desktop", "name": "A", "icon": "a", "path": "/apps/a.desktop" }
    readonly property var spacer: { "type": "separator", "style": "spacer" }
    readonly property var line: { "type": "separator", "style": "line" }

    function test_legacyApps() {
        var items = [app, app, app]
        compare(DockItems.baseLength(items, 52, 10), 176)
        var layout = DockItems.computeLayout(150, 0, items, 52, 10, 1.7, 300)
        compare(layout.pos, [62, 124, 186])
        compare(layout.widths, [52, 52, 52])
        compare(layout.scales, [1, 1, 1])
        compare(layout.total, 176)
        var magnified = DockItems.computeLayout(150, 1, items, 52, 10, 1.7, 300)
        fuzzyCompare(magnified.scales[1], 1.7, 0.000001)
        fuzzyCompare(magnified.scales[0], magnified.scales[2], 0.000001)
        fuzzyCompare(magnified.pos[0], (300 - magnified.total) / 2, 0.000001)
    }

    function test_separatorsDoNotMagnify() {
        var items = [app, spacer, line, app]
        fuzzyCompare(DockItems.baseLength(items, 52, 10), 204.2, 0.000001)
        var layout = DockItems.computeLayout(140, 1, items, 52, 10, 2.5, 400)
        compare(layout.scales[1], 1)
        compare(layout.scales[2], 1)
        compare(layout.widths[1], 52)
        fuzzyCompare(layout.widths[2], 18.2, 0.000001)
        verify(layout.scales[0] > 1)
        verify(layout.scales[3] > 1)
        for (var i = 1; i < items.length; i++)
            fuzzyCompare(layout.pos[i] - layout.pos[i - 1] - layout.widths[i - 1], 10, 0.000001)
    }

    function test_hitTesting_data() {
        return [
            { tag: "no gaps", gap: 0, factor: 0 },
            { tag: "normal gaps", gap: 10, factor: 0 },
            { tag: "large gaps", gap: 40, factor: 1 }
        ]
    }

    function test_hitTesting(data) {
        var items = [app, line, spacer, app]
        var layout = DockItems.computeLayout(200, data.factor, items, 52, data.gap, 1.7, 500)
        for (var i = 0; i < items.length; i++) {
            var center = layout.pos[i] + layout.widths[i] / 2
            compare(DockItems.indexAt(center, layout, items, data.gap, true), i)
            compare(DockItems.indexAt(center, layout, items, data.gap, false),
                DockItems.isSeparator(items[i]) ? -1 : i)
        }
        compare(DockItems.indexAt(-100, layout, items, data.gap, true), -1)
        compare(DockItems.indexAt(600, layout, items, data.gap, true), -1)
    }

    function test_emptyAndOnlySeparators() {
        compare(DockItems.baseLength([], 52, 10), 0)
        var empty = DockItems.computeLayout(0, 1, [], 52, 10, 1.7, 300)
        compare(empty.total, 0)
        compare(empty.pos, [])
        compare(DockItems.indexAt(150, empty, [], 10, true), -1)
        var items = [line, spacer, line]
        var layout = DockItems.computeLayout(150, 1, items, 52, 10, 1.7, 300)
        compare(layout.scales, [1, 1, 1])
        fuzzyCompare(layout.total, DockItems.baseLength(items, 52, 10), 0.000001)
    }

    function test_duplicatesIgnoreSeparators() {
        var items = [line, app, spacer, line]
        compare(DesktopFiles.appendApps(items, [app]), items)
        var second = { id: "b.desktop", name: "B", icon: "b", path: "/apps/b.desktop" }
        compare(DesktopFiles.appendApps(items, [second]), items.concat([DesktopFiles.configuredApp(second, second.name, second.icon)]))
        verify(DockItems.hasDuplicate(items, app, -1))
        verify(!DockItems.hasDuplicate(items, app, 1))
        verify(!DockItems.hasDuplicate([line, spacer], app, -1))
        verify(DockItems.hasDuplicate(items, { id: "other.desktop", path: app.path }, -1))
        verify(DockItems.hasDuplicate(items, { id: app.id, path: "/other.desktop" }, -1))
    }

    function test_roundTrip() {
        var items = [app, spacer, line, spacer]
        compare(JSON.parse(JSON.stringify(items)), items)
    }

    function test_move() {
        var items = [app, spacer, line, spacer]
        compare(DockItems.move(items, 0, 3), [spacer, line, spacer, app])
        compare(DockItems.move(items, 3, 0), [spacer, app, spacer, line])
        compare(DockItems.move(items, -1, 0), items)
        compare(DockItems.move(items, 0, 4), items)
        compare(items, [app, spacer, line, spacer])
    }

    function test_previewPositions() {
        var layout = { pos: [20, 82, 144], widths: [52, 52, 18] }
        compare(DockItems.previewPositions(layout, 0, 2, 10), [110, 20, 82])
        compare(DockItems.previewPositions(layout, 2, 0, 10), [48, 110, 20])
        compare(DockItems.previewPositions(layout, 0, -1, 10), layout.pos)
        compare(DockItems.previewPositions({ pos: [], widths: [] }, -1, -1, 10), [])
        compare(layout.pos, [20, 82, 144])
    }
}
