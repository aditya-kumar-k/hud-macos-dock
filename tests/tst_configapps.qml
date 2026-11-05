import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../package/contents/ui" as Dock
import "../package/contents/code/DesktopFiles.js" as DesktopFiles

TestCase {
    id: testCase
    name: "ConfigApps"
    width: 900
    height: 900
    visible: true
    when: windowShown

    function i18n(text) {
        for (var i = 1; i < arguments.length; i++)
            text = text.replace("%" + i, arguments[i])
        return text
    }

    readonly property var app: {
        "id": "editor.desktop", "name": "Original", "icon": "original-icon",
        "path": decodeURIComponent(Qt.resolvedUrl("fixtures/editor.desktop").toString().replace(/^file:\/\//, ""))
    }
    property var page

    Component {
        id: config
        Dock.ConfigApps {
            width: 800
            height: 800
        }
    }

    function init() {
        page = createTemporaryObject(config, testCase, { cfg_apps: JSON.stringify([app]) })
        verify(page !== null)
    }

    function test_reorderRemoveAndPersist() {
        var spacer = { type: "separator", style: "spacer" }
        var line = { type: "separator", style: "line" }
        page.commit([app, spacer, line])
        page.move(2, -1)
        compare(JSON.parse(page.cfg_apps), [app, line, spacer])
        page.removeAt(0)
        compare(JSON.parse(page.cfg_apps), [line, spacer])
        page.load()
        compare(page.current, [line, spacer])
    }

    function test_editApplicationAndValidateFile() {
        page.editItem(0)
        var editor = findChild(page, "applicationEditor")
        tryCompare(editor, "opened", true)
        findChild(page, "applicationName").text = "Custom name"
        findChild(page, "applicationIcon").text = "custom-icon"
        mouseClick(findChild(page, "saveApplication"))
        tryCompare(page, "saving", false, 10000)
        compare(page.errorMessage, "")
        compare(page.current[0].name, "Custom name")
        compare(page.current[0].icon, "custom-icon")
        compare(page.current[0].path, app.path)
        verify(page.current[0].customName)
        verify(page.current[0].customIcon)
        compare(page.current[0].desktopName, "Editor test application")
        tryCompare(editor, "visible", false)
        page.load()
        compare(page.current[0].name, "Custom name")
    }

    function test_cancelDoesNotSave() {
        page.editItem(0)
        findChild(page, "applicationName").text = "Unsaved name"
        findChild(page, "applicationEditor").close()
        compare(page.current, [app])
    }

    function test_replaceDesktopFile() {
        var path = decodeURIComponent(Qt.resolvedUrl("fixtures/alternative editor.desktop").toString().replace(/^file:\/\//, ""))
        page.editItem(0)
        findChild(page, "applicationPath").text = path
        page.saveApp()
        tryCompare(page, "saving", false, 10000)
        compare(page.errorMessage, "")
        compare(page.current.length, 1)
        compare(page.current[0].id, "alternative editor.desktop")
        compare(page.current[0].path, path)
        compare(page.current[0].name, app.name)
        compare(page.current[0].icon, app.icon)
    }

    function test_pickerSearchAndAdd() {
        var another = { id: "another.desktop", name: "Another application", icon: "app", path: "/apps/another.desktop" }
        page.allApps = [app, another]
        var picker = findChild(page, "applicationPicker")
        picker.open()
        tryCompare(picker, "opened", true)
        var list = findChild(page, "applicationList")
        list.forceLayout()
        compare(list.count, 2)
        verify(!list.itemAtIndex(0).enabled)
        findChild(page, "applicationSearch").text = "aNoThEr"
        tryCompare(list, "count", 1)
        list.forceLayout()
        mouseClick(list.itemAtIndex(0))
        compare(page.current, [app, DesktopFiles.configuredApp(another, another.name, another.icon)])
    }

    function test_pickerPopulatesEditorWithoutSaving() {
        var another = { id: "another.desktop", name: "Another application", icon: "app", path: "/apps/another.desktop" }
        page.allApps = [another]
        page.editItem(0)
        var picker = findChild(page, "applicationPicker")
        picker.selectingForEditor = true
        picker.open()
        tryCompare(picker, "opened", true)
        var list = findChild(page, "applicationList")
        list.forceLayout()
        mouseClick(list.itemAtIndex(0))
        compare(findChild(page, "applicationName").text, another.name)
        compare(findChild(page, "applicationIcon").text, another.icon)
        compare(findChild(page, "applicationPath").text, another.path)
        compare(page.current, [app])
        tryCompare(picker, "visible", false)
    }

    function test_addApplicationAlongsideSeparators() {
        page.commit([{ type: "separator", style: "line" }])
        page.editItem(-1)
        findChild(page, "applicationName").text = "New application"
        findChild(page, "applicationPath").text = app.path
        page.saveApp()
        tryCompare(page, "saving", false, 10000)
        compare(page.errorMessage, "")
        compare(page.current.length, 2)
        compare(page.current[1].name, "New application")
        compare(page.current[1].icon, "application-x-executable")
    }

    function test_defaultValuesFollowDesktopFile() {
        page.commit([])
        page.editItem(-1)
        findChild(page, "applicationName").text = "Editor test application"
        findChild(page, "applicationIcon").text = "application-x-executable"
        findChild(page, "applicationPath").text = app.path
        page.saveApp()
        tryCompare(page, "saving", false, 10000)
        compare(page.errorMessage, "")
        verify(!page.current[0].customName)
        verify(!page.current[0].customIcon)
        compare(page.current[0].desktopName, "Editor test application")
        compare(page.current[0].desktopIcon, "application-x-executable")
    }

    function test_invalidFileDoesNotSave() {
        page.editItem(0)
        findChild(page, "applicationPath").text = "/nonexistent/hud-dock-test.desktop"
        page.saveApp()
        tryCompare(page, "saving", false, 10000)
        verify(page.errorMessage.length > 0)
        compare(page.current, [app])
        verify(findChild(page, "applicationEditor").visible)
    }

    function test_duplicateDoesNotSave() {
        page.editItem(-1)
        findChild(page, "applicationName").text = "Duplicate"
        findChild(page, "applicationPath").text = app.path
        page.saveApp()
        tryCompare(page, "saving", false, 10000)
        compare(page.errorMessage, "This application is already on the dock.")
        compare(page.current, [app])
    }

    function test_editSeparator() {
        page.commit([app, { type: "separator", style: "spacer" }])
        page.editItem(1)
        var dialog = findChild(page, "separatorEditor")
        verify(dialog.visible)
        findChild(page, "separatorStyle").currentIndex = 1
        tryCompare(dialog, "opened", true)
        mouseClick(dialog.standardButton(Kirigami.Dialog.Ok))
        compare(JSON.parse(page.cfg_apps), [app, { type: "separator", style: "line" }])
        tryCompare(dialog, "visible", false)
    }

    function test_addAndCancelSeparator() {
        var dialog = findChild(page, "separatorEditor")
        dialog.editIndex = -1
        findChild(page, "separatorStyle").currentIndex = 0
        dialog.open()
        tryCompare(dialog, "opened", true)
        mouseClick(dialog.standardButton(Kirigami.Dialog.Cancel))
        compare(page.current, [app])
        tryCompare(dialog, "visible", false)
        dialog.open()
        tryCompare(dialog, "opened", true)
        mouseClick(dialog.standardButton(Kirigami.Dialog.Ok))
        compare(JSON.parse(page.cfg_apps), [app, { type: "separator", style: "spacer" }])
    }

    function test_requiredFields_data() {
        return [
            { tag: "empty name", name: "  ", path: app.path },
            { tag: "relative path", name: "App", path: "relative.desktop" },
            { tag: "not desktop", name: "App", path: "/tmp/document.txt" }
        ]
    }

    function test_requiredFields(data) {
        page.editItem(0)
        findChild(page, "applicationName").text = data.name
        findChild(page, "applicationPath").text = data.path
        page.saveApp()
        verify(!page.saving)
        verify(page.errorMessage.length > 0)
        compare(page.current, [app])
    }

    function test_changedConfigurationIsNotOverwritten() {
        page.editItem(0)
        findChild(page, "applicationName").text = "Custom name"
        page.saveApp()
        page.commit([app, { type: "separator", style: "line" }])
        tryCompare(page, "saving", false, 10000)
        compare(page.errorMessage, "The dock items changed while validating. Reopen the editor and try again.")
        compare(page.current[0].name, app.name)
        compare(page.current.length, 2)
    }

    function test_dragReordersAndPersists() {
        var spacer = { type: "separator", style: "spacer" }
        var line = { type: "separator", style: "line" }
        page.commit([app, spacer, line])
        waitForRendering(page)
        var icon = findChild(page, "dockSettingsHandle0")
        var last = findChild(page, "dockSettingsRow2")
        var destination = icon.mapFromItem(last, 24, last.height / 2)
        mouseDrag(icon, icon.width / 2, icon.height / 2,
            destination.x - icon.width / 2, destination.y - icon.height / 2, Qt.LeftButton)
        compare(JSON.parse(page.cfg_apps), [spacer, line, app])
        page.load()
        compare(page.current, [spacer, line, app])
    }

    function test_dragSeparatorUp() {
        var spacer = { type: "separator", style: "spacer" }
        page.commit([app, spacer])
        waitForRendering(page)
        var icon = findChild(page, "dockSettingsHandle1")
        var first = findChild(page, "dockSettingsRow0")
        var destination = icon.mapFromItem(first, 24, first.height / 2)
        mouseDrag(icon, icon.width / 2, icon.height / 2,
            destination.x - icon.width / 2, destination.y - icon.height / 2, Qt.LeftButton)
        compare(JSON.parse(page.cfg_apps), [spacer, app])
    }

    function test_handleAndAnimatedFeedback() {
        var spacer = { type: "separator", style: "spacer" }
        page.commit([app, spacer])
        waitForRendering(page)
        var handle = findChild(page, "dockSettingsHandle0")
        verify(handle.visible)
        compare(handle.Accessible.name, "Drag to reorder")
        var drag = findChild(page, "settingsReorder")
        var first = findChild(page, "dockSettingsRow0")
        var last = findChild(page, "dockSettingsRow1")
        var start = drag.mapFromItem(handle, handle.width / 2, handle.height / 2)
        var end = Qt.point(start.x, last.y + last.height / 2)
        mousePress(drag, start.x, start.y)
        mouseMove(drag, start.x, start.y + 25, 30)
        mouseMove(drag, end.x, end.y, 30)
        verify(drag.dragging)
        var preview = findChild(page, "settingsDragPreview")
        verify(preview.visible)
        compare(preview.app.name, app.name)
        compare(preview.accepted, true)
        fuzzyCompare(preview.x, end.x + 14, 1)
        var previousY = preview.y
        mouseMove(drag, end.x + 30, end.y + 4, 30)
        verify(preview.y !== previousY)
        wait(220)
        verify(first.transform[0].y > 0)
        verify(last.transform[0].y < 0)
        compare(page.current, [app, spacer])
        mouseRelease(drag, end.x + 30, end.y + 4)
        compare(page.current, [spacer, app])
        verify(!preview.visible)
    }
}
