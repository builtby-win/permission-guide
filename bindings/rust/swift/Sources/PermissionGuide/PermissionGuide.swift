import AppKit
import ApplicationServices
import CoreGraphics

public enum PermissionKind: Int, Sendable {
    case accessibility = 0, screenRecording = 1, inputMonitoring = 2

    var paneURL: URL {
        let id: String
        switch self {
        case .accessibility: id = "Privacy_Accessibility"
        case .screenRecording: id = "Privacy_ScreenCapture"
        case .inputMonitoring: id = "Privacy_ListenEvent"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(id)")!
    }
}

public enum PermissionGuide {
    /// Whether the permission is currently granted. Any thread.
    public static func status(_ kind: PermissionKind) -> Bool {
        switch kind {
        case .accessibility: return AXIsProcessTrusted()
        case .screenRecording: return CGPreflightScreenCaptureAccess()
        case .inputMonitoring: return CGPreflightListenEventAccess()
        }
    }

    /// Opens the Privacy pane and docks a drag-to-add guide beside System Settings.
    /// `completion(true)` on grant, `completion(false)` on dismiss. Any thread.
    public static func present(
        _ kind: PermissionKind,
        appURL: URL = Bundle.main.bundleURL,
        appName: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let done = UncheckedBox(completion)
        onMain {
            GuideController.shared.present(kind, appURL: appURL, appName: appName, completion: done.value)
        }
    }

    /// Closes the guide; the pending completion gets `false`. Any thread.
    public static func dismiss() {
        onMain { GuideController.shared.dismiss(granted: false) }
    }
}

struct UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

func onMain(_ work: @escaping @MainActor @Sendable () -> Void) {
    if Thread.isMainThread { MainActor.assumeIsolated(work) }
    else { DispatchQueue.main.async { MainActor.assumeIsolated(work) } }
}
