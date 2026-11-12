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
    private var fadingOut = false
    private var placedBelow: Bool?
    private var animatingUntil = Date.distantPast
    private var reduceMotionNow: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var generation = 0

    func present(_ kind: PermissionKind, appURL: URL, appName: String?, completion: @escaping (Bool) -> Void) {
        if self.completion != nil { dismiss(granted: false) }
        self.kind = kind
        self.completion = completion
        finishing = false
        fadingOut = false
        placedBelow = nil
        generation += 1

        NSWorkspace.shared.open(kind.paneURL)

        let name = resolveAppName(appName, appURL: appURL)
        let p = GuidePanel(appURL: appURL, appName: name)
        p.onClose = { [weak self] in self?.dismiss(granted: false) }
        panel = p

        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }
        RunLoop.main.add(t, forMode: .common)
        trackTimer = t
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                self.fadingOut = true
                self.panel?.setShown(false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self, self.generation == token else { return }
                        self.dismiss(granted: true)
                    }
                }
            }
        }
    }

    private func track() {
        guard let panel else { return }
        if fadingOut { return }
        // Pinned to Settings: visible only while Settings is the frontmost app (stays pending otherwise).
        let settingsActive = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == SettingsWindow.bundleID
        guard (settingsActive || finishing), let frame = SettingsWindow.frame() else { panel.setShown(false); return }
        let size = panel.frame.size
        let inset: CGFloat = 14, gap: CGFloat = 10
        let w = min(size.width, frame.width - 2 * inset)
        let screen = NSScreen.screens.max {
            $0.frame.intersection(frame).width * $0.frame.intersection(frame).height
                < $1.frame.intersection(frame).width * $1.frame.intersection(frame).height
        }
        // Prefer docking just below the window; fall back to inside its bottom edge.
        let belowY = frame.minY - gap - size.height
        let below = belowY >= (screen?.visibleFrame.minY ?? 0)
        let y = below ? belowY : frame.minY + inset
        let target = NSRect(x: frame.midX - w / 2, y: y, width: w, height: size.height).integral
        if let placedBelow, placedBelow != below, panel.isVisible, !reduceMotionNow {
            animatingUntil = Date().addingTimeInterval(0.3)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(target, display: true)
            }
        } else if Date() >= animatingUntil, panel.frame != target {
            panel.setFrame(target, display: true)
        }
        placedBelow = below
        panel.setShown(true)
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

/// Explicit name, else bundle display name, else bundle name, else the file name sans extension.
func resolveAppName(_ explicit: String?, appURL: URL) -> String {
    let info = Bundle(url: appURL)
    for candidate in [explicit, info?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                      info?.object(forInfoDictionaryKey: "CFBundleName") as? String] {
        if let c = candidate, !c.isEmpty { return c }
    }
    return appURL.deletingPathExtension().lastPathComponent
}
