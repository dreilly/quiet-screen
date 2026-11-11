import AppKit
import CoreGraphics
import IdlePolicy

@MainActor final class DriftView: NSView {
    var phase: Double = 0
    var style: SaverStyle = .drift
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        switch style {
        case .black: return
        case .stars:
            for i in 0..<65 {
                let seed = Double(i)
                let x = bounds.width * ((seed * 0.61803398875 + phase * 0.001).truncatingRemainder(dividingBy: 1))
                let y = bounds.height * ((seed * 0.41421356 + phase * 0.0005).truncatingRemainder(dividingBy: 1))
                let light = 0.07 + 0.035 * sin(phase * 0.3 + seed)
                NSColor(calibratedRed: light * 0.6, green: light * 0.8, blue: light, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: i % 4 == 0 ? 2 : 1, height: i % 4 == 0 ? 2 : 1)).fill()
            }
            return
        case .ribbons:
            for band in 0..<3 {
                let path = NSBezierPath()
                for step in 0...100 {
                    let x = Double(bounds.width) * Double(step) / 100
                    let y = Double(bounds.height) * (0.5 + 0.22 * sin(x / max(Double(bounds.width), 1) * 5 + phase * 0.12 + Double(band)) + 0.12 * sin(phase * 0.07 + Double(band)))
                    if step == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
                }
                NSColor(calibratedRed: 0.018, green: 0.045 + Double(band) * 0.008, blue: 0.07, alpha: 1).setStroke()
                path.lineWidth = 2 + Double(band); path.stroke()
            }
            return
        case .drift: break
        }
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
    private var cursorHidden = false
    let preferences = Preferences()
    var policy = IdlePolicy()
    var idleItems: [NSMenuItem] = []
    var styleItems: [NSMenuItem] = []
    var summaryItem: NSMenuItem!
    var lastMouse = NSEvent.mouseLocation
    var paused = false
    var sessionActive = true
    var pauseItem: NSMenuItem!
    let start = ProcessInfo.processInfo.systemUptime
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        policy = IdlePolicy(threshold: Double(preferences.idleMinutes * 60))
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "Quiet Screen")
        let menu = NSMenu()
        summaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: ""); summaryItem.isEnabled = false; menu.addItem(summaryItem)
        let settings = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu(); settings.submenu = settingsMenu; menu.addItem(settings)
        let idleRoot = NSMenuItem(title: "Start after", action: nil, keyEquivalent: "")
        let idleMenu = NSMenu(); idleRoot.submenu = idleMenu; settingsMenu.addItem(idleRoot)
        for minutes in Preferences.idleChoices {
            let item = NSMenuItem(title: "\(minutes) minute\(minutes == 1 ? "" : "s")", action: #selector(selectIdle(_:)), keyEquivalent: "")
            item.tag = minutes; item.target = self; idleMenu.addItem(item); idleItems.append(item)
        }
        let styleRoot = NSMenuItem(title: "Visual", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu(); styleRoot.submenu = styleMenu; settingsMenu.addItem(styleRoot)
        for (index, style) in SaverStyle.allCases.enumerated() {
            let item = NSMenuItem(title: style.title, action: #selector(selectStyle(_:)), keyEquivalent: "")
            item.tag = index; item.target = self; styleMenu.addItem(item); styleItems.append(item)
        }
        refreshSettingsMenu()
        let test = NSMenuItem(title: "Test cover now", action: #selector(testCover), keyEquivalent: ""); test.target = self; menu.addItem(test)
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
            let view = DriftView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.style = preferences.style
            window.contentView = view
            window.orderFrontRegardless(); windows.append(window)
        }
        // CGDisplayHideCursor alone only works for the active app. Opt into
        // background cursor control without taking focus from the user's app.
        // The hide count spans all displays: hide once, then show once on close.
        if !windows.isEmpty && !cursorHidden && BackgroundCursor.enable() {
            cursorHidden = CGDisplayHideCursor(CGMainDisplayID()) == .success
        }
    }
    func closeCover() {
        if cursorHidden {
            if CGDisplayShowCursor(CGMainDisplayID()) == .success { cursorHidden = false }
        }
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll()
    }
    func refreshSettingsMenu() {
        summaryItem.title = "Quiet Screen · \(preferences.idleMinutes) min · \(preferences.style.title)"
        for item in idleItems { item.state = item.tag == preferences.idleMinutes ? .on : .off }
        for item in styleItems { item.state = SaverStyle.allCases[item.tag] == preferences.style ? .on : .off }
    }
    @objc func selectIdle(_ sender: NSMenuItem) {
        preferences.idleMinutes = sender.tag
        policy = IdlePolicy(threshold: Double(preferences.idleMinutes * 60))
        hideCover(); refreshSettingsMenu()
    }
    @objc func selectStyle(_ sender: NSMenuItem) {
        preferences.style = SaverStyle.allCases[sender.tag]
        hideCover(); refreshSettingsMenu()
    }
    @objc func testCover() {
        // Let the menu dismiss before showing the cover and hiding the cursor.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessionActive else { return }
            self.lastMouse = NSEvent.mouseLocation
            self.policy.preview(now: ProcessInfo.processInfo.systemUptime)
            self.tick()
        }
    }
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
