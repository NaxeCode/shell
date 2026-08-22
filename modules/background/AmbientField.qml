import QtQuick
import qs.services

Item {
    id: root

    required property var screen
    anchors.fill: parent
    visible: Ambient.renderingEnabled
    opacity: visible ? 0.16 + Ambient.motionIntensity * 0.16 : 0

    Behavior on opacity {
        NumberAnimation { duration: 300 }
    }

    Rectangle {
        id: field

        anchors.fill: parent
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0; color: Ambient.surface }
            GradientStop { position: 0.5; color: Ambient.primary }
            GradientStop { position: 1; color: Ambient.tertiary }
        }
        opacity: 0.45
        rotation: phase * 360
        transformOrigin: Item.Center
        scale: 1.4

        NumberAnimation on rotation {
            running: root.visible && Ambient.motionIntensity > 0
            from: 0
            to: 360
            duration: Math.max(60000, Ambient.transitionMs / Math.max(0.05, Ambient.motionIntensity))
            loops: Animation.Infinite
        }

        Behavior on color {
            ColorAnimation { duration: Ambient.transitionMs }
        }
    }

    property real phase: 0

    NumberAnimation on phase {
        running: root.visible && Ambient.motionIntensity > 0
        from: 0
        to: 1
        duration: Math.max(90000, Ambient.transitionMs / Math.max(0.05, Ambient.motionIntensity))
        loops: Animation.Infinite
    }
}
