import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

Item {
    id: dock

    required property var host
    // True when shown in the floating on-top window opened by the shortcut
    property bool overlay: false
    readonly property alias hovered: hover.hovered
    readonly property alias contentItem: content

    signal launched()


        readonly property bool vertical: host.vertical

        Layout.minimumWidth: vertical ? host.crossLen : host.mainLen
        Layout.minimumHeight: vertical ? host.mainLen : host.crossLen
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight
        implicitWidth: Layout.minimumWidth
        implicitHeight: Layout.minimumHeight

        Plasma5Support.DataSource {
            id: runner
            engine: "executable"
            connectedSources: []
            onNewData: function (source, data) {
                disconnectSource(source)
            }
            function run(app) {
                var path = (app.path || "").replace(/'/g, "'\\''")
                var id = (app.id || "").replace(/\.desktop$/, "").replace(/'/g, "'\\''")
                connectSource("(gio launch '" + path + "' || gtk-launch '" + id + "') #" + Date.now())
            }
        }

        function launch(index) {
            if (index < 0 || index >= host.apps.length)
                return
            runner.run(host.apps[index])
            var tile = tiles.itemAt(index)
            if (tile)
                tile.bounce()
            if (overlay)
                launched()
        }

        function removeApp(index) {
            if (index < 0 || index >= host.apps.length)
                return
            var arr = host.apps.slice()
            arr.splice(index, 1)
            Plasmoid.configuration.apps = JSON.stringify(arr)
        }

        Item {
            id: content

            width: dock.vertical ? host.crossLen : host.mainLen
            height: dock.vertical ? host.mainLen : host.crossLen
            anchors.horizontalCenter: dock.vertical ? undefined : parent.horizontalCenter
            anchors.bottom: dock.vertical ? undefined : parent.bottom
            anchors.verticalCenter: dock.vertical ? parent.verticalCenter : undefined
            anchors.left: dock.vertical ? parent.left : undefined

            readonly property real mainSize: dock.vertical ? height : width

            // Pointer position along the dock, and how strongly magnification applies (0..1)
            property real mAxis: 0
            property real factor: 0

            Behavior on mAxis {
                enabled: hover.hovered
                NumberAnimation { duration: 60 }
            }
            Behavior on factor {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            readonly property var lay: computeLayout(mAxis, factor, host.apps.length, host.iconSize, host.gap, host.zoom, mainSize)
            readonly property int hoverIdx: hover.hovered ? indexAt(mAxis, lay) : -1

            // Scale and position of every icon for a pointer at m along the dock
            function computeLayout(m, f, n, size, gap, zoom, length) {
                var scales = []
                var pos = []
                var total = Math.max(0, n - 1) * gap
                var baseLen = n * size + Math.max(0, n - 1) * gap
                var start0 = (length - baseLen) / 2
                var sigma = size * 0.85
                for (var i = 0; i < n; i++) {
                    var c = start0 + i * (size + gap) + size / 2
                    var d = m - c
                    var s = 1 + (zoom - 1) * Math.exp(-(d * d) / (2 * sigma * sigma)) * f
                    scales.push(s)
                    total += size * s
                }
                var p = (length - total) / 2
                for (var j = 0; j < n; j++) {
                    pos.push(p)
                    p += size * scales[j] + gap
                }
                return { scales: scales, pos: pos, total: total }
            }

            function indexAt(m, layout) {
                var best = -1
                var bestDist = 1e9
                for (var i = 0; i < layout.pos.length; i++) {
                    var s = host.iconSize * layout.scales[i]
                    var d = Math.abs(m - (layout.pos[i] + s / 2))
                    if (d < bestDist && d <= s / 2 + host.gap / 2) {
                        bestDist = d
                        best = i
                    }
                }
                return best
            }

            HoverHandler {
                id: hover
                onPointChanged: content.mAxis = dock.vertical ? point.position.y : point.position.x
                onHoveredChanged: content.factor = hovered ? 1 : 0
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: function (eventPoint) {
                    var m = dock.vertical ? eventPoint.position.y : eventPoint.position.x
                    dock.launch(content.indexAt(m, content.lay))
                }
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: function (eventPoint) {
                    var m = dock.vertical ? eventPoint.position.y : eventPoint.position.x
                    itemMenu.target = content.indexAt(m, content.lay)
                    itemMenu.popup()
                }
            }

            // Frosted glass shelf behind the icons
            GlassCard {
                id: card
                z: 0
                useBlur: !dock.overlay
                tint: Plasmoid.configuration.glassTint / 100
                blurAmount: Plasmoid.configuration.glassBlur / 100
                sheen: Plasmoid.configuration.glassSheen / 100
                radius: Math.round(host.iconSize * 0.4)
                width: dock.vertical ? host.iconSize + 2 * host.pad : content.lay.total + 2 * host.pad
                height: dock.vertical ? content.lay.total + 2 * host.pad : host.iconSize + 2 * host.pad
                x: dock.vertical ? 0 : (content.width - width) / 2
                y: dock.vertical ? (content.height - height) / 2 : content.height - height
            }

            Text {
                visible: host.apps.length === 0
                z: 1
                anchors.centerIn: card
                text: i18n("Right-click → Configure to add apps")
                color: "#e8eef3"
                font.pixelSize: 13
            }

            Repeater {
                id: tiles
                model: host.apps.length

                delegate: Item {
                    id: tile

                    required property int index
                    readonly property var app: host.apps[index]
                    readonly property real s: host.iconSize * (content.lay.scales[index] !== undefined ? content.lay.scales[index] : 1)
                    property real bounceOff: 0

                    z: 2
                    width: s
                    height: s
                    x: dock.vertical ? host.pad + bounceOff : (content.lay.pos[index] || 0)
                    y: dock.vertical ? (content.lay.pos[index] || 0) : content.height - host.pad - s - bounceOff

                    function bounce() {
                        if (Plasmoid.configuration.bounceCount > 0)
                            bounceAnim.restart()
                    }

                    Kirigami.Icon {
                        anchors.fill: parent
                        source: host.iconSource(tile.app ? tile.app.icon : "")
                        roundToIconSize: false
                        smooth: true
                    }

                    SequentialAnimation {
                        id: bounceAnim
                        loops: Math.max(1, Plasmoid.configuration.bounceCount)
                        NumberAnimation {
                            target: tile
                            property: "bounceOff"
                            to: host.iconSize * 0.5
                            duration: 240
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: tile
                            property: "bounceOff"
                            to: 0
                            duration: 300
                            easing.type: Easing.OutBounce
                        }
                    }
                }
            }

            // App name above (or beside) the hovered icon
            Rectangle {
                id: label
                z: 3
                readonly property int idx: content.hoverIdx
                readonly property real itemSize: idx >= 0 ? host.iconSize * content.lay.scales[idx] : 0
                readonly property real itemPos: idx >= 0 ? content.lay.pos[idx] : 0

                visible: host.showLabels && idx >= 0 && content.factor > 0.3
                width: labelText.implicitWidth + 20
                height: labelText.implicitHeight + 10
                radius: 8
                color: Qt.rgba(0.04, 0.07, 0.10, 0.85)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.2)

                x: dock.vertical
                    ? host.pad + itemSize + 10
                    : Math.max(0, Math.min(content.width - width, itemPos + itemSize / 2 - width / 2))
                y: dock.vertical
                    ? Math.max(0, Math.min(content.height - height, itemPos + itemSize / 2 - height / 2))
                    : content.height - host.pad - itemSize - height - 8

                Text {
                    id: labelText
                    anchors.centerIn: parent
                    text: label.idx >= 0 && host.apps[label.idx] ? host.apps[label.idx].name : ""
                    color: "#f1f6fa"
                    font.pixelSize: 13
                }
            }

            Controls.Menu {
                id: itemMenu
                property int target: -1

                Controls.MenuItem {
                    text: i18n("Open")
                    enabled: itemMenu.target >= 0
                    onTriggered: dock.launch(itemMenu.target)
                }
                Controls.MenuItem {
                    text: i18n("Remove from dock")
                    enabled: itemMenu.target >= 0
                    onTriggered: dock.removeApp(itemMenu.target)
                }
                Controls.MenuSeparator {}
                Controls.MenuItem {
                    text: i18n("Dock settings…")
                    onTriggered: Plasmoid.internalAction("configure").trigger()
                }
            }
        }
}
