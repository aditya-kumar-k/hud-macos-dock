import QtQuick

Item {
    id: root

    required property var items
    function indexAtPosition(point, starting) {
        return -1
    }
    property int sourceIndex: -1
    property int targetIndex: -1
    property string originalItems: ""
    readonly property bool dragging: sourceIndex >= 0
    property point pointerPosition: Qt.point(0, 0)
    property bool settling: false
    readonly property bool animating: dragging || settling

    onDraggingChanged: {
        if (!dragging) {
            settling = true
            settleTimer.restart()
        }
    }

    Timer {
        id: settleTimer
        interval: 200
        onTriggered: root.settling = false
    }

    HoverHandler {
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    containmentMask: QtObject {
        function contains(point: point): bool {
            return root.indexAtPosition(point, true) >= 0
        }
    }

    signal started()
    signal moveRequested(int from, int to)

    DragHandler {
        id: handler
        target: null
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            if (active) {
                root.pointerPosition = centroid.position
                root.originalItems = JSON.stringify(root.items)
                root.sourceIndex = root.indexAtPosition(centroid.pressPosition, true)
                root.targetIndex = root.indexAtPosition(centroid.position, false)
                if (root.sourceIndex >= 0)
                    root.started()
            }
        }
        onGrabChanged: function (transition, point) {
            if (transition === PointerDevice.UngrabExclusive) {
                var from = root.sourceIndex
                var to = root.targetIndex
                root.sourceIndex = -1
                root.targetIndex = -1
                if (root.enabled && from >= 0 && to >= 0 && from !== to
                        && root.originalItems === JSON.stringify(root.items))
                    root.moveRequested(from, to)
            }
        }
        onCentroidChanged: {
            if (handler.active && root.dragging) {
                root.pointerPosition = centroid.position
                root.targetIndex = root.indexAtPosition(centroid.position, false)
            }
        }
        onCanceled: {
            root.sourceIndex = -1
            root.targetIndex = -1
        }
    }
}
