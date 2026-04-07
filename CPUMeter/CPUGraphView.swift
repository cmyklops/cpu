import SwiftUI

struct CPUGraphView: View {
    @ObservedObject var cpuMonitor: CPUMonitor
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // Draw background (transparent for menu bar blending)
            // No background - let system theme show through
            
            // Draw vertical pixel lines for each data point
            if cpuMonitor.cpuHistory.count > 0 {
                let lineWidth = max(1.0, width / Double(cpuMonitor.cpuHistory.count))
                
                for (index, cpuValue) in cpuMonitor.cpuHistory.enumerated() {
                    let xStart = Double(index) * lineWidth
                    let lineHeight = (cpuValue / 100.0) * height
                    
                    // Draw vertical line from bottom
                    var path = Path()
                    path.move(to: CGPoint(x: xStart + lineWidth / 2, y: height))
                    path.addLine(to: CGPoint(x: xStart + lineWidth / 2, y: height - lineHeight))
                    
                    context.stroke(path, with: .color(.white), lineWidth: max(1.0, lineWidth - 1))
                }
            }
        }
        .frame(width: 35, height: 22)
    }
}

#Preview {
    let monitor = CPUMonitor()
    CPUGraphView(cpuMonitor: monitor)
}
