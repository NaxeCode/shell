pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.items
import qs.modules.launcher.services

StyledListView {
    id: root

    readonly property string displayState: stateForText(displayText)
    property string displayText
    readonly property string requestedState: stateForText(search.text)
    required property ScreenState screenState
    required property SearchBar search
    readonly property list<string> systemActionAppNames: ["shut down", "reboot", "log out", "suspend", "lock screen"]

    function normalSearch(search: string): list<var> {
        const actions = Actions.normalSearch(search);
        const apps = Apps.search(search).filter(a => !systemActionAppNames.includes((a.name ?? "").toLowerCase()));
        return [...actions, ...apps];
    }

    function resultsForText(text: string): var {
        switch (stateForText(text)) {
        case "actions":
            return Actions.query(text);
        case "calc":
            return [0];
        case "scheme":
            return Schemes.query(text);
        case "variant":
            return M3Variants.query(text);
        default:
            return Apps.search(text);
        }
    }

    function stateForText(text: string): string {
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            for (const action of ["calc", "scheme", "variant"])
                if (text.startsWith(`${prefix}${action} `))
                    return action;

            return "actions";
        }

        return "apps";
    }

    function syncDisplayText(): void {
        if (screenState.launcher && requestedState === displayState)
            displayText = search.text;
    }

    highlightFollowsCurrentItem: false
    highlightRangeMode: ListView.ApplyRange
    implicitHeight: (Tokens.sizes.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing
    orientation: Qt.Vertical
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    spacing: Tokens.spacing.small
    state: screenState.launcher ? requestedState : displayState

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }
    add: Transition {
        enabled: !root.state

        Anim {
            from: 0
            property: "opacity"
            to: 1
            type: Anim.DefaultEffects
        }
    }
    addDisplaced: Transition {
        Anim {
            property: "y"
            type: Anim.StandardSmall
        }

        Anim {
            property: "opacity"
            to: 1
            type: Anim.DefaultEffects
        }
    }
    displaced: Transition {
        Anim {
            property: "y"
        }

        Anim {
            property: "opacity"
            to: 1
            type: Anim.DefaultEffects
        }
    }
    highlight: StyledRect {
        color: Colours.palette.m3onSurface
        implicitHeight: root.currentItem?.implicitHeight ?? 0
        implicitWidth: root.width
        opacity: 0.08
        radius: Tokens.rounding.large
        y: root.currentItem?.y ?? 0

        Behavior on y {
            Anim {
            }
        }
    }
    model: ScriptModel {
        values: root.resultsForText(root.displayText)

        onValuesChanged: root.currentIndex = 0
    }
    move: Transition {
        Anim {
            property: "y"
        }

        Anim {
            property: "opacity"
            to: 1
            type: Anim.DefaultEffects
        }
    }
    remove: Transition {
        enabled: !root.state

        Anim {
            from: 1
            property: "opacity"
            to: 0
            type: Anim.DefaultEffects
        }
    }
    states: [
        State {
            name: "apps"

            PropertyChanges {
                model.values: root.normalSearch(search.text)
                root.delegate: mixedItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                root.delegate: actionItem
            }
        },
        State {
            name: "calc"

            PropertyChanges {
                root.delegate: calcItem
            }
        },
        State {
            name: "scheme"

            PropertyChanges {
                root.delegate: schemeItem
            }
        },
        State {
            name: "variant"

            PropertyChanges {
                root.delegate: variantItem
            }
        }
    ]
    transitions: Transition {
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                    from: 1
                    property: "opacity"
                    target: root
                    to: 0
                }

                Anim {
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                    from: 1
                    property: "scale"
                    target: root
                    to: 0.9
                }
            }

            PropertyAction {
                property: "delegate"
                target: root
                value: null
            }

            ScriptAction {
                script: root.displayText = root.search.text
            }

            PropertyAction {
                property: "delegate"
                target: root
            }

            ParallelAnimation {
                Anim {
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                    from: 0
                    property: "opacity"
                    target: root
                    to: 1
                }

                Anim {
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                    from: 0.9
                    property: "scale"
                    target: root
                    to: 1
                }
            }

            PropertyAction {
                property: "enabled"
                targets: [root.add, root.remove]
                value: true
            }
        }
    }

    Component.onCompleted: displayText = search.text
    onStateChanged: {
        if (state === "scheme" || state === "variant")
            Schemes.reload();
    }

    Component {
        id: mixedItem

        Item {
            id: mixedDelegate

            required property var modelData

            anchors.left: parent?.left
            anchors.right: parent?.right
            implicitHeight: Tokens.sizes.launcher.itemHeight

            Loader {
                anchors.fill: parent
                sourceComponent: mixedDelegate.modelData?.launcherType === "action" ? mixedActionItem : mixedAppItem
            }

            Component {
                id: mixedAppItem

                AppItem {
                    modelData: mixedDelegate.modelData
                    screenState: root.screenState
                }
            }

            Component {
                id: mixedActionItem

                ActionItem {
                    list: root
                    modelData: mixedDelegate.modelData
                }
            }
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcItem

        CalcItem {
            list: root
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Component {
        id: variantItem

        VariantItem {
            list: root
        }
    }

    Connections {
        function onTextChanged() {
            root.syncDisplayText();
        }

        target: root.search
    }

    Connections {
        function onLauncherChanged() {
            root.syncDisplayText();
        }

        target: root.screenState
    }
}
