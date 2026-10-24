pragma Singleton
import QtQml

// Test stand-in for Quickshell's singleton: env() reads a map the test sets,
// and execDetached() records the command instead of running it.
QtObject {
  property var testEnv: ({})
  property var launched: []
  function env(name) { return testEnv[name] !== undefined ? testEnv[name] : "" }
  function execDetached(argv) { launched = launched.concat([argv]) }
}
