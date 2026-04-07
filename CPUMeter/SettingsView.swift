import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    @State private var sliderValue: Double = 1.0
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Metric selection
            Picker("Metric", selection: Binding(
                get: { preferences.metricType },
                set: { preferences.setMetricType($0) }
            )) {
                Text("CPU").tag("CPU")
                Text("Memory").tag("Memory")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            
            // Display mode selection
            VStack(alignment: .leading, spacing: 3) {
                Text("Display")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Picker("", selection: Binding(
                    get: { preferences.displayMode },
                    set: { preferences.setDisplayMode($0) }
                )) {
                    Text("Bars").tag("bars")
                    Text("Number").tag("number")
                    Text("Gradient").tag("gradient")
                }
                .pickerStyle(.segmented)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .padding(.vertical, 2)
            
            // Stats display
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Current")
                    Spacer()
                    Text(String(format: "%.1f%%", cpuMonitor.currentValue))
                        .monospacedDigit()
                }
                HStack {
                    Text("Average")
                    Spacer()
                    Text(String(format: "%.1f%%", cpuMonitor.averageValue))
                        .monospacedDigit()
                }
                HStack {
                    Text("Peak")
                    Spacer()
                    Text(String(format: "%.1f%%", cpuMonitor.peakValue))
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            Divider()
                .padding(.vertical, 2)
            
            // Update frequency
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Update frequency")
                    Spacer()
                    Text(String(format: "%.1fs", sliderValue))
                        .monospacedDigit()
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                Slider(
                    value: $sliderValue,
                    in: 0.1...2.0,
                    step: 0.1,
                    onEditingChanged: { editing in
                        if !editing {
                            preferences.setUpdateFrequency(sliderValue)
                        }
                    }
                )
            }
            .font(.caption)
            
            // Launch at startup - centered
            HStack {
                Spacer()
                Toggle("Launch at startup", isOn: Binding(
                    get: { preferences.launchAtStartup },
                    set: { preferences.setLaunchAtStartup($0) }
                ))
                .font(.caption)
                Spacer()
            }
            .padding(.vertical, 12)
            
            // Quit button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit CPU Meter")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .frame(width: 220, height: 300)
        .onAppear {
            sliderValue = preferences.updateFrequency
        }
    }
}

#Preview {
    SettingsView()
}