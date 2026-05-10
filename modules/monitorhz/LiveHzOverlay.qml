pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// Tiny per-monitor floating live refresh-rate overlay.
// Uses MonitorHz service: DRM vblank sampled live Hz, not just configured mode.
Variants {
    model: Quickshell.screens

    StyledWindow {
        id: win

        required property ShellScreen modelData
        readonly property var mon: {
            for (const m of MonitorHz.monitors) {
                if (m.name === modelData.name)
                    return m;
            }
            return null;
        }
        readonly property bool hasHz: mon && mon.liveHz !== null && mon.liveHz !== undefined

        screen: modelData
        name: "live-hz-overlay"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Empty input mask: show the overlay but pass mouse wheel/clicks through
        // to apps/Zellij underneath. Full-screen overlay otherwise eats scroll.
        mask: emptyMask

        Region {
            id: emptyMask
        }

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"

        StyledRect {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Config.bar.excludedScreens.includes(win.modelData.name)
                ? 18
                : Tokens.padding.large * 2 + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.smaller, Config.border.thickness)
            anchors.topMargin: 18

            visible: true
            opacity: 0.86
            radius: Tokens.rounding.normal
            color: Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.78)
            implicitWidth: label.implicitWidth + Tokens.padding.normal * 2
            implicitHeight: label.implicitHeight + Tokens.padding.small * 2
            width: implicitWidth
            height: implicitHeight

            StyledText {
                id: label

                anchors.centerIn: parent
                text: win.hasHz ? `${MonitorHz.fmtHz(win.mon.liveHz)} Hz` : `${win.modelData.name}\n— Hz`
                font.pointSize: Tokens.font.size.smaller
                font.family: Tokens.font.family.mono
                color: Colours.palette.m3primary
            }
        }
    }
}
