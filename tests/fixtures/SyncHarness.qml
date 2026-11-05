import QtQuick
import "../../package/contents/ui" as Dock

Item {
    id: root
    property var items: []
    property alias busy: sync.busy
    property alias paused: sync.paused
    property alias errorMessage: sync.errorMessage
    property int updates: 0
    property int failures: 0

    function i18n(text, value) { return text.replace("%1", value) }
    function refresh() { sync.refresh() }

    Dock.DesktopSync {
        id: sync
        items: root.items
        interval: 100
        onRefreshed: function (items) {
            root.items = items
            root.updates++
        }
        onFailed: root.failures++
    }
}
