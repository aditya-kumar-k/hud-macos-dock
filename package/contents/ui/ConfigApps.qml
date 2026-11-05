import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support
import "../code/DesktopFiles.js" as DesktopFiles
import "../code/DockItems.js" as DockItems

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
    property string errorMessage: ""
    property bool scanning: false
    property bool saving: false
    property var pendingApp: null

    function reportError(message) {
        errorMessage = message
        console.warn("HUD Dock settings:", message)
    }

    function iconSource(icon) {
        if (!icon)
            return "application-x-executable"
        return icon.charAt(0) === "/" ? "file://" + icon : icon
    }

    function load() {
        try {
            var a = JSON.parse(cfg_apps)
            if (!Array.isArray(a))
                throw new Error("Expected an array of dock items")
            current = a
        } catch (e) {
            current = []
            reportError(i18n("Could not read the dock configuration: %1", String(e)))
        }
    }

    function commit(arr) {
        errorMessage = ""
        current = arr
        internalChange = true
        cfg_apps = JSON.stringify(arr)
        internalChange = false
    }

    function addApp(app) {
        if (DockItems.hasDuplicate(current, app, -1)) {
            reportError(i18n("This application is already on the dock."))
            return
        }
        errorMessage = ""
        commit(DesktopFiles.appendApps(current, [app]))
    }

    function editItem(index) {
        errorMessage = ""
        if (index >= 0 && DockItems.isSeparator(current[index])) {
            separatorDialog.editIndex = index
            separatorStyle.currentIndex = current[index].style === "line" ? 1 : 0
            separatorDialog.open()
            return
        }
        editor.editIndex = index
        var app = index >= 0 ? current[index] : null
        editor.originalApp = app
        appName.text = app ? app.name : ""
        appIcon.text = app ? app.icon : ""
        appPath.text = app ? app.path : ""
        editor.open()
    }

    function saveApp() {
        if (!appName.text.trim()) {
            reportError(i18n("Enter an application name."))
            return
        }
        var path = appPath.text.trim()
        if (path.charAt(0) !== "/" || !path.endsWith(".desktop")) {
            reportError(i18n("Enter the absolute path to a local .desktop file."))
            return
        }
        pendingApp = {
            index: editor.editIndex,
            configuration: cfg_apps,
            originalApp: editor.originalApp,
            name: appName.text.trim(),
            icon: appIcon.text.trim() || "application-x-executable"
        }
        errorMessage = ""
        saving = true
        var script = decodeURIComponent(Qt.resolvedUrl("../code/listapps.py").toString().replace(/^file:\/\//, ""))
        var url = DesktopFiles.fileUrl(path)
        validator.connectSource("python3 " + DesktopFiles.shellQuote(script)
            + " --desktop-files " + DesktopFiles.shellQuote(url) + " #edit-" + Date.now())
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
        commit(DockItems.move(current, i, j))
    }

    onCfg_appsChanged: if (!internalChange) load()
    Component.onCompleted: load()

    Plasma5Support.DataSource {
        id: lister
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            page.scanning = false
            if (data["exit code"] !== 0) {
                page.reportError(i18n("Could not list applications: %1", data["stderr"] || data["exit code"]))
                return
            }
            try {
                var apps = JSON.parse(data["stdout"])
                if (!Array.isArray(apps))
                    throw new Error("Invalid application list")
                page.allApps = apps
            } catch (e) {
                page.reportError(i18n("Could not list applications: %1", String(e)))
            }
        }
        function scan() {
            if (page.scanning)
                return
            page.scanning = true
            page.errorMessage = ""
            var script = decodeURIComponent(Qt.resolvedUrl("../code/listapps.py").toString().replace(/^file:\/\//, ""))
            connectSource("python3 " + DesktopFiles.shellQuote(script) + " #" + Date.now())
        }
    }

    Plasma5Support.DataSource {
        id: validator
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            page.saving = false
            if (data["exit code"] !== 0) {
                page.reportError(i18n("Could not read desktop file: %1", data["stderr"] || data["exit code"]))
                return
            }
            var result
            try {
                result = JSON.parse(data["stdout"])
                if (!result || !Array.isArray(result.apps) || !Array.isArray(result.errors))
                    throw new Error("Invalid desktop file importer response")
            } catch (error) {
                page.reportError(i18n("Could not read desktop file: %1", String(error)))
                return
            }
            if (result.errors.length > 0 || result.apps.length !== 1) {
                page.reportError(i18n("Could not read desktop file: %1", result.errors.join("\n")))
                return
            }
            var app = result.apps[0]
            var pending = page.pendingApp
            if (page.cfg_apps !== pending.configuration) {
                page.reportError(i18n("The dock items changed while validating. Reopen the editor and try again."))
                return
            }
            if (DockItems.hasDuplicate(page.current, app, pending.index)) {
                page.reportError(i18n("This application is already on the dock."))
                return
            }
            app = DesktopFiles.configuredApp(app, pending.name, pending.icon, pending.originalApp)
            var arr = page.current.slice()
            if (pending.index < 0)
                arr.push(app)
            else
                arr[pending.index] = app
            page.commit(arr)
            editor.close()
        }
    }

    DesktopSync {
        id: desktopSync
        objectName: "settingsDesktopSync"
        items: page.current
        paused: editor.visible || pickDialog.visible || separatorDialog.visible || page.saving || settingsDrag.dragging
        onRefreshed: function (items) { page.commit(items) }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Drag the grip at the left of a row to reorder applications and separators, or use the arrows. Edit a launcher to customize its name, icon or desktop file. Running apps are not added automatically.")
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.errorMessage.length > 0 && !editor.visible && !pickDialog.visible
            type: Kirigami.MessageType.Error
            text: page.errorMessage
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: desktopSync.errorMessage.length > 0
            type: Kirigami.MessageType.Warning
            text: desktopSync.errorMessage
        }

        RowLayout {
            Layout.fillWidth: true
            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Add application…")
                onClicked: {
                    pickDialog.selectingForEditor = false
                    search.text = ""
                    lister.scan()
                    pickDialog.open()
                }
            }
            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Add separator…")
                onClicked: {
                    separatorDialog.editIndex = -1
                    separatorStyle.currentIndex = 0
                    separatorDialog.open()
                }
            }
        }

        QQC2.Label {
            visible: page.current.length === 0
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Your dock is empty. Add an application or a separator.")
            wrapMode: Text.WordWrap
            opacity: 0.6
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: rowsColumn.implicitHeight

            ColumnLayout {
                id: rowsColumn
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    id: rows
                    model: page.current

                    delegate: Kirigami.AbstractCard {
                        id: row
                        required property int index
                        required property var modelData
                        readonly property bool separator: DockItems.isSeparator(modelData)
                        readonly property alias dragHandle: grip
                        objectName: "dockSettingsRow" + index
                        Layout.fillWidth: true
                        opacity: settingsDrag.dragging && settingsDrag.sourceIndex === index ? 0.25 : 1
                        transform: Translate {
                            y: {
                                if (!settingsDrag.dragging || settingsDrag.targetIndex < 0)
                                    return 0
                                var from = settingsDrag.sourceIndex
                                var to = settingsDrag.targetIndex
                                var source = rows.itemAt(from)
                                var target = rows.itemAt(to)
                                if (!source || !target)
                                    return 0
                                if (row.index === from)
                                    return to > from ? target.y + target.height - row.height - row.y : target.y - row.y
                                if (from < row.index && row.index <= to)
                                    return -source.height - rowsColumn.spacing
                                if (to <= row.index && row.index < from)
                                    return source.height + rowsColumn.spacing
                                return 0
                            }
                            Behavior on y {
                                enabled: settingsDrag.animating
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: Kirigami.Theme.highlightColor
                            border.width: 2
                            radius: Kirigami.Units.cornerRadius
                            visible: settingsDrag.dragging && settingsDrag.sourceIndex === row.index && settingsDrag.targetIndex >= 0
                        }

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Item {
                                id: grip
                                objectName: "dockSettingsHandle" + row.index
                                Layout.preferredWidth: Kirigami.Units.gridUnit
                                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                Accessible.name: i18n("Drag to reorder")
                                Accessible.role: Accessible.Grip

                                Grid {
                                    anchors.centerIn: parent
                                    columns: 2
                                    spacing: 3
                                    Repeater {
                                        model: 6
                                        Rectangle {
                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            color: Kirigami.Theme.textColor
                                            opacity: 0.6
                                        }
                                    }
                                }
                                QQC2.ToolTip.text: i18n("Drag to reorder")
                                QQC2.ToolTip.visible: gripHover.hovered
                                HoverHandler {
                                    id: gripHover
                                    cursorShape: settingsDrag.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                }
                            }

                            Kirigami.Icon {
                                objectName: "dockSettingsIcon" + row.index
                                source: row.separator ? (row.modelData.style === "line" ? "insert-horizontal-rule" : "distribute-horizontal-x")
                                    : page.iconSource(row.modelData.icon)
                                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: row.separator ? (row.modelData.style === "line" ? i18n("Separator bar") : i18n("Spacer")) : row.modelData.name
                                    elide: Text.ElideRight
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: row.separator ? i18n("Separates groups of applications") : row.modelData.path
                                    elide: Text.ElideMiddle
                                    opacity: 0.6
                                    font: Kirigami.Theme.smallFont
                                }
                            }
                            QQC2.ToolButton {
                                icon.name: "document-edit"
                                text: i18n("Edit")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                                onClicked: page.editItem(row.index)
                            }
                            QQC2.ToolButton {
                                icon.name: "go-up"
                                text: i18n("Move up")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                                enabled: row.index > 0
                                onClicked: page.move(row.index, -1)
                            }
                            QQC2.ToolButton {
                                icon.name: "go-down"
                                text: i18n("Move down")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                                enabled: row.index < page.current.length - 1
                                onClicked: page.move(row.index, 1)
                            }
                            QQC2.ToolButton {
                                icon.name: "edit-delete"
                                text: i18n("Remove")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                                onClicked: page.removeAt(row.index)
                            }
                        }
                    }
                }
            }

            ReorderDrag {
                id: settingsDrag
                objectName: "settingsReorder"
                anchors.fill: parent
                items: page.current
                enabled: !page.saving
                function indexAtPosition(point, starting) {
                    for (var i = 0; i < rows.count; i++) {
                        var row = rows.itemAt(i)
                        // Hit-test stable layout slots, not the animated row positions.
                        var p = rowsColumn.mapFromItem(settingsDrag, point.x, point.y)
                        var inSlot = p.x >= 0 && p.x <= row.width && p.y >= row.y && p.y <= row.y + row.height
                        var onHandle = row.dragHandle.contains(row.dragHandle.mapFromItem(settingsDrag, point.x, point.y))
                        if (inSlot && (!starting || onHandle))
                            return i
                    }
                    return -1
                }
                onMoveRequested: function (from, to) { page.commit(DockItems.move(page.current, from, to)) }
            }

            DragPreview {
                objectName: "settingsDragPreview"
                visible: settingsDrag.dragging
                app: settingsDrag.dragging ? page.current[settingsDrag.sourceIndex] : null
                iconSource: page.iconSource(app ? app.icon : "")
                accepted: settingsDrag.targetIndex >= 0
                x: settingsDrag.pointerPosition.x + 14
                y: settingsDrag.pointerPosition.y - height / 2
            }
        }
    }

    Kirigami.Dialog {
        id: pickDialog
        objectName: "applicationPicker"
        property bool selectingForEditor: false
        title: selectingForEditor ? i18n("Choose application") : i18n("Add application")
        modal: true
        standardButtons: Kirigami.Dialog.Close
        preferredWidth: Kirigami.Units.gridUnit * 28
        preferredHeight: Kirigami.Units.gridUnit * 30

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: page.errorMessage.length > 0
                type: Kirigami.MessageType.Error
                text: page.errorMessage
            }

            Kirigami.SearchField {
                id: search
                objectName: "applicationSearch"
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
            }

            QQC2.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: page.scanning
                visible: running
            }

            QQC2.Button {
                visible: !pickDialog.selectingForEditor
                text: i18n("Add from .desktop file…")
                icon.name: "document-open"
                onClicked: {
                    pickDialog.close()
                    page.editItem(-1)
                }
            }

            QQC2.Label {
                visible: !page.scanning && appList.count === 0
                text: i18n("No applications found.")
                Layout.alignment: Qt.AlignHCenter
            }

            ListView {
                id: appList
                objectName: "applicationList"
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 22
                clip: true
                model: page.allApps.filter(function (a) {
                    return a.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0
                })

                delegate: QQC2.ItemDelegate {
                    id: appDelegate
                    required property var modelData
                    readonly property bool alreadyAdded: DockItems.hasDuplicate(page.current, modelData, -1)
                    width: ListView.view.width
                    enabled: pickDialog.selectingForEditor || !alreadyAdded

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon {
                            source: page.iconSource(appDelegate.modelData.icon)
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: appDelegate.alreadyAdded ? i18n("%1 (already added)", appDelegate.modelData.name) : appDelegate.modelData.name
                            elide: Text.ElideRight
                        }
                    }
                    onClicked: {
                        if (pickDialog.selectingForEditor) {
                            editor.originalApp = DesktopFiles.configuredApp(modelData, modelData.name, modelData.icon)
                            appName.text = modelData.name
                            appIcon.text = modelData.icon
                            appPath.text = modelData.path
                            pickDialog.close()
                        } else {
                            page.addApp(modelData)
                        }
                    }
                }
            }
        }
    }

    Kirigami.Dialog {
        id: editor
        objectName: "applicationEditor"
        property int editIndex: -1
        property var originalApp: null
        title: editIndex < 0 ? i18n("Add application") : i18n("Edit application")
        modal: true
        showCloseButton: !page.saving
        closePolicy: page.saving ? QQC2.Popup.NoAutoClose : QQC2.Popup.CloseOnEscape
        preferredWidth: Kirigami.Units.gridUnit * 28
        standardButtons: Kirigami.Dialog.NoButton

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: page.errorMessage.length > 0
                type: Kirigami.MessageType.Error
                text: page.errorMessage
            }
            Kirigami.FormLayout {
                Layout.fillWidth: true
                enabled: !page.saving
                QQC2.TextField {
                    id: appName
                    objectName: "applicationName"
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                    Kirigami.FormData.label: i18n("Name:")
                }
                QQC2.TextField {
                    id: appIcon
                    objectName: "applicationIcon"
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                    Kirigami.FormData.label: i18n("Icon:")
                    placeholderText: i18n("Theme icon name or absolute image path")
                }
                QQC2.TextField {
                    id: appPath
                    objectName: "applicationPath"
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                    Kirigami.FormData.label: i18n("Desktop file:")
                    placeholderText: "/usr/share/applications/org.example.App.desktop"
                }
            }
            RowLayout {
                Kirigami.Icon {
                    source: page.iconSource(appIcon.text.trim())
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("Changes apply only to this dock. The original desktop file is not modified.")
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
            }
            QQC2.Button {
                text: i18n("Choose installed application…")
                enabled: !page.saving
                onClicked: {
                    pickDialog.selectingForEditor = true
                    search.text = ""
                    lister.scan()
                    pickDialog.open()
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                QQC2.BusyIndicator {
                    running: page.saving
                    visible: running
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                QQC2.Button {
                    text: i18n("Cancel")
                    enabled: !page.saving
                    onClicked: editor.close()
                }
                QQC2.Button {
                    objectName: "saveApplication"
                    text: i18n("Save")
                    icon.name: "document-save"
                    enabled: !page.saving
                    onClicked: page.saveApp()
                }
            }
        }
    }

    Kirigami.Dialog {
        id: separatorDialog
        objectName: "separatorEditor"
        property int editIndex: -1
        title: editIndex < 0 ? i18n("Add separator") : i18n("Edit separator")
        modal: true
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            var arr = page.current.slice()
            var separator = { type: "separator", style: separatorStyle.currentIndex === 1 ? "line" : "spacer" }
            if (editIndex < 0)
                arr.push(separator)
            else
                arr[editIndex] = separator
            page.commit(arr)
        }

        ColumnLayout {
            QQC2.ComboBox {
                id: separatorStyle
                objectName: "separatorStyle"
                Layout.fillWidth: true
                model: [i18n("Spacer"), i18n("Separator bar")]
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("A spacer leaves an empty gap. A bar draws a line between groups, like Latte Dock. The line follows the dock orientation.")
                wrapMode: Text.WordWrap
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.gridUnit * 3
                Row {
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        source: "applications-internet"
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                    }
                    Item {
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                        Rectangle {
                            anchors.centerIn: parent
                            visible: separatorStyle.currentIndex === 1
                            width: 2
                            height: parent.height * 0.8
                            color: Kirigami.Theme.textColor
                            opacity: 0.4
                        }
                    }
                    Kirigami.Icon {
                        source: "system-file-manager"
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                    }
                }
            }
        }
    }
}
