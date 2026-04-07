import SwiftUI

struct CPUGraphView: View {
    @ObservedObject var cpuMonitor: CPUMonitor
    @ObservedObject var preferences = PreferencesManager.shared
    
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
            
            if history.count > 0 {
                let lineWidth = max(1.0, width / Double(history.count))
                
                for (index, value) in history.enumerated() {
                    let xStart = Double(index) * lineWidth
                    let lineHeight = (value / 100.0) * height
                    
                    let barPositionFromRight = history.count - 1 - index
                    let isHighlighted = cpuMonitor.highlightedBarPositions.contains(barPositionFromRight)
                    let barColor: Color = isHighlighted ? Color(red: 220/255, green: 195/255, blue: 6/255) : .white
                    
                    var path = Path()
                    path.move(to: CGPoint(x: xStart + lineWidth / 2, y: height))
                    path.addLine(to: CGPoint(x: xStart + lineWidth / 2, y: height - lineHeight))
                    
                    context.stroke(path, with: .color(barColor), lineWidth: max(1.0, lineWidth - 1))
                }
            }
        }
        .frame(width: 35, height: 22)
    }
    
    private var numberView: some View {
        ZStack {
            Text(String(format: "%.0f", cpuMonitor.currentValue))
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(colorForValue(cpuMonitor.currentValue))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 35, height: 22)
    }
    
    private var gradientView: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            Rectangle()
                .fill(Color.gray.opacity(0.2))
            
            // Fill bar with color
            let fillPercentage = cpuMonitor.currentValue / 100.0
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(gradientColor(fillPercentage))
                    .frame(height: 22.0 * fillPercentage)
            }
            
            // Text overlay that fills the space
            let label = cpuMonitor.currentMetric == "CPU" ? "C" : "M"
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 35, height: 22)
        .clipped()
    }
    
    private func colorForValue(_ value: Double) -> Color {
        if value < 33 {
            return .green
        } else if value < 66 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func gradientColor(_ percentage: Double) -> Color {
        if percentage < 0.33 {
            return .green
        } else if percentage < 0.66 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    let monitor = CPUMonitor()
    CPUGraphView(cpuMonitor: monitor)
}
