import Foundation

public enum SaverStyle: String, CaseIterable {
    case drift, stars, ribbons, black
    public var title: String {
        switch self {
        case .drift: return "Blue Drift"
        case .stars: return "Quiet Stars"
        case .ribbons: return "Aurora Ribbons"
        case .black: return "Pure Black"
        }
    }
}

public struct Preferences {
    public static let idleChoices = [1, 2, 5, 10, 15, 30, 60]
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var idleMinutes: Int {
        get {
            let value = defaults.integer(forKey: "idleMinutes")
            return Self.idleChoices.contains(value) ? value : 5
        }
        nonmutating set { defaults.set(Self.idleChoices.contains(newValue) ? newValue : 5, forKey: "idleMinutes") }
    }
    public var style: SaverStyle {
        get { SaverStyle(rawValue: defaults.string(forKey: "saverStyle") ?? "") ?? .drift }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "saverStyle") }
    }
}
