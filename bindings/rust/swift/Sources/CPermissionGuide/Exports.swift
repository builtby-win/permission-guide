import Foundation
import PermissionGuide

private func kindFrom(_ k: Int32) -> PermissionKind? {
    switch k {
    case 0: return .accessibility
    case 1: return .screenRecording
    case 2: return .inputMonitoring
    default: return nil
    }
}

@_cdecl("pg_status")
public func pg_status(_ kind: Int32) -> Int32 {
    guard let k = kindFrom(kind) else { return 0 }
    return PermissionGuide.status(k) ? 1 : 0
}

@_cdecl("pg_present")
public func pg_present(
    _ kind: Int32,
    _ appPath: UnsafePointer<CChar>?,
    _ appName: UnsafePointer<CChar>?,
    _ cb: (@convention(c) (Int32, UnsafeMutableRawPointer?) -> Void)?,
    _ ctx: UnsafeMutableRawPointer?
) {
    guard let k = kindFrom(kind) else { cb?(0, ctx); return }
    let url = appPath.map { URL(fileURLWithPath: String(cString: $0)) } ?? Bundle.main.bundleURL
    let name = appName.map { String(cString: $0) }
    nonisolated(unsafe) let ctx = ctx
    PermissionGuide.present(k, appURL: url, appName: name) { granted in
        cb?(granted ? 1 : 0, ctx)
    }
}

@_cdecl("pg_dismiss")
public func pg_dismiss() {
    PermissionGuide.dismiss()
}
