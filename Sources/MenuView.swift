import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var store: PointerStore
    @State private var newPresetName = ""
    @State private var editName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Where's My Mouse?").font(.headline)
                Spacer()
                Text(String(format: "%.1f×", store.size)).foregroundStyle(.secondary).monospacedDigit()
            }

            if !store.hasFullDiskAccess { fullDiskAccessBanner }

            section("Presets") {
                ForEach(store.allPresets) { preset in
                    PresetRow(preset: preset, isActive: store.activePresetID == preset.id)
                }
            }

            Divider()

            section("Adjust") {
                SizeSlider(size: Binding(get: { store.size }, set: { store.setSize($0) }), maxSize: store.maxSize)
                Toggle("Extra large sizes (up to 30×)", isOn: Binding(get: { store.extendedSizes }, set: { store.setExtendedSizes($0) }))
                    .font(.caption)
                    .controlSize(.small)
                ColorRow(title: "Fill", color: store.fill, target: .fill, onPick: store.setFill)
                ColorRow(title: "Outline", color: store.outline, target: .outline, onPick: store.setOutline)
            }

            Divider()

            if let editing = store.editingPreset {
                section("Editing “\(editing.name)”") {
                    HStack {
                        TextField("Name", text: $editName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(commitEdit)
                        Button("Done", action: commitEdit).disabled(trimmed(editName).isEmpty)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .onAppear { editName = editing.name }
                .onChange(of: editing.id) { _ in editName = editing.name }
            } else {
                if let modified = store.modifiedSelectedPreset {
                    HStack {
                        Text("Changed from “\(modified.name)”").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Update “\(modified.name)”") { store.updateSelectedPreset() }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                section(store.modifiedSelectedPreset == nil ? "Save current as preset" : "Or save as a new preset") {
                    HStack {
                        TextField("Preset name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(saveNew)
                        Button("Save", action: saveNew).disabled(trimmed(newPresetName).isEmpty)
                    }
                }
            }

            Divider()

            appRulesSection

            Divider()

            Toggle("Launch at login", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
            HStack {
                Spacer()
                Button("Quit Where's My Mouse") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { store.refresh() }
    }

    /// "While this app is open, use this preset." The newest open app wins.
    private var appRulesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("App rules").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(get: { store.appRulesEnabled }, set: { store.setAppRulesEnabled($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .help("Switch to an app's preset automatically. With no rule app open, it goes back to Default.")
            if !store.appRules.isEmpty {
                Picker("", selection: Binding(get: { store.ruleTrigger }, set: { store.setRuleTrigger($0) })) {
                    ForEach(RuleTrigger.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .help("Active app: follows the app you're using. Last opened: the most recently launched rule app wins.")
            }
            ForEach(store.appRules) { rule in
                HStack(spacing: 8) {
                    if let icon = PointerStore.icon(forBundleID: rule.bundleID) {
                        Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                    }
                    Text(rule.appName).lineLimit(1)
                    Spacer()
                    Picker("", selection: Binding(get: { rule.presetID }, set: { store.setPreset($0, for: rule) })) {
                        ForEach(store.allPresets) { preset in Text(preset.name).tag(preset.id) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(store.highlightedRuleID == rule.id ? Color.accentColor.opacity(0.2) : .clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .opacity(store.appRulesEnabled ? 1 : 0.5)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Remove “\(rule.appName)”", role: .destructive) { store.removeAppRule(rule) }
                }
                .help("Right-click to remove this rule.")
            }
            if store.appRules.isEmpty {
                Text("Switch to a preset automatically while an app is open, e.g. a recording app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { store.addAppRule() } label: { Label("Add app…", systemImage: "plus") }
                .buttonStyle(.borderless)
        }
    }

    private var fullDiskAccessBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Colors need Full Disk Access", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Size works without it. Add Where's My Mouse in Privacy & Security → Full Disk Access, then reopen this menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open Settings") { CursorController.openFullDiskAccessSettings() }
                Button("Show App in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }

    private func saveNew() {
        let name = trimmed(newPresetName)
        guard !name.isEmpty else { return }
        store.saveNewPreset(named: name)
        newPresetName = ""
    }

    private func commitEdit() {
        let name = trimmed(editName)
        guard !name.isEmpty else { return }
        store.commitEdit(name: name)
    }
}

private struct PresetRow: View {
    @EnvironmentObject private var store: PointerStore
    let preset: Preset
    let isActive: Bool
    @State private var hovering = false
    private var isEditing: Bool { store.editingPresetID == preset.id }

    var body: some View {
        HStack(spacing: 8) {
            Button { store.select(preset) } label: {
                HStack(spacing: 8) {
                    PointerSwatch(fill: preset.fill, outline: preset.outline)
                    Text(preset.name)
                    ForEach(store.ruleApps(for: preset)) { rule in
                        if let icon = PointerStore.icon(forBundleID: rule.bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 14, height: 14).help(rule.appName)
                        }
                    }
                    Spacer()
                    Text(String(format: "%.1f×", preset.size)).foregroundStyle(.secondary).monospacedDigit()
                    Image(systemName: "checkmark").opacity(isActive ? 1 : 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if !preset.isBuiltIn {
                    Button { store.beginEditing(preset) } label: { Image(systemName: "pencil") }
                        .buttonStyle(.borderless)
                        .help("Edit")
                    Button { store.delete(preset) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help("Delete")
                }
            }
            .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(isEditing ? Color.accentColor.opacity(0.15) : hovering ? Color.primary.opacity(0.08) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
        .onHover { hovering = $0 }
        .contextMenu {
            if !preset.isBuiltIn {
                Button("Edit") { store.beginEditing(preset) }
                Button("Delete", role: .destructive) { store.delete(preset) }
            }
        }
    }
}

/// Size slider with a mark per whole size. Snaps to a whole size when released nearby.
private struct SizeSlider: View {
    @Binding var size: Double
    let maxSize: Double
    private var range: ClosedRange<Double> { 1...maxSize }
    private var marks: [Double] { Array(stride(from: 1, through: maxSize, by: 1)) }
    /// Label every size up to 10×; past that, 1× and every 5× so they fit.
    private func showsLabel(_ mark: Double) -> Bool { maxSize <= 10 || mark == 1 || Int(mark) % 5 == 0 }
    // Approximate inset of the slider track from its frame (half the knob width).
    private let knobInset: CGFloat = 10

    var body: some View {
        VStack(spacing: 2) {
            Slider(value: $size, in: range) { editing in
                if !editing, let mark = marks.first(where: { abs($0 - size) < 0.12 }), mark != size { size = mark }
            }
            GeometryReader { geo in
                let track = geo.size.width - knobInset * 2
                let span = maxSize - 1
                ForEach(marks, id: \.self) { mark in
                    Button { size = mark } label: {
                        VStack(spacing: 1) {
                            Rectangle().frame(width: 1, height: 4)
                            Text("\(Int(mark))×").font(.caption2.weight(abs(size - mark) < 0.05 ? .bold : .regular))
                                .opacity(showsLabel(mark) || abs(size - mark) < 0.05 ? 1 : 0)
                        }
                        .foregroundStyle(abs(size - mark) < 0.05 ? Color.accentColor : .secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .position(x: knobInset + track * (mark - 1) / span, y: 9)
                }
            }
            .frame(height: 18)
        }
    }
}

private struct ColorRow: View {
    @EnvironmentObject private var store: PointerStore
    let title: String
    let color: RGBA
    let target: PointerStore.ColorTarget
    let onPick: (RGBA) -> Void

    private static let swatches: [RGBA] = [
        .black, .white, .red, .yellow,
        RGBA(red: 0.1, green: 0.8, blue: 0.2), RGBA(red: 0, green: 0.45, blue: 1),
        RGBA(red: 0.6, green: 0.2, blue: 1), RGBA(red: 1, green: 0.4, blue: 0.75),
    ]

    var body: some View {
        HStack(spacing: 5) {
            Text(title).frame(width: 52, alignment: .leading)
            ForEach(Self.swatches, id: \.self) { swatch in
                Button { onPick(swatch) } label: {
                    Circle()
                        .fill(swatch.color)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.5))
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2).padding(-3)
                            .opacity(swatch.isClose(to: color) ? 1 : 0))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Button { store.openColorPanel(for: target) } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.color)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary.opacity(0.3)))
                    .frame(width: 26, height: 16)
            }
            .buttonStyle(.plain)
            .help("Custom color…")
        }
    }
}

/// Small preview of a pointer's fill and outline.
private struct PointerSwatch: View {
    let fill: RGBA
    let outline: RGBA

    var body: some View {
        ZStack {
            Image(systemName: "cursorarrow").font(.system(size: 15, weight: .black)).foregroundStyle(outline.color)
            Image(systemName: "cursorarrow").font(.system(size: 11, weight: .regular)).foregroundStyle(fill.color)
        }
        .frame(width: 18, height: 18)
    }
}
