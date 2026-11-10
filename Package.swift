// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "QuietScreen", platforms: [.macOS(.v13)], products: [.executable(name: "QuietScreen", targets: ["QuietScreen"])], targets: [.target(name: "IdlePolicy"), .executableTarget(name: "QuietScreen", dependencies: ["IdlePolicy"]), .executableTarget(name: "PolicyChecks", dependencies: ["IdlePolicy"], path: "Tests/IdlePolicyTests")])
