import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var batteryMonitor: BatteryMonitor

    @AppStorage(BatteryTimeAppSettings.menuBarDisplayFormatKey)
    private var displayFormatRaw = BatteryTimeAppSettings.defaultMenuBarDisplayFormat.rawValue
    @AppStorage(BatteryTimeAppSettings.colorizeBatteryKey)
    private var colorizeBattery = BatteryTimeAppSettings.defaultColorizeBattery
    @AppStorage(BatteryTimeAppSettings.xlBatterySizeKey)
    private var xlBatterySize = BatteryTimeAppSettings.defaultXLBatterySize
    @AppStorage(BatteryTimeAppSettings.chargerStateInsideBatteryKey)
    private var chargerStateInsideBattery = BatteryTimeAppSettings.defaultChargerStateInsideBattery
    @AppStorage(BatteryTimeAppSettings.hideAdditionalWhenFullKey)
    private var hideAdditionalWhenFull = BatteryTimeAppSettings.defaultHideAdditionalWhenFull
    @State private var launchAtLogin = BatteryTimeAppSettings.launchAtLoginEnabled
    @State private var launchAtLoginError: String?

    // Popover
    @AppStorage(BatteryTimeAppSettings.popoverShowDetailsKey)
    private var popoverShowDetails = BatteryTimeAppSettings.defaultPopoverShowDetails
    @AppStorage(BatteryTimeAppSettings.popoverShowTopProcessKey)
    private var popoverShowTopProcess = BatteryTimeAppSettings.defaultPopoverShowTopProcess
    @AppStorage(BatteryTimeAppSettings.popoverShowUptimeKey)
    private var popoverShowUptime = BatteryTimeAppSettings.defaultPopoverShowUptime
    @AppStorage(BatteryTimeAppSettings.popoverCompactKey)
    private var popoverCompact = BatteryTimeAppSettings.defaultPopoverCompact
    @AppStorage(BatteryTimeAppSettings.popoverShowChargeKey)
    private var popoverShowCharge = BatteryTimeAppSettings.defaultPopoverShowCharge
    @AppStorage(BatteryTimeAppSettings.popoverShowTimeRemainingKey)
    private var popoverShowTimeRemaining = BatteryTimeAppSettings.defaultPopoverShowTimeRemaining
    @AppStorage(BatteryTimeAppSettings.popoverShowDrainRateKey)
    private var popoverShowDrainRate = BatteryTimeAppSettings.defaultPopoverShowDrainRate
    @AppStorage(BatteryTimeAppSettings.popoverShowCapacityKey)
    private var popoverShowCapacity = BatteryTimeAppSettings.defaultPopoverShowCapacity
    @AppStorage(BatteryTimeAppSettings.popoverShowTemperatureKey)
    private var popoverShowTemperature = BatteryTimeAppSettings.defaultPopoverShowTemperature
    @AppStorage(BatteryTimeAppSettings.popoverShowEstimateSourceKey)
    private var popoverShowEstimateSource = BatteryTimeAppSettings.defaultPopoverShowEstimateSource
    @AppStorage(BatteryTimeAppSettings.popoverShowChargeLimitKey)
    private var popoverShowChargeLimit = BatteryTimeAppSettings.defaultPopoverShowChargeLimit
    @AppStorage(BatteryTimeAppSettings.popoverShowDrainStatusKey)
    private var popoverShowDrainStatus = BatteryTimeAppSettings.defaultPopoverShowDrainStatus

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                BatterySettingsHeader(
                    snapshot: batteryMonitor.snapshot,
                    title: previewTitle,
                    showsInnerPercentage: showsInnerPercentage,
                    colorize: colorizeBattery,
                    xlSize: xlBatterySize,
                    chargerInside: chargerStateInsideBattery
                )

                // Widget section
                // Container matches Stats' PreferencesSection:
                // background = quaternaryLabelColor @ 0.025 alpha, radius 10,
                // edge insets top/bottom 8, left/right 10, spacing 8 between items.
                VStack(spacing: 8) {
                    BatterySettingsToggleRow(
                        title: "Start at login",
                        caption: launchAtLoginCaption,
                        isOn: launchAtLoginBinding
                    )

                    StatsSeparator()

                    BatterySettingsPickerRow(
                        title: "Additional information",
                        selection: additionalInformationBinding
                    )

                    StatsSeparator()

                    BatterySettingsToggleRow(
                        title: "Hide additional information when full",
                        isOn: $hideAdditionalWhenFull
                    )

                    StatsSeparator()

                    BatterySettingsToggleRow(
                        title: "Colourise",
                        isOn: $colorizeBattery
                    )

                    StatsSeparator()

                    BatterySettingsToggleRow(
                        title: "XL size",
                        isOn: $xlBatterySize
                    )

                    StatsSeparator()

                    BatterySettingsToggleRow(
                        title: "Charger state inside the battery",
                        isOn: $chargerStateInsideBattery
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.quaternaryLabelColor.withAlphaComponent(0.025)))
                }

                // Popover section header
                HStack {
                    Text("Popover")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)
                    Spacer()
                }
                .padding(.top, 4)

                // Popover section container
                VStack(spacing: 8) {
                    BatterySettingsToggleRow(
                        title: "Compact mode",
                        isOn: $popoverCompact
                    )

                    StatsSeparator()

                    BatterySettingsToggleRow(
                        title: "Show details",
                        isOn: $popoverShowDetails
                    )

                    // Indented sub-rows (dimmed when details section is off)
                    VStack(spacing: 8) {
                        BatterySettingsToggleRow(title: "Charge", isOn: $popoverShowCharge)
                        StatsSeparator()
                        BatterySettingsToggleRow(title: "Time remaining", isOn: $popoverShowTimeRemaining)
                        StatsSeparator()
                        BatterySettingsToggleRow(title: "Drain rate", isOn: $popoverShowDrainRate)
                        StatsSeparator()
                        BatterySettingsToggleRow(title: "Capacity", isOn: $popoverShowCapacity)
                        StatsSeparator()
                        BatterySettingsToggleRow(title: "Temperature", isOn: $popoverShowTemperature)
                        StatsSeparator()
                        BatterySettingsToggleRow(title: "Estimate source", isOn: $popoverShowEstimateSource)
                        StatsSeparator()
                        BatterySettingsToggleRow(title: "Charge limit", isOn: $popoverShowChargeLimit)
                        StatsSeparator()
                        BatterySettingsToggleRow(title: "Drain status", isOn: $popoverShowDrainStatus)
                    }
                    .padding(.leading, 16)
                    .opacity(popoverShowDetails ? 1 : 0.4)
                    .disabled(!popoverShowDetails)
                    .animation(.easeInOut(duration: 0.15), value: popoverShowDetails)

                    StatsSeparator()

                    BatterySettingsToggleRow(
                        title: "Show top process",
                        isOn: $popoverShowTopProcess
                    )

                    StatsSeparator()

                    BatterySettingsToggleRow(
                        title: "Show uptime",
                        isOn: $popoverShowUptime
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.quaternaryLabelColor.withAlphaComponent(0.025)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .frame(width: 540, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            launchAtLogin = BatteryTimeAppSettings.launchAtLoginEnabled
        }
    }

    private var additionalInformationBinding: Binding<DisplayFormat> {
        Binding(
            get: {
                DisplayFormat(rawValue: displayFormatRaw) ?? BatteryTimeAppSettings.defaultMenuBarDisplayFormat
            },
            set: { newValue in
                displayFormatRaw = newValue.rawValue
            }
        )
    }

    private var selectedFormat: DisplayFormat {
        DisplayFormat(rawValue: displayFormatRaw) ?? BatteryTimeAppSettings.defaultMenuBarDisplayFormat
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try BatteryTimeAppSettings.setLaunchAtLoginEnabled(newValue)
                    launchAtLogin = BatteryTimeAppSettings.launchAtLoginEnabled
                    launchAtLoginError = nil
                } catch {
                    launchAtLogin = BatteryTimeAppSettings.launchAtLoginEnabled
                    launchAtLoginError = "Could not update Login Items."
                }
            }
        )
    }

    private var launchAtLoginCaption: String? {
        if let launchAtLoginError { return launchAtLoginError }
        if BatteryTimeAppSettings.launchAtLoginRequiresApproval {
            return "Requires approval in System Settings."
        }
        return "Keeps usage history complete in the background."
    }

    private var previewTitle: String {
        batteryMonitor.menuBarTitle(format: selectedFormat, hideWhenFull: hideAdditionalWhenFull)
    }

    private var showsInnerPercentage: Bool {
        selectedFormat == .innerPercentage
            && (!batteryMonitor.snapshot.isPluggedIn || !chargerStateInsideBattery)
    }
}

// MARK: - Header

private struct BatterySettingsHeader: View {
    let snapshot: BatterySnapshot
    let title: String
    let showsInnerPercentage: Bool
    let colorize: Bool
    let xlSize: Bool
    let chargerInside: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: previewImage)
                .resizable()
                .frame(width: previewImage.size.width, height: previewImage.size.height)
                .frame(height: 22)

            Text("Battery")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery menu bar preview")
    }

    private var previewImage: NSImage {
        BatteryStatusIconRenderer.image(
            for: snapshot,
            title: title,
            showsInnerPercentage: showsInnerPercentage,
            colorize: colorize,
            xlSize: xlSize,
            chargerInside: chargerInside
        )
    }
}

// MARK: - Row components

// Matches Stats' PreferencesSeparator: 1pt, separatorColor @ 0.05 alpha
private struct StatsSeparator: View {
    var body: some View {
        Color(NSColor.separatorColor)
            .opacity(0.15)
            .frame(height: 1)
    }
}

// Matches Stats' PreferencesRow label: systemFont(ofSize: 12, weight: .regular)
private struct BatterySettingsPickerRow: View {
    let title: String
    @Binding var selection: DisplayFormat

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            AdditionalInformationPopUp(selection: $selection)
                .frame(width: 200, height: 22)
        }
        .padding(.top, 5)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
    }
}

private struct BatterySettingsToggleRow: View {
    let title: String
    let caption: String?
    @Binding var isOn: Bool

    init(title: String, caption: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.caption = caption
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.primary)

                if let caption {
                    Text(caption)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.top, 5)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Additional information popup

private struct AdditionalInformationPopUp: NSViewRepresentable {
    @Binding var selection: DisplayFormat

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        button.controlSize = .small
        button.bezelStyle = .rounded
        populate(button)
        selectCurrentItem(in: button)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        if button.itemArray.isEmpty { populate(button) }
        selectCurrentItem(in: button)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private func populate(_ button: NSPopUpButton) {
        button.removeAllItems()
        for item in menuItems {
            guard let format = item else {
                button.menu?.addItem(.separator())
                continue
            }
            button.addItem(withTitle: format.title)
            button.lastItem?.representedObject = format.rawValue
        }
    }

    private func selectCurrentItem(in button: NSPopUpButton) {
        guard let item = button.itemArray.first(where: { $0.representedObject as? String == selection.rawValue }) else { return }
        button.select(item)
    }

    private var menuItems: [DisplayFormat?] {
        [.iconOnly, nil, .innerPercentage, nil, .percentOnly, .timeOnly, .percentAndTime, .timeAndPercent]
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: AdditionalInformationPopUp
        init(parent: AdditionalInformationPopUp) { self.parent = parent }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            guard let rawValue = sender.selectedItem?.representedObject as? String,
                  let format = DisplayFormat(rawValue: rawValue) else { return }
            parent.selection = format
        }
    }
}
