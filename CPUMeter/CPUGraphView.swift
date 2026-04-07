import SwiftUI

struct CPUGraphView: View {
    @ObservedObject var cpuMonitor: CPUMonitor
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // Draw background
            let backgroundPath = Path(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), cornerRadius: 2)
            context.fill(backgroundPath, with: .color(.black.opacity(0.9)))
            
            // Draw CPU graph
            if cpuMonitor.cpuHistory.count > 1 {
                var path = Path()
                let xStep = width / Double(cpuMonitor.cpuHistory.count - 1)
                
                for (index, cpuValue) in cpuMonitor.cpuHistory.enumerated() {
                    let x = Double(index) * xStep
                    let y = height * (1.0 - cpuValue / 100.0)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                // Draw line
                context.stroke(path, with: .color(Color(red: 0.0, green: 1.0, blue: 1.0)), lineWidth: 1.0)
            }
            
            // Draw border
            let borderPath = Path(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), cornerRadius: 2)
            context.stroke(borderPath, with: .color(.white.opacity(0.15)), lineWidth: 0.5)
        }
        .frame(width: 120, height: 24)
    }
}

#Preview {
    let monitor = CPUMonitor()
    CPUGraphView(cpuMonitor: monitor)
}
