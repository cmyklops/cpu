import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    @State private var sliderValue: Double = PreferencesManager.shared.updateFrequency
    @State private var showResetConfirm = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    private let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

    var body: some View {
        ZStack(alignment: .top) {
            tahoeBackdrop

            VStack(spacing: 9) {
                headerView

                if !cpuMonitor.isDataFresh {
                    statusBanner
                }

                monitorPanel
                refreshPanel
                systemPanel
                actionButtons
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            sliderValue = preferences.updateFrequency
            preferences.refreshLaunchAtLoginStatus()
        }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                Color.clear
                    .tahoeGlass(
                        tint: tintColor.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous),
                        interactive: true
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(glassStroke, lineWidth: 1)
                    )
                Image(systemName: cpuMonitor.currentMetric == .cpu ? "cpu" : "memorychip")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tintColor)
            }
            .frame(width: 38, height: 38)

            Text("CPUMeter")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .help("CPUMeter \(appVersion) (\(appBuild))")
    }

    private var monitorPanel: some View {
        glassSection(spacing: 8) {
            if !cpuMonitor.isDataFresh {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.orange)
                    Text(cpuMonitor.sampleStatus.message)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.orange)
                    Spacer(minLength: 0)
                }
            }

            VStack(spacing: 6) {
                HStack {
                    Spacer(minLength: 0)
                    Picker("", selection: Binding(
                        get: { preferences.metricType },
                        set: { preferences.setMetricType($0) }
                    )) {
                        ForEach(MetricType.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .controlSize(.small)
                    .accessibilityLabel("Metric Type")
                    Spacer(minLength: 0)
                }

                HStack {
                    Spacer(minLength: 0)
                    Picker("", selection: Binding(
                        get: { preferences.displayMode },
                        set: { preferences.setDisplayMode($0) }
                    )) {
                        ForEach(DisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 224)
                    .controlSize(.small)
                    .accessibilityLabel("Display Mode")
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 8) {
                primaryStatTile

                VStack(spacing: 8) {
                    supportStat("Avg", value: cpuMonitor.averageValue, symbol: "chart.bar.fill")
                    supportStat("Peak", value: cpuMonitor.peakValue, symbol: "flame.fill")
                }
                .frame(width: 104)
            }
        }
    }

    private var refreshPanel: some View {
        glassSection(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("Refresh", systemImage: "slider.horizontal.3")
                Spacer()
                Text(String(format: "%.1fs", sliderValue))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
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
            .tint(tintColor)
            .controlSize(.small)
        }
    }

    private var systemPanel: some View {
        glassSection(spacing: 7) {
            HStack(spacing: 10) {
                Toggle("Launch at startup", isOn: Binding(
                    get: { preferences.launchAtStartup },
                    set: { preferences.setLaunchAtStartup($0) }
                ))
                .font(.caption.weight(.medium))
                .help(preferences.launchAtLoginStatus.detail)

                Spacer(minLength: 4)

                launchStatusBadge
            }

            Text(preferences.launchAtLoginStatus.detail)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(cpuMonitor.sampleStatus.message)
                .font(.caption2.weight(.medium))
            Spacer()
        }
        .padding(8)
        .background(
            Color.clear.tahoeGlass(
                tint: Color.orange.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        )
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .frame(width: 16)
                .foregroundColor(tintColor)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }

    private func glassSection<Content: View>(
        spacing: CGFloat = 7,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.clear.tahoeGlass(
                tint: tintColor.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(glassStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 5)
    }

    private var primaryStatTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(tintColor)
                Text("Now")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Text(String(format: "%.0f%%", cpuMonitor.currentValue))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Text(cpuMonitor.currentMetric == .cpu ? "Processor load" : "Memory pressure")
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(
            Color.clear.tahoeGlass(
                tint: tintColor.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(glassStroke, lineWidth: 0.8)
        )
    }

    private func supportStat(_ label: String, value: Double, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundColor(tintColor)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(height: 44)
        .background(
            Color.clear.tahoeGlass(
                tint: tintColor.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        )
    }

    private var launchStatusBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: launchStatusSymbol)
                .font(.caption2.weight(.bold))
            Text(preferences.launchAtLoginStatus.message)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(launchStatusColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Color.clear.tahoeGlass(
                tint: launchStatusColor.opacity(0.14),
                in: Capsule()
            )
        )
        .overlay(
            Capsule()
                .stroke(launchStatusColor.opacity(0.18), lineWidth: 1)
        )
        .help(preferences.launchAtLoginStatus.detail)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: { openActivityMonitor() }) {
                Label("Monitor", systemImage: "speedometer")
                    .labelStyle(.iconOnly)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassIconButtonStyle(tintColor: tintColor))
            .help("Open Activity Monitor")

            Button(action: { showResetConfirm = true }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassIconButtonStyle(tintColor: .orange))
            .help("Reset to Defaults")
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
                Label("Quit", systemImage: "power")
                    .labelStyle(.iconOnly)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassIconButtonStyle(tintColor: .red))
            .help("Quit CPUMeter")
        }
    }

    private var tintColor: Color {
        if cpuMonitor.currentMetric == .memory {
            switch cpuMonitor.memoryPressureLevel {
            case 2: return .red
            case 1: return .yellow
            default: return .mint
            }
        }

        switch cpuMonitor.currentValue {
        case ..<33: return .mint
        case ..<66: return .yellow
        default: return .red
        }
    }

    private var tahoeBackdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    tintColor.opacity(0.12),
                    Color.primary.opacity(0.035),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .background(.regularMaterial)
        .ignoresSafeArea()
    }

    private var glassStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.52),
                tintColor.opacity(0.20),
                Color.primary.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var launchStatusSymbol: String {
        switch preferences.launchAtLoginStatus {
        case .enabled: return "checkmark.circle.fill"
        case .disabled: return "circle"
        case .requiresApproval: return "exclamationmark.circle.fill"
        case .unavailable: return "arrow.down.app.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var launchStatusColor: Color {
        switch preferences.launchAtLoginStatus {
        case .enabled: return .green
        case .disabled: return .secondary
        case .requiresApproval: return .orange
        case .unavailable: return .secondary
        case .failed: return .red
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

private struct GlassIconButtonStyle: ButtonStyle {
    var tintColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(tintColor)
            .padding(.vertical, 7)
            .background(
                Color.clear.tahoeGlass(
                    tint: tintColor.opacity(configuration.isPressed ? 0.18 : 0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous),
                    interactive: true
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(configuration.isPressed ? 0.32 : 0.48),
                                tintColor.opacity(configuration.isPressed ? 0.30 : 0.17)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    SettingsView()
}
