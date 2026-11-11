public struct IdlePolicy {
    public let threshold: Double
    public private(set) var visible = false
    private var suppressedUntil: Double = 0
    private var previewStartedAt: Double?
    public init(threshold: Double = 300) { self.threshold = threshold }
    public mutating func preview(now: Double) { previewStartedAt = now; visible = true }
    public mutating func hide(now: Double) {
        previewStartedAt = nil
        visible = false
        suppressedUntil = now + threshold
    }
    public mutating func update(now: Double, idle: Double, moved: Bool, paused: Bool, sessionActive: Bool) -> Bool {
        // Cursor movement independently restarts the full quiet period, even if
        // the OS idle counter is stale or does not reflect that event.
        if moved { hide(now: now); return false }
        if !sessionActive || !idle.isFinite {
            previewStartedAt = nil
            visible = false
            return false
        }
        if let previewStartedAt {
            // Ignore pre-preview activity (including the menu click), but dismiss
            // on new keyboard/click activity. Manual previews also work when paused.
            if idle < now - previewStartedAt { hide(now: now); return false }
            visible = true
            return true
        }
        if paused || idle < threshold {
            visible = false
        } else if now >= suppressedUntil { visible = true }
        return visible
    }
}
