import SwiftUI

struct CPUGraphView: View {
    @ObservedObject var cpuMonitor: CPUMonitor
    @ObservedObject var preferences = PreferencesManager.shared
    @Environment(\.colorScheme) var colorScheme

    private let meterSize = CGSize(width: 35, height: 22)
    private let visibleBarCount = 6

    private var menuBarInk: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var highlightColor: Color {
        menuBarInk.opacity(colorScheme == .dark ? 0.52 : 0.34)
    }

    private var valueIntensity: Double {
        min(max(cpuMonitor.currentValue / 100.0, 0), 1)
    }
    
    var body: some View {
        Group {
            if preferences.displayMode == .bars {
                barsView
            } else if preferences.displayMode == .number {
                numberView
            } else {
                gradientView
            }
        }
        .frame(width: meterSize.width, height: meterSize.height)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
    
    private var barsView: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let fullHistory = cpuMonitor.currentMetric == .cpu ? cpuMonitor.cpuHistory : cpuMonitor.memoryHistory
            let history = Array(fullHistory.suffix(visibleBarCount))
            
            guard !history.isEmpty else { return }
            
            let spacing = 1.0
            let historyCount = history.count
            let barWidth = max(4.0, floor((width - (spacing * Double(max(0, historyCount - 1)))) / Double(historyCount)))
            let totalWidth = (barWidth * Double(historyCount)) + (spacing * Double(max(0, historyCount - 1)))
            let leadingInset = floor(max(0, (width - totalWidth) / 2))
            
            for (index, value) in history.enumerated() {
                let xStart = leadingInset + (Double(index) * (barWidth + spacing))
                let normalizedValue = min(max(value / 100.0, 0), 1)
                let lineHeight = floor(max(4.0, normalizedValue * (height - 3)))
                let yStart = floor(height - 1 - lineHeight)
                let barPositionFromRight = historyCount - 1 - index
                let isHighlighted = cpuMonitor.highlightedBarPositions.contains(barPositionFromRight)
                let opacity = isHighlighted ? 1.0 : 0.62 + (normalizedValue * 0.32)
                let rect = CGRect(x: xStart, y: yStart, width: barWidth, height: lineHeight)
                let path = Path(rect)

                context.fill(path, with: .color(menuBarInk.opacity(opacity)))

                if isHighlighted {
                    context.stroke(path, with: .color(highlightColor), lineWidth: 1)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(width: meterSize.width, height: meterSize.height)
        .accessibilityLabel(cpuMonitor.currentMetric == .cpu ? "CPU graph" : "Memory graph")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
    
    private var numberView: some View {
        ZStack {
            Text(String(format: "%.0f", cpuMonitor.currentValue))
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(menuBarInk.opacity(0.78 + (valueIntensity * 0.2)))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: meterSize.width, height: meterSize.height)
        .accessibilityLabel(cpuMonitor.currentMetric == .cpu ? "CPU usage" : "Memory usage")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
    
    private var gradientView: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle().fill(Color.clear)

            let fillPercentage = cpuMonitor.currentValue / 100.0
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(menuBarInk.opacity(0.42 + (fillPercentage * 0.48)))
                    .frame(height: 22.0 * fillPercentage)
            }
            
            let label = cpuMonitor.currentMetric == .cpu ? "C" : "M"
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(menuBarInk.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: meterSize.width, height: meterSize.height)
        .clipped()
        .accessibilityLabel(cpuMonitor.currentMetric == .cpu ? "CPU meter" : "Memory pressure meter")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
}

#Preview {
    let monitor = CPUMonitor()
    CPUGraphView(cpuMonitor: monitor)
}

extension View {
    @ViewBuilder
    func tahoeGlass<S: Shape>(
        tint: Color? = nil,
        in shape: S,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
