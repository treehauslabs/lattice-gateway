// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LatticeGateway",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "lattice-gateway", targets: ["LatticeGateway"])
    ],
    dependencies: [
        .package(path: "../lattice"),
        .package(path: "../AcornMemoryWorker"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "LatticeGateway",
            dependencies: [
                .product(name: "Lattice", package: "lattice"),
                .product(name: "AcornMemoryWorker", package: "AcornMemoryWorker"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]),
    ]
)
