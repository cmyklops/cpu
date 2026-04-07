import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    @State private var sliderValue: Double = 1.0
    @State private var showResetConfirm = false
    
    private let appVersion = "1.0.0"
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Data freshness indicator
            if !cpuMonitor.isDataFresh {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Data not updating")
                        .font(.caption2)
                    Spacer()
                }
                .padding(4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            }
            
            // Metric selection
            Picker("Metric", selection: Binding(
                get: { preferences.metricType },
                set: { preferences.setMetricType($0) }
            )) {
                Text("CPU").tag("CPU").help("Monitor processor usage")
                Text("Memory").tag("Memory").help("Monitor RAM usage")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Metric Type")
            .help("Choose what to monitor: CPU (processor) or Memory (RAM)")
            
            // Display mode selection
            VStack(alignment: .leading, spacing: 3) {
                Text("Display")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Picker("", selection: Binding(
                    get: { preferences.displayMode },
                    set: { preferences.setDisplayMode($0) }
                )) {
                    Text("Bars").tag("bars").help("Show as horizontal bars")
                    Text("Number").tag("number").help("Show as percentage")
                    Text("Gradient").tag("gradient").help("Show as vertical fill")
                }
                .pickerStyle(.segmented)
            }
            .frame(maxWidth: .infinity)
            .help("Choose display style for the menu bar indicator")
            
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
                    .help("Updates per second (lower = faster, higher = less CPU)")
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
                .help("Adjust how frequently the display updates. Lower values (0.1s) are more responsive but use more CPU.")
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
                .help("Automatically start CPUMeter when you log in")
                Spacer()
            }
            .padding(.vertical, 12)
            
            // Version and Reset
            VStack(spacing: 6) {
                Button(action: { showResetConfirm = true }) {
                    Text("Reset to Defaults")
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .alert("Reset Settings?", isPresented: $showResetConfirm) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        preferences.resetToDefaults()
                        sliderValue = 1.0
                    }
                } message: {
                    Text("This will restore all settings to factory defaults.")
                }
                
                Text("CPUMeter v\(appVersion)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
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