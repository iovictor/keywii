import AppKit

// Line-buffer stdout so `print()` diagnostics show up immediately when
// redirected to a log file instead of sitting in a block buffer.
setvbuf(stdout, nil, _IOLBF, 0)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
