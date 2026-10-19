import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: page

    property string cfg_apps
    property string cfg_appsDefault: "[]"
    property int cfg_iconSize
    property int cfg_iconSizeDefault: 52
    property real cfg_zoom
    property real cfg_zoomDefault: 1.7
    property int cfg_spacing
    property int cfg_spacingDefault: 10
    property int cfg_bounceCount
    property int cfg_bounceCountDefault: 3
    property bool cfg_vertical
    property bool cfg_verticalDefault: false
    property bool cfg_showLabels
    property bool cfg_showLabelsDefault: true
    property int cfg_glassTint
    property int cfg_glassTintDefault: 15
    property int cfg_glassBlur
    property int cfg_glassBlurDefault: 100
    property int cfg_glassSheen
    property int cfg_glassSheenDefault: 100
    // Set by Plasma on every page for panel-capable widgets
    property bool cfg_expanding
    property bool cfg_expandingDefault: false
    property int cfg_length
    property int cfg_lengthDefault: 0

    property var current: []
    property bool internalChange: false
    property var allApps: []

    function iconSource(icon) {
        if (!icon)
            return "application-x-executable"
        return icon.charAt(0) === "/" ? "file://" + icon : icon
    }

    function load() {
        try {
            var a = JSON.parse(cfg_apps)
            current = Array.isArray(a) ? a : []
        } catch (e) {
            current = []
        }
    }

    function commit(arr) {
        current = arr
        internalChange = true
        cfg_apps = JSON.stringify(arr)
        internalChange = false
    }

    function addApp(app) {
        for (var i = 0; i < current.length; i++) {
            if (current[i].id === app.id)
                return
        }
        var arr = current.slice()
        arr.push({ id: app.id, name: app.name, icon: app.icon, path: app.path })
        commit(arr)
    }

    function removeAt(i) {
        var arr = current.slice()
        arr.splice(i, 1)
        commit(arr)
    }

    function move(i, delta) {
        var j = i + delta
        if (j < 0 || j >= current.length)
            return
        var arr = current.slice()
        var tmp = arr[i]
        arr[i] = arr[j]
        arr[j] = tmp
        commit(arr)
    }

    onCfg_appsChanged: if (!internalChange) load()
    Component.onCompleted: load()

    Plasma5Support.DataSource {
        id: lister
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            try {
                page.allApps = JSON.parse(data["stdout"])
            } catch (e) {
                page.allApps = []
            }
        }
        function scan() {
            var script = Qt.resolvedUrl("../code/listapps.py").toString().replace("file://", "")
            connectSource("python3 '" + script + "' #" + Date.now())
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Apps shown on the dock, in order. Only these appear, running apps are not added.")
                wrapMode: Text.WordWrap
                opacity: 0.7
            }
            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Add application…")
                onClicked: {
                    lister.scan()
                    pickDialog.open()
                }
            }
        }

        QQC2.Label {
            visible: page.current.length === 0
            Layout.alignment: Qt.AlignHCenter
            text: i18n("No apps yet. Click \"Add application…\".")
            opacity: 0.6
        }

        Repeater {
            model: page.current

            delegate: Kirigami.AbstractCard {
                id: row
                required property int index
                required property var modelData
                Layout.fillWidth: true

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: page.iconSource(row.modelData.icon)
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                    }
                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: row.index > 0
                        onClicked: page.move(row.index, -1)
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: row.index < page.current.length - 1
                        onClicked: page.move(row.index, 1)
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        onClicked: page.removeAt(row.index)
                    }
                }
            }
        }
    }

    Kirigami.Dialog {
        id: pickDialog
        title: i18n("Add application")
        standardButtons: Kirigami.Dialog.Close
        preferredWidth: Kirigami.Units.gridUnit * 28
        preferredHeight: Kirigami.Units.gridUnit * 30

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.SearchField {
                id: search
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 22
                clip: true
                model: page.allApps.filter(function (a) {
                    return a.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0
                })

                delegate: QQC2.ItemDelegate {
                    id: appDelegate
                    required property var modelData
                    width: ListView.view.width

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon {
                            source: page.iconSource(appDelegate.modelData.icon)
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: appDelegate.modelData.name
                            elide: Text.ElideRight
                        }
                    }
                    onClicked: page.addApp(appDelegate.modelData)
                }
            }
        }
    }
}
