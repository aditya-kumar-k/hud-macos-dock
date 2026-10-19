import QtQuick
import QtQuick.Effects
import org.kde.plasma.plasmoid

// Frosted-glass backdrop: a blurred copy of the desktop wallpaper, aligned to
// this item's position on screen and clipped to a rounded rectangle.
// Falls back to `active: false` when there is no wallpaper to sample
// (panels, plasmawindowed), so callers can draw a plain translucent card.
Item {
    id: root

    property real radius: 14
    property real blurAmount: 1.0   // 0 (sharp) .. 1 (strongest)

    readonly property var wallpaperItem: findSource(Plasmoid.containment ? Plasmoid.containment.wallpaperGraphicsObject : null)
    readonly property bool active: wallpaperItem !== null && wallpaperItem.width > 0 && wallpaperItem.height > 0

    // Extra wallpaper sampled around the card so the blur doesn't darken at the edges
    readonly property real pad: 64
    property point origin: Qt.point(0, 0)

    // The wallpaper plugin's root may be a Loader or an unsized wrapper
    function findSource(node) {
        if (!node)
            return null
        if (node.sourceComponent !== undefined && node.item !== undefined)
            return findSource(node.item)
        if (node.width > 0 && node.height > 0)
            return node
        if (node.children) {
            for (var i = 0; i < node.children.length; i++) {
                var found = findSource(node.children[i])
                if (found)
                    return found
            }
        }
        return null
    }

    function updateOrigin() {
        if (!active)
            return
        var p = root.mapToItem(wallpaperItem, 0, 0)
        root.origin = Qt.point(p.x, p.y)
    }

    onWidthChanged: updateOrigin()
    onHeightChanged: updateOrigin()
    onVisibleChanged: updateOrigin()
    onActiveChanged: updateOrigin()
    Component.onCompleted: updateOrigin()

    // Follows the widget if it is dragged to a new spot
    Timer {
        interval: 500
        repeat: true
        running: root.active && root.visible
        onTriggered: root.updateOrigin()
    }

    // The wallpaper can finish loading after the first snapshot, and can change
    // later, so re-capture a few times at start-up and then occasionally.
    Timer {
        property int ticks: 0
        interval: ticks < 10 ? 1500 : 10000
        repeat: true
        running: root.active
        onTriggered: {
            ticks++
            snapshot.scheduleUpdate()
        }
    }

    Item {
        id: wallpaperLayer
        x: -root.pad
        y: -root.pad
        width: root.width + 2 * root.pad
        height: root.height + 2 * root.pad
        clip: true
        visible: false
        layer.enabled: true

        ShaderEffectSource {
            id: snapshot
            x: root.pad - root.origin.x
            y: root.pad - root.origin.y
            width: root.active ? root.wallpaperItem.width : 0
            height: root.active ? root.wallpaperItem.height : 0
            sourceItem: root.active ? root.wallpaperItem : null
            textureSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))
            live: false
            smooth: true
            onSourceItemChanged: scheduleUpdate()
        }
    }

    Item {
        id: maskShape
        x: -root.pad
        y: -root.pad
        width: root.width + 2 * root.pad
        height: root.height + 2 * root.pad
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.pad
            radius: root.radius
        }
    }

    MultiEffect {
        x: -root.pad
        y: -root.pad
        width: root.width + 2 * root.pad
        height: root.height + 2 * root.pad
        source: wallpaperLayer
        autoPaddingEnabled: false
        blurEnabled: true
        blur: root.blurAmount
        blurMax: 64
        saturation: 0.25
        maskEnabled: true
        maskSource: maskShape
    }
}
