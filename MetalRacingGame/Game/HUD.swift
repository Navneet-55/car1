//
//  HUD.swift
//  MetalRacingGame
//
//  Minimal, premium HUD for F1 racing with DRS, tires, and pit info
//

import SwiftUI
import simd

/// Driving mode
enum DrivingMode {
    case practice
    case qualifying
    case race
    
    var displayName: String {
        switch self {
        case .practice: return "PRACTICE"
        case .qualifying: return "QUALIFYING"
        case .race: return "RACE"
        }
    }
}

/// DRS HUD state
enum DRSDisplayState {
    case unavailable
    case available
    case active
    
    var color: Color {
        switch self {
        case .unavailable: return .gray.opacity(0.5)
        case .available: return .green
        case .active: return .green
        }
    }
    
    var text: String {
        switch self {
        case .unavailable: return "DRS"
        case .available: return "DRS"
        case .active: return "DRS"
        }
    }
}

/// Minimal, premium HUD overlay
struct RacingHUD: View {
    let speed: Float // km/h
    let gear: Int
    let mode: DrivingMode
    let showLapTimer: Bool
    let lapTime: TimeInterval?
    
    // New HUD elements
    let drsState: DRSDisplayState
    let tireCompound: String
    let tireWear: Float // 0-100
    let isPitLimiterActive: Bool
    let isLowBatteryModeActive: Bool
    
    var body: some View {
        ZStack {
            // Top bar with mode and DRS
            VStack {
                HStack(alignment: .top) {
                    // Mode indicator
                    Text(mode.displayName)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // DRS indicator
                    DRSIndicator(state: drsState)
                    
                    // Low Battery Mode indicator
                    if isLowBatteryModeActive {
                        LowBatteryIndicator()
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            
            // Pit limiter warning (center screen when active)
            if isPitLimiterActive {
                VStack {
                    Spacer()
                    PitLimiterIndicator()
                    Spacer()
                    Spacer()
                }
            }
            
            // Bottom HUD elements
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Speed, gear, and tire info
                    VStack(alignment: .leading, spacing: 8) {
                        // Speed
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(speed))")
                                .font(.system(size: 64, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("km/h")
                                .font(.system(size: 20, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Gear
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("GEAR")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(gear)")
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        // Tire compound indicator
                        TireIndicator(compound: tireCompound, wear: tireWear)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Lap timer (optional)
                    if showLapTimer {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("LAP TIME")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            if let lapTime = lapTime {
                                Text(formatLapTime(lapTime))
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            } else {
                                Text("--:--.---")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                }
                .padding(.bottom, 40)
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func formatLapTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

/// DRS indicator component
struct DRSIndicator: View {
    let state: DRSDisplayState
    
    var body: some View {
        HStack(spacing: 6) {
            // DRS icon/box
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(state == .active ? Color.green : Color.black.opacity(0.6))
                    .frame(width: 50, height: 28)
                
                if state == .active {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 50, height: 28)
                }
                
                Text("DRS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(state == .unavailable ? .gray : .white)
            }
            
            // Availability indicator
            if state == .available {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .modifier(PulseAnimation())
            }
        }
    }
}

/// Tire compound indicator
struct TireIndicator: View {
    let compound: String
    let wear: Float
    
    private var compoundColor: Color {
        switch compound {
        case "SOFT": return .red
        case "MEDIUM": return .yellow
        case "HARD": return .white
        default: return .gray
        }
    }
    
    private var wearColor: Color {
        if wear < 50 {
            return .green
        } else if wear < 70 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Compound badge
            Text(compound.prefix(1))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(compoundColor)
                .cornerRadius(4)
            
            // Wear bar
            VStack(alignment: .leading, spacing: 2) {
                Text("TIRE")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(wearColor)
                            .frame(width: geo.size.width * CGFloat((100 - wear) / 100), height: 4)
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
    }
}

/// Pit limiter indicator (warning style)
struct PitLimiterIndicator: View {
    @State private var isFlashing = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))
            
            Text("PIT LIMITER")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
            
            Text("80")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("km/h")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(isFlashing ? 1.0 : 0.5), lineWidth: 2)
        )
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                isFlashing = true
            }
        }
    }
}

/// Pulse animation modifier
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

/// HUD manager for game integration
class HUDManager: ObservableObject {
    @Published var speed: Float = 0
    @Published var gear: Int = 1
    @Published var mode: DrivingMode = .practice
    @Published var showLapTimer: Bool = true
    @Published var lapTime: TimeInterval? = nil
    
    // New HUD data
    @Published var drsState: DRSDisplayState = .unavailable
    @Published var tireCompound: String = "MEDIUM"
    @Published var tireWear: Float = 0
    @Published var isPitLimiterActive: Bool = false
    @Published var isLowBatteryModeActive: Bool = false
    
    func update(speed: Float, gear: Int) {
        self.speed = speed
        self.gear = gear
    }
    
    func setMode(_ mode: DrivingMode) {
        self.mode = mode
    }
    
    func updateLapTime(_ time: TimeInterval?) {
        self.lapTime = time
    }
    
    func updateDRS(available: Bool, active: Bool) {
        if active {
            drsState = .active
        } else if available {
            drsState = .available
        } else {
            drsState = .unavailable
        }
    }
    
    func updateTires(compound: TireCompound, wear: Float) {
        self.tireCompound = compound.displayName
        self.tireWear = wear
    }
    
    func updatePitLimiter(active: Bool) {
        self.isPitLimiterActive = active
    }
}

/// Low Battery Mode indicator
struct LowBatteryIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "battery.25")
                .foregroundColor(.orange)
                .font(.system(size: 12))
            Text("LOW POWER")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .cornerRadius(4)
    }
}

// Default initializer for backwards compatibility
extension RacingHUD {
    init(speed: Float, gear: Int, mode: DrivingMode, showLapTimer: Bool, lapTime: TimeInterval?) {
        self.speed = speed
        self.gear = gear
        self.mode = mode
        self.showLapTimer = showLapTimer
        self.lapTime = lapTime
        self.drsState = .unavailable
        self.tireCompound = "MEDIUM"
        self.tireWear = 0
        self.isPitLimiterActive = false
        self.isLowBatteryModeActive = false
    }
}
