import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    @State private var sliderValue: Double = 1.0
    @State private var showResetConfirm = false
    
    private let appVersion = "1.0.0"
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
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
            Picker("", selection: Binding(
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
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text("Current")
                    Spacer()
                    Text(String(format: "%.1f%%", cpuMonitor.currentValue))
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    Text("Average")
                    Spacer()
                    Text(String(format: "%.1f%%", cpuMonitor.averageValue))
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    Text("Peak")
                    Spacer()
                    Text(String(format: "%.1f%%", cpuMonitor.peakValue))
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            Divider()
                .padding(.vertical, 1)
            
            // Update frequency
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Update frequency")
                        .font(.caption)
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
            
            // Launch at startup - centered
            Toggle("Launch at startup", isOn: Binding(
                get: { preferences.launchAtStartup },
                set: { preferences.setLaunchAtStartup($0) }
            ))
            .font(.caption)
            .help("Automatically start CPUMeter when you log in")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            
            // Version and Reset
            VStack(spacing: 3) {
                Button(action: { openActivityMonitor() }) {
                    Text("Open Activity Monitor")
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
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
        .padding(6)
        .frame(width: 220, height: 320)
        .onAppear {
            sliderValue = preferences.updateFrequency
        }
    }
    
    private func openActivityMonitor() {
        let activityMonitorURL = FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask).first?
            .appendingPathComponent("Utilities/Activity Monitor.app")
        
        if let url = activityMonitorURL {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
}