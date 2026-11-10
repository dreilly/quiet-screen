func checkFalse(_ value: Bool) { precondition(!value) }
func checkTrue(_ value: Bool) { precondition(value) }
import Foundation
import IdlePolicy
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
print("PASS: 15 assertions covering threshold, activity, pause, inactive session, invalid idle and hide cooldown")
