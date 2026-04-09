import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    @State private var sliderValue: Double = PreferencesManager.shared.updateFrequency
    @State private var showResetConfirm = false
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
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
                Text("Memory").tag("Memory").help("Monitor memory pressure")
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Metric Type")
            .help("Choose what to monitor: CPU (processor) or Memory (pressure)")
            
            // Display mode selection
            Picker("", selection: Binding(
                get: { preferences.displayMode },
                set: { preferences.setDisplayMode($0) }
            )) {
                Text("Bars").tag("bars").help("Show as horizontal bars")
                Text("Number").tag("number").help("Show as percentage")
                Text("Gradient").tag("gradient").help("Show as vertical fill")
            }
            .pickerStyle(.segmented)
            .help("Choose display style for the menu bar indicator")
            
            Divider()
                .padding(.vertical, 6)
            
            // Stats display
            VStack(alignment: .leading, spacing: 4) {
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
                .padding(.vertical, 6)
            
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
            .padding(.bottom, 4)
            
            // Launch at startup - centered
            Toggle("Launch at startup", isOn: Binding(
                get: { preferences.launchAtStartup },
                set: { preferences.setLaunchAtStartup($0) }
            ))
            .font(.caption)
            .help("Automatically start CPUMeter when you log in")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            
            Divider()
                .padding(.vertical, 6)
            
            // Version and Reset
            VStack(spacing: 6) {
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
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit CPUMeter")
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Text("CPUMeter v\(appVersion)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .frame(width: 240)
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