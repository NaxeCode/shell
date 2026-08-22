import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.components.controls
import qs.services

Item {
    implicitWidth: 640
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.large
                text: qsTr("Ambient")
            }

            Item { Layout.fillWidth: true }

            IconTextButton {
                icon: "shield"
                text: qsTr("Safe theme")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["palette", "safe-theme"])
            }

            IconTextButton {
                icon: "undo"
                text: qsTr("Previous")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["palette", "rollback"])
            }
        }

        StyledText {
            Layout.fillWidth: true
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.large
            text: Ambient.stable.scene ?? qsTr("Observing")
        }

        StyledText {
            Layout.fillWidth: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            wrapMode: Text.Wrap
            text: (Ambient.stable.reasons ?? []).join("\n")
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true

            StyledText { text: qsTr("Generation") }
            StyledText { text: Ambient.generation.id ?? "—" }
            StyledText { text: qsTr("Next proposal") }
            StyledText { text: Ambient.candidate.scene ?? "—" }
            StyledText { text: qsTr("Autonomy") }
            StyledText { text: Ambient.controls.autonomy ?? "observe" }
            StyledText { text: qsTr("Motion") }
            StyledText { text: `${Math.round(Ambient.motionIntensity * 100)}%` }
            StyledText { text: qsTr("Colour drift") }
            StyledText { text: `${Ambient.transitionMs} ms` }
        }

        RowLayout {
            Layout.fillWidth: true

            IconTextButton {
                checked: Boolean(Ambient.controls.freezeUntil)
                icon: "pause"
                text: checked ? qsTr("Frozen") : qsTr("Freeze")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["ambient", "freeze", checked ? "off" : "indefinite"])
            }

            IconTextButton {
                icon: "visibility"
                text: qsTr("Observe")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["ambient", "autonomy", "observe"])
            }

            IconTextButton {
                icon: "auto_awesome"
                text: qsTr("Suggest")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["ambient", "autonomy", "suggest"])
            }

            IconTextButton {
                icon: "play_arrow"
                text: qsTr("Automatic")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["ambient", "autonomy", "automatic"])
            }
        }
    }
}
