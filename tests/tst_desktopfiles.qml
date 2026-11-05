import QtQuick
import QtTest
import "../package/contents/code/DesktopFiles.js" as DesktopFiles

TestCase {
    name: "DesktopFiles"

    function test_acceptsUrls_data() {
        return [
            { tag: "empty", urls: [], accepted: false },
            { tag: "single", urls: ["file:///tmp/app.desktop"], accepted: true },
            { tag: "multiple", urls: ["file:///tmp/a.desktop", "file:///tmp/b.desktop"], accepted: true },
            { tag: "encoded", urls: ["file:///tmp/a%20%23%C3%A7.desktop"], accepted: true },
            { tag: "localhost", urls: ["file://localhost/tmp/a.desktop"], accepted: true },
            { tag: "remote host", urls: ["file://server/tmp/a.desktop"], accepted: false },
            { tag: "remote URL", urls: ["https://example.com/a.desktop"], accepted: false },
            { tag: "mixed", urls: ["file:///tmp/a.desktop", "file:///tmp/a.txt"], accepted: false },
            { tag: "query", urls: ["file:///tmp/a.desktop?query"], accepted: false },
            { tag: "fragment", urls: ["file:///tmp/a.desktop#fragment"], accepted: false },
            { tag: "directory", urls: ["file:///tmp/a.desktop/"], accepted: false }
        ]
    }

    function test_acceptsUrls(data) {
        compare(DesktopFiles.acceptsUrls(data.urls), data.accepted)
    }

    function test_appendApps() {
        var first = { id: "a.desktop", name: "A", icon: "a", path: "/apps/a.desktop" }
        var second = { id: "b.desktop", name: "B", icon: "b", path: "/apps/b.desktop" }
        var third = { id: "c.desktop", name: "C", icon: "c", path: "/apps/c.desktop" }
        var trackedSecond = DesktopFiles.configuredApp(second, second.name, second.icon)
        var trackedThird = DesktopFiles.configuredApp(third, third.name, third.icon)
        var current = [first]
        compare(DesktopFiles.appendApps(current, [second, third]), [first, trackedSecond, trackedThird])
        compare(current, [first])
        compare(DesktopFiles.appendApps(current, [first, second, second]), [first, trackedSecond])
        compare(DesktopFiles.appendApps(current, [
            { id: first.id, name: "Copy", path: "/other/a.desktop" },
            { id: "alias.desktop", name: "Alias", path: first.path }
        ]), [first])
        compare(DesktopFiles.appendApps([], [second]), [trackedSecond])
    }

    function test_synchronize() {
        var original = { id: "a.desktop", path: "/apps/a.desktop", name: "Original", icon: "original" }
        var updated = { id: original.id, path: original.path, name: "Updated", icon: "updated" }
        var tracked = DesktopFiles.configuredApp(original, original.name, original.icon)
        var synced = DesktopFiles.synchronize([tracked], [updated])[0]
        compare(synced.name, "Updated")
        compare(synced.icon, "updated")
        compare(synced.desktopName, "Updated")
        compare(synced.desktopIcon, "updated")
        verify(!synced.customName)
        verify(!synced.customIcon)
        compare(tracked.name, "Original")

        var custom = DesktopFiles.configuredApp(original, "My name", original.icon)
        synced = DesktopFiles.synchronize([custom], [updated])[0]
        compare(synced.name, "My name")
        compare(synced.icon, "updated")
        verify(synced.customName)
        verify(!synced.customIcon)

        custom = DesktopFiles.configuredApp(original, original.name, "my-icon")
        synced = DesktopFiles.synchronize([custom], [updated])[0]
        compare(synced.name, "Updated")
        compare(synced.icon, "my-icon")
    }

    function test_editorSavingUnchangedFieldsKeepsSyncIntent() {
        var old = { id: "a.desktop", path: "/apps/a.desktop", name: "Original", icon: "original" }
        var latest = { id: old.id, path: old.path, name: "Changed while editing", icon: "changed" }
        var original = DesktopFiles.configuredApp(old, old.name, old.icon)
        var saved = DesktopFiles.configuredApp(latest, old.name, "my-icon", original)
        compare(saved.name, latest.name)
        verify(!saved.customName)
        compare(saved.icon, "my-icon")
        verify(saved.customIcon)

        original = DesktopFiles.configuredApp(old, "Custom", old.icon)
        latest.name = "Custom"
        saved = DesktopFiles.configuredApp(latest, "Custom", old.icon, original)
        verify(saved.customName)
        compare(saved.icon, latest.icon)
        verify(!saved.customIcon)
    }

    function test_syncKeepsOrderAndMissingEntries() {
        var app = { id: "a.desktop", path: "/apps/a.desktop", name: "A", icon: "a" }
        var separator = { type: "separator", style: "line" }
        var missing = { id: "missing.desktop", path: "/missing.desktop", name: "Missing", icon: "missing" }
        var tracked = DesktopFiles.configuredApp(app, app.name, app.icon)
        var items = [separator, missing, tracked]
        var updated = Object.assign({}, app, { name: "New" })
        var result = DesktopFiles.synchronize(items, [updated])
        compare(result[0], separator)
        compare(result[1], missing)
        compare(result[2].name, "New")
        compare(DesktopFiles.synchronize([], [updated]), [])
        compare(DesktopFiles.synchronize(result, [updated]), result)
    }

    function test_legacyMigration() {
        var desktop = { id: "a.desktop", path: "/apps/a.desktop", name: "A", icon: "a" }
        var matching = DesktopFiles.synchronize([desktop], [desktop])[0]
        verify(!matching.customName)
        verify(!matching.customIcon)
        var different = Object.assign({}, desktop, { name: "Custom", icon: "custom" })
        var migrated = DesktopFiles.synchronize([different], [desktop])[0]
        verify(migrated.customName)
        verify(migrated.customIcon)
        compare(migrated.name, "Custom")
        compare(migrated.icon, "custom")
    }

    function test_shellQuote() {
        compare(DesktopFiles.shellQuote("/tmp/a b.desktop"), "'/tmp/a b.desktop'")
        compare(DesktopFiles.shellQuote("/tmp/a'b.desktop"), "'/tmp/a'\\''b.desktop'")
        compare(DesktopFiles.shellQuote("$(touch /tmp/marker); `id`"), "'$(touch /tmp/marker); `id`'")
    }
}
