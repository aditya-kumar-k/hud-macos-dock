import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../code/DockItems.js" as DockItems

Item {
    id: dock

    required property var host
    // True when shown in the floating on-top window opened by the shortcut
    property bool overlay: false
    readonly property bool hovered: hover.hovered || dropArea.containsDrag || reorder.dragging
    readonly property alias contentItem: content
    readonly property bool reordering: reorder.dragging

    signal launched()


        readonly property bool vertical: host.vertical

        Layout.minimumWidth: vertical ? host.crossLen : host.mainLen
        Layout.minimumHeight: vertical ? host.mainLen : host.crossLen
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight
        implicitWidth: Layout.minimumWidth
        implicitHeight: Layout.minimumHeight

        function launch(index) {
            if (index < 0 || index >= host.apps.length || DockItems.isSeparator(host.apps[index]))
                return
            host.launchApplication(host.apps[index])
            var tile = tiles.itemAt(index)
            if (tile)
                tile.bounce()
            if (overlay)
                launched()
        }

        function removeApp(index) {
            if (index < 0 || index >= host.apps.length)
                return
            host.removeItem(index)
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

            DesktopDropArea {
                id: dropArea
                anchors.fill: parent
                onFilesDropped: function (urls) { dock.host.addDesktopFiles(urls) }
            }

            Controls.ToolTip {
                visible: host.dropError.length > 0
                text: host.dropError
                width: Math.min(420, implicitWidth)
            }

            // Pointer position along the dock, and how strongly magnification applies (0..1)
            property real mAxis: 0
            property real factor: 0
            property var frozenLayout: null

            Behavior on mAxis {
                enabled: hover.hovered
                NumberAnimation { duration: 60 }
            }
            Behavior on factor {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            readonly property var lay: reorder.dragging && frozenLayout ? frozenLayout
                : DockItems.computeLayout(mAxis, factor, host.apps, host.iconSize, host.gap, host.zoom, mainSize)
            readonly property int hoverIdx: hover.hovered ? indexAt(mAxis, lay) : -1
            readonly property var previewPositions: DockItems.previewPositions(lay,
                reorder.dragging ? reorder.sourceIndex : -1, reorder.targetIndex, host.gap)

            function indexAt(m, layout, includeSeparators) {
                return DockItems.indexAt(m, layout, host.apps, host.gap, includeSeparators)
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

            ReorderDrag {
                id: reorder
                objectName: "dockReorder"
                anchors.fill: parent
                items: dock.host.apps
                function indexAtPosition(point, starting) {
                    var axis = dock.vertical ? point.y : point.x
                    var index = content.indexAt(axis, content.lay, true)
                    if (index < 0 || !content.contains(point))
                        return -1
                    if (starting) {
                        var tile = tiles.itemAt(index)
                        if (!tile || !tile.contains(tile.mapFromItem(reorder, point.x, point.y)))
                            return -1
                    }
                    return index
                }
                onStarted: content.frozenLayout = content.lay
                onDraggingChanged: if (!dragging) content.frozenLayout = null
                onMoveRequested: function (from, to) {
                    dock.host.reorderItems(from, to)
                }
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: function (eventPoint) {
                    var m = dock.vertical ? eventPoint.position.y : eventPoint.position.x
                    itemMenu.target = content.indexAt(m, content.lay, true)
                    itemMenu.popup()
                }
            }

            // Frosted glass shelf behind the icons
            GlassCard {
                id: card
                z: 0
                useBlur: !dock.overlay
                tint: host.glassTint
                blurAmount: host.glassBlur
                sheen: host.glassSheen
                radius: Math.round(host.iconSize * 0.4)
                width: dock.vertical ? host.iconSize + 2 * host.pad : content.lay.total + 2 * host.pad
                height: dock.vertical ? content.lay.total + 2 * host.pad : host.iconSize + 2 * host.pad
                x: dock.vertical ? 0 : (content.width - width) / 2
                y: dock.vertical ? (content.height - height) / 2 : content.height - height
            }

            Rectangle {
                anchors.fill: card
                z: 1
                visible: dropArea.containsDrag
                radius: card.radius
                color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 2
                border.color: Kirigami.Theme.highlightColor
            }

            Text {
                visible: host.apps.length === 0
                z: 1
                anchors.centerIn: card
                width: content.width - 2 * host.pad
                text: i18n("Drop .desktop files here or right-click → Configure")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#e8eef3"
                font.pixelSize: 13
            }

            DragPreview {
                objectName: "dockDragPreview"
                visible: reorder.dragging
                app: reorder.dragging ? dock.host.apps[reorder.sourceIndex] : null
                iconSource: dock.host.iconSource(app ? app.icon : "")
                iconSize: dock.host.iconSize
                showName: false
                accepted: reorder.targetIndex >= 0
                x: reorder.pointerPosition.x - width / 2
                y: reorder.pointerPosition.y - height / 2 - 12
            }

            Repeater {
                id: tiles
                model: host.apps.length

                delegate: Item {
                    id: tile

                    required property int index
                    objectName: "dockTile" + index
                    readonly property var app: host.apps[index]
                    readonly property bool separator: DockItems.isSeparator(app)
                    readonly property real s: host.iconSize * (content.lay.scales[index] !== undefined ? content.lay.scales[index] : 1)
                    readonly property real mainSize: content.lay.widths[index] || 0
                    property real bounceOff: 0
                    opacity: reorder.dragging && reorder.sourceIndex === index ? 0.2 : 1

                    z: 2
                    width: dock.vertical ? s : mainSize
                    height: dock.vertical ? mainSize : s
                    x: dock.vertical ? host.pad + bounceOff : (content.previewPositions[index] || 0)
                    y: dock.vertical ? (content.previewPositions[index] || 0) : content.height - host.pad - s - bounceOff

                    Behavior on x {
                        enabled: reorder.animating
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: reorder.animating
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    function bounce() {
                        if (host.bounceCount > 0)
                            bounceAnim.restart()
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: reorder.dragging && reorder.sourceIndex === tile.index && reorder.targetIndex >= 0
                        color: Qt.rgba(1, 1, 1, 0.12)
                        border.color: Kirigami.Theme.highlightColor
                        border.width: 2
                        radius: 4
                    }

                    Kirigami.Icon {
                        visible: !tile.separator
                        anchors.fill: parent
                        source: host.iconSource(tile.app ? tile.app.icon : "")
                        roundToIconSize: false
                        smooth: true
                    }

                    Rectangle {
                        visible: tile.separator && tile.app.style === "line"
                        anchors.centerIn: parent
                        width: dock.vertical ? host.iconSize * 0.65 : 2
                        height: dock.vertical ? 2 : host.iconSize * 0.65
                        radius: 1
                        color: "#e8eef3"
                        opacity: 0.4
                    }

                    SequentialAnimation {
                        id: bounceAnim
                        loops: Math.max(1, host.bounceCount)
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

                visible: host.showLabels && idx >= 0 && content.factor > 0.3 && !reorder.dragging
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
                    enabled: itemMenu.target >= 0 && !DockItems.isSeparator(host.apps[itemMenu.target])
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
                    onTriggered: dock.host.configureDock()
                }
            }
        }
}
