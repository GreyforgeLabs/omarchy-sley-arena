pragma Singleton
import QtQml

QtObject {
  readonly property QtObject font: QtObject { readonly property int body: 13; readonly property string family: "sans-serif" }
  readonly property QtObject spacing: QtObject { readonly property int popupPadding: 12 }
  readonly property QtObject bar: QtObject { readonly property int sizeHorizontal: 26 }
  function space(n) { return n }
  function spaceReal(n) { return n }
}
