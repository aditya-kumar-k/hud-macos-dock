import QtQuick
import "../code/DesktopFiles.js" as DesktopFiles

DropArea {
    id: area

    signal filesDropped(var urls)

    onEntered: function (drag) {
        drag.accepted = DesktopFiles.acceptsUrls(drag.urls) && (drag.supportedActions & Qt.CopyAction) !== 0
    }
    onDropped: function (drop) {
        if (DesktopFiles.acceptsUrls(drop.urls) && (drop.supportedActions & Qt.CopyAction)) {
            area.filesDropped(drop.urls)
            drop.accept(Qt.CopyAction)
        } else {
            drop.accepted = false
        }
    }
}
