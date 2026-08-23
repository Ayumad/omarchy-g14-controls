import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ayumad.g14-controls"
  property string label: "G14"
  property string profile: ""
  property string gpuMode: ""
  property string runtime: ""
  property string keyboard: ""
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string helperPath: configHome + "/omarchy/plugins/ayumad.g14-controls/g14ctl"
  property int refreshIntervalSec: Number(setting("refreshIntervalSec", 10))
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  // WidgetButton is anchored rather than a layout child, so the host needs
  // an explicit slot size even during the first status refresh.
  implicitWidth: root.vertical ? root.barSize : Style.space(100)
  implicitHeight: root.barSize

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
    if ("anchorItem" in target) target.anchorItem = button
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
          root.runtime = value.nvidia_runtime || ""
          root.keyboard = value.keyboard_brightness || ""
          root.label = "G14 " + (root.profile || "") + " · " + (root.gpuMode || "")
        } catch (error) {
          root.label = "G14"
        }
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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? (root.profile || "G14") : root.label
    labelVisible: true
    horizontalMargin: 8
    verticalPadding: 6
    tooltipText: "Left: G14 controls · Right: cycle profile · Middle: refresh"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) {
        if (panelLoader.item) panelLoader.item.toggle()
      } else if (mouseButton === Qt.RightButton) {
        root.cycleProfile()
      } else if (mouseButton === Qt.MiddleButton) {
        root.refresh()
      }
    }
  }

  Component.onCompleted: root.refresh()
}
