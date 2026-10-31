import AppKit

final class GuidePanel: NSPanel {
    private let card: CardView

    @MainActor
    init(appURL: URL, appName: String) {
        card = CardView(appURL: appURL, appName: appName)
        super.init(contentRect: NSRect(origin: .zero, size: CardView.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = card
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    @MainActor func showGranted() { card.showGranted() }
}

private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

final class CardView: NSView {
    static let size = NSSize(width: 500, height: 76)

    private let fill = NSView()
    private let arrow = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let tile: DragTile
    private let appName: String

    init(appURL: URL, appName: String) {
        self.appName = appName
        tile = DragTile(appURL: appURL, appName: appName)
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        fill.wantsLayer = true
        fill.layer?.cornerRadius = 18
        fill.layer?.cornerCurve = .continuous
        fill.layer?.borderWidth = 0.5
        fill.layer?.masksToBounds = true
        fill.frame = bounds
        fill.autoresizingMask = [.width, .height]
        addSubview(fill)

        let cfg = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        arrow.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        arrow.contentTintColor = .systemBlue
        arrow.frame = NSRect(x: 18, y: (bounds.height - 36) / 2, width: 36, height: 36)
        addSubview(arrow)

        label.stringValue = "Drop \(appName) in the list of apps above"
        label.font = .systemFont(ofSize: 12.5, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.frame = NSRect(x: 66, y: (bounds.height - 36) / 2, width: 190, height: 36)
        label.cell?.isScrollable = false
        addSubview(label)

        tile.frame = NSRect(x: bounds.width - 18 - 150, y: (bounds.height - 44) / 2, width: 150, height: 44)
        addSubview(tile)
        // Label gets the remaining space between arrow and tile.
        label.frame.size.width = tile.frame.minX - label.frame.minX - 10
        updateColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { updateColors() }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            fill.layer?.backgroundColor = (dark ? NSColor(white: 0.18, alpha: 0.96) : NSColor(white: 0.97, alpha: 0.96)).cgColor
            fill.layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    func showGranted() {
        let cfg = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        arrow.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        arrow.contentTintColor = .systemGreen
        label.stringValue = "\(appName) added"
        tile.isHidden = true
        label.frame.size.width = bounds.width - label.frame.minX - 18
        if !reduceMotion, let layer = arrow.layer {
            let a = CABasicAnimation(keyPath: "transform.scale")
            a.fromValue = 0.6; a.toValue = 1; a.duration = 0.2
            layer.add(a, forKey: "pop")
        }
    }
}

final class DragTile: NSView, NSDraggingSource {
    private let appURL: URL
    private let icon: NSImage
    private var downEvent: NSEvent?
    private var dragged = false

    init(appURL: URL, appName: String) {
        self.appURL = appURL
        icon = NSWorkspace.shared.icon(forFile: appURL.path)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5
        let iv = NSImageView(image: icon)
        iv.frame = NSRect(x: 8, y: 6, width: 32, height: 32)
        addSubview(iv)
        let l = NSTextField(labelWithString: appName)
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.lineBreakMode = .byTruncatingTail
        l.frame = NSRect(x: 46, y: 13, width: 96, height: 18)
        l.autoresizingMask = [.width]
        addSubview(l)
        toolTip = "Drag into the list above"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
    override func viewDidMoveToWindow() { viewDidChangeEffectiveAppearance() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func mouseDown(with event: NSEvent) { downEvent = event }

    override func mouseDragged(with event: NSEvent) {
        guard !dragged, let down = downEvent else { return }
        let p0 = down.locationInWindow, p1 = event.locationInWindow
        guard hypot(p1.x - p0.x, p1.y - p0.y) > 3 else { return }
        dragged = true

        let item = NSDraggingItem(pasteboardWriter: appURL as NSURL)
        let size = NSSize(width: 64, height: 64)
        let origin = convert(p1, from: nil)
        item.setDraggingFrame(NSRect(x: origin.x - size.width / 2, y: origin.y - size.height / 2,
                                     width: size.width, height: size.height), contents: icon)
        liftAnimation(up: true)
        beginDraggingSession(with: [item], event: down, source: self)
    }

    override func mouseUp(with event: NSEvent) { downEvent = nil }

    private func liftAnimation(up: Bool) {
        guard !reduceMotion, let layer else { return }
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = up ? 1 : 0.4; a.toValue = up ? 0.4 : 1; a.duration = 0.15
        layer.opacity = up ? 0.4 : 1
        layer.add(a, forKey: "lift")
        if up {
            let s = CABasicAnimation(keyPath: "transform.scale")
            s.fromValue = 1; s.toValue = 1.06; s.duration = 0.15
            layer.add(s, forKey: "liftScale")
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragged = false
        downEvent = nil
        layer?.opacity = 1
        liftAnimation(up: false)
    }
}
