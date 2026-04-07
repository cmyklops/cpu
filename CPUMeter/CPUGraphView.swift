import SwiftUI

struct CPUGraphView: View {
    @ObservedObject var cpuMonitor: CPUMonitor
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // Draw background
            let backgroundPath = Path(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), cornerRadius: 4)
            context.fill(backgroundPath, with: .color(.black.opacity(0.7)))
            
            // Draw grid lines at 25%, 50%, 75%
            let gridColor = Color.white.opacity(0.1)
            for percentage in [25, 50, 75] {
                let y = height * (1.0 - Double(percentage) / 100.0)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            }
            
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
                        // Smooth curve interpolation
                        let prevValue = cpuMonitor.cpuHistory[index - 1]
                        let prevX = Double(index - 1) * xStep
                        let prevY = height * (1.0 - prevValue / 100.0)
                        
                        let controlX = (prevX + x) / 2
                        let controlY = (prevY + y) / 2
                        
                        path.addCurve(
                            to: CGPoint(x: x, y: y),
                            control1: CGPoint(x: controlX, y: prevY),
                            control2: CGPoint(x: controlX, y: y)
                        )
                    }
                }
                
                // Draw gradient fill under the line
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: width, y: height))
                fillPath.addLine(to: CGPoint(x: 0, y: height))
                fillPath.closeSubpath()
                
                let gradient = Gradient(colors: [
                    Color(red: 0.0, green: 1.0, blue: 1.0),  // Cyan
                    Color(red: 0.0, green: 0.8, blue: 1.0)   // Light cyan
                ])
                context.fill(fillPath, with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: height)))
                
                // Draw line on top
                context.stroke(path, with: .color(Color(red: 0.0, green: 1.0, blue: 1.0)), lineWidth: 2)
            }
            
            // Draw border
            let borderPath = Path(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), cornerRadius: 4)
            context.stroke(borderPath, with: .color(.white.opacity(0.2)), lineWidth: 1)
        }
        .frame(width: 160, height: 60)
    }
}

#Preview {
    let monitor = CPUMonitor()
    CPUGraphView(cpuMonitor: monitor)
}
