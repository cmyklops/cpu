import SwiftUI

struct CPUGraphView: View {
    @ObservedObject var cpuMonitor: CPUMonitor
    @ObservedObject var preferences = PreferencesManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var meterBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.34 : 0.62),
                                cachedColor.opacity(0.24),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: cachedColor.opacity(0.12), radius: 4, x: 0, y: 1)
    }

    private var barColor: Color {
        colorScheme == .dark ? .white.opacity(0.92) : .primary.opacity(0.82)
    }

    private var highlightColor: Color {
        Color.white
    }

    private var cachedColor: Color {
        if cpuMonitor.currentMetric == .memory {
            switch cpuMonitor.memoryPressureLevel {
            case 2: return .red
            case 1: return .yellow
            default: return .mint
            }
        }
        let value = cpuMonitor.currentValue
        if value < 33 {
            return .mint
        } else if value < 66 {
            return .yellow
        } else {
            return .red
        }
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
        .background(meterBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    
    private var barsView: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let history = cpuMonitor.currentMetric == .cpu ? cpuMonitor.cpuHistory : cpuMonitor.memoryHistory
            
            guard !history.isEmpty else { return }
            
            let lineWidth = max(1.0, width / Double(history.count))
            let historyCount = history.count
            
            for (index, value) in history.enumerated() {
                let xStart = Double(index) * lineWidth
                let lineHeight = (value / 100.0) * height
                let barPositionFromRight = historyCount - 1 - index
                let isHighlighted = cpuMonitor.highlightedBarPositions.contains(barPositionFromRight)
                let barDrawColor: Color = isHighlighted ? highlightColor : barColor
                
                var path = Path()
                path.move(to: CGPoint(x: xStart + lineWidth / 2, y: height))
                path.addLine(to: CGPoint(x: xStart + lineWidth / 2, y: height - lineHeight))
                
                context.stroke(path, with: .color(barDrawColor), lineWidth: max(1.0, lineWidth - 1))

                if isHighlighted {
                    context.stroke(path, with: .color(cachedColor.opacity(0.65)), lineWidth: max(2.0, lineWidth))
                }
            }
        }
        .frame(width: 35, height: 22)
        .accessibilityLabel(cpuMonitor.currentMetric == .cpu ? "CPU graph" : "Memory graph")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
    
    private var numberView: some View {
        ZStack {
            Text(String(format: "%.0f", cpuMonitor.currentValue))
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, cachedColor.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: cachedColor.opacity(0.35), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 35, height: 22)
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
                    .fill(
                        LinearGradient(
                            colors: [
                                cachedColor.opacity(0.95),
                                cachedColor.opacity(0.35)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: 22.0 * fillPercentage)
            }
            
            let label = cpuMonitor.currentMetric == .cpu ? "C" : "M"
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(.white.opacity(0.94))
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 35, height: 22)
        .clipped()
        .accessibilityLabel(cpuMonitor.currentMetric == .cpu ? "CPU meter" : "Memory pressure meter")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
}

#Preview {
    let monitor = CPUMonitor()
    CPUGraphView(cpuMonitor: monitor)
}
