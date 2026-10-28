// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DeliveryExampleConfig", platforms: [.macOS(.v13)],
  dependencies: [.package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.27.7"))],
  targets: [.executableTarget(name: "DeliveryExampleConfig", dependencies: ["XcodeProj"], path: "Sources")])
