import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    @State private var sliderValue: Double = PreferencesManager.shared.updateFrequency
    @State private var showResetConfirm = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    private let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    private let panelControlWidth: CGFloat = 256

    var body: some View {
        ZStack(alignment: .top) {
            tahoeBackdrop

            VStack(spacing: 7) {
                if !cpuMonitor.isDataFresh {
                    statusBanner
                }

                monitorPanel
                refreshPanel
                systemPanel
                actionButtons
                headerView
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(popoverBorder, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .onAppear {
            sliderValue = preferences.updateFrequency
            preferences.refreshLaunchAtLoginStatus()
        }
    }

    private var headerView: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tintColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(crispStroke, lineWidth: 1)
                    )
                Image(systemName: cpuMonitor.currentMetric == .cpu ? "cpu" : "memorychip")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tintColor)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 0) {
                Text("CPUMeter")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("v\(appVersion)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .offset(x: 62)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .help("CPUMeter \(appVersion) (\(appBuild))")
    }

    private var monitorPanel: some View {
        glassSection(spacing: 7, padding: 8) {
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

            VStack(spacing: 5) {
                displayModeSelector
                metricSelector
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 7) {
                primaryStatTile

                VStack(spacing: 7) {
                    supportStat("Avg", value: cpuMonitor.averageValue, symbol: "chart.bar.fill")
                    supportStat("Peak", value: cpuMonitor.peakValue, symbol: "flame.fill")
                }
                .frame(width: 104)
            }
        }
    }

    private var metricSelector: some View {
        segmentedControl(accessibilityLabel: "Metric Type") {
            ForEach(MetricType.allCases) { metric in
                segmentedButton(
                    title: metric.rawValue,
                    isSelected: preferences.metricType == metric,
                    action: { preferences.setMetricType(metric) }
                )
            }
        }
    }

    private var displayModeSelector: some View {
        segmentedControl(accessibilityLabel: "Display Mode") {
            ForEach(DisplayMode.allCases) { mode in
                segmentedButton(
                    title: mode.title,
                    isSelected: preferences.displayMode == mode,
                    action: { preferences.setDisplayMode(mode) }
                )
            }
        }
    }

    private func segmentedControl<Content: View>(
        accessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .frame(width: panelControlWidth, height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(controlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(crispStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func segmentedButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(2)
        )
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
                    .background(Capsule().fill(Color.white.opacity(0.08)))
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.13))
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
        padding: CGFloat = 9,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(crispStroke, lineWidth: 1)
        )
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tileFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(crispStroke, lineWidth: 1)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tileFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(crispStroke, lineWidth: 1)
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
            Capsule()
                .fill(launchStatusColor.opacity(0.12))
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
        Color(nsColor: NSColor(calibratedWhite: 0.055, alpha: 1))
            .ignoresSafeArea()
    }

    private var panelFill: Color {
        Color(nsColor: NSColor(calibratedRed: 0.045, green: 0.135, blue: 0.120, alpha: 1))
    }

    private var tileFill: Color {
        Color(nsColor: NSColor(calibratedRed: 0.030, green: 0.115, blue: 0.105, alpha: 1))
    }

    private var controlFill: Color {
        Color(nsColor: NSColor(calibratedWhite: 0.145, alpha: 1))
    }

    private var crispStroke: Color {
        Color.white.opacity(0.22)
    }

    private var popoverBorder: Color {
        Color.white.opacity(0.28)
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tintColor.opacity(configuration.isPressed ? 0.18 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.26 : 0.20), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    SettingsView()
}
