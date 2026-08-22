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

        readonly property bool hasHz: mon && mon.liveHz !== null && mon.liveHz !== undefined
        required property ShellScreen modelData
        readonly property var mon: {
            for (const m of MonitorHz.monitors) {
                if (m.name === modelData.name)
                    return m;
            }
            return null;
        }

        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        anchors.top: true
        color: "transparent"
        // Empty input mask: show the overlay but pass mouse wheel/clicks through
        // to apps/Zellij underneath. Full-screen overlay otherwise eats scroll.
        mask: emptyMask
        name: "live-hz-overlay"
        screen: modelData

        Region {
            id: emptyMask
        }

        StyledRect {
            anchors.left: parent.left
            anchors.leftMargin: Config.bar.excludedScreens.includes(win.modelData.name) ? 18 : Tokens.padding.large * 2 + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.extraSmall, Config.border.thickness)
            anchors.top: parent.top
            anchors.topMargin: 18
            color: Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.78)
            height: implicitHeight
            implicitHeight: label.implicitHeight + Tokens.padding.small * 2
            implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
            opacity: 0.86
            radius: Tokens.rounding.medium
            visible: true
            width: implicitWidth

            StyledText {
                id: label

                anchors.centerIn: parent
                color: Colours.palette.m3primary
                font: Tokens.font.mono.small
                text: win.hasHz ? `${MonitorHz.fmtHz(win.mon.liveHz)} Hz` : `${win.modelData.name}\n— Hz`
            }
        }
    }
}
