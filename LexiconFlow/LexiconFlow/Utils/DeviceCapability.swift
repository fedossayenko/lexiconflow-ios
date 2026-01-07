//
//  DeviceCapability.swift
//  LexiconFlow
//
//  Created on 2025-01-07.
//

import Foundation

/// Device capability detection for translation services.
///
/// Determines which translation service to use based on device capabilities:
/// - **On-Device Translation**: iOS 26.0+ devices (iPhone 12+)
enum DeviceCapability {

    // MARK: - On-Device Translation Support

    /// Check if device supports iOS 26 Translation framework (OS capability only).
    ///
    /// **IMPORTANT**: This method checks if the iOS 26 Translation framework is AVAILABLE on the device,
    /// NOT whether language packs are downloaded. For actual language pack availability,
    /// use `OnDeviceTranslationService.needsLanguageDownload()` async method.
    ///
    /// The Translation framework requires iOS 26.0+.
    /// It works on all iPhone 12+ models running iOS 26.
    ///
    /// - Returns: `true` if iOS 26+ Translation framework is available (does NOT check language packs)
    static func supportsOnDeviceTranslation() -> Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
}
