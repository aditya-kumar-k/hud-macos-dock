import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support
import "../code/DesktopFiles.js" as DesktopFiles
import "../code/DockItems.js" as DockItems

Item {
    id: root

    required property var items
    property bool paused: false
    property int interval: 5000
    property bool busy: false
    property int request: 0
    property string errorMessage: ""
    property string requestedPaths: ""
    readonly property string paths: JSON.stringify(items.filter(function (item) {
        return !DockItems.isSeparator(item) && item.path
    }).map(function (item) { return item.path }))

    signal refreshed(var items)
    signal failed(string message)

    function reportError(message) {
        if (message !== errorMessage) {
            errorMessage = message
            console.warn("HUD Dock desktop sync:", message)
            failed(message)
        }
    }

    function refresh() {
        if (paused || busy)
            return
        var urls = JSON.parse(paths).map(DesktopFiles.fileUrl)
        if (urls.length === 0) {
            errorMessage = ""
            return
        }
        var script = decodeURIComponent(Qt.resolvedUrl("../code/listapps.py").toString().replace(/^file:\/\//, ""))
        busy = true
        requestedPaths = paths
        reader.connectSource("python3 " + DesktopFiles.shellQuote(script) + " --desktop-files "
            + urls.map(DesktopFiles.shellQuote).join(" ") + " #sync-" + (++request))
    }

    onPathsChanged: {
        errorMessage = ""
        debounce.restart()
    }
    onPausedChanged: if (!paused) debounce.restart()
    Component.onCompleted: debounce.restart()

    Timer {
        id: debounce
        interval: 250
        onTriggered: root.refresh()
    }

    Timer {
        interval: root.interval
        repeat: true
        running: !root.paused
        onTriggered: root.refresh()
    }

    Plasma5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            root.busy = false
            if (root.paths !== root.requestedPaths || root.paused) {
                debounce.restart()
                return
            }
            if (data["exit code"] !== 0) {
                root.reportError(i18n("Could not synchronize desktop files: %1", data["stderr"] || data["exit code"]))
                return
            }
            var result
            try {
                result = JSON.parse(data["stdout"])
                if (!result || !Array.isArray(result.apps) || !Array.isArray(result.errors))
                    throw new Error("Invalid desktop file importer response")
            } catch (error) {
                root.reportError(i18n("Could not synchronize desktop files: %1", String(error)))
                return
            }
            var updated = DesktopFiles.synchronize(root.items, result.apps)
            if (JSON.stringify(updated) !== JSON.stringify(root.items))
                root.refreshed(updated)
            if (result.errors.length > 0)
                root.reportError(i18n("Some desktop files could not be synchronized:\n%1", result.errors.join("\n")))
            else
                root.errorMessage = ""
        }
    }
}
