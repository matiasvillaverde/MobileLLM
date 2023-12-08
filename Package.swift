// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MobileLLM",
    platforms: [
        .macOS(.v11),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MobileLLM",
            type: .dynamic,
            targets: ["Facade"])
    ],
    targets: [
        .testTarget(
            name: "Tests",
            dependencies: ["VectorDB", "Facade", "LLM"],
            resources: [.copy("Resources/RWKV.bin")]
        ),
        .target(
            name: "Facade",
            dependencies: ["LLM", "VectorDB"],
            path: "Sources/Facade"
        ),
        .target(
            name: "LLM",
            dependencies: ["CoreLLM"],
            path: "Sources/LLM"
        ),
        .target(
            name: "VectorDB",
            path: "Sources/VectorDB"
        ),
        .target(
            name: "CoreLLM",
            path: "Sources/CoreLLM",
            sources: [
                "ggml/ggml.c", "exception_helper.cpp", "ggml/k_quants.c",
                "ggml/ggml-alloc.c", "ggml/ggml-backend.c", "ggml/ggml-metal.m", "ggml/common.cpp",
                "gpt_spm.cpp", "package_helper.m", "exception_helper_objc.mm", "ggml/train.cpp",
                "ggml/ggml_dadbed9.c", "ggml/k_quants_dadbed9.c", "ggml/ggml-alloc_dadbed9.c",
                "ggml/ggml-metal_dadbed9.m", "ggml/ggml_d925ed.c", "ggml/ggml_d925ed-alloc.c",
                "ggml/ggml_d925ed-metal.m", "rwkv/rwkv.cpp", "llama/llama.cpp", "llama/llama_dadbed9.cpp"
            ],
            resources: [
                .copy("tokenizers")
            ],
            publicHeadersPath: "spm-headers",
            cSettings: [
                .unsafeFlags(["-O3"]),
                .unsafeFlags(["-DNDEBUG"]),
                .unsafeFlags(["-mfma", "-mfma", "-mavx", "-mavx2", "-mf16c", "-msse3", "-mssse3"]), // for Intel CPU
                .unsafeFlags(["-DGGML_METAL_NDEBUG"]),
                .unsafeFlags(["-DGGML_USE_ACCELERATE"]),
                .unsafeFlags(["-DGGML_USE_METAL"]),
                .unsafeFlags(["-DGGML_USE_K_QUANTS"]),
                .unsafeFlags(["-DSWIFT_PACKAGE"]),
                .unsafeFlags(["-pthread"]),
                .unsafeFlags(["-fno-objc-arc"]),
                .unsafeFlags(["-w"])
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("MetalPerformanceShaders")
            ]
        )],

    cxxLanguageStandard: .cxx20
)
