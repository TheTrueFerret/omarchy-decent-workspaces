import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "IconRules.js" as IconRules

// Workspace indicators that show only what is actually there: workspaces with
// windows on them, filtered to the monitor this bar instance lives on, each
// labelled with its number plus an icon per open window.
BarWidget {
  id: root
  moduleName: "io.github.thetrueferret.decent-workspaces"

  // --- settings, read from this widget's shell.json layout entry ------------
  readonly property bool perMonitor: root.setting("perMonitor", true)
  readonly property bool showEmpty: root.setting("showEmpty", false)
  readonly property bool showIcons: root.setting("showIcons", true)
  // 0 = show an icon for every window; otherwise overflow collapses to "+N".
  readonly property int maxIcons: root.setting("maxIcons", 0)
  readonly property int maxWorkspaceId: root.setting("maxWorkspaceId", 10)

  readonly property color fgColor: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color bgColor: root.bar ? root.bar.background : Color.background
  readonly property color urgentColor: Color.urgent
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(15)

  // --- which monitor is this bar on ----------------------------------------
  // One bar surface exists per monitor, so the widget reads its own screen off
  // the window it was instantiated into rather than off any global focus state.
  readonly property var barWindow: root.QsWindow ? root.QsWindow.window : null
  readonly property string screenName: barWindow && barWindow.screen ? String(barWindow.screen.name || "") : ""

  readonly property var hyprMonitor: {
    var _ = root.revision
    if (root.screenName === "") return null
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      if (String(monitors[i].name) === root.screenName) return monitors[i]
    }
    return null
  }

  // The workspace active *on this monitor*, which is not the same as the
  // globally focused workspace once a second monitor exists.
  readonly property int activeId: {
    if (root.hyprMonitor && root.hyprMonitor.activeWorkspace) return root.hyprMonitor.activeWorkspace.id
    return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  }

  // Whether this monitor is the one holding keyboard focus, used to keep the
  // active pill on the other monitors visibly quieter.
  readonly property bool monitorFocused: {
    var _ = root.revision
    if (root.screenName === "" || !Hyprland.focusedMonitor) return true
    return String(Hyprland.focusedMonitor.name) === root.screenName
  }

  // --- keeping Hyprland's view fresh ---------------------------------------
  // Quickshell does not refetch toplevels or workspaces on its own, so window
  // and workspace events have to poke it or occupancy goes stale. `revision`
  // is bumped alongside so bindings below re-evaluate on events that change
  // nothing Quickshell exposes as a property (focusedmon, urgent).
  property int revision: 0

  readonly property var windowEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle", "windowtitlev2", "activewindow", "activewindowv2", "urgent"]
  readonly property var workspaceEvents: ["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2", "focusedmon"]

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event.name
      if (root.windowEvents.indexOf(name) !== -1) {
        Hyprland.refreshToplevels()
        root.revision++
      } else if (root.workspaceEvents.indexOf(name) !== -1) {
        Hyprland.refreshWorkspaces()
        root.revision++
      }
    }
  }

  // --- model ---------------------------------------------------------------
  function hasWindows(workspace) {
    if (!workspace) return false
    var tops = workspace.toplevels ? workspace.toplevels.values : null
    return !!tops && tops.length > 0
  }

  // Hyprland reports the owning monitor as an object on the workspace and as a
  // bare name string in the raw IPC payload; either will do.
  function monitorNameOf(workspace) {
    if (!workspace) return ""
    if (workspace.monitor && workspace.monitor.name) return String(workspace.monitor.name)
    var ipc = workspace.lastIpcObject
    if (ipc && ipc.monitor) return String(ipc.monitor)
    return ""
  }

  readonly property var visibleWorkspaces: {
    var _ = root.revision
    var mine = root.screenName
    var active = root.activeId
    var result = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var id = workspace.id
      if (id <= 0 || id > root.maxWorkspaceId) continue

      if (root.perMonitor && mine !== "") {
        var owner = root.monitorNameOf(workspace)
        // An unknown owner is kept rather than dropped: better a stray pill
        // than a workspace that silently vanishes from every bar.
        if (owner !== "" && owner !== mine) continue
      }

      // The active workspace stays pinned even when empty, otherwise stepping
      // onto a fresh workspace leaves the bar with nothing to point at.
      if (!root.showEmpty && !root.hasWindows(workspace) && id !== active) continue

      result.push(workspace)
    }

    result.sort(function(left, right) { return left.id - right.id })
    return result
  }

  // --- icons ---------------------------------------------------------------
  function windowClass(toplevel) {
    var ipc = toplevel ? toplevel.lastIpcObject : null
    if (ipc && ipc.class) return ipc.class
    if (toplevel && toplevel.class) return toplevel.class
    if (toplevel && toplevel.appId) return toplevel.appId
    return ""
  }

  function windowTitle(toplevel) {
    if (toplevel && toplevel.title) return toplevel.title
    var ipc = toplevel ? toplevel.lastIpcObject : null
    if (ipc && ipc.title) return ipc.title
    return ""
  }

  function iconFor(toplevel) {
    var cls = root.windowClass(toplevel).toLowerCase()
    var title = root.windowTitle(toplevel).toLowerCase()
    if (!cls && !title) return IconRules.fallback
    return IconRules.resolve(cls, title)
  }

  function iconsFor(workspace) {
    if (!root.showIcons || !workspace) return ""
    var tops = workspace.toplevels ? workspace.toplevels.values : null
    if (!tops || tops.length === 0) return ""

    var shown = root.maxIcons > 0 ? Math.min(tops.length, root.maxIcons) : tops.length
    var icons = []
    for (var i = 0; i < shown; i++) icons.push(root.iconFor(tops[i]))
    if (tops.length > shown) icons.push("+" + (tops.length - shown))
    return icons.join(" ")
  }

  function switchWorkspace(delta) {
    if (!root.bar) return
    var target = delta > 0 ? "e+" + delta : "e" + delta
    root.bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.focus({ workspace = "' + target + '" })'))
  }

  // --- layout --------------------------------------------------------------
  implicitWidth: root.vertical ? root.barSize : strip.implicitWidth + root.trailingGap
  implicitHeight: strip.implicitHeight

  Item {
    id: strip
    anchors.left: parent.left
    anchors.right: root.vertical ? parent.right : undefined
    anchors.top: parent.top
    anchors.bottom: root.vertical ? undefined : parent.bottom
    anchors.topMargin: root.vertical ? Style.spaceReal(80) : Style.spaceReal(4)
    anchors.bottomMargin: root.vertical ? 0 : Style.spaceReal(4)
    implicitWidth: grid.implicitWidth + Style.spaceReal(8)
    implicitHeight: grid.implicitHeight + Style.spaceReal(8)

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      onWheel: function(wheel) {
        root.switchWorkspace(wheel.angleDelta.y > 0 ? 1 : -1)
      }
    }

    GridLayout {
      id: grid
      anchors.left: parent.left
      anchors.leftMargin: Style.spaceReal(4)
      anchors.right: parent.right
      anchors.rightMargin: Style.spaceReal(4)
      anchors.verticalCenter: parent.verticalCenter
      columns: root.vertical ? 1 : Math.max(1, root.visibleWorkspaces.length)
      columnSpacing: root.vertical ? 0 : Style.spaceReal(4)
      rowSpacing: root.vertical ? Style.spaceReal(4) : 0

      Repeater {
        model: root.visibleWorkspaces

        Rectangle {
          id: pill
          required property var modelData

          readonly property var workspace: pill.modelData
          readonly property int workspaceId: pill.workspace ? pill.workspace.id : -1
          readonly property bool active: pill.workspaceId === root.activeId
          readonly property bool urgent: pill.workspace !== null && pill.workspace.urgent === true
          property bool hovered: false

          radius: Style.spaceReal(8)
          color: pill.urgent ? root.urgentColor
            : pill.active ? Util.alpha(root.fgColor, root.monitorFocused ? 0.22 : 0.10)
            : pill.hovered ? Util.alpha(root.fgColor, 0.15)
            : "transparent"
          opacity: pill.active ? 1 : 0.7

          Layout.alignment: Qt.AlignVCenter
          Layout.fillHeight: true
          Layout.fillWidth: root.vertical
          implicitWidth: root.vertical ? (root.barSize - Style.spaceReal(8)) : content.implicitWidth + Style.spaceReal(16)
          implicitHeight: root.vertical ? content.implicitHeight + Style.spaceReal(10) : root.barSize - Style.spaceReal(8)

          Row {
            id: content
            anchors.centerIn: parent
            clip: true
            spacing: Style.spaceReal(3)

            Text {
              text: String(pill.workspaceId)
              color: pill.urgent ? root.bgColor : root.fgColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: root.vertical ? Style.font.icon : Style.font.body
            }

            Text {
              text: root.iconsFor(pill.workspace)
              visible: text !== ""
              color: pill.urgent ? root.bgColor : root.fgColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: root.vertical ? Style.font.icon : Style.font.body
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: pill.hovered = true
            onExited: pill.hovered = false
            onClicked: if (pill.workspace) pill.workspace.activate()
          }
        }
      }
    }
  }
}
