import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Launch at startup
            Toggle("Launch at startup", isOn: Binding(
                get: { preferences.launchAtStartup },
                set: { preferences.setLaunchAtStartup($0) }
            ))
            
            // Update frequency
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Update frequency")
                    Spacer()
                    Text(String(format: "%.1fs", preferences.updateFrequency))
                        .monospacedDigit()
                        .foregroundColor(.gray)
                }
                Slider(
                    value: Binding(
                        get: { preferences.updateFrequency },
                        set: { preferences.setUpdateFrequency($0) }
                    ),
                    in: 0.1...2.0,
                    step: 0.1
                )
            }
            
            Divider()
            
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
        .padding(12)
        .frame(width: 240)
    }
}

#Preview {
    SettingsView()
}