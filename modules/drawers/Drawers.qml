pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// NaxeCode fork: iterate ALL screens, including those with per-monitor `enabled:false`.
// This preserves drawer instantiation (so launcher renders on the focused screen even
// if it's marked OLED-blackout). ContentWindow then suppresses persistent paint when
// the screen is marked disabled.
Variants {
    model: Quickshell.screens

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
