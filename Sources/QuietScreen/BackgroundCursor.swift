import CoreGraphics
import Darwin
import Foundation

/// Allows cursor hiding without activating the app or taking keyboard focus.
/// This WindowServer property is undocumented; resolve it dynamically so a
/// future macOS change fails gracefully instead of preventing app launch.
enum BackgroundCursor {
    static func enable() -> Bool {
        guard let framework = dlopen(
            "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
            RTLD_LAZY | RTLD_LOCAL
        ) else {
            NSLog("Quiet Screen: could not load background cursor support")
            return false
        }
        defer { dlclose(framework) }
        guard let connectionSymbol = dlsym(framework, "_CGSDefaultConnection"),
              let propertySymbol = dlsym(framework, "CGSSetConnectionProperty") else {
            NSLog("Quiet Screen: background cursor APIs are unavailable on this macOS version")
            return false
        }
        typealias GetConnection = @convention(c) () -> Int32
        typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        let getConnection = unsafeBitCast(connectionSymbol, to: GetConnection.self)
        let setProperty = unsafeBitCast(propertySymbol, to: SetProperty.self)
        let connection = getConnection()
        let result = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        if result != CGError.success.rawValue {
            NSLog("Quiet Screen: enabling background cursor hiding failed (%d)", result)
            return false
        }
        return true
    }
}
