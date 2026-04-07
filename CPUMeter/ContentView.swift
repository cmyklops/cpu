import SwiftUI

struct ContentView: View {
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    
    var body: some View {
        CPUGraphView(cpuMonitor: cpuMonitor)
            .frame(width: 35, height: 22)
            .id(cpuMonitor.currentMetric)  // Force re-render when metric changes
    }
}

#Preview {
    ContentView()
}
