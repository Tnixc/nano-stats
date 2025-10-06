import Combine

// macos/Sources/UI/MenuBarView.swift
import SwiftUI

// MARK: - Usage Color Constants

enum UsageGradient {
    static let colors: [Color] = [
        Color(red: 0.0, green: 0.5, blue: 1.0), // Blue (0%)
        Color(red: 0.0, green: 0.8, blue: 1.0), // Cyan (25%)
        Color(red: 1.0, green: 0.9, blue: 0.0), // Yellow (50%)
        Color(red: 1.0, green: 0.6, blue: 0.0), // Orange (75%)
        Color(red: 1.0, green: 0.2, blue: 0.0), // Red (100%)
    ]

    static let gradient = LinearGradient(
        colors: colors,
        startPoint: .leading,
        endPoint: .trailing
    )

    static let verticalGradient = LinearGradient(
        colors: colors,
        startPoint: .bottom,
        endPoint: .top
    )

    static func colorForPercentage(_ percentage: Double) -> Color {
        let clamped = min(max(percentage, 0), 100)
        let scaled = clamped / 25.0 // 0-4 range for 5 stops
        let index = Int(scaled)
        let _ = scaled - Double(index)

        if index >= colors.count - 1 {
            return colors.last ?? colors[0]
        }

        return colors[index]
    }
}

enum BatteryGradient {
    static func gradientForPercentage(_ percentage: Double) -> LinearGradient {
        let clamped = min(max(percentage, 0), 100)

        if clamped >= 80 {
            // 80%-100%: light green to green
            return LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.9, blue: 0.6), // Light green
                    Color(red: 0.2, green: 0.8, blue: 0.2), // Green
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if clamped >= 60 {
            // 60%-80%: yellow to light green
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.9, blue: 0.0), // Yellow
                    Color(red: 0.6, green: 0.9, blue: 0.6), // Light green
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if clamped >= 40 {
            // 40%-60%: orange to yellow
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.0), // Orange
                    Color(red: 1.0, green: 0.9, blue: 0.0), // Yellow
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if clamped >= 20 {
            // 20%-40%: red to orange
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.2, blue: 0.0), // Red
                    Color(red: 1.0, green: 0.6, blue: 0.0), // Orange
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            // 0%-20%: dark red to red
            return LinearGradient(
                colors: [
                    Color(red: 0.8, green: 0.1, blue: 0.1), // Dark red
                    Color(red: 1.0, green: 0.2, blue: 0.0), // Red
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    static func colorForPercentage(_ percentage: Double) -> Color {
        let clamped = min(max(percentage, 0), 100)

        if clamped >= 80 {
            return Color(red: 0.2, green: 0.8, blue: 0.2) // Green
        } else if clamped >= 60 {
            return Color(red: 0.6, green: 0.9, blue: 0.6) // Light green
        } else if clamped >= 40 {
            return Color(red: 1.0, green: 0.9, blue: 0.0) // Yellow
        } else if clamped >= 20 {
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        } else {
            return Color(red: 1.0, green: 0.2, blue: 0.0) // Red
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var memoryMonitor: MemoryDataModel

    var body: some View {
        VStack(spacing: 16) {
            // CPU Stats Card
            VStack(spacing: 0) {
                CPUStatsRow(
                    userPercentage: memoryMonitor.cpuUserPercentage,
                    systemPercentage: memoryMonitor.cpuSystemPercentage,
                    totalPercentage: memoryMonitor.cpuTotalPercentage,
                    history: memoryMonitor.cpuHistory
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )

            // Memory Stats Card
            VStack(spacing: 0) {
                MemoryStatsRow(
                    memoryBreakdown: memoryMonitor.memoryBreakdown,
                    usagePercentage: memoryMonitor.usagePercentage,
                    memoryHistory: memoryMonitor.memoryHistory
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )

            // Battery Stats Card
            VStack(spacing: 0) {
                BatteryStatsRow(
                    batteryPercentage: memoryMonitor.batteryPercentage,
                    isCharging: memoryMonitor.batteryIsCharging,
                    timeRemaining: memoryMonitor.batteryTimeRemaining,
                    uptime: memoryMonitor.systemUptime
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )

            // Bottom Actions
            HStack(spacing: 12) {
                ControlCenterIconButton(
                    icon: "arrow.clockwise",
                    action: {
                        memoryMonitor.refresh()
                    }
                )

                Spacer()

                ControlCenterIconButton(
                    icon: "xmark",
                    action: {
                        NSApplication.shared.terminate(nil)
                    },
                    destructive: true
                )
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

// MARK: - Memory Stats Row Component

struct MemoryStatsRow: View {
    let memoryBreakdown: SystemMemoryMonitor.MemoryBreakdown?
    let usagePercentage: Double
    let memoryHistory: [Double]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("RAM")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Memory chart
            VerticalBarGraph(history: memoryHistory, height: 60)
                .padding(.horizontal, 16)

            // Pressure bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pressure")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(usagePercentage))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)

                        LinearGradient(
                            colors: UsageGradient.colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(
                            width: geometry.size.width,
                            height: 6
                        )
                        .mask(
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 3)
                                    .frame(
                                        width: geometry.size.width
                                            * CGFloat(usagePercentage / 100.0),
                                        height: 6
                                    )
                                Spacer()
                            }
                        )
                        .shadow(
                            color: UsageGradient.colorForPercentage(
                                usagePercentage
                            ).opacity(0.6),
                            radius: 4,
                            x: 0,
                            y: 0
                        )
                        .shadow(
                            color: UsageGradient.colorForPercentage(
                                usagePercentage
                            ).opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 0
                        )
                    }
                }.padding(.horizontal, 2)
                    .frame(height: 6)
            }
            .padding(.horizontal, 16)

            if let breakdown = memoryBreakdown {
                VStack(alignment: .leading, spacing: 8) {
                    MemoryDetailRow(
                        label: "Active",
                        value: formatBytesGB(breakdown.active_bytes),
                        showBar: false
                    )

                    MemoryDetailRow(
                        label: "Swap File",
                        value: formatBytesGB(breakdown.swap_used_bytes),
                        showBar: true,
                        barPercentage: breakdown.swap_total_bytes > 0
                            ? Double(breakdown.swap_used_bytes)
                            / Double(breakdown.swap_total_bytes) * 100.0 : 0
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private func formatBytesGB(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Vertical Bar Graph Component (Reusable)

struct VerticalBarGraph: View {
    let history: [Double]
    var height: CGFloat = 40.0

    var body: some View {
        GeometryReader { geometry in
            let maxValue = 100.0 // Percentage scale
            let barWidth = geometry.size.width / CGFloat(history.count)

            ZStack(alignment: .bottom) {
                // Background with glow
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .shadow(
                        color: UsageGradient.colorForPercentage(
                            history.max() ?? 0
                        ).opacity(0.5),
                        radius: 12,
                        x: 0,
                        y: 0
                    )
                    .shadow(
                        color: UsageGradient.colorForPercentage(
                            history.max() ?? 0
                        ).opacity(0.3),
                        radius: 6,
                        x: 0,
                        y: 0
                    )

                // Grid lines at 25%, 50%, 75%, 100%
                Path { path in
                    // 75% line (25% from bottom)
                    let y75 = height * 0.25
                    path.move(to: CGPoint(x: 0, y: y75))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y75))

                    // 50% line (50% from bottom)
                    let y50 = height * 0.5
                    path.move(to: CGPoint(x: 0, y: y50))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y50))

                    // 25% line (75% from bottom)
                    let y25 = height * 0.75
                    path.move(to: CGPoint(x: 0, y: y25))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y25))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundColor(Color.gray.opacity(0.3))

                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(history.enumerated()), id: \.offset) {
                        _,
                            value in
                        let barHeight = max(
                            height * CGFloat(value / maxValue),
                            2
                        )

                        // Full height gradient masked to show only the bottom portion
                        LinearGradient(
                            colors: UsageGradient.colors,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(width: max(barWidth - 1, 1), height: height)
                        .mask(
                            VStack(spacing: 0) {
                                Spacer(minLength: height - barHeight)
                                RoundedRectangle(cornerRadius: 1)
                                    .frame(height: barHeight)
                            }
                            .frame(height: height)
                        )
                        .shadow(
                            color: UsageGradient.colorForPercentage(value)
                                .opacity(0.6),
                            radius: 3,
                            x: 0,
                            y: 0
                        )
                        .shadow(
                            color: UsageGradient.colorForPercentage(value)
                                .opacity(0.1),
                            radius: 6,
                            x: 0,
                            y: 0
                        )
                    }
                }
            }
        }
        .frame(height: height)
    }
}

struct MemoryDetailRow: View {
    let label: String
    let value: String
    let showBar: Bool
    var barPercentage: Double = 0

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()

            if showBar {
                GeometryReader { _ in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 80, height: 4)

                        LinearGradient(
                            colors: UsageGradient.colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(
                            width: 80,
                            height: 4
                        )
                        .mask(
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 2)
                                    .frame(
                                        width: 80
                                            * CGFloat(
                                                min(barPercentage, 100.0)
                                                    / 100.0
                                            ),
                                        height: 4
                                    )
                                Spacer()
                            }
                        )
                        .shadow(
                            color: UsageGradient.colorForPercentage(
                                barPercentage
                            ).opacity(0.5),
                            radius: 3,
                            x: 0,
                            y: 0
                        )
                    }
                }
                .frame(width: 80, height: 4)
            }
        }
    }
}

// MARK: - CPU Stats Row Component

struct CPUStatsRow: View {
    let userPercentage: Double
    let systemPercentage: Double
    let totalPercentage: Double
    let history: [Double]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("CPU")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Sparkline chart
            VerticalBarGraph(history: history, height: 60)
                .padding(.horizontal, 16)

            // User percentage bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("User")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)

                    Text("\(Int(userPercentage))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)

                            LinearGradient(
                                colors: UsageGradient.colors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(
                                width: geometry.size.width,
                                height: 6
                            )
                            .mask(
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .frame(
                                            width: geometry.size.width
                                                * CGFloat(
                                                    userPercentage / 100.0
                                                ),
                                            height: 6
                                        )
                                    Spacer()
                                }
                            )
                            .shadow(
                                color: UsageGradient.colorForPercentage(
                                    userPercentage
                                ).opacity(0.6),
                                radius: 4,
                                x: 0,
                                y: 0
                            )
                            .shadow(
                                color: UsageGradient.colorForPercentage(
                                    userPercentage
                                ).opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 0
                            )
                        }
                    }
                    .frame(height: 6)
                }

                // System percentage bar
                HStack(spacing: 8) {
                    Text("System")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)

                    Text("\(Int(systemPercentage))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)

                            LinearGradient(
                                colors: UsageGradient.colors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(
                                width: geometry.size.width,
                                height: 6
                            )
                            .mask(
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .frame(
                                            width: geometry.size.width
                                                * CGFloat(
                                                    systemPercentage / 100.0
                                                ),
                                            height: 6
                                        )
                                    Spacer()
                                }
                            )
                            .shadow(
                                color: UsageGradient.colorForPercentage(
                                    systemPercentage
                                ).opacity(0.6),
                                radius: 4,
                                x: 0,
                                y: 0
                            )
                            .shadow(
                                color: UsageGradient.colorForPercentage(
                                    systemPercentage
                                ).opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 0
                            )
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Battery Stats Row Component

struct BatteryStatsRow: View {
    let batteryPercentage: Double
    let isCharging: Bool
    let timeRemaining: TimeInterval?
    let uptime: TimeInterval

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(
                    systemName: isCharging ? "battery.100.bolt" : "battery.100"
                )
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

                Text("Battery")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Battery percentage bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Text(isCharging ? "Charging" : "Battery")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)

                            BatteryGradient.gradientForPercentage(
                                batteryPercentage
                            )
                            .frame(
                                width: geometry.size.width,
                                height: 6
                            )
                            .mask(
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .frame(
                                            width: geometry.size.width
                                                * CGFloat(
                                                    batteryPercentage / 100.0
                                                ),
                                            height: 6
                                        )
                                    Spacer()
                                }
                            )
                            .shadow(
                                color: BatteryGradient.colorForPercentage(
                                    batteryPercentage
                                ).opacity(0.6),
                                radius: 4,
                                x: 0,
                                y: 0
                            )
                            .shadow(
                                color: BatteryGradient.colorForPercentage(
                                    batteryPercentage
                                ).opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 0
                            )
                        }
                    }
                    .frame(height: 6)

                    Text("\(Int(batteryPercentage))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)

            // Uptime and time remaining
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Uptime")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(BatteryMonitor.formatUptime(uptime))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }

                HStack {
                    Text(isCharging ? "Time to Full" : "Time Left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    Text(
                        BatteryMonitor.formatTimeRemaining(
                            timeRemaining,
                            isCharging: isCharging
                        )
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Control Center Icon Button Component

struct ControlCenterIconButton: View {
    let icon: String
    let action: () -> Void
    var destructive: Bool = false

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        destructive
                            ? (isHovered
                                ? Color.red.opacity(0.15)
                                : Color.secondary.opacity(0.08))
                            : (isHovered
                                ? Color.primary.opacity(0.12)
                                : Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                destructive && isHovered
                                    ? Color.red.opacity(0.3)
                                    : Color.white.opacity(
                                        isHovered ? 0.25 : 0.15
                                    ),
                                lineWidth: 1
                            )
                    )

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(destructive && isHovered ? .red : .primary)
            }
            .frame(width: 44, height: 44)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .pressEvents(
            onPress: {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
            },
            onRelease: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        )
    }
}

// MARK: - Press Events Modifier

extension View {
    func pressEvents(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    onPress()
                }
                .onEnded { _ in
                    onRelease()
                }
        )
    }
}

// MARK: - Memory Data Model

public class MemoryDataModel: ObservableObject {
    @Published public var usagePercentage: Double = 0.0
    @Published public var totalMemoryFormatted: String = "0 GB"
    @Published public var usedMemoryFormatted: String = "0 GB"
    @Published public var memoryBreakdown: SystemMemoryMonitor.MemoryBreakdown?
    @Published public var memoryHistory: [Double] = Array(
        repeating: 0,
        count: 60
    )

    @Published public var cpuUserPercentage: Double = 0.0
    @Published public var cpuSystemPercentage: Double = 0.0
    @Published public var cpuTotalPercentage: Double = 0.0
    @Published public var cpuHistory: [Double] = Array(repeating: 0, count: 60)

    @Published public var batteryPercentage: Double = 0.0
    @Published public var batteryIsCharging: Bool = false
    @Published public var batteryTimeRemaining: TimeInterval? = nil
    @Published public var systemUptime: TimeInterval = 0.0
    @Published public var statusBarTitle: String = "􀫖 0%"

    private let memoryMonitor = SystemMemoryMonitor()
    private let cpuMonitor = CPUMonitor()
    private let batteryMonitor = BatteryMonitor()
    private var totalPhysicalMemory: UInt64 = 0
    private var updateTimer: Timer?

    public init() {
        totalPhysicalMemory = memoryMonitor.fetchTotalPhysicalMemory()
        refresh()
        startPeriodicUpdates()
    }

    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    public func refresh() {
        guard let breakdown = memoryMonitor.fetchMemoryBreakdown() else {
            return
        }
        let cpuUsage = cpuMonitor.fetchCPUUsage()
        let batteryInfo = batteryMonitor.fetchBatteryInfo()

        DispatchQueue.main.async {
            self.usagePercentage = breakdown.usage_percentage
            self.memoryBreakdown = breakdown

            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB]
            formatter.countStyle = .memory
            formatter.zeroPadsFractionDigits = false

            self.totalMemoryFormatted = formatter.string(
                fromByteCount: Int64(breakdown.total_bytes)
            )
            self.usedMemoryFormatted = formatter.string(
                fromByteCount: Int64(breakdown.used_bytes)
            )

            if let cpuUsage = cpuUsage {
                self.cpuUserPercentage = cpuUsage.userPercentage
                self.cpuSystemPercentage = cpuUsage.systemPercentage
                self.cpuTotalPercentage = cpuUsage.totalPercentage

                // Update CPU history
                self.cpuHistory.removeFirst()
                self.cpuHistory.append(cpuUsage.totalPercentage)
            }

            // Update memory history
            self.memoryHistory.removeFirst()
            self.memoryHistory.append(breakdown.usage_percentage)

            // Update status bar title
            self.statusBarTitle = "􀫖 \(Int(breakdown.usage_percentage))%"

            // Update battery info
            if let batteryInfo = batteryInfo {
                self.batteryPercentage = batteryInfo.percentage
                self.batteryIsCharging = batteryInfo.isCharging
                self.batteryTimeRemaining = batteryInfo.timeRemaining
                self.systemUptime = batteryInfo.uptime
            }
        }
    }
}
