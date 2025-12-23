//
//  Settings.swift
//  MetalRacingGame
//
//  Game settings including Low Battery Mode toggle
//

import SwiftUI
import Foundation

/// Game settings manager
class Settings: ObservableObject {
    static let shared = Settings()
    
    @AppStorage("lowBatteryMode") var isLowBatteryMode: Bool = false {
        didSet {
            // Notify PowerManager
            PowerManager.shared.setLowBatteryModeActive(isLowBatteryMode)
        }
    }
    
    private init() {
        // Initialize settings
    }
}

