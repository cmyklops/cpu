import SwiftUI

struct ContentView: View {
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    
    var body: some View {
        VStack(spacing: 0) {
            CPUGraphView(cpuMonitor: cpuMonitor)
                .frame(width: 160, height: 60)
        }
        .frame(width: 160, height: 60)
        .background(Color.black.opacity(0.8))
        .cornerRadius(4)
        .padding(4)
    }
}

#Preview {
    ContentView()
        .frame(width: 160, height: 60)
}
