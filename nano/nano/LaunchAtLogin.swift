//
//  LaunchAtLogin.swift
//  nano
//
//  Created by tnixc on 5/10/2025.
//

import SwiftUI
import ServiceManagement
import Combine

/// Helper for managing launch at login functionality
struct LaunchAtLogin {
    /// Check if the app is set to launch at login
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // Fallback for older macOS versions
            return false
        }
    }
    
    /// Enable or disable launch at login
    /// - Parameter enabled: Whether to enable launch at login
    /// - Throws: Error if the operation fails
    static func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    // Already enabled
                    return
                }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    // Already disabled
                    return
                }
                try SMAppService.mainApp.unregister()
            }
        }
    }
}

/// View model for launch at login toggle
@MainActor
class LaunchAtLoginViewModel: ObservableObject {
    @Published var isEnabled: Bool = false
    
    init() {
        self.isEnabled = LaunchAtLogin.isEnabled
    }
    
    func toggle() {
        do {
            try LaunchAtLogin.setEnabled(!isEnabled)
            isEnabled = LaunchAtLogin.isEnabled
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }
}