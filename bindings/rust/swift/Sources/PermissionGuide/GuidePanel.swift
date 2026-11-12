import AppKit

private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

/// Resolves a dynamic color against `view`'s appearance for use on a CALayer.
private func resolved(_ color: NSColor, in view: NSView) -> CGColor {
    var cg = color.cgColor
    view.effectiveAppearance.performAsCurrentDrawingAppearance { cg = color.cgColor }
    return cg
}

final class GuidePanel: NSPanel {
    private let card: CardView
    private var shown = false

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
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Fades the panel in (with a short slide) or out. Safe to call every tick.
    @MainActor func setShown(_ on: Bool) {
        guard on != shown else { return }
        shown = on
        ignoresMouseEvents = !on
        if on {
            orderFrontRegardless()
            card.slideIn()
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = reduceMotion ? 0.01 : (on ? 0.28 : 0.18)
            animator().alphaValue = on ? 1 : 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { if let self, !self.shown { self.orderOut(nil) } }
        })
    }

    @MainActor func showGranted() { card.showGranted() }

    var onClose: () -> Void {
        get { card.onClose }
        set { card.onClose = newValue }
    }
}

final class CardView: NSView {
    static let size = NSSize(width: 520, height: 80)

    private let badge = Badge()
    private let title = NSTextField(labelWithString: Strings.string(.dragTitle))
    private let hint = NSTextField(labelWithString: Strings.string(.dragHint))
    private let tile: DragTile
    private let close = NSButton()
    private let appName: String
    var onClose: () -> Void = {}

    init(appURL: URL, appName: String) {
        self.appName = appName
        tile = DragTile(appURL: appURL, appName: appName)
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 2)
        layer?.masksToBounds = true

        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .labelColor
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        for l in [title, hint] { l.lineBreakMode = .byTruncatingTail; addSubview(l) }
        addSubview(badge)
        addSubview(tile)
        close.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: Strings.string(.close))?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        close.isBordered = false
        close.contentTintColor = .tertiaryLabelColor
        close.toolTip = Strings.string(.close)
        close.target = self
        close.action = #selector(closeTapped)
        addSubview(close)
        tile.onDragChange = { [badge] in badge.setDragging($0) }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let h = bounds.height, w = bounds.width
        let tw: CGFloat = w >= 480 ? 176 : 144
        // The close button owns the top-right corner; everything else centers on the tile row below it.
        let tileH: CGFloat = 48
        close.frame = NSRect(x: w - 10 - 18, y: h - 8 - 18, width: 18, height: 18)
        tile.frame = NSRect(x: w - 12 - tw, y: 12, width: tw, height: tileH)
        let cy = tile.frame.midY
        badge.frame = NSRect(x: 20, y: cy - 20, width: 40, height: 40)
        let x = badge.frame.maxX + 14
        let tx = tile.isHidden ? w - 20 : tile.frame.minX - 12
        title.frame = NSRect(x: x, y: cy - 1, width: max(0, tx - x), height: 20)
        hint.frame = NSRect(x: x, y: cy - 19, width: max(0, tx - x), height: 16)
    }

    override func viewDidChangeEffectiveAppearance() {
        layer?.backgroundColor = resolved(NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.985, alpha: 1)
        }, in: self)
        layer?.borderColor = resolved(NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.14) : NSColor(white: 0, alpha: 0.12)
        }, in: self)
        badge.refreshColor()
    }
    override func viewDidMoveToWindow() { viewDidChangeEffectiveAppearance() }

    @objc private func closeTapped() { onClose() }

    func slideIn() {
        guard !reduceMotion, let layer else { return }
        let a = CABasicAnimation(keyPath: "transform.translation.y")
        a.fromValue = -12; a.toValue = 0; a.duration = 0.35
        a.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
        layer.add(a, forKey: "slideIn")
    }

    func showGranted() {
        badge.showCheck()
        swap(title, Strings.string(.doneTitle))
        swap(hint, String(format: Strings.string(.doneHint), appName))
        tile.isEnabled = false
        close.isHidden = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? 0.01 : 0.2
            tile.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.tile.isHidden = true; self?.needsLayout = true }
        }
    }

    private func swap(_ field: NSTextField, _ text: String) {
        if !reduceMotion {
            let t = CATransition()
            t.type = .fade; t.duration = 0.2
            field.wantsLayer = true
            field.layer?.add(t, forKey: "swap")
        }
        field.stringValue = text
    }
}

/// Accent circle with an up arrow that bobs toward the list; morphs into a green check on success.
final class Badge: NSView {
    /// Plain CALayer (not a view-backed layer) so its anchor point and transforms are ours alone.
    private let arrow = CALayer()
    private let check = CAShapeLayer()
    private var done = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.cornerCurve = .continuous

        if let symbol = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 18, weight: .bold)) {
            let white = NSImage(size: symbol.size, flipped: false) { rect in
                symbol.draw(in: rect)
                NSColor.white.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            arrow.contents = white
            arrow.bounds = CGRect(origin: .zero, size: white.size)
            arrow.contentsGravity = .resizeAspect
        }
        arrow.position = CGPoint(x: 20, y: 20)
        arrow.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer?.addSublayer(arrow)

        let p = CGMutablePath()
        p.move(to: CGPoint(x: 12.5, y: 20.5)); p.addLine(to: CGPoint(x: 18, y: 14.5)); p.addLine(to: CGPoint(x: 28, y: 26))
        check.path = p
        check.fillColor = nil
        check.strokeColor = NSColor.white.cgColor
        check.lineWidth = 3.2
        check.lineCap = .round; check.lineJoin = .round
        check.strokeEnd = 0
        layer?.addSublayer(check)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        guard window != nil, !done else { return }
        setDragging(false)
    }

    /// Idle: a slow, gentle nudge toward the list (small hop + slight tilt). While dragging: a soft pulse.
    func setDragging(_ dragging: Bool) {
        guard !done, !reduceMotion else { return }
        arrow.removeAllAnimations()
        let ease = CAMediaTimingFunction(name: .easeInEaseOut)
        func loop(_ keyPath: String, _ from: CGFloat, _ to: CGFloat, _ duration: CFTimeInterval) {
            let a = CABasicAnimation(keyPath: keyPath)
            a.fromValue = from; a.toValue = to; a.duration = duration
            a.autoreverses = true; a.repeatCount = .infinity; a.timingFunction = ease
            arrow.add(a, forKey: keyPath)
        }
        if dragging {
            loop("transform.scale", 0.94, 1.08, 1.0)
        } else {
            loop("transform.translation.y", -1, 3, 0.9)
            loop("transform.rotation.z", -4 * .pi / 180, 4 * .pi / 180, 1.8)
        }
    }

    func refreshColor() {
        layer?.backgroundColor = resolved(done ? .systemGreen : .controlAccentColor, in: self)
    }

    func showCheck() {
        done = true
        let from = layer?.backgroundColor
        refreshColor()
        arrow.removeAllAnimations()
        check.strokeEnd = 1
        guard !reduceMotion else { arrow.opacity = 0; return }

        let color = CABasicAnimation(keyPath: "backgroundColor")
        color.fromValue = from; color.duration = 0.25
        layer?.add(color, forKey: "recolor")

        let out = CABasicAnimation(keyPath: "opacity")
        out.fromValue = 1; out.toValue = 0; out.duration = 0.15
        arrow.opacity = 0
        arrow.add(out, forKey: "out")

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0; draw.toValue = 1; draw.duration = 0.3; draw.beginTime = CACurrentMediaTime() + 0.1
        draw.fillMode = .backwards
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        check.add(draw, forKey: "draw")

        let pop = CASpringAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.85; pop.toValue = 1; pop.damping = 11; pop.initialVelocity = 6; pop.duration = pop.settlingDuration
        layer?.add(pop, forKey: "pop")
    }
}

final class DragTile: NSView, NSDraggingSource {
    var isEnabled = true
    var onDragChange: (Bool) -> Void = { _ in }
    private let appURL: URL
    private let icon: NSImage
    private let iconView: NSImageView
    private let name: NSTextField
    private let grip = NSImageView()
    private var downEvent: NSEvent?
    private var dragged = false
    private var hovering = false { didSet { updateFill(animated: true) } }

    init(appURL: URL, appName: String) {
        self.appURL = appURL
        icon = NSWorkspace.shared.icon(forFile: appURL.path)
        iconView = NSImageView(image: icon)
        name = NSTextField(labelWithString: appName)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        addSubview(iconView)
        name.font = .systemFont(ofSize: 13, weight: .medium)
        name.lineBreakMode = .byTruncatingTail
        addSubview(name)
        grip.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        grip.contentTintColor = .tertiaryLabelColor
        addSubview(grip)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        toolTip = Strings.string(.dragTitle)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let h = bounds.height
        iconView.frame = NSRect(x: 10, y: (h - 36) / 2, width: 36, height: 36)
        grip.frame = NSRect(x: bounds.width - 10 - 16, y: (h - 16) / 2, width: 16, height: 16)
        name.frame = NSRect(x: 54, y: (h - 18) / 2, width: max(0, grip.frame.minX - 54 - 4), height: 18)
    }

    private func updateFill(animated: Bool) {
        let base = hovering && isEnabled ? 0.10 : 0.05
        let color = resolved(NSColor.labelColor.withAlphaComponent(base), in: self)
        if animated, !reduceMotion, let from = layer?.backgroundColor {
            let a = CABasicAnimation(keyPath: "backgroundColor")
            a.fromValue = from; a.duration = 0.12
            layer?.add(a, forKey: "hover")
        }
        layer?.backgroundColor = color
    }

    override func viewDidChangeEffectiveAppearance() { updateFill(animated: false) }
    override func viewDidMoveToWindow() { updateFill(animated: false) }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        downEvent = event
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, !dragged, let down = downEvent else { return }
        let p0 = down.locationInWindow, p1 = event.locationInWindow
        guard hypot(p1.x - p0.x, p1.y - p0.y) > 3 else { return }
        dragged = true

        let item = NSDraggingItem(pasteboardWriter: appURL as NSURL)
        let size = NSSize(width: 64, height: 64)
        let origin = convert(p1, from: nil)
        item.setDraggingFrame(NSRect(x: origin.x - size.width / 2, y: origin.y - size.height / 2,
                                     width: size.width, height: size.height), contents: icon)
        lift(up: true)
        onDragChange(true)
        beginDraggingSession(with: [item], event: down, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        downEvent = nil
        NSCursor.openHand.set()
    }

    /// Spring-scales the tile and dims it while its icon is being dragged.
    private func lift(up: Bool) {
        guard let layer else { return }
        let target: CGFloat = up ? 1.04 : 1
        let opacity: Float = up ? 0.45 : 1
        guard !reduceMotion else { layer.transform = CATransform3DMakeScale(target, target, 1); layer.opacity = opacity; return }
        let s = CASpringAnimation(keyPath: "transform.scale")
        s.fromValue = layer.presentation()?.value(forKeyPath: "transform.scale") ?? 1
        s.toValue = target; s.damping = 14; s.stiffness = 260; s.mass = 1
        s.duration = s.settlingDuration
        layer.transform = CATransform3DMakeScale(target, target, 1)
        layer.add(s, forKey: "lift")
        let o = CABasicAnimation(keyPath: "opacity")
        o.fromValue = layer.presentation()?.opacity ?? 1; o.toValue = opacity; o.duration = 0.15
        layer.opacity = opacity
        layer.add(o, forKey: "dim")
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragged = false
        downEvent = nil
        lift(up: false)
        onDragChange(false)
    }
}
