import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// One bounded dashboard page; extra readings scroll rather than grow off-screen.
Item {
    id: root

    property real availableHeight: 650
    property real availableWidth: 760
    property int page: 0
    property bool polling: true

    implicitHeight: Math.min(650, availableHeight)
    implicitWidth: Math.min(760, availableWidth)

    Component.onCompleted: SysControl.subscribe(root)
    Component.onDestruction: SysControl.unsubscribe(root)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.medium

        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 580 ? 2 : 1
            rowSpacing: Tokens.spacing.small

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    font: Tokens.font.title.large
                    text: qsTr("PC & room")
                }
                StyledText {
                    Layout.fillWidth: true
                    color: SysControl.error || SysControl.stale ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    text: SysControl.error || (!SysControl.ready ? qsTr("Getting readings…") : SysControl.stale ? qsTr("Last reading · waiting for update") : qsTr("Live · refreshes every 2 seconds"))
                    wrapMode: Text.WordWrap
                }
            }
            RowLayout {
                spacing: Tokens.spacing.small

                IconTextButton {
                    checked: root.page === 0
                    icon: "thermostat"
                    text: qsTr("Power & room")
                    type: checked ? IconTextButton.Filled : IconTextButton.Tonal

                    onClicked: {
                        root.page = 0;
                        scroll.contentY = 0;
                    }
                }
                IconTextButton {
                    checked: root.page === 1
                    icon: "desktop_windows"
                    text: qsTr("Displays")
                    type: checked ? IconTextButton.Filled : IconTextButton.Tonal

                    onClicked: {
                        root.page = 1;
                        scroll.contentY = 0;
                    }
                }
            }
        }
        Flickable {
            id: scroll

            Layout.fillHeight: true
            Layout.fillWidth: true
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: pageLoader.height
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick
            objectName: "systemScroll"

            QQC.ScrollBar.vertical: StyledScrollBar {
                flickable: scroll
            }

            Loader {
                id: pageLoader

                height: item?.implicitHeight ?? 0
                sourceComponent: root.page === 0 ? overview : displays
                width: scroll.width - (scroll.contentHeight > scroll.height ? Tokens.padding.medium : 0)
            }
        }
    }
    Component {
        id: overview

        SystemOverview {
        }
    }
    Component {
        id: displays

        SystemDisplays {
        }
    }
}
