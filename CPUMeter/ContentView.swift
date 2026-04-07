import SwiftUI

struct ContentView: View {
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    
    var body: some View {
        CPUGraphView(cpuMonitor: cpuMonitor)
            .frame(width: 120, height: 24)
    }
}

#Preview {
    ContentView()
}
