import SwiftUI

/// Spacing on an 8-point grid.
private enum Grid {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let rowHeight: CGFloat = 36
    static let swatch: CGFloat = 22
}

struct MenuView: View {
    @EnvironmentObject private var store: PointerStore
    @State private var newPresetName = ""
    @State private var editName = ""
    @State private var addingPreset = false
    @FocusState private var typing: Bool
    @AppStorage("showAppRules") private var showAppRules = false

    var body: some View {
        VStack(alignment: .leading, spacing: Grid.m) {
            header

            if !store.hasFullDiskAccess { fullDiskAccessBanner }
            if let deleted = store.recentlyDeleted { undoBanner(deleted.preset) }
            if let pin = store.pinSuggestion { pinBanner(pin.rule, pin.preset) }

            presetsSection

            Divider()

            adjustSection

            Divider()

            appRulesSection

            Divider()

            footer
        }
        .padding(Grid.m)
        .frame(width: 340)
        .background(keyboardShortcuts)
        .onAppear { store.refresh() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Grid.xs) {
            HStack {
                Text("Where's My Mouse?").font(.headline)
                Spacer()
                Text(String(format: "%.1f×", store.size)).font(.headline).monospacedDigit().foregroundStyle(.secondary)
            }
            Label(store.statusText, systemImage: "cursorarrow.motionlines")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Now using \(store.statusText)")
        }
    }

    // MARK: Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: Grid.xs) {
            sectionTitle("Presets")
            ForEach(Array(store.allPresets.enumerated()), id: \.element.id) { index, preset in
                PresetRow(preset: preset, number: index + 1, isActive: store.activePresetID == preset.id)
            }

            if let editing = store.editingPreset {
                nameField(title: "Rename “\(editing.name)”", text: $editName, button: "Done", action: commitEdit)
                    .onAppear { editName = editing.name }
                    .onChange(of: editing.id) { _ in editName = editing.name }
            } else if let modified = store.modifiedSelectedPreset {
                HStack {
                    Text("Changed from “\(modified.name)”").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Update") { store.updateSelectedPreset() }
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, Grid.xs)
            }

            if addingPreset {
                nameField(title: "New preset from the current pointer", text: $newPresetName, button: "Save", action: saveNew)
            } else {
                Button {
                    addingPreset = true
                    typing = true
                } label: {
                    Label("New preset", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, Grid.s)
            }
        }
    }

    private func nameField(title: String, text: Binding<String>, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Grid.xs) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: Grid.s) {
                TextField("Name", text: text)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .focused($typing)
                    .onSubmit(action)
                Button(button, action: action)
                    .controlSize(.large)
                    .disabled(trimmed(text.wrappedValue).isEmpty)
            }
        }
        .padding(.top, Grid.xs)
    }

    // MARK: Adjust

    private var adjustSection: some View {
        VStack(alignment: .leading, spacing: Grid.s) {
            sectionTitle("Adjust")
            SizeSlider(size: Binding(get: { store.size }, set: { store.setSize($0) }), maxSize: store.maxSize)
            Toggle("Extra large sizes, up to 30×", isOn: Binding(get: { store.extendedSizes }, set: { store.setExtendedSizes($0) }))
                .font(.callout)
            HStack {
                Toggle("Shake mouse to find pointer", isOn: Binding(get: { store.shakeToLocate }, set: { store.setShakeToLocate($0) }))
                    .font(.callout)
                    .help("macOS's own trick: shake the mouse and the pointer briefly grows. Same switch as in Accessibility → Display.")
                Spacer()
                Button { CursorController.openPointerSettings() } label: {
                    Image(systemName: "gearshape").frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Open the Pointer settings in System Settings")
                .accessibilityLabel("Open Pointer settings in System Settings")
            }
            ColorRow(title: "Fill", color: store.fill, target: .fill, onPick: store.setFill)
            ColorRow(title: "Outline", color: store.outline, target: .outline, onPick: store.setOutline)
        }
    }

    // MARK: App rules

    private var appRulesSection: some View {
        VStack(alignment: .leading, spacing: Grid.s) {
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showAppRules.toggle() }
                } label: {
                    HStack(spacing: Grid.xs) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .rotationEffect(.degrees(showAppRules ? 90 : 0))
                        sectionTitle(store.appRules.isEmpty ? "App rules" : "App rules · \(store.appRules.count)")
                    }
                    .frame(minHeight: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showAppRules ? "Hide app rules" : "Show app rules")
                Spacer()
                Toggle("App rules on", isOn: Binding(get: { store.appRulesEnabled }, set: { store.setAppRulesEnabled($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .help("Switch to an app's preset automatically. With no rule app open, it goes back to Default.")

            if showAppRules {
                if store.appRules.isEmpty {
                    Text("Pick an app and a preset; while that app is open, your pointer switches to it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Picker("Follow", selection: Binding(get: { store.ruleTrigger }, set: { store.setRuleTrigger($0) })) {
                        ForEach(RuleTrigger.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .help("Active app: follows the app you're using. Last opened: the most recently launched rule app wins.")
                    ForEach(store.appRules) { rule in RuleRow(rule: rule) }
                }
                Button { store.addAppRule() } label: {
                    Label("Add app…", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, Grid.s)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Toggle("Launch at login", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .controlSize(.large)
                .keyboardShortcut("q")
                .help("Quit Where's My Mouse (⌘Q)")
        }
    }

    // MARK: Banners

    private var fullDiskAccessBanner: some View {
        VStack(alignment: .leading, spacing: Grid.s) {
            Label("Colors need Full Disk Access", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Size works without it. Add Where's My Mouse under Privacy & Security → Full Disk Access.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Grid.s) {
                Button("Open Settings") { CursorController.openFullDiskAccessSettings() }
                Button("Show App") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            }
        }
        .padding(Grid.s + Grid.xs)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Offered when you pick a preset while an app rule is in control; rules only change on purpose.
    private func pinBanner(_ rule: AppRule, _ preset: Preset) -> some View {
        let current = store.allPresets.first { $0.id == rule.presetID }?.name ?? "Default"
        return HStack(spacing: Grid.s) {
            Text("\(rule.appName) uses \(current).").font(.callout).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: Grid.xs)
            Button("Pin \(preset.name) to \(rule.appName)") { store.acceptPinSuggestion() }
                .controlSize(.large)
                .lineLimit(1)
        }
        .padding(.horizontal, Grid.s + Grid.xs)
        .padding(.vertical, Grid.s)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func undoBanner(_ preset: Preset) -> some View {
        HStack {
            Text("Deleted “\(preset.name)”").font(.callout)
            Spacer()
            Button("Undo") { store.undoDelete() }
                .controlSize(.large)
                .keyboardShortcut("z")
        }
        .padding(.horizontal, Grid.s + Grid.xs)
        .padding(.vertical, Grid.s)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Keyboard

    /// ↑/↓ step through presets and ⌘1–⌘9 jump to one. Off while typing a name.
    private var keyboardShortcuts: some View {
        ZStack {
            Button("Previous preset") { step(-1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("Next preset") { step(1) }.keyboardShortcut(.downArrow, modifiers: [])
            ForEach(Array(store.allPresets.prefix(9).enumerated()), id: \.element.id) { index, preset in
                Button(preset.name) { store.select(preset) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .disabled(typing)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func step(_ delta: Int) {
        let presets = store.allPresets
        guard !presets.isEmpty else { return }
        let current = presets.firstIndex { $0.id == store.activePresetID } ?? (delta > 0 ? -1 : presets.count)
        let next = min(max(current + delta, 0), presets.count - 1)
        store.select(presets[next])
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }

    private func saveNew() {
        let name = trimmed(newPresetName)
        guard !name.isEmpty else { return }
        store.saveNewPreset(named: name)
        newPresetName = ""
        addingPreset = false
        typing = false
    }

    private func commitEdit() {
        let name = trimmed(editName)
        guard !name.isEmpty else { return }
        store.commitEdit(name: name)
        typing = false
    }
}

// MARK: - Rows

private struct PresetRow: View {
    @EnvironmentObject private var store: PointerStore
    let preset: Preset
    let number: Int
    let isActive: Bool
    @State private var hovering = false
    private var isEditing: Bool { store.editingPresetID == preset.id }

    var body: some View {
        HStack(spacing: Grid.s) {
            Button { store.select(preset) } label: {
                HStack(spacing: Grid.s) {
                    PointerSwatch(fill: preset.fill, outline: preset.outline)
                    Text(preset.name).fontWeight(isActive ? .semibold : .regular).lineLimit(1)
                    ForEach(store.ruleApps(for: preset)) { rule in
                        if let icon = PointerStore.icon(forBundleID: rule.bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 16, height: 16).help(rule.appName)
                        }
                    }
                    Spacer(minLength: Grid.xs)
                    Text(String(format: "%.1f×", preset.size)).foregroundStyle(.secondary).monospacedDigit()
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .opacity(isActive ? 1 : 0)
                }
                .frame(maxWidth: .infinity, minHeight: Grid.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Edit and delete appear on hover (or while editing), keeping the list calm.
            if !preset.isBuiltIn {
                HStack(spacing: 0) {
                    iconButton("pencil", help: "Rename or update") { store.beginEditing(preset) }
                    iconButton("trash", help: "Delete") { store.delete(preset) }
                }
                .opacity(hovering || isEditing ? 1 : 0)
            } else {
                Color.clear.frame(width: 48, height: 1)
            }
        }
        .padding(.horizontal, Grid.s)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Use “\(preset.name)”") { store.select(preset) }
            if !preset.isBuiltIn {
                Button("Rename or update") { store.beginEditing(preset) }
                Button("Delete", role: .destructive) { store.delete(preset) }
            }
        }
        .help(number <= 9 ? "⌘\(number)" : "")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.name), \(String(format: "%.1f", preset.size)) times\(isActive ? ", selected" : "")")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var rowBackground: Color {
        if isEditing { return Color.accentColor.opacity(0.22) }
        if isActive { return Color.accentColor.opacity(0.14) }
        return hovering ? Color.primary.opacity(0.07) : .clear
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct RuleRow: View {
    @EnvironmentObject private var store: PointerStore
    let rule: AppRule
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Grid.s) {
            if let icon = PointerStore.icon(forBundleID: rule.bundleID) {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            }
            Text(rule.appName).lineLimit(1)
            Spacer()
            Picker("Preset for \(rule.appName)", selection: Binding(get: { rule.presetID }, set: { store.setPreset($0, for: rule) })) {
                ForEach(store.allPresets) { preset in Text(preset.name).tag(preset.id) }
            }
            .labelsHidden()
            .frame(width: 150)
            Button { store.removeAppRule(rule) } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Remove this rule")
            .accessibilityLabel("Remove rule for \(rule.appName)")
            .opacity(hovering ? 1 : 0)
        }
        .frame(minHeight: Grid.rowHeight)
        .padding(.horizontal, Grid.s)
        .background(store.highlightedRuleID == rule.id ? Color.accentColor.opacity(0.2) : hovering ? Color.primary.opacity(0.07) : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .opacity(store.appRulesEnabled ? 1 : 0.5)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Remove “\(rule.appName)”", role: .destructive) { store.removeAppRule(rule) }
        }
    }
}

// MARK: - Controls

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
        VStack(spacing: Grid.xs) {
            Slider(value: $size, in: range) { editing in
                if !editing, let mark = marks.first(where: { abs($0 - size) < 0.12 }), mark != size { size = mark }
            }
            .accessibilityLabel("Pointer size")
            .accessibilityValue(String(format: "%.1f times", size))
            GeometryReader { geo in
                let track = geo.size.width - knobInset * 2
                let span = maxSize - 1
                ForEach(marks, id: \.self) { mark in
                    let current = abs(size - mark) < 0.05
                    Button { size = mark } label: {
                        VStack(spacing: 2) {
                            Rectangle().frame(width: 1, height: 4)
                            Text("\(Int(mark))×").font(.caption.weight(current ? .bold : .regular))
                                .opacity(showsLabel(mark) || current ? 1 : 0)
                        }
                        .frame(minWidth: 22, minHeight: 24)
                        .foregroundStyle(current ? Color.accentColor : .secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Int(mark)) times")
                    .position(x: knobInset + track * (mark - 1) / span, y: 12)
                }
            }
            .frame(height: 24)
        }
    }
}

private struct ColorRow: View {
    @EnvironmentObject private var store: PointerStore
    let title: String
    let color: RGBA
    let target: PointerStore.ColorTarget
    let onPick: (RGBA) -> Void

    private static let swatches: [(name: String, color: RGBA)] = [
        ("Black", .black), ("White", .white), ("Red", .red), ("Yellow", .yellow),
        ("Green", RGBA(red: 0.1, green: 0.8, blue: 0.2)), ("Blue", RGBA(red: 0, green: 0.45, blue: 1)),
        ("Purple", RGBA(red: 0.6, green: 0.2, blue: 1)), ("Pink", RGBA(red: 1, green: 0.4, blue: 0.75)),
    ]

    var body: some View {
        HStack(spacing: 6) {
            Text(title).frame(width: 56, alignment: .leading)
            ForEach(Self.swatches, id: \.name) { swatch in
                let selected = swatch.color.isClose(to: color)
                Button { onPick(swatch.color) } label: {
                    Circle()
                        .fill(swatch.color.color)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.5))
                        // Selection is a ring and a check, not color alone.
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2).padding(-3).opacity(selected ? 1 : 0))
                        .overlay(Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(swatch.color.isDark ? .white : .black)
                            .opacity(selected ? 1 : 0))
                        .frame(width: Grid.swatch, height: Grid.swatch)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(swatch.name)
                .accessibilityLabel("\(swatch.name) \(title.lowercased())")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer(minLength: 0)
            Button { store.openColorPanel(for: target) } label: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.color)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.3)))
                    .overlay(Image(systemName: "eyedropper").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color.isDark ? .white : .black).opacity(0.7))
                    .frame(width: 30, height: Grid.swatch)
            }
            .buttonStyle(.plain)
            .help("Any color…")
            .accessibilityLabel("Custom \(title.lowercased()) color")
        }
    }
}

/// Small preview of a pointer's fill and outline.
private struct PointerSwatch: View {
    let fill: RGBA
    let outline: RGBA

    var body: some View {
        ZStack {
            Image(systemName: "cursorarrow").font(.system(size: 19, weight: .black)).foregroundStyle(outline.color)
            Image(systemName: "cursorarrow").font(.system(size: 14, weight: .regular)).foregroundStyle(fill.color)
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
