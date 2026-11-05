import QtQuick
import QtTest
import "../package/contents/ui" as Dock

TestCase {
    id: testCase
    name: "WidgetDuplicator"

    function i18n(text, value) { return text.replace("%1", value) }

    property var source
    property var duplicator
    property string failure
    property string request

    function settings() {
        return {
            apps: JSON.stringify([
                { id: "a.desktop", name: "Custom name", icon: "custom-icon", path: "/apps/a.desktop",
                    desktopName: "Original", desktopIcon: "original", customName: true, customIcon: true },
                { type: "separator", style: "spacer" },
                { type: "separator", style: "line" }
            ]),
            iconSize: 64, zoom: 2.1, spacing: 16, bounceCount: 2, vertical: true,
            glassTint: 27, glassBlur: 80, glassSheen: 60, showLabels: false
        }
    }

    Component {
        id: containmentComponent
        QtObject {
            property bool immutable: false
            property int id: 12
        }
    }

    Component {
        id: sourceComponent
        QtObject {
            property bool immutable: false
            property var containment
            property var configuration
            property string pluginName: "com.aadi.huddock"
            property int id: 42
        }
    }

    Component {
        id: duplicatorComponent
        Dock.WidgetDuplicator {
            onFailed: function (message) { testCase.failure = message }
            onRequested: function (payload) { testCase.request = payload }
        }
    }

    function init() {
        failure = ""
        request = ""
        source = createTemporaryObject(sourceComponent, testCase, {
            configuration: settings(), containment: createTemporaryObject(containmentComponent, testCase)
        })
        duplicator = createTemporaryObject(duplicatorComponent, testCase, { applet: source })
        verify(duplicator !== null)
    }

    function test_copyEverythingAndKeepSnapshotIndependent() {
        verify(duplicator.available)
        duplicator.duplicate()
        compare(failure, "")
        var payload = JSON.parse(request)
        compare(payload.containmentId, 12)
        compare(payload.appletId, 42)
        compare(payload.plugin, source.pluginName)
        compare(payload.settings, settings())
        verify(duplicator.busy)
        source.configuration.iconSize = 100
        compare(payload.settings.iconSize, 64)
        duplicator.complete(0, '{"id":43}', "")
        verify(!duplicator.busy)
        compare(failure, "")
    }

    function test_pendingRequestPreventsDoubleClick() {
        duplicator.duplicate()
        var first = request
        source.configuration.iconSize = 100
        duplicator.duplicate()
        compare(request, first)
    }

    function test_lockedSourceDoesNotRequest() {
        source.immutable = true
        verify(!duplicator.available)
        duplicator.duplicate()
        verify(failure.length > 0)
        compare(request, "")
    }

    function test_lockedContainmentDoesNotRequest() {
        source.containment.immutable = true
        verify(!duplicator.available)
        duplicator.duplicate()
        verify(failure.length > 0)
        compare(request, "")
    }

    function test_noContainmentDoesNotRequest() {
        source.containment = null
        verify(!duplicator.available)
        duplicator.duplicate()
        verify(failure.length > 0)
        compare(request, "")
    }

    function test_missingSettingDoesNotRequest() {
        var config = settings()
        delete config.glassSheen
        source.configuration = config
        duplicator.duplicate()
        verify(failure.indexOf("glassSheen") >= 0)
        compare(request, "")
        verify(!duplicator.busy)
    }

    function test_badResponse_data() {
        return [
            { tag: "process failed", code: 1, out: "", err: "D-Bus unavailable" },
            { tag: "invalid json", code: 0, out: "invalid", err: "" },
            { tag: "missing id", code: 0, out: "{}", err: "" },
            { tag: "invalid id", code: 0, out: '{"id":-1}', err: "" }
        ]
    }

    function test_badResponse(data) {
        duplicator.duplicate()
        duplicator.complete(data.code, data.out, data.err)
        verify(failure.length > 0)
        verify(!duplicator.busy)
    }
}
