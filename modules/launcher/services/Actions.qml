pragma Singleton

import ".."
import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property list<string> normalLauncherActions: ["Shutdown", "Reboot", "Logout", "Lock", "Sleep"]

    function normalSearch(search: string): list<var> {
        const query = search.trim().toLowerCase();
        if (!query)
            return [];

        return allVariants.instances.filter(a => normalLauncherActions.includes(a.name) && (`${a.name} ${a.desc}`.toLowerCase().includes(query)));
    }

    function transformSearch(search: string): string {
        return search.slice(GlobalConfig.launcher.actionPrefix.length);
    }

    list: variants.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.actions

    Variants {
        id: variants

        model: GlobalConfig.launcher.actions.filter(a => (a.enabled ?? true) && (GlobalConfig.launcher.enableDangerousActions || !(a.dangerous ?? false)))

        Action {
        }
    }

    Variants {
        id: allVariants

        model: GlobalConfig.launcher.actions.filter(a => a.enabled ?? true)

        Action {
        }
    }

    component Action: QtObject {
        readonly property list<string> command: modelData.command ?? []
        readonly property bool dangerous: modelData.dangerous ?? false
        readonly property string desc: modelData.description ?? qsTr("No description")
        readonly property bool enabled: modelData.enabled ?? true
        readonly property string icon: modelData.icon ?? "help_outline"
        readonly property string launcherType: "action"
        required property var modelData
        readonly property string name: modelData.name ?? qsTr("Unnamed")

        function onClicked(list: AppList): void {
            if (command.length === 0)
                return;

            if (command[0] === "autocomplete" && command.length > 1) {
                list.search.text = `${GlobalConfig.launcher.actionPrefix}${command[1]} `;
            } else if (command[0] === "setMode" && command.length > 1) {
                list.screenState.launcher = false;
                Colours.setMode(command[1]);
            } else {
                list.screenState.launcher = false;
                if (!SessionManager.exec(command))
                    Quickshell.execDetached(command);
            }
        }
    }
}
