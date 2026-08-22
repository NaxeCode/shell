pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    readonly property int minWidth: 500
    implicitWidth: Math.max(minWidth, flickable.contentItem.childrenRect.width + Tokens.padding.large * 2)
    implicitHeight: Math.min(flickable.contentHeight + Tokens.padding.large * 2, 900)

    // ── HyprGlass defaults (current hyprland.conf values) ──
    readonly property var hgDefaults: ({
        enabled: true,
        blur_strength: 6.0,
        blur_iterations: 3,
        refraction_strength: 0.9,
        chromatic_aberration: 0.7,
        fresnel_strength: 0.5,
        specular_strength: 0.5,
        edge_thickness: 0.08,
        lens_distortion: 0.6,
        vibrancy: 0.15,
        vibrancy_darkness: 0.0,
        layers_enabled: true
    })

    readonly property var nativeBlurDefaults: ({
        enabled: true,
        size: 8,
        passes: 2
    })

    readonly property var trDefaults: ({
        enabled: true,
        base: 0.85,
        layers: 0.4
    })

    readonly property var ghosttyDefaults: ({
        opacity: 0.85,
        blur: true
    })

    readonly property string ghosttyPath: `${Paths.home}/.config/ghostty/config`
    readonly property string effectsTool: `${Paths.home}/.local/bin/hypr-effects`

    property string ghosttyPreset: "glass"
    property bool hgPluginLoaded: false
    property bool hgHyprpmEnabled: false
    property string effectsStatus: ""
    property string effectsConfigErrors: ""

    // ── HyprGlass mutable state ──
    property bool hgEnabled: hgDefaults.enabled
    property real hgBlurStrength: hgDefaults.blur_strength
    property int hgBlurIterations: hgDefaults.blur_iterations
    property real hgRefractionStrength: hgDefaults.refraction_strength
    property real hgChromaticAberration: hgDefaults.chromatic_aberration
    property real hgFresnelStrength: hgDefaults.fresnel_strength
    property real hgSpecularStrength: hgDefaults.specular_strength
    property real hgEdgeThickness: hgDefaults.edge_thickness
    property real hgLensDistortion: hgDefaults.lens_distortion
    property real hgVibrancy: hgDefaults.vibrancy
    property real hgVibrancyDarkness: hgDefaults.vibrancy_darkness
    property bool hgLayersEnabled: hgDefaults.layers_enabled

    property bool nativeBlurEnabled: nativeBlurDefaults.enabled
    property int nativeBlurSize: nativeBlurDefaults.size
    property int nativeBlurPasses: nativeBlurDefaults.passes

    property real ghosttyOpacity: ghosttyDefaults.opacity
    property bool ghosttyBlur: ghosttyDefaults.blur

    property bool _loaded: false

    function applyHg(key: string, value): void {
        Hypr.extras.batchMessage([`keyword plugin:hyprglass:${key} ${value}`]);
    }

    function applyNativeBlur(key: string, value): void {
        Hypr.extras.batchMessage([`keyword decoration:blur:${key} ${value}`]);
    }

    function applyAllNativeBlur(): void {
        Hypr.extras.batchMessage([
            `keyword decoration:blur:enabled ${nativeBlurEnabled ? 1 : 0}`,
            `keyword decoration:blur:size ${nativeBlurSize}`,
            `keyword decoration:blur:passes ${nativeBlurPasses}`,
            "keyword decoration:blur:ignore_opacity 1",
            "keyword decoration:blur:new_optimizations 1",
        ]);
    }

    function applyHgLayers(): void {
        Hypr.extras.batchMessage([
            `keyword plugin:hyprglass:layers:enabled ${hgLayersEnabled ? 1 : 0}`,
            "keyword plugin:hyprglass:layers:namespaces caelestia-drawers",
            "keyword plugin:hyprglass:layers:preset subtle",
            "keyword plugin:hyprglass:layers:namespace_mask_thresholds caelestia-drawers=0.1",
        ]);
    }

    function applyAllHg(): void {
        Hypr.extras.batchMessage([
            `keyword plugin:hyprglass:enabled ${hgEnabled ? 1 : 0}`,
            `keyword plugin:hyprglass:blur_strength ${hgBlurStrength}`,
            `keyword plugin:hyprglass:blur_iterations ${hgBlurIterations}`,
            `keyword plugin:hyprglass:refraction_strength ${hgRefractionStrength}`,
            `keyword plugin:hyprglass:chromatic_aberration ${hgChromaticAberration}`,
            `keyword plugin:hyprglass:fresnel_strength ${hgFresnelStrength}`,
            `keyword plugin:hyprglass:specular_strength ${hgSpecularStrength}`,
            `keyword plugin:hyprglass:edge_thickness ${hgEdgeThickness}`,
            `keyword plugin:hyprglass:lens_distortion ${hgLensDistortion}`,
            `keyword plugin:hyprglass:vibrancy ${hgVibrancy}`,
            `keyword plugin:hyprglass:vibrancy_darkness ${hgVibrancyDarkness}`,
        ]);
    }

    function save(): void {
        if (!_loaded) return;
        const data = {
            enabled: hgEnabled,
            blur_strength: hgBlurStrength,
            blur_iterations: hgBlurIterations,
            refraction_strength: hgRefractionStrength,
            chromatic_aberration: hgChromaticAberration,
            fresnel_strength: hgFresnelStrength,
            specular_strength: hgSpecularStrength,
            edge_thickness: hgEdgeThickness,
            lens_distortion: hgLensDistortion,
            vibrancy: hgVibrancy,
            vibrancy_darkness: hgVibrancyDarkness,
            layers_enabled: hgLayersEnabled,
            native_blur_enabled: nativeBlurEnabled,
            native_blur_size: nativeBlurSize,
            native_blur_passes: nativeBlurPasses,
            ghostty_preset: ghosttyPreset,
        };
        jsonFile.setText(JSON.stringify(data, null, 2) + "\n");

        const conf = [
            "decoration {",
            "    blur {",
            `        enabled = ${nativeBlurEnabled ? 1 : 0}`,
            `        size = ${nativeBlurSize}`,
            `        passes = ${nativeBlurPasses}`,
            "        ignore_opacity = 1",
            "        new_optimizations = 1",
            "    }",
            "}",
            "",
            "plugin {",
            "    hyprglass {",
            `        enabled = ${hgEnabled ? 1 : 0}`,
            `        blur_strength = ${hgBlurStrength}`,
            `        blur_iterations = ${hgBlurIterations}`,
            `        refraction_strength = ${hgRefractionStrength}`,
            `        chromatic_aberration = ${hgChromaticAberration}`,
            `        fresnel_strength = ${hgFresnelStrength}`,
            `        specular_strength = ${hgSpecularStrength}`,
            `        edge_thickness = ${hgEdgeThickness}`,
            `        lens_distortion = ${hgLensDistortion}`,
            `        vibrancy = ${hgVibrancy}`,
            `        vibrancy_darkness = ${hgVibrancyDarkness}`,
            "",
            "        layers {",
            `            enabled = ${hgLayersEnabled ? 1 : 0}`,
            "            namespaces = caelestia-drawers",
            "            preset = subtle",
            "            namespace_mask_thresholds = caelestia-drawers=0.1",
            "        }",
            "    }",
            "}",
        ].join("\n") + "\n";
        confFile.setText(conf);
    }

    function hgChange(key: string, value): void {
        applyHg(key, value);
        saveDebounce.restart();
    }

    function loadGhosttyConfig(text: string): void {
        const opMatch = text.match(/^background-opacity\s*=\s*([\d.]+)/m);
        if (opMatch) ghosttyOpacity = parseFloat(opMatch[1]);
        const blurMatch = text.match(/^background-blur\s*=\s*(\w+)/m);
        if (blurMatch) ghosttyBlur = blurMatch[1] === "true";
    }

    function saveGhostty(): void {
        Quickshell.execDetached(["sh", "-c",
            `sed -i -E -e 's/^background-opacity\\s*=.*/background-opacity = ${ghosttyOpacity}/' ` +
            `-e 's/^background-blur\\s*=.*/background-blur = ${ghosttyBlur}/' ` +
            `'${ghosttyPath}' && ` +
            `gdbus call --session --dest com.mitchellh.ghostty ` +
            `--object-path /com/mitchellh/ghostty ` +
            `--method org.gtk.Actions.Activate reload-config '[]' '{}'`]);
    }

    function setGhosttyPreset(preset: string): void {
        ghosttyPreset = preset;
        Quickshell.execDetached([effectsTool, "set-ghostty-preset", preset]);
        liveRefreshDebounce.restart();
    }

    function refreshLive(): void {
        if (!liveStateProc.running)
            liveStateProc.running = true;
    }

    function reloadHyprGlassPlugin(): void {
        Quickshell.execDetached([effectsTool, "reload-plugin"]);
        liveRefreshDebounce.restart();
    }

    function applyLiveState(text: string): void {
        try {
            const data = JSON.parse(text);
            const blur = data.native_blur ?? {};
            if (blur.enabled !== null && blur.enabled !== undefined) nativeBlurEnabled = blur.enabled;
            if (blur.size !== null && blur.size !== undefined) nativeBlurSize = blur.size;
            if (blur.passes !== null && blur.passes !== undefined) nativeBlurPasses = blur.passes;

            const hg = data.hyprglass ?? {};
            if (hg.enabled !== null && hg.enabled !== undefined) hgEnabled = hg.enabled;
            if (hg.blur_strength !== null && hg.blur_strength !== undefined) hgBlurStrength = hg.blur_strength;
            if (hg.blur_iterations !== null && hg.blur_iterations !== undefined) hgBlurIterations = hg.blur_iterations;
            if (hg.refraction_strength !== null && hg.refraction_strength !== undefined) hgRefractionStrength = hg.refraction_strength;
            if (hg.chromatic_aberration !== null && hg.chromatic_aberration !== undefined) hgChromaticAberration = hg.chromatic_aberration;
            if (hg.fresnel_strength !== null && hg.fresnel_strength !== undefined) hgFresnelStrength = hg.fresnel_strength;
            if (hg.specular_strength !== null && hg.specular_strength !== undefined) hgSpecularStrength = hg.specular_strength;
            if (hg.edge_thickness !== null && hg.edge_thickness !== undefined) hgEdgeThickness = hg.edge_thickness;
            if (hg.lens_distortion !== null && hg.lens_distortion !== undefined) hgLensDistortion = hg.lens_distortion;
            if (hg.vibrancy !== null && hg.vibrancy !== undefined) hgVibrancy = hg.vibrancy;
            if (hg.vibrancy_darkness !== null && hg.vibrancy_darkness !== undefined) hgVibrancyDarkness = hg.vibrancy_darkness;
            if (hg.layers_enabled !== null && hg.layers_enabled !== undefined) hgLayersEnabled = hg.layers_enabled;
            hgPluginLoaded = hg.loaded ?? false;
            hgHyprpmEnabled = hg.hyprpm_enabled ?? false;

            const ghostty = data.ghostty ?? {};
            if (ghostty.opacity !== null && ghostty.opacity !== undefined) ghosttyOpacity = ghostty.opacity;
            if (ghostty.blur !== null && ghostty.blur !== undefined) ghosttyBlur = ghostty.blur;
            ghosttyPreset = data.rules?.ghostty_preset ?? ghosttyPreset;
            effectsConfigErrors = data.config_errors ?? "";
            effectsStatus = qsTr("Live state refreshed");
        } catch (e) {
            effectsStatus = qsTr("Live readback failed: %1").arg(e);
        }
    }

    function loadFromJson(text: string): void {
        try {
            const data = JSON.parse(text);
            hgEnabled = data.enabled ?? hgDefaults.enabled;
            hgBlurStrength = data.blur_strength ?? hgDefaults.blur_strength;
            hgBlurIterations = data.blur_iterations ?? hgDefaults.blur_iterations;
            hgRefractionStrength = data.refraction_strength ?? hgDefaults.refraction_strength;
            hgChromaticAberration = data.chromatic_aberration ?? hgDefaults.chromatic_aberration;
            hgFresnelStrength = data.fresnel_strength ?? hgDefaults.fresnel_strength;
            hgSpecularStrength = data.specular_strength ?? hgDefaults.specular_strength;
            hgEdgeThickness = data.edge_thickness ?? hgDefaults.edge_thickness;
            hgLensDistortion = data.lens_distortion ?? hgDefaults.lens_distortion;
            hgVibrancy = data.vibrancy ?? hgDefaults.vibrancy;
            hgVibrancyDarkness = data.vibrancy_darkness ?? hgDefaults.vibrancy_darkness;
            hgLayersEnabled = data.layers_enabled ?? hgDefaults.layers_enabled;
            nativeBlurEnabled = data.native_blur_enabled ?? nativeBlurDefaults.enabled;
            nativeBlurSize = data.native_blur_size ?? nativeBlurDefaults.size;
            nativeBlurPasses = data.native_blur_passes ?? nativeBlurDefaults.passes;
            ghosttyPreset = data.ghostty_preset ?? ghosttyPreset;
        } catch (e) {
            console.warn("EffectsTab: JSON parse failed, using defaults");
        }
        _loaded = true;
    }

    function resetToDefaults(): void {
        hgEnabled = hgDefaults.enabled;
        hgBlurStrength = hgDefaults.blur_strength;
        hgBlurIterations = hgDefaults.blur_iterations;
        hgRefractionStrength = hgDefaults.refraction_strength;
        hgChromaticAberration = hgDefaults.chromatic_aberration;
        hgFresnelStrength = hgDefaults.fresnel_strength;
        hgSpecularStrength = hgDefaults.specular_strength;
        hgEdgeThickness = hgDefaults.edge_thickness;
        hgLensDistortion = hgDefaults.lens_distortion;
        hgVibrancy = hgDefaults.vibrancy;
        hgVibrancyDarkness = hgDefaults.vibrancy_darkness;
        hgLayersEnabled = hgDefaults.layers_enabled;

        nativeBlurEnabled = nativeBlurDefaults.enabled;
        nativeBlurSize = nativeBlurDefaults.size;
        nativeBlurPasses = nativeBlurDefaults.passes;

        GlobalConfig.appearance.transparency.enabled = trDefaults.enabled;
        GlobalConfig.appearance.transparency.base = trDefaults.base;
        GlobalConfig.appearance.transparency.layers = trDefaults.layers;

        ghosttyOpacity = ghosttyDefaults.opacity;
        ghosttyBlur = ghosttyDefaults.blur;
        ghosttyPreset = "glass";

        save();
        applyAllNativeBlur();
        applyAllHg();
        applyHgLayers();
        saveGhostty();
        setGhosttyPreset(ghosttyPreset);
    }

    FileView {
        id: jsonFile

        path: `${Paths.config}/effects.json`
        printErrors: false
        onLoaded: root.loadFromJson(text())
        onLoadFailed: {
            root._loaded = true;
            root.save();
        }
    }

    FileView {
        id: confFile

        path: `${Paths.config}/hyprglass-effects.conf`
        printErrors: false
    }

    FileView {
        id: ghosttyFile

        path: root.ghosttyPath
        printErrors: false
        onLoaded: root.loadGhosttyConfig(text())
    }

    Process {
        id: liveStateProc

        command: [root.effectsTool, "state"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.applyLiveState(text)
        }
    }

    Timer {
        id: liveRefreshDebounce

        interval: 800
        onTriggered: root.refreshLive()
    }

    Connections {
        function onConfigReloaded(): void {
            root.refreshLive();
        }

        target: Hypr
    }

    Component.onCompleted: root.refreshLive()

    Timer {
        id: saveDebounce

        interval: 200
        onTriggered: root.save()
    }

    Timer {
        id: ghosttyDebounce

        interval: 200
        onTriggered: root.saveGhostty()
    }

    StyledFlickable {
        id: flickable

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        flickableDirection: Flickable.VerticalFlick
        contentHeight: layout.implicitHeight

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: flickable
        }

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Tokens.spacing.larger

            // ── Header ────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.normal

                RowLayout {
                    spacing: Tokens.spacing.small

                    IconTextButton {
                        icon: "auto_awesome"
                        text: (Colours.transparency.enabled && root.nativeBlurEnabled && root.hgEnabled && root.hgLayersEnabled && root.ghosttyBlur)
                            ? qsTr("All effects on")
                            : qsTr("All effects off")
                        checked: Colours.transparency.enabled && root.nativeBlurEnabled && root.hgEnabled && root.hgLayersEnabled && root.ghosttyBlur
                        type: IconTextButton.Filled
                        onClicked: {
                            const enable = !(Colours.transparency.enabled && root.nativeBlurEnabled && root.hgEnabled && root.hgLayersEnabled && root.ghosttyBlur);
                            GlobalConfig.appearance.transparency.enabled = enable;
                            root.nativeBlurEnabled = enable;
                            root.hgEnabled = enable;
                            root.hgLayersEnabled = enable;
                            root.ghosttyBlur = enable;
                            root.ghosttyPreset = enable ? "glass" : "off";
                            root.applyNativeBlur("enabled", enable ? 1 : 0);
                            root.applyHg("enabled", enable ? 1 : 0);
                            root.applyHgLayers();
                            root.saveGhostty();
                            root.setGhosttyPreset(root.ghosttyPreset);
                            root.saveDebounce.restart();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                IconTextButton {
                    icon: "sync"
                    text: qsTr("Read live")
                    type: IconTextButton.Tonal
                    onClicked: root.refreshLive()
                }

                IconTextButton {
                    icon: "extension"
                    text: qsTr("Reload HyprGlass")
                    type: IconTextButton.Tonal
                    onClicked: root.reloadHyprGlassPlugin()
                }

                IconTextButton {
                    icon: "restart_alt"
                    text: qsTr("Default")
                    type: IconTextButton.Tonal
                    onClicked: root.resetToDefaults()
                }
            }

            // ── Live status ───────────────────────────────────────────────────
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: liveStatus.implicitHeight + Tokens.padding.normal * 2
                radius: Tokens.rounding.normal
                color: (!root.hgPluginLoaded || root.effectsConfigErrors.length > 0)
                    ? Qt.alpha(Colours.palette.m3errorContainer, 0.7)
                    : Colours.tPalette.m3surfaceContainer

                ColumnLayout {
                    id: liveStatus

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.normal
                    spacing: Tokens.spacing.smaller

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Live readback: native blur %1 · Ghostty preset %2 · HyprGlass plugin %3")
                            .arg(root.nativeBlurEnabled ? qsTr("on") : qsTr("off"))
                            .arg(root.ghosttyPreset)
                            .arg(root.hgPluginLoaded ? qsTr("loaded") : (root.hgHyprpmEnabled ? qsTr("enabled but not loaded") : qsTr("not enabled")))
                        color: Colours.palette.m3onSurface
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.effectsStatus.length > 0
                        text: root.effectsStatus
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.smaller
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.effectsConfigErrors.length > 0
                        text: root.effectsConfigErrors
                        color: Colours.palette.m3error
                        font.pointSize: Tokens.font.size.smaller
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Transparency ──────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Transparency")
                    font.pointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurfaceVariant
                }

                SwitchRow {
                    label: qsTr("Enabled")
                    checked: Colours.transparency.enabled
                    onToggled: checked => {
                        GlobalConfig.appearance.transparency.enabled = checked;
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: trSliders.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.normal
                    color: Colours.tPalette.m3surfaceContainer
                    opacity: Colours.transparency.enabled ? 1.0 : 0.5

                    ColumnLayout {
                        id: trSliders

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.normal
                        spacing: Tokens.spacing.normal

                        EffectSlider {
                            label: qsTr("Base opacity")
                            value: (GlobalConfig.appearance.transparency.base ?? 0.85) * 100
                            from: 0; to: 100; stepSize: 1; decimals: 0
                            suffix: "%"
                            enabled: Colours.transparency.enabled
                            onValueModified: v => {
                                GlobalConfig.appearance.transparency.base = v / 100;
                            }
                        }

                        EffectSlider {
                            label: qsTr("Layer opacity")
                            value: (GlobalConfig.appearance.transparency.layers ?? 0.4) * 100
                            from: 0; to: 100; stepSize: 1; decimals: 0
                            suffix: "%"
                            enabled: Colours.transparency.enabled
                            onValueModified: v => {
                                GlobalConfig.appearance.transparency.layers = v / 100;
                            }
                        }
                    }
                }
            }

            // ── Hyprland native blur ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Hyprland blur")
                    font.pointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurfaceVariant
                }

                SwitchRow {
                    label: qsTr("Enabled")
                    checked: root.nativeBlurEnabled
                    onToggled: checked => {
                        root.nativeBlurEnabled = checked;
                        root.applyNativeBlur("enabled", checked ? 1 : 0);
                        root.saveDebounce.restart();
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: blurSliders.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.normal
                    color: Colours.tPalette.m3surfaceContainer
                    opacity: root.nativeBlurEnabled ? 1.0 : 0.5

                    ColumnLayout {
                        id: blurSliders

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.normal
                        spacing: Tokens.spacing.normal
                        enabled: root.nativeBlurEnabled

                        EffectSlider {
                            label: qsTr("Size")
                            value: root.nativeBlurSize
                            from: 1; to: 20; stepSize: 1; decimals: 0
                            onValueModified: v => {
                                root.nativeBlurSize = Math.round(v);
                                root.applyNativeBlur("size", Math.round(v));
                                root.saveDebounce.restart();
                            }
                        }

                        EffectSlider {
                            label: qsTr("Passes")
                            value: root.nativeBlurPasses
                            from: 1; to: 6; stepSize: 1; decimals: 0
                            onValueModified: v => {
                                root.nativeBlurPasses = Math.round(v);
                                root.applyNativeBlur("passes", Math.round(v));
                                root.saveDebounce.restart();
                            }
                        }
                    }
                }
            }

            // ── HyprGlass ────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("HyprGlass")
                    font.pointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurfaceVariant
                }

                SwitchRow {
                    label: qsTr("Enabled")
                    checked: root.hgEnabled
                    onToggled: checked => {
                        root.hgEnabled = checked;
                        root.applyHg("enabled", checked ? 1 : 0);
                        root.saveDebounce.restart();
                    }
                }

                SwitchRow {
                    label: qsTr("Caelestia drawer glass")
                    checked: root.hgLayersEnabled
                    onToggled: checked => {
                        root.hgLayersEnabled = checked;
                        root.applyHgLayers();
                        root.saveDebounce.restart();
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: hgSliders.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.normal
                    color: Colours.tPalette.m3surfaceContainer
                    opacity: root.hgEnabled ? 1.0 : 0.5

                    ColumnLayout {
                        id: hgSliders

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.normal
                        spacing: Tokens.spacing.normal
                        enabled: root.hgEnabled

                        EffectSlider {
                            label: qsTr("Blur strength")
                            value: root.hgBlurStrength
                            from: 0; to: 20; stepSize: 0.5; decimals: 1
                            onValueModified: v => {
                                root.hgBlurStrength = v;
                                root.hgChange("blur_strength", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Blur iterations")
                            value: root.hgBlurIterations
                            from: 1; to: 10; stepSize: 1; decimals: 0
                            onValueModified: v => {
                                root.hgBlurIterations = Math.round(v);
                                root.hgChange("blur_iterations", Math.round(v));
                            }
                        }

                        EffectSlider {
                            label: qsTr("Refraction")
                            value: root.hgRefractionStrength
                            from: 0; to: 2; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgRefractionStrength = v;
                                root.hgChange("refraction_strength", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Chromatic aberration")
                            value: root.hgChromaticAberration
                            from: 0; to: 2; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgChromaticAberration = v;
                                root.hgChange("chromatic_aberration", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Fresnel")
                            value: root.hgFresnelStrength
                            from: 0; to: 1; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgFresnelStrength = v;
                                root.hgChange("fresnel_strength", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Specular")
                            value: root.hgSpecularStrength
                            from: 0; to: 1; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgSpecularStrength = v;
                                root.hgChange("specular_strength", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Edge thickness")
                            value: root.hgEdgeThickness
                            from: 0; to: 0.5; stepSize: 0.01; decimals: 2
                            onValueModified: v => {
                                root.hgEdgeThickness = v;
                                root.hgChange("edge_thickness", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Lens distortion")
                            value: root.hgLensDistortion
                            from: 0; to: 2; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgLensDistortion = v;
                                root.hgChange("lens_distortion", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Vibrancy")
                            value: root.hgVibrancy
                            from: 0; to: 1; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgVibrancy = v;
                                root.hgChange("vibrancy", v);
                            }
                        }

                        EffectSlider {
                            label: qsTr("Vibrancy darkness")
                            value: root.hgVibrancyDarkness
                            from: 0; to: 1; stepSize: 0.05; decimals: 2
                            onValueModified: v => {
                                root.hgVibrancyDarkness = v;
                                root.hgChange("vibrancy_darkness", v);
                            }
                        }
                    }
                }
            }

            // ── Ghostty ──────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Ghostty")
                    font.pointSize: Tokens.font.size.normal
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: ghosttyCol.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.normal
                    color: Colours.tPalette.m3surfaceContainer

                    ColumnLayout {
                        id: ghosttyCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.normal
                        spacing: Tokens.spacing.normal

                        EffectSlider {
                            label: qsTr("Background opacity")
                            value: root.ghosttyOpacity * 100
                            from: 0; to: 100; stepSize: 1; decimals: 0
                            suffix: "%"
                            onValueModified: v => {
                                root.ghosttyOpacity = v / 100;
                                ghosttyDebounce.restart();
                            }
                        }

                        SwitchRow {
                            label: qsTr("Background blur")
                            checked: root.ghosttyBlur
                            onToggled: checked => {
                                root.ghosttyBlur = checked;
                                if (checked && !root.nativeBlurEnabled) {
                                    root.nativeBlurEnabled = true;
                                    root.applyNativeBlur("enabled", 1);
                                    root.saveDebounce.restart();
                                }
                                root.saveGhostty();
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.smaller

                            StyledText {
                                text: qsTr("HyprGlass preset rule")
                                font.pointSize: Tokens.font.size.smaller
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                Repeater {
                                    model: [
                                        { id: "off", label: qsTr("Off") },
                                        { id: "subtle", label: qsTr("Subtle") },
                                        { id: "clear", label: qsTr("Clear") },
                                        { id: "glass", label: qsTr("Glass") },
                                        { id: "high_contrast", label: qsTr("High contrast") },
                                    ]

                                    delegate: IconTextButton {
                                        required property var modelData
                                        text: modelData.label
                                        checked: root.ghosttyPreset === modelData.id
                                        type: IconTextButton.Tonal
                                        font.pointSize: Tokens.font.size.smaller
                                        verticalPadding: Tokens.padding.small
                                        onClicked: root.setGhosttyPreset(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component EffectSlider: ColumnLayout {
        id: slider

        property string label
        property real value
        property real from: 0
        property real to: 1
        property real stepSize: 0.01
        property int decimals: 2
        property string suffix: ""

        signal valueModified(real newValue)

        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: slider.label
                font.pointSize: Tokens.font.size.smaller
                color: Colours.palette.m3onSurfaceVariant
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: slider.value.toFixed(slider.decimals) + slider.suffix
                font.pointSize: Tokens.font.size.smaller
                color: Colours.palette.m3onSurface
                font.family: Tokens.font.family.mono
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.normal * 3
            from: slider.from
            to: slider.to
            stepSize: slider.stepSize
            value: slider.value
            live: false
            onMoved: slider.valueModified(value)
            onPressedChanged: if (!pressed) slider.valueModified(value)
        }
    }
}
