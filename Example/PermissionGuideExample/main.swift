import AppKit
import PermissionGuide

let kinds: [String: PermissionKind] = [
    "accessibility": .accessibility,
    "screen-recording": .screenRecording,
    "input-monitoring": .inputMonitoring,
]
guard CommandLine.arguments.count > 1, let kind = kinds[CommandLine.arguments[1]] else {
    print("usage: PermissionGuideExample <accessibility|screen-recording|input-monitoring> [/path/to/App.app]")
    exit(2)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let url = CommandLine.arguments.count > 2
    ? URL(fileURLWithPath: CommandLine.arguments[2]) : Bundle.main.bundleURL
print("status:", PermissionGuide.status(kind))
PermissionGuide.present(kind, appURL: url, appName: CommandLine.arguments.count > 2 ? nil : "PermissionGuideExample") { granted in
    print("completion:", granted)
    exit(granted ? 0 : 1)
}
app.run()
