import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "Shared.js" as Shared

// Follow changed Super+L files. A directory rescan is not a new layout choice.
// Presses the generated Lua recorded (W.note_mode) arrive in `liveDir` and are
// deleted once read, so each counts exactly once.
Item {
  id: root

  property var config: null
  property var workspaceMonitors: ({})
  property bool active: true
  property var snapshot: null
  property var pendingLive: ({})
  property var scanLive: ({})
  property bool scanAgain: false
  property bool dirReady: false

  signal followed(var document)

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string dir: stateHome + "/omarchy/workspace-layouts"
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
  readonly property string liveDir: runtimeDir !== "" ? runtimeDir + "/omarchy-workspace-layout/modes" : ""

  function scan() {
    if (!root.active || !root.config) return
    if (scanProcess.running) {
      scanAgain = true
      return
    }
    scanAgain = false
    scanLive = pendingLive
    pendingLive = ({})
    scanProcess.running = true
  }

  function ingest(text) {
    if (!active || !config) {
      var pending = pendingLive
      for (var key in scanLive) pending[key] = true
      pendingLive = pending
      return
    }
    consume(Model.liveRecordIds(text))
    var current = Model.parseOmarchyToggleSnapshot(text)
    var changes = Model.omarchyToggleChanges(snapshot, current, scanLive).filter(function(change) {
      return change.removed === undefined || !Shared.wasForgotten(change.workspace)
    })
    snapshot = current
    var next = Model.followOmarchyToggles(config, changes, { workspaceMonitors: workspaceMonitors })
    if (next) followed(next)
  }

  onActiveChanged: if (active) scanTimer.restart()

  Process {
    id: ensureDir
    running: true
    command: root.liveDir !== "" ? ["mkdir", "-p", "--", root.dir, root.liveDir] : ["mkdir", "-p", "--", root.dir]
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      dirWatch.reload()
      root.dirReady = true
      scanTimer.restart()
    }
  }

  FileView {
    id: dirWatch
    path: root.dir
    watchChanges: true
    printErrors: false
    onFileChanged: scanTimer.restart()
  }

  // Only while this copy is the one following: an inactive copy (the panel,
  // while the service runs) must not keep a second inotifywait alive.
  Process {
    id: watchProcess
    running: root.dirReady && root.active
    command: ["inotifywait", "-m", "-q",
      "-e", "close_write", "-e", "create", "-e", "moved_to", "--format", "%w%f", root.dir]
      .concat(root.liveDir !== "" ? [root.liveDir] : [])
    stdout: SplitParser {
      onRead: function(line) {
        var path = String(line)
        if (root.liveDir !== "" && path.indexOf(root.liveDir + "/") === 0) {
          scanTimer.restart()
          return
        }
        var match = /\/(\d+|default)\.lua$/.exec(path)
        var key = match ? (match[1] === "default" ? "default" : Model.normalizeWorkspaceId(match[1])) : null
        if (key === null) return
        var pending = root.pendingLive
        pending[key] = true
        root.pendingLive = pending
        scanTimer.restart()
      }
    }
  }

  Process {
    id: scanProcess
    // The fingerprint includes nanoseconds. Polls also detect a rewrite with identical content.
    command: ["sh", "-c",
      "[ -d \"$1\" ] && [ -r \"$1\" ] || exit 1; " +
      "for file in \"$1\"/*.lua; do [ -f \"$file\" ] || continue; " +
      "name=${file##*/}; id=${name%.lua}; case $id in default) ;; ''|*[!0-9]*) continue;; esac; " +
      "stamp=$(stat -Lc '%i:%y:%z:%s' -- \"$file\") || continue; " +
      "content=$(cat -- \"$file\") || continue; " +
      "printf '\\036%s\\037%s\\037%s\\n' \"$id\" \"$stamp\" \"$content\"; done; " +
      "[ -n \"$2\" ] && [ -d \"$2\" ] || exit 0; " +
      "for file in \"$2\"/*.lua; do [ -f \"$file\" ] || continue; " +
      "name=${file##*/}; id=${name%.lua}; case $id in *[!0-9-]*|-*|*-) continue;; esac; " +
      "content=$(head -c 512 -- \"$file\") || continue; " +
      "printf '\\036live:%s\\037-\\037%s\\n' \"$id\" \"$content\"; done",
      "workspace-layout-toggles", root.dir, root.liveDir]
    stdout: StdioCollector { id: scanReply; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && exitStatus === 0) root.ingest(String(scanReply.text || ""))
      else {
        var pending = root.pendingLive
        for (var key in root.scanLive) pending[key] = true
        root.pendingLive = pending
      }
      if (root.scanAgain) scanTimer.restart()
    }
  }

  function forget(ids) {
    var command = ["rm", "-f", "--"]
    var known = snapshot
    for (var i = 0; i < ids.length; i++) {
      var key = Model.normalizeWorkspaceId(ids[i])
      if (key === null) continue
      command.push(dir + "/" + key + ".lua")
      // Our own deletion is not Omarchy handing the workspace back to the
      // default, so no copy of this watcher may read it as one.
      Shared.forget(key)
      if (known && known[key]) delete known[key]
    }
    if (command.length === 3) return
    forgetProcess.command = command
    forgetProcess.running = true
  }

  Process { id: forgetProcess }

  // Press records are read once; whatever their mode (floating included),
  // they are done with as soon as a scan has seen them.
  function consume(ids) {
    if (liveDir === "" || ids.length === 0) return
    var command = ["rm", "-f", "--"]
    for (var i = 0; i < ids.length; i++) command.push(liveDir + "/" + ids[i] + ".lua")
    consumeProcess.command = command
    consumeProcess.running = true
  }

  Process { id: consumeProcess }

  Timer {
    id: scanTimer
    interval: 80
    onTriggered: root.scan()
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.active
    onTriggered: scanTimer.restart()
  }
}
