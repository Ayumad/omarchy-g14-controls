import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ayumad.g14-controls"
  property string profile: ""
  property string gpuMode: ""
  property string runtime: ""
  property string dgpuName: ""
  property string keyboard: ""
  readonly property string rogLogoSource: "file:///usr/share/icons/hicolor/512x512/apps/rog-control-center.png"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string helperPath: configHome + "/omarchy/plugins/ayumad.g14-controls/g14ctl"
  property int refreshIntervalSec: Number(setting("refreshIntervalSec", 10))
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  // Each state gets its own compact, directly hoverable glyph.
  implicitWidth: root.vertical ? root.barSize : glyphRow.implicitWidth
  implicitHeight: root.barSize

  function profileGlyph() {
    switch (root.profile.toLowerCase()) {
      case "quiet": return "󰌪"
      case "balanced": return "󰊚"
      case "performance": return "󰓅"
      default: return "󰂄"
    }
  }

  function gpuIconSource() {
    switch (root.gpuMode.toLowerCase()) {
      case "integrated": return "file:///usr/share/icons/hicolor/scalable/status/gpu-integrated.svg"
      case "hybrid": return "file:///usr/share/icons/hicolor/scalable/status/gpu-hybrid.svg"
      case "ultimate": return "file:///usr/share/icons/hicolor/scalable/status/gpu-nvidia.svg"
      default: return ""
    }
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleProfile() {
    runAction(["profile", "next"])
  }

  function handleGlyphPress(mouseButton) {
    if (mouseButton === Qt.LeftButton) {
      root.toggle()
    } else if (mouseButton === Qt.RightButton) {
      root.cycleProfile()
    } else if (mouseButton === Qt.MiddleButton) {
      root.refresh()
    }
  }

  function graphicsTooltip() {
    var mode = root.gpuMode || "unknown"
    var name = root.dgpuName || "dGPU"
    if (root.runtime === "suspended") return name + " · " + mode + " · asleep"
    if (root.runtime) return name + " · " + mode + " · " + root.runtime
    return name + " · " + mode
  }

  function runAction(args) {
    if (actionProc.running) return
    actionProc.command = [root.helperPath].concat(args)
    actionProc.running = true
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = deviceButton
    if ("hostWidget" in target) target.hostWidget = root
  }

  Process {
    id: statusProc
    command: [root.helperPath, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var value = JSON.parse(text)
          root.profile = value.profile || ""
          root.gpuMode = value.gpu_mode || ""
          root.runtime = value.dgpu_runtime || value.nvidia_runtime || ""
          root.dgpuName = value.dgpu_name || ""
          root.keyboard = value.keyboard_brightness || ""
        } catch (error) {}
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: root.refresh()
  }

  Timer {
    interval: Math.max(5000, root.refreshIntervalSec * 1000)
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  onBarChanged: root.injectPanel()
  onSettingsChanged: root.injectPanel()

  IpcHandler {
    target: "ayumad.g14-controls"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Row {
    id: glyphRow
    anchors.centerIn: parent
    spacing: Style.space(1)

    BarIconButton {
      id: deviceButton
      bar: root.bar
      opticalSize: Style.space(20)
      iconComponent: Component {
        Item {
          Image {
            id: rogMark
            anchors.fill: parent
            source: root.rogLogoSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: false
            layer.enabled: true
          }

          MultiEffect {
            anchors.fill: rogMark
            source: rogMark
            autoPaddingEnabled: false
            colorization: 1.0
            colorizationColor: root.bar ? root.bar.foreground : Color.foreground
          }
        }
      }
      tooltipText: "G14 controls"
      onPressed: function(mouseButton) { root.handleGlyphPress(mouseButton) }
    }

    BarIconButton {
      bar: root.bar
      text: root.profileGlyph()
      tooltipText: "Profile: " + (root.profile || "unknown")
      onPressed: function(mouseButton) { root.handleGlyphPress(mouseButton) }
    }

    BarIconButton {
      bar: root.bar
      iconComponent: Component {
        Item {
          Image {
            id: gpuMark
            anchors.fill: parent
            source: root.gpuIconSource()
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: false
            layer.enabled: true
          }

          MultiEffect {
            anchors.fill: gpuMark
            source: gpuMark
            autoPaddingEnabled: false
            colorization: 1.0
            colorizationColor: root.bar ? root.bar.foreground : Color.foreground
          }
        }
      }
      tooltipText: root.graphicsTooltip()
      onPressed: function(mouseButton) { root.handleGlyphPress(mouseButton) }
    }
  }

  Component.onCompleted: root.refresh()
}
