import QtQuick
import Quickshell

// Drives BarWidget.qml against tests/arena_server.py with stand-in Quickshell
// and Omarchy modules (tests/stubs), headless. Run by tests/run.sh; prints
// one line per check and exits 1 on any failure.
Item {
  id: root
  readonly property string port: arg("port")
  readonly property string home: arg("home")
  property var widget: null
  property int passed: 0
  property int failed: 0
  property int step: 0

  function arg(name) {
    const a = Qt.application.arguments
    for (let i = 0; i < a.length; i++) if (a[i].indexOf("--" + name + "=") === 0) return a[i].slice(name.length + 3)
    return ""
  }
  function check(name, ok, detail) {
    if (ok) { passed++; console.log("ok   " + name) }
    else { failed++; console.warn("FAIL: " + name + (detail !== undefined ? " (got " + JSON.stringify(detail) + ")" : "")) }
  }
  function make(scenario, settings, kitHome) {
    if (widget) widget.destroy()
    Quickshell.testEnv = {
      SLEY_ARENA_API: "http://127.0.0.1:" + port + "/" + scenario + "/arena/api/",
      SLEY_ARENA_SITE: "https://arena.invalid/arena/",
      SLEY_ARENA_HOME: kitHome ? home : home + "/none",
      HOME: home + "/none"
    }
    Quickshell.launched = []
    const c = Qt.createComponent(Qt.resolvedUrl("../BarWidget.qml"))
    if (c.status !== Component.Ready) { console.warn(c.errorString()); Qt.exit(2); return }
    widget = c.createObject(root, { moduleName: "greyforge.sley-arena", settings: settings })
  }
  // Every Text under an item, popup rows included.
  function texts(item) {
    let out = []
    if (!item) return out
    if (typeof item.text === "string" && item.text !== "" && item.font !== undefined) out.push(item.text)
    const kids = item.children || []
    for (let i = 0; i < kids.length; i++) out = out.concat(texts(kids[i]))
    if (item.item && kids.indexOf(item.item) === -1) out = out.concat(texts(item.item))  // Loader
    return out
  }
  function barText() { return texts(widget).filter(t => t.indexOf("◆") === 0)[0] || "" }
  function serverLog(scenario, done) {
    const x = new XMLHttpRequest()
    x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) done(JSON.parse(x.responseText || "[]")) }
    x.open("GET", "http://127.0.0.1:" + port + "/" + scenario + "/_log")
    x.send()
  }

  // [action, milliseconds to wait before the next one]
  readonly property var steps: [
    [() => make("basic", {}, true), 1200],
    [() => {
      check("login from the kit session under SLEY_ARENA_HOME, API from SLEY_ARENA_API", widget.login === "ada" && widget.phase === "ok", widget.phase)
      check("bar shows my non-house bot", barText() === "◆ #3 Night Shuttle 1612", barText())
      check("site honours SLEY_ARENA_SITE without its trailing slash", widget.site === "https://arena.invalid/arena", widget.site)
      check("latest matches loaded", widget.matches.length === 2, widget.matches.length)
      check("outcome: a win", widget.outcome(widget.matches[0]) === "won 12-9", widget.outcome(widget.matches[0]))
      check("outcome: a draw", widget.outcome(widget.matches[1]) === "drew 4-4", widget.outcome(widget.matches[1]))
      check("outcome: no opponent seat is blank, not -Infinity", widget.outcome({ seats: [{ bot_id: 33, score: 5 }] }) === "")
      check("outcome: a match without seats is blank", widget.outcome({}) === "")
      serverLog("basic", log => {
        check("start-up costs one ladder and one matches request", log.length === 2
          && log[0] === "/ladder?mode=duel&limit=200" && log[1] === "/matches?bot=33&mode=duel&limit=4", log)
      })
      widget.menu = true
    }, 300],
    [() => {
      const all = texts(widget)
      check("popup lists the ladder and my record with draws", all.indexOf("you: #3 Night Shuttle  5W 2L 1D") !== -1, all)
      check("popup lists my matches", all.indexOf("  won 12-9 vs Looper") !== -1, all)
      widget.open(widget.site + "/bot?id=33")
      check("rows open in the browser", Quickshell.launched.length === 1 && Quickshell.launched[0][1] === "https://arena.invalid/arena/bot?id=33", Quickshell.launched)
    }, 50],

    [() => make("race", { login: " @Ada " }), 400],
    [() => { widget.settings = { login: " @Ada ", mode: "brawl" } }, 1500],
    [() => {
      check("a login typed with @ and spaces still matches", widget.login === "Ada", widget.login)
      check("a slow reply for the old mode never overwrites the new one", widget.mode === "brawl" && widget.mine && widget.mine.name === "Fast Brawl", widget.mine)
      check("bar shows the brawl rank", barText() === "◆ #2 Fast Brawl 1555", barText())
    }, 50],

    [() => make("nomatches", { login: "ada" }), 1000],
    [() => {
      check("a failed matches request keeps the rank on the bar", widget.phase === "ok" && barText() === "◆ #3 Night Shuttle 1612", barText())
      check("and leaves no matches", widget.matches.length === 0, widget.matches)
    }, 50],

    [() => make("down", { login: "ada" }), 1000],
    [() => {
      check("an unreachable ladder reads offline", widget.phase === "offline" && barText() === "◆ arena offline", barText())
      check("offline retries within a minute", widget.pollMs <= 60000, widget.pollMs)
    }, 50],

    [() => make("deep", { login: "ada" }), 1200],
    [() => {
      check("a bot ranked below the first 200 is still found", widget.mine && widget.mine.rank === 230, widget.mine)
      serverLog("deep", log => check("by one larger ladder request", log.length === 3 && log[1] === "/ladder?mode=duel&limit=1000", log))
    }, 300],

    [() => make("basic", {}, false), 1000],
    [() => {
      check("without a login the bar shows the leader", widget.login === "" && barText() === "◆ arena #1 House Claude", barText())
      check("and no matches", widget.mine === null && widget.matches.length === 0)
    }, 50]
  ]

  Timer { id: tick; onTriggered: root.next() }
  function next() {
    if (step >= steps.length) {
      console.log("SleyArena: " + passed + " checks passed, " + failed + " failed")
      Qt.exit(failed ? 1 : 0)
      return
    }
    const s = steps[step++]
    try { s[0]() } catch (e) { check("step " + step + " ran without an exception", false, String(e)) }
    tick.interval = s[1]
    tick.start()
  }
  Component.onCompleted: next()
}
