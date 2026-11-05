import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../code/DockItems.js" as DockItems

Rectangle {
    id: root

    required property var app
    required property var iconSource
    property int iconSize: 40
    property bool showName: true
    property bool accepted: true
    readonly property bool separator: DockItems.isSeparator(app)

    implicitWidth: preview.implicitWidth + 24
    implicitHeight: preview.implicitHeight + 20
    radius: 10
    color: Kirigami.Theme.backgroundColor
    border.color: accepted ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
    border.width: 2
    opacity: accepted ? 0.96 : 0.65
    scale: visible ? 1.04 : 1
    z: 100

    RowLayout {
        id: preview
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        Item {
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize

            Kirigami.Icon {
                anchors.fill: parent
                visible: !root.separator
                source: root.iconSource
            }
            Rectangle {
                anchors.centerIn: parent
                visible: root.separator
                width: root.app && root.app.style === "line" ? 2 : parent.width * 0.75
                height: parent.height * 0.75
                radius: 2
                color: root.app && root.app.style === "line" ? Kirigami.Theme.textColor : "transparent"
                border.width: root.app && root.app.style === "spacer" ? 1 : 0
                border.color: Kirigami.Theme.textColor
            }
        }
        QQC2.Label {
            visible: root.showName
            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
            text: root.separator ? (root.app.style === "line" ? i18n("Separator bar") : i18n("Spacer"))
                : (root.app ? root.app.name : "")
            elide: Text.ElideRight
        }
    }
}
