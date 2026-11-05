import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import "../code/DesktopFiles.js" as DesktopFiles

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // The shortcut pops the dock up over whatever window is open
    Plasmoid.onActivated: {
        if (overlay.visible) {
            overlay.visible = false
        } else {
            overlay.place()
            overlay.visible = true
            hideTimer.interval = 3000
            hideTimer.restart()
        }
    }

    readonly property var apps: parseApps(Plasmoid.configuration.apps)
    readonly property int iconSize: Plasmoid.configuration.iconSize
    readonly property real zoom: Plasmoid.configuration.zoom
    readonly property int gap: Plasmoid.configuration.spacing
    readonly property bool vertical: Plasmoid.configuration.vertical
    readonly property bool showLabels: Plasmoid.configuration.showLabels
    property string dropError: ""
    property int dropRequest: 0

    function reportDropError(message) {
        dropError = message
        console.warn("HUD Dock:", message)
        dropErrorTimer.restart()
    }

    function addDesktopFiles(urls) {
        if (!DesktopFiles.acceptsUrls(urls)) {
            reportDropError(i18n("Drop local .desktop files to add applications."))
            return
        }
        dropError = ""
        var scriptUrl = Qt.resolvedUrl("../code/listapps.py").toString()
        var script = decodeURIComponent(scriptUrl.replace(/^file:\/\//, ""))
        var command = "python3 " + DesktopFiles.shellQuote(script) + " --desktop-files "
            + urls.map(function (url) { return DesktopFiles.shellQuote(String(url)) }).join(" ")
        importer.connectSource(command + " #drop-" + (++dropRequest))
    }

    Plasma5Support.DataSource {
        id: importer
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            if (data["exit code"] !== 0) {
                root.reportDropError(i18n("Could not read desktop files: %1", data["stderr"] || data["exit code"]))
                return
            }
            var result
            try {
                result = JSON.parse(data["stdout"])
                if (!result || !Array.isArray(result.apps) || !Array.isArray(result.errors))
                    throw new Error("Invalid desktop file importer response")
            } catch (error) {
                root.reportDropError(i18n("Could not read desktop files: %1", String(error)))
                return
            }
            Plasmoid.configuration.apps = JSON.stringify(DesktopFiles.appendApps(root.apps, result.apps))
            if (result.errors.length > 0)
                root.reportDropError(i18n("Some desktop files could not be added:\n%1", result.errors.join("\n")))
        }
    }

    Timer {
        id: dropErrorTimer
        interval: 10000
        onTriggered: root.dropError = ""
    }

    readonly property real pad: Math.round(iconSize * 0.28)
    // Extra room along the dock for the magnified icons spreading out
    readonly property real slack: Math.ceil(iconSize * (zoom - 1) * 2.6)
    readonly property real baseLen: apps.length > 0 ? apps.length * iconSize + (apps.length - 1) * gap : iconSize
    readonly property real mainLen: Math.ceil(baseLen + 2 * pad + slack)
    // Room across the dock for the magnified icon, a launch bounce and the label
    readonly property real crossLen: Math.ceil(iconSize * zoom + 2 * pad + iconSize * 0.6 + (showLabels ? 34 : 0))

    function parseApps(json) {
        try {
            var a = JSON.parse(json)
            return Array.isArray(a) ? a : []
        } catch (e) {
            return []
        }
    }

    function iconSource(icon) {
        if (!icon)
            return "application-x-executable"
        return icon.charAt(0) === "/" ? "file://" + icon : icon
    }

    fullRepresentation: DockView {
        host: root
    }

    // Auto-hide: shortly after the pointer leaves, or if it never enters
    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: overlay.visible = false
    }

    PlasmaCore.Dialog {
        id: overlay

        // Sit exactly where the desktop dock is, in screen coordinates
        function place() {
            var view = root.fullRepresentationItem
            if (!view || !view.contentItem)
                return
            var p = view.contentItem.mapToGlobal(0, 0)
            overlay.x = Math.round(p.x)
            overlay.y = Math.round(p.y)
        }

        visible: false
        type: PlasmaCore.Dialog.Notification
        backgroundHints: PlasmaCore.Dialog.NoBackground
        location: PlasmaCore.Types.Floating

        mainItem: DockView {
            host: root
            overlay: true
            onLaunched: overlay.visible = false
            onHoveredChanged: {
                if (!overlay.visible)
                    return
                if (hovered) {
                    hideTimer.stop()
                } else {
                    hideTimer.interval = 700
                    hideTimer.restart()
                }
            }
        }
    }
}
