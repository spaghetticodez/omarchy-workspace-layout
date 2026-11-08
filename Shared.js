.pragma library

// State shared by every copy of the plugin's QML in one shell.
//
// A `.pragma library` script is instantiated once per engine and handed to
// every importer, unlike Model.js, which each importing component evaluates
// on its own. The bar widget's panel (one per screen) and the service are
// separate components, so this is the only place they can see each other.

// Super+L files this plugin deleted itself, by workspace number, with the
// time it happened. Omarchy 4.5 also deletes these files, and that deletion
// means "follow the default again"; ours (after a swap) does not.
var forgotten = ({})

function forget(key) {
  forgotten[String(key)] = Date.now()
}

function wasForgotten(key, now) {
  var at = forgotten[String(key)]
  if (at === undefined) return false
  if ((now === undefined ? Date.now() : now) - at > 15000) {
    delete forgotten[String(key)]
    return false
  }
  return true
}

// Mounted copies of Service.qml. Omarchy 4.x mounts the service for every
// enabled plugin that declares one, bar widget or not, so the panel and the
// service both ran the Super+L watcher and both re-applied every config
// change (upstream issue #14). While a service runs, it owns that background
// work and the panel keeps only what the user does in it.
var services = 0

function serviceStarted() {
  services += 1
}

function serviceStopped() {
  if (services > 0) services -= 1
}

function serviceRunning() {
  return services > 0
}
