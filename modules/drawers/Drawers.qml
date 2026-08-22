pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Internal
import qs.services

// NaxeCode fork: iterate ALL screens, including those with per-monitor `enabled:false`.
// This preserves drawer instantiation (so launcher renders on the focused screen even
// if it's marked OLED-blackout). Rebuild the screen scopes after output topology
// changes so suspend/resume cannot leave a drawer window attached to a stale screen.
Variants {
    id: root

    property list<var> screenModel: []
    property bool sleeping
    readonly property Timer rebuildTimer: Timer {
        interval: 500
        onTriggered: root.screenModel = Quickshell.screens.slice()
    }

    function rebuildScreens(): void {
        screenModel = [];
        root.rebuildTimer.restart();
    }

    model: screenModel
    Component.onCompleted: root.rebuildScreens()

    Connections {
        function onScreensChanged(): void {
            if (!root.sleeping)
                root.rebuildScreens();
        }

        target: Quickshell
    }

    LogindManager {
        onAboutToSleep: {
            root.sleeping = true;
            root.rebuildTimer.stop();
            root.screenModel = [];
        }
        onResumed: {
            root.sleeping = false;
            root.rebuildTimer.restart();
        }
    }

    Scope {
        id: scope

        required property ShellScreen modelData

        Exclusions {
            screen: scope.modelData
            bar: content.bar
        }

        ContentWindow {
            id: content

            screen: scope.modelData
        }
    }
}
