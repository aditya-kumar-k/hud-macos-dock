import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

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
    property string cfg_apps
    property string cfg_appsDefault: "[]"
    // Set by Plasma on every page for panel-capable widgets
    property bool cfg_expanding
    property bool cfg_expandingDefault: false
    property int cfg_length
    property int cfg_lengthDefault: 0

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Orientation:")
            model: [i18n("Horizontal"), i18n("Vertical")]
            currentIndex: page.cfg_vertical ? 1 : 0
            onActivated: page.cfg_vertical = (currentIndex === 1)
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Icon size:")
            from: 24
            to: 128
            stepSize: 2
            value: page.cfg_iconSize
            onValueModified: page.cfg_iconSize = value
            textFromValue: function (v) { return i18n("%1 px", v) }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Magnification:")
            QQC2.Slider {
                id: zoomSlider
                from: 1.0
                to: 2.5
                stepSize: 0.05
                value: page.cfg_zoom
                onMoved: page.cfg_zoom = Math.round(value * 100) / 100
            }
            QQC2.Label {
                text: page.cfg_zoom <= 1.0 ? i18n("Off") : "×" + page.cfg_zoom.toFixed(2)
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Icon spacing:")
            from: 0
            to: 40
            value: page.cfg_spacing
            onValueModified: page.cfg_spacing = value
            textFromValue: function (v) { return i18n("%1 px", v) }
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Launch bounces:")
            from: 0
            to: 10
            value: page.cfg_bounceCount
            onValueModified: page.cfg_bounceCount = value
            textFromValue: function (v) { return v === 0 ? i18n("Off") : v }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Labels:")
            text: i18n("Show app name when hovering")
            checked: page.cfg_showLabels
            onToggled: page.cfg_showLabels = checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Glass")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Tint:")
            QQC2.Slider {
                from: 0
                to: 100
                stepSize: 1
                value: page.cfg_glassTint
                onMoved: page.cfg_glassTint = Math.round(value)
            }
            QQC2.Label { text: page.cfg_glassTint + "%"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5 }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Blur:")
            QQC2.Slider {
                from: 0
                to: 100
                stepSize: 1
                value: page.cfg_glassBlur
                onMoved: page.cfg_glassBlur = Math.round(value)
            }
            QQC2.Label { text: page.cfg_glassBlur + "%"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5 }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Sheen:")
            QQC2.Slider {
                from: 0
                to: 200
                stepSize: 1
                value: page.cfg_glassSheen
                onMoved: page.cfg_glassSheen = Math.round(value)
            }
            QQC2.Label { text: page.cfg_glassSheen + "%"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5 }
        }
    }
}
