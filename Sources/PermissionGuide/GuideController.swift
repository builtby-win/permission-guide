import AppKit

@MainActor
final class GuideController {
    static let shared = GuideController()

    private var panel: GuidePanel?
    private var kind: PermissionKind = .accessibility
    private var completion: ((Bool) -> Void)?
    private var trackTimer: Timer?
    private var pollTimer: Timer?
    private var observer: NSObjectProtocol?
    private var finishing = false
    private var generation = 0

    func present(_ kind: PermissionKind, appURL: URL, appName: String?, completion: @escaping (Bool) -> Void) {
        if self.completion != nil { dismiss(granted: false) }
        self.kind = kind
        self.completion = completion
        finishing = false
        generation += 1

        NSWorkspace.shared.open(kind.paneURL)

        let name = appName
            ?? (Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let p = GuidePanel(appURL: appURL, appName: name)
        panel = p
        p.orderOut(nil)

        trackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkGranted() }
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkGranted() }
        }
        track()
    }

    func dismiss(granted: Bool) {
        guard let cb = completion else { return }
        completion = nil
        trackTimer?.invalidate(); trackTimer = nil
        pollTimer?.invalidate(); pollTimer = nil
        if let o = observer { NSWorkspace.shared.notificationCenter.removeObserver(o); observer = nil }
        panel?.orderOut(nil)
        panel = nil
        cb(granted)
    }

    private func checkGranted() {
        guard !finishing, completion != nil, PermissionGuide.status(kind) else { return }
        finishing = true
        pollTimer?.invalidate(); pollTimer = nil
        panel?.showGranted()
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                self.dismiss(granted: true)
            }
        }
    }

    private func track() {
        guard let panel else { return }
        guard let frame = SettingsWindow.frame() else { panel.orderOut(nil); return }
        let size = panel.frame.size
        let inset: CGFloat = 14
        let w = min(size.width, frame.width - 2 * inset)
        var target = NSRect(x: frame.midX - w / 2, y: frame.minY + inset, width: w, height: size.height)
        target = target.integral
        if panel.frame != target { panel.setFrame(target, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}

enum SettingsWindow {
    static let bundleID = "com.apple.systempreferences"

    /// Frame of the largest on-screen System Settings window in Cocoa coordinates.
    /// On-screen-only listing excludes minimized windows and other Spaces.
    static func frame() -> NSRect? {
        let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map(\.processIdentifier))
        guard !pids.isEmpty,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        var best: CGRect?
        for w in list {
            guard let pid = w[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
                  (w[kCGWindowLayer as String] as? Int) == 0,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  r.width > 200, r.height > 200,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0
            else { continue }
            if best == nil || r.width * r.height > best!.width * best!.height { best = r }
        }
        guard let r = best, let primary = NSScreen.screens.first else { return nil }
        return NSRect(x: r.minX, y: primary.frame.height - r.maxY, width: r.width, height: r.height)
    }
}
