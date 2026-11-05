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
        var current = [first]
        compare(DesktopFiles.appendApps(current, [second, third]), [first, second, third])
        compare(current, [first])
        compare(DesktopFiles.appendApps(current, [first, second, second]), [first, second])
        compare(DesktopFiles.appendApps(current, [
            { id: first.id, name: "Copy", path: "/other/a.desktop" },
            { id: "alias.desktop", name: "Alias", path: first.path }
        ]), [first])
        compare(DesktopFiles.appendApps([], [second]), [second])
    }

    function test_shellQuote() {
        compare(DesktopFiles.shellQuote("/tmp/a b.desktop"), "'/tmp/a b.desktop'")
        compare(DesktopFiles.shellQuote("/tmp/a'b.desktop"), "'/tmp/a'\\''b.desktop'")
        compare(DesktopFiles.shellQuote("$(touch /tmp/marker); `id`"), "'$(touch /tmp/marker); `id`'")
    }
}
