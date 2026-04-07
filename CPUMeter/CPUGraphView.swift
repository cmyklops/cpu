import SwiftUI

struct CPUGraphView: View {
    @ObservedObject var cpuMonitor: CPUMonitor
    @ObservedObject var preferences = PreferencesManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    // Adapt bar color based on system appearance
    private var barColor: Color {
        colorScheme == .dark ? Color.white : Color.white
    }
    
    private var highlightColor: Color {
        Color(red: 220/255, green: 195/255, blue: 6/255)
    }
    
    // Cache color for current value to avoid recalculation
    private var cachedColor: Color {
        let value = cpuMonitor.currentValue
        if value < 33 {
            return .green
        } else if value < 66 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var body: some View {
        Group {
            if preferences.displayMode == "bars" {
                barsView
            } else if preferences.displayMode == "number" {
                numberView
            } else {
                gradientView
            }
        }
    }
    
    private var barsView: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let history = cpuMonitor.currentMetric == "CPU" ? cpuMonitor.cpuHistory : cpuMonitor.memoryHistory
            
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
            }
        }
        .frame(width: 35, height: 22)
        .accessibilityLabel("\(cpuMonitor.currentMetric) graph")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
    
    private var numberView: some View {
        ZStack {
            Text(String(format: "%.0f", cpuMonitor.currentValue))
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(cachedColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 35, height: 22)
        .accessibilityLabel("\(cpuMonitor.currentMetric) usage")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
    
    private var gradientView: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle().fill(Color.gray.opacity(0.2))
            
            let fillPercentage = cpuMonitor.currentValue / 100.0
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(cachedColor.opacity(0.8))
                    .frame(height: 22.0 * fillPercentage)
            }
            
            let label = cpuMonitor.currentMetric == "CPU" ? "C" : "M"
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 35, height: 22)
        .clipped()
        .accessibilityLabel(cpuMonitor.currentMetric == "CPU" ? "CPU meter" : "Memory meter")
        .accessibilityValue(String(format: "%.0f%%", cpuMonitor.currentValue))
    }
}

#Preview {
    let monitor = CPUMonitor()
    CPUGraphView(cpuMonitor: monitor)
}
