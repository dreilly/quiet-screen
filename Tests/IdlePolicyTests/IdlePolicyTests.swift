func checkFalse(_ value: Bool) { precondition(!value) }
func checkTrue(_ value: Bool) { precondition(value) }
import Foundation
import IdlePolicy
// Separate-process persistence smoke test, isolated from the real app domain.
if CommandLine.arguments.count == 3 {
    let mode = CommandLine.arguments[1], name = CommandLine.arguments[2]
    let store = UserDefaults(suiteName: name)!
    let prefs = Preferences(defaults: store)
    if mode == "--persist-write" {
        prefs.idleMinutes = 15; prefs.style = .ribbons
        precondition(store.synchronize()); exit(0)
    }
    if mode == "--persist-read" {
        precondition(prefs.idleMinutes == 15 && prefs.style == .ribbons)
        store.removePersistentDomain(forName: name); _ = store.synchronize()
        print("PASS: preferences survived process restart"); exit(0)
    }
}
struct IdlePolicyTests {
    func testThresholdAndActivity() {
        var p = IdlePolicy()
        checkFalse(p.update(now: 299, idle: 299, moved: false, paused: false, sessionActive: true))
        checkTrue(p.update(now: 300, idle: 300, moved: false, paused: false, sessionActive: true))
        checkFalse(p.update(now: 301, idle: 301, moved: true, paused: false, sessionActive: true))
        checkFalse(p.update(now: 302, idle: 0, moved: false, paused: false, sessionActive: true))
    }
    func testPauseAndInactiveSession() {
        var p = IdlePolicy()
        checkFalse(p.update(now: 500, idle: 500, moved: false, paused: true, sessionActive: true))
        checkFalse(p.update(now: 500, idle: 500, moved: false, paused: false, sessionActive: false))
        checkFalse(p.update(now: 500, idle: .infinity, moved: false, paused: false, sessionActive: true))
    }
    func testMovementResetsFullIntervalWithStaleOSIdle() {
        var p = IdlePolicy()
        checkTrue(p.update(now: 500, idle: 500, moved: false, paused: false, sessionActive: true))
        checkFalse(p.update(now: 501, idle: 501, moved: true, paused: false, sessionActive: true))
        checkFalse(p.update(now: 501.1, idle: 501.1, moved: false, paused: false, sessionActive: true))
        checkFalse(p.update(now: 600, idle: 600, moved: true, paused: false, sessionActive: true))
        checkFalse(p.update(now: 899.9, idle: 899.9, moved: false, paused: false, sessionActive: true))
        checkTrue(p.update(now: 900, idle: 900, moved: false, paused: false, sessionActive: true))
    }
    func testPreviewBypassesIdleAndCooldownUntilMovement() {
        var p = IdlePolicy()
        p.hide(now: 20)
        p.preview(now: 21)
        checkTrue(p.visible)
        checkTrue(p.update(now: 21.1, idle: 0.2, moved: false, paused: false, sessionActive: true))
        checkTrue(p.update(now: 21.2, idle: 0.3, moved: false, paused: false, sessionActive: true))
        checkFalse(p.update(now: 22, idle: 999, moved: true, paused: false, sessionActive: true))
        checkFalse(p.update(now: 321.9, idle: 999, moved: false, paused: false, sessionActive: true))
        checkTrue(p.update(now: 322, idle: 999, moved: false, paused: false, sessionActive: true))
    }
    func testPreviewDismissesOnKeyboardOrClickActivity() {
        var p = IdlePolicy()
        p.preview(now: 100)
        checkTrue(p.update(now: 100.1, idle: 0.3, moved: false, paused: false, sessionActive: true))
        checkFalse(p.update(now: 102, idle: 0.01, moved: false, paused: false, sessionActive: true))
        checkFalse(p.update(now: 401, idle: 999, moved: false, paused: false, sessionActive: true))
        checkTrue(p.update(now: 402, idle: 999, moved: false, paused: false, sessionActive: true))
    }
    func testPreviewWhilePausedAndExplicitHide() {
        var p = IdlePolicy()
        p.preview(now: 100)
        checkTrue(p.update(now: 101, idle: 1.1, moved: false, paused: true, sessionActive: true))
        p.hide(now: 102)
        checkFalse(p.visible)
        checkFalse(p.update(now: 103, idle: 999, moved: false, paused: false, sessionActive: true))
        checkFalse(p.update(now: 500, idle: 999, moved: false, paused: true, sessionActive: true))
    }
    func testPreviewStopsForInactiveSessionOrInvalidIdle() {
        var p = IdlePolicy()
        p.preview(now: 100)
        checkFalse(p.update(now: 101, idle: 1.1, moved: false, paused: false, sessionActive: false))
        checkFalse(p.update(now: 102, idle: 2.1, moved: false, paused: false, sessionActive: true))
        p.preview(now: 103)
        checkFalse(p.update(now: 104, idle: .infinity, moved: false, paused: false, sessionActive: true))
        checkFalse(p.update(now: 105, idle: 5.1, moved: false, paused: false, sessionActive: true))
    }
    func testHideCooldown() {
        var p = IdlePolicy(); p.hide(now: 100)
        checkFalse(p.update(now: 399, idle: 999, moved: false, paused: false, sessionActive: true))
        checkTrue(p.update(now: 400, idle: 999, moved: false, paused: false, sessionActive: true))
    }
}

let tests = IdlePolicyTests()
tests.testThresholdAndActivity()
tests.testPauseAndInactiveSession()
tests.testHideCooldown()
tests.testMovementResetsFullIntervalWithStaleOSIdle()
tests.testPreviewBypassesIdleAndCooldownUntilMovement()
tests.testPreviewDismissesOnKeyboardOrClickActivity()
tests.testPreviewWhilePausedAndExplicitHide()
tests.testPreviewStopsForInactiveSessionOrInvalidIdle()
print("PASS: 33 assertions covering threshold, activity, pause, inactive session, invalid idle, hide cooldown and manual preview")

let suite = "local.quietscreen.tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let prefs = Preferences(defaults: defaults)
precondition(prefs.idleMinutes == 5 && prefs.style == .drift)
for minutes in Preferences.idleChoices {
    prefs.idleMinutes = minutes
    let reloaded = Preferences(defaults: UserDefaults(suiteName: suite)!)
    precondition(reloaded.idleMinutes == minutes)
    var p = IdlePolicy(threshold: Double(reloaded.idleMinutes * 60))
    p.hide(now: 100)
    checkFalse(p.update(now: 100 + Double(minutes * 60) - 0.1, idle: 99999, moved: false, paused: false, sessionActive: true))
    checkTrue(p.update(now: 100 + Double(minutes * 60), idle: 99999, moved: false, paused: false, sessionActive: true))
}
for style in SaverStyle.allCases {
    prefs.style = style
    precondition(Preferences(defaults: UserDefaults(suiteName: suite)!).style == style)
}
defaults.set(-99, forKey: "idleMinutes"); defaults.set("unknown", forKey: "saverStyle")
precondition(prefs.idleMinutes == 5 && prefs.style == .drift)
print("PASS: settings reload, all seven idle intervals, four styles and invalid-value fallbacks")
