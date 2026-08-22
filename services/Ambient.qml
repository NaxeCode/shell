pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var context: ({})
    property var generation: ({})
    readonly property var stable: context.stable ?? ({})
    readonly property var candidate: context.candidate ?? ({})
    readonly property var controls: context.controls ?? ({})
    readonly property var scheme: generation.scheme ?? ({ colours: ({}) })
    readonly property bool renderingEnabled: controls.alive !== false
        && !controls.reducedMotion
        && !stable.suppressed
    readonly property real motionIntensity: generation.genome?.motion?.intensity ?? 0
    readonly property real transitionMs: generation.genome?.motion?.transitionMs ?? 8000
    readonly property string primary: `#${scheme.colours?.primary ?? "F66E0D"}`
    readonly property string tertiary: `#${scheme.colours?.tertiary ?? "E8A04B"}`
    readonly property string surface: `#${scheme.colours?.surface ?? "221D2B"}`

    function load(file, propertyName) {
        try {
            root[propertyName] = JSON.parse(file.text());
        } catch (_) {
            root[propertyName] = ({});
        }
    }

    FileView {
        id: contextFile

        path: `${Quickshell.env("HOME")}/.local/state/ambient/context.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(contextFile, "context")
    }

    FileView {
        id: generationFile

        path: `${Quickshell.env("HOME")}/.local/state/ambient/current.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(generationFile, "generation")
    }
}
