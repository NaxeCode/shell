pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState

    readonly property bool shouldBeActive: screenState.usage
    readonly property bool oledBlackout: !GlobalConfig.forScreen(screen.name).enabled
    readonly property real hiddenOverscan: oledBlackout ? 32 : 5
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: oledBlackout ? (shouldBeActive || offsetScale < 0.99) : offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - hiddenOverscan) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 480
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
            maximumHeight: Math.max(240, root.screen.height - 64)
        }
    }
}
