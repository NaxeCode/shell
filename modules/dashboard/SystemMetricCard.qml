import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    property bool caution: false
    property string icon
    property string note
    property var rows: []
    property string title
    property string unit
    property string value: "—"

    color: Colours.tPalette.m3surfaceContainer
    implicitHeight: content.implicitHeight + Tokens.padding.medium * 2
    radius: Tokens.rounding.medium

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.margins: Tokens.padding.medium
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
                text: root.icon
            }
            StyledText {
                Layout.fillWidth: true
                font: Tokens.font.body.medium
                text: root.title
                wrapMode: Text.WordWrap
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                color: root.caution ? Colours.palette.m3error : Colours.palette.m3onSurface
                elide: Text.ElideRight
                font: Tokens.font.title.large
                text: root.value
            }
            StyledText {
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                text: root.unit
                visible: text !== ""
            }
        }
        Repeater {
            model: root.rows

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    text: modelData.label
                }
                StyledText {
                    horizontalAlignment: Text.AlignRight
                    text: modelData.value
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            color: root.caution ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            text: root.note
            visible: text !== ""
            wrapMode: Text.WordWrap
        }
    }
}
