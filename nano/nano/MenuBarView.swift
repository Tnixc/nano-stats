// macos/Sources/UI/MenuBarView.swift
import Combine
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var memoryMonitor: MemoryDataModel

    var body: some View {
        VStack(spacing: 12) {
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
                    usagePercentage: memoryMonitor.usagePercentage
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

            // Top Processes Card
            if !memoryMonitor.topProcesses.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(memoryMonitor.topProcesses.enumerated()), id: \.element.pid) { index, process in
                        ProcessRow(
                            name: process.name,
                            memoryMB: Double(process.memory_usage_bytes) / (1024.0 * 1024.0),
                            percentage: process.memory_usage_percentage
                        )

                        if index < memoryMonitor.topProcesses.count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
            }

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

    var body: some View {
        VStack(spacing: 12) {
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

            // Pressure bar
            VStack(alignment: .leading, spacing: 6) {
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

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(usagePercentage / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 16)

            if let breakdown = memoryBreakdown {
                VStack(alignment: .leading, spacing: 8) {
                    MemoryDetailRow(
                        label: "Active",
                        value: formatBytes(breakdown.active_bytes),
                        showBar: false
                    )

                    MemoryDetailRow(
                        label: "Wired",
                        value: formatBytes(breakdown.wired_bytes),
                        showBar: false
                    )

                    MemoryDetailRow(
                        label: "Available",
                        value: formatBytes(breakdown.free_bytes),
                        showBar: false
                    )

                    MemoryDetailRow(
                        label: "Compressed",
                        value: formatBytes(breakdown.compressed_bytes),
                        showBar: false
                    )

                    MemoryDetailRow(
                        label: "Swap File",
                        value: formatBytes(breakdown.swap_used_bytes),
                        showBar: true,
                        barPercentage: breakdown.swap_total_bytes > 0 ?
                            Double(breakdown.swap_used_bytes) / Double(breakdown.swap_total_bytes) * 100.0 : 0
                    )
                }
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 4)
        }
        .padding(.bottom, 12)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .memory
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(bytes))
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

            Spacer()

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

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: 80 * CGFloat(min(barPercentage, 100.0) / 100.0), height: 4)
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
        VStack(spacing: 12) {
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
            CPUSparklineChart(history: history)
                .frame(height: 40)
                .padding(.horizontal, 16)

            // User percentage bar
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

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(userPercentage / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 16)

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

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(systemPercentage / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - CPU Sparkline Chart

struct CPUSparklineChart: View {
    let history: [Double]

    var body: some View {
        GeometryReader { geometry in
            let maxValue = max(history.max() ?? 1.0, 1.0)
            let barWidth = geometry.size.width / CGFloat(history.count)

            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(history.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.orange)
                        .frame(
                            width: max(barWidth - 1, 1),
                            height: max(geometry.size.height * CGFloat(value / maxValue), 2)
                        )
                }
            }
        }
    }
}

// MARK: - Process Row Component

struct ProcessRow: View {
    let name: String
    let memoryMB: Double
    let percentage: Double

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(String(format: "%.1f MB", memoryMB))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                            ? (isHovered ? Color.red.opacity(0.15) : Color.secondary.opacity(0.08))
                            : (isHovered ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                destructive && isHovered
                                    ? Color.red.opacity(0.3)
                                    : Color.white.opacity(isHovered ? 0.25 : 0.15),
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
    @Published public var topProcesses: [ProcessMemoryMonitor.ProcessDetails] = []
    @Published public var memoryBreakdown: SystemMemoryMonitor.MemoryBreakdown?

    @Published public var cpuUserPercentage: Double = 0.0
    @Published public var cpuSystemPercentage: Double = 0.0
    @Published public var cpuTotalPercentage: Double = 0.0
    @Published public var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published public var topCPUProcesses: [CPUMonitor.ProcessCPUDetails] = []

    private let memoryMonitor = SystemMemoryMonitor()
    private let processMonitor = ProcessMemoryMonitor()
    private let cpuMonitor = CPUMonitor()
    private var totalPhysicalMemory: UInt64 = 0
    private var updateTimer: Timer?

    public var statusBarTitle: String {
        "􀫖 \(Int(usagePercentage))%"
    }

    public init() {
        totalPhysicalMemory = memoryMonitor.fetchTotalPhysicalMemory()
        refresh()
        startPeriodicUpdates()
    }

    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    public func refresh() {
        guard let breakdown = memoryMonitor.fetchMemoryBreakdown() else { return }
        let cpuUsage = cpuMonitor.fetchCPUUsage()

        DispatchQueue.main.async {
            self.usagePercentage = breakdown.usage_percentage
            self.memoryBreakdown = breakdown

            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB]
            formatter.countStyle = .memory
            formatter.zeroPadsFractionDigits = false

            self.totalMemoryFormatted = formatter.string(fromByteCount: Int64(breakdown.total_bytes))
            self.usedMemoryFormatted = formatter.string(fromByteCount: Int64(breakdown.used_bytes))

            self.topProcesses = self.processMonitor.fetchTopMemoryProcesses(
                limit: 5,
                totalPhysicalMemory: self.totalPhysicalMemory
            )

            if let cpuUsage = cpuUsage {
                self.cpuUserPercentage = cpuUsage.userPercentage
                self.cpuSystemPercentage = cpuUsage.systemPercentage
                self.cpuTotalPercentage = cpuUsage.totalPercentage

                // Update CPU history
                self.cpuHistory.removeFirst()
                self.cpuHistory.append(cpuUsage.totalPercentage)
            }

            self.topCPUProcesses = self.cpuMonitor.fetchTopCPUProcesses(limit: 5)
        }
    }
}
