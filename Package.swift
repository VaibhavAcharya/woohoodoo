// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WooHooDoo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WooHooDoo", targets: ["WooHooDoo"])],
    targets: [.executableTarget(name: "WooHooDoo")]
)
