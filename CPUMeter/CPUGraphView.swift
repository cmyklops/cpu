import SwiftUI

struct CPUGraphView: View {
    @ObservedObject var cpuMonitor: CPUMonitor
    @ObservedObject var preferences = PreferencesManager.shared
    @Environment(\.colorScheme) var colorScheme

    private let meterSize = CGSize(width: 35, height: 22)
    private let meterCornerRadius: CGFloat = 5

    private var meterBackground: some View {
        Color.clear
            .tahoeGlass(
                tint: cachedColor.opacity(colorScheme == .dark ? 0.18 : 0.12),
                in: RoundedRectangle(cornerRadius: meterCornerRadius, style: .continuous),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: meterCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.34 : 0.62),
                                cachedColor.opacity(colorScheme == .dark ? 0.18 : 0.24),
                                Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            )
    }

    private var barColor: Color {
        cachedColor
    }

    private var highlightColor: Color {
        colorScheme == .dark ? .white : .primary
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
        .clipShape(RoundedRectangle(cornerRadius: meterCornerRadius, style: .continuous))
    }
    
    private var barsView: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let history = cpuMonitor.currentMetric == .cpu ? cpuMonitor.cpuHistory : cpuMonitor.memoryHistory
            
            guard !history.isEmpty else { return }
            
            let spacing = 1.0
            let historyCount = history.count
            let barWidth = max(1.0, floor((width - (spacing * Double(max(0, historyCount - 1)))) / Double(historyCount)))
            let totalWidth = (barWidth * Double(historyCount)) + (spacing * Double(max(0, historyCount - 1)))
            let leadingInset = max(0, (width - totalWidth) / 2)
            
            for (index, value) in history.enumerated() {
                let xStart = leadingInset + (Double(index) * (barWidth + spacing))
                let normalizedValue = min(max(value / 100.0, 0), 1)
                let lineHeight = max(2.0, normalizedValue * (height - 5))
                let yStart = height - 2 - lineHeight
                let barPositionFromRight = historyCount - 1 - index
                let isHighlighted = cpuMonitor.highlightedBarPositions.contains(barPositionFromRight)
                let opacity = isHighlighted ? 0.96 : 0.48 + (normalizedValue * 0.38)
                let rect = CGRect(x: xStart, y: yStart, width: barWidth, height: lineHeight)
                let path = Path(roundedRect: rect, cornerSize: CGSize(width: 1.5, height: 1.5))

                context.fill(path, with: .color(barColor.opacity(opacity)))

                if isHighlighted {
                    context.stroke(path, with: .color(highlightColor.opacity(0.38)), lineWidth: 0.7)
                }
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .frame(width: meterSize.width, height: meterSize.height)
        .accessibilityLabel(cpuMonitor.currentMetric == .cpu ? "CPU graph" : "Memory graph")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
    
    private var numberView: some View {
        ZStack {
            Text(String(format: "%.0f", cpuMonitor.currentValue))
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(cachedColor)
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
                    .fill(cachedColor.opacity(0.86))
                    .frame(height: 22.0 * fillPercentage)
            }
            
            let label = cpuMonitor.currentMetric == .cpu ? "C" : "M"
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.94) : .primary.opacity(0.78))
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
