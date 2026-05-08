pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    // NaxeCode fork: gate exclusion-zone visibility on per-screen `enabled` and
    // zero-thickness borders so 1px edge surfaces do not emit degenerate layer
    // geometry on OLED-blackout / no-border screens.
    readonly property bool oledBlackout: !GlobalConfig.forScreen(root.screen.name).enabled

    ExclusionZone {
        anchors.left: true
        exclusiveZone: root.bar.exclusiveZone
    }

    ExclusionZone {
        anchors.top: true
    }

    ExclusionZone {
        anchors.right: true
    }

    ExclusionZone {
        anchors.bottom: true
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
        visible: !root.oledBlackout && contentItem.Config.border.thickness > 0
    }
}
