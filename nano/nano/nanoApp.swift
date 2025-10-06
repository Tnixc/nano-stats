//
//  nanoApp.swift
//  nano
//
//  Created by tnixc on 5/10/2025.
//

import SwiftUI

@main
struct nanoApp: App {
    @StateObject private var menuBarModel = MemoryDataModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(memoryMonitor: menuBarModel)
                .background(.clear)
                .focusable(false)
        } label: {
            MenuBarCPULabel(
                cpuHistory: menuBarModel.cpuHistory,
                cpuPercentage: menuBarModel.cpuTotalPercentage
            )
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar CPU Label

struct MenuBarCPULabel: View {
    let cpuHistory: [Double]
    let cpuPercentage: Double

    var body: some View {
        if let combinedImage = createCombinedImage() {
            Image(nsImage: combinedImage)
                .resizable()
                .frame(width: 85, height: 16)
                .focusable(false)
        }
    }

    private func createCombinedImage() -> NSImage? {
        let graphWidth: CGFloat = 50
        let textWidth: CGFloat = 35
        let spacing: CGFloat = 6
        let totalWidth = graphWidth + spacing + textWidth
        let height: CGFloat = 16

        let size = NSSize(width: totalWidth, height: height)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        // Background rounded rectangle for graph
        NSColor.white.withAlphaComponent(0.2).setFill()
        let bgPath = NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: graphWidth, height: height),
            xRadius: 3,
            yRadius: 3
        )
        bgPath.fill()

        // Draw bars
        let last30 = Array(cpuHistory.suffix(30))
        if !last30.isEmpty {
            let barWidth: CGFloat = graphWidth / CGFloat(last30.count)
            let barSpacing: CGFloat = 0.1
            let actualBarWidth = barWidth - barSpacing

            NSColor.white.setFill()

            for (index, value) in last30.enumerated() {
                let x = CGFloat(index) * barWidth + barSpacing / 2
                let normalizedValue = min(max(value, 0), 100) / 100.0
                let barHeight = max(height * normalizedValue, 1.5)
                let y = 0.0

                let barRect = NSRect(
                    x: x,
                    y: y,
                    width: actualBarWidth,
                    height: barHeight
                )

                let barPath = NSBezierPath(
                    roundedRect: barRect,
                    xRadius: 0.5,
                    yRadius: 0.5
                )
                barPath.fill()
            }
        }

        // Draw text
        let text = "\(Int(cpuPercentage))%"
        let textX = graphWidth + spacing

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
        ]

        let attributedString = NSAttributedString(
            string: text,
            attributes: attributes
        )

        let textRect = NSRect(
            x: textX,
            y: (height - 13) / 2 + 2,
            width: textWidth,
            height: 13
        )

        attributedString.draw(in: textRect)

        return image
    }
}
