// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Package.swift
//  SHVideoPlayer
//
//  Created by Sahib Hussain on 01/09/23.
//

import PackageDescription

let package = Package(
    name: "SHVideoPlayer",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SHVideoPlayer",
            targets: ["SHVideoPlayer"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SHVideoPlayer"),
        .testTarget(
            name: "SHVideoPlayerTests",
            dependencies: ["SHVideoPlayer"]),
    ]
)
