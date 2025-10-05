// macos/Sources/UI/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var memoryMonitor: MemoryDataModel

    var body: some View {
        VStack(spacing: 12) {
            // Memory Stats Card
            VStack(spacing: 0) {
                MemoryStatsRow(
                    label: "Memory Pressure",
                    value: memoryMonitor.usagePercentage,
                    total: memoryMonitor.totalMemoryFormatted,
                    used: memoryMonitor.usedMemoryFormatted
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
    let label: String
    let value: Double
    let total: String
    let used: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "memorychip.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            VStack(spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(Int(value))%")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(colorForPercentage(value))

                    Spacer()
                }
                .padding(.horizontal, 16)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForPercentage(value))
                            .frame(width: geometry.size.width * CGFloat(value / 100.0), height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 16)

                HStack {
                    Text("\(used) of \(total)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private func colorForPercentage(_ percentage: Double) -> Color {
        if percentage > 85 {
            return .red
        } else if percentage > 70 {
            return .orange
        } else if percentage > 50 {
            return .yellow
        } else {
            return .blue
        }
    }
}

// MARK: - Process Row Component

struct ProcessRow: View {
    let name: String
    let memoryMB: Double
    let percentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForPercentage(percentage))
                        .frame(width: geometry.size.width * CGFloat(min(percentage, 100.0) / 100.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func colorForPercentage(_ percentage: Double) -> Color {
        if percentage > 15 {
            return .red
        } else if percentage > 10 {
            return .orange
        } else if percentage > 5 {
            return .yellow
        } else {
            return .blue
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

    private let memoryMonitor = SystemMemoryMonitor()
    private let processMonitor = ProcessMemoryMonitor()
    private var totalPhysicalMemory: UInt64 = 0

    public init() {
        totalPhysicalMemory = memoryMonitor.fetchTotalPhysicalMemory()
        refresh()
    }

    public func refresh() {
        guard let breakdown = memoryMonitor.fetchMemoryBreakdown() else { return }

        DispatchQueue.main.async {
            self.usagePercentage = breakdown.usage_percentage

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
        }
    }
}
