import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "IconRules.js" as IconRules

// Workspace indicators that show only what is actually there: workspaces with
// windows on them, filtered to the monitor this bar instance lives on, each
// labelled with its number plus an icon per open window.
//
// Everything past that default is opt-in: `showEmpty` keeps every workspace
// number on the bar whether or not it holds windows, `localWorkspaceNumbers`
// relabels per-monitor banks so each bar counts from 1, and `showScratchpad`
// adds a pill for Hyprland's special:scratchpad while something is parked in
// it.
BarWidget {
  id: root
  moduleName: "io.github.thetrueferret.decent-workspaces"

  // --- settings, read from this widget's shell.json layout entry ------------
  readonly property bool perMonitor: root.setting("perMonitor", true)
  readonly property bool showEmpty: root.setting("showEmpty", false)
  readonly property bool showIcons: root.setting("showIcons", true)
  // 0 = show an icon for every window; otherwise overflow collapses to "+N".
  readonly property int maxIcons: root.setting("maxIcons", 0)
  // Collapse windows sharing a glyph into one icon with a "×N" count.
  readonly property bool groupIcons: root.setting("groupIcons", false)
  // How far `showEmpty` fills in numbers. Never hides a workspace that has
  // windows on it, whatever its id.
  readonly property int maxWorkspaceId: root.setting("maxWorkspaceId", 10)
  // Label each monitor's bank as 1..workspacesPerMonitor instead of using the
  // global Hyprland id. Display only; ids and dispatches stay global.
  readonly property bool localWorkspaceNumbers: root.setting("localWorkspaceNumbers", false)
  readonly property int workspacesPerMonitor: Math.max(1, root.setting("workspacesPerMonitor", 10))
  // Workspace ids are global by default. Turn this on to follow Omarchy's
  // per-monitor blocks instead (1-10 on the first monitor, 11-20 on the
  // next, ...): `showEmpty` fills each bar with its own monitor's block and
  // clicking an empty number creates it on that monitor.
  readonly property bool omarchyMonitorBlocks: root.setting("omarchyMonitorBlocks", false)
  // The scratchpad pill appears only while the special workspace holds
  // windows, so it costs nothing on a bar that never uses it.
  readonly property bool showScratchpad: root.setting("showScratchpad", true)
  readonly property string scratchpadName: root.setting("scratchpadName", "special:scratchpad")
  readonly property string scratchpadLabel: root.setting("scratchpadLabel", "S")

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

  // --- Omarchy's per-monitor blocks (opt-in) -------------------------------
  // Omarchy can give every monitor its own block of ten global ids (1-10,
  // 11-20, 21-30, ...), recording which connector owns which block in a state
  // file (default/hypr/monitor-workspaces.lua). Only `omarchyMonitorBlocks`
  // uses it: then the id range stretches to cover every block, and an empty
  // number belongs to the monitor whose block it falls in. With it off the
  // file is ignored and ids are plain global numbers.
  readonly property int blockSize: 10
  property var blockByMonitor: ({})
  property int highestBlock: -1

  function readBlocks(text) {
    var next = {}
    var highest = -1
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length < 3) continue
      var block = parseInt(fields[0], 10)
      if (!(block >= 0)) continue
      if (block > highest) highest = block
      if (fields[1] !== "") next[fields[1]] = block
    }
    root.blockByMonitor = next
    root.highestBlock = highest
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  // With blocks on, the range never cuts a monitor's block in half: the
  // default of 10 would otherwise fill in numbers on the first monitor only.
  readonly property int effectiveMaxId: root.omarchyMonitorBlocks
    ? Math.max(root.maxWorkspaceId, (root.highestBlock + 1) * root.blockSize)
    : root.maxWorkspaceId

  // This bar's own block, or -1 when blocks are off or unassigned.
  readonly property int ownBlock: {
    if (!root.omarchyMonitorBlocks) return -1
    var block = root.blockByMonitor[root.screenName]
    return block === undefined ? -1 : block
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.blockSize)
  }

  function blockOwnerOf(id) {
    if (!root.omarchyMonitorBlocks) return ""
    var blocks = root.blockByMonitor
    var block = root.blockOf(id)
    for (var name in blocks) {
      if (blocks[name] === block) return name
    }
    return ""
  }

  // --- keeping Hyprland's view fresh ---------------------------------------
  // Quickshell does not refetch toplevels or workspaces on its own, so window
  // and workspace events have to poke it or occupancy goes stale. `revision`
  // is bumped alongside so bindings below re-evaluate on events that change
  // nothing Quickshell exposes as a property (focusedmon, urgent).
  property int revision: 0

  readonly property var windowEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle", "windowtitlev2", "activewindow", "activewindowv2", "urgent"]
  readonly property var workspaceEvents: ["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2", "changeworkspaceid", "focusedmon", "configreloaded"]
  // Toggling the scratchpad open or shut changes which monitor is showing it,
  // which only the monitors payload carries.
  readonly property var specialEvents: ["activespecial", "activespecialv2"]

  // Only changes that can affect the client icons require a new snapshot.
  // changeworkspaceid renumbers a workspace under its windows (Omarchy's
  // per-monitor blocks do this), so the snapshot's ids go stale with it.
  readonly property var clientEvents: ["changeworkspaceid", "openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle", "windowtitlev2", "configreloaded", "activespecial", "activespecialv2", "workspace", "workspacev2", "pin", "togglegroup", "moveintogroup", "moveoutofgroup"]

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event.name
      if (root.clientEvents.indexOf(name) !== -1) clientsDebounce.start()
      if (root.windowEvents.indexOf(name) !== -1) {
        Hyprland.refreshToplevels()
        root.revision++
      } else if (root.workspaceEvents.indexOf(name) !== -1) {
        Hyprland.refreshWorkspaces()
        if (name === "configreloaded" && root.rulesNeeded) root.refreshRules()
        root.revision++
      } else if (root.specialEvents.indexOf(name) !== -1) {
        Hyprland.refreshWorkspaces()
        Hyprland.refreshMonitors()
        root.revision++
      }
    }
  }

  // --- model ---------------------------------------------------------------
  // Read authoritative clients instead of workspace.toplevels, whose cached
  // entries can outlive closed windows. Keep the last good snapshot on errors.
  property var liveClients: []
  property bool clientsPending: false
  // Until the first snapshot lands, Quickshell's own lists stand in, so the
  // bar does not start out blank. Fresh at startup, so not yet stale.
  property bool clientsLoaded: false

  function refreshClients() {
    if (clientsProc.running) {
      root.clientsPending = true
      return
    }
    clientsProc.running = true
  }

  function clientsFor(workspace) {
    if (!workspace) return []
    if (!root.clientsLoaded) return workspace.toplevels ? workspace.toplevels.values : []
    // Hidden group tabs are still open windows and retain their icons.
    return root.liveClients.filter(function(client) {
      return client && client.workspace && client.workspace.id === workspace.id &&
        client.mapped !== false
    })
  }

  function hasWindows(workspace) {
    return root.clientsFor(workspace).length > 0
  }

  Timer {
    id: clientsDebounce
    // start() leaves an existing deadline unchanged; no polling while idle.
    interval: 100
    onTriggered: root.refreshClients()
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    onRunningChanged: {
      if (!running && root.clientsPending) {
        root.clientsPending = false
        clientsDebounce.start()
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var listed
        try {
          listed = JSON.parse(text)
        } catch (e) {
          return
        }
        if (!Array.isArray(listed)) return
        root.liveClients = listed
        root.clientsLoaded = true
      }
    }
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

  function workspaceById(id) {
    var _ = root.revision
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  // --- workspace rules, only needed to place empty numbers -----------------
  // Hyprland only reports workspaces that currently exist, so `showEmpty` has
  // to synthesise the missing ids rather than filter live objects — and then
  // decide which bar each synthesised id belongs on. Rules answer that for
  // both sequential (1-5 / 6-10) and interleaved (odds / evens) layouts; live
  // occupancy still wins wherever a workspace has already been created.
  property var workspaceRules: []
  property bool rulesPending: false
  property bool rulesLoaded: false
  readonly property bool rulesNeeded: root.showEmpty && root.perMonitor

  function refreshRules() {
    if (rulesProc.running) {
      root.rulesPending = true
      return
    }
    rulesProc.running = true
  }

  onRulesNeededChanged: if (root.rulesNeeded && !root.rulesLoaded) root.refreshRules()
  Component.onCompleted: {
    root.refreshClients()
    if (root.rulesNeeded) root.refreshRules()
  }

  function ruleMonitorMatches(spec, mine, mineDesc) {
    if (!spec) return false
    var value = String(spec)
    if (value === mine) return true
    if (value.indexOf("desc:") === 0) {
      var desc = value.slice(5)
      return mineDesc !== "" && desc === mineDesc
    }
    return false
  }

  function resolveRuleMonitor(spec) {
    var _ = root.revision
    if (!spec) return ""
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var name = String(monitors[i].name)
      var desc = ""
      var ipc = monitors[i].lastIpcObject
      if (ipc && ipc.description) desc = String(ipc.description)
      else if (monitors[i].description) desc = String(monitors[i].description)
      if (root.ruleMonitorMatches(spec, name, desc)) return name
    }
    return ""
  }

  function ruleOwnerById(maxId) {
    var rules = root.workspaceRules
    var map = {}
    for (var i = 0; i < rules.length; i++) {
      var id = rules[i].id
      if (id <= 0 || id > maxId) continue
      var name = root.resolveRuleMonitor(rules[i].monitor)
      if (name) map[id] = name
    }
    return map
  }

  Process {
    id: rulesProc
    command: ["hyprctl", "-j", "workspacerules"]
    onRunningChanged: {
      if (!running && root.rulesPending) {
        root.rulesPending = false
        root.refreshRules()
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var listed
        try {
          listed = JSON.parse(text || "[]")
        } catch (e) {
          return
        }
        if (!Array.isArray(listed)) return
        var parsed = []
        for (var i = 0; i < listed.length; i++) {
          var row = listed[i]
          if (!row || row.enabled === false) continue
          var id = parseInt(row.workspaceString, 10)
          if (!(id > 0)) continue
          parsed.push({ id: id, monitor: String(row.monitor || "") })
        }
        root.workspaceRules = parsed
        root.rulesLoaded = true
        root.revision++
      }
    }
  }

  // Numeric order, except that with Omarchy blocks on a workspace visiting from
  // another monitor's block goes after this monitor's own, as on the stock bar.
  function compareIds(left, right) {
    if (root.perMonitor && root.ownBlock >= 0) {
      var leftGuest = root.blockOf(left) !== root.ownBlock ? 1 : 0
      var rightGuest = root.blockOf(right) !== root.ownBlock ? 1 : 0
      if (leftGuest !== rightGuest) return leftGuest - rightGuest
    }
    return left - right
  }

  // The pills, as ids. Ids rather than workspace objects, because a
  // synthesised empty number has no object behind it until it is focused.
  readonly property var visibleIds: {
    var _ = root.revision
    var __ = root.workspaceRules
    var ___ = root.rulesLoaded
    var ____ = root.blockByMonitor
    var mine = root.screenName
    var active = root.activeId
    var maxId = root.effectiveMaxId
    var values = Hyprland.workspaces.values

    var mineIds = []
    var occupied = []
    var owners = {}
    var known = []

    // Every id is considered here, however high: a workspace with windows on
    // it always gets a pill, whatever numbering the compositor uses.
    // `maxWorkspaceId` only bounds which empty numbers get filled in.
    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var id = workspace.id
      if (id <= 0) continue

      var owner = root.monitorNameOf(workspace)
      if (owner !== "" && id <= maxId) {
        owners[id] = owner
        known.push(id)
      }

      // An unknown owner is kept rather than dropped: better a stray pill
      // than a workspace that silently vanishes from every bar.
      if (root.perMonitor && mine !== "" && owner !== "" && owner !== mine) continue
      if (id <= maxId) mineIds.push(id)

      // The active workspace stays pinned even when empty, otherwise stepping
      // onto a fresh workspace leaves the bar with nothing to point at.
      if (root.hasWindows(workspace) || id === active) occupied.push(id)
    }
    known.sort(function(left, right) { return left - right })

    // Filled-in lists stop at maxId; live workspaces past it still show.
    function withLive(ids) {
      for (var k = 0; k < occupied.length; k++) {
        if (ids.indexOf(occupied[k]) === -1) ids.push(occupied[k])
      }
      ids.sort(root.compareIds)
      return ids
    }

    if (!root.showEmpty) return withLive([])

    if (!root.perMonitor) {
      var all = []
      for (var n = 1; n <= maxId; n++) all.push(n)
      return withLive(all)
    }

    if (mine === "") return withLive([])

    // Live-only until the first workspacerules read; [] means "not loaded"
    // and "no rules" otherwise, and fallback would flash the wrong layout.
    if (!root.rulesLoaded) {
      var pending = mineIds.slice()
      if (active > 0 && active <= maxId && pending.indexOf(active) === -1) {
        if (owners[active] === undefined || owners[active] === mine) pending.push(active)
      }
      return withLive(pending)
    }

    var ruleOwners = root.ruleOwnerById(maxId)
    var firstOwner = known.length > 0 ? owners[known[0]] : ""
    var pred = 0
    var filled = []
    for (var id2 = 1; id2 <= maxId; id2++) {
      if (owners[id2]) pred = id2
      // A workspace rule that pins the id wins, then Omarchy's per-monitor
      // block (setups that keep global ids can switch Omarchy's renumbering
      // off and pin with rules instead).
      var owner2 = owners[id2] || ruleOwners[id2] || root.blockOwnerOf(id2) || (pred > 0 ? owners[pred] : firstOwner)
      if (owner2 === mine) filled.push(id2)
    }
    if (filled.length === 0 && active > 0 && active <= maxId && (owners[active] === undefined || owners[active] === mine)) {
      filled.push(active)
    }
    return withLive(filled)
  }

  // --- scratchpad -----------------------------------------------------------
  // Hyprland keeps special:scratchpad in the workspace list for as long as it
  // holds windows, whether or not it is currently toggled open. It belongs to
  // no monitor in any lasting sense, so the pill shows up on every bar.
  readonly property var scratchpadWorkspace: {
    var _ = root.revision
    if (!root.showScratchpad) return null
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (String(values[i].name || "") === root.scratchpadName) return values[i]
    }
    return null
  }

  readonly property bool scratchpadVisible: root.showScratchpad && root.hasWindows(root.scratchpadWorkspace)

  // Open on *this* monitor, which is the only place the stash is reachable
  // from right now.
  readonly property bool scratchpadOpen: {
    var _ = root.revision
    if (!root.hyprMonitor) return false
    var ipc = root.hyprMonitor.lastIpcObject
    var special = ipc ? ipc.specialWorkspace : null
    return !!special && String(special.name || "") === root.scratchpadName
  }

  function toggleScratchpad() {
    if (!root.bar) return
    var name = root.scratchpadName.indexOf("special:") === 0 ? root.scratchpadName.slice(8) : root.scratchpadName
    root.bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.workspace.toggle_special("' + name + '")'))
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
    var tops = root.clientsFor(workspace)
    if (!tops || tops.length === 0) return ""

    if (root.groupIcons) return root.groupedIcons(tops)

    var shown = root.maxIcons > 0 ? Math.min(tops.length, root.maxIcons) : tops.length
    var icons = []
    for (var i = 0; i < shown; i++) icons.push(root.iconFor(tops[i]))
    if (tops.length > shown) icons.push("+" + (tops.length - shown))
    return icons.join(" ")
  }

  // Grouped by glyph rather than class, so what looks the same on the bar is
  // shown once. maxIcons caps groups; "+N" still counts the hidden windows.
  function groupedIcons(tops) {
    var order = []
    var counts = {}
    for (var i = 0; i < tops.length; i++) {
      var icon = root.iconFor(tops[i])
      if (counts[icon] === undefined) {
        counts[icon] = 0
        order.push(icon)
      }
      counts[icon]++
    }

    // The count sits after an en space: Nerd Font glyphs draw wider than their
    // advance, so a bare "×" overlaps them, and a full space splits it off.
    var shown = root.maxIcons > 0 ? Math.min(order.length, root.maxIcons) : order.length
    var icons = []
    var hidden = 0
    for (var j = 0; j < order.length; j++) {
      if (j < shown) icons.push(counts[order[j]] > 1 ? order[j] + "\u2002×" + counts[order[j]] : order[j])
      else hidden += counts[order[j]]
    }
    if (hidden > 0) icons.push("+" + hidden)
    return icons.join(" ")
  }

  // Global ids are what Hyprland dispatches on; the label is the only thing
  // local numbering touches.
  function displayWorkspaceId(id) {
    return root.localWorkspaceNumbers ? ((id - 1) % root.workspacesPerMonitor) + 1 : id
  }

  function focusWorkspace(id) {
    var workspace = root.workspaceById(id)
    if (workspace) {
      workspace.activate()
      return
    }
    // A synthesised empty number has nothing to activate, so it goes out as a
    // dispatch, which creates the workspace the same way a keybind would.
    if (!root.bar) return
    // Within this monitor's Omarchy block, go through Omarchy's own focus so
    // the workspace is created on this monitor rather than the focused one.
    if (root.ownBlock >= 0 && root.blockOf(id) === root.ownBlock) {
      var slot = (id - 1) % root.blockSize + 1
      root.bar.run("hyprctl dispatch " + Util.shellQuote('o.workspaces.focus(' + slot + ', "' + root.screenName + '")'))
      return
    }
    root.bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.focus({ workspace = "' + id + '" })'))
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

    GridLayout {
      id: grid
      anchors.left: parent.left
      anchors.leftMargin: Style.spaceReal(4)
      anchors.right: parent.right
      anchors.rightMargin: Style.spaceReal(4)
      anchors.verticalCenter: parent.verticalCenter
      columns: root.vertical ? 1 : Math.max(1, root.visibleIds.length + (root.scratchpadVisible ? 1 : 0))
      columnSpacing: root.vertical ? 0 : Style.spaceReal(4)
      rowSpacing: root.vertical ? Style.spaceReal(4) : 0

      Repeater {
        model: root.visibleIds

        Rectangle {
          id: pill
          required property int modelData

          readonly property int workspaceId: pill.modelData
          readonly property var workspace: root.workspaceById(pill.workspaceId)
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
              text: String(root.displayWorkspaceId(pill.workspaceId))
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
            onClicked: root.focusWorkspace(pill.workspaceId)
          }
        }
      }

      // The scratchpad sits after the numbers, as the place windows go when
      // they are not on any of them.
      Rectangle {
        id: scratchpad
        visible: root.scratchpadVisible
        property bool hovered: false

        radius: Style.spaceReal(8)
        color: scratchpad.hovered ? Util.alpha(root.fgColor, 0.15)
          : root.scratchpadOpen ? Util.alpha(root.fgColor, root.monitorFocused ? 0.22 : 0.10)
          : "transparent"
        opacity: root.scratchpadOpen ? 1 : 0.7

        Layout.alignment: Qt.AlignVCenter
        Layout.fillHeight: true
        Layout.fillWidth: root.vertical
        implicitWidth: !scratchpad.visible ? 0
          : root.vertical ? (root.barSize - Style.spaceReal(8))
          : scratchpadContent.implicitWidth + Style.spaceReal(16)
        implicitHeight: root.vertical ? scratchpadContent.implicitHeight + Style.spaceReal(10) : root.barSize - Style.spaceReal(8)

        Row {
          id: scratchpadContent
          anchors.centerIn: parent
          clip: true
          spacing: Style.spaceReal(3)

          Text {
            text: root.scratchpadLabel
            visible: text !== ""
            color: root.fgColor
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.vertical ? Style.font.icon : Style.font.body
          }

          Text {
            text: root.iconsFor(root.scratchpadWorkspace)
            visible: text !== ""
            color: root.fgColor
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.vertical ? Style.font.icon : Style.font.body
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: scratchpad.hovered = true
          onExited: scratchpad.hovered = false
          onClicked: root.toggleScratchpad()
        }
      }
    }
  }
}
