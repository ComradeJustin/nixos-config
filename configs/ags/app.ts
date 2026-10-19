// Process entry: AGS ring overlay. Mod+Space runs `ags-toggle`, which sends
// "toggle" here via `ags request` (a second `ags run` becomes a client).
import app from "ags/gtk4/app"
import { cssVariables } from "./colors"
import style from "./style.scss"
import { Overlay } from "./widget/Overlay"

let overlay: Overlay

app.start({
  css: cssVariables() + style,
  requestHandler(argv: string[], respond: (response: string) => void) {
    switch (argv[0]) {
      case "toggle":
        overlay.toggle()
        return respond("ok")
      case "dive":
        return respond(overlay.ipcDive(argv[1] ?? "") ? "ok" : "unknown pane")
      case "filter":
        return respond(overlay.ipcFilter(argv.slice(1).join(" ")))
      case "move":
        return respond(overlay.ipcMove(argv[1] ?? "j") ? "ok" : "not dived")
      case "key":
        return respond(overlay.ipcKey(argv[1] ?? "") ? "ok" : "unknown key")
      case "state":
        return respond(overlay.ipcState())
      case "frames":
        return respond(overlay.ipcFrames())
      default:
        respond("unknown command")
    }
  },
  main() {
    overlay = new Overlay()
  },
})
