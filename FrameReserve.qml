import Quickshell
import Quickshell.Wayland
import QtQuick
import "config.js" as Config

// Reserves the left strip so tiled windows avoid it. Purely functional —
// no visible output; FrameShape draws the actual frame on top.
PanelWindow {
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Config.frame.thick

    anchors {
        top: true
        bottom: true
        left: true
    }

    implicitWidth: Config.frame.thick
}
