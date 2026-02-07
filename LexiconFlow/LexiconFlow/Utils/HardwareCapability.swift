//
//  HardwareCapability.swift
//  LexiconFlow
//
//  Device hardware capability detection for intelligent feature routing
//
//  **Purpose**: Detect device capabilities to route requests to optimal providers:
//  - On-device generative audio (A19 Pro)
//  - Cloud TTS (A14-A18)
//  - Hardware-accelerated ML
//

import Foundation
import OSLog

/// Device hardware capability detection
///
/// Detects device capabilities to intelligently route AI and audio requests
/// to optimal providers (on-device vs cloud) based on hardware support.
enum HardwareCapability {
    private static let logger = Logger(subsystem: "com.lexiconflow.hardware", category: "HardwareCapability")

    /// Chip generation
    enum Chip: String, Sendable {
        case a14, a15, a16, a17, a18, a19
        case unknown

        /// Current device chip
        static var current: Chip {
            #if targetEnvironment(simulator)
                // Simulator: Assume a19 for testing
                return .a19
            #else
                var size = 0
                sysctlbyname("hw.machine", nil, &size, nil, 0)
                var machine = [CChar](repeating: 0, count: size)
                sysctlbyname("hw.machine", &machine, &size, nil, 0)
                let model = String(cString: machine)

                // Map device models to chip generations
                // Reference: https://www.theiphonewiki.com/wiki/Models
                switch model {
                // iPhone 12 series (A14 Bionic)
                case let s where s.hasPrefix("iPhone13,"):
                    return .a14

                // iPhone 13 series (A15 Bionic)
                case let s where s.hasPrefix("iPhone14,"):
                    return .a15

                // iPhone 14 series (A16 Bionic)
                case let s where s.hasPrefix("iPhone15,"):
                    return .a16

                // iPhone 15 series (A17 Pro)
                case let s where s.hasPrefix("iPhone16,"):
                    // A17 Pro for Pro models, A16 for non-Pro
                    if s.contains("iPhone16,1") || s.contains("iPhone16,2") {
                        return .a17 // iPhone 15 Pro/Pro Max
                    } else {
                        return .a16 // iPhone 15/Plus
                    }

                // iPhone 16 series (A18)
                case let s where s.hasPrefix("iPhone17,"):
                    return .a18

                // iPhone 17 series (A19)
                case let s where s.hasPrefix("iPhone18,"):
                    return .a19

                // Unknown device
                default:
                    logger.warning("Unknown device model: \(model)")
                    return .unknown
                }
            #endif
        }

        /// Human-readable chip name
        var name: String {
            switch self {
            case .a14: "A14 Bionic"
            case .a15: "A15 Bionic"
            case .a16: "A16 Bionic"
            case .a17: "A17 Pro"
            case .a18: "A18"
            case .a19: "A19 Pro"
            case .unknown: "Unknown"
            }
        }
    }

    /// Whether device supports on-device generative audio
    ///
    /// **A18/A19**: Uses on-device generative audio (AVSpeechSynthesizer .premium)
    /// **A14-A17**: Uses cloud TTS
    static var supportsOnDeviceGenerativeAudio: Bool {
        switch Chip.current {
        case .a18, .a19:
            true
        default:
            false
        }
    }

    /// Whether device supports hardware-accelerated ML
    static var supportsHardwareML: Bool {
        switch Chip.current {
        case .a14, .a15, .a16, .a17, .a18, .a19:
            true
        case .unknown:
            false
        }
    }

    /// Device RAM in GB
    static var totalRAM: UInt64 {
        #if targetEnvironment(simulator)
            // Simulator: Assume 8GB
            return 8
        #else
            var size = 0
            var sizeLen = MemoryLayout<Int>.size
            sysctlbyname("hw.memsize", &size, &sizeLen, nil, 0)
            let bytes = UInt64(bitPattern: size)
            return bytes / 1_000_000_000 // Convert to GB
        #endif
    }

    /// Whether device has sufficient RAM for heavy ML operations
    static var hasHighPerformanceMemory: Bool {
        totalRAM >= 6 // 6GB+ RAM
    }

    /// Get device capability summary for logging
    static var summary: String {
        """
        LexiconFlow Hardware Capability:
        - Chip: \(Chip.current.name)
        - Supports On-Device Audio: \(supportsOnDeviceGenerativeAudio)
        - Supports Hardware ML: \(supportsHardwareML)
        - Total RAM: \(totalRAM)GB
        - High Performance Memory: \(hasHighPerformanceMemory)
        """
    }
}
