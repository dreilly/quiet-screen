import AppKit
import CoreGraphics
import IdlePolicy

@MainActor final class DriftView: NSView {
    var phase: Double = 0
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        for i in 0..<4 {
            let k = Double(i)
            let x = bounds.width * (0.5 + 0.43 * sin(phase * (0.19 + k * 0.023) + k * 1.9))
            let y = bounds.height * (0.5 + 0.43 * cos(phase * (0.14 + k * 0.019) + k * 2.1))
            let r = min(bounds.width, bounds.height) * (0.14 + k * 0.018)
            let color = NSColor(calibratedRed: 0.015, green: 0.035 + k * 0.004, blue: 0.055 + k * 0.007, alpha: 1)
            let gradient = NSGradient(starting: color, ending: .black)!
            gradient.draw(in: NSBezierPath(ovalIn: NSRect(x: x-r, y: y-r, width: r*2, height: r*2)), relativeCenterPosition: .zero)
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var timer: Timer?
    var windows: [NSWindow] = []
    var policy = IdlePolicy()
    var lastMouse = NSEvent.mouseLocation
    var paused = false
    var sessionActive = true
    var pauseItem: NSMenuItem!
    let start = ProcessInfo.processInfo.systemUptime
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Quiet Screen")
        let menu = NSMenu()
        let label = NSMenuItem(title: "Quiet Screen · after 5 minutes idle", action: nil, keyEquivalent: ""); label.isEnabled = false; menu.addItem(label)
        pauseItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: ""); pauseItem.target = self; menu.addItem(pauseItem)
        let hide = NSMenuItem(title: "Hide cover", action: #selector(hideCover), keyEquivalent: ""); hide.target = self; menu.addItem(hide)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Quiet Screen", action: #selector(quitApp), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        status.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(sessionResigned), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(sessionBecameActive), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(sessionResigned), name: NSWorkspace.screensDidSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(sessionBecameActive), name: NSWorkspace.screensDidWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(hideCover), name: .init("local.quietscreen.hide"), object: nil)
        // Poll aggregate idle time and cursor coordinates only; no event taps or input injection.
        timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let mouse = NSEvent.mouseLocation
        let moved = mouse != lastMouse; lastMouse = mouse
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        let visible = policy.update(now: now, idle: idle, moved: moved, paused: paused, sessionActive: sessionActive)
        if visible {
            if windows.isEmpty { showCover() }
            for window in windows { if let view = window.contentView as? DriftView { view.phase = now - start; view.needsDisplay = true } }
        } else if !windows.isEmpty { closeCover() }
    }
    func showCover() {
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            // Ordinary non-key windows; never touch macOS loginwindow or screen saver.
            window.level = .popUpMenu
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.backgroundColor = .black; window.isOpaque = true; window.hasShadow = false
            window.ignoresMouseEvents = true; window.isReleasedWhenClosed = false
            window.contentView = DriftView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.orderFrontRegardless(); windows.append(window)
        }
    }
    func closeCover() { for window in windows { window.orderOut(nil); window.close() }; windows.removeAll() }
    @objc func hideCover() { policy.hide(now: ProcessInfo.processInfo.systemUptime); closeCover() }
    @objc func togglePause() { paused.toggle(); pauseItem.title = paused ? "Resume" : "Pause"; hideCover() }
    @objc func screensChanged() { closeCover() }
    @objc func sessionResigned() { sessionActive = false; hideCover() }
    @objc func sessionBecameActive() { sessionActive = true; hideCover() }
    @objc func quitApp() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); closeCover() }
}

if CommandLine.arguments.contains("--hide") {
    DistributedNotificationCenter.default().postNotificationName(.init("local.quietscreen.hide"), object: nil, userInfo: nil, deliverImmediately: true)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
