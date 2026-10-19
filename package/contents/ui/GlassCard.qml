import QtQuick

// Frosted-glass card: blurred wallpaper + translucent tint + top-lit sheen + rim.
Item {
    id: card

    property real radius: 14
    property real tint: 0.15        // 0 (clear) .. 1 (opaque)
    property real blurAmount: 1.0   // 0 .. 1
    property real sheen: 1.0        // strength of the white top-lit gradient
    // Off in the on-top overlay, where there is no wallpaper behind to blur
    property bool useBlur: true

    readonly property bool blurred: useBlur && glass.active

    GlassBlur {
        id: glass
        anchors.fill: parent
        radius: card.radius
        blurAmount: card.blurAmount
        visible: card.useBlur
    }

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: Qt.rgba(0.04, 0.07, 0.10, card.blurred ? card.tint : 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16 * card.sheen) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.06 * card.sheen) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.04 * card.sheen) }
            }
        }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 1
            anchors.leftMargin: card.radius
            anchors.rightMargin: card.radius
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.45 * card.sheen) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
