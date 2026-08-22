pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// NaxeCode fork: keep drawers available on OLED-blackout outputs even when
// their persistent shell chrome is disabled.
Variants {
    id: root

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
