public struct IdlePolicy {
    public let threshold: Double
    public private(set) var visible = false
    private var suppressedUntil: Double = 0
    public init(threshold: Double = 300) { self.threshold = threshold }
    public mutating func hide(now: Double) { visible = false; suppressedUntil = now + threshold }
    public mutating func update(now: Double, idle: Double, moved: Bool, paused: Bool, sessionActive: Bool) -> Bool {
        // Cursor movement independently restarts the full quiet period, even if
        // the OS idle counter is stale or does not reflect that event.
        if moved { hide(now: now); return false }
        if paused || !sessionActive || !idle.isFinite || idle < threshold {
            visible = false
        } else if now >= suppressedUntil { visible = true }
        return visible
    }
}
