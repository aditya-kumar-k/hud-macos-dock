import QtQuick

QtObject {
    id: root

    required property var applet
    readonly property bool available: !!applet && !applet.immutable
        && !!applet.containment && !applet.containment.immutable
    property bool busy: false
    readonly property var configurationKeys: [
        "apps", "iconSize", "zoom", "spacing", "bounceCount", "vertical",
        "glassTint", "glassBlur", "glassSheen", "showLabels"
    ]

    signal failed(string message)
    signal requested(string payload)

    function duplicate() {
        if (busy)
            return
        if (!available) {
            failed(i18n("Could not duplicate the widget. Unlock widgets and use a dock on the desktop or a panel."))
            return
        }
        busy = true
        try {
            var settings = {}
            configurationKeys.forEach(function (key) {
                if (root.applet.configuration[key] === undefined)
                    throw new Error("Missing dock setting: " + key)
                settings[key] = root.applet.configuration[key]
            })
            requested(JSON.stringify({
                containmentId: applet.containment.id, appletId: applet.id,
                plugin: applet.pluginName, settings: settings
            }))
        } catch (error) {
            busy = false
            failed(i18n("Could not duplicate the widget: %1", String(error)))
        }
    }

    function complete(exitCode, stdout, stderr) {
        busy = false
        if (exitCode !== 0) {
            failed(i18n("Could not duplicate the widget: %1", stderr || String(exitCode)))
            return
        }
        try {
            var result = JSON.parse(stdout)
            if (!result || !Number.isInteger(result.id) || result.id <= 0)
                throw new Error("Invalid widget duplication response")
        } catch (error) {
            failed(i18n("Could not duplicate the widget: %1", String(error)))
        }
    }
}
